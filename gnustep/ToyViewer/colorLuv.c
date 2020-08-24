//#include  <libc.h>
#include  <math.h>
#include  <objc/objc.h>
#include  "colorLuv.h"
#include  "common.h"
#include  "getpixel.h"

/*
	L:  min:   0.000   max:  99.888
	u:  min:-138.473   max: 218.054
	v:  min:-139.288   max: 121.482
*/

static float Ltab[256];
static int inited = 0;

void setupLuv(void)
{
	int	i;

	if (inited)
		return;
	for (i = 0; i < 3; i++)
		Ltab[i] = i * 903.29 / 255.0;
	for ( ; i < 256; i++)
		Ltab[i] = pow((double)i / 2.55, 1.0/3.0) * 25.0 - 16.0;
	inited = 1;
}

void transRGBtoLuv(t_Luv luv[], const int rgb[], int cnum, int alp)
{
	static const float t[3][3] = {
		{ 0.61, 0.17, 0.20 },
		{ 0.30, 0.59, 0.11 },
		{ 0.00, 0.07, 1.12 } };
	int	i, j;
	double	xyz[3], w, el;

	if (alp && rgb[3] == AlphaTransp) {
		luv[0] = LuvTrans;
		return;
	}
	if (cnum == 1) {
		luv[0] = real2LuvL( Ltab[rgb[0]] );
		/* if rgb[0] = rgb[1] = rgb[2], then xyz[1] = rgb[.] */
	}else {
		for (i = 0; i < 3; i++) {
			w = 0.0;
			for (j = 0; j < 3; j++)
				w += rgb[j] * t[i][j];
			xyz[i] = w;
		}
#define  U0	(4 * 255.0 / (16*255.0 + 900.3))
#define  V0	(9 * 255.0 / (16*255.0 + 900.3))
		w = xyz[0] + 15 * xyz[1] + 3 * xyz[2];
		el = Ltab[(int)xyz[1]];
		luv[0] = real2LuvL(el);
		luv[1] = real2Luv( 13.0 * el * (4.0 * xyz[0] / w - U0) );
		luv[2] = real2Luv( 13.0 * el * (9.0 * xyz[1] / w - V0) );
	}
}

int getLuv(t_Luv luv[], int cnum, int alp)
{
	/* Return:
		-1: End of Image (same as getPixelA())
		0: normal
		1: end of line
	*/
	int	elm[MAXPLANE];
	int	rs;

	if ((rs = getPixelA(elm)) < 0)
		return -1;
	transRGBtoLuv(luv, elm, cnum, alp);
	return rs;
}

int allocLuvPlanes(t_Luv **planes, int size, int pnum)
{
	int i;
	unsigned int sz;
	t_Luv	*p;

	sz = (size + 3) & ~3;
	if ((p = (t_Luv *)malloc(sz * sizeof(t_Luv) * pnum)) == NULL)
		return Err_MEMORY;
	for (i = 0; i < pnum; i++) {
		planes[i] = p;
		p += size;
	}
	return 0;
}

