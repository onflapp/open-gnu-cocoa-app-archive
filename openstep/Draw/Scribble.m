#import "draw.h"

/*
 * This line is just a stub to get genstrings to generate
 * a .strings file entry for the name of this type of Graphic.
 * The name is used in the Undo New <Whatever> menu item.
 *
 * NSLocalString("Scribble", NULL, "Name of the tool that draws scribbles, i.e., the %@ of the New %@ operation.")
 */

@implementation Scribble : Graphic

static NSPoint lastPoint;	/* used in creating only */

+ (NSCursor *)cursor
/*
 * A Scribble uses a pencil as its cursor.
 */
{
    NSPoint spot;
    static NSCursor *cursor = nil;

    if (!cursor) {
	spot.x = 0.0; spot.y = 15.0;
	cursor = [[NSCursor alloc] initWithImage:[NSImage imageNamed:@"Pencil.tiff"] hotSpot:spot];
    }

    return cursor ? cursor : [super cursor];
}

- (void)dealloc
{
    NSZoneFree([self zone], points);
    NSZoneFree([self zone], userPathOps);
    [super dealloc];
}

- (void)allocateChunk
/*
 * The Scribble's storage is allocated in chunks.
 * This allocates another chunk.
 */
{
    int i, newSize;

    newSize = length + CHUNK_SIZE;
    if (points) {
	points = NSZoneRealloc((NSZone *)[self zone], points, (newSize << 1) * sizeof(float));
	userPathOps = NSZoneRealloc((NSZone *)[self zone], userPathOps, (newSize) * sizeof(char));
    } else {
	points = NSZoneMalloc((NSZone *)[self zone], (newSize << 1) * sizeof(float));
	userPathOps = NSZoneMalloc((NSZone *)[self zone], (newSize) * sizeof(char));
    }
    for (i = newSize - 1; i >= length; i--) {
	userPathOps[i] = dps_rlineto;
    } 
}

- (float)naturalAspectRatio
/*
 * The Scribble's natural aspect ratio is the one it was created with.
 */
{
    return (gFlags.initialized ? ((bbox[2]-bbox[0])/(bbox[3]-bbox[1])) : 0.0);
}

- (int)moveCorner:(int)corner to:(NSPoint)point constrain:(BOOL)flag
/*
 * After the Scribble is created (gFlags.initialized == YES), this method
 * just returns super's implementation.  During creation, every time the
 * "corner" is moved, a new line segment is added to the Scribble and
 * the bounding box is expanded if necessary.
 */
{
    float *p;

    if (gFlags.initialized) {
	return [super moveCorner:corner to:point constrain:flag];
    }

    if (!(point.x - lastPoint.x || point.y - lastPoint.y)) return corner;

    length++;

    if (!(length % CHUNK_SIZE)) [self allocateChunk];

    p = points + (length << 1);
    *p++ = point.x - lastPoint.x;
    *p = point.y - lastPoint.y;
    lastPoint = point;

    bbox[2] = MAX(point.x, bbox[2]);
    bbox[0] = MIN(point.x, bbox[0]);
    bbox[3] = MAX(point.y, bbox[3]);
    bbox[1] = MIN(point.y, bbox[1]);

    bounds.origin.x = bbox[0];
    bounds.origin.y = bbox[1];
    bounds.size.width = bbox[2] - bbox[0];
    bounds.size.height = bbox[3] - bbox[1];

    return corner;
}


- (BOOL)create:(NSEvent *)event in:view
/*
 * Before creating, an initial chunk is initialized, and the userPathOps
 * are initialized.  The lastPoint is also remembered as the start point.
 * After the Scribble is created, the initialized flag is set.
 */
{
    NSPoint p;

    [self allocateChunk];
    userPathOps[0] = dps_moveto;    
    p = [event locationInWindow];
    p = [view convertPoint:p fromView:nil];
    p = [view grid:p];
    points[0] = p.x;
    points[1] = p.y;
    lastPoint = p;
    bbox[0] = bbox[2] = p.x;
    bbox[1] = bbox[3] = p.y;
    bounds.origin = p;
    bounds.size.width = bounds.size.height = 0.0;

    if ([super create:event in:view]) {
	gFlags.initialized = YES;
	return YES;
    }

    return NO;
}


