//
//  UIViewController+LoggingTests.m
//  APCAppCore
//
//  Created by Dariusz Lesniak on 14/12/2015.
//  Copyright © 2015 Apple, Inc. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "APCLog.h"
#import "APCWebViewController.h"
#import "UIViewController+LoggingTests.m"

@interface TestableAnalyticsPublisher: NSObject <AnalyticsPublisher>
@property (nonatomic, strong) NSString *eventName;
@property (nonatomic, strong) NSDictionary *eventData;
@end

@implementation TestableAnalyticsPublisher

-(void) publishEvent: (NSString *) eventName eventData:(NSDictionary *) eventData {
    self.eventName = eventName;
    self.eventData = eventData;
}

@end

@interface UIViewController_LoggingTests : XCTestCase
@property (nonatomic, strong) TestableAnalyticsPublisher *analyticsPublisher;
@end

@implementation UIViewController_LoggingTests

- (void)setUp {
    [super setUp];
    self.analyticsPublisher = [TestableAnalyticsPublisher new];
    [APCLog setAnalyticsPublisher:self.analyticsPublisher];
}

- (void)testShouldPublishEventWhen_APCLogEventWithDataMethod_Called {
    NSString *eventName = @"testEvent";
    NSDictionary *eventData = @{@"testKey": @"testValue"};
    APCLogEventWithData(eventName, eventData);
    XCTAssertEqual(eventName, self.analyticsPublisher.eventName);
    XCTAssertEqual(eventData, self.analyticsPublisher.eventData);
}

- (void)testShouldPublishPageStartEventWhenViewControllerAppears {
    APCWebViewController *viewController = [[APCWebViewController alloc] init];
    [viewController viewWillAppear:@YES];
    XCTAssertEqual(@"PageStarted", self.analyticsPublisher.eventName);
    XCTAssertEqualObjects(@"APCWebViewController", [self.analyticsPublisher.eventData objectForKey:@"pageName"]);
    XCTAssertNotNil([self.analyticsPublisher.eventData objectForKey:@"time"]);
}

- (void)testShouldPublishPageEndEventWhenViewControllerAppears {
    APCWebViewController *viewController = [[APCWebViewController alloc] init];
    [viewController viewWillDisappear:@YES];
    XCTAssertEqual(@"PageEnded", self.analyticsPublisher.eventName);
    XCTAssertEqualObjects(@"APCWebViewController", [self.analyticsPublisher.eventData objectForKey:@"pageName"]);
    XCTAssertNotNil([self.analyticsPublisher.eventData objectForKey:@"duration"]);
}

- (void)testShouldExcludeNotAPCorAPHControllers {
    UIAlertController *viewController = [[UIAlertController alloc] init];
    viewController.title = @"title";
    [viewController viewWillAppear:@YES];
    XCTAssertNil(self.analyticsPublisher.eventName);
}

@end


