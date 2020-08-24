#include  <stdio.h>
#include  <stdlib.h>
//#include  <libc.h>
#include  <objc/objc.h>
#include  "ppm.h"
#include  "imfunc.h"
#include  "strfunc.h"

/* PPM Format
    Px			: Header
    Width Height
    MAX			: pbm does not have this field
    Bitmap		: in ASCII / Binary
*/

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
    Width Height MAX
    Planes		: Planes = 1,2,3 or 4.  (planes 2 and 4 have ALPHA)
    [Bitmap]		: Binary
*/

static int ppmkind = 0, ppmmax = 0;
static int pxtrans = 0;
static char ppmcomm[MAX_COMMENT];
static int GIFWrongIndexColor = 255;	/* White */

void setGIFWrongIndexBlack(int black)
{
	GIFWrongIndexColor = black ? 0 : 255;
}

static void ppm_skip(FILE *fp)
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

static int ppm_head(FILE *fp)
{
	int c, i, kind = UnknownHD;

	if ((c = getc(fp)) != 'P')
		return UnknownHD;
	c = getc(fp);
	if (c >= '0' && c <= '9')
		kind = c - '0';
	else if (c == 'X')
		kind = PXOF;
	else if (c == 'A')
		kind = PAOF;
	ppmcomm[0] = 0;
	while ((c = getc(fp)) <= ' ') ;
	if (c == '#') {
		for (i = 0; (c = getc(fp)) != '\n'; i++)
			if (i < MAX_COMMENT-1)
				ppmcomm[i] = c;
			else {
				while (getc(fp) != '\n') ;
				break;
			}
		ppmcomm[i] = 0;
		ungetc('\n', fp);
		ppm_skip(fp);
	}else
		ungetc(c, fp);
	return kind;
}

static int ppm_getint(FILE *fp)
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


commonInfo *loadPpmHeader(FILE *fp, int *errcode)
{
	int w, err;
	commonInfo *cinf;

	*errcode = err = 0;
	ppmkind = ppm_head(fp);
	if (ppmkind == UnknownHD) {
		*errcode = Err_FORMAT;
		return NULL;
	}
	if ((w = ppm_getint(fp)) >= MAXWidth) {
		*errcode = Err_IMPLEMENT;
		return NULL;
	}
	if ((cinf = (commonInfo *)malloc(sizeof(commonInfo))) == NULL) {
		*errcode = Err_MEMORY;
		return NULL;
	}
	cinf->width = w;
	cinf->alpha = NO;
	cinf->type = Type_ppm;
	cinf->isplanar = YES;
	cinf->pixbits = 0;	/* don't care */
	cinf->palsteps = 0;
	cinf->palette = NULL;
	cinf->memo[0] = 0;
	ppm_skip(fp);
	cinf->height = ppm_getint(fp);
	if (ppmkind == PBMa || ppmkind == PBMb) {
		ppmmax = 2;
		cinf->numcolors = 1;
		cinf->cspace = CS_Black;
		cinf->bits = 1;
		cinf->xbytes = byte_length(1, cinf->width);
		(void)getc(fp);	/* feed last CR */
		return cinf;
	}
	ppm_skip(fp);
	ppmmax = ppm_getint(fp) + 1;
	if (ppmkind == PAOF) {
		int pn;
		ppm_skip(fp);
		pn = ppm_getint(fp);
		if (pn < 1 || pn > 4) { /* PAOF must have alpha */
			*errcode = Err_FORMAT;
			return NULL;
		}
		if (pn >= 3) {
			cinf->numcolors = 3;
			cinf->cspace = CS_RGB;
		}else {
			cinf->numcolors = 1;
			cinf->cspace = CS_White;
		}
		(void)getc(fp);	/* feed last CR */
		cinf->alpha = (pn == 2 || pn == 4);
	}else if (ppmkind == PXOF) {
		int cnt;
		pxtrans = -1;
		ppm_skip(fp);
		cnt = ppm_getint(fp);
		if (cnt-- > 0) {
			ppm_skip(fp);
			pxtrans = ppm_getint(fp);
		}
		while (cnt-- > 0) { /* skip unknown parameters */
			ppm_skip(fp);
			(void) ppm_getint(fp);
		}
		(void)getc(fp);	/* feed last CR */
		if (pxtrans >= 256 && pxtrans < 512) {
			cinf->alpha = YES;
			pxtrans -= 256;
		}else
			pxtrans = -1;
		cinf->numcolors = 3;
		cinf->cspace = CS_RGB;
		cinf->bits = 8;
		cinf->xbytes = cinf->width;
		return cinf;
	}else {
		(void)getc(fp);	/* feed last CR */
		if (ppmkind == PPMa || ppmkind == PPMb) {
			cinf->numcolors = 3;
			cinf->cspace = CS_RGB;
		}else {
			cinf->numcolors = 1;
			cinf->cspace = CS_White;
		}
	}

	cinf->bits = (ppmmax > 16) ? 8
			: ((ppmmax > 4) ? 4 : ((ppmmax > 2) ? 2 : 1));
	cinf->xbytes = byte_length(cinf->bits, cinf->width);
	return cinf;
}


