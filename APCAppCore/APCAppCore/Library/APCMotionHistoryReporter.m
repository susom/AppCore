// 
//  APCMotionHistoryReporter.m 
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

#import "APCMotionHistoryReporter.h"
#import <CoreMotion/CoreMotion.h>
#import "APCMotionHistoryData.h"
#import "APCConstants.h"
#import "APCAppCore.h"

static NSInteger const kSleepBlocksInSeconds = 10800; // 3 hours

typedef NS_ENUM(NSInteger, MotionActivity)
{
    MotionActivityStationary = 1,
    MotionActivityWalking,
    MotionActivityRunning,
    MotionActivityAutomotive,
    MotionActivityCycling,
    MotionActivityUnknown
};


@interface APCMotionHistoryReporter()
{
    CMMotionActivityManager * motionActivityManager;
    CMMotionManager * motionManager;
    NSMutableArray *motionReport;
    BOOL isTheDataReady;
    
}

@property (nonatomic) __block BOOL isBusy;

@end

@implementation APCMotionHistoryReporter

static APCMotionHistoryReporter __strong *sharedInstance = nil;



+(APCMotionHistoryReporter *) sharedInstance {
    
    //Thread-Safe version
    static dispatch_once_t pred;
    dispatch_once(&pred, ^{
        sharedInstance = [self new];
        
    });
    
    
    return sharedInstance;
}


- (id)init
{
    self = [super init];
    if(self) {
        self->motionActivityManager = [CMMotionActivityManager new];
        self->motionReport = [NSMutableArray new];
        self->isTheDataReady = false;
        
        _isBusy = NO;
        
    }
    
    return self;
}

-(void)startMotionCoProcessorDataFrom:(NSDate *)startDate andEndDate:(NSDate *)endDate andNumberOfDays:(NSInteger)numberOfDays
{
    
    if (!self.isBusy)
    {
        self.isBusy = YES;
        
        //Explicitly set the start date to the zero hour and the end date to the last second of the day.
        NSDate *startDateZeroHour = [startDate startOfDay];
        NSDate *endOfDay = [endDate endOfDay];
        
        [motionReport removeAllObjects];
        isTheDataReady = false;
        
        //zero out.
        //    NSInteger adjustedNumberOfDays = numberOfDays - 1;
        
        NSInteger               numberOfDaysBack = numberOfDays * -1;
        NSDateComponents        *components = [[NSDateComponents alloc] init];
        
        [components setDay:numberOfDaysBack];
        
        NSDate                  *newStartDate = [[NSCalendar currentCalendar] dateByAddingComponents:components
                                                                                              toDate:startDateZeroHour
                                                                                             options:0];
        
        NSInteger               numberOfDaysBackForEndDate = numberOfDays * -1;
        
        NSDateComponents        *endDateComponent = [[NSDateComponents alloc] init];
        [endDateComponent setDay:numberOfDaysBackForEndDate];
        
        NSDate                  *newEndDate = [[NSCalendar currentCalendar] dateByAddingComponents:endDateComponent
                                                                                            toDate:endOfDay
                                                                                           options:0];
        
        [self getMotionCoProcessorDataFrom:newStartDate andEndDate:newEndDate numberOfDays:numberOfDays motionActivityType:0 andAddObjectFlag:NO];
        
    }
}

