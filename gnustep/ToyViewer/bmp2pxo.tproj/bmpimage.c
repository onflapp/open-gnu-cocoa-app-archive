#include <stdio.h>
//#include <libc.h> //GNUstep only

#include "bmp.h"

static int xdelta, ydelta, compmode;

static int bmpGetPalette(FILE *fp, bmpHeader *bh)
    /*	Reads palette of the image and store its address into bh->palette.
	In cases 15, 16, or 24bit-color images, bh->palette == NULL.
	Returns 0, when success.
	Otherwise returns Error Code, and bh->palette := NULL.
    */
{
	int	i, color;
	paltype	*pal = NULL;
	unsigned char *p;

	bh->palette = NULL;
	bh->colors = 0;
	if (bh->bits >= 15)	/* No palette for 15, 16, 24 colors */
		return 0;
	color = 1 << bh->bits;
	pal = (paltype *)malloc(sizeof(paltype) * color);
	if (bh->type == OS2) {
		for (i = 0; i < color; i++) {
			p = pal[i];
			p[BLUE] = getc(fp);
			p[GREEN] = getc(fp);
			p[RED] = getc(fp);
		}
	}else { /* WIN3 */
		for (i = 0; i < color; i++) {
			p = pal[i];
			p[BLUE] = getc(fp);
			p[GREEN] = getc(fp);
			p[RED] = getc(fp);
			(void) getc(fp);
		}
	}
	bh->palette = pal;
	bh->colors = color;
	if (feof(fp) || fseek(fp, bh->bitoffset, SEEK_SET) < 0)
		return Err_SHORT;
	return 0;
}

static int get1dot(FILE *fp, int wid, unsigned char *ln)
{
	int x, cnt, cc, mask;

	if (feof(fp))
		return -1;
	for (x = 0, cnt = 0; x < wid; cnt++) {
		cc = getc(fp);
		for (mask = 0x80; mask; mask >>= 1)
			ln[x++] = (cc & mask) ? 1 : 0;
	}
	for ( ; cnt & 0x03; cnt++)
		(void) getc(fp);
	return 0;
}

static int get4dots(FILE *fp, int wid, unsigned char *ln)
{
	int x, cnt, cc;

	if (feof(fp))
		return -1;
	for (x = 0, cnt = 0; x < wid; cnt++) {
		cc = getc(fp);
		ln[x++] = cc >> 4;
		ln[x++] = (cc & 0x0f);
	}
	for ( ; cnt & 0x03; cnt++)
		(void) getc(fp);
	return 0;
}

static int get8dots(FILE *fp, int wid, unsigned char *ln)
{
	int cnt;

	if (feof(fp))
		return -1;
	for (cnt = 0; cnt < wid; cnt++)
		ln[cnt] = getc(fp);
	for ( ; cnt & 0x03; cnt++)
		(void) getc(fp);
	return 0;
}

static int rledots(FILE *fp, int wid, unsigned char *ln)
{
	int	i, j, k, cc, count;
	int	half[2];

	if (feof(fp))
		return -1;
	for (i = 0; i < wid; i++)
		ln[i] = 0;
	if (ydelta > 0) {
		ydelta--;
		return 0;
	}
	count = wid;
	if (xdelta > 0) {
		if (xdelta > count) {
			xdelta = 0;
			return 0;
		}
		count -= xdelta;
		ln += xdelta;
	}
	xdelta = 0;
	for ( ; ; ) {
		i = getc(fp);
		if (i) { /* Codec Mode */
			if (i > count) i = count;
			count -= i;
			cc = getc(fp);
			if (compmode == RLE8) {
				while (i-- > 0)
					*ln++ = cc;
			}else {
				half[0] = cc >> 4;
				half[1] = cc & 0x0f;
				for (k = 0; i-- > 0; k ^= 1)
					*ln++ = half[k];
			}
			continue;
		}
		/* Absolute Mode */
		j = getc(fp);
		if (j == 0 || j == 1) /* EOL / EOF */
			break; /* return */
		if (j == 2) {  /* Delta Mode */
			xdelta = getc(fp);  /* X-offset */
			ydelta = getc(fp);  /* Y-offset */
			if (ydelta == 0) {
				count -= xdelta;
				ln += xdelta;
				xdelta = 0;
			}else {
				xdelta += wid - count;
				ydelta--;
				break; /* return */
			}
		}else {
			if (j > count) j = count;
			count -= j;
			if (compmode == RLE8) {
				k = j & 1;	/* 16-bit packing */
				while (j-- > 0)
					*ln++ = getc(fp);
			}else {
				k = (j + 1) & 2; /* 16-bit packing */
				while (j-- > 0) {
					cc = getc(fp);
					*ln++ = cc >> 4;
					if (j-- <= 0)
						break;
					*ln++ = cc & 0x0f;
				}
			}
			if (k)
				(void) getc(fp);
		}
	}
	return 0;
}

