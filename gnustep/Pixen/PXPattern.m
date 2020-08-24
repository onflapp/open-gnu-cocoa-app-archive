//
//  PXPattern.m
//  Pixen-XCode
//
//  Created by Ian Henderson on 07.10.04.
//  Copyright 2004 Open Sword Group. All rights reserved.
//

#import "PXPattern.h"


@implementation PXPattern


- (void)addPoints:(NSArray *)points
{
	[self setColor:[NSColor blackColor] atPoints:points];
}

- (void)addPoint:(NSPoint)point
{
	[self setColor:[NSColor blackColor] atPoint:point];
}

- (NSArray *)pointsInPattern
{
	NSMutableArray *points = [NSMutableArray array];
	int x, y, z;
	for (x=0; x<[self size].width; x++) {
		for (y=0; y<[self size].height; y++) {
			for (z=0; z<[[self layers] count]; z++) {
				if ([[[[self layers] objectAtIndex:z] colorAtPoint:NSMakePoint(x, y)] alphaComponent] > .5) {
					[points addObject:[NSValue valueWithPoint:NSMakePoint(x, y)]];
				}
			}
		}
	}
	return points;
}

- (void)drawRect:(NSRect)rect fixBug:(BOOL)fixBug // this is slow, but patterns are very small.
{
	NSEnumerator *pointsEnumerator = [[self pointsInPattern] objectEnumerator];
	NSValue *point;
	[[NSColor blackColor] set];
	while ( ( point = [pointsEnumerator nextObject]) ) {
		NSRectFill(NSMakeRect([point pointValue].x, [point pointValue].y, 1, 1));
	}
}

@end
