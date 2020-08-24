#import "draw.h"
#import "compatibility.h"

@implementation GraphicView(NSPasteboard)

/* Methods to search through Pasteboard types lists. */

extern BOOL IncludesType(NSArray *types, NSString *type)
{
    return types ? ([types indexOfObject:type] != NSNotFound) : NO;
}

NSString *MatchTypes(NSArray *typesToMatch, NSArray *orderedTypes)
{
    int typesCount = [orderedTypes count];
    int index = 0;
    
    while (index < typesCount) {
        NSString * currType = [orderedTypes objectAtIndex:index];
	
	if (IncludesType(typesToMatch, currType)) {
	    return currType;
	}
	++index;
    }
    return nil;
}

NSString *TextPasteType(NSArray *types)
/*
 * Returns the pasteboard type in the passed list of types which is preferred
 * by the Draw program for pasting.  The Draw program prefers PostScript over TIFF.
 */
{
    if (IncludesType(types, NSRTFPboardType)) return NSRTFPboardType;
    if (IncludesType(types, NSStringPboardType)) return NSStringPboardType;
    return nil;
}

NSString *ForeignPasteType(NSArray *types)
/*
 * Returns the pasteboard type in the passed list of types which is preferred
 * by the Draw program for pasting.  The Draw program prefers PostScript over TIFF.
 */
{
    NSString *retval = TextPasteType(types);
    return retval ? retval : MatchTypes(types, [NSImage imagePasteboardTypes]);
}

NSString *DrawPasteType(NSArray *types)
/*
 * Returns the pasteboard type in the passed list of types which is preferred
 * by the Draw program for pasting.  The Draw program prefers its own type
 * of course, then it prefers Text, then something NSImage can handle.
 */
{
    if (IncludesType(types, DrawPboardType)) return DrawPboardType;
    return ForeignPasteType(types);
}

NSArray *TypesDrawExports(void)
{
    static NSArray * exportList = nil;
    if (!exportList) {
        exportList = [[NSArray allocWithZone:NSDefaultMallocZone()] initWithObjects:DrawPboardType, NSPostScriptPboardType, NSTIFFPboardType, nil];
    }
    return exportList;
}

/* Lazy Pasteboard evaluation handler */

/*
 * IMPORTANT: The pasteboard:provideDataForType: method is a factory method since the
 * factory object is persistent and there is no guarantee that the INSTANCE of
 * GraphicView that put the Draw format into the Pasteboard will be around
 * to lazily put PostScript or TIFF in there, so we keep one around (actually
 * we only create it when we need it) to do the conversion (scrapper).
 *
 * If you find this part of the code confusing, then you need not even
 * use the provideData: mechanism--simply put the data for all the different
 * types your program knows how to put in the Pasteboard in at the time
 * that you declareTypes:.
 */

/*
 * Converts the data in the Pasteboard from Draw internal format to
 * either PostScript or TIFF using the dataForTIFF and dataForEPS
 * methods.  It sends these messages to the scrapper (a GraphicView cached
 * to perform this very function).  Note that the scrapper view is put in
 * a window, but that window is off-screen, has no backing store, and no
 * title (and is thus very cheap).
 */

+ (void)convert:(NSUnarchiver *)unarchiver to:(NSString *)type using:(SEL)writer toPasteboard:(NSPasteboard *)pb
{
    NSWindow *w;
    NSMutableArray *array;
    NSData *data;
    GraphicView *scrapper;
    NSRect scrapperFrame = {{0.0, 0.0}, {11.0*72.0, 14.0*72.0}};
    static NSZone *scrapperZone = NULL;

    if (!scrapperZone) scrapperZone = NSCreateZone(NSPageSize(), NSPageSize(), YES);

    if (unarchiver) {
        scrapper = [[GraphicView allocWithZone:scrapperZone] initWithFrame:scrapperFrame];
        [unarchiver setObjectZone:scrapperZone];
        array = [[NSMutableArray allocWithZone:scrapperZone] initFromList:[unarchiver decodeObject]];
        scrapperFrame = [scrapper getBBoxOfArray:array];
        scrapperFrame.size.width += scrapperFrame.origin.x;
        scrapperFrame.size.height += scrapperFrame.origin.y;
        scrapperFrame.origin.x = scrapperFrame.origin.y = 0.0;
        [scrapper setFrameSize:(NSSize){ scrapperFrame.size.width, scrapperFrame.size.height }];
        w = [[NSWindow allocWithZone:scrapperZone] initWithContentRect:scrapperFrame styleMask:NSBorderlessWindowMask backing:NSBackingStoreNonretained defer:NO];
        [w setContentView:scrapper];
        data = [scrapper performSelector:writer withObject:array];
        [pb setData:data forType:type];
        [array removeAllObjects];
        [array release];
        [w release];
    }
}


