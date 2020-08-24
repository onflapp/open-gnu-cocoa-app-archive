// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "NSArray.SenUtilities.h"
#import <Foundation/Foundation.h>

@implementation NSMutableArray (SenUtilities)
- (void)addNewObject:anObject
{
	if (![self containsObject:anObject]) {
		[self addObject:anObject];
	}
}

- (void)addNewObjectsFromArray:(NSArray *)otherArray
{
	NSObject *anObject;
	id enumerator=[otherArray objectEnumerator];

	while ( (anObject=[enumerator nextObject]) ) {
		if (![self containsObject:anObject]) {
			[self addObject:anObject];
		}
	}
}

@end