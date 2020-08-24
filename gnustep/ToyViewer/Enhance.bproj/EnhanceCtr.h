#import "../ImgToolCtrlAbs.h"

@interface EnhanceCtr : ImgToolCtrlAbs
{
	id	enhanceSlider;
	id	blurSlider;
	id	contourCtrl;
	id	whichside;
}

- (void)enhance:(id)sender;
- (void)blur:(id)sender;
- (id)contourCtrl;

@end
