/*
	paoread.c
		pao2png by Takeshi Ogihara
 */

#include  <stdio.h>
#include  <stdlib.h>
#include  "png.h"
#include  "pao2png.h"

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


static char paocomm[MAX_COMMENT];

static void pao_skip(FILE *fp)
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

static int pao_head(FILE *fp)
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
	paocomm[0] = 0;
	while ((c = getc(fp) & 0xff) <= ' ') ;
	if (c == '#') {
		for (i = 0; (c = getc(fp)) != '\n'; i++)
			if (i < MAX_COMMENT-1) paocomm[i] = c;
		paocomm[i] = 0;
		ungetc('\n', fp);
		pao_skip(fp);
	}else
		ungetc(c, fp);
	return kind;
}

static int pao_getint(FILE *fp)
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


void paoread(FILE *fin, FILE *fout)
{
	int paokind = 0, paomax = 0;
	int width, height, pn = 0, transp = -1;
	char *kp = NULL;

	paokind = pao_head(fin);
	width = pao_getint(fin);
	pao_skip(fin);
	height = pao_getint(fin);
	if (paokind == UnknownHD || width <= 0 || height <= 0) {
		fprintf(stderr, "ERROR: Unknown format\n");
		exit(1);
	}
	if (paokind == PAOF) {
		pao_skip(fin);
		paomax = pao_getint(fin) + 1;
		kp = "PAOF";
		pao_skip(fin);
		pn = pao_getint(fin);
		if (pn < 1 || pn > 4) { /* PAOF must have alpha */
			fprintf(stderr, "ERROR: illegal depth\n");
			exit(1);
		}
		(void)getc(fin);	/* feed last CR */
	}else if (paokind == PXOF) {
		int cnt;
		pao_skip(fin);
		paomax = pao_getint(fin) + 1;
		kp = "PXOF";
		pao_skip(fin);
		cnt = pao_getint(fin);
		if (cnt-- > 0) {
			pao_skip(fin);
			transp = pao_getint(fin);
			transp = (transp > 256) ? (transp - 256) : -1;
			while (cnt-- > 0) {	/* skip unknown parameters */
				pao_skip(fin);
				(void) pao_getint(fin);
			}
		}
		pn = 0;
		(void)getc(fin);	/* feed last CR */
		read_palette(fin, paomax, transp);
	}else {
		if (paokind == 4) {	/* PBM */
			paomax = 1;
			kp = "PBM";
			pn = 1;
		}else {
			pao_skip(fin);
			paomax = pao_getint(fin) + 1;
			if (paokind == 5) {	/* PGM */
				kp = "PGM";
				pn = 1;
			}else if (paokind == 6) {	/* PPM */
				kp = "PPM";
				pn = 3;
			}
		}
		(void)getc(fin);	/* feed last CR */
	}
	if (verbose)
		fprintf(stderr, "%s, %dx%d, max:%d, plane:%d\n",
			kp, width, height, paomax, pn);

	open_png(fout, width, height, paomax, pn);
	write_png(fin, paocomm);
	close_png();
}
