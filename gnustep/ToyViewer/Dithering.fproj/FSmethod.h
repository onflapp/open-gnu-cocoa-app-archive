#import <AppKit/AppKit.h>
#import "Dithering.h"

@interface FSmethod:NSObject <Dithering>
{
	short *buffer;
	short *lines[3];
	unsigned char *cline;
	unsigned char *vline;
	int first;
	int workwidth;
	BOOL leftToRight;
	unsigned char grad[256];
	unsigned char threshold[16];
}

@end

#define  FirstLOOP	10
#define  MARGINAL	10
#define  TableMARGIN	2
#define  SUM_WEIGHT	22
extern const unsigned char FSweight[3][5];
