//
//  PXCanvasResizeView.h
//  Pixen-XCode
//
//  Created by Ian Henderson on Wed Jun 09 2004.
//  Copyright (c) 2004 Open Sword Group. All rights reserved.
//

#import <AppKit/AppKit.h>


@interface PXCanvasResizeView : NSView {
	NSSize oldSize;
	NSSize newSize;
	NSPoint position;
	NSImage *cachedImage;
	NSColor *backgroundColor;
	
	NSTimer *guideDisappearTimer;
	NSAffineTransform *scaleTransform;
	BOOL drawingArrows;
}

- (NSSize)newSize;
- (NSPoint)position;

- (void)setBackgroundColor:(NSColor *)color;
- (void)setCachedImage:(NSImage *)cachedImage;
- (void)setNewImageSize:(NSSize)newSize;
- (void)setOldImageSize:(NSSize)oldSize;

@end
