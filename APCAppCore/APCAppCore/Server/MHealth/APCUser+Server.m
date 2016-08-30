// 
//  APCUser+Server.m
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

#import "APCUser+Server.h"
#import "APCAppCore.h"
#import "APCDataServer.h"

static NSString *const kNewNamePropertytName = @"newName";

@implementation APCUser (Server)

- (BOOL) serverDisabled
{
#if DEVELOPMENT
    return YES;
#else
    return ((APCAppDelegate*)[UIApplication sharedApplication].delegate).dataSubstrate.parameters.bypassServer;
#endif
}

- (NSString *)newName
{
    return [APCKeychainStore stringForKey:kNewNamePropertytName] ?: @"";
}

- (void)setNewName:(NSString *)newName
{
    if (newName != nil) {
        [APCKeychainStore setString:newName forKey:kNewNamePropertytName];
    }
    else {
        [APCKeychainStore removeValueForKey:kNewNamePropertytName];
    }
}


- (NSString * )generatePassword {
    int32_t randomNumber = 0;
    int32_t anotherRndNum = 0;
    int32_t another1RndNum = 0;
    int32_t another2RndNum = 0;
    SecRandomCopyBytes(kSecRandomDefault, 4, (uint8_t*) &randomNumber);
    SecRandomCopyBytes(kSecRandomDefault, 4, (uint8_t*) &anotherRndNum);
    SecRandomCopyBytes(kSecRandomDefault, 4, (uint8_t*) &another1RndNum);
    SecRandomCopyBytes(kSecRandomDefault, 4, (uint8_t*) &another2RndNum);
    NSString* password1 = [NSString stringWithFormat:@"%d", abs(randomNumber)];
    NSString* password2 = [NSString stringWithFormat:@"%d", abs(anotherRndNum)];
    NSString* password3 = [NSString stringWithFormat:@"%d", abs(another1RndNum)];
    NSString* password4 = [NSString stringWithFormat:@"%d", abs(another2RndNum)];
    NSString* password = [NSString stringWithFormat:@"%@%@%@%@", password1,password2,password3,password4];
    if(password.length>32)
        password = [password substringToIndex:32];
    if(password.length<32)
        password = [password stringByPaddingToLength:32
                                          withString:@"0"
                                     startingAtIndex: password.length];
    [self setPassword : password];
    return password;
    
}

- (void)signUpOnCompletion:(void (^)(NSError *))completionBlock
{
    
    [[APCDataServerManager currentServer] signUpWithEmail:self.email
                                                 username:self.email
                                                 password:self.password
                                               completion:completionBlock];
}

- (void)signInOnCompletion:(void (^)(NSError *))completionBlock
{
    
    [[APCDataServerManager currentServer] signIn:completionBlock];
    
}

- (void)resendEmailVerificationOnCompletion:(void (^)(NSError *))completionBlock
{
    [[APCDataServerManager currentServer] resendEmailVerification:self.email
                                                       completion:completionBlock];
}

- (void)signOutOnCompletion:(void (^)(NSError *))completionBlock
{
    [[APCDataServerManager currentServer] signOutOnCompletion:completionBlock];
}

- (void)updateProfileOnCompletion:(void (^)(NSError * error))completionBlock {
    [[APCDataServerManager currentServer] updateProfileOnCompletion:completionBlock];
}

- (void)getProfileOnCompletion:(void (^)(NSError *error))completionBlock {
    [[APCDataServerManager currentServer] getProfileOnCompletion:completionBlock];
}

- (void)sendUserConsentedToBridgeOnCompletion: (void (^)(NSError * error))completionBlock {
    [[APCDataServerManager currentServer] sendUserConsentedToBridgeOnCompletion:completionBlock];
}

- (void)retrieveConsentOnCompletion:(void (^)(NSError *error))completionBlock {
    [[APCDataServerManager currentServer] retrieveConsentOnCompletion:completionBlock];
}

- (void)withdrawStudyOnCompletion:(void (^)(NSError *))completionBlock
{
    [[APCDataServerManager currentServer] withdrawStudyOnCompletion:completionBlock];
}

- (void)resumeStudyOnCompletion:(void (^)(NSError *error))completionBlock {
    [[APCDataServerManager currentServer] resumeStudyOnCompletion:completionBlock];
}

- (void)changeDataSharingTypeOnCompletion:(void (^)(NSError *))completionBlock {
    [[APCDataServerManager currentServer] changeDataSharingTypeOnCompletion:completionBlock];
}

/*********************************************************************************/
#pragma mark - Authmanager Delegate Protocol
/*********************************************************************************/

- (NSString *)sessionTokenForAuthManager:(id<SBBAuthManagerProtocol>) __unused authManager
{
    return self.sessionToken;
}

- (void)authManager:(id<SBBAuthManagerProtocol>) __unused authManager didGetSessionToken:(NSString *)sessionToken
{
    self.sessionToken = sessionToken;
}

- (NSString *)usernameForAuthManager:(id<SBBAuthManagerProtocol>) __unused authManager
{
    return [APCDataServerManager isMhealthServer] ? self.newName : self.email;
}

- (NSString *)passwordForAuthManager:(id<SBBAuthManagerProtocol>) __unused authManager
{
    return self.password;
}

@end
