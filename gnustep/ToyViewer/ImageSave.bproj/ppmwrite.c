#include <stdio.h>
#include <stdlib.h>
#include <sys/file.h>
#include <sys/wait.h>
#include <libc.h>
#include <objc/objc.h>
#include "../ppm.h"
#include "../common.h"
#include "../strfunc.h"
#include "J2kParams.h"
#include "save.h"

FILE *openWPipe(FILE *fp, arglist list, int *err)
{
	int pfd[2];
	int pid;

	/* if (*err != 0) then fork() didn't called successfully */
	*err = 0;
	if (list == NULL || access(list[0], X_OK) < 0) {
		*err = Err_FLT_EXEC;
		return NULL;	/* not executable */
	}
	(void)pipe(pfd);
	if ((pid = fork()) == 0) { /* child process */
		(void)close(0);
		dup(pfd[0]);
		if (fp != NULL) {
		    (void)close(1);
		    dup(fileno(fp));
		    (void)fclose(fp);
		}
		(void)close(pfd[0]);
		(void)close(pfd[1]);
		execv(list[0], (char *const *)&list[1]);
		exit(1);	/* Error */
	}else if (pid < 0) {	/* ERROR */
		*err = Err_FLT_EXEC;
		(void)close(pfd[0]);
		(void)close(pfd[1]);
		if (fp != NULL)
		    (void)fclose(fp);
		return NULL;
	}
	(void)close(pfd[0]);
	if (fp != NULL)
	    (void)fclose(fp);
	return fdopen(pfd[1], "w");
}


int ppmwrite(FILE *fp, const commonInfo *cinf, unsigned char **planes)
{
	int max = 255, sft = 0, n;
	int r, g, b, a;

	switch (cinf->bits) {
	case 1: max = 1;  sft = 7;  break;
	case 2: max = 3;  sft = 6;  break;
	case 4: max = 15;  sft = 4;  break;
	case 8: max = 255;  sft = 0;  break;
	}

	if (cinf->numcolors > 1) { /* color */
		/* PPM Binary */
		fprintf(fp, "P6\n# %s\n%d %d %d\n",
			key_comm(cinf), cinf->width, cinf->height, max);
		n = cinf->width * cinf->height;
		if (sft)
			while (n-- > 0) {
				(void) getPixel(&r, &g, &b, &a);
				putc(r >> sft, fp);
				putc(g >> sft, fp);
				putc(b >> sft, fp);
			}
		else
			while (n-- > 0) {
				(void) getPixel(&r, &g, &b, &a);
				putc(r, fp);
				putc(g, fp);
				putc(b, fp);
			}
	}else if (max == 1) { /* Bi-Level */
		/* PBM Binary */
		int x = (cinf->width + 7) >> 3;
		int y = cinf->height;
		unsigned char *p = planes[0];
		fprintf(fp, "P4\n# %s\n%d %d\n",
			key_comm(cinf), cinf->width, cinf->height);
		while (y-- > 0) {
			if (cinf->cspace == CS_White)
				for (n = 0; n < x; n++)
					putc(p[n] ^ 0xff, fp);
			else
				for (n = 0; n < x; n++)
					putc(p[n], fp);
			p += cinf->xbytes;
		}
	}else { /* Gray */
		/* PGM Binary */
		fprintf(fp, "P5\n# %s\n%d %d %d\n",
			key_comm(cinf), cinf->width, cinf->height, max);
		n = cinf->width * cinf->height;
		if (sft)
			while (n-- > 0) {
				(void) getPixel(&r, &g, &b, &a);
				putc(r >> sft, fp);
			}
		else
			while (n-- > 0) {
				(void) getPixel(&r, &g, &b, &a);
				putc(r, fp);
			}
	}
	return 0;
}


