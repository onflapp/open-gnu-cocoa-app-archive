//
//  PXLinearTool.m
//  Pixen-XCode
//
//  Created by Ian Henderson on Mon Mar 15 2004.
//  Copyright (c) 2004 Open Sword Group. All rights reserved.
//

#import "PXLinearTool.h"
#import "PXCanvas.h"
#import "PXCanvasController.h"


@implementation PXLinearTool
- init
{
    [super init];
    locked = NO;
	centeredOnOrigin = NO;
    return self;
}

- (NSPoint)originWithDrawingPoint:(NSPoint)aPoint
{
	if (centeredOnOrigin) {
		//  .      *      .
		//  3      10     17
		return NSMakePoint(2*_origin.x - aPoint.x, 2*_origin.y - aPoint.y);
	}
	return _origin;
}
- (BOOL)shiftKeyDown
{
    locked = YES;
    return YES;
}

- (BOOL)shiftKeyUp
{
  locked = NO;
  return YES;
}

- (BOOL)optionKeyDown
{
	centeredOnOrigin = YES;
	return YES;
}

- (BOOL)optionKeyUp
{
	centeredOnOrigin = NO;
	return YES;
}

- (void)mouseDownAt:(NSPoint)aPoint fromCanvasController:controller
{
    _origin = aPoint;
    [super mouseDownAt:aPoint fromCanvasController:controller];
	[[self undoManager] beginUndoGrouping];
}

- (void)finalDrawFromPoint:(NSPoint)origin toPoint:(NSPoint)finalPoint inCanvas:canvas
{
    // General class, no implementation.
}

- (void)drawFromPoint:(NSPoint)origin toPoint:(NSPoint)finalPoint inCanvas:canvas
{
    // General class, no implementation.
}

- (BOOL)supportsAdditionalLocking
{
    return NO;
}

- (NSPoint)lockedPointFromUnlockedPoint:(NSPoint)unlockedPoint withOrigin:(NSPoint)origin
{
    NSPoint modifiedFinal = unlockedPoint;
    if (locked) {
		float slope = (unlockedPoint.y - origin.y) / (unlockedPoint.x - origin.x);
		if ([self supportsAdditionalLocking]) {
			if (fabs(slope) < .25) {
				modifiedFinal.y = origin.y;
				return modifiedFinal;
			} else if (fabs(slope) < .75) {
				//x=2y ((but why do we need the +1??))
				modifiedFinal.x = origin.x + (slope > 0 ? 1 : -1) * 2 * (modifiedFinal.y-origin.y) + (unlockedPoint.x > origin.x ? 1 : -1);
				return modifiedFinal;
			} else if (fabs(slope) < 1.5) {
				//x=y
				modifiedFinal.x = origin.x + (slope > 0 ? 1 : -1) * (modifiedFinal.y - origin.y);
				return modifiedFinal;
			} else if (fabs(slope) < 3) {
				//y=2x ((but why do we need the +1??))
				modifiedFinal.y = origin.y + (slope > 0 ? 1 : -1) * 2 * (unlockedPoint.x-origin.x) + (unlockedPoint.x > origin.x ? 1 : -1);
				return modifiedFinal;
			} else {
				modifiedFinal.x = origin.x;
				return modifiedFinal;
			}
		}
		if (slope < 0) { // different diagonal
			modifiedFinal.x = origin.x - (unlockedPoint.y - origin.y);
		} else {
			modifiedFinal.x = origin.x + (unlockedPoint.y - origin.y);
		}
    }
    return modifiedFinal;
}

- (void)mouseUpAt:(NSPoint)aPoint fromCanvasController:controller
{
	NSPoint origin = [self originWithDrawingPoint:[self lockedPointFromUnlockedPoint:aPoint withOrigin:_origin]];
	[[self undoManager] endUndoGrouping];
    [self finalDrawFromPoint:origin toPoint:[self lockedPointFromUnlockedPoint:aPoint withOrigin:origin] inCanvas:[controller canvas]];
    [super mouseUpAt:aPoint fromCanvasController:controller];
}

- (void)mouseDraggedFrom:(NSPoint)initialPoint to:(NSPoint)finalPoint fromCanvasController:controller
{
	NSPoint origin = [self originWithDrawingPoint:[self lockedPointFromUnlockedPoint:finalPoint withOrigin:_origin]];
    if (!NSEqualPoints(initialPoint, finalPoint)) {
		[[self undoManager] endUndoGrouping]; 
		[[self undoManager] undoNestedGroup];
        [[self undoManager] beginUndoGrouping];
		[self drawFromPoint:origin toPoint:[self lockedPointFromUnlockedPoint:finalPoint withOrigin:origin] inCanvas:[controller canvas]];
    }
}
@end
