//
//  CvsEditRequest.h
//  CVL
//
//  Created by Isa Kindov on Wed Jul 10 2002.
//  Copyright (c) 2002 Sen:te. All rights reserved.
//

#import <CvsRequest.h>



@interface CvsEditRequest : CvsRequest
{
    NSMutableString 	*parsingBuffer;
}

+ (CvsEditRequest *) editRequestForFiles:(NSArray *)files inPath:(NSString *)path;
+ (CvsEditRequest *) uneditRequestForFiles:(NSArray *)files inPath:(NSString *)path;

@end
