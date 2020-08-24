#import "draw.h"

/*
 * This line is just a stub to get genstrings to generate
 * a .strings file entry for the name of this type of Graphic.
 * The name is used in the Undo New <Whatever> menu item.
 *
 * NSLocalString("Polygon", NULL, "Name of the tool that draws polygons, i.e., the %@ of the New %@ operation.")
 */

@implementation Polygon

+ (NSCursor *)cursor
/*
 * The cursor inherited from Scribble is a pencil.
 * That's not very appropriate, so CrossCursor is used instead.
 */
{
    return [Graphic cursor];
}

static NSRect NSRectFromBBox(float x1, float y1, float x2, float y2)
/*
 * Takes two points (x1, y1) and (x2, y2) and updates the r rect to
 * equal that bounding box.
 */
{
    NSRect r;

    r.size.width = x1 - x2;
    r.size.height = y1 - y2;
    if (r.size.width < 0.0) {
	r.origin.x = x2 + r.size.width;
	r.size.width = 0.0 - r.size.width;
    } else r.origin.x = x2;
    if (r.size.height < 0.0) {
	r.origin.y = y2 + r.size.height;
	r.size.height = 0.0 - r.size.height;
    } else r.origin.y = y2;

    return r;
}

/*
 * This class probably is probably not implemented in the optimal way,
 * but it shows how an existing implementation (i.e. Scribble) can be
 * used to implement some other object.
 *
 * This method creates a polygon.  The user must drag out each segment of
 * the polygon clicking to make a corner, finally ending with a double click.
 *
 * Start by getting the starting point of the polygon from the mouse down
 * event passed in the event parameter (if the ALT key is not down, then we
 * will close the path even if the user does not explicitly do so).
 *
 * Next, we initialize a chunk of space for the points to be stored in
 * and initialize point[0] and point[1] to be the starting point (since the
 * first thing in the userpath is a moveto).  We also initialize our bounding
 * box to contain only that point.
 *
 * p represents the last point the user moved the mouse to.  We initialize it
 * to start before entering the tracking loop.
 *
 * Inside the loop, last represents the last point the user confirmed (by
 * clicking) as opposed to p, the last point the user moved to.  We update
 * last every time we start the segment tracking loop (the inner,
 * while (event->type != NSMouseUp) loop).
 *
 * In the segment tracking loop, r represents the rectangle which must be
 * redrawn to get rid of the last time we drew the segment we are currently
 * tracking.  After we [view drawSelf:&r :1] to clear out the last segment,
 * we recalculate the value of r for the next time around the loop.  Finally,
 * we draw ourselves (i.e. all the other segments besides the one we are
 * currently tracking) and then draw the segment we are currently tracking.
 *
 * After tracking the segment, we check to see if we are done.
 * We are finished if any of the following are true:
 *    1. The last segment the user created was smaller than a gridSpacing.
 *    2. The user clicked on the starting point (thereby closing the path).
 *    3. The mouse down is outside the view's bounds.
 *    4. A kit defined or system defined event comes through.
 *
 * If we are not done (or we need to close the path), then we store the
 * new point pair into points (reallocating our points
 * and userPathOps arrays if we are out of room).  We then update our bounding
 * box to reflect the new point and update our bounds to equal our bounding
 * box.  If we aren't done, we look for the next mouse down to begin the
 * tracking of another segment.
 *
 * After we are finished with all segments, we check to be sure that we have
 * at least two segments (one segment is a line, not a polygon).  If the
 * path is closed, then we need at least three segments.  If we have the
 * requisite number of segments, then we reallocate our arrays to fit exactly
 * our number of points and return YES.  Otherwise, we free the storage of
 * those arrays and clean up any drawing we did and return NO.
 */

#define POLYGON_MASK (NSLeftMouseDraggedMask|NSLeftMouseUpMask)
#define END_POLYGON_MASK (NSAppKitDefinedMask|NSLeftMouseDownMask|NSApplicationDefinedMask)

