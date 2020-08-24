#import "FullScreenView.h"
#import <AppKit/NSApplication.h>
#import <AppKit/NSWindow.h>
#import <AppKit/NSImage.h>
#import <AppKit/NSControl.h>
#import <AppKit/NSScreen.h>
#import <AppKit/NSColor.h>
#import <AppKit/NSEvent.h>
#import <Foundation/NSData.h>
#import "backgops.h"
#import "../PrefControl.h"
#import "BackgCtr.h"

#define CursorImgR @"CRightArrow.tiff"
#define CursorImgL @"CLeftArrow.tiff"
#define CursorImgP @"CPause.tiff"

static NSCursor *CursorR = nil;
static NSCursor *CursorL = nil;
static NSCursor *CursorP = nil;
static NSRect	rectL, rectP;

@implementation FullScreenView

+ (void)initialize
{
	NSPoint spot;
	NSImage *test;
	NSZone	*zone = [BackgCtr zoneForBackground];
	NSSize	ssize = [[self class] screenRect].size;

	spot.x = 7.0;
	spot.y = 7.0;
	//CursorR = [NSCursor allocWithZone:zone];
	//CursorL = [NSCursor allocWithZone:zone];
	//CursorP = [NSCursor allocWithZone:zone];
#if 0	/* Not Implemented yet...? */
        [xCursor initWithImage: [NSImage imageNamed:CrossCursor]];
	[xCursor setHotSpot:spot];
#else
	test = [NSImage imageNamed:CursorImgR];
	NSLog(@"=====> %@",test);
	CursorR= [[NSCursor alloc] initWithImage: [NSImage imageNamed:CursorImgR] hotSpot:spot];
	CursorL = [[NSCursor alloc] initWithImage: [NSImage imageNamed:CursorImgL] hotSpot:spot];
	CursorP = [[NSCursor alloc] initWithImage: [NSImage imageNamed:CursorImgP] hotSpot:spot];
	//[CursorR initWithImage: [NSImage imageNamed:CursorImgR] hotSpot:spot];
	//[CursorL initWithImage: [NSImage imageNamed:CursorImgL] hotSpot:spot];
	//[CursorP initWithImage: [NSImage imageNamed:CursorImgP] hotSpot:spot];
#endif
	rectL.origin.x = rectL.origin.y = 0;
	rectL.size.width = ssize.width / 3.0;
	rectL.size.height = ssize.height;
	rectP.origin.x = ssize.width * 5.0 / 6.0;
	rectP.origin.y = ssize.height * 5.0 / 6.0;
	rectP.size.width = ssize.width - rectP.origin.x;
	rectP.size.height = ssize.height -rectP.origin.y;
}

- (id)init
{
	[super init];
	controller = nil;
	isfront = YES;
	return self;
}

- (BOOL)becomeFirstResponder
{ /* This Method and 'makeFirstResponder:' to the window is needed to accept
     KeyDown event. */
	return YES;
}

- (void)resetCursorRects
{
	NSRect	srect = [[self class] screenRect];
	[self addCursorRect:srect cursor:CursorR];
	[self addCursorRect:rectL cursor:CursorL];
	[self addCursorRect:rectP cursor:CursorP];
}

- (void)setController:(id <PlayControl>)obj
{
	controller = obj;
}

- (void)mouseDown:(NSEvent *)event
{
	NSPoint	p;
	int	dmy;

	if ([event type] != NSLeftMouseDown)
		return;
	dmy = [event clickCount];	/* prevent error multi-clicking */
	p = [event locationInWindow];
	p = [self convertPoint:p fromView:nil]; /* View based point */
	if (NSMouseInRect(p, rectL, NO))
		[controller backPush:self];
	else if (NSMouseInRect(p, rectP, NO))
		[controller pausePush:self];
	else
		[controller stepPush:self];
}

- (void)keyDown:(NSEvent *)event
{ /* This code is from ToyAlbum */
	unichar ev = [[event characters] characterAtIndex:0];
	switch (ev) {
	case 'f': case 'n':
	case 'F': case 'N':
	case ' ': case '\n': case '\t':
	case NSRightArrowFunctionKey:
		[controller stepPush:self];
		break;
	case 'b': case 'p':
	case 'B': case 'P':
	case '\010' /* BS */: case '\177' /* DEL */:
//	case '\019' /* Shift-TAB */:
	case NSLeftArrowFunctionKey:
		[controller backPush:self];
		break;
	case 'q': case 'Q':
	case '\033' /* ESC */:
		[controller pausePush:self];
		return;
	default:
		NSBeep();
		return;
	}
}

@end
