#import "draw.h"
#import "compatibility.h"

#define DRAW_VERSION_2_0 184
#define NEW_DRAW_VERSION FIRST_OPENSTEP_VERSION

#define DRAW_DOCUMENT_NAME @"document.draw"

/* Keys used in the property list draw documents are stored as. */

#define VERSION_KEY @"Version"
#define PRINTINFO_KEY @"PrintInfo"
#define FRAME_KEY @"WindowFrame"
#define SIZE_KEY @"ViewSize"
#define GRAPHIC_IDENT_KEY @"GraphicIdentifier"
#define VIEW_KEY @"View"

@implementation DrawDocument
/*
 * This class is used to keep track of a Draw document.
 *
 * Its view and window instance variables keep track of the GraphicView
 * comprising the document as well as the window it is in.
 * The printInfo instance variable is used to allow the user to control
 * how the printed page is printed.  It is an instance of a PrintInfo object.
 * The listener is used to allow the user to drag an icon representing
 * a PostScript or TIFF file into the document.  The iconPathList is the
 * list of files which was last dragged into the document.
 * The name and directory specify where the document is to be saved.
 * haveSavedDocument keeps track of whether a disk file is associated
 * with the document yet (i.e. if it has ever been saved).
 *
 * The DrawDocument class's responsibilities:
 *
 * 1. Manage the window (including the scrolling view) which holds the
 *    document's GraphicView.  This includes constraining the resizing of
 *    the window so that it never becomes larger than the GraphicView, and
 *    ensuring that if the window contains an unsaved document and the user
 *    tries to close it, the user gets an opportunity to save her changes.
 * 2. Handle communication with the Workspace Manager which allows icons
 *    for PostScript and TIFF files to be dragged into the document window
 *    and be assimilated into the document.
 * 3. Saving the document to a disk file.
 * 4. Provide an external interface to saving the contents of the GraphicView
 *    as a PostScript or TIFF file.
 */

#define MIN_WINDOW_WIDTH 50.0
#define MIN_WINDOW_HEIGHT 75.0
#define SCROLLVIEW_BORDER NSNoBorder

static NSRect calcFrame(NSPrintInfo *printInfo)
/*
 * Calculates the size of the page the user has chosen minus its margins.
 */
{
    NSRect viewRect;
    viewRect.origin = NSZeroPoint;
    viewRect.size = [printInfo paperSize];
    viewRect.size.width -= [printInfo leftMargin] + [printInfo rightMargin];
    viewRect.size.height -= [printInfo topMargin] + [printInfo bottomMargin];
    return viewRect;
}

static NSSize contentSizeForView(NSView *view)
/*
 * Calculates the size of the window's contentView by accounting for the
 * existence of the ScrollView around the GraphicView.  No scrollers are
 * assumed since we are interested in the minimum size need to enclose
 * the entire view and, if the entire view is visible, we don't need
 * scroll bars!
 */
{
    return [SyncScrollView frameSizeForContentSize:[view frame].size hasHorizontalScroller:YES hasVerticalScroller:YES borderType:SCROLLVIEW_BORDER];
}

static NSWindow *createWindowForView(NSView *view, NSRect *windowContentRect, NSString *frameString)
/*
 * Creates a window for the specified view.
 *
 * If windowContentRect is NULL, then a window big enough to fit the whole
 * view is created (unless that would be too big to comfortably fit on the
 * screen, in which case a smaller window may be allocated).
 * If windowContentRect is not NULL, then it is used as the contentView of
 * the newly created window.
 *
 * setMiniwindowIcon: sets the name of the bitmap which will be used in
 * the miniwindow of the window (i.e. when the window is miniaturized).
 * The icon "drawdoc" was defined in InterfaceBuilder (take a look in
 * the icon suitcase).
 */
{
    NSWindow *window;
    NSSize screenSize;
    SyncScrollView *scrollView;
    NSRect defaultWindowContentRect;

    if (!windowContentRect) {
	windowContentRect = &defaultWindowContentRect;
	windowContentRect->size = contentSizeForView(view);
	screenSize = [[NSScreen mainScreen] frame].size;
#ifndef WIN32
	if (windowContentRect->size.width > screenSize.width / 2.0) {
	    windowContentRect->size.width = floor(screenSize.width / 2.0);
	}
#endif WIN32
	if (windowContentRect->size.height > screenSize.height - 20.0) {
	    windowContentRect->size.height = screenSize.height - 20.0;
	}
	windowContentRect->origin.x = screenSize.width - 85.0 - windowContentRect->size.width;
	windowContentRect->origin.y = floor((screenSize.height - windowContentRect->size.height) / 2.0);
    }

    window = [[NSWindow allocWithZone:(NSZone *)[view zone]] initWithContentRect:*windowContentRect
			    styleMask:NSResizableWindowMask|NSClosableWindowMask|NSMiniaturizableWindowMask
			      backing:(InMsgPrint ? NSBackingStoreNonretained : NSBackingStoreBuffered)
				defer:(InMsgPrint ? NO : YES)];

    if (frameString) [window setFrameFromString:frameString];
    scrollView = [[SyncScrollView allocWithZone:(NSZone *)[view zone]] initWithFrame:*windowContentRect];
    [scrollView setRulerClass:[Ruler class]];
    [scrollView setRulerOrigin:UpperLeft];
    [scrollView setRulerWidths:[Ruler width] :[Ruler width]];
    [scrollView setHasVerticalScroller:YES];
    [scrollView setHasHorizontalScroller:YES];
    [scrollView setBorderType:SCROLLVIEW_BORDER];
    [scrollView setDocumentView:view];
    [window setContentView:scrollView];
    [window makeFirstResponder:view];
    [window setMiniwindowImage:[[NSWorkspace sharedWorkspace] iconForFileType:DRAW_EXTENSION]];
    [window setReleasedWhenClosed:YES];

    return window;
}