- (BOOL)create:(NSEvent *)event in:view
{
    float *pptr;
    NSRect viewBounds;
    NSPoint start, last, p;
    NSWindow *window = [view window];
    BOOL closepath, done = NO, resend = NO;
    float grid = (float)[view gridSpacing];
    int windowNum = [event windowNumber], arrow = 0;

    if (![view gridIsEnabled]) grid = 1.0;

    gFlags.initialized = YES;
    if (gFlags.arrow && gFlags.arrow != ARROW_AT_START) {
	arrow = gFlags.arrow;
	gFlags.arrow = (gFlags.arrow == ARROW_AT_END) ? 0 : ARROW_AT_START;
    }

    start = [event locationInWindow];
    start = [view convertPoint:start fromView:nil];
    start = [view grid:start];

    viewBounds = [view visibleRect];

    closepath = ([event modifierFlags] & NSAlternateKeyMask) ? NO : YES;

    length = 0;
    [self allocateChunk];
    pptr = points;
    *pptr++ = bbox[0] = bbox[2] = start.x;
    *pptr++ = bbox[1] = bbox[3] = start.y;
    userPathOps[0] = dps_moveto;

    [view lockFocus];

    [self setLineColor];
    PSsetlinewidth(linewidth);

    p = start;
    event = [window nextEventMatchingMask:POLYGON_MASK];
    while (!done) {
	last = p;
	if ([event type] == NSLeftMouseDown) {
	    if ([event clickCount] > 1) {
		done = YES;
		[window nextEventMatchingMask:NSLeftMouseUpMask];
	    } else if ([event windowNumber] != windowNum) {
		done = YES;
		resend = YES;
	    } else {
		p = [event locationInWindow];
		p = [view convertPoint:p fromView:nil];
		if (!NSMouseInRect(p, viewBounds, NO)) {
                    done = YES;
		    resend = YES;
		}
	    }
	} else if ([event type] == NSAppKitDefined || [event type] == NSSystemDefined) {
	    done = YES;
	    resend = YES;
	}
	if (!done) {
	    NSRect aRect = NSZeroRect;
	    while ([event type] != NSLeftMouseUp) {
		p = [event locationInWindow];
		p = [view convertPoint:p fromView:nil];
		p = [view grid:p];
		[view drawRect:aRect];
		aRect = NSRectFromBBox(p.x, p.y, last.x, last.y);
		[view scrollPointToVisible:p];
		aRect = NSInsetRect(aRect, -2.0, -2.0);
		[self draw];
		PSmoveto(last.x, last.y);
		PSlineto(p.x, p.y);
		PSstroke();
		[window flushWindow];
		event = [window nextEventMatchingMask:POLYGON_MASK];
	    }
	    if (fabs(p.x-start.x) <= grid && fabs(p.y-start.y) <= grid) {
		done = YES;
		closepath = YES;
	    }
	}
	if (!done || (closepath && length > 1)) {
	    if (done) p = start;
	    length++;
	    if (!(length % CHUNK_SIZE)) [self allocateChunk];
	    *pptr++ = p.x - last.x;
	    *pptr++ = p.y - last.y;
	    if (p.x < bbox[0]) bbox[0] = p.x;
	    if (p.x > bbox[2]) bbox[2] = p.x;
	    if (p.y < bbox[1]) bbox[1] = p.y;
	    if (p.y > bbox[3]) bbox[3] = p.y;
	    bounds = NSRectFromBBox(bbox[0], bbox[1], bbox[2], bbox[3]);
	    if (!done) event = [window nextEventMatchingMask:END_POLYGON_MASK];
	}
    }

    [view unlockFocus];

    if (resend) [NSApp postEvent:event atStart:YES];
    if (arrow) gFlags.arrow = arrow;

    if (length > (closepath ? 2 : 1)) {
	points = points = NSZoneRealloc([self zone], points, ((length+1) << 1) * sizeof(float));
	userPathOps = userPathOps = NSZoneRealloc([self zone], userPathOps, (length+1) * sizeof(char));
	return YES;
    } else {
	NSZoneFree([self zone], points); points = NULL;
	NSZoneFree([self zone], userPathOps); userPathOps = NULL;
	if (length) [view drawRect:[self extendedBounds]]; // clean up aborted Polygon
	return NO;
    }
}

- (Graphic *)colorAcceptorAt:(NSPoint)point
{
    return [self hit:point] ? self : nil;
}

@end

