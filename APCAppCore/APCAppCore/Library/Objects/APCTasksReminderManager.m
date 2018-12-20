// 
//  APCTasksReminderManager.m 
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
 
#import "APCTasksReminderManager.h"
#import "APCAppDelegate.h"
#import "APCScheduledTask+AddOn.h"
#import "APCResult+AddOn.h"
#import "APCConstants.h"
#import "APCLog.h"
#import "NSDate+Helper.h"
#import "NSDictionary+APCAdditions.h"
#import "NSManagedObject+APCHelper.h"
#import "APCTask.h"
#import "APCTaskGroup.h"
#import "APCScheduler.h"
#import <UIKit/UIKit.h>

NSString* const kDelayPostfix                   = @"Delayed";
NSString* const kTaskReminderUserInfo           = @"CurrentTaskReminder";
NSString* const kSubtaskReminderUserInfo        = @"CurrentSubtaskReminder";
NSString* const kTaskReminderUserInfoKey        = @"TaskReminderUserInfoKey";
NSString* const kSubtaskReminderUserInfoKey     = @"SubtaskReminderUserInfoKey";

static NSInteger kSecondsPerMinute              = 60;
static NSInteger kMinutesPerHour                = 60;
static NSInteger kSubtaskReminderDelayMinutes   = 120;

NSString * const kTaskReminderMessage           = @"Please complete your %@ activities today. Thank you for participating in the %@ study! %@";
NSString * const kTaskReminderDelayMessage      = @"Remind me in 1 hour";

@interface APCTasksReminderManager ()

@property (strong, nonatomic) __block   NSArray*                taskGroups;
@property (strong, nonatomic) __block   NSDate*                 currentDate;
@property (strong, nonatomic)           NSMutableDictionary*    remindersToSend;

@end

@implementation APCTasksReminderManager

- (instancetype)init
{
    self = [super init];

    if (self)
    {
        //posted by APCSettingsViewController on turning reminders on/off
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(checkIfNeedToUpdateTaskReminder) name:APCUpdateTasksReminderNotification object:nil];
        //posted by APCBaseTaskViewController when user completes an activity
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(checkIfNeedToUpdateTaskReminder) name:APCActivityCompletionNotification object:nil];
        
        _reminders          = [NSMutableArray new];
        _remindersToSend    = [NSMutableDictionary new];
    }
    
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

/*********************************************************************************/
#pragma mark - Task Reminder Queue
/*********************************************************************************/

-(void)manageTaskReminder:(APCTaskReminder*)reminder
{
    [self.reminders addObject:reminder];
}

/*********************************************************************************/
#pragma mark - Local Notification Scheduling
/*********************************************************************************/

- (void)updateTaskGroupsInPlaceForDate:(NSDate*)taskGroupDay
{
    NSPredicate*    filterForRequiredTasks = [NSPredicate predicateWithFormat: @"%K == nil || %K == %@",
                                              NSStringFromSelector(@selector(taskIsOptional)),
                                              NSStringFromSelector(@selector(taskIsOptional)),
                                              @(NO)];
    
    [[APCScheduler defaultScheduler] fetchTaskGroupsFromDate: taskGroupDay
                                                      toDate: taskGroupDay
                                      forTasksMatchingFilter: filterForRequiredTasks
                                                  usingQueue: [NSOperationQueue mainQueue]
                                             toReportResults: ^(NSDictionary* taskGroups, NSError* queryError)
     {
         if (!queryError)
         {
             self.taskGroups    = taskGroups [taskGroupDay];
             self.currentDate   = taskGroupDay;

             [self createTaskReminder];
             
             if ( taskGroupDay == [[NSDate date] startOfDay])
             {
                 [self updateTaskGroupsInPlaceForDate:[NSDate tomorrowAtMidnight]];
             }
         }
         else
         {
             APCLogError2(queryError);
         }
     }];
}

- (void) checkIfNeedToUpdateTaskReminder
{
    //  Clear all outdated notifications if they exist to regenerate new ones.
    [self cancelLocalNotificationRequstsIfExist:^{
        if (self.reminderOn) {
            [self updateTaskGroupsInPlaceForDate:[[NSDate date] startOfDay]];
        }
    }];
}

