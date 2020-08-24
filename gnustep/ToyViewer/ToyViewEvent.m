#import "ToyView.h"
#import <Foundation/NSRunLoop.h>
#import <Foundation/NSData.h>
#import <AppKit/NSEvent.h>
#import <AppKit/NSScrollView.h>
#import <AppKit/NSClipView.h>
#import <AppKit/NSImage.h>
#import <AppKit/NSBitmapImageRep.h>
#import <AppKit/NSApplication.h>
#import <AppKit/NSCursor.h>
#import <AppKit/NSColor.h>
#import <AppKit/NSBezierPath.h>
#import <AppKit/NSFont.h>
#import <AppKit/NSStringDrawing.h>
#import "NSStringAppended.h"
#import <AppKit/NSTextField.h>
#import <stdlib.h>
#import "PrefControl.h"

#define CrossCursor	@"cross.tiff"
#define CursorImgP	@"PlaceCursor.tiff"

static NSCursor *xCursor = nil;
static NSCursor *pCursor = nil;
static BOOL originUpperLeft = NO;


@implementation ToyView (EventHandling)

+ (void)cursor
{
	NSPoint spot = NSMakePoint(7.0, 7.0);
#if 0	/* Not Implemented yet... */
	xCursor = [[NSCursor alloc]
        	initWithImage: [NSImage imageNamed:CrossCursor]];
	[xCursor setHotSpot:spot];
#else
	xCursor = [[NSCursor alloc]
		initWithImage: [NSImage imageNamed:CrossCursor] hotSpot:spot];
#endif
	pCursor = [[NSCursor alloc]
		initWithImage: [NSImage imageNamed:CursorImgP] hotSpot:spot];
}

+ (BOOL)setOriginUpperLeft:(BOOL)flag
{
	BOOL oldflag = originUpperLeft;
	originUpperLeft = flag;
	return oldflag;
}

- (BOOL)acceptsFirstResponder { return YES; }

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent { return NO; }

- (void)resetCursorRects
{
	NSRect visible = [self visibleRect];
	if (!NSIsEmptyRect(visible))
		[self addCursorRect:visible cursor:xCursor];
	if (selectRect.size.width > 0.0 && selectRect.size.height > 0.0)
		[self addCursorRect:selectRect cursor:pCursor];
}

/* Local Method */
- (void)drawImageInRect:(NSRect)r
{
	if (comInfo->alpha) {
		[[NSColor colorWithCalibratedWhite:backgray alpha:1.0] set];	
		NSRectFill(r);
		[image compositeToPoint:(r.origin) fromRect:r
				operation: NSCompositeSourceOver];
	}else
		[image compositeToPoint:(r.origin) fromRect:r
				operation:NSCompositeCopy];
}

- (void)drawRect:(NSRect)r
{
	NSSize *sz;

	[self drawImageInRect:r];
	sz = &selectRect.size;
	if (sz->width > 0.0 && sz->height > 0.0
		&& NSIntersectsRect(r, selectRect)) {
		[self setDraggedLine: self];
	}
}


/* Local Method */
- (void)drawDraggedLine	/* does NOT has "lockFocus" */
{
	float	x, y;
	int	y1, y2, dx, dy;
	NSString *points;
	NSBezierPath *path;

	x = selectRect.origin.x;
	y = selectRect.origin.y;
	dx = selectRect.size.width;
	dy = selectRect.size.height;
	if (originUpperLeft) {
		y1 = curSize.height - y - dy;
		y2 = curSize.height - y - 1;
	}else {
		y1 = y,  y2 = y + dy - 1;
	}
	points = [NSString stringWithFormat:@"%d x %d  (%d, %d : %d, %d)",
			dx, dy, (int)x, y1, (int)x + dx - 1, y2];
	[commText setStringValue:points];

	// already 'lockFocus'ed
        // Note. OPENSTEP: NSMakeRect(x, y+1, dx-1, dy-1) ... Why y+1 ?? */
	path = [NSBezierPath bezierPathWithRect:NSMakeRect(x+0.5, y+0.5, dx-1, dy-1)];
	[path setLineWidth:0.5];
	[[NSColor colorWithCalibratedWhite:0.1667 alpha:1.0] set];	
	[path stroke];
	if ( dx >= 18 && dy >= 10 ) {
		NSString *str = [NSString stringWithFormat:@"%d x %d", dx, dy];
                [[NSFont fontWithName:@"Times-Roman" size:12.0] set];
		selectStrRect.origin = NSMakePoint(x+1.0, y+2.0);
		selectStrRect.size = [str sizeWithAttributes:nil];
                [str drawAtPoint:selectStrRect.origin withAttributes:nil];
	}
}

