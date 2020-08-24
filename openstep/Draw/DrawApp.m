#import "draw.h"
#import "compatibility.h"

const int DrawVersion = 50;	/* minor version of the program */

@implementation DrawApp : NSApplication
/*
 * This class is used primarily to handle the opening of new documents
 * and other application-wide activity (such as responding to messages from
 * the tool palette).  It listens for requests from the Workspace Manager
 * to open a draw-format file as well as target/action messages from the
 * New and Open... menu items.
 */

/* Private C functions used to implement methods in this class. */

static DrawDocument *documentInWindow(NSWindow *window)
/*
 * Checks to see if the passed window's delegate is a DrawDocument.
 * If it is, it returns that document, otherwise it returns nil.
 */
{
    id document = [window delegate];
    return [document isKindOfClass:[DrawDocument class]] ? document : nil;
}

static NSWindow *findDocument(NSString *name)
/*
 * Searches the window list looking for a DrawDocument with the specified name.
 * Returns the window containing the document if found.
 * If name == NULL then the first document found is returned.
 */
{
    int count;
    DrawDocument *document;
    NSWindow *window;
    NSArray *windows;

    windows = [NSApp windows];
    count = [windows count];
    while (count--) {
	window = [windows objectAtIndex:count];
	document = documentInWindow(window);
	if ((!name && document) || [document isSameAs:name]) return window;
    }

    return nil;
}

static DrawDocument *openFile(NSString *directory, NSString *name, BOOL display)
/*
 * Opens a file with the given name in the specified directory.
 * If we already have that file open, it is ordered front.
 * Returns the document if successful, nil otherwise.
 */
{
    NSWindow *window;

    if (name && ![name isEqual:@""]) {
    	NSFileManager *fileMgr = [NSFileManager defaultManager];
	if ([directory isEqual:@""]) directory = @".";
	directory = [directory stringByStandardizingPath];
	if ([fileMgr changeCurrentDirectoryPath:directory]) {
	    NSString *newPath = [fileMgr currentDirectoryPath];
	    newPath = [newPath stringByAppendingPathComponent:name];
	    window = findDocument(newPath);
	    if (window) {
		if (display) [window makeKeyAndOrderFront:window];
		return [window delegate];
	    } else {
		DrawDocument *document = [DrawDocument newFromFile:newPath andDisplay:display];
                return document;
	    }
	} else {
	    NSRunAlertPanel(OPEN_TITLE, INVALID_PATH, nil, nil, nil, directory);
	}
    }

    return nil;
}

static DrawDocument *openDocument(NSString *document, BOOL display)
/*
 * Takes a full path to a document and splits it into the
 * directory and document name, ensures that it has a proper
 * extension, checks to see if such a file exists, and, if so,
 * calls openFile().
 */
{
    NSString *directory;
    NSString *name;
    
    if (![[document pathExtension] isEqual:@"draw"]) {
        document = [document stringByAppendingPathExtension:@"draw"];
    }
    name = [document lastPathComponent];
    if (![name isEqual:@""]) {
	directory = [document stringByDeletingLastPathComponent];
    } else {
	name = document;
	directory = nil;
    }
        
    // Make sure the file exists before we go try to open it.
    if (! [[NSFileManager defaultManager] fileExistsAtPath:document])  {
	return nil;
    }

    return openFile(directory, name, display);
}

/* Public methods */

+ (void)initialize
/*
 * Initializes the defaults.
 */
{
    NSMutableDictionary *registrationDict = [NSMutableDictionary dictionary];
    [registrationDict setObject:@"5" forKey:@"KnobWidth"];
    [registrationDict setObject:@"5" forKey:@"KnobHeight"];
    [registrationDict setObject:@"1" forKey:@"KeyMotionDelta"];
    [registrationDict setObject:@"YES" forKey:@"RemoteControl"];
    [registrationDict setObject:@"NO" forKey:@"EnableObjectLinks"];
    [[NSUserDefaults standardUserDefaults] registerDefaults:registrationDict];
}

- init
{
    if ((self = [super init])) {
        [self setDelegate:self]; // so that we get NSApp delegation methods
    }
    return self;
}

/* General application status and information querying/modifying methods. */

- (Class)currentGraphic
/*
 * The current factory to use to create new Graphics.
 */
{
    return currentGraphic;
}

