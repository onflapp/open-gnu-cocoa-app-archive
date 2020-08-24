/*
	pcxbmap.c
*/
#include <stdio.h>
//#include <libc.h> //Linux only

#include "pcx.h"

static unsigned char *ImgBuffer, *ImgPtr;

static unsigned char *getAllImage(FILE *fp, pcxHeader *ph, int *err)
{
	int	cc, n;
	unsigned char *buf;

	*err = 0;
	n = ph->xbytes * ph->y * ph->planes;
	if ((ImgBuffer = buf = (unsigned char *)malloc(n)) == NULL) {
		*err = Err_MEMORY;
		return NULL;
	}
	/* イメージをメモリ内に読み込んでしまう */
	fseek(fp, sizeof_pcxHeader, SEEK_SET);
	if (ph->comp == 1) { /* Run-Length Encoded */
		while (n > 0) {
			if ((cc = getc(fp)) == EOF) {
				*err = Err_SHORT;
				break;
			}
			if ((cc & 0xc0) == 0xc0) { /* RLE */
				int k = cc & 0x3f;
				cc = getc(fp);
				if (k > n) k = n;
				n -= k;
				while (k-- > 0)
				    *buf++ = cc;
			}else {
			    *buf++ = cc;
			    n--;
			}
		}
	}else { /* normal */
		while (n-- > 0) {
			if ((cc = getc(fp)) == EOF) {
				*err = Err_SHORT;
				break;
			}
			*buf++ = cc;
		}
	}
	return ImgBuffer;
}

static unsigned char *conv1to8(pcxHeader *ph, unsigned char *raw)
     /*	１ビット×４プレーンのイメージを、８ビット×１プレーンの形式に
	変換する。見かけは 8dots/byteだが、実際は４ドットずつ。
	引数の rawは解放され、新しいメモリ領域がとられる。 */
{
	int x, y, v, mask;
	unsigned char *buffer, *src;

	buffer = (unsigned char *)malloc(ph->x * ph->y + 16);
		/* ph->xbytes := (ph->x + 15) / 8,
		 * so, 15 bytes are added for loops below. Tricky... */
	if (buffer == NULL) {
		free((void *)raw);
		return NULL;
	}

	src = raw;
	for (y = 0; y < ph->y; y++) {
		unsigned char *dst, *dy;
		dy = &buffer[ph->x * y];
		bzero(dy, ph->xbytes);
		for (mask = 0x01; mask <= 0x08; mask <<= 1) {
			dst = dy;
			for (x = 0; x < ph->xbytes; x++) {
				for (v = 0x80; v; v >>= 1) {
					if (src[x] & v)
						*dst |= mask;
					dst++;
				}
			}
			src += ph->xbytes;
		}
	}
	ph->xbytes = ph->x;
	ph->bits = 8;
	ph->planes = 1;
	free((void *)raw);
	return buffer;
}

static void get2bitLine(unsigned char *line, int xbytes)
{
	int x, s;

	for (x = 0; x < xbytes; x++) {
		for (s = 6; s >= 0; s -= 2)
			*line++ = (*ImgPtr >> s) & 0x03;
		ImgPtr++;
	}
}

static void get4bitLine(unsigned char *line, int xbytes)
{
	int x;
	for (x = 0; x < xbytes; x++) {
		*line++ = *ImgPtr >> 4;
		*line++ = *ImgPtr++ & 0x0f;
	}
}

static void get8bitLine(unsigned char *line, int xbytes)
{
	int x;
	for (x = 0; x < xbytes; x++)
		*line++ = *ImgPtr++;
}

static void writeBitmap(FILE *fw, pcxHeader *ph, unsigned char *bm)
{
	int x, y, width;
	unsigned char *p;

	/* PBM */
	fprintf(fw, "P4\n#%s\n", ph->memo);
	fprintf(fw, "%d %d\n", ph->x, ph->y);
	width = (ph->x + 7) >> 3;
	for (y = 0; y < ph->y; y++) {
		p = bm + ph->xbytes * y;
		for (x = 0; x < width; x++)
			putc(p[x] ^ 0xff, fw);
	}
}

