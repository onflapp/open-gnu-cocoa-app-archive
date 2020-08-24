#import "draw.h"

@implementation Graphic : NSObject

static int KNOB_WIDTH = 0.0;
static int KNOB_HEIGHT = 0.0;

#define MINSIZE 5.0	/* minimum size of a Graphic */

NSCursor *CrossCursor = nil;	/* global since subclassers may need it */

/* Optimization method. */

/*
 * The fastKnobFill optimization just keeps a list of black and dark gray
 * rectangles (the knobbies are made out of black and dark gray rectangles)
 * and emits them in a single NSRectFillList() which is much faster than
 * doing individual rectfills (we also save the repeated setgrays).
 */

static NSRect *blackRectList = NULL;
static int blackRectSize = 0;
static int blackRectCount = 0;
static NSRect *dkgrayRectList = NULL;
static int dkgrayRectSize = 0;
static int dkgrayRectCount = 0;

+ fastKnobFill:(NSRect)aRect isBlack:(BOOL)isBlack
{
    if (isBlack) {
	if (!blackRectList) {
	    blackRectSize = 16;
	    blackRectList = NSZoneMalloc((NSZone *)[(NSObject *)NSApp zone], (blackRectSize) * sizeof(NSRect));
	} else {
	    while (blackRectCount >= blackRectSize) blackRectSize <<= 1;
	    blackRectList = NSZoneRealloc((NSZone *)[(NSObject *)NSApp zone], blackRectList, (blackRectSize) * sizeof(NSRect));
	}
	blackRectList[blackRectCount++] = aRect;
    } else {
	if (!dkgrayRectList) {
	    dkgrayRectSize = 16;
	    dkgrayRectList = NSZoneMalloc((NSZone *)[(NSObject *)NSApp zone], (dkgrayRectSize) * sizeof(NSRect));
	} else {
	    while (dkgrayRectCount >= dkgrayRectSize) dkgrayRectSize <<= 1;
	    dkgrayRectList = NSZoneRealloc((NSZone *)[(NSObject *)NSApp zone], dkgrayRectList, (dkgrayRectSize) * sizeof(NSRect));
	}
	dkgrayRectList[dkgrayRectCount++] = aRect;
    }

    return self;
}

+ (void)showFastKnobFills
{
    if (blackRectCount)  {
	PSsetgray(NSBlack);
	NSRectFillList(blackRectList, blackRectCount);
    }
    if (dkgrayRectCount)  {
	PSsetgray(NSDarkGray);
	NSRectFillList(dkgrayRectList, dkgrayRectCount);
    }
    blackRectCount = 0;
    dkgrayRectCount = 0;
}

/* Factory methods. */

+ (BOOL)isEditable
/*
 * Any Graphic which can be edited should return YES from this
 * and its instances should do something in the response to the
 * edit:in: method.
 */
{
    return NO;
}

+ (NSCursor *)cursor
/*
 * Any Graphic that doesn't have a special cursor gets the default cross.
 */
{
    NSPoint spot;

    if (!CrossCursor) {
	spot.x = 7.0; spot.y = 7.0;
	CrossCursor = [[NSCursor alloc] initWithImage:[NSImage imageNamed:@"Cross.tiff"] hotSpot:spot];
    }

    return CrossCursor;
}

+ (void)initClassVars
{
    NSString *value;
    float w = 2.0, h = 2.0;

    if (!KNOB_WIDTH) {
	value = [[NSUserDefaults standardUserDefaults] objectForKey:@"KnobWidth"];
	if (value) w = floor(atof([value cString]) / 2.0);
	value = [[NSUserDefaults standardUserDefaults] objectForKey:@"KnobHeight"];
	if (value) h = floor(atof([value cString]) / 2.0);
	w = MAX(w, 1.0); h = MAX(h, 1.0);
	KNOB_WIDTH = w * 2.0 + 1.0;	/* size must be odd */
	KNOB_HEIGHT = h * 2.0 + 1.0;
    }
}

/*
 * The currentGraphicIdentifier is a number that is kept unique for a given
 * Draw document by being monotonically increasing and is bumped each time a
 * new Graphic is created.  The method of the same name is used during the
 * archiving of a Draw document to write out what the number is at save-time.
 * updateCurrentGraphicIdentifer: is used at document load time to reset
 * the number to that level (if it's already higher, then we don't need to
 * bump it).
 */

static int currentGraphicIdentifier = 1;

+ (int)currentGraphicIdentifier
{
    return currentGraphicIdentifier;
}

+ (int)nextCurrentGraphicIdentifier
{
    return currentGraphicIdentifier++;
}

+ (void)updateCurrentGraphicIdentifier:(int)newMaxIdentifier
{
    if (newMaxIdentifier > currentGraphicIdentifier) currentGraphicIdentifier = newMaxIdentifier;
}

- (id)init
{
    [super init];
    gFlags.active = YES;
    gFlags.selected = YES;
    [[self class] initClassVars];
    identifier = currentGraphicIdentifier++;
    return self;
}

/* Private C functions and macros used to implement methods in this class. */

