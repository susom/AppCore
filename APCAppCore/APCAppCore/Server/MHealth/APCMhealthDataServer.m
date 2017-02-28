// 
//  APCMhealthDataServer.m
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

#import "APCMhealthDataServer.h"
#import "APCAppCore.h"
#import "APCUser+Server.h"
#import "APCDataServer.h"

@interface APCMhealthDataServer () <APCDataServer>

@property (strong, nonatomic) SBBMhealthNetworkManager * networkManager;
@property (strong, nonatomic) SBBAuthManager * authManager;
@property (strong, nonatomic) SBBConsentManager * consentManager;
@property (strong, nonatomic) SBBUploadManager * uploadManager;

@end

@implementation APCMhealthDataServer

- (instancetype)initWithNetworkManager: (SBBMhealthNetworkManager *) networkManager {
    self = [super init];
    if (self) {
        _networkManager = networkManager;
        _authManager = [SBBAuthManager authManagerWithNetworkManager:networkManager];
        _authManager.authDelegate = [APCAppDelegate sharedAppDelegate].dataSubstrate.currentUser;
        
        _consentManager = [SBBConsentManager
                           managerWithAuthManager:_authManager
                           networkManager:networkManager
                           objectManager:[SBBObjectManager objectManager]];
        _uploadManager = [SBBUploadManager
                           managerWithAuthManager:_authManager
                           networkManager:networkManager
                           objectManager:[SBBObjectManager objectManager]];
        _networkManager.backgroundTransferDelegate = (id<NSURLSessionDataDelegate, NSURLSessionDownloadDelegate>) _uploadManager;

        [self restoreBackgroundSession];
    }
    return self;
}

- (void)signUpWithEmail:(NSString *)email
               username:(NSString *)username
               password:(NSString *)password
             completion:(void (^)(NSError *))completionBlock {
    
    if ([self serverDisabled]) {
        if (completionBlock) {
            completionBlock(nil);
        }
    }
    else
    {
        NSParameterAssert(email);
        APCUser *user = [APCAppDelegate sharedAppDelegate].dataSubstrate.currentUser;
        
        password = [user generatePassword];
        
        [self.authManager signUpWithEmail: email
                                 username: username
                                 password: password
                               completion: ^(NSURLSessionDataTask * __unused task,
                                             id __unused responseObject,
                                             NSError *error)
         {
             NSString *newUsername = responseObject[@"username"];
             [[APCAppDelegate sharedAppDelegate].dataSubstrate.currentUser setNewName:newUsername];
             
             dispatch_async(dispatch_get_main_queue(), ^{
                 if (!error) {
                     APCLogEventWithData(kNetworkEvent, (@{@"event_detail":@"User Signed Up"}));
                 }
                 if (completionBlock) {
                     completionBlock(error);
                 }
             });
         }];
    }
}

-(void)signUpWithParameters:(id)params completion:(void (^)(NSError *))completionBlock {
  if ([self serverDisabled]) {
    if (completionBlock) {
      completionBlock(nil);
    }
  }
  else
  {
    NSParameterAssert(params);
  
    
    [self.authManager signUpWithParams:params
                           completion: ^(NSURLSessionDataTask * __unused task,
                                         id __unused responseObject,
                                         NSError *error)
     {
       NSString *newUsername = responseObject[@"username"];
       [[APCAppDelegate sharedAppDelegate].dataSubstrate.currentUser setNewName:newUsername];
       
       dispatch_async(dispatch_get_main_queue(), ^{
         if (!error) {
           APCLogEventWithData(kNetworkEvent, (@{@"event_detail":@"User Signed Up"}));
         }
         if (completionBlock) {
           completionBlock(error);
         }
       });
     }];
  }
}


