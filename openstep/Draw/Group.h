@interface Group : Graphic
{
    NSImage *cache;	/* an NSImage used to cache the group */
    NSMutableArray *components;	/* the Graphics in the group */
    NSRect lastRect;	/* the last rectangle the group was drawn in */
    BOOL dontCache;	/* whether we can cache this group */
    BOOL hasTextGraphic;/* whether a TextGraphic is included in the group */
}

/* Creation methods */

- initList:(NSMutableArray *)list;
- (void)dealloc;

/* Public methods */

- (void)transferSubGraphicsTo:(NSMutableArray *)array at:(int)position;
- (NSMutableArray *)subGraphics;

/* Group must override all the setting routines to forward to components */

- (void)makeGraphicsPerform:(SEL)aSelector with:(const void *)anArgument;

- (void)changeFont:(id)sender;
- (NSFont *)font;
- (void)setLineWidth:(const float *)value;
- (void)setGray:(const float *)value;
- (void)setFill:(int)mode;
- (void)setFillColor:(NSColor *)aColor;
- (void)setLineColor:(NSColor *)aColor;
- (void)setLineCap:(int)capValue;
- (void)setLineArrow:(int)arrowValue;
- (void)setLineJoin:(int)joinValue;

/* Link methods */

- (void)reviveLink:(NSDataLinkManager *)linkManager;
- (Graphic *)graphicLinkedBy:(NSDataLink *)aLink;

- (void)resetIdentifier;
- (NSString *)identifierString;
- (Graphic *)graphicIdentifiedBy:(int)anIdentifier;
- (void)readLinkFromPasteboard:(NSPasteboard *)pboard usingManager:(NSDataLinkManager *)linkManager useNewIdentifier:(BOOL)useNewIdentifier;

/* Notification from GraphicView */

- (void)wasRemovedFrom:(GraphicView *)sender;
- (void)wasAddedTo:(GraphicView *)sender;

/* Methods overridden from superclass */

- (Graphic *)colorAcceptorAt:(NSPoint)point;
- (void)setCacheable:(BOOL)flag;
- (BOOL)isCacheable;
- draw;
- (BOOL)hit:(NSPoint)point;

/* Methods propagated onto all the Graphics in the Group. */

- (BOOL)hasTextGraphic;
- (BOOL)hasFormEntries;
- (BOOL)writeFormEntryToMutableString:(NSMutableString *)aString;
- (BOOL)writesFiles;
- (void)writeFilesToDirectory:(NSString *)directory;

/* Archiving methods */

- (void)convertSelf:(ConversionDirection)direction propertyList:(id)plist;
- (id)propertyList;
- initFromPropertyList:(id)plist inDirectory:(NSString *)directory;

@end