+ (NSWindow *)createWindowForView:(NSView *)gview windowRect:(NSRect *)windowContentRect frameString:(NSString *)frameString
{
    return createWindowForView(gview, windowContentRect, frameString);
}

/* Factory methods */

/*
 * We reuse zones since it doesn't cost us anything to have a
 * zone lying around (e.g. if we open ten documents at the start
 * then don't use 8 of them for the rest of the session, it doesn't
 * cost us anything except VM (no real memory cost)), and it is
 * risky business to go around NSDestroy()'ing zones since if
 * your application accidentally allocates some piece of global
 * data into a zone that gets destroyed, you could have a pointer
 * to freed data on your hands!  We use the List object since it
 * is so easy to use (which is okay as long as 'id' remains a
 * pointer just like (NSZone *) is a pointer!).
 *
 * Note that we don't implement alloc and allocFromZone: because
 * we create our own zone to put ourselves in.  It is generally a
 * good idea to "notImplemented:" those methods if you do not allow
 * an object to be alloc'ed from an arbitrary zone (other examples
 * include Application and all of the Application Kit panels
 * (which allocate themselves into their own zone).
 */

static List *zoneList = nil;

+ (NSZone *)newZone
{
    if (!zoneList || ![zoneList count]) {
	return NSCreateZone(NSPageSize(), NSPageSize(), YES);
    } else {
	return (NSZone *)[zoneList removeLastObject];
    }
}

+ (void)reuseZone:(NSZone *)aZone
{
    if (!zoneList) zoneList = [List new];
    [zoneList addObject:(id)aZone];
    NSSetZoneName(aZone, @"Unused");
}

+ (id)allocWithZone:(NSZone *)aZone
{
    [NSException raise:@"NSInvalidArgumentException" format:@"*** Method: %@ not implemented by %@", sel_getName(_cmd), [self class]];
    return nil;
}

+ (id)alloc
{
    [NSException raise:@"NSInvalidArgumentException" format:@"*** Method: %@ not implemented by %@", sel_getName(_cmd), [self class]];
    return nil;
}

/* Handles errors encountered by NSFileManager */

+ (BOOL)fileManagerShouldProceedAfterError:(NSDictionary *)info
{
    return NSRunAlertPanel(FILE_ERROR, [info objectForKey:@"Error"], PROCEED_AFTER_FILE_ERROR, ABORT_AFTER_FILE_ERROR, nil);
}

/* Creation methods */

+ new
/*
 * Creates a new, empty, document.
 *
 * Creates a PrintInfo object; creates a view whose size depends on the
 * default PrintInfo created; creates a window for that view; sets self
 * as the window's delegate; orders the window front; registers the window
 * with the Workspace Manager.  Note that the default margins are set
 * to 1/2 inch--that's more appropriate for a draw program than 1 or 1.25
 * inches.
 */
{
    NSZone *zone;
    NSRect frameRect;
    DrawDocument *newDocument = nil;
    zone = [self newZone];
    newDocument = [super allocWithZone:zone];
    [newDocument init];
    newDocument->printInfo = [[NSPrintInfo allocWithZone:zone] init];
    [newDocument->printInfo setLeftMargin:36.0];
    [newDocument->printInfo setRightMargin:36.0];
    [newDocument->printInfo setTopMargin:36.0];
    [newDocument->printInfo setBottomMargin:36.0];
    frameRect = calcFrame(newDocument->printInfo);
    newDocument->view = [[GraphicView allocWithZone:zone] initWithFrame:frameRect];
    newDocument->window = [self createWindowForView:newDocument->view windowRect:NULL frameString:nil];
    [newDocument->window setDelegate:newDocument];
    [newDocument resetScrollers];
    [newDocument setName:nil andDirectory:nil];
#ifndef OBJECT_LINKS_BROKEN
    [newDocument setLinkManager:[[NSDataLinkManager allocWithZone:(NSZone *)[newDocument zone]] initWithDelegate:newDocument]];
#endif
    [newDocument->window makeKeyAndOrderFront:newDocument];

    return newDocument;
}

