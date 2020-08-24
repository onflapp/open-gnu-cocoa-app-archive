#import "../ImgToolCtrlAbs.h"

@interface NoiseCtr : ImgToolCtrlAbs
{
	id	freqSlider;
	id	magSlider;
	id	freqText;
	id	magText;
	id	brightSW;
	id	granSlider;
}

- (void)doit:(id)sender;
- (void)changeValue:(id)sender;

@end
