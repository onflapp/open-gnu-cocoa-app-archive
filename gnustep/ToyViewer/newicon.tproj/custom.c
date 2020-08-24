#include <Carbon/Carbon.h>
#include <stdio.h>
#include <string.h>
#include "custom.h"
#include "pnmread.h"
#include "utils.h"
#include "dirmark.h"

static Handle thumbDataH = NULL, thumbMaskH = NULL;
static Handle largeDataH = NULL, largeMaskH = NULL;
static Handle smallDataH = NULL, smallMaskH = NULL;
static int thumbDMx = 104, thumbDMy = 104;	// Position of Directory Mark

const int IconKinds = 4;
static const struct {
	OSType	ostyp;
	Size	rsize;
} family[8] = {
	{ 'ics#',    72 },  // kSmall1BitMask,  8 + 32*2: 32=16x2(2x8pixel)
//	{ 'ics8',   264 },  // kSmall8BitData,  8 + 256 : 256 = 16x16
	{ 'is32',   602 },  // kSmall32BitData, compressed? : not exact
	{ 'ICN#',   264 },  // kLarge1BitMask,  8 + 128*2: 128=32x4(4x8pixel)
//	{ 'icl8',  1032 },  // kLarge8BitData,  8 + 1024 : 1024 = 32x32
	{ 'il32',  2340 },  // kLarge32BitData, compressed? : not exact
//	{ 'it32', 36752 },  // kThumbnail32BitData, compressed? : not exact
//	{ 't8mk', 16392 }   // kThumbnail8BitMask,  8 + 16384 : 16384 = 128x128
};


static commonInfo *makeHalfSize(const commonInfo *info)
{
	commonInfo *half;
	int i, v, x, y, px;
	unsigned char *p, *q0, *q1;

	half = (commonInfo *)malloc(sizeof(commonInfo));
	half->width = info->width / 2;
	half->height = info->height / 2;
	if (half->width <= 0 || half->height <= 0) {
		(void)free((void *)info);
		return NULL;
	}
	half->numcolors = info->numcolors;
	half->bits = 8;
	half->memo = NULL;
	v = half->width * half->height;
	p = (unsigned char *)malloc(v * half->numcolors);
	for (i = 0; i < half->numcolors; i++)
		half->pixels[i] = p + v * i;

	for (i = 0; i < half->numcolors; i++) {
		p = half->pixels[i];
		for (y = 0; y < half->height; y++) {
			q0 = info->pixels[i] + y * info->width * 2;
			q1 = q0 + info->width;
			for (x = 0; x < half->width; x++) {
				px = *q0++ + *q1++;
				*p++ = (px + *q0++ + *q1++ + 2) / 4;
			}
		}
	}
	return half;
}

static int makeThumbIcon(const commonInfo *info)
{
	const int thumbDataBytes = ThumbSIZE * ThumbSIZE * 4;
	const int thumbMaskBytes = ThumbSIZE * ThumbSIZE;
	int x, y, c, v;
	int xstart, ystart, xam, yam, yline, index;
	unsigned char *thumbMask;
	fourElements *thumbData;

	thumbDataH = NewHandle(thumbDataBytes);
	thumbMaskH = NewHandle(thumbMaskBytes);
	if (thumbDataH == NULL || thumbMaskH == NULL)
		return c_MEMORY;

	thumbData = (fourElements *)*thumbDataH;
	thumbMask = (unsigned char *)*thumbMaskH;
	bzero((void *)thumbData, thumbDataBytes);
	bzero((void *)thumbMask, thumbMaskBytes);

	xstart = (ThumbSIZE - info->width) / 2;
	ystart = (ThumbSIZE - info->height) / 2;
	thumbDMx = xstart + info->width;	// Position of Directory Mark
	thumbDMy = ystart + info->height;
	index = 0;
	if (info->numcolors == 1)
	    for (y = ystart, yam = info->height; yam > 0; y++, yam--) {
		yline = y * ThumbSIZE;
		for (x = xstart, xam = info->width; xam > 0; x++, xam--) {
			v = info->pixels[0][index++];
			for (c = 1; c <= 3; c++)
			    thumbData[yline + x][c] = v;
			thumbMask[yline + x] = 0xff;
		}
	    }
	else
	    for (y = ystart, yam = info->height; yam > 0; y++, yam--) {
		yline = y * ThumbSIZE;
		for (x = xstart, xam = info->width; xam > 0; x++, xam--) {
			for (c = 0; c < 3; c++)
			    thumbData[yline + x][c+1] = info->pixels[c][index];
			index++;
			thumbMask[yline + x] = 0xff;
		}
	    }

	return c_NoErr;
}