static void drawKnobs(NSRect knob, int cornerMask, BOOL black)
/*
 * Draws either the knobs or their shadows (not both).
 */
{
    float dx, dy;
    BOOL oddx, oddy;

    dx = knob.size.width / 2.0;
    dy = knob.size.height / 2.0;
    oddx = (floor(dx) != dx);
    oddy = (floor(dy) != dy);
    knob.size.width = KNOB_WIDTH;
    knob.size.height = KNOB_HEIGHT;
    knob.origin.x -= ((KNOB_WIDTH - 1.0) / 2.0);
    knob.origin.y -= ((KNOB_HEIGHT - 1.0) / 2.0);

    if (cornerMask & LOWER_LEFT_MASK) [Graphic fastKnobFill:knob isBlack:black];
    knob.origin.y += dy;
    if (oddy) knob.origin.y -= 0.5;
    if (cornerMask & LEFT_SIDE_MASK) [Graphic fastKnobFill:knob isBlack:black];
    knob.origin.y += dy;
    if (oddy) knob.origin.y += 0.5;
    if (cornerMask & UPPER_LEFT_MASK) [Graphic fastKnobFill:knob isBlack:black];
    knob.origin.x += dx;
    if (oddx) knob.origin.x -= 0.5;
    if (cornerMask & TOP_SIDE_MASK) [Graphic fastKnobFill:knob isBlack:black];
    knob.origin.x += dx;
    if (oddx) knob.origin.x += 0.5;
    if (cornerMask & UPPER_RIGHT_MASK) [Graphic fastKnobFill:knob isBlack:black];
    knob.origin.y -= dy;
    if (oddy) knob.origin.y -= 0.5;
    if (cornerMask & RIGHT_SIDE_MASK) [Graphic fastKnobFill:knob isBlack:black];
    knob.origin.y -= dy;
    if (oddy) knob.origin.y += 0.5;
    if (cornerMask & LOWER_RIGHT_MASK) [Graphic fastKnobFill:knob isBlack:black];
    knob.origin.x -= dx;
    if (oddx) knob.origin.x += 0.5;
    if (cornerMask & BOTTOM_SIDE_MASK) [Graphic fastKnobFill:knob isBlack:black];
}

/* Private methods sometimes overridden by subclassers */

- (void)setGraphicsState
/*
 * Emits a gsave, must be balanced by grestore.
 */
{
    PSSetParameters(gFlags.linecap, gFlags.linejoin, linewidth); 
}

- (void)setLineColor
{
    if (lineColor) {
	[lineColor set];
    } else {
	[[NSColor blackColor] set];
    } 
}

- (void)setFillColor
{
    if (fillColor) [fillColor set]; 
}

- (int)cornerMask
/*
 * Returns a mask of the corners which should have a knobby in them.
 */
{
    return ALL_CORNERS;
}

/* Data link methods -- see Links.rtf and gvLinks.m for more info */

/*
 * Most Graphics aren't linked (i.e. their visual display is
 * not determined by some other document).  See Image and
 * TextGraphic for examples of Graphics that sometimes do.
 */

- (void)setLink:(NSDataLink *)aLink
{
}

- (NSDataLink *)link
{
    return nil;
}

- (Graphic *)graphicLinkedBy:(NSDataLink *)aLink
/*
 * The reason we implement this method (instead of just relying on
 * saying if ([graphic link] == aLink)) is for the sake of Group
 * objects which may have a linked Graphic embedded in them.
 */
{
    NSDataLink *link = [self link];

    if (link) {
	if (!aLink) {	/* !aLink means any link */
	    return ([link disposition] != NSLinkBroken) ? self : nil;
	} else {
	    return (aLink == link) ? self : nil;
	}
    }

    return nil;
}

- (void)reviveLink:(NSDataLinkManager *)linkManager
/*
 * We never archive link information (but, of course, the unique identifer
 * is always archived with a Graphic).  Thus, when our document is reloaded,
 * we just asked the NSDataLinkManager which NSDataLink object is associated
 * with the NSSelection which represents this Graphic.
 */
{
    if (![self link]) [self setLink:[linkManager destinationLinkWithSelection:[self selection]]]; 
}

- (NSSelection *)selection
/*
 * Just creates an NSSelection "bag o' bits" with our unique identifier in it.
 */
{
    NSString *identstring = [NSString stringWithFormat:@"%d %d\0", ByGraphic, [self identifier]];
    return [[NSSelection allocWithZone:[self zone]] initWithDescriptionData:[identstring dataUsingEncoding:NSASCIIStringEncoding]];
}

- (BOOL)mightBeLinked
/*
 * This is set whenever our Graphic has a link set in it.
 * It is never cleared.
 * We use it during copy/paste to determine whether we have
 * to check with the data link manager to possibly reestablish
 * a link to this object.
 */
{
    return gFlags.mightBeLinked;
}

