//
//  SBBDataArchive+APCHelper.h
//  APCAppCore
//
//  Created by Paweł Kowalczyk on 18/09/2019.
//  Copyright © 2019 Stanford Medical, Inc. All rights reserved.
//

#import <BridgeSDK/BridgeSDK.h>

NS_ASSUME_NONNULL_BEGIN

@interface SBBDataArchive (APCHelper)

- (instancetype)initWithReference:(NSString *)reference;
- (void)insertDictionaryIntoArchive:(NSDictionary *)dictionary;
- (void)setSchemaRevision:(NSNumber *)schemaRevision;

@end

NS_ASSUME_NONNULL_END
