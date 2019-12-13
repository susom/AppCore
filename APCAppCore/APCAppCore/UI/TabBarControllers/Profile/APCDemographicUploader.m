//
//  APCDemographicUploader.m
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

#import "APCDemographicUploader.h"
#import "APCAllSetTableViewCell.h"
#import "NSDate+Helper.h"
#import "APCAppDelegate.h"
#import "SBBDataArchive+APCHelper.h"

static  NSInteger const kTaskSchemaRevision        = 3;
static  NSString  *kTaskIdentifierKey              = @"NonIdentifiableDemographicsTask";
static  NSString  *kFileIdentifierKey              = @"NonIdentifiableDemographics";
static  NSString  *kPatientInformationKey          = @"item";
static  NSString  *kPatientCurrentAgeKey           = @"patientCurrentAge";
static  NSString  *kPatientBiologicalSexKey        = @"patientBiologicalSex";
static  NSString  *kPatientBloodTypeKey            = @"patientBloodType";
static  NSString  *kPatientFitzpatrickSkinTypeKey  = @"patientFitzpatrickSkinType";
static  NSString  *kPatientHeightInchesKey         = @"patientHeightInches";
static  NSString  *kPatientWeightPoundsKey         = @"patientWeightPounds";
static  NSString  *kPatientWakeUpTimeKey           = @"patientWakeUpTime";
static  NSString  *kPatientGoSleepTimeKey          = @"patientGoSleepTime";

@interface APCDemographicUploader ( )

@property (nonatomic, strong) APCUser *user;

@end

@implementation APCDemographicUploader

- (instancetype)initWithUser:(APCUser *)user
{
    self = [super init];
    if (self != nil) {
        _user = user;
        
    }
    return  self;
}

- (void)uploadNonIdentifiableDemographicData
{
    NSMutableDictionary  *demographics = [NSMutableDictionary dictionary];
    
    demographics[kPatientInformationKey] = kFileIdentifierKey;
    
    NSDate  *sleepTime = self.user.sleepTime;
    demographics[kPatientGoSleepTimeKey] = (sleepTime != nil) ? [sleepTime ISO8601String] : [NSNull null];
    
    NSDate  *wakeUpTime = self.user.wakeUpTime;
    demographics[kPatientWakeUpTimeKey] = (wakeUpTime != nil) ? [wakeUpTime ISO8601String] : [NSNull null];
    
    NSDate  *birthDate = self.user.birthDate;
    if (birthDate == nil) {
        demographics[kPatientCurrentAgeKey] = [NSNull null];
    } else {
        NSUInteger  age = [NSDate ageFromDateOfBirth:birthDate];
        demographics[kPatientCurrentAgeKey] = [NSNumber numberWithUnsignedInteger:age];
    }
    
    HKBiologicalSex  biologicalSex = self.user.biologicalSex;
    NSString  *biologicalSexString = [APCUser stringValueFromSexType:biologicalSex];
    demographics[kPatientBiologicalSexKey] = (biologicalSexString != nil) ? biologicalSexString : [NSNull null];
    
    HKBloodType bloodType = self.user.bloodType;
    NSString  *bloodTypeString = [APCUser stringValueFromBloodType:bloodType];
    demographics[kPatientBloodTypeKey] = (bloodTypeString != nil) ? bloodTypeString : [NSNull null];
    
    HKFitzpatrickSkinType fitzpatrickSkinType = self.user.fitzpatrickSkinType;
    NSString  *fitzpatrickSkinTypeString = [APCUser stringValueFromFitzpatrickSkinType:fitzpatrickSkinType];
    demographics[kPatientFitzpatrickSkinTypeKey] = (fitzpatrickSkinTypeString != nil) ? fitzpatrickSkinTypeString : [NSNull null];
    
    HKQuantity  *height = self.user.height;
    double  heightInInches = [APCUser heightInInches:height];
    int  klass = fpclassify(heightInInches);
    if ((klass == FP_INFINITE) || (klass == FP_NAN) || (klass == FP_ZERO)) {
        demographics[kPatientHeightInchesKey] = @(0);
    } else {
        demographics[kPatientHeightInchesKey] = @(heightInInches);
    }
    
    HKQuantity  *weight = self.user.weight;
    double  weightInPounds = [APCUser weightInPounds:weight];
    int  klarse = fpclassify(weightInPounds);
    if ((klarse == FP_INFINITE) || (klass == FP_NAN) || (klass == FP_ZERO)) {
        demographics[kPatientWeightPoundsKey] = @(0);
    } else {
        demographics[kPatientWeightPoundsKey] = @(weightInPounds);
    }
    
    //Archive and upload
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
        SBBDataArchive *archive = [[SBBDataArchive alloc] initWithReference:kTaskIdentifierKey];
        [archive setSchemaRevision:@(kTaskSchemaRevision)];
        [archive insertDictionaryIntoArchive:demographics filename:kFileIdentifierKey createdOn:[NSDate date]];
        [archive encryptAndUploadArchiveWithCompletion:^(NSError * _Nullable error) {
            if (! error) {
                [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kAnonDemographicDataUploadedKey];
            }
        }];
    });
}

@end
