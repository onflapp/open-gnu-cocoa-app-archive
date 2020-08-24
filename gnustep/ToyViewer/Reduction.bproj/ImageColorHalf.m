#import "ImageReduce.h"
#import <AppKit/NSApplication.h>
#import <AppKit/NSBitmapImageRep.h>
#import <AppKit/NSControl.h>
#import <AppKit/NSPanel.h>
#import <AppKit/NSTextField.h>
#import <Foundation/NSBundle.h>	/* LocalizedString */
#import <stdio.h>
#import <stdlib.h>
#import <string.h>
//#import <libc.h> // GNUstep only ??
#import "../TVController.h"
#import "../ToyWin.h"
#import "../ToyWinEPS.h"
#import "../ToyView.h"
#import "../common.h"
#import "../strfunc.h"
#import "../imfunc.h"
#import "../getpixel.h"
#import "../ColorMap.h"
#import "../AlertShower.h"
#import "../WaitMessageCtr.h"
#import "../IntervalTimer.h"
#import "../ImageOpr.bproj/ImageOpr.h"
#import <Dithering/MDAmethod.h>
#import <Dithering/FSmethod.h>
#import <Dithering/Dither.h>

@implementation ImageReduce (ColorHalf)

/* Local Method */
- (commonInfo *)colorHalfMap:(int)tag from:(ToyWin *)tw with:(commonInfo *)cinf
{
	commonInfo *newinf = NULL;
	int	i, x, y, tabidx, bits;
	int	colnum, pl, err = 0;
	unsigned char *working[MAXPLANE];
	unsigned char apool[MAXWidth];
	unsigned char *q[4];
	Class	ditherClass;
	id <Dithering> dither[3];
	static int psudoBits[][3] = {
		{8,8,4},	/* 256 */
		{4,8,4},	/* 128 */
		{4,4,4},	/* 64 */
		{4,4,2},	/* 32 */
		{2,4,2},	/* 16 */
		{2,2,2}		/* 8 */
	};

	newmap[0] = working[0] = NULL;
	switch (colornum) {
	default:
	case 256: tabidx = 0;  bits = 4;  break;
	case 128: tabidx = 1;  bits = 4;  break;
	case  64: tabidx = 2;  bits = 2;  break;
	case  32: tabidx = 3;  bits = 2;  break;
	case  16: tabidx = 4;  bits = 2;  break;
	case   8: tabidx = 5;  bits = 1;  break;
	}
	pl = hasAlpha ? 4 : 3;
	err = allocImage(working, cinf->width, cinf->height, 8, pl);
	if (err) goto ErrEXIT;
	err = allocImage(newmap, cinf->width, cinf->height, bits, pl);
	if (err) goto ErrEXIT;
	if ((newinf = (commonInfo *)malloc(sizeof(commonInfo))) == NULL) {
		err = Err_MEMORY;
		goto ErrEXIT;
	}
	*newinf = *cinf;
	newinf->xbytes = byte_length(bits, newinf->width);
	newinf->bits = bits;
	newinf->numcolors = 3;
	newinf->isplanar = YES;
	newinf->pixbits = 0;	/* don't care */
	newinf->alpha = hasAlpha;
	newinf->palsteps = 0;
	newinf->palette = NULL;

	switch (tag) {
	case 0: ditherClass = [FSmethod class]; break;
	case 1: ditherClass = [MDAmethod class]; break;
	case 2: default:
		ditherClass = [Dither class]; break;
	}
	for (i = 0; i < 3; i++) {
		if ((dither[i] = [[ditherClass alloc] init]) == nil)
			goto ErrEXIT;
		[dither[i] reset:psudoBits[tabidx][i] width:newinf->width];
	}

	[theWaitMsg messageDisplay:
		NSLocalizedString(@"Reducing...", Reducing)];
	[theWaitMsg setProgress:(newinf->height - 1)];
	for (y = 0; y < newinf->height; ++y) {
		unsigned char *qn, *ptr;
		int elm[MAXPLANE];

		[theWaitMsg progress: y];
		for (i = 0; i < 3; i++)
			q[i] = [dither[i] buffer];
		for (x = 0; x < newinf->width; x++) {
			getPixel(&elm[0], &elm[1], &elm[2], &elm[3]);
			for (i = 0; i < 3; i++)
				q[i][x] = elm[i];
			apool[x] = elm[3];
		}
		for (i = 0; i < 3; i++) {
			qn = [dither[i] getNewLine];
			ptr = &working[i][y * newinf->width];
			for (x = 0; x < newinf->width; x++)
				*ptr++ = *qn++;
		}
		if (pl == 4) {
			for (i = 0; i < pl; i++)
				q[i] = &working[i][y * newinf->width];
			ptr = q[ALPHA];
			for (x = 0; x < newinf->width; x++)
				if (apool[x] == AlphaTransp) {
					for (i = 0; i < 3; i++)
						q[i][x] = 255;
					ptr[x] = AlphaTransp;
				}else
					ptr[x] = AlphaOpaque;
		}
	}
	[theWaitMsg resetProgress];
	colnum = colornum;
	if (hasAlpha && colornum == 256) { /* reduce to 255 */
		int cnum = 0;
		BOOL al;
		commonInfo tmpinf;

		tmpinf = *newinf;
		tmpinf.xbytes = newinf->width;
		tmpinf.bits = 8;	/* Temporally */
		tmpinf.alpha = NO;
		if (initGetPixel(&tmpinf) > 0)
		    cnum = 0;
		else
		    cnum = [colormap getAllColor:(refmap)working limit:0 alpha:&al];
		if (cnum == 256) {
		    const unsigned char *lv;
		    [theWaitMsg messageDisplay:
			NSLocalizedString(@"Reducing 255 col.", Reducing)];
		    lv = [dither[RED] threshold];
		    for (y = 0; y < newinf->height; y++) {
			for (i = 0; i < 3; i++)
			    q[i] = &working[i][y * newinf->width];
			for (x = 0; x < newinf->width; x++) {
			    if (q[GREEN][x] == 0 && q[BLUE][x] == 0
				&& q[RED][x] == lv[1])
				q[RED][x] = ((x ^ y) & 1) ? lv[2] : 0;
			}
		    }
		}
		colnum = 255;
	}
	for (i = 0; i < 3; i++)
		[dither[i] release];

	[theWaitMsg messageDisplay:
		NSLocalizedString(@"Packing Bits...", Packing)];
	packWorkingImage(newinf, pl, working, newmap);
	free((void *)working[0]);
	[tw freeTempBitmap];
	[theWaitMsg messageDisplay:nil];

	sprintf(newinf->memo, "%d x %d  %dcolors(%dbit%s)%s",
			newinf->width, newinf->height, colnum,
			newinf->bits, ((newinf->bits > 1) ? "s" : ""),
			(newinf->alpha ? "  Alpha" : ""));
	comment_copy(newinf->memo, cinf->memo);
	return newinf;

ErrEXIT:
	if (err) [ErrAlert runAlert: [tw filename] : err];
	[tw freeTempBitmap];
	if (newmap[0]) {
		free((void *)newmap[0]);
		newmap[0] = NULL;
	}
	if (working[0]) free((void *)working[0]);
	if (newinf) free((void *)newinf);
	return NULL;
}


