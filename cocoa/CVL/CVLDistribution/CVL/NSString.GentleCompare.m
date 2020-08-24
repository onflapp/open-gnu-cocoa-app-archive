// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "NSString.GentleCompare.h"
#import "SenFoundationCVLCandidates.subproj/NSString_SenCaseInsensitiveComparison.h"
#import <Foundation/Foundation.h>

@implementation NSString (GentleCompare)
- (NSComparisonResult)gentleCompare:(NSString *)aString
{
		BOOL iDo= ([[self lastPathComponent] characterAtIndex: 0] == '.');
		BOOL itDoes= ([[aString lastPathComponent] characterAtIndex: 0] == '.');
	if (iDo != itDoes)
	{
		if (iDo)
		{
			return NSOrderedDescending;
		}
		else
		{
			return NSOrderedAscending;
		}
	}
	else
	{
        return [self senCaseInsensitiveCompare:aString];
	}
}

@end
