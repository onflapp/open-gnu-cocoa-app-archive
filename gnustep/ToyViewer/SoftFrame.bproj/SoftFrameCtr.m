#import  "SoftFrameCtr.h"
#import  <AppKit/NSColorWell.h>
#import  <AppKit/NSTextField.h>
#import  <AppKit/NSColor.h>
#import  "../ImageOpCtr.h"
#import  "../common.h"
#import  "SoftFramer.h"
#import  "SFAqua.h"

@implementation SoftFrameCtr

- (id)init
{
	[super init];
	widPixel = 16;
	widRatio = 10;
	return self;
}

- (void)changeAlpha:(id)sender
{
	[colorwell setEnabled:![alphaSW state]]; 
}

- (void)selectShape:(id)sender
{
	BOOL	alphaON, sliderON, bwellON, unitON;
	int tag = [shape selectedTag];

	switch (tag) {
	case S_BezelConvex:
	case S_BezelConcave:
		alphaON = NO;
		sliderON = unitON = YES;
		bwellON = NO;
		break;
	case S_AquaRect:
		alphaON = NO;
		sliderON = YES;
		unitON = NO;
		bwellON = YES;
		[unitRB selectCellWithTag:0];	/* in Pixel */
		[self changeUnitSW: self];
		break;
	case S_AquaOval:
		alphaON = NO;
		sliderON = unitON = NO;
		bwellON = YES;
		break;
	default:
		alphaON = YES;
		sliderON = unitON = YES;
		bwellON = NO;
		break;
	}

	if (alphaON)
		[alphaSW setEnabled:YES];
	else {
		[alphaSW setState:NO];
		[self changeAlpha:self];
		[alphaSW setEnabled:NO];
	}
	[widthSL setEnabled: sliderON];
	[unitRB setEnabled: unitON];
	[buttonwell setEnabled: bwellON];
	[welltitle setTextColor:
		(bwellON ? [NSColor blackColor]
		: [NSColor colorWithCalibratedWhite:0.9 alpha:1.0])];
}

static void get256RGB(NSColor *color, int rgb[])
{
	int	i;
	float	cl[3];

	[[color colorUsingColorSpaceName:NSCalibratedRGBColorSpace]
		getRed:&cl[0] green:&cl[1] blue:&cl[2] alpha:NULL];
	for (i = 0; i < 3; i++)
		rgb[i] = cl[i] * 255;
}

- (void)changeSlider:(id)sender
{
	if ([unitRB selectedTag] == 0) {	/* in Pixel */
		widPixel = [widthSL intValue];
		[indicator setIntValue: widPixel];
	}else {
		widRatio = [widthSL intValue];
		[indicator setStringValue:
			[NSString stringWithFormat:@"%d%%", widRatio]];
	}
}

- (void)changeUnitSW:(id)sender
{
	if ([unitRB selectedTag] == 0) {	/* in Pixel */
		[widthSL setIntValue: widPixel];
		[maxtext setStringValue:@"50pix."];
	}else {
		[widthSL setIntValue: widRatio];
		[maxtext setStringValue:@"50%"];
	}
	[self changeSlider: self];
}

- (void)doit:(id)sender
{
	int	i, tag;
	int	color[MAXPLANE], bcol[MAXPLANE];
	id	she;
	BOOL	alpf = [alphaSW state];

	if (alpf) {
		for (i = 0; i < 3; i++)
			color[i] = 255;
		color[ALPHA] = AlphaTransp;
	}else {
		get256RGB([colorwell color], color);
		color[ALPHA] = AlphaOpaque;
	}

	tag = [shape selectedTag];
	if (tag == S_AquaRect || tag == S_AquaOval) {
		she = [[SFAqua alloc] init];
		get256RGB([buttonwell color], bcol);
		[she setButtonColor: bcol];
	}else
		she = [[SoftFramer alloc] init];
	if (she == nil)
		return;
	[she setFrame:tag bgColor:color withAlpha:alpf];
	if ([unitRB selectedTag] == 0)	/* in Pixel */
		[she setFrameWidth: widPixel];
	else
		[she setFrameRatio: widRatio/100.0];
	[she createNewImage];
	[she release];
}


@end
