#import "draw.h"
#import "compatibility.h"

/*
 * This file is for compatibility with reading old draw files.
 * Once we start using property lists for the pasteboard, we can even
 * remove the -encodeWithCoder: and +initialize: methods below.
 */

/*
 * This is just a convenience method for reading old Draw files that
 * have List classes archived in them.  It creates an NSMutableArray
 * out of the passed in List.  It frees the List (it does this because
 * it assumes you are converting to the new world and what nothing to
 * do with the old world).
 */

@implementation NSMutableArray(Compatibility)

- (id)initFromList:(id)aList
{
    int i, count;

    if ([aList isKindOf:[List class]]) {
        count = [aList count];
        [self initWithCapacity:count];
        for (i = 0; i < count; i++) {
            [self addObject:[aList objectAt:i]];
        }
    } else if ([aList isKindOf:[NSArray class]]) {
        return [self initWithArray:aList];
    } else {
        /* should probably raise */
    }

    return self;
}

@end

@interface Graphic(FileCompatibility)

- (Graphic *)replaceWithImage;
- (id)initWithCoder:(NSCoder *)stream;
- (void)encodeWithCoder:(NSCoder *)stream;

@end

@interface Tiff : Graphic
{
    NSData *newData;
}

- (Graphic *)replaceWithImage;
- (id)initWithCoder:(NSCoder *)stream;

@end

@interface PSGraphic : Graphic
{
    NSMutableData *newData;
}

- (Graphic *)replaceWithImage;
- (id)initWithCoder:(NSCoder *)stream;

@end

@implementation Circle(FileCompatibility)

+ (void)initialize
/*
 * This bumps the class version so that we can compatibly read
 * old Graphic objects out of an archive.
 */
{
    [Circle setVersion:1];
}

@end

@implementation Curve(FileCompatibility)

+ (void)initialize
/*
 * This bumps the class version so that we can compatibly read
 * old Graphic objects out of an archive.
 */
{
    [Curve setVersion:1];
}

@end

@implementation Graphic(FileCompatibility)

+ (void)initialize
/*
 * This sets the class version so that we can compatibly read
 * old Graphic objects out of an archive.
 */
{
    [Graphic setVersion:5];
}

/* Compatibility method for old PSGraphic and Tiff classes. */

- (Graphic *)replaceWithImage
{
    return self;
}

- (void)encodeWithCoder:(NSCoder *)stream
{
    gFlags.linewidthSet = (linewidth != 0.0);
    gFlags.lineColorSet = lineColor ? YES : NO;
    gFlags.fillColorSet = fillColor ? YES : NO;
    [stream encodeValuesOfObjCTypes:"ffffii", &bounds.origin.x, &bounds.origin.y,
	&bounds.size.width, &bounds.size.height, &gFlags, &identifier];
    if (gFlags.linewidthSet) [stream encodeValuesOfObjCTypes:"f", &linewidth];
    if (gFlags.lineColorSet) [stream encodeObject:lineColor];
    if (gFlags.fillColorSet) [stream encodeObject:fillColor];
}

