#import "../ImgToolCtrlAbs.h"
#import <AppKit/AppKit.h>

@interface ColorChangeCtr: ImgToolCtrlAbs
{
	id	comparison;
	id	newAlpha;
	id	newWell;
	id	origAlpha;
	id	origWell;
	id	methodMenu;
	id	whichside;
}

- (void)changeAlpha:(id)sender;
- (void)doit:(id)sender;

@end
