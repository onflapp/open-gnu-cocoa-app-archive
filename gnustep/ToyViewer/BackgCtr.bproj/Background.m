/*
	Background.m
		based on "Background"
		by Scott Hess and Andreas Windemut (1991)
	ver.2.0 1997-12-31  by T. Ogihara
	ver.3.1 1999-04-10  by T. Ogihara
	ver.4.0 2001-04-15  by T. Ogihara
*/

#import "Background.h"
#import <AppKit/NSApplication.h>
#import <AppKit/NSImage.h>
#import <AppKit/NSControl.h>
#import <AppKit/NSScreen.h>
#import <AppKit/NSColor.h>
#import <AppKit/NSBezierPath.h>
#import <Foundation/NSData.h>
#import "FullScreenWindow.h"
#import "backgops.h"
#import "../PrefControl.h"

#define  Bright(r, g, b)	(((r)*30 + (g)*59 + (b)*11 + 50) / 100)
#define  TooLargeRatio	2.2

enum { backgMONO, backgCOLOR };	/* bgDepth */

/* class variable */
static NSRect screenRect;

static int	bgDepth;


@implementation Background

+ (void)initialize
{
	NSScreen *sc = [NSScreen mainScreen];
        NSWindowDepth depth;

	screenRect.size = [sc frame].size;
	screenRect.origin.x = screenRect.origin.y = 0;
	depth = [sc depth];
	bgDepth = (NSNumberOfColorComponents(NSColorSpaceFromDepth(depth)) <= 2)
			? backgMONO : backgCOLOR;
}

+ (NSRect)screenRect {
	return screenRect;
}

- (id)init
{
	[super initWithFrame:screenRect];
	cache = nil;
	isfront = NO;
	return self;
}

- (void)dealloc
{
	[cache release];
	[super dealloc];
}


/* Local Method */
- (void)getDafaultBGColor
{
	[[PrefControl sharedPref] backgroungColor:bgColor];
	if (bgDepth == backgMONO)
		bgColor[0] = Bright(bgColor[0], bgColor[1], bgColor[2]);
}

/* Local Method */
- (void)paintDefault:(NSSize)size
{
	NSRect r;
	if (bgDepth == backgMONO)
		[[NSColor colorWithCalibratedWhite:bgColor[0] alpha:1.0] set];
	else
		[[NSColor colorWithCalibratedRed:bgColor[0]
			green:bgColor[1] blue:bgColor[2] alpha:1.0] set];
	r.origin = NSZeroPoint;
	r.size = size;
	NSRectFill(r);
}

- (void)paintDefaultColor
{
	[self getDafaultBGColor];
	[self lockFocus];
	[self paintDefault: screenRect.size];
	[self unlockFocus];
}

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent
{
	return isfront;
}

- (void)setIsFront:(BOOL)flag { isfront = flag; }

- (BOOL)isFront { return isfront; }


- (void)mouseDown:(NSEvent *)event
{
	NSEventType	typ;

	typ = [event type];
	if (isfront) {
		[(FullScreenWindow *)[self window] toBehind:self];
		return;
	}
	if (typ == NSLeftMouseDown && ([event modifierFlags] & NSShiftKeyMask))
		[(FullScreenWindow *)[self window] toFront:self];
}


/* Local Method */
- (double)enlargeScale: (const NSSize *)size by: (int)method err:(int *)err
{
	double xr, yr, w, ratio = 1.0;

	if (err) *err = 0;
	xr = (double)screenRect.size.width / size->width;
	yr = (double)screenRect.size.height / size->height;
	if (method == bk_FitScreen)
		ratio = (xr < yr) ? xr : yr;
	else if (err == NULL)	/* bk_CoverScreen for Bitmap */
		ratio = (xr > yr) ? xr : yr;
	else { /* bk_CoverScreen */
		if (xr > yr) {
			w = xr * size->height / (double)screenRect.size.height;
			ratio = xr;
		}else {
			w = yr * size->width / (double)screenRect.size.width;
			ratio = yr;
		}
		if (w > TooLargeRatio) { /* Too Large */
			ratio = (xr < yr) ? xr : yr; /* bk_FitScreen */
			*err = 1;
		}
	}
	return ratio;
}

