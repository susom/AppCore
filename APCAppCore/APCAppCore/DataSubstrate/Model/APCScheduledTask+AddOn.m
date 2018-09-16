// 
//  APCScheduledTask+AddOn.m 
//  APCAppCore 
// 
// Copyright (c) 2015, Apple Inc. All rights reserved. 
// 
// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
// 
// 1.  Redistributions of source code must retain the above copyright notice, this
// list of conditions and the following disclaimer.
// 
// 2.  Redistributions in binary form must reproduce the above copyright notice, 
// this list of conditions and the following disclaimer in the documentation and/or 
// other materials provided with the distribution. 
// 
// 3.  Neither the name of the copyright holder(s) nor the names of any contributors 
// may be used to endorse or promote products derived from this software without 
// specific prior written permission. No license is granted to the trademarks of 
// the copyright holders even if such marks are included in this software. 
// 
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE 
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL 
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR 
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER 
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, 
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE 
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
// 
 
#import "APCScheduledTask+AddOn.h"
#import "APCAppCore.h"
#import "APCDateRange.h"

static NSInteger kSecondsPerMinute = 60;
static NSInteger kDefaultReminderOffset = -15;

static NSString * const kScheduledTaskIDKey = @"scheduledTaskID";

@implementation APCScheduledTask (AddOn)

- (void)completeScheduledTask
{
    self.completed = @(YES);
    NSError * saveError;
    [self saveToPersistentStore:&saveError];
    APCLogError2 (saveError);
}

- (void) deleteScheduledTask
{
    [self clearCurrentReminderIfNecessary];
    [self.managedObjectContext deleteObject:self];
    NSError * saveError;
    [self saveToPersistentStore:&saveError];
    APCLogError2 (saveError);
}

- (BOOL)removeScheduledTask:(NSError **)taskError
{
    BOOL deleteSuccess = NO;
    
    [self clearCurrentReminderIfNecessary];
    
    [self.managedObjectContext deleteObject:self];
    
    NSError *coreDataError = nil;
    deleteSuccess = [self saveToPersistentStore:&coreDataError];
    
    if (!deleteSuccess) {
        APCLogError2(coreDataError);
    }
    
    *taskError = coreDataError;
    
    return deleteSuccess;
}

- (NSString *)completeByDateString
{
    return [self.endOn friendlyDescription];
}

- (APCResult *)lastResult
{
    APCResult * retValue = nil;
    @synchronized(self){
        if (self.results.count == 1) {
            retValue = [self.results anyObject];
        }
        else if(self.results.count > 1)
        {
            NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"endDate" ascending:NO];
            NSArray * sortedArray = [self.results sortedArrayUsingDescriptors:@[sortDescriptor]];
            retValue = [sortedArray firstObject];
        }
    }
    return  retValue;
}


/*********************************************************************************/
#pragma mark - Life Cycle Methods
/*********************************************************************************/
- (void)awakeFromInsert
{
    [super awakeFromInsert];
    [self setPrimitiveValue:[NSDate date] forKey:@"createdAt"];
    [self setPrimitiveValue:[NSUUID UUID].UUIDString forKey:@"uid"];
}

- (void)willSave
{
    [self setPrimitiveValue:[NSDate date] forKey:@"updatedAt"];
}


/*********************************************************************************/
#pragma mark - Local Notification
/*********************************************************************************/

- (void)scheduleReminderIfNecessary
{
    if ([self.generatedSchedule.shouldRemind boolValue]) {
        [self clearCurrentReminderIfNecessary];
        // Schedule the notification
        UNMutableNotificationContent *content = [UNMutableNotificationContent new];
        content.body = self.generatedSchedule.reminderMessage;
        NSMutableDictionary *notificationInfo = [NSMutableDictionary dictionary];
        notificationInfo[kScheduledTaskIDKey] = self.uid;
        content.userInfo = notificationInfo;
        
        NSTimeInterval reminderOffset = self.generatedSchedule.reminderOffset ? (NSTimeInterval)[self.generatedSchedule.reminderOffset doubleValue] : kDefaultReminderOffset * kSecondsPerMinute;
        NSDate *fireDate = [self.startOn dateByAddingTimeInterval: reminderOffset];
        unsigned unitFlags = NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond;
        NSDateComponents *components = [[NSCalendar currentCalendar] components:unitFlags fromDate:fireDate];
        components.timeZone = [NSTimeZone localTimeZone];
        UNCalendarNotificationTrigger *trigger = [UNCalendarNotificationTrigger triggerWithDateMatchingComponents:components repeats:NO];
        
        UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:kScheduledTaskIDKey content:content trigger:trigger];
        
        //TODO: figure out how the badge numbers are going to be set.
        //localNotification.applicationIconBadgeNumber = [[UIApplication sharedApplication] applicationIconBadgeNumber] + 1;
        
        [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request withCompletionHandler:nil];
    }
}


+ (void)clearAllReminders
{
    __block NSMutableArray *appNotificationRequests = [NSMutableArray new];
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    [[UNUserNotificationCenter currentNotificationCenter] getPendingNotificationRequestsWithCompletionHandler:^(NSArray<UNNotificationRequest *> * _Nonnull requests) {
        for (UNNotificationRequest *request in requests) {
            NSDictionary *userInfoCurrent = request.content.userInfo;
            if (userInfoCurrent[kScheduledTaskIDKey]) {
                [appNotificationRequests addObject:request];
            }
        }
        dispatch_semaphore_signal(sem);
    }];
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    NSArray *identifiers = [appNotificationRequests valueForKey:@"identifier"];
    [[UNUserNotificationCenter currentNotificationCenter] removePendingNotificationRequestsWithIdentifiers:identifiers];
}

- (void)clearCurrentReminderIfNecessary
{
    UNNotificationRequest *currentReminder = [self currentReminder];
    if (currentReminder) {
        [[UNUserNotificationCenter currentNotificationCenter] removePendingNotificationRequestsWithIdentifiers:@[currentReminder.identifier]];
    }
}

- (UNNotificationRequest *)currentReminder
{
    __block UNNotificationRequest *appNotificationRequest;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    [[UNUserNotificationCenter currentNotificationCenter] getPendingNotificationRequestsWithCompletionHandler:^(NSArray<UNNotificationRequest *> * _Nonnull requests) {
        for (UNNotificationRequest *request in requests) {
            NSDictionary *userInfoCurrent = request.content.userInfo;
            if ([userInfoCurrent[kScheduledTaskIDKey] isEqualToString:self.uid]) {
                appNotificationRequest = request;
                break;
            }
        }
        dispatch_semaphore_signal(sem);
    }];
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    return appNotificationRequest;
}

/*********************************************************************************/
#pragma mark - Multiday Tasks
/*********************************************************************************/
- (BOOL) isMultiDayTask {
    NSTimeInterval interval = [self.endOn timeIntervalSinceDate:self.startOn];
    return (interval > (24 * 60 * 60) + 3);
}

- (APCDateRange*) dateRange {
    if (self.startOn == nil || self.endOn == nil) {
        return nil;
    }
    return [[APCDateRange alloc] initWithStartDate:self.startOn endDate:self.endOn];
}

- (void)setDateRange:(APCDateRange *)dateRange {
    self.startOn = dateRange.startDate;
    self.endOn = dateRange.endDate;
}

@end
