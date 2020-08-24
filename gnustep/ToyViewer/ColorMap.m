/*
	getmap.c	1995-07-02
	ColorMap.m	1995-12-18
		by T.Ogihara (ogihara@seg.kobe-u.ac.jp)

	Checks number of color used in the image.
	Reduces color by median cut algorithm (MCA) of Paul Heckbert.
	This code refers to "ppmquant" of Jef Poskanzer, but, in
	many cases, this program could generate more beautiful image.
*/


#import  "ColorMap.h"
#import  <stdio.h>
#import  <stdlib.h>
#import  <string.h>
#import  <AppKit/NSColor.h>
#import  <AppKit/NSControl.h>
#import  "common.h"
#import  "getpixel.h"
#import  "colormapsub.h"


#if EnoughMemory
# define  COLORSTEPS		65536	/* = 0x10000 */
# define  MAXColors		62000	/* < COLORSTEPS */
# define  ColorHash(r,g,b)	(((r)<<8) | ((g)<<4) | ((b)>>2)) /* Hash KEY */
# define  ColorHnew(x)		(((x) + 5987) & 0xffff)
#else
# define  COLORSTEPS		32768	/* = 32 ^ 3 = 0x8000 */
# define  MAXColors		30000	/* < COLORSTEPS */
# define  ColorHash(r,g,b)	(((r)<<7) | ((g)<<2) | ((b)>>3)) /* Hash KEY */
# define  ColorHnew(x)		(((x) + 5987) & 0x7fff)
#endif

typedef struct {
	int 	count;
	unsigned char red, green, blue;
	unsigned char palidx;	/* index for palette */
} tabcell;

typedef struct {
	int index;	/* Begining of this area in pindex */
	int colors;	/* the number of elements of pindex */
	int sum;
	unsigned char axis;
	float diff;
} element;

/* quick sort */
static int q_red(int);
static int q_green(int);
static int q_blue(int);
static int q_colors(int);
static int q_count(int);
static int q_palette(int);

static int hashIndex(int, int, int);
static void sortMaxElement(element *);
static void makepalette(element *, int, BOOL);
static tabcell *hashIndexCheck(int r, int g, int b);


@implementation ColorMap

static tabcell  *hashtab;
static indexint *pindex;	/* indirect index to hashtab */
static paltype  *pal;
static long	colornum;	/* Number of colors used in the image */
static long	totalnum;
static BOOL	hasalpha;
static BOOL	fourBitPal;
static int	palcolors;

int mapping(int r, int g, int b)
{
	return hashtab[hashIndex(r,g,b)].palidx;
}

int getBestColor(int r, int g, int b)
{
	int	x, i, w[3], xmin = 0;
	long	dmin, dt;
	unsigned char *p;
	tabcell	*tp;

	r &= 0xfc;
	g &= 0xfc;
	b &= 0xfc;
	tp = hashIndexCheck(r,g,b);
	if (tp->count > 0)
		return tp->palidx;
	dmin = 256*256*3;
	for (x = 0; x < palcolors; x++) {
		p = pal[x];
		w[RED] = p[RED] - r;
		w[GREEN] = p[GREEN] - g;
		w[BLUE] = p[BLUE] - b;
		for (i = 0, dt = 0L; i < 3; i++)
			dt += w[i] * w[i];
		if (dt == 0) {
			xmin = x;
			break;
		}
		if (dmin > dt)
			dmin = dt, xmin = x;
	}
	if (colornum < MAXColors) {
		tp->red = r;
		tp->green = g;
		tp->blue = b;
		tp->count = 1;
		tp->palidx = xmin;
		colornum++;
	}
	return xmin;
}


- (id)init
{
	[super init];
	hashtab = NULL;
	pindex = NULL;
	pal = NULL;
	fourBitPal = NO;
	return self;
}

- (void)setFourBitsPalette:(BOOL)flag
{
	fourBitPal = flag;
}

- (id)mallocForFullColor
{
	hashtab = (tabcell *)calloc(COLORSTEPS, sizeof(tabcell));
	pindex = (indexint *)calloc(COLORSTEPS, sizeof(indexint));
	pal = (paltype *)calloc(FIXcount, sizeof(paltype));
	if (!hashtab || !pindex || !pal)
		return nil;
	return self;
}

