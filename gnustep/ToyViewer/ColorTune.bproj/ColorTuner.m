#import "ColorTuner.h"
#import <AppKit/NSApplication.h>
#import <AppKit/NSImage.h>
#import <AppKit/NSBitmapImageRep.h>
#import <AppKit/NSControl.h>
#import <AppKit/NSPanel.h>
#import <AppKit/NSTextField.h>
#import <Foundation/NSBundle.h>	/* LocalizedString */
#import <stdio.h>
#import <stdlib.h>
#import <string.h>
//#import <libc.h> //GNUstep only ???
#import "../TVController.h"
#import "../ToyWin.h"
#import "../ToyWinEPS.h"
#import "../ToyView.h"
#import "../common.h"
#import "../imfunc.h"
#import "../getpixel.h"
#import "../AlertShower.h"
#import "../WaitMessageCtr.h"
#import "TonePanelCtrl.h"
#import "colorEnhance.h"


@implementation ColorTuner

+ (int)opcode {
	return ColorTone;
}

+ (NSString *)oprString {
	return NSLocalizedString(@"ColorTone", Effects);
}

- (id)waitingMessage
{
	return [theWaitMsg messageDisplay:
		NSLocalizedString(@"Color Tuning...", ColorTuning)];
}

/* overwrite */
- (BOOL)checkInfo:(NSString *)filename
{
	if (![[self class] check:(ck_EPS|ck_CMYK|ck_MONO)
			info:cinf filename:filename])
		return YES;
	return NO;
}

- (void)setSaturation:(float)sval andHue:(float *)hval
{
	ratio = hval;
	set_ratio(ratio);
	satval = (sval < 1.0-rLimit || sval > 1.0+rLimit)
		? sval : 1.0;
	sat_enhance_init(satval);
}

- (BOOL)makeNewPlane:(unsigned char **)newmap with:(commonInfo *)newinf
{
	int total, i, idx;
	int pnum, alp, err;
	int elm[MAXPLANE];

	pnum = cinf->numcolors;	/* must be 3 */
	if (cinf->alpha) alp = pnum++;
	else alp = 0;
	err = allocImage(newmap, cinf->width, cinf->height, 8, pnum);
	if (err) return NO;

	resetPixel((refmap)map, 0);
	total = cinf->height * cinf->width;
	[theWaitMsg setProgress:(total - 1)];
	for (idx = 0; idx < total; idx++) {
		[theWaitMsg progress: idx];
		getPixelA(elm);
		if (satval != 1.0)
			sat_enhance(elm);
		tone_enhance(elm);
		for (i = 0; i < 3; i++) {
			int v = elm[i];
			newmap[i][idx] = (v > 255) ? 255 : ((v < 0) ? 0 : v);
		}
		if (alp) newmap[alp][idx] = elm[ALPHA];
	}
	if (newinf->alpha) newinf->alpha = hadAlpha();
	[theWaitMsg resetProgress];
	return YES;
}

@end
