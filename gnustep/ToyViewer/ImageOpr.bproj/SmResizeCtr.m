#import  "SmResizeCtr.h"
#import  <AppKit/NSControl.h>
#import  <AppKit/NSMatrix.h>
#import  <AppKit/NSButton.h>
#import  <AppKit/NSWindow.h>
#import  <stdio.h>
#import  "../TVController.h"
#import  "../ToyWin.h"
#import  "../ToyView.h"
#import  "../common.h"
#import  "../ImageOpCtr.h"
#import  "../rescale.h"

#define  rs_SMOOTH	0
#define  rs_SAMPLE	1

@implementation SmResizeCtr

- (id)init
{
	[super init];
	svalue = 100.0;
	ratiox = DCT_TableIndex(1, svalue);
	currentSize = NSZeroSize;

	[[NSNotificationCenter defaultCenter] addObserver:self
		selector:@selector(didGetNotification:)
		name:NSWindowDidBecomeMainNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
		selector:@selector(didGetNotification:)
		name:NotifyAllWindowDidClosed object:nil];

	return self;
}

/* Local Method */
- (void)activateAndCheck:(id)sender
{
	ToyWin *w = [theController keyWindow];
	NSSize sz = w ? [[w toyView] originalSize] : NSZeroSize;
	if (NSEqualSizes(currentSize, sz))
		return;
	currentSize = sz;
	[self changeValue:scaleText];
}

- (void)didGetNotification:(NSNotification *)notify
{
	[self performSelector:@selector(activateAndCheck:) withObject:self
				afterDelay: 300 / 1000.0];
	/* Don't call directly activate:, because TVController does not
	  have right information about the key window */
}

/* Over write */
- (void)setup:(id)sender
{
	if (imageOpCtr == nil)
		imageOpCtr = sender;
	[self didGetNotification:nil];
}

/* Local Method */
- (void)changeAndSet
{
	NSString *vstr, *rstr, *szstr;
	int	tag;
	float	factor;

	if ([autoButton state]) {
		tag = (svalue < 100.0) ? rs_SMOOTH : rs_SAMPLE;
		[methodButton selectCellWithTag: tag];
	}else
		tag = [methodButton selectedTag];

	ratiox = DCT_TableIndex(ratiox, svalue);
	if (tag == rs_SMOOTH) {
		const DCT_ratioCell *p = &DCT_ratioTable[ratiox];
		vstr = [NSString stringWithFormat:@"%5.1f", p->r];
		rstr = [NSString stringWithFormat:@"%d/%d", (int)p->b, (int)p->a];
		factor = (float)(p->b)/(float)(p->a);
	}else {
		int w = (int)(svalue * 2);
		svalue = (float)w / 2.0;
		factor = svalue / 100.0;
		vstr = [NSString stringWithFormat:@"%5.1f", svalue];
		rstr = @"";
	}
	[scaleText setStringValue:vstr];
	[ratioText setStringValue:rstr];
	szstr = @"";
	if (currentSize.width > 2 && currentSize.height > 2) {
		int w, h;
		calcWidthAndHeight(&w, &h,
			currentSize.width, currentSize.height, factor);
		szstr = [NSString stringWithFormat:@"%d x %d", w, h];
	}
	[newSizeText setStringValue:szstr];
}

- (void)resetValue:(id)sender
{
  svalue = (float)[sender tag]; //GNUstep only ???
  [slider setFloatValue: svalue];
  [self changeAndSet];
}

#define  SliderMAX	130.0
#define  KPoint		120.0
#define  KPoint_V	300.0	// Sld2Val( KPoint )
#define  Sld2Val(v)	((int)(((v) - 90.0) * 2.0) * 5)
#define  Val2Sld(v)	(((v) / 10.0) + 90.0)
#define  Sld2Val_K(v)	(((int)(v) - 110) * 30.0)
#define  Val2Sld_K(v)	(((v) / 30.0) + 110.0)

- (void)changeValue:(id)sender
{
	svalue = [slider floatValue];
	if (svalue >= KPoint)
		svalue = Sld2Val_K(svalue);
	else if (svalue > 100.0)
		svalue = Sld2Val(svalue);
	[self changeAndSet];
}

/* Local Method */
- (void)setSliderKnob
{
	float	w = (svalue >= KPoint_V) ? Val2Sld_K(svalue)
		: ((svalue > 100.0) ? Val2Sld(svalue) : svalue);
	if (w > SliderMAX)
		w = SliderMAX;
	[slider setFloatValue: w];
}

- (void)changeText:(id)sender
{
	svalue = [scaleText floatValue];
	[self setSliderKnob];
	[self changeAndSet];
}

- (void)setCurrentScale:(id)sender
{
	ToyWin	*tw;

	if ((tw = [theController keyWindow]) == nil) {
		NSBeep();
		return;
	}
	svalue = [[tw toyView] scaleFactor] * 100.0;
	[self setSliderKnob];
	[self changeAndSet];
}

- (void)getRatio:(int *)b :(int *)a
{
	if ([methodButton selectedTag] == rs_SMOOTH) {
		*b = DCT_ratioTable[ratiox].b;
		*a = DCT_ratioTable[ratiox].a;
	}else
		*b = *a = 0;
}

- (void)getFactor:(float *)factor
{
	*factor = svalue / 100.0;
}

- (void)setAutoDetect:(id)sender
{
	if ([autoButton state]) {
		[[methodButton cellWithTag:rs_SMOOTH] setEnabled:NO];
		[[methodButton cellWithTag:rs_SAMPLE] setEnabled:NO];
		[self changeAndSet];
	}else {
		[[methodButton cellWithTag:rs_SMOOTH] setEnabled:YES];
		[[methodButton cellWithTag:rs_SAMPLE] setEnabled:YES];
	}
}

- (void)doResize:(id)sender
{
	int tag, kind, op;
	float	f;

	f = svalue - [scaleText floatValue];
	if (f * f > 1.0) {
		svalue = [scaleText floatValue];
		[self setSliderKnob];
		[self changeAndSet];
	}

	tag = [sender selectedTag];
	if (tag == 2) { /* EPS -> Bitmap */
		[imageOpCtr doResize:self by:NewBitmap];
		return;
	}
	kind = [methodButton selectedTag];
	if (svalue == 100.0 || (kind == rs_SMOOTH
		    && DCT_ratioTable[ratiox].a == DCT_ratioTable[ratiox].b)) {
		NSBeep();
		return;
	}
	if (tag == 1) /* EPS -> EPS */
		op = ResizeEPS;
	else
		op = (kind == rs_SMOOTH) ? SmoothResize : SimpleResize;
	[imageOpCtr doResize:self by:op];
}

@end
