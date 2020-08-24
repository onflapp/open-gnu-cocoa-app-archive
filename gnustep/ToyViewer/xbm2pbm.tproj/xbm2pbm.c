/*	xbm2pbm		Coded by T.Ogihara  1996-03-23		*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define  MAXBMLINE	256
#ifndef  MAXWidth
# define  MAXWidth	4096
#endif

static int readHeader(int *widp, int *heip, char *iname)
{
	int i, j, v, np = 0, lng = 0;
	char *p;
	char line[MAXBMLINE], feature[MAXBMLINE];

	*widp = *heip = 0;
	for ( ;  ; ) {
		if (fgets(line, MAXBMLINE, stdin) == NULL)
			return -1;
		if ((lng = strlen(line)) >= MAXBMLINE - 1)
			return -2;

		if (line[0] == 's') /* static ... */
			break;
		if (line[0] == '#') {
			i = 1;
			while (i < lng && line[i] <= ' ')
				i++;	/* skip spaces */
			while (i < lng && line[i] > ' ')
				i++;	/* skip "define" */
			while (i < lng && line[i] <= ' ')
				i++;	/* skip spaces */
			if (i >= lng)
				continue;
			for (j = 0; line[i] > ' '; i++, j++)
				feature[j] = line[i];
			feature[j] = 0;
			v = atoi(&line[i]);
			for (--j; j >= 0 && feature[j] != '_'; j--) ;
			if (j > 0) {
				p = &feature[j + 1];
				if (np <= 0) {
					for (np = 0; np < j; np++)
						iname[np] = feature[np];
					iname[np] = 0;
				}
			}else
				p = feature;
			if (strcmp(p, "width") == 0)
				*widp = v;
			else if (strcmp(p, "height") == 0)
				*heip = v;
		}else if (line[0] == 's')
			break;
	}
	if (strncmp(line, "static", 6) != 0)
		return -1;
	/* Read "static short ... = {" */
	for (i = 6; i < lng && line[i] <= ' '; i++)
		;	/* skip spaces */
	if (i >= lng)
		return -1;
	p = &line[i];
	if (strncmp(p, "short", 5) == 0)
		return 1;	/* Version 10 */
	else if (strncmp(p, "char", 4) == 0)
		return 0;	/* Version 11 */
	return -1;
}

#define  NOT_XDIGIT(x)	(hextable[x] & 0xff00)
static short hextable[256];
static unsigned char flipbits[256];
static int version10;

static void init_tables(int v10)
{
	int i, n, nr, m;

	for (i = 0; i < 256; i++)
		hextable[i] = 0x100;
	for (i = 0; i < 10; i++)
		hextable[(int)("0123456789"[i])] = i;
	for (i = 0; i < 6; i++)
		hextable[(int)("ABCDEF"[i])] = i + 10;
	for (i = 0; i < 6; i++)
		hextable[(int)("abcdef"[i])] = i + 10;
	for (n = nr = 0;  ; n++) {
		flipbits[n] = nr;
		if (n >= 255) break;
		for (i = 1; nr & (m = 0x100 >> i); i++)
			;
		nr = (nr & (0xff >> i)) | m;
	}
	version10 = v10;
}

static int readByte(int hline)	/* hline == 1: Heading of a line */
{
	int c, v;
	static int hasvalue = 0, nextvalue;

	if (version10 && !hline && hasvalue) {
		hasvalue = 0;
		return flipbits[nextvalue];
	}
	if (feof(stdin)) return 0;
	do {
		if ((c = getchar()) == EOF)
			return 0;
	}while (c != 'x' && c != 'X');
	for (v = 0;  ; ) {
		if ((c = getchar()) == EOF || NOT_XDIGIT(c))
			break;
		v = (v << 4) | hextable[c];
	}
	if (version10) {
		hasvalue = 1;
		nextvalue = (v >> 8) & 0xff;
	}
	return flipbits[v & 0xff];
}

static void convertBitmap(int width, int height, int v10)
{
	int x, y, v;
	int xbytes;

	init_tables(v10);
	xbytes = (width+7) >> 3;
	for (y = 0; y < height; y++) {
		v = readByte(1);
		for (x = 0;  ; v = readByte(0)) {
			putchar(v);
			if (++x >= xbytes) break;
		}
	}
}


int main(int argc, char **argv)
{
	int ver, rows, cols;
	char *fnp = "(stdin)";
	char imageName[80];

	if ( argc > 2 ) {
		fprintf(stderr, "%s [inputfile]\n", argv[0]);
		return 1;
	}

	if ( argc == 2 ) {
		fnp = argv[1];
		if (freopen(fnp, "r", stdin) == NULL) {
			fprintf(stderr, "Can't open %s\n", fnp);
			return 1;
		}
	}

	ver = readHeader(&cols, &rows, imageName);
	if (ver < 0 || cols <= 0 || cols >= MAXWidth
			|| rows <= 0 || rows >= MAXWidth) {
		fprintf(stderr, "Illegal format: %s\n", fnp);
		return 1;
	}
	printf("P4\n# %s%s\n%d %d\n",
		imageName, (ver ? " : X10" : ""), cols, rows);
	convertBitmap(cols, rows, ver);

	return 0;
}