- (void)existingLocalNotificationRequests:(void(^)(NSArray<UNNotificationRequest *> *requests))completionHandler {
    [[UNUserNotificationCenter currentNotificationCenter] getPendingNotificationRequestsWithCompletionHandler:^(NSArray<UNNotificationRequest *> * _Nonnull requests) {
        NSMutableArray *appNotificationRequests = [NSMutableArray new];
        for (UNNotificationRequest *request in requests) {
            NSDictionary *userInfoCurrent = request.content.userInfo;
            if ([userInfoCurrent[kTaskReminderUserInfoKey] isEqualToString:kTaskReminderUserInfo] ||
                [userInfoCurrent[kSubtaskReminderUserInfoKey] isEqualToString:kSubtaskReminderUserInfo]) {
                [appNotificationRequests addObject:request];
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completionHandler) completionHandler(appNotificationRequests);
        });
    }];
}

- (void) cancelLocalNotificationRequstsIfExist:(void(^)(void))completionHandler {
    [self existingLocalNotificationRequests:^(NSArray<UNNotificationRequest *> *requests) {
        if (!requests.count) {
            if (completionHandler) completionHandler();
            return;
        }
        NSArray *identifiers = [requests valueForKey:@"identifier"];
        [[UNUserNotificationCenter currentNotificationCenter] removePendingNotificationRequestsWithIdentifiers:identifiers];
        APCLogDebug(@"Cancelled Notification Requsts with identifiers: %@", identifiers);
        if (completionHandler) completionHandler();
    }];
}

- (void)delayTaskReminder:(UNNotificationRequest *)notificationRequest completion:(void(^)(void))completionHandler
{
    NSDate *date = [NSDate date];
    if ([notificationRequest.trigger isKindOfClass:UNCalendarNotificationTrigger.class]) {
        UNCalendarNotificationTrigger *notificationTrigger = (UNCalendarNotificationTrigger *)notificationRequest.trigger;
        NSDateComponents *components = notificationTrigger.dateComponents;
        date = [[NSCalendar currentCalendar] dateFromComponents:components];
    } else if ([notificationRequest.trigger respondsToSelector:NSSelectorFromString(@"date")]) {
        // UNLegacyNotificationTrigger private class support
        UNNotificationTrigger *trigger = notificationRequest.trigger;
        id triggerDate = [trigger valueForKey:@"date"];
        if ([triggerDate isKindOfClass:NSDate.class]) {
            date = triggerDate;
        };
    }
    date = [date dateByAddingTimeInterval:3600.0];
    unsigned unitFlags = NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond;
    NSDateComponents *dateComponents = [[NSCalendar currentCalendar] components:unitFlags fromDate:date];
    dateComponents.timeZone = [NSTimeZone localTimeZone];
    UNCalendarNotificationTrigger *trigger = [UNCalendarNotificationTrigger triggerWithDateMatchingComponents:dateComponents repeats:NO];
    
    UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:[notificationRequest.identifier stringByAppendingString:kDelayPostfix] content:notificationRequest.content trigger:trigger];
    
    [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable __unused error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completionHandler) completionHandler();
        });
    }];
}

- (void) createTaskReminder
{    
    BOOL    subtaskReminderOnly         = NO;
    int     numOfRemindersToCreate      = [self determineNumberofRemindersToSend];
    
    if (numOfRemindersToCreate > 0)
    {
        if (self.remindersToSend.count > 0 && [self shouldSendSubtaskReminder])
        {
            subtaskReminderOnly = YES;
        }

        NSDate* fireDate                            = subtaskReminderOnly ?   [self calculateSubtaskReminderFireDate] :
                                                                                [self calculateTaskReminderFireDate:self.currentDate];
        
        NSDate* now                                 = [NSDate date];
        
        if ([fireDate isLaterThanDate:now])
        {
            UNMutableNotificationContent *content = [UNMutableNotificationContent new];
            content.body = [self reminderMessage];
            content.sound = UNNotificationSound.defaultSound;
            NSMutableDictionary *notificationInfo = [NSMutableDictionary dictionary];
            notificationInfo[kTaskReminderUserInfoKey] = kTaskReminderUserInfo;//Task Reminder
            content.userInfo = notificationInfo;
            content.categoryIdentifier = kTaskReminderDelayCategory;
            
            unsigned unitFlags = NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond;
            NSDateComponents *components = [[NSCalendar currentCalendar] components:unitFlags fromDate:fireDate];
            components.timeZone = [NSTimeZone localTimeZone];
            NSDate *today = [[NSDate date] startOfDay];
            bool shouldRepeat = self.currentDate != today;
            UNCalendarNotificationTrigger *trigger = [UNCalendarNotificationTrigger triggerWithDateMatchingComponents:components repeats:shouldRepeat];
            
            UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:kTaskReminderUserInfo content:content trigger:trigger];
            
            [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {
                if (error) {
                    APCLogError2(error);
                    return;
                }
                APCLogEventWithData(kSchedulerEvent,
                                (@{@"event_detail": [NSString stringWithFormat:@"Scheduled Reminder: %@. Body: %@",
                                                     request,
                                                     request.content.body]}));
            }];
        }
    }

    //create a subtask reminder if needed
    if ([self shouldSendSubtaskReminder] && !subtaskReminderOnly)
    {
        [self createSubtaskReminder];
    }
}