- (void)readLinkFromPasteboard:(NSPasteboard *)pboard usingManager:(NSDataLinkManager *)linkManager useNewIdentifier:(BOOL)useNewIdentifier
/*
 * This is called by pasteFromPasteboard: when we paste a Graphic (i.e. copied/pasted from
 * another Draw document) in case that Graphic was linked to something when it was copied.
 * Since we called writeLinksToPasteboard: when we put the Graphic into the pasteboard (see
 * writeLinkToPasteboard:types: above) we can simply retrieve all the link information for
 * that graphic by using the linkManager method addLinkPreviouslyAt:fromPasteboard:at:.
 */
{
    NSDataLink *link;
    NSSelection *oldSelection, *newSelection;

    oldSelection = [self selection];
    if (linkManager && oldSelection) {
	if (useNewIdentifier) [self resetIdentifier];
	newSelection = [self selection];
	link = [linkManager addLinkPreviouslyAt:oldSelection
			         fromPasteboard:pboard
					     at:newSelection];
	[self setLink:link];
    }
}

/* Notification messages */

/*
 * These methods are sent when a Graphic is added to or removed
 * from a GraphicView (respectively).  Currently we only use them
 * to break and reestablish links if any.
 */

- (void)wasAddedTo:(GraphicView *)sender
{
    NSDataLink *link;
    NSDataLinkManager *linkManager;

    if ((linkManager = [sender linkManager]) && (link = [self link])) {
	if ([link disposition] == NSLinkBroken) {
	    [linkManager addLink:link at:[self selection]];
	}
    } 
}

- (void)wasRemovedFrom:(GraphicView *)sender
{
    [[self link] break]; 
}

/* Methods for uniquely identifying a Graphic. */

- (void)resetIdentifier
{
    identifier = currentGraphicIdentifier++; 
}

- (NSString *)identifierString
/*
 * This method is necessary to support a Group which never writes out
 * its own identifier, but, instead has its components each write out
 * their own identifier.
 */
{
    return [NSString stringWithFormat:@"%d", identifier];
}

- (int)identifier
{
    return identifier;
}

- (Graphic *)graphicIdentifiedBy:(int)anIdentifier
{
    return (identifier == anIdentifier) ? self : nil;
}

/* Event handling */

- (BOOL)handleEvent:(NSEvent *)event at:(NSPoint)p inView:(NSView *)view
/*
 * Currently the only Graphic's that handle events are Image Graphic's that
 * are linked to something else (they follow the link on double-click and
 * the track the mouse for link buttons, for example).  This method should
 * return YES only if it tracked the mouse until it went up.
 */
{
    return NO;
}

/* Public routines mostly called by GraphicView's. */

- (NSString *)title
{
    return NSLocalizedString( [(NSObject *)[self class] description], nil );
}

- (BOOL)isSelected
{
    return gFlags.selected;
}

- (BOOL)isActive
{
    return gFlags.active;
}

- (BOOL)isCached
{
    return !gFlags.notCached;
}

- (BOOL)isLocked
{
    return gFlags.locked;
}

- (void)select
{
    gFlags.selected = YES; 
}

- (void)deselect
{
    gFlags.selected = NO; 
}

- (void)activate
/*
 * Activation is used to *temporarily* take a Graphic out of the GraphicView.
 */
{
    gFlags.active = YES; 
}

- (void)deactivate
{
    gFlags.active = NO;
}

- (void)lockGraphic
/*
 * A locked graphic cannot be selected, resized or moved.
 */
{
    gFlags.locked = YES; 
}

- (void)unlockGraphic
{
    gFlags.locked = NO; 
}

/* See TextGraphic for more info about form entries. */

- (BOOL)isFormEntry
{
    return NO;
}

- (void)setFormEntry:(int)flag
{
}

- (BOOL)hasFormEntries
{
    return NO;
}

- (BOOL)writeFormEntryToMutableString:(NSMutableString *)aString;
{
    return NO;
}

- (BOOL)writesFiles
{
    return NO;
}

- (void)writeFilesToDirectory:(NSString *)directory
{
}

/* See Group and Image for more info about cacheability. */

- (void)setCacheable:(BOOL)flag
{
}

- (BOOL)isCacheable
{
    return YES;
}

/* Getting and setting the bounds. */

- (NSRect)bounds
{
    NSRect theRect;
    theRect = bounds;
    return theRect;
}

- (void)setBounds:(NSRect)aRect
{
    bounds = aRect; 
}

- (NSRect)extendedBounds
/*
 * Returns, by reference, the rectangle which encloses the Graphic
 * AND ITS KNOBBIES and its increased line width (if appropriate).
 */
{
    NSRect returnRect;
    
    if (bounds.size.width < 0.0) {
	returnRect.origin.x = bounds.origin.x + bounds.size.width;
	returnRect.size.width = - bounds.size.width;
    } else {
	returnRect.origin.x = bounds.origin.x;
	returnRect.size.width = bounds.size.width;
    }
    if (bounds.size.height < 0.0) {
	returnRect.origin.y = bounds.origin.y + bounds.size.height;
	returnRect.size.height = - bounds.size.height;
    } else {
	returnRect.origin.y = bounds.origin.y;
	returnRect.size.height = bounds.size.height;
    }

    returnRect.size.width = MAX(1.0, returnRect.size.width);
    returnRect.size.height = MAX(1.0, returnRect.size.height);

    returnRect = NSInsetRect(returnRect, - ((KNOB_WIDTH - 1.0) + linewidth + 1.0), - ((KNOB_HEIGHT - 1.0) + linewidth + 1.0));

    if (gFlags.arrow) {
	if (linewidth) {
	    returnRect = NSInsetRect(returnRect, - linewidth * 2.5, - linewidth * 2.5);
	} else {
	    returnRect = NSInsetRect(returnRect, - 13.0, - 13.0);
	}
    }

    returnRect = NSIntegralRect(returnRect);

    return returnRect;
}

