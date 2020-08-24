//  PXCanvasView.m
//  Pixen
//
//  Created by Joe Osborn on Sat Sep 13 2003.
//  Copyright (c) 2003 Open Sword Group. All rights reserved.
//

#import "PXCanvasView.h"
#import "PXCanvas.h"
#import "PXBackground.h"
#import "PXBackgroundController.h"
#import "PXToolPaletteController.h"
#import "PXToolSwitcher.h"
#import "PXEyedropperTool.h"
#import "PXInfoPanelController.h"
#import "PXGrid.h"
#import "PXCrosshair.h"

//Taken from a man calling himself "BROCK BRANDENBERG" who is here to save the day.
#import "SBCenteringClipView.h"

#ifndef __COCOA__
#include "math.h"
#endif



@implementation PXCanvasView

- (void)rightMouseDown:event
{
    [delegate rightMouseDown:event];
}

- (void)setDelegate:aDelegate
{
    delegate = aDelegate;
}

- initWithFrame:(NSRect)rect
{
    [super initWithFrame:rect];
    zoomPercentage = 100;
    shouldDrawMainBackground = YES;
    trackingRect = -1;
	grid = [[PXGrid alloc] initWithUnitSize:NSMakeSize(1,1) color:[NSColor blackColor] shouldDraw:NO];
	crosshair = [[PXCrosshair alloc] init];
    return self;
}

- (void)dealloc
{
	[crosshair release];
	[grid release];
    [mainBackground release];
    [alternateBackground release];
    [super dealloc];
}

- (void)setCrosshair:aCrosshair
{
	[crosshair release];
	crosshair = [aCrosshair retain];
}

- (void)setMainBackground:aBackground
{
	[aBackground retain];
	[mainBackground release];
	mainBackground = aBackground;
	[self setNeedsDisplayInRect:[self visibleRect]];
}

- (void)setAlternateBackground:aBackground
{
    [aBackground retain];
    [alternateBackground release];
    alternateBackground = aBackground;
    [self setNeedsDisplayInRect:[self visibleRect]];
}

- tiledRectsAroundRect:(NSRect)initial
{
	id array = [NSMutableArray arrayWithCapacity:9];
	NSRect current = initial;
	id transformation = [self setupTransform];
	NSSize size = [transformation transformSize:[canvas size]];
	[array addObject:[NSValue valueWithRect:current]];
	current.origin.x -= size.width;
	[array addObject:[NSValue valueWithRect:current]];
	current.origin.y += size.height;
	[array addObject:[NSValue valueWithRect:current]];
	current.origin.x += size.width;
	[array addObject:[NSValue valueWithRect:current]];
	current.origin.x += size.width;
	[array addObject:[NSValue valueWithRect:current]];
	current.origin.y -= size.height;
	[array addObject:[NSValue valueWithRect:current]];
	current.origin.y -= size.height;
	[array addObject:[NSValue valueWithRect:current]];
	current.origin.x -= size.width;
	[array addObject:[NSValue valueWithRect:current]];
	current.origin.x -= size.width;
	[array addObject:[NSValue valueWithRect:current]];
	return array;
}

- (void)refreshTiles:sender
{
	NSRect srcRect = [[[timer userInfo] objectForKey:@"rect"] rectValue];
	id enumerator = [[self tiledRectsAroundRect:[self convertFromCanvasToViewRect:srcRect]] objectEnumerator];
	id current;
	while(current = [enumerator nextObject])
	{
		[self setNeedsDisplayInRect:[current rectValue]];
	}
}

- (void)setNeedsDisplayInCanvasRect:(NSRect)rect
{
	if([self shouldTile] && ((timer == nil) || ![timer isValid]))
	{
		[timer release];
		timer = [[NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(refreshTiles:) userInfo:[NSDictionary dictionaryWithObject:[NSValue valueWithRect:NSMakeRect(rect.origin.x-20, rect.origin.y-20, rect.size.width+40, rect.size.height+40)] forKey:@"rect"] repeats:NO] retain];
	}
	[self setNeedsDisplayInRect:[self convertFromCanvasToViewRect:rect]];	
}

- (void)setCanvas:aCanvas
{
    canvas = aCanvas;
	[grid setUnitSize:[aCanvas gridUnitSize]];
	[grid setColor:[aCanvas gridColor]];
	[grid setShouldDraw:[aCanvas gridShouldDraw]];
    [self sizeToCanvas];
}