- colorHalftoneWith:(int)colnum method:(int)tag
	/* by FS (Floyd-Steinberg), MDA (Mean Density Approximation Method)
	   or Dither
	 */ 
{
	ToyWin		*tw, *newtw;
	commonInfo	*cinf, *newinf = NULL;
	BOOL	needflag = NO;
	int	cnum, err = 0;
	NSString *filename, *fn, *opstr;

	colornum = colnum;
	if ((tw = [theController keyParentWindow: Reduction]) == nil) {
		NSBeep();
		return self;
	}
	filename = [tw filename];
	cinf = [[tw toyView] commonInfo];
	if (![[self class] check:(ck_EPS|ck_CMYK|ck_MONO)
				info:cinf filename:filename])
		return self;
	if ([colormap mallocForFullColor] == nil) {
		err = Err_MEMORY;
		goto ErrEXIT;
	}
	if (cinf->palette && cinf->palsteps <= colornum) {
		if ([self needReduce:filename colors:cinf->palsteps ask:YES])
			needflag = YES;
		else
			return self;
	}

	if ((err = [tw getBitmap:origmap info: &cinf]) == 0)
		err = initGetPixel(cinf);
	if (err) goto ErrEXIT;
	hasAlpha = cinf->alpha;
	if (!needflag) {
		cnum = [colormap getAllColor:(refmap)origmap limit:0 alpha:&hasAlpha];
		if (cnum <= colornum
			&& ![self needReduce:filename colors:cnum ask:YES])
			goto ErrEXIT;
	}

	resetPixel((refmap)origmap, 0);
	newinf = [self colorHalfMap:tag from:tw with:cinf];
	if (newinf == NULL)
		goto ErrEXIT;
	newtw = [[ToyWin alloc] init:tw by:Reduction];
	opstr = (tag < 2) ? @"HalfToning" : @"Dither";
	fn = [NSString stringWithFormat:@"%@(%@%d)", filename,
		NSLocalizedString(opstr, Effects),
		colornum];
	[newtw locateNewWindow:fn width:newinf->width height:newinf->height];
	// [newtw makeComment: newinf];
	if ([newtw drawView:newmap info: newinf] == nil) {
		err = Err_MEMORY;
		[newtw release];
		free((void *)newmap[0]);
		goto ErrEXIT;
	}else
		[theController newWindow:newtw];
	return self;

ErrEXIT:
	if (err) [ErrAlert runAlert:filename :err];
	[tw freeTempBitmap];
	if (newinf) free((void *)newinf);
	return NULL;
}

@end
