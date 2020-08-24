#include "common.h"

int initGetPixel(const commonInfo *cinf);
void resetPixel(refmap, int);
void compositeColors(int clr[], const int bkg[], int a);
int getPixel(int *, int *, int *, int *);
int getPixelA(int *);
int getPixelK(int *);
int hadAlpha(void);
int getPalPixel(int *, int *, int *);
int mapping(int, int, int);
int getBestColor(int r, int g, int b);
void convCMYKtoRGB(int width, int kkx, unsigned char **planes);