- (id)setImage:(NSImage *)backimage hasAlpha:(BOOL)alpha with:(int)method
{
	NSImage *image;
	NSSize sz, nwsz;
	NSPoint pnt;
	double	ratio = 1.0;
	int	mode;
	BOOL	large = NO;

	drawMethod = method;
	sz = [backimage size];
	if (sz.width <= 0 || sz.height <= 0)
		return self;
	if (drawMethod == bk_FitScreen || drawMethod == bk_CoverScreen) {
		ratio = [self enlargeScale:&sz by:drawMethod err:NULL];
		nwsz.width = sz.width * ratio;
		nwsz.height = sz.height * ratio;
		drawMethod = bk_Centering;
	}else
		nwsz = sz;
	/* To make size of 'image' smaller than screen */
	pnt.x = pnt.y = 0;
	if (nwsz.width > screenRect.size.width) {
		pnt.x = (screenRect.size.width - nwsz.width) / (ratio * 2.0);
		nwsz.width = screenRect.size.width;
		large = YES;
	}
	if (nwsz.height > screenRect.size.height) {
		pnt.y = (screenRect.size.height - nwsz.height) / (ratio * 2.0);
		nwsz.height = screenRect.size.height;
		large = YES;
	}

	if (large) {
		sz.width = nwsz.width / ratio;
		sz.height = nwsz.height / ratio;
	}

	image = [[NSImage allocWithZone:[self zone]] initWithSize: sz];
	if (image == NULL)
		return nil;
	[image setScalesWhenResized:YES];
	[self getDafaultBGColor];
/* { */	[image lockFocus];
	if (alpha) {
		[self paintDefault: sz];
		mode = NSCompositeSourceOver;
	}else
		mode = NSCompositeCopy;
	[backimage compositeToPoint:pnt operation:mode];
/* } */	[image unlockFocus];
	[image setSize:nwsz];
	[self makeCacheImage: image];
	[image release];

	return self;
}

- (id)setStream:(NSData *)data with:(int)method
{
	NSImage *backimage;
	NSSize	sz, nwsz;
	int	err = 0;
	id	rtn;

	backimage = [[NSImage allocWithZone:[self zone]] initWithData: data];
	if (backimage == NULL)
		return nil;
	sz = [backimage size];
	if (method == bk_FitScreen || method == bk_CoverScreen) {
		double r = [self enlargeScale:&sz by:method err:&err];
		nwsz.width = (int)(sz.width * r + 0.5);
		nwsz.height = (int)(sz.height * r + 0.5);
		method = bk_Centering;
		[backimage setScalesWhenResized:YES];
		[backimage setSize:nwsz];
	}
	rtn = [self setImage:backimage hasAlpha:YES with:method];
	[backimage release];
	return (err ? nil : rtn);
}

- (void)drawRect:(NSRect)rect
{
	[cache compositeToPoint:rect.origin
			fromRect:rect operation:NSCompositeCopy];
}

- (void)makeCacheImage:(NSImage *)image
{
	NSSize sz;
	NSPoint pnt;
	NSRect irect;
	int i, wd, ht;

	if (image == nil)
		return;
	if (cache == nil)
		cache = [[NSImage allocWithZone:[self zone]]
			initWithSize:screenRect.size];
	sz = [image size];
	if (sz.width <= 0 || sz.height <= 0)
		return;

	pnt.x = (int)((screenRect.size.width - sz.width) / 2.0);
	pnt.y = (int)((screenRect.size.height - sz.height) / 2.0);
	if (drawMethod == bk_Centering) { /* Centering */
		[cache lockFocus];
		[self paintDefault: [cache size]];
		[image compositeToPoint:pnt operation:NSCompositeCopy];
		[cache unlockFocus];
		return;
	}

	[cache lockFocus];
	if (drawMethod == bk_Tiling || sz.height >= screenRect.size.height) {
	/* Tiling */
		wd = irect.size.width = sz.width;
		ht = irect.size.height = sz.height;
	}else {
	/* Brick Work */
		wd = (int)(sz.width) / 2;
		pnt.x = -wd, pnt.y = sz.height;
		[image compositeToPoint:pnt operation:NSCompositeSourceOver];
		pnt.x = sz.width - wd;
		[image compositeToPoint:pnt operation:NSCompositeSourceOver];
		wd = irect.size.width = sz.width;
		ht = irect.size.height = sz.height * 2;
	}
	pnt.x = pnt.y = 0;
	[image compositeToPoint:pnt operation:NSCompositeSourceOver];

	irect.origin = pnt;
	for(i = wd; i < screenRect.size.width; i += wd) {
		pnt.x = i;
		NSCopyBits([self gState], irect, pnt);
	}
	pnt.x=0;
	irect.size.width = screenRect.size.width;
	for(i = ht; i < screenRect.size.height; i += ht) {
		pnt.y = i;
		NSCopyBits([self gState], irect, pnt);
	}
	[cache unlockFocus];
}

@end
