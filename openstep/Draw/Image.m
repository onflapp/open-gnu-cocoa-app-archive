#import "draw.h"

/* Optimally viewed in a wide window.  Make your window big enough so that this comment fits on one line without wrapping. */

/*
 * Image is a simple graphic which takes PostScript or
 * TIFF images and draws them in a bounding box (it scales
 * the image if the bounding box is changed).  It is
 * implemented using the NSImage class.  Using NSImage
 * here is especially nice since it images its PostScript
 * in a separate context (thus, any errors that PostScript
 * generates will not affect our main drawing context).
 */

@implementation Image : Graphic

/* Factory methods. */

+ (NSImage *)highlightedLinkButtonImage:(NSSize)size
/*
 * Just makes an NSHighlightedLinkButton NSImage the same size as
 * the size passed in.  I suppose this could just be a
 * function.
 */
{
    static NSImage *retval = nil;
    if (!retval) {
	retval = [NSImage imageNamed:@"NSHighlightedLinkButton"];
	[retval setScalesWhenResized:YES];
	[retval setDataRetained:YES];
    }
    [retval setSize:size];
    return retval;
}

+ (BOOL)canInitWithPasteboard:(NSPasteboard *)pboard
{
    return [NSImage canInitWithPasteboard:pboard];
}

static BOOL checkImage(NSImage *anImage)
/*
 * Locking focus on an NSImage forces it to draw and thus verifies
 * whether there are any PostScript or TIFF errors in the source of
 * the image.  lockFocus returns YES only if there are no errors.
 */
{
    if ([anImage isValid]) { 
	[anImage lockFocus];
	[anImage unlockFocus];
	return YES;
    }
    return NO;
}

/* Creation/Initialization Methods */

- (id)init
/*
 * This creates basically an "empty" Image.
 * This is the designated initializer for Image.
 * Be careful, however, because by the time this
 * returns, a newly initialized Image may not be
 * fully initialized (it'll be "valid," just not
 * necessarily fully initialized).  If you want that
 * behaviour, override finishedWithInit.
 */
{
    [super init];
    originalSize.width = originalSize.height = 1.0;
    bounds.size = originalSize;
    return self;
}

- finishedWithInit
/*
 * Called when a newly initialized Image is fully
 * initialized and ready to roll.  For subclassers
 * only.
 */
{
     return self;
}

- initEmpty
/*
 * Creates a blank Image.
 */
{
    [self init];
    return [self finishedWithInit];
}

- (id)initWithData:(NSData *)data
/*
 * Creates a new NSImage and sets it to be scalable and to retain
 * its data (which means that when we archive it, it will actually
 * write the TIFF or PostScript data into the stream).
 */
{
    [self init];

    if (data) {
	image = [NSImage allocWithZone:(NSZone *)[self zone]];
	if ((image = [image initWithData:data])) {
	    [image setDataRetained:YES];
	    if (checkImage(image)) {
		originalSize = [image size];
		[image setScalesWhenResized:YES];
		bounds.size = originalSize;
		return [self finishedWithInit];
	    }
	}
    }
    [self release];
    return nil;
}

- (id)initWithPasteboard:(NSPasteboard *)pboard;
/*
 * Creates a new NSImage and sets it to be scalable and to retain
 * its data (which means that when we archive it, it will actually
 * write the TIFF or PostScript data into the stream).
 */
{
    [self init];

    if (pboard) {
	image = [NSImage allocWithZone:(NSZone *)[self zone]];
	if ((image = [image initWithPasteboard:pboard])) {
	    [image setDataRetained:YES];
	    if (checkImage(image)) {
		originalSize = [image size];
		[image setScalesWhenResized:YES];
		bounds.size = originalSize;
		return [self finishedWithInit];
	    }
	}
    }
    [self release];
    return nil;
}

- (id)initWithFile:(NSString *)file
/*
 * Creates an NSImage by reading data from an .eps or .tiff file.
 */
{
    [self init];

    image = [[NSImage allocWithZone:(NSZone *)[self zone]] init];
    [image addRepresentations:[NSImageRep imageRepsWithContentsOfFile:file]];
    [image setDataRetained:YES];
    if (checkImage(image)) {
	originalSize = [image size];
	[image setScalesWhenResized:YES];
	bounds.size = originalSize;
	return [self finishedWithInit];
    }
    [self release];
    return nil;
}

- doInitFromImage:(NSImage *)anImage
/*
 * Common code for initFromImage: and unarchiving.
 */
{
    if (anImage) {
	image = [anImage copy];
	originalSize = [image size];
	[image setScalesWhenResized:YES];
	[image setDataRetained:YES];
	bounds.size = originalSize;
    } else {
	[self release];
	self = nil;
    }
    return self;
}