- (int)determineNumberofRemindersToSend
{
    int count = 0;
    
    for (APCTaskReminder *taskReminder in self.reminders)
    {
        if ([self includeTaskInReminder:taskReminder]) {
            count++;
        }
    }
    
    return count;
}

- (void) createSubtaskReminder {
    
    UNMutableNotificationContent *content = [UNMutableNotificationContent new];
    content.body = [self subtaskReminderMessage];//include only the subtask reminder body
    content.sound = UNNotificationSound.defaultSound;
    NSMutableDictionary *notificationInfo = [NSMutableDictionary dictionary];
    notificationInfo[kSubtaskReminderUserInfoKey] = kSubtaskReminderUserInfo;//Subtask Reminder
    content.userInfo = notificationInfo;
    content.categoryIdentifier = kTaskReminderDelayCategory;
    
    unsigned unitFlags = NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond;
    NSDate *fireDate = [self calculateSubtaskReminderFireDate];//delay by subtask reminder delay
    NSDateComponents *components = [[NSCalendar currentCalendar] components:unitFlags fromDate:fireDate];
    components.timeZone = [NSTimeZone localTimeZone];
    UNCalendarNotificationTrigger *trigger = [UNCalendarNotificationTrigger triggerWithDateMatchingComponents:components repeats:YES];
    
    // Schedule the Subtask notification
    UNNotificationRequest* subtaskReminder = [UNNotificationRequest requestWithIdentifier:kSubtaskReminderUserInfo content:content trigger:trigger];
    
    if (self.remindersToSend.count >0) {
        
        [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:subtaskReminder withCompletionHandler:^(NSError * _Nullable error) {
            if (error) {
                APCLogError2(error);
                return;
            }
            APCLogEventWithData(kSchedulerEvent, (@{@"event_detail":[NSString stringWithFormat:@"Scheduled Subtask Reminder: %@. Body: %@", subtaskReminder, subtaskReminder.content.body]}));
        }];
    }
}


+(NSSet *)taskReminderCategories{
    
    //Add Action for delay reminder
    UNNotificationAction *delayReminderAction = [UNNotificationAction actionWithIdentifier:kDelayReminderIdentifier title:NSLocalizedString(kTaskReminderDelayMessage, nil) options:UNNotificationActionOptionNone];
    
    //Add Category for delay reminder
    UNNotificationCategory *delayCategory = [UNNotificationCategory categoryWithIdentifier:kTaskReminderDelayCategory actions:@[delayReminderAction] intentIdentifiers:@[] options:UNNotificationCategoryOptionNone];
    
    return [NSSet setWithObjects:delayCategory, nil];
    
}

/*********************************************************************************/
#pragma mark - Reminder Parameters
/*********************************************************************************/
-(NSString *)reminderMessage{
    
    NSString *reminders = @"\n";
    //concatenate body of each message with \n
    
    for (APCTaskReminder *taskReminder in self.reminders) {
        if ([self includeTaskInReminder:taskReminder]) {
            reminders = [reminders stringByAppendingString:@"• "];
            reminders = [reminders stringByAppendingString:taskReminder.reminderBody];
            reminders = [reminders stringByAppendingString:@"\n"];
            self.remindersToSend[taskReminder.reminderIdentifier] = taskReminder;
        }else{
            if (self.remindersToSend[taskReminder.reminderIdentifier]) {
                [self.remindersToSend removeObjectForKey:taskReminder.reminderIdentifier];
            }
        }
    }
    
    return [NSString stringWithFormat:kTaskReminderMessage, [self studyName], [self studyName], reminders];
}

