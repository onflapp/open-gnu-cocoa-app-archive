/*
	pao2png
		coded by Takeshi Ogihara
	-----------------------------------------------
	pao2png is partially based on tiff2png (C) 1996
		by Willem van Schaik, Singapore
	-----------------------------------------------
	pao2png  Ver. 1.1  1997-12-26  For libpng 0.96  by T.Ogihara
 */

/*
** tiff2png.c - converts a Tagged Image File to a Portable Network Graphics file
**
** Copyright (C) 1996 by Willem van Schaik, Singapore
**                       <gwillem@ntuvax.ntu.ac.sg>
**
** version 0.6 - May 1996
**
** Lots of material was stolen from libtiff, tifftopnm, pnmtopng, which
** programs had also done a fair amount of "borrowing", so the credit for
** this program goes besides the author also to:
**         Sam Leffler
**         Jef Poskanzer
**         Alexander Lehmann
**         Patrick Naughton
**         Marcel Wijkstra
**
** Permission to use, copy, modify, and distribute this software and its
** documentation for any purpose and without fee is hereby granted,
** provided that the above copyright notice appear in all copies and that
** both that copyright notice and this permission notice appear in
** supporting documentation.
**
** This file is provided AS IS with no warranties of any kind.  The author
** shall have no liability with respect to the infringement of copyrights,
** trade secrets or any patents by this file or any part thereof.  In no
** event will the author be liable for any lost revenue or profits or
** other special, indirect and consequential damages.
*/

#ifndef YES
#define YES 1
#endif
#ifndef NO
#define NO 0
#endif
#ifndef NONE
#define NONE 0
#endif
#define MAXCOLORS	256
#define MAX_COMMENT	256

extern int verbose;
extern int progressive;
extern float gamma_param;

void read_palette(FILE *fp, int cols, int transp);
void open_png(FILE *png, int cols, int rows, int mval, int pnum);
void close_png(void);
void write_png(FILE *fp, char *comm);
void paoread(FILE *fin, FILE *fout);
