#import  "Posterizer.h"
#import  <AppKit/NSTextField.h>
#import  <Foundation/NSBundle.h>	/* LocalizedString */
#import  <stdio.h>
#import  <stdlib.h>
#import  <string.h>
#import "../colorLuv.h"
#import "../AlertShower.h"
#import "../WaitMessageCtr.h"
#import "../common.h"
#import "../getpixel.h"
#import "../imfunc.h"

#define  CellMAX(n)	((n) >> 2)
#define  DiffHUGE	(LuvColorWidth * LuvColorWidth * 3)
#define  AvrMAX		1000
#define  AlphaMark	255

typedef  int	area_t;			/* 32 bits */
typedef  unsigned char	brite_t;

typedef struct _area_cell {
	long	rgb[3];
	long	count;
	long	alias;
} area_cell;


@implementation Posterizer

+ (int)opcode {
	return Posterize;
}

+ (NSString *)oprString {
	return NSLocalizedString(@"Posterize", Effects);
}

- (id)waitingMessage
{
	return [theWaitMsg messageDisplay:
		NSLocalizedString(@"Posterizing...", Posterizing)];
}


static int cnum;
static int cell_max;
static unsigned char *planes[MAXPLANE];	/* faster than **planes */
static t_Luv *luvmap[3];
/* work memory */
static area_t *area;
static brite_t *brite;
static area_cell *acell;

static int	ngidx[8];

static int alink(int idx)
{
	int	i, x;
	area_cell	*ptr;

	for (x = idx; x < cell_max && acell[x].count == 0; x = acell[x].alias)
		;
	for (i = idx; i != x; ) {
		i = (ptr = &acell[i])->alias;
		ptr->alias = x;
	}
	return x;
}

/* Local Method */
- (void)smooth:(int)brdiff
{
	int	tim, i, j, x, y, idx;
	int	cnt, val, sum, d;

	for (tim = 0; tim < 2; tim++)
	    for (y = 1; y < cinf->height - 1; y++) {
		    idx = y * cinf->width + 1;
		    for (x = 1; x < cinf->width - 1; x++, idx++) {
			cnt = 1;
			sum = val = brite[idx];
			if (val == AlphaMark)
				continue;
			for (i = 0; i < 8; i++) {
				if ((j = brite[idx + ngidx[i]]) == AlphaMark)
					continue;
				d = j - val;
				if (d > - brdiff && d < brdiff)
					sum += j, cnt++;
			}
			if (cnt > 1)
				brite[idx] = sum / cnt;
		    }
	    }
}

static int distance(int r1, int g1, int b1, int r2, int g2, int b2)
{
	int	r = r1 - r2;
	int	g = g1 - g2;
	int	b = b1 - b2;

	return ((r * r + g * g + b * b) / 3);
}

static int neighbor(int nx, int idx, int alp)
{
	int	i, v, n, ap;
	long	va, vb;
	area_cell *aptr;
	int	ctmp[3];
	t_Luv	ltmp[3];

	if (alp && (planes[cnum][nx] == AlphaTransp
			|| planes[cnum][idx] == AlphaTransp))
			return DiffHUGE;
	if (cnum > 1) {
		va = distance(luvmap[0][nx], luvmap[1][nx], luvmap[2][nx],
			luvmap[0][idx], luvmap[1][idx], luvmap[2][idx]);
	}else {
		v = luvmap[0][nx] - luvmap[0][idx];
		va = v * v;
	}

	if ((ap = area[nx]) >= cell_max) /* Alpha */
		return DiffHUGE;
	aptr = &acell[alink(ap)];
	if ((n = aptr->count) < 1)
		n = 1;
	for (i = 0; i < cnum; i++)
		ctmp[i] = (int)((double)(aptr->rgb[i]) / n + 0.5);
	transRGBtoLuv(ltmp, ctmp, cnum, 0);
	if (cnum > 1) {
	    vb = distance(ltmp[0], ltmp[1], ltmp[2],
		    luvmap[0][idx], luvmap[1][idx], luvmap[2][idx]);
	}else {
	    v = ltmp[0] - luvmap[0][idx];
	    vb = v * v;
	}

	return (vb > va) ? vb : va;
}

