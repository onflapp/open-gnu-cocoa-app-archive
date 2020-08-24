#import  "MonotoneView.h"
#import  <AppKit/NSImage.h>
#import  <AppKit/NSColor.h>
#import  <AppKit/NSBezierPath.h>
#import  "../common.h"


@implementation MonotoneView

/* Overload */
- (id)initWithFrame:(NSRect)frameRect
{
	[super initWithFrame:frameRect];
	cache = [[NSImage alloc] initWithSize: frameRect.size];
	tone = NULL;
	[self drawCache];
	return self;
}

/* Overload */
- (void)dealloc
{
	[cache release];
	[super dealloc];
}

/* Overload */
- (void)drawRect:(NSRect)r
{
	[cache compositeToPoint:(r.origin)
		fromRect:r operation:NSCompositeSourceOver];
}

- (void)drawCache
{
	const float rectHgt = 2.0;
	int	i;
	float	half, wid, hgt, y, yold, rh;

	[cache lockFocus];
	half = (wid = [self frame].size.width) / 2.0;
	rh = (hgt = [self frame].size.height) / 256.0 + 1.0;
	rh = (rh >= rectHgt) ? (int)rh : rectHgt;

	yold = -1;
	if (tone) /* if 'tone' is given, only right half is drawn */
		for (i = 0; i < 256; i++) {
			y = (int)(i * hgt / 256.0);
			if (y == yold) continue;
			[[NSColor colorWithCalibratedWhite:tone[i]/255.0 alpha:1.0] set];
			NSRectFill(NSMakeRect(half, y, half, rh));
		}
	else /* if 'tone' is not given, draws the whole view. */
		for (i = 0; i < 256; i++) {
			y = (int)(i * hgt / 256.0);
			if (y == yold) continue;
			[[NSColor colorWithCalibratedWhite:i/255.0 alpha:1.0] set];
			NSRectFill(NSMakeRect(0.0, y, wid, rh));
		}
	[cache unlockFocus]; 
}

- (void)setTone:(unsigned char *)buffer
{
	tone = buffer;
	[self drawCache]; 
}

@end
