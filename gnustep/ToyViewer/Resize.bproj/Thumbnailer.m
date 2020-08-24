//
//  Thumbnailer.m
//  ToyViewer
//
//  Created by OGIHARA Takeshi on Tue Jan 29 2002.
//  Copyright (c) 2001 OGIHARA Takeshi. All rights reserved.
//

#import "Thumbnailer.h"
#import <Foundation/NSString.h>
#import <Foundation/NSData.h>
#import <AppKit/NSImage.h>
#import <AppKit/NSBitmapImageRep.h>
//#import <libc.h>
#import "ImageResize.h"
#import "../ToyWin.h"
#import "../ToyWinVector.h"
#import "../ToyView.h"
#import "../common.h"
#import "../imfunc.h"
#import "../getpixel.h"
#import "../AlertShower.h"
#import "../dcttable.h"
#import "DCTscaler.h"
#import "resize.h"

#define TRIM_LIMIT	0.96

@implementation Thumbnailer

/* Local Method */
- (void)setNewToyWin:(ToyWin *)tw
{
	float	hra;

	[toywin release];
	toywin = [tw retain];
	info = [[toywin toyView] commonInfo];
	factor = targetSize.width / info->width;
	hra = targetSize.height / info->height;
	if (factor > hra)
		factor = hra;
}

- (id)initWithToyWin:(ToyWin *)tw
{
	[super init];
	targetSize = NSMakeSize(128.0, 128.0);
	[self setNewToyWin: tw];
	_newinfo = NULL;
	_bitmap = NULL;
	return self;
}

- (void)dealloc
{
	[toywin release];
	if (_newinfo) free(_newinfo);
	if (_bitmap) free(_bitmap);
	[super dealloc];
}

/* Local Method */
- (BOOL)makeBitmapFromStream:(NSData *)stream
{
	ToyWin	*newwin;

	newwin = [[[ToyWin alloc] initMapOnly] autorelease];
	if ([newwin drawFromFile:[toywin filename] or:stream] != 0)
		return NO;
	[self setNewToyWin: newwin];
	return YES;
}

static commonInfo *trim(const commonInfo *cinf, NSSize sz,
	unsigned char *map[], unsigned char *newmap[])
{
	int	idx, i, x, y;
	int	xst, yst, xen, yen, pn;
	commonInfo *trinf = NULL;
	int	elm[MAXPLANE];
	unsigned char	*avgmap = NULL;

	newmap[0] = NULL;
	trinf = malloc(sizeof(commonInfo));
	*trinf = *cinf;
	trinf->alpha = NO;
	trinf->isplanar = YES;
	trinf->bits = 8;
	if (cinf->width > sz.width) {
		xst = (cinf->width - sz.width) / 2;
		xen = xst + sz.width;
		trinf->width = sz.width;
	}else
		xst = 0, xen = cinf->width;
	if (cinf->height > sz.height) {
		yst = (cinf->height - sz.height) / 2;
		yen = yst + sz.height;
		trinf->height = sz.height;
	}else
		yst = 0, yen = cinf->height;

	pn = trinf->numcolors;
	if (allocImage(newmap, trinf->width, trinf->height, 8, pn))
		goto ErrEXIT;
	if (initGetPixel(cinf) != 0)
		goto ErrEXIT;


	idx = 0;
	for (y = yst; y < yen; y++) {
		resetPixel((refmap)map, y);
		for (x = 0; x < xst; x++)
			getPixelA(elm);
		for ( ; x < xen; x++) {
			getPixelA(elm);
			for (i = 0; i < pn; i++)
				newmap[i][idx] = elm[i];
			idx++;
		}
	}

	if (trinf->width < 5 || trinf->height < 5)
		return trinf;
	if ((avgmap = malloc(trinf->width * trinf->height)) == NULL)
		goto ErrEXIT;
	for (i = 0; i < pn; i++) {
	    unsigned char *p0, *p1, *p2, *q;
	    int j, v;
	    for (y = 0; y < trinf->height - 2; y++) {
		p0 = newmap[i] + trinf->width * y;
		p1 = p0 + trinf->width;
		p2 = p1 + trinf->width;
		q = avgmap + trinf->width * (y+1) + 1;
		for (x = trinf->width - 2; x > 0; x--) {
			v = 0;
			for (j = 0; j < 3; j++)
				v += p0[j] + p1[j] + p2[j];
			v = p1[1] + 0.7 * (double)(p1[1] * 9 - v) / 8.0;
			if (v > 255) v = 255;
			else if (v < 0) v = 0;
			*q++ = v;
			p0++, p1++, p2++;
		}
	    }
	    for (y = 1; y < trinf->height - 1; y++) {
		p0 = newmap[i] + trinf->width * y + 1;
		q = avgmap + trinf->width * y + 1;
		for (x = trinf->width - 2; x > 0; x--)
			*p0++ = *q++;
	    }
	}
	free(avgmap);
	return trinf;
ErrEXIT:
	if (trinf) free(trinf);
	if (newmap[0]) free(newmap[0]);
	if (avgmap) free(avgmap);
	return NULL;
}