- (id)mallocForPaletteColor
{
	hashtab = (tabcell *)calloc(COLORSTEPS, sizeof(tabcell));
	if (!hashtab)
		return nil;
	return self;
}

- (void)dealloc
{
	if (hashtab) free((void *)hashtab), hashtab = NULL;
	if (pindex) free((void *)pindex), pindex = NULL;
	if (pal) free((void *)pal), pal = NULL;
	[super dealloc];
}

- (void)tabInitForRegColors
{
	int i;

	for (i = 0; i < COLORSTEPS; i++)
		pindex[i] = i;
	bzero((void *)hashtab, sizeof(tabcell)*COLORSTEPS);
	colornum = 0;
	totalnum = 0;
	hasalpha = NO;
}

- (int)getAllColor:(refmap)map limit:(int)limit alpha:(BOOL *)alpha
    /* Returns the number of colors used in the image.
	"limit" is the upper limit of the number, where alpha color
	is not included.
	If limit=0, then "MAXColors" is used as the upper limit.
	In the case that the number of colors is too much, or in the
	case that no need to count any more, this method returns
	COLORSTEPS and set "colorum" 0.
    */
{
	int r, g, b, a;
	int maxclr = MAXColors - 1;

	if (limit > 0) maxclr = limit;
	[self tabInitForRegColors];
	resetPixel(map, 0);
	while (getPixel(&r, &g, &b, &a) >= 0) {
		if (a != AlphaTransp) {
			(void)hashIndex(r,g,b);
			if (colornum > maxclr)
				break;	/* Too many color */
		}else hasalpha = YES;
	}
	*alpha = hasalpha;
	if (colornum > maxclr) { /* Too many color */
		colornum = 0;
		return COLORSTEPS;
	}
	return colornum;
}

- (int)getAllColor:(refmap)map limit:(int)limit
    /* Returns the number of colors used in the image as the previous
	method.  However, alpha color is counted as white.
	You can use this method to convert the image into other format
	which does not have alpha channel.
    */
{
	BOOL alpha;
	int cnum;
	int maxclr = MAXColors - 1;

	if (limit > 0) maxclr = limit;
	cnum = [self getAllColor:map limit:maxclr alpha:&alpha];
	if (cnum > maxclr)	/* Too many color */
		return COLORSTEPS;
	if (alpha) {
		(void)hashIndex(255, 255, 255);	/* for transparent */
		if ((cnum = colornum) > maxclr) {  /* Too many color */
			colornum = 0;
			return COLORSTEPS;
		}
	}
	return cnum;
}


- (int)regColorToMap: (int)red : (int)green : (int)blue
    /* Counts the number of colors as "getAllColor:".
	With too much colors, it returns -1 and sets "colornum" 0.
    */
{
	(void)hashIndex(red, green, blue);
	totalnum++;
	if (colornum >= MAXColors) {
		colornum = 0;
		return -1;
	}
	return colornum;
}

- (int)regPalColorWithAlpha:(BOOL)alpha
	/* Registers colors in the palette into the Hash Table */
{
	int r, g, b, idx;
	BOOL hasWhite = NO;

	colornum = 0;
	hasalpha = NO;
	for (idx = 0; getPalPixel(&r, &g, &b) >= 0; idx++) {
		hashtab[hashIndex(r,g,b)].palidx = idx;
		if (!hasWhite && r == 255 && g == 255 && b == 255)
			hasWhite = YES;
	}
	if (alpha && !hasWhite) {
		if (idx >= FIXcount)
			return (FIXcount + 1);	/* no room */
		hashtab[hashIndex(255,255,255)].palidx = idx++;
	}
	return idx;	/* return number of colors */
}

- (void)regGivenPal:(paltype *)gpal colors:(int)cnum
	/* Registers colors in the given palette into the Hash Table */
{
	int idx, i;
	unsigned char *p;

	[self tabInitForRegColors];
	palcolors = cnum;
	for (idx = 0; idx < palcolors; idx++) {
		p = gpal[idx];
		hashtab[hashIndex(p[RED],p[GREEN],p[BLUE])].palidx = idx;
		for (i = 0; i < 3; i++)
			pal[idx][i] = p[i];
	}
}

