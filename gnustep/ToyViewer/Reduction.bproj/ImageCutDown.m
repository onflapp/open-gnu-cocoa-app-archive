#import "ImageReduce.h"
#import <Foundation/NSString.h>
#import <AppKit/NSApplication.h>
#import <AppKit/NSWindow.h>
#import <AppKit/NSImage.h>
#import <AppKit/NSBitmapImageRep.h>
#import <AppKit/NSControl.h>
#import <stdio.h>
#import <stdlib.h>
#import <string.h>
//#import <libc.h> //GNUstep only
#import "../TVController.h"
#import "../ToyWin.h"
#import "../ToyView.h"
#import "../common.h"
#import "../imfunc.h"
#import "../getpixel.h"
#import "../AlertShower.h"


@implementation ImageReduce (CutDownBits)

/* Local Method */
- doCutDown:(NSString *)fn parent:parent info:(commonInfo *)cinf to:(int)bits
{
	ToyWin	*tw;
	commonInfo *newinf = NULL;
	unsigned char *working[MAXPLANE];
	int	i, pl;

	working[0] = newmap[0] = NULL;
	tw = NULL;
	if ((newinf = (commonInfo *)malloc(sizeof(commonInfo))) == NULL)
		goto ErrEXIT;
	*newinf = *cinf;
        if (cinf->cspace == CS_Black)
		newinf->cspace = CS_White;
		/* getPixel() fixes 0 as Black */
	newinf->bits = bits;
	newinf->xbytes = byte_length(bits, newinf->width);
	newinf->palette = NULL;
	newinf->palsteps = 0;
	newinf->isplanar = YES;
	newinf->pixbits = 0;	/* don't care */
	pl = newinf->numcolors;
	if (newinf->alpha) pl++;

	if (allocImage(newmap, newinf->width, newinf->height, bits, pl))
		goto ErrEXIT;
	tw = [[ToyWin alloc] init:parent by:CutDown];
	[tw locateNewWindow:fn width:newinf->width height:newinf->height];
	[tw makeComment:newinf from:cinf];

	if (!cinf->isplanar || cinf->bits < 8) {
		int	x, y, ptr, pidx;
		int	idx[MAXPLANE];
		int	pix[MAXPLANE];

		for (i = 0; i < newinf->numcolors; i++) idx[i] = i;
		for ( ; i < MAXPLANE; i++) idx[i] = -1;
		if (newinf->alpha) idx[ALPHA] = newinf->numcolors;
		if (allocImage(working, newinf->width, newinf->height, 8, pl))
			goto ErrEXIT;
		resetPixel((refmap)origmap, 0);
		for (y = 0; y < newinf->height; y++) {
			ptr = y * newinf->width;
			for (x = 0; x < newinf->width; x++) {
				getPixelA(pix);
				for (i = 0; i <= ALPHA; i++) {
					if ((pidx = idx[i]) < 0) continue;
					working[pidx][ptr + x] = pix[i];
				}
			}
		}
		packWorkingImage(newinf, pl, working, newmap);
		free((void *)working[0]);
	}else
		packWorkingImage(newinf, pl, origmap, newmap);
	if ([tw drawView:newmap info: newinf] == nil)
		goto ErrEXIT;
	[theController newWindow:tw];
	return self;

ErrEXIT:
	if (working[0]) free((void *)working[0]);
	if (newmap[0]) free((void *)newmap[0]);
	if (newinf)  free((void *)newinf);
	if (tw) [[tw window] performClose:self];
		/* This call frees tw */
	return nil;
}


- (void)cutDownBitsTo:(int)bits
{
	ToyWin	*tw;
	ToyView	*tv = NULL;
	commonInfo	*cinf;
	NSString	*filename, *fn;
	int	err;

	if ((tw = [theController keyWindow]) == nil ||
		(bits != 4 && bits != 2 && bits != 1)) {
		NSBeep();
		return;
	}
	tv = [tw toyView];
	cinf = [tv commonInfo];
	filename = [tw filename];
	if (cinf->type == Type_eps || cinf->type == Type_pdf) {
		[WarnAlert runAlert:filename : Err_EPS_PDF_IMPL];
		return;
	}
	if (cinf->bits <= bits) {
		[WarnAlert runAlert:filename : Err_OPR_IMPL];
		return;
	}
        if (cinf->cspace == CS_CMYK) {
		[WarnAlert runAlert:filename : Err_IMPLEMENT];
		return;
	}
	if (cinf->width >= MAXWidth || cinf->height >= MAXWidth) {
		[ErrAlert runAlert:filename : Err_MEMORY];
		return;
	}
	fn = [NSString stringWithFormat:@"%@(%dbit%s)",
		filename, bits, ((bits == 1)?"":"s")];

	if ((err = [tw getBitmap:origmap info:&cinf]) != 0
	|| (err = initGetPixel(cinf)) != 0) {
		[ErrAlert runAlert:filename : err];
		[tw freeTempBitmap];
		return;
	}
	if ([self doCutDown:fn parent:tw info:cinf to:bits] == nil)
		[ErrAlert runAlert:fn : Err_MEMORY]; 
	[tw freeTempBitmap];
}

@end
