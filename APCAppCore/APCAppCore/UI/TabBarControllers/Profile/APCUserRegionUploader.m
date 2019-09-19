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
#import "APCLog.h"
#import "SBBDataArchive+APCHelper.h"

static       NSString* kUploadID            = @"regionInformation";
static const NSString* kCountryCode         = @"countryCode";
static       NSString* kAPHCountryCode      = @"APHCountryCode";

@implementation APCUserRegionUploader

- (void)startAndUploadWhenReady
{
    [self createValuesAndUploadCountry];
}

- (void)createValuesAndUploadCountry
{
    APCLogDebug(@"Create region values");
    
    NSMutableDictionary*    regionInformation   = [NSMutableDictionary new];
    NSString*               countryCode         = [[NSLocale currentLocale] objectForKey:NSLocaleCountryCode];
    
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
        SBBDataArchive*          archive         = [[SBBDataArchive alloc] initWithReference:kUploadID];
       
        [archive insertDictionaryIntoArchive:regionInformation filename:kUploadID createdOn:[NSDate date]];
        
        [archive encryptAndUploadArchiveWithCompletion:^(NSError * _Nullable error) {
            if (! error)
            {
                NSString* countryCode   = [regionInformation objectForKey:kCountryCode];
                
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
    BOOL        upload              = NO;
    NSString*   countryCode         = [regionInformation objectForKey:kCountryCode];
    NSString*   lastCountryCode     = [[NSUserDefaults standardUserDefaults] objectForKey:kAPHCountryCode];
    
    if (![countryCode isEqualToString:lastCountryCode])
    {
        upload = YES;
    }
    
    return upload;
}

@end