- draw
/*
 * The Scribble is drawn simply by scaling appropriately from its
 * initial bounding box and drawing the user path.
 */
{
    float x, y;
    NSPoint p1, p2;
    int i, count, coords;
    float angle, sx, sy, tx, ty;

    if (bounds.size.width < 1.0 || bounds.size.height < 1.0) return self;

    if (length && (bbox[2] - bbox[0]) && (bbox[3] - bbox[1])) {
	sx = bounds.size.width / (bbox[2] - bbox[0]);
	sy = bounds.size.height / (bbox[3] - bbox[1]);
	tx = (bounds.origin.x +
	      ((points[0]-bbox[0]) / (bbox[2]-bbox[0]) * bounds.size.width)) - points[0] * sx;
	ty = (bounds.origin.y +
	      ((points[1]-bbox[1]) / (bbox[3]-bbox[1]) * bounds.size.height)) - points[1] * sy;
	if (gFlags.arrow && ![self fill] && (sx != 1.0 || sy != 1.0 || tx || ty)) {
	    PSgsave();
	}
	if ([self fill]) {
	    PSgsave();
	    PStranslate(tx, ty);
	    PSscale(sx, sy);
	    [self setFillColor];
	    PSDoUserPath(points, (length + 1) << 1, dps_float, userPathOps, length + 1, bbox, gFlags.eofill ? dps_ueofill : dps_ufill);
	    PSgrestore();
	}
	if (!gFlags.nooutline) {
	    PStranslate(tx, ty);
	    PSscale(sx, sy);
	    [self setLineColor];
	    PSDoUserPath(points, (length + 1) << 1, dps_float, userPathOps, length + 1, bbox, dps_ustroke);
	}
	if (gFlags.arrow && ![self fill]) {
	    if (sx != 1.0 || sy != 1.0 || tx || ty) {
		PSgrestore();
		[self setLineColor];
	    }
	    if (gFlags.arrow != ARROW_AT_END) {
		i = 0;
		p1.x = points[i++];
		p1.y = points[i++];
		p2 = p1;
		p2.x += points[i++];
		p2.y += points[i++];
		count = length - 1;
		while (sqrt(((p1.x-p2.x)*sx)*((p1.x-p2.x)*sx) + ((p1.y-p2.y)*sy)*((p1.y-p2.y)*sy)) < 7.0 && count--) {	// no hypot on Windows?
		    p2.x += points[i++];
		    p2.y += points[i++];
		}
		angle = atan2((p1.y-p2.y)*sy, (p1.x-p2.x)*sx);
		angle = (angle / 3.1415) * 180.0;
		x = bounds.origin.x + (p1.x - bbox[0]) * sx;
		y = bounds.origin.y + (p1.y - bbox[1]) * sy;
		PSArrow(x, y, angle);
	    }
	    if (gFlags.arrow != ARROW_AT_START) {
		i = 0;
		coords = (length + 1) << 1;
		p1.x = points[i++];
		p1.y = points[i++];
		while (i < coords) {
		    p1.x += points[i++];
		    p1.y += points[i++];
		}
		p2 = p1;
		i = coords;
		p2.y -= points[--i];
		p2.x -= points[--i];
		count = length - 1;
		while (sqrt(((p2.x-p1.x)*sx)*((p2.x-p1.x)*sx) + ((p2.y-p1.y)*sy)*((p2.y-p1.y)*sy)) < 7.0 && count--) {	// no hypot on Windows?
		    p2.y -= points[--i];
		    p2.x -= points[--i];
		}
		angle = atan2((p1.y-p2.y)*sy, (p1.x-p2.x)*sx);
		angle = (angle / 3.1415) * 180.0;
		x = bounds.origin.x + (p1.x - bbox[0]) * sx;
		y = bounds.origin.y + (p1.y - bbox[1]) * sy;
		PSArrow(x, y, angle);
	    }
	}
    }

    return self;
}

/* Archiving */

#define LENGTH_KEY @"NumberOfPoints"
#define BBOX_KEY @"BoundingBox"
#define DATA_KEY @"Points"

- (id)propertyList
{
    int i, numFloats;
    NSMutableArray *floatArray;
    NSMutableDictionary *plist;
    NSRect bboxRect;

    plist = [super propertyList];
    bboxRect.origin.x = bbox[0]; bboxRect.origin.y = bbox[1];
    bboxRect.size.width = bbox[2]; bboxRect.size.height = bbox[3];
    [plist setObject:propertyListFromNSRect(bboxRect) forKey:BBOX_KEY];
    [plist setObject:propertyListFromInt(length) forKey:LENGTH_KEY];
    numFloats = (length + 1) << 1;
    floatArray = [NSMutableArray arrayWithCapacity:numFloats];
    for (i = 0; i < numFloats; i++) {
        [floatArray addObject:propertyListFromFloat(points[i])];
    }
    [plist setObject:floatArray forKey:DATA_KEY];

    return plist;
}

- (NSString *)description
{
    NSMutableDictionary *plist;
    NSRect bboxRect;

    plist = [super propertyList];
    bboxRect.origin.x = bbox[0]; bboxRect.origin.y = bbox[1];
    bboxRect.size.width = bbox[2]; bboxRect.size.height = bbox[3];
    [plist setObject:propertyListFromNSRect(bboxRect) forKey:BBOX_KEY];
    [plist setObject:propertyListFromInt(length) forKey:LENGTH_KEY];
    // should we report the points here too?

    return [plist description];
}

- initFromPropertyList:(id)plist inDirectory:(NSString *)directory
{
    NSEnumerator *enumerator;
    NSArray *floatArray;
    float *p;
    int i;
    NSRect bboxRect;

    [super initFromPropertyList:plist inDirectory:directory];
    bboxRect = rectFromPropertyList([plist objectForKey:BBOX_KEY]);
    bbox[0] = bboxRect.origin.x; bbox[1] = bboxRect.origin.y;
    bbox[2] = bboxRect.size.width; bbox[3] = bboxRect.size.height;
    length = [[plist objectForKey:LENGTH_KEY] intValue];
    floatArray = [plist objectForKey:DATA_KEY];
    points = NSZoneMalloc((NSZone *)[self zone], ((length + 1) << 1) * sizeof(float));
    userPathOps = NSZoneMalloc((NSZone *)[self zone], (length + 1) * sizeof(char));
    p = points;
    enumerator = [floatArray objectEnumerator];
    for (i = 0; i <= length; i++) {
        *p++ = [[enumerator nextObject] floatValue];
        *p++ = [[enumerator nextObject] floatValue];
        userPathOps[i] = dps_rlineto;
    }
    userPathOps[0] = dps_moveto;

    return self;
}

@end