- (NSRect)convertFromViewToCanvasRect:(NSRect)viewRect
{
	id transformation = [self setupTransform];
	[transformation invert];
	NSPoint floored = [self convertFromViewToCanvasPoint:viewRect.origin];
	NSSize ceiled = [transformation transformSize:viewRect.size];
	ceiled.width += 1;
	ceiled.height += 1;
	return NSMakeRect(floored.x, floored.y, ceiled.width, ceiled.height);
}

- (NSPoint)convertFromCanvasToViewPoint:(NSPoint)point
{
	id transformation = [self setupTransform];
	return [transformation transformPoint:point];
}

- (NSRect)convertFromCanvasToViewRect:(NSRect)rect
{
	id transformation = [self setupTransform];
	NSPoint origin = [transformation transformPoint:rect.origin];
	NSSize size = [transformation transformSize:rect.size];
	return NSMakeRect(origin.x, origin.y, size.width, size.height);
}

- (NSPoint)convertFromViewToCanvasPoint:(NSPoint)point
{
	id transformation = [self setupTransform];
	[transformation invert];
	NSPoint floored = [transformation transformPoint:point];
	floored.x = floorf(floored.x);
	floored.y = floorf(floored.y);
	return floored;
}

- (NSPoint)convertFromWindowToCanvasPoint:(NSPoint)location
{
	return [self convertFromViewToCanvasPoint:[self convertPoint:location fromView:nil]];
}

- (void)centerOn:(NSPoint)aPoint
{
    if(![[self superview] isKindOfClass:[NSClipView class]]) { return; }
    NSRect clipFrame = [[self superview] frame];
    [self scrollPoint:NSMakePoint(aPoint.x - clipFrame.size.width/2.0, aPoint.y - clipFrame.size.height/2.0)];
    centeredPoint = [self convertFromViewToCanvasPoint:aPoint];
}

- (BOOL)shouldTile
{
	id transformation = [self setupScaleTransform];
	return [[NSUserDefaults standardUserDefaults] boolForKey:@"PXShouldTile"] && (([transformation transformSize:[canvas size]].width < [[self superview] frame].size.width) && ([transformation transformSize:[canvas size]].height < [[self superview] frame].size.height)) && (([canvas size].width <= 256) && ([canvas size].height <= 256));
}

- (void)setShouldTile:(BOOL)newShouldTile
{
	shouldTile = newShouldTile;
	[self sizeToCanvas];
}

- (void)toggleShouldTile
{
	[self setShouldTile:!shouldTile];
}

- (void)sizeToCanvas
{
	
    if(NSEqualSizes([canvas size], NSZeroSize))
	{
		return;
	}
    transform = [self setupTransform];
    [self setFrameSize:NSMakeSize([transform transformSize:[canvas size]].width, [transform transformSize:[canvas size]].height)];
	
    if([self shouldTile])
	{
		[self setFrameSize:NSMakeSize([self frame].size.width * 3, [self frame].size.height * 3)];
	}
    [self centerOn:[self convertFromCanvasToViewPoint:centeredPoint]];
    [[self window] invalidateCursorRectsForView:self];
    [self setNeedsDisplay:YES];
}

- (float)zoomPercentage
{
    return zoomPercentage;
}

- (void)setZoomPercentage:(float)percent
{
    centeredPoint = [self convertFromViewToCanvasPoint:NSMakePoint([self visibleRect].origin.x + [self visibleRect].size.width/2, [self visibleRect].origin.y + [self visibleRect].size.height/2)];
    zoomPercentage = percent;
    [self sizeToCanvas];
}

- (BOOL)shouldDrawMainBackground
{
    return shouldDrawMainBackground;
}

- (void)setShouldDrawMainBackground:(BOOL)newShouldDrawBG
{
	if(mainBackground != alternateBackground && alternateBackground != nil)
    {
		shouldDrawMainBackground = newShouldDrawBG;
		[self setNeedsDisplay:YES];
    }
}

- grid
{
	return grid;
}

