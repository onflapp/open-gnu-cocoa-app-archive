/*
	Floyd-Steinberg Algorithm

	This routine uses Floyd-Steinberg method tuned for color images.
	Coded by Takeshi Ogihara.
*/
#import  "FScolor.h"
#import  "../getpixel.h"

@implementation FScolor

- (void)colorMapping:(paltype *)pal with:(FScolor *)green and:(FScolor *)blue
{
	int idx, i, j, w, cx;
	FScolor *rgb[3];
	unsigned char *wline;

	rgb[0] = self;
	rgb[1] = green;
	rgb[2] = blue;

	w = workwidth - MARGINAL;
	for (cx = 0; cx < 3; cx++) {
		wline = rgb[cx]->cline;
		for (i = 0; i < MARGINAL; i++) {
			wline[i] = wline[MARGINAL + (i & 1)];
			wline[w+i] = wline[w - 1 - (i & 1)];
		}
	}
	if (first) {
		first = 0;
		for (cx = 0; cx < 3; cx++)
			for (i = 0; i < FirstLOOP; i++)
				(void)[rgb[cx] getNewLine];
	}
	idx = leftToRight ? TableMARGIN : (workwidth - TableMARGIN - 1);
	do {
	    int	rv;
	    int	cl[3], gc[3];
	    unsigned char *p;

	    for (cx = 0; cx < 3; cx++) {
		rv = (int)rgb[cx]->cline[idx] + rgb[cx]->lines[0][idx];
		cl[cx] = (rv > 255) ? 255 : ((rv < 0) ? 0 : rv);
		gc[cx] = grad[cl[cx]];
	    }
	    p = pal[getBestColor(gc[0], gc[1], gc[2])];
	    for (cx = 0; cx < 3; cx++) {
		rv = cl[cx] - p[cx];
		for (i = 0; i < 3; i++) {
		    short *wl = rgb[cx]->lines[i];
		    for (j = -TableMARGIN; j <= TableMARGIN; j++) {
			    if ((w = FSweight[i][j + TableMARGIN]) == 0)
				    continue;
			    wl[idx + j] += (rv * w) / SUM_WEIGHT;
		    }
		}
		rgb[cx]->vline[idx] = p[cx];
	    }
	}while (leftToRight ? (++idx < workwidth - TableMARGIN)
			: (--idx >= TableMARGIN));

	for (cx = 0; cx < 3; cx++) {
		short **ww = rgb[cx]->lines;
		short *pp = ww[0];
		ww[0] = ww[1];
		ww[1] = ww[2];
		ww[2] = pp;
		bzero((char *)pp, sizeof(short) * workwidth);
	}
	leftToRight = !leftToRight;
}

/* Override */
- (unsigned char *)getNewLine
{
	return &vline[MARGINAL];
}

@end
