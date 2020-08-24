#import  <math.h>
#import  <stdlib.h>
#import  <objc/objc.h>
#import  "common.h"
#import  "getpixel.h"
#import  <AppKit/NSColor.h>
#import  <AppKit/NSGraphics.h> //GNUstep only ??
#import  <Foundation/NSAutoreleasePool.h>

void convCMYKtoRGB(int width, int kkx, unsigned char **planes)
{
	int	x, i;
	float	k;
	id	clr, newclr;
	float	cs[3];
	NSAutoreleasePool *subpool;

	subpool = [[NSAutoreleasePool alloc] init];
	for (x = 0; x < width; x++) {
		k = kkx ? (planes[kkx][x]/255.0) : 0.0;
		clr = [NSColor colorWithDeviceCyan: planes[0][x]/255.0
			magenta:planes[1][x]/255.0
			yellow: planes[2][x]/255.0
			black:  k
			alpha:1.0];
		newclr = [clr colorUsingColorSpaceName:NSDeviceRGBColorSpace];
		[newclr getRed:&cs[0] green:&cs[1] blue:&cs[2] alpha:NULL];
		for (i = 0; i < 3; i++)
			planes[i][x] = (int)(cs[i] * 255.0);
	}
	[subpool release];
}




#if 0

#define  GammaPower	0.5

static const short conv[3][7] = {
	{ 253,   0,   0, 232, 255,   0, 255 },
	{ 176, 255,  48, 255, 180, 255, 255 },
	{   0, 214, 255, 213, 251, 255, 255 }
	/*  C,   M,   Y,  CM,  CY,  MY, CMY */
};
static float *gammaScale = NULL;
static unsigned char cmy2b[3][256];
static unsigned char b2cmy[3][256];


static void init_cmyk(void)
{
	int	i;
	double	v;

	gammaScale = (float *)malloc(sizeof(float) * 256);
	for (i = 0; i < 256; i++) {
		v = i / 255.0;
		gammaScale[i] = pow(v, GammaPower);
		b2cmy[0][i] = (int)(pow(1.0 - v, 2.0) * 255.0);
		b2cmy[1][i] = (int)(pow(1.0 - v, 5.0) * 255.0);
		v = pow(v, 0.6);
		b2cmy[2][i] = (int)(pow(1.0 - v, 1.8) * 255.0);
	}
	for (i = 0; i < 256; i++) {
		v = i / 255.0;
		cmy2b[0][i] = (int)((1.0 - pow(v, 0.5)) * 255.0);
		cmy2b[1][i] = (int)((1.0 - pow(v, 0.2)) * 255.0);
		v = pow(v, 1.0/1.8);
		cmy2b[2][i] = (int)(pow(1.0 - v, 1.0/0.6) * 255.0);
	}
}

#ifdef TESTALONE
#include <stdio.h>

main()
{
	int	i;
	init_cmyk();
	for (i = 0; i < 256; i++)
		printf("%d\t%d\t%d\t%d\t%d\t%d\n",
			b2cmy[0][i], b2cmy[1][i], b2cmy[2][i],
			cmy2b[0][i], cmy2b[1][i], cmy2b[2][i]);
}
#endif /* test */

void CMYKtoRGB(int width, int kkx, unsigned char **planes)
{
	int	x, i, j, k, m, gray, rmv;
	int	cmy[3];
	float	fcmy[3];

	if (gammaScale == NULL)
		init_cmyk();
	for (x = 0; x < width; x++) {
		/* Remove Black */
		gray = 0;
		rmv = -1;
		for (i = 0; i < 3; i++) {
			cmy[i] = planes[i][x];
			if (cmy2b[i][cmy[i]] > gray)
				rmv = i, gray = cmy2b[i][cmy[i]];
		}
		/* gray == 0 : Black */
		if (gray < 255) {
		    for (i = 0; i < 3; i++)
			cmy[i] -= b2cmy[i][gray];
		}

		/* Add All */
		for (i = 0; i < 3; i++) {
			k = 0;
			for (j = 0; j < 3; j++) {
				m = cmy[j] * conv[i][j] / 255;
				// k += m;
				if (m > k)
					k = m;
			}
			k = (255 - k) * gray;
			if (k < 0) k = 0;
			else if (k > 255) k = 255;
			planes[i][x] = k;
		}
		if ((m = planes[kkx][x]) > 0) {
			float kuro = gammaScale[255 - m];
			for (i = 0; i < 3; i++)
				planes[i][x] *= kuro;
		}
	}
}
#endif
