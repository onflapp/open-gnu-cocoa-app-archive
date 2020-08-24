#include "colorEnhance.h"

#if !defined(RED)
# define  RED		0
# define  GREEN		1
# define  BLUE		2
#endif

static const float cnv[3][3] = {
	{ 1, 0, -1 },
	{ 0, 1, -1 },
	{ 1, 1,  1 } };
static const float rcnv[3][3] = {
	{  2,  -1,  1 },
	{ -1,   2,  1 },
	{ -1,  -1,  1 } };	/*  * 1/3 */
static float satcnv[3][3];

static float ratio[N_Colors];

/* Saturation Enhancement
   (1) RGB --convert--> r=(2R,-G,-B)/3, g=(-R,2G,-B)/3, k=(R,G,B)/3
   (2) r *= sat,  g *= sat
   (3) rgk --convert--> RGB
 */

void sat_enhance_init(float satval)
{
	float	v[3][3], w;
	int	i, j, k;

	for (j = 0; j < 3; j++)
		v[j][2] = rcnv[j][2];
	for (i = 0; i < 2; i++)
	    for (j = 0; j < 3; j++)
		v[j][i] = rcnv[j][i] * satval;
	for (i = 0; i < 3; i++)
	    for (j = 0; j < 3; j++) {
		w = 0.0;
		for (k = 0; k < 3; k++)
		    w += v[i][k] * cnv[k][j];
		satcnv[i][j] = w / 3.0;
	    }
}

void set_ratio(float hval[])
{
	int i;

	for (i = 0; i < N_Colors; i++)
		ratio[i] = (hval[i] < -rLimit || hval[i] > rLimit)
			? hval[i] : 0.0;
}

void sat_enhance(int elm[])
{
	float	w[3];
	int	i, j;

	for (i = 0; i < 3; i++) {
		w[i] = 0;
		for (j = 0; j < 3; j++)
			w[i] += satcnv[i][j] * elm[j];
	}
	for (i = 0; i < 3; i++)
		elm[i] = (int)(w[i] + 0.5);
}

void tone_enhance(int elm[])
{
	int mdfy[3];
	int i, x, dif, flag;
	double r;
	const unsigned char order[8][3] = {
		{ RED, GREEN, BLUE }, /* R>G>B; 000; R>G, R>B, G>B */
		{ RED, BLUE, GREEN }, /* R>B>G; 001; R>G, R>B, G<B */
		{ 0,    0,    0    }, /* R>G>B; 010; R>G, R<B, G>B NEVER!! */
		{ BLUE, RED, GREEN }, /* B>R>G; 011; R>G, R<B, G<B */
		{ GREEN, RED, BLUE }, /* G>R>B; 100; R<G, R>B, G>B */
		{ 0,    0,    0    }, /* R>G>B; 101; R<G, R>B, G<B NEVER!! */
		{ GREEN, BLUE, RED }, /* G>B>R; 110; R<G, R<B, G>B */
		{ BLUE, GREEN, RED }, /* B>G>R; 111; R<G, R<B, G<B */
	};
	const unsigned char *co;

	x = (elm[0] >= elm[1]) ? 0 : 4;
	if (elm[0] < elm[2]) x |= 2;
	if (elm[1] < elm[2]) x |= 1;
	co = order[x];

	flag = 0;
	if ((r = ratio[co[0]]) != 0.0) { /* RGB */
		/* r >= -1.0, shoud be */
		if (r > 0) {
			dif = r * (elm[co[0]] - elm[co[1]]);
			mdfy[co[0]] = elm[co[0]] + dif;
			if ((mdfy[co[1]] = elm[co[1]] - dif) < elm[co[2]])
				mdfy[co[1]] = elm[co[2]];
			mdfy[co[2]] = elm[co[2]];
		}else {
			dif = r * (elm[co[0]] - elm[co[1]]) / 3.0;
			mdfy[co[0]] = elm[co[0]] + dif * 2;
			mdfy[co[1]] = elm[co[1]] - dif;
			mdfy[co[2]] = elm[co[2]] - dif;
		}
		flag = 1;
	}else {
		for (i = 0; i < 3; i++)
			mdfy[i] = elm[i];
	}
	if ((r = ratio[co[2]+3]) != 0.0) { /* CMY */
		if (r > 0) {
			dif = r * (elm[co[1]] - elm[co[2]]);
			if ((mdfy[co[1]] += dif) > mdfy[co[0]])
				mdfy[co[1]] = mdfy[co[0]];
			if ((mdfy[co[2]] -= dif) < 0)
				mdfy[co[2]] = 0;
		}else {
			dif = r * (elm[co[1]] - elm[co[2]]) / 3.0;
			mdfy[co[0]] += dif;
			mdfy[co[1]] += dif;
			mdfy[co[2]] -= dif * 2;
		}
		flag = 1;
	}
	if (flag)
		for (i = 0; i < 3; i++) {
			int v = mdfy[i];
			elm[i] = (v > 255) ? 255 : ((v < 0) ? 0 : v);
		}
}
