#import <objc/Storage.h>

typedef enum { Normal, Resizing } DrawStatusType;
typedef enum { LEFT = 1, RIGHT, BOTTOM, TOP, HORIZONTAL_CENTERS, VERTICAL_CENTERS, BASELINES } AlignmentType;

extern DrawStatusType DrawStatus;
extern NSString *DrawPboardType;
extern BOOL InMsgPrint;

typedef enum { ByRect, ByGraphic, ByList } DrawSelectionType;

/* Update modes for links. */

#define UPDATE_NEVER 0
#define UPDATE_IMMEDIATELY - 1
#define UPDATE_NORMALLY 1

@interface GraphicView : NSView
{
    NSMutableArray *glist;		/* the list of Graphics */
    NSMutableArray *slist;		/* the list of selected Graphics. In 
    					   Draw with undo we are very careful
					   to keep slist sorted, like glist */
    NSImage *cacheImage;		/* the cache of drawn graphics */
    struct {
#ifdef __BIG_ENDIAN__
	unsigned int groupInSlist:1;	/* whether a Group is in the slist */
	unsigned int cacheing:1;	/* whether cacheing or drawing */
	unsigned int suspendLinkUpdate:1; /* don't update links */
	unsigned int grid:8;		/* grid size */
	unsigned int showGrid:1;	/* whether grid is visible */
	unsigned int locked:1;		/* some graphics are locked */
	unsigned int gridDisabled:1;	/* whether grid is enabled */
	unsigned int freeOriginalPaste:1;/* whether originalPaste needs free */
	unsigned int serviceActsOnSelection:1;	/* whether service acts on selection */
#else
	unsigned int serviceActsOnSelection:1;	/* whether service acts on selection */
	unsigned int freeOriginalPaste:1;/* whether originalPaste needs free */
	unsigned int gridDisabled:1;	/* whether grid is enabled */
	unsigned int locked:1;		/* some graphics are locked */
	unsigned int showGrid:1;	/* whether grid is visible */
	unsigned int grid:8;		/* grid size */
	unsigned int suspendLinkUpdate:1; /* don't update links */
	unsigned int cacheing:1;	/* whether cacheing or drawing */
	unsigned int groupInSlist:1;	/* whether a Group is in the slist */
#endif
// These last 16 bits are NOT archived, so don't depend on them being permanent across a Save/Open
	unsigned int selectAll:1;	/* select all was last select operation performed */
	unsigned int dragCopyOk:1;	/* true if dragging with sourcMask == copy is ok */
	unsigned int dragLinkOk:1;	/* true if dragging with sourcMask == link is ok */
	unsigned int didPrintCustomDefs:1; /* true if wrote custom PostScript defs in printing */
	unsigned int padding:12;
    } gvFlags;
    short *gupCoords;			/* points in the grid user path */
    int gupLength;			/* number of points in gupCoords */
    char *gupOps;			/* movetos and linetos in the gup */
    short *gupBBox;			/* bounding box of the gup */
    float gridGray;			/* grayness of the grid */
    int consecutivePastes;		/* number of consecutive pastes */
    int lastPastedChangeCount;		/* the change count of last paste */
    int lastCopiedChangeCount;		/* the change count of last cut or copy */
    int lastCutChangeCount;		/* the change count of last cut */
    NSView *editView;			/* flipped subview for editing */
    Graphic *originalPaste;		/* the first pasted graphic */
    NSDataLinkManager *linkManager;	/* manager of data links */
    NSRect *invalidRect;		/* invalid area which must be cleaned up */
    NSRect *dragRect;			/* last rectangle we dragged out to select */
    Storage *linkTrackingRects;		/* the rects of the links we are tracking */
    int spellDocTag;
}

/* Class initialization */

+ (void)initClassVars;

/* Alignment methods */

+ (SEL)actionFromAlignType:(AlignmentType)alignType;

/* Creation methods */

- (id)initWithFrame:(NSRect)frameRect;

/* Free method */

- (void)dealloc;

/* Public methods */

- (BOOL)isEmpty;
- (BOOL)hasEmptySelection;
- (void)dirty;
- (void)getSelection;
- (void)setGroupInSlist:(BOOL)setting;
- (void)resetGroupInSlist;
- (void)resetLockedFlag;
- (NSRect)getBBoxOfArray:(NSArray *)array;
- (NSRect)getBBoxOfArray:(NSArray *)array extended:(BOOL)flag;

