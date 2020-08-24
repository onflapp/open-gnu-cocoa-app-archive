/*
	ppmread.c
	Ver.1.0		1995-04-28  T.Ogihara
	for pxo2bmp	2000-03-25  T.Ogihara
	for newicon	2002-01-17  T.Ogihara
 */

#include  <stdio.h>
#include  <stdlib.h>
#include  <string.h>
#include  "pnmread.h"

#define  UnknownHD	0
#define  MAX_COMMENT	256

static char ppmcomm[MAX_COMMENT];
static int verbose = 0;

void setVerbose(int flag) {
	verbose = flag;
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
	if (c >= '4' && c <= '6') /* Binary PPM only */
		kind = c - '0';
	ppmcomm[0] = 0;
	while ((c = getc(fp) & 0xff) <= ' ') ;
	if (c == '#') {
		for (i = 0; (c = getc(fp)) != '\n'; i++)
			if (i < MAX_COMMENT-1) ppmcomm[i] = c;
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


commonInfo *pnmread(FILE *fin)
{
	int pnmkind = 0, pnmmax = 0;
	int width, height, pn = 0;
	long	amount;
	const char *kp = NULL;
	commonInfo *info;
	unsigned char *pp;

	pnmkind = ppm_head(fin);
	width = ppm_getint(fin);
	ppm_skip(fin);
	height = ppm_getint(fin);
	if (pnmkind == UnknownHD || width <= 0 || height <= 0) {
		fprintf(stderr, "ERROR: Unknown format\n");
		return NULL;
	}
	if (pnmkind <= 3) {
		fprintf(stderr, "ERROR: This program can't read PPM in ASCII\n");
		return NULL;
	}
	info = (commonInfo *)malloc(sizeof(commonInfo));
	info->width = width;
	info->height = height;
	info->pixels[0] = NULL;
	info->bits = 8;
	info->memo = NULL;

	amount = width * height;
	if (pnmkind == 4) {	/* PBM */
		pnmmax = 0;
		kp = "PBM";
		pn = 1;
		info->bits = 1;
	}else {
		ppm_skip(fin);
		pnmmax = ppm_getint(fin);
		if (pnmkind == 5) {	/* PGM */
			kp = "PGM";
			pn = 1;
		}else if (pnmkind == 6) {	/* PPM */
			kp = "PPM";
			pn = 3;
			amount *= 3;
		}
	}
	info->numcolors = pn;
	(void)getc(fin);	/* feed last CR */

	if (verbose)
		fprintf(stderr, "%s, %dx%d, max:%d, plane:%d\n",
			kp, width, height, pnmmax+1, pn);
	info->pixels[0] = pp = (unsigned char *)malloc(amount);
	if (pn > 1) { /* PPM */
		int i, w;
		long a = width * height;
		for (i = 1; i < pn; i++)
			info->pixels[i] = pp + a * i;
		for (w = 0; w < a; w++) {
			for (i = 0; i < pn; i++)
				info->pixels[i][w] = (unsigned char)getc(fin);
		}
	}else if (info->bits == 8) { /* PGM */
		while (amount-- > 0)
			*pp++ = (unsigned char)getc(fin);
	}else {
		int x, y, uc, mask, bit;
		int xbyte = (width + 7) >> 3;
		for (y = 0; y < height; y++) {
		    for (x = 0; x < xbyte - 1; x++) {
			uc = getc(fin);
			for (mask = 0x80; mask; mask >>= 1)
			    *pp++ = (uc & mask) ? 255 : 0;
		    }
		    if ((bit = width & 7) != 0) {
			uc = getc(fin);
			for (mask = 0x80; bit; mask >>= 1, bit--)
			    *pp++ = (uc & mask) ? 255 : 0;
		    }
		}
	}
	if (pnmmax != 255 && info->bits != 1) {
		long a = width * height * pn;
		pp = info->pixels[0];
		while (a > 0) {
			*pp = *pp * 255 / pnmmax;
			pp++, a--;
		}
	}
	if (ppmcomm[0]) {
		info->memo = (char *)malloc(strlen(ppmcomm) + 1);
		strcpy(info->memo, ppmcomm);
	}
	return info;
}

void freePnmInfo(commonInfo *info)
{
	if (info->pixels[0])
		free((void *)info->pixels[0]);
	if (info->memo)
		free((void *)info->memo);
	free((void *)info);
}
