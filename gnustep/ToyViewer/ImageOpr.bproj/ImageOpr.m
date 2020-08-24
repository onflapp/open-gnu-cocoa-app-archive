#import "ImageOpr.h"
#import <Foundation/NSData.h>
#import <AppKit/NSApplication.h>
#import <AppKit/NSImage.h>
#import <AppKit/NSEPSImageRep.h>
#import <AppKit/NSBitmapImageRep.h>
#import <AppKit/NSControl.h>
#import <AppKit/NSPanel.h>
#import <AppKit/NSTextField.h>
#import <stdio.h>
#import <stdlib.h>
#import <string.h>
#import <sys/types.h>
//#import <libc.h> //Linux Only
#import "../TVController.h"
#import "../ToyWin.h"
#import "../ToyWinEPS.h"
#import "../ToyView.h"
#import "../AlertShower.h"
#import "../WaitMessageCtr.h"
#import "../common.h"
#import "../imfunc.h"
#import "../getpixel.h"
#import "rotate.h"
#import "CmykConverter.h"

@implementation ImageOpr

+ (NSString *)oprString:(int)op
{
	NSString *s = nil;

	switch (op) {
	case Rotation:		s = @"Rotate";	break;
	case SmoothRotation:	s = @"SmRotate"; break;
	case Horizontal:	/* Flip */
	case Vertical:		s = @"Flip";	break;
	case Clip:		s = @"Clip";	break;
	case Negative:		s = @"Negative"; break;
	default:		return nil;
	}
	return NSLocalizedString(s, Effects);
}

static void sub_clip(NSRect *select, const commonInfo *cinf,
	commonInfo *newinf, int idx[], unsigned char **working)
{
	int	x, y;
	int	i, pidx, ptr;
	int	pix[MAXPLANE];

	int skipx = select->origin.x;
	int skipt = cinf->width - (skipx + select->size.width);
	int skipy = cinf->height - (select->origin.y + select->size.height);
	for (y = 0; y < skipy; y++) {
		for (x = 0; x < cinf->width; x++)
			getPixelA(pix);
	}
	for (y = 0; y < newinf->height; y++) {
		ptr = y * newinf->width;
		for (x = 0; x < skipx; x++)
			getPixelA(pix);
		for (x = 0; x < newinf->width; x++) {
			getPixelA(pix);
			for (i = 0; i <= ALPHA; i++) {
				if ((pidx = idx[i]) < 0) continue;
				working[pidx][ptr + x] = pix[i];
			}
		}
		for (x = 0; x < skipt; x++)
			getPixelA(pix);
	}
}


static void sub_negative(NSRect *select, 
		commonInfo *newinf, int idx[], unsigned char **working)
{
	int	x, y;
	int	i, pidx, ptr, alp;
	int	pix[MAXPLANE];
	int	selectflag = NO, yout, xout;
	int	skipx = 0, skipy = 0, yorig = 0;

	if (select && select->size.width > 0) {
		skipx = select->origin.x + select->size.width - 1;
		skipy = newinf->height - select->origin.y - 1;
		yorig = skipy - select->size.height + 1;
		selectflag = YES;
	}

	if ((alp = idx[ALPHA]) < 0)
		alp = 0;	/* index of Alpha > 0 */
	for (y = 0; y < newinf->height; y++) {
		yout = (selectflag && (y < yorig || y > skipy));
		ptr = y * newinf->width;
		for (x = 0; x < newinf->width; x++) {
			xout = (yout ||
			(selectflag && (x < select->origin.x || x > skipx)));
			getPixelA(pix);
			if (xout) {
				for (i = 0; i < ALPHA; i++) {
					if ((pidx = idx[i]) < 0) continue;
					working[pidx][ptr + x] = pix[i];
				}
			}else {
				for (i = 0; i < ALPHA; i++) {
					if ((pidx = idx[i]) < 0) continue;
					working[pidx][ptr + x] = 0xff - pix[i];
				}
			}
			if (alp) /* Alpha */
				working[alp][ptr + x] = pix[i];
		}
	}
	if (newinf->palette) {
		unsigned char *p;
		paltype *pal = newinf->palette;
		for (x = 0; x < newinf->palsteps; x++) {
			p = pal[x];
			for (i = 0; i < 3; i++)
				p[i] = 0xff - p[i];
		}
	}
}


