#import "draw.h"

@implementation GraphicView(Links)

/* See the Links.rtf file for overview about Object Links in Draw. */

#define BUFFER_SIZE 1100
#define INT_WIDTH 11

/*
 * Returns an NSSelection describe the current Graphic's selected in the view.
 * If the user did Select All, then the gvFlags.selectAll bit is set and we
 * return the allSelection NSSelection.  If the user dragged out a rectangle,
 * then the dragRect rectangle is set and we return a ByRect NSSelection.
 * Otherwise, we return a ByGraphic NSSelection.
 *
 * We use the identifierString mechanism so that Group Graphic's can ask
 * their components to write out all their identifiers so that we have a
 * maximal chance of getting all the objects.
 */

- (NSSelection *)currentSelection
{
    NSString *selectionString;

    if (![slist count]) return [NSSelection emptySelection];

    if (gvFlags.selectAll) {
	if ([slist count] == [glist count]) {
	    return [NSSelection allSelection];
	} else {
	    gvFlags.selectAll = NO;
	}
    }

    if (dragRect) {
	selectionString = [NSString stringWithFormat:@"%d %d %d %d %d",
	    ByRect, dragRect->origin.x, dragRect->origin.y, (int)(dragRect->size.width+0.5), (int)(dragRect->size.height+0.5)];
    } else {
        int i = [slist count];
	NSMutableString *mselString = [NSMutableString stringWithFormat:@"%d %d", ByList, i];
	while (i--) [mselString appendFormat:@" %@", [[slist objectAtIndex:i] identifierString]];
	selectionString = mselString;
    }

    return [[NSSelection allocWithZone:(NSZone *)[self zone]] initWithDescriptionData:[selectionString dataUsingEncoding:NSASCIIStringEncoding]];
}

/*
 * Purely for code beautification.
 * Returns an array of all the elements in an NSSelection.
 * Assumes they are all space separated (which is the only kind of
 * NSSelection's Draw creates).
 */

static inline NSArray *NSArrayFromNSSelection(NSSelection *selection)
{
    return [[[[NSString alloc] initWithData:[selection descriptionData] encoding:NSASCIIStringEncoding] autorelease] componentsSeparatedByString:@" "];
}

/*
 * Used for destination selections only.
 * Just extracts the unique identifier for the destination Image
 * or TextGraphic and then searches through the glist to find that
 * Graphic and returns it.
 *
 * Again, we use the graphicIdentifiedBy: mechanism so that we
 * descend into Group's of Graphics to find a destination.
 */

- (Graphic *)findGraphicInSelection:(NSSelection *)selection
{
    int i, identifier;
    Graphic *graphic;
    NSArray *selectionInfo;

    if ((selectionInfo = NSArrayFromNSSelection(selection))) {
        if ([[selectionInfo objectAtIndex:0] intValue] == ByGraphic) {
	    identifier = [[selectionInfo objectAtIndex:1] intValue];
	    for (i = [glist count]-1; i >= 0; i--) {
		if ((graphic = [[glist objectAtIndex:i] graphicIdentifiedBy:identifier])) return graphic;
	    }
	}
    }

    return nil;
}

/*
 * Returns YES and theRect is valid only if the selection is one which
 * the user created by dragging out a rectangle.
 */

- (BOOL)getRect:(NSRect *)theRect forSelection:(NSSelection *)selection
{
    NSString *selectionType;
    NSArray *selectionInfo;

    if ((selectionInfo = NSArrayFromNSSelection(selection))) {
	selectionType = [selectionInfo objectAtIndex:0];
	if (([selectionType length] == 1) && ([selectionType intValue] == ByRect)) {
            if (theRect) {
                theRect->origin.x = [[selectionInfo objectAtIndex:1] floatValue];
                theRect->origin.y = [[selectionInfo objectAtIndex:2] floatValue];
                theRect->size.width = [[selectionInfo objectAtIndex:3] floatValue];
                theRect->size.height = [[selectionInfo objectAtIndex:4] floatValue];
	    }
            return YES;
        }
    }

    return NO;
}