- (commonInfo *)makeThumbnail:(unsigned char **)thmmap
{
	unsigned char	*map[MAXPLANE], *newmap[MAXPLANE];
	commonInfo	*newinf, *trinf;
	int	idx, afr, bfr, thumbsc;
	ToyView	*tv;
	NSRect srect;
	BOOL	selected;
	NSData	*stream;

	tv = [toywin toyView];
	srect = [tv selectedRect];
	selected = (srect.size.width >= 1.0 && srect.size.height >= 1.0);
	if ((info->type == Type_eps || info->type == Type_pdf) && !selected) {
		/* Vector-type and Not Selected */
		stream = [(ToyWinVector *)toywin openTiffDataBy:factor compress:NO];
		if (stream == nil || ![self makeBitmapFromStream: stream])
			return NULL;
	}else	/* Bitmap-type or Selected */
	if (selected) {
		stream = [tv streamInSelectedRect:self];
		if (stream == nil || ![self makeBitmapFromStream: stream])
			return NULL;
	} /* else: Bitmap-type and Not Selected ... Do Nothing */

	if (factor < TRIM_LIMIT) {
	    if ([toywin getBitmap:map info:&info] != 0)
		return NULL;
	    idx = DCT_TableIndexForThumb(factor);
	    afr = DCT_ratioTable[idx].a;
	    bfr = DCT_ratioTable[idx].b;
	    thumbsc = DCT_ratioTable[idx].thumb;
	//  printf("%6.3f --> %d/%d, (%d)\n", factor, bfr, afr, thumbsc);
	    if (thumbsc > 1) {
		unsigned char *tmpmap[MAXPLANE];
		commonInfo *tmpinf;
		tmpinf = makeDCTResizedMap(info, 1, thumbsc, map, tmpmap, NO);
		newinf = makeDCTResizedMap(tmpinf,
			bfr, afr/thumbsc, tmpmap, newmap, NO);
		free(tmpmap[0]);
		free(tmpinf);
	    }else {
		newinf = makeDCTResizedMap(info, bfr, afr, map, newmap, NO);
	    }
	    _newinfo = newinf;	/* will be freed with this instance */
	    _bitmap = newmap[0];
	}else {
		if ([toywin getBitmap:newmap info:&info] != 0)
			return NULL;
		newinf = info;
	}

	if ((trinf = trim(newinf, targetSize, newmap, thmmap)) == NULL)
		return NULL;
	if (_newinfo) free(_newinfo);
	_newinfo = trinf;	/* It will be freed with this instance */
	if (_bitmap) free(_bitmap);
	_bitmap = thmmap[0];	/* It will be freed with this instance */
	[toywin freeTempBitmap];

	return trinf;
}

@end
