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
//#import <libc.h> //GNUstep only
#import "../TVController.h"
#import "../ToyWin.h"
#import "../ToyWinEPS.h"
#import "../ToyView.h"
#import "../AlertShower.h"
#import "../WaitMessageCtr.h"
#import "../common.h"
#import "../imfunc.h"
#import "../getpixel.h"
#import "../strfunc.h"
#import "../ColorMap.h"
#import <Dithering/Dither.h>
#import <Dithering/FSmethod.h>
#import "FScolor.h"

/* syspal.c */
paltype *getSysPalette(int colors);

@implementation ImageReduce

- (id)init
{
	[super init];
	colormap = [[ColorMap alloc] init];
	origmap[0] = newmap[0] = NULL;
	hasAlpha = NO;
	special = sp_NONE;
	return self;
}

- (void)dealloc
{
	[colormap release];
	[super dealloc];
}


/* Local Method */
- (void)makePlanarImage:(commonInfo *)cinf
{
	int	i, x, y, idx;
	unsigned char apool[MAXWidth];
	unsigned char *alp;
	int elm[MAXPLANE];

	resetPixel((refmap)origmap, 0);
	idx = 0;
	for (y = 0; y < cinf->height; y++) {
		alp = hasAlpha ? &newmap[ALPHA][idx] : apool;
		for (x = 0; x < cinf->width; x++, idx++) {
			getPixel(&elm[0], &elm[1], &elm[2], &elm[3]);
			if ((alp[x] = elm[ALPHA]) == AlphaTransp) {
				for (i = 0; i < 3; i++)
					newmap[i][idx] = 255;
			}else {
				for (i = 0; i < 3; i++)
					newmap[i][idx] = elm[i];
			}
		}
	}
}

static const short dthbits[][3] = {
	{7, 7, 7}, {7, 7, 6}, {6, 6, 6}, {6, 6, 5},
	{5, 5, 5}, {5, 5, 4}, {4, 4, 4}, {4, 4, 3},
	{3, 3, 3}, {3, 3, 2}, {2, 2, 2 /* never */ }};

/* Local Method */
- (int)tryMakePalette:(commonInfo *)cinf with:(id <Dithering> *)dither
{
	int	trial;
	int	i, x, y;
	NSString *msg, *lng;
	unsigned char *rr, *gg, *bb;

	/* set initial value of 'trial'... index for dthbits[][] */
	if (special == sp_Default)
		trial = 2;	/* MCA (default reduction) */
	else if (colornum == 64)
		trial = 7;	/* Dither + MCA 64 colors */
	else	trial = 5;	/* Dither + MCA 256, 16, and 8 colors */

	for ( ; ; trial++) {
	    lng = NSLocalizedString(@"Trying Reduction", Reduction);
	    msg = [NSString stringWithFormat:@"%@: RGB=%d:%d:%d", lng,
		(int)dthbits[trial][0],
		(int)dthbits[trial][1],
		(int)dthbits[trial][2]];
	    [theWaitMsg messageDisplay: msg];

	    for (i = 0; i < 3; i++)
		[dither[i] reset:(1 << dthbits[trial][i])];
	    [colormap tabInitForRegColors];
	    for (y = 0; y < cinf->height; y++) {
		for (i = 0; i < 3; i++) {
			rr = [dither[i] buffer];
			gg = &newmap[i][y * cinf->width];
			for (x = 0; x < cinf->width; x++)
				*rr++ = *gg++;
		}
		rr = [dither[RED] getNewLine];
		gg = [dither[GREEN] getNewLine];
		bb = [dither[BLUE] getNewLine];
		for (x = 0; x < cinf->width; x++) {
			if ([colormap regColorToMap:*rr++:*gg++:*bb++] < 0)
				goto ReTRY;	/* Too Many Color */
		}
	    }
	    break;	/* OK */
ReTRY:	    ;
	}
	return trial;
}