- (int)knobHit:(NSPoint)p
/*
 * Returns 0 if point is in bounds, and Graphic isOpaque, and no knobHit.
 * Returns -1 if outside bounds or not opaque or not active.
 * Returns corner number if there is a hit on a corner.
 * We have to be careful when the bounds are off an odd size since the
 * knobs on the sides are one pixel larger.
 */
{
    NSRect eb;
    NSRect knob;
    float dx, dy;
    BOOL oddx, oddy;
    int cornerMask = [self cornerMask];

    eb = [self extendedBounds];

    if (!gFlags.active) {
	return -1;
    } else if (!gFlags.selected) {
        return (NSMouseInRect(p, bounds, NO) && [self isOpaque]) ? 0 : -1;
    } else {
        if (!NSMouseInRect(p, eb, NO)) return -1;
    }

    knob = bounds;
    dx = knob.size.width / 2.0;
    dy = knob.size.height / 2.0;
    oddx = (floor(dx) != dx);
    oddy = (floor(dy) != dy);
    knob.size.width = KNOB_WIDTH;
    knob.size.height = KNOB_HEIGHT;
    knob.origin.x -= ((KNOB_WIDTH - 1.0) / 2.0);
    knob.origin.y -= ((KNOB_HEIGHT - 1.0) / 2.0);

    if ((cornerMask & LOWER_LEFT_MASK) && NSMouseInRect(p, knob, NO))
	return(LOWER_LEFT);
    knob.origin.y += dy;
    if (oddy) knob.origin.y -= 0.5;
    if ((cornerMask & LEFT_SIDE_MASK) && NSMouseInRect(p, knob, NO))
	return(LEFT_SIDE);
    knob.origin.y += dy;
    if (oddy) knob.origin.y += 0.5;
    if ((cornerMask & UPPER_LEFT_MASK) && NSMouseInRect(p, knob, NO))
	return(UPPER_LEFT);
    knob.origin.x += dx;
    if (oddx) knob.origin.x -= 0.5;
    if ((cornerMask & TOP_SIDE_MASK) && NSMouseInRect(p, knob, NO))
	return(TOP_SIDE);
    knob.origin.x += dx;
    if (oddx) knob.origin.x += 0.5;
    if ((cornerMask & UPPER_RIGHT_MASK) && NSMouseInRect(p, knob, NO))
	return(UPPER_RIGHT);
    knob.origin.y -= dy;
    if (oddy) knob.origin.y -= 0.5;
    if ((cornerMask & RIGHT_SIDE_MASK) && NSMouseInRect(p, knob, NO))
	return(RIGHT_SIDE);
    knob.origin.y -= dy;
    if (oddy) knob.origin.y += 0.5;
    if ((cornerMask & LOWER_RIGHT_MASK) && NSMouseInRect(p, knob, NO))
	return(LOWER_RIGHT);
    knob.origin.x -= dx;
    if (oddx) knob.origin.x += 0.5;
    if ((cornerMask & BOTTOM_SIDE_MASK) && NSMouseInRect(p, knob, NO))
	return(BOTTOM_SIDE);

    return NSMouseInRect(p, bounds, NO) ? ([self isOpaque] ? 0 : -1) : -1;
}

/* This method is analogous to display (not drawSelf::) in View. */

- (void)draw:(NSRect)rect
/*
 * Draws the graphic inside rect.  If rect is an "empty" rect, then it draws
 * the entire Graphic.  If the Graphic is not intersected by rect, then it
 * is not drawn at all.  If the Graphic is selected, it is drawn with
 * its knobbies.  This method is not intended to be overridden.  It
 * calls the overrideable method "draw" which doesn't have to worry
 * about drawing the knobbies.
 *
 * Note the showFastKnobFills optimization here.  If this Graphic is
 * opaque then there is a possibility that it might obscure knobbies
 * of Graphics underneath it, so we must emit the cached rectfills
 * before drawing this Graphic.
 */
{
    NSRect r = [self extendedBounds];
    if (gFlags.active && (NSIsEmptyRect(rect) || !NSIsEmptyRect(NSIntersectionRect(rect, r)))) {
	if ([self isOpaque]) [Graphic showFastKnobFills];
	[self setGraphicsState];	/* does a gsave */
	[self draw];
	PSgrestore();			/* so we need a grestore here */
	if ([[NSDPSContext currentContext] isDrawingToScreen]) {
	    if (gFlags.selected) {
		r.origin.x = floor(bounds.origin.x);
		r.origin.y = floor(bounds.origin.y);
		r.size.width = floor(bounds.origin.x + bounds.size.width + 0.99) - r.origin.x;
		r.size.height = floor(bounds.origin.y + bounds.size.height + 0.99) - r.origin.y;
		r.origin.x += 1.0;
		r.origin.y -= 1.0;
		drawKnobs(r, [self cornerMask], YES);		/* shadows */
		r.origin.x = floor(bounds.origin.x);
		r.origin.y = floor(bounds.origin.y);
		r.size.width = floor(bounds.origin.x + bounds.size.width + 0.99) - r.origin.x;
		r.size.height = floor(bounds.origin.y + bounds.size.height + 0.99) - r.origin.y;
		drawKnobs(r, [self cornerMask], NO);	/* knobs */
	    }
	}
    }
}