+ newFromFile:(NSString *)file andDisplay:(BOOL)display
/*
 * Opens an existing document from the specified file.
 */
{
    DrawDocument *newDocument = nil;
    NSDictionary *plist = nil;
    NSString *fileDirectory = nil;
    NSFileManager *fileManager = [NSFileManager defaultManager];
	NSString *directoryContainingDocument = nil;
    BOOL isDirectory = NO;

    if ([fileManager fileExistsAtPath:file isDirectory:&isDirectory]) {
        if (isDirectory) {
            fileDirectory = file;
            file = [file stringByAppendingPathComponent:DRAW_DOCUMENT_NAME];
        } else if ([[file lastPathComponent] isEqual:DRAW_DOCUMENT_NAME]) {
		    fileDirectory = [file stringByDeletingLastPathComponent];
			if (![[fileDirectory pathExtension] isEqual:DRAW_EXTENSION]) {
			    fileDirectory = nil;
			}
		}
        if ([self isPreOpenStepFile:file]) {
            [fileManager copyPath:file
                        toPath:[[[file stringByDeletingPathExtension] stringByAppendingPathComponent:@"-pre-OpenStep"] stringByAppendingPathExtension:DRAW_EXTENSION]
                        handler:self];
            newDocument = [self openPreOpenStepFile:file];
        } else {
            if ([fileManager isReadableFileAtPath:file]) {
                newDocument = [super allocWithZone:[self newZone]];
                [newDocument init];
                plist = [NSDictionary dictionaryWithContentsOfFile:file];
                newDocument->printInfo = [[NSUnarchiver unarchiveObjectWithData:[plist objectForKey:PRINTINFO_KEY]] retain];
                [Graphic updateCurrentGraphicIdentifier:[[plist objectForKey:GRAPHIC_IDENT_KEY] intValue]];
 			    directoryContainingDocument = fileDirectory ? fileDirectory : [file stringByDeletingLastPathComponent];
                newDocument->view = [[GraphicView allocWithZone:[newDocument zone]] initWithFrame:rectFromPropertyList([plist objectForKey:SIZE_KEY])
                                                                                 fromPropertyList:[plist objectForKey:VIEW_KEY]
                                                                                      inDirectory:directoryContainingDocument];
                newDocument->window = [self createWindowForView:newDocument->view windowRect:NULL frameString:[plist objectForKey:FRAME_KEY]];
            }
        }
    }

    if (!newDocument) {
        NSRunAlertPanel(OPEN_TITLE, OPEN_ERROR, nil, nil, nil, file);
    } else {
        [newDocument->window setDelegate:newDocument];
        [newDocument resetScrollers];
        newDocument->haveSavedDocument = YES;
        [newDocument setName:fileDirectory ? fileDirectory : file];
#ifndef OBJECT_LINKS_BROKEN
        [newDocument setLinkManager:[[NSDataLinkManager allocWithZone:(NSZone *)[newDocument zone]] initWithDelegate:newDocument fromFile:fileDirectory ? fileDirectory : file]];
	// initWithDelegate:fromFile: might dirty our document but the linkManager is obviously not set yet, so let it know now that it is set, catch-22!
	if ([newDocument isDirty]) [newDocument dirty:nil];
#endif
        if (display) [newDocument->window makeKeyAndOrderFront:newDocument];
    }

    return newDocument;
}

+ newFromFile:(NSString *)file
{
    return [self newFromFile:file andDisplay:YES];
}

- (id)init
{
    [super init];
    [self registerForServicesMenu];
    return self;
}

- (void)dealloc
{
    [self reset:self];
    [printInfo release];
    [linkManager release];
    [name autorelease];
    [directory autorelease];
    [iconPathList autorelease];
    [[self class] reuseZone:(NSZone *)[self zone]];
    [super dealloc];

}

/* Data link methods -- see gvLinks.m and Links.rtf for more info. */

- (void)setLinkManager:(NSDataLinkManager *)aLinkManager
{
    linkManager = aLinkManager;
    [view setLinkManager:aLinkManager]; 
}

- (BOOL)showSelection:(NSSelection *)selection
{
    return [view showSelection:selection];
}

- copyToPasteboard:(NSPasteboard *)pasteboard at:(NSSelection *)selection cheapCopyAllowed:(BOOL)flag
{
    return [view copyToPasteboard:pasteboard at:selection cheapCopyAllowed:flag];
}

- (BOOL)pasteFromPasteboard:(NSPasteboard *)pasteboard at:(NSSelection *)selection
{
    return [view pasteFromPasteboard:pasteboard at:selection];
}

- (BOOL)importFile:(NSString *)filename at:(NSSelection *)selection
{
    return [view importFile:filename at:selection];
}

- (NSWindow *)windowForSelection:(NSSelection *)selection
{
    return window;
}

- (void)dataLinkManager:linkManager didBreakLink:(NSDataLink *)aLink
{
    [view breakLinkAndRedrawOutlines:aLink];
}

- (void)dataLinkManagerRedrawLinkOutlines:(NSDataLinkManager *)sender
{
    [view breakLinkAndRedrawOutlines:nil];
}

- (BOOL)dataLinkManagerTracksLinksIndividually:(NSDataLinkManager *)sender
{
    return YES;
}

- (void)dataLinkManager:(NSDataLinkManager *)sender startTrackingLink:(NSDataLink *)link
{
    [view startTrackingLink:link];
}

- (void)dataLinkManager:(NSDataLinkManager *)sender stopTrackingLink:(NSDataLink *)link
{
    [view stopTrackingLink:link];
}

- (void)dataLinkManagerDidEditLinks:(NSDataLinkManager *)sender
{
    [self dirty:self];
    [view updateLinksPanel];
}

- saveLink:sender
{
    NSSelection *selection;
    NSDataLink *link;
    NSArray *typesDrawExports = TypesDrawExports();

    selection = [view currentSelection];
    link = [[NSDataLink alloc] initLinkedToSourceSelection:selection managedBy:linkManager supportingTypes:typesDrawExports];
    [link saveLinkIn:[self filename]];
    [link release];

    return self;
}

/*
 * Overridden from ChangeManager (Undo stuff)
 */

- (void)changeWasDone
{
    [super changeWasDone];
    [window setDocumentEdited:[self isDirty]];
    [linkManager noteDocumentEdited];
}

- (void)changeWasUndone
{
    [super changeWasUndone];
    [window setDocumentEdited:[self isDirty]];
    [linkManager noteDocumentEdited];
}

- (void)changeWasRedone
{
    [super changeWasRedone];
    [window setDocumentEdited:[self isDirty]];
    [linkManager noteDocumentEdited];
}