int jpgwrite(FILE *fp, const commonInfo *cinf, const char *dir,
		int quality, BOOL progressive)
{
	int r, g, b, a, n, argp, err;
	char cjpegPath[MAXFILENAMELEN];
	char cjpegQuality[16];
	char comm_text[MAX_COMMENT];
	const char *cmp;
	static char *cjpegArg[10] = {
		NULL,		/* 0: Tool Path */
		CJPEG,
		"-quality",
		NULL,		/* 3: Quality (0-100) */
		"-optimize",
		NULL,		/* 5: -grayscale (maybe) */
		NULL,		/* 6: -progressive (maybe) */
		NULL,		/* 7: -comment (maybe) */
		NULL, NULL };

	sprintf(cjpegPath, "%s/%s", dir, CJPEG);
	cjpegArg[0] = cjpegPath;
	sprintf(cjpegQuality, "%d", quality);
	cjpegArg[3] = cjpegQuality;
	argp = 5;
	if (cinf->numcolors == 1) /* mono */
		cjpegArg[argp++] = "-grayscale";
	if (progressive)
		cjpegArg[argp++] = "-progressive";
	if ((cmp = begin_comm(cinf->memo, YES)) != NULL) {
		int i, cc;
		for (i = 0; cmp[i]; i++) {
			if ((cc = cmp[i] & 0xff) < ' ') cc = ' ';
			comm_text[i] = cc;
		}
		comm_text[i] = 0;
		cjpegArg[argp++] = "-comment";
		cjpegArg[argp++] = comm_text;
	}
	cjpegArg[argp] = NULL;

	if ((fp = openWPipe(fp, (arglist)cjpegArg, &err)) == NULL)
		return err;

	n = cinf->width * cinf->height;
	if (cinf->numcolors > 1) { /* color */
		/* PPM Binary */
		fprintf(fp, "P6\n# %s\n%d %d 255\n",
			key_comm(cinf), cinf->width, cinf->height);
		while (n-- > 0) {
			(void) getPixel(&r, &g, &b, &a);
			putc(r, fp);
			putc(g, fp);
			putc(b, fp);
		}
	}else { /* Gray */
		/* PGM Binary */
		fprintf(fp, "P5\n# %s\n%d %d 255\n",
			key_comm(cinf), cinf->width, cinf->height);
		while (n-- > 0) {
			(void) getPixel(&r, &g, &b, &a);
			putc(r, fp);
		}
	}
	(void)fclose(fp);
	wait(0);	/* Don't forget */
	return 0;
}

int j2kwrite(FILE *fp, const commonInfo *cinf, const char *dir,
		int format, float quality, int progressive)
{
	int r, g, b, a, n, argp, err;
	char jasperPath[MAXFILENAMELEN];
	char jasperQuality[16];
	char jasperProg[16];
	static const char *progop[] = {
		"lrcp", "rlcp", "cprl"
	};
	static char *jasperArg[12] = {
		NULL,		/* 0: Tool Path */
		PNM_J2K,
		"-t",
		"pnm",
		"-T",
		NULL,		/* 5: Output Format (jp2/jpc) */
		NULL,		/* 6: -O */
		NULL,		/* 7: prg=??? */
		NULL,		/* 8: -O (maybe) */
		NULL,		/* 9: rate=0.15 (maybe) */
		NULL, NULL };

	sprintf(jasperPath, "%s/%s", dir, PNM_J2K);
	jasperArg[0] = jasperPath;
	jasperArg[5] = (format == Tag_jp2) ? "jp2" : "jpc";
	/* progressive */
	if (!TagIsLegalProg(progressive))
		progressive = Tag_rate; // default
	sprintf(jasperProg, "prg=%s", progop[progressive]);
	jasperArg[6] = "-O";
	jasperArg[7] = jasperProg;
	argp = 8;
	if (quality < 1.0 && quality > 0.0) {
		sprintf(jasperQuality, "rate=%f", quality);
		jasperArg[argp++] = "-O";
		jasperArg[argp++] = jasperQuality;
	}

	jasperArg[argp] = NULL;

	if ((fp = openWPipe(fp, (arglist)jasperArg, &err)) == NULL)
		return err;

	n = cinf->width * cinf->height;
	if (cinf->numcolors > 1) { /* color */
		/* PPM Binary */
		fprintf(fp, "P6\n# %s\n%d %d 255\n",
			key_comm(cinf), cinf->width, cinf->height);
		while (n-- > 0) {
			(void) getPixel(&r, &g, &b, &a);
			putc(r, fp);
			putc(g, fp);
			putc(b, fp);
		}
	}else { /* Gray */
		/* PGM Binary */
		fprintf(fp, "P5\n# %s\n%d %d 255\n",
			key_comm(cinf), cinf->width, cinf->height);
		while (n-- > 0) {
			(void) getPixel(&r, &g, &b, &a);
			putc(r, fp);
		}
	}
	(void)fclose(fp);
	wait(0);	/* Don't forget */
	return 0;
}

