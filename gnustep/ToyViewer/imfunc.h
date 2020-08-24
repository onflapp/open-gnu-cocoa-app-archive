/*
 *  imfunc.h
 *  ToyViewer
 */

#ifndef _IM_FUNC_h_
#define _IM_FUNC_h_

#include "common.h"

int byte_length(int bits, int width);
int optimalBits(unsigned char *, int);
int howManyBits(paltype *, int);
BOOL isGray(paltype *, int);
int allocImage(unsigned char **, int, int, int, int);
void expandImage(unsigned char **,
	unsigned char *, paltype const *, int, int, BOOL, int);
void packImage(unsigned char *, unsigned char *, int, int);
void packWorkingImage(const commonInfo *, int, unsigned char **, unsigned char **);
paltype *copyPalette(paltype *, int);

#endif /* _IM_FUNC_h_ */