- (void)clean:sender
{
    [super clean:sender];
    [window setDocumentEdited:NO]; 
}

- (void)dirty:sender
{
    [super dirty:sender];
    [window setDocumentEdited:YES];
    [linkManager noteDocumentEdited];
}

/* Services menu support methods. */

/* Services menu registrar */

- (void)registerForServicesMenu
{
    static BOOL registered = NO;
    NSArray * validSendTypes = [[[NSArray alloc] initWithObjects:NSFilenamesPboardType, nil] autorelease];

    if (!registered) {
	registered = YES;
	[NSApp registerServicesMenuSendTypes:validSendTypes returnTypes:nil];
    } 
}

- (id)validRequestorForSendType:(NSString *)sendType returnType:(NSString *)returnType
/*
 * Services menu support.
 * We are a valid requestor if the send type is filename
 * and there is no return data from the request.
 */
{
    return (haveSavedDocument && [sendType isEqual:NSFilenamesPboardType] && (!returnType || [returnType isEqual:@""])) ? self : nil;
}

- (BOOL)writeSelectionToPasteboard:(NSPasteboard *)pboard types:(NSArray *)types;
/*
 * Services menu support.
 * Here we are asked by the Services menu mechanism to supply
 * the filename (which we said we were a valid requestor for
 * in the above method).
 */
{
    int save;

    if (haveSavedDocument) {
	int typeCount = [types count];
	int index = 0;
    
	while (index < typeCount) {
	    if ([[types objectAtIndex:index] isEqual:NSFilenamesPboardType]) {
	        break;
	    }else {
	        index++;
	    }
	}
	if (index < typeCount) {
	    NSString *filename = [self filename];
	    
	    if ([self isDirty]) {
		save = NSRunAlertPanel(SERVICE, SAVE_FOR_SERVICE, SAVE, DONT_SAVE, nil);
		if (save == NSAlertDefaultReturn) {
		    if ([self saveDocument]) [linkManager noteDocumentSaved];
		}
	    }

	    [pboard declareTypes:[[[NSArray alloc] initWithObjects:NSFilenamesPboardType, nil] autorelease] owner:self];
	    [pboard setData:[filename dataUsingEncoding:NSNonLossyASCIIStringEncoding] forType:NSFilenamesPboardType];

	    return YES;
	}
    }

    return NO;
}

/* Other methods. */

- (void)resetScrollers
/*
 * Checks to see if the new window size is too large.
 * Called whenever the page layout (either by user action or
 * by the opening or reverting of a file) is changed or
 * the user resizes the window.
 */
{
    SyncScrollView *scrollView;
    NSSize contentSize;
    NSRect contentRect, windowFrame;
    BOOL updateRuler = NO;

    if (window) {
	windowFrame = [window frame];
	contentRect = [[window class] contentRectForFrameRect:windowFrame styleMask:[window styleMask]];
	scrollView = [window contentView];
	contentSize = contentSizeForView(view);
	if ([scrollView horizontalRulerIsVisible]) {
	    contentSize.height += [Ruler width];
	    updateRuler = YES;
	}
	if ([scrollView verticalRulerIsVisible]) {
	    contentSize.width += [Ruler width];
	    updateRuler = YES;
	}
	if (contentRect.size.width >= contentSize.width || contentRect.size.height >= contentSize.height) {
	    contentSize.width = MIN(contentRect.size.width, contentSize.width);
	    contentSize.height = MIN(contentRect.size.height, contentSize.height);
	    [window setContentSize:(NSSize){contentSize.width, contentSize.height}];
	}
	if (updateRuler) [scrollView updateRuler];
    } 
}

- (GraphicView *)view
/*
 * Returns the GraphicView associated with this document.
 */
{
    return view;
}

- (NSPrintInfo *)printInfo
/*
 * Returns the PrintInfo object associated with this document.
 */
{
    return printInfo;
}

/* Target/Action methods */


- (void)changeLayout:sender
/*
 * Puts up a PageLayout panel and allows the user to pick a different
 * size paper to work on.  After she does so, the view is resized to the
 * new paper size.
 * Since the PrintInfo is effectively part of the document, we note that
 * the document is now dirty (by performing the dirty method).
 */
{
    NSRect frame;
    float lm, rm, tm, bm;
    NSSize paperSize;
    NSPrintInfo *tempPrintInfo;
    
    tempPrintInfo = [[printInfo copy] autorelease];

    if ([[NSApp pageLayout] runModalWithPrintInfo:tempPrintInfo] == NSOKButton) {
	paperSize = [printInfo paperSize];
	lm = [printInfo leftMargin];
	rm = [printInfo rightMargin];
	tm = [printInfo topMargin];
	bm = [printInfo bottomMargin];
	if (lm < 0.0 || rm < 0.0 || tm < 0.0 || bm < 0.0 ||
	    paperSize.width - lm - rm < 0.0 || paperSize.height - tm - bm < 0.0) {
	    NSRunAlertPanel(nil, BAD_MARGINS, nil, nil, nil);
	} else {
            [printInfo release];			/* Keep the changed (new) printInfo */
            printInfo = [tempPrintInfo retain];
            frame = calcFrame(printInfo);
            [view setFrameSize:(NSSize){ frame.size.width, frame.size.height }];
            [self resetScrollers];
            [view display];
            [self dirty:self];
	}
    } 
}

- (void)printDocumentWithPanels:(BOOL)panelFlag
/*
 * This is the "designated method" for printing.
 */
{
    NSPrintOperation *op;
    
    op = [NSPrintOperation printOperationWithView:[self view] printInfo:[self printInfo]];
    [op setShowPanels:panelFlag];
    [op runOperation]; 
}

