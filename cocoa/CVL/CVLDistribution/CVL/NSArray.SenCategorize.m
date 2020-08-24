// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "NSArray.SenCategorize.h"
#import <Foundation/Foundation.h>

@implementation NSArray (SenCategorize)
- (NSDictionary *)categorizeUsingMethod:(SEL)aMethod
{
	return [self categorizeUsingMethod:aMethod keepUnkownItems:NO];
}

- (NSDictionary *)categorizeUsingMethod:(SEL)aMethod keepUnkownItems:(BOOL)keep
{
	NSMutableDictionary *result;
	id enumerator;
	NSString *key;
	NSMutableArray *list;
	id anItem;
	
	result=[NSMutableDictionary dictionary];
	enumerator=[self objectEnumerator];
	while ( (anItem=[enumerator nextObject]) ) {
		key=[anItem performSelector:aMethod];
		if (keep && !key) {
			key=@"";
		}
		if (key) {
			if (!(list=[result objectForKey:key])) {
				list=[NSMutableArray array];
				[result setObject:list forKey:key];
			}
			[list addObject:anItem];
		}
	}
	return result;
}

@end
