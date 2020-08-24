#import  "../ImgOprAbs.h"

@interface ImageOpr: ImgOprAbs

+ (NSString *)oprString:(int)op;
- (void)doRotateFlipClip:(int)op to:(float)angle;
- (void)convertCMYKtoRGB:sender;

@end


@interface ImageOpr (Mono)

- (void)monochrome:(int)steps tone:(const unsigned char *)tone method:(int)tag;
- (void)brightness:(const unsigned char *)tone;

@end
