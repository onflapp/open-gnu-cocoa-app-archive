//  PXPencilTool.h
//  Pixen
//
//  Created by Joe Osborn on Tue Sep 30 2003.
//  Copyright (c) 2003 Open Sword Group. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PXTool.h"

@interface PXPencilTool : PXTool {
    id color;
	
	BOOL shiftDown;
}
- (void)mouseDownAt:(NSPoint)aPoint fromCanvasController:controller;
- (void)mouseDraggedFrom:(NSPoint)origin to:(NSPoint)destination fromCanvasController:controller;
- (void)mouseUpAt:(NSPoint)point fromCanvasController:controller;
- (void)drawWithOldColor:(NSColor *)oldColor newColor:(NSColor *)newColor atPoint:(NSPoint)aPoint inLayer:aLayer ofCanvas:aCanvas;
- (void)drawPixelAtPoint:(NSPoint)aPoint inCanvas:aCanvas;
- (void)drawLineFrom:(NSPoint)initialPoint to:(NSPoint)finalPoint inCanvas:canvas;
- (void)setColor:aColor;
- color;
@end
