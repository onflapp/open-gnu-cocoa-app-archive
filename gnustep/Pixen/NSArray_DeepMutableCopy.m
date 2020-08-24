//
//  NSArray_DeepMutableCopy.m
//  Pixen-XCode
//
//  Created by Joe Osborn on Sat Jan 24 2004.
//  Copyright (c) 2004 Open Sword Group. All rights reserved.
//

#import "NSArray_DeepMutableCopy.h"


@implementation NSArray(DeepMutableCopy)
- deepMutableCopy
{
	id new = [[NSMutableArray alloc] initWithCapacity:[self count]];
	id enumerator = [self objectEnumerator];
	id current;
	while ( ( current = [enumerator nextObject] ) )
	{
		[new addObject:[[current copy] autorelease]];
	}
	return new;
}
@end