- (DrawDocument *)currentDocument
/*
 * The DrawDocument in the main window (dark gray title bar).
 */
{
    return documentInWindow([self mainWindow]);
}

- (NSString *)currentDirectory
/*
 * Directory where Draw is currently "working."
 */
{
    NSString * cdir = [[self currentDocument] directory];
    return (cdir && ![cdir isEqual:@""]) ? cdir : (haveOpenedDocument ? [((NSOpenPanel *)[NSOpenPanel openPanel]) directory] : NSHomeDirectory());
}

/*
 * Call these to enter/exit the TextGraphic tool.
 * These are used currently by the Undo architecture.
 */

- (void)startEditMode
{
    [tools selectCellAtRow:1 column:0];
    [tools sendAction]; 
}

- (void)endEditMode
{
    [tools selectCellAtRow:0 column:0];
    [tools sendAction]; 
}

/* Application-wide shared panels */

static NSString *cleanTitle(NSString * menuItem)
/*
 * Just strips off trailing "..."'s.
 */
{
    NSString *returnTitle = menuItem;

    if ([menuItem hasSuffix:@"..."]) {
    	int index = [menuItem rangeOfString:@"..." options:NSBackwardsSearch|NSAnchoredSearch].location;
        returnTitle = [menuItem substringToIndex:index];
    }

    return returnTitle;
}

- (void)changeSaveType:(NSMatrix *)sender
/*
 * Called by the SavePanel accessory view whenever the user chooses
 * a different type of file to save to.  setRequiredFileType: does
 * not affect the SavePanel while it is running.  It only has effect
 * when the user has chosen a file, and the SavePanel ensures that it
 * has the correct extension by adding it if it doesn't have it already.
 * This message gets here via the Responder chain from the SavePanel.
 */
{
    NSSavePanel *saveToPanel = [self saveToPanel:nil];

    switch ([sender selectedRow]) {
        case 0: [saveToPanel setRequiredFileType:DRAW_EXTENSION]; break;
        case 1: [saveToPanel setRequiredFileType:@"eps"]; break;
        case 2: [saveToPanel setRequiredFileType:@"tiff"]; break;
    }
}

- (NSSavePanel *)saveToPanel:(id <NSMenuItem>)invokingMenuItem
/*
 * Returns a SavePanel with the accessory view which allows the user to
 * pick which type of file she wants to save.  The title of the Panel is
 * set to whatever was on the menu item that brought it up (it is assumed
 * invokingMenuItem cause the action which requires the SavePanel to come up).
 * If you want the currently-in-use saveToPanel, just pass nil to this method.
 */
{
    static NSSavePanel *currentSaveToPanel = nil;
    NSString *theTitle;

    if (invokingMenuItem || !currentSaveToPanel) {
	if (!savePanelAccessory) {
	    [NSBundle loadNibNamed:@"SavePanelAccessory" owner:self];
	}
	currentSaveToPanel = [NSSavePanel savePanel];
	theTitle = cleanTitle([invokingMenuItem title]);
	if (theTitle) [currentSaveToPanel setTitle:theTitle];
	[currentSaveToPanel setAccessoryView:savePanelAccessory];
	[spamatrix selectCellAtRow:0 column:0];
	[currentSaveToPanel setRequiredFileType:@"draw"];
    }

    return currentSaveToPanel;
}

- (NSSavePanel *)saveAsPanel:(id <NSMenuItem>)invokingMenuItem
/*
 * Returns a regular SavePanel with "draw" as the required file type.
 */
{
    NSSavePanel *savepanel = [NSSavePanel savePanel];
    NSString *theTitle;

    [savepanel setAccessoryView:nil];
    theTitle = cleanTitle([invokingMenuItem title]);
    if (theTitle) [savepanel setTitle:theTitle];
    [savepanel setRequiredFileType:@"draw"];

    return savepanel;
}

- (GridView *)gridInspector
/*
 * Returns the application-wide inspector for a document's grid.
 * Note that if we haven't yet loaded the GridView panel, we do it.
 * The instance variable gridInspector is set in setGridInspector:
 * since it is set as an outlet of the owner (self, i.e. DrawApp).
 */
{
    if (!gridInspector) [NSBundle loadNibNamed:@"GridView" owner:self];
    return gridInspector;
}

