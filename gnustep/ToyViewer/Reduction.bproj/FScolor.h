#import  <Dithering/FSmethod.h>
#import  "../ColorMap.h"

@interface FScolor: FSmethod

- (void)colorMapping:(paltype *)pal with:(FScolor *)green and:(FScolor *)blue;
- (unsigned char *)getNewLine;	/* Override */

@end
