//
//  SBBBridgeInfo+APCHelper.m
//  APCAppCore
//
//  Created by Paweł Kowalczyk on 27/09/2019.
//  Copyright © 2019 Apple, Inc. All rights reserved.
//

#import "SBBBridgeInfo+APCHelper.h"

@interface SBBBridgeInfo()

+ (NSMutableDictionary *)dictionaryFromDefaultPlists;

@end


@implementation SBBBridgeInfo (APCHelper)

- (id)plistValueForKey:(NSString *)key
{
    NSDictionary *plistDict = [SBBBridgeInfo dictionaryFromDefaultPlists];
    NSString *languageSpecificKey = [NSString stringWithFormat:@"%@-%@", key, NSLocale.currentLocale.countryCode];
    return plistDict[languageSpecificKey] ? plistDict[languageSpecificKey] : plistDict[key];
}

- (NSArray<NSString *> *)dataGroups
{
    return [self plistValueForKey:NSStringFromSelector(@selector(dataGroups))];
}

- (NSString *)subpopulationGuid
{
    NSString *guid = [self plistValueForKey:NSStringFromSelector(@selector(subpopulationGuid))];
    return guid ? guid : self.studyIdentifier;
}

@end
