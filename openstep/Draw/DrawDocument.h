@interface DrawDocument : ChangeManager
{
    GraphicView *view;		/* the document's GraphicView */
    NSWindow *window;		/* the window the GraphicView is in */
    NSPrintInfo *printInfo;	/* the print information for the GraphicView */
    NSString *name;		/* the name of the document */
    NSString *directory;	/* the directory it is in */
    NSArray * iconPathList;	/* list of files last dragged over document */
    BOOL haveSavedDocument;	/* whether document has associated disk file */
    DrawSpellText *drawFieldEditor;
    NSDataLinkManager *linkManager;	/* manager of data links */
}

/* Factory methods */

+ (NSWindow *)createWindowForView:(NSView *)view windowRect:(NSRect *)windowContentRect frameString:(NSString *)frameString;
+ (NSZone *)newZone;

+ new;

+ newFromFile:(NSString *)file andDisplay:(BOOL)display;
+ newFromFile:(NSString *)file;

/* Public methods */

- (id)init;
- (void)dealloc;
- (void)close;	/* Frees (delayed). */

/* Data link methods */

- (void)setLinkManager:(NSDataLinkManager *)aLinkManager;
- (BOOL)showSelection:(NSSelection *)selection;
- copyToPasteboard:(NSPasteboard *)pasteboard at:(NSSelection *)selection cheapCopyAllowed:(BOOL)flag;
- (BOOL)pasteFromPasteboard:(NSPasteboard *)pasteboard at:(NSSelection *)selection;
- (BOOL)importFile:(NSString *)filename at:(NSSelection *)selection;
- (NSWindow *)windowForSelection:(NSSelection *)selection;

/* Overridden from ChangeManager */

- (void)changeWasDone;
- (void)changeWasUndone;
- (void)changeWasRedone;
- (void)clean:sender;
- (void)dirty:sender;

/* Public Methods */

- (void)resetScrollers;
- (GraphicView *)view;
- (NSPrintInfo *)printInfo;

/* Target/Action methods */

- (void)changeLayout:sender;
- (void)printDocumentWithPanels:(BOOL)panelsFlag;
- (void)printDocument:sender;
- (void)changeGrid:sender;
- (BOOL)save:sender;
- (BOOL)saveAs:sender;
- (void)saveTo:sender;
- (void)revertToSaved:sender;
- (void)showTextRuler:sender;
- (void)hideRuler:sender;

/* Document name and file handling methods */

- (NSString *)filename;
- (NSString *)directory;
- (NSString *)name;
- (void)setName:(NSString *)name andDirectory:(NSString *)directory;
- (BOOL)setName:(NSString *)name;
- (void)setTemporaryTitle:(NSString *)title;
- (BOOL)saveTo:(NSString *)type using:(SEL)streamWriter;
- (BOOL)saveToTIFFFile:(NSString *)file;
- (BOOL)saveToEPSFile:(NSString *)file;
- (BOOL)saveDocument;
- (BOOL)isSameAs:(NSString *)filename;

/* Services menu methods */

- (void)registerForServicesMenu;
- (id)validRequestorForSendType:(NSString *)sendType returnType:(NSString *)returnType;
- (BOOL)writeSelectionToPasteboard:(NSPasteboard *)pboard types:(NSArray *)types;

/* Window delegate methods */

- (BOOL)windowShouldClose:sender cancellable:(BOOL)flag;

- (BOOL)windowShouldClose:(NSWindow *)sender;
- windowDidBecomeMain:(NSWindow *)sender;
- (NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)frameSize;
- windowWillMiniaturize:(NSWindow *)sender toMiniwindow:counterpart;
- windowWillReturnFieldEditor:(NSWindow *)sender toObject:client;

/* Cursor setting */

- (void)resetCursor;

/* Getting the graphicView */

- (GraphicView *)graphicView;

@end

