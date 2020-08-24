#import "draw.h"

/* See the Dragging.rtf for overview of Dragging in Draw. */

#define ERROR (-1)

@implementation GraphicView(Drag)

/*
 * Determines whether there is a Graphic at the specified point that is
 * willing to accept a dragged color.  If color is non-NULL, then the
 * color is actually set in that Graphic (i.e. you can find out if any
 * Graphics is "willing" to accept a color by calling this with
 * color == NULL).
 *
 * We use the mechanism of sending a Graphic the message colorAcceptorAt:
 * and letting it return a Graphic (rather than just asking each Graphic
 * doYouAcceptAColorAt:) so that Group's of Graphics can return one of
 * the Graphic's inside itself as the one to handle a dropped color.
 */

- (BOOL)acceptsColor:(NSColor *)color atPoint:(NSPoint)point
{
    id change;
    NSRect gbounds;
    Graphic *graphic;
    int i, count = [glist count];

    for (i = 0; i < count; i++) {
	graphic = [glist objectAtIndex:i];
	if ((graphic = [graphic colorAcceptorAt:point])) {
	    if (color) {
		gbounds = [graphic extendedBounds];
		change = [[FillGraphicsChange alloc] initGraphicView:self forChangeToGraphic:graphic];
		[change startChange];
		    [graphic setFillColor:color];
		    [self cache:gbounds];		// acceptsColor:atPoint:
		    [[self window] flushWindow];
		[change endChange];
		return YES;
	    } else {
		return YES;
	    }
	}
    }

    return NO;
}

/*
 * Registers the view with the Workspace Manager so that when the
 * user picks up an icon in the Workspace and drags it over our view
 * and lets go, dragging messages will be sent to our view.
 * We register for NSFilenamesPboardType because we handle data link
 * files and NSImage and Text files dragged into draw as well as any
 * random file when the Control key is depressed (indicating a link
 * operation) during the drag.  We also accept anything that NSImage
 * is able to handle (even if it's not in a file, i.e., it's directly
 * in the dragged Pasteboard--unusual, but we can handle it, so why
 * not?).
 */

- (void)registerForDragging
{
    [self registerForDraggedTypes:[NSArray arrayWithObjects:NSFilenamesPboardType, nil]];
    [self registerForDraggedTypes:[NSArray arrayWithObjects:NSColorPboardType, nil]];
    [self registerForDraggedTypes:[NSImage imagePasteboardTypes]]; 
}

/*
 * This is where we determine whether the contents of the dragging Pasteboard
 * is acceptable to Draw.  The gvFlags.drag*Ok flags say whether we can accept
 * the dragged information as a result of a copy or link (or both) operation.
 * If NSImage can handle the Pasteboard, then we know we can do copy.  We
 * always know we can do link as long as we have a linkManager.  We cache as
 * much of the answer around as we can so that draggingUpdated: will be fast.
 * Of course, we can't cache the part of the answer which is dependent upon
 * the position inside our view (important for colors).
 */

- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender
{
    NSPasteboard *pboard;
    unsigned int sourceMask;

    gvFlags.dragCopyOk = NO;
    gvFlags.dragLinkOk = NO;

    sourceMask = [sender draggingSourceOperationMask];
    pboard = [sender draggingPasteboard];

    if (IncludesType([pboard types], NSColorPboardType)) {
	NSPoint p = [sender draggingLocation];
	p = [self convertPoint:p fromView:nil];
	if ([self acceptsColor:nil atPoint:p]) return NSDragOperationGeneric;
    } else if (sourceMask & NSDragOperationCopy) {
//	if ([NSImage canInitWithPasteboard:pboard]) {
//	    gvFlags.dragCopyOk = YES;
//	} else
// should also make sure its either EPS or TIFF until ObjectLinks is working again
	if (IncludesType([pboard types], NSFilenamesPboardType)) {
	    gvFlags.dragCopyOk = YES;
	}
    }

    if (linkManager) gvFlags.dragLinkOk = YES;

    if (sourceMask & NSDragOperationCopy) {
	if (gvFlags.dragCopyOk) return NSDragOperationCopy;
    } else if (sourceMask & NSDragOperationLink) {
	if (gvFlags.dragLinkOk) return NSDragOperationLink;
    }

    return NSDragOperationNone;
}