- (id)initWithCoder:(NSCoder *)stream
{
    
    int version;
    float gray = NSBlack;

    version = [stream versionForClassName:[NSString stringWithCString:"Graphic"]];
    if (version > 2) {
	[stream decodeValuesOfObjCTypes:"ffffii", &bounds.origin.x, &bounds.origin.y,
	    &bounds.size.width, &bounds.size.height, &gFlags, &identifier];
    } else if (version > 1) {
	[stream decodeValuesOfObjCTypes:"ffffsi", &bounds.origin.x, &bounds.origin.y,
	    &bounds.size.width, &bounds.size.height, &gFlags, &identifier];
#ifdef __LITTLE_ENDIAN__
	*(unsigned int *)&gFlags = *(unsigned int *)&gFlags <<= 16;
#endif	
    } else {
	[stream decodeValuesOfObjCTypes:"ffffs", &bounds.origin.x, &bounds.origin.y,
	    &bounds.size.width, &bounds.size.height, &gFlags];
#ifdef __LITTLE_ENDIAN__
	*(unsigned int *)&gFlags = *(unsigned int *)&gFlags <<= 16;
#endif	
	identifier = [[self class] nextCurrentGraphicIdentifier];
    }
    if (version > 1 && identifier >= [[self class] currentGraphicIdentifier]) [[self class] updateCurrentGraphicIdentifier:identifier+1];
    if (gFlags.linewidthSet) [stream decodeValuesOfObjCTypes:"f", &linewidth];
    if (version < 1) {
	if (gFlags.lineColorSet) [stream decodeValuesOfObjCTypes:"f", &gray];
	if (gFlags.fillColorSet && (gFlags.eofill | gFlags.fill)) {
	    lineColor = NSZoneMalloc((NSZone *)[self zone], (1) * sizeof(NSColor *));
	    lineColor = [[NSColor blackColor] retain];
	    fillColor = NSZoneMalloc((NSZone *)[self zone], (1) * sizeof(NSColor *));
	    fillColor = [[NSColor colorWithCalibratedWhite:gray alpha:1.0] retain];
	} else if (gFlags.eofill | gFlags.fill) {
	    fillColor = NSZoneMalloc((NSZone *)[self zone], (1) * sizeof(NSColor *));
	    fillColor = [[NSColor colorWithCalibratedWhite:gray alpha:1.0] retain];
	    [self setOutlined:NO];
	} else {
	    lineColor = NSZoneMalloc((NSZone *)[self zone], (1) * sizeof(NSColor *));
	    lineColor = [[NSColor colorWithCalibratedWhite:gray alpha:1.0] retain];
	}
    } else {
	if (gFlags.lineColorSet) {
	    if (version < 5) {
                lineColor = [stream decodeNXColor];
	    } else {
                lineColor = [stream decodeObject];
            }
	    if ([lineColor isEqual:[NSColor clearColor]]) {
		lineColor = NULL;
		[self setOutlined:NO];
	    } else {
		[lineColor retain];
	    }
	}
	if (gFlags.fillColorSet) {
            if (version < 5) {
                fillColor = [stream decodeNXColor];
            } else {
                fillColor = [stream decodeObject];
            }
	    if ([fillColor isEqual:[NSColor clearColor]] || ([fillColor alphaComponent] == 0.0)) {
		fillColor = NULL;
		[self setFill:FILL_NONE];
	    } else {
		[fillColor retain];
	    }
	}
    }
    
    // from old awake method
    [[self class] initClassVars];
    
    return self;

}

@end

@interface GraphicView(PrivateMethods)
- (void)resetGUP;
- (NSView *)createEditView;
@end

@implementation GraphicView(FileCompatibility)

+ (void)initialize
/*
 * We up the version of the class so that we can read old .draw files.
 * See the read: method for how we use the version.
 */
{
    [GraphicView setVersion:1];
}

- (void)encodeWithCoder:(NSCoder *)stream
{
    
    [super encodeWithCoder:stream];
    [stream encodeValuesOfObjCTypes:"@sf", &glist, &gvFlags, &gridGray];
    [stream encodeObject:editView];

}

