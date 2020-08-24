/* png2pao.c
 *	is based on pngtopnm(2.31) by A. Lehmann & W. van Schaik.
 */

/*
** pngtopnm.c -
** read a Portable Network Graphics file and produce a portable anymap
**
** Copyright (C) 1995,1996 by Alexander Lehmann <alex@hal.rhein-main.de>
**                        and Willem van Schaik <gwillem@ntuvax.ntu.ac.sg>
**
** version 2.31 - July 1996
**
** Permission to use, copy, modify, and distribute this software and its
** documentation for any purpose and without fee is hereby granted, provided
** that the above copyright notice appear in all copies and that both that
** copyright notice and this permission notice appear in supporting
** documentation.  This software is provided "as is" without express or
** implied warranty.
**
** modeled after giftopnm by David Koblas and
** with lots of bits pasted from pnglib.txt by Guy Eric Schalnat
*/

/* pnglib forgot gamma correction for palette images, so we do it ourselves */

#include <stdio.h>
#include <stdlib.h>
#include "png.h"
#include "png2pao.h"

/* Global Data */
int verbose = NO;
int useBackground = YES;
int usePXO = YES;
float displaygamma = -1.0; /* display gamma */


static void print_usage(char *path)
{
	int b, x;

	for (b = 0, x = 0; path[x]; x++)
		if (path[x] == '/') b = x + 1;
	fprintf(stderr, "Usage: %s [Options] [pngfile]\n", &path[b]);
	fprintf(stderr, "Options:\n");
	fprintf(stderr, "    -v        verbose\n");
	fprintf(stderr, "    -t        do not use background color\n");
	fprintf(stderr, "    -g value  gamma value\n");
	fprintf(stderr, "    -A        do not use PXO (use PAO)\n");
	exit(1);
}


int main (int argc, char *argv[])
{
	int argn;

	for (argn = 1; argn < argc; argn++) {
		if (argv[argn][0] != '-' || argv[argn][1] == '\0')
			break;
		switch (argv[argn][1]) {
		case 'g':	/* gamma */
			if (++argn < argc)
				sscanf(argv[argn], "%f", &displaygamma);
			else
				print_usage(argv[0]);
			break;
		case 't':
			useBackground = NO;
			break;
		case 'v':	/* verbose */
			verbose = YES;
			break;
		case 'A':	/* use only PAO */
			usePXO = NO;
			break;
		default:
			print_usage(argv[0]);
			break;
		}
	}
	if (argn != argc && argv[argn][0] != '-') {
		if (freopen(argv[argn], "r", stdin) == NULL) {
			fprintf(stderr, "ERROR: Can't open: %s\n", argv[argn]);
			return 1;
		}
		++argn;
	}
	if (argn != argc)
		print_usage(argv[0]);

	convertpng(stdin);

	return 0;
}
