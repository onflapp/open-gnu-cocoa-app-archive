//
//  PXCrosshair.m
//  Pixen-XCode
//
//  Created by Ian Henderson on Fri Jun 11 2004.
//  Copyright (c) 2004 Open Sword Group. All rights reserved.
//

#import "PXCrosshair.h"
#ifndef __COCOA__
#import <AppKit/NSGraphicsContext.h>
#import <AppKit/NSBezierPath.h>
#import <AppKit/NSColor.h>
#endif

@implementation PXCrosshair


- (void)drawRect:(NSRect)drawingRect
{
	if (![self shouldDraw]) { return; }
	NSSize dimensions = drawingRect.size;
	float lineWidth;
    BOOL oldShouldAntialias = [[NSGraphicsContext currentContext] shouldAntialias];
	[[NSGraphicsContext currentContext] setShouldAntialias:NO];
	lineWidth = [NSBezierPath defaultLineWidth];
	[NSBezierPath setDefaultLineWidth:0];
	[[self color] set];
	[NSBezierPath strokeLineFromPoint:NSMakePoint(cursorPosition.x, 0) toPoint:NSMakePoint(cursorPosition.x, dimensions.height)];
	[NSBezierPath strokeLineFromPoint:NSMakePoint(0, cursorPosition.y) toPoint:NSMakePoint(dimensions.width, cursorPosition.y)];
	[NSBezierPath strokeLineFromPoint:NSMakePoint(cursorPosition.x+1, 0) toPoint:NSMakePoint(cursorPosition.x+1, dimensions.height)];
	[NSBezierPath strokeLineFromPoint:NSMakePoint(0, cursorPosition.y+1) toPoint:NSMakePoint(dimensions.width, cursorPosition.y+1)];
	[NSBezierPath setDefaultLineWidth:lineWidth];
	[[NSGraphicsContext currentContext] setShouldAntialias:oldShouldAntialias];	
}

- color
{
	NSData *colorData = [[NSUserDefaults standardUserDefaults] objectForKey:@"PXCrosshairColor"];
	if (colorData == nil) {
		colorData = [NSArchiver archivedDataWithRootObject:[NSColor redColor]];
		[[NSUserDefaults standardUserDefaults] setObject:colorData forKey:@"PXCrosshairColor"];
	}
	return [NSUnarchiver unarchiveObjectWithData:colorData];
}
- (BOOL)shouldDraw
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:@"PXCrosshairEnabled"];
}

- (NSPoint)cursorPosition
{
	return cursorPosition;
}

- (void)setCursorPosition:(NSPoint)position
{
	cursorPosition = position;
}

@end
