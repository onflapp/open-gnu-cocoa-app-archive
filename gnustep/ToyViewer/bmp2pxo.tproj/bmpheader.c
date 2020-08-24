#include <stdio.h>
//#include <libc.h> //Linux Only

#include "bmp.h"

int get_short(FILE *fp)
{
	int c = getc(fp);
	return ((getc(fp) << 8) | c);
}

long get_long(FILE *fp)
{
	long c = get_short(fp);
	return ((get_short(fp) << 16) | c);
}


bmpHeader *loadBmpHeader(FILE *fp, int *errcode)
     /* ファイルからヘッダ情報を読む。
	エラーが起きた場合は NULLが返り、errcodeにその理由が入る。
	ファイルポインタはパレット情報の先頭を指して返る。 */
{
	long	ftype, boffs, wid, hei, xp, yp, planes, colors;
	long	cmp=NoComp;
	short	bits = 0;
	bmpHeader *bh;

	wid = hei = planes = bits = xp = yp = colors = 0;
	*errcode = 0;
	if (getc(fp) != 'B' || getc(fp) != 'M') {
		*errcode = Err_FORMAT;
		return NULL;
	}
	(void) fseek(fp, 8L, SEEK_CUR); /* Skip hot spot */
	boffs = get_long(fp);
	ftype = get_long(fp);
	if (ftype == OS2) {
		wid = get_short(fp);
		hei = get_short(fp);
		planes = get_short(fp);
		bits = get_short(fp);
	}else if (ftype == WIN3) {
		wid = get_long(fp);
		hei = get_long(fp);
		planes = get_short(fp);
		bits = get_short(fp);
		cmp = get_long(fp);
		(void) get_long(fp);
		xp = get_long(fp);
		yp = get_long(fp);
		colors = get_long(fp);
		(void) get_long(fp);
	}else { /* ERROR */
		*errcode = Err_FORMAT;
		return NULL;
	}
	if(feof(fp)) {
		*errcode = Err_SHORT;
		return NULL;
	}
	if (xp < 0 || yp < 0) {
		*errcode = Err_FORMAT;
		return NULL;
	}
	if (planes != 1 || wid > MAXWidth
		|| (bits != 1 && bits != 4 && bits != 8
			&& bits != 15 && bits != 16 && bits != 24)) {
		*errcode = Err_IMPLEMENT;
		return NULL;
	}
	bh = (bmpHeader *)malloc(sizeof(bmpHeader));
	bh->type = ftype;
	bh->bits = bits;
	bh->x = wid;
	bh->y = hei;
	bh->xpm = xp;
	bh->ypm = yp;
	bh->bitoffset = boffs;
	bh->comp = cmp;
	return bh;
}

void freeBmpHeader(bmpHeader *bh)
{
	if (bh) {
		if (bh->palette) free((void *)bh->palette);
		free((void *)bh);
	}
}
