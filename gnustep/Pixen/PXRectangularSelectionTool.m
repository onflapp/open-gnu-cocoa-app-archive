//
//  PXRectangularSelectionTool.m
//  Pixen-XCode
//
//  Created by Joe Osborn on Sun Jan 04 2004.
//  Copyright (c) 2004 Open Sword Group. All rights reserved.
//

#import "PXRectangularSelectionTool.h"
#import "PXCanvasController.h"
#import "PXCanvas.h"
#import "PXCanvasView.h"
#import "PXLayer.h"
#import "PXSelectionLayer.h"
#import "PXToolSwitcher.h"

@implementation PXRectangularSelectionTool

- (NSString *)name
{
	return NSLocalizedString(@"RECTANGULARSELECTION_NAME", @"Rectangular Selection Tool");
}

- movingActionName
{
	return NSLocalizedString(@"MOVE_ACTION", @"Moving");
}

- actionName
{
	return NSLocalizedString(@"RECTANGULARSELECTION_ACTION", @"Selection");
}

- (BOOL)shiftKeyDown
{
	if (!isClicking)
	{
		isAdding = YES;
		[switcher setIcon:[NSImage imageNamed:@"squareselectadd"] forTool:self];
	}
	return YES;
}

- (BOOL)shiftKeyUp
{
	if (!isClicking)
	{
		isAdding = NO;
		[switcher setIcon:[NSImage imageNamed:@"squareselect"] forTool:self];
	}
	return YES;
}

- (BOOL)optionKeyDown
{
	if (!isClicking)
	{
		isSubtracting = YES;
		[switcher setIcon:[NSImage imageNamed:@"squareselectsubtract"] forTool:self];
	}
	return YES;
}

- (BOOL)optionKeyUp
{
	if (!isClicking)
	{
		isSubtracting = NO;
		[switcher setIcon:[NSImage imageNamed:@"squareselect"] forTool:self];
	}
	return YES;
}

