#import "CmykConverter.h"
#import <AppKit/NSApplication.h>
#import <AppKit/NSImage.h>
#import <AppKit/NSBitmapImageRep.h>
#import <AppKit/NSControl.h>
#import <AppKit/NSPanel.h>
#import <Foundation/NSBundle.h>	/* LocalizedString */
#import <stdio.h>
#import <stdlib.h>
#import <string.h>
//#import <libc.h> //Linux only ???
#import "../TVController.h"
#import "../ToyWin.h"
#import "../ToyView.h"
#import "../common.h"
#import "../imfunc.h"
#import "../getpixel.h"
#import "../AlertShower.h"
#import "../WaitMessageCtr.h"


@implementation CmykConverter

+ (int)opcode {
	return CMYKtoRGB;
}

+ (NSString *)oprString {
	return NSLocalizedString(@"CMYKtoRGB", Effects);
}

- (id)waitingMessage
{
	return [theWaitMsg messageDisplay:
		NSLocalizedString(@"Converting...", Converting)];
}

/* overwrite */
- (BOOL)checkInfo:(NSString *)filename
{
	if (![[self class] check:ck_EPS info:cinf filename:filename])
		return YES;
	if (cinf->cspace != CS_CMYK) {
		[WarnAlert runAlert:filename : Err_OPR_IMPL];
		return YES;
	}
	return NO;
}

- (commonInfo *)makeNewInfo
{
	commonInfo *newinf = [super makeNewInfo];
        newinf->cspace = CS_RGB;
	newinf->numcolors = 3;
	return newinf;
}

- (BOOL)makeNewPlane:(unsigned char **)newmap with:(commonInfo *)newinf
{
	int	i, x, y, pl;
	int	idx[MAXPLANE];
	int	pidx, ptr;
	int	pix[MAXPLANE];

	pl = newinf->numcolors;
	for (i = 0; i < pl; i++) idx[i] = i;
	for (i = pl; i < MAXPLANE; i++) idx[i] = -1;
	if (newinf->alpha) idx[ALPHA] = pl++;
	if (allocImage(newmap, newinf->width, newinf->height, 8, pl))
		return NO;	/* return immediately */

	if (msgtext)
		[theWaitMsg setProgress:(newinf->height - 1)];
	resetPixel((refmap)map, 0);
	for (y = 0, ptr = 0; y < newinf->height; y++) {
		if (msgtext) [theWaitMsg progress: y];
		for (x = 0; x < newinf->width; x++, ptr++) {
			getPixelA(pix);
			for (i = 0; i <= ALPHA; i++) {
				if ((pidx = idx[i]) < 0) continue;
				newmap[pidx][ptr] = pix[i];
			}
		}
	}
	if (newinf->alpha) newinf->alpha = hadAlpha();
	if (msgtext)
		[theWaitMsg resetProgress];
	return YES;
}

@end
