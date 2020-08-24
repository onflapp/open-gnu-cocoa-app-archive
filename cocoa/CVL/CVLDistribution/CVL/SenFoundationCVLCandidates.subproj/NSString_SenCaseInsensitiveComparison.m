/* NSString_SenCaseInsensitiveComparison.m created by stephane on Thu 02-Mar-2000 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "NSString_SenCaseInsensitiveComparison.h"

@implementation NSString(SenCaseInsensitiveComparison)

- (NSComparisonResult) senCaseInsensitiveCompare:(NSString *)aString
{
    NSComparisonResult	result = [self caseInsensitiveCompare:aString];

    if(result == NSOrderedSame)
        return [self compare:aString];
    return result;
}

@end
