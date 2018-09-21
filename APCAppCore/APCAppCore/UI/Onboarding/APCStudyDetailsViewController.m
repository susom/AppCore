// 
//  APCStudyDetailsViewController.m 
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
 
#import "APCStudyDetailsViewController.h"
#import "UIColor+APCAppearance.h"
#import "UIFont+APCAppearance.h"
#import "APCAppCore.h"
#import <WebKit/WebKit.h>

@interface APCStudyDetailsViewController () <WKNavigationDelegate>

@property (weak, nonatomic) WKWebView *webView;

@end

@implementation APCStudyDetailsViewController

- (void)dealloc {
    _webView.navigationDelegate = nil;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [self setupAppearance];
    [self setupNavAppearance];
    
    self.title = self.studyDetails.caption;
    
    NSString *filePath = [[NSBundle mainBundle] pathForResource:self.studyDetails.detailText ofType:@"html" inDirectory:@"HTMLContent"];
    NSURL *targetURL = [NSURL fileURLWithPath:filePath];
    WKWebViewConfiguration *webViewConfiguration = [WKWebViewConfiguration new];
    webViewConfiguration.dataDetectorTypes = WKDataDetectorTypeAll;
    WKWebView *webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:webViewConfiguration];
    webView.translatesAutoresizingMaskIntoConstraints = NO;
    webView.navigationDelegate = self;
    [self.view addSubview:webView];
    self.webView = webView;
    [self.webView loadFileURL:targetURL allowingReadAccessToURL:targetURL.URLByDeletingLastPathComponent];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:YES];
  APCLogViewControllerAppeared();
}

-(void)viewDidLayoutSubviews {
    
    [super viewDidLayoutSubviews];
    
    // A Hack to get rid of the black border surrounding the PDF in the WKWebView
    UIView *view = self.webView;
    while (view) {
        view.backgroundColor = [UIColor whiteColor];
        view = [view.subviews firstObject];
    }
}

- (void)updateViewConstraints
{
    [self.webView.topAnchor constraintEqualToAnchor:self.view.topAnchor].active = YES;
    [self.webView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor].active = YES;
    [self.webView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor].active = YES;
    [self.webView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor].active = YES;
    [super updateViewConstraints];
}

- (void)setupNavAppearance
{
    UIBarButtonItem  *backster = [APCCustomBackButton customBackBarButtonItemWithTarget:self action:@selector(back) tintColor:[UIColor appPrimaryColor]];
    [self.navigationItem setLeftBarButtonItem:backster];
}

#pragma mark - Setup

- (void)setupAppearance
{
    
}

- (void)webView:(WKWebView *) __unused webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    if (navigationAction.navigationType == WKNavigationTypeLinkActivated)
    {
        [[UIApplication sharedApplication] openURL:navigationAction.request.URL options:@{} completionHandler:^(BOOL __unused success) {
            decisionHandler(WKNavigationActionPolicyCancel);
        }];
    }
    else {
        decisionHandler(WKNavigationActionPolicyAllow);
    }
}

#pragma mark - Selectors / IBActions

- (void)back
{
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - WebView Delegates

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *) __unused navigation
{
    // Disable user selection
    [webView evaluateJavaScript:@"document.documentElement.style.webkitUserSelect='none';" completionHandler:nil];
}


@end
