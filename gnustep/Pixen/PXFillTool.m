//
//  PXFillTool.m
//  Pixen-XCode
//
//  Created by Joe Osborn on Tue Nov 18 2003.
//  Copyright (c) 2003 Open Sword Group. All rights reserved.
//

// This code is based on some from Will Leshner. Thanks, man!

#import "PXFillTool.h"
#import "PXCanvas.h"
#import "PXCanvasController.h"
#import "PXPoint.h"

@implementation PXFillTool

- (NSString *)name
{
	return NSLocalizedString(@"FILL_NAME", @"Fill Tool");
}

- actionName
{
    return NSLocalizedString(@"FILL_ACTION", @"Fill");
}

- color
{
    return color;
}

- (void)setColor:aColor
{
    color = aColor;
}

- (BOOL)shouldAbandonFillingAtPoint:(NSPoint)aPoint fromCanvasController:controller
{
	if([[self color] isEqual:[[controller canvas] colorAtPoint:aPoint]]) { return YES; }
	//this is all to dodge the clear-on-clear bug.
	if([[self color] alphaComponent] < .00125)
	{
		if([[controller canvas] colorAtPoint:aPoint] == nil) { return YES; }
		if([[[controller canvas] colorAtPoint:aPoint] alphaComponent] < .00125) { return YES; }
	}
	return NO;
}

- (void)mouseDownAt:(NSPoint)aPoint fromCanvasController:controller
{
	if([self shouldAbandonFillingAtPoint:aPoint fromCanvasController:controller]) { return; }
    [[self undoManager] setActionName:[self actionName]];
    [[self undoManager] beginUndoGrouping];
    [[[NSDocumentController sharedDocumentController] currentDocument] updateChangeCount:NSChangeDone];
    [self fillAtPoint:aPoint inCanvas:[controller canvas] replacingColor:[[controller canvas] colorAtPoint:aPoint] withColor:[self color]];
    if([[self undoManager] groupingLevel] != 0)	{ [[self undoManager] endUndoGrouping];	}
}

- (void)registerUndoForReplacingColor:oldColor withColor:newColor atPoints:points inLayer:aLayer ofCanvas:aCanvas
{
    [[[self undoManager] prepareWithInvocationTarget:self] replaceColor:newColor withColor:oldColor atPoints:points inLayer:aLayer ofCanvas:aCanvas];
    [[[self undoManager] prepareWithInvocationTarget:aCanvas] changedInRect:NSMakeRect(0, 0, [aCanvas size].width, [aCanvas size].height)];
}

- (void)replaceColor:oldColor withColor:newColor atPoints:points inLayer:aLayer ofCanvas:aCanvas
{
    if([[self undoManager] isUndoing] || [[self undoManager] isRedoing]) { [self registerUndoForReplacingColor:oldColor withColor:newColor atPoints:points inLayer:aLayer ofCanvas:aCanvas]; }
    [aLayer setColor:newColor atPoints:points];
}

- (BOOL)point:(NSPoint)aPoint isUsefulForReplacing:oldColor inCanvas:aCanvas shouldCheckToTheLeft:(BOOL)check
{
    return  
	([[NSUserDefaults standardUserDefaults] boolForKey:@"PXShouldTile"] ? YES : (aPoint.y < [aCanvas size].height)) &&
	([[NSUserDefaults standardUserDefaults] boolForKey:@"PXShouldTile"] ? YES : (aPoint.y >= 0)) &&
	([[aCanvas colorAtPoint:aPoint] isEqual:oldColor] &&
	(check ? ![[aCanvas colorAtPoint:NSMakePoint(aPoint.x-1, aPoint.y)] isEqual:oldColor] : YES) &&
	([aCanvas canDrawAtPoint:aPoint]));
}

