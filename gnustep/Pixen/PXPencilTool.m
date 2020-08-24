//  PXPencilTool.m
//  Pixen
//
//  Created by Joe Osborn on Tue Sep 30 2003.
//  Copyright (c) 2003 Open Sword Group. All rights reserved.
//

#import "PXPencilTool.h"
#import "PXCanvas.h"
#import "PXCanvasController.h"
#import "PXPencilToolPropertiesView.h"

@implementation PXPencilTool

- (NSString *)name
{
	return NSLocalizedString(@"PENCIL_NAME", @"Pencil Tool");
}

- (BOOL)shiftKeyDown
{
	shiftDown = YES;
	return YES;
}

- (BOOL)shiftKeyUp
{
	shiftDown = NO;
	return YES;
}

- init
{
    [super init];
    propertiesView = [[PXPencilToolPropertiesView alloc] init];
	shiftDown = NO;
    return self;
}

- (void)dealloc
{
    [propertiesView release];
	[super dealloc];
}

- actionName
{
    return NSLocalizedString(@"PENCIL_ACTION", @"Drawing");
}

- (void)setColor:aColor
{
    color = aColor;
}

- color
{
    return color;
}

- (void)drawWithOldColor:(NSColor *)oldColor newColor:(NSColor *)newColor atPoint:(NSPoint)aPoint inLayer:aLayer ofCanvas:aCanvas
{
	if(![aCanvas canDrawAtPoint:aPoint]) { return; }
    id setColor = newColor;
    [[[self undoManager] prepareWithInvocationTarget:self]
drawWithOldColor:newColor newColor:oldColor atPoint:aPoint inLayer:aLayer ofCanvas:aCanvas];
    [aLayer setColor:setColor atPoint:aPoint];
    [aCanvas changedInRect:NSMakeRect(aPoint.x, aPoint.y, 1, 1)];
}

- (void)drawPixelAtPoint:(NSPoint)aPoint inCanvas:aCanvas
{
    if (![propertiesView respondsToSelector:@selector(lineThickness)]) {
		[self drawWithOldColor:[aCanvas
colorAtPoint:aPoint] newColor:[self color] atPoint:aPoint inLayer:[aCanvas activeLayer] ofCanvas:aCanvas];
		return;
    }
	if ([propertiesView drawingPoints] != nil) {
		NSArray *points = [propertiesView drawingPoints];
		int i;
		for (i=0; i<[points count]; i++) {
			NSPoint point = [[points objectAtIndex:i] pointValue];
			point.x += ceilf(aPoint.x - ([propertiesView patternSize].width / 2));
			point.y += ceilf(aPoint.y - ([propertiesView patternSize].height / 2));
			[self drawWithOldColor:[aCanvas
colorAtPoint:point] newColor:[self color] atPoint:point inLayer:[aCanvas activeLayer] ofCanvas:aCanvas];
		}
		return;
	}
    int diameter = [propertiesView lineThickness];
    int radius = diameter/2;
    NSRect rect = NSMakeRect(aPoint.x-radius, aPoint.y-radius, diameter, diameter);
    int x,y;
    for (x=rect.origin.x; x<rect.origin.x+rect.size.width; x++) {
        for (y=rect.origin.y; y<rect.origin.y+rect.size.height; y++) {
            [self drawWithOldColor:[aCanvas
colorAtPoint:NSMakePoint(x,y)] newColor:[self color] atPoint:NSMakePoint(x,y) inLayer:[aCanvas activeLayer] ofCanvas:aCanvas];
        }
    }
}

- (void)drawLineFrom:(NSPoint)initialPoint to:(NSPoint)finalPoint inCanvas:canvas
{
    NSPoint differencePoint = NSMakePoint(finalPoint.x - initialPoint.x, finalPoint.y - initialPoint.y);
    NSPoint currentPoint = initialPoint;
    while(!NSEqualPoints(finalPoint, currentPoint))
    {
        if(differencePoint.x == 0) { currentPoint.y += ((differencePoint.y > 0) ? 1 : -1); }
        else if(differencePoint.y == 0) { currentPoint.x += ((differencePoint.x > 0) ? 1 : -1); }
        else if(abs(differencePoint.x) < abs(differencePoint.y)) 
        {
            currentPoint.y += ((differencePoint.y > 0) ? 1 : -1);
            currentPoint.x = rintf((differencePoint.x/differencePoint.y)*(currentPoint.y-initialPoint.y) + initialPoint.x);
        } 
        else
        {
            currentPoint.x += ((differencePoint.x > 0) ? 1 : -1);
            currentPoint.y = rintf((differencePoint.y/differencePoint.x)*(currentPoint.x-initialPoint.x) + initialPoint.y);
        }
        if([canvas canDrawAtPoint:currentPoint]) { [self drawPixelAtPoint:currentPoint inCanvas:canvas]; }
    }
}

- (void)mouseDownAt:(NSPoint)aPoint fromCanvasController:controller
{
    [[self undoManager] setActionName:[self actionName]];
    [[self undoManager] beginUndoGrouping];
    [[[NSDocumentController sharedDocumentController] currentDocument] updateChangeCount:NSChangeDone];
	if (!shiftDown || [[controller canvas] lastDrawnPoint].x == -1) {
		[self drawPixelAtPoint:aPoint inCanvas:[controller canvas]];
		[[controller canvas] changedInRect:NSMakeRect(aPoint.x, aPoint.y, 1, 1)];
	} else {
		[self drawLineFrom:[[controller canvas] lastDrawnPoint] to:aPoint inCanvas:[controller canvas]];
	}
	[[controller canvas] setLastDrawnPoint:aPoint];
}

- (void)mouseDraggedFrom:(NSPoint)initialPoint to:(NSPoint)finalPoint fromCanvasController:controller
{
	if (!shiftDown) {
		[[controller canvas] setLastDrawnPoint:finalPoint];
		[self drawLineFrom:initialPoint to:finalPoint inCanvas:[controller canvas]];
	}
}

- (void)mouseUpAt:(NSPoint)aPoint fromCanvasController:controller
{
    if([[self undoManager] groupingLevel] != 0)
	{
		[[self undoManager] endUndoGrouping];
	}
}

@end