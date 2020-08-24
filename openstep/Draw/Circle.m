#import "draw.h"

/*
 * This line is just a stub to get genstrings to generate
 * a .strings file entry for the name of this type of Graphic.
 * The name is used in the Undo New <Whatever> menu item.
 *
 * NSLocalString("Circle", NULL, "Name of the tool that draws ovals, i.e., the %@ of the New %@ operation.")
 */

@implementation Circle : Graphic

- (Graphic *)colorAcceptorAt:(NSPoint)point
/*
 * An oval accepts a dropped color if the drop occurs
 * within the bounds of the circle itself.
 */
{
    if ([self hit:point]) {
        return self;
    } else {
        return nil;
    }
}

- (float)naturalAspectRatio
/*
 * The natural aspect ratio of an oval is 1.0 (a circle).
 */
{
    return 1.0;
}

- draw
{
    if (bounds.size.width >= 1.0 && bounds.size.height >= 1.0) {
        if ([self fill]) {
            PSgsave();
            [self setFillColor];
            PSFilledOval(bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height);
            PSgrestore();
        }
        if (!gFlags.nooutline) {
            [self setLineColor];
            PSFramedOval(bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height);
        }
    }
    return self;
}

- (BOOL)hit:(NSPoint)p
/*
 * Hit only if inside the interior of the oval.
 */
{
    float x, y;
    NSPoint center;
    double angle, radius, diameter;

    if ([super hit:p]) {
	center.x = bounds.origin.x + bounds.size.width / 2.0;
	center.y = bounds.origin.y + bounds.size.height / 2.0;
	diameter = MIN(bounds.size.width, bounds.size.height);
	x = fabs(center.x - p.x) / (bounds.size.width / diameter);
	y = fabs(center.y - p.y) / (bounds.size.height / diameter);
	angle = atan2(y, x);
	radius = diameter / 2.0;
	return(x < radius * cos(angle) && y < radius * sin(angle));
    } else {
	return NO;
    }
}

@end