- (void)_drawRect:(NSRect)rect
{
	[transform concat];
	[canvas drawRect:[self convertFromViewToCanvasRect:rect] fixBug:NO];
	
	if ((zoomPercentage / 100.0f) * [grid unitSize].width >= 4 && (zoomPercentage / 100.0f) * [grid unitSize].height >= 4)
    {
		[grid drawRect:[self convertFromViewToCanvasRect:[self frame]]];
    }
	if (![self shouldTile])
    {
		[crosshair drawRect:[self convertFromViewToCanvasRect:[self frame]]];
    }
	[transform invert];
	[transform concat];
	[transform invert];
}

- (void)drawRect:(NSRect)rect
{
	NSLog(@"rect %",rect);
	
	[[NSGraphicsContext currentContext] setShouldAntialias:NO];
	[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationNone];
	[[NSColor lightGrayColor] set]; 
	NSRectFill(rect);
	if(canvas == nil || NSEqualSizes([canvas size], NSZeroSize)) { return; }
	transform = [self setupTransform];
	[transform concat];
	if(shouldDrawMainBackground || alternateBackground == nil) { [mainBackground drawRect:rect withinRect:[self visibleRect] withTransform:transform onCanvas:canvas]; }
	else { [alternateBackground drawRect:rect withinRect:[self visibleRect] withTransform:transform onCanvas:canvas]; }
	[transform invert];
	[transform concat];
	[transform invert];
	[self _drawRect:rect];
	if(![self shouldTile]) { return; }
	[transform translateXBy:-[canvas size].width yBy:0];
	[self _drawRect:rect];
	[transform translateXBy:0 yBy:[canvas size].height];
	[self _drawRect:rect];
	[transform translateXBy:[canvas size].width yBy:0];
	[self _drawRect:rect];
	[transform translateXBy:[canvas size].width yBy:0];
	[self _drawRect:rect];
	[transform translateXBy:0 yBy:-[canvas size].height];
	[self _drawRect:rect];
	[transform translateXBy:0 yBy:-[canvas size].height];
	[self _drawRect:rect];
	[transform translateXBy:-[canvas size].width yBy:0];
	[self _drawRect:rect];
	[transform translateXBy:-[canvas size].width yBy:0];
	[self _drawRect:rect];
}

- (NSAffineTransform *)setupScaleTransform
{
#ifndef __COCOA__
	zoomPercentage = 600;
#endif
	id transformation = [NSAffineTransform transform];
	
	[transformation scaleBy:zoomPercentage/100.0f];
	return transformation;	
}

- (NSAffineTransform *)setupTransform
{
	id transformation = [self setupScaleTransform];
	
	if([self shouldTile])
    {	
		[transformation translateXBy:[canvas size].width yBy:[canvas size].height];
    }
	return transformation;
}

- (BOOL)acceptsFirstResponder
{
    return YES;
}

- (BOOL)isOpaque
{
    return YES;
}

- (void)scrollUpBy:(int)amount
{
    [self centerOn:[self convertFromCanvasToViewPoint:NSMakePoint(centeredPoint.x, centeredPoint.y+amount)]];
}

- (void)scrollRightBy:(int)amount
{
    [self centerOn:[self convertFromCanvasToViewPoint:NSMakePoint(centeredPoint.x+amount, centeredPoint.y)]];
}

- (void)scrollDownBy:(int)amount
{
    [self centerOn:[self convertFromCanvasToViewPoint:NSMakePoint(centeredPoint.x, centeredPoint.y-amount)]];
}

- (void)scrollLeftBy:(int)amount
{
    [self centerOn:[self convertFromCanvasToViewPoint:NSMakePoint(centeredPoint.x-amount, centeredPoint.y)]];   
}

- (void)resetCursorRects
{
	//    [self addCursorRect:[self visibleRect] cursor:[NSCursor currentCursor]];
    if(trackingRect != -1) { [self removeTrackingRect:trackingRect]; }
    trackingRect = [self addTrackingRect:[self visibleRect] owner:self userData:NULL assumeInside:YES];
}

- (void)mouseEntered:event
{
	[self setShouldDrawMainBackground:YES];
}

- (void)mouseExited:event
{
	[self setShouldDrawMainBackground:NO];
}