- (void)lookAround:(NSPoint)currentPoint inCanvas:aCanvas replacingColor:oldColor shouldCheckToTheLeft:(BOOL)check newPointsInto:points
{
    NSPoint upPoint = NSMakePoint(currentPoint.x, currentPoint.y+1);
    if([self point:upPoint isUsefulForReplacing:oldColor inCanvas:aCanvas shouldCheckToTheLeft:check])
    {
        [points addObject:[PXPoint withNSPoint:upPoint]];
    }
    NSPoint downPoint = NSMakePoint(currentPoint.x, currentPoint.y-1);
    if([self point:downPoint isUsefulForReplacing:oldColor inCanvas:aCanvas shouldCheckToTheLeft:check])
    {
        [points addObject:[PXPoint withNSPoint:downPoint]];
    }    
}

- (NSPoint)leftmostValidPointInRowOf:(NSPoint)point replacingColor:oldColor inCanvas:aCanvas
{
    NSPoint leftmost = point;
	int columnsChecked = 0;
    while(([[NSUserDefaults standardUserDefaults] boolForKey:@"PXShouldTile"] ? (columnsChecked < [aCanvas size].width) : leftmost.x >= 0) && 
		  [[aCanvas colorAtPoint:NSMakePoint(leftmost.x-1, leftmost.y)] isEqual:oldColor]) 
	{ 
		leftmost.x--; 
		columnsChecked++; 
	}
    return leftmost;
}

- drawLineStartingAtPoint:(NSPoint)currentPoint inCanvas:aCanvas replacingColor:oldColor withColor:newColor newPointsInto:points
{
    id thisTimeFilled = [[[NSMutableArray alloc] initWithCapacity:2048] autorelease];
    [self lookAround:currentPoint inCanvas:aCanvas replacingColor:oldColor shouldCheckToTheLeft:NO newPointsInto:points];
	int columnsChecked = 0;
    while(([[NSUserDefaults standardUserDefaults] boolForKey:@"PXShouldTile"] ? (columnsChecked < [aCanvas size].width) : currentPoint.x < [aCanvas size].width) && [[aCanvas colorAtPoint:currentPoint] isEqual:oldColor])
    {
        [self lookAround:currentPoint inCanvas:aCanvas replacingColor:oldColor shouldCheckToTheLeft:YES newPointsInto:points];
		if([aCanvas canDrawAtPoint:currentPoint]) { [thisTimeFilled addObject:[PXPoint withNSPoint:currentPoint]]; }
        currentPoint.x++;
		columnsChecked++;
    }
    [self activatePointWithOldColor:oldColor newColor:newColor atPoints:thisTimeFilled ofCanvas:aCanvas];
    return thisTimeFilled;
}

- (void)activatePointWithOldColor:oldColor newColor:newColor atPoints:thisTimeFilled ofCanvas:aCanvas
{
    [self replaceColor:oldColor withColor:newColor atPoints:thisTimeFilled inLayer:[aCanvas activeLayer] ofCanvas:aCanvas];
}

- (void)fillAtPoint:(NSPoint)aPoint inCanvas:aCanvas replacingColor:oldColor withColor:newColor
{
    id points = [[[NSMutableArray alloc] initWithCapacity:50000] autorelease];
    id filledPoints = [[[NSMutableArray alloc] initWithCapacity:50000] autorelease];
    [points addObject:[PXPoint withNSPoint:aPoint]];
    while([points count] > 0)
    {
        NSPoint current = [[points lastObject] pointValue];
        [points removeLastObject];
        [filledPoints addObjectsFromArray:
            [self drawLineStartingAtPoint:[self leftmostValidPointInRowOf:current replacingColor:oldColor inCanvas:aCanvas] 
                                 inCanvas:aCanvas 
                           replacingColor:oldColor 
                                withColor:newColor 
                            newPointsInto:points]];
    }
    [aCanvas changedInRect:NSMakeRect(0, 0, [aCanvas size].width, [aCanvas size].height)];
    [self registerUndoForReplacingColor:oldColor withColor:newColor atPoints:filledPoints inLayer:[aCanvas activeLayer] ofCanvas:aCanvas];
}

@end