/*
 * For source selections only.
 * Returns the list of Graphics in the current document which were
 * in the selection passed to this method.  Note that any Group 
 * which includes a Graphic in the passed selection will be included
 * in its entirety.
 *
 * Return value is autoreleased.
 */

- (NSArray *)findGraphicsInSelection:(NSSelection *)selection
{
    Graphic *graphic;
    NSArray *selectionInfo;
    NSMutableArray *array = nil;
    int i, j, count, selectionCount;
    NSRect sBounds, gBounds;

    if ([selection isEqual:[NSSelection allSelection]]) {
	count = [glist count];
	array = [[NSMutableArray allocWithZone:(NSZone *)[self zone]] initWithCapacity:count];
	for (i = 0; i < count; i++) [array addObject:[glist objectAtIndex:i]];
    } else if ([self getRect:&sBounds forSelection:selection]) {
	count = [glist count];
	array = [[NSMutableArray allocWithZone:(NSZone *)[self zone]] init];
	for (i = 0; i < count; i++) {
	    graphic = [glist objectAtIndex:i];
	    gBounds = [graphic bounds];
	    gBounds = NSInsetRect(gBounds, -0.1, -0.1);
	    if (!NSIsEmptyRect(NSIntersectionRect(gBounds, sBounds))) [array addObject:graphic];
	}
    } else if ((selectionInfo = NSArrayFromNSSelection(selection))) {
	if ([[selectionInfo objectAtIndex:0] intValue] == ByList) {
            selectionCount = [[selectionInfo objectAtIndex:1] intValue];
            array = [[NSMutableArray allocWithZone:(NSZone *)[self zone]] init];
            count = [glist count];
            for (i = 0; i < count; i++) {
                graphic = [glist objectAtIndex:i];
                for (j = 0; j < selectionCount; j++) {
                    if ([graphic graphicIdentifiedBy:[[selectionInfo objectAtIndex:j+2] intValue]]) {
                        [array addObject:graphic];
                        break;
                    }
                }
            }
	}
    }

    if (![array count]) {
        [array release];
	array = nil;
    }

    return [array autorelease];
}

/*
 * Importing/Exporting links.
 */

/*
 * This method is called by copyToPasteboard:.  It just puts a link to the currentSelection
 * (presumably just written to the pasteboard by copyToPasteboard:) into the specified
 * pboard.  Note that it only does all this if we are writing all possible types to the
 * pasteboard (typesList == NULL) or if we explicitly ask for the link to be written
 * (typesList includes NSDataLinkPboardType).
 */

- (void)writeLinkToPasteboard:(NSPasteboard *)pboard types:(NSArray *)typesList
{
    NSDataLink *link;

    if (linkManager && (!typesList || IncludesType(typesList, NSDataLinkPboardType))) {
	NSArray *typesDrawExports = TypesDrawExports();
	if ((link = [[NSDataLink alloc] initLinkedToSourceSelection:[self currentSelection] managedBy:linkManager supportingTypes:typesDrawExports])) {
	    [pboard addTypes:[[[NSArray alloc] initWithObjects:NSDataLinkPboardType, nil] autorelease] owner:[self class]];
	    [link writeToPasteboard:pboard];
	    [link release];
	}
	[linkManager writeLinksToPasteboard:pboard]; // for embedded linked things
    } 
}

/*
 * Sets up a link from the Draw document to another document.
 * This is called by the drag stuff (gvDrag.m) and the normal copy/paste stuff (gvPasteboard.m).
 * We allow for the case of graphic being nil as long as the link is capable of supplying
 * data of a type we can handle (currently Text or Image).
 */

