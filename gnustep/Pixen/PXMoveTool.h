//
//  PXMoveTool.h
//  Pixen-XCode
//
//  Created by Andy Matuschak on Fri Feb 27 2004.
//  Copyright (c) 2004 Open Sword Group. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PXTool.h"

@interface PXMoveTool : PXTool
{

}

//+ (void)offsetLayer:layer inCanvas:canvas byAmount:(NSPoint)amount;

- (void)mouseDownAt:(NSPoint)aPoint fromCanvasController:controller;
- (void)mouseDraggedFrom:(NSPoint)initialPoint to:(NSPoint)finalPoint fromCanvasController:controller;
- (void)mouseUpAt:(NSPoint)aPoint fromCanvasController:controller;

- (void)setLayers:layers fromLayers:oldLayers ofCanvas:canvas;

@end
