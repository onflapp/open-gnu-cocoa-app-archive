#import <AppKit/AppKit.h>
#import "../ImgToolCtrlAbs.h"

@interface SoftFrameCtr: ImgToolCtrlAbs
{
	id	shape;
	id	widthSL;
	id	indicator;
	id	maxtext;
	id	unitRB;
	id	alphaSW;
	id	colorwell;
	id	buttonwell;
	id	welltitle;
	int	widPixel;
	int	widRatio;
}

- (id)init;
- (void)changeAlpha:(id)sender;
- (void)selectShape:(id)sender;
- (void)changeSlider:(id)sender;
- (void)changeUnitSW:(id)sender;
- (void)doit:(id)sender;

@end