/*
 * Called by the Pasteboard whenever PostScript or TIFF data is requested
 * from the Pasteboard by some other application.  The current contents of
 * the Pasteboard (which is in the Draw internal format) is taken out and loaded
 * into an NSData, then convert:to:using:toPasteboard: is called.  This
 * returns self if successful, nil otherwise.
 */

+ (void)pasteboard:(NSPasteboard *)sender provideDataForType:(NSString *)type
{
    if ([type isEqual:NSPostScriptPboardType] || [type  isEqual:NSTIFFPboardType]) {
	NSData *pbData;
	
	if ((pbData = [sender dataForType:DrawPboardType]))  {
	    NSUnarchiver *unarchiver = [[NSUnarchiver allocWithZone:(NSZone *)[(NSObject *)self zone]] initForReadingWithData:pbData];
	    
	    if (unarchiver)  {
		if ([type  isEqual:NSPostScriptPboardType]) {
		    [self convert:unarchiver to:type using:@selector(dataForEPSUsingList:) toPasteboard:sender];
		} else {
		    // So it must be "NSTIFFPboardType"...
		    [self convert:unarchiver to:type using:@selector(dataForTIFFUsingList:) toPasteboard:sender];
		}
		[unarchiver release];
	    }
//	    [sender deallocatePasteboardData:pbData];
	}
	
    }
}

/* Writing data in different forms (other than the internal Draw format) */

/*
 * Writes out the PostScript generated by drawing all the objects in the
 * glist.  The bounding box of the generated encapsulated PostScript will
 * be equal to the bounding box of the objects in the glist (NOT the
 * bounds of the view).
 */

- (NSData *)dataForEPS
{
    NSRect bbox;
    NSData *data = nil;

    if (([glist count] == 1) && [[glist objectAtIndex:0] canEmitEPS]) {
        data = [[glist objectAtIndex:0] dataForEPS];
    } else {
        bbox = [self getBBoxOfArray:glist];
        data = [self dataWithEPSInsideRect:bbox];
    }

    return data;
}

/*
 * This is the same as dataForEPS, but it lets you specify the list
 * of Graphics you want to generate PostScript for (does its job by swapping
 * the glist for the list you provide temporarily).
 */

- (NSData *)dataForEPSUsingList:list
{
    NSMutableArray *savedglist;
    NSData *data;
    
    savedglist = glist;
    glist = list;
    data = [self dataForEPS];
    glist = savedglist;

    return data;
}

/*
 * Images all of the objects in the glist and writes out the result in
 * the Tagged Image File Format (TIFF).  The image will not have alpha in it.
 */

- (NSData *)dataForTIFF
{
    NSData *data = nil;
    NSImage *tiffCache;
    
    if (([glist count] == 1) && [[glist objectAtIndex:0] canEmitTIFF]) {
	data = [[glist objectAtIndex:0] dataForTIFF];
    } else {
        tiffCache = [[NSImage allocWithZone:[self zone]] initWithSize:[self getBBoxOfArray:glist].size];
	[self cacheList:glist into:tiffCache withTransparentBackground:NO];
	data = [tiffCache TIFFRepresentationUsingCompression:NSTIFFCompressionLZW factor:NSTIFFCompressionJPEG];
	[tiffCache release];
    }

    return data;
}

/*
 * This is the same as dataForTIFF, but it lets you specify the list
 * of Graphics you want to generate TIFF for (does its job by swapping
 * the glist for the list you provide temporarily).
 */

- (NSData *)dataForTIFFUsingList:list
{
    NSMutableArray *savedglist;
    NSData *data;
    
    savedglist = glist;
    glist = list;
    data = [self dataForTIFF];
    glist = savedglist;

    return data;
}

/* Writing the selection to an NSData */

- (NSData *)copySelectionAsEPS
{
    return ([slist count]) ? [self dataForEPSUsingList:slist] : nil;
}