/* Local Method */
- doBitmap:(int)op parent:parent
		filename:(NSString *)fn info:(const commonInfo *)cinf
		to:(float)angle rect:(NSRect *)select
{
	ToyWin	*tw;
	commonInfo *newinf = NULL;
	unsigned char *working[MAXPLANE], *planes[MAXPLANE];
	int	i, pl;
	int	idx[MAXPLANE];
	BOOL	rotalpha = NO, hadalpha = NO;

	working[0] = planes[0] = NULL;
	tw = NULL;
	if ((newinf = (commonInfo *)malloc(sizeof(commonInfo))) == NULL)
		goto ErrEXIT;
	*newinf = *cinf;
        if (cinf->cspace == CS_Black)
		newinf->cspace = CS_White;
		/* getPixel() fixes 0 as Black */
	newinf->isplanar = YES;
	newinf->pixbits = 0;	/* don't care */
	if (cinf->cspace == CS_CMYK) {
		newinf->cspace = CS_RGB;
		newinf->numcolors = 3;
	}
	if (op == Rotation || op == SmoothRotation) {
		rotate_size(angle, cinf, newinf);
		if (newinf->width >= MAXWidth || newinf->height >= MAXWidth)
			goto ErrEXIT;
	}else if (op == Clip) {
		newinf->width = select->size.width;
		newinf->height = select->size.height;
	}

	/** if rotalpha==YES one color(transparent) is added **/
	if (op == SmoothRotation) {
		newinf->alpha = rotalpha = NO;
		newinf->bits = 8;
	}else if (op == Rotation) {
		float a = angle/90.0;
		if (a - (int)a != 0.0)
			newinf->alpha = rotalpha = YES;
	}
	if (op != SmoothRotation
	&& cinf->palette && (cinf->alpha || newinf->palsteps < FIXcount)) {
		newinf->palette = copyPalette(cinf->palette, newinf->palsteps);
		if (newinf->palette == NULL)
			goto ErrEXIT;
	}else {
		newinf->palette = NULL;
		newinf->palsteps = 0;
	}
	newinf->xbytes = byte_length(newinf->bits, newinf->width);

	pl = newinf->numcolors;
	for (i = 0; i < pl; i++) idx[i] = i;
	for (i = pl; i < MAXPLANE; i++) idx[i] = -1;
	if (newinf->alpha) idx[ALPHA] = pl++;
	if (allocImage(working, newinf->width, newinf->height, 8, pl))
		goto ErrEXIT;
	tw = [[ToyWin alloc] init:parent by:op];
	[tw locateNewWindow:fn width:newinf->width height:newinf->height];

	if (op == Clip) {
		sub_clip(select, cinf, newinf, idx, working);
		if (newinf->alpha) {
			int aw = newinf->width * newinf->height;
			unsigned char *ap = working[pl-1];
			for (i = 0; i < aw; i++, ap++)
				if (isAlphaTransp(*ap)) {
					hadalpha = YES;
					break;
				}
		}
	}else if (op == Negative) {
		sub_negative(select, newinf, idx, working);
		if (newinf->alpha) hadalpha = hadAlpha();
	}else if (op == SmoothRotation) {
		if (sub_rotate(op, angle, cinf, newinf, idx, working))
			goto ErrEXIT;
		hadalpha = NO;
	}else /* Rotation | Horizontal | Vertical */ {
		if (sub_rotate(op, angle, cinf, newinf, idx, working))
			goto ErrEXIT;
		if (rotalpha)
			hadalpha = YES;
		else if (newinf->alpha)
			hadalpha = hadAlpha();
	}

	if (newinf->alpha && !hadalpha) {
		newinf->alpha = NO;
		working[--pl] = NULL;
	}
	if (newinf->alpha && newinf->palette && newinf->palsteps >= 256) {
		free((void *)newinf->palette);	/* 256 colors are too much */
		newinf->palette = NULL;
		newinf->palsteps = 0;
	}
	[tw makeComment:newinf from:cinf];
	if (newinf->bits < 8) {
		if (allocImage(planes, newinf->width, newinf->height,
			newinf->bits, pl))
			goto ErrEXIT;
		packWorkingImage(newinf, pl, working, planes);
		if ([tw drawView:planes info: newinf] == nil)
			goto ErrEXIT;
		free((void *)working[0]);
	}else {
		if ([tw drawView:working info: newinf] == nil)
			goto ErrEXIT;
	}
	[theController newWindow:tw];
	return self;

ErrEXIT:
	if (working[0]) free((void *)working[0]);
	if (planes[0]) free((void *)planes[0]);
	if (newinf) {
		if (newinf->palette) free((void *)newinf->palette);
		free((void *)newinf);
	}
	if (tw) [[tw window] performClose:self];
		/* This call frees tw */
	return nil;
}


