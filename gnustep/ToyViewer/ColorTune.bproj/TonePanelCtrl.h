#import "../ImgToolCtrlAbs.h"

@interface TonePanelCtrl: ImgToolCtrlAbs
{
	id	mainSlider;
	id	mainIndicator;
	id	colorSliders;		/* Matrix */
	id	colorIndicators;	/* Matrix */
	id	toneview;
}

- (void)reset:(id)sender;
- (void)changeMainValue:(id)sender;
- (void)changeColorValue:(id)sender;
- (void)colorTone:(id)sender;

@end
