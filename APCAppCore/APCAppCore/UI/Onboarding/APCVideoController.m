// 
//  APCVideoController.m
//  APCAppCore 
// 
// Copyright (c) 2018, Apple Inc. All rights reserved. 
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
 
#import "APCVideoController.h"
#import "APCStudyOverviewViewController.h"
#import "NSBundle+Helper.h"
#import "APCAppCore.h"
#import <AVFoundation/AVFoundation.h>

static NSString *const kVideoShownKey = @"VideoShown";
static NSString *const kPlayerItemStatus = @"status";
static NSString *const kViewFrameKeyPath = @"view.frame";

@interface APCVideoController ()

@property (nonatomic, strong) AVPlayerViewController *playerViewController;
@property (nonatomic, copy) APCVideoControllerCompletionHandler completionHandler;

@end

@implementation APCVideoController

#pragma mark - Init

- (instancetype) initWithContentURL:(NSURL *)contentURL completion:(APCVideoControllerCompletionHandler)handler {
    self = [super init];
    if (!self) {
        return nil;
    }
    
    _completionHandler = handler;
    AVPlayer *player = [AVPlayer playerWithURL:contentURL];
    _playerViewController = [AVPlayerViewController new];
    _playerViewController.player = player;
    NSKeyValueObservingOptions options = NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew;
    // Register as an observer of the player item's status property
    [_playerViewController.player.currentItem addObserver:self forKeyPath:kPlayerItemStatus options:options context:nil];
    // Register as an observer of the player view controller view's frame property
    [_playerViewController addObserver:self forKeyPath:kViewFrameKeyPath options:options context:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackDidFinish:) name:AVPlayerItemDidPlayToEndTimeNotification object:_playerViewController.player.currentItem];
    
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    
    return self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id) __unused object change:(NSDictionary<NSString *,id> *)change context:(void *) __unused context {
    
    if ([keyPath isEqualToString:kPlayerItemStatus])
    {
        AVPlayerItemStatus status = AVPlayerItemStatusUnknown;
        // Get the status change from the change dictionary
        NSNumber *statusNumber = change[NSKeyValueChangeNewKey];
        if ([statusNumber isKindOfClass:[NSNumber class]]) {
            status = statusNumber.integerValue;
        }
        switch (status) {
            case AVPlayerItemStatusReadyToPlay:
                [self.playerViewController.player play];
                [APCLog methodInfo:[NSString new] viewControllerAppeared: self.playerViewController];
                APCLogEventWithData(kVideoWatch, (@{}));
                break;
            case AVPlayerItemStatusFailed:
                // Failed. Examine AVPlayerItem.error
                break;
            case AVPlayerItemStatusUnknown:
                // Not ready
                break;
        }
    }
    else if ([keyPath isEqualToString:kViewFrameKeyPath] && self.playerViewController.player.currentItem.status == AVPlayerItemStatusReadyToPlay)
    {
        // Player view controller has been dismissed
        APCLogEventWithData(kVideoCompleted, (@{}));
        if (self.completionHandler) self.completionHandler();
    }
}

- (void)dealloc
{
    [self.playerViewController.player.currentItem removeObserver:self forKeyPath:kPlayerItemStatus context:nil];
    [self.playerViewController removeObserver:self forKeyPath:kViewFrameKeyPath context:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:_playerViewController.player.currentItem];
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kVideoShownKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark - Notifications

- (void) playbackDidFinish:(NSNotification*) __unused notification {
    [self dismiss];
}


#pragma mark - Public Methods

- (void) dismiss {
    [self.playerViewController.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}
@end
