/*
    ras2pxo  --- SUN Rasterfile --> PXO file
    Ver. 1.0   2001.05.12   By OGIHARA Takeshi
  ---------------------------
    Original ...
    SUNLBP  --- SUN rasterfile print out filter
    Ver. 1.0   1988-12-21  by T.Ogihara
    Ver. 1.5   1990-03-30   for LaserShot
*/

#include  <stdio.h>
#include  <stdlib.h>
#include  "rasterfile.h"
#include  "ras2pxo.h"

static long get_long(FILE *fp)
{
	int i = 3;
	long c = getc(fp);
	while (i--)
		c = (c << 8) | getc(fp);
	return c;
}

rasinfo *loadRasterHeader(FILE *fp, int *errcode)
{
	rasinfo *ras;

	if (get_long(fp) != RAS_MAGIC)
		return NULL;
	ras = (rasinfo *)malloc(sizeof(rasinfo));
	ras->ras_magic = RAS_MAGIC;
	ras->ras_width = get_long(fp);
	ras->ras_height = get_long(fp);
	ras->ras_depth = get_long(fp);
	ras->ras_length = get_long(fp);
	ras->ras_type = get_long(fp);
	ras->ras_maptype = get_long(fp);
	ras->ras_maplength = get_long(fp);
	if (ras->ras_maplength > 0) {
		int num, i, col;
		num = ras->ras_maplength / 3;
		for (col = 0; col < 3; col++) {
			for (i = 0; i < num; i++)
				ras->palette[i][col] = getc(fp);
		}
	}
	return ras;
}

void freeRasterHeader(rasinfo *ras)
{
	(void)free((void *)ras);
}

BOOL isGray(const rasinfo *ras)
/* Is Gray-scaled all colors of the palette ? */
{
	int i, n;
	const unsigned char *p;
	const paltype *pal;

	if (ras->ras_depth != 8)
		return NO;
	if (ras->ras_maplength == 0)
		return NO;
	pal = ras->palette;
	n = ras->ras_maplength / 3;
	for (i = 0; i < n; i++) {
		p = pal[i];
		if (p[0] != p[1] || p[1] != p[2])
			return NO;
	}
	return YES;
}


static void ras_uncmp(FILE *fp, FILE *fo, unsigned char *maparray)
{
	const unsigned char SPC = 0x80;
	int c, d;
	unsigned char *map, gray[256];

	if (maparray) map = maparray;
	else {
		int i;
		for (i = 0; i < 255; i++) gray[i] = i;
		map = gray;
	}
	while ((c = getc(fp)) != EOF) {
		if (c == SPC) {
			if ((d = getc(fp)) == 0)
			    putc(map[SPC], fo);
			else {
			    c = getc(fp);
			    for (; d >= 0; d--) putc(map[c], fo);
			}
		}else
			putc(map[c], fo);
	}
} /* ras_uncmp */

static void ras_bytecopy(FILE *fp, FILE *fo, int wid, int hgt)
{
	int x, y;
	BOOL odd = wid & 1;
	for (y = 0; y < hgt; y++) {
		for (x = 0; x < wid; x++)
			putc(getc(fp), fo);
		if (odd) (void)getc(fp);
	}
}

int raster_to_pxo(const rasinfo *ras, FILE *fp, FILE *fo)
{
	int	num, i, j;
	const unsigned char *p;

/* PX original Format
    PX			: Header
    Width Height Colors	: Colors := Number of colors in palette - 1
    Count		: if Trans is there Count=1, otherwise Count=0.
    Trans		: Transparent + 256
    [Palette]		: Binary
    [Bitmap]		: Binary
*/
	num = ras->ras_maplength / 3;
	fprintf(fo, "PX\n%d %d %d 0\n",
		ras->ras_width, ras->ras_height, num - 1);
	for (i = 0; i < num; i++) {	/* Palette */
		p = (unsigned char *)ras->palette[i];
		for (j = 0; j < 3; j++)
			putc(p[j], fo);
	}
	if (ras->ras_type == RT_BYTE_ENCODED)
		ras_uncmp(fp, fo, NULL);
	else
		ras_bytecopy(fp, fo, ras->ras_width, ras->ras_height);
	return 0;
}

int raster_to_pgm(const rasinfo *ras, FILE *fp, FILE *fo)
{
	fprintf(fo, "P5\n%d %d 255\n", ras->ras_width, ras->ras_height);
	if (ras->ras_maplength > 0) {
		unsigned char map[256];
		int  i;
		int  num = ras->ras_maplength / 3;
		for (i = 0; i < num; i++)	/* Palette */
			map[i] = (unsigned char)ras->palette[i][0];
		if (ras->ras_type == RT_BYTE_ENCODED)
			ras_uncmp(fp, fo, map);
		else {
			int x, y;
			int wid = ras->ras_width;
			int hgt = ras->ras_height;
			BOOL odd = wid & 1;
			for (y = 0; y < hgt; y++) {
				for (x = 0; x < wid; x++)
					putc(map[getc(fp)], fo);
				if (odd) (void)getc(fp);
			}
		}
	}else { /* No Palette */
		if (ras->ras_type == RT_BYTE_ENCODED)
			ras_uncmp(fp, fo, NULL);
		else
			ras_bytecopy(fp, fo, ras->ras_width, ras->ras_height);
	}
	return 0;
}

int raster_to_pbm(const rasinfo *ras, FILE *fp, FILE *fo)
{
	fprintf(fo, "P4\n%d %d\n", ras->ras_width, ras->ras_height);
	if (ras->ras_type == RT_BYTE_ENCODED)
		ras_uncmp(fp, fo, NULL);
	else {
		int bytes = (ras->ras_width + 7) >> 3;
		ras_bytecopy(fp, fo, bytes, ras->ras_height);
	}
	return 0;
}
