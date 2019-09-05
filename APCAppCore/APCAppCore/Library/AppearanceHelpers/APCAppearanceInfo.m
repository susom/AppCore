// 
//  APCAppearanceInfo.m 
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
 
#import "APCAppearanceInfo.h"
#import "UIColor+APCAppearance.h"
#import "APCConstants.h"

static NSDictionary * localAppearanceDictionary;

@implementation APCAppearanceInfo

+ (void) setAppearanceDictionary: (NSDictionary*) appearanceDictionary
{
    localAppearanceDictionary = appearanceDictionary;
}

// This is per Parkinson's App
+ (NSDictionary *)defaultAppearanceDictionary
{
    UIColor *secondaryColor1 = [UIColor blackColor];  //#000000
    UIColor *secondaryColor2 = [UIColor colorWithWhite:0.392 alpha:1.000];  //#646464
    UIColor *secondaryColor3 = [UIColor colorWithRed:0.557 green:0.557 blue:0.573 alpha:1.000];  //#8e8e93
    UIColor *secondaryColor4 = [UIColor colorWithWhite:0.973 alpha:1.000];  //#f8f8f8
    UIColor *tertiaryColor1 = [UIColor colorWithRed:0.267 green:0.824 blue:0.306 alpha:1.000];  //#44d24e
    UIColor *tertiaryColor2 = [UIColor blackColor]; //#000000
    UIColor *tertiaryGreenColor = [UIColor colorWithRed:0.195 green:0.830 blue:0.443 alpha:1.000];
    UIColor *tertiaryBlueColor = [UIColor colorWithRed:0.132 green:0.684 blue:0.959 alpha:1.000];
    UIColor *tertiaryRedColor = [UIColor colorWithRed:0.919 green:0.226 blue:0.342 alpha:1.000];
    UIColor *tertiaryYellowColor = [UIColor colorWithRed:0.994 green:0.709 blue:0.278 alpha:1.000];
    UIColor *tertiaryPurpleColor = [UIColor colorWithRed:0.574 green:0.252 blue:0.829 alpha:1.000];
    UIColor *tertiaryGrayColor = [UIColor colorWithRed:157/255.0f green:157/255.0f blue:157/255.0f alpha:1.000];
    UIColor *quaternaryGrayColor = [UIColor colorWithRed:217/255.f green:217/255.f blue:217/255.f alpha:1.f];
    UIColor *borderLineColor = [UIColor colorWithWhite:0.749 alpha:1.000];
    if (@available(iOS 13.0, *)) {
        secondaryColor1 = [UIColor labelColor];
        secondaryColor2 = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            return traitCollection.userInterfaceStyle == UIUserInterfaceStyleLight ? [UIColor colorWithWhite:0.392 alpha:1.000] : [UIColor colorWithWhite:0.962 alpha:1.000];
        }];
        secondaryColor3 = [UIColor systemGrayColor];
        secondaryColor4 = [UIColor groupTableViewBackgroundColor];
        tertiaryColor1 = [UIColor systemGreenColor];
        tertiaryColor2 = [UIColor labelColor];
        tertiaryGreenColor = [UIColor systemGreenColor];
        tertiaryBlueColor = [UIColor systemBlueColor];
        tertiaryRedColor = [UIColor systemRedColor];
        tertiaryYellowColor = [UIColor systemYellowColor];
        tertiaryPurpleColor = [UIColor systemPurpleColor];
        tertiaryGrayColor = [UIColor systemGray2Color];
        quaternaryGrayColor = [UIColor systemGray4Color];
        borderLineColor = [UIColor separatorColor];
    }
    return @{
             //Fonts
             kRegularFontNameKey                : @"HelveticaNeue",
             kMediumFontNameKey                 : @"HelveticaNeue-Medium",
             kLightFontNameKey                  : @"HelveticaNeue-Light",
             
             //Colors
             kPrimaryAppColorKey                : [UIColor colorWithRed:0.176 green:0.706 blue:0.980 alpha:1.000],  //#2db4fa
             
             kSecondaryColor1Key                : secondaryColor1,
             kSecondaryColor2Key                : secondaryColor2,
             kSecondaryColor3Key                : secondaryColor3,
             kSecondaryColor4Key                : secondaryColor4,
             
             kTertiaryColor1Key                 : tertiaryColor1,
             kTertiaryColor2Key                 : tertiaryColor2,
             
             kTertiaryGreenColorKey : tertiaryGreenColor,
             kTertiaryBlueColorKey : tertiaryBlueColor,
             kTertiaryRedColorKey : tertiaryRedColor,
             kTertiaryYellowColorKey : tertiaryYellowColor,
             kTertiaryPurpleColorKey : tertiaryPurpleColor,
             kTertiaryGrayColorKey : tertiaryGrayColor,
             kQuaternaryGrayColorKey : quaternaryGrayColor,
             kBorderLineColor: borderLineColor
             };
}

+ (id)valueForAppearanceKey:(NSString *)key
{
    return localAppearanceDictionary[key] ?: [self defaultAppearanceDictionary][key];
}

@end
