//
//  PXSelectionLayer.m
//  Pixen-XCode
//
//  Created by Joe Osborn on Sun Jan 04 2004.
//  Copyright (c) 2004 Open Sword Group. All rights reserved.
//

#import "PXSelectionLayer.h"
#import "PXImage.h"
#import "PXPoint.h"
#import "KTMutableMatrix.h"

@implementation PXSelectionLayer

+ selectionWithSize:(NSSize)aSize
{
	return [[[self alloc] initWithName:@"(selection)" size:aSize] autorelease];
}

- initWithName:aName size:(NSSize)aSize
{
	[super initWithName:aName size:aSize];
	return self;
}

- (void)setIsSubtracting:(BOOL)subtracting
{
	isSubtracting = subtracting;
}

- (void)checkWorkingPoints
{
	if (workingPoints == nil)
	{	
		workingPoints = [[KTMutableMatrix matrixWithCapacity:512*512 cuboidBounds:(unsigned)([self size].width), (unsigned)([self size].height), 0, 0] retain];
	}
}

- workingPoints
{
	return workingPoints;
}

- (void)addWorkingPoint:(NSPoint)aPoint
{
	[self checkWorkingPoints];
	[workingPoints setObject:self atCoordinates:(unsigned)aPoint.x, (unsigned)aPoint.y];
}

- (void)removeWorkingPoint:(NSPoint)aPoint
{
	[self checkWorkingPoints];
	[workingPoints setObject:nil atCoordinates:(unsigned)aPoint.x, (unsigned)aPoint.y];
}

- (BOOL)canDrawAtPoint:(NSPoint)point
{
	return [super canDrawAtPoint:point] && [self pointIsSelected:point];
}

- pixelAtPoint:(NSPoint)point
{
	return [image _pixelAtPoint:point];
}

- (BOOL)pointIsSelected:(NSPoint)point
{
	return (([image pixelAtPoint:point] != nil) || ([workingPoints objectAtCoordinates:(unsigned)point.x, (unsigned)point.y] == self));
}

- (NSColor *)colorAtPoint:(NSPoint)aPoint
{
	return [image colorAtPoint:aPoint];
}

- (void)finalize
{
	[workingPoints removeAllObjects];	
}

- (void)transformedDrawRect:(NSRect)aRect fixBug:(BOOL)fix
{
	[super transformedDrawRect:NSMakeRect(aRect.origin.x-2, aRect.origin.y-2, aRect.size.width+4, aRect.size.height+4) fixBug:fix];
	unsigned i, j;
	NSRect rect = NSIntersectionRect(aRect, NSMakeRect(0, 0, [self size].width, [self size].height));
	for(i = MAX(aRect.origin.x, 0); i < MIN(NSMaxX(aRect), [self size].width); i++)
	{
		for(j = MAX(aRect.origin.y, 0); j < MIN(NSMaxY(aRect), [self size].height); j++)
		{
			if([self pixelAtPoint:NSMakePoint(i, j)] != nil)
			{
				NSRect currentRect = NSMakeRect(i, j, 1, 1);
				if(NSEqualRects(rect, NSZeroRect)) { rect = currentRect; }
				rect = NSUnionRect(rect, currentRect);
			}
		}
	}
	
	for (i = MAX(rect.origin.x, 0); i < MIN(NSMaxX(aRect), [self size].width) + 1; i++)
	{
		for (j = MAX(rect.origin.y, 0); j < MIN(NSMaxY(rect), [self size].height) + 1; j++)
		{
			if (![self canDrawAtPoint:NSMakePoint(i,j)]) { continue; }
			if (![self canDrawAtPoint:NSMakePoint(i-1, j)])
			{
				[self drawBezierFromPoint:NSMakePoint(i, j) toPoint:NSMakePoint(i, j + 1) color:[NSColor blackColor]];
			}
			if (![self canDrawAtPoint:NSMakePoint(i+1, j)])
			{
				[self drawBezierFromPoint:NSMakePoint(i + 1, j) toPoint:NSMakePoint(i + 1, j + 1) color:[NSColor blackColor]];
			}
			if (![self canDrawAtPoint:NSMakePoint(i, j-1)])
			{
				[self drawBezierFromPoint:NSMakePoint(i, j) toPoint:NSMakePoint(i + 1, j) color:[NSColor blackColor]];
			}
			if (![self canDrawAtPoint:NSMakePoint(i, j+1)])
			{
				[self drawBezierFromPoint:NSMakePoint(i, j + 1) toPoint:NSMakePoint(i + 1, j + 1) color:[NSColor blackColor]];
			}
		}
	}
	
	if (isSubtracting)
	{
		for(i = MAX(rect.origin.x - 1, 0); i < (MIN(NSMaxX(rect), [self size].width-2) + 2); i++)
		{
			for(j = MAX(rect.origin.y - 1, 0); j < (MIN(NSMaxY(rect), [self size].height-2) + 2); j++)
			{
				if (![workingPoints objectAtCoordinates:i, j]) { continue; }
				if (![workingPoints objectAtCoordinates:i-1, j])
				{
					[self drawBezierFromPoint:NSMakePoint(i, j) toPoint:NSMakePoint(i, j + 1) color:[NSColor redColor]];
				}
				if (![workingPoints objectAtCoordinates:i+1,j])
				{
					[self drawBezierFromPoint:NSMakePoint(i + 1, j) toPoint:NSMakePoint(i + 1, j + 1) color:[NSColor redColor]];
				}
				if (![workingPoints objectAtCoordinates:i,j-1])
				{
					[self drawBezierFromPoint:NSMakePoint(i, j) toPoint:NSMakePoint(i + 1, j) color:[NSColor redColor]];
				}
				if (![workingPoints objectAtCoordinates:i,j+1])
				{
					[self drawBezierFromPoint:NSMakePoint(i, j + 1) toPoint:NSMakePoint(i + 1, j + 1) color:[NSColor redColor]];
				}
			}
		}
	}
}

- (void)drawBezierFromPoint:(NSPoint)fromPoint toPoint:(NSPoint)toPoint color:color
{
	id path = [[[NSBezierPath alloc] init] autorelease];
	[path setLineWidth:.1];
	const float pattern[] = { 0.5, 0.5 };
	[path moveToPoint:fromPoint];
	[path lineToPoint:toPoint];
	[[NSColor colorWithCalibratedWhite:1 alpha:1] set];
	[path setLineDash:pattern count:1 phase:0];
	[path stroke];
	[color set];
	[path setLineDash:pattern count:1 phase:.5];
	[path stroke];	
}

@end