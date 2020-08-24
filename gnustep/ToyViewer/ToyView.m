#import "ToyView.h"
#import <Foundation/NSData.h>
#import <AppKit/NSImage.h>
#import <AppKit/NSBitmapImageRep.h>

#ifdef __APPLE__
#import <AppKit/NSPICTImageRep.h>
#import <AppKit/NSPDFImageRep.h>
#endif

#import <AppKit/NSCell.h>
#import <AppKit/NSWindow.h>
#import <AppKit/NSView.h>
#import <AppKit/NSColor.h>
#import <AppKit/NSCursor.h>
#import <AppKit/NSApplication.h>
#import "NSStringAppended.h"
#import <stdlib.h>
#import "rescale.h"
#import "ColorSpaceCtrl.h"

#include <AppKit/NSGraphics.h> //GNUstep only

static BOOL transBlack = NO;

@implementation ToyView

+ (void)initialize
{
	[self cursor];
}

+ (BOOL)alphaAsBlack { return transBlack; }

+ (void)setAlphaAsBlack:(BOOL)flag { transBlack = flag; }

/* Local Method */
- (id)setupInfo:(NSImage *)img
{
	NSRect rect;
	NSSize imagesz;
	NSImageRep *rep;
	int x;

	imagesz = [img size];
	if (imagesz.width == 0 || imagesz.height == 0)
		return nil;	/* maybe Filter error */
	[img setScalesWhenResized:YES];
	[img setDataRetained:YES];
	rep = [img bestRepresentationForDevice:nil];
	if ((x = [rep pixelsWide]) != NSImageRepMatchesDevice
			&& x != imagesz.width) {
		imagesz.width = x;
		imagesz.height = [rep pixelsHigh];
		[img setSize:imagesz];
	}
	rect.size = curSize = imagesz;
	rect.origin.x = rect.origin.y = 0;

	[super initWithFrame:rect];

	image = [img retain];
	origSize = imagesz;
	rawmap = NULL;
	scaleFactor = 1.0;
	commStr = @"";
	comInfo = (commonInfo *)malloc(sizeof(commonInfo));
	comInfo->width	= origSize.width;
	comInfo->height	= origSize.height;
	comInfo->bits	= [rep bitsPerSample];
	comInfo->numcolors = NSNumberOfColorComponents([rep colorSpaceName]);
	/* numcolors does not count alpha */
	comInfo->alpha	= [rep hasAlpha];
	comInfo->palette = NULL;
	comInfo->palsteps = 0;
	comInfo->memo[0] = 0;
	if ( [rep isKindOfClass:[NSBitmapImageRep class]] ) {
		NSString *w;
		id prop;
		comInfo->xbytes	= [(NSBitmapImageRep *)rep bytesPerRow];
		w = [(NSBitmapImageRep *)rep colorSpaceName];
		comInfo->cspace	= [ColorSpaceCtrl colorSpaceID: w];
		comInfo->isplanar = [(NSBitmapImageRep *)rep isPlanar];
		comInfo->pixbits = [(NSBitmapImageRep *)rep bitsPerPixel];
		comInfo->type = Type_tiff;
		backgray = [[self class] alphaAsBlack] ? 0.0 : 1.0;	/* Transparent Color */
		/*prop = [(NSBitmapImageRep *)rep valueForProperty:NSImageRGBColorTable];
		if ([prop isKindOfClass:[NSData class]]) {
			int len = [prop length];
			unsigned char *p = (unsigned char *)malloc(len);
			[prop getBytes:(void *)p];
			comInfo->palette = (paltype *)p;
			comInfo->palsteps = len / 3;
			}*/ //TODO GNUStep
	}
	/*else if ( [rep isKindOfClass:[NSPICTImageRep class]] ) {
		comInfo->xbytes	= 0;
		//  comInfo->cspace	= 0;  DON'T CARE
		comInfo->alpha	= NO;
		comInfo->isplanar = YES;	// maybe...
		comInfo->pixbits = 0;		// don't care 
		comInfo->type = Type_pict;
		backgray = 1.0;
	}
	else if ( [rep isKindOfClass:[NSPDFImageRep class]] ) {
		comInfo->xbytes	= 0;
		//  comInfo->cspace	= 0;  DON'T CARE
		comInfo->alpha	= YES;
		comInfo->isplanar = YES;	// maybe... 
		comInfo->pixbits = 0;		// don't care 
		comInfo->type = Type_pdf;
		backgray = 1.0;
	}else {	// EPS 
		comInfo->xbytes	= 0;
		//  comInfo->cspace	= 0;  DON'T CARE
		comInfo->alpha	= YES;
		comInfo->isplanar = YES;	//maybe... 
		comInfo->pixbits = 0;		//don't care 
		comInfo->type = Type_eps;
		backgray = 1.0;
	}
*/ //GNUstep only
	selectRect.size.width = 0.0;
	selectRect.size.height = 0.0;

	return self;
}

