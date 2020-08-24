#import <Foundation/Foundation.h>
#import "../ImgToolCtrlAbs.h"
#import "../dcttable.h"

@interface SmResizeCtr: ImgToolCtrlAbs
{
	id	imageOpCtr;
	id	slider;
	id	methodButton;
	id	scaleText;
	id	ratioText;
	id	autoButton;
	id	newSizeText;
	NSSize	currentSize;
	float	svalue;
	int	ratiox;
}

- (id)init;
- (void)didGetNotification:(NSNotification *)notify;
- (void)resetValue:(id)sender;
- (void)changeValue:(id)sender;
- (void)changeText:(id)sender;
- (void)setCurrentScale:(id)sender;
- (void)getRatio:(int *)b :(int *)a;
- (void)getFactor:(float *)factor;
- (void)setAutoDetect:(id)sender;
- (void)doResize:(id)sender;

@end
