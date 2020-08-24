#import  <Foundation/NSBundle.h>
#import  <Foundation/NSString.h>
#import  <stdio.h>
//#import  <libc.h> /GNUstep only ???
#import  <stdlib.h>
#import  <objc/objc.h>
#import  "../common.h"
#import  "../rescale.h"
#import  "../imfunc.h"
#import  "../getpixel.h"
#import  "../WaitMessageCtr.h"
#import  "DCTscaler.h"

static int shrink(int asz, PIXmat apix)
{
	int	i, j, val;
	unsigned char *p;

	val = 0;
	for (i = 0; i < asz; i++) {
		p = apix[i];
		for (j = 0; j < asz; j++)
			val += p[j];
	}
	val /= (asz * asz);
	if (val > 255) return 255;
	return val;
}

commonInfo *makeDCTResizedMap(commonInfo *cinf, int bsz, int asz,
		unsigned char *map[], unsigned char *newmap[], BOOL wmsg)
{
	commonInfo *newinf = NULL;
	unsigned char *planes[MAXPLANE], *bufa[MAXPLANE], *bufb[MAXPLANE];
	PIXmat	apix, bpix;
	int	wida, widb;
	int	pn, i, x, y, nx, ny, ptr;
	DCTscaler *dct = nil;
	id	waitMsg = wmsg ? theWaitMsg : nil;

	planes[0] = NULL;
	bufa[0] = bufb[0] = NULL;
	if (asz % bsz == 0) {
		if (bsz > 1) asz /= bsz, bsz = 1;
		/* dct = nil */
	}else
		dct = [[DCTscaler alloc] init:bsz :asz];

	if ((newinf = (commonInfo *)malloc(sizeof(commonInfo))) == NULL)
		goto ErrEXIT;
	*newinf = *cinf;
	calcWidthAndHeight(&newinf->width, &newinf->height,
		cinf->width, cinf->height, (float)bsz / (float)asz);
	x = (cinf->width + asz - 1) / asz;
	wida = x * asz;
	widb = x * bsz;
	if (newinf->width > widb) newinf->width = widb;
	newinf->bits = 8;
	newinf->xbytes = byte_length(newinf->bits, newinf->width);
	newinf->palette = NULL;
	newinf->palsteps = 0;
	newinf->isplanar = YES;
	newinf->pixbits = 0;	/* don't care */
	newinf->alpha = NO;	/* remove Alpha */
	if (cinf->cspace == CS_Black)
		newinf->cspace = CS_White;
	if (newinf->width > MAXWidth)
		goto ErrEXIT;
	pn = (cinf->numcolors == 1) ? 1 : 3;

	if (allocImage(bufa, wida, asz, 8, pn)
	 || allocImage(bufb, widb, bsz, 8, pn))
		goto ErrEXIT;
	if (allocImage(planes, newinf->width, newinf->height, 8, pn))
		goto ErrEXIT;
	if (initGetPixel(cinf) != 0)
		goto ErrEXIT;

	resetPixel((refmap)map, 0);
	[waitMsg messageDisplay:
		NSLocalizedString(@"Resizing...", Resizing)];
	[waitMsg setProgress:(cinf->height - 1)];
	for (y = 0, ny = 0, ptr = 0; y < cinf->height; ) {
		int	z, idx;
		int	elm[MAXPLANE];
		[waitMsg progress: y];
		for (z = 0, idx = 0; z < asz; z++) { /* the last strip */
			if (++y > cinf->height) {
				int	svx = idx - wida;
				for (x = 0; x < wida; x++, idx++, svx++) {
					for (i = 0; i < pn; i++)
						bufa[i][idx] = bufa[i][svx];
				}
				continue;
			}
			for (x = 0; x < cinf->width; x++, idx++) {
				getPixelA(elm);
				for (i = 0; i < pn; i++)
					bufa[i][idx] = elm[i];
			}
			for ( ; x < wida; x++, idx++) { /* right end */
				for (i = 0; i < pn; i++)
					bufa[i][idx] = elm[i];
			}
		}
		for (i = 0; i < pn; i++) {
		    for (x = 0, nx = 0; x < cinf->width; x += asz, nx += bsz) {
			for (z = 0; z < asz; z++)
				apix[z] = &bufa[i][wida * z + x];
			for (z = 0; z < bsz; z++)
				bpix[z] = &bufb[i][widb * z + nx];
			if (dct)
				[dct DCTrescale:bpix from:apix];
			else
				bufb[i][nx] = shrink(asz, apix);
		    }
		}
		for (z = 0; z < bsz; z++) {
			if (++ny > newinf->height)
				break;
			for (i = 0; i < pn; i++)
				memcpy(&planes[i][ptr], &bufb[i][widb * z],
					newinf->width);
			ptr += newinf->width;
		}
	}
	[waitMsg resetProgress];
	[waitMsg messageDisplay: nil];

	for (i = 0; i < pn; i++)
		newmap[i] = planes[i];

	if (dct) [dct release];
	free((void *)bufa[0]);
	free((void *)bufb[0]);
	return newinf;

ErrEXIT:
	if (newinf) free((void *)newinf);
	if (dct) [dct release];
	if (planes[0]) free((void *)planes[0]);
	if (bufa[0]) free((void *)bufa[0]);
	if (bufb[0]) free((void *)bufb[0]);
	return NULL;
}

