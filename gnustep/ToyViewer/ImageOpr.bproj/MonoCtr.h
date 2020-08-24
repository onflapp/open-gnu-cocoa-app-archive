#import <Foundation/NSObject.h>

@interface MonoCtr:NSObject
{
	id	imageOpCtr;
	id	contrSlider;
	id	brightSlider;
	id	gammaSlider;
	id	ditherSW;
	id	stepsSW;
	id	monoView;
	id	valTexts;
	unsigned char	tone[256];
	float	gammaScale[256];
	float	gammaValue;
	BOOL	isScaleRapid;
}

- (id)init;
- (void)changeValue:(id)sender;
- (void)reset:(id)sender;
- (void)setGamma:(float)gamma;
- (void)monochrome:(id)sender;
- (void)changeBrightness:(id)sender;

@end
