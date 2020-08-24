//
//  CvsEditorsRequest.h
//  CVL
//
//  Created by Isa Kindov on Tue Jul 09 2002.
//  Copyright (c) 2002 Sen:te. All rights reserved.
//

#import <CvsRequest.h>


@class NSMutableDictionary;


@interface CvsEditorsRequest : CvsRequest
{
    NSMutableDictionary	*result;
    NSMutableString 	*parsingBuffer;
}

+ (CvsEditorsRequest *) editorsRequestForFiles:(NSArray *)files inPath:(NSString *)path;

- (NSDictionary *) result;
// Returns a dictionary; keys are full filenames, values are dictionaries with key-values
// editor			NSString
// editionStartDate	NSCalendarDate
// editorHost		NSString
// editedFilename	NSString

@end
