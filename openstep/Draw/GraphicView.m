#import <AppKit/psopsNeXT.h> // for PShide/showcursor
#import "draw.h"

@interface FlippedView : NSView

- (BOOL)isFlipped;

@end

@implementation FlippedView : NSView

- (BOOL)isFlipped
{
    return YES;
}
 
@end

/* This file is best read in a window as wide as this comment (so that this comment fits on one line). */

@interface GraphicView(PrivateMethods)

/* Private methods */

- (NSView *)createEditView;

- (NSRect)getBBoxOfArray:(NSArray *)list extended:(BOOL)extended;

- (NSImage *)selectionCache;			// the shared cache used to cache the selection only
- (void)recacheSelection:(BOOL)updateLinks;	// recaches the selection into the view cache, not the selection cache
- (void)compositeSelection:(NSRect)sbounds;	// composites the selection from the selection cache
- (void)cacheSelection;				// caches the selection into the selection cache
- (void)dirty:sender;

- (void)resetGUP;
- (BOOL)move:(NSEvent *)event ;
- (void)moveGraphicsBy:(NSPoint)vector andDraw:(BOOL)drawFlag;
- (void)dragSelect:(NSEvent *)event;
- (void)alignGraphicsBy:(AlignmentType)alignType edge:(float *)edge; 
- (void)alignBy:(AlignmentType)alignType; 

@end

NSString *DrawPboardType = @"Draw Graphic List Type version 3.0";

BOOL InMsgPrint = NO;		/* whether we are in msgPrint: */

#define LEFTARROW	172
#define RIGHTARROW	174
#define UPARROW		173
#define DOWNARROW	175

@implementation GraphicView : NSView
/*
 * The GraphicView class is the core of a DrawDocument.
 *
 * It overrides the View methods related to drawing and event handling
 * and allows manipulation of Graphic objects.
 *
 * The user is allowed to select objects, move them around, group and
 * ungroup them, change their font, and cut and paste them to the pasteboard.
 * It understands multiple formats including PostScript and TIFF as well as
 * its own internal format.  The GraphicView can also import PostScript and
 * TIFF documents and manipulate them as Graphic objects.
 *
 * This is a very skeleton implementation and is intended purely for
 * example purposes.  It should be very easy to add new Graphic objects
 * merely by subclassing the Graphic class.  No code need be added to the
 * GraphicView class when a new Graphic subclass is added.
 *
 * Moving is accomplished using a selection cache which is shared among
 * all instances of GraphicView in the application.  The objects in the
 * selection are drawn using opaque ink on a transparent background so
 * that when they are moved around, the user can see through them to the
 * objects that are not being moved.
 *
 * All of the drawing is done in an NSImage which is merely
 * composited back to the screen.  This makes for very fast redraw of
 * areas obscured either by the selection moving or the user's scrolling.
 *
 * The glist instance variable is just an ordered list of all the Graphics
 * in the GraphicView.  The slist is an ordered list of the Graphic objects
 * in the selection.  In the original Draw code it was almost always kept 
 * in the same order as the glist, but could be jumbled by doing a shift-drag 
 * select to add to an existing selection. We are now extremely careful about 
 * keeping the slist in the same order as the glist.
 *
 * cacheImage is the NSImage into which the objects are
 * drawn.  Flags:  grid is the distance between pixels in the grid
 * imposed on drawing; cacheing is used so that drawSelf:: knows when
 * to composite from the cache and when to draw into the
 * cache; groupInSlist is used to keep track of whether a
 * Group Graphic is in the slist so that it knows when to highlight
 * the Ungroup entry in the menu.
 *
 * This class should be able to be used outside the context of this
 * application since it takes great pains not to depend on any other objects
 * in the application.
 */

/*
 * Of course, one should NEVER use global variables in an application, but
 * the following is necessary.  DrawStatus is
 * analogous to the Application Kit's NSDrawingStatus and reflects whether
 * we are in some modal loop.  By definition, that modal loop is "atomic"
 * since we own the mouse during its duration (of course, all bets are off
 * if we have multiple mice!).
 */
 
DrawStatusType DrawStatus = Normal;  /* global state reflecting what we
					are currently doing (resizing, etc.) */

const float DEFAULT_GRID_GRAY = 0.8333;

static Class currentGraphic = nil;	/* won't be used if NSApp knows how
					   to keep track of the currentGraphic */

static float KeyMotionDeltaDefault = 0.0;

/* Code-cleaning macros */

#define GRID (gvFlags.gridDisabled ? 1.0 : (gvFlags.grid ? (float)gvFlags.grid : 1.0))

#define grid(point) \
    (point).x = floor(((point).x / GRID) + 0.5) * GRID; \
    (point).y = floor(((point).y / GRID) + 0.5) * GRID;

static NSRect regionFromCorners(NSPoint p1, NSPoint p2)
/*
 * Returns the rectangle which has p1 and p2 as its corners.
 */
{
    NSRect region;

    region.size.width = p1.x - p2.x;
    region.size.height = p1.y - p2.y;
    if (region.size.width < 0.0) {
	region.origin.x = p2.x + region.size.width;
	region.size.width = ABS(region.size.width);
    } else {
	region.origin.x = p2.x;
    }
    if (region.size.height < 0.0) {
	region.origin.y = p2.y + region.size.height;
	region.size.height = ABS(region.size.height);
    } else {
	region.origin.y = p2.y;
    }

    return region;
}

static BOOL checkForGroup(NSArray *array)
/*
 * Looks through the given list searching for objects of the Group class.
 * We use this to keep the gvFlags.groupInSlist flag up to date when things
 * are removed from the slist (the list of selected objects).  That way
 * we can efficiently keep the Ungroup menu item up to date.
 */
{
    int i = [array count];
    while (i--) if ([[array objectAtIndex:i] isKindOfClass:[Group class]]) return YES;
    return NO;
}

/* Factory methods. */

/* Alignment methods */

+ (SEL)actionFromAlignType:(AlignmentType)alignType
{
    switch (alignType) {
	case LEFT: return @selector(moveLeftEdgeTo:);
	case RIGHT: return @selector(moveRightEdgeTo:);
	case BOTTOM: return @selector(moveBottomEdgeTo:);
	case TOP: return @selector(moveTopEdgeTo:);
	case HORIZONTAL_CENTERS: return @selector(moveVerticalCenterTo:);
	case VERTICAL_CENTERS: return @selector(moveHorizontalCenterTo:);
	case BASELINES: return @selector(moveBaselineTo:);
    }
    return (SEL)NULL;
}

/* Creation methods. */

+ (void)initClassVars
/*
 * Sets up any default values.
 */
{
    static BOOL registered = NO;
    NSArray * validSendTypes = [[[NSMutableArray alloc] initWithObjects:NSPostScriptPboardType, NSTIFFPboardType, DrawPboardType, nil] autorelease];
    NSArray * validReturnTypes = [[[NSMutableArray alloc] initWithObjects:DrawPboardType, nil] autorelease];

    if (!KeyMotionDeltaDefault) {
	NSString * value = [[NSUserDefaults standardUserDefaults] objectForKey:@"KeyMotionDelta"];
	if (value) KeyMotionDeltaDefault = [value floatValue];
	KeyMotionDeltaDefault = MAX(KeyMotionDeltaDefault, 1.0);
    }
    if (!registered) {
	registered = YES;
	[NSApp registerServicesMenuSendTypes:validSendTypes returnTypes:[NSImage imagePasteboardTypes]];
	[NSApp registerServicesMenuSendTypes:validSendTypes returnTypes:validReturnTypes];
    }
}

- (id)initWithFrame:(NSRect)frameRect {
    [super initWithFrame:frameRect];
    glist = [[NSMutableArray allocWithZone:[self zone]] init];
    slist = [[NSMutableArray allocWithZone:[self zone]] init];
    cacheImage = [[NSImage allocWithZone:[self zone]] initWithSize:[self bounds].size];
    [self cache:[self bounds] andUpdateLinks:NO];
    gvFlags.grid = 10;
    gvFlags.gridDisabled = 1;
    [self allocateGState];
    gridGray = DEFAULT_GRID_GRAY;
    PSInit();
    currentGraphic = [Rectangle class];	      /* default graphic */
    currentGraphic = [self currentGraphic];   /* trick to allow NSApp to control currentGraphic */
    editView = [self createEditView];
    [[self class] initClassVars];
    [self registerForDragging];
    spellDocTag = 0;
    return self;
}

/* Free method */

- (void)dealloc
{
    if (gupCoords) {
	NSZoneFree([self zone], gupCoords);
	NSZoneFree([self zone], gupOps);
	NSZoneFree([self zone], gupBBox);
    }
    [glist removeAllObjects];
    [slist removeAllObjects];
    [glist release];
    [slist release];
    [cacheImage release];
    if (![editView superview]) [editView release];
    [super dealloc];
}

/* Used by Change's */

- (void)setGroupInSlist:(BOOL)setting
{
    gvFlags.groupInSlist = setting; 
}

- (void)resetGroupInSlist
{
    gvFlags.groupInSlist = checkForGroup(slist); 
}

- (void)resetLockedFlag
{
    int i, count;

    gvFlags.locked = NO;
    count = [glist count];
    for (i = 0; (i < count) && (!gvFlags.locked); i++) 
        if ([[glist objectAtIndex:i] isLocked])
	    gvFlags.locked = YES; 
}

- (void)redrawGraphics:graphicsList afterChangeAgent:changeAgent performs:(SEL)aSelector 
{
    NSRect afterBounds, beforeBounds;

    if ([(NSArray *)graphicsList count]) {
        beforeBounds = [self getBBoxOfArray:graphicsList];
	[changeAgent performSelector:aSelector];
        afterBounds = [self getBBoxOfArray:graphicsList];
	afterBounds = NSUnionRect(beforeBounds, afterBounds);
	[self cache:afterBounds]; // (cache and) redraw after change object did something
    } else {
	[changeAgent performSelector:aSelector];
    } 
}

/* Hack to support growable Text objects. */

