#import <Foundation/NSBundle.h>	/* LocalizedString */
#import <Foundation/NSNotification.h>
#import <AppKit/NSApplication.h>
#import <AppKit/NSControl.h>
#import <AppKit/NSTextField.h>
#import <AppKit/NSScrollView.h>
#import <AppKit/NSPanel.h>
#import <AppKit/NSGraphics.h>
#import <AppKit/NSImage.h>
#import "NSStringAppended.h"
#import <stdio.h>
#import <stdlib.h>
#import <string.h>
#import "ToyWin.h"
#import "ToyView.h"
#import "TVController.h"
#import "PrefControl.h"
#import "WaitMessageCtr.h"
#import "strfunc.h"

#define MiniIcon @"miniwin.tiff"
#define  DiffStep	20.0
#define  MinWinXSIZE	120.0
#define  MinWinYSIZE	32.0
#define  MinResizeXSIZE	200.0
#define  MinResizeYSIZE	150.0


@implementation ToyWin

/* Local */
static BOOL	displayOverKeyWindowFlag = NO;
static id	theMiniIcon = nil;
static NSSize	screenSize;
static int view_offsetX = 0, view_offsetY = 0;
static int scrollBar_width = 0;

+ (void)initialize
{
	screenSize = [[NSScreen mainScreen] frame].size;
	theMiniIcon = [NSImage imageNamed:MiniIcon];
}

+ (BOOL)displayOverKeyWindow { return displayOverKeyWindowFlag; }

+ (void)setDisplayOverKeyWindow:(BOOL)flag {
	displayOverKeyWindowFlag = flag;
}

+ (NSString *)stripHistory:(NSString *)path
{
	const int FilenameLimit	= 48;
	int n, lx, rx;
	unichar *buf;
	NSString *result = nil;
	NSString *dir, *elm;

	dir = [path stringByDeletingLastPathComponent];
	elm = [path lastPathComponent];
	if ([elm cStringLength] < FilenameLimit)
		return nil;
	n = [elm length];
	if ([elm characterAtIndex:(n-1)] != (unichar)')' )
		return nil;
	buf = (unichar *)malloc(sizeof(unichar) * (n+1));
	[elm getCharacters:buf];
	buf[n] = 0;
	for (rx = n-1; buf[rx] != (unichar)'('; )
		if (--rx <= 0) goto EXIT;
	for (lx = 0; buf[lx] != (unichar)'('; )
		if (++lx >= n) goto EXIT;
	if (lx == rx) goto EXIT;
	if (lx > 0 && buf[lx-1] != (unichar)'_')
		buf[lx++] = (unichar)'_';
	while (rx <= n)
		buf[lx++] = buf[rx++];
	result = [dir stringByAppendingPathComponent:
		[NSString stringWithCharacters:buf length:lx]];
EXIT:
	free((void *)buf);
	return result;
}


- (id)init
{
	[super init];
	parental = nil;
	operation = 0;
	scaleFactor = 1.0;
	imageFilename = nil;
	makeMapOnly = NO;
	_tview = nil;
	return self;
}

- (id)init:(id)parent by:(int)op
{
	[self init];
	[NSBundle loadNibNamed:@"ToyWin" owner:self];
	[thiswindow setReleasedWhenClosed:YES];
	[thiswindow setMiniwindowImage: theMiniIcon];
	if (view_offsetY <= 0) {
		NSRect wrect = [thiswindow frame];
		NSSize frsize = [scView frame].size;
		NSSize sz = [NSScrollView contentSizeForFrameSize:frsize
			hasHorizontalScroller:NO hasVerticalScroller:NO
			borderType:[scView borderType]];
		NSSize szbar = [NSScrollView contentSizeForFrameSize:frsize
			hasHorizontalScroller:YES hasVerticalScroller:YES
			borderType:[scView borderType]];
		view_offsetX = wrect.size.width - sz.width;
		view_offsetY = wrect.size.height - sz.height;
		scrollBar_width = sz.height - szbar.height;
	}
	parental = parent;
	operation = op;
	return self;
}

