//
//  APCHealthKitBackgroundDataCollector.m
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

#import "APCHealthKitBackgroundDataCollector.h"
#import "APCAppCore.h"

static NSString* const kLastUsedTimeKey = @"APCPassiveDataCollectorLastTerminatedTime";

@interface APCHealthKitBackgroundDataCollector()

@property (strong, nonatomic)   HKHealthStore*              healthStore;
@property (strong, nonatomic)   HKUnit*                     unit;
@property (strong, nonatomic)   HKObjectType*               sampleType;
@property (strong, nonatomic)   HKObserverQuery*            observerQuery;
@property (strong, nonatomic)   HKSampleQuery*              sampleQuery;

@end

@implementation APCHealthKitBackgroundDataCollector

- (instancetype)initWithIdentifier:(NSString*)identifier sampleType:(HKObjectType*)type anchorName:(NSString*)anchorName launchDateAnchor:(APCInitialStartDatePredicateDesignator)launchDateAnchor healthStore:(HKHealthStore *)healthStore
{
    self = [super initWithIdentifier:identifier dateAnchorName:anchorName launchDateAnchor:launchDateAnchor];
    
    if (self)
    {
        _sampleType         = type;
        _healthStore        = healthStore;
    }
    
    return self;
}

- (instancetype)initWithQuantityTypeIdentifier:(NSString*)identifier
                                    sampleType:(HKSampleType*)type
                                    anchorName:(NSString*)anchorName
                              launchDateAnchor:(APCInitialStartDatePredicateDesignator)launchDateAnchor
                                   healthStore:(HKHealthStore*)healthStore
                                          unit:(HKUnit*)unit
{
    self = [super initWithIdentifier:identifier dateAnchorName:anchorName launchDateAnchor:launchDateAnchor];
    
    if (self)
    {
        _sampleType         = type;
        _healthStore        = healthStore;
        _unit               = unit;
    }
    
    return self;
}

- (void)start
{
    if (!self.observerQuery)
    {
        [self observerQueryForSampleType:(HKSampleType *)self.sampleType];
        
        NSSet* readTypes = [[NSSet alloc] initWithArray:@[self.sampleType]];
        
        [self.healthStore requestAuthorizationToShareTypes:[NSSet new]
                                                 readTypes:readTypes
                                                completion:nil];
    }
}

- (void)observerQueryForSampleType:(HKSampleType*)sampleType
{
    __weak __typeof(self) weakSelf = self;
    
    self.observerQuery = [[HKObserverQuery alloc] initWithSampleType:sampleType
                                                                 predicate:nil
                                                             updateHandler:^(HKObserverQuery *query,
                                                                             HKObserverQueryCompletionHandler completionHandler,
                                                                             NSError *error)
    {
        if (error)
        {
            APCLogError2(error);
        }
        else
        {
            __typeof(self) strongSelf = weakSelf;

            [strongSelf anchorQuery:query
                  completionHandler:completionHandler];
        }
    }];

    [self.healthStore executeQuery:self.observerQuery];
}

- (void)stop
{
    [self.healthStore stopQuery:self.observerQuery];
}


- (void)anchorQuery:(HKObserverQuery*)query completionHandler:(HKObserverQueryCompletionHandler)completionHandler
{
    HKQueryAnchor*  anchorToUse                         = nil;
    id              backgroundLaunchAnchor              = [[NSUserDefaults standardUserDefaults] objectForKey:self.anchorName];
    NSPredicate*    predicate                           = nil;
    
    if ([backgroundLaunchAnchor isKindOfClass:NSData.class])
    {
        anchorToUse = [NSKeyedUnarchiver unarchivedObjectOfClass:HKQueryAnchor.class fromData:backgroundLaunchAnchor error:NULL];
    }
    //  Support for older versions of the app.
    else if ([backgroundLaunchAnchor isKindOfClass:NSNumber.class])
    {
        anchorToUse = [HKQueryAnchor anchorFromValue:[backgroundLaunchAnchor unsignedIntegerValue]];
    }
    
    __weak __typeof(self)   weakSelf        = self;
    HKAnchoredObjectQuery*  anchorQuery     = [[HKAnchoredObjectQuery alloc] initWithType:(HKSampleType *)query.objectType
                                                                                predicate:predicate
                                                                                   anchor:anchorToUse
                                                                                    limit:HKQueryOptionNone
                                                                           resultsHandler:^(HKAnchoredObjectQuery * _Nonnull __unused query,
                                                                                            NSArray<__kindof HKSample *> * _Nullable sampleObjects,
                                                                                            NSArray<HKDeletedObject *> * _Nullable __unused deletedObjects,
                                                                                            HKQueryAnchor * _Nullable newAnchor,
                                                                                            NSError * _Nullable error)
    {
        if (error)
        {
          APCLogError2(error);
        }
        else
        {
          if (sampleObjects)
          {
              __typeof(self) strongSelf = weakSelf;
              
              if ([sampleObjects lastObject])
              {
                  //  Set the anchor date for the next time the app is alive and send the current results to the data sink.
                  NSData *newAnchorData = [NSKeyedArchiver archivedDataWithRootObject:newAnchor requiringSecureCoding:YES error:NULL];
                  [[NSUserDefaults standardUserDefaults] setObject:newAnchorData forKey:strongSelf.anchorName];
              }
              
              [strongSelf notifyListenersWithResults:sampleObjects withError:error];
          }
        }
        
        if (completionHandler)
        {
            completionHandler();
        }
    }];
    
    [self.healthStore executeQuery:anchorQuery];
    
}

- (void)notifyListenersWithResults:(NSArray*)results withError:(NSError*)error
{
    if (results)
    {
        HKSample *sampleKind = results.firstObject;
        
        if (sampleKind)
        {
            APCLogDebug(@"HK Update received for: %@", sampleKind.sampleType.identifier);
            
            if (self.unit)
            {
                if ([self.delegate respondsToSelector:@selector(didReceiveUpdatedHealthkitSamplesFromCollector:withUnit:)])
                {
                    [self.delegate didReceiveUpdatedHealthkitSamplesFromCollector:results withUnit:self.unit];
                }
            }
            else
            {
                if ([self.delegate respondsToSelector:@selector(didReceiveUpdatedValuesFromCollector:)])
                {
                    [self.delegate didReceiveUpdatedValuesFromCollector:results];
                }
            }
        }
    }
    else
    {
        APCLogError2(error);
    }
}

@end
