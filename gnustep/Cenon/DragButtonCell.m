
#import "DragButtonCell.h"

NXAtom pastboardTypes[1];

@implementation DragButtonCell

- init
{
	return [super init];
}

#define mask (NSLeftMouseUpMask|NSLeftMouseDraggedMask)
/* true if mouse moves > n pixels from 'o' */
static int aMouseMoved(NSPoint *o, int n)
{	NSPoint	p;
	float	d;
	NSEvent *e;

	do
	{
		e = [NSApp nextEventMatchingMask:mask untilDate:[NSDate distantFuture] inMode:NSEventTrackingRunLoopMode dequeue:YES];
		p = [e locationInWindow];
		d = abs(p.x - o->x);
		if (d < abs(p.y - o->y))
			d = abs(p.y - o->y);
	}
	while ([e type] != NSLeftMouseUp && d < n);
	*o = p;
	return [e type] != NSLeftMouseUp;
}

#warning RectConversion: 'trackMouse:inRect:ofView:untilMouseUp:' used to be 'trackMouse:inRect:ofView:'.  untilMouseUp == YES when inRect used to be NULL
- (BOOL)trackMouse:(NSEvent *)event inRect:(NSRect)cellFrame ofView:(NSView *)aView untilMouseUp:(BOOL)_untilMouseUp
{//	NXRect		dragRect;
	NSPoint		hit;
	NSEvent *saveEvent;
//	Pasteboard	*dragPasteboard;
//	NXStream	*psStream;

	hit = [event locationInWindow];
	saveEvent = event;
	if (aMouseMoved(&hit, 1))
	{
		[[aView target] drag:event];	/* view is our matrix, target is our window */
#if 0
	//[self convertPoint:&hit fromView:nil];
		dragRect.size = [[self image] size];
		dragRect.origin.x = 8;
		dragRect.origin.y = 8;
		dragPasteboard = [NSPasteboard pasteboardWithName:NSDragPboard];
		[dragPasteboard declareTypes:[NSArray arrayWithObject:[NSString stringWithCString:*pastboardTypes]] owner:self];

		/* fill pasteboard */
	//	if(psStream = NXMapFile(pathName, NX_READONLY))
	//		[dragPasteboard writeType:pastboardTypes[0] fromStream:psStream];

		[view dragImage:[self image] at:(dragRect.origin) offset:NSMakeSize((&hit)->x,(&hit)->y) event:saveEvent pasteboard:dragPasteboard source:self slideBack:YES];
#endif
	}
	return NO;
//	return [super trackMouse:theEvent inRect:cellFrame ofView:aView];
}

@end
