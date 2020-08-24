//
//  SFAqua.m
//  ToyViewer
//
//  Created on Sun Jun 23 2002.
//  Copyright (c) 2002 OGIHARA Takeshi. All rights reserved.
//

#import "SFAqua.h"
#import <Foundation/NSString.h>
#import <Foundation/NSData.h>
#import <Foundation/NSBundle.h>
#import "../common.h"
#import "../getpixel.h"
#import "../imfunc.h"

#define  AquaDATA	@"SFAqua"
#define  AquaDATASFX	@"pnm"
#define  modelRe(x)	(modelLe[x] + modelxw[x])
#define  modelDe(x)	(modelUe[x] + modelyw[x])
#define  White		0xff
#define  Black		0x00
#define  MODELS		3

enum {
	q_model = 0, q_in = 1, q_hl = 2
};

static const unsigned char *aq_dat[MODELS][3];
static const int modelSize[MODELS] = { 30, 40, 72 };
static const int modelxw[MODELS] =   {  8, 10, 16 };
static const int modelyw[MODELS] =   {  4,  6, 10 };
static const int modelLe[MODELS] =   { 11, 15, 28 };
static const int modelUe[MODELS] =   { 12, 17, 30 };


@implementation SFAqua

+ (void)initialize
{
	static NSData *aqua[MODELS];
	NSBundle *bundle, *mbun;
	NSString *path, *fnam;
	int	md, cnt, i;
	const unsigned char *p;

	if (aqua[0]) return;
	mbun = [NSBundle mainBundle];
	path = [mbun pathForResource:@"SoftFrame" ofType:@"bundle"];
	bundle = [NSBundle bundleWithPath:path];
	for (md = 0; md < MODELS; md++) {
	    fnam = [NSString stringWithFormat:@"%@%03d", AquaDATA, modelSize[md]];
	    path = [bundle pathForResource:fnam ofType:AquaDATASFX];
	    aqua[md] = [[NSData alloc] initWithContentsOfFile:path];
	    if (aqua[md] == NULL)
		continue;	// ERROR
	    p = [aqua[md] bytes];
	    /* skip header */
	    for (cnt = 3; cnt > 0; p++)
		if (*p == '\n')
			cnt--;
	    for (i = 0; i < 3; i++)
		aq_dat[md][i] = p + (modelSize[md] * modelSize[md]) * i;
	/*
	    Data file has 3 parts; shape-model, inside-mask, and highlight-mask.
	    Each has (AquaSIZE * AquaSIZE) bytes.
	*/
	}
}

- (void)setButtonColor:(int *)clr
{
	int	i;
	for (i = 0; i < 3; i++)
		buttonColor[i] = clr[i];
}

- (BOOL)isTooLarge
{
	int sz;
	double f;

	if (shape == S_AquaRect)
		return NO;
	sz = (cinf->width > cinf->height) ? cinf->width : cinf->height;
	f = (double)sz / modelSize[MODELS-1];
	return (f >= 2.5);
}

- (BOOL)isColorImageMade
{
	if (cinf->numcolors >= 3)
		return YES;
	return ([self isColorful:bgcolor] || [self isColorful:buttonColor]);
}

- (commonInfo *)makeNewInfo
{
	commonInfo *newinf;
	int	i, estim;
	static BOOL firstWarn = YES;

	if ((newinf = [super makeNewInfo]) == NULL)
		return NULL;
	if (shape == S_AquaOval && firstWarn && [self isTooLarge]) {
		NSString *title = NSLocalizedString(@"WARNING", ERROR);
		NSString *msg = NSLocalizedString(
			@"Image size is too large as Aqua-Button.", AquaTooLarge);
		NSRunAlertPanel(title, @"%@", @"", nil, nil, msg);
		firstWarn = NO;
	}
	if (shape == S_AquaRect) {
		estim = sq_width * 3;	// 0 - 13, 14 - 23, 24 - 50 ===> 30, 40, 72
	}else {
		int	lx, sx;
		if (newinf->width < newinf->height)
			sx = newinf->width,  lx = newinf->height;
		else
			lx = newinf->width,  sx = newinf->height;
		estim = (lx > sx * 2.5) ? (int)(sx * 1.3) : sx;
	}
	for (i = MODELS - 1; i > 0; i--)
		if (modelSize[i] <= estim)
			break;
	modelid = (i < 0) ? 0 : i;
	if (newinf->width < modelSize[modelid])
		newinf->width = modelSize[modelid];
	if (newinf->height < modelSize[modelid])
		newinf->height = modelSize[modelid];
	newinf->bits = 8;
	newinf->xbytes = newinf->width;
	newinf->alpha = NO;

	aq_model = aq_dat[modelid][q_model];
	aq_in = aq_dat[modelid][q_in];
	aq_hl = aq_dat[modelid][q_hl];
	return newinf;
}

#define  DELTA		(1.0/512.0)

static void bilinearRatio(double fact, double index, int bias, int *newidx, double *ratio)
{
	double	dif, mapx;
	int	xidx;

	if (fact == 1.0) {
		*newidx = index;
		*ratio = 0.0;
		return;
	}
	mapx = (index - bias) / (double)fact - 0.4;
	xidx = (int)mapx;
	dif = mapx - xidx;
	*newidx = xidx + bias;
	if (dif <= DELTA)
		dif = 0.0;
	else if (dif >= 1.0 - DELTA)
		dif = 1.0;
	*ratio = dif;
}