- (void)printDocument:sender
/*
 * Print the document with UI, etc.  The default Print command.
 */
{
    [self printDocumentWithPanels:YES]; 
}

- (void)changeGrid:sender
/*
 * Changes the grid by putting up a modal panel asking the user what
 * she wants the grid to look like.
 */
{
    [[NSApp gridInspector] runModalForGraphicView:view]; 
}

- close:sender
{
    [window performClose:self];
    return self;
}

- (BOOL)save:(id <NSMenuItem>)invokingMenuItem
/*
 * Saves the file.  If this document has never been saved to disk,
 * then a SavePanel is put up to ask the user what file name she
 * wishes to use to save the document.
 */
{
    if (haveSavedDocument) {
        if ([self saveDocument]) {
	    [linkManager noteDocumentSaved];
	    [self clean:self];
	}
        return YES;
    } else {
        return [self saveAs:invokingMenuItem];
    }
}

- (BOOL)saveAs:(id <NSMenuItem>)invokingMenuItem
{
    NSSavePanel *savepanel;

    savepanel = [NSApp saveAsPanel:invokingMenuItem];
    if ([savepanel runModalForDirectory:directory file:name]) {
	NSString *path = [savepanel filename];
	[self setName:path];
	if ([self saveDocument]) {
	    [linkManager noteDocumentSavedAs:path];
	    [self clean:self];
	}
	return YES;
    }

    return NO;
}

- (void)saveTo:(id <NSMenuItem>)invokingMenuItem
/*
 * This takes the document and saves it as a Draw document file, PostScript
 * file, or TIFF file.  If the document type chosen is Draw document, then
 * this saves the file, but DOES NOT make that file the currently edited
 * file (this makes it easy to save your document elsewhere as a backup
 * and keep on going in the current document).
 *
 * If PostScript or TIFF is selected, then the document is written out
 * in the appropriate format.  In the case of PostScript and TIFF, the
 * actual saving is done using the more general method saveAs:using:.
 */
{
    NSSavePanel *savepanel = [NSApp saveToPanel:invokingMenuItem];

    if ([savepanel runModalForDirectory:directory file:[name stringByDeletingPathExtension]]) {
        NSString *fileWithExtension = [savepanel filename];
        NSString *fileWithoutExtension = [fileWithExtension stringByDeletingPathExtension];
        if ([[savepanel requiredFileType] isEqual:@"eps"]) {
            [self saveToEPSFile:fileWithoutExtension];
        } else if ([[savepanel requiredFileType] isEqual:@"tiff"]) {
            [self saveToTIFFFile:fileWithoutExtension];
        } else {
            BOOL reallyHaveSavedDocument = haveSavedDocument;
            NSString *savedName = name;		        /* save current name */
            NSString *savedDirectory = directory;	/* save current directory */
            name = nil; directory = nil;		/* clear current filename */
            [self setName:fileWithExtension];		/* temporarily change name */
            if ([self saveDocument]) {			/* save, then restore name */
                [linkManager noteDocumentSavedTo:[self filename]];
            }
            [self setName:savedName andDirectory:savedDirectory];
            haveSavedDocument = reallyHaveSavedDocument;
        }
    }
}

- (void)revertToSaved:sender
/*
 * Revert the document back to what is on the disk.
 */ 
{
    NSDictionary *plist;
    GraphicView *newView;
    NSPrintInfo *newPrintInfo;
    NSRect viewFrame, visibleRect;
    NSView *oldDocView;
    NSString *file;
    BOOL isDirectory = NO;
    
    if (!haveSavedDocument
	|| ![self isDirty]
	|| (NSRunAlertPanel(REVERT_TITLE, SURE_TO_REVERT, REVERT, CANCEL, nil, name) != NSAlertDefaultReturn)) {
	return;
    }

    visibleRect = [view visibleRect];
    [window endEditingFor:nil];

    file = [self filename];
    if ([[NSFileManager defaultManager] fileExistsAtPath:file isDirectory:&isDirectory] && isDirectory) {
        file = [file stringByAppendingPathComponent:DRAW_DOCUMENT_NAME];
    }

    if ((plist = [NSDictionary dictionaryWithContentsOfFile:file])) {
        newPrintInfo = [[NSUnarchiver unarchiveObjectWithData:[plist objectForKey:PRINTINFO_KEY]] retain];
        newView = [[GraphicView allocWithZone:[self zone]] initWithFrame:rectFromPropertyList([plist objectForKey:SIZE_KEY])
                                                        fromPropertyList:[plist objectForKey:VIEW_KEY]
                                                             inDirectory:[file stringByDeletingLastPathComponent]];
        if (newPrintInfo && newView) {
            [Graphic updateCurrentGraphicIdentifier:[[plist objectForKey:GRAPHIC_IDENT_KEY] intValue]];
            [self reset:self];
            printInfo = newPrintInfo;
            view = newView;
            oldDocView = [[window contentView] documentView];
            [[window contentView] setDocumentView:newView];
            [oldDocView release];
            viewFrame = calcFrame(printInfo);
            [window disableFlushWindow];
            [newView setFrameSize:(NSSize){ viewFrame.size.width, viewFrame.size.height }];
            [self resetScrollers];
            [newView scrollRectToVisible:visibleRect];
            [newView display];
            [window enableFlushWindow];
            [window flushWindow];
            [window makeFirstResponder:view];
            [self reset:self];
            [window setDocumentEdited:NO];
	    [view setLinkManager:linkManager];
	    [linkManager noteDocumentReverted];
            [view updateLinksPanel];
        }
    }
}

