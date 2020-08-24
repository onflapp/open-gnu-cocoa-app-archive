//
//  J2kSavePanel.m
//  ToyViewer
//
//  Created on Sat Aug 03 2002.
//  Copyright (c) 2002 Takeshi Ogihara. All rights reserved.
//

#import "J2kSavePanel.h"
#import <Foundation/NSString.h>
#import <Foundation/NSUserDefaults.h>
#import <AppKit/NSControl.h>
#import <AppKit/NSButton.h>
#import <AppKit/NSPopUpButton.h>
#import <AppKit/NSMatrix.h>
#import <AppKit/NSSlider.h>

#define  J2KSuffix	@"J2KSuffix"
#define  sfxTag_jpc	0
#define  sfxTag_j2k	1

#define  J2KFormat	@"J2KFormat"
#define  J2KProgressive	@"J2KProgressive"
#define  J2KFactor	@"J2KFactor"
#define  ProgRate	@"Rate"
#define  ProgResol	@"Resolution"
#define  ProgCompo	@"Component"

#define  SL_Prec	10
#define  SL_Rate	4
#define  SL_MaxVal	100
#define  SL_MinVal	(0 - (SL_Prec * (SL_Rate - 1)))
#define  SL_MinMin	0.0001

#define  isLossyFactor(x)	((x) < 1.0 && (x) > 0.0)

static int suffixTagSV = sfxTag_j2k;
static int formatKindTagSV = Tag_jpc;
static int progKindTagSV = Tag_rate;
static float compFactor = (float)Lossless;

@implementation J2kSavePanel

+ (void)initialize
{
	NSString *s;
	NSUserDefaults *usrdef = [NSUserDefaults standardUserDefaults];
	suffixTagSV = sfxTag_j2k;
	s = [usrdef stringForKey: J2KSuffix];
	if (s && [s isEqualToString:@"jpc"])
		suffixTagSV = sfxTag_jpc;
	formatKindTagSV = Tag_jp2;
	s = [usrdef stringForKey: J2KFormat];
	if (s && [s isEqualToString:@"jpc"])
		formatKindTagSV = Tag_jpc;
	progKindTagSV = Tag_rate;
	s = [usrdef stringForKey: J2KProgressive];
	if (s) {
	    if ([s isEqualToString: ProgRate])
		progKindTagSV = Tag_rate;
	    else if ([s isEqualToString: ProgResol])
		progKindTagSV = Tag_resol;
	    else if ([s isEqualToString: ProgCompo])
		progKindTagSV = Tag_compo;
	}
	compFactor = (float)Lossless;
	s = [usrdef stringForKey: J2KFactor];
	if (s != nil) {
		float r = [s floatValue];
		if (r > 0)
			compFactor = r;
	}
}

+ (NSString *)nameOfAccessory { return @"J2kAccessory.nib"; }

+ (void)setSuffix:(int)tag { suffixTagSV = tag; }
+ (void)setFormatKind:(int)tag { formatKindTagSV = tag; }
+ (void)setProgressiveKind:(int)tag { progKindTagSV = tag; }

/* Local Method */
- (double)getSliderValue
{
	double v = [J2kSlider doubleValue];
	if (v >= SL_Prec)
		return (double)((int)(v * 2) / 200.0);
	v = (v + (SL_Prec * (SL_Rate - 1))) / (double)SL_Rate;
	return (double)((int)(v * 10) / 1000.0);
}

/* Local Method */
- (void)setSliderValue:(double)v
{
	v *= 100.0;
	if (v > SL_MaxVal) v = SL_MaxVal;
	else if (v < SL_Prec)
		v = v * SL_Rate - (SL_Prec * (SL_Rate - 1));
	[J2kSlider setDoubleValue: v];
}

- (void)loadNib
{
	BOOL isLossy;
	float r;

	[super loadNib];
	formatKindTag = formatKindTagSV;
	[formatKindButton selectCellWithTag: formatKindTag];
	[suffixButton selectCellWithTag:(suffixTag = suffixTagSV)];
	[suffixButton setEnabled: (formatKindTag == Tag_jpc)];
	progKindTag = progKindTagSV;
	// [progKindButton selectCellWithTag: progKindTag];
	[progKindButton selectItemAtIndex: progKindTag];
	isLossy = isLossyFactor(compFactor);
	[J2kText setEnabled: isLossy];
	[J2kSlider setEnabled: isLossy];
	[losslessButton setState: !isLossy];
	r = isLossy ? compFactor : 0.1;
	[J2kText setFloatValue: r];

	[J2kSlider setMaxValue: SL_MaxVal];
	[J2kSlider setMinValue: SL_MinVal];
	[self setSliderValue: r];
}

- (int)formatKind { return formatKindTag; }
- (int)progressiveKind { return progKindTag; }

- (float)compressRate
{
	compFactor = [losslessButton state] ? Lossless : [J2kText floatValue];
	return compFactor;
}

- (void)changeRate:(id)sender
{
	double r = 0.0;

	if (sender == J2kText) {
		r = [J2kText floatValue];
		if (isLossyFactor(r))
			[self setSliderValue: r];
		else
			r = 0.0;
	}
	if (r <= 0.0) {
		r = [self getSliderValue];
		if (r <= 0.0) r = SL_MinMin;
		[J2kText setFloatValue: r];
	}
	compFactor = [losslessButton state] ? Lossless : r;
}

- (void)changeFormatKind:(id)sender
{
	formatKindTag = [formatKindButton selectedTag];
	[suffixButton setEnabled: (formatKindTag == Tag_jpc)];
	[[self class] setFormatKind: formatKindTag];
	[self changeSuffix: self];
}

- (void)changeProgressiveKind:(id)sender
{
	progKindTag = [progKindButton indexOfSelectedItem];
	[[self class] setProgressiveKind: progKindTag];
}

- (void)changeLossless:(id)sender
{
	BOOL isLossy = ![losslessButton state];
	[J2kText setEnabled: isLossy];
	[J2kSlider setEnabled: isLossy];
	(void)[self compressRate];
}

- (NSString *)suffix
{
	if (formatKindTag == Tag_jp2)
		return @"jp2";
	return (suffixTag == sfxTag_jpc) ? @"jpc" : @"j2k";
}

- (void)saveParameters
{
	NSString *s;
	NSUserDefaults *usrdef = [NSUserDefaults standardUserDefaults];
	s = (suffixTag == sfxTag_jpc) ? @"jpc" : @"j2k";
	[usrdef setObject:s forKey:J2KSuffix];
	s = (formatKindTag == Tag_jp2) ? @"jp2" : @"jpc";
	[usrdef setObject:s forKey:J2KFormat];
	s = (progKindTag == Tag_rate) ? ProgRate : ProgResol;
	[usrdef setObject:s forKey:J2KProgressive];
	if (isLossyFactor(compFactor))
		[usrdef setFloat:compFactor forKey:J2KFactor];
	else
		[usrdef setObject:@"Lossless" forKey:J2KFactor];
}

@end