- (id)initWithImage:(NSImage *)img
{
	if (img == nil || [self setupInfo:img] == nil) {
		[super initWithFrame:NSZeroRect];
		// To release self, it must be initialized.
		[self release];
		return nil;
	}
	return self;
}

- (id)initWithContentsOfFile:(NSString *)filename
{
	NSImage *img = [[[NSImage alloc] initByReferencingFile:filename] autorelease];
	return [self initWithImage:img];
}

- (id)initFromData:(NSData *)data
{
	NSImage *img = [[[NSImage alloc] initWithData:data] autorelease];
	return [self initWithImage:img];
}


- (id)initDataPlanes:(unsigned char **)planes info:(commonInfo *)cinf
{
	NSRect frect;
	NSBitmapImageRep *imageRep;
	int spp;
        NSString *cs;

	frect = NSMakeRect(0.0, 0.0, cinf->width, cinf->height);
	[super initWithFrame:frect];

	curSize = origSize = frect.size;
	scaleFactor = 1.0;
	backgray = [[self class] alphaAsBlack] ? 0.0 : 1.0;	/* Transparent Color */
	rawmap = planes[0];
	comInfo = cinf;

	spp = cinf->numcolors;
	if (cinf->alpha) spp++;
        cs = [ColorSpaceCtrl colorSpaceName: cinf->cspace];
	imageRep = [[NSBitmapImageRep alloc]
		initWithBitmapDataPlanes:planes
		pixelsWide:cinf->width pixelsHigh:cinf->height
		bitsPerSample:cinf->bits samplesPerPixel:spp
		hasAlpha:cinf->alpha isPlanar:cinf->isplanar colorSpaceName:cs
		bytesPerRow:cinf->xbytes bitsPerPixel:cinf->pixbits];
	if (imageRep == nil
	|| (image = [[NSImage alloc] initWithSize:origSize]) == nil) {
		[imageRep release];
		[self release];
		return nil;
	}
	[image setScalesWhenResized:YES];
	[image setDataRetained:YES];
	[image addRepresentation:imageRep];
	[imageRep release];	/* Because imageRep is retained by image */
	return self;
}

- (void)setCommText:(id)text
{
	commText = text; 
}

- (void)setCommString:(NSString *)str
{
	[commStr release];
	commStr = [str retain];
	[commText setStringValue:commStr];
	[commText setToolTip:commStr];
}

- (NSSize)originalSize
{
	return origSize;
}

- (NSSize)resize:(float)factor
{
	NSSize sz = calcSize(origSize, factor);
	if (sz.width < 4)
		return NSZeroSize;
	curSize = sz;
	scaleFactor = factor;
	// backgray = (comInfo->type == Type_eps) ? 1.0
	//	: ([[self class] alphaAsBlack] ? 0.0 : 1.0);	/* Transparent Color */
	[self setFrameSize:curSize];
	[image setSize:curSize];
	[self clearDraggedLine];
	[[self window] invalidateCursorRectsForView:self];
	return curSize;
}

