#include  <stdio.h>
//#include  <libc.h>
#include  <objc/objc.h>
#include  "imfunc.h"

int byte_length(int bits, int width)
{
	switch (bits) {
	case 1: return ((width + 7) >> 3);
	case 2: return ((width + 3) >> 2);
	case 4: return ((width + 1) >> 1);
	case 8:
	default:
		break;
	}
	return width;
}

int optimalBits(unsigned char *pattern, int num)
/* How many bits are needed to represent given patterns */
{
	int i, x;

	if (num > 16) return 8;
	if (num == 1) { /* 1 bit; only one color */
		if (pattern[0] || pattern[0xff]) return 1;
	}else if (num == 2) { /* 1 bit */
		if (pattern[0] && pattern[0xff]) return 1;
	}
	if (num <= 4) { /* 2 bits */
		for (i = 1; i <= 0xfe; i++)
			if (pattern[i] && (i != 0x55 && i != 0xaa))
				goto BIT4;
		return 2;
	}
BIT4:	/* num <= 16 -- 4 bits */
	for (i = 1; i <= 0xfe; i++)
		if (pattern[i]
			&& ((x = i & 0x0f) != 0 && x != 0x0f && x != i >> 4))
				return 8;
	return 4;
}

int howManyBits(paltype *pal, int n)
/* How many bits are needed to display colors of the palette ? */
{
	int i, c, num;
	unsigned char *p, buf[256];

	for (i = 0; i < 256; i++) buf[i] = 0;
	num = 0;
	for (i = 0; i < n; i++) {
	    p = pal[i];
	    for (c = 0; c < 3; c++)
		if (buf[p[c]] == 0) {
			buf[p[c]] = 1;
			if (++num > 16) return 8;
		}
	}
	return optimalBits(buf, num);
}

BOOL isGray(paltype *pal, int n)
/* Is Gray-scaled all colors of the palette ? */
{
	int i;
	unsigned char *p;

	if (pal == NULL)
		return NO;
	for (i = 0; i < n; i++) {
		p = pal[i];
		if (p[0] != p[1] || p[1] != p[2])
			return NO;
	}
	return YES;
}


int allocImage(unsigned char **planes,
	int width, int height, int repbits, int pnum)
{
	int i, xbyte, wd;
	unsigned char *p;

	xbyte = byte_length(repbits, width);
	wd = xbyte * height;
	if ((p = (unsigned char *)malloc(wd * pnum)) == NULL)
		return Err_MEMORY;
	for (i = 0; i < pnum; i++) {
		planes[i] = p;
		p += wd;
	}
	if (pnum < 5) planes[pnum] = NULL;
	return 0;
}


