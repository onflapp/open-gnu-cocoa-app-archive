#import  "FullScreenWindow.h"
#import "../TVController.h"
#import "Background.h"
#import "FullScreenView.h"

#define  WLevel_Behind	(NSNormalWindowLevel-2)
#define  WLevel_Front	NSScreenSaverWindowLevel  // was (NSMainMenuWindowLevel+5)


@implementation FullScreenWindow

- (id)initWithContentRect:(NSRect)rect styleMask:(int)mask
{
	NSPoint p;

        [super initWithContentRect:rect styleMask:mask
		backing:NSBackingStoreBuffered defer:NO];
	[self useOptimizedDrawing:YES];
	[self setAcceptsMouseMovedEvents:NO];
	if (mask) {
		p.x = 0.0;
		p.y = 0.0;
		/* p.y = -1.0 : Title "Line" for emergency */
	}else
		p.x = p.y = 0.0;
	[self setFrameOrigin:p];
	return self;
}

- (void)toBehind:(id)sender
{
	[self setLevel: WLevel_Behind];
	[self orderWindow:NSWindowBelow relativeTo:0];
//	[theController backWinFront: NO]; 
	[[self contentView] setIsFront: NO]; 
}

- (void)toFront:(id)sender
{
	[self setLevel: WLevel_Front];
	[self orderWindow:NSWindowAbove relativeTo:0];
//	[theController backWinFront: YES]; 
	[[self contentView] setIsFront: YES]; 
}

- (NSRect)constrainFrameRect:(NSRect)frameRect toScreen:(NSScreen *)aScreen
{
	return frameRect;
}

/* This class ignore constrainFrameRect:toScreen: method not to display
   title bars of windows.  A window should have a title bar to be a key
   window.
*/
@end