- (NSData *)copySelectionAsTIFF
{
    return ([slist count]) ? [self dataForTIFFUsingList:slist] : nil;
}

- (NSData *)copySelection
{
    NSData *data = nil;
    
    if ([slist count]) {
	data = [NSArchiver archivedDataWithRootObject:slist];
    }

    return data;
}

/* Pasteboard-related target/action methods */

- (void)cut:(id)sender
/*
 * Calls copy: then delete:.
 */
{
    id change;

    if ([slist count] > 0) {
	change = [[CutGraphicsChange alloc] initGraphicView:self];
	[change startChange];
	    [self copy:sender];
	    lastCutChangeCount = lastCopiedChangeCount;
	    [self delete:sender];
	    consecutivePastes = 0;
        [change endChange];
    } 
}

- (void)copy:(id)sender
{
    if ([slist count]) {
	[self copyToPasteboard:[NSPasteboard generalPasteboard]];
	lastPastedChangeCount = [[NSPasteboard generalPasteboard] changeCount];
	lastCopiedChangeCount = [[NSPasteboard generalPasteboard] changeCount];
	consecutivePastes = 1;
	originalPaste = [slist objectAtIndex:0];
    }
}

- (void)paste:(id)sender
{
    [self paste:sender andLink:DontLink];
}

- (void)pasteAndLink:sender
{
    return [self paste:sender andLink:Link];
}

- (void)link:sender
{
    [self paste:sender andLink:LinkOnly];
}

/* Methods to write to/read from the pasteboard */

/*
 * Puts all the objects in the slist into the Pasteboard by archiving
 * the slist itself.  Also registers the PostScript and TIFF types since
 * the GraphicView knows how to convert its internal type to PostScript
 * or TIFF via the write{PS,TIFF} methods.
 */

- copyToPasteboard:(NSPasteboard *)pboard types:(NSArray *)typesList
{
    if ([slist count]) {
    	NSMutableArray * types = [[[NSMutableArray alloc] initWithCapacity:1] autorelease];
        NSData *data;
        
	[types addObject:DrawPboardType];
	if (!typesList || IncludesType(typesList, NSPostScriptPboardType)) {
	    [types addObject:NSPostScriptPboardType];
	}
	if (!typesList || IncludesType(typesList, NSTIFFPboardType)) {
	    [types addObject:NSTIFFPboardType];
	}
	[pboard declareTypes:types owner:[self class]];
        data = [self copySelection];
        if (data) [pboard setData:data forType:DrawPboardType];
	[self writeLinkToPasteboard:pboard types:typesList];
	return self;
    } else {
	return nil;
    }
}

- copyToPasteboard:(NSPasteboard *)pboard
{
    return [self copyToPasteboard:pboard types:NULL];
}

/*
 * Pastes any data that comes from another application.
 * Basically this is the "else" in pasteFromPasteboard: below if there
 * is no Draw internal format in the Pasteboard.  This is also called
 * from the drag stuff (see gvDrag.m).
 */

- (BOOL)pasteForeignDataFromPasteboard:(NSPasteboard *)pboard andLink:(LinkType)doLink at:(NSPoint)center
{
    NSDataLink *link = nil;
    Graphic *graphic = nil;

    if (!linkManager) doLink = DontLink;

    if (doLink) link = [[[NSDataLink alloc] initWithPasteboard:pboard] autorelease];
    if (link && (doLink == LinkOnly)) {
	graphic = [[Image allocWithZone:(NSZone *)[self zone]] initWithLinkButton];
    } else {
	graphic = [[TextGraphic allocWithZone:(NSZone *)[self zone]] initWithPasteboard:pboard];
	if (!graphic) graphic = [[Image allocWithZone:(NSZone *)[self zone]] initWithPasteboard:pboard];
    }
    [self deselectAll:self];
    if (doLink && link) {
	if ([self addLink:link toGraphic:graphic at:center update:UPDATE_NORMALLY]) return YES;
    } else if (graphic) {
	if ([self placeGraphic:graphic at:&center]) return YES;
    }

    return NO;
}

/*
 * Pastes any type available from the specified Pasteboard into the GraphicView.
 * If the type in the Pasteboard is the internal type, then the objects
 * are simply added to the slist and glist.  If it is PostScript or TIFF,
 * then an Image object is created using the contents of
 * the Pasteboard.  Returns a list of the pasted objects (which should be freed
 * by the caller).
 */

