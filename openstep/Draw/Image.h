@interface Image : Graphic
{
    NSImage *image;		/* an NSImage object */
    NSString *imageFile;		/* file NSImage is stored into */
    NSSize originalSize;	/* the original size */
    NSDataLink *link;
    BOOL dontCache, amLinkButton, amIcon;
}

/* Creation methods */

+ (BOOL)canInitWithPasteboard:(NSPasteboard *)pboard;

- (id)init;
- finishedWithInit;

- initEmpty;
- initFromImage:(NSImage *)anImage;
- (id)initWithData:(NSData *)data;
- (id)initWithPasteboard:(NSPasteboard *)pboard;
- (id)initWithFile:(NSString *)file;
- initFromIcon:(NSImage *)anImage;
- initWithLinkButton;

- (NSRect)reinitWithPasteboard:(NSPasteboard *)pboard;
- (NSRect)reinitFromFile:(NSString *)file;

- (void)dealloc;

/* Link methods */

- (void)setLink:(NSDataLink *)aLink;
- (NSDataLink *)link;

/* Methods overridden from superclass to support links */

- (int)cornerMask;
- (NSRect)extendedBounds;
- (BOOL)constrainByDefault;

/* Overridden from superclass */

- (BOOL)isValid;
- (BOOL)isOpaque;
- (float)naturalAspectRatio;
- draw;

- (BOOL)canEmitEPS;
- (NSData *)dataForEPS;
- (BOOL)canEmitTIFF;
- (NSData *)dataForTIFF;

- (void)setCacheable:(BOOL)flag;
- (BOOL)isCacheable;

/* Archiving methods */

- (BOOL)writesFiles;
- (void)writeFilesToDirectory:(NSString *)directory;
- (id)propertyList;
- (void)convertSelf:(ConversionDirection)direction propertyList:(id)plist;
- initFromPropertyList:(id)plist inDirectory:(NSString *)directory;

@end