- (NSPanel *)inspectorPanel
/*
 * Returns the application-wide inspector for Graphics.
 */
{
    if (!inspectorPanel) {
	[NSBundle loadNibNamed:@"InspectorPanel" owner:self];
	[inspectorPanel setFrameAutosaveName:@"Inspector"];
	[inspectorPanel setBecomesKeyOnlyIfNeeded:YES];
	[[inspectorPanel delegate] preset];
    }
    return inspectorPanel;
}

- (DrawPageLayout *)pageLayout
/*
 * Returns the application-wide DrawPageLayout panel.
 */
{
    static DrawPageLayout *dpl = nil;

    if (!dpl) {
	dpl = [[DrawPageLayout pageLayout] retain];
	[NSBundle loadNibNamed:@"PageLayoutAccessory" owner:dpl];
    }

    return dpl;
}

- (void)orderFrontInspectorPanel:sender
/*
 * Creates the inspector panel if it doesn't exist, then orders it front.
 */
{
    [[self inspectorPanel] orderFront:self]; 
}

/* Setting up the Fax Cover Sheet menu */

#define aLCSE @selector(addLocalizableCoverSheetEntry:)

- setFaxCoverSheetMenu:anObject
/*
 * This goes through all the entries in CoverSheet.strings and makes
 * an entry in the cover sheet menu for them.  This is kind of a kooky
 * method, but it makes Draw much more usable as a Fax Cover Sheet
 * editor.
 */
{
    NSMenu *fcsMenu;
    id cell;
    NSString *coverSheetStringsFileContents;
    NSDictionary *table;
    NSString *path;
    NSEnumerator *enumerator;
    NSString *key, *value;

    fcsMenu = [anObject target];
    if (fcsMenu) {
        path = [[NSBundle mainBundle] pathForResource:@"CoverSheet" ofType:@"strings"];
        if (path) {
            coverSheetStringsFileContents = [NSString stringWithContentsOfFile:path];
            if (coverSheetStringsFileContents) {
                table = [coverSheetStringsFileContents propertyListFromStringsFileFormat];
                if (table) {
                    enumerator = [table keyEnumerator];
                    while ((key = [enumerator nextObject])) {
                        value = [table objectForKey:key];
                        cell = [fcsMenu addItemWithTitle:value action:aLCSE keyEquivalent:@""];
                        [cell setTarget:nil];
                        [cell setTag:(int)key]; // Yikes! Casting NSString * to int!
                    }
                }
            }
        }
        cell = [fcsMenu addItemWithTitle:FAX_NOTE action:@selector(addCoverSheetEntry:) keyEquivalent:@""];
        [cell setTarget:nil];
        [cell setTag:0];
    }

    return self;
}

/* Target/Action methods */

- (void)info:sender
/*
 * Brings up the information panel.
 */
{
    if (!infoPanel) {
	[NSBundle loadNibNamed:@"InfoPanel" owner:self];
	[infoPanel setFrameAutosaveName:@"InfoPanel"];
	[version setStringValue:[NSString stringWithFormat:@"(v%2d)", DrawVersion]];
    }

    [infoPanel orderFront:self]; 
}

- help:sender
/*
 * Loads up the Help draw document.
 * Note the use of NSBundle so that the Help document can be localized.
 * Should use the standard OpenStep help mechanism.
 */
{
    DrawDocument *document = nil;
    NSString *path;

    if ((path = [[NSBundle mainBundle] pathForResource:@"Help" ofType:@"draw"])) {
	if ((document = openDocument(path, NO))) {
	    [document setTemporaryTitle:HELP];
	    [[[document view] window] makeKeyAndOrderFront:self];
	}
    }

    if (!document) NSRunAlertPanel(nil, NO_HELP, nil, nil, nil);

    return self;
}

- (void)new:sender
/*
 * Creates a new document--called by pressing New in the Document menu.
 */
{
    [DrawDocument new];
}

- (void)open:sender
/*
 * Called by pressing Open... in the Window menu.
 */
{
    int numFiles;
    int index = 0;
    NSString *directory;
    NSArray *files;
    NSArray *drawFileTypes = [[[NSArray alloc] initWithObjects:@"draw", nil] autorelease];
    NSOpenPanel *openpanel = [NSOpenPanel openPanel];
    
    [openpanel setAllowsMultipleSelection:YES];
    directory = [self currentDirectory];
    if (directory) [openpanel setDirectory:directory];
    if ([openpanel runModalForTypes:drawFileTypes]) {
	files = [openpanel filenames];
        numFiles = [files count];
	while (index < numFiles) {
	    NSString *fullPath = [files objectAtIndex:index];
	    haveOpenedDocument = (openFile([fullPath stringByDeletingLastPathComponent], [fullPath lastPathComponent], YES) ? YES : NO) || haveOpenedDocument;
	    index++;
	}
    } 
}