int pcxGetImage(FILE *fp, FILE *fw, pcxHeader *ph)
{
	int	i, y;
	int	colors, err = 0, colbit = 8;
	Boolean	isgray, isfullc;
	paltype	*pal;
	unsigned char line[MAXWidth];
	void (*getNbitLine)(unsigned char *, int) = get8bitLine;

	pal = ph->palette;
	if ((ImgPtr = getAllImage(fp, ph, &err)) == NULL)
		return err;
	/* 8bit color の場合、イメージの後ろにパレットがある */
	if (ph->bits == 8 && err == 0) {
		if (getc(fp) == hasPALETTE) { /* Magic Number */
			if (ph->palette) free((void *)ph->palette);
			pal = (paltype *)malloc(sizeof(paltype) * numPALETTE);
			if (pal == NULL)
				return Err_MEMORY;
			ph->palette = pal;
			for (i = 0; i < numPALETTE; i++) {
				unsigned char *p = pal[i];
				if (feof(fp)) {
					err = Err_SHORT;
					break;
				}
				p[RED] = getc(fp);
				p[GREEN] = getc(fp);
				p[BLUE] = getc(fp);
			}
		}else
			err = Err_SHORT;
	}
	colors = 1 << (ph->bits * ph->planes);
	colbit = howManyBits(pal, colors);
	isfullc = (ph->planes == 3 && ph->bits == 8);
	isgray = isfullc ? NO : isGray(pal, colors);

	if (ph->bits == 1) {
		if (ph->planes == 1) { /* Monochrome */
			writeBitmap(fw, ph, ImgBuffer);
			return err;
		}
		/* 1bit x 4planes -> 8bits x 1plane */
		if ((ImgBuffer = conv1to8(ph, ImgBuffer)) == NULL)
			return Err_MEMORY;
		ImgPtr = ImgBuffer;
	}
	if (ph->bits == 2)
		getNbitLine = get2bitLine;
	else if (ph->bits == 4)
		getNbitLine = get4bitLine;
	else /* 8 */
		getNbitLine = get8bitLine;

	if (isgray) {
		/* PGM */
		fprintf(fw, "P5\n#%s\n", ph->memo);
		fprintf(fw, "%d %d 255\n", ph->x, ph->y);
		for (y = 0; y < ph->y; y++) {
			getNbitLine(line, ph->xbytes);
			for (i = 0; i < ph->x; i++)
				putc(pal[line[i]][0], fw);
		}
	}else if (isfullc) {
		/* PPM */
		unsigned char gg[MAXWidth], bb[MAXWidth];
		fprintf(fw, "P6\n#%s\n", ph->memo);
		fprintf(fw, "%d %d 255\n", ph->x, ph->y);
		for (y = 0; y < ph->y; y++) {
			getNbitLine(line, ph->xbytes);
			getNbitLine(gg, ph->xbytes);
			getNbitLine(bb, ph->xbytes);
			for (i = 0; i < ph->x; i++) {
				putc(line[i], fw);
				putc(gg[i], fw);
				putc(bb[i], fw);
			}
		}
	}else {
		/* PXOF: PPM eXtended Original Format */
		fprintf(fw, "PX\n#%s\n", ph->memo);
		fprintf(fw, "%d %d %d 0\n", ph->x, ph->y, colors - 1);
		for (y = 0; y < colors; y++) {
			unsigned char *p = pal[y];
			for (i = 0; i < 3; i++)
				putc(p[i], fw);
		}
		for (y = 0; y < ph->y; y++) {
			getNbitLine(line, ph->xbytes);
			for (i = 0; i < ph->x; i++)
				putc(line[i], fw);
		}
	}
	(void)free((void *)ImgBuffer);
	return err;
}
