#include <sys/types.h>
#include <sys/stat.h>
#include <stdio.h>
//#include <libc.h> //Linux only

#include "mag.h"

static struct {
	unsigned char dx, dy;
} idxtab[16] = {
	{ 0, 0 }, { 2, 0 }, { 4, 0 }, { 8, 0 },
	{ 0, 1 }, { 2, 1 },
	{ 0, 2 }, { 2, 2 }, { 4, 2 },
	{ 0, 4 }, { 2, 4 }, { 4, 4 },
	{ 0, 8 }, { 2, 8 }, { 4, 8 },
	{ 0, 16}
};

int magDecode(FILE *fp, FILE *fw, magHeader *mh, long base)
{
	unsigned char	*flagA, *Ap, *Bp;
	int	i, x, y, amask, vbufp, color;
	int	xwidth, /* mh->xbitwidth */
		xiter,	/* 256色の場合、 mh->xbytewidth*2 */
		/* 16色の場合、読み込む1byteが２ドット分だから、１ラインは
		   (xbytewidth*4)byte で構成される。256色の場合は
		   (xbytewidth*8)byte. 結局、１ラインは (xiter*4)byte. */
		xbyte;	/* xiter*4 */
	long	w;
	unsigned char	flagbuf[FlagBufMAX];
	unsigned char	vbuf[17][MaxImageSize];
	int	green;

/* PX original Format
    PX			: Header
    Width Height Colors	: Colors := Number of colors in palette - 1
    Count		: if Trans is there Count=1, otherwise Count=0.
    Trans		: Transparent + 256
    [Palette]		: Binary
    [Bitmap]		: Binary
*/
	color = mh->is256c ? 256 : 16;
	fprintf(fw, "PX\n");
	if (mh->memo && mh->memo[0])
		fprintf(fw, "# : %s\n", mh->memo);
	fprintf(fw, "%d %d %d 0\n", mh->xbitwidth, mh->yheight, color - 1);
	for (i = 0; i < color; i++) {	/* Palette */
		green = getc(fp);
		putc(getc(fp), fw); /* RED */
		putc(green   , fw); /* GREEN */
		putc(getc(fp), fw); /* BLUE */
	}

	w = mh->pixeloffset - mh->flagAoffset;
	if ((flagA = (unsigned char *)malloc(w)) == NULL)
		return Err_MEMORY;
	Ap = flagA;
	Bp = flagA + (mh->flagBoffset - mh->flagAoffset);
	// (void)fseek(fp, base + mh->flagAoffset, SEEK_SET);
	for ( ; w > 0; w--)
		*Ap++ = getc(fp);
	Ap = flagA;
	xiter = mh->xbytewidth;
	xwidth = mh->xbitwidth;
	if (mh->is256c)
		xiter *= 2;
	xbyte = xiter * 4;
	bzero((char *)flagbuf, FlagBufMAX);
	amask = 0x80;
	vbufp = 0;
	// (void)fseek(fp, base + mh->pixeloffset, SEEK_SET);

	for (y = 0; y < mh->yheight; y++) {
		unsigned char *vp = vbuf[vbufp];
		unsigned char *fb = flagbuf;
		int k, xpos = 0;
		for (x = 0; x < xiter; x++, fb++) {
			int bflag, py;
			unsigned char *q;
			if (*Ap & amask)
				*fb ^= *Bp++;
			if ((amask >>= 1) == 0)
				amask = 0x80, Ap++;
			/* １バイト、２つのフラグに対して４ドットを読む */
			for (k = 0; k < 2; k++) {
				bflag = (k ? *fb : (*fb >> 4)) & 0x0f;
				if (bflag == 0) {
					if (feof(fp)) {
						free((void *)flagA);
						return Err_SHORT;
					}
					*vp++ = getc(fp);
					*vp++ = getc(fp);
				}else {
					py = vbufp - idxtab[bflag].dy;
					if (py < 0) py += 17;
					q = &vbuf[py][xpos - idxtab[bflag].dx];
					*vp++ = q[0];
					*vp++ = q[1];
				}
				xpos += 2;
			}
		}
		vp = vbuf[vbufp];
		for (k = mh->isDouble ? 2 : 1; k > 0; k--)
			if (mh->is256c) {
				for (x = 0; x < xwidth; x++, vp++)
					putc(*vp, fw);
			}else {
				for (x = 0; x < xwidth; x++, vp++) {
					putc(*vp >> 4, fw);
					if (++x >= xwidth) break;
					putc(*vp & 0x0f, fw);
				}
			}
		if (++vbufp >= 17) vbufp = 0;
	}

	free((void *)flagA);
	return 0;
}