- (NSView *)createEditView
/*
 * editView is essentially a dumb, FLIPPED (with extra emphasis on the
 * flipped) subview of our GraphicView which completely covers it and
 * which automatically sizes itself to always completely cover the
 * GraphicView.  It is necessary since growable Text objects only work
 * when they are subviews of a flipped view.
 *
 * See TextGraphic for more details about why we need editView
 * (it is purely a workaround for a limitation of the Text object).
 */
{
    NSView *view;
    NSRect viewFrame = [self frame];

    [self setAutoresizesSubviews:YES];
    view = [[FlippedView allocWithZone:[self zone]] initWithFrame:(NSRect){{0, 0}, {viewFrame.size.width, viewFrame.size.height}}];
    [view setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
    [self addSubview:view];

    return view;
}

/* Public interface methods. */

- (BOOL)isEmpty
{
    return [glist count] == 0;
}

- (BOOL)hasEmptySelection
{
    return [slist count] == 0;
}

- (void)dirty
{
    id delegate = [[self window] delegate];
    if ([delegate respondsToSelector:@selector(dirty:)]) [delegate dirty:self]; 
}

- (void)getSelection
/*
 * Resets slist by going through the glist and locating all the Graphics
 * which respond YES to the isSelected method.
 */
{
    int i;
    Graphic *graphic;

    [slist removeAllObjects];
    gvFlags.groupInSlist = NO;
    i = [glist count];
    while (i--) {
	graphic = [glist objectAtIndex:i];
	if ([graphic isSelected]) {
	    [slist insertObject:graphic atIndex:0];
	    gvFlags.groupInSlist = gvFlags.groupInSlist || [graphic isKindOfClass:[Group class]];
	}
    } 
}

- (NSRect)getBBoxOfArray:(NSArray *)array
{
    return [self getBBoxOfArray:array extended:YES];
}

- (void)graphicsPerform:(SEL)aSelector
/*
 * Performs the given aSelector on each member of the slist, then
 * recaches and redraws the larger of the area covered by the objects before
 * the selector was applied and the area covered by the objects after the
 * selector was applied.  If you want to perform a method on each item
 * in the slist and NOT redraw, then use the List method makeObjectsPerform:.
 */
{
    int i, count;
    Graphic *graphic;
    NSRect affectedBounds;

    count = [slist count];
    if (count) {
	affectedBounds = [[slist objectAtIndex:0] extendedBounds];
	for (i = 1; i < count; i++) {
	    graphic = [slist objectAtIndex:i];
	    affectedBounds = NSUnionRect([graphic extendedBounds], affectedBounds);
	}
	for (i = 0; i < count; i++) {
	    graphic = [slist objectAtIndex:i];
	    [graphic performSelector:aSelector];
	    affectedBounds = NSUnionRect([graphic extendedBounds], affectedBounds);
	}
	[self cache:affectedBounds];	// (cache and) redraw after a graphicsPerform:
    } 
}

- (void)graphicsPerform:(SEL)aSelector with:(void *)argument
{
    int i, count;
    Graphic *graphic;
    NSRect affectedBounds;

    count = [slist count];
    if (count) {
	affectedBounds = [[slist objectAtIndex:0] extendedBounds];
	for (i = 1; i < count; i++) {
	    graphic = [slist objectAtIndex:i];
	    affectedBounds = NSUnionRect([graphic extendedBounds], affectedBounds);
	}
	for (i = 0; i < count; i++) {
	    graphic = [slist objectAtIndex:i];
	    [graphic performSelector:aSelector withObject:argument];
	    affectedBounds = NSUnionRect([graphic extendedBounds], affectedBounds);
	}
	[self cache:affectedBounds];	// (cache and) redraw after a graphicsPerform:with:
    } 
}

- (void)cache:(NSRect)rect andUpdateLinks:(BOOL)updateLinks;
/*
 * Draws all the Graphics intersected by rect into the off-screen cache,
 * then composites the rect back to the screen (but does NOT flushWindow).
 * If updateLinks is on, then we check to see if the redrawn area intersects
 * an area that someone has created a link to (see gvLinks.m).
 */
{
    gvFlags.cacheing = YES;
    [self drawRect:rect];
    gvFlags.cacheing = NO;

    if ([self canDraw]) {
	[self lockFocus];
	[self drawRect:rect];
	[self unlockFocus];
    }  else  {
	[self setNeedsDisplayInRect:rect];
    }

    if (updateLinks && !gvFlags.suspendLinkUpdate) [self updateTrackedLinks:rect];
}

- (void)cache:(NSRect)rect;
{
    return [self cache:rect andUpdateLinks:YES];
}

- cacheAndFlush:(NSRect)rect
{
    [self cache:rect];	// cacheAndFlush:
    [[self window] flushWindow];
    return self;
}

- (void)insertGraphic:(Graphic *)graphic
/*
 * Inserts the specified graphic into the glist and draws it.
 * The new graphic will join the selection, not replace it.
 */
{
    if (graphic) {
	if ([graphic isSelected]) [slist insertObject:graphic atIndex:0];
	[glist insertObject:graphic atIndex:0];
	[graphic wasAddedTo:self];
	[self cache:[graphic extendedBounds]];	// insertGraphic:
	if ([graphic isKindOfClass:[Group class]]) gvFlags.groupInSlist = YES;
	[[self window] flushWindow];
    } 
}

- (void)removeGraphic:(Graphic *)graphic
/*
 * Removes the graphic from the GraphicView and redraws.
 */
{
    int i;
    NSRect eb;
    Graphic *g = nil;

    if (graphic) {
        i = [glist count];
        while (g != graphic && i--) g = [glist objectAtIndex:i];
        if (g == graphic) {
            eb = [g extendedBounds];
            [glist removeObjectAtIndex:i];
            [graphic wasRemovedFrom:self];
            [slist removeObject:g];
            if ([g isKindOfClass:[Group class]]) gvFlags.groupInSlist = checkForGroup(slist);
            [self cache:eb];	// removeGraphic:
            [[self window] flushWindow];
        }
    }
}

- (Graphic *)selectedGraphic
/*
 * If there is one and only one Graphic selected, this method returns it.
 */
{
    if ([slist count] == 1) {
	Graphic *graphic = [slist objectAtIndex:0];
	return [graphic isKindOfClass:[Group class]] ? nil : graphic;
    } else {
	return nil;
    }
}

- (NSMutableArray *)selectedGraphics
/*
 * Result valid only immediately after call. GraphicView 
 * reserves the right to free the list without warning.
 */
{
    return slist;
}

- (NSMutableArray *)graphics
/*
 * Result valid only immediately after call. GraphicView 
 * reserves the right to free the list without warning.
 */
{
    return glist;
}

/* Methods to modify the grid of the GraphicView. */

- (int)gridSpacing
{
    return gvFlags.grid;
}

- (BOOL)gridIsVisible
{
    return gvFlags.showGrid;
}

- (BOOL)gridIsEnabled
{
    return !gvFlags.gridDisabled;
}

- (float)gridGray
{
    return gridGray;
}

- (void)setGridSpacing:(int)gridSpacing
{
    id change;
    
    if (gridSpacing != gvFlags.grid && gridSpacing > 0 && gridSpacing < 256) {
	change = [[GridChange alloc] initGraphicView:self];
	[change startChange];
	    gvFlags.grid = gridSpacing;
	    if (gvFlags.showGrid) {
		[self resetGUP];
		[self cache:[self bounds] andUpdateLinks:NO];
		[[self window] flushWindow];
	    }
	[change endChange];
    } 
}

- (void)setGridEnabled:(BOOL)flag
{
    id change;
    
    change = [[GridChange alloc] initGraphicView:self];
    [change startChange];
        gvFlags.gridDisabled = flag ? NO : YES;
    [change endChange]; 
}

- (void)setGridVisible:(BOOL)flag
{
    id change;
    
    if (gvFlags.showGrid != flag) {
	change = [[GridChange alloc] initGraphicView:self];
	[change startChange];
	    gvFlags.showGrid = flag;
	    if (flag) [self resetGUP];
	    [self cache:[self bounds] andUpdateLinks:NO];
	    [[self window] flushWindow];
	[change endChange];
    } 
}

- (void)setGridGray:(float)gray
{
    id change;
    
    if (gray != gridGray) {
	change = [[GridChange alloc] initGraphicView:self];
	[change startChange];
	    gridGray = gray;
	    if (gvFlags.showGrid) {
		[self cache:[self bounds] andUpdateLinks:NO];
		[[self window] flushWindow];
	    }
	[change endChange];
    } 
}

- (void)setGridSpacing:(int)gridSpacing andGray:(float)gray
{
    id change;
    
    if (gray != gridGray || (gridSpacing != gvFlags.grid && gridSpacing > 0 && gridSpacing < 256)) {
	change = [[GridChange alloc] initGraphicView:self];
	[change startChange];
	    gridGray = gray;
	    if (gvFlags.grid != gridSpacing && gridSpacing > 0 && gridSpacing < 256) {
		gvFlags.grid = gridSpacing;
		if (gvFlags.showGrid) [self resetGUP];
	    }
	    if (gvFlags.showGrid) {
		[self cache:[self bounds] andUpdateLinks:NO];
		[[self window] flushWindow];
	    }
	[change endChange];
    } 
}

- (NSPoint)grid:(NSPoint)p
{
    grid(p);
    return p;
}

/* Public methods for importing foreign data types into the GraphicView */

- (Graphic *)placeGraphic:(Graphic *)graphic at:(const NSPoint *)location
/*
 * Places the graphic centered at the given location on the page.
 * If the graphic is too big, the user is asked whether the graphic
 * should be scaled.
 */
{
    int scale;
    float sx, sy, factor;
    NSRect gbounds, visibleRect, bounds = [self bounds];
    id change;

    if (graphic) {
	gbounds = [graphic extendedBounds];
	if (gbounds.size.width > bounds.size.width || gbounds.size.height > bounds.size.height) {
	    scale = NSRunAlertPanel(LOAD_IMAGE, IMAGE_TOO_LARGE, SCALE, DONT_SCALE, CANCEL);
	    if (scale < 0) {
		[graphic release];
		return nil;
	    } else if (scale > 0) {
		sx = (bounds.size.width / gbounds.size.width) * 0.95;
		sy = (bounds.size.height / gbounds.size.height) * 0.95;
		factor = MIN(sx, sy);
		gbounds.size.width *= factor;
		gbounds.size.height *= factor;
		[graphic sizeTo:&gbounds.size];
	    }
	}
	if (location) {
	    [graphic centerAt:*location];
	} else {
	    visibleRect = [self visibleRect];
	    visibleRect.origin.x += floor(visibleRect.size.width / 2.0 + 0.5);
	    visibleRect.origin.y += floor(visibleRect.size.height / 2.0 + 0.5);
	    [graphic centerAt:visibleRect.origin];
	}

	change = [[CreateGraphicsChange alloc] initGraphicView:self graphic:graphic];
	[change startChangeIn:self];
	    [self deselectAll:self];
	    [graphic select];
	    [self insertGraphic:graphic];
	    [self scrollGraphicToVisible:graphic];
	[change endChange];
    }

    return graphic;
}

/* Methods overridden from superclass. */

- (void)setFrameSize:(NSSize)newSize
/*
 * Overrides View's sizeTo:: so that the cacheImage is resized when
 * the View is resized.
 */
{
    NSRect bounds = [self bounds];

    if (newSize.width != bounds.size.width || newSize.height != bounds.size.height) {
	[super setFrameSize:(NSSize){ newSize.width, newSize.height }];
	bounds = [self bounds];
	[cacheImage setSize:bounds.size];
	[self resetGUP];
	[self cache:bounds andUpdateLinks:NO];
    }
}

- (void)mouseDown:(NSEvent *)event 
/*
 * This method handles a mouse down.
 *
 * If a current tool is in effect, then the mouse down causes a new
 * Graphic to begin being created.  Otherwise, the selection is modified
 * either by adding elements to it or removing elements from it, or moving
 * it.  Here are the rules:
 *
 * Tool in effect
 *    Shift OFF
 *	create a new Graphic which becomes the new selection
 *    Shift ON
 *	create a new Graphic and ADD it to the current selection
 *    Control ON
 *	leave creation mode, and start selection
 * Otherwise
 *    Shift OFF
 *	a. Click on a selected Graphic -> select graphic further back
 *	b. Click on an unselected Graphic -> that Graphic becomes selection
 *    Shift ON
 *	a. Click on a selected Graphic -> remove it from selection
 *	b. Click on unselected Graphic -> add it to selection
 *    Alternate ON
 *	if no affected graphic, causes drag select to select only objects
 *	completely contained within the dragged box.
 *
 * Essentially, everything works as one might expect except the ability to
 * select a Graphic which is deeper in the list (i.e. further toward the
 * back) by clicking on the currently selected Graphic.
 *
 * This is a very hairy mouseDown:.  Most need not be this scary.
 */
{
    NSPoint p;
    int i, count, corner;
    id change;
    NSWindow *window = [self window];
    Class factory;
    Graphic *g = nil, *startg = nil;
    BOOL shift, control, gotHit = NO, deepHit = NO, didDrag = NO;

    /*
     * You only need to do the following line in a mouseDown: method if
     * you receive this message because one of your subviews gets the
     * mouseDown: and does not respond to it (thus, it gets passed up the
     * responder chain to you).  In this case, our editView receives the
     * mouseDown:, but doesn't do anything about it, and when it comes
     * to us, we want to become the first responder.
     *
     * Normally you won't have a subview which doesn't do anything with
     * mouseDown:, in which case, you need only return YES from the
     * method acceptsFirstResponder (see that method below) and will NOT
     * need to do the following makeFirstResponder:.  In other words,
     * don't put the following line in your mouseDown: implementation!
     *
     * Sorry about confusing this issue ... 
     */

    if ([window firstResponder] != self) {
	if ([event clickCount] < 2) {
	    [window makeFirstResponder:self];
	} else {
	    [[window firstResponder] mouseDown:event];
	    return;
	}
    }

    shift = ([event modifierFlags] & NSShiftKeyMask) ? YES : NO;
    control = ([event modifierFlags] & NSControlKeyMask) ? YES : NO;

    p = [event locationInWindow];
    p = [self convertPoint:p fromView:nil];

    i = 0;	// See if a Graphic wants to handle this event itself
    [self lockFocus];
    count = [glist count];
    while (i < count) {
	g = [glist objectAtIndex:i++];
	if ([g handleEvent:event at:p inView:self]) return;
    }
    g = nil;
    [self unlockFocus];

    factory = [self currentGraphic];
    if (!control && (factory || ([event clickCount] == 2))) {
	id editFactory = factory;
	if (([event clickCount] == 2) && ![editFactory isEditable]) editFactory = [TextGraphic class];
	if ([editFactory isEditable]) {	/* if editable, try to edit one */
	    i = 0;
	    count = [glist count];
	    while (i < count) {
		g = [glist objectAtIndex:i++];
		if ([g isKindOfClass:editFactory] && [g hit:p]) {
		    if ([g isSelected]) {
			[g deselect];
			[self cache:[g extendedBounds] andUpdateLinks:NO];
			[slist removeObject:g];
		    }
                    [g edit:event in:editView];
		    goto done;
		}
	    }
	    g = nil;
	}
    }
    if (!control && factory) {
	if (factory && !g) {	/* not editing or no editable graphic found */
	    g = [[factory allocWithZone:[self zone]] init];
	    if ([NSApp respondsToSelector:@selector(inspectorPanel)]) {
		[((id)[[NSApp inspectorPanel] delegate]) initializeGraphic:g];
	    }
	    if ([g create:event in:self]) {
		change = [[CreateGraphicsChange alloc] initGraphicView:self graphic:g];
		[change startChange];
		    if (!shift) [self deselectAll:self];
		    [self insertGraphic:g];
                    [g edit:NULL in:editView];
		[change endChange];
	    } else {
		[g release];
	    }
	}
    } else {		/* selecting/resizing/moving */
	i = 0;
	count = [glist count];
	while (i < count && !gotHit) {
	    g = [glist objectAtIndex:i];
	    corner = [g knobHit:p];
	    if (corner > 0) {			/* corner hit */
		gotHit = YES;
		change = [[ResizeGraphicsChange alloc] initGraphicView:self graphic:g];
		[change startChange];
		[g resize:event by:corner in:self];
		[change endChange];
	    } else if (corner) {
	    	i++;
	    } else {	/* complete miss */
		break;
	    }   /* non-corner opaque hit */
	}
	i = 0;
	count = [glist count];
	while (i < count && !gotHit && !deepHit) {
	    g = [glist objectAtIndex:i++];
	    if ([g isSelected] && [g hit:p]) {
		if (shift) {
		    gotHit = YES;
		    [g deselect];
		    [self cache:[g extendedBounds] andUpdateLinks:NO];
		    [slist removeObject:g];
		    if ([g isKindOfClass:[Group class]]) gvFlags.groupInSlist = checkForGroup(slist);
		} else {
		    gotHit = [self move:event];
		    if (!gotHit) {
			deepHit = ![g isOpaque];
			if (!deepHit) gotHit = YES;
		    } 
		}
	    }
	}
	startg = g;
	count = [glist count];
	i = 0;
	if (!gotHit) while (i < count && !gotHit) {
	    g = [glist objectAtIndex:i];
	    if (![g isSelected] && [g hit:p]) {
		gotHit = YES;
		if (!shift) {
		    [self deselectAll:self];
		    [slist addObject:g];
		    gvFlags.groupInSlist = [g isKindOfClass:[Group class]];
		}
		[g select];
		if (shift) [self getSelection];
		if (deepHit || ![self move:event]) {
		    [self cache:[g extendedBounds] andUpdateLinks:NO];
		}
	    } else {
		i++;
	    }
	};

	if (!gotHit && !deepHit) {
	    if (!shift) {
		[self lockFocus];
		[self deselectAll:self];
		[self unlockFocus];
		didDrag = YES;
	    }
	    [self dragSelect:event];
	}
    }
done:
    if (!didDrag && dragRect) {
	NSZoneFree(NSDefaultMallocZone(), dragRect);
	dragRect = NULL;
    }
    gvFlags.selectAll = NO;

    [window flushWindow];
}

- (void)drawRect:(NSRect)rect
/*
 * Draws the GraphicView.
 *
 * If cacheing is on or if ![[NSDPSContext currentContext] isDrawingToScreen],
 * then all the graphics which intersect the specified rectangles will be drawn
 * (and clipped to those rectangles).  Otherwise, the specified rectangles
 * are composited to the screen from the off-screen cache.  The invalidRect
 * stuff is to clean up any temporary drawing we have in the view
 * (currently used only to show a source selection in the links mechanism--
 * see showSelection: in gvLinks.m).
 */
{
    int i;
    NSWindow *window = [self window];
    NSRect visibleRect;

    if (!gvFlags.cacheing && invalidRect && !NSEqualRects(rect, *invalidRect)) {
	*invalidRect = NSUnionRect(rect, *invalidRect);
	[self drawRect:*invalidRect];
	[window flushWindow];
	NSZoneFree(NSDefaultMallocZone(), invalidRect);
	invalidRect = NULL;
	return;
    }

    if (gvFlags.cacheing || ![[NSDPSContext currentContext] isDrawingToScreen]) {
	if ([[NSDPSContext currentContext] isDrawingToScreen]) {
	    [cacheImage lockFocus];
	    NSRectClip(rect);
	    PSsetgray(NSWhite);
	    NSRectFill(rect);
	    if (gvFlags.showGrid && gvFlags.grid >= 4) {
		PSsetlinewidth(0.0);
		PSsetgray(gridGray);
		PSDoUserPath(gupCoords, gupLength, dps_short, gupOps, gupLength >> 1, gupBBox, dps_ustroke);
		PSsetgray(NSWhite);
	    }
	}
	i = [glist count];
	while (i--) [[glist objectAtIndex:i] draw:rect];
	[Graphic showFastKnobFills];
	if ([[NSDPSContext currentContext] isDrawingToScreen]) {
	    [cacheImage unlockFocus];
	}
    }

    if (!gvFlags.cacheing && [[NSDPSContext currentContext] isDrawingToScreen]) {
	visibleRect = [self visibleRect];
	if (!NSEqualRects(rect, visibleRect)) {
	    rect = NSIntersectionRect(visibleRect, rect);
	}
	if (!NSIsEmptyRect(rect)) {
            [cacheImage compositeToPoint:rect.origin fromRect:rect operation:NSCompositeCopy];
            i = [glist count]; // pick up uncached graphics (used in resize:, etc.)
            while (i--) {
                Graphic *g = [glist objectAtIndex:i];
		if (![g isCached]) [g draw:rect];
            }
        }
    }
}

static NSPoint keyMoveBy;

- (void)keyDown:(NSEvent *)event 
/*
 * Let's the key-binding handler handles key events.
 * It will call things like moveForward:, deleteBackward:, etc.
 * Since moving the selection and such can be expensive, we
 * coalesce consecutive key down events (up to 20 in a row)
 * so that they'll be processed without a draw happening
 * at each increment.
 */
{
    int flags = [event modifierFlags];

    if ((flags & NSAlternateKeyMask) || ([[self window] firstResponder] != self)) {
	[super keyDown:event];
    } else {
        int throttle = 20; // don't suck more than 20 consecutive key events
        NSMutableArray *eventList = [NSMutableArray arrayWithCapacity:throttle];

        [eventList addObject:event];
        while (--throttle) {
            event = [[self window] nextEventMatchingMask:NSAnyEventMask untilDate:[NSDate distantPast] inMode:NSDPSRunLoopMode dequeue:NO];
            if (!event) {
                break;
            } else if ([event type] == NSKeyUp) {
                [[self window] nextEventMatchingMask:NSKeyUpMask]; // discard these
                continue;
            }
            if ([event type] != NSKeyDown) { // only grab consecutive key events
                break;
            }
            event = [[self window] nextEventMatchingMask:NSAnyEventMask untilDate:[NSDate distantPast] inMode:NSDPSRunLoopMode dequeue:YES];
            [eventList addObject:event];
        }

        keyMoveBy.x = keyMoveBy.y = 0.0;
        [self interpretKeyEvents:eventList];
        if (keyMoveBy.x || keyMoveBy.y) {
            float delta = KeyMotionDeltaDefault;
            delta = floor(delta / GRID) * GRID;
            delta = MAX(delta, GRID);
            keyMoveBy.x *= delta;
            keyMoveBy.y *= delta;
            [self moveGraphicsBy:keyMoveBy andDraw:YES];
            [[self window] flushWindow];
            PSWait();
        }
    }
}

- (void)deleteForward:(id)sender
{
    [self delete:self];
}

- (void)deleteBackward:(id)sender
{
    [self delete:self];
}

- (void)moveLeft:(id)sender;
{
    keyMoveBy.x -= 1.0;
}

- (void)moveRight:(id)sender;
{
    keyMoveBy.x += 1.0;
}

- (void)moveUp:(id)sender;
{
    keyMoveBy.y += 1.0;
}

- (void)moveDown:(id)sender;
{
    keyMoveBy.y -= 1.0;
}

/* Accepting becoming the First Responder */

- (BOOL)acceptsFirstResponder
/*
 * GraphicView always wants to become the first responder when it is
 * clicked on in a window, so it returns YES from this method.
 */
{
    return YES;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent  {
    return YES;
}

/* Printing */

- (void)endPrologue
/*
 * Spit out the custom PostScript defs.
 */
{
    PSInit();
    [super endPrologue];
}

/*
 * These two method set and get the factory object used to create new
 * Graphic objects (i.e. the subclass of Graphic to use).
 * They are kind of weird since they check to see if the
 * Application object knows what the current graphic is.  If it does, then
 * it lets it handle these methods.  Otherwise, it determines the
 * current graphic by querying the sender to find out what its title is
 * and converts that title to the name to a factory object.  This allows
 * the GraphicView to stand on its own, but also use an application wide
 * tool palette if available.
 * If the GraphicView handles the current graphic by itself, it does so
 * by querying the sender of setCurrentGraphic: to find out its title.
 * It assumes, then, that that title is the name of the factory object to
 * use and calls NSClassFromString() to get a pointer to it.
 * If the application is not control what our current graphic is, then
 * we restrict creations to be made only when the control key is down.
 * Otherwise, it is the other way around (control key leaves creation
 * mode).  This is due to the fact that the application can be smart
 * enough to set appropriate cursors when a tool is on.  The GraphicView
 * can't be.
 */

- (Class)currentGraphic
{
    if ([NSApp respondsToSelector:@selector(currentGraphic)]) {
	return [NSApp currentGraphic];
    } else {
	return currentGraphic;
    }
}

/* sender could be an NSMenuItem or a matrix or something */

- (void)setCurrentGraphic:sender
{
    id item;
    if ([sender respondsTo:@selector(selectedCell)]) {
        item = [sender selectedCell];
    } else {
        item = sender;
    }
    if ([item respondsTo:@selector(title)]) {
        currentGraphic = NSClassFromString([item title]);
    }
}

/* These methods write out the form information. */

- (BOOL)hasFormEntries
{
    int i;
    for (i = [glist count]-1; i >= 0; i--) {
        if ([[glist objectAtIndex:i] isFormEntry]) return YES;
    }
    return NO;
}

- (void)writeFormEntriesToFile:(NSString *)file
{
    int i;
    NSMutableString *string;
    NSRect bounds = [self bounds];

    string = [NSMutableString stringWithFormat:@"Page Size: w = %d, h = %d\n", (int)bounds.size.width, (int)bounds.size.height];
    for (i = [glist count]-1; i >= 0; i--) {
	[[glist objectAtIndex:i] writeFormEntryToMutableString:string];
    }
    [string writeToFile:file atomically:NO];
}

/* Some graphics (notably Image) want to write out files when we save. */

- (BOOL)hasGraphicsWhichWriteFiles
{
    int i;
    for (i = [glist count]-1; i >= 0; i--) {
        if ([[glist objectAtIndex:i] writesFiles]) return YES;
    }
    return NO;
}

- (void)allowGraphicsToWriteFilesIntoDirectory:(NSString *)directory
{
    int i;

    for (i = [glist count]-1; i >= 0; i--) {
        [[glist objectAtIndex:i] writeFilesToDirectory:directory];
    }
}

/*
 * Target/Action methods.
 */

- (void)delete:(id)sender
{
    int i;
    Graphic *graphic;
    id change;

    i = [slist count];
    if (i > 0) {
	change = [[DeleteGraphicsChange alloc] initGraphicView:self];
	[change startChange];
	    [self graphicsPerform:@selector(deactivate)];
	    [slist makeObjectsPerform:@selector(activate)];
	    while (i--) {
		graphic = [slist objectAtIndex:i];
		[glist removeObject:graphic];
		[graphic wasRemovedFrom:self];
	    }
	    if (originalPaste == [slist objectAtIndex:0]) [slist removeObjectAtIndex:0];
	    [slist removeAllObjects];
	    gvFlags.groupInSlist = NO;
	    [[self window] flushWindow];
        [change endChange];
    } 
}

- (void)selectAll:(id)sender
/*
 * Selects all the items in the glist.
 */
{
    int i;
    Graphic *g;
    NSRect visibleRect;

    i = [glist count];
    if (!i) return;

    [slist removeAllObjects];
    [cacheImage lockFocus];
    while (i--) {
	g = [glist objectAtIndex:i];
	if (![g isLocked]) {
	    [g select];
	    [g draw:NSZeroRect];
	    [slist insertObject:g atIndex:0];
	    gvFlags.groupInSlist = gvFlags.groupInSlist || [g isKindOfClass:[Group class]];
	}
    }
    [Graphic showFastKnobFills];
    [cacheImage unlockFocus];
    visibleRect = [self visibleRect];
    if ([self canDraw]) {
	[self lockFocus];
	[self drawRect:visibleRect];
	[self unlockFocus];
    }  else  {
	[self setNeedsDisplay:YES];
    }
    if (sender != self) [[self window] flushWindow];
    gvFlags.selectAll = YES;
}

- (void)deselectAll:sender
/*
 * Deselects all the items in the slist.
 */
{
    NSRect sbounds;

    if ([slist count] > 0) {
	sbounds = [self getBBoxOfArray:slist];
	[slist makeObjectsPerform:@selector(deselect)];
	[self cache:sbounds andUpdateLinks:NO];
	[slist removeAllObjects];
	gvFlags.groupInSlist = NO;
	if (sender != self) [[self window] flushWindow];
    } 
}

- (void)lockGraphic:sender
/*
 * Locks all the items in the selection so that they can't be selected
 * or resized or moved.  Useful if there are some Graphics which are getting
 * in your way.  Undo this with unlockGraphic:.
 */
{
    id change;

    if ([slist count] > 0) {
	change = [[LockGraphicsChange alloc] initGraphicView:self];
	[change startChange];
	    gvFlags.locked = YES;
	    [slist makeObjectsPerform:@selector(lockGraphic)];
	    [self deselectAll:sender];
	[change endChange];
    } 
}

- (void)unlockGraphic:sender
{
    id change;

    change = [[UnlockGraphicsChange alloc] initGraphicView:self];
    [change startChange];
	[glist makeObjectsPerform:@selector(unlockGraphic)];
	gvFlags.locked = NO;
    [change endChange]; 
}

- (void)bringToFront:sender
/*
 * Brings each of the items in the slist to the front of the glist.
 * The item in the front of the slist will be the new front element
 * in the glist.
 */
{
    id change, temp;
    int i;

    i = [slist count];
    if (i) {
	change = [[BringToFrontGraphicsChange alloc] initGraphicView:self];
	[change startChange];
	    while (i--) {
		temp = [slist objectAtIndex:i];
		[glist removeObject:temp];
		[glist insertObject:temp atIndex:0];
	    }
	    [self recacheSelection];
	[change endChange];
    } 
}

- (void)sendToBack:sender
{
    int i, count;
    id change, temp;

    count = [slist count];
    if (count > 0) {
	change = [[SendToBackGraphicsChange alloc] initGraphicView:self];
	[change startChange];
	    for (i = 0; i < count; i++){
		temp = [slist objectAtIndex:i];
		[glist removeObject:temp];
		[glist addObject:temp];
	    }
	    [self recacheSelection];
	[change endChange];
    } 
}

- (void)group:sender
/*
 * Creates a new Group object with the current slist as its member list.
 * See the Group class for more info.
 */
{
    int i;
    Graphic *graphic;
    id change;

    i = [slist count];
    if (i > 1) {
	change = [[GroupGraphicsChange alloc] initGraphicView:self];
	[change startChange];
	    while (i--) [glist removeObject:[slist objectAtIndex:i]];
	    graphic = [[Group allocWithZone:[self zone]] initList:slist];
	    [change noteGroup:graphic];
	    [glist insertObject:graphic atIndex:0];
	    [slist removeAllObjects];
	    [slist addObject:graphic];
	    gvFlags.groupInSlist = YES;
	    [self cache:[graphic extendedBounds]];
	    if (sender != self) [[self window] flushWindow];
	[change endChange];
    } 
}


- (void)ungroup:sender
/*
 * Goes through the slist and ungroups any Group objects in it.
 * Does not descend any further than that (i.e. all the Group objects
 * in the slist are ungrouped, but any Group objects in those ungrouped
 * objects are NOT ungrouped).
 */
{
    int i, k;
    NSRect sbounds;
    id graphic;
    id change;

    if (gvFlags.groupInSlist && [slist count]) {
        change = [[UngroupGraphicsChange alloc] initGraphicView:self];
        [change startChange];
            sbounds = [self getBBoxOfArray:slist];
            i = [slist count];
            while (i--) {
                graphic = [slist objectAtIndex:i];
                if ([graphic isKindOfClass:[Group class]]) {
                    k = [glist indexOfObject:graphic];
                    [glist removeObjectAtIndex:k];
                    [graphic transferSubGraphicsTo:glist at:k];
                }
            }
            [self cache:sbounds];
            if (sender != self) [[self window] flushWindow];
            [self getSelection];
        [change endChange];
    }
}

/* sender could be an NSMenuItem or a matrix or something */

- (void)align:sender
{
    id item;
    if ([sender respondsTo:@selector(selectedCell)]) {
        item = [sender selectedCell];
    } else {
        item = sender;
    }
    if ([item respondsTo:@selector(tag)]) {
        [self alignBy:(AlignmentType)[item tag]];
    }
}

- (void)changeAspectRatio:sender
{
    id change;
    
    change = [[AspectRatioGraphicsChange alloc] initGraphicView:self];
    [change startChange];
	[self graphicsPerform:@selector(sizeToNaturalAspectRatio)];
    [change endChange];

    [[self window] flushWindow]; 
}

- (void)alignToGrid:sender
{
    id change;
    
    change = [[AlignGraphicsChange alloc] initGraphicView:self];
    [change startChange];
	[self graphicsPerform:@selector(alignToGrid:) with:self];
	[[self window] flushWindow];
    [change endChange]; 
}

- (void)sizeToGrid:sender
{
    id change;

    change = [[DimensionsGraphicsChange alloc] initGraphicView:self];
    [change startChange];
	[self graphicsPerform:@selector(sizeToGrid:) with:self];
	[[self window] flushWindow];
    [change endChange]; 
}

- (void)enableGrid:sender
/*
 * If the tag of the sender is non-zero, then gridding is enabled.
 * If the tag is zero, then gridding is disabled.
 * sender might be an NSMenuItem or a matrix of cells.
 */
{
    if ([sender respondsTo:@selector(selectedTag)]) {
        [self setGridEnabled:[sender selectedTag] ? YES : NO];
    } else if ([sender respondsTo:@selector(tag)]) {
        [self setGridEnabled:[sender tag] ? YES : NO];
    }
}

- (void)hideGrid:sender
/*
 * If the tag of the sender is non-zero, then the grid is made visible
 * otherwise, it is hidden (but still conceivable in effect).
 */
{
    if ([sender respondsTo:@selector(selectedTag)]) {
        [self setGridVisible:[sender selectedTag] ? YES : NO]; 
    } else if ([sender respondsTo:@selector(tag)]) {
        [self setGridVisible:[sender tag] ? YES : NO];
    }
}

- showLinks:sender
/*
 * If the tag of the sender is non-zero, then linked items are
 * shown with a border around them (see redrawLinkOutlines: in gvLinks.m).
 */
{
    if ([sender respondsTo:@selector(selectedTag)]) {
        [linkManager setLinkOutlinesVisible:[sender selectedTag] ? YES : NO];
    } else if ([sender respondsTo:@selector(tag)]) {
        [linkManager setLinkOutlinesVisible:[sender tag] ? YES : NO];
    }
    return self;
}

- (int)spellDocumentTag  {
    if (!spellDocTag)  {
	spellDocTag = [NSSpellChecker uniqueSpellDocumentTag];
    }
    return spellDocTag;
}

- (void)ignoreSpelling:(id)sender  {
    [[NSSpellChecker sharedSpellChecker] ignoreWord:[sender stringValue] inSpellDocumentWithTag:[self spellDocumentTag]];
}

- (void)checkSpelling:(id)sender  {
    int i;
    float curY, newY, maxY = 0.0;
    float curX, newX, maxX = 0.0;
    NSRect egbounds, gbounds;
    id fr = [[self window] firstResponder];
    Graphic *graphic, *editingGraphic, *newEditingGraphic = nil;
    NSRange range = {0,0};
    
    // These statics are used for keeping track of where spelling started in case there are no misspelled words so that we can know when to stop.
    static id startGraphic = nil;
    static BOOL oneMoreTime = NO;
    
    if ([fr isKindOfClass:[NSText class]])  {
	NSRange selRange = [fr selectedRange];
	range = [[NSSpellChecker sharedSpellChecker] checkSpellingOfString:[fr string] startingAt:(selRange.location + selRange.length) language:nil wrap:NO inSpellDocumentWithTag:[self spellDocumentTag] wordCount:NULL];
	if (range.length > 0)  {
	    [fr setSelectedRange:range];
	    [[NSSpellChecker sharedSpellChecker] updateSpellingPanelWithMisspelledWord:[[fr string] substringWithRange:range]];
	    startGraphic = nil;
	    oneMoreTime = NO;
	    return;
	}
    }

    if ([fr isKindOfClass:[NSText class]]) {
	editingGraphic = [fr delegate];
	if (!startGraphic)  {
	    startGraphic = editingGraphic;
	    oneMoreTime = YES;
	}
	egbounds = [editingGraphic bounds];
	curY = egbounds.origin.y + egbounds.size.height;
	curX = egbounds.origin.x;
    } else {
	curX = 0.0;
	curY = 10000.0;
    }
    maxY = 0.0; maxX = 10000.0;
    for (i = [glist count]-1; i >= 0; i--) {
	graphic = [glist objectAtIndex:i];
	if ([graphic isKindOfClass:[TextGraphic class]]) {
	    gbounds = [graphic bounds];
	    newY = gbounds.origin.y + gbounds.size.height;
	    newX = gbounds.origin.x;
	    if ((newY > maxY || (newY == maxY && newX < maxX)) && (newY < curY || (newY == curY && newX > curX))) {
		maxY = newY;
		maxX = newX;
		newEditingGraphic = graphic;
	    }
	}
    }
    [[self window] makeFirstResponder:self];
    if (newEditingGraphic) {
        [newEditingGraphic edit:NULL in:editView];
    }
    if ((startGraphic != newEditingGraphic) || oneMoreTime)  {
	if (startGraphic == newEditingGraphic)  {
	    oneMoreTime = NO;
	}
	[self checkSpelling:sender];
    }  else  {
	// We seem to have been once around the track already with no misspellings found.
	[[NSSpellChecker sharedSpellChecker] updateSpellingPanelWithMisspelledWord:@""];
	startGraphic = nil;
    }
}

- (void)showGuessPanel:(id)sender
{
    [[[NSSpellChecker sharedSpellChecker] spellingPanel] makeKeyAndOrderFront:sender];
}

/* Cover-Sheet items (see TextGraphic.m). */

- (void)doAddCoverSheetEntry:(id <NSMenuItem>)invokingMenuItem localizable:(BOOL)flag
{
    NSString *entry;
    entry = (NSString *)[invokingMenuItem tag];	// Yikes, casting int to NSString *!
    if ([entry isEqual:@""]) {
        entry = [invokingMenuItem title];
    }
    [self placeGraphic:[[TextGraphic allocWithZone:[self zone]] initFormEntry:entry localizable:flag] at:NULL];
}

- (void)addLocalizableCoverSheetEntry:(id <NSMenuItem>)invokingMenuItem
{
    [self doAddCoverSheetEntry:invokingMenuItem localizable:YES];
}

- (void)addCoverSheetEntry:(id <NSMenuItem>)invokingMenuItem
{
    [self doAddCoverSheetEntry:invokingMenuItem localizable:NO];
}

/*
 * Target/Action methods to change Graphic parameters from a Control.
 * If the sender is a PopUpList, then the indexOfSelectedItem is used to
 * determine the value to use (for linecap, linearrow, etc.) otherwise, the
 * sender's floatValue or intValue is used (whichever is appropriate).
 * This allows interface builders the flexibility to design different
 * ways of setting those values.
 */

- (void)takeGridValueFrom:sender
{
    [self setGridSpacing:[sender intValue]]; 
}

- (void)takeGridGrayFrom:sender
{
    [self setGridGray:[sender floatValue]]; 
}

- (void)takeGrayValueFrom:sender
{
    float value;

    value = [sender floatValue];
    [self graphicsPerform:@selector(setGray:) with:&value];
    [[self window] flushWindow]; 
}

- (void)takeLineWidthFrom:sender
{
    id change;
    float width = [sender floatValue];

    change = [[LineWidthGraphicsChange alloc] initGraphicView:self lineWidth:width];
    [change startChange];
	[self graphicsPerform:@selector(setLineWidth:) with:&width];
	[[self window] flushWindow];
    [change endChange]; 
}

- (void)takeLineJoinFrom:sender
{
    int joinValue;
    id change;

    if ([sender respondsToSelector:@selector(indexOfSelectedItem)])
        joinValue = [sender indexOfSelectedItem];
    else
        joinValue = [sender intValue];
    
    change = [[LineJoinGraphicsChange alloc] initGraphicView:self lineJoin:joinValue];
    [change startChange];
	[self graphicsPerform:@selector(setLineJoin:) with:(void *)joinValue];
	[[self window] flushWindow];
    [change endChange]; 
}

- (void)takeLineCapFrom:sender
{
    int capValue;
    id change;

    if ([sender respondsToSelector:@selector(indexOfSelectedItem)])
        capValue = [sender indexOfSelectedItem];
    else
        capValue = [sender intValue];
    
    change = [[LineCapGraphicsChange alloc] initGraphicView:self lineCap:capValue];
    [change startChange];
	[self graphicsPerform:@selector(setLineCap:) with:(void *)capValue];
	[[self window] flushWindow];
    [change endChange]; 
}

- (void)takeLineArrowFrom:sender
{
    int arrowValue;
    id change;

    if ([sender respondsToSelector:@selector(indexOfSelectedItem)])
        arrowValue = [sender indexOfSelectedItem];
    else
        arrowValue = [sender intValue];
    
    change = [[ArrowGraphicsChange alloc] initGraphicView:self lineArrow:arrowValue];
    [change startChange];
	[self graphicsPerform:@selector(setLineArrow:) with:(void *)arrowValue];
	[[self window] flushWindow];
    [change endChange]; 
}

- (void)takeFillValueFrom:sender
{
    int fillValue;
    id change;

    if ([sender respondsToSelector:@selector(indexOfSelectedItem)])
        fillValue = [sender indexOfSelectedItem];
    else
        fillValue = [sender intValue];
    
    change = [[FillGraphicsChange alloc] initGraphicView:self fill:fillValue];
    [change startChange];
	[self graphicsPerform:@selector(setFill:) with:(void *)fillValue];
	[[self window] flushWindow];
    [change endChange]; 
}

- (void)takeFrameValueFrom:sender
{
    if ([sender respondsToSelector:@selector(indexOfSelectedItem)]) {
	[self graphicsPerform:@selector(setFramed:) with:(void *)[sender indexOfSelectedItem]];
    } else {
	[self graphicsPerform:@selector(setFramed:) with:(void *)[sender intValue]];
    }
    [[self window] flushWindow]; 
}

- (void)takeLineColorFrom:sender
{
    id change;
    NSColor *color = [sender color];

    change = [[LineColorGraphicsChange alloc] initGraphicView:self color:color];
    [change startChange];
	[self graphicsPerform:@selector(setLineColor:) with:color];
	[[self window] flushWindow];
    [change endChange]; 
}

- (void)takeFillColorFrom:sender
{
    id change;
    NSColor *color = [sender color];

    change = [[FillGraphicsChange alloc] initGraphicView:self];
    [change startChange];
	[self graphicsPerform:@selector(setFillColor:) with:color];
	[[self window] flushWindow];
    [change endChange]; 
}

- (void)takeFormEntryStatusFrom:sender
{
    [self graphicsPerform:@selector(setFormEntry:) with:(void *)[sender intValue]];
    [[self window] flushWindow]; 
}

- (void)changeFont:(id)sender
{
    id change;

    if ([[self window] firstResponder] == self) {
	change = [[MultipleChange alloc] initChangeName:FONT_OP];
	[change startChange];
	    [self graphicsPerform:@selector(changeFont:) with:sender];
	    [[self window] flushWindow];
	[change endChange];
    }
}

/* Archiver-related methods. */

#define GRAPHICS_KEY @"Graphics"

- (void)convertSelf:(ConversionDirection)setting propertyList:(id)plist
{
    PL_FLAG(plist, gvFlags.gridDisabled, @"GridDisabled", setting);
    PL_FLAG(plist, gvFlags.locked, @"SomeGraphicsAreLocked", setting);
    PL_FLAG(plist, gvFlags.showGrid, @"GridVisible", setting);
    PL_FLAG(plist, gvFlags.groupInSlist, @"GroupInTheSelection", setting);
    PL_FLOAT(plist, gridGray, @"GridGray", setting);
    PL_INT(plist, gvFlags.grid, @"GridSize", setting);
}

- (id)propertyList
{
    NSMutableDictionary *plist = [NSMutableDictionary dictionaryWithCapacity:7];
    [self convertSelf:ToPropertyList propertyList:plist];
    [plist setObject:propertyListFromArray(glist) forKey:GRAPHICS_KEY];
    return plist;
}

- (NSString *)description
{
    Graphic *graphic;
    NSMutableDictionary *plist = [NSMutableDictionary dictionaryWithCapacity:8];
    NSMutableArray *array;
    NSEnumerator *enumerator;

    [self convertSelf:ToPropertyList propertyList:plist];

    array = [NSMutableArray arrayWithCapacity:[glist count]];
    enumerator = [glist objectEnumerator];
    while ((graphic = [enumerator nextObject])) {
        [array addObject:[NSString stringWithFormat:@"0x%x", (int)graphic]];
    }
    [plist setObject:array forKey:GRAPHICS_KEY]; // don't expand them in description

    array = [NSMutableArray arrayWithCapacity:[slist count]];
    enumerator = [slist objectEnumerator];
    while ((graphic = [enumerator nextObject])) {
        [array addObject:[NSString stringWithFormat:@"0x%x", (int)graphic]];
    }
    [plist setObject:array forKey:@"Selection"];

    return [plist description];
}

- initWithFrame:(NSRect)frame fromPropertyList:(id)plist inDirectory:(NSString *)directory
{
    [super initWithFrame:frame];
    [self convertSelf:FromPropertyList propertyList:plist];
    glist = arrayFromPropertyList([plist objectForKey:GRAPHICS_KEY], directory, [self zone]);
    slist = [[NSMutableArray allocWithZone:[self zone]] initWithCapacity:[glist count]];
    [self getSelection];
    gvFlags.grid = 10;
    gvFlags.gridDisabled = 1;
    gridGray = DEFAULT_GRID_GRAY;
    [self resetGUP];
    [self allocateGState];
    PSInit();
    currentGraphic = [Rectangle class];	      /* default graphic */
    currentGraphic = [self currentGraphic];   /* trick to allow NSApp to control currentGraphic */
    editView = [self createEditView];
    if (!InMsgPrint) {
        NSRect bounds = [self bounds];
        cacheImage = [[NSImage allocWithZone:[self zone]] initWithSize:bounds.size];
        [self cache:bounds andUpdateLinks:NO];
    }
    [[self class] initClassVars];
    [self registerForDragging];
    spellDocTag = 0;
    return self;
}

/* Methods to deal with being/becoming the First Responder */

/* Strings that appear in menus. */

static NSString *hideGrid;
static NSString *showGrid;
static NSString *turnGridOff;
static NSString *turnGridOn;
static NSString *showLinks;
static NSString *hideLinks;
static BOOL menuStringsInitted = NO;

static void initMenuItemStrings(void)
{
    hideGrid = HIDE_GRID;
    showGrid = SHOW_GRID;
    turnGridOff = TURN_GRID_OFF;
    turnGridOn = TURN_GRID_ON;
    showLinks = SHOW_LINKS;
    hideLinks = HIDE_LINKS;
    menuStringsInitted = YES;
}

/* Validates whether a menu command makes sense now */

static BOOL updateMenuItem(id <NSMenuItem> menuItem, NSString *zeroItem, NSString *oneItem, BOOL state)
{
    if (state) {
        if ([menuItem tag] != 0) {
            [menuItem setTitleWithMnemonic:zeroItem];
            [menuItem setTag:0];
            [menuItem setEnabled:NO];	// causes it to get redrawn
	}
    } else {
        if ([menuItem tag] != 1) {
            [menuItem setTitleWithMnemonic:oneItem];
            [menuItem setTag:1];
            [menuItem setEnabled:NO];	// causes it to get redrawn
	}
    }

    return YES;
}

- (BOOL)validateMenuItem:(id <NSMenuItem>)anItem
/*
 * Can be called to see if the specified action is valid on this view now.
 * It returns NO if the GraphicView knows that action is not valid now,
 * otherwise it returns YES.  Note the use of the Pasteboard change
 * count so that the GraphicView does not have to look into the Pasteboard
 * every time paste: is validated.
 */
{
    NSPasteboard *pb;
    int i, count, gcount;
    SEL action = [anItem action];
    static BOOL pboardHasPasteableType = NO;
    static BOOL pboardHasPasteableLink = NO;
    static int cachedPasteboardChangeCount = - 1;

    if (!menuStringsInitted) initMenuItemStrings();
    if (action == @selector(bringToFront:)) {
	if ((count = [slist count]) && [glist count] > count) {
	    for (i = 0; i < count; i++) {
		if ([slist objectAtIndex:i] != [glist objectAtIndex:i]) {
		    return YES;
		}
	    }
	}
	return NO;
    } else if (action == @selector(sendToBack:)) {
	if ((count = [slist count]) && (gcount = [glist count]) > count) {
	    for (i = 1; i <= count; i++) {
		if ([slist objectAtIndex:count-i] != [glist objectAtIndex:gcount-i]) {
		    return YES;
		}
	    }
	}
	return NO;
    } else if (action == @selector(group:) ||
	action == @selector(align:)) {
	return([slist count] > 1);
    } else if (action == @selector(ungroup:)) {
	return(gvFlags.groupInSlist && [slist count] > 0);
    } else if (action == @selector(checkSpelling:)) {
	for (i = [glist count]-1; i >= 0; i--) if ([[glist objectAtIndex:i] isKindOfClass:[TextGraphic class]]) return YES;
	return NO;
    } else if (action == @selector(deselectAll:) ||
	action == @selector(lockGraphic:) ||
	action == @selector(changeAspectRatio:) ||
	action == @selector(cut:) ||
	action == @selector(copy:)) {
	return([slist count] > 0);
    } else if (action == @selector(alignToGrid:) ||
	action == @selector(sizeToGrid:)) {
	return(GRID > 1 && [slist count] > 0);
    } else if (action == @selector(unlockGraphic:)) {
	return gvFlags.locked;
    } else if (action == @selector(selectAll:)) {
	return([glist count] > [slist count]);
    } else if (action == @selector(paste:) || action == @selector(pasteAndLink:) || action == @selector(link:)) {
	pb = [NSPasteboard generalPasteboard];
	count = [pb changeCount];
	if (count != cachedPasteboardChangeCount) {
	    cachedPasteboardChangeCount = count;
	    pboardHasPasteableType = (DrawPasteType([pb types]) != NULL);
	    pboardHasPasteableLink = pboardHasPasteableType ? IncludesType([pb types], NSDataLinkPboardType) : NO;
	}
	return (action == @selector(paste:)) ? pboardHasPasteableType : pboardHasPasteableLink;
    } else if (action == @selector(hideGrid:)) {
	return (gvFlags.grid >= 4) ? updateMenuItem(anItem, hideGrid, showGrid, [self gridIsVisible]) : NO;
    } else if (action == @selector(enableGrid:)) {
	return (gvFlags.grid > 1) ? updateMenuItem(anItem, turnGridOff, turnGridOn, [self gridIsEnabled]) : NO;
    } else if (action == @selector(showLinks:)) {
	return linkManager ? updateMenuItem(anItem, hideLinks, showLinks, [linkManager areLinkOutlinesVisible]) : NO;
    }

    return YES;
}

/* Useful scrolling routines. */

- (void)scrollGraphicToVisible:(Graphic *)graphic
{
    NSPoint p;
    NSRect bounds = [self bounds];

    p = bounds.origin;
    NSContainsRect([graphic extendedBounds], bounds);
    p.x -= bounds.origin.x;
    p.y -= bounds.origin.y;
    if (p.x || p.y) {
	[graphic moveBy:&p];
	bounds.origin.x += p.x;
	bounds.origin.y += p.y;
	[self scrollRectToVisible:[graphic extendedBounds]];
    } 
}

- (void)scrollPointToVisible:(NSPoint)point
{
    NSRect r;

    r.origin.x = point.x - 5.0;
    r.origin.y = point.y - 5.0;
    r.size.width = r.size.height = 10.0;

    [self scrollRectToVisible:r];
}

- (void)scrollSelectionToVisible
{
    NSRect sbounds;

    if ([slist count]) {
	sbounds = [self getBBoxOfArray:slist];
	[self scrollRectToVisible:sbounds];
    } 
}

/* Private selection management methods. */

- (NSImage *)selectionCache
{
    static NSImage *selectioncache = nil;
    if (!selectioncache) selectioncache = [[NSImage allocWithZone:[self zone]] initWithSize:[self getBBoxOfArray:slist].size];
    return selectioncache;
}

- (NSRect)getBBoxOfArray:(NSArray *)array extended:(BOOL)extended
/*
 * Returns a rectangle which encloses all the objects in the list.
 */
{
    int i;
    NSRect bbox, eb;

    i = [array count];
    if (i) {
	if (extended) {
	    bbox = [[array objectAtIndex:--i] extendedBounds];
	    while (i--) bbox = NSUnionRect([[array objectAtIndex:i] extendedBounds], bbox);
	} else {
	    bbox = [[array objectAtIndex:--i] bounds];
	    while (i--) {
		eb = [[array objectAtIndex:i] bounds];
		bbox = NSUnionRect(eb, bbox);
	    }
	}
    } else {
	bbox.size = NSZeroSize;
    }

    return bbox;
}

- (void)recacheSelection:(BOOL)updateLinks
 /*
  * Redraws the selection in the off-screen cache (not the selection cache),
  * then composites it back on to the screen.
  */
{
    NSRect sbounds;
    
    if ([slist count]) {
	sbounds = [self getBBoxOfArray:slist];
	gvFlags.cacheing = YES;
	[self drawRect:sbounds];
	gvFlags.cacheing = NO;
	[self displayRect:sbounds];
	if (updateLinks && !gvFlags.suspendLinkUpdate) [self updateTrackedLinks:sbounds];
    } 
}

- (void)recacheSelection
{
    return [self recacheSelection:YES];
}

- (void)compositeSelection:(NSRect)sbounds
/*
 * Composites from the selection cache whatever part of sbounds is
 * currently visible in the View.  Assumes we're lockFocus'ed on self.
 */
{
    NSRect rect = sbounds;
    rect.origin = NSZeroPoint;
    [[self selectionCache] compositeToPoint:sbounds.origin fromRect:rect operation:NSCompositeSourceOver];
    [[self window] flushWindow];
    PSWait(); 
}

- (void)cacheList:(NSArray *)array into:(NSImage *)aCache withTransparentBackground:(BOOL)transparentBackground
 /*
  * Caches the selection into the application-wide selection cache
  * window (a window which has alpha in it).  See also: selectionCache:.
  * It draws the objects without their knobbies in the selection cache,
  * but it leaves them selected.
  */
{
    int i;
    NSRect sbounds;
    NSSize scsize;

    sbounds = [self getBBoxOfArray:array];
    scsize = [aCache size];
    if (scsize.width < sbounds.size.width || scsize.height < sbounds.size.height) {
	[aCache setSize:(NSSize){MAX(scsize.width, sbounds.size.width), MAX(scsize.height, sbounds.size.height)}];
    }
    [aCache lockFocus];
    PSsetgray(NSWhite);
    PSsetalpha(transparentBackground ? 0.0 : 1.0);	/* 0.0 means fully transparent */
    PStranslate(- sbounds.origin.x, - sbounds.origin.y);
    sbounds.size.width += 1.0;
    sbounds.size.height += 1.0;
    NSRectFill(sbounds);
    sbounds.size.width -= 1.0;
    sbounds.size.height -= 1.0;
    PSsetalpha(1.0);					/* set back to fully opaque */ 
    i = [array count];
    while (i--) {
        Graphic *g = [array objectAtIndex:i];
        [g deselect];
        [g draw:NSZeroRect];
        [g select];
    }
    [Graphic showFastKnobFills];
    PStranslate(sbounds.origin.x, sbounds.origin.y);
    [aCache unlockFocus];
}

- (void)cacheList:(NSArray *)array into:(NSImage *)aCache
{
    [self cacheList:array into:aCache withTransparentBackground:YES];
}

- (void)cacheSelection
{
    [self cacheList:slist into:[self selectionCache] withTransparentBackground:YES];
}

/* Other private methods. */

- (void)cacheGraphic:(Graphic *)graphic
 /*
  * Draws the graphic into the off-screen cache, then composites
  * it back to the screen.
  * NOTE: This ONLY works if the graphic is on top of the list!
  * That is why it is a private method ...
  */
{
    [cacheImage lockFocus];
    [graphic draw:NSZeroRect];
    [Graphic showFastKnobFills];
    [cacheImage unlockFocus];
    [self displayRect:[graphic extendedBounds]]; 
}

- (void)resetGUP
/*
 * The "GUP" is the Grid User Path.  It is a user path which draws a grid
 * the size of the bounds of the GraphicView.  This gets called whenever
 * the View is resized or the grid spacing is changed.  It sets up all
 * the arguments to DPSDoUserPath() called in drawSelf::.
 */
{
    int x, y, i, j;
    short w, h;
    NSZone *zone = [self zone];
    NSRect bounds = [self bounds];

    if (gvFlags.grid < 4) return;

    x = (int)bounds.size.width / (gvFlags.grid ? gvFlags.grid : 1);
    y = (int)bounds.size.height / (gvFlags.grid ? gvFlags.grid : 1);
    gupLength = (x << 2) + (y << 2);
    if (gupCoords) {
	NSZoneFree(zone, gupCoords);
	NSZoneFree(zone, gupOps);
	NSZoneFree(zone, gupBBox);
    }
    gupCoords = NSZoneMalloc(zone, (gupLength) * sizeof(short));
    gupOps = NSZoneMalloc(zone, (gupLength >> 1) * sizeof(char));
    gupBBox = NSZoneMalloc(zone, (4) * sizeof(short));
    w = bounds.size.width;
    h = bounds.size.height;
    j = 0;
    for (i = 1; i <= y; i++) {
	gupCoords[j++] = 0.0;
	gupCoords[j++] = i * (gvFlags.grid ? gvFlags.grid : 1);
	gupCoords[j++] = w;
	gupCoords[j] = gupCoords[j-2];
	j++;
    }
    for (i = 1; i <= x; i++) {
	gupCoords[j++] = i * (gvFlags.grid ? gvFlags.grid : 1);
	gupCoords[j++] = 0.0;
	gupCoords[j] = gupCoords[j-2];
	j++;
	gupCoords[j++] = h;
    }
    i = gupLength >> 1;
    while (i) {
	gupOps[--i] = dps_lineto;
	gupOps[--i] = dps_moveto;
    }
    gupBBox[0] = gupBBox[1] = 0;
    gupBBox[2] = bounds.size.width + 1;
    gupBBox[3] = bounds.size.height + 1; 
}

#define MOVE_MASK NSLeftMouseUpMask|NSLeftMouseDraggedMask

- (BOOL)move:(NSEvent *)event 
/*
 * Moves the selection by cacheing the selected graphics into the
 * selection cache, then compositing them repeatedly as the user
 * moves the mouse.  The tracking loop uses TIMER events to autoscroll
 * at regular intervals.  TIMER events do not have valid mouse coordinates,
 * so the last coordinates are saved and restored when there is a TIMER event.
 */
{
    NSEvent *peek;
    float dx, dy;
    NSWindow *window = [self window];
    BOOL inTimerLoop = NO;
    
    NSPoint p, start, last, sboundspad;
    NSRect minbounds, sbounds, startbounds, visibleRect;
    BOOL canScroll, tracking = YES, alternate, horizConstrain = NO, vertConstrain = NO, hideCursor;

    last = [event locationInWindow];
    alternate = ([event modifierFlags] & NSAlternateKeyMask) ? YES : NO;

    event = [window nextEventMatchingMask:MOVE_MASK];
    if ([event type] == NSLeftMouseUp) return NO;

    hideCursor = [[NSUserDefaults standardUserDefaults] objectForKey:@"HideCursorOnMove"] ? YES : NO;
    if (hideCursor) [NSCursor hide];

    last = [self convertPoint:last fromView:nil];
    last = [self grid:last];

    [self lockFocus];

    [self cacheSelection];
    gvFlags.suspendLinkUpdate = YES;	/* we'll update links when the move is complete */
    [self graphicsPerform:@selector(deactivate)];
    gvFlags.suspendLinkUpdate = NO;
    sbounds = [self getBBoxOfArray:slist];
    startbounds = sbounds;
    minbounds = [self getBBoxOfArray:slist extended:NO];
    sboundspad.x = minbounds.origin.x - sbounds.origin.x;
    sboundspad.y = minbounds.origin.y - sbounds.origin.y;
    [self compositeSelection:sbounds];

    visibleRect = [self visibleRect];
    canScroll = !NSEqualRects(visibleRect, [self bounds]);

    start = sbounds.origin;

    while (tracking) {
	p = [event locationInWindow];
	p = [self convertPoint:p fromView:nil];
	p = [self grid:p];
	dx = p.x - last.x;
	dy = p.y - last.y;
	if (dx || dy) {
	    [self drawRect:sbounds];
	    if (alternate && (dx || dy)) {
		if (ABS(dx) > ABS(dy)) {
		    horizConstrain = YES;
		    dy = 0.0;
		} else {
		    vertConstrain = YES;
		    dx = 0.0;
		}
		alternate = NO;
	    } else if (horizConstrain) {
		dy = 0.0;
	    } else if (vertConstrain) {
		dx = 0.0;
	    }
	    sbounds = NSOffsetRect(sbounds, dx, dy);
	    minbounds.origin.x = sbounds.origin.x + sboundspad.x;
	    minbounds.origin.y = sbounds.origin.y + sboundspad.y;
	    [self tryToPerform:@selector(updateRulers:) with:(void *)&minbounds];
	    if (!canScroll || NSContainsRect(visibleRect, sbounds)) {
		[self compositeSelection:sbounds];
		if(inTimerLoop){
		    [NSEvent stopPeriodicEvents];
		    inTimerLoop = NO;
		}
	    }
	    last = p;
	}
	tracking = ([event type] != NSLeftMouseUp);
	if (tracking) {
	    if (canScroll && !NSContainsRect(visibleRect, sbounds)) {
		[window disableFlushWindow];
		[self scrollPointToVisible:p];  // actually we want to keep the "edges" of the
						// Graphic being resized that were visible when
						// the move started visible throughout the
						// moving session, this current solution is
                				// easy, but sub-standard
		visibleRect = [self visibleRect];
		[self compositeSelection:sbounds];
		[window update];
		[window enableFlushWindow];
		[window flushWindow];
		if(!inTimerLoop){
		    [NSEvent startPeriodicEventsAfterDelay:0.1 withPeriod:0.1];
		    inTimerLoop = YES;
		}
	    }
	    p = [event locationInWindow];
	    if (!(peek = [window nextEventMatchingMask:MOVE_MASK untilDate:[NSDate date] inMode:NSEventTrackingRunLoopMode dequeue:NO])) {
		event = [window nextEventMatchingMask:MOVE_MASK|NSPeriodicMask];
	    } else {
		event = [window nextEventMatchingMask:MOVE_MASK];
	    }
	    if ([event type] == NSPeriodic) event = periodicEventWithLocationSetToPoint(event, p);
	}
    }

    if (canScroll && inTimerLoop){
    	[NSEvent stopPeriodicEvents];
	inTimerLoop = NO;
    }

    if (hideCursor) [NSCursor unhide];

    p.x = sbounds.origin.x - start.x;
    p.y = sbounds.origin.y - start.y;
    if (p.x || p.y)
        [self moveGraphicsBy:p andDraw:NO];

    gvFlags.suspendLinkUpdate = YES;	/* we'll update links when the move is complete */
    [self graphicsPerform:@selector(activate)];
    gvFlags.suspendLinkUpdate = NO;
    startbounds = NSUnionRect(sbounds, startbounds);
    [self updateTrackedLinks:startbounds];

    [self tryToPerform:@selector(updateRulers:) with:nil];

    [[self window] flushWindow];
    [self unlockFocus];

    return YES;
}

- (void)moveGraphicsBy:(NSPoint)vector andDraw:(BOOL)drawFlag
{
    id change;

    change = [[MoveGraphicsChange alloc] initGraphicView:self vector:vector];
    [change startChange];
	if (drawFlag) {
	    [self graphicsPerform:@selector(moveBy:) with:(id)&vector];
	} else {
	    [slist makeObjectsPerform:@selector(moveBy:) withObject:(id)&vector];
	}
    [change endChange]; 
}

#define DRAG_MASK (NSLeftMouseUpMask|NSLeftMouseDraggedMask|NSPeriodicMask)

- (void)dragSelect:(NSEvent *)event 
/*
 * Allows the user the drag out a box to select all objects either
 * intersecting the box, or fully contained within the box (depending
 * on the state of the ALTERNATE key).  After the selection is made,
 * the slist is updated.
 */
{
    int i;
    Graphic *graphic;
    NSWindow *window = [self window];
    NSPoint p, last, start;
    BOOL inTimerLoop = NO;
    NSRect eb;
    NSRect visibleRect, region, oldRegion;
    BOOL mustContain, shift, canScroll, oldRegionSet = NO;

    p = start = [event locationInWindow];
    start = [self convertPoint:start fromView:nil];
    last = start;
    region = regionFromCorners(last, start);

    shift = ([event modifierFlags] & NSShiftKeyMask) ? YES : NO;
    mustContain = ([event modifierFlags] & NSAlternateKeyMask) ? YES : NO;

    [self lockFocus];

    visibleRect = [self visibleRect];
    canScroll = !NSEqualRects(visibleRect, [self bounds]);
    if (canScroll && !inTimerLoop) {
    	[NSEvent startPeriodicEventsAfterDelay:0.1 withPeriod:0.1];
	inTimerLoop = YES;
    }
    PSsetgray(NSLightGray);
    PSsetlinewidth(0.0);

    event = [window nextEventMatchingMask:DRAG_MASK];
    while ([event type] != NSLeftMouseUp) {
	if ([event type] == NSPeriodic) event = periodicEventWithLocationSetToPoint(event, p); 
	p = [event locationInWindow];
	p = [self convertPoint:p fromView:nil];
	if (p.x != last.x || p.y != last.y) {
	    region = regionFromCorners(p, start);
	    [window disableFlushWindow];
	    if (oldRegionSet) {
		oldRegion = NSInsetRect(oldRegion, -1.0, -1.0);
		[self drawRect:oldRegion];
	    }
	    if (canScroll) {
		[self scrollRectToVisible:region];
		[self scrollPointToVisible:p];
	    }
	    PSrectstroke(region.origin.x, region.origin.y, region.size.width, region.size.height);
	    [self tryToPerform:@selector(updateRulers:) with:(void *)&region];
	    [window enableFlushWindow];
	    [window flushWindow];
	    oldRegion = region; oldRegionSet = YES;
	    last = p;
	    PSWait();
	}
	p = [event locationInWindow];
	event = [window nextEventMatchingMask:DRAG_MASK];
    }

    if (canScroll && inTimerLoop){
	[NSEvent stopPeriodicEvents];
	inTimerLoop = NO;
    }
    for (i = [glist count] - 1; i >= 0; i--) {
 	graphic = [glist objectAtIndex:i];
	eb = [graphic extendedBounds];
	if (![graphic isLocked] && ![graphic isSelected] && 
	    ((mustContain && NSContainsRect(region, eb)) ||
	     (!mustContain && !NSIsEmptyRect(NSIntersectionRect(region, eb))))) {
	    [graphic select];
	}
    }
    [self getSelection];

    if (!dragRect) dragRect = NSZoneMalloc(NSDefaultMallocZone(), ((1) * sizeof(NSRect)));
    *dragRect = region;

    region = NSInsetRect(region, -1.0, -1.0);
    [self drawRect:region];
    [self recacheSelection:NO];

    [self tryToPerform:@selector(updateRulers:) with:nil];

    [self unlockFocus]; 
}

- (void)alignGraphicsBy:(AlignmentType)alignType edge:(float *)edge
{
    SEL	action;
    id change;
    
    change = [[AlignGraphicsChange alloc] initGraphicView:self];
    [change startChange];
        action = [GraphicView actionFromAlignType:alignType];
	[self graphicsPerform:action with:edge];
    [change endChange]; 
}

- (void)alignBy:(AlignmentType)alignType
{
    int i;
    NSRect rect;
    Graphic *graphic;
    float minEdge = 10000.0;
    float maxEdge = 0.0;
    float baseline = 0.0;

    for (i = [slist count]-1; i >= 0 && !baseline; i--) {
	graphic = [slist objectAtIndex:i];
	rect = [graphic bounds];
	switch (alignType) {
	    case LEFT:
	 	if (rect.origin.x < minEdge) 
		    minEdge = rect.origin.x;
	        break;
	    case RIGHT:
		if (rect.origin.x + rect.size.width > maxEdge) 
		    maxEdge = rect.origin.x + rect.size.width;
	        break;
	    case BOTTOM:
		if (rect.origin.y < minEdge) 
		    minEdge = rect.origin.y;
	        break;
	    case TOP:
		if (rect.origin.y + rect.size.height > maxEdge) 
		    maxEdge = rect.origin.y + rect.size.height;
	        break;
	    case HORIZONTAL_CENTERS:
		if (rect.origin.y + floor(rect.size.height / 2.0) < minEdge)
		    minEdge = rect.origin.y + floor(rect.size.height / 2.0);
	        break;
	    case VERTICAL_CENTERS:
		if (rect.origin.x + floor(rect.size.width / 2.0) < minEdge)
		    minEdge = rect.origin.x + floor(rect.size.width / 2.0);
	        break;
	    case BASELINES:
		baseline = [graphic baseline];
	        break;
	}
    }

    switch (alignType) {
        case LEFT:
        case BOTTOM:
        case HORIZONTAL_CENTERS:
        case VERTICAL_CENTERS:
	    [self alignGraphicsBy:alignType edge:&minEdge];
	    break;
        case RIGHT:
        case TOP:
	    [self alignGraphicsBy:alignType edge:&maxEdge];
	    break;
	case BASELINES:
	    if (baseline) [self alignGraphicsBy:alignType edge:&baseline];
    }
    [[self window] flushWindow]; 
}

@end

extern NSEvent *periodicEventWithLocationSetToPoint(NSEvent *oldEvent, NSPoint point) {
    return [NSEvent otherEventWithType:[oldEvent type] location:point modifierFlags:[oldEvent modifierFlags]
                             timestamp:[oldEvent timestamp] windowNumber:[oldEvent windowNumber] context:[oldEvent context]
                               subtype:[oldEvent subtype] data1:[oldEvent data1] data2:[oldEvent data2]];
}