- (BOOL)addLink:(NSDataLink *)link toGraphic:(Graphic *)graphic at:(NSPoint)p update:(int)update
{
    NSSelection *selection = nil;

    if (!graphic && link && update != UPDATE_NEVER) {
	if (TextPasteType([link types])) {
	    graphic = [[TextGraphic allocWithZone:(NSZone *)[self zone]] initEmpty];
	} else if (MatchTypes([link types], [NSImage imagePasteboardTypes])) {
	    graphic = [[Image allocWithZone:(NSZone *)[self zone]] initEmpty];
	}
	update = UPDATE_IMMEDIATELY;
    }

    if (graphic && link) {
	selection = [graphic selection];
	if ([linkManager addLink:link at:selection]) {
	    if (!update) [link setUpdateMode:NSUpdateNever];
	    [graphic setLink:link];
	    if ((graphic = [self placeGraphic:graphic at:&p])) {
		if (update == UPDATE_IMMEDIATELY) {
		    [link updateDestination];
		    graphic = [self findGraphicInSelection:selection];
		    if (![graphic isValid]) {
			NSRunAlertPanel(IMPORT_LINK, UNABLE_TO_IMPORT_LINK, nil, nil, nil);
			[self removeGraphic:graphic];
		    } else {
			return YES;
		    }
		} else {
		    return YES;
		}
	    }
	}
    }

    [graphic release];

    return NO;
}

/*
 * Keeping links up to date.
 * These methods are called either to update a link that draw has to another
 * document or to cause Draw to update another document that is linked to it.
 */

/*
 * Sent whenever NeXTSTEP wants us to update some data in our document which
 * we get by being linked to some other document.
 */

- (BOOL)pasteFromPasteboard:(NSPasteboard *)pboard at:(NSSelection *)selection
{
    id graphic;
    NSRect gBounds;

    if ((graphic = [self findGraphicInSelection:selection])) {
	gBounds = [graphic reinitWithPasteboard:pboard];
	[self cache:gBounds];	// updating a destination link
	[[self window] flushWindow];
	[self dirty];
	return YES;
    }

    return NO;
}

/*
 * Lazy pasteboard method for cheapCopyAllowed case ONLY.
 * See copyToPasteboard:at:cheapCopyAllowed: below.
 */

- (void)pasteboard:(NSPasteboard *)sender provideDataForType:(NSString *)type
{
    NSArray *array;
    NSData *data = nil;
    NSSelection *selection;

    selection = [[NSSelection allocWithZone:(NSZone *)[self zone]] initWithPasteboard:sender];
    array = [self findGraphicsInSelection:selection];
    if (array) {
	if ([type  isEqual:NSPostScriptPboardType]) {
	    data = [self dataForEPSUsingList:array];
	} else if ([type  isEqual:NSTIFFPboardType]) {
	    data = [self dataForTIFFUsingList:array];
	}
        if (data) [sender setData:data forType:type];
    }
    [selection release];
}

/*
 * Called by NeXTSTEP when some other document needs to be updated because
 * they are linked to something in our document.
 */

- copyToPasteboard:(NSPasteboard *)pboard at:(NSSelection *)selection cheapCopyAllowed:(BOOL)cheapCopyAllowed
{
    NSArray *array;
    NSData *objectData = nil;
    id retval = self;
    NSString *firstType = (cheapCopyAllowed ?  NSSelectionPboardType : DrawPboardType);
    NSArray *types = [[[NSArray alloc] initWithObjects:firstType, NSPostScriptPboardType, NSTIFFPboardType, nil] autorelease];

    if (cheapCopyAllowed) {
	if ((array = [self findGraphicsInSelection:selection])) {
	    [pboard declareTypes:types owner:self];
	    [selection writeToPasteboard:pboard];
	} else {
	    retval = nil;
	}
    } else {
	[pboard declareTypes:types owner:[self class]];
	array = [self findGraphicsInSelection:selection];
	if (array) {
	    objectData = [NSArchiver archivedDataWithRootObject:array];
	    [pboard setData:objectData forType:DrawPboardType];
	} else {
	    retval = nil;
	}
    }

    return retval;
}


/*
 * Supports linking to an entire file (not just a selection therein).
 * This occurs when you drag a file into Draw and link (see gvDrag).
 * This is very analogous to the pasteFromPasteboard:at: above.
 */

- (BOOL)importFile:(NSString *)filename at:(NSSelection *)selection
{
    id graphic;
    NSRect gBounds;

    if ((graphic = [self findGraphicInSelection:selection])) {
	gBounds = [graphic reinitFromFile:filename];
	[self cache:gBounds];	// updating a link to an imported file
	[[self window] flushWindow];
	[self dirty];
	return YES;
    }

    return NO;
}

