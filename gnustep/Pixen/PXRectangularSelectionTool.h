//
//  PXRectangularSelectionTool.h
//  Pixen-XCode
//
//  Created by Joe Osborn on Sun Jan 04 2004.
//  Copyright (c) 2004 Open Sword Group. All rights reserved.
//

#import "PXTool.h"

@interface PXRectangularSelectionTool : PXTool {
	NSPoint origin;
	NSRect selectedRect, lastSelectedRect;
	BOOL isMoving;
	BOOL isAdding;
	BOOL isSubtracting;
	BOOL isClicking;
	int oldLayerIndex;
	int oldLastLayerIndex;
}
- (void)mouseDownAt:(NSPoint)aPoint fromCanvasController:controller;
- (void)mouseDraggedFrom:(NSPoint)origin to:(NSPoint)destination fromCanvasController:controller;
- (void)startMovingCanvas:canvas;
- (void)stopMovingCanvas:canvas;
- (void)setLayers:layers fromLayers:oldLayers ofCanvas:canvas;
@end
