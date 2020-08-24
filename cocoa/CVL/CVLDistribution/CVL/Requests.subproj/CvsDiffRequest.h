/* CvsDiffRequest.h created by vincent on Mon 08-Dec-1997 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <CvsRequest.h>
#import "CVLFile.h"

@class NSMutableDictionary;


extern NSString* CvsDiffRequestFilenamePattern;
extern NSString* CvsDiffPathPattern;


@interface CvsDiffRequest : CvsRequest
{
    NSMutableString *parsingBuffer;
    NSMutableDictionary *result;
    NSString *diffPath;
    unsigned context;
    CVLDiffOutputFormat outputFormat;
}
+ (CvsDiffRequest*) cvsDiffRequestAtPath:(NSString *)aPath files:(NSArray *)someFiles context:(unsigned)context outputFormat:(CVLDiffOutputFormat)newOutputFormat;

- (NSDictionary *)result;

@end