/* Local Method */
- (void)eraseDraggedLineOnly	/* Erase line only.  Does NOT reset selectRect. */
{
	const float bwid = 1.0;
	NSRect rect = selectRect;
	if (rect.origin.x >= bwid) {
		rect.origin.x -= bwid;  rect.size.width += bwid;
	}
	if (rect.origin.y >= bwid) {
		rect.origin.y -= bwid;  rect.size.height += bwid;
	}
	if (rect.origin.x + rect.size.width + bwid < curSize.width)
		rect.size.width += bwid;
	if (rect.origin.y + rect.size.height + bwid < curSize.height)
		rect.size.height += bwid;
#if 0
	if (rect.size.width < 100.0 && rect.size.height < 100.0) {
		[self drawImageInRect: rect];
		if (rect.size.width < selectStrRect.size.width + 2.0
		|| rect.size.height < selectStrRect.size.height + 3.0)
			[self drawImageInRect: selectStrRect];
	}else {
		NSRect eg;
		eg = selectRect;
		eg.size.width = bwid * 2;
		[self drawImageInRect: rect];
		eg.origin.x += selectRect.size.width - bwid * 4;
		[self drawImageInRect: rect];
		eg = selectRect;
		eg.size.height = bwid * 2;
		[self drawImageInRect: rect];
		eg.origin.y += selectRect.size.height - bwid * 4;
		[self drawImageInRect: rect];
		[self drawImageInRect: selectStrRect];
	}
#else
	if (rect.size.width < selectStrRect.size.width + 2.0
	|| rect.size.height < selectStrRect.size.height + 3.0) {
		[self drawImageInRect: NSUnionRect(rect, selectStrRect)];
	}else
		[self drawImageInRect: rect];
#endif
}

- (void)clearDraggedLine	/* has "lockFocus" */
{
	NSSize *sz = &selectRect.size;
	if (sz->width > 0.0 || sz->height > 0.0) {
		[self lockFocus];
		[self eraseDraggedLineOnly];
		[self unlockFocus];
		sz->width = sz->height = 0.0;
		[self rewriteComment];
	} 
}

- (void)setDraggedLine:sender
{
	NSSize *sz = &selectRect.size;
	if (sz->width > 0.0 && sz->height > 0.0) {
		[self lockFocus];
		[self drawDraggedLine];
		[self unlockFocus];
	} 
}

- (void)rewriteComment
{
	[commText setStringValue:commStr];
}

#define DRAG_MASK	(NSLeftMouseUpMask|NSLeftMouseDraggedMask)
#define PRESS_MASK	(NSLeftMouseUpMask|NSLeftMouseDownMask)

/* Local Method */
- (void)mousePress: (int)count
{
	NSRect	rect;

	if (count >= 2 && [[self window] isZoomed]) {
		[[self window] performZoom: self];	/* unZoom */
		return;
	}
	if (!comInfo->alpha)
		return;
	if ([[self class] alphaAsBlack]
	&& comInfo->type != Type_eps && comInfo->type != Type_pdf) {
		if (count <= 1) {
			if (backgray == 0.0) return;
			backgray = 0.0;
		}else if (count > 3) backgray = 1.0;
		else backgray = (count - 1) / 3.0;
		// Double-click = Dark Gray,  Triple click = Gray Light
	}else {
		if (count <= 1) {
			if (backgray == 1.0) return;
			backgray = 1.0;
		}else if (count > 3) backgray = 0.0;
		else backgray = (4 - count) / 3.0;
		// Double-click = Light Gray,  Triple click = Dark Gray
	}
	rect.origin.x = rect.origin.y = 0;
	rect.size = curSize;
	[self lockFocus];
	[self drawRect:rect];
	[self unlockFocus];
	[[self window] flushWindow];
}