- (void)showTextRuler:sender
/*
 * Sent to cause the Text object ruler to be displayed.
 * Only does anything if the rulers are already visible.
 */
{
    SyncScrollView *scrollView = [window contentView];

    if ([scrollView verticalRulerIsVisible] && [scrollView horizontalRulerIsVisible]) {
	[scrollView showHorizontalRuler:NO];
	[sender toggleRuler:sender];
    } 
}

- (void)hideRuler:sender
/*
 * If sender is nil, we assume the sender wants the
 * ruler hidden, otherwise, we toggle the ruler.
 * If sender is the field editor itself, we do nothing
 * (this allows the field editor to demand that the
 * ruler stay up).
 */
{
    SyncScrollView *scrollView = [window contentView];
    NSText *fe = [window fieldEditor:NO forObject:NSApp];

    if (!sender && [scrollView verticalRulerIsVisible]) {
	[fe toggleRuler:sender];
	[scrollView toggleRuler:nil];
	if ([scrollView verticalRulerIsVisible]) [scrollView showHorizontalRuler:YES];
	[scrollView resizeSubviewsWithOldSize:NSZeroSize];
    } else if (sender) {
	if ([scrollView verticalRulerIsVisible]) {
	    [scrollView showVerticalRuler:NO];
	    [scrollView showHorizontalRuler:NO];
	    if (![fe window]) [scrollView toggleRuler:nil];
	} else {
	    [scrollView showVerticalRuler:YES];
	    if ([fe window]) {
		[scrollView showHorizontalRuler:NO];
	    } else {
		[scrollView showHorizontalRuler:YES];
		[scrollView toggleRuler:nil];
	    }
	}
	if ([fe superview] != nil)
	    [fe toggleRuler:sender];
    } 
}

/* Methods related to naming/saving this document. */

- (NSString *)filename
/*
 * Gets the fully specified file name of the document.
 * If directory is NULL, then the currentDirectory is used.
 * If name is NULL, then the default title is used.
 * ???kb NSString - This now returns an autorelease... I tried to fix up
 * all users of this, but it may kill something!
 */
{
    NSString *returnString = @"";
    if (!directory && !name) [self setName:nil andDirectory:nil];
    if (name) returnString = [directory stringByAppendingPathComponent:name];
    return returnString;
}

- (NSString *)directory
{
    return directory;
}

- (NSString *)name
{
    return name;
}

- (void)setName:(NSString *)newName andDirectory:(NSString *)newDirectory
/*
 * Updates the name and directory of the document.
 * newName or newDirectory can be nil, in which case the name or directory
 * will not be changed (unless one is currently not set, in which case
 * a default name will be used).
 */
{
    static int untitledCount = 0;
    
    if ((newName && ![newName isEqual:@""]) || !name) {
 	if (!newName || [newName isEqual:@""]) {
	    newName = UNTITLED;
	    // Should probably keep count of current UNTITLED documents.  When that goes to 0, set untitledCount = 0.
	    if (untitledCount) {
		newName = [newName stringByAppendingString:[NSString stringWithFormat:@"%d", untitledCount]];
	    }
	    untitledCount++;
	}
	if (![newName isEqual:name]) {
	    [name autorelease];
	    name = [newName copyWithZone:(NSZone *)[self zone]];
	}
    }

    if ((newDirectory && ![newDirectory isEqual:@""]) || !directory) {
 	if (!newDirectory || [newDirectory isEqual:@""]) {
	    newDirectory = [NSApp currentDirectory];
	}
	if (![newDirectory isEqual:directory]) {
	    [directory autorelease];
	    directory = [newDirectory copyWithZone:(NSZone *)[self zone]];
	}
    }

    [window setTitleWithRepresentedFilename:[self filename]];
    NSSetZoneName((NSZone *)[self zone], [self filename]); 
}

- (BOOL)setName:(NSString *)file
/*
 * If file is a full path name, then both the name and directory of the
 * document is updated appropriately, otherwise, only the name is changed.
 */
{
    if (file) {
    	NSString *lastComponent = [file lastPathComponent];
	
	if (![lastComponent isEqual:@""]) {
	    [self setName:lastComponent andDirectory:[file stringByDeletingLastPathComponent]];
	    return YES;
	} else {
	    [self setName:file andDirectory:nil];
	    return YES;
	}
    }

    return NO;
}

- (void)setTemporaryTitle:(NSString *)title
{
    [window setTitle:title];
    haveSavedDocument = NO;
    [self setName:title andDirectory:NSHomeDirectory()]; 
}

- (BOOL)saveTo:(NSString *)file using:(SEL)writeMethod
/*
 * Performed by the saveTo: method, this method uses the writeMethod
 * to have the GraphicView write itself in some foreign format (i.e., not
 * in Draw archive format).  It does some work to make the default name
 * of the file being saved to be the name of the document with the appropriate
 * extension.  It brings up the SavePanel so the user can specify the name
 * of the file to save to.
 */
{
    NSData *data;
    
    if (file && writeMethod && (data = [view performSelector:writeMethod])) {
        return [data writeToFile:file atomically:NO];    
    }

    return NO;
}

- (BOOL)saveToTIFFFile:(NSString *)file
{
    if (![[file pathExtension] isEqualToString:@"tiff"]) file = [file stringByAppendingPathExtension:@"tiff"];
    return [self saveTo:file using:@selector(dataForTIFF)];
}

