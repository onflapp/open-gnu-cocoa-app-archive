#import  "TonePanelCtrl.h"
#import  <AppKit/NSControl.h>
#import  <AppKit/NSMatrix.h>
#import  <stdio.h>
#import  "../common.h"
#import  "ColorTuner.h"
#import  "ColorToneView.h"
#import  "colorEnhance.h"


@implementation TonePanelCtrl

/* Local Method */
- (id)setFormatFloat:(float)value to:target
{
	NSString *str;

	str = [NSString stringWithFormat:@"%4.2f", (int)(value * 20.0) / 20.0];
	[target setStringValue:str];
	return target;
}

/* Local Method */
- (void)getToneParameters:(float *)param
{
	int i;

	for (i = 0; i < N_Colors; i++)
	    param[i]
		= [[colorSliders cellAtRow:i column:0] floatValue] - 1.0;
}

- (void)reset:(id)sender
{
	int	i;
	float	param[N_Colors];

	if ([sender selectedTag] == 0) {
		[mainSlider setFloatValue:1.0];
		[self setFormatFloat:1.0 to:mainIndicator];
		return;
	}
	for (i = 0; i < N_Colors; i++) {
		[[colorSliders cellAtRow:i column:0] setFloatValue:1.0];
		[self setFormatFloat:1.0
			to:[colorIndicators cellAtRow:i column:0]];
		param[i] = 0.0;
	} 
	[toneview setToneParameters: param];
	[toneview display];
}

- (void)changeMainValue:(id)sender
{
	[self setFormatFloat:[mainSlider floatValue] to:mainIndicator];
}

- (void)changeColorValue:(id)sender
{
	int	tag;
	float	param[N_Colors];

	tag = [[sender selectedCell] tag];
	[self getToneParameters: param];
	[self setFormatFloat:param[tag]+1.0
		to:[colorIndicators cellAtRow:tag column:0]];
	[toneview setToneParameters: param];
	[toneview display];
}

- (void)colorTone:(id)sender
{
	float	values[N_Colors];
	id	she;

	[self getToneParameters: values];
	she = [[ColorTuner alloc] init];
	if (she == nil)
		return;
	[she setSaturation:[mainSlider floatValue] andHue:values];
	[she createNewImage];
	[she release];
}

@end
