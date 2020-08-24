#import "ToyWin.h"
#import <AppKit/NSApplication.h>
#import <AppKit/NSImage.h>
#import <AppKit/NSBitmapImageRep.h>
#import <AppKit/NSEPSImageRep.h>
#import <AppKit/NSControl.h>
#import <Foundation/NSBundle.h>	/* LocalizedString */
#import "NSStringAppended.h"
#import <AppKit/NSPanel.h>
#import <stdio.h>
#import <stdlib.h>
#import <string.h>
//#import <libc.h>
#import <time.h>
#import "ToyView.h"
#import "TVController.h"
#import "ImageSave.bproj/TVSavePanel.h" //GNUstep !!!!
#import "ColorSpaceCtrl.h"
#import "ColorMap.h"
#import "common.h"
#import "imfunc.h"
#import "getpixel.h"

#define  BINFixedLength		224
#define  MAXEPSLEN		512

@implementation ToyWin (Saving)

static void wrFixedLength(NSMutableData *stream,
	const unsigned char *plane, int length,
	const unsigned char *alp, int oneisblack)
{
	int	n, cc;
	int	idx = 0;
	char	buf[BINFixedLength + 8];
	static const char hex[] = "0123456789abcdef";

	for (n = 0; n < length; n++) {
		cc = oneisblack ? ~plane[n] : plane[n];
		if (alp)
			cc |= ~alp[n];
		cc &= 0xff;
		buf[idx++] = hex[cc >> 4]; 
		buf[idx++] = hex[cc & 0x0f];
		if (idx >= BINFixedLength) {
			buf[idx++] = '\n';
			buf[idx] = 0;
			[stream appendBytes: buf length: idx];
			idx = 0;
		}
	}
	if (idx) {
		buf[idx++] = '\n';
		buf[idx] = 0;
		[stream appendBytes: buf length: idx];
	}
}

/* Local Method */
/* ...... Don't call this method when (cinf->alpha && !cinf->isplanar) */
- (NSMutableData *) writeBitmapAsEPS:(unsigned char **)map info:(commonInfo *)cinf
{
	const char *p, *q;
	int	cc, i, bwid, buflen;
	time_t	tt;
	NSMutableData *stream;
	char buf[MAXEPSLEN];

	stream = [NSMutableData dataWithCapacity: 0];
	p = "%!PS-Adobe-2.0 EPSF-2.0\n%%Title: ";
	[stream appendBytes: p length: strlen(p)];
	for (p = q = [[self filename] fileSystemRepresentation]; *p; p++)
		if (*p == '/') q = p + 1;
	for (i = 0, p = q; *p; p++, i++) {
		if ((cc = *p & 0xff) <= ' ' || cc == '(' || cc == ')')
			break;
		buf[i] = cc;
	}
	buf[i] = 0;
	[stream appendBytes: buf length: i];
	(void)time(&tt);
	sprintf(buf, "\n%s\n%s%s",
		"%%Creator: ToyViewer", "%%CreationDate: ", ctime(&tt));
	[stream appendBytes: buf length: strlen(buf)];
	sprintf(buf, "%s\n%s 0 0 %d %d\n%s\n\n",
		"%%DocumentFonts: (atend)", "%%BoundingBox:",
		cinf->width, cinf->height,
		"%%EndComments");
	[stream appendBytes: buf length: strlen(buf)];

	bwid = byte_length(cinf->bits, cinf->width);
	buflen = bwid;
	if (cinf->numcolors == 1) {
		sprintf(buf, "/pictstr %d string def\n", bwid);
		[stream appendBytes: buf length: strlen(buf)];
	}else if (!cinf->isplanar) { /* mesh */
		buflen = byte_length(cinf->bits, cinf->width * 3);
		sprintf(buf, "/pictstr %d string def\n", buflen);
		[stream appendBytes: buf length: strlen(buf)];
	}else {
		sprintf(buf, "/pictstr %d string def\n", bwid * 3);
		[stream appendBytes: buf length: strlen(buf)];
		for (i = 0; i < 3; i++) {
		    sprintf(buf, "/subStr%d pictstr %d %d getinterval def\n",
			i, bwid * i, bwid);
			[stream appendBytes: buf length: strlen(buf)];
		}
	}
	sprintf(buf, "gsave\n0 0 translate\n%d %d %d [1 0 0 -1 0 %d]\n",
		cinf->width, cinf->height, cinf->bits, cinf->height);
	[stream appendBytes: buf length: strlen(buf)];
	if (cinf->numcolors == 1 || !cinf->isplanar) {
		p = "{currentfile pictstr readhexstring pop}\n";
		[stream appendBytes: p length: strlen(p)];
	}else {
		for (i = 0; i < 3; i++) {
		    sprintf(buf, "{currentfile subStr%d readhexstring pop}\n", i);
		    [stream appendBytes: buf length: strlen(buf)];
		}
	}
	if (cinf->numcolors == 1) {
		p = "image\n";
		[stream appendBytes: p length: strlen(p)];
		wrFixedLength(stream, map[0], bwid * cinf->height,
		    (cinf->alpha ? map[1]: NULL), (cinf->cspace == CS_Black) );
	}else if (cinf->isplanar) {
		int	y, idx;
		unsigned char *alp;
		p = "true 3 colorimage\n";
		[stream appendBytes: p length: strlen(p)];
		for (y = 0; y < cinf->height; y++) {
			idx = y * bwid;
			alp = cinf->alpha ? &map[3][idx]: NULL;
			for (i = 0; i < 3; i++)
			    wrFixedLength(stream, &map[i][idx], bwid, alp, NO);
		}
	}else {
		/* IGNORE (cinf->alpha && !cinf->isplanar) */
		p = "false 3 colorimage\n";
		[stream appendBytes: p length: strlen(p)];
		wrFixedLength(stream, map[0], buflen * cinf->height, NULL, NO);
	}
	p = "grestore\n%%Trailer\n";
	[stream appendBytes: p length: strlen(p)];
	return stream;
}