- (BOOL)saveToEPSFile:(NSString *)file
{
    if (![[file pathExtension] isEqualToString:@"eps"]) file = [file stringByAppendingPathExtension:@"eps"];
    return [self saveTo:file using:@selector(dataForEPS)];
}
    
- (BOOL)saveDocument
/*
 * This just creates a property list with all the pertinent info and writes it
 * out to an ASCII file.  Not super efficient, but easy to debug and examplary
 * of how to use a property list to store a tree of objects.
 *
 * See GraphicView's propertylist method for more details on how the GraphicView
 * is archived.
 */
{
    BOOL savedOk = NO;
    NSString *filename = [self filename];
    NSString *backupFilename;
    NSString *fileDirectory = nil;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSMutableDictionary *fileContents;
    BOOL alreadyHasFormEntries = NO, isDirectory = NO;

    if ([fileManager fileExistsAtPath:filename isDirectory:&isDirectory] && isDirectory) {
        fileDirectory = filename;
        filename = [filename stringByAppendingPathComponent:DRAW_DOCUMENT_NAME];
    }

    alreadyHasFormEntries = isDirectory && [fileManager fileExistsAtPath:[fileDirectory stringByAppendingPathComponent:@"form.info"]];

    backupFilename = [[[filename stringByDeletingPathExtension] stringByAppendingString:@"~"] stringByAppendingPathExtension:DRAW_EXTENSION];
    if (([fileManager fileExistsAtPath:backupFilename] && ![fileManager removeFileAtPath:backupFilename handler:[self class]]) ||
        ([fileManager fileExistsAtPath:filename] && ![fileManager movePath:filename toPath:backupFilename handler:[self class]])) {
        NSRunAlertPanel(SAVE_TITLE, CANT_CREATE_BACKUP, nil, nil, nil);
    } else if (!isDirectory && ([view hasGraphicsWhichWriteFiles] || [view hasFormEntries]) &&
               [fileManager createDirectoryAtPath:filename attributes:nil]) {
	    fileDirectory = filename;
        filename = [filename stringByAppendingPathComponent:DRAW_DOCUMENT_NAME];
    }

    if ([fileManager isWritableFileAtPath:[filename stringByDeletingLastPathComponent]]) {
        [window makeFirstResponder:view];
        fileContents = [NSMutableDictionary dictionaryWithCapacity:10];
        [fileContents setObject:propertyListFromInt(NEW_DRAW_VERSION) forKey:VERSION_KEY];
        [fileContents setObject:[NSArchiver archivedDataWithRootObject:printInfo] forKey:PRINTINFO_KEY];
        [fileContents setObject:[window stringWithSavedFrame] forKey:FRAME_KEY];
        [fileContents setObject:propertyListFromNSRect([view bounds]) forKey:SIZE_KEY];
        [fileContents setObject:propertyListFromInt([Graphic currentGraphicIdentifier]) forKey:GRAPHIC_IDENT_KEY];
        [fileContents setObject:[view propertyList] forKey:VIEW_KEY];
        savedOk = [fileContents writeToFile:filename atomically:YES];
        haveSavedDocument = savedOk;
        if (fileDirectory) {
            if ([view hasFormEntries]) {
                if (alreadyHasFormEntries || NSRunAlertPanel(SAVE_TITLE, FORM_WARNING, YES_BUTTON, NO_BUTTON, nil)) {
                    [view writeFormEntriesToFile:[fileDirectory stringByAppendingPathComponent:@"form.info"]];
                    [self saveTo:[fileDirectory stringByAppendingPathComponent:@"form.eps"] using:@selector(dataForEPS)];
                }
            }
            [view allowGraphicsToWriteFilesIntoDirectory:fileDirectory];
        }
    } else {
        NSRunAlertPanel(SAVE_TITLE, DIR_NOT_WRITABLE, nil, nil, nil);
    }

    if (!savedOk) NSRunAlertPanel(SAVE_TITLE, CANT_SAVE, nil, nil, nil);

    return savedOk;
}

- (BOOL)isSameAs:(NSString *)filename
{
    return [[[self filename] stringByResolvingSymlinksInPath] isEqual:[filename stringByResolvingSymlinksInPath]];
}

/* Window delegate methods. */


- (BOOL)windowShouldClose:(id <NSMenuItem>)invokingMenuItem cancellable:(BOOL)cancellable
/*
 * If the GraphicView has been edited, then this asks the user if she
 * wants to save the changes before closing the window.
 *
 * Returning nil from this method informs the caller that the window should
 * NOT be closed.  Anything else implies it should be closed.
 */
{
    int save;
    NSString * action;

    action = [invokingMenuItem title];

    if (!action || [action isEqual:@""]) action = CLOSE;

    if ([self isDirty]) {
	if (cancellable) {
	    save = NSRunAlertPanel(action, SAVE_CHANGES, SAVE, DONT_SAVE, CANCEL, name);
	} else {
	    save = NSRunAlertPanel(action, SAVE_CHANGES, SAVE, DONT_SAVE, nil, name);
	}
	if (save != NSAlertDefaultReturn && save != NSAlertAlternateReturn) {
	    return NO;
	} else {
	    [window endEditingFor:self];	/* terminate any editing */
            if ((save == NSAlertDefaultReturn) && ![self save:invokingMenuItem]) return NO;
	}
    }

    return YES;
}

- (void)close
{
    [linkManager noteDocumentClosed];
    [linkManager release];
    linkManager = nil;
    [self reset:self];
    [self autorelease];
}

