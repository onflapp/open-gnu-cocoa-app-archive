//
//  ToyWindow.h
//  ToyViewer
//
//  Created by Takeshi OGIHARA on Sun Dec 23 2001.
//  Copyright (c) 2001 Takeshi OGIHARA. All rights reserved.
//

#import  <AppKit/NSWindow.h>

@interface ToyWindow: NSWindow
{
	NSRect	ordinaryFrame;
	BOOL	isZoomed;
}

+ (BOOL)inFrontMode;
+ (void)setZoomedWindow:(ToyWindow *)win;

/* Override */
- (id)initWithContentRect:(NSRect)contentRect styleMask:(unsigned int)styleMask
	backing:(NSBackingStoreType)backingType defer:(BOOL)flag;
- (void)setZoom:(BOOL)flag;
- (void)zoom:(id)sender;
- (BOOL)isZoomed;
- (void)cancelZoom;
- (NSRect)constrainFrameRect:(NSRect)frameRect toScreen:(NSScreen *)aScreen;
- (void)becomeMainWindow;

@end
