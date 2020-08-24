//
//  Blurrer.m
//  ToyViewer
//
//  Created on Sat Jun 08 2002.
//  Copyright (c) 2002 OGIHARA Takeshi. All rights reserved.
//

#import "Blurrer.h"
#import "../common.h"
#import "../WaitMessageCtr.h"

static void set_factor(int num, float fac);
static void blur_sub(int *, int, int *);
static void blur_nlsub(int *pix, int pixnum, const unsigned char *vals[3]);

@implementation Blurrer

+ (int)opcode {
	return Blur;
}

+ (NSString *)oprString {
	return NSLocalizedString(@"Blur", Effects);
}

- (id)waitingMessage {
	return [theWaitMsg messageDisplay:
		NSLocalizedString(@"Blurring...", Blurring)];
}


- (id)init
{
	[super init];
	tablep = NULL;
	return self;
}

- (void)dealloc
{
	if (tablep) free(tablep);
	[super dealloc];
}

- (void)setFactor:(float)value
{
	int	wid, x, y;
	int	yy, rad2, lng2, v;
	char *ptr;

	factor = value;		// assume 1 .. 10
	radius = (int)factor;
	wid = radius * 2 + 1;
	if (tablep) free(tablep);
	tablep = malloc(wid * wid);
	rad2 = radius * radius + 1;
	ptr = tablep;
	for (y = -radius; y <= radius; y++) {
		yy = y * y;
		for (x = -radius; x <= radius; x++) {
			lng2 = yy + x * x;
			if (lng2 > rad2 || lng2 == 0) v = 0;
			else {
				v = radius - sqrt((double)lng2);
				if (v <= 0) v = 1;
				// if (v > 127) v = 127;	/* max of char */
			}
			*ptr++ = v;
		}
	}

	yy = radius * wid + radius;	// center
	tablep[yy] = v = tablep[yy+1];
	if (radius > 4) {
		tablep[yy-1] = tablep[yy+1] = v - 1;
		tablep[yy-wid] = tablep[yy+wid] = v - 1;
	}

#ifdef _DEBUG
	printf("radius=%d\n", radius);
	ptr = tablep;
	for (y = -radius; y <= radius; y++) {
		for (x = -radius; x <= radius; x++)
			printf(" %3d", *ptr++);
		putchar('\n');
	}
#endif
}

- (BOOL)isLinearFilter { return YES; }

- (f_enhance)enhanceFunc { return blur_sub; }

- (f_nonlinear)nonlinearFunc { return blur_nlsub; }

- (t_weight)weightTabel:(int *)size
{
	*size = radius;
	return tablep;
}

- (void)prepareCommonValues:(int)num {
	set_factor(num, factor);
}

@end

static int cnum;

static void set_factor(int num, float fac) {
	cnum = num;
}

static void blur_sub(int *pix, int totalw, int *totalv)
{
	int	n;

	// should be totalw > 0 always
	for (n = 0; n < cnum; n++) {
		pix[n] = totalv[n] / totalw;
	}
}

static void blur_nlsub(int *pix, int pixnum, const unsigned char *vals[3])
{
#if 0
// #import <math.h>
	int	i, n;
	double	sum;

	for (n = 0; n < cnum; n++) {
		sum = 0.0;
		for (i = 0; i < pixnum; i++)
			sum += (double)(vals[n][i] * vals[n][i]);
		pix[n] = pow( sum / pixnum, 0.5 );
	}
#endif
}

// Median Filter
#if 0
	int	i, n, cnt;
	int	count[256];

	// should be totalw > 0 always
	for (n = 0; n < cnum; n++) {
		for (i = 0; i < 256; i++)
			count[i] = 0;
		for (i = 0; i < pixnum; i++)
			count[ vals[n][i] ]++;
		cnt = (pixnum + 1) / 2;
		for (i = 0; i < 256; i++)
			if ((cnt -= count[i]) <= 0)
				break;
		pix[n] = i;
	}
#endif
