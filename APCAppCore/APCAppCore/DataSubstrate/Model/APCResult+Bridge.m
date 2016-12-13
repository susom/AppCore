// 
//  APCResult+Bridge.m 
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
 
#import "APCResult+Bridge.h"
#import "APCAppDelegate.h"
#import "APCLog.h"
#import "NSManagedObject+APCHelper.h"
#import "APCDataEncryptor.h"

#import <BridgeSDK/BridgeSDK.h>


@implementation APCResult (Bridge)

- (BOOL) serverDisabled
{
#if DEVELOPMENT
    return YES;
#else
    return ((APCAppDelegate*)[UIApplication sharedApplication].delegate).dataSubstrate.parameters.bypassServer;
#endif
}

- (void) uploadToBridgeOnCompletion: (void (^)(NSError * error)) completionBlock {
    if ([self serverDisabled]) {
        if (completionBlock) {
            completionBlock(nil);
        }
        return;
    }
    
    NSURL *fileURL = self.archiveURL;
    BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:fileURL.path];
    
    if (!fileExists) {
        if (completionBlock) {
            completionBlock(nil);
        }
        return;
    }
    
    APCLogFilenameBeingUploaded(fileURL.path);

    [[APCDataUploader sharedUploader] uploadFileAtURL:fileURL withCompletion:^(NSError *error) {
        
        if (error) {
            APCLogError2(error);
        } else {
            APCLogEventWithData(kNetworkEvent, (@{@"event_detail":[NSString stringWithFormat:@"Uploaded Task: %@    RunID: %@", self.taskID, self.taskRunID]}));
            
            self.uploaded = @(YES);
            NSError * saveError;
            [self saveToPersistentStore:&saveError];
            
            //Delete archiveURLs
            [self.dataEncryptor removeDirectory];
        }
        
        if (completionBlock) {
            completionBlock(error);
        }
    }];
}

- (APCDataEncryptor *)dataEncryptor {
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:self.taskRunID];
    return [[APCDataEncryptor alloc] initWithUUID:uuid];
}

- (NSURL *)archiveURL {
    NSString *filePath = [self.dataEncryptor encryptedPath];
    return [NSURL fileURLWithPath:filePath];
}

@end
