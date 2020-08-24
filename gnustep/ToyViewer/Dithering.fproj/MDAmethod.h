#import <AppKit/AppKit.h>
#import "Dithering.h"

@interface MDAmethod:NSObject <Dithering>
{
	unsigned char *buffer;
	unsigned char *lines[3];
	int first;
	int lnwidth;
	BOOL leftToRight;
	unsigned char grad[256];
	unsigned char threshold[16];
}

@end