/*
 * This is basically the same as draggingEntered: but, instead of being
 * called when the dragging enters our view, it is called every time the
 * mouse moves while dragging inside our view.
 */

- (unsigned int)draggingUpdated:(id <NSDraggingInfo>)sender
{
    unsigned int sourceMask = [sender draggingSourceOperationMask];
    if (IncludesType([[sender draggingPasteboard] types], NSColorPboardType)) {
	NSPoint p = [sender draggingLocation];
	p = [self convertPoint:p fromView:nil];
	if ([self acceptsColor:nil atPoint:p]) return NSDragOperationGeneric;
    } else if (sourceMask & NSDragOperationCopy) {
	if (gvFlags.dragCopyOk) return NSDragOperationCopy;
    } else if (sourceMask & NSDragOperationLink) {
	if (gvFlags.dragLinkOk) return NSDragOperationLink;
    }
    return NSDragOperationNone;
}

/*
 * Takes the name of a saved link (.objlink) file and incorporates
 * the "linked thing" into the view.  This is really just some glue between
 * the dragging mechanism and the addLink:toGraphic:at:update: method
 * which does all the work of actually incorporating the linked stuff
 * into the view.
 */

- (int)createGraphicForDraggedLink:(NSString *)file at:(NSPoint)p
{
    NSDataLink *link;
    Graphic *graphic = nil;

    if (linkManager) {
	link = [[[NSDataLink alloc] initWithContentsOfFile:file] autorelease];
	if ([self addLink:link toGraphic:graphic at:p update:UPDATE_IMMEDIATELY]) {
	    return YES;
	} else {
	    NSRunAlertPanel(nil, BAD_IMAGE, nil, nil, nil);
	    return ERROR;
	}
    }

    return NO;
}

/* A couple of convenience methods to determine what kind of file we have. */

static BOOL isNSImageFile(NSString * file)
{
    NSString * extension = [file pathExtension];
    
    return ([NSImageRep imageRepClassForFileType:extension]) ? YES : NO;
}

static BOOL isRTFFile(NSString * file)
{
    NSString * extension = [file pathExtension];
    
    return ([extension isEqual:@"rtf"]) ? YES : NO;
}

/*
 * Creates a Graphic from a file NSImage or the Text object can handle
 * (or just allows linking it if NSImage nor Text can handle the file).
 * It links to it if the doLink is YES.
 *
 * If we are linking, then we ask the user if she wants the file's icon,
 * a link button, or (if we can do so) the actually contents of the file
 * to appear in the view.
 *
 * Note the use of the workspace protocol object to get information about
 * the file.  We know that we cannot import the contents of a WriteNow or
 * other known document format into Draw, so we don't even give the user
 * the option of trying to do so.
 *
 * Again, if it ends up that we are linking, we just call the all-powerful
 * addLink:toGraphic:at:update: method in gvLinks.m, otherwise, we just
 * call placeGraphic:at:.
 */

- (int)createGraphicForDraggedFile:(NSString *)file withIcon:(NSImage *)icon at:(NSPoint)p andLink:(BOOL)doLink
{
    NSString *fileType;
    Graphic *graphic;
    NSDataLink *link;
    int choice, updateMode = UPDATE_NORMALLY;
    BOOL isImportable;

    isImportable = isNSImageFile(file) || isRTFFile(file);
    if (!isImportable && [[NSWorkspace sharedWorkspace] getInfoForFile:file application:NULL type:&fileType]) {
	isImportable = ([fileType isEqual:NSPlainFileType]);
    }

    if (!linkManager) doLink = NO;

    if (doLink) {
	if (isImportable) {
	    choice = NSRunAlertPanel(nil, FILE_CONTENTS_OR_ICON_OR_LINK_BUTTON, FILE_CONTENTS, FILE_ICON, LINK_BUTTON);
	} else {
	    choice = NSRunAlertPanel(nil, FILE_ICON_OR_LINK_BUTTON, FILE_ICON, LINK_BUTTON, nil);
	    if (choice == NSAlertDefaultReturn) {
		choice = NSAlertAlternateReturn;
	    } else if (choice == NSAlertAlternateReturn) {
		choice = NSAlertOtherReturn;
	    }
	}
    } else if (isImportable) {
	choice = NSAlertDefaultReturn;
    } else {
	return NO;
    }

    if (choice == NSAlertDefaultReturn) {		// import the contents of the file
	if (isNSImageFile(file)) {
	    graphic = [[Image allocWithZone:(NSZone *)[self zone]] initWithFile:file];
	} else {
	    graphic = [[TextGraphic allocWithZone:(NSZone *)[self zone]] initWithFile:file];
	}
	updateMode = UPDATE_NORMALLY;
    } else if (choice == NSAlertAlternateReturn) {	// show the file's icon
	graphic = [[Image allocWithZone:(NSZone *)[self zone]] initFromIcon:icon];
	updateMode = UPDATE_NEVER;
    } else {					        // show a link button
	graphic = [[Image allocWithZone:(NSZone *)[self zone]] initWithLinkButton];
	updateMode = UPDATE_NEVER;
    }

    if (graphic) {
	if (doLink) {
	    link = [[[NSDataLink alloc] initLinkedToFile:file] autorelease];
	    if ([self addLink:link toGraphic:graphic at:p update:UPDATE_NORMALLY]) return YES;
	} else {
	    if ([self placeGraphic:graphic at:&p]) return YES;
	}
    }

    NSRunAlertPanel(nil, nil, BAD_IMAGE, nil, nil, nil);

    return ERROR;
}