- (void)mouseDownAt:(NSPoint)aPoint fromCanvasController:controller
{
	if (isSubtracting && ![[controller canvas] hasSelection]) { return; }
	
	isClicking = YES;
    origin = aPoint;
	
	[[self undoManager] beginUndoGrouping];
	[self setLayers:[[[controller canvas] layers] deepMutableCopy] fromLayers:[[controller canvas] layers] ofCanvas:[controller canvas]];
	
	if([[controller canvas] pointIsSelected:aPoint] && (!isAdding && !isSubtracting))
	{
		lastSelectedRect = [[controller canvas] selectedRect];
		[self startMovingCanvas:[controller canvas]];
	}
	else
	{
		if (!isAdding && !isSubtracting)
		{
			[[controller canvas] deselect];
			oldLayerIndex = [[[controller canvas] layers] indexOfObject:[[controller canvas] activeLayer]];
			oldLastLayerIndex = [[[controller canvas] layers] indexOfObject:[[controller canvas] lastActiveLayer]];
			selectedRect = NSZeroRect;
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
		[[controller canvas] changedInRect:NSMakeRect(lastSelectedRect.origin.x-2, lastSelectedRect.origin.y-2, lastSelectedRect.size.width+4, lastSelectedRect.size.height+4)];
		lastSelectedRect = NSZeroRect;
	}
	
	if (isSubtracting)
		[[[[controller canvas] layers] lastObject] setIsSubtracting:YES];
}

- (void)setLayers:layers fromLayers:oldLayers ofCanvas:canvas
{
	[[[self undoManager] prepareWithInvocationTarget:self] setLayers:oldLayers fromLayers:layers ofCanvas:canvas];
	[canvas setLayers:layers];
	lastSelectedRect = NSZeroRect;
}

- (void)startMovingCanvas:canvas
{
	[[self undoManager] setActionName:[self movingActionName]];
	isMoving = YES;
}

- (void)stopMovingCanvas:canvas
{
	isMoving = NO;
	selectedRect = lastSelectedRect; 
	[[canvas activeLayer] finalizeMotion];
}

- (void)refreshRect:(NSRect)rectangle inView:view
{
	NSRect modifiedRect = rectangle;
	modifiedRect.origin.x -= 1;
	modifiedRect.origin.y -= 1;
	modifiedRect.size.width += 2;
	modifiedRect.size.height += 2;
	[view displayRect:[view convertFromCanvasToViewRect:modifiedRect]];
}

- (void)mouseDraggedFrom:(NSPoint)initialPoint to:(NSPoint)finalPoint fromCanvasController:(PXCanvasController *)controller
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
		int i, j;
		for(i = lastSelectedRect.origin.x; i < NSMaxX(lastSelectedRect); i++)
		{
			for(j = lastSelectedRect.origin.y; j < NSMaxY(lastSelectedRect); j++)
			{
				[[controller canvas] deselectPixelAtPoint:NSMakePoint(i, j)];
			}
		}
		selectedRect = NSIntersectionRect(NSUnionRect(NSMakeRect(origin.x, origin.y, 1, 1), NSMakeRect(finalPoint.x, finalPoint.y, 1, 1)), NSMakeRect(0, 0, [[controller canvas] size].width, [[controller canvas] size].height));
		if(!NSEqualPoints(origin, finalPoint)) 
		{
			int i, j;
			for(i = selectedRect.origin.x; i < NSMaxX(selectedRect); i++)
			{
				for(j = selectedRect.origin.y; j < NSMaxY(selectedRect); j++)
				{
					[[controller canvas] selectPixelAtPoint:NSMakePoint(i, j)];
				}
			}
			//selectedRect = [[controller canvas] selectedRect];
			//selectedRect = NSMakeRect(0,0,[[controller canvas] size].width,[[controller canvas] size].height);
			
			// really ugly code!
			// DO NOT READ BELOW THIS LINE IF YOU WISH TO RETAIN YOUR SANITY
			
			NSRect shortVerticalDirty, longVerticalDirty, shortHorizontalDirty, longHorizontalDirty, lastVerticalDirty, lastHorizontalDirty; // phew
			
			if (NSEqualPoints(selectedRect.origin, lastSelectedRect.origin)) { // quadrant I
				// ------- 4 --
				// |          |
				// 1          2
				// ...6...    |
				// :     5    |
				// :.....:_3__|
				
				// 1)
				shortVerticalDirty = NSMakeRect(selectedRect.origin.x, selectedRect.origin.y + MIN(lastSelectedRect.size.height, selectedRect.size.height),
												1, fabs(selectedRect.size.height - lastSelectedRect.size.height) + 1);
				// 2)
				longVerticalDirty = NSMakeRect(selectedRect.origin.x + selectedRect.size.width, selectedRect.origin.y,
											   1, selectedRect.size.height + 1);
				// 3)
				shortHorizontalDirty = NSMakeRect(selectedRect.origin.x + MIN(lastSelectedRect.size.width, selectedRect.size.width), selectedRect.origin.y,
												fabs(selectedRect.size.width - lastSelectedRect.size.width) + 1, 1);
				// 4)
				longHorizontalDirty = NSMakeRect(selectedRect.origin.x, selectedRect.origin.y + selectedRect.size.height,
											   selectedRect.size.width + 1, 1);
				// 5)
				lastVerticalDirty = NSMakeRect(selectedRect.origin.x + lastSelectedRect.size.width, selectedRect.origin.y,
											   1, lastSelectedRect.size.height + 1);
				// 6)
				lastHorizontalDirty = NSMakeRect(selectedRect.origin.x, selectedRect.origin.y + lastSelectedRect.size.height,
											   lastSelectedRect.size.width + 1, 1);
				
			} else if (selectedRect.origin.x + selectedRect.size.width == lastSelectedRect.origin.x + lastSelectedRect.size.width &&
					   selectedRect.origin.y == lastSelectedRect.origin.y) { // quadrant II
				// ------- 4 --
				// |          |
				// 2          1
				// |    ...6...
				// |    5     :
				// |__3_:.....:
				
				// 1)
				shortVerticalDirty = NSMakeRect(selectedRect.origin.x + selectedRect.size.width, selectedRect.origin.y + MIN(lastSelectedRect.size.height, selectedRect.size.height),
												1, fabs(selectedRect.size.height - lastSelectedRect.size.height) + 1);
				// 2)
				longVerticalDirty = NSMakeRect(selectedRect.origin.x, selectedRect.origin.y,
											   1, selectedRect.size.height + 1);
				// 3)
				shortHorizontalDirty = NSMakeRect(selectedRect.origin.x + MIN(selectedRect.size.width - lastSelectedRect.size.width, 0), selectedRect.origin.y,
												  fabs(selectedRect.size.width - lastSelectedRect.size.width) + 1, 1);
				// 4)
				longHorizontalDirty = NSMakeRect(selectedRect.origin.x, selectedRect.origin.y + selectedRect.size.height,
												 selectedRect.size.width + 1, 1);
				// 5)
				lastVerticalDirty = NSMakeRect(selectedRect.origin.x + selectedRect.size.width - lastSelectedRect.size.width, selectedRect.origin.y,
											   1, lastSelectedRect.size.height + 1);
				// 6)
				lastHorizontalDirty = NSMakeRect(selectedRect.origin.x + selectedRect.size.width - lastSelectedRect.size.width, selectedRect.origin.y + lastSelectedRect.size.height,
												 lastSelectedRect.size.width + 1, 1);
				
				
			} else if (selectedRect.origin.x + selectedRect.size.width == lastSelectedRect.origin.x + lastSelectedRect.size.width &&
					   selectedRect.origin.y + selectedRect.size.height == lastSelectedRect.origin.y + lastSelectedRect.size.height) { // quadrant III
				// - 3 -.......
				// |	5     :
				// 2	:..6..:
				// |          |
				// |          1
				// |__4_______|
				
				// 1)
				shortVerticalDirty = NSMakeRect(selectedRect.origin.x + selectedRect.size.width, selectedRect.origin.y + MIN(selectedRect.size.height - lastSelectedRect.size.height, 0),
												1, fabs(selectedRect.size.height - lastSelectedRect.size.height) + 1);
				// 2)
				longVerticalDirty = NSMakeRect(selectedRect.origin.x, selectedRect.origin.y,
											   1, selectedRect.size.height + 1);
				// 3)
				shortHorizontalDirty = NSMakeRect(selectedRect.origin.x + MIN(selectedRect.size.width - lastSelectedRect.size.width, 0), selectedRect.origin.y  + selectedRect.size.height,
												  fabs(selectedRect.size.width - lastSelectedRect.size.width) + 1, 1);
				// 4)
				longHorizontalDirty = NSMakeRect(selectedRect.origin.x, selectedRect.origin.y,
												 selectedRect.size.width + 1, 1);
				// 5)
				lastVerticalDirty = NSMakeRect(selectedRect.origin.x + selectedRect.size.width - lastSelectedRect.size.width, selectedRect.origin.y + selectedRect.size.height - lastSelectedRect.size.height,
											   1, lastSelectedRect.size.height + 1);
				// 6)
				lastHorizontalDirty = NSMakeRect(selectedRect.origin.x + selectedRect.size.width - lastSelectedRect.size.width, selectedRect.origin.y + selectedRect.size.height - lastSelectedRect.size.height,
												 lastSelectedRect.size.width + 1, 1);
				
				
			} else if (selectedRect.origin.x == lastSelectedRect.origin.x &&
					   selectedRect.origin.y + selectedRect.size.height == lastSelectedRect.origin.y + lastSelectedRect.size.height) { // quadrant IV
				// .......- 3 -
				// :	 5    |
				// :..6..:    |
				// |          |
				// 1          2
				// |________4_|
				
				// 1)
				shortVerticalDirty = NSMakeRect(selectedRect.origin.x, selectedRect.origin.y + MIN(selectedRect.size.height - lastSelectedRect.size.height, 0),
												1, fabs(selectedRect.size.height - lastSelectedRect.size.height) + 1);
				// 2)
				longVerticalDirty = NSMakeRect(selectedRect.origin.x + selectedRect.size.width, selectedRect.origin.y,
											   1, selectedRect.size.height + 1);
				// 3)
				shortHorizontalDirty = NSMakeRect(selectedRect.origin.x + MIN(lastSelectedRect.size.width, selectedRect.size.width), selectedRect.origin.y + selectedRect.size.height,
												  fabs(selectedRect.size.width - lastSelectedRect.size.width) + 1, 1);
				// 4)
				longHorizontalDirty = NSMakeRect(selectedRect.origin.x, selectedRect.origin.y,
												 selectedRect.size.width + 1, 1);
				// 5)
				lastVerticalDirty = NSMakeRect(selectedRect.origin.x + lastSelectedRect.size.width, selectedRect.origin.y + selectedRect.size.height - lastSelectedRect.size.height,
											   1, lastSelectedRect.size.height + 1);
				// 6)
				lastHorizontalDirty = NSMakeRect(selectedRect.origin.x, selectedRect.origin.y + selectedRect.size.height - lastSelectedRect.size.height,
												 lastSelectedRect.size.width + 1, 1);
			} else { // TRANSITION OMG
				// ?
				lastHorizontalDirty = NSZeroRect;
				lastVerticalDirty = NSZeroRect;
				shortVerticalDirty = NSUnionRect(NSMakeRect(selectedRect.origin.x, selectedRect.origin.y, 1, selectedRect.size.height),
												 NSMakeRect(lastSelectedRect.origin.x, lastSelectedRect.origin.y, 1, lastSelectedRect.size.height));
				
				shortHorizontalDirty = NSUnionRect(NSMakeRect(selectedRect.origin.x, selectedRect.origin.y, selectedRect.size.width, 1),
												 NSMakeRect(lastSelectedRect.origin.x, lastSelectedRect.origin.y, lastSelectedRect.size.width, 1));
				
				longVerticalDirty = NSUnionRect(NSMakeRect(selectedRect.origin.x + selectedRect.size.width, selectedRect.origin.y, 1, selectedRect.size.height),
												NSMakeRect(lastSelectedRect.origin.x + lastSelectedRect.size.width, lastSelectedRect.origin.y, 1, lastSelectedRect.size.height));
				
				longHorizontalDirty = NSUnionRect(NSMakeRect(selectedRect.origin.x, selectedRect.origin.y + selectedRect.size.height, selectedRect.size.width, 1),
												   NSMakeRect(lastSelectedRect.origin.x, lastSelectedRect.origin.y + lastSelectedRect.size.height, lastSelectedRect.size.width, 1));
			}
			
			if (lastVerticalDirty.size.height >= 1) {
				[self refreshRect:lastVerticalDirty inView:[controller view]];
			}
			if (lastHorizontalDirty.size.width >= 1) {
				[self refreshRect:lastHorizontalDirty inView:[controller view]];
			}
			[self refreshRect:longVerticalDirty inView:[controller view]];
			[self refreshRect:longHorizontalDirty inView:[controller view]];
			[self refreshRect:shortVerticalDirty inView:[controller view]];
			[self refreshRect:shortHorizontalDirty inView:[controller view]];
			
			lastSelectedRect = selectedRect;
		}
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
	else if(NSEqualPoints(origin, aPoint)) 
	{ 
		NSRect deselectRect = [[controller canvas] selectedRect];
		[[controller canvas] deselect];
		[[controller canvas] changedInRect:NSMakeRect(deselectRect.origin.x-2, deselectRect.origin.y-2, deselectRect.size.width+4, deselectRect.size.height+4)];
	}
	else
	{
		NSRect changeRect = [[controller canvas] selectedRect];

		if (isSubtracting)
		{
			int i, j;
			for (i = lastSelectedRect.origin.x; i < NSMaxX(lastSelectedRect); i++)
			{
				for (j = lastSelectedRect.origin.y; j < NSMaxY(lastSelectedRect); j++)
				{
					NSPoint point = NSMakePoint(i, j);
					[[controller canvas] deselectPixelAtPoint:point];
					if ([[controller canvas] pointIsSelected:point])
					{
						[[controller canvas] setColor:[[[[controller canvas] layers] lastObject] colorAtPoint:point] atPoint:point];
					}
					[[[[controller canvas] layers] lastObject] setColor:nil atPoint:point];
					
				}
			}
			[[[[controller canvas] layers] lastObject] finalize];
			[[controller canvas] activateLayer:[[[controller canvas] layers] lastObject]];
			changeRect = NSUnionRect(changeRect, lastSelectedRect);
		}
		else
			[[controller canvas] finalizeSelection];
		changeRect.size.width++;
		changeRect.size.height++;
		[[controller canvas] changedInRect:changeRect];
	}
	
	if (isSubtracting && !(NSEqualPoints(origin, aPoint)))
		[[[[controller canvas] layers] lastObject] setIsSubtracting:NO];
	
	[[self undoManager] endUndoGrouping];
}

@end
