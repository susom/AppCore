//
//  APCCoreMotionBackgroundDataCollector.m
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

#import "APCCoreMotionBackgroundDataCollector.h"
#import "CMMotionActivity+Helper.h"

static NSString* const kLastUsedTimeKey         = @"APCPassiveDataCollectorLastTerminatedTime";
static NSInteger const kDefaultNumberOfDaysBack = 8;
static NSTimeInterval const kInactivityInterval = 60.0;

@interface APCCoreMotionBackgroundDataCollector()

@property (nonatomic, strong) CMMotionActivityManager *motionActivityManager;
@property (nonatomic, strong, readonly) NSDate *lastTrackedEndDate;

@end

@implementation APCCoreMotionBackgroundDataCollector

/*
*      You can only have one handler installed at a time, calling
*      startActivityUpdatesToQueue:withHandler: replaces the current
*      handler.
*/
- (void)start
{
    if (!self.motionActivityManager)
    {
        self.motionActivityManager = [[CMMotionActivityManager alloc] init];
        
        __weak typeof(self) weakSelf = self;
        
        [self collectActivityStartingFromDate:self.lastTrackedEndDate
                                       toDate:[NSDate date]
                                   completion:^
        {
            __typeof(self) strongSelf = weakSelf;
            
            [strongSelf startLiveActivityUpdates];
        }];
    }
}

- (void)stop
{
    [self.motionActivityManager stopActivityUpdates];
}

/*********************************************************************************/
#pragma mark - Helpers
/*********************************************************************************/

- (void)startLiveActivityUpdates
{
    __weak typeof(self) weakSelf = self;
    
    [self.motionActivityManager startActivityUpdatesToQueue:[NSOperationQueue new] withHandler:^(CMMotionActivity* activity)
    {
        __typeof(self) strongSelf = weakSelf;
        
        // Each time the live motion update takes place,
        // the app gathers and returns historical motion data since lastTrackedEndDate,
        // however only if the lastTrackedEndDate occurred more than 60 seconds ago (kInactivityInterval).
        // The purpose is to get all of the updates that occurred while the app was suspended.
        NSDate *endDate = activity ? [activity.startDate dateByAddingTimeInterval:-1.0] : [NSDate date];
        [strongSelf collectActivityStartingFromDate:strongSelf.lastTrackedEndDate
                                             toDate:endDate
                                         completion:^
        {
            if (activity)
            {
                [strongSelf setLastTrackedEndDate:activity];
                if ([strongSelf.delegate respondsToSelector:@selector(didReceiveUpdatedValueFromCollector:)])
                {
                    [strongSelf.delegate didReceiveUpdatedValueFromCollector:activity];
                }
            }
        }];
    }];
}

- (void)collectActivityStartingFromDate:(NSDate *)start toDate:(NSDate *)end completion:(void (^)(void))completion
{
    if ([[NSDate date] timeIntervalSinceDate:self.lastTrackedEndDate] < kInactivityInterval) {
        if (completion) completion();
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    
    [self.motionActivityManager queryActivityStartingFromDate:start
                                                       toDate:end
                                                      toQueue:[NSOperationQueue new]
                                                  withHandler:^(NSArray* activities, NSError* error)
     {
         __typeof(self) strongSelf = weakSelf;
         
         if (error)
         {
             APCLogError2(error);
         }
         else if (activities)
         {
             if ([strongSelf.delegate respondsToSelector:@selector(didReceiveUpdatedValuesFromCollector:)])
             {
                 [strongSelf.delegate didReceiveUpdatedValuesFromCollector:activities];
             }
             
             if ([activities lastObject])
             {
                 [strongSelf setLastTrackedEndDate:[activities lastObject]];
             }
         }
         if (completion) completion();
     }];
}

- (NSDate *)lastTrackedEndDate
{
    NSDate* lastTrackedEndDate = [[NSUserDefaults standardUserDefaults] objectForKey:self.anchorName];
    
    if (!lastTrackedEndDate)
    {
        lastTrackedEndDate = [self launchDate];
    }
    return lastTrackedEndDate;
}

- (void)setLastTrackedEndDate:(CMMotionActivity *)activity
{
    NSDate*             date        = activity.startDate;
    NSDateComponents*   components  = [[NSCalendar currentCalendar] components:NSCalendarUnitSecond fromDate:date];
    
    [components setSecond:1];
    
    NSDate* futureDate = [[NSCalendar currentCalendar] dateByAddingComponents:components toDate:date options:0];
    
    if (futureDate)
    {
        [[NSUserDefaults standardUserDefaults] setObject:futureDate forKey:self.anchorName];
    }
}

- (NSDate*)maximumNumberOfDaysBack
{
    NSInteger           numberOfDaysBack    = kDefaultNumberOfDaysBack * -1;
    NSDateComponents*   components          = [[NSDateComponents alloc] init];
    
    [components setDay:numberOfDaysBack];

    NSDate*             date                = [[NSCalendar currentCalendar] dateByAddingComponents:components
                                                                                            toDate:[NSDate date]
                                                                                           options:0];
    return date;
}

@end