/* Local Method */
- (int)reduceByFS:(commonInfo *)cinf palette:(paltype *)pal
{
	int i, x, y, idx, err;
	FScolor *dither[3];
	unsigned char *rr, *gg, *bb;

	err = 0;
	for (i = 0; i < 3; i++)
		dither[i] = nil;
	for (i = 0; i < 3; i++) {
		if ((dither[i] = [[FScolor alloc] init]) == nil) {
			err = -1;
			goto ErrEXIT;
		}
		[dither[i] reset:128 width:cinf->width];
	}
	[theWaitMsg setProgress:(cinf->height - 1)];
	idx = 0;
	for (y = 0; y < cinf->height; y++) {
		[theWaitMsg progress: y];
		for (i = 0; i < 3; i++) {
			rr = [dither[i] buffer];
			gg = &newmap[i][idx];
			for (x = 0; x < cinf->width; x++)
				*rr++ = *gg++;
		}
		[dither[RED] colorMapping:pal
			with:dither[GREEN] and:dither[BLUE]];
		rr = [dither[RED] getNewLine];
		gg = [dither[GREEN] getNewLine];
		bb = [dither[BLUE] getNewLine];
		memcpy(&newmap[RED][idx], rr, cinf->width);
		memcpy(&newmap[GREEN][idx], gg, cinf->width);
		memcpy(&newmap[BLUE][idx], bb, cinf->width);
		idx += cinf->width;
	}
	[theWaitMsg resetProgress];
ErrEXIT:
	for (i = 0; i < 3; i++)
		if (dither[i]) [dither[i] release];
	return err;
}

/* Local Method */
- (id)reduceNormal:(commonInfo *)cinf palette:(paltype *) pal
	with:(id <Dithering> *)dither
{
	int i, x, y, idx;
	unsigned char *rr, *gg, *bb;

	[theWaitMsg setProgress:(cinf->height - 1)];
	idx = 0;
	for (y = 0; y < cinf->height; y++) {
		[theWaitMsg progress: y];
		for (i = 0; i < 3; i++) {
			rr = [dither[i] buffer];
			gg = &newmap[i][idx];
			for (x = 0; x < cinf->width; x++)
				*rr++ = *gg++;
		}
		rr = [dither[RED] getNewLine];
		gg = [dither[GREEN] getNewLine];
		bb = [dither[BLUE] getNewLine];
		for (x = 0; x < cinf->width; x++, idx++) {
			unsigned char *p = pal[mapping(*rr, *gg, *bb)];
			for (i = 0; i < 3; i++)
				newmap[i][idx] = p[i];
			rr++, gg++, bb++;
		}
	}
	[theWaitMsg resetProgress];
	return self;
}

/* Local Method */
- (int)reduceColor:(commonInfo *)cinf
{
	paltype *pal = NULL;
	id <Dithering> dither[3];
	int i;
	int trial = 0, cnum = 0;

	[theWaitMsg messageDisplay:
		NSLocalizedString(@"Starting Reduction...", Reduction)];

	for (i = 0; i < 3; i++)
		dither[i] = nil;
	for (i = 0; i < 3; i++) {
		if ((dither[i] = [[Dither alloc] init]) == nil)
			goto ErrEXIT;
		[dither[i] reset:128 width:cinf->width];
	}

	[self makePlanarImage: cinf];

	[theWaitMsg messageDisplay:
		NSLocalizedString(@"Making Palette...", Reduction)];
	cnum = colornum;
	if (special == sp_FixedPalette) {
		pal = getSysPalette(cnum);
		[colormap regGivenPal:pal colors:cnum];
	}else {
		trial = [self tryMakePalette:cinf with:dither];
		pal = [colormap getReducedMap: &cnum alpha:hasAlpha];
	}
	[theWaitMsg messageDisplay:
		NSLocalizedString(@"Writing Image...", Reduction)];

	if (fsFlag) /* with color FS-Method */ {
		if ([self reduceByFS:cinf palette:pal] != 0) {
			cnum = 0;
			/* goto ErrEXIT; */
		}
	}else { /* without FS-Method */
		for (i = 0; i < 3; i++)
			[dither[i] reset:(1 << dthbits[trial][i])];
		[self reduceNormal:cinf palette:pal with:dither];
	}
ErrEXIT:
	for (i = 0; i < 3; i++)
		if (dither[i]) [dither[i] release];
	[theWaitMsg messageDisplay:nil];
	return cnum;
}


