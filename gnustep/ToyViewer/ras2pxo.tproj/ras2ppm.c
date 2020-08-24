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

static int bgr_idx = 0;
static int bgrset[2];

static void put_bgr(int c, FILE *fo)
{
	if (bgr_idx >= 2) {
		putc(c, fo);
		putc(bgrset[1], fo);
		putc(bgrset[0], fo);
		bgr_idx = 0;
	}else
		bgrset[bgr_idx++] = c;
}

static void ras_uncmp_rgb(FILE *fp, FILE *fo)
{
	const unsigned char SPC = 0x80;
	int c, d;

	while ((c = getc(fp)) != EOF) {
		if (c == SPC) {
			if ((d = getc(fp)) == 0)
			    put_bgr(SPC, fo);
			else {
			    c = getc(fp);
			    for (; d >= 0; d--) put_bgr(c, fo);
			}
		}else
			put_bgr(c, fo);
	}
} /* ras_uncmp_rgb */

static void ras_rgbcopy(FILE *fp, FILE *fo, int wid, int hgt)
{
	int x, y, blue, green;
	BOOL odd = wid & 1;
	for (y = 0; y < hgt; y++) {
		for (x = 0; x < wid; x++) {
			blue = getc(fp);
			green = getc(fp);
			putc(getc(fp), fo);
			putc(green, fo);
			putc(blue, fo);
		}
		if (odd) (void)getc(fp);
	}
}

int raster_to_ppm(const rasinfo *ras, FILE *fp, FILE *fo)
{
	fprintf(fo, "P6\n%d %d 255\n", ras->ras_width, ras->ras_height);
	if (ras->ras_type == RT_BYTE_ENCODED)
		ras_uncmp_rgb(fp, fo);
	else
		ras_rgbcopy(fp, fo, ras->ras_width, ras->ras_height);
	return 0;
}