//iOS is collecting activity data in the background whether you ask for it or not, so this feature will give you activity data even if your application as only been installed very recently.
-(void)getMotionCoProcessorDataFrom:(NSDate *)startDate andEndDate:(NSDate *)endDate numberOfDays:(NSInteger)numberOfDays motionActivityType: (NSInteger)initialMotionActivity andAddObjectFlag: (BOOL)shouldAddObject
{
    
    [motionActivityManager queryActivityStartingFromDate:startDate
                                                  toDate:endDate
                                                 toQueue:[NSOperationQueue new]
                                             withHandler:^(NSArray *activities, NSError * __unused error)
{
    if (numberOfDays >= 0)
    {
        NSDate *lastActivity_started;

        NSTimeInterval totalUnknownTime           = 0.0;

        NSTimeInterval totalVigorousTime          = 0.0;
        NSTimeInterval totalSleepTime             = 0.0;
        NSTimeInterval totalLightActivityTime     = 0.0;
        NSTimeInterval totalSedentaryTime         = 0.0;
        NSTimeInterval totalModerateTime          = 0.0;

        //CMMotionActivity is generated every time the state of motion changes. Assuming this, given two CMMMotionActivity objects you can calculate the duration between the two events thereby determining how long the activity of stationary/walking/running/driving/uknowning was.

        //Setting lastMotionActivityType to 0 from this point on we will use the emum.
        NSInteger lastMotionActivityType = initialMotionActivity;

        NSMutableArray *motionDayValues = [NSMutableArray new];

        for(CMMotionActivity *activity in activities)
        {
            NSTimeInterval activityLengthTime = 0.0;
            activityLengthTime = fabs([lastActivity_started timeIntervalSinceDate:activity.startDate]);
             
             
             
            NSDate *midnight = [[NSCalendar currentCalendar] dateBySettingHour:0
                                                                        minute:0
                                                                        second:0
                                                                        ofDate:endDate
                                                                        options:0];
            
            NSTimeInterval removeThis = 0;
         
            if (![[midnight laterDate:activity.startDate] isEqualToDate:midnight]|| [midnight isEqualToDate:activity.startDate])
            {
                if (![[lastActivity_started laterDate: midnight] isEqualToDate:lastActivity_started] && ![midnight isEqualToDate:lastActivity_started])
                {
                    //Get time interval of the potentially overlapping date
                    removeThis = [midnight timeIntervalSinceDate:lastActivity_started];

                    activityLengthTime = activityLengthTime - removeThis;

                }
             
                //Look for walking moderate and high confidence
                //Cycling any confidence
                //Running any confidence
             
                if((lastMotionActivityType == MotionActivityWalking && activity.confidence == CMMotionActivityConfidenceHigh) || (lastMotionActivityType == MotionActivityWalking && activity.confidence == CMMotionActivityConfidenceMedium))
                {
                    if(activity.confidence == CMMotionActivityConfidenceMedium || activity.confidence == CMMotionActivityConfidenceHigh)
                    {
                        totalModerateTime += activityLengthTime;
                    }
                 
                }
                else if (lastMotionActivityType == MotionActivityRunning || lastMotionActivityType == MotionActivityCycling)
                {
                 
                    totalVigorousTime += activityLengthTime;
                }
            }
         
            if((lastMotionActivityType == MotionActivityWalking && activity.confidence == CMMotionActivityConfidenceHigh) || (lastMotionActivityType == MotionActivityWalking && activity.confidence == CMMotionActivityConfidenceMedium))
            {
                if(activity.confidence == CMMotionActivityConfidenceMedium || activity.confidence == CMMotionActivityConfidenceHigh) // 45 seconds
                {
                    totalModerateTime += fabs([lastActivity_started timeIntervalSinceDate:activity.startDate]);
                }
            }
            else if(lastMotionActivityType == MotionActivityWalking && activity.confidence == CMMotionActivityConfidenceLow)
            {
                totalLightActivityTime += fabs([lastActivity_started timeIntervalSinceDate:activity.startDate]);
            }
            else if(lastMotionActivityType == MotionActivityRunning && activity.confidence == CMMotionActivityConfidenceHigh)
            {
                totalVigorousTime += fabs([lastActivity_started timeIntervalSinceDate:activity.startDate]);
             
            }
            else if(lastMotionActivityType == MotionActivityAutomotive)
            {
                totalSedentaryTime += fabs([lastActivity_started timeIntervalSinceDate:activity.startDate]);
            }
            else if(lastMotionActivityType == MotionActivityCycling && activity.confidence == CMMotionActivityConfidenceHigh)
            {
                totalVigorousTime += fabs([lastActivity_started timeIntervalSinceDate:activity.startDate]);
             
            }
            else if(lastMotionActivityType == MotionActivityStationary)
            {
                 
                //now we need to figure out if its sleep time
                // anything over 3 hours will be sleep time
                NSTimeInterval activityLength = 0.0;

                activityLength = fabs([lastActivity_started timeIntervalSinceDate:activity.startDate]);

                if(activityLength >= kSleepBlocksInSeconds) // 3 hours in seconds
                {
                    totalSleepTime += fabs([lastActivity_started timeIntervalSinceDate:activity.startDate]);
                }
                else
                {
                    totalSedentaryTime += fabs([lastActivity_started timeIntervalSinceDate:activity.startDate]);
                }
            }
            else if(lastMotionActivityType == MotionActivityUnknown)
            {
                if (activity.stationary)
                {
                    totalSedentaryTime += fabs([lastActivity_started timeIntervalSinceDate:activity.startDate]);
                }
                else if (activity.walking && activity.confidence == CMMotionActivityConfidenceLow)
                {
                    totalLightActivityTime += fabs([lastActivity_started timeIntervalSinceDate:activity.startDate]);
                    lastActivity_started = activity.startDate;
                }
                else if (activity.walking)
                {
                    totalModerateTime += fabs([lastActivity_started timeIntervalSinceDate:activity.startDate]);
                    lastActivity_started = activity.startDate;
                }
                else if (activity.running)
                {
                    totalVigorousTime += fabs([lastActivity_started timeIntervalSinceDate:activity.startDate]);
                    lastActivity_started = activity.startDate;
                }

                else if (activity.cycling)
                {
                    totalVigorousTime += fabs([lastActivity_started timeIntervalSinceDate:activity.startDate]);
                    lastActivity_started = activity.startDate;
                }
                else if (activity.automotive)
                {
                    totalSedentaryTime += fabs([lastActivity_started timeIntervalSinceDate:activity.startDate]);
                    lastActivity_started = activity.startDate;
                }
                else
                {
                    totalSedentaryTime += fabs([lastActivity_started timeIntervalSinceDate:activity.startDate]);
                }

                totalUnknownTime += fabs([lastActivity_started timeIntervalSinceDate:activity.startDate]);
            }

            //Configure last motion activity for the next loop and the start dates.
            if (activity.stationary)
            {
                lastMotionActivityType = MotionActivityStationary;
                lastActivity_started = activity.startDate;
            }
            else if (activity.walking)
            {
                lastMotionActivityType = MotionActivityWalking;
                lastActivity_started = activity.startDate;
            }
            else if (activity.walking && activity.confidence == CMMotionActivityConfidenceLow)
            {
                lastMotionActivityType = MotionActivityWalking;
                lastActivity_started = activity.startDate;
            }
            else if (activity.running)
            {
                lastMotionActivityType = MotionActivityRunning;
                lastActivity_started = activity.startDate;
            }
            else if (activity.automotive)
            {
                lastMotionActivityType = MotionActivityAutomotive;
                lastActivity_started = activity.startDate;
            }
            else if (activity.cycling)
            {
                lastMotionActivityType = MotionActivityCycling;
                lastActivity_started = activity.startDate;
            }
            else if (activity.unknown)
            {
                lastMotionActivityType = MotionActivityUnknown;
                lastActivity_started = activity.startDate;
            }
            else
            {
                lastMotionActivityType = MotionActivityStationary;

                if ([activity isEqual:activities[0]])
                {
                    lastActivity_started = startDate;
                }
            }
        }

        if (shouldAddObject)
        {
            APCMotionHistoryData * motionHistoryDataSleeping = [APCMotionHistoryData new];
            motionHistoryDataSleeping.activityType = ActivityTypeSleeping;
            motionHistoryDataSleeping.timeInterval = totalSleepTime;
            [motionDayValues addObject:motionHistoryDataSleeping];
            
            APCMotionHistoryData * motionHistoryDataSedentary = [APCMotionHistoryData new];
            motionHistoryDataSedentary.activityType = ActivityTypeSedentary;
            motionHistoryDataSedentary.timeInterval = totalSedentaryTime;
            [motionDayValues addObject:motionHistoryDataSedentary];
            
            APCMotionHistoryData * motionHistoryDataLight = [APCMotionHistoryData new];
            motionHistoryDataLight.activityType = ActivityTypeLight;
            motionHistoryDataLight.timeInterval = totalLightActivityTime;
            [motionDayValues addObject:motionHistoryDataLight];
            
            APCMotionHistoryData * motionHistoryDataModerate = [APCMotionHistoryData new];
            motionHistoryDataModerate.activityType = ActivityTypeModerate;
            motionHistoryDataModerate.timeInterval = totalModerateTime;
            [motionDayValues addObject:motionHistoryDataModerate];
            
            APCMotionHistoryData * motionHistoryDataVigorous = [APCMotionHistoryData new];
            motionHistoryDataVigorous.activityType = ActivityTypeRunning;
            motionHistoryDataVigorous.timeInterval = totalVigorousTime;
            [motionDayValues addObject:motionHistoryDataVigorous];

            APCMotionHistoryData * motionHistoryDataUnknown = [APCMotionHistoryData new];
            motionHistoryDataUnknown.activityType = ActivityTypeUnknown;
            motionHistoryDataUnknown.timeInterval = totalUnknownTime;
            [motionDayValues addObject:motionHistoryDataUnknown];

            [motionReport addObject:motionDayValues];
        }

        NSDateComponents *firstDateComp = [[NSDateComponents alloc] init];
        [firstDateComp setDay:+1];
        NSDate *newStartDate = [[NSCalendar currentCalendar] dateByAddingComponents:firstDateComp
                                                                             toDate:startDate
                                                                            options:0];

        NSDate *newEndDate = [[NSCalendar currentCalendar] dateByAddingComponents:firstDateComp
                                                                           toDate:endDate
                                                                          options:0];


        [self getMotionCoProcessorDataFrom:newStartDate
                                andEndDate:newEndDate
                              numberOfDays:numberOfDays - 1
                        motionActivityType:lastMotionActivityType
                          andAddObjectFlag:YES];
    }

    if(numberOfDays < 0)
    {
        isTheDataReady = true;

        [[NSNotificationCenter defaultCenter] postNotificationName:APCMotionHistoryReporterDoneNotification object:nil];

        self.isBusy = NO;
    }


    }];
}

-(NSArray*) retrieveMotionReport
{
    //Return the NSMutableArray as an immutable array
    return [motionReport copy];
}

-(BOOL)isDataReady{
    return isTheDataReady;
}

@end
