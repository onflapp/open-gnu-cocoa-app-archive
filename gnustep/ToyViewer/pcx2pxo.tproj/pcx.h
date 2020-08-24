/*
	pcx.h
		partially based on "pcxtoppm.c" by Michael Davidson (1990).

	Ver.1.0  1995-05-02  T.Ogihara
	ver.2.0  1997-08-25  for Full Color	by T.Ogihara
*/

#include  <stdio.h>
//#include  <libc.h> //Linux only

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
#define  MAXWidth	4096	/* MAX width of images */
#define  MAX_COMMENT	256
#define	 MAXFILENAMELEN	512

#ifndef YES
# define  YES	1
# define  NO	0
#endif

#define	 pcxMAGIC	0x0a	/* Magic number */
#define	 sizeof_pcxHeader  128
#define	 hasPALETTE	0x0c
#define  numPALETTE	256

typedef unsigned char	paltype[3];
typedef int	Boolean;

typedef struct {
	unsigned short	x, y;
	unsigned char	version, comp;	   /* version, compression */
	unsigned char	bits;	/* 1: 8dots/byte  4: 2dots/byte  8: 1dot/byte */
	unsigned char	planes;	/* Number of planes */
	short	xbytes;		/* bytes/line */
	short	xpm, ypm;	/* ratio x:y */
	short	pinfo;		/* palette info. */
	paltype	*palette;
	unsigned char	memo[MAX_COMMENT];
} pcxHeader;

pcxHeader *loadPcxHeader(FILE *, int *);
void freePcxHeader(pcxHeader *);
int pcxGetImage(FILE *, FILE *, pcxHeader *);

int howManyBits(paltype *pal, int n);
Boolean isGray(paltype *pal, int n);
