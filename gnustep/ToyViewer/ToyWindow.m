//
//  ToyWindow.m
//  ToyViewer
//
//  Created by Takeshi OGIHARA on Sun Dec 23 2001.
//  Copyright (c) 2001 Takeshi OGIHARA. All rights reserved.
//

#import  <AppKit/NSScreen.h>
#import "ToyWindow.h"
#import "ToyWin.h"

#define  WLevel_Front		NSPopUpMenuWindowLevel

static BOOL isClassInZoomMode = NO;
static ToyWindow *zoomedWindow = nil;
static int numOfWindow = 0;

@implementation ToyWindow

+ (BOOL)inFrontMode {
	return isClassInZoomMode;
}

+ (void)setZoomedWindow:(ToyWindow *)win
{
	ToyWindow *tmp;

	if (isClassInZoomMode) {
	    if (zoomedWindow != win) {
		if (zoomedWindow) {
			tmp = zoomedWindow;
			zoomedWindow = win;
			[tmp setZoom: NO];
		}else
			zoomedWindow = win;
	    }
	    if (win == nil)
		isClassInZoomMode = NO;
	}else {
		zoomedWindow = win;
		isClassInZoomMode = (win != nil);
	}
}

- (id)initWithContentRect:(NSRect)contentRect styleMask:(unsigned int)styleMask
	backing:(NSBackingStoreType)backingType defer:(BOOL)flag
{
	self = [super initWithContentRect:contentRect styleMask:styleMask
		backing:backingType defer:flag];
	numOfWindow++;
	isZoomed = NO;
	ordinaryFrame = [self frame];
	return self;
}

- (void)dealloc
{
	if (--numOfWindow <= 0)
		isClassInZoomMode = NO;
	if (self == zoomedWindow)
		zoomedWindow = nil;
	// Don't change isClassInZoomMode, because new main window would be set.
	[super dealloc];
}

- (void)setZoom:(BOOL)flag
{
	NSRect zrect;
	ToyWin *mydel;

	if (isZoomed == flag)
		return;
	if ((mydel = (ToyWin *)[self delegate]) == nil)
		return;	/* error */

	if (flag) {
		zrect = [mydel zoomedWindowFrame];
		ordinaryFrame = [self frame];
		isZoomed = YES;
		zrect.size = [mydel properlyResize:self toSize:zrect.size];
		[self setFrame:zrect display:YES];
		[self setLevel: WLevel_Front];
		[[self class] setZoomedWindow: self];
	}else {
		isZoomed = NO;
		if (self == zoomedWindow) /* Zoom button is clicked. */
			[[self class] setZoomedWindow: nil];
		[self setLevel: NSNormalWindowLevel];
		// [self setHasShadow:YES];
		zrect = ordinaryFrame;
		zrect.size = [mydel properlyResize:self toSize:zrect.size];
		[self setFrame:zrect display:YES];
	}
	// [super zoom: sender];
}

- (void)zoom:(id)sender
{
	[self setZoom: !isZoomed];	/* toggle */
}

- (BOOL)isZoomed { return isZoomed; }

- (void)cancelZoom
{
	if (!isZoomed) return;
	isZoomed = NO;
	isClassInZoomMode = NO;
	[self setLevel: NSNormalWindowLevel];
	// [self setHasShadow:YES];
}

- (NSRect)constrainFrameRect:(NSRect)frameRect toScreen:(NSScreen *)aScreen
{
	return (isZoomed)
	? frameRect
	: [super constrainFrameRect:frameRect toScreen:aScreen];
}
/* This class ignore constrainFrameRect:toScreen: method not to display
   title bars of windows.  A window should have a title bar to be a key
   window.
*/

- (void)becomeMainWindow
{
	if (isClassInZoomMode)
		[self setZoom: YES];
	[super becomeMainWindow];
}

@end
