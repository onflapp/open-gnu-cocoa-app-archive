/*
	bmp.h
		partially based on
			"bmptoppm" by DaviD W. Sanderson (1992) and
			"CzView 2.20" by Y.Sasaki (1994).

	Ver.1.0   1995-04-28  T.Ogihara
	pxo2bmp   2000-03-25  T.Ogihara
*/

#define  RED		0
#define  GREEN		1
#define  BLUE		2
#define  ALPHA		3
#define  MAX_COMMENT	256

#define  NoComp	0
#define  RLE8	1
#define  RLE4	2

#define  OS2	0x0c	/* 12 */
#define  WIN3	0x28	/* 40 */

typedef unsigned char	paltype[3];

typedef struct {
	int	width, height;
	short	xbytes;		/* (number of bytes)/line */
	short	palsteps;	/* colors of palette */
	unsigned char	bits;
	unsigned char	pixbits;	/* bits/pixel (mesh) */
	unsigned char	numcolors;	/* color elements without alpha */
	paltype	*palette;
	unsigned char *memo;
	unsigned char *pixels[4];
} commonInfo;

extern int verbose;

/* pxoread.c */
commonInfo *pxoread(FILE *fin);
void freePxoInfo(commonInfo *info);

/* bmpsave.c */
int saveBmpFromPBM(FILE *fp, commonInfo *cinf);
int saveBmpWithPalette(FILE *fp, commonInfo *cinf);
int saveBmpbmap(FILE *fp, commonInfo *cinf);