- initFromImage:(NSImage *)anImage
/*
 * Initializes an Image from a specific NSImage.
 */
{
    [self init];
    return [[self doInitFromImage:anImage] finishedWithInit];
}

- initFromIcon:(NSImage *)anImage
/*
 * Same as initFromImage:, but we remember that this particular
 * NSImage was actually a file icon (which enables us to double-click
 * on it to open the icon, see handleEvent:).
 */
{
    if ([self initFromImage:anImage]) {
	amIcon = YES;
	return self;
    } else {
	return nil;
    }
}

- initWithLinkButton
/*
 * Creates an image which is just the link button.
 * This is only applicable with Object Links.
 */
{
    if ([self initFromImage:[[NSImage imageNamed:@"NSLinkButton"] copy]]) {
	amLinkButton = YES;
	return self;
    } else {
	return nil;
    }
}

- (NSRect)resetImage:(NSImage *)newImage
/*
 * Called by the "reinit" methods to reset all of our instance
 * variables based on using a new NSImage for our image.
 */
{
    NSRect eBounds;
    NSRect neBounds;

    /* TOPS-WARNING!!!  NSObject conversion:  This release used to be a free. */ [image release];
    image = newImage;
    eBounds = [self extendedBounds];
    neBounds.size = [image size];
    neBounds.size.width *= bounds.size.width / originalSize.width;
    neBounds.size.height *= bounds.size.height / originalSize.height;
    neBounds.origin.x = bounds.origin.x - floor((neBounds.size.width - bounds.size.width) / 2.0 + 0.5);
    neBounds.origin.y = bounds.origin.y - floor((neBounds.size.height - bounds.size.height) / 2.0 + 0.5);
    [self setBounds:neBounds];
    neBounds = [self extendedBounds];
    neBounds = NSUnionRect(eBounds, neBounds);
    [image setDataRetained:YES];
    originalSize = [image size];
    [image setScalesWhenResized:YES];

    return neBounds;
}

- (NSRect)reinitWithPasteboard:(NSPasteboard *)pboard
/*
 * Reset all of our instance variable based on extract an
 * NSImage from data in the the passed pboard.  Happens when
 * we update a link through Object Links.
 */
{
    NSRect neBounds;
    NSImage *newImage;

    newImage = [NSImage allocWithZone:(NSZone *)[self zone]];
    if ((newImage = [newImage initWithPasteboard:pboard])) {
	[newImage setDataRetained:YES];
	if (checkImage(newImage)) {
            return [self resetImage:newImage];
	}
    }

    [newImage release];
    neBounds.origin.x = neBounds.origin.y = 0.0;
    neBounds.size.width = neBounds.size.height = 0.0;

    return neBounds;
}

- (NSRect)reinitFromFile:(NSString *)file
/*
 * Reset all of our instance variable based on extract an
 * NSImage from the data in the passed file.  Happens when
 * we update a link through Object Links.
 */
{
    NSRect neBounds;
    NSImage *newImage;

    newImage = [[NSImage allocWithZone:(NSZone *)[self zone]] init];
    [newImage addRepresentations:[NSImageRep imageRepsWithContentsOfFile:file]];
    [newImage setDataRetained:YES];
    if (checkImage(newImage)) return [self resetImage:newImage];

    [newImage release];
    neBounds.origin.x = neBounds.origin.y = 0.0;
    neBounds.size.width = neBounds.size.height = 0.0;

    return neBounds;
}

/* All those allocation/initialization method and only this one free method. */

- (void)dealloc
{
    [image release];
    [super dealloc];
}

/* Link methods */

- (void)setLink:(NSDataLink *)aLink
/*
 * It's "might" be linked because we're linked now, but might
 * have our link broken in the future and the mightBeLinked flag
 * is only advisory and is never cleared.  It is used just so that
 * we know we might want to try to reestablish a link with this
 * Graphic after a cut/paste.  No biggie if there really is no
 * link associated with this any more.  In gvLinks.m, see
 * readLinkForGraphic:fromPasteboard:useNewIdentifier:, and in
 * gvPasteboard.m, see pasteFromPasteboard:andLink:at:.
 * If this Image is a link button, then we obviously never need
 * to update the link because we don't actually show the data
 * associated with the link (we just show that little link button).
 */
{
    if (aLink) {
        link = [aLink retain];
        gFlags.mightBeLinked = YES;
        if (amLinkButton) [link setUpdateMode:NSUpdateNever];
   }
}

- (NSDataLink *)link
{
    return link;
}

/* Event-handling */

