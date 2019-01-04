// 
//  NSManagedObject+APCHelper.m 
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
 
#import "NSManagedObject+APCHelper.h"

@implementation NSManagedObjectContext (APCHelper)

- (BOOL)saveRecursively:(NSError *__autoreleasing *)error
{
    __block NSError *localError = nil;
    __block BOOL success = [self obtainPermanentIDsForObjects:[[self insertedObjects] allObjects] error:&localError];
    
    if (!success) {
        if (error) *error = localError;
        return NO;
    }
    
    success = [self save:&localError];
    
    if (!success && !localError) NSLog(@"Saving of managed object context failed, but a `nil` value for the `error` argument was returned. This typically indicates an invalid implementation of a key-value validation method exists within your model. This violation of the API contract may result in the save operation being mis-interpretted by callers that rely on the availability of the error.");
    
    if (!success) {
        if (error) *error = localError;
        return NO;
    }
    
    if (!self.parentContext && !self.persistentStoreCoordinator) {
        NSLog(@"Reached the end of the chain of nested managed object contexts without encountering a persistent store coordinator. Objects are not fully persisted.");
        return NO;
    }
    
    NSManagedObjectContext *parentContext = self.parentContext;
    if (parentContext) {
        [parentContext performBlockAndWait:^{
            success = [parentContext saveRecursively:&localError];
        }];
        
        if (!success) {
            if (error) *error = localError;
            return NO;
        }
    }
    
    return success;
}

@end

@implementation NSManagedObject (APCHelper)

+ (instancetype)newObjectForContext:(NSManagedObjectContext*)context
{
    return  [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([self class]) inManagedObjectContext:context];
    
}

+ (NSFetchRequest *)request
{
    return [NSFetchRequest fetchRequestWithEntityName:NSStringFromClass([self class])];
}

+ (NSFetchRequest *)requestWithPredicate:(NSPredicate *)predicate
{
    NSFetchRequest *request = [self request];
    request.predicate = predicate;
    return request;
}

+ (NSFetchRequest *)requestWithPredicate:(NSPredicate *)predicate
                         sortDescriptors:(NSArray *)sortDescriptors
{
    NSFetchRequest *request = [self requestWithPredicate: predicate];
    request.sortDescriptors = sortDescriptors;
    return request;
}

- (BOOL)saveToPersistentStore:(NSError *__autoreleasing *)error
{
    __block NSError *localError = nil;
    BOOL success = [self.managedObjectContext saveRecursively:&localError];
    if (!success) {
        if (error) *error = localError;
        return NO;
    }
    return success;
}

@end
