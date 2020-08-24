#import "ToyWinPPM.h"

@interface ToyWinPCD : ToyWinPPM

+ (void)setBase:(int)base bright:(int)bright;
- (commonInfo *)drawToyWin:(NSString *)fileName type:(int)type
	map:(unsigned char **)map err:(int *)err;
- (void)setting;

@end
