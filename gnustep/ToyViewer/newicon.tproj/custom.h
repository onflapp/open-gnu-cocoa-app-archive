#include <Carbon/Carbon.h>
#include <stdio.h>

#ifndef __CUSTOM__ICON__
#define __CUSTOM__ICON__	1

#define  ThumbSIZE	128
#define  SmallSIZE	16
#define  LargeSIZE	32

typedef unsigned char  fourElements[4];

enum {
	c_MEMORY = -3,
	c_SIZE = -2,
	c_OPEN = -1,
	c_NoErr = 0
};

int readImage(FILE *fp);
void attachDirMark(void);
int allocIconHandle(IconFamilyHandle *ihandp);
OSErr setIconImages(IconFamilyHandle ihandle);

#endif /* __CUSTOM__ICON__ */