/* Other Links methods */

/*
 * Just makes the Link Inspector panel reflect whether any of the
 * Graphic's currently selected are linked to some other document.
 */

- (void)updateLinksPanel
{
    int i, linkCount = 0;
    Graphic *foundGraphic = nil, *graphic = nil;

    if (linkManager) {
	for (i = [slist count]-1; i >= 0; i--) {
	    if ((graphic = [[slist objectAtIndex:i] graphicLinkedBy:NULL])) {
		if ([graphic isKindOfClass:[Group class]]) {
		    linkCount += 2;
		    break;
		} else {
		    linkCount += 1;
		    foundGraphic = graphic;
		}
	    }
	}
	if (linkCount == 1) {
	    [NSDataLinkPanel setLink:[foundGraphic link] manager:linkManager isMultiple:NO];
	} else if (linkCount) {
	    [NSDataLinkPanel setLink:[foundGraphic link] manager:linkManager isMultiple:YES];
	} else {
	    [NSDataLinkPanel setLink:nil manager:linkManager isMultiple:NO];
	}
    } 
}

- (NSDataLinkManager *)linkManager
{
    return linkManager;
}

/*
 * When we get a linkManager via this method, we must go and revive all the links.
 * This is due to the fact that we don't archive ANY link information when we
 * save a Draw document.  However, the unique identifiers ARE archived, and thus,
 * when we unarchive, we can recreate NSSelections with those unique identifiers
 * and then ask the NSDataLinkManager for the link objects associated with those
 * NSSelections.
 *
 * After we have revived all the links, we call breakLinkAndRedrawOutlines:
 * with nil (meaning redraw the link outlines for all links).
 */

- (void)setLinkManager:(NSDataLinkManager *)aLinkManager
{
    if (!linkManager) {
	linkManager = aLinkManager;
	[glist makeObjectsPerform:@selector(reviveLink:) withObject:linkManager];
	[self breakLinkAndRedrawOutlines:nil];
    } 
}

/*
 * This is called when the user chooses Open Source.
 * It uses the trick of drawing directly into the GraphicView
 * which, of course, is only ephemeral since the REAL contents
 * of the GraphicView are stored in the backing store.
 * This is convenient because Open Source is only a temporary
 * the the user calls to see where the data for his link is
 * coming from.
 */
 
- (BOOL)showSelection:(NSSelection *)selection
{
    BOOL retval = YES;
    NSArray *graphics = nil;
    NSRect *newInvalidRect;
    NSRect sBounds, linkBounds;
    
    [self lockFocus];
    if (invalidRect) {
	[self drawRect:*invalidRect];
	newInvalidRect = invalidRect;
	invalidRect = NULL;
    } else{
	newInvalidRect = NSZoneMalloc(NSDefaultMallocZone(), (1) * sizeof(NSRect));
    }
    if ([self getRect:&linkBounds forSelection:selection]) {
	PSsetgray(NSLightGray);
	NSFrameRectWithWidth(linkBounds, 2.0);
	*newInvalidRect = linkBounds;
	graphics = [self findGraphicsInSelection:selection];
	if (graphics) {
	    sBounds = [self getBBoxOfArray:graphics];
	    *newInvalidRect = NSUnionRect(sBounds, *newInvalidRect);
	} else {
	    invalidRect = newInvalidRect;
	    [self scrollRectToVisible:*invalidRect];
	    [[self window] flushWindow];
	    retval = NO;
	}
    } else {
	graphics = [self findGraphicsInSelection:selection];
	if (graphics) {
	    sBounds = [self getBBoxOfArray:graphics];
	    *newInvalidRect = sBounds;
	} else {
	    retval = NO;
	}
    }

    if (retval) {
	NSFrameLinkRect(sBounds, NO);
	invalidRect = newInvalidRect;
	*invalidRect = NSInsetRect(*invalidRect, -NSLinkFrameThickness(), -NSLinkFrameThickness());
	[self scrollRectToVisible:*invalidRect];
	[[self window] flushWindow];
    }

    [self unlockFocus];

    return retval;
}