- (NSData *)openEPSData
{
	NSData	*stream = nil;
	id	tv;
	commonInfo *cinf;

	tv = [self toyView];
	cinf = [tv commonInfo];
	if (cinf->type == Type_eps || cinf->cspace == CS_CMYK
		|| (cinf->alpha && !cinf->isplanar)) {
		/* This code may be no use */
		NSRect	rect;
		rect = [tv frame];
		stream = [tv dataWithEPSInsideRect:rect];
	}else {
		unsigned char *map[MAXPLANE];
		[self getBitmap: map info: &cinf];
		stream = [self writeBitmapAsEPS: map info: cinf];
		[self freeTempBitmap];
	}
	return stream;
}

- (NSData *)openPDFData
{
	id	tv;
	NSRect	rect;

#if MAC_OS_X_VERSION_10_2 > MAC_OS_X_VERSION_MAX_ALLOWED
	// Because of BUG of Mac OS X 10.1.x
	if ((tv = [self meshView]) == nil)
#endif /* MAC_OS_X_VERSION_10_2 > MAC_OS_X_VERSION_MAX_ALLOWED */
		tv = [self toyView];
	rect = [tv frame];
	rect.origin = NSZeroPoint;
	return [tv dataWithPDFInsideRect:rect];
}

- (NSData *)openVectorData
{
	return [self openPDFData];
}

- (int)getBitmap:(unsigned char **)map info:(commonInfo **)infp
{
	NSImageRep *rep;
	rep = [[[self toyView] image] bestRepresentationForDevice:nil];
	[(NSBitmapImageRep *)rep getBitmapDataPlanes:map];
	return 0;
}

- (void)freeTempBitmap
{
	 
}

#if MAC_OS_X_VERSION_10_2 > MAC_OS_X_VERSION_MAX_ALLOWED
//
// Because of BUG of Mac OS X.
// Mac OS X 10.1.2 or earlier version
//  - can not print or preview images in planar-style.
//  - can not make PDF images from planar-style.
//
- (ToyView *)meshView
{
	NSImageRep *rep;
	NSBitmapImageRep *brep;
	unsigned char *p, *newmap[MAXPLANE], *map[MAXPLANE];
	commonInfo *info, *cinf;
	ToyView *view;
	int total, num, i, elm[MAXPLANE];

	rep = [[[self toyView] image] bestRepresentationForDevice:nil];
	if (![rep isKindOfClass:[NSBitmapImageRep class]])
		return nil;
	brep = (NSBitmapImageRep *)rep;
	if (![brep isPlanar] || [brep samplesPerPixel] == 1)
		return nil;

	[brep getBitmapDataPlanes:map];
	cinf = [[self toyView] commonInfo];
	info = malloc(sizeof(commonInfo));
	*info = *cinf;
	info->isplanar = NO;
	info->palsteps = 0;
	info->bits = 8;
	info->pixbits = (num = info->numcolors) * 8;	/* bits/pixel (mesh) */
	info->xbytes = num * info->width;	/* (number of bytes)/line */
	info->alpha = NO;			/* Alpha is ignored */
	info->palette = NULL;
	info->memo[0] = 0;

	if (initGetPixel(cinf) != 0 || (p = malloc(info->xbytes * info->height)) == NULL)
		return nil;
	newmap[0] = p;
	for (i = 1; i < MAXPLANE; i++)
		newmap[i] = NULL;
	resetPixel((refmap)map, 0);
	for (total = cinf->width * cinf->height; total > 0; total--) {
		getPixel(&elm[0], &elm[1], &elm[2], &elm[3]);
		for (i = 0; i < num; i++)
			*p++ = elm[i];
	}
	view = [[ToyView alloc] initDataPlanes:newmap info:info];
	return [view autorelease];
}
#endif /* MAC_OS_X_VERSION_10_2 > MAC_OS_X_VERSION_MAX_ALLOWED */

- (void)printWithDPI:(int)dpi
{
	ToyView *view;
	float vsf;
	float factor = 75.0/(float)dpi;

#if MAC_OS_X_VERSION_10_2 > MAC_OS_X_VERSION_MAX_ALLOWED
	NSImageRep *rep = [[[self toyView] image] bestRepresentationForDevice:nil];
	if ([rep isKindOfClass:[NSBitmapImageRep class]]
	&& [(NSBitmapImageRep *)rep isPlanar]
	&& [(NSBitmapImageRep *)rep samplesPerPixel] > 1) {
		view = [self meshView];
		if (view == nil)
			return;
		if (factor != 1.0)
			[view resize: factor];
	}else
#endif /* MAC_OS_X_VERSION_10_2 > MAC_OS_X_VERSION_MAX_ALLOWED */
	{
		view = [self toyView];
		vsf = [view scaleFactor];
		if (vsf != factor)
			view = [view resizedView: factor];
	}
	[view print:self];
}

@end
