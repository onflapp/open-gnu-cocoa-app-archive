#import "draw.h"

/* Optimally viewed in a wide window.  Make your window big enough so that this comment fits entirely on one line w/o wrapping. */

#define GROUP_CACHE_THRESHOLD 4

@implementation Group : Graphic
/*
 * This Graphic is used to create heirarchical groups of other Graphics.
 * It simply keeps a list of all the Graphics in the group and resizes
 * and translates them as the Group object itself is resized and moved.
 * It also passes messages sent to the Group onto its members.
 *
 * For efficiency, we cache the group whenever it passes the caching
 * threshold.  Thus, grouping becomes a tool to let the user have some
 * control over the memory/speed tradeoff (which can be different
 * depending on the kind of drawing the user is making).
 */

/* Factory method */

/* Initialization */

- initList:(NSMutableArray *)array
/*
 * Creates a new grouping with list containing the list of Graphics
 * in the group.  Groups of Groups is perfectly allowable.  We have
 * to keep track of the largest linewidth in the group as well as
 * whether any of the elements of the group have arrows since both
 * of those attributes affect the extended bounds of the Group.
 * We set any objects which might be cacheing (notably subgroups of
 * this group) to be not cacheable since it is no use for them to
 * cache themselves when we are caching them as well.  We also have
 * to check to see if there are any TextGraphic's in the group
 * because we can't cache ourselves if there are (unfortunately).
 */
{
    int i;
    NSRect r;
    Graphic *graphic;

    [super init];

    gFlags.mightBeLinked = YES;
    i = [array count];
    graphic = [array objectAtIndex:--i];
    bounds = [graphic bounds];
    gFlags.arrow = [graphic lineArrow];
    linewidth = [graphic lineWidth];
    bounds.size.width = MAX(1.0, bounds.size.width);
    bounds.size.height = MAX(1.0, bounds.size.height);
    while (i) {
	graphic = [array objectAtIndex:--i];
	r = [graphic bounds];
	[graphic setCacheable:NO];
	r.size.width = MAX(1.0, r.size.width);
	r.size.height = MAX(1.0, r.size.height);
	bounds = NSUnionRect(r, bounds);
	if (!gFlags.arrow && [graphic lineArrow]) gFlags.arrow = [graphic lineArrow];
	if ([graphic lineWidth] > linewidth) linewidth = [graphic lineWidth];
	if ([graphic isKindOfClass:[TextGraphic class]] || ([graphic isKindOfClass:[Group class]] && [(Group *)graphic hasTextGraphic])) hasTextGraphic = YES;
    }

    components = [[NSMutableArray alloc] initWithArray:array];
    lastRect = bounds;

    return self;
}

- (void)dealloc
{
    [components removeAllObjects];
    [components release];
    [cache release];
    [super dealloc];
}

/* Public methods */

- (void)transferSubGraphicsTo:(NSMutableArray *)array at:(int)position
/*
 * Called by Ungroup.  This just unloads the components into the
 * passed list, modifying the bounds of each of the Graphics
 * accordingly (remember that when a Graphic joins a Group, its
 * bounds are still kept in GraphicView coordinates (not
 * Group-relative coordinates), but they may be non-integral,
 * we can't allow non-integral bounds outside a group because
 * it conflicts with the compositing rules (and we use
 * compositing to move graphics around).
 */
{
    int i, count;
    Graphic *graphic;
    NSRect gbounds;
    BOOL zeroWidth, zeroHeight;

    count = [components count];
    for (i = (count - 1); i >= 0; i--) {
	graphic = [components objectAtIndex:i];
	gbounds = [graphic bounds];
	if (!gbounds.size.width) {
	    zeroWidth = YES;
	    gbounds.size.width = 1.0;
	} else zeroWidth = NO;
	if (!gbounds.size.height) {
	    zeroHeight = YES;
	    gbounds.size.height = 1.0;
	} else zeroHeight = NO;
	gbounds = NSIntegralRect(gbounds);
	if (zeroWidth) gbounds.size.width = 0.0;
	if (zeroHeight) gbounds.size.height = 0.0;
	[graphic setBounds:gbounds];
	[graphic setCacheable:YES];
	[array insertObject:graphic atIndex:position];
    } 
}

