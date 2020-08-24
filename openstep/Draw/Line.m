#import "draw.h"

@implementation Line : Graphic
/*
 * Drawing a line is simple except that we have to keep track of whether
 * the line goes from the upper left to the lower right of the bounds or
 * from the lower left to the upper right.  This can easily be determined
 * every time a corner is moved to a different corner.  Therefore, all
 * that is needed is to override moveCorner:to:constrain: to keep track
 * of that.  It is an efficiency hack to have the downhill flag kept
 * in our superclass's flags.
 *
 * This line is just a stub to get genstrings to generate
 * a .strings file entry for the name of this type of Graphic.
 * The name is used in the Undo New <Whatever> menu item.
 *
 * NSLocalString("Line", NULL, "Name of the tool that draws lines, i.e., the %@ of the New %@ operation.")
 */

#define HIT_TOLERANCE 6.0

- (id)init
{
    [super init];
    startCorner = LOWER_LEFT;
    return self;
}

- (BOOL)isValid
/*
 * A line is validly created if EITHER of the dimensions is big enough.
 */
{
    return(bounds.size.width >= 5.0 || bounds.size.height >= 5.0);
}

static int oppositeCorner(int corner)
{
    switch (corner) {
	case UPPER_RIGHT: return LOWER_LEFT;
	case LOWER_LEFT: return UPPER_RIGHT;
	case UPPER_LEFT: return LOWER_RIGHT;
	case LOWER_RIGHT: return UPPER_LEFT;
    }

    return corner;
}

- (int)moveCorner:(int)corner to:(NSPoint)point constrain:(BOOL)flag
/*
 * Moves the corner to the specified point keeping track of whether the
 * line is going uphill or downhill and where the start corner has moved to.
 */
{
    int newcorner;

    newcorner = [super moveCorner:corner to:point constrain:flag];

    if (newcorner != corner) {
	if ((newcorner == UPPER_RIGHT && corner == LOWER_LEFT) ||
	    (newcorner == UPPER_LEFT && corner == LOWER_RIGHT) ||
	    (newcorner == LOWER_RIGHT && corner == UPPER_LEFT) ||
	    (newcorner == LOWER_LEFT && corner == UPPER_RIGHT)) {
	} else {
	    gFlags.downhill = !gFlags.downhill;
	}
	if (startCorner == corner) {
	    startCorner = newcorner;
	} else {
	    startCorner = oppositeCorner(newcorner);
	}
    }

    return newcorner;
}

- (void)constrainCorner:(int)corner toAspectRatio:(float)ratio
/*
 * Constrains the corner to the nearest 15 degree angle.  Ignores ratio.
 */
{
    float width, height;
    double angle, distance;

    distance = sqrt(bounds.size.width*bounds.size.width + bounds.size.height*bounds.size.height);	// hypot not available on Windows?
    angle = atan2(bounds.size.height, bounds.size.width);
    angle = (angle / 3.1415) * 180.0;
    angle = floor(angle / 15.0 + 0.5) * 15.0;
    angle = (angle / 180.0) * 3.1415;
    width = floor(cos(angle) * distance + 0.5);
    height = floor(sin(angle) * distance + 0.5);

    switch (corner) {
	case LOWER_LEFT:
	    bounds.origin.x -= width - bounds.size.width;
	    bounds.origin.y -= height - bounds.size.height;
	    break;
	case UPPER_LEFT:
	    bounds.origin.x -= width - bounds.size.width;
	    break;
	case LOWER_RIGHT:
	    bounds.origin.y -= height - bounds.size.height;
	    break;
    }

    bounds.size.width = width;
    bounds.size.height = height; 
}

- (int)cornerMask
/*
 * Only put corner knobs at the start and end of the line.
 */
{
    if (gFlags.downhill) {
	return(UPPER_LEFT_MASK|LOWER_RIGHT_MASK);
    } else {
	return(LOWER_LEFT_MASK|UPPER_RIGHT_MASK);
    }
}