- (void)signIn:(void (^)(NSError *))completionBlock {
    
    if ([self serverDisabled]) {
        if (completionBlock) {
            completionBlock(nil);
        }
    }
    else
    {
        APCUser *user = [APCAppDelegate sharedAppDelegate].dataSubstrate.currentUser;
        [self.authManager signInWithUsername: user.newName
                                    password: user.password
                                  completion: ^(NSURLSessionDataTask * __unused task,
                                                id responseObject,
                                                NSError *signInError)
         {
             dispatch_async(dispatch_get_main_queue(), ^{
                 if (!signInError) {
                     
                     NSDictionary *responseDictionary = (NSDictionary *) responseObject;
                     if (responseDictionary) {
                         NSNumber *dataSharing = responseDictionary[@"dataSharing"];
                         
                         APCUser *user = [APCAppDelegate sharedAppDelegate].dataSubstrate.currentUser;
                         if (dataSharing.integerValue == 1) {
                             NSString *scope = responseDictionary[@"sharingScope"];
                             if ([scope isEqualToString:@"sponsors_and_partners"]) {
                                 user.sharedOptionSelection = @(SBBConsentShareScopeStudy);
                             } else if ([scope isEqualToString:@"all_qualified_researchers"]) {
                                 user.sharedOptionSelection = @(SBBConsentShareScopeAll);
                             }
                         } else if (dataSharing.integerValue == 0) {
                             user.sharedOptionSelection = @(SBBConsentShareScopeNone);
                         }
                     }
                     APCLogEventWithData(kNetworkEvent, (@{@"event_detail":@"User Signed In"}));
                 }
                 
                 if (completionBlock) {
                     completionBlock(signInError);
                 }
             });
         }];
    }
}

- (void)resendEmailVerification: (NSString*) email completion:(void (^)(NSError *))completionBlock {
    if ([self serverDisabled]) {
        if (completionBlock) {
            completionBlock(nil);
        }
    }
    else
    {
        if (email.length > 0) {
            APCUser *user = [APCAppDelegate sharedAppDelegate].dataSubstrate.currentUser;
            [self.authManager resendMhealthEmailVerification:email
                                                    username:user.newName
                                                    password:user.password
                                                  completion:^(NSURLSessionDataTask * __unused task,
                                                               id __unused responseObject,
                                                               NSError *error)
             {
                 if (!error) {
                     APCLogEventWithData(kNetworkEvent, (@{@"event_detail":@"Bridge Server Aked to resend email verficiation email"}));
                 }
                 if (completionBlock) {
                     completionBlock(error);
                 }
             }];
        }
        else {
            if (completionBlock) {
                completionBlock([NSError errorWithDomain:@"APCAppCoreErrorDomain" code:-100 userInfo:@{NSLocalizedDescriptionKey : @"User email empty"}]);
            }
        }
    }
}

- (void)signOutOnCompletion:(void (^)(NSError *))completionBlock {
    if ([self serverDisabled]) {
        if (completionBlock) {
            completionBlock(nil);
        }
    }
    else
    {
        [self.authManager mhealthWithdrawWithCompletion: ^(NSURLSessionDataTask * __unused task,
                                                               id __unused responseObject,
                                                               NSError *error)
         {
            dispatch_async(dispatch_get_main_queue(), ^{
                APCLogEventWithData(kNetworkEvent, (@{@"event_detail":@"User Signed Out"}));
                if (completionBlock) {
                    completionBlock(error);
                }
            });
        }];
    }
}

- (void)updateProfileOnCompletion:(void (^)(NSError *))completionBlock {
    //MHealth server doesnt support profile information therefore calling completion block immediately
    if (completionBlock) {
        completionBlock(nil);
    }
}

- (void)getProfileOnCompletion:(void (^)(NSError *error))completionBlock {
    //MHealth server doesnt support profile information therefore calling completion block immediately
    if (completionBlock) {
        completionBlock(nil);
    }
}

