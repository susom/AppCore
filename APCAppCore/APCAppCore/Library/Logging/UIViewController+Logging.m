//
//  UIViewController+Logging.m
//  APCAppCore
//
//  Created by Dariusz Lesniak on 11/12/2015.
//  Copyright © 2015 Apple, Inc. All rights reserved.
//

#import "APCLog.h"
#import "UIViewController+Logging.h"
#import "APCBaseTaskViewController.h"
#import "APCTask.h"
#import "APCConstants.h"
#import <objc/runtime.h>

@implementation UIViewController (Logging)

+ (void)load {
    [self swizzleWillAppear];
    [self swizzleWillDisappear];
}

+(void) swizzleWillAppear {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = [self class];
        
        SEL originalSelector = @selector(viewWillAppear:);
        SEL swizzledSelector = @selector(viewWillAppearWithLogging:);
        
        Method originalMethod = class_getInstanceMethod(class, originalSelector);
        Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);
        
        BOOL didAddMethod =
        class_addMethod(class,
                        originalSelector,
                        method_getImplementation(swizzledMethod),
                        method_getTypeEncoding(swizzledMethod));
        
        if (didAddMethod) {
            class_replaceMethod(class,
                                swizzledSelector,
                                method_getImplementation(originalMethod),
                                method_getTypeEncoding(originalMethod));
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }
    });
    
}

+(void) swizzleWillDisappear {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = [self class];
        
        SEL originalSelector = @selector(viewWillDisappear:);
        SEL swizzledSelector = @selector(viewWillDisappearWithLogging:);
        
        Method originalMethod = class_getInstanceMethod(class, originalSelector);
        Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);
        
        BOOL didAddMethod =
        class_addMethod(class,
                        originalSelector,
                        method_getImplementation(swizzledMethod),
                        method_getTypeEncoding(swizzledMethod));
        
        if (didAddMethod) {
            class_replaceMethod(class,
                                swizzledSelector,
                                method_getImplementation(originalMethod),
                                method_getTypeEncoding(originalMethod));
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }
    });
    
}

- (void)viewWillAppearWithLogging:(BOOL)animated {
    [self viewWillAppearWithLogging:animated];
    
    if ([self shouldAnalyseController]) {
        self.pageStart = [NSDate date];
        APCLogEventWithData(kPageStarted, (@{@"pageName" : NSStringFromClass(self.class),
                                                      @"time" : [APCLog getStringFromDate:self.pageStart]}));
    }
    
}

- (void)viewWillDisappearWithLogging:(BOOL)animated {
    [self viewWillDisappearWithLogging:animated];
    
    if ([self shouldAnalyseController]) {
        NSDate *now = [NSDate date];
        NSTimeInterval secondsBetween = [now timeIntervalSinceDate:self.pageStart];
        
        APCLogEventWithData(kPageEnded, (@{@"pageName" : NSStringFromClass(self.class), @"duration" : [NSString stringWithFormat:@"%d", (int)secondsBetween]}));
    }
    

}

-(BOOL) shouldAnalyseController {
    NSString *viewName = NSStringFromClass([self class]);
    
    return ([viewName hasPrefix:@"APC"]
    || [viewName hasPrefix:@"APH"])
    && ![viewName isEqualToString:@"APCBaseTaskViewController"];
    
}

- (NSDate *)pageStart {
    return objc_getAssociatedObject(self, @selector(pageStart));
}

- (void)setPageStart:(NSDate *)pageStart {
    objc_setAssociatedObject(self, @selector(pageStart), pageStart, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
