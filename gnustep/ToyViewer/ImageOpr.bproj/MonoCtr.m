#import  "MonoCtr.h"
#import  <Foundation/NSString.h>
#import  <Foundation/NSRunLoop.h>	// performSelector:withObject:afterDelay:
#import  <AppKit/NSControl.h>
#import  <AppKit/NSMatrix.h>
#import  <stdio.h>
#import  <math.h>
#import  "../common.h"
#import  "ImageOpr.h"
#import  "MonotoneView.h"
#import  "../ImageOpCtr.h"

#define  Tag_Bright	0
#define  Tag_Contrast	1
#define  Tag_Gamma	2

static void monoScale(unsigned char *buf, float contr, float bright, float *gscale)
{
	float	a, b, cn2;
	int	i, v;

	if (contr == 0.0) a = 1.0;
	else {
		cn2 = contr * contr;
		if (contr > 0.0)
			a = (contr < 1.0) ? (1.0 / (1.0 - cn2)) : 512.0;
		else
			a = 1.0 - cn2;
	}
#ifdef	BRIGHT_SQUARE
	b = bright * bright;
	if (bright < 0.0) b *= -1.0;
#else
	b = bright * bright * bright;
#endif
	b = (-1.0 - a) * 128.0 * (1.0 - b) + 256.0;

	for (i = 0; i < 256; i++) {
		v = (int)(a * gscale[i] + b + 0.5);
		buf[i] = (v > 255) ? 255 : ((v < 0) ? 0 : v);
	}
}


@implementation MonoCtr

- (id)init
{
	int i;

	[super init];
	for (i = 0; i < 256; i++)
		tone[i] = i;
	gammaValue = 0.0;
	[self setGamma:1.0];
	[[valTexts cellWithTag: Tag_Gamma] setFloatValue:1.0];
//	[[valTexts cellWithTag: Tag_Bright] setFloatValue:0.0];
//	[[valTexts cellWithTag: Tag_Contrast] setFloatValue:0.0];
	return self;
}

static void setGammaScale(float scale[], double gval, BOOL rapid)
{
	int	i;

	if (gval == 1.0) {
		for (i = 0; i < 256; i++)
			scale[i] = i;
	}else {
		scale[0] = 0.0;
		scale[255] = 255.0;
		if (rapid) {
			for (i = 2; i < 256; i += 2)
				scale[i] = pow(i / 255.0, gval) * 255.0;
			for (i = 1; i < 255; i += 2)
				scale[i] = (scale[i-1] + scale[i+1]) / 2.0;
		}else {
			for (i = 1; i < 255; i++)
				scale[i] = pow(i / 255.0, gval) * 255.0;
		}
	}
}

/* Local Method */
- (void)setGammaRapid:(float)gamma
{
	if (gamma == gammaValue)
		return;
	setGammaScale(gammaScale, gamma, isScaleRapid = YES);
	gammaValue = gamma; 
}

- (void)setGamma:(float)gamma
{
	if (isScaleRapid == NO && gamma == gammaValue)
		return;
	setGammaScale(gammaScale, gamma, isScaleRapid = NO);
	gammaValue = gamma; 
}

/* Local Method */
- (void)redoGamma:(id)sender
{
	setGammaScale(gammaScale, gammaValue, isScaleRapid = NO);
	monoScale(tone, [contrSlider floatValue],
			[brightSlider floatValue], gammaScale);
}

- (void)changeValue:(id)sender
{
	int tag = [sender tag];
	float val = [sender floatValue];
	[[valTexts cellWithTag: tag] setFloatValue: val];

	if (tag == Tag_Gamma)
		[self setGammaRapid: val];
	monoScale(tone, [contrSlider floatValue],
			[brightSlider floatValue], gammaScale);
	[monoView setTone:tone];
	[monoView display];

	if (isScaleRapid) {
		[[self class] cancelPreviousPerformRequestsWithTarget:self
			selector:@selector(redoGamma:) object:self];
		[self performSelector:@selector(redoGamma:) withObject:self
			afterDelay: 0.1];
	}
}

- (void)reset:(id)sender
{
	int i;

	[contrSlider setFloatValue:0.0];
	[brightSlider setFloatValue:0.0];
	[gammaSlider setFloatValue:1.0];
	for (i = 0; i < 256; i++)
		tone[i] = i;
	[self setGamma:1.0];
	[[valTexts cellWithTag: Tag_Bright] setFloatValue:0.0];
	[[valTexts cellWithTag: Tag_Contrast] setFloatValue:0.0];
	[[valTexts cellWithTag: Tag_Gamma] setFloatValue:1.0];
	[monoView setTone:tone];
	[monoView display];
}

- (void)monochrome:(id)sender
{
	id op = [[ImageOpr alloc] init];
	if ([sender selectedTag])
		[op monochrome:256 tone:tone method:0];
		/* Don't mind Arg of method:, but arg >= 0 */
	else
		[op monochrome:[stepsSW selectedTag]
			tone:tone method:[ditherSW selectedTag]];
	[op release];
}

- (void)changeBrightness:(id)sender
{
	id op = [[ImageOpr alloc] init];
	[op brightness:tone];
	[op release];
}

@end
