#import  <Foundation/NSObject.h>
#import  <AppKit/NSView.h>


@interface MonotoneView: NSView
{
	id		cache;
	unsigned char	*tone;
}

- initWithFrame:(NSRect)frameRect;	/* Overload */
- (void)dealloc;
- (void)drawCache;
- (void)drawRect:(NSRect)r;	/* Overload */
- (void)setTone:(unsigned char *)buffer;

@end
