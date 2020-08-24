#import "../ImgOperatorClipped.h"

@interface Noiser:ImgOperatorClipped
{
	int	freq;
	int	mag;
	BOOL	brightOnly;
}

+ (int)opcode;
+ (NSString *)oprString;

- (void)setFreq:(float)fval mag:(float)mval brightOnly:(BOOL)flag;
- (BOOL)makeNewPlane:(unsigned char **)newmap with:(commonInfo *)newinf;

@end