static int bilinearValue(const unsigned char *aq, int wid, int outer,
	int y, double ydif, int x, double xdif)
{
	double	d, yv[2];
	int	i, n, m, idx[2][2], v[2][2];

	d = 1.0 - xdif;
	i = y*wid + x;

	idx[0][0] = i;
	idx[0][1] = i + 1;
	idx[1][0] = i + wid;
	idx[1][1] = i + wid + 1;

	if (x < 0)
		idx[0][0] = idx[1][0] = -1;
	else if (x >= wid - 1)
		idx[0][1] = idx[1][1] = -1;
	if (y < 0)
		idx[0][0] = idx[0][1] = -1;
	else if (y >= wid - 1)
		idx[1][0] = idx[1][1] = -1;
	for (n = 0; n < 2; n++) {
	    for (m = 0; m < 2; m++)
		v[n][m] = (idx[n][m] >= 0) ? aq[idx[n][m]] : outer;
	    yv[n] = v[n][0] * d + v[n][1] * xdif;
	}
	return (int)(yv[0] * (1.0 - ydif) + yv[1] * ydif);
}

- (BOOL)makeNewPlane:(unsigned char **)newmap with:(commonInfo *)newinf
{
	int	cn, ptr;
	int	x, y, i, val, hval;
	int	xmgn, ymgn, xidx, yidx;
	int	elm[MAXPLANE];
	double	xratio, yratio, xdif, ydif;
	BOOL	isOval, isIn;

	if (aq_model == NULL)
		return NO;
	isOval = (shape == S_AquaOval);
	newmap[0] = NULL;
	cn = newinf->numcolors;
	if (allocImage(newmap, newinf->width, newinf->height, 8, cn))
		return NO;

	xmgn = (newinf->width - cinf->width + 1) / 2;
	ymgn = (newinf->height - cinf->height + 1) / 2;
	if (ymgn > 0 || xmgn > 0) {
		ptr = 0;
		for (y = 0; y < newinf->height; y++)
			for (x = 0; x < newinf->width; x++) {
				for (i = 0; i < cn; i++)
					newmap[i][ptr] = bgcolor[i];
				ptr++;
			}
		if (ymgn > 0) ymgn--;	/* Adjust a little */
	}
	resetPixel((refmap)map, 0);
	for (y = 0; y < cinf->height; y++) {
	    ptr = newinf->width * (ymgn + y) + xmgn;
	    for (x = 0; x < cinf->width; x++) {
		getPixel(&elm[RED], &elm[GREEN], &elm[BLUE], &elm[ALPHA]);
		for (i = 0; i < cn; i++)
			newmap[i][ptr] = elm[i];
		ptr++;
	    }
	}
	if (isOval) {
	    xratio = (double)newinf->width / (double)modelSize[modelid];
	    yratio = (double)newinf->height / (double)modelSize[modelid];
	}else {
	    xratio = (newinf->width - (modelSize[modelid] - modelxw[modelid])) / (double)modelxw[modelid];
	    yratio = (newinf->height - (modelSize[modelid] - modelyw[modelid])) / (double)modelyw[modelid];
	}

	ptr = 0;
	for (y = 0; y < newinf->height; y++) {
	    if (isOval) {
		bilinearRatio(yratio, y, 0, &yidx, &ydif);
	    }else {
		ydif = 0.0;
		if (y < modelUe[modelid]) yidx = y;
		else {
		    yidx = y - (newinf->height - (modelSize[modelid] - modelDe(modelid)));
		    if (yidx >= 0) yidx += modelDe(modelid);
		    else
			bilinearRatio(yratio, y, modelUe[modelid], &yidx, &ydif);
		}
	    }
	    for (x = 0; x < newinf->width; x++) {
		if (isOval) {
		    int	v;
		    bilinearRatio(xratio, x, 0, &xidx, &xdif);
		    v = bilinearValue(aq_in, modelSize[modelid], Black, yidx, ydif, xidx, xdif);
		    isIn = (v > 64);
		}else {
		    xdif = 0.0;
		    if (x < modelLe[modelid]) xidx = x;
		    else {
			xidx = x - (newinf->width - (modelSize[modelid] - modelRe(modelid)));
			if (xidx >= 0) xidx += modelRe(modelid);
			else
			    bilinearRatio(xratio, x, modelLe[modelid], &xidx, &xdif);
		    }
		    isIn = (aq_in[yidx * modelSize[modelid] + xidx] != 0);
		}
		val = bilinearValue(aq_model, modelSize[modelid], White, yidx, ydif, xidx, xdif);
		hval = bilinearValue(aq_hl, modelSize[modelid], Black, yidx, ydif, xidx, xdif);

		if (isIn) {
	/* Inside */
		    for (i = 0; i < cn; i++) {
			int v = newmap[i][ptr];
			if (hval != 0)	/* Highlight */
				v += (255 - v) * hval / 255;
			v = (v * val) / 255 + (255 - val);
			newmap[i][ptr] = (v * val + buttonColor[i] * ( 255 - val )) / 255;
		    }
		}else {
	/* Outside */
		    for (i = 0; i < cn; i++)
			newmap[i][ptr] = (bgcolor[i] * val + buttonColor[i] * ( 255 - val )) / 255;
		}
		ptr++;
	    }
	}
	return YES;
}

@end