static commonInfo *makeLargeIcon(const commonInfo *orig)
{
	const int largeDataBytes = LargeSIZE * LargeSIZE * 4;
	const int largeMaskBytes = LargeSIZE * LargeSIZE / 4;
	int x, y, c;
	int xstart, ystart, xam, yam, yline, index;
	unsigned char *largeMask;
	fourElements *largeData;
	commonInfo *half, *info;
	UInt32 v, *pp;

	if ((half = makeHalfSize(orig)) == NULL)
		return NULL;
	info = makeHalfSize(half);
	freePnmInfo(half);
	if (info == NULL)
		return NULL;

	largeDataH = NewHandle(largeDataBytes);
	largeMaskH = NewHandle(largeMaskBytes);
	if (largeDataH == NULL || largeMaskH == NULL) {
		freePnmInfo(info);
		return NULL;
	}
	largeData = (fourElements *)*largeDataH;
	largeMask = (unsigned char *)*largeMaskH;
	bzero((void *)largeData, largeDataBytes);
	bzero((void *)largeMask, largeMaskBytes);

	xstart = (LargeSIZE - info->width) / 2;
	ystart = (LargeSIZE - info->height) / 2;
	index = 0;
	if (info->numcolors == 1)
	    for (y = ystart, yam = info->height; yam > 0; y++, yam--) {
		yline = y * LargeSIZE;
		for (x = xstart, xam = info->width; xam > 0; x++, xam--) {
			v = info->pixels[0][index++];
			for (c = 1; c <= 3; c++)
			    largeData[yline + x][c] = v;
		}
	    }
	else
	    for (y = ystart, yam = info->height; yam > 0; y++, yam--) {
		yline = y * LargeSIZE;
		for (x = xstart, xam = info->width; xam > 0; x++, xam--) {
			for (c = 0; c < 3; c++)
			    largeData[yline + x][c+1] = info->pixels[c][index];
			index++;
		}
	    }

	v = ~(~0UL >> info->width);
	v >>= xstart;
	pp = (UInt32 *)largeMask + ystart;
	for (y = ystart, yam = info->height; yam > 0; y++, yam--)
		*pp++ = v & ((y & 1) ? 0xaaaaaaaa : 0x55555555);
	pp = (UInt32 *)(largeMask + largeMaskBytes/2) + ystart;
	for (y = ystart, yam = info->height; yam > 0; y++, yam--)
		*pp++ = v;

	return info;
}

static int makeSmallIcon(const commonInfo *orig)
{
	const int smallDataBytes = SmallSIZE * SmallSIZE * 4;
	const int smallMaskBytes = SmallSIZE * SmallSIZE / 4;
	int x, y, c;
	int xstart, ystart, xam, yam, yline, index;
	unsigned char *smallMask;
	UInt16 v, *pp;
	fourElements *smallData;
	commonInfo *info;

	if ((info = makeHalfSize(orig)) == NULL)
		return c_MEMORY;

	smallDataH = NewHandle(smallDataBytes);
	smallMaskH = NewHandle(smallMaskBytes);
	if (smallDataH == NULL || smallMaskH == NULL) {
		freePnmInfo(info);
		return NULL;
	}
	smallData = (fourElements *)*smallDataH;
	smallMask = (unsigned char *)*smallMaskH;
	bzero((void *)smallData, smallDataBytes);
	bzero((void *)smallMask, smallMaskBytes);

	xstart = (SmallSIZE - info->width) / 2;
	ystart = (SmallSIZE - info->height) / 2;
	index = 0;
	if (info->numcolors == 1)
	    for (y = ystart, yam = info->height; yam > 0; y++, yam--) {
		yline = y * SmallSIZE;
		for (x = xstart, xam = info->width; xam > 0; x++, xam--) {
			v = info->pixels[0][index++];
			for (c = 1; c <= 3; c++)
			    smallData[yline + x][c] = v;
		}
	    }
	else
	    for (y = ystart, yam = info->height; yam > 0; y++, yam--) {
		yline = y * SmallSIZE;
		for (x = xstart, xam = info->width; xam > 0; x++, xam--) {
			for (c = 0; c < 3; c++)
			    smallData[yline + x][c+1] = info->pixels[c][index];
			index++;
		}
	    }

	v = (0xffff0000UL >> info->width) & 0xffff;
	v >>= xstart;
	pp = (UInt16 *)smallMask + ystart;
	for (y = ystart, yam = info->height; yam > 0; y++, yam--)
		*pp++ = v & ((y & 1) ? 0xaaaa : 0x5555);
	pp = (UInt16 *)(smallMask + smallMaskBytes/2) + ystart;
	for (y = ystart, yam = info->height; yam > 0; y++, yam--)
		*pp++ = v;

	freePnmInfo(info);
	return c_NoErr;
}