- draw
/*
 * Calls drawLine to draw the line, then draws the arrows if any.
 */
{
    if (bounds.size.width < 1.0 && bounds.size.height < 1.0) return self;

    [self setLineColor];
    [self drawLine];

    if (gFlags.arrow) {
	if (gFlags.downhill) {
	    if (((gFlags.arrow != ARROW_AT_START) &&
	    	 (startCorner == LOWER_RIGHT)) ||
		((gFlags.arrow != ARROW_AT_END) &&
		 (startCorner == UPPER_LEFT))) {
		PSArrow(bounds.origin.x,
			bounds.origin.y + bounds.size.height,
			[self arrowAngle:UPPER_LEFT]);	    
	    }
	    if (((gFlags.arrow != ARROW_AT_START) &&
	    	 (startCorner == UPPER_LEFT)) ||
		((gFlags.arrow != ARROW_AT_END) &&
		 (startCorner == LOWER_RIGHT))) {
		PSArrow(bounds.origin.x + bounds.size.width,
			bounds.origin.y,
			[self arrowAngle:LOWER_RIGHT]);	    
	    }
	} else {
	    if (((gFlags.arrow != ARROW_AT_START) &&
	    	 (startCorner == LOWER_LEFT)) ||
		((gFlags.arrow != ARROW_AT_END) &&
		 (startCorner == UPPER_RIGHT))) {
		PSArrow(bounds.origin.x + bounds.size.width,
			bounds.origin.y + bounds.size.height,
			[self arrowAngle:UPPER_RIGHT]);	    
	    }
	    if (((gFlags.arrow != ARROW_AT_START) &&
	    	 (startCorner == UPPER_RIGHT)) ||
		((gFlags.arrow != ARROW_AT_END) &&
		 (startCorner == LOWER_LEFT))) {
		PSArrow(bounds.origin.x,
			bounds.origin.y,
			[self arrowAngle:LOWER_LEFT]);	    
	    }
	}
    }

    return self;
}

- (BOOL)hit:(NSPoint)point
/*
 * Gets a hit if the point is within HIT_TOLERANCE of the line.
 */
{
    NSRect r;
    NSPoint p;
    float lineangle, pointangle, distance;
    float tolerance = HIT_TOLERANCE + linewidth;

    if (gFlags.locked || !gFlags.active) return NO;

    r = bounds;
    if (r.size.width < tolerance) {
	r.size.width += tolerance * 2.0;
	r.origin.x -= tolerance;
    }
    if (r.size.height < tolerance) {
	r.size.height += tolerance * 2.0;
	r.origin.y -= tolerance;
    }

    if (!NSMouseInRect(point, r, NO)) return NO;

    p.x = point.x - bounds.origin.x;
    p.y = point.y - bounds.origin.y;
    if (gFlags.downhill) p.y = bounds.size.height - p.y;
    if (p.x && bounds.size.width) {
	lineangle = atan(bounds.size.height/bounds.size.width);
	pointangle = atan(p.y/p.x);
	distance = sqrt(p.x*p.x+p.y*p.y)*sin(fabs(lineangle-pointangle));
    } else {
	distance = fabs(point.x - bounds.origin.x);
    }

    return((distance - tolerance) <= linewidth);
}

/* Methods intended to be subclassed */

- (float)arrowAngle:(int)corner
/*
 * Returns the angle which the arrow should be drawn at.
 */
{
    float angle;
    angle = atan2(bounds.size.height, bounds.size.width);
    angle = (angle / 3.1415) * 180.0;
    switch (corner) {
	case UPPER_RIGHT: return angle;
	case LOWER_LEFT: return angle + 180.0;
	case UPPER_LEFT: return 180.0 - angle;
	case LOWER_RIGHT: return - angle;
    }
    return angle;
}

- (void)drawLine
/*
 * The actual line drawing is done here so that it can be subclassed.
 */
{
    if (gFlags.downhill) {
	PSLine(bounds.origin.x, bounds.origin.y + bounds.size.height,
	       bounds.size.width, - bounds.size.height);
    } else {
	PSLine(bounds.origin.x, bounds.origin.y,
	       bounds.size.width, bounds.size.height);
    } 
}

/* Archiving methods */

#define START_CORNER_KEY @"Start Corner"

- (id)propertyList
{
    NSMutableDictionary *plist = [super propertyList];
    [plist setObject:propertyListFromInt(startCorner) forKey:START_CORNER_KEY];
    return plist;
}

- (NSString *)description
{
    return [(NSObject *)[self propertyList] description];
}

- initFromPropertyList:(id)plist inDirectory:(NSString *)directory
{
    [super initFromPropertyList:plist inDirectory:directory];
    startCorner = [[plist objectForKey:START_CORNER_KEY] intValue];
    return self;
}

@end