-(NSString *)subtaskReminderMessage{
    
    NSString *reminders = @"\n";
    //concatenate body of each message with \n
    
    for (APCTaskReminder *taskReminder in self.reminders) {
        if ([self includeTaskInReminder:taskReminder] && taskReminder.resultsSummaryKey) {
            reminders = [reminders stringByAppendingString:@"• "];
            reminders = [reminders stringByAppendingString:taskReminder.reminderBody];
            reminders = [reminders stringByAppendingString:@"\n"];
            self.remindersToSend[taskReminder.reminderIdentifier] = taskReminder;
        }
    }
    
    return [NSString stringWithFormat:kTaskReminderMessage, [self studyName], [self studyName], reminders];;
}

- (NSString *)studyName {
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"StudyOverview" ofType:@"json"];
    NSString *JSONString = [[NSString alloc] initWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:NULL];
    
    NSError *parseError;
    NSDictionary *jsonDictionary = [NSJSONSerialization JSONObjectWithData:[JSONString dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:&parseError];
    
    if (jsonDictionary) {
        return jsonDictionary[@"disease_name"];
    } else {
        APCLogError2(parseError);
        return @"this study";
    }
}

/*********************************************************************************/
#pragma mark - Reminder Time
/*********************************************************************************/

- (bool)reminderOn {
    __block NSNumber *flag = [[NSUserDefaults standardUserDefaults] objectForKey:kTasksReminderDefaultsOnOffKey];
    //Setting up defaults using initialization options
    
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
        //default to on if user has given Notification permissions
        if (flag == nil) {
            flag = @(settings.authorizationStatus == UNAuthorizationStatusAuthorized);
        }
        //if Notifications are not enabled, set Reminders to off
        else if (settings.authorizationStatus != UNAuthorizationStatusAuthorized) {
            flag = @NO;
        }
        dispatch_semaphore_signal(sem);
    }];
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    [[NSUserDefaults standardUserDefaults] setObject:flag forKey:kTasksReminderDefaultsOnOffKey];
    return [flag boolValue];
}

- (void)setReminderOn:(BOOL)reminderOn
{
    [self updateReminderOn:reminderOn];
    [self checkIfNeedToUpdateTaskReminder];
}

- (void) updateReminderOn: (BOOL) reminderOn
{
    [[NSUserDefaults standardUserDefaults] setObject:@(reminderOn) forKey:kTasksReminderDefaultsOnOffKey];
}

- (NSString *)reminderTime {
    NSString * timeString = [[NSUserDefaults standardUserDefaults] objectForKey:kTasksReminderDefaultsTimeKey];
    if (timeString == nil) {
        APCAppDelegate * delegate = (APCAppDelegate*)[UIApplication sharedApplication].delegate;
        NSString * timeDefault = delegate.initializationOptions[kTaskReminderStartupDefaultTimeKey];
        timeString = timeDefault?:@"5:00 PM";
        [[NSUserDefaults standardUserDefaults] setObject:timeString forKey:kTasksReminderDefaultsTimeKey];
    }
    return timeString;
}

- (void)setReminderTime:(NSString *)reminderTime 
{
    [self updateReminderTime:reminderTime];
    [self checkIfNeedToUpdateTaskReminder];
}

- (void)updateReminderTime:(NSString *)reminderTime
{
    NSAssert([[APCTasksReminderManager reminderTimesArray] containsObject:reminderTime], @"reminder time should be in the reminder times array");
    [[NSUserDefaults standardUserDefaults] setObject:reminderTime forKey:kTasksReminderDefaultsTimeKey];
}

- (NSDate*) calculateTaskReminderFireDate:(NSDate*)date
{
    NSTimeInterval reminderOffset = ([[APCTasksReminderManager reminderTimesArray] indexOfObject:self.reminderTime]) * kMinutesPerHour * kSecondsPerMinute;

    date = [date dateByAddingTimeInterval:reminderOffset];
    
    if ([date isEarlierOrEqualToDate:[NSDate date]])
    {
        date = nil;
    }
    
    return date;
}