- (ToyView *)resizedView:(float)factor
{
	ToyView *nview;
	NSImage *nimage;
	NSSize sz = calcSize(origSize, factor);
	if (sz.width < 4)
		return nil;
	nimage = [[image copy] autorelease];
	nview = [[ToyView alloc] initWithImage: nimage];
	[nview resize: factor];
	return [nview autorelease];
}

- (void)dealloc
{
	[image release];
	[commStr release];
	if (rawmap) free((void *)rawmap);
	/* NXBitmapImageRep's Bug ??
		Method "initDataPlanes: planes ..." allocates inside
		an area of 20 bytes such as "unsigned char *planes[5]".
		This area is not freed and becomes a leak node.
	*/
	if (comInfo) {
		if (comInfo->palette) free((void *)comInfo->palette);
		free((void *)comInfo);
	}
	[super dealloc];
}

- (NSImage *)image
{
	return image;
}

- (commonInfo *)commonInfo
{
	return comInfo;
}

- (NSRect)selectedRect
{
	return selectRect;
}

- (BOOL)setSelectedRect:(NSRect)rect
{
	NSRect w;

	if (rect.size.width < 1.0 || rect.size.height < 1.0) {
		selectRect = NSZeroRect;
		return YES;
	}
	w.origin = NSZeroPoint;
	w.size = curSize;
	if (NSContainsRect(w, NSInsetRect(rect, 0.1, 0.1))) {
		selectRect = rect;
		return YES;
	}
	return NO;
}

static int decideWH(int selw, int curw, int origw, float sfactor)
{
	int w;

	if (selw == curw)
		 w = origw;
	else {
		w = (int)(selw / sfactor + 0.5);
		if (w > origw)
			w = origw;
	}
	return w;
}

- (NSRect)selectedScaledRect
{
	int	w, h, x, y;
	BOOL	square;

	if (scaleFactor == 1.0)
		return selectRect;
	square = ((int)selectRect.size.width == (int)selectRect.size.height);
	/* Decide width&height first */
	if (square) {
		int cus, ors;
		if (origSize.width < origSize.height)
			cus = curSize.width, ors = origSize.width;
		else
			cus = curSize.height, ors = origSize.height;
		w = h = decideWH(selectRect.size.width, cus, ors, scaleFactor);
	}else {
		w = decideWH(selectRect.size.width, curSize.width, origSize.width, scaleFactor);
		h = decideWH(selectRect.size.height, curSize.height, origSize.height, scaleFactor);
	}

	x = (int)(selectRect.origin.x / scaleFactor + 0.5);
	y = (int)(selectRect.origin.y / scaleFactor + 0.5);
	if (x + w > origSize.width)
		 x = origSize.width - w;
	if (y + h > origSize.height)
		 y = origSize.height - h;
	return NSMakeRect(x, y, w, h);
}

- (float)scaleFactor
{
	return scaleFactor;
}


#ifdef WITH_LEGACY_EPS

/* Overload */
- (void)beginPrologueBBox:(NSRect)boundingBox creationDate:(NSString *)dateCreated createdBy:(NSString *)anApplication fonts:(NSString *)fontNames forWhom:(NSString *)user pages:(int)numPages title:(NSString *)aTitle
{
/* Not to use the title of the window as %%Title: of EPS file. */

	char buf[MAXFILENAMELEN];
	const char *p;
	int i, cc;

	p = [aTitle cString];
	if (!p)
		p = [[[self window] title] cString];
	for (i = 0;  ; i++) {
		cc = p[i];
		if (cc == 0 || (cc > 0 && cc <= ' ')
		|| cc == '(' || cc == ')' ) break;
		buf[i] = cc;
	}
	buf[i] = 0;
	[super beginPrologueBBox:boundingBox creationDate:dateCreated
		createdBy:anApplication fonts:fontNames forWhom:user
		pages:numPages title:
			[NSString stringWithCString:(const char *)buf]];
}
#endif /* WITH_LEGACY_EPS */

@end
