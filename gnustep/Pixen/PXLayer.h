//
//  PXLayer.h
//  Pixen-XCode
//
//  Created by Joe Osborn on Sun Jan 04 2004.
//  Copyright (c) 2004 Open Sword Group. All rights reserved.
//
#import <AppKit/AppKit.h>
@class PXImage;

@interface PXLayer : NSObject <NSCoding, NSCopying> {
	id name;
	PXImage *image;
	double opacity;
	BOOL visible;
	NSPoint origin;
	
	id layerController;
}
- initWithName:aName image:anImage;
- initWithName:aName size:(NSSize)size;
- name;
- (void)setName:aName;
- image;
- (NSSize)size;
- (void)setSize:(NSSize)aSize;
- (void)setSize:(NSSize)newSize withOrigin:(NSPoint)origin backgroundColor:(NSColor *)color;

- (double)opacity;
- (void)setOpacity:(double)opacity;

- (BOOL)visible;
- (void)setVisible:(BOOL)visible;

- (BOOL)canDrawAtPoint:(NSPoint)point;
- (NSColor *)colorAtPoint:(NSPoint)aPoint;
- (void)setColor:(NSColor *)aColor atPoint:(NSPoint)aPoint;
- (void)setColor:(NSColor *)aColor atPoints:(NSArray *)points;
- (void)replacePixelsOfColor:oldColor withColor:newColor;
- (void)moveToPoint:(NSPoint)newOrigin;
- (void)translateXBy:(float)amountX yBy:(float)amountY;
- (void)finalizeMotion;
- (void)drawRect:(NSRect)rect fixBug:(BOOL)fixBug;
- (void)transformedDrawRect:(NSRect)rect fixBug:(BOOL)fixBug;
- (void)compositeUnder:aLayer flattenOpacity:(BOOL)flattenOpacity;
- (void)flipHorizontally;
- (void)flipVertically;

- (void)setLayerController:controller;
@end