/*
 * Returns whether this Graphic can emit, all by itself, fully
 * encapsulated PostScript (or fully conforming TIFF) representing
 * itself.  This is an optimization for copy/paste.
 */

- (BOOL)canEmitEPS
{
    return NO;
}

- (BOOL)canEmitTIFF
{
    return NO;
}

/* Sizing, aligning and moving. */

- (void)moveLeftEdgeTo:(const float *)x
{
    bounds.origin.x = *x; 
}

- (void)moveRightEdgeTo:(const float *)x
{
    bounds.origin.x = *x - bounds.size.width; 
}

- (void)moveTopEdgeTo:(const float *)y
{
    bounds.origin.y = *y - bounds.size.height; 
}

- (void)moveBottomEdgeTo:(const float *)y
{
    bounds.origin.y = *y; 
}

- (void)moveHorizontalCenterTo:(const float *)x
{
    bounds.origin.x = *x - floor(bounds.size.width / 2.0); 
}

- (void)moveVerticalCenterTo:(const float *)y
{
    bounds.origin.y = *y - floor(bounds.size.height / 2.0); 
}

- (float)baseline
{
    return 0.0;
}

- (void)moveBaselineTo:(const float *)y
{
}

- (void)moveBy:(const NSPoint *)offset
{
    bounds.origin.x += floor(offset->x);
    bounds.origin.y += floor(offset->y); 
}

- (void)moveTo:(NSPoint)p
{
    bounds.origin.x = floor(p.x);
    bounds.origin.y = floor(p.y); 
}

- (void)centerAt:(NSPoint)p
{
    bounds.origin.x = floor(p.x - bounds.size.width / 2.0);
    bounds.origin.y = floor(p.y - bounds.size.height / 2.0); 
}

- (void)sizeTo:(const NSSize *)size
{
    bounds.size.width = floor(size->width);
    bounds.size.height = floor(size->height); 
}

- (void)sizeToNaturalAspectRatio
{
    return [self constrainCorner:UPPER_RIGHT toAspectRatio:[self naturalAspectRatio]];
}

- (void)sizeToGrid:(GraphicView *)graphicView
{
    NSPoint p;

    bounds.origin = [graphicView grid:bounds.origin];
    p.x = bounds.origin.x + bounds.size.width;
    p.y = bounds.origin.y + bounds.size.height;
    p = [graphicView grid:p];
    bounds.size.width = p.x - bounds.origin.x;
    bounds.size.height = p.y - bounds.origin.y; 
}

- (void)alignToGrid:(GraphicView *)graphicView
{
    bounds.origin = [graphicView grid:bounds.origin]; 
}

/* Public routines. */

- (void)setLineWidth:(const float *)value
/*
 * This is called with value indirected so that it can be called via
 * a perform:with: method.  Kind of screwy, but ...
 */
{
    if (value) linewidth = *value; 
}

- (float)lineWidth
{
    return linewidth;
}

- (void)setLineColor:(NSColor *)color
{
    if (color) {
	[lineColor autorelease];
	if ([color isEqual:[NSColor blackColor]]) {
	    lineColor = NULL;
	    gFlags.nooutline = NO;
	} else {
	    lineColor = [color copyWithZone:(NSZone *)[self zone]];
	    gFlags.nooutline = NO;
	}
    } 
}

- (NSColor *)lineColor
{
    return lineColor ? lineColor : [NSColor blackColor];
}

- (void)setFillColor:(NSColor *)color
{
    if (color) {
	[fillColor autorelease];
	fillColor = [color copyWithZone:(NSZone *)[self zone]];
	if (![self fill]) [self setFill:FILL_NZWR];
    } 
}

- (NSColor *)fillColor
{
    return fillColor ? fillColor : [NSColor whiteColor];
}

- (Graphic *)colorAcceptorAt:(NSPoint)point
/*
 * This method supports dragging and dropping colors on Graphics.
 * Whatever object is returned from this may well be sent
 * setFillColor: if the color actually gets dropped on it.
 * See gvDrag.m's acceptsColor:atPoint: method.
 */
{
    return nil;
}

- (void)changeFont:(id)sender
{
}

- (NSFont *)font
{
    return nil;
}

- (void)setGray:(const float *)value
/*
 * This is called with value indirected so that it can be called via
 * a perform:with: method.  Kind of screwy, but ...
 * Now that we have converted to using NSColor's, we'll interpret this
 * method as a request to set the lineColor.
 */
{
    if (value) [self setLineColor:[NSColor colorWithCalibratedWhite:*value alpha:1.0]]; 
}

