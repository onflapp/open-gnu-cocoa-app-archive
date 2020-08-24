#import "ColorChanger.h"
#import <AppKit/NSApplication.h>
#import <AppKit/NSGraphics.h>	/* PS_funcs */
#import <AppKit/NSImage.h>
#import <AppKit/NSBitmapImageRep.h>
#import <AppKit/NSControl.h>
#import <AppKit/NSPanel.h>
#import <AppKit/NSTextField.h>
#import <stdio.h>
#import <stdlib.h>
#import <string.h>
//#import <libc.h> //GNUstep only
#import <math.h>
#import "../TVController.h"
#import "../ToyWin.h"
#import "../ToyWinEPS.h"
#import "../ToyView.h"
#import "../AlertShower.h"
#import "../getpixel.h"
#import "../imfunc.h"

#define  MONO_THRESHOLD	128


@implementation ColorChanger

+ (int)opcode {
	return ColorChange;
}

+ (NSString *)oprString {
	return NSLocalizedString(@"ColorChange", Effects);
}

- (void)setColor:(const int *)ocl to:(const int *)ncl method:(int)method with:(float)comp
{
	int	i;

	for (i = 0; i < MAXPLANE; i++) {
		origclr[i] = ocl[i];
		newclr[i] = ncl[i];
		diffclr[i] = newclr[i] - origclr[i];
	}
	comparison = MONO_THRESHOLD * comp;
	cnvMethod = method;
}

- (void)setupWith:(ToyView *)tv
{
	[super setupWith: tv];
	isMono = (cinf->numcolors < 3)
		&& ((newclr[0] == newclr[1] && newclr[1] == newclr[2])
		|| newclr[ALPHA] == AlphaTransp);
	setupLuv();
	transRGBtoLuv(origluv, origclr, (isMono ? 1 : 3), 0);
}

static int distance(const int *elm, const t_Luv *orig)
{
	int i, v, w;
	t_Luv luv[3];

	transRGBtoLuv(luv, elm, 3, 0);
	w = orig[0] - luv[0];
	v = w * w;
	for (i = 1; i < 3; i++) {
		w = orig[i] - luv[i];
		v += w * w * 2;
	}
	return v;
}

/* Local Method */
- (float)nearColor:(const int *)elm
{
	int  v;
	t_Luv luv[3];
	double r;

	if (isMono) {
		transRGBtoLuv(luv, elm, 1, 0);
		r = (luv[0] - origluv[0]) / comparison;
		if (r < 0.0) r = -r;
	}else {
		v = distance(elm, origluv);
		if (v > comparison * comparison)
			return -1.0;
		r = sqrt(v) / comparison;
	}
	return (1.0 - r);
}

/* Local Method */
- (void)gradualColor:(int *)newelm from:(const int *)elm
{
	int	i, n;
	double	v;
	t_Luv luv[3];

	if (isMono) {
		transRGBtoLuv(luv, elm, 1, 0);
		v = origluv[0] - luv[0];
		if (v < 0.0) v = -v;
		n = elm[0] + (int)(diffclr[0] * comparison / (v + comparison));
		newelm[0] = (n > 255) ? 255 : ((n < 0) ? 0 : n);
		return;
	}
	v = distance(elm, origluv);
	v = (v <= 0.0) ? 0.0 : sqrt(v);
	for (i = 0; i < 3; i++) {
		n = elm[i] + (int)(diffclr[i] * comparison / (v + comparison));
		newelm[i] = (n > 255) ? 255 : ((n < 0) ? 0 : n);
	}
}

- (commonInfo *)makeNewInfo
{ /* Note that this method is called in method "doOperation", that is,
     after method "setupWith:" is called.  Therefore, variable "selected"
     is set already. */

	commonInfo *newinf = [super makeNewInfo];
	if (newinf == NULL)
		return NULL;
        if (cinf->alpha && origclr[ALPHA] == AlphaTransp && !selected)
		newinf->alpha = NO;
	if (newclr[ALPHA] == AlphaTransp)
		newinf->alpha = YES;
	if (cinf->numcolors == 1) {
		if (newclr[RED] != newclr[GREEN]
				|| newclr[RED] != newclr[BLUE]) {
			newinf->numcolors = 3;
			newinf->cspace = CS_RGB;
		}else {
			newinf->numcolors = 1;
			newinf->cspace = CS_White;
		}
	}
	return newinf;
}

- (BOOL)makeNewPlane:(unsigned char **)newmap with:(commonInfo *)newinf
{
	int pn, alp, cn;
	int x, y, i;
	float near;

	newmap[0] = NULL;
	pn = cn = (newinf->numcolors == 1) ? 1 : 3;
	if (newinf->alpha) alp = pn++;
	else alp = 0;
	if (allocImage(newmap, newinf->width, newinf->height, 8, pn))
		return NO;	/* return immediately */
	resetPixel((refmap)map, 0);
	for (y = 0; y < newinf->height; y++) {
	    int elm[MAXPLANE], gen[MAXPLANE];
	    int d;
            BOOL ysel, xsel;
	    const int *cp = NULL;
	    int ptr = newinf->width * y;
            ysel = (selected && yorg <= y && y <= yend);
	    for (x = 0; x < newinf->width; x++, ptr++) {
		getPixel(&elm[RED], &elm[GREEN], &elm[BLUE], &elm[ALPHA]);
		xsel = (ysel && xorg <= x && x <= xend);
                if (!selected || (outside && !xsel) || (!outside && xsel)) {
		    if (origclr[ALPHA] == AlphaTransp)
			cp = (elm[ALPHA] == AlphaTransp) ? newclr : elm;
		    else if (elm[ALPHA] == AlphaTransp)
			cp = elm;	/* origclr[ALPHA] != AlphaTransp */
		    else {
			switch (cnvMethod) {
			case cnv_Uniq:
			case cnv_Match:
			    if (comparison == 0.0) {
				for (i = 0; i < cn; i++)
				    if (origclr[i] != elm[i]) break;
				cp = (i >= cn) ? newclr : elm;
			    }else if ((near = [self nearColor:elm]) > 0.0) {
				if (cnvMethod == cnv_Uniq || near == 0.0)
					cp = newclr;
				else {
				    for (i = 0; i < cn; i++) {
					d = elm[i] + diffclr[i] * near;
					gen[i] = (d>255)? 255: ((d<0)? 0: d);
				    }
				    if (alp) gen[ALPHA] = newclr[ALPHA];
				    cp = gen;
				}
			    }else
				cp = elm;
			    break;
			case cnv_Grad:
			    [self gradualColor:gen from:elm];
			    if (alp) gen[ALPHA] = elm[ALPHA];
			    cp = gen;
			    break;
			case cnv_Simu:
			    for (i = 0; i < cn; i++) {
				d = elm[i] + diffclr[i];
				gen[i] = (d>255)? 255: ((d<0)? 0: d);
			    }
			    if (alp) gen[ALPHA] = elm[ALPHA];
			    cp = gen;
			    break;
			}
		    }
		}else
		    cp = elm;
		for (i = 0; i < cn; i++)
		    newmap[i][ptr] = cp[i];
		if (alp)
		    newmap[alp][ptr] = cp[ALPHA];
	    }
	}
	return YES;
}

@end
