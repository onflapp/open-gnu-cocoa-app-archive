#import <AppKit/AppKit.h>
#import "Dithering.h"

#define  MAXHalftoneLevel  256	/* was 16 */

@interface Dither:NSObject <Dithering>
{
	unsigned char *buffer;
	int lnwidth;
	int ylines;
	unsigned char sect[256];	/* section */
	unsigned char grad[256];	/* 0 - 16 */
	unsigned char threshold[MAXHalftoneLevel + 2];
}

@end
