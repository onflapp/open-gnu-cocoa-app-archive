#import "ImgOperator.h"
#import <AppKit/NSApplication.h>
#import <AppKit/NSImage.h>
#import <AppKit/NSBitmapImageRep.h>
#import <AppKit/NSControl.h>
#import <AppKit/NSPanel.h>
#import <stdio.h>
#import <stdlib.h>
#import <string.h>
#import "TVController.h"
#import "ToyWin.h"
#import "ToyView.h"
#import "common.h"
#import "getpixel.h"
#import "AlertShower.h"
#import "WaitMessageCtr.h"

@implementation ImgOperator

+ (BOOL)detectParent
{
	return YES;
}

/* Virtual */
- (BOOL)makeNewPlane:(unsigned char **)newmap with:(commonInfo *)newinf
{
	return YES;
}

/* Virtual */
- (id)waitingMessage
{
	// return [theWaitMsg messageDisplay: @"..."];
	return nil;
}

- (BOOL)checkInfo:(NSString *)filename
{
	if (![[self class] check:(ck_EPS|ck_CMYK) info:cinf filename:filename])
		return YES;
	return NO;
}

/* Virtual */
- (commonInfo *)makeNewInfo
{
	commonInfo *newinf;

	if ((newinf = (commonInfo *)malloc(sizeof(commonInfo))) == NULL)
		return NULL;
	*newinf = *cinf;
        if (cinf->cspace == CS_Black)
		newinf->cspace = CS_White;
		/* getPixel() fixes 0 as Black */
	newinf->bits = 8;
	newinf->isplanar = YES;
	newinf->pixbits = 0;	/* don't care */
	newinf->xbytes = newinf->width;
	newinf->palsteps = 0;
	newinf->palette = NULL;
	return newinf;
}

/* Virtual */
- (void)setupWith:(ToyView *)tv
{
}

/* Virtual */
- (int)doEPSOperation
{
	return Err_EPS_IMPL;
}

/* Local Method */
- (int)doOperation
{
	ToyWin	*tw;
	int	err = 0;
	commonInfo *newinf = NULL;
	unsigned char *working[MAXPLANE];

	working[0] = NULL;
	tw = NULL;
	if ((newinf = [self makeNewInfo]) == NULL)
		goto ErrEXIT;
	msgtext = [self waitingMessage];
	tw = [[ToyWin alloc] init:parentw by:[[self class] opcode]];
	[tw locateNewWindow:newfname
		width:newinf->width height:newinf->height];

	err = ![self makeNewPlane:working with:newinf];

	if (msgtext)
		[theWaitMsg messageDisplay:nil];
	if (err) goto ErrEXIT;
	[tw makeComment:newinf from:cinf];
	if ([tw drawView:working info: newinf] == nil)
		goto ErrEXIT;
	[theController newWindow:tw];

	return 0;

ErrEXIT:
	if (working[0]) free((void *)working[0]);
	if (newinf) free((void *)newinf);
	// if (tw) [tw release];
	if (tw) [[tw window] performClose:self];
		/* This call frees tw */
	return Err_MEMORY;
}

- (void)createNewImage
{
	ToyView		*tv;
	NSString	*filename;
	int	detect, err = 0;

	detect = [[self class] detectParent] ? [[self class] opcode] : NoOperation;
	if ((parentw = [theController keyParentWindow: detect]) == nil) {
		NSBeep();
		return;
	}
	tv = [parentw toyView];
	filename = [parentw filename];
	cinf = [tv commonInfo];
	if ([self checkInfo:filename])
		return;

	newfname = [NSString stringWithFormat:@"%@(%@)",
			filename, [[self class] oprString]];
	if (cinf->type == Type_eps || cinf->type == Type_pdf) {
		[self setupWith:tv];
		err = [self doEPSOperation];
	}else {
		if ((err = [parentw getBitmap:map info:&cinf]) != 0
		|| (err = initGetPixel(cinf)) != 0) {
			[ErrAlert runAlert:filename : err];
			[parentw freeTempBitmap];
			return;
		}
		[self setupWith:tv];
		err = [self doOperation];
		[parentw freeTempBitmap];
	}
	if (err)
		[ErrAlert runAlert:filename : err];
}

@end