/* Local Method */
- (commonInfo *)reducedBitmap:(ToyWin *)tw with:(commonInfo *)cinf
{
	commonInfo *newinfo = NULL;
	int	cnum = 0, pl, err = 0;
	NSString *filename;

	filename = [tw filename];
	if ((err = [tw getBitmap:origmap info: &cinf]) == 0)
		err = initGetPixel(cinf);
	if (err) {
		[ErrAlert runAlert:filename : err];
		return NULL;
	}

	if ([colormap mallocForFullColor] == nil) {
		err = Err_MEMORY;
		goto ErrEXIT;
	}
	if (special != sp_FixedPalette) {
		cnum = [colormap getAllColor:(refmap)origmap limit:0 alpha:&hasAlpha];
		if (hasAlpha) ++cnum;
		if (cnum <= colornum) {
			(void)[self needReduce:filename colors:cnum ask:NO];
			goto ErrEXIT;
		}
	}
	pl = hasAlpha ? 4 : 3;
	err = allocImage(newmap, cinf->width, cinf->height, 8, pl);
	newinfo = (commonInfo *)malloc(sizeof(commonInfo));
	if (!newinfo)
		err = Err_MEMORY;
	if (err) goto ErrEXIT;

	cnum = [self reduceColor:cinf];
	if (cnum <= 0) {
		err = Err_MEMORY;
		goto ErrEXIT;
	}
	*newinfo = *cinf;
	newinfo->palsteps = cnum;
	newinfo->bits = fourFlag ? 4 : 8;
	newinfo->xbytes = byte_length(newinfo->bits, newinfo->width);
	newinfo->numcolors = 3;
	newinfo->isplanar = YES;
	newinfo->pixbits = 0;	/* don't care */
	newinfo->alpha = hasAlpha;
	newinfo->palette = [colormap getPalette];
	sprintf(newinfo->memo, "%d x %d  %dcolors%s%s",
			newinfo->width, newinfo->height, cnum,
			(fourFlag ? "(4bits)" : ""),
			(newinfo->alpha ? "  Alpha" : ""));
	comment_copy(newinfo->memo, cinf->memo);

	if (fourFlag) {
		int i;
		unsigned char *work[MAXPLANE];
		err = allocImage(work, newinfo->width, newinfo->height, 4, pl);
		if (err) goto ErrEXIT;
		packWorkingImage(newinfo, pl, newmap, work);
		free((void *)newmap[0]);
		for (i = 0; i < MAXPLANE; i++)
			newmap[i] = work[i];
	}

	[tw freeTempBitmap];
	return newinfo;

ErrEXIT:
	if (err) [ErrAlert runAlert:filename : err];
	[tw freeTempBitmap];
	if (newmap[0]) free((void *)newmap[0]);
	if (newinfo) free((void *)newinfo);
	return NULL;
}


- (void)reduce:sender	/* Default Method */
{
	special = sp_Default;
	[self reduceTo:256 withFS:NO fourBit:NO];
}

- (void)reduceWithFixedPalette:(int)colors
{
	special = sp_FixedPalette;
	[self reduceTo:colors withFS:YES fourBit:YES];
}

- reduceTo:(int)colors withFS:(BOOL)fsflag fourBit:(BOOL)fourflag
{
	ToyWin		*tw, *newtw;
	commonInfo	*cinf;
	NSString	*filename, *fn, *ops;

	colornum = colors;
	fsFlag = fsflag;
	[colormap setFourBitsPalette: (fourFlag = fourflag)];
	if ((tw = [theController keyParentWindow: Reduction]) == nil) {
		NSBeep();
		return self;
	}
	filename = [tw filename];
	cinf = [[tw toyView] commonInfo];
	if (![[self class] check:(ck_EPS|ck_CMYK|ck_MONO)
				info:cinf filename:filename])
		return self;

	if (cinf->palette && cinf->palsteps <= colornum) {
		(void)[self needReduce:filename colors:cinf->palsteps ask:NO];
		return NULL;
	}

	if ((cinf = [self reducedBitmap:tw with:cinf]) == NULL)
		return self;
	newtw = [[ToyWin alloc] init:tw by:Reduction];
	ops = NSLocalizedString(@"Reduce", Effects);
	fn = (special == sp_Default)
	  ? [NSString stringWithFormat:@"%@(%@)", filename, ops]
	  : [NSString stringWithFormat:@"%@(%@%d)", filename, ops, colornum];
	[newtw locateNewWindow:fn width:cinf->width height:cinf->height];
	if ([newtw drawView:newmap info: cinf] == nil) {
		[ErrAlert runAlert:filename : Err_MEMORY];
		[newtw release];
		free((void *)newmap[0]);
		free((void *)cinf);
	}else
		[theController newWindow:newtw];
	return self;
}


- (BOOL)needReduce:(NSString *)fn colors:(int)cnum ask:(BOOL)ask
{
	NSString	*qust, *title, *cancel, *reduce;

	qust = NSLocalizedString(@"No Need to Reduce", NO_Need_Reduction);
	title = NSLocalizedString(@"WARNING", WARNING);
	if (ask) {
	    cancel = NSLocalizedString(@"Cancel", Stop_SAVE);
	    reduce = NSLocalizedString(@"Reduce", BMP_Reduce);
	    if (NSRunAlertPanel(title, qust, cancel, reduce, nil, fn, cnum))
		return NO;
	}else
	    NSRunAlertPanel(title, qust, @"", nil, nil, fn, cnum);
	return YES;
}

@end