- (float)gray
{
    float retval;

    if (lineColor) {
	[[lineColor colorUsingColorSpaceName:NSCalibratedWhiteColorSpace] getWhite:&retval alpha:NULL];
    } else {
	retval = NSBlack;
    }

    return retval;
}

- (void)setFill:(int)mode
{
    switch (mode) {
	case FILL_NONE:	gFlags.eofill = gFlags.fill = NO; break;
	case FILL_EO:	gFlags.eofill = YES; gFlags.fill = NO; break;
	case FILL_NZWR:	gFlags.eofill = NO; gFlags.fill = YES; break;
    } 
}

- (int)fill
{
    if (gFlags.eofill) {
	return FILL_EO;
    } else if (gFlags.fill) {
	return FILL_NZWR;
    } else {
	return FILL_NONE;
    }
}

- (void)setOutlined:(BOOL)outlinedFlag
{
    gFlags.nooutline = outlinedFlag ? NO : YES; 
}

- (BOOL)isOutlined
{
    return gFlags.nooutline ? NO : YES;
}

- (void)setLineCap:(int)capValue
{
    if (capValue >= 0 && capValue <= 2) {
	gFlags.linecap = capValue;
    } 
}

- (int)lineCap
{
    return gFlags.linecap;
}

- (void)setLineArrow:(int)arrowValue
{
    if (arrowValue >= 0 && arrowValue <= 3) {
	gFlags.arrow = arrowValue;
    } 
}

- (int)lineArrow
{
    return gFlags.arrow;
}

- (void)setLineJoin:(int)joinValue
{
    if (joinValue >= 0 && joinValue <= 2) {
	gFlags.linejoin = joinValue;
    } 
}

- (int)lineJoin
{
    return gFlags.linejoin;
}

/* Archiving methods. */

#define FILLED_KEY @"Filled"
#define ARROW_AT_END_KEY @"ArrowAtEnd"
#define ARROW_AT_START_KEY @"ArrowAtStart"
#define EVEN_ODD_KEY @"EvenOddRule"

- (void)convertSelf:(ConversionDirection)direction propertyList:(id)plist
{
    if ((direction == FromPropertyList) || linewidth) PL_FLOAT(plist, linewidth, @"LineWidth", direction);
    if ((direction == FromPropertyList) || lineColor) PL_COLOR(plist, lineColor, @"LineColor", direction, [self zone]);
    if ((direction == FromPropertyList) || fillColor) PL_COLOR(plist, fillColor, @"FillColor", direction, [self zone]);
    PL_RECT(plist, bounds, @"Bounds", direction);
    PL_INT(plist, identifier, @"Identifier", direction);
    PL_FLAG(plist, gFlags.localizeFormEntry, @"LocalizeFormEntry", direction);
    PL_FLAG(plist, gFlags.isFormEntry, @"IsFormEntry", direction);
    PL_FLAG(plist, gFlags.nooutline, @"NoOutline", direction);
    if (direction == ToPropertyList) {
        if (gFlags.arrow & ARROW_AT_END) [plist setObject:@"YES" forKey:ARROW_AT_END_KEY];
        if (gFlags.arrow & ARROW_AT_START) [plist setObject:@"YES" forKey:ARROW_AT_START_KEY];
    } else {
        if ([plist objectForKey:ARROW_AT_END_KEY]) gFlags.arrow |= ARROW_AT_END;
        if ([plist objectForKey:ARROW_AT_START_KEY]) gFlags.arrow |= ARROW_AT_START;
    }
    PL_FLAG(plist, gFlags.locked, @"Locked", direction);
    if (direction == ToPropertyList) {
        if (gFlags.fill || gFlags.eofill)
            [plist setObject:(gFlags.fill ? @"Non-ZeroWindingRule" : EVEN_ODD_KEY) forKey:FILLED_KEY];
    } else {
        if ([[plist objectForKey:FILLED_KEY] isEqual:EVEN_ODD_KEY]) {
            gFlags.eofill = YES;
        } else if ([plist objectForKey:FILLED_KEY]) {
            gFlags.fill = YES;
        }
    }
    PL_INT(plist, gFlags.linecap, @"LineCap", direction);
    PL_INT(plist, gFlags.linejoin, @"LineJoin", direction);
    PL_FLAG(plist, gFlags.initialized, @"Initialized", direction);
    PL_FLAG(plist, gFlags.downhill, @"LineGoesDownhill", direction);
    PL_FLAG(plist, gFlags.selected, @"Selected", direction);
}

- (id)propertyList
{
    NSMutableDictionary *plist = [NSMutableDictionary dictionaryWithCapacity:10];
    [plist setObject:NSStringFromClass([self class]) forKey:@"Class"];
    [self convertSelf:ToPropertyList propertyList:plist];
    return plist;
}

