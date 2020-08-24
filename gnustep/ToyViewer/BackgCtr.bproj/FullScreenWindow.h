#import  <AppKit/NSWindow.h>

@interface FullScreenWindow:NSWindow

- (id)initWithContentRect:(NSRect)rect styleMask:(int)mask;
- (void)toBehind:(id)sender;
- (void)toFront:(id)sender;
- (NSRect)constrainFrameRect:(NSRect)frameRect toScreen:(NSScreen *)aScreen;

@end