/* Local Method */
- (void)mouseDragImage:(NSPoint)start
{
	NSEvent *event;
	NSPoint p, origp, neworig, maxp;
	NSRect	vrect;
	NSSize	imgsz;
	NSClipView *cv;
	NSScrollView *scview;

	scview = [self enclosingScrollView];
	cv = (NSClipView *)[self superview];
	vrect = [cv documentVisibleRect];
	origp = vrect.origin;
	imgsz = [self frame].size;
	maxp.x = imgsz.width - vrect.size.width;
	maxp.y = imgsz.height - vrect.size.height;
	start = [self convertPoint:start toView:nil];
	/* Window based Point */

	event = [[self window] nextEventMatchingMask:DRAG_MASK];

	while ([event type] != NSLeftMouseUp) {
		p = [event locationInWindow];
		neworig.x = origp.x + start.x - p.x;
		neworig.y = origp.y + start.y - p.y;
		if (neworig.x < 0.0)
			neworig.x = 0.0;
		else if (neworig.x > maxp.x)
			neworig.x = maxp.x;
		if (neworig.y < 0.0)
			neworig.y = 0.0;
		else if (neworig.y > maxp.y)
			neworig.y = maxp.y;
		[cv scrollToPoint: neworig];
		[scview reflectScrolledClipView: cv];
	//	[[self window] flushWindow];
		event = [[self window] nextEventMatchingMask:DRAG_MASK];
	}
	[[self window] flushWindow];
}

/* Local Method */
- (void)mouseDrawRect:(NSPoint)start
{
	int	xn = 0, yn = 0, xs, ys;
	BOOL	altDrag = NO, sftDrag = NO;
	NSEvent *event;
	NSPoint p, lowerleft;

	event = [[self window] nextEventMatchingMask:DRAG_MASK];
	if ([event type] != NSLeftMouseUp
	&& (NSCommandKeyMask & [event modifierFlags]) != 0) {
		/* if command key is pressed after mouse button */
		[self mouseDragImage: start];
		return;
	}

	[self lockFocus];
	while ([event type] != NSLeftMouseUp) {
		if (NSAlternateKeyMask & [event modifierFlags])
			altDrag = YES;
		if (NSShiftKeyMask & [event modifierFlags])
			sftDrag = YES;
		[self autoscroll:event];
		p = [event locationInWindow];
		p = [self convertPoint:p fromView:nil];
		if (p.x < 0.0) p.x = 0.0;
		else if (p.x >= curSize.width) p.x = curSize.width - 1;
		p.y--;
		if (p.y < 0.0) p.y = 0.0;
		else if (p.y > curSize.height) p.y = curSize.height - 1;

		if (p.x > start.x)
			xn = (int)p.x - start.x + 1,  xs = 1;
		else
			xn = start.x - (int)p.x + 1,  xs = -1;
		if (p.y > start.y)
			yn = (int)p.y - start.y + 1,  ys = 1;
		else
			yn = start.y - (int)p.y + 1,  ys = -1;
		if (sftDrag) {
			xn = (xn + 1) & ~3;
			yn = (yn + 1) & ~3;
			if (xs == -1 && start.x < xn-1) xn -= 4;
			if (ys == -1 && start.y < yn-1) yn -= 4;
		}
		if (altDrag) {
			if (xn < yn) yn = xn;
			else xn = yn;
		}
		p.x = start.x + (xn-1) * xs;
		p.y = start.y + (yn-1) * ys;

		lowerleft.x = (start.x < p.x) ? start.x : p.x;
		lowerleft.y = (start.y < p.y) ? start.y : p.y;
		[self eraseDraggedLineOnly];
		selectRect.origin = lowerleft;
		selectRect.size.width  = xn;
		selectRect.size.height = yn;
		[self drawDraggedLine];
		event = [[self window] nextEventMatchingMask:DRAG_MASK];
	}
	[self unlockFocus];
	    
	if (xn == 0 && yn == 0)		/* only click */
		[self rewriteComment];
	else if (xn < 3 && yn < 3)	/* Too small area */
		[self clearDraggedLine];

	[[self window] flushWindow];
}