- (paltype *)getNormalmap:(int *)cnum
    /* It returns the palette after "getAllColor:" method.
	Colors should not be more than 256.
    */
{
	unsigned char *p;
	tabcell *t;
	int i, x, num;

	quicksort(COLORSTEPS, pindex, q_colors);
	for (i = 0, num = 0; i < COLORSTEPS && num < FIXcount; i++) {
		if (hashtab[x = pindex[i]].count == 0) continue;
		t = &hashtab[x];
		p = pal[num];
		p[RED]   = t->red;
		p[GREEN] = t->green;
		p[BLUE]  = t->blue;
		t->palidx = num++;
	}
	*cnum = num;
	return pal;
}


- (paltype *)getReducedMap:(int *)cnum alpha:(BOOL)alpha
	/* Median Cut Algorithm */
{
	int i, k=0, w;
	element elm[FIXcount];
	int ncolors, elmptr, curelm;
	int indx, clrs, sm, rgb=0, thresh;
	int halfsum, lowersum;

	ncolors = *cnum;
	if (ncolors < 2 || ncolors > FIXcount)
		ncolors = FIXcount;
	if (alpha) ncolors--; 
	quicksort(COLORSTEPS, pindex, q_count);
	for (i = 0; i < COLORSTEPS; i++)
		if (hashtab[pindex[i]].count) break;
	elm[0].index = i;
	elm[0].colors = COLORSTEPS - i;
	elm[0].sum = totalnum;
	sortMaxElement(&elm[0]);
    
	for (elmptr = 1; elmptr < ncolors; elmptr++) {
		/* Find largest element */
		curelm = -1;
		w = 2;	/* should be divided */
		for (i = 0; i < elmptr; i++) {
			int t = elm[i].colors * elm[i].diff;
			if (t >= w)
				w = t, curelm = i;
		}
		if (curelm < 0)
			break;	/* all color was found */
		indx = elm[curelm].index;
		clrs = elm[curelm].colors;
		sm = elm[curelm].sum;
		rgb = elm[curelm].axis;

		/* Find the median */
		w = clrs - 1;
		lowersum = 0;
		halfsum = sm / 2;
		for (i = 0; i < w && lowersum < halfsum; i++) {
			int s, px;
			s = lowersum + hashtab[px = pindex[indx + i]].count;
			if (s > halfsum) {
				if (s - halfsum > halfsum - lowersum)
					break;
			}
			lowersum = s;
			k = px;
		}
		thresh = (rgb == RED) ? hashtab[k].red
		    : ((rgb == GREEN) ? hashtab[k].green : hashtab[k].blue);

		/* Divide the box */
		elm[curelm].colors = i;
		elm[curelm].sum = lowersum;
		sortMaxElement(&elm[curelm]);
		elm[elmptr].index = indx + i;
		elm[elmptr].colors = clrs - i;
		elm[elmptr].sum = sm - lowersum;
		sortMaxElement(&elm[elmptr]);
	}

	makepalette(elm, elmptr, alpha);
	*cnum = palcolors = elmptr;
	return pal;
}

- (paltype *)getPalette
{
	paltype *p = pal;
	pal = NULL;
	return p;
}

@end


static int hashIndex(int r, int g, int b)
{
	tabcell *tp;
	int x = ColorHash(r,g,b);

	tp = &hashtab[x];
	while (tp->count > 0
	    && (tp->red != r || tp->green != g || tp->blue != b))
		tp = &hashtab[x = ColorHnew(x)];
	if (tp->count == 0) {
		tp->red = r;
		tp->green = g;
		tp->blue = b;
		colornum++;
	}
	tp->count++;
	return x;
}

static tabcell *hashIndexCheck(int r, int g, int b)
{
	tabcell *tp;
	int x = ColorHash(r,g,b);

	tp = &hashtab[x];
	while (tp->count > 0
	    && (tp->red != r || tp->green != g || tp->blue != b))
		tp = &hashtab[x = ColorHnew(x)];
	return tp;
}

