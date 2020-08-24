#import "draw.h"

/*
 * This line is just a stub to get genstrings to generate
 * a .strings file entry for the name of this type of Graphic.
 * The name is used in the Undo New <Whatever> menu item.
 *
 * NSLocalString("Curve", NULL, "Name of the tool that draws curves, i.e., the %@ of the New %@ operation.")
 */

@implementation Curve

/* Curve is a silly class that just draws a stupid curved line. */

- (float)arrowAngle:(int)corner
/*
 * Since our control points are at a 90 degree angle, we'll draw our arrows
 * at 90 degree angles (however, this method breaks down a bit as the bounds
 * get very skinny--perhaps a better one could be found).
 */
{
    if (gFlags.downhill) {
	switch (corner) {
	    case UPPER_LEFT: return 180.0;
	    case LOWER_RIGHT: return - 90.0;
	}
    } else {
	switch (corner) {
	    case UPPER_RIGHT: return 0.0;
	    case LOWER_LEFT: return -90.0;
	}
    }
    return 0.0;
}

- (void)drawLine
/*
 * Overridden from our superclass (Line).
 * This is called from the draw method to actually do the drawing of the line,
 * that way, we can inherit the arrow drawing, etc ...
 */
{
    if (gFlags.downhill) {
	PSCurve(bounds.origin.x, bounds.origin.y + bounds.size.height,
		bounds.origin.x + bounds.size.width,
		bounds.origin.y + bounds.size.height,
		bounds.origin.x + bounds.size.width,
		bounds.origin.y + bounds.size.height,
	        bounds.origin.x + bounds.size.width, bounds.origin.y);
    } else {
	PSCurve(bounds.origin.x, bounds.origin.y,
		bounds.origin.x,
		bounds.origin.y + bounds.size.height,
	        bounds.origin.x,
		bounds.origin.y + bounds.size.height,
	        bounds.origin.x + bounds.size.width,
		bounds.origin.y + bounds.size.height);
    } 
}

- (BOOL)hit:(NSPoint)p
/*
 * Line only gets a hit if the mouse is within some tolerance of the line.
 * Obviously that algorithm doesn't work for a curve.  We could come up
 * with the proper algorithm to only hit a curve if it is within a tolerance,
 * but that would be complicated so we take the easy way out and just
 * get a hit if it is anywhere in the bounds.  It is unfortunate that we
 * have to copy code from Graphic to accomplish this.  Perhaps a better
 * way exists?
 */
{
    return (!gFlags.locked && gFlags.active && NSMouseInRect(p, bounds, NO));
}

@end
