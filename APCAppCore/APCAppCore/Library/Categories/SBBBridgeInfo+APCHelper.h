//
//  SBBBridgeInfo+APCHelper.h
//  APCAppCore
//
//  Created by Paweł Kowalczyk on 27/09/2019.
//  Copyright © 2019 Apple, Inc. All rights reserved.
//

#import <BridgeSDK/BridgeSDK.h>

NS_ASSUME_NONNULL_BEGIN

@interface SBBBridgeInfo (APCHelper)

@property (nonatomic, readonly, copy) NSArray<NSString *>* dataGroups;
@property (nonatomic, readonly, copy) NSString *subpopulationGuid;

@end

NS_ASSUME_NONNULL_END
