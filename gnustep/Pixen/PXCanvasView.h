//  PXCanvasView.h
//  Pixen
//
//  Created by Joe Osborn on Sat Sep 13 2003.
//  Copyright (c) 2003 Open Sword Group. All rights reserved.
//

#import <AppKit/AppKit.h>

@class PXCanvas;
@interface PXCanvasView : NSView {
    PXCanvas * canvas;
    id mainBackground, alternateBackground;
	id grid, crosshair;
    NSAffineTransform * transform;
    float zoomPercentage;
    NSPoint centeredPoint;
    BOOL shouldDrawMainBackground;
    
    NSTrackingRectTag trackingRect;
    
    id delegate;

	id timer;
	BOOL shouldTile;
}
- (void)setDelegate:aDelegate;
- (void)setCrosshair:aCrosshair;
- initWithFrame:(NSRect)rect;
- (float)zoomPercentage;
- (void)setZoomPercentage:(float)percent;
- (void)setCanvas:aCanvas;
- (NSPoint)convertFromCanvasToViewPoint:(NSPoint)point;
- (NSRect)convertFromCanvasToViewRect:(NSRect)rect;
- (NSPoint)convertFromViewToCanvasPoint:(NSPoint)point;
- (NSPoint)convertFromWindowToCanvasPoint:(NSPoint)location;
- (void)setNeedsDisplayInCanvasRect:(NSRect)rect;
- (void)sizeToCanvas;
- (void)centerOn:(NSPoint)aPoint;
- (NSAffineTransform *)setupTransform;
- (NSAffineTransform *)setupScaleTransform;

- (void)setMainBackground:aBackground;
- (void)setAlternateBackground:aBackground;

- (void)scrollUpBy:(int)amount;
- (void)scrollRightBy:(int)amount;
- (void)scrollDownBy:(int)amount;
- (void)scrollLeftBy:(int)amount;

- (void)setShouldDrawMainBackground:(BOOL)newShouldDraw;
- grid;
- (BOOL)shouldTile;
- (void)setShouldTile:(BOOL)newShouldTile;
- (void)toggleShouldTile;

@end
