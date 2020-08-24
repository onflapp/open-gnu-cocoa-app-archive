@interface TextGraphic : Graphic
{
    NSData *richTextData;
    NSFont *font;
    NSView *editView;
    GraphicView *graphicView;
    NSTextView *fe;		 /* the field editor text object      */
    				/* used for editing between edit:in: */
				/* and textDidEnd:endChar:           */
    NSDataLink *link;
    NSString *name;
    NSRect lastEditingFrame;
}

/* Get class in shape. */

+ (void)initClassVars;

/* Factory methods overridden from superclass */

+ (BOOL)isEditable;
+ (NSCursor *)cursor;

/* Initialization methods */

+ (BOOL)canInitWithPasteboard:(NSPasteboard *)pboard;

- (id)init;
- finishedWithInit;

- initEmpty;

- (id)initFromData:(NSData *)data;
- (id)initWithPasteboard:(NSPasteboard *)pboard;

- (NSRect)reinitWithPasteboard:(NSPasteboard *)pboard;
- (NSRect)reinitFromData:(NSData *)data;

- initFormEntry:(NSString *)name localizable:(BOOL)isLocalizable;

/* Link methods */

- (void)setLink:(NSDataLink *)aLink;
- (NSDataLink *)link;

/* Instance methods overridden from superclass */

- (NSString *)title;
- (BOOL)create:(NSEvent *)event in:(GraphicView *)view;
- (BOOL)edit:(NSEvent *)event in:(NSView *)view;
- draw;
- (void)performTextMethod:(SEL)aSelector with:(void *)anArgument;
- (void)changeFont:(id)sender;
- (NSFont *)font;
- (BOOL)isOpaque;
- (BOOL)isValid;
- (BOOL)isFormEntry;
- (void)setFormEntry:(int)flag;
- (BOOL)writeFormEntryToMutableString:(NSMutableString *)aString;
- (NSColor *)lineColor;
- (NSColor *)fillColor;
- (float)baseline;
- (void)moveBaselineTo:(const float *)y;

/* Public methods */

- (void)prepareFieldEditor;
- (void)resignFieldEditor;
- (BOOL)isEmpty;
- (NSData *)richTextData;
- (void)setRichTextData:(NSData *)data;
- (void)setFont:(NSFont *)newFont;

/* Text delegate methods */

- (void)textDidEndEditing:(NSNotification *)notification;

/* Archiving methods */

- (id)propertyList;
- initFromPropertyList:(id)plist inDirectory:(NSString *)directory;

@end
