/*
	bmp2pxo
	Ver.1.0   1995-04-28  T.Ogihara
	Ver.1.3   1997-08-25  T.Ogihara
		partially based on
			"bmptoppm" by DaviD W. Sanderson (1992) and
			"CzView 2.20" by Y.Sasaki (1994).
	Ver.2.0   1998-01-07  T.Ogihara
		for 16 bits BMP
*/

#include  <stdio.h>
#include  "bmp.h"

void write_pxo(bmpHeader *bh, unsigned char **planes, FILE *fout);


static void usage(const char *toolname)
{
	fprintf(stderr, "Usage: %s [bmp_file]\n", toolname);
}

int main(int argc, char **argv)
{
	FILE *fp;
	bmpHeader *bh = NULL;
	int	err;
	unsigned char *planes[MAXPLANE];

	fp = stdin;
	if (argc >= 2) {
		if (argv[1][0] == '-') {
			usage(argv[0]);
			return 1;
		}
		if ((fp = fopen(argv[1], "r")) == NULL) {
			fprintf(stderr, "ERROR: Can't open %s\n", argv[1]);
			return 1;
		}
	}
	if ((bh = loadBmpHeader(fp, &err)) == NULL) {
		fprintf(stderr, "ERROR: Illegal format: %s\n", argv[1]);
		(void)fclose(fp);
		return 1;
	}

#ifdef NOTE
	if (bh->bits == 15 || bh->bits == 16) {
		fprintf(stderr, "Note: 16bit BMP: %s\n", argv[1]);
	}
#endif

	if ((err = bmpGetImage(fp, bh, planes)) == 0) {
		write_pxo(bh, planes, stdout);
		(void)free(planes[0]);
	}

	freeBmpHeader(bh);
	(void)fclose(fp);
	return err;
}

void write_pxo(bmpHeader *bh, unsigned char **planes, FILE *fout)
{
	long total, i, j;

	if (bh->bits == 24)
		fprintf(fout, "P6\n# FullColor ");
	else if (bh->bits == 15 || bh->bits == 16)
		fprintf(fout, "P6\n# %dbit Color ", bh->bits);
	else
		fprintf(fout, "PX\n# Palette(%d) ", bh->colors);
	fprintf(fout, "%s%s\n",
		(bh->type == OS2)?"OS2":"WIN3", (bh->comp ? "(RLE)":""));
	fprintf(fout, "%d %d ", bh->x, bh->y);
	total = bh->x * bh->y;
	if (bh->bits > 8) {
		unsigned char *rr, *gg, *bb;
		fprintf(fout, "255\n");
		rr = planes[0];
		gg = planes[1];
		bb = planes[2];
		for (i = 0; i < total; i++) {
			fputc(*rr++, fout);
			fputc(*gg++, fout);
			fputc(*bb++, fout);
		}
	}else {
		unsigned char *p;
		fprintf(fout, "%d 0\n", bh->colors - 1);
		for (i = 0; i < bh->colors; i++) {
			p = bh->palette[i];
			for (j = 0; j < 3; j++)
				fputc(*p++, fout);
		}
		p = planes[0];
		for (i = 0; i < total; i++)
			fputc(*p++, fout);
	}
}
