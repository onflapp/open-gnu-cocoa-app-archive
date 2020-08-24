/*
	bmp.h
		partially based on
			"bmptoppm" by DaviD W. Sanderson (1992) and
			"CzView 2.20" by Y.Sasaki (1994).

	Ver.1.0   1995-04-28  T.Ogihara
*/

#include  <stdio.h>
//#include  <libc.h> // Linux only ??

#define  Err_OPEN	1
#define  Err_FORMAT	2
#define  Err_MEMORY	3
#define  Err_SHORT	4
#define  Err_ILLG	5
#define  Err_IMPLEMENT	6
#define  Err_SAVE	7
#define  Err_SAV_IMPL	8
#define  Err_EPS_IMPL	9
#define  Err_EPS_ONLY	10
#define  Err_OPR_IMPL	11
#define  Err_NOFILE	12
#define  Err_FLT_EXEC	13

#define  RED	0
#define  GREEN	1
#define  BLUE	2
#define  ALPHA	3
#define  FIXcount	256
#define  MAXPLANE	5

#define  NoComp	0
#define  RLE8	1
#define  RLE4	2

#define  OS2	0x0c	/* 12 */
#define  WIN3	0x28	/* 40 */
#define  RLE8	1
#define  RLE4	2
#define  MAXWidth	4096	/* 画像の横幅の想定最大値 */

#ifndef YES
# define  YES	1
# define  NO	0
#endif

typedef unsigned char	paltype[3];

typedef struct {
	int	x, y;
	char	type;  /* OS2 / WIN3 */
	short	bits;  /* 1: 8dot/byte   4: 2dot/byte
			  8: 1dot/byte  24: 1dot/3byte */
	int	xpm, ypm;  /* 縦横比 */
	int	comp;	   /* 圧縮方式 */
	int	colors;    /* パレットの色数 */
	long	bitoffset; /* イメージの開始位置 */	
	paltype	*palette;
} bmpHeader;

bmpHeader *loadBmpHeader(FILE *, int *);
void freeBmpHeader(bmpHeader *);
int bmpGetImage(FILE *, bmpHeader *, unsigned char **);
