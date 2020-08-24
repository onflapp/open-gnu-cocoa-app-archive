//
//  PXGrid.m
//  Pixen-XCode
//
//  Created by Andy Matuschak on Wed Mar 17 2004.
//  Copyright (c) 2004 Open Sword Group. All rights reserved.
//

#import "PXGrid.h"
#ifndef __COCOA__
#import <AppKit/NSGraphicsContext.h>
#import <AppKit/NSBezierPath.h>
#endif

@implementation PXGrid

- initWithUnitSize:(NSSize)newUnitSize color:newColor shouldDraw:(BOOL)newShouldDraw;
{
	[super init];
	[self setUnitSize:newUnitSize];
	[self setColor:newColor];
	[self setShouldDraw:newShouldDraw];
	return self;
}

- (void)drawRect:(NSRect)drawingRect
{
	if (!shouldDraw) { return; }
	NSSize dimensions = drawingRect.size;
	int i;
	float lineWidth;
    BOOL oldShouldAntialias = [[NSGraphicsContext currentContext] shouldAntialias];
	[[NSGraphicsContext currentContext] setShouldAntialias:NO];
	lineWidth = [NSBezierPath defaultLineWidth];
	[NSBezierPath setDefaultLineWidth:0];
	[color set];
	for (i = 0; i < dimensions.width + unitSize.width; i+=unitSize.width)
	{
		[NSBezierPath strokeLineFromPoint:NSMakePoint(i, 0) toPoint:NSMakePoint(i, dimensions.height)];
	}
	for (i = 0; i < dimensions.height + unitSize.width; i+=unitSize.height)
	{
		[NSBezierPath strokeLineFromPoint:NSMakePoint(0, i) toPoint:NSMakePoint(dimensions.width, i)];
	}
	[NSBezierPath setDefaultLineWidth:lineWidth];
	[[NSGraphicsContext currentContext] setShouldAntialias:oldShouldAntialias];	
}

- (NSSize)unitSize
{
	return unitSize;
}

- color
{
	return color;
}

- (BOOL)shouldDraw
{
	return shouldDraw;
}

- (void)setShouldDraw:(BOOL)newShouldDraw
{
	shouldDraw = newShouldDraw;
}

- (void)setColor:newColor
{
	color = newColor;
}

- (void)setUnitSize:(NSSize)newUnitSize
{
	unitSize = newUnitSize;
}

@end
