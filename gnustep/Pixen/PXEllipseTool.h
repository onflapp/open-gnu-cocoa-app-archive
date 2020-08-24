//
//  PXEllipseTool.h
//  Pixen-XCode
//
//  Created by Ian Henderson on Wed Mar 10 2004.
//  Copyright (c) 2004 Open Sword Group. All rights reserved.
//

#import "PXLinearTool.h"


@interface PXEllipseTool : PXLinearTool {
}

- (void)mouseDownAt:(NSPoint)aPoint fromCanvasController:controller;
- (void)drawPixelAtPoint:(NSPoint)aPoint withColor:(NSColor *)specialColor inCanvas:aCanvas; //should probably be put into PXPencilTool
- (void)plotFilledEllipseInscribedInRect:(NSRect)bound withLineWidth:(int)borderWidth withFillColor:(NSColor *)fillColor inCanvas:canvas;
- (void)plotUnfilledEllipseInscribedInRect:(NSRect)bound withLineWidth:(int)borderWidth inCanvas:canvas;

@end