- (NSMutableArray *)subGraphics
{
    return components;
}

/* Group must override all the setting routines to forward to components */

- (void)makeGraphicsPerform:(SEL)aSelector with:(const void *)anArgument
{
    [components makeObjectsPerform:aSelector withObject:(id)anArgument];
    [cache release];
    cache = nil; 
}

- (void)changeFont:(id)sender
{
    [self makeGraphicsPerform:@selector(changeFont:) with:sender];
}

- (NSFont *)font
{
    int i;
    NSFont *gfont, *font = nil;

    i = [components count];
    while (i--) {
	gfont = [[components objectAtIndex:i] font];
	if (gfont) {
	    if (font && font != gfont) {
		font = nil;
		break;
	    } else {
		font = gfont;
	    }
	}
    }

    return font;
}

- (void)setLineWidth:(const float *)value
{
    return [self makeGraphicsPerform:@selector(setLineWidth:) with:value];
}

- (void)setGray:(const float *)value
{
    return [self makeGraphicsPerform:@selector(setGray:) with:value];
}

- (void)setFillColor:(NSColor *)aColor
{
    return [self makeGraphicsPerform:@selector(setFillColor:) with:aColor];
}

- (void)setFill:(int)mode
{
    return [self makeGraphicsPerform:@selector(setFill:) with:(void *)mode];
}

- (void)setLineColor:(NSColor *)aColor
{
    return [self makeGraphicsPerform:@selector(setLineColor:) with:aColor];
}

- (void)setLineCap:(int)value
{
    return [self makeGraphicsPerform:@selector(setLineCap:) with:(void *)value];
}

- (void)setLineArrow:(int)value
{
    return [self makeGraphicsPerform:@selector(setLineArrow:) with:(void *)value];
}

- (void)setLineJoin:(int)value
{
    return [self makeGraphicsPerform:@selector(setLineJoin:) with:(void *)value];
}

/* Link methods */

/*
 * Called after unarchiving and after a linkManager has been created for
 * the document this Graphic is in.  Graphic's implementation of this just
 * adds the link to the linkManager.
 */

- (void)reviveLink:(NSDataLinkManager *)linkManager
{
    [components makeObjectsPerform:@selector(reviveLink:) withObject:linkManager]; 
}

/*
 * This returns self if there is more than one linked Graphic in the Group.
 * If aLink is not nil, returns the Graphic which is linked by that link.
 * If aLink is nil, then it returns the one and only linked Graphic in the
 * group or nil otherwise.  Used when updating the link panel and when
 * redrawing link outlines.
 */

- (Graphic *)graphicLinkedBy:(NSDataLink *)aLink
{
    int i, linkCount = 0;
    Graphic *graphic = nil;

    for (i = [components count]-1; i >= 0; i--) {
	if ((graphic = [[components objectAtIndex:i] graphicLinkedBy:aLink])) {
	    if ([graphic isKindOfClass:[Group class]]) return graphic;
	    linkCount++;
	}
    }

    return (linkCount <= 1) ? graphic : self;
}

/*
 * When you copy/paste a Graphic, its identifier must be reset to something
 * different since you don't want the pasted one to have the same identifier
 * as the copied one!  See gvPasteboard.m.
 */

- (void)resetIdentifier
{
    [components makeObjectsPerform:@selector(resetIdentifier)]; 
}

/*
 * Used when creating an NSSelection representing all the Graphics
 * in a selection.  Has to recurse through Groups because you still
 * want the NSSelection to be valid even if the Graphics are ungrouped
 * in the interim between the time the selection is determined to the
 * time the links stuff asks questions about the selection later.
 */

- (NSString *)identifierString
{
    int i = [components count];
    NSMutableString *retval = [NSMutableString stringWithFormat:@"%d", identifier];
    while (i--) [retval appendFormat:@" %@", [[components objectAtIndex:i] identifierString]];
    return retval;
}

