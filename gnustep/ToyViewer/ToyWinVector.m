#import "ToyWinVector.h"
#import <AppKit/NSTextField.h>
#import <AppKit/NSImage.h>
#import <AppKit/NSWindow.h>
#import <AppKit/NSImageRep.h>
#import <AppKit/NSCachedImageRep.h>
#import <AppKit/NSEPSImageRep.h>
#import <AppKit/NSBitmapImageRep.h>
#import <Foundation/NSData.h>
#import <stdio.h>
//#import <libc.h>
#import <string.h>
#import <math.h>
#import "ToyView.h"
#import "ColorSpaceCtrl.h"
#import "common.h"
#import "strfunc.h"
#import "rescale.h"

@implementation ToyWinVector

- (id)init
{
	[super init];
	tiffrep = nil;
	return self;
}

- (void)dealloc
{
	[tiffrep release];
	[super dealloc];
}

- (NSData *)openTiffDataBy:(float)scale compress:(BOOL)compress
{
	NSData *stream, *epsst;
	NSImage	*img;
	ToyView	*tv;
	NSSize	cSize;
	int	bestDepth;
	float	sfact;

	tv = [self toyView];
	img = [tv image];
	cSize = [img size];
	if (cSize.width >= MAXWidth)
		return NULL;
	sfact = [tv scaleFactor];
	bestDepth = NSBestDepth(NSCalibratedRGBColorSpace, 8, 24, NO, NULL);
	if ([NSWindow defaultDepthLimit] != bestDepth
			|| (scale > 0.0 && scale != sfact)) {
		/* Need to open EPS stream */
		if ((epsst = [self openVectorData]) == NULL)
			return NULL;
		if (scale <= 0.0) scale = sfact;
		cSize = calcSize([tv originalSize], scale);
		if (cSize.width <= 0.0)
			return NULL;
		img = [NSImage alloc];
		[img autorelease];
		[img initWithData: epsst];
		[img setScalesWhenResized:YES];
		[img setSize:cSize];
		[img setCacheDepthMatchesImageDepth:YES];
		[img recache];
	}
	stream = [img TIFFRepresentationUsingCompression:
		(compress ? NSTIFFCompressionLZW : NSTIFFCompressionNone)
		factor:0.0];
	// stream will be autoreleased.
	return stream;
}

/* Over write */
- (int)getBitmap:(unsigned char **)map info:(commonInfo **)infp
{
	NSData *stream;
	static commonInfo info;

	if ((stream = [self openTiffDataBy:0.0 compress:NO]) == nil)
		return Err_MEMORY;
	tiffrep = [[NSBitmapImageRep alloc] initWithData:stream];
	[tiffrep getBitmapDataPlanes:map];

	info.width	= [tiffrep pixelsWide];
	info.height	= [tiffrep pixelsHigh];
	info.xbytes	= [tiffrep bytesPerRow];
	info.type	= Type_tiff;
	info.bits	= [tiffrep bitsPerSample];
	info.numcolors	= NSNumberOfColorComponents([tiffrep colorSpaceName]); /* without alpha */
	info.alpha	= [tiffrep hasAlpha];
	info.isplanar	= [tiffrep isPlanar];
	info.pixbits	= [tiffrep bitsPerPixel];
	info.cspace = [ColorSpaceCtrl colorSpaceID: [tiffrep colorSpaceName]];
	info.palette	= NULL;
	info.palsteps	= 0;
	info.memo[0]	= 0;
	*infp = &info;
	return 0;
}

/* Over write */
- (void)freeTempBitmap	/* must be called after getBitmap:info: */
{
	if (tiffrep != nil) {
		[tiffrep release];
		tiffrep = nil;
	} 
}

/* Over write */
- (void)printWithDPI:(int)dpi
{
	/* Don't care about DPI */
	ToyView *view = [self toyView];
	if ([view scaleFactor] != 1.0)
		view = [view resizedView: 1.0];
	[view print:self];
}

@end
