#import "../ImgOperator.h"


@interface ColorTuner:ImgOperator
{
	float	*ratio;
	float	satval;
}

+ (int)opcode;
+ (NSString *)oprString;

- (void)setSaturation:(float)sval andHue:(float *)hval;
- (BOOL)makeNewPlane:(unsigned char **)newmap with:(commonInfo *)newinf;
- (id)waitingMessage;
- (BOOL)checkInfo:(NSString *)filename;

@end