/*
 * See the method findGraphicInSelection: in gvLinks.m to see how this
 * method is used (it basically just lets you get back to a Graphic
 * from its identifier whether its in a Group or not).
 */

- (Graphic *)graphicIdentifiedBy:(int)anIdentifier
{
    int i;

    if (anIdentifier == identifier) return self;

    i = [components count];
    while (i--) {
	Graphic *graphic = [components objectAtIndex:i];
	if ((graphic = [graphic graphicIdentifiedBy:anIdentifier])) return graphic;
    }
    return nil;
}

/*
 * We pass this method onto all the things inside the group since
 * there might be linked things inside the group.
 */

- (void)readLinkFromPasteboard:(NSPasteboard *)pboard usingManager:(NSDataLinkManager *)linkManager useNewIdentifier:(BOOL)useNewIdentifier
{
    int i = [components count];
    while (i--) {
	Graphic *graphic = [components objectAtIndex:i];
	if ([graphic mightBeLinked]) [graphic readLinkFromPasteboard:pboard usingManager:linkManager useNewIdentifier:useNewIdentifier];
    }
}

/* Form Entry methods.  See TextGraphic.m for details. */

- (BOOL)hasFormEntries
{
    int i = [components count];
    while (i--) if ([[components objectAtIndex:i] hasFormEntries]) return YES;
    return NO;
}

- (BOOL)writeFormEntryToMutableString:(NSMutableString *)string
{
    BOOL retval = NO;
    int i = [components count];

    while (i--) {
        if ([[components objectAtIndex:i] writeFormEntryToMutableString:string]) {
            retval = YES;
        }
    }

    return retval;
}

- (BOOL)writesFiles
{
    int i = [components count];
    while (i--) if ([[components objectAtIndex:i] writesFiles]) return YES;
    return NO;
}

- (void)writeFilesToDirectory:(NSString *)directory
{
    int i = [components count];
    while (i--) [[components objectAtIndex:i] writeFilesToDirectory:directory];
}

/* Notification methods */

- (void)wasRemovedFrom:(GraphicView *)sender
{
    [components makeObjectsPerform:@selector(wasRemovedFrom:) withObject:sender];
    [cache release];
    cache = nil; 
}

- (void)wasAddedTo:(GraphicView *)sender
{
    [components makeObjectsPerform:@selector(wasAddedTo:) withObject:sender]; 
}

/* Color drag-and-drop support. */

- (Graphic *)colorAcceptorAt:(NSPoint)point
{
    int i, count;
    Graphic *graphic;

    count = [components count];
    for (i = 0; i < count; i++) {
	if ((graphic = [[components objectAtIndex:i] colorAcceptorAt:point])) return graphic;
    }

    return nil;
}

/* We can't cache ourselves if we have a TextGraphic in the Group. */

- (BOOL)hasTextGraphic
{
    return hasTextGraphic;
}

- (void)setCacheable:(BOOL)flag
/*
 * Sets whether we do caching of this Group or not.
 */
{
    dontCache = flag ? NO : YES;
    if (dontCache) {
	[cache release];
	cache = nil;
    } 
}

- (BOOL)isCacheable
{
    return !hasTextGraphic && !dontCache;
}