int bmpGetImage(FILE *fp, bmpHeader *bh, unsigned char **planes)
     /*	¥Õ¥¡¥¤¥?«¤é¥¤¥á¡¼¥¸¥Ç¡¼¥¿¤òÇÉ¤ß½Ð¤·¡¢R,G,B ¤Î£³¤Ä¤Î¥×¥ì¡¼¥ó¤ÎÀèÆ¬
	¥¢¥É¥ì¥¹¤?planes[0]~[2] ¤Ë¥»¥Ã¥È¤¹¤?£³Æ¿§¤ËÉ¬Í×¤Ê¥Ô¥¯¥»¥?ô¤Ï
	bits ¤ËÆþ¤?é¤??£bh¤Ë¤Ï¥Ø¥Ã¥À¾ðËó¤ò»ØÄê¤¹¤?£ */	
{
	int	x, y, w;
	long	total;
	int	err = 0;
	int 	(*getNdots)(FILE *, int, unsigned char *) = get8dots;

	if (bh->comp) {
		if (bh->comp != RLE8 && bh->comp != RLE4)
			return Err_IMPLEMENT;
		compmode = bh->comp;
		getNdots = rledots;
	}else {
		compmode = NoComp;
		if (bh->bits == 1)
			getNdots = get1dot;
		else if (bh->bits == 4)
			getNdots = get4dots;
		else if (bh->bits == 8)
			getNdots = get8dots;
	} /* else bits == 15, 16, 24 */

	if ((err = bmpGetPalette(fp, bh)) != 0)
		return err;
	total = bh->x * bh->y;
	if (bh->bits <= 8) {
		unsigned char	*map;
		unsigned char	buf[MAXWidth];
		if ((map = (unsigned char *)malloc(total)) == NULL)
			return Err_MEMORY;
		planes[0] = map;
		planes[1] = NULL;
		for (y = bh->y - 1; y >= 0; y--) {
			if (getNdots(fp, bh->x, buf) < 0)
				return Err_SHORT;
			map = planes[0] + bh->x * y;
			for (x = 0; x < bh->x; x++)
				*map++ = buf[x];
		}
	}else if (bh->bits == 15 || bh->bits == 16) { /* 15, 16 bits color */
		unsigned char	*rr, *gg, *bb;
		unsigned int	val, cc;
		if ((rr = (unsigned char *)malloc(total*3)) == NULL)
			return Err_MEMORY;
		planes[0] = rr;
		planes[1] = gg = rr + total;
		planes[2] = bb = planes[1] + total;
		for (y = bh->y - 1; y >= 0; y--) {
			if (feof(fp))
				return Err_SHORT;
			rr = planes[0] + (w = bh->x * y);
			gg = planes[1] + w;
			bb = planes[2] + w;
			for (x = 0; x < bh->x; x++) {
				val = getc(fp) & 0xff;
				val = ((getc(fp) & 0xff) << 8) | val;
			/* 0rrr rrgg gggb bbbb */
				cc = (val >> 7) & 0xf8;
				*rr++ = cc | (cc >> 5);
				cc = (val >> 2) & 0xf8;
				*gg++ = cc | (cc >> 5);
				cc = (val << 3) & 0xf8;
				*bb++ = cc | (cc >> 5);
			}
			for (x *= 2; x & 0x03; x++)
				(void) getc(fp);
		}
	}else { /* 24 bits color */
		unsigned char	*rr, *gg, *bb;
		if ((rr = (unsigned char *)malloc(total*3)) == NULL)
			return Err_MEMORY;
		planes[0] = rr;
		planes[1] = rr + total;
		planes[2] = planes[1] + total;
		for (y = bh->y - 1; y >= 0; y--) {
			if (feof(fp))
				return Err_SHORT;
			rr = planes[0] + (w = bh->x * y);
			gg = planes[1] + w;
			bb = planes[2] + w;
			for (x = 0; x < bh->x; x++) {
				*bb++ = getc(fp);
				*gg++ = getc(fp);
				*rr++ = getc(fp);
			}
			for (x *= 3; x & 0x03; x++)
				(void) getc(fp);
		}
	}
	return 0;
}
