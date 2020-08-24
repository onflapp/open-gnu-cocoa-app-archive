#import "Noiser.h"
#import <AppKit/NSApplication.h>
#import <AppKit/NSImage.h>
#import <AppKit/NSBitmapImageRep.h>
#import <AppKit/NSControl.h>
#import <AppKit/NSPanel.h>
#import <stdio.h>
#import <stdlib.h>
#import <string.h>
//#import <libc.h> GNUstep only ????
#import "../TVController.h"
#import "../ToyWin.h"
#import "../ToyView.h"
#import "../AlertShower.h"
#import "../getpixel.h"
#import "../imfunc.h"

#define  ValBAND	32
#define  BANDMask	0x1f
#define  ValBIAS	16


@implementation Noiser

+ (int)opcode {
	return RandomPttn;
}

+ (NSString *)oprString {
	return NSLocalizedString(@"Noise", Effects);
}


- (void)setFreq:(float)fval mag:(float)mval brightOnly:(BOOL)flag
{
	freq = fval * fval * 256.0;
	mag = (int)(mval * mval * (ValBAND - ValBIAS + 256.0)) + ValBIAS; 
	brightOnly = flag;
}

/* Local Method */
- (void)makeRandom:(int *)elm
{
	long	r, v;
	int	i, cn;
	float	av;

	r = random();
	if ((r & 0xff) >= freq)
		return;
	cn = cinf->numcolors;
	if (brightOnly && cn > 1) {
		r = random();
		v = mag - ((r >> 1) & BANDMask);
		av = 0.0;
		for (i = 0; i < cn; i++)
			av += elm[i];
		av = 1.0 + 0.577 * ((r & 1) ? v : -v) * cn / av;
		for (i = 0; i < cn; i++) {
			v = elm[i] * av;
			elm[i] = (v > 255) ? 255 : ((v < 0) ? 0 : v);
		}
	}else {
		for (i = 0; i < cn; i++) {
			r = random();
			v = mag - ((r >> 1) & BANDMask);
			if (r & 1) v += elm[i];
			else v = elm[i] - v;
			elm[i] = (v > 255) ? 255 : ((v < 0) ? 0 : v);
		}
	}
}

- (BOOL)makeNewPlane:(unsigned char **)newmap with:(commonInfo *)newinf
{
	int pn, alp, cn;
	int x, y, i;

	newmap[0] = NULL;
	pn = cn = (newinf->numcolors == 1) ? 1 : 3;
	if (newinf->alpha) alp = pn++;
	else alp = 0;
	if (allocImage(newmap, newinf->width, newinf->height, 8, pn))
		return NO;	/* return immediately */
	resetPixel((refmap)map, 0);
	for (y = 0; y < newinf->height; y++) {
	    int elm[MAXPLANE];
            BOOL ysel;
	    int ptr = newinf->width * y;
            ysel = (selected && yorg <= y && y <= yend);
	    for (x = 0; x < newinf->width; x++, ptr++) {
		getPixelA(elm);
		if (alp) {
		    newmap[alp][ptr] = elm[ALPHA];
		    if (elm[ALPHA] == AlphaTransp) {
			for (i = 0; i < cn; i++)
			    newmap[i][ptr] = 255;
			continue;
		    }
		}
		if (!selected || (ysel && xorg <= x && x <= xend))
		    [self makeRandom: elm];
		for (i = 0; i < cn; i++)
		    newmap[i][ptr] = elm[i];
	    }
	}
	if (newinf->alpha && !hadAlpha()) {
		newinf->alpha = NO;
		alp = 0;
	}
	return YES;
}

@end
