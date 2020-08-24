#import  "../ImgOperator.h"

enum {
	post_POST, post_SMOOTH, post_MIX
};

@interface Posterizer:ImgOperator
{
	float	divfactor;
	float	clrfactor;
	int	option;
}

+ (int)opcode;
+ (NSString *)oprString;

- (BOOL)makeNewPlane:(unsigned char **)newmap with:(commonInfo *)newinf;
- (id)waitingMessage;

- (id)init;
- (void)setOption:(int)opt;
- (void)dealloc;
- (void)setDivFactor:(float)dval andColorFactor:(float)cval;

@end
