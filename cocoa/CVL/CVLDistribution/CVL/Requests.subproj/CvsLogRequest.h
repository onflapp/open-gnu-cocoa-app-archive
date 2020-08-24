/* CvsLogRequest.h created by ja on Thu 04-Sep-1997 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <CvsRequest.h>


@class NSMutableDictionary;


@interface CvsLogRequest : CvsRequest
{
    NSMutableString *parsingBuffer;
    NSMutableDictionary *result;
    NSString *logPath;
}
+ (CvsLogRequest *)cvsLogRequestForFiles:(NSArray *)files inPath:(NSString *)aPath;
-(NSDictionary *)result;

@end