void expandImage(unsigned char **planes, unsigned char *buf,
	const paltype *pal, int repbits, int width, BOOL isgray, int transp)
{
	int x, n;
	unsigned char	*rr, *gg, *bb;
	const unsigned char	*p;

	if (isgray) {
		rr = planes[0];
	
		if (repbits == 1) {
			for (x = 0; x < width; x++) {
				*rr = pal[buf[x]][RED] & 0x80;
				for (n = 1; n < 8; n++) {
					if (++x >= width) break;
					*rr |= (pal[buf[x]][RED] & 0x80) >> n;
				}
				rr++;
			}
		}else if (repbits == 2) {
			for (x = 0; x < width; x++) {
				*rr = pal[buf[x]][RED] & 0xc0;
				for (n = 2; n < 8; n += 2) {
					if (++x >= width) break;
					*rr |= (pal[buf[x]][RED] & 0xc0) >> n;
				}
				rr++;
			}
		}else if (repbits == 4) {
			for (x = 0; x < width; x++) {
				*rr = pal[buf[x]][RED] & 0xf0;
				if (++x >= width) break;
				*rr++ |= pal[buf[x]][RED] >> 4;
			}
		}else /* 8 */ {
			for (x = 0; x < width; x++)
				*rr++ = pal[buf[x]][RED];
		}
	}else { /* Color */

		rr = planes[0];
		gg = planes[1];
		bb = planes[2];
	
		if (repbits == 1) {
			for (x = 0; x < width; x++) {
				p = pal[buf[x]];
				*rr = p[RED] & 0x80;
				*gg = p[GREEN] & 0x80;
				*bb = p[BLUE] & 0x80;
				for (n = 1; n < 8; n++) {
					if (++x >= width) break;
					p = pal[buf[x]];
					*rr |= (p[RED] & 0x80) >> n;
					*gg |= (p[GREEN] & 0x80) >> n;
					*bb |= (p[BLUE] & 0x80) >> n;
				}
				rr++, gg++, bb++;
			}
		}else if (repbits == 2) {
			for (x = 0; x < width; x++) {
				p = pal[buf[x]];
				*rr = p[RED] & 0xc0;
				*gg = p[GREEN] & 0xc0;
				*bb = p[BLUE] & 0xc0;
				for (n = 2; n < 8; n += 2) {
					if (++x >= width) break;
					p = pal[buf[x]];
					*rr |= (p[RED] & 0xc0) >> n;
					*gg |= (p[GREEN] & 0xc0) >> n;
					*bb |= (p[BLUE] & 0xc0) >> n;
				}
				rr++, gg++, bb++;
			}
		}else if (repbits == 4) {
			for (x = 0; x < width; x++) {
				p = pal[buf[x]];
				*rr = p[RED] & 0xf0;
				*gg = p[GREEN] & 0xf0;
				*bb = p[BLUE] & 0xf0;
				if (++x >= width) break;
				p = pal[buf[x]];
				*rr++ |= p[RED] >> 4;
				*gg++ |= p[GREEN] >> 4;
				*bb++ |= p[BLUE] >> 4;
			}
		}else /* 8 */ {
			for (x = 0; x < width; x++) {
				p = pal[buf[x]];
				*rr++ = p[RED];
				*gg++ = p[GREEN];
				*bb++ = p[BLUE];
			}
		}
	}

	if (transp >= 0) {
		rr = planes[isgray ? 1 : 3];
	
		if (repbits == 1) {
			for (x = 0; x < width; x++) {
				*rr = (buf[x] == transp) ? 0 : 0x80;
				for (n = 1; n < 8; n++) {
					if (++x >= width) break;
					if (buf[x] != transp)
						*rr |= 0x80 >> n;
				}
				rr++;
			}
		}else if (repbits == 2) {
			for (x = 0; x < width; x++) {
				*rr = (buf[x] == transp) ? 0 : 0xc0;
				for (n = 2; n < 8; n += 2) {
					if (++x >= width) break;
					if (buf[x] != transp)
						*rr |= 0xc0 >> n;
				}
				rr++;
			}
		}else if (repbits == 4) {
			for (x = 0; x < width; x++) {
				*rr = (buf[x] == transp) ? 0 : 0xf0;
				if (++x >= width) break;
				if (buf[x] != transp)
					*rr |= 0x0f;
				rr++;
			}
		}else /* 8 */ {
			for (x = 0; x < width; x++)
				*rr++ = (buf[x] == transp) ? 0 : 0xff;
		}
	}
}

void packImage(unsigned char *dst, unsigned char *src, int width, int bits)
{
	int x, n;

	if (bits == 1) {
		for (x = 0; x < width; x++) {
			*dst = *src++ & 0x80;
			for (n = 1; n < 8; n++) {
				if (++x >= width) break;
				*dst |= (*src++ & 0x80) >> n;
			}
			dst++;
		}
	}else if (bits == 2) {
		for (x = 0; x < width; x++) {
			*dst = *src++ & 0xc0;
			for (n = 2; n < 8; n += 2) {
				if (++x >= width) break;
				*dst |= (*src++ & 0xc0) >> n;
			}
			dst++;
		}
	}else if (bits == 4) {
		for (x = 0; x < width; x++) {
			*dst = *src++ & 0xf0;
			if (++x >= width) break;
			*dst++ |= *src++ >> 4;
		}
	}else /* bits == 8 */ {
		for (x = 0; x < width; x++)
			*dst++ = *src++;
	}
}

void packWorkingImage(const commonInfo *newinf, int pl,
	unsigned char **working, unsigned char **planes)
{
	int	pn, y;
	unsigned char *pp, *ww;

	for (pn = 0; pn < pl; pn++) {
	    for (y = 0; y < newinf->height; y++) {
		ww = working[pn] + y * newinf->width;
		pp = planes[pn] + y * newinf->xbytes;
		packImage(pp, ww, newinf->width, newinf->bits);
	    }
	}
}

paltype *copyPalette(paltype *pal, int pnum)
{
	paltype *np;

	if ((np = (paltype *)malloc(sizeof(paltype) * pnum)) == NULL)
		return NULL;
	memcpy(np, pal, sizeof(paltype) * pnum);
	return np;
}