/* Local Method */
- (void)mouseMoveRect:(NSPoint)start
{
	int	xn = 0, yn = 0, xs, ys;
	NSEvent *event;
	NSPoint p, selupr, selorig;

	selorig = selectRect.origin;
	selupr.x = selorig.x + selectRect.size.width - 1;
	selupr.y = selorig.y + selectRect.size.height - 1;
	event = [[self window] nextEventMatchingMask:DRAG_MASK];
	if ([event type] == NSLeftMouseUp) {
		[self clearDraggedLine];
		[[self window] flushWindow];
		return;
	}

	[self lockFocus];
	do {
		[self autoscroll:event];
		p = [event locationInWindow];
		p = [self convertPoint:p fromView:nil];

		if (p.x > start.x) {
			xn = (int)p.x - start.x;
			if (selupr.x + xn > curSize.width - 1.0)
				xn = curSize.width - selupr.x - 1.0;
			xs = 1;
		}else {
			xn = start.x - (int)p.x;
			if (selorig.x < xn)
				xn = selorig.x;
			xs = -1;
		}
		if (p.y > start.y) {
			yn = (int)p.y - start.y;
			if (selupr.y + yn > curSize.height - 1.0)
				yn = curSize.height - selupr.y - 1.0;
			ys = 1;
		}else {
			yn = start.y - (int)p.y;
			if (selorig.y < yn)
				yn = selorig.y;
			ys = -1;
		}

		[self eraseDraggedLineOnly];
		selectRect.origin.x = selorig.x + xn * xs;
		selectRect.origin.y = selorig.y + yn * ys;
		[self drawDraggedLine];
		event = [[self window] nextEventMatchingMask:DRAG_MASK];
	} while ([event type] != NSLeftMouseUp);
	[self unlockFocus];

	[[self window] flushWindow];
}

- (void)mouseDown:(NSEvent *)event 
{
	NSPoint	p, start;
	int	cn;

	[self mousePress: (cn = [event clickCount])];
	if (cn > 1) return;
	p = [event locationInWindow];
	p = [self convertPoint:p fromView:nil]; /* View based point */
	if (p.x < 0.0) p.x = 0.0;
	else if (p.x >= curSize.width) p.x = curSize.width - 1;
	p.y--;
	if (p.y < 0.0) p.y = 0.0;
	else if (p.y > curSize.height) p.y = curSize.height - 1;
	start.x = (int)p.x;
	start.y = (int)p.y;

	if (selectRect.size.width > 1.0 && selectRect.size.height > 1.0
		&& NSMouseInRect(start, selectRect, NO)) {
			[self mouseMoveRect: start];
	}else {
		[self clearDraggedLine];
		if ([[self window] level] > NSNormalWindowLevel
			/* isZoomed and Large */
		|| (NSCommandKeyMask & [event modifierFlags]))
			[self mouseDragImage: start];
		else
			[self mouseDrawRect: start];
	}
	[[self window] invalidateCursorRectsForView:self];
}

- (void)selectAll:(id)sender
{
	[self clearDraggedLine];
	selectRect.size = curSize;
	selectRect.origin.x = selectRect.origin.y = 0.0;
	[self setDraggedLine:sender];
}

- (NSData *)streamInSelectedRect:(id)sender
{
	NSImage *tmpimg;

	if (selectRect.size.width < 1.0 || selectRect.size.height < 1.0)
		return nil;
	if (scaleFactor == 1.0 && NSEqualSizes(origSize, selectRect.size)) {
		id stream = [[self image] TIFFRepresentation];
		if (stream != nil)
			return stream;
	}
	tmpimg = [[NSImage alloc] initWithSize: selectRect.size];
	[tmpimg autorelease];
	[tmpimg lockFocus];
	[image compositeToPoint:NSZeroPoint
		fromRect:selectRect operation:NSCompositeCopy];
	[tmpimg unlockFocus];
	return [tmpimg TIFFRepresentation];
}

- (void)copy:(id)sender
{
	NSData	*st;
        NSArray	*types;
	id	pb = [NSPasteboard generalPasteboard];

	if ((st = [self streamInSelectedRect:sender]) == nil) {
		NSBeep();
		return;
	}

	//  note that "owner:" in the following can not be "self", or the
	//  id of anything else which might be freed inbetween "Copy"
	//  operations.
        types = [NSArray arrayWithObject:NSTIFFPboardType];
        [pb declareTypes: types owner:NSApp];
	[pb setData:st forType:NSTIFFPboardType];	
}

@end