- (id)initWithCoder:(NSCoder *)stream
// Comment from the old awake method...
/*
 * After the GraphicView is unarchived, its cache must be created.
 * If we are loading in this GraphicView just to print it, then we need
 * not load up our cache.
 */
{
    
    int i;
    NSArray *evsvs;
    Graphic *graphic, *newGraphic;

    self = [super initWithCoder:stream];
    [stream decodeValuesOfObjCTypes:"@sf", &glist, &gvFlags, &gridGray];
    glist = [[NSMutableArray allocWithZone:[self zone]] initFromList:glist];
    for (i = [glist count]-1; i >= 0; i--) {
	graphic = [glist objectAtIndex:i];
	newGraphic = [graphic replaceWithImage];
	if (graphic != newGraphic) {
	    if (graphic) {
		[glist replaceObjectAtIndex:i withObject:newGraphic];
	    } else {
		[glist removeObjectAtIndex:i];
	    }
	}
    }
    slist = [[NSMutableArray allocWithZone:[self zone]] initWithCapacity:[glist count]];
    [self getSelection];
    [self resetGUP];
    if ([stream versionForClassName:@"GraphicView"] < 1) {
	editView = [self createEditView];
    } else {
	editView = [[stream decodeObject] retain];
    }

    evsvs = [editView subviews];
    for (i = [evsvs count]-1; i >= 0; i--) {
        [[evsvs objectAtIndex:i] release];
    }
    // from the old awake method
    PSInit();
    if (!InMsgPrint) {
        NSRect bounds = [self bounds];
        cacheImage = [[NSImage allocWithZone:[self zone]] initWithSize:bounds.size];
	[self cache:bounds andUpdateLinks:NO];
    }
    [[self class] initClassVars];
    [self registerForDragging];
    
    return self;

}

@end

@implementation Group(FileCompatibility)

- (Graphic *)replaceWithImage
/*
 * Since we got rid of Tiff and PSGraphic and replaced them
 * with the unified Image graphic, we need to go through our
 * list and replace all of them with an Image graphic.
 */
{
    int i;
    Graphic *graphic, *newGraphic;

    for (i = [components count]-1; i >= 0; i--) {
        graphic = [components objectAtIndex:i];
        newGraphic = [graphic replaceWithImage];
        if (graphic != newGraphic) {
            if (graphic) {
                [components replaceObjectAtIndex:i withObject:newGraphic];
            } else {
                [components removeObjectAtIndex:i];
            }
        }
    }

    return self;
}

+ (void)initialize
/*
 * This bumps the class version so that we can compatibly read
 * old Graphic objects out of an archive.
 */
{
    [Group setVersion:3];
}

- (void)encodeWithCoder:(NSCoder *)stream
{
    [super encodeWithCoder:stream];
    [stream encodeValuesOfObjCTypes:"@", &components];
    [stream encodeValueOfObjCType:"c" at:&dontCache];
    [stream encodeRect:lastRect];
    [stream encodeValueOfObjCType:"c" at:&hasTextGraphic];
}

static BOOL checkForTextGraphic(NSArray *list)
{
    int i;
    Graphic *graphic;

    for (i = [list count]-1; i >= 0; i--) {
        graphic = [list objectAtIndex:i];
        if ([graphic isKindOfClass:[TextGraphic class]] || ([graphic isKindOfClass:[Group class]] && [(Group *)graphic hasTextGraphic])) return YES;
    }

    return NO;
}

- (id)initWithCoder:(NSCoder *)stream
{

    self = [super initWithCoder:stream];
    [stream decodeValuesOfObjCTypes:"@", &components];
    components = [[NSMutableArray allocWithZone:[self zone]] initFromList:components];
    lastRect = bounds;
    if ([stream versionForClassName:[NSString stringWithCString:"Group"]] > 1) {
        [stream decodeValueOfObjCType:"c" at:&dontCache];
        lastRect = [stream decodeRect];
    }
    if ([stream versionForClassName:[NSString stringWithCString:"Group"]] > 2) {
        [stream decodeValueOfObjCType:"c" at:&hasTextGraphic];
    } else {
        hasTextGraphic = checkForTextGraphic(components);
    }
    return self;

}

@end

@interface Image(PrivateMethods)

- doInitFromImage:(NSImage *)anImage;

@end

@implementation Image(FileCompatibility)

+ (void)initialize
{
    [Image setVersion:7];
}

- (void)encodeWithCoder:(NSCoder *)stream
{

    [super encodeWithCoder:stream];
    [stream encodeValueOfObjCType:"c" at:&amLinkButton];
    [stream encodeValueOfObjCType:"c" at:&amIcon];
    if (!amLinkButton) {
        [stream encodeObject:image];
        [stream encodeSize:originalSize];
    }

}