#define  DELTA		(1.0/512.0)

commonInfo *makeBilinearResizedMap(float xfactor, float yfactor, commonInfo *cinf,
		unsigned char *map[], unsigned char *newmap[])
{
	commonInfo *newinf = NULL;
	unsigned char *planes[MAXPLANE];
	float **wbuf[2];	// buffer for Bilinear
	float *w1[MAXPLANE], *w2[MAXPLANE];
	unsigned char *wrd[MAXPLANE];
	int	i, j, x, y;
	int	pn;
	int	wy;	// y-axis index of wbuf;

	pn = (cinf->numcolors == 1) ? 1 : 3;
	planes[0] = NULL;
	w1[0] = w2[0] = NULL;
	wbuf[0] = w1;
	wbuf[1] = w2;
	wrd[0] = NULL;

	if ((newinf = (commonInfo *)malloc(sizeof(commonInfo))) == NULL)
		goto ErrEXIT;
	*newinf = *cinf;
	newinf->width = (int)(cinf->width * xfactor);
	newinf->height = (int)(cinf->height * yfactor);
	if (newinf->width > MAXWidth || newinf->width <= 0
	|| newinf->height > MAXWidth || newinf->height <= 0)
		goto ErrEXIT;
	if (allocImage(wrd, cinf->width + 1, 1, 8, pn))
		goto ErrEXIT;
	for (i = 0; i < 2; i++) {
		float **wp = wbuf[i];	// w1 & w2
		wp[0] = (float *)malloc(sizeof(float) * newinf->width * pn);
		if (wp[0] == NULL)
			goto ErrEXIT;
		for (j = 1; j < pn; j++)
			wp[j] = wp[0] + newinf->width * j;
	}

	newinf->bits = 8;
	newinf->xbytes = byte_length(newinf->bits, newinf->width);
	newinf->palette = NULL;
	newinf->palsteps = 0;
	newinf->isplanar = YES;
	newinf->pixbits = 0;	/* don't care */
	newinf->alpha = NO;	/* remove Alpha */
	if (cinf->cspace == CS_Black)
		newinf->cspace = CS_White;

	if (allocImage(planes, newinf->width, newinf->height, 8, pn))
		goto ErrEXIT;
	if (initGetPixel(cinf) != 0)
		goto ErrEXIT;

	resetPixel((refmap)map, 0);
	[theWaitMsg messageDisplay:
		NSLocalizedString(@"Resizing...", Resizing)];
	[theWaitMsg setProgress:(newinf->height - 1)];
	wy = -2;
	for (y = 0; y < newinf->height; y++) {
		double mapy;
		double dif, dif2;
		int yidx, wbufidx;
		unsigned char *pp;
		float *wp1, *wp2;
		[theWaitMsg progress: y];
		mapy = y / (double)yfactor;
		yidx = (int)mapy;
		for (; wy < yidx; wy++) {
			int idx;
			int elm[MAXPLANE];
			float **wp = wbuf[0];
			wbuf[0] = wbuf[1];
			wbuf[1] = wp;
			for (idx = 0; ; ) { // Read new line
				if (getPixelA(elm) < 0) { // EOF
					wbuf[1] = wbuf[0]; // It's tricky
					break;
				}
				for (i = 0; i < pn; i++)
					wrd[i][idx] = elm[i];
				if (++idx >= cinf->width) {
					for (i = 0; i < pn; i++)
						wrd[i][idx] = elm[i];	// right edge
					break;
				}
			}
			for (x = 0; x < newinf->width; x++) {
				double mapx = x / (double)xfactor;
				int xidx = (int)mapx;
				dif = mapx - xidx;
				dif2 = (xidx + 1) - mapx;
				for (i = 0; i < pn; i++)
				    wp[i][x] = wrd[i][xidx] * dif2 + wrd[i][xidx+1] * dif;
			}
		}
		dif = mapy - yidx;
		dif2 = (yidx + 1) - mapy;
		wbufidx = -1;
		if (dif < DELTA) wbufidx = 0;
		else if (dif2 < DELTA) wbufidx = 1;
		if (wbufidx >= 0) {
			for (i = 0; i < pn; i++) {
				pp = planes[i] + y * newinf->width;
				wp1 = wbuf[wbufidx][i];
				for (x = 0; x < newinf->width; x++)
				    pp[x] = (unsigned char)(wp1[x] + 0.5);
			}
		}else {
			for (i = 0; i < pn; i++) {
				pp = planes[i] + y * newinf->width;
				wp1 = wbuf[0][i];
				wp2 = wbuf[1][i];
				for (x = 0; x < newinf->width; x++)
				    pp[x] = (unsigned char)(0.5
					+ wp1[x] * dif2 + wp2[x] * dif);
			}
		}
	}
	[theWaitMsg resetProgress];
	[theWaitMsg messageDisplay: nil];

	for (i = 0; i < pn; i++)
		newmap[i] = planes[i];
	free((void *)w1[0]);
	free((void *)w2[0]);
	free((void *)wrd[0]);
	return newinf;

ErrEXIT:
	if (w1[0]) free((void *)w1[0]);
	if (w2[0]) free((void *)w2[0]);
	if (wrd[0]) free((void *)wrd[0]);
	if (newinf) free((void *)newinf);
	if (planes[0]) free((void *)planes[0]);
	return NULL;
}