- (void)sendUserConsentedToBridgeOnCompletion: (void (^)(NSError * error))completionBlock {
    
    if ([self serverDisabled]) {
        if (completionBlock) {
            completionBlock(nil);
        }
    }
    else
    {
        APCUser *user = [APCAppDelegate sharedAppDelegate].dataSubstrate.currentUser;
        NSString * name = user.consentSignatureName.length ? user.consentSignatureName : @"FirstName LastName";
        NSDate * birthDate = user.birthDate ?: [NSDate dateWithTimeIntervalSince1970:(60*60*24*365*10)];
        UIImage *consentImage = [UIImage imageWithData:user.consentSignatureImage];
        
        APCAppDelegate *delegate = (APCAppDelegate*) [UIApplication sharedApplication].delegate;
        NSNumber *selected = delegate.dataSubstrate.currentUser.sharedOptionSelection;
        
        [self.consentManager mHealthConsentSignature:name
                                                birthdate: [birthDate startOfDay]
                                           signatureImage:consentImage
                                                dataSharing:[selected integerValue]
                                               completion:^(id __unused responseObject, NSError * __unused error) {
                                                   dispatch_async(dispatch_get_main_queue(), ^{
                                                       if (!error) {
                                                           APCLogEventWithData(kNetworkEvent, (@{@"event_detail":@"User Consent Sent To Bridge"}));
                                                       }
                                                       
                                                       if (completionBlock) {
                                                           completionBlock(error);
                                                       }
                                                   });
                                               }];
    }
    
}

- (void)sendUserConsentedToBridgeWithParams:(id)params completion:(void (^)(NSError *))completionBlock {
  
  if ([self serverDisabled]) {
    if (completionBlock) {
      completionBlock(nil);
    }
  }
  else
  {
    [self.consentManager mHealthConsentSignatureWithParams:params completion:^(id __unused responseObject, __unused NSError *error) {
      dispatch_async(dispatch_get_main_queue(), ^{
        if (!error) {
          APCLogEventWithData(kNetworkEvent, (@{@"event_detail":@"User Consent Sent To Bridge"}));
        }
        
        if (completionBlock) {
          completionBlock(error);
        }
      });
    }];
  }
}

- (void)retrieveConsentOnCompletion:(void (^)(NSError *))completionBlock {
    if ([self serverDisabled]) {
        if (completionBlock) {
            completionBlock(nil);
        }
    }
    else
    {
        [self.consentManager retrieveConsentSignatureWithCompletion: ^(NSString*          name,
                                                                                   NSString* __unused birthdate,
                                                                                   UIImage*           signatureImage,
                                                                                   NSError*           error)
		 {
            if (error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completionBlock) {
                        completionBlock(error);
                    }
                });
            } else {
                APCUser *user = [APCAppDelegate sharedAppDelegate].dataSubstrate.currentUser;
                user.consentSignatureName = name;
                user.consentSignatureImage = UIImagePNGRepresentation(signatureImage);
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (!error) {
                        APCLogEventWithData(kNetworkEvent, (@{@"event_detail":@"User Consent Signature Received From Bridge"}));
                    }
                    
                    if (completionBlock) {
                        completionBlock(error);
                    }
                });
            }
        }];
    }
}

- (void) withdrawStudyOnCompletion:(void (^)(NSError *))completionBlock
{
    if ([self serverDisabled]) {
        if (completionBlock) {
            completionBlock(nil);
        }
    }
    else
    {
        [self.consentManager mHealthDataSharing:SBBConsentShareScopeNone completion:^(id __unused responseObject, NSError * __unused error) {
            [self signOutOnCompletion:^(NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if(!error) {
                        [APCAppDelegate sharedAppDelegate].dataSubstrate.currentUser.consented = NO;
                        APCLogEventWithData(kNetworkEvent, (@{@"event_detail":@"User Suspended Consent"}));
                    }
                    if (completionBlock) {
                        completionBlock(error);
                    }
                });
            }];
        }];
    }
}

- (void) resumeStudyOnCompletion:(void (^)(NSError *))completionBlock
{
    if ([self serverDisabled]) {
        if (completionBlock) {
            completionBlock(nil);
        }
    }
    else
    {
        APCAppDelegate *delegate = (APCAppDelegate*) [UIApplication sharedApplication].delegate;
        NSNumber *selected = delegate.dataSubstrate.currentUser.sharedOptionSelection;
        
        [self.consentManager mHealthDataSharing:[selected integerValue] completion:^(id __unused responseObject, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!error) {
                    APCLogEventWithData(kNetworkEvent, (@{@"event_detail":@"User Resumed Consent"}));
                }
                if (completionBlock) {
                    completionBlock(error);
                }
            });
        }];
    }
}