- (NSDate*) calculateSubtaskReminderFireDate
{
    NSTimeInterval reminderOffset = ([[APCTasksReminderManager reminderTimesArray] indexOfObject:self.reminderTime]) * kMinutesPerHour * kSecondsPerMinute;
    //add subtask reminder delay
    reminderOffset += kSubtaskReminderDelayMinutes * kSecondsPerMinute;
    
    NSDate* date = [[NSDate todayAtMidnight] dateByAddingTimeInterval:reminderOffset];
    
    if ([date isEarlierOrEqualToDate:[NSDate date]])
    {
        date = nil;
    }
    
    return date;
}

- (BOOL) shouldSendSubtaskReminder{
    
    BOOL shouldSend = NO;
    
    //Send the subtask reminder if self.remindersToSend contains a reminder where taskReminder.resultsSummaryKey != nil
    for (NSString *key in self.remindersToSend) {
        
        APCTaskReminder *reminder = [self.remindersToSend objectForKey:key];
        if (reminder) {
            if (reminder.resultsSummaryKey) {
                shouldSend = YES;
            }
        }
    }
    
    return shouldSend;
}

/*********************************************************************************/
#pragma mark - Helper
/*********************************************************************************/
+ (NSArray*) reminderTimesArray {
    static NSArray * timesArray = nil;
    if (timesArray == nil) {
        timesArray = @[
                       @"Midnight",
                       @"1:00 AM",
                       @"2:00 AM",
                       @"3:00 AM",
                       @"4:00 AM",
                       @"5:00 AM",
                       @"6:00 AM",
                       @"7:00 AM",
                       @"8:00 AM",
                       @"9:00 AM",
                       @"10:00 AM",
                       @"11:00 AM",
                       @"Noon",
                       @"1:00 PM",
                       @"2:00 PM",
                       @"3:00 PM",
                       @"4:00 PM",
                       @"5:00 PM",
                       @"6:00 PM",
                       @"7:00 PM",
                       @"8:00 PM",
                       @"9:00 PM",
                       @"10:00 PM",
                       @"11:00 PM"
                       ];
    }
    return timesArray;
}

/*********************************************************************************/
#pragma mark - Task Reminder Inclusion Model
/*********************************************************************************/
- (BOOL)includeTaskInReminder:(APCTaskReminder*)taskReminder
{
    BOOL includeTask = NO;
    
    //the reminderIdentifier shall be added to NSUserDefaults only when the task reminder is set to ON
    if ([[NSUserDefaults standardUserDefaults] objectForKey: taskReminder.reminderIdentifier])
    {
        APCTaskGroup*   groupForTaskID  = nil;
        NSString*       predicateFormat = @"task.taskID in %@";
        NSArray*        thisDaysNaps    = [self.taskGroups filteredArrayUsingPredicate: [NSPredicate predicateWithFormat:predicateFormat,
                                                                                         [taskReminder taskIdsToMatch]]];
        
        groupForTaskID = (APCTaskGroup*)[thisDaysNaps firstObject];
        
        if (!groupForTaskID)
        {
            includeTask = NO;
        }
        else if (!groupForTaskID.isFullyCompleted)
        {
            //if this task has not been completed but was required, include it in the reminder
            includeTask = YES;
        }
        else if (taskReminder.resultsSummaryKey != nil)
        {
            //we have a completed task with a subtask reminder. Get the results object from task.
            NSArray *allCompletedActivitiesForTaskID = [groupForTaskID.requiredCompletedTasks arrayByAddingObjectsFromArray:groupForTaskID.gratuitousCompletedTasks];
            
            for (APCScheduledTask *subtask in allCompletedActivitiesForTaskID)
            {
                if (subtask.results.count > 0)
                {
                    NSString*       resultSummary    = subtask.lastResult.resultSummary;
                    NSDictionary*   dictionary       = resultSummary ? [NSDictionary dictionaryWithJSONString:resultSummary] : nil;
                    
                    NSString* result = nil;
                    
                    if (dictionary.count > 0)
                    {
                        result = [dictionary objectForKey:taskReminder.resultsSummaryKey];
                    }
                    
                    NSArray*        results          = [[NSArray alloc]initWithObjects:result, nil];
                    NSArray*        completedSubtask = [results filteredArrayUsingPredicate:taskReminder.completedTaskPredicate];
                    
                    if (completedSubtask.count == 0)
                    {
                        includeTask = YES;
                    }
                }
            }
        }
    }
    
    return includeTask;
}

@end
