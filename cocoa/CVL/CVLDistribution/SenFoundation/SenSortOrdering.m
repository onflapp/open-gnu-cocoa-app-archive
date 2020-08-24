/*$Id: SenSortOrdering.m,v 1.6 2005/01/10 09:32:34 stephane Exp $*/

// Copyright (c) 1997-2003, Sen:te (Sente SA).  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#ifndef RHAPSODY

#import "SenSortOrdering.h"
#import <SenFoundation/SenFoundation.h>

@implementation SenSortOrdering : NSObject
{
    SEL selector;
    NSString *key;
}


+ (id) sortOrderingWithKey:(NSString *) aKey selector:(SEL) aSelector
{
	return [[[self alloc] initWithKey:aKey selector:aSelector] autorelease];
}


- (id) initWithKey:(NSString *) aKey selector:(SEL) aSelector
{
	[super init];
	key = [aKey copy];
	selector = aSelector;
	return self;
}


- (void) dealloc
{
	RELEASE (key);
	[super dealloc];
}


- (NSString *) key
{
	return key;
}


- (SEL) selector
{
	return selector;
}
@end


static int compareUsingKeyOrderingArray (id left, id right, void *context)
{
	NSEnumerator *orderingEnumerator = [(NSArray *) context objectEnumerator];
	id each;

	while ( (each = [orderingEnumerator nextObject]) ){
		NSString *eachKey = [each key];
		id leftValue = [left valueForKey:eachKey];
		id rightValue = [right valueForKey:eachKey];
		NSComparisonResult result;
		
		if ((leftValue == nil) && (rightValue == nil)) {
			result = NSOrderedSame;
		}
		else if (leftValue == nil) {
			result = ([each selector] == SenCompareAscending) ? NSOrderedAscending : NSOrderedDescending;
		}
		else if (rightValue == nil) {
			result = ([each selector] == SenCompareAscending) ? NSOrderedDescending : NSOrderedAscending;
		}
		else {
			 result = (NSComparisonResult) [leftValue performSelector:[each selector] withObject:rightValue];
		}
		if (result != NSOrderedSame) {
			return result;
		}		
	}
	return NSOrderedSame;
}


@implementation NSArray (SenKeyBasedSorting)
- (NSArray *) arrayBySortingOnKeyOrderArray:(NSArray *) orderArray
{
	return [self sortedArrayUsingFunction:compareUsingKeyOrderingArray context:orderArray];
}
@end


@implementation NSMutableArray (SenKeyBasedSorting)
- (void) sortOnKeyOrderArray:(NSArray *) orderArray
{
	[self sortUsingFunction:compareUsingKeyOrderingArray context:orderArray];
}
@end


@protocol Comparable
- (NSComparisonResult) compare:other;
@end


@implementation NSObject (SenSortOrderingComparison)
- (NSComparisonResult) compareAscending:(id) other
{
	if (![self respondsToSelector:@selector (compare:)]) {
		[NSException raise:NSInvalidArgumentException format:@"%@ does not respond to compare:", self];
	}
	return [(id <Comparable>) self compare:other];
}


- (NSComparisonResult) compareDescending:(id) other
{
	if (![other respondsToSelector:@selector (compare:)]) {
		[NSException raise:NSInvalidArgumentException format:@"%@ does not respond to compare:", other];
	}
	return [(id <Comparable>) other compare:self];
}
@end
#endif
