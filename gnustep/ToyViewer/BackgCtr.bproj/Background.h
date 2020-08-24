/*
	Background.h
		based on "Background"
		by Scott Hess and Andreas Windemut (1991)
*/

#import <AppKit/NSView.h>
#import <AppKit/NSWindow.h>

@class NSImage, NSData;

@interface Background:NSView
{
	id	cache;
	int	drawMethod;
	BOOL	isfront;
	float	bgColor[3];
}

+ (void)initialize;
+ (NSRect)screenRect;

- (id)init;
- (void)dealloc;
- (void)paintDefaultColor;
- (void)setIsFront:(BOOL)flag;
- (BOOL)isFront;
- (void)mouseDown:(NSEvent *)event;
- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent;
- (id)setImage:(NSImage *)backimage hasAlpha:(BOOL)alpha with:(int)method;
- (id)setStream:(NSData *)data with:(int)method;
- (void)makeCacheImage:(NSImage *)image;
- (void)drawRect:(NSRect)r;

@end