- draw
/*
 * Individually scales and translates each Graphic in the group and draws
 * them.  This is done this way so that ungrouping is trivial.  Note that
 * if we are caching, we need to take the extra step of translating
 * everything to the origin, drawing them in the cache, then translating
 * them back.
 */
{
    int i;
    Graphic *g;
    NSRect eb;
    NSRect b;
    float sx = 1.0, sy = 1.0, tx, ty;
    BOOL changed, changedSize, caching = NO;

    if (bounds.size.width < 1.0 || bounds.size.height < 1.0 || !components) return self;

    changedSize = lastRect.size.width != bounds.size.width || lastRect.size.height != bounds.size.height;
    changed = changedSize || lastRect.origin.x != bounds.origin.x || lastRect.origin.y != bounds.origin.y;

    if ((changedSize || !cache) && [[NSDPSContext currentContext] isDrawingToScreen]) {
	[cache release];
	cache = nil;
	if (DrawStatus != Resizing && [self isCacheable] && [components count] > GROUP_CACHE_THRESHOLD) {
	    caching = YES;
	    eb = [self extendedBounds];
	    cache = [[NSImage allocWithZone:(NSZone *)[self zone]] initWithSize:eb.size];
	    [cache lockFocus];
	    PStranslate(- eb.origin.x, - eb.origin.y);
	    PSsetalpha(0.0);
	    PSsetgray(NSWhite);
	    NSRectFill(eb);
	    PSsetalpha(1.0);
	}
    }

    if (changedSize) {
	sx = bounds.size.width / lastRect.size.width;
	sy = bounds.size.height / lastRect.size.height;
    }

    i = [components count];
    while (i) {
	g = [components objectAtIndex:--i];
	if (changed) {
	    b = [g bounds];
	    tx = (bounds.origin.x + ((b.origin.x - lastRect.origin.x) / lastRect.size.width * bounds.size.width)) - b.origin.x;
	    ty = (bounds.origin.y + ((b.origin.y - lastRect.origin.y) / lastRect.size.height * bounds.size.height)) - b.origin.y;
	    b.origin.x = b.origin.x + tx;
	    b.origin.y = b.origin.y + ty;
	    b.size.width = b.size.width * sx;
	    b.size.height = b.size.height * sy;
	    [g setBounds:b];
	}
	if (![[NSDPSContext currentContext] isDrawingToScreen] || !cache || caching) {
	    [g setGraphicsState];	/* does a gsave ... */
	    [g draw];
	    PSgrestore();		/* ... so we need this grestore */
	}
    }

    if (cache && [[NSDPSContext currentContext] isDrawingToScreen]) {
	if (caching) {
	    [cache unlockFocus];
	} else {
	    eb = [self extendedBounds];
	}
	[cache compositeToPoint:eb.origin operation:NSCompositeSourceOver];
    }

    lastRect = bounds;

    return self;
}

- (BOOL)hit:(NSPoint)point
/*
 * Gets a hit if any of the items in the group gets a hit.
 */
{
    int i;
    NSPoint p;
    float px, py;
    Graphic *graphic;

    if ([super hit:point]) {
	if (components) {
	    p = point;
	    px = (p.x - bounds.origin.x) / bounds.size.width;
	    p.x = px * lastRect.size.width + lastRect.origin.x;
	    py = (p.y - bounds.origin.y) / bounds.size.height;
	    p.y = py * lastRect.size.height + lastRect.origin.y;
	    i = [components count];
	    while (i) {
		graphic = [components objectAtIndex:--i];
		if ([graphic hit:p]) return YES;
	    }
	} else {
	    return YES;
	}
    }

    return NO;
}

/* Archiving methods */

#define COMPONENTS_KEY @"Components"

- (void)convertSelf:(ConversionDirection)direction propertyList:(id)plist
{
    [super convertSelf:direction propertyList:plist];
    PL_FLAG(plist, dontCache, @"DontCache", direction);
    PL_FLAG(plist, hasTextGraphic, @"HasTextGraphic", direction);
    PL_RECT(plist, lastRect, @"LastPosition", direction);
}

- (id)propertyList
{
    NSMutableDictionary *plist = [super propertyList];
    [plist setObject:propertyListFromArray(components) forKey:COMPONENTS_KEY];
    return plist;
}

- (NSString *)description
{
    NSMutableDictionary *plist = [super propertyList];
    [plist setObject:components forKey:COMPONENTS_KEY]; // don't expand for description
    return [plist description];
}

- initFromPropertyList:(id)plist inDirectory:(NSString *)directory
{
    [super initFromPropertyList:plist inDirectory:directory];
    components = arrayFromPropertyList([plist objectForKey:COMPONENTS_KEY], directory, [self zone]);
    return self;
}

@end