static int isGrayPPM(unsigned char **planes, int length)
{
	int i;
	unsigned char *rr, *gg, *bb;

	rr = planes[0];
	gg = planes[1];
	bb = planes[2];
	for (i = 0; i < length; i++) {
		if (rr[i] != gg[i] || gg[i] != bb[i]) return 0;
	}
	return 1;
}

static int bitsOfPPM(unsigned char **planes, commonInfo *cinf)
{
	unsigned char *p, buf[256];
	int i, pn, pnmx, w, num;

	w = cinf->width * cinf->height;
	for (i = 0; i < 256; i++) buf[i] = 0;
	num = 0;
	pnmx = cinf->numcolors;
	if (cinf->alpha) pnmx++;
	for (pn = 0; pn < pnmx; pn++) {
		p = planes[pn];
		for (i = 0; i < w; i++)
			if (buf[p[i]] == 0) {
				buf[p[i]] = 1;
				if (++num > 16) return 8;
			}
	}
	return optimalBits(buf, num);
}

static int getPXOF(FILE *fp, commonInfo *cinf,
			unsigned char **planes, int *aflag)
{
	int	i, x, y;
	unsigned char *p, *rr, *gg, *bb;

	cinf->palette = (paltype *)malloc(sizeof(paltype) * 256);
	/* V3.02: Some illegal GIF has pixel value > ppmmax */
	if (cinf->palette == NULL)
		return Err_MEMORY;
	cinf->palsteps = ppmmax;
	for (i = 0; i < ppmmax; i++) {
		p = cinf->palette[i];
		for (x = 0; x < 3; x++)
			p[x] = getc(fp);
	}
	for ( ; i < 256; i++) {	/* V3.02 */
		p = cinf->palette[i];
		for (x = 0; x < 3; x++)
			p[x] = GIFWrongIndexColor;
	}
	rr = planes[0];
	gg = planes[1];
	bb = planes[2];
	if (! cinf->alpha) {
		for (y = 0; y < cinf->height; y++) {
			for (x = 0; x < cinf->width; x++) {
				p = cinf->palette[getc(fp)];
				*rr++ = p[RED];
				*gg++ = p[GREEN];
				*bb++ = p[BLUE];
			}
		}
	}else {
		unsigned char *aa = planes[3];
		int cc;
		for (y = 0; y < cinf->height; y++) {
			for (x = 0; x < cinf->width; x++) {
				if ((cc = getc(fp)) == pxtrans) {
					*rr++ = *gg++ = *bb++ = 255;
					*aa++ = AlphaTransp;
					*aflag = YES;
				}else {
					p = cinf->palette[cc];
					*rr++ = p[RED];
					*gg++ = p[GREEN];
					*bb++ = p[BLUE];
					*aa++ = AlphaOpaque;
				}
			}
		}
		if (pxtrans >= ppmmax) {
			/* in this case, palette[ppmmax] is allocated */
			cinf->palsteps = pxtrans = ppmmax;
			p = cinf->palette[pxtrans];
			for (i = 0; i < 3; i++)
				p[i] = 255;
			if (*aflag)
				ppmmax++;
		}else if (pxtrans != ppmmax - 1) {
			unsigned char *q;
			p = cinf->palette[ppmmax-1];
			q = cinf->palette[pxtrans];
			for (i = 0; i < 3; i++)
				q[i] = p[i];
			cinf->palsteps = pxtrans = ppmmax - 1;
			p = cinf->palette[pxtrans];
			for (i = 0; i < 3; i++)
				p[i] = 255;
		}
	}
	return 0;
}

