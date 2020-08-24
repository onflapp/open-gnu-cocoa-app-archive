//
//  PXLassoTool.h
//  Pixen-XCode
//
//  Created by Joe Osborn on Sat Jun 12 2004.
//  Copyright (c) 2004 Open Sword Group. All rights reserved.
//

#import "PXPencilTool.h"

@interface PXLassoTool : PXPencilTool {
    BOOL isMoving, isAdding, isSubtracting, isClicking;
	int oldLayerIndex, oldLastLayerIndex;
	NSPoint origin;
	id selected;
	int leftMost, rightMost, topMost, bottomMost;
	id path;
}

- (void)setLayers:layers fromLayers:oldLayers ofCanvas:canvas;
- (void)startMovingCanvas:canvas;

@end
