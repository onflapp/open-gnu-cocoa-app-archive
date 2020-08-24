
#import  "Dither.h"
#import  <stdlib.h>
#import  <string.h>

@implementation Dither

static const unsigned char ditherTable[4][4] = {
	{  0,  8,  2, 10},
	{ 12,  4, 14,  6},
	{  3, 11,  1,  9},
	{ 15,  7, 13,  5} };

- (void)reset:(int)pixellevel width:(int)width
{
	if (buffer) free((void *)buffer);
	buffer = (unsigned char *)malloc(width);
	lnwidth = width;
	[self reset:pixellevel];
}

- (void)reset:(int)pixellevel
{
	int i, v, pv, cnt;
	float thresh, thstep;

	ylines = 0;
	thresh = 256.0 / (pixellevel - 1) + 0.1;
	thstep = (int)thresh / 17.0;
	threshold[cnt = 0] = pv = 0;
	for (i = 0, v = (int)thresh; i < 256; i++) {
		if (i >= v) {
			threshold[++cnt] = pv = v;
			v = (int)((cnt + 1) * thresh);
			if (v > 255) v = 255;
		}
		sect[i] = cnt;
		grad[i] = (int)((i - pv) / thstep);
	}
	threshold[++cnt] = 255; 
}

- (void)dealloc
{
	free((void *)buffer);
	[super dealloc];
}

- (unsigned char *)buffer
{
	return buffer;
}

- (unsigned char *)getNewLine
{
	int x, cc, n;
	const unsigned char *yp;

	yp = ditherTable[ylines & 0x03];
	for (x = 0; x < lnwidth; x++) {
		cc = buffer[x];
		n = sect[cc];
		if (yp[x & 3] < grad[cc]) ++n;
		buffer[x] = threshold[n];
	}
	ylines++;
	return buffer;
}

- (const unsigned char *)threshold
{
	return threshold;
}

@end
