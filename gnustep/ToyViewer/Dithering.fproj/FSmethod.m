/*
	Floyd-Steinberg Algorithm

	This routine uses Floyd-Steinberg method coded by Takeshi Ogihara.
*/
#import  "FSmethod.h"
#import  <stdlib.h>
#import  <string.h>

@implementation FSmethod

/* extern */ const unsigned char FSweight[3][5] = {
	{2, 5, 0, 5, 2},
	{1, 2, 5, 2, 1},
	{0, 1, 2, 1, 0}
};

- (void)reset:(int)pixellevel width:(int)width
{
	if (buffer) free((void *)buffer);
	if (cline) free((void *)cline);
	if (vline) free((void *)vline);

	workwidth = width + MARGINAL * 2;
	buffer = (short *)malloc(sizeof(short) * workwidth * 3);
	cline = (unsigned char *)malloc(workwidth);
	vline = (unsigned char *)malloc(workwidth);
	if (buffer == NULL || cline == NULL || vline == NULL)
		return;
	lines[0] = buffer;
	lines[1] = lines[0] + workwidth;
	lines[2] = lines[1] + workwidth;
	[self reset:pixellevel];
}

- (void)reset:(int)pixellevel
{
	int i, v;
	float thresh, wadd;

	first = 1;
	bzero((char *)buffer, sizeof(short) * workwidth * 3);
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
	if (buffer) free((void *)buffer);
	if (cline) free((void *)cline);
	if (vline) free((void *)vline);
	[super dealloc];
}

- (unsigned char *)buffer
{
	return &cline[MARGINAL];
}

- (unsigned char *)getNewLine
{
	int idx, i, j, w, rv, val;
	short *p;

	w = workwidth - MARGINAL;
	for (i = 0; i < MARGINAL; i++) {
		cline[i] = cline[MARGINAL + (i & 1)];
		cline[w+i] = cline[w - 1 - (i & 1)];
	}
	if (first) {
		first = 0;
		for (i = 0; i < FirstLOOP; i++)
			(void)[self getNewLine];
	}
	idx = leftToRight ? TableMARGIN : (workwidth - TableMARGIN - 1);
	do {
		rv = (int)cline[idx] + lines[0][idx];
		val = (rv > 255) ? 255 : ((rv < 0) ? 0 : grad[rv]);
		rv -= val;
		for (i = 0; i < 3; i++)
			for (j = -TableMARGIN; j <= TableMARGIN; j++) {
				if ((w = FSweight[i][j + TableMARGIN]) == 0)
					continue;
				lines[i][idx + j] += (rv * w) / SUM_WEIGHT;
			}
		vline[idx] = val;
	}while (leftToRight ? (++idx < workwidth - TableMARGIN)
			: (--idx >= TableMARGIN));

	p = lines[0];
	lines[0] = lines[1];
	lines[1] = lines[2];
	lines[2] = p;
	bzero((char *)p, sizeof(short) * workwidth);
	leftToRight = !leftToRight;

	return &vline[MARGINAL];
}

- (const unsigned char *)threshold
{
	return threshold;
}

@end