int readImage(FILE *fp)
{
	commonInfo *info, *lginfo;
	int err;

	if ((info = pnmread(fp)) == NULL)
		return c_OPEN;	/* ERROR */
	if (info->width > ThumbSIZE || info->height > ThumbSIZE) {
		freePnmInfo(info);
		return c_SIZE;
	}
	if ((err = makeThumbIcon(info)) != c_NoErr) {
		freePnmInfo(info);
		return err;
	}
	lginfo = makeLargeIcon(info);
	freePnmInfo(info);
	if (lginfo == NULL)
		return c_MEMORY;
	err = makeSmallIcon(lginfo);
	freePnmInfo(lginfo);
	return err;
}

void attachDirMark(void)
{
	if (thumbDMx > ThumbSIZE - DM_SIZE)
		thumbDMx = ThumbSIZE - DM_SIZE;
	thumbDMx &= 0xf8;
	if (thumbDMy > ThumbSIZE - DM_SIZE)
		thumbDMy = ThumbSIZE - DM_SIZE;
	thumbDMy &= 0xf8;
	if (thumbDMx < DM_SIZE * 2 || thumbDMy < DM_SIZE * 2)
		return;	// too small icon
	attachDirMarkToThumb((fourElements *)*thumbDataH,
		(unsigned char *)*thumbMaskH, thumbDMx, thumbDMy);
	attachDirMarkToLarge((fourElements *)*largeDataH,
		(UInt32 *)*largeMaskH, thumbDMx >> 2, thumbDMy >> 2);
	attachDirMarkToSmall((fourElements *)*smallDataH,
		(UInt16 *)*smallMaskH, thumbDMx >> 3, thumbDMy >> 3);
}

int allocIconHandle(IconFamilyHandle *ihandp)
{
	int i, all;
	unsigned char *p;
	IconFamilyHandle ihandle;
	IconFamilyPtr pIconFamily;
	IconFamilyElement *pElement;

	all = 8;
	for (i = 0; i < IconKinds; i++)
		all += family[i].rsize;
	ihandle = (IconFamilyHandle)NewHandle(all);
	if (ihandle == NULL)
		return c_MEMORY;
	*ihandp = ihandle;
	pIconFamily = *ihandle;
	pIconFamily->resourceType = kIconFamilyType; // ('icns')
	pIconFamily->resourceSize = all;
	p = (unsigned char *)(pElement = pIconFamily->elements);
	for (i = 0; i < IconKinds; i++) {
		pElement->elementType = family[i].ostyp;
		pElement->elementSize = family[i].rsize;
		pElement = (IconFamilyElement *)(p += family[i].rsize);
	}
	/* Because SetIconFamilyData() does not work well
	   when IconFamily is incomplete.  Bug?  (OS X 10.1.2) */
	return c_NoErr;
}

#ifdef DEBUG
static void dumpRsrc(const char *title, unsigned char *p, int n)
{
	int i;

	fprintf(stderr, "*** %s ***\n", title);
	for (i = 0; i < n; ) {
		fprintf(stderr, "%02x", *p++);
		if ((++i % 32) == 0)
			fputc('\n', stderr);
		else if ((i % 4) == 0)
			fputc(' ', stderr);
	}
}
#endif

OSErr setIconImages(IconFamilyHandle ihandle)
{
	OSErr err = 0;

	err = SetIconFamilyData(ihandle, kSmall1BitMask, smallMaskH);
	err = SetIconFamilyData(ihandle, kSmall32BitData, smallDataH);
#ifdef DEBUG
	dumpRsrc("Small Mask", *smallMaskH, 64);
	dumpRsrc("Large Mask", *largeMaskH, 256);
#endif
	err = SetIconFamilyData(ihandle, kLarge1BitMask, largeMaskH);
	err = SetIconFamilyData(ihandle, kLarge32BitData, largeDataH);
	err = SetIconFamilyData(ihandle, kThumbnail8BitMask, thumbMaskH);
	err = SetIconFamilyData(ihandle, kThumbnail32BitData, thumbDataH);
	DisposeHandle(smallDataH);
	DisposeHandle(smallMaskH);
	DisposeHandle(largeDataH);
	DisposeHandle(largeMaskH);
	DisposeHandle(thumbDataH);
	DisposeHandle(thumbMaskH);
	return err;
}
