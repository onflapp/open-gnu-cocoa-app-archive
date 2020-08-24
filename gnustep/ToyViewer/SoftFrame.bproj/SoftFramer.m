#import "SoftFramer.h"
#import <AppKit/NSApplication.h>
#import <AppKit/NSImage.h>
#import <AppKit/NSBitmapImageRep.h>
#import <AppKit/NSControl.h>
#import <AppKit/NSPanel.h>
#import <AppKit/NSColor.h>
#import <stdio.h>
#import <stdlib.h>
#import <string.h>
//#import <libc.h> //GNUstep only ???
#import <math.h>
#import "../TVController.h"
#import "../ToyWin.h"
#import "../ToyWinEPS.h"
#import "../ToyView.h"
#import "../common.h"
#import "../imfunc.h"
#import "../getpixel.h"
#import "../AlertShower.h"
#import "../WaitMessageCtr.h"

#define  BzBriteU	100
#define  BzBriteL	70
#define  BzDarkR	80	/* they all should differ each other */
#define  BzDarkD	120	/* they may not be equal to 0 or 255 */

@implementation SoftFramer

#ifdef NONLINEAR
#define  TAB_SIZE	(256*4)
static unsigned short curve[TAB_SIZE + 1];

+ (void)initialize
{
	int x, y;

	for (x = 0; x <= TAB_SIZE/2; x++)
		curve[x] = (int)(128.0 * pow((double)x / (TAB_SIZE/2), 1.25));
        for (x = 0, y = TAB_SIZE; y > x; x++, y--)
                curve[y] = 256 - curve[x];
}
#endif

+ (int)opcode {
	return SoftFrame;
}

+ (NSString *)oprString {
	return NSLocalizedString(@"Frame", Effects);
}

- (id)waitingMessage
{
	return nil;
}

- (BOOL)isColorful:(int *)clr
{
	int	i, d;

	for (i = 0; i < 3; i++) {
		d = clr[i % 3] - clr[(i+1) % 3];
		if (d > 5 || d < -5)
			return YES;
	}
	return NO;
}

- (BOOL)isColorImageMade
{
	if (cinf->numcolors >= 3)
		return YES;
	if (!useAlpha)
		return [self isColorful:bgcolor];
	return NO;
}

- (void)setFrame:(int)sval bgColor:(int *)color withAlpha:(BOOL)alpf
{
	int	i;

	shape = sval;
	for (i = 0; i < MAXPLANE; i++)
		bgcolor[i] = color[i];
	useAlpha = alpf;
}

- (void)setFrameRatio:(float)rval { ratio = rval; }

- (void)setFrameWidth:(int)wid {
	ratio = 0.0;
	sq_width = wid;
}

- (commonInfo *)makeNewInfo
{
	commonInfo *newinf;
	int x;

	if ((newinf = [super makeNewInfo]) == NULL)
		return NULL;
	if (cinf->bits <= 4) {
		newinf->bits = 4;
		newinf->xbytes = byte_length(newinf->bits, newinf->width);
	}
	newinf->alpha = useAlpha;

	x = (cinf->width > cinf->height) ? cinf->height : cinf->width;
	if (shape == S_Oval) {
		ov_x = cinf->width / 2.0;
		ov_y = cinf->height / 2.0;
		if (ratio == 0.0) {
			ratio = (float)sq_width / (float)x;
			if (ratio > 0.5) ratio = 0.5;
		}
		t_rad = 1.0 - ratio * 2.0;
	}else {
		if (ratio == 0.0) { /* sq_width is given */
		    if (shape == S_RoundRect) {
			if (sq_width >= (x+3) / 4) {
				t_rad = 1.0 - (sq_width * 2.0) / x;
				if (t_rad < 0.0) t_rad = 0.0;
				sq_width = x * 0.5;
			}else
				t_rad = 0.5;
		    }else /* Rect and Bezel */
			t_rad = 0.0;
		}else {
		    if (shape == S_RoundRect) {
			if (ratio >= 0.25) {
				sq_width = x * 0.5;
				t_rad = 1.0 - ratio * 2.0;
			}else {
				sq_width = x * ratio * 2.0;
				t_rad = 0.5;
			}
		    }else { /* Rect and Bezel */
			sq_width = x * ratio;
			t_rad = 0.0;
		    }
		}
		sq_x = cinf->width - sq_width;
		sq_y = cinf->height - sq_width;
	}

	if ([self isColorImageMade]) {
		newinf->cspace = CS_RGB;
		newinf->numcolors = 3;
	}else {
		newinf->cspace = CS_White;
		newinf->numcolors = 1;
	}

	return newinf;
}