int jbigwrite(FILE *fp, const commonInfo *cinf, const char *map, const char *dir)
{
	int x, y, xb, xbytes, neg = 0, err = 0;
	char jbigPath[MAXFILENAMELEN];
	const unsigned char *pp, *pmap = NULL;
	static char *jbigArg[4] = {
		NULL,		/* 0: Tool Path */
		PBM_JBIG,
		NULL };

	sprintf(jbigPath, "%s/%s", dir, PBM_JBIG);
	jbigArg[0] = jbigPath;

	if ((fp = openWPipe(fp, (arglist)jbigArg, &err)) == NULL)
		return err;

	xbytes = xb = (cinf->width + 7) >> 3;
	if (cinf->alpha || cinf->bits != 1) {
		pmap = pp = allocBilevelMap(cinf);
		if (!pp) {
			err = Err_MEMORY;
			goto EXIT;
		}
	}else {
		pp = map;
		xbytes = cinf->xbytes;
		neg = (cinf->cspace == CS_White);
	}
	fprintf(fp, "P4\n# %s\n%d %d\n",
		key_comm(cinf), cinf->width, cinf->height);
	for (y = 0; y < cinf->height; y++) {
		if (neg)
			for (x = 0; x < xb; x++)
				putc(*pp++ ^ 0xff, fp);
		else
			for (x = 0; x < xb; x++)
				putc(*pp++, fp);
		for ( ; x < xbytes; x++) ++pp;
	}
EXIT:
	(void)fclose(fp);
	wait(0);	/* Don't forget */
	if (pmap) free((void *)pmap);
	return err;
}

unsigned char *allocBilevelMap(const commonInfo *cinf)
{
	unsigned char *pp, *q;
	int x, y, val, mask;
	int r, g, b, a;
	static unsigned short pattern[4][4]= {
		{ 102, 153, 102, 153 },
		{ 204,  51, 204,  51 },
		{ 102, 153, 102, 153 },
		{ 204,  51, 204,  51 } };

	pp = (unsigned char *)malloc(((cinf->width + 7) >> 3) * cinf->height);
	if (!pp) return NULL;
	q = pp;
	val = 0;
	mask = 0x80;
	x = cinf->width;
	for (y = 0; y < cinf->height; y++) {
		for (x = cinf->width; x > 0; ) {
			(void) getPixel(&r, &g, &b, &a);
			if (pattern[x & 3][y & 3] > r) val |= mask;
			--x;
			if (!(mask >>= 1) || x <= 0) {
				*q++ = val;
				val = 0;
				mask = 0x80;
			}
		}
	}
	return pp;
}

int customIconWrite(const commonInfo *cinf, unsigned char *map[],
	const char *dir, const char *target)
{
	FILE *fp;
	int n, argp, err;
	const char *rr, *gg, *bb;
	unsigned char nwiconPath[MAXFILENAMELEN];
	static const char *nwiconArg[8] = {
		NULL,		/* 0: Tool Path */
		NEWICON,
		"-p",
		"-",
		"-o",
		NULL,		/* 5: target filename */
		NULL, NULL };

	if (access(target, W_OK) < 0)
		return Err_ACCESS;

	sprintf(nwiconPath, "%s/%s", dir, NEWICON);
	nwiconArg[0] = nwiconPath;
	argp = 5;
	nwiconArg[argp++] = target;
	nwiconArg[argp] = NULL;

	if ((fp = openWPipe(NULL, (arglist)nwiconArg, &err)) == NULL)
		return err;

	n = cinf->width * cinf->height;
	if (cinf->numcolors > 1) { /* color */
		/* PPM Binary */
		fprintf(fp, "P6 %d %d 255\n", cinf->width, cinf->height);
		rr = map[0];
		gg = map[1];
		bb = map[2];
		while (n-- > 0) {
			putc(*rr++, fp);
			putc(*gg++, fp);
			putc(*bb++, fp);
		}
	}else { /* Gray */
		/* PGM Binary */
		fprintf(fp, "P5 %d %d 255\n", cinf->width, cinf->height);
		rr = map[0];
		while (n-- > 0)
			putc(*rr++, fp);
	}
	(void)fclose(fp);
	wait(0);	/* Don't forget */
	return 0;
}

int customIconRemove(const char *dir, const char *target)
{
	FILE *fp;
	int argp, err;
	unsigned char nwiconPath[MAXFILENAMELEN];
	static const char *nwiconArg[8] = {
		NULL,		/* 0: Tool Path */
		NEWICON,
		"-d",
		"-o",
		NULL,		/* 4: target filename */
		NULL, NULL };

	if (access(target, W_OK) < 0)
		return Err_ACCESS;

	sprintf(nwiconPath, "%s/%s", dir, NEWICON);
	nwiconArg[0] = nwiconPath;
	argp = 4;
	nwiconArg[argp++] = target;
	nwiconArg[argp] = NULL;

	if ((fp = openWPipe(NULL, (arglist)nwiconArg, &err)) == NULL)
		return err;
	wait(0);	/* Don't forget */
	(void)fclose(fp);
	return 0;
}