/*
 * Called when the Show Links button in the Link Inspector panel is clicked
 * (the link argument will be nil in this case), or when a link is broken
 * (the link argument will be the link that was broken).
 */

- (void)breakLinkAndRedrawOutlines:(NSDataLink *)link
{
    int i;
    Graphic *graphic;
    BOOL gotOne = NO;
    NSRect eBounds;
    NSRect recacheBounds;

    for (i = [glist count]-1; i >= 0; i--) {
	graphic = [glist objectAtIndex:i];
	if ((graphic = [graphic graphicLinkedBy:link])) {
	    if (link && ([graphic link] == link) &&
		([link updateMode] == NSUpdateNever)) {
		    [self removeGraphic:graphic];
	    }
	    if (!link || [linkManager areLinkOutlinesVisible]) {
		eBounds = [graphic extendedBounds];
		if (gotOne) {
		    recacheBounds = NSUnionRect(eBounds, recacheBounds);
		} else {
		    recacheBounds = eBounds;
		    gotOne = YES;
		}
	    }
	}
    }
    if (gotOne) {
	[self cache:recacheBounds andUpdateLinks:NO];
	[[self window] flushWindow];
    } 
}

/*
 * Tracking Link Changes.
 *
 * This is how we get "Continuous" updating links.
 *
 * We simply assume that a thing someone is linked to in our document
 * changes whenever we have to redraw any rectangle in the GraphicView
 * which intersects the linked-to rectangle.  See cache:andUpdateLinks:
 * in GraphicView.m.
 *
 * We should stop using Storage in this code!
 */

typedef struct {
    NSRect linkRect;
    NSDataLink *link;
    BOOL dragged, all;
} LinkRect;

- (void)updateTrackedLinks:(NSRect)rect
{
    int i;
    LinkRect *lr;
    NSArray *graphics;
    NSSelection *selection;
    NSRect *lRect, newRect;

    for (i = [linkTrackingRects count]-1; i >= 0; i--) {
	if (!NSIsEmptyRect(NSIntersectionRect(rect, *(NSRect *)[linkTrackingRects elementAt:i]))) {
	    lr = ((LinkRect *)[linkTrackingRects elementAt:i]);
	    [lr->link noteSourceEdited];
	    lRect = (NSRect *)[linkTrackingRects elementAt:i];
	    if (!lr->dragged && !lr->all && !NSContainsRect(*lRect, rect)) {
		selection = [lr->link sourceSelection];
		if ((graphics = [self findGraphicsInSelection:selection])) {
		    newRect = [self getBBoxOfArray:graphics];
		    *lRect = newRect;
		}
	    }
	}
    } 
}

/* Add to linkTrackingRects. */

- (void)startTrackingLink:(NSDataLink *)link
{
    LinkRect trackRect;
    NSArray *graphics = nil;
    NSSelection *selection;
    BOOL all = NO, dragged = NO, piecemeal = NO;

    selection = [link sourceSelection];
    if ([selection isEqual:[NSSelection allSelection]]) {
	all = YES;
	trackRect.linkRect = _bounds;
    } else if ([self getRect:&trackRect.linkRect forSelection:selection]) {
	dragged = YES;
    } else if ((graphics = [self findGraphicsInSelection:selection])) {
	trackRect.linkRect = [self getBBoxOfArray:graphics];
	piecemeal = YES;
    } else {
	return;
    }

    if (all || dragged || piecemeal) {
	if (!linkTrackingRects) {
	    linkTrackingRects = [[Storage alloc] initCount:1 elementSize:sizeof(LinkRect) description:"{ffff@}"];
	}
	[self stopTrackingLink:link];
	trackRect.link = link;
	trackRect.dragged = dragged;
	trackRect.all = all;
	[linkTrackingRects addElement:&trackRect];
    }
}

/* Remove from linkTrackingRects. */

- (void)stopTrackingLink:(NSDataLink *)link
{
    int i;

    for (i = [linkTrackingRects count]-1; i >= 0; i--) {
	if (((LinkRect *)[linkTrackingRects elementAt:i])->link == link) {
	    [linkTrackingRects removeElementAt:i];
	}
    }
}

@end
