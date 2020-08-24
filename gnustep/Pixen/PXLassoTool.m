//
//  PXLassoTool.m
//  Pixen-XCode
//
//  Created by Joe Osborn on Sat Jun 12 2004.
//  Copyright (c) 2004 Open Sword Group. All rights reserved.
//

#import "PXLassoTool.h"
#import "PXCanvasController.h"
#import "PXCanvas.h"
#import "PXSelectionLayer.h"
#import "PXToolSwitcher.h"

#ifndef __COCOA__
#import "NSArray_DeepMutableCopy.h"
#endif

@implementation PXLassoTool

- (NSString *)name
{
	return NSLocalizedString(@"LASSO_NAME", @"Lasso Tool");
}

- init
{
	[super init];
	selected = [[NSMutableArray alloc] initWithCapacity:128*128];
	isClicking = NO;
	return self;
}

- actionName
{
    return NSLocalizedString(@"LASSO_ACTION", @"Selection");
}

- movingActionName
{
	return NSLocalizedString(@"MOVE_ACTION", @"Moving");
}

- (BOOL)shiftKeyDown
{
	if (!isClicking)
	{
		isAdding = YES;
		[switcher setIcon:[NSImage imageNamed:@"lassoadd"] forTool:self];
	}
	return YES;
}

- (BOOL)shiftKeyUp
{
	if (!isClicking)
	{
		isAdding = NO;
		[switcher setIcon:[NSImage imageNamed:@"lasso"] forTool:self];
	}
	return YES;
}

- (BOOL)optionKeyDown
{
	if (!isClicking)
	{
		isSubtracting = YES;
		[switcher setIcon:[NSImage imageNamed:@"lassosubtract"] forTool:self];
	}
	return YES;
}

- (BOOL)optionKeyUp
{
	if (!isClicking)
	{
		isSubtracting = NO;
		[switcher setIcon:[NSImage imageNamed:@"lasso"] forTool:self];
	}
	return YES;
}

- (void)mouseDownAt:(NSPoint)aPoint fromCanvasController:controller
{
	if (isSubtracting && ![[controller canvas] hasSelection]) { return; }
	
	[selected removeAllObjects];
	isClicking = YES;
	origin = aPoint;
	leftMost = origin.x;
	rightMost = origin.x;
	bottomMost = origin.y;
	topMost = origin.y;
	[path release];
	path = [[NSBezierPath bezierPath] retain];
	[path moveToPoint:origin];
	[self setLayers:[[[controller canvas] layers] deepMutableCopy] fromLayers:[[controller canvas] layers] ofCanvas:[controller canvas]];
	
	if([[controller canvas] pointIsSelected:aPoint] && (!isAdding && !isSubtracting))
	{
		[self startMovingCanvas:[controller canvas]];
	}
	else
	{
		if (!isAdding && !isSubtracting)
		{
			[[controller canvas] deselect];
			oldLayerIndex = [[[controller canvas] layers] indexOfObject:[[controller canvas] activeLayer]];
			oldLastLayerIndex = [[[controller canvas] layers] indexOfObject:[[controller canvas] lastActiveLayer]];
		}
		else
		{
			if (oldLastLayerIndex != NSNotFound)
			{
				[[controller canvas] restoreActivateLayer:[[[controller canvas] layers] objectAtIndex:oldLayerIndex] lastActiveLayer:[[[controller canvas] layers] objectAtIndex:oldLastLayerIndex]];
			}
			else
			{
				[[controller canvas] restoreActivateLayer:[[[controller canvas] layers] objectAtIndex:oldLayerIndex] lastActiveLayer:nil];
			}
		}
		[super mouseDownAt:aPoint fromCanvasController:controller];
		[[controller canvas] changedInRect:NSMakeRect(leftMost-2, bottomMost-2, rightMost-leftMost-2, topMost-bottomMost-2)];
	}
	
	if (isSubtracting)
	{	
		[[[[controller canvas] layers] lastObject] setIsSubtracting:YES];
	}
}

