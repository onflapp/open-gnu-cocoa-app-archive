#import "PXImageView.h"

@implementation PXImageView

- (void)mouseDown:event
{
	[[self superview] mouseDown:event];
}

- (void)rightMouseDown:event
{
	[[self superview] rightMouseDown:event];
}

- (void)mouseUp:event
{
	[[self superview] mouseUp:event];
}

- (void)rightMouseUp:event
{
	[[self superview] rightMouseUp:event];
}

- (void)mouseDragged:event
{
	[[self superview] mouseDragged:event];
}

- (void)rightMouseDragged:event
{
	[[self superview] rightMouseDragged:event];
}

@end