- (id)initMapOnly {
	/* An instance of ToyWin initialized by this method does not
		display a window.  It is used to make the bitmap of
		a image file to support pasteboard service. */
	[self init];
	makeMapOnly = YES;
	return self;
}

- (void)dealloc
{
	[imageFilename release];
	if (scView == nil) // makeMapOnly == YES
		[_tview release];
	[super dealloc];
}

- (NSString *)filename {
	return imageFilename;
}

- (void)resetFilename:(NSString *)fileName
{
	[imageFilename release];
	imageFilename = [fileName retain];
	[thiswindow setTitleWithRepresentedFilename:imageFilename]; 
}

- (NSWindow *)window { return thiswindow; }

- (id)toyView {
	return scView ? [scView documentView] : _tview;
}

- (id)parent { return parental; }

- (int)madeby { return operation; }


#define  loc_INIT	0	/* Window is initialized */
#define  loc_RESZ	1	/* Window is resized */
#define  loc_SPEC	2	/* Window is initialized */
				/* and displayed at specified point */

/* Local Method */
- (NSSize)modifiedScreenSizeAndBias:(NSSize *)bias
{
	int wid;
	unsigned int bit;
	id pref = [PrefControl sharedPref];
	NSSize scr = screenSize;
#ifdef __APPLE__
	scr.height -= 22.0;
#else
	scr.width -= 68.0;
#endif
	if ((bit = [pref windowMarginBits]) != 0) {
		wid = [pref windowMarginWidth];
		if (bit & margin_L)
			scr.width -= wid;
		if (bit & margin_R)
			scr.width -= wid;
		if (bit & margin_B)
			scr.height -= wid;
		if (bias) {
			bias->width = (bit & margin_L) ? wid : 0;
			bias->height = (bit & margin_B) ? wid : 0;
		}
	}else
		if (bias) *bias = NSZeroSize;
	return scr;
}

/* Local Method */
- (NSSize)allowedWindowSize:(NSPoint)atpoint fixed:(BOOL)fixed
	/* width, height : Size of the image */
	/* if fixed==YES, atpoint is real axis, otherwise it is in the modifiedScreenSize */
{
	NSSize allow, scr, bias;

	scr = [self modifiedScreenSizeAndBias: &bias];
	if (fixed)
		allow.width = scr.width - (atpoint.x - bias.width);
	else
		allow.width = scr.width - atpoint.x;
	if (allow.width < 0.0 || allow.width > scr.width)
		allow.width = scr.width;
	allow.height = atpoint.y;
	if (fixed)
		allow.height -= bias.height;
	if (allow.height < 0.0 || allow.height > scr.height)
		allow.height = scr.height;
	return allow;
}

/* Local Method */
- (NSSize)requiredWindowSize:(NSSize)viewsize
{
	NSSize req;
	req.width = ((MinWinXSIZE > viewsize.width) ? MinWinXSIZE : viewsize.width) + view_offsetX;
	req.height = ((MinWinYSIZE > viewsize.height) ? MinWinYSIZE : viewsize.height) + view_offsetY;
	return req;
}

