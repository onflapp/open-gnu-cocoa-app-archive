#import "ToyWin.h"

@interface ToyWinPPM : ToyWin
{
	const char **execList;
	const char *extension;
}

- (commonInfo *)drawToyWin:(NSString *)fileName type:(int)type
	map:(unsigned char **)map err:(int *)err;
- (void)setExecList: (const char **)list ext: (const char *)type;
	/* list is free-ed by this obj */

@end