- initFromPropertyList:(id)plist inDirectory:(NSString *)directory;
{
    [self convertSelf:FromPropertyList propertyList:plist];
    gFlags.active = YES;
    if (identifier >= currentGraphicIdentifier) currentGraphicIdentifier = identifier+1;
    [[self class] initClassVars];
    return self;
}

- (NSString *)description
{
    return [(NSObject *)[self propertyList] description];
}

/* Routines which may need subclassing for different Graphic types. */

- (BOOL)constrainByDefault
{
    return NO;
}

- (void)constrainCorner:(int)corner toAspectRatio:(float)aspect
/*
 * Modifies the bounds rectangle by moving the specified corner so that
 * the Graphic maintains the specified aspect ratio.  This is used during
 * constrained resizing.  Can be overridden if the aspect ratio is not
 * sufficient to constrain resizing.
 */
{
    int newcorner;
    float actualAspect;

    if (!bounds.size.height || !bounds.size.width || !aspect) return;
    actualAspect = bounds.size.width / bounds.size.height;
    if (actualAspect == aspect) return;

    switch (corner) {
    case LEFT_SIDE:
	bounds.origin.x -= bounds.size.height * aspect- bounds.size.width;
    case RIGHT_SIDE:
	bounds.size.width = bounds.size.height * aspect;
	if (bounds.size.width) bounds = NSIntegralRect(bounds);
	return;
    case BOTTOM_SIDE:
	bounds.origin.y -= bounds.size.width / aspect- bounds.size.height;
    case TOP_SIDE:
	bounds.size.height = bounds.size.width / aspect;
	if (bounds.size.height) bounds = NSIntegralRect(bounds);
	return;
    case LOWER_LEFT:
	corner = 0;
    case 0:
    case UPPER_RIGHT:
    case UPPER_LEFT:
    case LOWER_RIGHT:
	if (actualAspect > aspect) {
	    newcorner = ((corner|KNOB_DY_ONCE)&(~(KNOB_DY_TWICE)));
	} else {
	    newcorner = ((corner|KNOB_DX_ONCE)&(~(KNOB_DX_TWICE)));
	}
	return [self constrainCorner:newcorner toAspectRatio:aspect];
    default:
	return;
    }
}

#define RESIZE_MASK (NSLeftMouseUpMask|NSLeftMouseDraggedMask|NSPeriodicMask)

- (void)resize:(NSEvent *)event by:(int)corner in:(GraphicView *)view
/*
 * Resizes the graphic by the specified corner.  If corner == CREATE,
 * then it is resized by the UPPER_RIGHT corner, but the initial size
 * is reset to 1 by 1.
 */
{
    NSPoint p, last;
    float aspect = 0.0;
    NSWindow *window = [view window];
    BOOL constrain, canScroll, temporarilyAddedToGraphicsList = NO;
    DrawStatusType oldDrawStatus;
    NSRect eb, starteb, visibleRect;

    if (!gFlags.active || !gFlags.selected || !corner) return;

    constrain = (([event modifierFlags] & NSAlternateKeyMask) &&
	((bounds.size.width && bounds.size.height) || corner == CREATE));
    if ([self constrainByDefault]) constrain = !constrain;
    if (constrain) aspect = bounds.size.width / bounds.size.height;
    if (corner == CREATE) {
	bounds.size.width = bounds.size.height = 1.0;
	corner = UPPER_RIGHT;
    }

    gFlags.selected = NO;

    starteb = eb = [self extendedBounds];

    if (![[view graphics] containsObject:self]) {
        [[view graphics] addObject:self];
        temporarilyAddedToGraphicsList = YES;
    }

    gFlags.notCached = YES;
    gFlags.active = NO;
    [view cache:eb andUpdateLinks:NO];
    gFlags.active = YES;

    oldDrawStatus = DrawStatus;
    DrawStatus = Resizing;

    visibleRect = [view visibleRect];
    canScroll = !NSEqualRects(visibleRect, bounds);
    if (canScroll) [NSEvent startPeriodicEventsAfterDelay:0.1 withPeriod:0.1];

    last.x = last.y = - 1.0;
    while ([event type] != NSLeftMouseUp) {
        p = [event locationInWindow]; // save for periodicEventWithLocationSetToPoint()
	event = [window nextEventMatchingMask:RESIZE_MASK];
	if ([event type] == NSPeriodic) event = periodicEventWithLocationSetToPoint(event, p);
	p = [event locationInWindow];
	p = [view convertPoint:p fromView:nil];
	p = [view grid:p];
	if (p.x != last.x || p.y != last.y) {
	    corner = [self moveCorner:corner to:p constrain:constrain];
	    if (constrain) [self constrainCorner:corner toAspectRatio:aspect];
	    if (canScroll) {
		[view scrollPointToVisible:p]; // actually we want to keep the "edges" of the
						// Graphic being resized that were visible when
						// the resize started visible throughout the
						// resizing time (this will be difficult if those
						// edges flip from being the left edge to the
						// right edge in the middle of the resize!).
	    }
            [view setNeedsDisplayInRect:eb]; // post redraw for the old bounds
            eb = [self extendedBounds];
            [view setNeedsDisplayInRect:eb]; // and for the new bounds
	    [view tryToPerform:@selector(updateRulers:) with:(void *)&bounds];
	    last = p;
	}
    }

    if (canScroll) [NSEvent stopPeriodicEvents];

    DrawStatus = oldDrawStatus;
    gFlags.selected = YES;
    gFlags.notCached = NO;

    if (temporarilyAddedToGraphicsList) {
        [[view graphics] removeObject:self];
    } else {
        [view cache:eb andUpdateLinks:NO]; // recache after resizing a Graphic
    }

    [view updateTrackedLinks:NSUnionRect(eb, starteb)];		// update links
    [view tryToPerform:@selector(updateRulers:) with:nil];	// clear rulers
}

