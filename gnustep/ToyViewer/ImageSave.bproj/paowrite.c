#include <stdio.h>
#include <stdlib.h>
#include <libc.h>
#include <objc/objc.h>
#include "../common.h"
#include "../strfunc.h"
#include "save.h"

static void pxo_write(FILE *fp, const commonInfo *cinf)
{
	int i, n;
	int r, g, b, a;
	int alphaindex = -1;

	/* PXO */
	fprintf(fp, "PX\n# %s\n%d %d %d\n",
		key_comm(cinf), cinf->width, cinf->height, cinf->palsteps - 1);
	if (cinf->alpha) {
		alphaindex = cinf->palsteps;
		if (alphaindex >= FIXcount)
			alphaindex = FIXcount - 1;	/* Error */
		fprintf(fp, "1 %d\n", alphaindex + 256);
	}else
		fprintf(fp, "0\n");
	for (n = 0; n < cinf->palsteps; n++) {
		unsigned char *p = cinf->palette[n];
		for (i = 0; i < 3; i++)
			putc(*p++, fp);
	}
	for (n = cinf->width * cinf->height - 1; n >= 0; n--) {
		getPixel(&r, &g, &b, &a);
		putc( (a == AlphaTransp ? alphaindex : mapping(r, g, b)), fp);
	}
}

/* Note:
	PNG_COLOR_TYPE_GRAY (bit depths 1, 2, 4, 8, 16)
	PNG_COLOR_TYPE_GRAY_ALPHA (bit depths 8, 16)
*/

static void png_write_f(FILE *fp, const commonInfo *cinf)
{
	int max = 255, sft = 0, i, n, pn, pnum, ax;
	int elm[MAXPLANE];

	pn = pnum = cinf->numcolors;
	if (cinf->alpha) {
		max = 255;
		sft = 0;
		ax = pn++;
	}else {
		switch (cinf->bits) {
		case 1: max = 1;  sft = 7;  break;
		case 2: max = 3;  sft = 6;  break;
		case 4: max = 15;  sft = 4;  break;
		case 8: max = 255;  sft = 0;  break;
		}
		ax = 0;
	}
	/* PAO */
	fprintf(fp, "PA\n# %s\n%d %d %d %d\n",
			key_comm(cinf), cinf->width, cinf->height, max, pn);
	n = cinf->width * cinf->height;
	while (n-- > 0) {
		(void) getPixel(&elm[0], &elm[1], &elm[2], &elm[3]);
		if (sft) {
			for (i = 0; i < pnum; i++)
				putc(elm[i] >> sft, fp);
			if (ax)
				putc(elm[3] >> sft, fp);
		}else {
			for (i = 0; i < pnum; i++)
				putc(elm[i], fp);
			if (ax)
				putc(elm[3], fp);
		}
	}
}

int pngwrite(FILE *fp, const commonInfo *cinf, const char *dir, BOOL interl)
{
	int err;
	char ppngPath[MAXFILENAMELEN];
	static char *ppngArg[8] = {
		NULL,		/* 0: Tool Path */
		PAO_PNG,
		NULL,		/* 2: -p (maybe) */
		NULL, NULL };

	sprintf(ppngPath, "%s/%s", dir, PAO_PNG);
	ppngArg[0] = ppngPath;
	ppngArg[2] = interl ? "-p" : NULL;	/* Progressive */

	if ((fp = openWPipe(fp, (arglist)ppngArg, &err)) == NULL)
		return err;

	if (cinf->palette && cinf->palsteps > 0)
		pxo_write(fp, cinf);
	else
		png_write_f(fp, cinf);

	(void) fclose(fp);
	wait(0);	/* Don't forget */
	return 0;
}

int gifwrite(FILE *fp, const commonInfo *cinf, const char *dir, BOOL interl)
{
	int err;
	char pgifPath[MAXFILENAMELEN];
	static char *pgifArg[8] = {
		NULL,		/* 0: Tool Path */
		PXO_GIF,
		NULL,		/* 2: -i (maybe) */
		NULL, NULL };

	sprintf(pgifPath, "%s/%s", dir, PXO_GIF);
	pgifArg[0] = pgifPath;
	pgifArg[2] = interl ? "-i" : NULL;	/* Interlaced */

	if ((fp = openWPipe(fp, (arglist)pgifArg, &err)) == NULL)
		return err;

	pxo_write(fp, cinf);
	(void) fclose(fp);
	wait(0);	/* Don't forget */
	return 0;
}

int bmpwrite(FILE *fp, const commonInfo *cinf, const char *dir, unsigned char **planes)
{
	int err;
	char pgifPath[MAXFILENAMELEN];
	static char *pbmpArg[8] = {
		NULL,		/* 0: Tool Path */
		PXO_BMP,
		NULL, NULL };

	sprintf(pgifPath, "%s/%s", dir, PXO_BMP);
	pbmpArg[0] = pgifPath;

	if ((fp = openWPipe(fp, (arglist)pbmpArg, &err)) == NULL)
		return err;

	if (cinf->palette && cinf->palsteps > 0)
		pxo_write(fp, cinf);
	else
		ppmwrite(fp, cinf, planes);
	(void)fclose(fp);
	wait(0);	/* Don't forget */
	return 0;
}
