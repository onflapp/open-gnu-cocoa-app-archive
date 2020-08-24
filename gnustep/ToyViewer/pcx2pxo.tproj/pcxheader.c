#include <stdio.h>
//#include <libc.h> //Linux only 

#include "pcx.h"

int get_short(FILE *fp)
{
	int c = getc(fp);
	return ((getc(fp) << 8) | c);
}

pcxHeader *loadPcxHeader(FILE *fp, int *errcode)
	/* Reads header info. from the file.  If an error has occurred,
	its reason is stored in errcode, and NULL is returned. */
{
	int i, x1, y1, err;
	pcxHeader *ph;
	unsigned char *pp;
	paltype *pal;

	*errcode = err = 0;
	if (getc(fp) != pcxMAGIC) {
		*errcode = Err_FORMAT;
		return NULL;
	}
	if ((ph = (pcxHeader *)malloc(sizeof(pcxHeader))) == NULL) {
		*errcode = Err_MEMORY;
		return NULL;
	}
	if ((pal = (paltype *)malloc(sizeof(paltype) * 16)) == NULL) {
		free((void *)ph);
		*errcode = Err_MEMORY;
		return NULL;
	}
	ph->version = getc(fp);
	ph->comp = getc(fp);
	ph->bits = getc(fp);
	x1 = get_short(fp);	/* (x,y) min. */
	y1 = get_short(fp);
	ph->x = get_short(fp) - x1 + 1;  /* get width and height */
	ph->y = get_short(fp) - y1 + 1;
	ph->xpm = get_short(fp);	/* resolution */
	ph->ypm = get_short(fp);
	for (i = 0; i < 16; i++) { /* get palette */
		pp = pal[i];
		pp[RED]   = getc(fp);
		pp[GREEN] = getc(fp);
		pp[BLUE]  = getc(fp);
	}
	ph->palette = pal;
	(void) getc(fp);	/* skip 1 byte */
	ph->planes = getc(fp);
	ph->xbytes = get_short(fp);
	ph->pinfo = get_short(fp);

	if (ph->comp > 1)
		err = Err_IMPLEMENT;
	else {
		if (ph->bits == 1) {
			if (ph->planes > 4)
				err = Err_ILLG;
			if (ph->planes != 1 && ph->planes != 4)
				err = Err_IMPLEMENT;
		}else if (ph->bits == 8) {
			if (ph->planes != 1 && ph->planes != 3)
				err = Err_ILLG;
		}else if ((ph->bits != 2 && ph->bits != 4 && ph->bits != 8)
			|| ph->planes != 1)
			err = Err_ILLG;
		if (ph->x <= 0 || ph->y <= 0)
			err = Err_ILLG;
	}
	if (err) {
		*errcode = err;
		freePcxHeader(ph);
		return NULL;
	}
	sprintf(ph->memo,
		"%dbit%s/%dplane%s  ver.%d, comp=%d",
		ph->bits, ((ph->bits > 1) ? "s" : ""),
		ph->planes, ((ph->planes > 1) ? "s" : ""),
		ph->version,  ph->comp);
	return ph;
}

void freePcxHeader(pcxHeader *ph)
{
	if (ph) {
		if (ph->palette) free((void *)ph->palette);
		free((void *)ph);
	}
}