- (void)redrawGraphics:graphicsList afterChangeAgent:changeAgent performs:(SEL)aSelector;
- (void)graphicsPerform:(SEL)aSelector;
- (void)graphicsPerform:(SEL)aSelector with:(void *)argument;

- (void)cache:(NSRect)rect;
- (void)cache:(NSRect)rect andUpdateLinks:(BOOL)updateLinks;
- (void)recacheSelection;
- (NSImage *)selectionCache;
- (void)cacheSelection;
- (void)cacheList:(NSArray *)array into:(NSImage *)aCache withTransparentBackground:(BOOL)flag;
- (void)cacheList:(NSArray *)array into:(NSImage *)aCache;
- (void)cacheGraphic:(Graphic *)graphic;

- (void)removeGraphic:(Graphic *)graphic;
- (void)insertGraphic:(Graphic *)graphic;
- (Graphic *)selectedGraphic;
- (NSMutableArray *)selectedGraphics;
- (NSMutableArray *)graphics;

- (int)gridSpacing;
- (BOOL)gridIsVisible;
- (BOOL)gridIsEnabled;
- (float)gridGray;
- (void)setGridSpacing:(int)gridSpacing;
- (void)setGridEnabled:(BOOL)flag;
- (void)setGridVisible:(BOOL)flag;
- (void)setGridGray:(float)gray;
- (void)setGridSpacing:(int)gridSpacing andGray:(float)gray;
- (NSPoint)grid:(NSPoint)point;

- (Graphic *)placeGraphic:(Graphic *)graphic at:(const NSPoint *)location;

/* Methods overridden from superclass */

- (void)setFrameSize:(NSSize)newSize;
- (void)mouseDown:(NSEvent *)event;
- (void)drawRect:(NSRect)rects;
- (void)keyDown:(NSEvent *)event;

/* Getting/Setting the current Graphic */

- (Class)currentGraphic;
- (void)setCurrentGraphic:sender;

/* Writing Draw forms and files */

- (BOOL)hasFormEntries;
- (void)writeFormEntriesToFile:(NSString *)filename;
- (BOOL)hasGraphicsWhichWriteFiles;
- (void)allowGraphicsToWriteFilesIntoDirectory:(NSString *)directory;

/* Target/Action methods */

- (void)delete:(id)sender;
- (void)selectAll:(id)sender;
- (void)deselectAll:sender;
- (void)lockGraphic:sender;
- (void)unlockGraphic:sender;
- (void)bringToFront:sender;
- (void)sendToBack:sender;
- (void)group:sender;
- (void)ungroup:sender;
- (void)align:sender;
- (void)changeAspectRatio:sender;
- (void)alignToGrid:sender;
- (void)sizeToGrid:sender;
- (void)enableGrid:sender;
- (void)hideGrid:sender;
- (void)addCoverSheetEntry:sender;
- (void)addLocalizableCoverSheetEntry:sender;

/* Target/Action messages sent from Controls to set various parameters */

- (void)takeGridValueFrom:sender;
- (void)takeGridGrayFrom:sender;
- (void)takeGrayValueFrom:sender;
- (void)takeLineWidthFrom:sender;
- (void)takeLineJoinFrom:sender;
- (void)takeLineCapFrom:sender;
- (void)takeLineArrowFrom:sender;
- (void)takeFillValueFrom:sender;
- (void)takeFrameValueFrom:sender;
- (void)takeLineColorFrom:sender;
- (void)takeFillColorFrom:sender;
- (void)takeFormEntryStatusFrom:sender;

- (void)changeFont:(id)sender;

/* Accepting becoming the First Responder */

- (BOOL)acceptsFirstResponder;

/* Printing-related methods */

- (void)endPrologue;

/* Archiving methods */

- (id)propertyList;
- initWithFrame:(NSRect)frame fromPropertyList:(id)plist inDirectory:(NSString *)directory;

/* Useful scrolling methods */

- (void)scrollGraphicToVisible:(Graphic *)graphic;
- (void)scrollPointToVisible:(NSPoint)point;
- (void)scrollSelectionToVisible;


- (void)checkSpelling:(id)sender;
- (void)ignoreSpelling:(id)sender;

@end

/* Pasteboard */

typedef enum { LinkOnly = -1, DontLink = 0, Link = 1 } LinkType;

@interface GraphicView(NSPasteboard)