/* Local Method */
- (void)locateWindow: (NSSize)viewsize by:(int)is_init : (NSPoint *)atpoint;
	/* width, height : Size of the image */
{
	NSSize req;	/* Size needed to display whole image */
	NSSize reqbar;	/* Size needed to display whole image width scrollers */
	NSSize rsmin;	/* minimum size of resizing */
	NSRect winrect;	/* result */
	NSSize allow;	/* allowable size */
	NSPoint ulpnt;	/* Upper-Left point of the window */
	BOOL needScroll;	/* Scrollers are neeed ? */
	static int winCounter = 6; /* because small window is under the menu */

	if (makeMapOnly)
		return;
	req = [self requiredWindowSize: viewsize];
	reqbar.width = req.width + scrollBar_width;
	reqbar.height = req.height + scrollBar_width;
	rsmin.width = (req.width < MinResizeXSIZE)
			? req.width : MinResizeXSIZE;
	rsmin.height = (req.height < MinResizeYSIZE)
			? req.height : MinResizeYSIZE;
	winrect.size = req;

	if (is_init == loc_RESZ || is_init == loc_SPEC) {
		if (atpoint) /* loc_SPEC */
			ulpnt = *atpoint;
		else {	/* loc_RESZ: Window is resized by Pop-up Menu */
			NSRect rect = [thiswindow frame];	/* size of the current window */
			ulpnt.x = rect.origin.x;
			ulpnt.y = rect.origin.y + rect.size.height;
		}
		allow = [self allowedWindowSize:ulpnt fixed:YES];
		if (allow.width >= req.width && allow.height >= req.height) {
			winrect.origin.x = ulpnt.x;
			winrect.origin.y = ulpnt.y - req.height;
			needScroll = NO;
		}else {
			winrect.size = reqbar;
			needScroll = YES;
			if (allow.width < reqbar.width)
				winrect.size.width = allow.width;
			if (allow.height < reqbar.height)
				winrect.size.height = allow.height;
			winrect.origin.x = ulpnt.x;
			winrect.origin.y = ulpnt.y - winrect.size.height;
		}
	}else { /* loc_INIT */
		int xp, yp;	/* Location of the window */
		int xm, ym;
		NSSize bias;
		NSSize scr = [self modifiedScreenSizeAndBias: &bias];
		/* In case of loc_INIT, location of ulpnt is calculated within
		   modifiedScreenSize */

		if (scr.height <= 600.0) xm = 7, ym = 9;
		else xm = 13, ym = 15;
#ifdef __APPLE__
		xp = (req.width > scr.width)
			? 0 : (10 + (winCounter % xm) * DiffStep);
		yp = (req.height > scr.height)
			? 20 : (0 + (winCounter % ym) * DiffStep);
#else
		xp = (req.width > scr.width)
			? 0 : (120 + (winCounter % xm) * DiffStep);
		yp = (req.height > scr.height)
			? 0 : (20 + (winCounter % ym) * DiffStep);
#endif
		ulpnt.x = xp;
		ulpnt.y = scr.height - yp;
		allow = [self allowedWindowSize:ulpnt fixed:NO];
		if (scr.width >= req.width && scr.height >= req.height) {
			winrect.origin.x = ulpnt.x;
			winrect.origin.y = ulpnt.y - req.height;
			needScroll = NO;
			if (allow.width < req.width || allow.height < req.height) {
				if (allow.width < req.width)
					winrect.origin.x = scr.width - req.width;
				if (allow.height < req.height)
					winrect.origin.y = scr.height - req.height;
			}
		}else {
			winrect.size = reqbar;
			needScroll = YES;
			if (allow.width < reqbar.width) {
				winrect.size.width =
					(scr.width > reqbar.width) ? reqbar.width : scr.width;
				winrect.origin.x = 0.0;
			}else
				winrect.origin.x = ulpnt.x;
			if (allow.height < reqbar.height) {
				int d;
				if ((d = scr.height - reqbar.height) > 0) {
					winrect.size.height = reqbar.height;
					winrect.origin.y = d;
				}else {
					winrect.size.height = scr.height;
					winrect.origin.y = 0.0;
				}
			}else
				winrect.origin.y = ulpnt.y - reqbar.height;
		}
		winrect.origin.x += bias.width;
		winrect.origin.y += bias.height;
		winCounter++;
	}
	[scView setHasVerticalScroller: needScroll];
	[scView setHasHorizontalScroller: needScroll];
	[thiswindow setFrame:winrect display:NO];
	[thiswindow setMinSize:rsmin];
	[thiswindow setMaxSize: (needScroll ? reqbar : req)];
}