- saveAll:(id <NSMenuItem>)invokingMenuItem
/*
 * Saves all the documents.
 */
{
    int count;
    NSWindow *window;

    count = [[self windows] count];
    while (count--) {
	window = [[self windows] objectAtIndex:count];
        [documentInWindow(window) save:invokingMenuItem];
    }

    return nil;
}

- terminate:(id <NSMenuItem>)invokingMenuItem cancellable:(BOOL)cancellable
/*
 * Makes sure all documents get an opportunity
 * to be saved before exiting the program.  If we are terminating because
 * the user logged out of the workspace (or powered off), then we cannot
 * give the user the option of cancelling the quit (that's what the
 * cancellable flag is for).
 */
{
    int count, choice;
    NSWindow *window;
    id document;

    count = [[self windows] count];
    while (count--) {
	window = [[self windows] objectAtIndex:count];
 	document = [window delegate];
	if ([document respondsToSelector:@selector(isDirty)] && [document isDirty]) {
	    if (cancellable) {
		choice = NSRunAlertPanel(QUIT_TITLE, UNSAVED_DOCUMENTS, REVIEW_UNSAVED, QUIT_ANYWAY, CANCEL);
	    } else {
		choice = NSRunAlertPanel(QUIT_TITLE, UNSAVED_DOCUMENTS, REVIEW_UNSAVED, QUIT_ANYWAY, nil);
	    }
	    if (choice == NSAlertOtherReturn)  {
		return self;
	    } else if (choice == NSAlertDefaultReturn) {
		count = [[self windows] count];
		while (count--) {
		    window = [[self windows] objectAtIndex:count];
		    document = [window delegate];
		    if ([document respondsToSelector:@selector(windowShouldClose:cancellable:)]) {
			if (![document windowShouldClose:invokingMenuItem cancellable:cancellable] && cancellable) {
			    return self;
			} else {
			    [document close];
			    [window close];
			}
		    }
		}
	    }
	    break;
	}
    }

    return nil;
}

- (void)terminate:(id <NSMenuItem>)invokingMenuItem
/*
 * Overridden to give user the opportunity to save unsaved files.
 */
{
    if (![self terminate:invokingMenuItem cancellable:YES]) {
        [super terminate:invokingMenuItem];
    }
}

/*
 * Application object delegate methods.
 * Since we don't have an application delegate, messages that would
 * normally be sent there are sent to the Application object itself instead.
 */

static void deactivateKeyUIinToolWindow(NSMatrix *tools)
{
    NSArray *cellArray = [tools cells];
    NSEnumerator *enumerator = [cellArray objectEnumerator];
    NSCell *cell;
    while ((cell = [enumerator nextObject])) {
	[cell setRefusesFirstResponder:YES];
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
/*
 * Makes the tool palette not ever become the key window.
 * Check for files to open specified on the command line.
 * Initialize the menus.
 * If there are no open documents (and we are not being
 * launched to service a Services request or otherwise
 * being invoked due to interapplication communication),
 * then open a blank one.
 */
{
    NSPanel *toolWindow;
    NSArray *arguments;
    NSEnumerator *enumerator;
    NSString *arg = nil;

    deactivateKeyUIinToolWindow(tools);
    toolWindow = (NSPanel *)[tools window];
    [toolWindow setFrameAutosaveName:[toolWindow title]];
    [toolWindow setBecomesKeyOnlyIfNeeded:YES];
    [toolWindow setFloatingPanel:YES];
    [toolWindow orderFront:self];

    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"EnableObjectLinks"]) {
        [editMenu removeItem:linkMenuItem]; // ObjectLinks not supported under OpenStep
    }

    arguments = [[NSProcessInfo processInfo] arguments];
    enumerator = [arguments objectEnumerator];
    while ((arg = [enumerator nextObject])) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:arg]) {
            haveOpenedDocument = (openDocument(arg, YES) ? YES : NO) || haveOpenedDocument;
        }
    }

    if (!haveOpenedDocument && ![[NSUserDefaults standardUserDefaults] objectForKey:@"NSServiceLaunch"]) {
	[self new:self];
    }

    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"Quit"]) {
	[self activateIgnoringOtherApps:YES];
	PSWait();
	[self terminate:nil];
    }
}

