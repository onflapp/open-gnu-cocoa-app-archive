//
//  NSIndexSet_SenAdditions.m
//  SenFoundation
//
//  Created by William Swats on Mon Jun 14 2004.
//  Copyright (c) 2004 Sente SA. All rights reserved.
//

#import "NSIndexSet_SenAdditions.h"


@implementation NSIndexSet (SenAdditions)


- (NSArray *)indexSetAsAnArray
{
	NSMutableArray *anIndexArray = nil;
	NSNumber *aNumber = nil;
	unsigned int anIndex = 0;
	unsigned int aCount = 0;
	
	aCount = [self count];
	if ( aCount == 0 ) aCount = 1;
	anIndexArray = [NSMutableArray arrayWithCapacity:aCount];
	anIndex = [self firstIndex];
	while ( anIndex != NSNotFound ) {
		aNumber = [NSNumber numberWithUnsignedInt:anIndex];
		[anIndexArray addObject:aNumber];
		anIndex = [self indexGreaterThanIndex:anIndex];
	}            
	return anIndexArray;
}
@end
