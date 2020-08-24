//
//  PXMoveTool.m
//  Pixen-XCode
//
//  Created by Andy Matuschak on Fri Feb 27 2004.
//  Copyright (c) 2004 Open Sword Group. All rights reserved.
//

#import "PXMoveTool.h"
#import "PXCanvasController.h"
#import "PXCanvas.h"
#import "PXLayer.h"


@implementation PXMoveTool

- (NSString *)name
{
	return NSLocalizedString(@"MOVE_NAME", @"Move Tool");
}

- actionName
{
	return NSLocalizedString(@"MOVE_ACTION", @"Moving");
}

- (void)mouseDownAt:(NSPoint)aPoint fromCanvasController:controller
{
	[[self undoManager] beginUndoGrouping];
	[[self undoManager] setActionName:[self actionName]];
	[self setLayers:[[[controller canvas] layers] deepMutableCopy] fromLayers:[[controller canvas] layers] ofCanvas:[controller canvas]];	
}

- (void)setLayers:layers fromLayers:oldLayers ofCanvas:canvas
{
	[[[self undoManager] prepareWithInvocationTarget:self] setLayers:oldLayers fromLayers:layers ofCanvas:canvas];
	[canvas setLayers:layers];
}

- (void)mouseDraggedFrom:(NSPoint)initialPoint to:(NSPoint)finalPoint fromCanvasController:controller
{
	[[[controller canvas] activeLayer] translateXBy:(finalPoint.x - initialPoint.x) yBy:(finalPoint.y - initialPoint.y)];
	[[controller canvas] changedInRect:NSMakeRect(0,0,[[controller canvas] size].width,[[controller canvas] size].height)];
}

- (void)mouseUpAt:(NSPoint)aPoint fromCanvasController:controller
{
	[[[controller canvas] activeLayer] finalizeMotion];
	[[self undoManager] endUndoGrouping];
}

/*
+ (void)offsetLayer:layer inCanvas:canvas byAmount:(NSPoint)amount
{
	id object = [[[self alloc] init] autorelease];
	[[object undoManager] beginUndoGrouping];
	[[object undoManager] setActionName:[self actionName]];
	[object setLayers:[[canvas layers] deepMutableCopy] fromLayers:[canvas layers] ofCanvas:canvas];
	[layer translateXBy:amount.x yBy:amount.y];
	[canvas changedInRect:NSMakeRect(0,0,[canvas size].width,[canvas size].height)];
	[layer finalizeMotion];
	[[object undoManager] endUndoGrouping];
}
*/

@end
