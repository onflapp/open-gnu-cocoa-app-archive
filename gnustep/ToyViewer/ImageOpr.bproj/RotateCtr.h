#import  <Foundation/NSObject.h>

@interface RotateCtr: NSObject
{
	id	imageOp;
	id	angleSlider;
	id	angleStepper;
	id	angleText;
	id	rotView;
	id	smoothSW;
	float	value;
}

// - (id)init;
- (int)intValue:(id)sender;
- (int)floatValue:(id)sender;
- (void)changeValue:(id)sender;
- (void)adjustValue:(id)sender;
- (void)writenAngle:(id)sender;
- (void)doit:(id)sender;

@end
