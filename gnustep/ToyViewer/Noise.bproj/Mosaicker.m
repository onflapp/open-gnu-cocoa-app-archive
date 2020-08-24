#import "Mosaicker.h"
#import <AppKit/NSApplication.h>
#import <AppKit/NSImage.h>
#import <AppKit/NSBitmapImageRep.h>
#import <AppKit/NSControl.h>
#import <AppKit/NSPanel.h>
#import <stdio.h>
#import <stdlib.h>
#import <string.h>
//#import <libc.h> GNUstep only ???
#import "../TVController.h"
#import "../ToyWin.h"
#import "../ToyView.h"
#import "../AlertShower.h"
#import "../imfunc.h"
#import "../getpixel.h"
#import "../ColorMap.h"


@implementation Mosaicker

+ (int)opcode {
	return Mosaic;
}

+ (NSString *)oprString {
	return NSLocalizedString(@"Mosaic", Effects);
}

- (id)init
{
	[super init];
	colormap = nil;
	return self;
}

- (void)dealloc
{
	[colormap release];
	[super dealloc];
}

- (void)setGranularity:(int)val
{
	granul = val;
}

- (commonInfo *)makeNewInfo
{
	commonInfo *newinf = [super makeNewInfo];
	if (newinf == NULL)
		return NULL;
	if (cinf->bits <= 4) {
		newinf->bits = 4;
		newinf->xbytes = byte_length(newinf->bits, newinf->width);
	}
	if (cinf->palette && cinf->palsteps >= 16) {
		newinf->palsteps = cinf->palsteps;
		newinf->palette = copyPalette(cinf->palette, cinf->palsteps);
		colormap = [[ColorMap alloc] init];
		if ([colormap mallocForFullColor] == nil) {
			free((void *)newinf);
			return NULL;
		}
		[colormap regGivenPal:newinf->palette colors:newinf->palsteps];
	}
	return newinf;
}

- (BOOL)makeNewPlane:(unsigned char **)newmap with:(commonInfo *)newinf
{
	int elm[MAXPLANE];
	int pn, alp, cn;
	int x, y, i, ptr;
	unsigned char *working[MAXPLANE];

	working[0] = newmap[0] = NULL;
	pn = cn = (newinf->numcolors == 1) ? 1 : 3;
	if (newinf->alpha) alp = pn++;
	else alp = 0;
	if (allocImage(working, newinf->width, newinf->height, 8, pn))
		return NO;	/* return immediately */
	resetPixel((refmap)map, 0);
	for (y = 0; y < newinf->height; y++) {
		ptr = newinf->width * y;
		for (x = 0; x < newinf->width; x++, ptr++) {
			getPixelA(elm);
			for (i = 0; i < cn; i++)
				working[i][ptr] = elm[i];
			if (alp)
				working[alp][ptr] = elm[ALPHA];
		}
	}
	if (alp && !hadAlpha()) {
		newinf->alpha = NO;
		alp = 0;
	}

	if (!selected) {
		xorg = yorg = 0;
		xend = newinf->width;
		yend = newinf->height;
	}
	for (y = yorg; y < yend; y += granul) {
	    for (x = xorg; x < xend; x += granul) {
		int	ix, iy, ex, ey, pp, cnt, sum[3];

		ptr = newinf->width * y + x;
		ey = newinf->height - y;
		if (ey > granul) ey = granul;
		ex = newinf->width - x;
		if (ex > granul) ex = granul;
		cnt = 0;
		for (i = 0; i < cn; i++)
		    sum[i] = 0;
		for (iy = 0; iy < ey; iy++) {
		    pp = ptr + iy * newinf->width;
		    for (ix = 0; ix < ex; ix++, pp++) {
			if (alp && working[alp][pp] == AlphaTransp)
			    continue;
			for (i = 0; i < cn; i++)
			    sum[i] += working[i][pp];
			cnt++;
		    }
		}
		if (cnt > 0) {
		    for (i = 0; i < cn; i++)
			sum[i] /= cnt;
		    if (colormap) {
			int idx;
			if (cn < 3)
				sum[GREEN] = sum[BLUE] = sum[RED];
			idx = getBestColor(sum[RED], sum[GREEN], sum[BLUE]);
			for (i = 0; i < cn; i++)
			    sum[i] = newinf->palette[idx][i];
		    }
		    for (iy = 0; iy < ey; iy++) {
			pp = ptr + iy * newinf->width;
			for (ix = 0; ix < ex; ix++, pp++) {
			    if (alp && working[alp][pp] == AlphaTransp)
				continue;
			    for (i = 0; i < cn; i++)
				working[i][pp] = sum[i];
			}
		    }
		}
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
