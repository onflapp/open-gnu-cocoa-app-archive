#import "draw.h"

@implementation Rectangle : Graphic
/*
 * This is the canonical Graphic.
 * It doesn't get much simpler than this.
 *
 * This line is just a stub to get genstrings to generate
 * a .strings file entry for the name of this type of Graphic.
 * The name is used in the Undo New <Whatever> menu item.
 *
 * NSLocalString("Rectangle", NULL, "Name of the tool that draws rectangles, i.e., the %@ of the New %@ operation.")
 */

/* Methods overridden from superclass */

- (float)naturalAspectRatio
/*
 * The natural aspect ratio of a rectangle is 1.0 (a square).
 */
{
    return 1.0;
}

- (Graphic *)colorAcceptorAt:(NSPoint)point
{
    if ([self hit:point]) return self;
    return nil;
}

- draw
{
    if (bounds.size.width < 1.0 || bounds.size.height < 1.0) return self;

    if ([self fill]) {
	[self setFillColor];
	NSRectFill(bounds);
    }
    if (!gFlags.nooutline) {
	[self setLineColor];
	PSrectstroke(bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height);
    }

    return self;
}

@end