- (void) resendEmailVerificationOnCompletion:(void (^)(NSError *))completionBlock
{
    if ([self serverDisabled]) {
        if (completionBlock) {
            completionBlock(nil);
        }
    }
    else
    {
        APCUser *user = [APCAppDelegate sharedAppDelegate].dataSubstrate.currentUser;
        if (user.email.length > 0) {
            [self.authManager resendMhealthEmailVerification:user.email username:user.newName password:user.password completion: ^(NSURLSessionDataTask * __unused task,
                                                                                           id __unused responseObject,
                                                                                           NSError *error)
			 {
                if (!error) {
                     APCLogEventWithData(kNetworkEvent, (@{@"event_detail":@"Bridge Server Aked to resend email verficiation email"}));
                }
                if (completionBlock) {
                    completionBlock(error);
                }
            }];
        }
        else {
            if (completionBlock) {
                completionBlock([NSError errorWithDomain:@"APCAppCoreErrorDomain" code:-100 userInfo:@{NSLocalizedDescriptionKey : @"User email empty"}]);
            }
        }
    }
}

- (void) changeDataSharingTypeOnCompletion:(void (^)(NSError *))completionBlock {
    NSNumber *selected = [APCAppDelegate sharedAppDelegate].dataSubstrate.currentUser.sharedOptionSelection;
    
    [self.consentManager mHealthDataSharing:[selected integerValue]
                                 completion:^(id __unused responseObject, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!error) {
                switch (selected.integerValue) {
                    case 0:
                    {
                        APCLogEventWithData(kNetworkEvent, (@{@"event_detail":@"Data Sharing disabled"}));
                    }
                        break;
                    case 1:
                    {
                        APCLogEventWithData(kNetworkEvent, (@{@"event_detail":@"Data Sharing with Institute only"}));
                    }
                        break;
                    case 2:
                    {
                        APCLogEventWithData(kNetworkEvent, (@{@"event_detail":@"Data Sharing with all"}));
                    }
                        break;
                        
                    default:
                        break;
                }
            }
            if (completionBlock) {
                completionBlock(error);
            }
        });
    }];
}

- (void)ensureSignedIn:(void (^)(NSError *))completionBlock {
    [self.authManager ensureSignedInWithCompletion:^(NSURLSessionDataTask __unused *task, id __unused responseObject, NSError __unused *error) {
      APCLogError2 (error);
      if( completionBlock ) {
        completionBlock(error);
      }
    }];
}

- (void)uploadFileToServer:(NSURL *)fileUrl contentType:(NSString *)contentType completion:(void (^)(NSError *))completion {
    [self.uploadManager uploadFileToBridge:fileUrl
                               contentType:contentType
                                completion:completion];
}

- (void)requestPasswordResetForEmail:(NSString *) __unused email completion:(void (^)(NSError *))completion {
    //MHealth server doesnt support password reset
    if (completion) {
        completion(nil);
    }
}

- (NSString *)serverCertificate {
    APCAppDelegate *appDelegate = [APCAppDelegate sharedAppDelegate];
    return ([appDelegate.initializationOptions[kBridgeEnvironmentKey] integerValue] == SBBEnvironmentStaging) ? [appDelegate.initializationOptions[kAppPrefixKey] stringByAppendingString:@"-mhealth-staging"] :[appDelegate.initializationOptions[kAppPrefixKey] stringByAppendingString:@"-mhealth"];
}

- (void)restoreBackgroundSession
{
    [self.networkManager restoreBackgroundSession:kStanfordBackgroundSessionIdentifier completionHandler:nil];
}

- (BOOL) serverDisabled {
#if DEVELOPMENT
    return YES;
#else
    return ((APCAppDelegate*)[UIApplication sharedApplication].delegate).dataSubstrate.parameters.bypassServer;
#endif
}
@end