/*
 * If we get this far, we are pretty sure we can succeed (though we're
 * not 100% sure because it might be, for example, a WriteNow file
 * without the link button down).
 *
 * We return YES here and do the work in conclude so that we don't
 * timeout if we are dragging in a big image or something that will
 * take a long time to import (or if we have to ask the user a question
 * to figure out how to import the dragged thing).  The bummer here
 * is that if creating the image should fail for some reason, we can't
 * give the slide-back feedback because it's too late to do so in
 * concludeDragOperation:.
 */

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
    NSPasteboard *pboard = [sender draggingPasteboard];

    if (IncludesType([pboard types], NSColorPboardType)) {
	BOOL retval = NO;
	NSColor *color = [NSColor colorFromPasteboard:pboard] /* ??? CHECK THIS: retain? */;
	NSPoint p = [sender draggingLocation];
	p = [self convertPoint:p fromView:nil];
	retval = [self acceptsColor:color atPoint:p];
	[NSApp updateWindows];	// reflect color change in Inspector, et. al.
	return retval;
    }

    return YES;
}

/* Another convenience method for identifying .objlink files. */

static BOOL isLinkFile(NSString * file)
{
    NSString * extension = [file pathExtension];
    return ([extension isEqual:NSDataLinkFilenameExtension]) ? YES : NO;
}

/*
 * Actually do the "drop" of the drag here.
 *
 * Note that if we successfully dropped, we bring the window
 * we dropped into to the front and activate ourselves.  We also
 * update our inspectors, etc. (this is especially important for
 * the LinkInspector window!) by calling updateWindows.
 */

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
    NSPoint p;
    NSPasteboard *pboard;
    NSArray * filenameArray;
    int foundOne = NO;
    BOOL doLink;

    p = [sender draggingLocation];
    p = [self convertPoint:p fromView:nil];

    doLink = ([self draggingUpdated:sender] == NSDragOperationLink);
    pboard = [sender draggingPasteboard];

    if (IncludesType([pboard types], NSColorPboardType)) foundOne = YES;

    if (!foundOne && IncludesType([pboard types], NSFilenamesPboardType)) {
        int nameCount;
	int index = 0;
	
	filenameArray = [pboard propertyListForType:NSFilenamesPboardType];
	nameCount = [filenameArray count];
	
	while (index < nameCount) {
	    NSString * currFile = [filenameArray objectAtIndex:index];
	    
	    if (isLinkFile(currFile)) {
		foundOne = [self createGraphicForDraggedLink:currFile at:p] || foundOne;
	    } else {
		foundOne = [self createGraphicForDraggedFile:currFile withIcon:[sender draggedImage] at:p andLink:doLink] || foundOne;
	    }
	    ++index;
	}
    }

    if (!foundOne) foundOne = [self pasteForeignDataFromPasteboard:pboard andLink:doLink at:p];
    
    if (foundOne > 0) {
	[NSApp activateIgnoringOtherApps:YES];
	[[self window] makeKeyAndOrderFront:self];
	[NSApp updateWindows];
    }
}

@end
