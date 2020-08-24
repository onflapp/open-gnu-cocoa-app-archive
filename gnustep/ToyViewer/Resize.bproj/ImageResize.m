#import "ImageResize.h"
#import <Foundation/NSString.h>
#import <Foundation/NSData.h>
#import <AppKit/NSApplication.h>
#import <AppKit/NSImage.h>
#import <AppKit/NSBitmapImageRep.h>
#import <AppKit/NSControl.h>
#import <AppKit/NSPanel.h>
#import <AppKit/NSTextField.h>
#import <stdio.h>
#import <stdlib.h>
#import <string.h>
//#import <libc.h> GNUstep only ??
#import "../TVController.h"
#import "../ToyWin.h"
#import "../ToyWinEPS.h"
#import "../ToyView.h"
#import "../common.h"
#import "../getpixel.h"
#import "../AlertShower.h"
#import "DCTscaler.h"
#import "resize.h"


@implementation ImageResize

- (void)newBitmapWith:(float)factor
{
	ToyWin	*tw, *newtw = nil;
	ToyView	*tv = NULL;
	commonInfo	*cinf;
	NSString	*filename, *fn;
	NSData	*stream;
	int err;

	if ((tw = [theController keyWindow]) == nil) {
		NSBeep();
		return;
	}
	tv = [tw toyView];
	cinf = [tv commonInfo];
	filename = [tw filename];
	if (cinf->type != Type_eps && cinf->type != Type_pdf) {
		[WarnAlert runAlert:filename : Err_EPS_PDF_ONLY];
		return;
	}

	fn = [NSString stringWithFormat:@"%@(%@)",
		filename, NSLocalizedString(@"Bitmap", Effects)];
	stream = [(ToyWinVector *)tw openTiffDataBy:factor compress:NO];
	if (stream == nil) {
		[ErrAlert runAlert:filename : Err_MEMORY];
		return;
	}
	newtw = [[ToyWin alloc] init:tw by:NewBitmap];
	err = [newtw drawFromFile:fn or:stream];
	if (err) {
		[ErrAlert runAlert:filename : err];
		[newtw release];
		return;
	}

	[theController newWindow:newtw];
}

- (void)simpleResizeWith:(float)factor
{
	ToyWin	*tw, *newtw = nil;
	ToyView	*tv = NULL;
	commonInfo	*cinf, *newinf;
	NSString *filename, *fn;
	int	err;
	unsigned char *map[MAXPLANE], *newmap[MAXPLANE];

	if ((tw = [theController keyWindow]) == nil) {
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

	if ((err = [tw getBitmap:map info:&cinf]) != 0) {
		[WarnAlert runAlert:filename : err];
		return;
	}
	fn = [NSString stringWithFormat:@"%@(%@)",
		filename, NSLocalizedString(@"Resize", Effects)];
	newinf = makeBilinearResizedMap(factor, factor, cinf, map, newmap);
	if (newinf == NULL) {
		[WarnAlert runAlert:filename : Err_MEMORY];
		[tw freeTempBitmap];
		return;
	}
	newtw = [[ToyWin alloc] init:tw by:NewBitmap];
	[newtw locateNewWindow:fn
		width:newinf->width height:newinf->height];
	[newtw makeComment:newinf from:cinf];
	[newtw drawView:newmap info: newinf];

	[theController newWindow:newtw]; 
	[tw freeTempBitmap];
}

- (void)smoothResizeWith:(int) b :(int) a
{
	ToyWin	*tw, *newtw = nil;
	ToyView	*tv = NULL;
	commonInfo	*cinf, *newinf;
	NSString *filename, *fn;
	int	err;
	unsigned char *map[MAXPLANE], *newmap[MAXPLANE];

	if ((tw = [theController keyWindow]) == nil) {
		NSBeep();
		return;
	}
	tv = [tw toyView];
	cinf = [tv commonInfo];
	filename = [tw filename];

	if (cinf->type == Type_eps || cinf->type == Type_pdf) {
		[ErrAlert runAlert:filename : Err_EPS_PDF_IMPL];
		return;
	}
	if ((err = [tw getBitmap:map info:&cinf]) != 0) {
		[WarnAlert runAlert:filename : err];
		return;
	}
	fn = [NSString stringWithFormat:@"%@(%@)",
		filename, NSLocalizedString(@"SmResize", Effects)];
	newinf = makeDCTResizedMap(cinf, b, a, map, newmap, YES);
	if (newinf == NULL) {
		[WarnAlert runAlert:filename : Err_MEMORY];
		[tw freeTempBitmap];
		return;
	}
	newtw = [[ToyWin alloc] init:tw by:NewBitmap];
	[newtw locateNewWindow:fn width:newinf->width height:newinf->height];
	[newtw makeComment:newinf from:cinf];
	[newtw drawView:newmap info: newinf];

	[theController newWindow:newtw]; 
	[tw freeTempBitmap];
}

- (void)EPSResizeWith:(float)factor
{
	ToyWin	*tw, *newtw = nil;
	ToyView	*tv = NULL;
	NSData *stream;
	commonInfo	*cinf;
	NSString *filename, *fn;
	int err;

	if (factor == 1.0 || (tw = [theController keyWindow]) == nil) {
		NSBeep();
		return;
	}
	tv = [tw toyView];
	cinf = [tv commonInfo];
	filename = [tw filename];
	fn = [NSString stringWithFormat:@"%@(%@)",
		filename, NSLocalizedString(@"ResizeEPS", Effects)];

	if (cinf->type != Type_eps) {
		[ErrAlert runAlert:filename : Err_EPS_ONLY];
		return;
	}

	stream = [(ToyWinEPS *)tw resizeEPS:factor name:fn error:&err];
	if (stream == nil) {
		[ErrAlert runAlert:filename : err];
		return;
	}
	newtw = [[ToyWinEPS alloc] init:tw by:ResizeEPS];
	err = [newtw drawFromFile:fn or:stream];
	if (err) {
		[ErrAlert runAlert:filename : err];
		[newtw release];
		return;
	}
	[theController newWindow:newtw]; 
}

@end