- (BOOL)create:(NSEvent *)event in:(GraphicView *)view
/*
 * This method rarely needs to be subclassed.
 * It sets up an initial bounds, and calls resize:by:in:.
 */
{
    BOOL valid;
    float gridSpacing;

    bounds.origin = [event locationInWindow];
    bounds.origin = [view convertPoint:bounds.origin fromView:nil];
    bounds.origin = [view grid:bounds.origin];

    gridSpacing = (float)[view gridSpacing];
    bounds.size.height = gridSpacing;
    bounds.size.width = gridSpacing * [self naturalAspectRatio];

    [self resize:event by:CREATE in:view];

    valid = [self isValid];

    if (valid) {
	gFlags.selected = YES;
	gFlags.active = YES;
    } else {
	gFlags.selected = NO;
	gFlags.active = NO;
	[view display];
    }

    return valid;
}

- (BOOL)hit:(NSPoint)p
{
    return (!gFlags.locked && gFlags.active && NSMouseInRect(p, bounds, NO));
}

- (BOOL)isOpaque
{
    return [self fill] ? YES : NO;
}

- (BOOL)isValid
/*
 * Called after a Graphic is created to see if it is valid (this usually
 * means "is it big enough?").
 */
{
    return (bounds.size.width > MINSIZE && bounds.size.height > MINSIZE);
}

- (float)naturalAspectRatio
/*
 * A natural aspect ratio of zero means it doesn't have a natural aspect ratio.
 */
{
    return 0.0;
}

- (int)moveCorner:(int)corner to:(NSPoint)p constrain:(BOOL)flag
/*
 * Moves the specified corner to the specified point.
 * Returns the position of the corner after it was moved.
 */
{
    int newcorner = corner;

    if ((corner & KNOB_DX_ONCE) && (corner & KNOB_DX_TWICE)) {
	bounds.size.width += p.x - (bounds.origin.x + bounds.size.width);
	if (bounds.size.width <= 0.0) {
	    newcorner &= ~ (KNOB_DX_ONCE | KNOB_DX_TWICE);
	    bounds.origin.x += bounds.size.width;
	    bounds.size.width = - bounds.size.width;
	}
    } else if (!(corner & KNOB_DX_ONCE)) {
	bounds.size.width += bounds.origin.x - p.x;
	bounds.origin.x = p.x;
	if (bounds.size.width <= 0.0) {
	    newcorner |= KNOB_DX_ONCE | KNOB_DX_TWICE;
	    bounds.origin.x += bounds.size.width;
	    bounds.size.width = - bounds.size.width;
	}
    }

    if ((corner & KNOB_DY_ONCE) && (corner & KNOB_DY_TWICE)) {
	bounds.size.height += p.y - (bounds.origin.y + bounds.size.height);
	if (bounds.size.height <= 0.0) {
	    newcorner &= ~ (KNOB_DY_ONCE | KNOB_DY_TWICE);
	    bounds.origin.y += bounds.size.height;
	    bounds.size.height = - bounds.size.height;
	}
    } else if (!(corner & KNOB_DY_ONCE)) {
	bounds.size.height += bounds.origin.y - p.y;
	bounds.origin.y = p.y;
	if (bounds.size.height <= 0.0) {
	    newcorner |= KNOB_DY_ONCE | KNOB_DY_TWICE;
	    bounds.origin.y += bounds.size.height;
	    bounds.size.height = - bounds.size.height;
	}
    }

    if (newcorner != LOWER_LEFT) newcorner &= 0xf;
    if (!newcorner) newcorner = LOWER_LEFT;

    return newcorner;
}

- (void)unitDraw
/*
 * If a Graphic just wants to draw itself in the bounding box of
 * {{0.0,0.0},{1.0,1.0}}, it can simply override this method.
 * Everything else will work fine.
 */
{
     
}

- draw
/*
 * Almost all Graphics need to override this method.
 * It does the Graphic-specific drawing.
 * By default, it scales the coordinate system and calls unitDraw.
 */
{
    if (bounds.size.width >= 1.0 && bounds.size.height >= 1.0) {
	PStranslate(bounds.origin.x, bounds.origin.y);
	PSscale(bounds.size.width, bounds.size.height);
	[self unitDraw];
    }
    return self;
}

- (BOOL)edit:(NSEvent *)event in:(NSView *)view
/*
 * Any Graphic which has editable text should override this method
 * to edit that text.  TextGraphic is an example.
 */
{
    return NO;
}

@end