- (void)doRotateFlipClip:(int)op to:(float)angle
{
	ToyWin	*tw;
	ToyView	*tv = NULL;
	commonInfo	*cinf, *info;
	NSRect		select;
	unsigned char	*map[MAXPLANE];
	NSString	*filename, *fn;
	int	err;

	if ((tw = [theController keyWindow]) != nil) {
	    tv = [tw toyView];
	    if (op == Clip) {
		select = [tv selectedScaledRect];
		if (select.size.width < 1.0 || select.size.height < 1.0)
		    tw = nil;
	    }else if (op == Negative)
		select = [tv selectedScaledRect];
	}
	if (tw == nil) {
		NSBeep();
		return;
	}

	cinf = [tv commonInfo];
	if (cinf->width >= MAXWidth || cinf->height >= MAXWidth) {
		[ErrAlert runAlert:[tw filename] : Err_MEMORY];
		return;
	}
	filename = [tw filename];
	if (cinf->type == Type_pdf) {
		[WarnAlert runAlert:filename : Err_PDF_IMPL];
		return;
	}

	fn = [NSString stringWithFormat:@"%@(%@)",
		filename, [[self class] oprString:op]];

	if (cinf->type == Type_eps) {
		NSData		*stream;
		ToyWinEPS	*newtw;
		commonInfo	info;

		if (op == Negative) {
			[WarnAlert runAlert:filename : Err_EPS_IMPL];
			return;
		}
		if (op == Clip)
			stream = [(ToyWinEPS *)tw clipEPS:select error:&err];
		else { /* Rotate | Horizontal | Vertical */
			int iangle = (int)angle;
			rotate_size(iangle, cinf, &info);
			stream = [(ToyWinEPS *)tw rotateEPS:op to:iangle
				width:info.width height:info.height
				name: fn error: &err];
		}
		if (stream == nil) {
			[ErrAlert runAlert:filename : err];
			return;
		}
		newtw = [[ToyWinEPS alloc] init:tw by:op];
		err = [newtw drawFromFile:fn or:stream];
		if (err) {
			[ErrAlert runAlert:filename : err];
			[newtw release];
		}else
			[theController newWindow:newtw];
		return;
	}

/*	if (cinf->cspace == CS_CMYK) {
		[WarnAlert runAlert:filename : Err_IMPLEMENT];
		return;
	}
*/
	info = cinf;
	if ((err = [tw getBitmap:map info:&info]) != 0)
		goto ErrExit;
	if ((err = initGetPixel(info)) != 0)
		goto ErrExit;
	resetPixel((refmap)map, 0);
	angle = (int)(angle * 16.0) / 16.0;
	if ([self doBitmap:op parent:tw
		filename:fn info:info to:angle rect:&select] == nil)
		[ErrAlert runAlert: fn : Err_MEMORY]; 
	[tw freeTempBitmap];
	return;
ErrExit:
	[tw freeTempBitmap];
	[ErrAlert runAlert:filename : err];
}

- (void)convertCMYKtoRGB:sender
{
	id she;

	if ((she = [[CmykConverter alloc] init]) == nil)
		return;
	[she createNewImage];
	[she release];
}

@end
