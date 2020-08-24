/*
	mag.h
		partially based on
			"CzView 2.20" by Y.Sasaki (1994) and
			"MAGLV 1.20" by H.Takada (1993).

	Ver.1.0   1995-04-29  T.Ogihara
	Ver.1.1   2001-04-18
*/

#define  MaxImageSize	1024
#define  sizeof_magHeader 32
#define  FlagBufMAX	  (MaxImageSize / 2)
#define  MAX_COMMENT	256

#ifndef  YES
# define  YES	1
# define  NO	0
#endif

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

typedef  short	Bool;

typedef struct {
	short	xbitwidth, yheight, xbytewidth;
	Bool	is256c, isDouble;
	long	flagAoffset;
	long	flagBoffset;
	long	flagBsize;
	long	pixeloffset;
	long	pixelsize;
	unsigned char	memo[MAX_COMMENT];
} magHeader;

extern Bool eucflag;

magHeader *loadMagHeader(FILE *, long *, int *);
void freeMagHeader(magHeader *);
int magDecode(FILE *, FILE *, magHeader *, long);