/* Local Method */
- (int)sfTransp:(int)ax :(int)ay
{
	double v, w;
	int x, y, n;

	switch (shape) {
	case S_BezelConvex:
	case S_BezelConcave:
		return AlphaOpaque;	/* Never */
	case S_Oval:
		w = (ax - ov_x) / ov_x;
		v = (ay - ov_y) / ov_y;
		v = w * w + v * v;
		break;
	default:
		x = (ax < sq_width) ? (sq_width - 1 - ax) : (ax - sq_x);
		y = (ay < sq_width) ? (sq_width - 1 - ay) : (ay - sq_y);
		if (x < 0 && y < 0)
			return AlphaOpaque;
		if (shape == S_Rect)
			v = (x >= y) ? (x * x) : (y * y);
		else { /* S_RoundRect */
			if (x < 0) x = 0;
			else if (y < 0) y = 0;
			v = x * x + y * y;
		}
		v /= (double)(sq_width * sq_width);
		break;
	}
	if (t_rad != 0.0) {
		if ((v -= t_rad) < 0.0)
			return AlphaOpaque;
		v /= 1.0 - t_rad;
	}
	if (useAlpha)
		return ((int)(v * 0xffff) > (random() & 0xffff))
			? AlphaTransp : AlphaOpaque;

#ifdef NONLINEAR
	n = TAB_SIZE * (1.0 - v);
	n = (n < 0) ? 0 : ((n >= TAB_SIZE) ? (TAB_SIZE-1) : n);
	return curve[n];
#else
	n = 255 * (1.0 - v);
	return (n < 0) ? 0 : ((n > 255) ? 255 : n);
#endif
}

- (BOOL)makeNewPlane:(unsigned char **)newmap with:(commonInfo *)newinf
{
	int pn, alp, cn;
	int x, y, i;
	int elm[MAXPLANE], ptr, av = 0;
	unsigned char *working[MAXPLANE];

	working[0] = newmap[0] = NULL;
	pn = cn = newinf->numcolors;
	if (useAlpha)
		alp = pn++;
	else alp = 0;	/* not used */

	if (allocImage(working, newinf->width, newinf->height, 8, pn))
		return NO;
	resetPixel((refmap)map, 0);
	if (useAlpha)
	    for (y = 0; y < newinf->height; y++) {
		ptr = newinf->width * y;
		for (x = 0; x < newinf->width; x++) {
		    getPixel(&elm[RED], &elm[GREEN], &elm[BLUE], &elm[ALPHA]);
		    if (elm[ALPHA] == AlphaTransp
			|| (av = [self sfTransp:x:y]) == AlphaTransp) {
			for (i = 0; i < cn; i++)
			    working[i][ptr + x] = 0xff;
			working[alp][ptr + x] = AlphaTransp;
		    }else {
			for (i = 0; i < cn; i++)
			    working[i][ptr + x] = elm[i];
			working[alp][ptr + x] = (elm[ALPHA] < av) ? elm[ALPHA] : av;
		    }
		}
	    }
	else if (shape == S_BezelConvex || shape == S_BezelConcave)
	    for (y = 0; y < newinf->height; y++) {
		ptr = newinf->width * y;
		for (x = 0; x < newinf->width; x++) {
		    static const int bgbrite[] = { 255, 255, 255 };
		    static const int bgdark[] = { 0, 0, 0 };
		    static const int *bgp;
		    int	w;
		    getPixel(&elm[RED], &elm[GREEN], &elm[BLUE], &elm[ALPHA]);
		    av = AlphaOpaque;
		    if (x < sq_width && x < y && x < newinf->height - 1 - y)
			av = BzBriteL;
		    else if (x >= sq_x && (w = newinf->width - 1 - x) < y
				&& w < newinf->height - 1 - y)
			av = BzDarkR;
		    else if (y < sq_width)
			av = BzBriteU;
		    else if (y >= sq_y)
			av = BzDarkD;
		    if (av > elm[ALPHA])
		    	av = elm[ALPHA];
		    bgp = bgcolor;
		    if (av == BzBriteU || av == BzBriteL)
		    	bgp = (shape == S_BezelConvex) ? bgbrite : bgdark;
		    else if (av == BzDarkD || av == BzDarkR)
		    	bgp = (shape == S_BezelConvex) ? bgdark : bgbrite;
		    compositeColors(elm, bgp, av);
		    for (i = 0; i < cn; i++)
			working[i][ptr + x] = elm[i];
		}
	    }
	else
	    for (y = 0; y < newinf->height; y++) {
		ptr = newinf->width * y;
		for (x = 0; x < newinf->width; x++) {
		    getPixel(&elm[RED], &elm[GREEN], &elm[BLUE], &elm[ALPHA]);
		    if ((av = [self sfTransp:x:y]) > elm[ALPHA])
		    	av = elm[ALPHA];
		    compositeColors(elm, bgcolor, av);
		    for (i = 0; i < cn; i++)
			working[i][ptr + x] = elm[i];
		}
	    }

	if (newinf->bits < 8) {
		if (allocImage(newmap, newinf->width, newinf->height,
				newinf->bits, pn)) {
			free((void *)working[0]);
			return NO;
		}
		packWorkingImage(newinf, pn, working, newmap);
		free((void *)working[0]);
	}else {
		for (i = 0; i < MAXPLANE; i++)
			newmap[i] = working[i];
	}
	return YES;
}

@end
