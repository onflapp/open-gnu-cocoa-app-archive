#import "ImageOpr.h"
#import <AppKit/NSApplication.h>
#import <AppKit/NSEPSImageRep.h>
#import <AppKit/NSBitmapImageRep.h>
#import <AppKit/NSControl.h>
#import <AppKit/NSPanel.h>
#import <stdio.h>
#import <stdlib.h>
#import <string.h>
#import "../TVController.h"
#import "../ToyWin.h"
#import "../ToyWinEPS.h"
#import "../ToyView.h"
#import "../PrefControl.h"
#import "../AlertShower.h"
#import "../common.h"
#import "../strfunc.h"
#import "../imfunc.h"
#import "../getpixel.h"
#import <Dithering/Dither.h>
#import <Dithering/MDAmethod.h>
#import <Dithering/FSmethod.h>


@implementation ImageOpr (Mono)

/* Local Method */
- (int)doMonochrome:(int)steps parent:parent
	filename:(NSString *)fn info:(commonInfo *)cinf
	scale:(const unsigned char *)scale method:(int)tag
{
	ToyWin	*tw;
	commonInfo *newinf = NULL;
	unsigned char *working[MAXPLANE];
	int	x, y, w;
	int	r, g, b, a;
	int	pn, binf = 1;
	unsigned char *ptr, *pta;

	working[0] = NULL;
	tw = NULL;
	if ((newinf = (commonInfo *)malloc(sizeof(commonInfo))) == NULL)
		goto ErrEXIT;
	*newinf = *cinf;
        newinf->cspace = CS_White;
		/* getPixel() fixes 0 as Black */
	newinf->bits = 8;
	newinf->numcolors = 1;
	newinf->isplanar = YES;
	newinf->pixbits = 0;	/* don't care */
	newinf->xbytes = byte_length(newinf->bits, newinf->width);
	newinf->palsteps = 0;
	newinf->palette = NULL;
	pn = newinf->alpha ? 2: 1;

	w = newinf->width * newinf->height;
	if ((working[0] = (unsigned char *)calloc(w * pn, 1)) == NULL)
		goto ErrEXIT;
	if (pn == 2) working[1] = working[0] + w;

	tw = [[ToyWin alloc] init:parent by:Monochrome];
	[tw locateNewWindow:fn width:newinf->width height:newinf->height];

	if (steps == 256) {
		for (y = 0; y < newinf->height; y++) {
			ptr = &working[0][y * newinf->width];
			pta = ptr + w;
			for (x = 0; x < newinf->width; x++) {
				getPixel(&r, &g, &b, &a);
				r = Bright255(r, g, b);
				ptr[x] = r = scale[r];
				if (r && r != 255)
					binf = 8;
				if (pn == 2)
					pta[x] = (a == AlphaTransp)
						? AlphaTransp : AlphaOpaque;
			}
		}
	}else {
		unsigned char apool[MAXWidth];
		NSObject <Dithering> *dither;

		switch (tag) {
		case 0:	dither = [[FSmethod alloc] init];  break;
		case 1:	dither = [[MDAmethod alloc] init]; break;
		case 2: default:
			dither = [[Dither alloc] init];    break;
		}
		if (steps > 16) binf = 8;
		else if (steps > 4) binf = 4;
		else if (steps > 2) binf = 2;
		else binf = 1;
		if (dither == nil)
			goto ErrEXIT;
		[dither reset:steps width:newinf->width];
		for (y = 0; y < newinf->height; y++) {
			unsigned char *q;
			q = [dither buffer];
			ptr = &working[0][y * newinf->width];
			for (x = 0; x < newinf->width; x++) {
				getPixel(&r, &g, &b, &a);
				r = Bright255(r, g, b);
				*q++ = scale[r];
				apool[x] = a;
			}
			q = [dither getNewLine];
			for (x = 0; x < newinf->width; x++)
				*ptr++ = *q++;
			if (pn == 2) {
				pta = &working[1][y * newinf->width];
				for (x = 0; x < newinf->width; x++)
					pta[x] = (apool[x] == AlphaTransp)
						? AlphaTransp : AlphaOpaque;
			}
		}
		[dither release];
	}

	if (binf < 8) {
		unsigned char *planes[MAXPLANE];
		if (pn == 2 && !hadAlpha()) {
			pn = 1;
			newinf->alpha = NO;
		}
		newinf->bits = binf;
		newinf->xbytes = byte_length(newinf->bits, newinf->width);
		if (allocImage(planes, newinf->width, newinf->height, binf, pn))
			goto ErrEXIT;
		packWorkingImage(newinf, pn, working, planes);
		[tw makeComment:newinf from:cinf];
		if ([tw drawView:planes info: newinf] == nil) {
			free((void *)planes[0]);
			goto ErrEXIT;
		}
		free((void *)working[0]);
	}else {
		if (pn == 2 && !hadAlpha()) {
			pn = 1;
			newinf->alpha = NO;
			working[0] = (unsigned char *)realloc(working[0], w);
			working[1] = NULL;
		}
		[tw makeComment:newinf from:cinf];
		if ([tw drawView:working info: newinf] == nil)
			goto ErrEXIT;
	}
	[theController newWindow:tw];
	return 0;

ErrEXIT:
	if (working[0]) free((void *)working[0]);
	if (newinf) free((void *)newinf);
	if (tw) [tw release];
	return Err_MEMORY;
}