/* Scroll image to be top & center */
- (void)scrollProperly
{
	NSSize imgsz;
	NSRect wrect;
	NSPoint scorig;
	int	xp, yp;
	id	tv;

	if (makeMapOnly)
		return;
	tv = [self toyView];
	imgsz = [[tv image] size];
	wrect = [scView documentVisibleRect];
	scorig.x = ((xp = imgsz.width - wrect.size.width) > 0) ? (xp / 2) : 0;
	scorig.y = ((yp = imgsz.height - wrect.size.height) > 0) ? yp : 0;
	if (xp > 0 || yp > 0)
		[tv scrollPoint:scorig]; 
}

- (id)locateNewWindow:(NSString *)fileName width:(int)width height:(int)height 
{
	ToyWin *keytw;
	BOOL	hasKey;
	NSSize	viewsize;

	viewsize = NSMakeSize(width, height);
	keytw = [theController keyWindow];
	hasKey = (keytw != nil && ![[keytw window] isMiniaturized]);
	if (displayOverKeyWindowFlag) {
		NSPoint point;
		if (hasKey) {
			NSRect rect = [[keytw window] frame];
			point = rect.origin;
			point.y += rect.size.height;
		}else {
			NSPoint pnt = [[PrefControl sharedPref] topLeftPoint];
			point.x = pnt.x;
			point.y = screenSize.height - pnt.y;
		}
		[self locateWindow:viewsize by:loc_SPEC : &point];
	}else
		[self locateWindow:viewsize by:loc_INIT : NULL];
	if (parental) {
		NSString *newfn = [[self class] stripHistory: fileName];
		imageFilename = newfn ? newfn : fileName;
		[imageFilename retain];
		[thiswindow setTitle: [imageFilename lastPathComponent]];
	}else if (operation == FromPasteBoard) {
		imageFilename = [fileName retain];
		[thiswindow setTitle: [imageFilename lastPathComponent]];
	}else {
		imageFilename = [fileName retain];
		[thiswindow setTitleWithRepresentedFilename: imageFilename];
	}
	if (hasKey)
		[thiswindow orderWindow:NSWindowBelow
			relativeTo:[[keytw window] windowNumber]];
	else
		[thiswindow orderFront:self];
	[thiswindow display];
	return self;
}

/* Local */
- (void)doRescale: (float)factor
{
	float r;
	NSSize sz;
	BOOL showmsg;

	r = (scaleFactor > factor)
		? (scaleFactor / factor):(factor / scaleFactor);
	if (r < 1.0025)
		return;
	sz = [[self toyView] resize:factor];
	if (sz.width <= 0 || sz.height <= 0) {
		NSBeep();
		return;
	}
	scaleFactor = factor;
	showmsg = (r > 1.7 || (sz.width * sz.height) > 60000);

	if (showmsg)
		[theWaitMsg messageDisplay:
			NSLocalizedString(@"Resizing...", Resizing)];
	[self locateWindow: sz by:loc_RESZ : NULL];
	// DON'T -> [scView sizeTo: sz.width + 21.0 : sz.height + 21.0];
	[self scrollProperly];
	[thiswindow display];
	if (showmsg)
		[theWaitMsg messageDisplay:nil];
}

/* Local */
- (void)selectRescale:(id)sender
{
#ifdef __APPLE__
  [self doRescale: [[sender selectedCell] floatValue] / 100.0];
#else
  id cell = [sender selectedCell];
  NSString *item= [[cell stringValue] substringToIndex:(unsigned) ([[cell stringValue] length] - 1)];
  [self doRescale: [item floatValue] / 100.0];
#endif
}

- (void)reScale:(id)sender
{
	id cell = [sender selectedCell];
       	NSString *item = [cell stringValue];
	float f = [item floatValue] / 100.0;
	if (f <= 0.01 || f >= 100.0)
		return;
	if (![item hasSuffix:@"%"]) {
	  [cell setStringValue:
		  [NSString stringWithFormat:@"%@%%", item]];

	}

	[NSObject cancelPreviousPerformRequestsWithTarget:self
			selector:@selector(selectRescale:) object:sender];
	[self performSelector:@selector(selectRescale:)
			withObject:sender afterDelay: 5 / 1000.0];
}

