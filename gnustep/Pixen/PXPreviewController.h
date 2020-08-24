/* PXPreviewController */

#import <AppKit/AppKit.h>

@class PXCanvas, PXCanvasView;

@interface PXPreviewController : NSWindowController
{
    IBOutlet PXCanvasView *view;
    PXCanvas *canvas;
	NSRect updateRect;
	NSWindow *resizeSizeWindow;
	NSTimer *fadeOutTimer;
	
	BOOL temporarilyHiding; // this is a little hack so a nil canvas is never shown, the window just hides itself for a while
}
+ sharedPreviewController;
- (void)setCanvas:aCanvas;
@end