- (NSArray *)pasteFromPasteboard:(NSPasteboard *)pboard andLink:(LinkType)doLink at:(const NSPoint *)center
{
    int i;
    id change;
    NSArray *pblist = nil;
    Graphic *graphic = nil;
    BOOL pasteDrawType = NO;

    if (!linkManager) doLink = DontLink;
    if (!doLink) pasteDrawType = IncludesType([pboard types], DrawPboardType);

    if (pasteDrawType) {
	NSData *pbData = NULL;
	
	if ((pbData = [pboard dataForType:DrawPboardType]))  {
	    NSUnarchiver *unarchiver = [[NSUnarchiver allocWithZone:(NSZone *)[self zone]] initForReadingWithData:pbData];
	    
	    if (unarchiver)  {
		pblist = [[NSMutableArray allocWithZone:[self zone]] initFromList:[unarchiver decodeObject]];	// should probably autorelease
		if ((i = [pblist count])) {
		    change = [[PasteGraphicsChange alloc] initGraphicView:self graphics:pblist];	// but must ensure this works
		    [change startChange];
			[self deselectAll:self];
			while (i--) {
			    graphic = [pblist objectAtIndex:i];
			    [slist insertObject:graphic atIndex:0];
			    [glist insertObject:graphic atIndex:0];
			    if ([graphic mightBeLinked]) {
				BOOL useNewId = ([pboard changeCount] != lastCutChangeCount) || consecutivePastes;
				[graphic readLinkFromPasteboard:pboard usingManager:linkManager useNewIdentifier:useNewId];
			    }
			    gvFlags.groupInSlist = gvFlags.groupInSlist || [graphic isKindOfClass:[Group class]];
			}
		    [change endChange];
		} else {
		    pblist = nil;
		}
		[unarchiver release];
	    }
	}
    } else {
        NSPoint position;
        NSRect bounds;
        if (!center) {
            bounds = [self visibleRect];
            position.x = floor(bounds.size.width / 2.0 + 0.5);
            position.y = floor(bounds.size.height / 2.0 + 0.5);
        } else {
            position = *center;
        }
	[self pasteForeignDataFromPasteboard:pboard andLink:doLink at:position];
    }

    return pblist;
}

/*
 * Pastes from the normal pasteboard.
 * This paste implements "smart paste" which goes like this: if the user
 * pastes in a single item (a Group is considered a single item), then
 * pastes that item again and moves that second item somewhere, then
 * subsequent pastes will be positioned at the same offset between the
 * first and second pastes (this is also known as "transform again").
 */

- (void)paste:sender andLink:(LinkType)doLink
{
    NSArray *pblist;
    NSPoint offset;
    Graphic *graphic;
    NSPasteboard *pboard;
    NSRect originalBounds, secondBounds;
    static Graphic *secondPaste;
    static NSPoint pasteOffset;

    pboard = [NSPasteboard generalPasteboard];
    pblist = [self pasteFromPasteboard:pboard andLink:doLink at:NULL];

    if (pblist && IncludesType([pboard types], DrawPboardType)) {
	graphic = ([pblist count] == 1) ? [pblist objectAtIndex:0] : nil;
	if (lastPastedChangeCount != [pboard changeCount]) {
	    consecutivePastes = 0;
	    lastPastedChangeCount = [pboard changeCount];
	    originalPaste = graphic;
	} else {
	    if (consecutivePastes == 1) {	/* smart paste */
		if (gvFlags.gridDisabled) {	/* offset to grid if turned off */
		    pasteOffset.x = 10.0;
		    pasteOffset.y = -10.0;
		} else {
		    pasteOffset.x = (float)gvFlags.grid;
		    pasteOffset.y = -(float)gvFlags.grid;
		}
		secondPaste = graphic;
	    } else if ((consecutivePastes == 2) && graphic) {
		originalBounds = [originalPaste bounds];
		secondBounds = [secondPaste bounds];
		pasteOffset.x = secondBounds.origin.x - originalBounds.origin.x;
		pasteOffset.y = secondBounds.origin.y - originalBounds.origin.y;
	    }
	    offset.x = pasteOffset.x * consecutivePastes;
	    offset.y = pasteOffset.y * consecutivePastes;
	    [slist makeObjectsPerform:@selector(moveBy:) withObject:(id)&offset];
	}
	consecutivePastes++;
	[self recacheSelection];
    }
    [pblist release]; 
}

@end
