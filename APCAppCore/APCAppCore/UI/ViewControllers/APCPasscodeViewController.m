// 
//  APCPasscodeViewController.m 
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
 
#import "APCPasscodeViewController.h"
#import <LocalAuthentication/LocalAuthentication.h>
#import "UIAlertController+Helper.h"
#import "APCPasscodeView.h"
#import "APCLog.h"

#import "UIColor+APCAppearance.h"
#import "UIFont+APCAppearance.h"
#import "APCKeychainStore+Passcode.h"
#import "APCUserInfoConstants.h"
#import "APCConstants.h"
#import "UIImage+APCHelper.h"

@interface APCPasscodeViewController ()<APCPasscodeViewDelegate>

@property (nonatomic, strong) LAContext *touchContext;
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet APCPasscodeView *passcodeView;
@property (weak, nonatomic) IBOutlet UIButton *touchIdButton;
@property (weak, nonatomic) IBOutlet UIImageView *logoImageView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *touchIdButtonBottomConstraint;
@property (nonatomic) NSInteger wrongAttemptsCount;

@end

@implementation APCPasscodeViewController

#pragma mark - View Life Cycle
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.wrongAttemptsCount = 0;
    
    self.touchContext = [LAContext new];
    self.passcodeView.delegate = self;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(makePasscodeViewBecomeFirstResponder) name:UIApplicationWillEnterForegroundNotification object:nil];
    
    [self setupAppearance];
    
    if ([self.touchContext canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:nil]) {
        self.passcodeView.alpha = 0;
        self.titleLabel.alpha = 0;
        self.touchIdButton.alpha = 0;
        NSString *biometryType = self.touchContext.biometryType == LABiometryTypeFaceID ? @"Face ID" : @"Touch ID";
        self.titleLabel.text = [NSString stringWithFormat:NSLocalizedString(@"%@ or Enter Passcode", nil), NSLocalizedString(biometryType, nil)];
        [self.touchIdButton setTitle:[NSString stringWithFormat:NSLocalizedString(@"Use %@", nil), NSLocalizedString(biometryType, nil)] forState:UIControlStateNormal];
    } else {
        self.touchIdButton.hidden = YES;
        self.titleLabel.text = NSLocalizedString(@"Enter Passcode", nil);
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    APCLogViewControllerAppeared();
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if (![self.touchContext canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:nil]) {
        [self makePasscodeViewBecomeFirstResponder];
    } else {
        self.passcodeView.alpha = 0;
        self.titleLabel.alpha = 0;
        self.touchIdButton.alpha = 0;
        [self promptTouchId];
    }
    
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
}

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Setup

- (void)setupAppearance
{
    [self.titleLabel setTextColor:[UIColor appSecondaryColor1]];
    [self.titleLabel setFont:[UIFont appLightFontWithSize:19.0f]];
    
    [self.logoImageView setImage:[UIImage imageNamed:@"logo_disease"]];
}

#pragma mark - APCPasscodeViewDelegate

- (void) passcodeViewDidFinish:(APCPasscodeView *) __unused passcodeView withCode:(NSString *) code
{
    if (self.passcodeView.code.length > 0) {
        if ([code isEqualToString:[APCKeychainStore stringForKey:kAPCPasscodeKey]]) {
            //Authenticated
            if ([self.passcodeViewControllerDelegate respondsToSelector:@selector(passcodeViewControllerDidSucceed:)]) {
                [self.passcodeViewControllerDelegate passcodeViewControllerDidSucceed:self];
            }
            
            APCLogEventWithData(kPasscodeSuccess, @{});
            
        } else {
            
            if ([self.passcodeViewControllerDelegate respondsToSelector:@selector(passcodeViewControllerDidFail:)]) {
                [self.passcodeViewControllerDelegate passcodeViewControllerDidFail:self];
            }
            
            if (self.wrongAttemptsCount < 5) {
                CAKeyframeAnimation *shakeAnimation = [CAKeyframeAnimation animation];
                shakeAnimation.keyPath = @"position.x";
                shakeAnimation.values = @[ @0, @15, @-15, @15, @-15, @0 ];
                shakeAnimation.keyTimes = @[ @0, @(1 / 8.0), @(3 / 8.0), @(5 / 8.0), @(7 / 8.0), @1 ];
                shakeAnimation.duration = 0.27;
                shakeAnimation.delegate = self;
                shakeAnimation.additive = YES;
                
                [self.passcodeView.layer addAnimation:shakeAnimation forKey:@"shakeAnimation"];
                
                self.wrongAttemptsCount++;
                
            } else {
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Wrong Passcode", nil) message:NSLocalizedString(@"Please enter again.", nil) preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * __unused action) {
                    [self.passcodeView reset];
                    [self makePasscodeViewBecomeFirstResponder];
                }];
                [alert addAction:okAction];
                [self presentViewController:alert animated:YES completion:nil];
                
            }
            
            APCLogEventWithData(kPasscodeFailed, @{});
        }
    }
}

#pragma mark - IBActions

- (IBAction) useTouchId: (id) __unused sender
{
    [self promptTouchId];
}

- (void)promptTouchId
{
    NSError *error = nil;
    self.touchContext = [LAContext new];
    if ([self.touchContext canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&error]) {
        self.touchContext.localizedFallbackTitle = NSLocalizedString(@"Enter Passcode", @"");
        NSString *biometryType = self.touchContext.biometryType == LABiometryTypeFaceID ? @"Face ID" : @"Touch ID";
        
        NSString *localizedReason = [NSString stringWithFormat:NSLocalizedString(@"Please authenticate with %@", nil), NSLocalizedString(biometryType, nil)];
        
        [self.touchContext evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics
                          localizedReason:localizedReason
                                    reply:^(BOOL success, NSError __unused *error)
         {
             dispatch_sync(dispatch_get_main_queue(), ^{
                 if (success) {
                     if ([self.passcodeViewControllerDelegate respondsToSelector:@selector(passcodeViewControllerDidSucceed:)]) {
                         [self.passcodeViewControllerDelegate passcodeViewControllerDidSucceed:self];
                     }
                 } else {
                     if ([self.passcodeViewControllerDelegate respondsToSelector:@selector(passcodeViewControllerDidFail:)]) {
                         [self.passcodeViewControllerDelegate passcodeViewControllerDidFail:self];
                     }
                     
                     [UIView animateWithDuration:0.3 animations:^{
                         self.passcodeView.alpha = 1;
                         self.titleLabel.alpha = 1;
                         self.touchIdButton.alpha = 1;
                     }];
                     
                     [self makePasscodeViewBecomeFirstResponder];
                 }
             });
         }];
    }
}

#pragma mark - Keyboard Notifications

- (void)keyboardWillShow:(NSNotification *)notifcation
{
    CGFloat keyboardHeight = [notifcation.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue].size.height;
    
    double animationDuration = [notifcation.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    
    [UIView animateWithDuration:animationDuration animations:^{
        self.touchIdButtonBottomConstraint.constant = keyboardHeight + 15;
    }];
    
}

#pragma mark - Application Notifications
- (void)makePasscodeViewBecomeFirstResponder{
    [self.passcodeView performSelector:@selector(becomeFirstResponder) withObject:nil afterDelay:0.5];
}

#pragma mark - Animation Delegate

- (void)animationDidStop:(CAAnimation *)__unused anim finished:(BOOL)__unused flag
{
    [self.passcodeView reset];
    [self makePasscodeViewBecomeFirstResponder];
}

@end
