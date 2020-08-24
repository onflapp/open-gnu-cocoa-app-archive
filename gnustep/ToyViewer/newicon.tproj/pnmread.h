/*
	ppmread.h
	Ver.1.0		1995-04-28  T.Ogihara
	for pxo2bmp	2000-03-25  T.Ogihara
	for newicon	2002-01-17  T.Ogihara
 */

typedef struct {
	int		width, height;
	unsigned char	bits;
	unsigned char	numcolors;	/* color elements without alpha */
	char		*memo;
	unsigned char	*pixels[3];
} commonInfo;

void setVerbose(int flag);
commonInfo *pnmread(FILE *fin);
void freePnmInfo(commonInfo *info);
