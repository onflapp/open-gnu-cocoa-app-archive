#include  "common.h"

#define  PBMa	1	/* pbm (bits) in ASCII */
#define  PGMa	2	/* pgm (gray) in ASCII */
#define  PPMa	3	/* ppm (color) in ASCII */
#define  PBMb	4	/* pbm (bits) in BINARY */
#define  PGMb	5	/* pgm (gray) in BINARY */
#define  PPMb	6	/* ppm (color) in BINARY */
#define  isPPMascii(x)	((x)==PBMa || (x)==PGMa || (x)==PPMa)
#define  PPMname(x)	(&"PPM\0PBM\0PGM"[(x)%3 * 4])

commonInfo *loadPpmHeader(FILE *, int *);
void setGIFWrongIndexBlack(int);
int ppmGetImage(FILE *, commonInfo *, unsigned char **, const char *);