- (void)windowDidMiniaturize:(NSNotification *)notification
{
	[[self toyView] clearDraggedLine];
}

- (void)windowDidDeminiaturize:(NSNotification *)notification
{
	// NSWindow *theWindow = [notification object];
}

- (BOOL)windowShouldClose:(id)sender
{
	// printf("Window will be freed\n");
	[theController checkAndDeleteWindow: self];
	[thiswindow setDelegate:nil];
	[self release];
	return YES;
}

- (void)windowDidBecomeKey:(NSNotification *)notification
{
	id tv = [self toyView];
	[thiswindow makeFirstResponder:tv];
	[tv setDraggedLine:self];
}

- (void)windowDidExpose:(NSNotification *)notification {
	[[self toyView] setDraggedLine:self];
}

- (void)windowDidMove:(NSNotification *)notification {
	[[self toyView] setDraggedLine:self];
}

- (BOOL)keepOpen {
	return [keepOpenButton state];
}

- (void)changeKeepOpen:(id)sender {
	if ([keepOpenButton state])
		[theController addToRecentMenu:imageFilename];
}

/* Delegate */
- (NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)proposedFrameSize
{
	if ([sender respondsToSelector:@selector(cancelZoom)])
		[sender performSelector:@selector(cancelZoom)];
	return [self properlyResize:sender toSize:proposedFrameSize];
}

- (NSSize)properlyResize:(NSWindow *)sender toSize:(NSSize)proposedFrameSize
{
	NSSize mx;
	NSSize req;
	ToyView	*tv;

	if (makeMapOnly || (tv = [self toyView]) == nil)
		return proposedFrameSize;
		// if tv == nil, the window has been just allocated.
	req = [self requiredWindowSize:[tv frame].size];
	if ([scView hasVerticalScroller]) {
		if (req.height <= proposedFrameSize.height
		&& req.width <= proposedFrameSize.width) {
			/* Remove Scrollers */
			[scView setHasVerticalScroller:NO];
			[scView setHasHorizontalScroller:NO];
			[thiswindow setMaxSize:req];
			return req;
		}
		[self scrollProperly];
		return proposedFrameSize;
	}
	/* No Scroll Bars */
	mx = [thiswindow maxSize];
	if (mx.height > proposedFrameSize.height
	|| mx.width > proposedFrameSize.width) {
		NSSize newmx = NSMakeSize(mx.width + scrollBar_width, mx.height + scrollBar_width);
		/* Attach Scrollers */
		[scView setHasVerticalScroller:YES];
		[scView setHasHorizontalScroller:YES];
		[thiswindow setMaxSize:newmx];
	}
	return proposedFrameSize;
}

- (NSRect)zoomedWindowFrame
{
	NSRect	mxrect;
	NSSize	mxsize, sz;
	BOOL	scflag = NO;

	sz = [[self toyView] frame].size;
	if (sz.width > screenSize.width) {
		sz.width = screenSize.width;
		scflag = YES;
	}
	if (sz.height > screenSize.height) {
		sz.height = screenSize.height;
		scflag = YES;
	}
	mxsize = [self requiredWindowSize: sz];
	if (scflag) { /* scroller needed */
		mxsize.width += scrollBar_width;
		mxsize.height += scrollBar_width;
	}
	mxrect.origin.x = (mxsize.width > screenSize.width) ? 0 :
		(int)(screenSize.width - mxsize.width) / 2;
	mxrect.origin.y = (mxsize.height > screenSize.height)
		? (int)(22.0 + sz.height - mxsize.height)
		: (int)(screenSize.height - mxsize.height) / 2;
	mxrect.size = mxsize;
	return mxrect;
}

@end
