//
//  SBBDataArchive+APCHelper.m
//  APCAppCore
//
//  Created by Paweł Kowalczyk on 18/09/2019.
//  Copyright © 2019 Stanford Medical, Inc. All rights reserved.
//

#import "SBBDataArchive+APCHelper.h"

static NSString * const kAPCSerializedDataKey_Identifier = @"identifier";
static NSString * const kAPCSerializedDataKey_Item = @"item";
static NSString * const kUnknownFileNameFormatString = @"UnknownFile_%lu";
static NSString * const kJsonPathExtension = @"json";
static NSString * kSchemaRevision = @"schemaRevision";
static NSInteger const kSchemaRevisionDefaultValue = 1;

@implementation SBBDataArchive (APCHelper)

- (instancetype)initWithReference:(NSString *)reference
{
    self = [self initWithReference:reference jsonValidationMapping:nil];
    if (!self) return nil;
    [self setSchemaRevision:@(kSchemaRevisionDefaultValue)];
    return self;
}

- (void)insertDictionaryIntoArchive:(NSDictionary *)dictionary
{
    NSString *filename = [self filenameFromDictionary:dictionary];
    filename = [filename stringByAppendingPathExtension:kJsonPathExtension];
    [self insertDictionaryIntoArchive:dictionary filename:filename createdOn:[NSDate date]];
}

/**
 Represents an old convention in this project:  the dictionary
 we're about to .zip must contain one entry with the name of that
 file.  Here, we'll try to extract it.  If we can't find it,
 no problem (kind of); we'll make one up.  At worst case, we'll
 have a .zip file with a bunch of files like "UnknownFile_1.json",
 "UnknownFile_2.json", etc.
 */
- (NSString *)filenameFromDictionary:(NSDictionary *)dictionary
{
    //
    // Try to extract a filename from the dictionary.
    //
    NSString *filename = dictionary [kAPCSerializedDataKey_Item];
    
    if (filename == nil)
    {
        filename = dictionary [kAPCSerializedDataKey_Identifier];
    }
    
    //
    // If that didn't work, use the next "unnamed_file" filename.
    //
    if (filename == nil)
    {
        NSUInteger countOfUnknownFileNames = 0;
        do {
            countOfUnknownFileNames = countOfUnknownFileNames + 1;
            filename = [NSString stringWithFormat: kUnknownFileNameFormatString, (unsigned long)countOfUnknownFileNames];
        } while (dictionary[filename]);

    }
    
    return filename;
}

- (void)setSchemaRevision:(NSNumber *)schemaRevision
{
    [self setArchiveInfoObject:schemaRevision forKey:kSchemaRevision];
}

@end

