#import "ToyWinVector.h"

@interface ToyWinEPS : ToyWinVector

/* Overload */
- (NSData *)openEPSData;

- (NSData *)rotateEPS:(int)op to:(int)angle width:(int)lx height:(int)ly name:(NSString *)fname error:(int *)err;
- (NSData *)clipEPS:(NSRect)select error:(int *)err;
- (NSData *)resizeEPS:(float)factor name:(NSString *)fname error:(int *)err;

@end


@interface ToyWinEPS (Readin)

/* Overload */
- (void)makeComment:(commonInfo *)cinf;
- (commonInfo *)drawToyWin:(NSString *)fileName type:(int)type
	map:(unsigned char **)map err:(int *)err;

/* NEW */
- (NSData *)openDataFromFile:(NSString *)fileName err:(int *)err;

@end
