// 
//  APCWebViewController.m 
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
 
#import "APCWebViewController.h"

@interface APCWebViewController () <WKNavigationDelegate>

@property (weak, nonatomic) IBOutlet UIBarButtonItem *backBarButtonItem;

@property (weak, nonatomic) IBOutlet UIBarButtonItem *refreshBarButtonItem;

@property (weak, nonatomic) IBOutlet UIBarButtonItem *stopBarButtonItem;

@property (weak, nonatomic) IBOutlet UIBarButtonItem *forwardBarButtonItem;

@end

@implementation APCWebViewController

-(void)viewDidLoad{
    
    WKWebViewConfiguration *webViewConfiguration = [WKWebViewConfiguration new];
    webViewConfiguration.dataDetectorTypes = WKDataDetectorTypePhoneNumber | WKDataDetectorTypeLink;
    WKWebView *webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:webViewConfiguration];
    webView.translatesAutoresizingMaskIntoConstraints = NO;
    webView.navigationDelegate = self;
    [self.view insertSubview:webView atIndex:0];
    self.webView = webView;
    
    if (self.link.length > 0) {
        NSString *encodedURLString=[self.link stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:encodedURLString]]];
    }
}

- (UIRectEdge)edgesForExtendedLayout
{
    return UIRectEdgeNone;
}

- (BOOL)automaticallyAdjustsScrollViewInsets
{
    return YES;
}

- (void)updateViewConstraints
{
    [self.webView.topAnchor constraintEqualToAnchor:self.view.topAnchor].active = YES;
    [self.webView.bottomAnchor constraintEqualToAnchor:self.webToolBar.topAnchor].active = YES;
    [self.webView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor].active = YES;
    [self.webView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor].active = YES;
    [super updateViewConstraints];
}

/*********************************************************************************/
#pragma mark - WKNavigationDelegate methods
/*********************************************************************************/

- (void)webView:(WKWebView *) __unused webView didStartProvisionalNavigation:(WKNavigation *) __unused navigation
{
    [self updateToolbarButtons];
}

- (void)webView:(WKWebView *) __unused webView didFinishNavigation:(WKNavigation *) __unused navigation
{
    [self updateToolbarButtons];
}

- (void)webView:(WKWebView *) __unused webView didFailNavigation:(WKNavigation *) __unused navigation withError:(NSError *) __unused error
{
    [self updateToolbarButtons];
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


/*********************************************************************************/
#pragma mark - Helper methods
/*********************************************************************************/

- (void)updateToolbarButtons
{
    self.refreshBarButtonItem.enabled = !self.webView.isLoading;
    self.stopBarButtonItem.enabled = !self.webView.isLoading;
    
    self.backBarButtonItem.enabled = self.webView.canGoBack;
    self.forwardBarButtonItem.enabled = self.webView.canGoForward;
}

/*********************************************************************************/
#pragma mark - IBActions
/*********************************************************************************/

- (IBAction)back:(id)__unused sender
{
    [self.webView goBack];
}

- (IBAction)refresh:(id)__unused sender
{
    [self.webView reload];
}

- (IBAction)stop:(id)__unused sender
{
    [self.webView stopLoading];
}

- (IBAction)forward:(id)__unused sender
{
    [self.webView goForward];
}

- (IBAction)close:(id) __unused sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}


@end
