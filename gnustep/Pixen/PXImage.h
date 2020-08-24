//  PXImage.h
//  Pixen
//
//  Created by Joe Osborn on Thu Sep 11 2003.
//  Copyright (c) 2003 Open Sword Group. All rights reserved.
//

#import <AppKit/AppKit.h>

@interface PXImage : NSObject <NSCopying> {
    id pixelsByColor, pixelsByPosition, palettes;
	id currentPaletteName;
	
	NSColor ** colors;
	NSRect * rects;
    NSSize size;
	unsigned int width;
	unsigned int height;
}
- (NSPoint)correct:(NSPoint)aPoint;

- initWithSize:(NSSize)aSize;
- (NSSize)size;
- (void)setSize:(NSSize)newSize withOrigin:(NSPoint)origin backgroundColor:(NSColor *)color;
- (void)setSize:(NSSize)aSize;
- pixelOfColor:(NSColor *)aColor;
- (BOOL)containsPoint:(NSPoint)point;
- pixelAtPoint:(NSPoint)aPoint;
- pixelAtX:(unsigned int)x y:(unsigned int)y;
- (void)setPixel:aPixel atPoint:(NSPoint)aPoint;
- (void)setPixel:aPixel atPoints:(NSArray *)points;

- (void)flipHorizontally;
- (void)flipVertically;

- (NSColor *)colorAtPoint:(NSPoint)aPoint;
- (NSColor *)colorAtX:(unsigned int)x y:(unsigned int)y;
- (void)setColor:(NSColor *)aColor atPoint:(NSPoint)aPoint;
- (void)setColor:(NSColor *)aColor atPoints:(NSArray *)points;
- (void)replacePixelsOfColor:oldColor withColor:newColor;

- (void)drawRect:(NSRect)rect withOpacity:(double)anOpacity fixBug:(BOOL)fixBug;

- (void)compositeUnder:anImage;

- (void)translateXBy:(float)amountX yBy:(float)amountY;

@end


@interface PXImage(Archiving) <NSCoding>

- initWithCoder:coder;
- (void)encodeWithCoder:coder;

- legacyDiscoverPixelsByPositionFromPositionsByPixel:positionsByPixel;
- (NSSize)legacyDiscoverSizeFromPixelsByPosition:pixels;
- legacyDiscoverPixelsByPositionMatrixFromPixelsByPositionDictionary:pixels;
- legacyInitWithCoder:coder;
@end