- (BOOL)windowShouldClose:(NSWindow *)sender
{
    if ([self windowShouldClose:nil cancellable:YES]) {
	[self close];
	return YES;
    } else {
	return NO;
    }
}

- windowDidBecomeMain:(NSWindow *)sender
/*
 * Set the cursor appropriately depending on which tool is currently selected.
 */
{
    [self performSelector:@selector(resetCursor:) withObject:[[NSNumber numberWithInt:50] retain] afterDelay:0.1];
    return self;
}

- (void)windowDidUpdate:(NSNotification *)notification
{
    if ([window isMainWindow]) [view updateLinksPanel];
}

- (NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)frameSize
/*
 * Constrains the size of the window to never be larger than the
 * GraphicView inside it (including the ScrollView around it).
 */
{
    NSRect fRect, cRect;

    cRect.size = contentSizeForView(view);
    fRect = [[window class] frameRectForContentRect:cRect styleMask:[window styleMask]];
    if ([[window contentView] horizontalRulerIsVisible]) fRect.size.height += [Ruler width];
    if ([[window contentView] verticalRulerIsVisible]) fRect.size.width += [Ruler width];
    frameSize.width = MIN(fRect.size.width, frameSize.width);
    frameSize.height = MIN(fRect.size.height, frameSize.height);
    frameSize.width = MAX(MIN_WINDOW_WIDTH, frameSize.width);
    frameSize.height = MAX(MIN_WINDOW_HEIGHT, frameSize.height);

    return frameSize;
}

- (void)windowDidResize:(NSNotification *)sender
/*
 * Just makes sure the selection is visible after resizing.
 */
{
    [view scrollSelectionToVisible];
}

- windowWillMiniaturize:(NSWindow *)sender toMiniwindow:counterpart
{
    NSString *extension;
    NSString *title;

    title = [self name];
    extension = [title pathExtension];
    if ([extension isEqual:DRAW_EXTENSION]) {
        title = [title stringByDeletingPathExtension];
    }
    [counterpart setTitle:title];
    return self;
}

- windowWillReturnFieldEditor:(NSWindow *)sender toObject:client
{
    if (!drawFieldEditor) drawFieldEditor = [[DrawSpellText alloc] initWithFrame:NSZeroRect];
    return drawFieldEditor;
}

/* Validates whether a menu command makes sense now */

static NSString *showRuler;
static NSString *hideRuler;
static BOOL menuStringsInitted = NO;

static void initMenuItemStrings(void)
{
    showRuler = SHOW_RULER;
    hideRuler = HIDE_RULER;
    menuStringsInitted = YES;
}

- (BOOL)validateMenuItem:(id <NSMenuItem>)anItem
/*
 * Validates whether a menu command that DrawDocument responds to
 * is valid at the current time.
 */
{
    SEL action = [anItem action];

    if (!menuStringsInitted) initMenuItemStrings();
    if (action == @selector(save:)) {
	return YES;
    } else if (action == @selector(revertToSaved:)) {
	return ([self isDirty] && haveSavedDocument);
    } else if (action == @selector(saveAs:)) {
	return (haveSavedDocument || ![view isEmpty]);
    } else if (action == @selector(saveTo:)) {
	return ![view isEmpty];
    } else if (action == @selector(saveLink:)) {
	return (haveSavedDocument && ![view hasEmptySelection]);
    } else if (action == @selector(close:)) {
	return YES;
    } else if (action == @selector(hideRuler:)) {
	if ([[window contentView] eitherRulerIsVisible]) {
	    [anItem setTitleWithMnemonic:hideRuler];
	    [anItem setEnabled:NO];
	} else {
	    [anItem setTitleWithMnemonic:showRuler];
	    [anItem setEnabled:NO];
	}
    } else if (action == @selector(alignSelLeft:) ||
	       action == @selector(alignSelRight:) ||
	       action == @selector(alignSelCenter:) ||
	       action == @selector(checkSpelling:) ||
	       action == @selector(showGuessPanel:)) {
	return [[window fieldEditor:NO forObject:NSApp] superview] ? YES : NO;
    } else if (action == @selector(printDocument:)) {
	return(![view isEmpty]);
    }

    return [super validateMenuItem:anItem];
}

/* Cursor-setting method */

- (void)resetCursor:(NSNumber *)countdownNumber
/*
 * Sets the document's cursor according to whatever the current graphic is.
 * Makes the graphic view the first responder if there isn't one or if
 * no tool is selected (the cursor is the normal one).
 */
{
    id fr, cursor = [NSApp cursor];
    NSScrollView *scrollview = [window contentView];

    if ([scrollview isKindOfClass:[NSScrollView class]]) {
        [scrollview setDocumentCursor:cursor];
        fr = [window firstResponder];
        if (!fr || fr == window || cursor == [NSCursor arrowCursor]) {
            [window makeFirstResponder:view];
        }
    } else {
	int countdown = [countdownNumber intValue];
	if (countdown-- > 0) {
            [self performSelector:@selector(resetCursor:) withObject:[[NSNumber numberWithInt:countdown] retain] afterDelay:0.1];
	}
        [countdownNumber release];
    }
}

- (void)resetCursor
{
   [self resetCursor:0];
}

/* Getting the graphicView */

- (GraphicView *)graphicView
{
    return view;
}

- (NSString *)description
{
    return [(NSDictionary *)[NSDictionary dictionaryWithObjectsAndKeys:name, @"Name", directory, @"Directory", view, @"View", haveSavedDocument ? @"Yes" : @"No", @"SavedDocument", nil] description];
}

@end