- (void)setLayers:layers fromLayers:oldLayers ofCanvas:canvas
{
	[[[self undoManager] prepareWithInvocationTarget:self] setLayers:oldLayers fromLayers:layers ofCanvas:canvas];
	[canvas setLayers:layers];
}

- (void)startMovingCanvas:canvas
{
	[[self undoManager] setActionName:[self movingActionName]];
	isMoving = YES;
}

- (void)stopMovingCanvas:canvas
{
	isMoving = NO;
	[[canvas activeLayer] finalizeMotion];
}

- (void)mouseDraggedFrom:(NSPoint)initialPoint to:(NSPoint)finalPoint fromCanvasController:controller
{
	if (isSubtracting && ![[controller canvas] hasSelection]) { return; }
	
	if(isMoving)
	{
		[[[controller canvas] activeLayer] translateXBy:(finalPoint.x - initialPoint.x) yBy:(finalPoint.y - initialPoint.y)];
		[[controller canvas] changedInRect:NSMakeRect(0,0,[[controller canvas] size].width,[[controller canvas] size].height)];
	}
	else
	{
		[[self undoManager] setActionName:[self actionName]];
		[super mouseDraggedFrom:initialPoint to:finalPoint fromCanvasController:controller];
	}
}

- (void)mouseUpAt:(NSPoint)aPoint fromCanvasController:controller
{
	if (isSubtracting && ![[controller canvas] hasSelection]) { return; }
	
	isClicking = NO;
	if(isMoving)
	{
		[self stopMovingCanvas:[controller canvas]];
	}
	else if(NSEqualPoints(origin, aPoint) && ([selected count] <= 1)) 
	{ 
		NSRect deselectRect = [[controller canvas] selectedRect];
		[[controller canvas] deselect];
		[[controller canvas] changedInRect:NSMakeRect(deselectRect.origin.x-2, deselectRect.origin.y-2, deselectRect.size.width+4, deselectRect.size.height+4)];
	}
	else
	{
		[path lineToPoint:aPoint];
		id enumerator = [selected objectEnumerator];
		id current;
		while ( ( current = [enumerator nextObject] ) )
		{
			[[controller canvas] deselectPixelAtPoint:NSPointFromString(current)];
		}
		int i, j;
		//go from left to right
		for(i = leftMost; i <= rightMost; i++)
		{
			//go from bottom to top
			for(j = bottomMost; j <= topMost; j++)
			{
				NSPoint point = NSMakePoint(i, j);
				if([path containsPoint:point])
				{
					if(isSubtracting)
					{
						if ([[controller canvas] pointIsSelected:point] && [[[[controller canvas] layers] lastObject] colorAtPoint:point] != nil)
						{
							[[controller canvas] deselectPixelAtPoint:point];
							[[controller canvas] setColor:[[[[controller canvas] layers] lastObject] colorAtPoint:point] atPoint:point];
							[[[[controller canvas] layers] lastObject] setColor:nil atPoint:point];
						}
					}
					else
					{	
						[[controller canvas] selectPixelAtPoint:point];
					}
				}
			}
		}
		if (isSubtracting)
		{	
			[[[[controller canvas] layers] lastObject] setIsSubtracting:NO];
		}
		[[controller canvas] finalizeSelection];
		[super mouseUpAt:aPoint fromCanvasController:controller];
	}
	
    if([[self undoManager] groupingLevel] != 0)
	{
		[[self undoManager] endUndoGrouping];
	}
	[[controller canvas] changedInRect:NSMakeRect(leftMost-8, bottomMost-8, rightMost-leftMost+16, topMost-bottomMost+16)];
}


- (void)drawPixelAtPoint:(NSPoint)point inCanvas:canvas
{
	leftMost = MIN(point.x, leftMost);
	rightMost = MAX(point.x, rightMost);
	bottomMost = MIN(point.y, bottomMost);
	topMost = MAX(point.y, topMost);
	[canvas selectPixelAtPoint:point];
	[selected addObject:NSStringFromPoint(point)];
	[canvas changedInRect:NSMakeRect(point.x-8, point.y-8, 16, 16)];
	[path lineToPoint:point];
}

@end