- (id)initWithCoder:(NSCoder *)stream
{

    BOOL alphaOk;
    NSRect savedBounds;
    int version, linkNumber;

    self = [super initWithCoder:stream];
    version = [stream versionForClassName:[NSString stringWithCString:"Image"]];
    if (version > 5) [stream decodeValueOfObjCType:"c" at:&amLinkButton];
    if (version > 6) [stream decodeValueOfObjCType:"c" at:&amIcon];
    if (amLinkButton) {
        savedBounds = bounds;
        [self doInitFromImage:[NSImage imageNamed:@"NSLinkButton"]];
        bounds = savedBounds;
    } else {
        image = [[stream decodeObject] retain];
        originalSize = [stream decodeSize];
    }
    if (version <= 2) [stream decodeValuesOfObjCTypes:"c", &alphaOk];
    if (version == 4) {
        [[stream decodeObject] retain];	// used to be the NSDataLink
    } else if (version > 2 && version < 6) {
        [stream decodeValuesOfObjCTypes:"i", &linkNumber];
    }

    return self;

}

@end

@implementation Line(FileCompatibility)

+ (void)initialize
{
    [Line setVersion:1];
}

- (void)encodeWithCoder:(NSCoder *)stream
{
    [super encodeWithCoder:stream];
    [stream encodeValueOfObjCType:"i" at:&startCorner];
}

- (id)initWithCoder:(NSCoder *)stream
{
    self = [super initWithCoder:stream];
    if ([stream versionForClassName:[NSString stringWithCString:"Line"]] > 0) {
        [stream decodeValueOfObjCType:"i" at:&startCorner];
    } else {
        startCorner = LOWER_LEFT;
    }
    return self;
}

@end

@implementation Polygon(FileCompatibility)

+ (void)initialize
/*
 * This bumps the class version so that we can compatibly read
 * old Graphic objects out of an archive.
 */
{
    [Polygon setVersion:1];
}

@end

@implementation PSGraphic

- (Graphic *)replaceWithImage
{
    Image *retval = [[Image allocWithZone:(NSZone *)[self zone]] initWithData:newData];
    [retval setBounds:bounds];
    if (!gFlags.selected) [retval deselect];
    if (gFlags.locked) [retval lockGraphic];
    [self release];
    return retval;
}

- (id)initWithCoder:(NSCoder *)stream
{
    int length;
    float bbox[4];

    self = [super initWithCoder:stream];
    [stream decodeValuesOfObjCTypes:"ffffi",&bbox[0],&bbox[1],&bbox[2],&bbox[3],&length];
    newData = [[NSData alloc] initWithLength:length];
    [stream decodeArrayOfObjCType:"c" count:length at:[newData mutableBytes]];
    return self;
}

/*
 * No write: because PSGraphic is no longer used (replaced by Image).
 * It is here only for compatibility.
 */

@end

@implementation Rectangle(FileCompatibility)

+ (void)initialize
/*
 * This bumps the class version so that we can compatibly read
 * old Graphic objects out of an archive.
 */
{
    [Rectangle setVersion:1];
}

@end

@implementation Scribble(FileCompatibility)

+ (void)initialize
/*
 * This bumps the class version so that we can compatibly read
 * old Graphic objects out of an archive.
 */
{
    [Scribble setVersion:1];
}

- (void)encodeWithCoder:(NSCoder *)stream
{

    int i, numFloats;

    [super encodeWithCoder:stream];

    [stream encodeValuesOfObjCTypes:"iffff",&length,&bbox[0],&bbox[1],&bbox[2],&bbox[3]];

    numFloats = (length + 1) << 1;
    for (i = 0; i < numFloats; i++) {
        [stream encodeValuesOfObjCTypes:"f", &points[i]];
    }

}

