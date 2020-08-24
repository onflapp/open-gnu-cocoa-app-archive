/*
	Mean Density Approximation Method
	by Y.Kurosawa: "A Bilevel Display Technique for Gray Pictures Using
	Mean Density Approximation", Trans. IPSJ, Vol.26, No.1, pp.153-160,
	Jan. 1985 (in Japanese).

	This routine uses modified MDA method coded by Takeshi Ogihara.
*/
#import  "MDAmethod.h"
#import  <stdlib.h>
#import  <string.h>

@implementation MDAmethod

#define  CUR_WEIGHT	10
static const unsigned char weight[3][5] = {
	{0, 1, 2, 1, 0},
	{1, 2, 5, 2, 1},
	{2, 5, 0, 5, 2}
};


- (void)reset:(int)pixellevel width:(int)width
{
	if (lines[0])
		free((void *)buffer);
	buffer = (unsigned char *)malloc(width * 3);
	lines[0] = buffer;
	lines[1] = lines[0] + width;
	lines[2] = lines[1] + width;
	lnwidth = width;
	[self reset:pixellevel];
}

- (void)reset:(int)pixellevel
{
	int i, v;
	float thresh, wadd;

	first = 1;
	thresh = 256.0 / (pixellevel - 1) + 0.1;
	leftToRight = YES;
	if (pixellevel == 2) {
		for (i = 0; i < 128; i++) grad[i] = 0;
		for ( ; i < 256; i++) grad[i] = 255;
		threshold[0] = 0;
		threshold[1] = 255;
	}else {
		wadd = thresh / 2.0;
		for (i = 0; i < 256; i++) {
			v = (int)((i + wadd) / thresh) * thresh;
			if (v >= 255) break;
			grad[i] = (v < 0) ? 0 : v;
		}
		for ( ; i < 256; i++) grad[i] = 255;
		for (i = 0; i < 16; i++) {
			if ((v = thresh * i) >= 255) {
				threshold[i] = 255;
				break;
			}
			threshold[i] = v;
		}
	} 
}

- (void)dealloc
{
	free((void *)buffer);
	[super dealloc];
}

- (unsigned char *)buffer
{
	return lines[2];
}

- (unsigned char *)getNewLine
{
	int totalv, totalw;
	int idx, i, j, w, low, high;
	unsigned char *p;

	if (first) {
		memcpy(lines[0], lines[2], lnwidth);
		memcpy(lines[1], lines[2], lnwidth);
		first = 0;
	}
	idx = leftToRight ? 0 : (lnwidth - 1);
	do {
		if ((low = idx - 2) < 0) low = 0;
		if ((high = idx + 2) >= lnwidth) high = lnwidth - 1;
		totalv = 0;
		totalw = 0;
		for (i = 0; i < 3; i++)
			for (j = low; j < high; j++) {
				if ((w = weight[i][j + 2 - idx]) == 0)
					continue;
				totalw += w;
				totalv += lines[i][j] * w;
			}
	
		/* (totalv + X * WEIGHT) / (totalw + WEIGHT) ~= val */
		/* (totalv + X * WEIGHT) ~= val * (totalw + WEIGHT) */
		/* X * WEIGHT ~= val * (totalw + WEIGHT) - totalv */
		w = (lines[2][idx] * (totalw + CUR_WEIGHT) - totalv)
			/ CUR_WEIGHT;
		lines[2][idx] = (w > 255) ? 255 : ((w < 0) ? 0 : grad[w]);
	}while (leftToRight ? (++idx < lnwidth) : (--idx >= 0));

	p = lines[0];
	lines[0] = lines[1];
	lines[1] = lines[2];
	lines[2] = p;
	leftToRight = !leftToRight;

	return lines[1];
}

- (const unsigned char *)threshold
{
	return threshold;
}

@end
