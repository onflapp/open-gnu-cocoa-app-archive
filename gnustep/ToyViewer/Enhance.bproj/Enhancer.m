#import "Enhancer.h"
#import <Foundation/NSObject.h>
#import <Foundation/NSBundle.h>	/* LocalizedString */
#import <stdio.h>
#import <stdlib.h>
#import <string.h>
#import <math.h>
#import "../WaitMessageCtr.h"
#import "../common.h"
#import "../getpixel.h"
#import "../imfunc.h"

static void set_factor(int num, float fac);
static void enhance_sub(int *pix, int totalw, int *totalv);


@implementation Enhancer

+ (int)opcode {
	return Enhance;
}

+ (NSString *)oprString {
	return NSLocalizedString(@"Enhance", Effects);
}

- (id)waitingMessage
{
	return [theWaitMsg messageDisplay:
		NSLocalizedString(@"Enhancing...", Enhancing)];
}


- (BOOL)isLinearFilter { return YES; }

- (f_enhance)enhanceFunc {
	return enhance_sub;
}

- (f_nonlinear)nonlinearFunc { /* Virtual */
	return (f_nonlinear)0;
}

- (t_weight)weightTabel:(int *)size
{
	static const char enhanceTab[] = {
		0, 1, 1, 1, 0,
		1, 2, 3, 2, 1,
		1, 3, 0, 3, 1,
		1, 2, 3, 2, 1,
		0, 1, 1, 1, 0
	};
	*size = 2;
	return enhanceTab;
}

- (void)setFactor:(float)value
{
	factor = value;
}

- (void)prepareCommonValues:(int)num
{
	set_factor(num, factor);
}

- (BOOL)makeNewPlane:(unsigned char **)newmap with:(commonInfo *)newinf
{
	int i, j, x, y, ptr;
	int cnum, pnum, wgtsz, wgtwd;
	int elm[MAXPLANE];
	int alp, err;
	t_weight	weight;
	f_enhance	func = (f_enhance)0;
	f_nonlinear	nlfunc = (f_nonlinear)0;
	BOOL	linear, result;
	unsigned char *nlbuffer[3];

	result = YES;
	weight = [self weightTabel: &wgtsz];
	wgtwd = wgtsz * 2 + 1;
	if ((linear = [self isLinearFilter])) {
		func = [self enhanceFunc];
		nlbuffer[0] = NULL;
	}else {
		nlfunc = [self nonlinearFunc];
		x = wgtsz * 2 + 1;
		x *= x;
		nlbuffer[0] = malloc(x * 3);
		nlbuffer[1] = nlbuffer[0] + x;
		nlbuffer[2] = nlbuffer[1] + x;
	}
	cnum = pnum = newinf->numcolors;
	if (cinf->alpha) alp = pnum++;
	else alp = 0;
	[self prepareCommonValues: cnum];

	err = allocImage(newmap, cinf->width, cinf->height + wgtsz + 1, 8, pnum);
	if (err) {
		result = NO;
		goto EXIT;
	}

	resetPixel((refmap)map, 0);
	for (y = 0; y < cinf->height; y++) {
		ptr = cinf->width * (y + wgtsz + 1);
		for (x = 0; x < cinf->width; x++) {
			getPixelA(elm);
			for (i = 0; i < cnum; i++)
				newmap[i][ptr] = elm[i];
			if (alp) newmap[alp][ptr] = elm[ALPHA];
			ptr++;
		}
	}
	if (newinf->alpha && !hadAlpha()) {
		newinf->alpha = NO;
		alp = 0;
	}

	[theWaitMsg setProgress:(cinf->height - 1)];
	for (y = 0; y < cinf->height; y++) {
	    int curp, pw, n, w;
	    int xlow, xhigh, ylow, yhigh;
	    int pix[MAXPLANE];
	    BOOL yoflag = (y < yorg || y > yend);

	    [theWaitMsg progress: y];

	    // ylow = (y > 2) ? -2 : -y;
	    // if ((yhigh = cinf->height - 1 - y) > 2) yhigh = 2;
	    ylow = (y > wgtsz) ? -wgtsz : -y;
	    if ((yhigh = cinf->height - 1 - y) > wgtsz) yhigh = wgtsz;
	    ptr = cinf->width * (y + wgtsz + 1);
	    curp = cinf->width * y;
	    for (x = 0; x < cinf->width; x++, ptr++, curp++) {
		if (alp) {
			newmap[alp][curp] = w = newmap[alp][ptr];
			if (w == AlphaTransp) {
				for (n = 0; n < cnum; n++)
					newmap[n][curp] = 255;
				continue;
			}
		}
		if (selected) {
		    BOOL oflag = (yoflag || x < xorg || x > xend);
		    if (outside != oflag) {
			for (n = 0; n < cnum; n++)
				newmap[n][curp] = newmap[n][ptr];
			continue;
		    }
		}

		xlow = (x > wgtsz) ? -wgtsz : -x;
		if ((xhigh = cinf->width - 1 - x) > wgtsz) xhigh = wgtsz;

		if (linear) {
		    int totalv[MAXPLANE];
		    int totalw;

		    for (n = 0; n < cnum; n++) {
			totalv[n] = 0;
			pix[n] = newmap[n][ptr];
		    }
		    totalw = 0;
		    for (i = ylow; i <= yhigh; i++) {
			t_weight wgtp = weight + wgtwd * (i + wgtsz);
			pw = cinf->width * (y + wgtsz + 1 + i);
			for (j = xlow; j <= xhigh; j++) {
			    if ((w = wgtp[j + wgtsz]) != 0) {
				totalw += (w > 0) ? w : -w;
				for (n = 0; n < cnum; n++)
				    totalv[n] += newmap[n][pw+x+j] * w;
			    }
			}
		    }
		    (*func)(pix, totalw, totalv);
		}else { /* non-linear */
		    int idx = 0;

		    for (i = ylow; i <= yhigh; i++) {
			t_weight wgtp = weight + wgtwd * (i + wgtsz);
			pw = cinf->width * (y + wgtsz + 1 + i);
			for (j = xlow; j <= xhigh; j++) {
			    if ((w = wgtp[j + wgtsz]) != 0) {
				for (n = 0; n < cnum; n++)
				    nlbuffer[n][idx] = newmap[n][pw+x+j];
				idx++;
			    }
			}
		    }
		    for (n = 0; n < cnum; n++)
			pix[n] = newmap[n][ptr];
		    (*nlfunc)(pix, idx, (const unsigned char **)nlbuffer);
		}

		for (n = 0; n < cnum; n++) {
			w = pix[n];
			newmap[n][curp] = (w < 0) ? 0
					: ((w > 255) ? 255 : w);
		}
	    }
	}
	[theWaitMsg resetProgress];

EXIT:
	if (nlbuffer[0]) free(nlbuffer[0]);
	return result;
}

@end

static int cnum;
static float strength;

static void set_factor(int num, float fac)
{
	cnum = num;
	strength = fac;
}

static void enhance_sub(int *pix, int totalw, int *totalv)
{
	int	n, v;

	// should be totalw > 0 always
	for (n = 0; n < cnum; n++) {
		v = totalv[n] / totalw - pix[n];
		pix[n] -= (int)(strength * v + 0.5);
	}
}
