#import  "NoiseCtr.h"
#import  <AppKit/NSControl.h>
#import  <AppKit/NSMatrix.h>
#import  <stdio.h>
#import  "../common.h"
#import  "Noiser.h"
#import  "Mosaicker.h"

@implementation NoiseCtr

- (void)doit:(id)sender
{
	id	she;

	if ([sender tag] == 0) {	/* Noise */
		she = [[Noiser alloc] init];
		if (she == nil)
			return;
		[she setFreq:[freqSlider floatValue]
			mag:[magSlider floatValue]
			brightOnly:[brightSW state]];
	}else {
		she = [[Mosaicker alloc] init];
		if (she == nil)
			return;
		[she setGranularity:[granSlider intValue]];
	}
	[she createNewImage];
	[she release];
}

- (void)changeValue:(id)sender
{
	NSString *str;
	id	obj;

	str = [NSString stringWithFormat:@"%4.2f",
		(int)([sender floatValue] * 20.0) / 20.0];
	obj = ([sender tag] == 0) ? freqText : magText;
	[obj setStringValue: str];
}

@end
