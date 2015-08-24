//
// APCUserRegionUploader.m
// APCAppCore
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

#import "APCUserRegionUploader.h"
#import <CoreLocation/CoreLocation.h>
#import "APCLog.h"
#import "APCDataArchive.h"
#import "APCDataArchiveUploader.h"

static       NSString* kUploadID            = @"regionInformation";
static const NSString* kAdminArea           = @"adminArea";
static const NSString* kCountry             = @"country";
static const NSString* kCountryCode         = @"countryCode";
static       NSString* kAPHAdminArea        = @"APHAdminArea";
static       NSString* kAPHCountry          = @"APHCountry";
static       NSString* kAPHCountryCode      = @"APHCountryCode";
static const NSString* kRegionInformation   = @"regionInformation";
static const NSString* kMeasurementSystem   = @"measurementSystem";
static const NSString* kLanguageCode        = @"languageCode";
static const NSString* kGroupingSeparator   = @"groupingSeparator";
static const NSString* kDecimalSeparator    = @"decimalSeparator";
static const NSString* kLocaleCalendar      = @"localeCalendar";
static const float     kDesiredHorizAccur   = 40.0;

@interface APCUserRegionUploader() <CLLocationManagerDelegate>

@property (strong, nonatomic) CLLocationManager *locationManager;

@end

@implementation APCUserRegionUploader

- (void)startAndUploadWhenReady
{
    if ([CLLocationManager locationServicesEnabled])
    {
        if (!self.locationManager)
        {
            APCLogDebug(@"Start country tracking");
            
            self.locationManager            = [[CLLocationManager alloc] init];
            self.locationManager.delegate   = self;
            
            if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusAuthorizedWhenInUse || [CLLocationManager authorizationStatus] == kCLAuthorizationStatusAuthorizedAlways)
            {
                [self.locationManager startUpdatingLocation];
            }
        }
    }
    else
    {
        [self createValuesAndUploadCountry:nil administrativeArea:nil];
    }
}

- (void)stop
{
    if ([CLLocationManager locationServicesEnabled])
    {
        [self.locationManager stopUpdatingLocation];
    }
}

/*********************************************************************************/
#pragma mark -CLLocationManagerDelegate
/*********************************************************************************/

- (void)locationManager:(CLLocationManager*)manager didFailWithError:(NSError*)error
{
    APCLogError2(error);
    
    switch(error.code)
    {
        case kCLErrorNetwork:
        {
            APCLogDebug(@"APCUserRegionUploader: Possible network connection issue (eg, in airplane mode)");
            break;
        }
        
        case kCLErrorDenied:
        {
            APCLogDebug(@"APCUserRegionUploader: The user has denied use of location");
            [manager stopUpdatingLocation];
        
            break;
        }
        
        default:
        {
            APCLogDebug(@"APCUserRegionUploader: Unknown error");
            break;
        }
    }
}

- (void)locationManager:(CLLocationManager*)manager didUpdateLocations:(NSArray*) __unused locations
{
    APCLogDebug(@"locationManager didUpdateLocations at %@", [NSDate date]);
    
    CLGeocoder*         geocoder = [[CLGeocoder alloc] init];
    __weak typeof(self) weakSelf = self;
    
    if (manager.location.horizontalAccuracy > 0 && manager.location.horizontalAccuracy < kDesiredHorizAccur)
    {
        [self stop];
        
        [geocoder reverseGeocodeLocation:manager.location
                       completionHandler:^(NSArray* placemarks, NSError* error)
         {
             APCLogDebug(@"reverseGeocodeLocation:completionHandler: Completion Handler called!");
             
             if (placemarks == nil)
             {
                 if (error)
                 {
                     APCLogError2(error);
                 }
             }
             else if(placemarks && placemarks.count > 0)
             {
                 CLPlacemark*           topResult   = [placemarks firstObject];
                 __strong typeof(self)  strongSelf  = weakSelf;
                 
                 [strongSelf createValuesAndUploadCountry:[topResult country] administrativeArea:[topResult administrativeArea]];
             }
         }];
    }
}
        
- (void)createValuesAndUploadCountry:(NSString*)country administrativeArea:(NSString*)adminArea
{
    APCLogDebug(@"Create region values");
    
    NSMutableDictionary*    regionInformation   = [NSMutableDictionary new];
    NSString*               countryCode         = [[NSLocale currentLocale] objectForKey:NSLocaleCountryCode];

    if (adminArea)
    {
        [regionInformation addEntriesFromDictionary:@{ kAdminArea         : adminArea}];
    }
    
    if (country)
    {
        [regionInformation addEntriesFromDictionary:@{ kCountry           : country}];
    }
    
    if (countryCode)
    {
        [regionInformation addEntriesFromDictionary:@{ kCountryCode       : countryCode}];
    }
    
    if ([self determineIfUploadNecessary:regionInformation])
    {
        [self upload:regionInformation];
    }
}

- (void)upload:(NSMutableDictionary*)regionInformation
{
    APCLogDebug(@"Archive and upload region values");

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^
    {
        APCDataArchive*          archive         = [[APCDataArchive alloc] initWithReference:kUploadID];
       
        [archive insertIntoArchive:regionInformation filename:kUploadID];
       
        APCDataArchiveUploader*  archiveUploader = [[APCDataArchiveUploader alloc] init];
       
        [archiveUploader encryptAndUploadArchive:archive withCompletion:^(NSError *error)
        {
            if (! error)
            {
                NSString* country       = [regionInformation objectForKey:kCountry];
                NSString* adminArea     = [regionInformation objectForKey:kAdminArea];
                NSString* countryCode   = [regionInformation objectForKey:kCountryCode];

                if (country)
                {
                    [[NSUserDefaults standardUserDefaults] setObject:country        forKey:kAPHCountry];
                }
                
                if (adminArea)
                {
                    [[NSUserDefaults standardUserDefaults] setObject:adminArea      forKey:kAPHAdminArea];
                }
                
                if (countryCode)
                {
                    [[NSUserDefaults standardUserDefaults] setObject:countryCode    forKey:kAPHCountryCode];
                }
            }
        }];
    });
}

- (BOOL)determineIfUploadNecessary:(NSMutableDictionary*)regionInformation
{
    BOOL upload = NO;
    
    NSString* country           = [regionInformation objectForKey:kCountry];
    NSString* adminArea         = [regionInformation objectForKey:kAdminArea];
    NSString* countryCode       = [regionInformation objectForKey:kCountryCode];
    
    NSString* lastCountry       = [[NSUserDefaults standardUserDefaults] objectForKey:kAPHCountry];
    NSString* lastAdminArea     = [[NSUserDefaults standardUserDefaults] objectForKey:kAPHAdminArea];
    NSString* lastCountryCode   = [[NSUserDefaults standardUserDefaults] objectForKey:kAPHCountryCode];
    
    if ([CLLocationManager locationServicesEnabled])
    {
        if (country != lastCountry || adminArea != lastAdminArea)
        {
            upload = YES;
        }
    }
    
    if (countryCode != lastCountryCode)
    {
        upload = YES;
    }
    
    return upload;
}

@end
