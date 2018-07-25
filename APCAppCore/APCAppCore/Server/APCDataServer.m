// 
//  APCDataServer.m
//  APCAppCore 
// 
// Copyright (c) 2016, Apple Inc. All rights reserved. 
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

#import "APCDataServer.h"
#import "APCAppDelegate.h"
#import "APCBridgeDataServer.h"
#import "APCMhealthDataServer.h"
#import <BridgeSDK/BridgeSDK.h>



NSString *kBridgeServerKey = @"Bridge";
NSString *kMhealthServerKey = @"MHealth";
NSString *kDataServerKey = @"DataServer";



static id<APCDataServer> dataServer = nil;
static dispatch_once_t onceToken;



@implementation APCDataServerManager

+ (id<APCDataServer>)currentServer {

    dispatch_once(&onceToken, ^{
        if ([self isMhealthServer]) {
            dataServer = [self createMhealthServer];
            NSLog(@"USE mhealth create");
        } else {
            dataServer = [self createBridgeServer];
            NSLog(@"USE bridge create");
        }
    });

    return dataServer;
}

+ (BOOL)isMhealthServer {
    return [[self serverString] isEqualToString:kMhealthServerKey];
}

+ (BOOL)isServerUsed {
    return dataServer != nil;
}



#pragma mark - Change server

+ (void)useBridgeServer {
    [self setServerString:kBridgeServerKey];
}

+ (void)useMhealthServer {
    [self setServerString:kMhealthServerKey];
}



#pragma mark - Persistence

+ (NSString *)serverString {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults synchronize];
    return [defaults stringForKey:kDataServerKey];
}

+ (void)setServerString:(NSString *)server {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:server forKey:kDataServerKey];
    [defaults synchronize];
}



#pragma mark - Construction

+ (id<APCDataServer>)createMhealthServer {
    APCMhealthDataServer *dataServer = [[APCMhealthDataServer alloc] initWithNetworkManager:SBBComponent(SBBMhealthNetworkManager)];
    return dataServer;
}

+ (id<APCDataServer>)createBridgeServer {
    return (id<APCDataServer>)[[APCBridgeDataServer alloc] init];
}

@end