static void sortMaxElement(element *elemp)
{
	int i, j, end;
	int indx, clrs, rgb;
	unsigned short min[3], max[3], val[3];
	float bright[3];
	tabcell *t;

	/* Find the minimum and maximum of each component */
	indx = elemp->index;
	clrs = elemp->colors;
	for (i = 0; i < 3; i++)
		min[i] = 255, max[i] = 0;
	end = indx + clrs;
	for (i = indx; i < end; i++) {
		t = &hashtab[pindex[i]];
		if (t->count == 0)
			continue;
		val[RED]   = t->red;
		val[GREEN] = t->green;
		val[BLUE]  = t->blue;
		for (j = 0; j < 3; j++) {
			if (min[j] > val[j]) min[j] = val[j];
			if (max[j] < val[j]) max[j] = val[j];
		}
	}
	/* calculate brightness */
	for (i = 0; i < 3; i++) {
		int d = max[i] - min[i];
		if (fourBitPal && d < 0x11)
			d = 0;
		bright[i] = d;
	}
/* Old Version...
	bright[RED] *= 0.299;
	bright[GREEN] *= 0.587;
	bright[BLUE] *= 0.114;
*/
	bright[RED] *= 0.6;
	bright[BLUE] *= 0.3;

	if ( bright[RED] >= bright[GREEN] && bright[RED] >= bright[BLUE] ) {
		quicksort(clrs, &pindex[indx], q_red);
		rgb = RED;
	}else if ( bright[GREEN] >= bright[BLUE] ) {
		quicksort(clrs, &pindex[indx], q_green);
		rgb = GREEN;
	}else {
		quicksort(clrs, &pindex[indx], q_blue);
		rgb = BLUE;
	}
	elemp->axis = rgb;
	elemp->diff = bright[rgb];
}

static void makepalette(element *elm, int cellnum, BOOL alpha)
{
	int indx, clrs, i, ex, best;
	long r, g, b, w, sum;
	unsigned char *p;
	tabcell *t;

	for (ex = 0; ex < cellnum; ex++) {
		indx = elm[ex].index;
		clrs = elm[ex].colors;
		r = g = b = 0, sum = 0;
		p = pal[ex];

		w = indx + clrs;
		for (i = indx; i < w; i++) {
			int c = (t = &hashtab[pindex[i]])->count;
			r += t->red * c;
			g += t->green * c;
			b += t->blue * c;
			sum += c;
		}
		p[RED]   = ((r /= sum) < 256) ? r : 255;
		p[GREEN] = ((g /= sum) < 256) ? g : 255;
		p[BLUE]  = ((b /= sum) < 256) ? b : 255;
		if (fourBitPal)
			for (i = 0; i < 3; i++) {
				int a = p[i] & 0xf0;
				p[i] = a | (a >> 4);
			}
	}

	/* Values of pindex[] are not used any more.
	   Sort the palette. */
	for (i = 0; i < cellnum; i++)
		pindex[i] = i;
	quicksort(cellnum, pindex, q_palette);

	for (ex = 0; ex < cellnum; ex++) {
		unsigned char *q;
		int x, y;
		x = pindex[ex];
		if (ex == x) continue;
		for (y = ex+1; y < cellnum; y++)
			if (pindex[y] == ex) break;
		p = pal[x];
		q = pal[ex];
		for (i = 0; i < 3; i++)
			r = p[i], p[i] = q[i], q[i] = r;
		pindex[ex] = ex;
		pindex[y] = x;
	}

	if (alpha /* && cellnum < FIXcount */) {
		p = pal[cellnum];
		for (i = 0; i < 3; i++)
			p[i] = 255;
	}
	
	for (i = 0; i < COLORSTEPS; i++) {
		if (hashtab[i].count == 0) continue;
		t = &hashtab[i];
		r = t->red;
		g = t->green;
		b = t->blue;
		w = 4 * 256 * 256;
		best = 0;
		for (ex = 0; ex < cellnum; ex++) {
			long rr, gg, bb;
			p = pal[ex];
			rr = r - p[RED];
			gg = g - p[GREEN];
			bb = b - p[BLUE];
			if ((sum = rr*rr + gg*gg + bb*bb) < w)
				w = sum, best = ex;
		}
		t->palidx = best;
	}
}

/* Functions for Quicksort... */
static int q_red(int x) { return hashtab[x].red; }
static int q_green(int x) { return hashtab[x].green; }
static int q_blue(int x) { return hashtab[x].blue; }
static int q_count(int x) { return hashtab[x].count; }
static int q_colors(int x) {
	tabcell *t = &hashtab[x];
	return (t->count)
		? ((t->red << 16) | (t->green << 8) | t->blue) : 0;
}
static int q_palette(int x) {
	unsigned char *p = pal[x];
	return ((p[RED] << 16) | (p[GREEN] << 8) | p[BLUE]);
}