extern NSArray *TypesDrawExports(void);
extern NSString *DrawPasteType(NSArray *types);
extern NSString *ForeignPasteType(NSArray *types);
extern NSString *TextPasteType(NSArray *types);
extern BOOL IncludesType(NSArray *types, NSString *type);
extern NSString *MatchTypes(NSArray *typesToMatch, NSArray *orderedTypes);

+ (void)convert:(NSUnarchiver *)unarchiver to:(NSString *)type using:(SEL)writer toPasteboard:(NSPasteboard *)pb;
+ (void)pasteboard:(NSPasteboard *)sender provideDataForType:(NSString *)type;

- (NSData *)dataForEPS;
- (NSData *)dataForEPSUsingList:(NSArray *)array;
- (NSData *)dataForTIFF;
- (NSData *)dataForTIFFUsingList:(NSArray *)array;

- (NSData *)copySelectionAsEPS;
- (NSData *)copySelectionAsTIFF;
- (NSData *)copySelection;

- copyToPasteboard:(NSPasteboard *)pboard types:(NSArray *)types;
- copyToPasteboard:(NSPasteboard *)pboard;
- (BOOL)pasteForeignDataFromPasteboard:(NSPasteboard *)pboard andLink:(LinkType)doLink at:(NSPoint)point;
- (NSArray *)pasteFromPasteboard:(NSPasteboard *)pboard andLink:(LinkType)doLink at:(const NSPoint *)point;
- (void)paste:sender andLink:(LinkType)doLink;
- (void)cut:(id)sender;
- (void)copy:(id)sender;
- (void)paste:(id)sender;
- (void)pasteAndLink:sender;

@end

/* Data link methods */

@interface GraphicView(Links)

- (NSSelection *)currentSelection;
- (Graphic *)findGraphicInSelection:(NSSelection *)selection;
- (NSArray *)findGraphicsInSelection:(NSSelection *)selection;

- (void)writeLinkToPasteboard:(NSPasteboard *)pboard types:(NSArray *)types;
- (BOOL)addLink:(NSDataLink *)link toGraphic:(Graphic *)graphic at:(NSPoint)p update:(int)update;

- (BOOL)pasteFromPasteboard:(NSPasteboard *)pboard at:(NSSelection *)selection;
- (BOOL)importFile:(NSString *)filename at:(NSSelection *)selection;
- (void)pasteboard:(NSPasteboard *)sender provideDataForType:(NSString *)type;
- copyToPasteboard:(NSPasteboard *)pboard at:(NSSelection *)selection cheapCopyAllowed:(BOOL)cheapCopyAllowed;

- (void)updateLinksPanel;
- (NSDataLinkManager *)linkManager;
- (void)setLinkManager:(NSDataLinkManager *)linkManager;
- (BOOL)showSelection:(NSSelection *)selection;
- (void)breakLinkAndRedrawOutlines:(NSDataLink *)aLink;
- (void)updateTrackedLinks:(NSRect)rect;
- (void)startTrackingLink:(NSDataLink *)link;
- (void)stopTrackingLink:(NSDataLink *)link;

@end

/* Dragging */

@interface GraphicView(Drag)

- (void)registerForDragging;
- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender;
- (unsigned int)draggingUpdated:(id <NSDraggingInfo>)sender;
- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender;

@end

/* Services Menu */

@interface GraphicView(Services)

- (id)validRequestorForSendType:(NSString *)sendType returnType:(NSString *)returnType;
- (BOOL)writeSelectionToPasteboard:(NSPasteboard *)pboard types:(NSArray *)types;
- readSelectionFromPasteboard:(NSPasteboard *)pboard;

@end

/*
 * Since we can't be sure that we have an InspectorPanel, we use the
 * objective-C respondsTo: mechanism to see if we can send the message
 * initializeGraphic: to [NSApp inspectorPanel].  This dummy interface
 * declaration declares those messages (so that even if they don't exists,
 * we can at least use them to check with respondsTo:).  We don't want
 * to import DrawApp.h or InspectorPanel.h since we might accidentally
 * introduce a dependency on them which wouldn't be caught because we
 * imported both of their interfaces.
 */

@interface PossibleInspectorPanel : NSObject

- (NSPanel *)inspectorPanel;
- (void)initializeGraphic:(Graphic *)graphic;

@end

extern NSEvent *periodicEventWithLocationSetToPoint(NSEvent *oldEvent, NSPoint point);