static int PPMplanes(FILE *fp,
	commonInfo *cinf, int pn, unsigned char **planes, int *hasalpha)
{
	int	i, r, x, y;
	unsigned char	work[MAXPLANE][MAXWidth];
	unsigned char	*pp;
	int	width = cinf->width;
	int	rdmax = ppmmax - 1;
	int	aflag = NO;

	for (y = 0; y < cinf->height; y++) {
		if (feof(fp))
			return Err_SHORT;
		if (isPPMascii(ppmkind)) {
			for (x = 0; x < width; x++)
			    for (i = 0; i < pn; i++) {
				ppm_skip(fp);
				work[i][x] = ((r = ppm_getint(fp)) >= rdmax)
					? 255 : ((r << 8) / ppmmax);
			    }
		}else if (ppmkind == PBMb) {
			int mask, cc;
			for (x = 0; x < width; ) {
				cc = getc(fp);
				for (mask = 0x80; mask; mask >>= 1) {
				    work[0][x] = (cc & mask) ? 0xff : 0;
				    if (++x >= width) break;
				}
			}
		}else {
			for (x = 0; x < width; x++) {
			    for (i = 0; i < pn; i++)
				work[i][x] = ((r = getc(fp)) >= rdmax)
					? 255 : ((r << 8) / ppmmax);
			}
		}
		for (i = 0; i < pn; i++) {
			pp = planes[i] + y * cinf->xbytes;
			packImage(pp, work[i], width, cinf->bits);
		}
		if (cinf->alpha && aflag == NO) {
			pp = work[pn - 1];
			for (i = 0; i < width; i++) {
				if (*pp++ != AlphaOpaque) {
					aflag = YES;
					break;
				}
			}
		}
	}
	*hasalpha = aflag;
	return 0;
}

int ppmGetImage(FILE *fp,
	commonInfo *cinf, unsigned char **planes, const char *fkind)
{
	int	i, y, pn, bits, err;
	int	width, xbyte;
	const char *kp;
	int	aflag = NO;

	width = cinf->width;
	pn = cinf->numcolors;
	if (cinf->alpha) pn++;
	err = allocImage(planes, width, cinf->height, cinf->bits, pn);
	if (err) return err;
	if (ppmkind == PXOF)
		err = getPXOF(fp, cinf, planes, &aflag);
	else
		err = PPMplanes(fp, cinf, pn, planes, &aflag);
	if (err) return err;

	/* ALPHA image ? */
	if (cinf->alpha && aflag == NO) {
		cinf->alpha = NO;
		--pn;
	}
	/* Is this image Gray ? */
	if (pn == 3 && isGrayPPM(planes, cinf->xbytes * cinf->height)) {
		size_t newsize = planes[1] - planes[0];
		planes[0] = (unsigned char *)realloc(planes[0], newsize);
		planes[1] = planes[2] = NULL;
		pn = cinf->numcolors = 1;
		cinf->cspace = CS_White;
	}
	/* How many bits are needed ? */
	if (cinf->bits == 8 && (bits = bitsOfPPM(planes, cinf)) < 8) {
		unsigned char *src, *dst, *newmap[MAXPLANE];
		err = allocImage(newmap, width, cinf->height, bits, pn);
		if (err) return 0; /* Error */
		xbyte = byte_length(bits, width);
		for (i = 0; i < pn; i++) {
			src = planes[i];
			dst = newmap[i];
			for (y = 0; y < cinf->height; y++) {
				packImage(dst, src, width, bits);
				src += width;
				dst += xbyte;
			}
		}
		free((void *)planes[0]);
		for (i = 0; i < pn; i++)
			planes[i] = newmap[i];
		cinf->xbytes = xbyte;
		cinf->bits = bits;
	}

	sprintf(cinf->memo, "%d x %d  ", cinf->width, cinf->height);
	if (fkind) kp = fkind;
	else if (ppmkind == PXOF) kp = "PXOF";
	else if (ppmkind == PAOF) kp = "PAOF";
	else kp = PPMname(ppmkind);
	strcat(cinf->memo, kp);
	if ((bits = cinf->bits) == 1)
		strcat(cinf->memo, " 1bit");
	else {
		i = strlen(cinf->memo);
		sprintf(cinf->memo + i, " %dbits%s", bits,
				(pn > 2 ? "" : " gray"));
	}
	if (pn == 2 || pn == 4)
		strcat(cinf->memo, " Alpha");

	if (ppmcomm[0]) {
		const char *p = ppmcomm;
		while (*p == ' ') p++;
		if (*p != 0) {
			strcat(cinf->memo, "  ");
			comm_cat(cinf->memo, p);
		}
	}

	return 0;
}

#ifdef _TEST
main()
{
	printf("kind=P%d\n", ppm_head(stdin));
	while (!feof(stdin)) {
		ppm_skip(stdin);
		printf("%d\n", ppm_getint(stdin));
	}
}
#endif
