#import  <Foundation/NSObject.h>
#import  <AppKit/NSView.h>


@interface RotateView: NSView
{
	id	angleText;
	int	angle;
	float	xc, yc;			/* center */
	float	x0, y0, x1, y1;		/* left buttom & right top */
	float	x[4], y[4];	/* current points: diff from xc & yc */
}

- (id)initWithFrame:(NSRect)frameRect;	/* Over Write */
- (void)drawRect:(NSRect)r;		/* Over Write */
- (void)setAngle:(int)val;	/* set angle and display self */
- (int)intValue;
- (void)takeIntValueFrom:(id)sender;

@end