/* Local Method */
- (BOOL) segment: (int)brdiff : (int)diffc
{
	int	i, j, x, y, base, up, rp;
	int	acp, idx, alp, scandir;
	int	elm[MAXPLANE];
	area_cell *aptr, *bptr;
	long	*lp;
	long	diffcolor, difx, dify;
	unsigned char br[256];
	t_Luv luv[3];

	for (i = 0, j = 0; i < LuvMaxL*2/3; ) {
		br[i] = j;
		if (++i > j) j += brdiff;
	}
	br[AlphaMark] = AlphaMark;

	diffcolor = diffc * diffc;
	alp = (cinf->alpha) ? cnum : 0;
	acp = 0;
	idx = 0;
	for (y = 0; y < cinf->height; y++) {
	    for (x = 0; x < cinf->width; x++, idx++) {
		getPixel(&elm[0], &elm[1], &elm[2], &elm[3]);
		for (i = 0; i < cnum; i++)
			planes[i][idx] = elm[i];
		if (alp) {
			planes[alp][idx] = elm[ALPHA];
			if (elm[ALPHA] == AlphaTransp) {
				brite[idx] = AlphaMark;	/* 255 */
				continue;
			}
		}
		transRGBtoLuv(luv, elm, cnum, alp);
		for (i = 0; i < cnum; i++)
			luvmap[i][idx] = luv[i];
		brite[idx] = luv[0] * 2 / 3;
			/* Should be LuvMaxL*2/3 < 255 */
	    }
	}
	[self smooth: brdiff];

	idx = 0;
	for (y = 0; y < cinf->height; y++)
	    for (x = 0; x < cinf->width; x++, idx++)
		brite[idx] = br[brite[idx]];

	scandir = 1;
	for (y = 0; y < cinf->height; y++) {
	    base = y * cinf->width;
	    for (x = (scandir > 0) ? 0 : (cinf->width - 1);
			x >= 0 && x < cinf->width; x += scandir) {
		idx = base + x;
		if (alp && planes[alp][idx] == AlphaTransp) {
			area[idx] = cell_max;	/* mark as ALPHA */
			continue;
		}
		rp = ((j = x - scandir) < 0 || j >= cinf->width)
			? -1 : (idx - scandir);
		up = (y == 0) ? -1 : (idx - cinf->width);
		difx = (rp < 0 || brite[rp] != brite[idx])
			? DiffHUGE : neighbor(rp, idx, alp);
		dify = (up < 0 || brite[up] != brite[idx])
			? DiffHUGE : neighbor(up, idx, alp);
		if (difx > diffcolor && dify > diffcolor) {
			/* isolated pixel */
			aptr = &acell[area[idx] = acp];
			lp = aptr->rgb;
			for (i = 0; i < cnum; i++)
				lp[i] = planes[i][idx];
			aptr->count = 1;
			if (++acp >= cell_max) /* Too Many Colors */
				return NO;
		}else {
			if (difx <= diffcolor && dify <= diffcolor
			&& (i = alink(area[rp])) != (j = alink(area[up]))
				&& neighbor(rp, up, alp) <= diffcolor) {
				aptr = &acell[i];
				bptr = &acell[j];
				bptr->count += aptr->count;
				aptr->count = 0;
				aptr->alias = j;
				for (i = 0; i < cnum; i++)
					bptr->rgb[i] += aptr->rgb[i];
			}else
				j = alink(area[(difx < dify)? rp : up]);
			area[idx] = j;
			aptr = &acell[j];
			if (aptr->count < AvrMAX) {
				lp = aptr->rgb;
				for (i = 0; i < cnum; i++)
					lp[i] += planes[i][idx];
				aptr->count++;
			}
		}
	    } /* x */
	    scandir = (scandir > 0) ? -1 : 1;
	}

	for (j = 0; j < acp; j++) {
		long n;
		if ((n = (aptr = &acell[j])->count) > 1) {
			lp = aptr->rgb;
			for (i = 0; i < cnum; i++)
				lp[i] /= n;
		}
	}
	return YES;
}


- (void)setDivFactor:(float)dval andColorFactor:(float)cval
{
	divfactor = dval;
	clrfactor = cval;
}

- (id)init
{
	[super init];
	area = NULL;
	acell = NULL;
	brite = NULL;
	luvmap[0] = NULL;
	option = post_POST;
	return self;
}

- (void)setOption:(int)opt {
	option = opt;
}

static inline void freeReset(void *x)
{
	if (x) {
		free(x);
		x = NULL;
	}
}

- (void)dealloc
{
	freeReset((void *)area);
	freeReset((void *)acell);
	freeReset((void *)brite);
	freeReset((void *)luvmap[0]);
	[super dealloc];
}

