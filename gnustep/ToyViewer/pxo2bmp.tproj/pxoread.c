/*
	pxoread.c
		pxo2bmp		by Takeshi Ogihara (Mar. 2000)
 */

#include  <stdio.h>
//#include  <libc.h> //GNUstep only
#include  "bmp.h"

#define  PXOF		0xff
#define  PAOF		0xfe
#define  UnknownHD	0
/* PX original Format
    PX			: Header
    Width Height Colors	: Colors := Number of colors in palette - 1
    Count		: if Trans is there Count=1, otherwise Count=0.
    Trans		: Transparent + 256
    [Palette]		: Binary
    [Bitmap]		: Binary
*/
/* PA original Format
    PA			: Header
    Width Height
    MAX Planes		: Planes = 2 or 4.  This format should have ALPHA.
    Bitmap		: Binary
*/

static char pxocomm[MAX_COMMENT];

static void pxo_skip(FILE *fp)
{
	int c;

	while ((c = getc(fp)) != EOF) {
		if (c == '\n') {
			c = getc(fp);
			while (c == '#') {
				while ((c = getc(fp)) != '\n')
					if (c == EOF)
						return;
				c = getc(fp);
			}
		}
		if (c > ' ') {
			ungetc(c, fp);
			return;
		}
	}
}

static int pxo_head(FILE *fp)
{
	int c, i, kind = UnknownHD;

	if ((c = getc(fp)) != 'P')
		return UnknownHD;
	c = getc(fp);
	if (c >= '4' && c <= '6') /* Binary PPM only */
		kind = c - '0';
	else if (c == 'X')
		kind = PXOF;
	else if (c == 'A')
	 	kind = PAOF;
	pxocomm[0] = 0;
	while ((c = getc(fp) & 0xff) <= ' ') ;
	if (c == '#') {
		for (i = 0; (c = getc(fp)) != '\n'; i++)
			if (i < MAX_COMMENT-1) pxocomm[i] = c;
		pxocomm[i] = 0;
		ungetc('\n', fp);
		pxo_skip(fp);
	}else
		ungetc(c, fp);
	return kind;
}

static int pxo_getint(FILE *fp)
{
	int c;
	int v = 0;

	c = getc(fp);
	while (c < '0' || c > '9') {
		if (c == EOF) return -1;
		c = getc(fp);
	}
	while (c >= '0' && c <= '9') {
		v = (v * 10) + c - '0';
		c = getc(fp);
	}
	if (c != EOF && c < ' ')
		ungetc(c, fp);
	return v;
}


static paltype *read_palette(FILE *fp, int cols, int transp)
{
	int	i, j;
	paltype *palette;
	unsigned char *p;

	palette = (paltype *)malloc(sizeof(paltype) * 256);
	for (i = 0; i < cols; i++) {
		p = (unsigned char *)&palette[i];
		for (j = 0; j < 3; j++)
			p[j] = (unsigned char)getc(fp);
	}
	while (cols <= transp && cols < 255) {
		p = (unsigned char *)&palette[cols++];
		for (j = 0; j < 3; j++)
			p[j] = 255;
	}
	return palette;
}

static paltype *gray_palette(int colors)
{
	int	i, j, s;
	float	wid;
	paltype *palette;
	unsigned char *p;

	wid = 255.0 / colors;
	palette = (paltype *)malloc(sizeof(paltype) * 256);
	for (i = 0; i < colors; i++) {
		s = wid * i;
		p = palette[i];
		for (j = 0; j < 3; j++)
			p[j] = s;
	}
	return palette;
}

commonInfo *pxoread(FILE *fin)
{
	int i, w;
	int pxokind = 0, pxomax = 0;
	int width, height, pn = 0, transp = -1;
	long	amount;
	char *kp = NULL;
	commonInfo *info;
	unsigned char *pp;

	info = (commonInfo *)malloc(sizeof(commonInfo));
	pxokind = pxo_head(fin);
	width = pxo_getint(fin);
	pxo_skip(fin);
	height = pxo_getint(fin);
	if (pxokind == UnknownHD || width <= 0 || height <= 0) {
		fprintf(stderr, "ERROR: Unknown format\n");
		exit(1);
	}
	info->width = width;
	info->height = height;
	info->palette = NULL;
	info->pixels[0] = NULL;
	info->bits = 8;

	if (pxokind == PXOF) {
		int cnt;
		pxo_skip(fin);
		pxomax = pxo_getint(fin) + 1;
		kp = "PXOF";
		pxo_skip(fin);
		cnt = pxo_getint(fin);
		if (cnt-- > 0) {
			pxo_skip(fin);
			transp = pxo_getint(fin);
			transp = (transp > 256) ? (transp - 256) : -1;
			while (cnt-- > 0) {	/* skip unknown parameters */
				pxo_skip(fin);
				(void) pxo_getint(fin);
			}
		}
		pn = 0;
		(void)getc(fin);	/* feed last CR */
		info->palette = read_palette(fin, pxomax, transp);
		info->palsteps = pxomax;
		info->numcolors = 0;
		amount = width * height;
	}else if (pxokind == PAOF) {
		pxo_skip(fin);
		pxomax = pxo_getint(fin) + 1;
		pxo_skip(fin);
		pn = (pxo_getint(fin) > 2) ? 4 : 2;	/* planes */
		/* Alpha values are ignored */
		amount = width * height * pn;
		kp = "PAOF";
		info->palsteps = pxomax;
		info->numcolors = pn - 1;
		(void)getc(fin);	/* feed last CR */
	}else {
		if (pxokind == 4) {	/* PBM */
			pxomax = 1;
			kp = "PBM";
			pn = 1;
			amount = ((width + 7) >> 3) * height;
			info->bits = 1;
		}else {
			pxo_skip(fin);
			pxomax = pxo_getint(fin) + 1;
			amount = width * height;
			if (pxokind == 5) {	/* PGM */
				kp = "PGM";
				pn = 1;
				info->palsteps = pxomax;
				info->palette = gray_palette(pxomax);
			}else if (pxokind == 6) {	/* PPM */
				kp = "PPM";
				pn = 3;
				amount *= 3;
			}
		}
		info->palsteps = pxomax;
		info->numcolors = pn;
		(void)getc(fin);	/* feed last CR */
	}
	if (verbose)
		fprintf(stderr, "%s, %dx%d, max:%d, plane:%d\n",
			kp, width, height, pxomax, pn);
	info->pixels[0] = pp = (unsigned char *)malloc(amount);
	if (pn > 1) {
		long a = width * height;
		for (i = 1; i < pn; i++)
			info->pixels[i] = pp + a * i;
		for (w = 0; w < a; w++) {
			for (i = 0; i < pn; i++)
				info->pixels[i][w] = (unsigned char)getc(fin);
		}
	}else {
		while (amount-- > 0)
			*pp++ = (unsigned char)getc(fin);
	}
	return info;
}

void freePxoInfo(commonInfo *info)
{
	if (info->pixels[0])
		free((void *)info->pixels[0]);
	if (info->palette)
		free((void *)info->palette);
	free((void *)info);
}