- (id)initWithCoder:(NSCoder *)stream
{

    int i;
    float *p;

    self = [super initWithCoder:stream];

    [stream decodeValuesOfObjCTypes:"iffff",&length,&bbox[0],&bbox[1],&bbox[2],&bbox[3]];

    points = NSZoneMalloc((NSZone *)[self zone], ((length + 1) << 1) * sizeof(float));
    userPathOps = NSZoneMalloc((NSZone *)[self zone], (length + 1) * sizeof(char));

    p = points;
    for (i = 0; i <= length; i++) {
        [stream decodeValuesOfObjCTypes:"f", p++];
        [stream decodeValuesOfObjCTypes:"f", p++];
        userPathOps[i] = dps_rlineto;
    }
    userPathOps[0] = dps_moveto;

    return self;

}

@end

@interface TextGraphic(PrivateMethods)

+ (NSTextView *)drawText;

@end

@implementation TextGraphic(FileCompatibility)

+ (void)initialize
{
    [TextGraphic setVersion:6];		/* class version, see initWithCoder: */
}

- (void)encodeWithCoder:(NSCoder *)stream
{
    int length;
    [super encodeWithCoder:stream];
    length = [richTextData length];
    [stream encodeValuesOfObjCTypes:"i", &length];
    [stream encodeArrayOfObjCType:"c" count:length at:[richTextData bytes]];
}

- (id)initWithCoder:(NSCoder *)stream
{

    int version = [stream versionForClassName:[NSString stringWithCString:"TextGraphic"]];

    self = [super initWithCoder:stream];

    if (version < 1) {
        NSCell *cell;
	NSTextView *drawText = [[self class] drawText];
        [stream decodeValuesOfObjCTypes:"@", &cell];
        [drawText setString:[cell stringValue]];
        font = [cell font];
        [drawText setFont:[cell font]];
        [drawText setTextColor:[self lineColor]];
        [self setRichTextData:[drawText RTFFromRange:(NSRange){0, [[drawText string] length]}]];
    } else {
        int length;
        char *unarchivedText;
        [stream decodeValuesOfObjCTypes:"i", &length];
        unarchivedText = (char *)NSZoneMalloc([self zone], length*sizeof(char));
        [stream decodeArrayOfObjCType:"c" count:length at:unarchivedText];
        richTextData = [[NSData dataWithBytesNoCopy:unarchivedText length:length] retain];
    }

    if (version > 2 && version < 5) {
        int linkNumber;
        [stream decodeValuesOfObjCTypes:"i", &linkNumber];
    } else if (version == 2) {
        int linkNumber;
        link = [[stream decodeObject] retain];
        linkNumber = [link linkNumber];
        link = nil;
    }

    if (version > 3 && version < 6) {
        BOOL isFormEntry;
        [stream decodeValuesOfObjCTypes:"c", &isFormEntry];
        gFlags.isFormEntry = isFormEntry ? YES : NO;
    }

    [[self class] initClassVars];

    return self;

}

@end

@implementation Tiff

- (Graphic *)replaceWithImage
{
    Image *retval = [[Image allocWithZone:(NSZone *)[self zone]] initWithData:newData];
    [retval setBounds:bounds];
    if (!gFlags.selected) [retval deselect];
    if (gFlags.locked) [retval lockGraphic];
    [self release];
    return retval;
}

- (id)initWithCoder:(NSCoder *)stream
{
    NSBitmapImageRep *tempImageRep = [[NSBitmapImageRep alloc] initWithCoder:stream];
    newData = [tempImageRep TIFFRepresentation];
    [tempImageRep release];
    return self;
}

@end

@implementation DrawDocument(FileCompatibility)

#define DRAW_VERSION_3_0_PRERELEASE 234
#define DRAW_VERSION_3_0 245