- trackLinkButton:(NSEvent *)event at:(NSPoint)startPoint inView:(NSView *)view
/*
 * This method tracks that little link button.  Note that the link button is a diamond,
 * but we track the whole rectangle.  This is unfortunate, but we can't be sure that,
 * in the future, the shape of the link button might not change (thus, what we really
 * need is a NeXTSTEP function to track the thing!).  Anyway, we track it and if the 
 * mouse goes up inside the button, we openSource on the link (we wouldn't be here if
 * we didn't have a link).
 */
{
    NSImage *realImage, *highImage, *imageToDraw;

    realImage = image;
    highImage = [[self class] highlightedLinkButtonImage:bounds.size];
    image = imageToDraw = highImage;
    [self draw];
    [[view window] flushWindow];
    do {
	event = [[view window] nextEventMatchingMask:NSLeftMouseDraggedMask|NSLeftMouseUpMask];
	startPoint = [event locationInWindow];
	startPoint = [view convertPoint:startPoint fromView:nil];
	imageToDraw = NSMouseInRect(startPoint, bounds, NO) ? highImage : realImage;
	if (imageToDraw != image) {
	    image = imageToDraw;
	    [self draw];
	    [[view window] flushWindow];
	}
    } while ([event type] != NSLeftMouseUp);

    if (imageToDraw == highImage) {
	[link openSource];
	image = realImage;
	[self draw];
	[[view window] flushWindow];
    }

    return self;
}

- (BOOL)handleEvent:(NSEvent *)event at:(NSPoint)p inView:(NSView *)view
{
    if (NSMouseInRect(p, bounds, NO)) {
	if (amLinkButton && !gFlags.selected && !([event modifierFlags] & (NSControlKeyMask|NSShiftKeyMask|NSAlternateKeyMask))) {
	    [self trackLinkButton:event at:p inView:view];
	    return YES;
	} else if (link && ([event clickCount] == 2) && (amIcon || ([event modifierFlags] & NSControlKeyMask))) {
	    [[view window] nextEventMatchingMask:NSLeftMouseUpMask];
	    [link openSource];
	    return YES;
	}
    }
    return NO;
}

/* Methods overridden from superclass to support links. */

- (int)cornerMask
/*
 * Link buttons are too small to have corners AND sides, so
 * we only let link buttons have knobbies on the corners.
 */
{
    if (amLinkButton) {
	return LOWER_LEFT_MASK|UPPER_LEFT_MASK|UPPER_RIGHT_MASK|LOWER_RIGHT_MASK;
    } else {
	return [super cornerMask];
    }
}

- (NSRect)extendedBounds
/*
 * We have to augment this because we might have a link frame
 * (if show links is on), so we have to extend our extended bounds
 * a bit.
 */
{
    NSRect linkBounds;
    float linkFrameThickness = NSLinkFrameThickness();

    linkBounds = bounds;
    linkBounds.origin.x -= linkFrameThickness;
    linkBounds.size.width += linkFrameThickness * 2.0;
    linkBounds.origin.y -= linkFrameThickness;
    linkBounds.size.height += linkFrameThickness;

    return NSUnionRect(linkBounds, [super extendedBounds]);
}

- (BOOL)constrainByDefault;
/*
 * Icons and link buttons look funny outside their natural
 * aspect ratio, so we constrain them (by default) to keep
 * their natural ratio.  You can still use the Alternate key
 * to NOT constrain these.
 */
{
    return (amLinkButton || amIcon);
}

/* Methods overridden from superclass */

- (BOOL)isValid
{
    return image ? YES : NO;
}

- (BOOL)isOpaque
{
    return [[image bestRepresentationForDevice:nil] isOpaque];
}

- (float)naturalAspectRatio
{
    if (!originalSize.height) return 0.0;
    return originalSize.width / originalSize.height;
}

- draw
/*
 * If we are resizing, we just draw a gray box.
 * If not, then we simply see if our bounds have changed
 * and update the NSImage object if they have.  Then,
 * if we do not allow alpha (i.e. this is a TIFF image),
 * we paint a white background square (we don't allow
 * alpha in our TIFF images since it won't print and
 * Draw is WYSIWYG).  Finally, we SOVER the image.
 * If we are not keeping the cache around, we tell
 * NSImage to toss its cached version of the image
 * via the message recache.
 *
 * If we are linked to something and the user has chosen
 * "Show Links", then linkOutlinesAreVisible, so we must
 * draw a link border around ourself.
 */
{
    NSRect r;
    NSPoint p;
    NSSize currentSize;

    if (bounds.size.width < 1.0 || bounds.size.height < 1.0) return self;

    if (DrawStatus == Resizing) {
	PSsetgray(NSDarkGray);
	PSsetlinewidth(0.0);
	PSrectstroke(bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height);
    } else if (image) {
	p = bounds.origin;
	currentSize = [image size];
	if (currentSize.width != bounds.size.width || currentSize.height != bounds.size.height) {
	    if ([image scalesWhenResized]) {
		[image setSize:bounds.size];
	    } else {
		p.x = bounds.origin.x + floor((bounds.size.width - currentSize.width) / 2.0 + 0.5);
		p.y = bounds.origin.y + floor((bounds.size.height - currentSize.height) / 2.0 + 0.5);
	    }
	}
	if ([[image bestRepresentationForDevice:nil] isOpaque]) {
	    PSsetgray(NSWhite);
	    NSRectFill(bounds);
	}
	[image compositeToPoint:p operation:NSCompositeSourceOver];
	if (dontCache && [[NSDPSContext currentContext] isDrawingToScreen]) [image recache];
	if (([[NSDPSContext currentContext] isDrawingToScreen]) && !amLinkButton && [[link manager] areLinkOutlinesVisible]) {
	    r.origin.x = floor(bounds.origin.x);
	    r.origin.y = floor(bounds.origin.y);
	    r.size.width = floor(bounds.origin.x + bounds.size.width + 0.99) - r.origin.x;
	    r.size.height = floor(bounds.origin.y + bounds.size.height + 0.99) - r.origin.y;
	    NSFrameLinkRect(r, YES);	// YES means "is a destination link"
	}
    }

    return self;
}

