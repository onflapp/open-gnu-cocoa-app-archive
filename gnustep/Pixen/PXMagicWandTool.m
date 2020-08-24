//
//  PXMagicWandTool.m
//  Pixen-XCode
//
//  Created by Andy Matuschak on Sat Jun 12 2004.
//  Copyright (c) 2004 Open Sword Group. All rights reserved.
//

#import "PXMagicWandTool.h"
#import "PXCanvas.h"
#import "PXCanvasController.h"
#import "PXTool.h"
#import "PXLayer.h"
#import "PXImage.h"
#import "PXToolSwitcher.h"
#import "PXPoint.h"

@implementation PXMagicWandTool

- (NSString *)name
{
	return NSLocalizedString(@"MAGICWAND_NAME", @"Magic Wand Tool");
}

- (BOOL)shiftKeyDown
{
	isAdding = YES;
	[switcher setIcon:[NSImage imageNamed:@"magicadd"] forTool:self];
	return YES;
}

- (BOOL)shiftKeyUp
{
	isAdding = NO;
	[switcher setIcon:[NSImage imageNamed:@"magic"] forTool:self];
	return YES;
}

- (BOOL)optionKeyDown
{
	isSubtracting = YES;
	[switcher setIcon:[NSImage imageNamed:@"magicsubtract"] forTool:self];
	return YES;
}

- init
{
    [super init];
	selectedPoints = [[NSMutableArray alloc] init];
    return self;
}

- (void)dealloc
{
	[selectedPoints release];
	[super dealloc];
}

- (BOOL)optionKeyUp
{
	isSubtracting = NO;
	[switcher setIcon:[NSImage imageNamed:@"magic"] forTool:self];
	return YES;
}

- actionName
{
    return NSLocalizedString(@"MAGICWAND_ACTION", @"Selection");
}

- movingActionName
{
	return NSLocalizedString(@"MOVE_ACTION", @"Moving");
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

- (BOOL)shouldAbandonFillingAtPoint:(NSPoint)aPoint fromCanvasController:controller
{
	return NO;
}

- (void)setLayers:layers fromLayers:oldLayers ofCanvas:canvas
{
	[[[self undoManager] prepareWithInvocationTarget:self] setLayers:oldLayers fromLayers:layers ofCanvas:canvas];
	[canvas setLayers:layers];
}

- (void)mouseDownAt:(NSPoint)aPoint fromCanvasController:controller
{
	[[self undoManager] beginUndoGrouping];
	[self setLayers:[[[controller canvas] layers] deepMutableCopy] fromLayers:[[controller canvas] layers] ofCanvas:[controller canvas]];
	
    if([[controller canvas] pointIsSelected:aPoint] && !isSubtracting)
	{
		lastSelectedRect = [[controller canvas] selectedRect];
		[self startMovingCanvas:[controller canvas]];
	}	
    else
	{
		if (!isAdding && !isSubtracting)
		{
			oldLayerIndex = [[[controller canvas] layers] indexOfObject:[[controller canvas] activeLayer]];
			oldLastLayerIndex = [[[controller canvas] layers] indexOfObject:[[controller canvas] lastActiveLayer]];
			selectedRect = NSZeroRect;
			if ([[controller canvas] hasSelection])
			{
				NSRect deselectRect = [[controller canvas] selectedRect];
				[[controller canvas] deselect];
				[[controller canvas] changedInRect:NSMakeRect(deselectRect.origin.x-2, deselectRect.origin.y-2, deselectRect.size.width+4, deselectRect.size.height+4)];
			}
		}
		if (isAdding)
		{
			if (oldLastLayerIndex < [[[controller canvas] layers] count])
			{
				[[controller canvas] restoreActivateLayer:[[[controller canvas] layers] objectAtIndex:oldLayerIndex] lastActiveLayer:[[[controller canvas] layers] objectAtIndex:oldLastLayerIndex]];
			}
			else
			{
				[[controller canvas] restoreActivateLayer:[[[controller canvas] layers] objectAtIndex:oldLayerIndex] lastActiveLayer:nil];
			}
		}
        [super mouseDownAt:aPoint fromCanvasController:controller];
	}
	[[self undoManager] endUndoGrouping];
}

- (void)mouseDraggedFrom:(NSPoint)initialPoint to:(NSPoint)finalPoint fromCanvasController:controller
{
	if(isMoving)
	{
		[[[controller canvas] activeLayer] translateXBy:(finalPoint.x - initialPoint.x) yBy:(finalPoint.y - initialPoint.y)];
		[[controller canvas] changedInRect:NSMakeRect(0,0,[[controller canvas] size].width,[[controller canvas] size].height)];
	}
}

- (void)mouseUpAt:(NSPoint)aPoint fromCanvasController:controller
{
	if(isMoving)
	{
		[self stopMovingCanvas:[controller canvas]];
	}
	else
	{
		NSEnumerator *enumerator = [selectedPoints objectEnumerator];
		id current;
		while  ( (current = [enumerator nextObject] ) )
		{
			if (isSubtracting)
			{
				NSPoint currentPoint = [current pointValue];
				[[controller canvas] deselectPixelAtPoint:currentPoint];
				if ([[controller canvas] pointIsSelected:currentPoint])
				{
					[[[controller canvas] lastActiveLayer] setColor:[[[[controller canvas] layers] lastObject] colorAtPoint:currentPoint] atPoint:currentPoint];
				}
				[[[[controller canvas] layers] lastObject] setColor:nil atPoint:currentPoint];
			} else {
				[[controller canvas] selectPixelAtPoint:[current pointValue]];
			}
		}
		if (isSubtracting && NSEqualRects([[controller canvas] selectedRect], NSZeroRect))
		{
			[[controller canvas] deselect];
		}
		[[controller canvas] changedInRect:NSMakeRect(selectedRect.origin.x-2, selectedRect.origin.y-2, selectedRect.size.width+4, selectedRect.size.height+4)];
		selectedRect = NSZeroRect;
		[selectedPoints removeAllObjects];
		[[controller canvas] finalizeSelection];
	}
}

- (BOOL)point:(NSPoint)aPoint isUsefulForReplacing:oldColor inCanvas:aCanvas shouldCheckToTheLeft:(BOOL)check
{
    return  (([[NSUserDefaults standardUserDefaults] boolForKey:@"PXShouldTile"] ? YES : (aPoint.y < [aCanvas size].height)) &&
			 ([[NSUserDefaults standardUserDefaults] boolForKey:@"PXShouldTile"] ? YES : (aPoint.y >= 0)) &&
			 ([[aCanvas colorAtPoint:aPoint] isEqual:oldColor] &&
			  (check ? ![[aCanvas colorAtPoint:NSMakePoint(aPoint.x-1, aPoint.y)] isEqual:oldColor] : YES)) &&
			 (isSubtracting ? [aCanvas pointIsSelected:aPoint] : ![aCanvas pointIsSelected:aPoint]) &&
			 ![selectedPoints containsObject:[PXPoint withNSPoint:aPoint]]);
}

- (void)activatePointWithOldColor:oldColor newColor:newColor atPoints:thisTimeFilled ofCanvas:aCanvas
{
    id enumerator = [thisTimeFilled objectEnumerator], current;
	[selectedPoints addObjectsFromArray:thisTimeFilled];
	while ( (current = [enumerator nextObject]) )
    {
		selectedRect = NSUnionRect(selectedRect, NSMakeRect([current pointValue].x, [current pointValue].y, 1, 1));
		lastSelectedRect = selectedRect;
    }
}

@end
