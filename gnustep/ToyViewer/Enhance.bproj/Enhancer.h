#import "../ImgOperatorClipped.h"

typedef	const char *t_weight;
typedef	void (*f_enhance)(int *, int, int *);
typedef	void (*f_nonlinear)(int *pix, int num, const unsigned char *vals[3]);

@interface Enhancer:ImgOperatorClipped
{
	float	factor;
}

+ (int)opcode;
+ (NSString *)oprString;
- (id)waitingMessage;

- (BOOL)isLinearFilter;
- (f_enhance)enhanceFunc;
- (f_nonlinear)nonlinearFunc;
- (t_weight)weightTabel:(int *)size;
- (void)setFactor:(float)value;
- (void)prepareCommonValues:(int)num;

- (BOOL)makeNewPlane:(unsigned char **)newmap with:(commonInfo *)newinf;

@end