- (BOOL)application:(NSApplication *)sender openFile:(NSString *)path
{
    if (openDocument(path, YES)) {
        haveOpenedDocument = YES;
        return YES;
    }
    return NO;
}

- (BOOL)application:(NSApplication *)sender printFile:(NSString *)path
{
    id document;

    if ((document = findDocument(path))) {
        [[document delegate] printDocumentWithPanels:NO];
        return YES;
    } else {
        if ((document = [DrawDocument newFromFile:path andDisplay:NO])) {
            [document printDocumentWithPanels:NO];
            return YES;
        }
    }

    return NO;
}

- (void)workspaceWillPowerOff:(NSNotification *)notification 
/*
 * Give the user a chance to save his documents.
 */
{
    [self terminate:nil cancellable:NO];
}

/* Global cursor setting */

- (NSCursor *)cursor
/*
 * This is called by DrawDocument objects who want to set the cursor
 * depending on what the currently selected tool is (as well as on whether
 * the Control key has been pressed indicating that the select tool is
 * temporarily set--see sendEvent:).
 */
{
    NSCursor *theCursor = nil;
    if (!cursorPushed) theCursor = [[self currentGraphic] cursor];
    return theCursor ? theCursor : [NSCursor arrowCursor];
}

- (void)sendEvent:(NSEvent *)event 
/*
 * We override this because we need to find out when the control key is down
 * so we can set the arrow cursor so the user knows she is (temporarily) in
 * select mode.
 */
{
    if (event && [event type] < NSAppKitDefined) {	/* mouse or keyboard event */
#ifdef WIN32
         if ([event modifierFlags] & NSCommandKeyMask) { /* overload ctrl key for both key equivs and temporary select */
             if (!cursorPushed && currentGraphic
         	&& currentGraphic != [TextGraphic class] /* but we need to be able to do ctrl-b for bold */
                 ) {
#else
        if ([event modifierFlags] & NSControlKeyMask) {
            if (!cursorPushed && currentGraphic) {
#endif
		cursorPushed = YES;
		[[self currentDocument] resetCursor];
	    }
	} else if (cursorPushed) {
	    cursorPushed = NO;
	    [[self currentDocument] resetCursor];
	}
    }

    [super sendEvent:event];
}

- (BOOL)validateMenuItem:(id <NSMenuItem>)anItem
/*
 * The only command DrawApp itself controls is saveAll:.
 * Save All is enabled only if there are any documents open.
 */
{
    if ([anItem action] == @selector(saveAll:)) {
	return findDocument(nil) ? YES : NO;
    }
    return YES;
}


/*
 * This is a very funky method and tricks of this sort are not generally
 * recommended, but this hack is done so that new Graphic subclasses can
 * be added to the program without changing even one line of code (except,
 * of course, to implement the subclass itself).  One day it'd be nice to
 * show dynamically loading a new graphic from a bundle.
 *
 * The objective-C runtime function NSClassFromString is used to find the factory object
 * corresponding to the name of the icon of the cell sending the setCurrentGraphic:
 * message.
 *
 * Again, this is not recommended procedure, but it illustrates how
 * objective-C can be used to make some funky runtime dependent decisions.
 */

- (void)setCurrentGraphic:(NSMatrix *)sender
/*
 * The sender's selectedCell's icon is queried.  If that name corresponds
 * to the name of a class, then that class is set as the currentGraphic.
 * If not, then the select tool is put into effect.
 */
{
    id cell;
    NSString *className;

    if ((cell = [sender selectedCell])) {
	if ((className = [[cell image] name])) {
	    currentGraphic = NSClassFromString(className);
	} else {
	    currentGraphic = nil;
	}
	if (!currentGraphic) [tools selectCellAtRow:0 column:0];
	[[self currentDocument] resetCursor];
    } 
}

- (NSString *)description
{
    return [(NSDictionary *)[NSDictionary dictionaryWithObjectsAndKeys:[version stringValue], @"Version", cursorPushed ? @"Yes" : @"No", @"Cursor Pushed", haveOpenedDocument ? @"Yes" : @"No", @"Have Opened Document", nil] description];
}

@end