/* Direct writing of EPS or TIFF. */

- (BOOL)canEmitEPS
/*
 * If we have a representation that can provide EPS directly, then,
 * if we are copying PostScript to the Pasteboard and this Image is the
 * only Graphic selected, then we might as well just have the EPS which
 * represents this Image go straight to the Pasteboard rather than
 * wrapping it up in the copyPSCodeInside: wrappers.  Of course, we
 * can only do that if we haven't been resized.
 *
 * See gvPasteboard.m's dataForEPS.
 */
{
    NSArray *reps = [image representations];
    int i = [reps count];

    if (originalSize.width == bounds.size.width && originalSize.height == bounds.size.height) {
	while (i--) {
	    if ([[reps objectAtIndex:i] respondsToSelector:@selector(getEPS:length:)]) {
		return YES;
	    }
	}
    }

    return NO;
}

- (NSData *)dataForEPS
/*
 * If canEmitEPS above returns YES, then we can write ourself out directly
 * as EPS.  This method does that.
 */
{
    NSArray *reps = [image representations];
    int i = [reps count];

    while (i--) {
	if ([[reps objectAtIndex:i] respondsToSelector:@selector(EPSRepresentation)]) {
	    return [[reps objectAtIndex:i] EPSRepresentation];
	}
    }

    return nil;
}

- (BOOL)canEmitTIFF
/*
 * Similar to canEmitEPS, except its for TIFF.
 */
{
    return (originalSize.width == bounds.size.width && originalSize.height == bounds.size.height);
}

- (NSData *)dataForTIFF
/*
 * Ditto above.
 */
{
    return [image TIFFRepresentation];
}

/* Caching. */

- (void)setCacheable:(BOOL)flag
{
    dontCache = flag ? NO : YES; 
}

- (BOOL)isCacheable
{
    return !dontCache;
}

/* Archiving. */

- (BOOL)writesFiles
{
    return (image && !amLinkButton) ? YES : NO;
}

- (void)writeFilesToDirectory:(NSString *)directory
{
    NSString *filename = [directory stringByAppendingPathComponent:[imageFile lastPathComponent]];
    if (![[NSFileManager defaultManager] fileExistsAtPath:filename]) {
        [NSArchiver archiveRootObject:image toFile:filename];
    }
}

#define FILE_KEY @"ImageFileName"
#define SIZE_KEY @"OriginalSize"

- (void)convertSelf:(ConversionDirection)direction propertyList:(id)plist
{
    [super convertSelf:direction propertyList:plist];
    PL_FLAG(plist, amLinkButton, @"IsLinkButton", direction);
    PL_FLAG(plist, amIcon, @"IsIcon", direction);
}

- (id)propertyList
{
    NSMutableDictionary *plist;

    plist = [super propertyList];
    if (!amLinkButton) {
        [plist setObject:propertyListFromNSSize(originalSize) forKey:SIZE_KEY];
        if (!imageFile) imageFile = [[NSString stringWithFormat:@"Image%d", identifier] retain];
        [plist setObject:imageFile forKey:FILE_KEY];
    }

    return plist;
}

- (NSString *)description
{
    return [(NSObject *)[self propertyList] description];
}

- initFromPropertyList:(id)plist inDirectory:(NSString *)directory
{
    NSRect savedBounds;

    [super initFromPropertyList:plist inDirectory:directory];
    if (amLinkButton) {
        savedBounds = bounds;
        [self doInitFromImage:[NSImage imageNamed:@"NSLinkButton"]];
        bounds = savedBounds;
    } else {
        originalSize = sizeFromPropertyList([plist objectForKey:SIZE_KEY]);
		imageFile = [[plist objectForKey:FILE_KEY] retain];
        image = [[NSUnarchiver unarchiveObjectWithFile:[directory stringByAppendingPathComponent:imageFile]] retain];
    }

    return self;
}

@end
