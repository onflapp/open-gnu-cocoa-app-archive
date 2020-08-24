#import  <Foundation/NSObject.h>
#import  <AppKit/NSView.h>

@class	NSImage;

@interface PercentView: NSView
{
	NSImage	*cache;
	float	percent;
}

- initWithFrame:(NSRect)frameRect;	/* Overload */
- (void)dealloc;		/* Overload */
- (void)drawRect:(NSRect)r;	/* Overload */
- (void)reset:(id)sender;
- (void)setFloatValue:(float)value;
- (void)takeFloatValueFrom:(id)sender;

@end
