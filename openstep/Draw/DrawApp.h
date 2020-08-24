@interface DrawApp : NSApplication
{
    NSMatrix *tools;		  /* the Tool Palette matrix */
    Class currentGraphic;	  /* the factory object used to create things */
    NSView *savePanelAccessory;	  /* the SavePanel Draw/PS/TIFF view */
    NSMatrix *spamatrix;	  /* the matrix in the savePanelAccessory view */
    NSPanel *infoPanel;		  /* the Info... panel */
    NSTextField *version;	  /* the version field in the Info... panel */
    GridView *gridInspector;	  /* the shared modal panel to inspect grids */
    NSColorPanel *inspectorPanel; /* the shared inspector panel */
    id <NSMenuItem> linkMenuItem; /* old Object Links menu item */
    NSMenu *editMenu;		  /* the Edit menu */
    BOOL cursorPushed;		  /* whether we've temporarily changed the
				     cursor to NSArrow because the user held
				     down the Control key */
    BOOL haveOpenedDocument;	  /* whether we have opened a document */
}

/* Public methods */

+ (void)initialize;

- (Class)currentGraphic;
- (DrawDocument *)currentDocument;
- (NSString *)currentDirectory;
- (void)startEditMode;
- (void)endEditMode;

/* Shared panels */

- (NSSavePanel *)saveToPanel:sender;
- (NSSavePanel *)saveAsPanel:sender;
- (GridView *)gridInspector;
- (NSPanel *)inspectorPanel;
- (DrawPageLayout *)pageLayout;
- (void)orderFrontInspectorPanel:sender;

/* Target/Action methods */

- (void)info:sender;
- (void)new:sender;
- (void)open:sender;
- (void)terminate:(id)sender;

/* Application delegate methods */

- (void)applicationDidFinishLaunching:(NSNotification *)notification;
- (BOOL)application:(NSApplication *)sender openFile:(NSString *)path;

/* Listener/Speaker methods */

/* Global cursor setting methods */

- (NSCursor *)cursor;
- (void)sendEvent:(NSEvent *)event;

/* Target/Action method which sets up the currentGraphic */

- (void)setCurrentGraphic:sender;

@end