- (BOOL)loadDocument:(NXStream *)stream frameSize:(NSRect *)frame frameString:(NSString **)frameString
/*
 * For backwards compatibility only.
 * Not used by the OpenStep version of this application except to read
 * files created by pre-OpenStep versions of Draw.
 *
 * Loads an archived document from the specified filename.
 * Loads the window frame specified in the archived document into the
 * frame argument (if the frame argument is NULL, then the frame in
 * the archived document is ignored).  Returns YES if the document
 * has been successfully loaded, NO otherwise.  Note that this method
 * destroys the receiving document, so use with extreme care
 * (essentially, this should only be called when a new document is
 * being created or an existing one is being reverted to its form
 * on disk).
 *
 * An NS_DURING handler is needed around the NXTypedStream operations because
 * if the user has asked that a bogus file be opened, the NXTypedStream will
 * raise an error.  To handle the error, the NXTypedStream must be closed.
 */
{
    char *archivedString;
    int cgi, version;
    volatile NSRect docFrame;
    volatile BOOL retval = YES;
    char *streamBuff = NULL;
    int streamLen, streamCapacity;
    NSData *streamData = nil;

    NS_DURING
	NXGetMemoryBuffer(stream, &streamBuff, &streamLen, &streamCapacity);
	if (streamBuff)  {
	    streamData = [NSData dataWithBytes:(const void *)streamBuff length:(unsigned)streamLen];
	    if (streamData)  {
		NSUnarchiver *unarchiver = [[[NSUnarchiver allocWithZone:(NSZone *)[self zone]] initForReadingWithData:streamData] autorelease];
		if (unarchiver)  {
		    [unarchiver setObjectZone:(NSZone *)[self zone]];
		    [unarchiver decodeValueOfObjCType:"i" at:&version];
		    printInfo = [[unarchiver decodeObject] retain];
		    if (version >= DRAW_VERSION_3_0_PRERELEASE) {
			[unarchiver decodeValueOfObjCType:"*" at:&archivedString];
			if (frameString) {
			    *frameString = [[NSString allocWithZone:(NSZone *)[self zone]] initWithCString:archivedString];
			} else {
			    NSZoneFree([self zone], archivedString);
			}
		    } else {
			docFrame = [unarchiver decodeRect];
		    }
		    if (version >= DRAW_VERSION_3_0) {
			[unarchiver decodeValueOfObjCType:"i" at:&cgi];
			[Graphic updateCurrentGraphicIdentifier:cgi];
		    }
		    view = [[unarchiver decodeObject] retain];
		}  else  {
		    retval = NO;
		}
	    }  else  {
		retval = NO;
	    }
	}  else  {
	    retval = NO;
	}
    NS_HANDLER
	retval = NO;
    NS_ENDHANDLER
    
    if (retval && frame) *frame = docFrame;

    return retval;
}

/* This is kind of an expensive way to check.  Should find a better way. */

+ (BOOL)isPreOpenStepFile:(NSString *)file
{
    NSData *fileData;
    int version = FIRST_OPENSTEP_VERSION;
    NSUnarchiver *unarchiver = nil;

    NS_DURING  {
        fileData = [NSData dataWithContentsOfFile:file];
        if (fileData)  {
            unarchiver = [[NSUnarchiver allocWithZone:(NSZone *)[(NSObject *)self zone]] initForReadingWithData:fileData];
            if (unarchiver) [unarchiver decodeValueOfObjCType:"i" at:(int *)&version];
        }
    }  NS_HANDLER  {
    }  NS_ENDHANDLER

    if (unarchiver) [unarchiver release];

    return (version < FIRST_OPENSTEP_VERSION);
}

+ openPreOpenStepFile:(NSString *)file
{
    DrawDocument *newDocument = nil;
    NSRect contentViewFrame;
    NXStream *stream;
    NSString *frameString = @""; // will come back still "" if an old file is read

    if ((stream = NXMapFile([file cString], NX_READONLY))) {
        newDocument = [super allocWithZone:[self newZone]];
        [newDocument init];
        if (stream && [newDocument loadDocument:stream frameSize:&contentViewFrame frameString:&frameString]) {
            newDocument->window = [self createWindowForView:newDocument->view windowRect:&contentViewFrame frameString:[frameString isEqual:@""] ? nil : frameString];
        } else {
            [newDocument release];
            newDocument = nil;
        }
        NXCloseMemory(stream, NX_FREEBUFFER);
    }

    return newDocument;
}

@end
