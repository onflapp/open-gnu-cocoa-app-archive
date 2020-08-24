#import "../ImgOperatorClipped.h"

@interface Mosaicker:ImgOperatorClipped
{
	int	granul;
	id	colormap;
}

+ (int)opcode;
+ (NSString *)oprString;

- (id)init;
- (void)dealloc;

- (void)setGranularity:(int)val;
- (commonInfo *)makeNewInfo;
- (BOOL)makeNewPlane:(unsigned char **)newmap with:(commonInfo *)newinf;

@end
