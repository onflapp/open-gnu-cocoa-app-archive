#import  "RotateView.h"
#import  <math.h>
#import  <AppKit/NSImage.h>
#import  <AppKit/NSColor.h>
#import  <AppKit/NSBezierPath.h>
#import  <AppKit/NSControl.h>
#import  <AppKit/NSTextField.h>
#import  "../common.h"

@implementation RotateView

/* Overload */
- (id)initWithFrame:(NSRect)frameRect
{
	float	min;

	[super initWithFrame:frameRect];
	min = frameRect.size.width;
	if (min > frameRect.size.height) min = frameRect.size.height;
	xc = frameRect.size.width / 2.0;
	yc = frameRect.size.height / 2.0;
	x0 = min * -0.35;
	x1 = min * 0.35;
	y0 = min * -0.25;
	y1 = min * 0.25;
	[self setAngle: 0];
	return self;
}

/* Over Write */
- (void)drawRect:(NSRect)r
{
	NSSize	sz;
	int	i;
	NSBezierPath *path;

	sz = [self bounds].size;
        [[NSColor clearColor] set];
        [NSBezierPath fillRect:NSMakeRect(0.0, 0.0, sz.width, sz.height)];
        [[NSColor cyanColor] set];
	path = [NSBezierPath bezierPath];
        [path moveToPoint:NSMakePoint(xc + x[0], yc + y[0])];
	for (i = 1; i < 4; i++)
		[path lineToPoint:NSMakePoint(xc + x[i], yc + y[i])];
	[path fill];
        [[NSColor darkGrayColor] set];
	path = [NSBezierPath bezierPath];
        [path moveToPoint:NSMakePoint(xc + x[0], yc + y[0])];
        [path lineToPoint:NSMakePoint(xc + x[1], yc + y[1])];
        [path lineToPoint:NSMakePoint(xc + (x[2] + x[3])/2.0, yc + (y[2] + y[3])/2.0)];
	[path fill];
}

- (void)setAngle:(int)val
{
	if ((angle = val) == 0) {
		x[0] = x[3] = x0;
		x[1] = x[2] = x1;
		y[0] = y[1] = y0;
		y[2] = y[3] = y1;
	}else {
		double si = sin((double)angle * 3.14159265 / 180.0);
		double co = cos((double)angle * 3.14159265 / 180.0);
		double xw, xs, yw;
		x[0] = (xs = x0 * co) - (yw = y0 * si);
		x[1] = (xw = x1 * co) - yw;
		x[2] = xw - (yw = y1 * si);
		x[3] = xs - yw;
		y[0] = (xs = x0 * si) + (yw = y0 * co);
		y[1] = (xw = x1 * si) + yw;
		y[2] = xw + (yw = y1 * co);
		y[3] = xs + yw;
	}
	[self display];
	[angleText takeIntValueFrom: self];
}

- (int)intValue
{
	return angle;
}

- (void)takeIntValueFrom:(id)sender
{
	[self setAngle:[sender intValue]];
}

@end
