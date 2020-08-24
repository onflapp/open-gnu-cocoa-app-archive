//
//  CvsWatchersRequest.h
//  CVL
//
//  Created by Isa Kindov on Tue Jul 09 2002.
//  Copyright (c) 2002 Sen:te. All rights reserved.
//

#import <CvsRequest.h>


@class NSMutableDictionary;


@interface CvsWatchersRequest : CvsRequest
{
    NSMutableDictionary	*result;
    NSMutableString 	*parsingBuffer;
}

+ (CvsWatchersRequest *) watchersRequestForFiles:(NSArray *)files inPath:(NSString *)path;

- (NSDictionary *) result;
    // Returns a dictionary; keys are full filenames, values are dictionaries with key-values
    // cvsWatchers			NSArray of dictionaries whose ke-value pairs are
    //   email	NSString
    //   edit	NSNumber
    //   unedit	NSNumber
    //   commit	NSNumber

@end
