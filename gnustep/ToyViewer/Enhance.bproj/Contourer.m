//
//  Contourer.m
//  ToyViewer
//
//  Created on Tue Jun 04 2002.
//  Copyright (c) 2002 OGIHARA Takeshi. All rights reserved.
//

#import "Contourer.h"
#import <stdlib.h>
#import "../common.h"
#import "../getpixel.h"
#import "../WaitMessageCtr.h"

static void set_factor(int num, float fac, float con);
static void contour_mono_sub(int *pix, int totalw, int *totalv);


@implementation Contourer

+ (int)opcode {
	return Contour;
}

+ (NSString *)oprString {
	return NSLocalizedString(@"Contour", Effects);
}

/* ignore clipping */
- (void)setupWith:(ToyView *)tv
{
	selected = NO;
}

- (BOOL)isMono {
	return (bright <= 0.005);
}

- (f_enhance)enhanceFunc {
	return contour_mono_sub;
}

- (t_weight)weightTabel:(int *)size
{
	static const char contourTab[] = {
		 0, -1, -1, -1,  0,
		-1, -1, -1, -1, -1,
		-1, -1,  0, -1, -1,
		-1, -1, -1, -1, -1,
		 0, -1, -1, -1,  0
	};
	*size = 2;
	return contourTab;
}

- (id)waitingMessage
{
	return [theWaitMsg messageDisplay:
		NSLocalizedString(@"Contouring...", Contouring)];
}

- (void)setFactor:(float)fval andBright:(float)bval
{
	factor = fval;
	bright = bval;
}

- (void)setContrast:(float)val {
	contrast = val;
}

- (void)prepareCommonValues:(int)num
{
	set_factor(num, factor, contrast);
}

static unsigned char *removeMap(int width, int height, const unsigned char *map)
{
	unsigned char *rmov, *rp[3];
	const unsigned char *mp;
	int x, y, rmvsz;

	rmvsz = (width + 2) * (height + 2);
	if ((rmov = calloc(rmvsz, 1)) == NULL)
		return NULL;
	mp = map;
	for (y = 0; y < height; y++) {
		rp[0] = rmov + (width + 2) * y;
		rp[1] = rp[0] + width + 2;
		rp[2] = rp[1] + width + 2;
		for (x = 0; x < width; x++) {
			int i, j;
			if (*mp++ == 255) {
			    for (i = 0, j = x; i < 3; i++, j++)
				rp[0][j]++, rp[1][j]++, rp[2][j]++;
			    rp[1][x+1] = 0; // self;
			}
		}
	}
	/* Remove isolated pairs */
	for (y = 0; y <= height; y++) {
		rp[0] = rmov + (width + 2) * y;
		rp[1] = rp[0] + width + 2;
		for (x = 0; x <= width; x++) {
			if (rp[0][x] == 7) {
				if (rp[0][x+1] == 7) {
					rp[0][x] = rp[0][x+1] = 8;
				}else if (rp[1][x] == 7) {
					rp[0][x] = rp[1][x] = 8;
				}else if (rp[1][x+1] == 7) {
					rp[0][x] = rp[1][x+1] = 8;
				}else if (x > 0 && rp[1][x-1] == 7) {
					rp[0][x] = rp[1][x-1] = 8;
				}
			}
		}
	}
	return rmov;
}

- (BOOL)makeNewPlane:(unsigned char **)newmap with:(commonInfo *)newinf
{
	const unsigned char *rp;
	unsigned char *rmov;
	int cnum, pnum, alp;
	int x, y, ptr;

	if (newinf->width < 4 ||newinf->height < 4)
		return NO;
	if (![super makeNewPlane:newmap with:newinf])
		return NO;
	rmov = removeMap(newinf->width, newinf->height, newmap[0]);
	if (rmov == NULL) {
		free(newmap[0]);
		return NO;
	}

	cnum = pnum = newinf->numcolors;
	if (cinf->alpha) alp = pnum++;
	else alp = 0;
	if ([self isMono] && cnum > 1 && alp == 0) {
		size_t	w = newinf->width * newinf->height;
		newinf->numcolors = 1;	/* Mono */
		newinf->cspace = CS_White;
		newmap[0] = (unsigned char *)realloc(newmap[0], w);
		newmap[1] = NULL;

		ptr = 0;
		for (y = 0; y < newinf->height; y++) {
		    rp = rmov + (newinf->width + 2) * (y + 1) + 1;
		    for (x = 0; x < newinf->width; x++) {
			if (rp[x] == 8)
				newmap[0][ptr] = 255;
			ptr++;
		    }
		}
	}else {
	    resetPixel((refmap)map, 0);
	    ptr = 0;
	    for (y = 0; y < newinf->height; y++) {
		int i, val;
		double v;
		int elm[MAXPLANE];
		rp = rmov + (newinf->width + 2) * (y + 1) + 1;
		for (x = 0; x < newinf->width; x++) {
		    getPixelA(elm);
		    val = newmap[0][ptr];
		    if (rp[x] == 8 || val == 255)
			for (i = 0; i < cnum; i++)
				newmap[i][ptr] = elm[i];
		    else {
			v = val / 255.0;
			for (i = 0; i < cnum; i++)
			    newmap[i][ptr] = v * (255 - (255 - elm[0]) * bright);
		    }
		    if (alp) newmap[alp][ptr] = elm[ALPHA];
		    ptr++;
		}
	    }
	}

	free(rmov);
	return YES;
}

@end


#define  Enlarge	4
#define  ScaleSize	64

static int cnum, darkness;
static float scale[ScaleSize];

static void set_factor(int num, float fac, float con)
{
	int	i, j, b;

	cnum = num;
	darkness = ScaleSize + Enlarge * (fac * 5 + 2);	// assume 0 .. 3 (default = 1)
	b = (ScaleSize / 2) * (con + 1.0);		// assume -1 .. +1
	for (i = 0; i < b; i++)
		scale[i] = 0.0;
	for (j = 0; i < ScaleSize; i++, j++)
		scale[i] = j / (double)(ScaleSize - 1);
}

static void contour_mono_sub(int *pix, int totalw, int *totalv)
{
	int	v;
	double	val;

	// should be totalw > 0 always
	v = ((double)totalv[0] / totalw + pix[0]) * Enlarge + darkness;
	val = (v >= ScaleSize) ? 1.0 : ((v < 0) ? 0.0 : scale[v]);
	pix[0] = val * 255;
}
