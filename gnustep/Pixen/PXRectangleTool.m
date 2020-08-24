//
//  PXRectangleTool.m
//  Pixen-XCode
//
//  Created by Andy Matuschak on Wed Mar 10 2004.
//  Copyright (c) 2004 Open Sword Group. All rights reserved.
//

#import "PXRectangleTool.h"
#import "PXCanvasController.h"
#import "PXRectangleToolPropertiesView.h"

@implementation PXRectangleTool

- (NSString *)name
{
	return NSLocalizedString(@"RECTANGLE_NAME", @"Rectangle Tool");
}

- actionName
{
	return NSLocalizedString(@"RECTANGLE_ACTION", @"Drawing Rectangle");
}

- init
{
    [super init];
    propertiesView = [[PXRectangleToolPropertiesView alloc] init];
    return self;
}


- (void)mouseDownAt:(NSPoint)aPoint fromCanvasController:controller
{
    [super mouseDownAt:aPoint fromCanvasController:controller];
    lastRect = NSMakeRect(_origin.x, _origin.y, 0, 0);
}

- (void)drawRect:(NSRect)aRect inCanvas:aCanvas
{
    int i, j;
    for (i = aRect.origin.x; i <= aRect.origin.x + aRect.size.width; i++)
    {
		for (j = aRect.origin.y; j <= aRect.origin.y + aRect.size.height; j++)
		{
			[self drawPixelAtPoint:NSMakePoint(i, j) inCanvas:aCanvas];
		}
    }
}

- (void)finalDrawFromPoint:(NSPoint)origin toPoint:(NSPoint)aPoint inCanvas:canvas
{
    if ([propertiesView shouldFill])
    {
		// careful about backwards-drawn rectangles...
		NSColor * oldColor = [self color];
		int borderWidth = [propertiesView borderWidth];
		if (![propertiesView shouldUseMainColorForFill]) { [self setColor:[propertiesView fillColor]]; }
		[self drawRect:NSMakeRect((origin.x < aPoint.x) ? origin.x+borderWidth : aPoint.x+borderWidth,
								  (origin.y < aPoint.y) ? origin.y+borderWidth : aPoint.y+borderWidth,
								  (origin.x < aPoint.x) ? aPoint.x - origin.x - (borderWidth*2): origin.x - aPoint.x - (borderWidth*2),
								  (origin.y < aPoint.y) ? aPoint.y - origin.y - (borderWidth*2): origin.y - aPoint.y - (borderWidth*2))
			  inCanvas:canvas];
		[self setColor:oldColor];
    }
}

- (void)drawFromPoint:(NSPoint)origin toPoint:(NSPoint)finalPoint inCanvas:canvas
{
    int i, j;
    for (i = 0; i < [propertiesView borderWidth]; i++)
    {
		if (i != 0)
		{
			NSPoint tempOrigin, tempFinalPoint;
			tempOrigin.x = (origin.x < finalPoint.x) ? origin.x + 1 : origin.x - 1;
			tempOrigin.y = (origin.y < finalPoint.y) ? origin.y + 1 : origin.y - 1;
			tempFinalPoint.x = (origin.x < finalPoint.x) ? finalPoint.x - 1 : finalPoint.x + 1;
			tempFinalPoint.y = (origin.y < finalPoint.y) ? finalPoint.y - 1 : finalPoint.y + 1;
			origin = tempOrigin;
			finalPoint = tempFinalPoint;
		}
		/*if (finalPoint.x > [canvas size].width - 1) { finalPoint.x = [canvas size].width - 1; }
		if (finalPoint.x < 0) { finalPoint.x = 0; }
		if (finalPoint.y > [canvas size].height - 1) { finalPoint.y = [canvas size].height - 1; }
		if (finalPoint.y < 0) { finalPoint.y = 0; }*/
		for (j = (origin.x < finalPoint.x) ? origin.x : finalPoint.x; (origin.x < finalPoint.x) ? j <= finalPoint.x : j <= origin.x; j++)
		{
			[self drawPixelAtPoint:NSMakePoint(j, origin.y) inCanvas:canvas];
			[self drawPixelAtPoint:NSMakePoint(j, finalPoint.y) inCanvas:canvas];
		}
		for (j = (origin.y < finalPoint.y) ? origin.y : finalPoint.y; (origin.y < finalPoint.y) ? j <= finalPoint.y : j <= origin.y; j++)
		{
			[self drawPixelAtPoint:NSMakePoint(origin.x, j) inCanvas:canvas];
			[self drawPixelAtPoint:NSMakePoint(finalPoint.x, j) inCanvas:canvas];
		}
    }
}

- (void)mouseDraggedFrom:(NSPoint)initialPoint to:(NSPoint)finalPoint fromCanvasController:controller
{
    NSPoint backupOrigin = _origin;
    [super mouseDraggedFrom:initialPoint to:finalPoint fromCanvasController:controller];
    _origin = backupOrigin;
}

@end