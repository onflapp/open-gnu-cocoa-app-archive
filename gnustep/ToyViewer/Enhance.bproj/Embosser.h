#import "Enhancer.h"

@interface Embosser:Enhancer
{
	float	bright;
	int	embossDirection;
}

+ (int)opcode;
+ (NSString *)oprString;

- (void)setupWith:(ToyView *)tv;
- (BOOL)isMono;
- (f_enhance)enhanceFunc;
- (t_weight)weightTabel:(int *)size;

- (id)init;
- (void)setFactor:(float)fval andBright:(float)bval;
- (void)setEmbossDirection:(int)tag;
- (void)prepareCommonValues:(int)num;

- (BOOL)makeNewPlane:(unsigned char **)newmap with:(commonInfo *)newinf;
- (id)waitingMessage;

@end