- (void)monochrome:(int)steps tone:(const unsigned char *)tone method:(int)tag
{
	ToyWin	*tw;
	ToyView	*tv = NULL;
	commonInfo	*cinf, *info;
	unsigned char	*map[MAXPLANE];
	NSString	*filename, *fn;
	int	isby, err;

	if ((tw = [theController keyWindow]) == nil) {
		NSBeep();
		return;
	}
	isby = [tw madeby];
	if (isby == Monochrome || isby == Brightness) {
		ToyWin	*win = [tw parent];
		if (win && [theController checkWindow: win])
			tw = win;
	}

	tv = [tw toyView];
	filename = [tw filename];
	cinf = [tv commonInfo];
	if (cinf->numcolors == 1 && cinf->bits == 1) {
		[WarnAlert runAlert:filename : Err_OPR_IMPL];
		return;
	}
	if (![[self class] check:(ck_EPS|ck_CMYK) info:cinf filename:filename])
		return;
	if (tag < 0 || steps == 2) {
		NSString *opstr = (tag < 0) ? @"Bright" : @"BiLevel";
		fn = [NSString stringWithFormat:@"%@(%@)", filename,
			NSLocalizedString(opstr, Effects)];
	}else {
		fn = [NSString stringWithFormat:@"%@(%@%d)", filename,
			NSLocalizedString(@"Gray", Effects), steps];
	}
	info = cinf;
	if ((err = [tw getBitmap:map info:&info]) != 0)
		goto ErrExit;
	if ((err = initGetPixel(info)) != 0)
		goto ErrExit;
	resetPixel((refmap)map, 0);
	if ((err = [self doMonochrome:steps parent:tw
		filename:fn info:info scale:tone method:tag]) != 0)
		goto ErrExit;
	[tw freeTempBitmap];
	return;
ErrExit:
	[tw freeTempBitmap];
	[ErrAlert runAlert:filename : err];
}


/* Local Method */
- (int)doBrightness:(NSString *)fn parent:(ToyWin *)parent
	info:(commonInfo *)cinf scale:(const unsigned char *)scale
{
	ToyWin	*tw;
	commonInfo *newinf = NULL;
	unsigned char *working[MAXPLANE];
	int	x, y, pn;

	working[0] = NULL;
	tw = NULL;
	if ((newinf = (commonInfo *)malloc(sizeof(commonInfo))) == NULL)
		goto ErrEXIT;
	*newinf = *cinf;
	newinf->bits = 8;
	newinf->isplanar = YES;
	newinf->pixbits = 0;	/* don't care */
	newinf->xbytes = newinf->width;
	newinf->palsteps = 0;
	newinf->palette = NULL;
	pn = newinf->alpha ? 4: 3;

	if (allocImage(working, newinf->width, newinf->height, 8, pn))
		goto ErrEXIT;

	tw = [[ToyWin alloc] init:parent by:Brightness];
	[tw locateNewWindow:fn width:newinf->width height:newinf->height];

	for (y = 0; y < newinf->height; y++) {
	    int  elm[MAXPLANE];
	    int  i, v, ny, dd;
	    int  ptr = y * newinf->width;
	    for (x = 0; x < newinf->width; x++) {
		getPixel(&elm[0], &elm[1], &elm[2], &elm[3]);
		if (elm[3] != AlphaTransp) {
			ny = Bright255(elm[RED], elm[GREEN], elm[BLUE]);
			if ((dd = scale[ny] - ny) != 0)
			    for (i = 0; i < 3; i++) {
				v = elm[i] + dd;
				elm[i] = (v > 255) ? 255 : ((v < 0) ? 0 : v);
			    }
		}
		for (i = 0; i < pn; i++)
		    working[i][ptr] = elm[i];
		ptr++;
	    }
	}

	if (newinf->alpha && !hadAlpha()) {
		pn = 3;
		newinf->alpha = NO;
		working[0] = (unsigned char *)
		    realloc(working[0], newinf->width * newinf->height * pn);
		working[pn] = NULL;
	}
	[tw makeComment:newinf from:cinf];
	if ([tw drawView:working info: newinf] == nil)
		goto ErrEXIT;

	[theController newWindow:tw];
	return 0;

ErrEXIT:
	if (working[0]) free((void *)working[0]);
	if (newinf) free((void *)newinf);
	if (tw) [tw release];
	return Err_MEMORY;
}

- (void)brightness:(const unsigned char *)tone
{
	ToyWin	*tw;
	ToyView	*tv = NULL;
	commonInfo	*cinf, *info;
	unsigned char	*map[MAXPLANE];
	NSString	*filename, *fn;
	int	isby, err;

	if ((tw = [theController keyWindow]) == nil) {
		NSBeep();
		return;
	}
	isby = [tw madeby];
	if (isby == Monochrome || isby == Brightness) {
		ToyWin	*win = [tw parent];
		if (win && [theController checkWindow: win])
			tw = win;
	}
	tv = [tw toyView];
	filename = [tw filename];
	cinf = [tv commonInfo];
	if (cinf->numcolors == 1)	/* Monochrome */
		return [self monochrome:256 tone:tone method:(-1)];
			/* method:(-1) shows op==Brightness */

	if (![[self class] check:(ck_EPS|ck_CMYK) info:cinf filename:filename])
		return;
	fn = [NSString stringWithFormat:@"%@(%@)",
		filename, NSLocalizedString(@"Bright", Effects)];

	info = cinf;
	if ((err = [tw getBitmap:map info:&info]) != 0)
		goto ErrExit;
	if ((err = initGetPixel(info)) != 0)
		goto ErrExit;
	resetPixel((refmap)map, 0);
	if ((err = [self doBrightness:fn parent:tw info:info scale:tone]) != 0)
		goto ErrExit;
	[tw freeTempBitmap];
	return;
ErrExit:
	[tw freeTempBitmap];
	[ErrAlert runAlert:filename : err];
}

@end
