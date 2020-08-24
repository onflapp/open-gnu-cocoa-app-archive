//
//  PXPoint.m
//  Pixen-XCode
//
//  Created by Joe Osborn on 2004.08.08.
//  Copyright 2004 Open Sword Group. All rights reserved.
//

#import "PXPoint.h"


@implementation PXPoint

+ withNSPoint:(NSPoint)aPoint
{
	return [[[self alloc] initWithNSPoint:aPoint] autorelease];
}

- initWithNSPoint:(NSPoint)aPoint
{
	[super init];
	point = aPoint;
	return self;
}

- (NSPoint)pointValue
{
	return point;
}

- (unsigned)hash
{
	return point.x * point.y;
}

- (BOOL)isEqual:other
{
	return NSEqualPoints(point, [other pointValue]);
}

@end
