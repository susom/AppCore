//
//  NSURL+APCHelper.m
//  APCAppCore
//
//  Created by Paweł Kowalczyk on 21.09.2018.
//  Copyright © 2018 Apple, Inc. All rights reserved.
//

#import "NSURL+APCHelper.h"

@implementation NSURL (APCHelper)

+ (NSURL *)randomBaseURL
{
    return [NSURL URLWithString:[NSString stringWithFormat:@"http://researchkit.%@/", [[NSUUID UUID] UUIDString]]];
}

@end
