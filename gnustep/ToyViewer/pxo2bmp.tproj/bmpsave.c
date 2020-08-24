#include <stdio.h>
//#include <libc.h> //Linux only
#include "bmp.h"

static void put_short(int k, FILE *fp)
{
	putc(k & 0xff, fp);
	putc((k >> 8) & 0xff, fp);
}

static void put_long(long k, FILE *fp)
{
	put_short(k & 0xffff, fp);
	put_short((k >> 16) & 0xffff, fp);
}

static void saveBmpHeader(FILE *fp,
		commonInfo *cinf, int bits, int cnum, paltype *pal)
{
	int i;
	unsigned char *p;
	int colors = 1 << bits;
	long iSize = ((((cinf->width * bits) + 31) >> 3) & ~3) * cinf->height;
	long hSize = (bits == 24)? 54 : (54 + colors * 4);

	putc('B', fp);
	putc('M', fp);
	put_long(iSize + hSize + 2, fp);	/* File Size */
	put_long(0, fp);	/* Reserved */
	put_long(hSize, fp);
	put_long(WIN3, fp);
	put_long((long)cinf->width, fp);
	put_long((long)cinf->height, fp);
	put_short(1, fp);	/* plane */
	put_short(bits, fp);
	put_long(0, fp);	/* compression */
	put_long(iSize, fp);	/* image size */
	put_long(2834, fp);	/* Pixels/Meter */
	put_long(2834, fp);	/* 2834 = 72bpi */
	put_long(colors, fp);	/* colors */
	put_long(colors, fp);

	if (bits != 24 && pal) {
		for (i = 0; i < cnum; i++) {
			p = pal[i];
			putc(p[BLUE], fp);
			putc(p[GREEN], fp);
			putc(p[RED], fp);
			putc(0, fp);
		}
		for ( ; i < colors; i++) {
			putc(255, fp);
			putc(255, fp);
			putc(255, fp);	/* white */
			putc(0, fp);
		}
	}
}

int saveBmpFromPBM(FILE *fp, commonInfo *cinf)
{
	int	x, y, cc, cnt;
	unsigned char *pp;
	static paltype pal[2] = { { 0, 0, 0 }, { 255, 255, 255 } };

	saveBmpHeader(fp, cinf, 1, 2, pal);
	for (y = cinf->height - 1; y >= 0; y--) {
		cnt = 0;
		pp = cinf->pixels[0] + ((cinf->width + 7) >> 3) * y;
		for (x = 0; x < cinf->width; x += 8, cnt++) {
			cc = *pp++ ^ 0xff;
			putc(cc, fp);
		}
		while (cnt & 0x03) {
			putc(0, fp);
			cnt++;
		}
	}
	putc(0, fp);
	putc(0, fp);
	return 0;
}

int saveBmpWithPalette(FILE *fp, commonInfo *cinf)
{
	int	x, y;
	int	cnum, cnt, bits;
	unsigned char *pp;

	cnum = cinf->palsteps;
	bits = (cnum <= 2) ? 1 :((cnum <= 16) ? 4 : 8);
	saveBmpHeader(fp, cinf, bits, cnum, cinf->palette);
	for (y = cinf->height - 1; y >= 0; y--) {
	    cnt = 0;
	    if (cnum <= 2) {
		int cc, mask;
		pp = cinf->pixels[0] + cinf->width * y;
		mask = 0x80, cc = 0;
		for (x = 0; ; ) {
			if (*pp++)
				cc |= mask;
			if (++x >= cinf->width) {
				putc(cc, fp);
				cnt++;
				break;
			}
			if ((mask >>= 1) == 0) {
				putc(cc, fp);
				cnt++;
				mask = 0x80, cc = 0;
			}
		}
	    }else {
		pp = cinf->pixels[0] + cinf->width * y;
		if (cnum <= 16) {
		    int cc, dd;
		    for (x = 0; x < cinf->width; x++, cnt++) {
			cc = (*pp++ << 4) & 0xf0;
			if (++x >= cinf->width) dd = 0;
			else
				dd = *pp++ & 0x0f;
			putc((cc|dd), fp);
		    }
		}else { /* 8 bits */
		    for (x = 0; x < cinf->width; x++, cnt++)
			putc(*pp++, fp);
		}
	    }

	    while (cnt & 0x03) {
		putc(0, fp);
		cnt++;
	    }
	}
	putc(0, fp);
	putc(0, fp);
	return 0;
}

int saveBmpbmap(FILE *fp, commonInfo *cinf)
{
	int	x, y, i;
	unsigned char *pp[3];

	saveBmpHeader(fp, cinf, 24, 0, NULL);
	for (y = cinf->height - 1; y >= 0; y--) {
		for (i = 0; i < 3; i++)
			pp[i] = cinf->pixels[i] + cinf->width * y;
		for (x = 0; x < cinf->width; x++) {
			putc(pp[BLUE][x], fp);
			putc(pp[GREEN][x], fp);
			putc(pp[RED][x], fp);
		}
		for (x *= 3 ; x & 0x03; x++)
			putc(0, fp);
	}
	putc(0, fp);
	putc(0, fp);
	return 0;
}