- (void)updateCrosshairs:(NSPoint)newLocation
{
	if (![crosshair shouldDraw] || [self shouldTile]) 
    { 
		return; 
    }
	
	NSPoint oldPosition = [self convertFromCanvasToViewPoint:[crosshair cursorPosition]];
	[crosshair setCursorPosition:[self convertFromWindowToCanvasPoint:newLocation]];
	NSPoint newPosition = [self convertFromCanvasToViewPoint:[crosshair cursorPosition]];
	NSRect visibleRect = [self visibleRect];
	NSRect oldXAxis = visibleRect, oldYAxis = visibleRect, newXAxis = visibleRect, newYAxis = visibleRect;
	
	if (!(oldPosition.y < visibleRect.origin.y || oldPosition.y >= visibleRect.origin.y + visibleRect.size.height)) {
		oldXAxis.origin.y = oldPosition.y - 1;
		oldXAxis.size.height = zoomPercentage / 100 + 2;
		[self displayRect:oldXAxis];
	}
	if (!(oldPosition.x < visibleRect.origin.x || oldPosition.x >= visibleRect.origin.x + visibleRect.size.width)) {
		oldYAxis.origin.x = oldPosition.x - 1;
		oldYAxis.size.width = zoomPercentage / 100 + 2;
		[self displayRect:oldYAxis];
	}
	if (!(newPosition.y < visibleRect.origin.y || newPosition.y >= visibleRect.origin.y + visibleRect.size.height)) {
		newXAxis.origin.y = newPosition.y - 1;
		newXAxis.size.height = zoomPercentage / 100 + 2;
		[self displayRect:newXAxis];
	}
	if (!(newPosition.x < visibleRect.origin.x || newPosition.x >= visibleRect.origin.x + visibleRect.size.width)) {
		newYAxis.origin.x = newPosition.x - 1;
		newYAxis.size.width = zoomPercentage / 100 + 2;
		[self displayRect:newYAxis];
	}
}

- (void)updateInfoPanelWithMousePosition:(NSPoint)point dragging:(BOOL)dragging
{
	NSPoint cursorPoint = point;
	cursorPoint.y = [canvas size].height - cursorPoint.y - 1;
	if (cursorPoint.x < 0) { cursorPoint.x = 0; }
	if (cursorPoint.y < 0) { cursorPoint.y = 0; }
	//if (cursorPoint.x > ([canvas size].width - 1)) { cursorPoint.x = [canvas size].width - 1; }
	//if (cursorPoint.y > ([canvas size].height - 1)) { cursorPoint.y = [canvas size].height - 1; }
	if (!dragging) {
		[[PXInfoPanelController sharedInfoPanelController] setDraggingOrigin:cursorPoint];
	}
	[[PXInfoPanelController sharedInfoPanelController] setCursorPosition:cursorPoint];
	[[PXInfoPanelController sharedInfoPanelController] setColorInfo:[[[[PXToolPaletteController sharedToolPaletteController] leftSwitcher] toolWithTag:PXEyedropperToolTag] compositeColorAtPoint:point fromCanvas:canvas]]; // eeew HACK: METHOD SHOULD BE MOVED TO CANVAS
}

- (void)mouseDown:event
{
	NSLog(@"MouseDown");
	[self updateInfoPanelWithMousePosition:[self convertFromWindowToCanvasPoint:[event locationInWindow]] dragging:NO];
	NSLog(@"mouseDown to super");
#ifdef __COCOA__
	[super mouseDown:event];
#else
	NSLog(@" [NSApp keyWindow] title %@",[[NSApp keyWindow] delegate] );
	[[[NSApp keyWindow] delegate] mouseDown: event];
#endif
	
	
	
}

- (void)mouseUp:event
{
	[self updateInfoPanelWithMousePosition:[self convertFromWindowToCanvasPoint:[event locationInWindow]] dragging:NO];
	[super mouseUp:event];
}

- (void)mouseMoved:event
{
	[self updateCrosshairs:[event locationInWindow]];
	[self updateInfoPanelWithMousePosition:[self convertFromWindowToCanvasPoint:[event locationInWindow]] dragging:NO];
}

- (void)mouseDragged:event
{
	[self updateCrosshairs:[event locationInWindow]];
	[self updateInfoPanelWithMousePosition:[self convertFromWindowToCanvasPoint:[event locationInWindow]] dragging:YES];
	[super mouseDragged:event];
}

- (void)rightMouseDragged:event
{
	[self updateCrosshairs:[event locationInWindow]];
	[self updateInfoPanelWithMousePosition:[self convertFromWindowToCanvasPoint:[event locationInWindow]] dragging:YES];
	[super rightMouseDragged:event];
}

@end