/* Local Method */
- (BOOL)areaInit:(unsigned char **)nmap : (unsigned char **)localmap
{
	long	allpix;
	int	i, pnum;

	pnum = cnum = cinf->numcolors;
	if (cinf->alpha) pnum++;
	if (allocImage(nmap, cinf->width, cinf->height, 8, pnum))
		return NO;
	if (allocImage(localmap, cinf->width, cinf->height, 8, pnum)) {
		freeReset((void *)nmap[0]);
		return NO;
	}
	for (i = 0; i < MAXPLANE; i++)
		planes[i] = localmap[i];
	allpix = cinf->width * cinf->height;
	setupLuv();
	if (allocLuvPlanes(luvmap, allpix, pnum) != 0) {
		freeReset((void *)nmap[0]);
		freeReset((void *)localmap[0]);
		luvmap[0] = NULL;
		return NO;
	}
	cell_max = CellMAX(allpix);
	acell = (area_cell *)malloc(cell_max * sizeof(area_cell));
	area = (area_t *)malloc(allpix * sizeof(area_t));
	brite = (brite_t *)malloc(allpix * sizeof(brite_t));
	if (area == NULL || acell == NULL || brite == NULL)
		return NO;

	ngidx[0] = - cinf->width - 1;
	ngidx[1] = - cinf->width;
	ngidx[2] = - cinf->width + 1;
	ngidx[3] = -1;
	ngidx[4] = 1;
	ngidx[5] = cinf->width - 1;
	ngidx[6] = cinf->width;
	ngidx[7] = cinf->width + 1;

	return YES;
}

/* overwrite */
- (BOOL)checkInfo:(NSString *)filename
{
	if (![[self class] check:(ck_EPS|ck_CMYK|ck_MONO)
			info:cinf filename:filename])
		return YES;
	return NO;
}

- (BOOL)makeNewPlane:(unsigned char **)newmap with:(commonInfo *)newinf
{
	int	i, x, y, idx;
	int	diffc, brdiff;
	area_cell *aptr;
	long	*lp;
	float	w;
	unsigned char *localplanes[MAXPLANE];

	if (![self areaInit:newmap : localplanes])
		return NO;

	[theWaitMsg setProgress:0.0];	/* Barber Pole */

	w = 0.25 + (divfactor * 0.75);
	for (w *= w;  ; w += 0.05) {	/* w = [1/16 .. 1] */
		brdiff = w * 64;	/* brdiff = [4 .. 64] */
		diffc = brdiff * (0.1 + (clrfactor * 0.9));
		if (diffc < 4) diffc = 4;
		if (msgtext) {
			NSString *msg = [NSString stringWithFormat:
				@"%@: %d:%d",
				NSLocalizedString(@"Posterizing", Posterizing),
				brdiff, diffc];
			[msgtext setStringValue:msg];
		}
		resetPixel((refmap)map, 0);
		if ([self segment: brdiff : diffc])
			break;
	}
	if (newinf->alpha && !hadAlpha())
		newinf->alpha = NO;
	if (msgtext)
		[msgtext setStringValue:
			NSLocalizedString(@"Painting...", Painting)];

	idx = 0;
	if (option == post_SMOOTH) {
	    for (y = 0; y < cinf->height; y++) {
		int aidx, sum[MAXPLANE], j, z;
		BOOL flag = (y > 0 && y < cinf->height - 1);
		for (x = 0; x < cinf->width; x++, idx++) {
			if (!flag || x == 0 || x >= cinf->width - 1)
				goto NORMAL;
			aidx = alink(area[idx]);
			for (j = 0; j < 8; j++) {
				if (alink(area[idx + ngidx[j]]) != aidx)
					goto NORMAL;
			}
			for (i = 0; i < cnum; i++) {
				sum[i] = 0;
				for (j = 0; j < 8; j++) {
					z = idx + ngidx[j];
					sum[i] += localplanes[i][z];
				}
				newmap[i][idx] = (sum[i] + 4) >> 3;
			}
			continue;
NORMAL:
			for (i = 0; i < cnum; i++)
				newmap[i][idx] = localplanes[i][idx];
		}
	    }
	}else {
	    for (y = 0; y < cinf->height; y++) {
		for (x = 0; x < cinf->width; x++, idx++) {
			aptr = &acell[alink(area[idx])];
			if (aptr->count > 1) {
				lp = aptr->rgb;
				if (option == post_POST)
				    for (i = 0; i < cnum; i++)
					newmap[i][idx] = lp[i];
				else /* MIX */
				    for (i = 0; i < cnum; i++)
					newmap[i][idx] = (lp[i] + localplanes[i][idx]) >> 1;
			}else
			    for (i = 0; i < cnum; i++)
				newmap[i][idx] = localplanes[i][idx];
		}
	    }

	}
	[theWaitMsg resetProgress];
	freeReset((void *)localplanes[0]);
	return YES;
}

@end
