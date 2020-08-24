#import "draw.h"

@implementation TextGraphic
/*
 * This uses a text object to draw and edit text.
 *
 * The one quirky thing to understand here is that growable Text objects
 * in NeXTSTEP must be subviews of flipped view (this is a bug and will
 * be fixed in 4.0).  Since a GraphicView is not flipped, we must have a
 * flipped view into the view heirarchy when we edit (this editing view
 * is permanently installed as a subview of the GraphicView--see
 * GraphicView's newFrame: method).
 */

static NSTextView *drawText = nil;	/* shared Text object used for drawing */

+ (void)initClassVars
/*
 * Create the class variable drawText here.
 */
{
    if (!drawText) {
        drawText = [[NSTextView alloc] init];
        [[drawText textContainer] setWidthTracksTextView:YES];
        [[drawText textContainer] setHeightTracksTextView:YES];
        [drawText setHorizontallyResizable:NO];
        [drawText setVerticallyResizable:NO];
        [drawText setDrawsBackground:NO];
        [drawText setRichText:YES];
        [drawText setEditable:NO];
        [drawText setSelectable:NO];
    }
    [super initClassVars];
}

+ (NSTextView *)drawText
{
    if (!drawText) [self initClassVars];
    return drawText;
}

+ (BOOL)canInitWithPasteboard:(NSPasteboard *)pboard
{
    return IncludesType([pboard types], NSRTFPboardType) ||
	   IncludesType([pboard types], NSStringPboardType);
}

- (id)init
/*
 * Creates a "blank" TextGraphic.
 * This is TextGraphic's designated initializer,
 * but be wary because by the time this returns, the
 * TextGraphic may not be full initialized (it'll be
 * valid, just perhaps not fully initialized).
 * Override finishedWithInit if you want that.
 */
{
    [super init];
    [[self class] initClassVars];
    return self;
}

- initEmpty
/*
 * Creates an empty TextGraphic.
 */
{
    [self init];
    return [self finishedWithInit];
}

- finishedWithInit
/*
 * Override this if you want to know when a newly
 * initialized TextGraphics is fully init'ed.
 */
{
     return self;
}

- doInitFromData:(NSData *)data
/*
 * Common code for initFromData: and reinitFromData:.
 * Looks at the first 5 characters of the data and if it
 * looks like an RTF file, then the contents of the stream
 * are parsed as RTF, otherwise, the contents of the stream
 * are assumed to be ASCII text and is passed through the
 * drawText object and turned into RTF (using the method
 * (writeRichText:).
 */
{
    if (data) {
	if (!strncmp([data bytes], "{\\rtf", 5)) {
	    [self setRichTextData:data];
	    [drawText replaceCharactersInRange:(NSRange){0, [[drawText string] length]} withRTF:data];
	} else {
	    [drawText selectAll:self];
	    [drawText setFont:[NSFont userFontOfSize:-1.0]];
	    [drawText setString:[NSString stringWithCString:[data bytes] length:[data length]]];
	    [self setRichTextData:[drawText RTFFromRange:(NSRange){0, [[drawText string] length]}]];
	}
	[drawText setSelectedRange:(NSRange){0,0}];
	font = [drawText font];
    }

    return self;
}

- (id)initFromData:(NSData *)data
/*
 * Initializes the TextGraphic using data from the passed data.
 */
{
    [self init];

    if (data) {
	[self doInitFromData:data];
	[drawText setHorizontallyResizable:YES];
	[drawText setVerticallyResizable:YES];
	bounds.size.width = bounds.size.height = 10000.0;
	[drawText setMaxSize:bounds.size];
	[drawText sizeToFit];
	bounds.size = [drawText bounds].size;
	bounds.origin.x = bounds.origin.y = 0.0;
    }

    return [self finishedWithInit];
}

- (id)initFromFile:(NSString *)file
/*
 * Initializes the TextGraphic using data from the passed file.
 */
{
    return [self initFromData:[NSData dataWithContentsOfMappedFile:file]];
}


- (id)initWithPasteboard:(NSPasteboard *)pboard
/*
 * Initializes the TextGraphic using data from the passed Pasteboard.
 */
{
    if (IncludesType([pboard types], NSRTFPboardType)) {
	return [self initFromData:[pboard dataForType:NSRTFPboardType]];
    } else if (IncludesType([pboard types], NSStringPboardType)) {
	return [self initFromData:[pboard dataForType:NSStringPboardType]];
    } else {
	[self release];
	return nil;
    }
}

- (NSRect)reinitFromData:(NSData *)data
/*
 * Reinitializes the TextGraphic from the data in the passed data.
 */
{
    [self doInitFromData:data];
    return [self extendedBounds];
}

- (NSRect)reinitFromFile:(NSString *)file
/*
 * Reinitializes the TextGraphic from the data in the passed file.
 */
{
    [self doInitFromData:[NSData dataWithContentsOfMappedFile:file]];
    return [self extendedBounds];
}

- (NSRect)reinitWithPasteboard:(NSPasteboard *)pboard
/*
 * Reinitializes the TextGraphic from the data in the passed Pasteboard.
 */
{
    NSRect ebounds;

    if (IncludesType([pboard types], NSRTFPboardType)) {
	[self doInitFromData:[pboard dataForType:NSRTFPboardType]];
	ebounds = [self extendedBounds];
    } else if (IncludesType([pboard types], NSStringPboardType)) {
	[self doInitFromData:[pboard dataForType:NSStringPboardType]];
	ebounds = [self extendedBounds];
    } else {
	ebounds.origin.x = ebounds.origin.y = 0.0;
	ebounds.size.width = ebounds.size.height = 0.0;
    }

    return ebounds;
}

- (void)dealloc
{
    [richTextData release];
    [super dealloc];
}

/* Link methods */

- (void)setLink:(NSDataLink *)aLink
/*
 * Note that we "might" be linked because even though we obviously
 * ARE linked now, that might change in the future and the mightBeLinked
 * flag is only advisory and is never cleared.  This is because during
 * cutting and pasting, the TextGraphic might be linked, then unlinked,
 * then linked, then unlinked and we have to know to keep trying to
 * reestablish the link.  See readLinkForGraphic:... in gvLinks.m.
 */
{
    link = [aLink retain];
    gFlags.mightBeLinked = YES;
}

- (NSDataLink *)link
{
    return link;
}

/* Form entry methods. */

/*
 * Form Entries are essentially text items whose location, font, etc., are
 * written out separately in an ASCII file when a Draw document is saved.
 * When this is done, an EPS image of the Draw view is also written out
 * (both of these files are place along with the document in the file package).
 * These ASCII descriptions can then be used by other applications to overlay
 * fields on top of a background of what is created by Draw.
 *
 * The most notable client of this right now is the Fax stuff.
 */

- initFormEntry:(NSString *)entryName localizable:(BOOL)isLocalizable
/*
 * The localizeFormEntry stuff is used by the Fax stuff in the following manner:
 * If a form entry is localizable, then it appears in Draw in whatever the local
 * language is, but, when written to the ASCII form.info file, it is written out
 * not-localized.  Then, when the entity that reads the form.info file reads it,
 * it is responsible for localizing it.  This enables the entity reading the
 * form to actually semantically understand what a given form entry is (e.g. it
 * is the To: field in a Fax Cover Sheet).
 */ 
{
    [self init];
    gFlags.isFormEntry = YES;
    gFlags.localizeFormEntry = isLocalizable ? YES : NO;
    bounds.size.width = 300.0;
    bounds.size.height = 30.0;
    [drawText setString:entryName];
    [drawText setSelectedRange:(NSRange){0, [[drawText string] length]}];
    [drawText setTextColor:[NSColor blackColor] range:[drawText selectedRange]];
    [drawText setFont:[NSFont userFontOfSize:24.0]];
    [drawText setHorizontallyResizable:YES];
    [drawText setVerticallyResizable:YES];
    bounds.size.width = bounds.size.height = 10000.0;
    [drawText setMaxSize:bounds.size];
    [drawText sizeToFit];
    bounds.size = [drawText bounds].size;
    bounds.origin.x = bounds.origin.y = 0.0;
    bounds.size.width = 300.0;
    [self setRichTextData:[drawText RTFFromRange:(NSRange){0, [[drawText string] length]}]];
    return [self finishedWithInit];
}
   
#define LOCAL_FORM_ENTRY(s) NSLocalizedStringFromTable(s, @"CoverSheet", nil)

- prepareFormEntry
/*
 * Loads up the drawText with all the right attributes to
 * display a form entry.  Called from draw.
 */
{
    float width, height;
    NSString *formText;
    int crLocation;
    
    [drawText setTextColor:[NSColor lightGrayColor]];
    [drawText setFont:[drawText font]];
    [drawText setAlignment:NSLeftTextAlignment];
    formText = [[drawText string] substringWithRange:(NSRange){0, [[drawText string] length]}];
    if (((crLocation = [formText rangeOfString:@"\n"].location) != NSNotFound) || gFlags.localizeFormEntry) {
	if (crLocation != NSNotFound) {
	    // Then only use string up to carriage return...
	    formText = [formText substringToIndex:crLocation];
	}
	if (gFlags.localizeFormEntry) {
	    [drawText setString:LOCAL_FORM_ENTRY(formText)];
	} else {
	    [drawText setString:formText];
	}
    }
    [drawText setHorizontallyResizable:YES];
    [drawText setVerticallyResizable:YES];
    [drawText setMaxSize:bounds.size];
    [drawText sizeToFit];
    width = [drawText bounds].size.width;
    height = [drawText bounds].size.height;
    if (width > bounds.size.width) width = bounds.size.width;
    if (height > bounds.size.height) height = bounds.size.height;
    [drawText setFrameSize:(NSSize){ width, height }];
    [drawText setFrameOrigin:(NSPoint){ bounds.origin.x+floor((bounds.size.width-width)/2.0), bounds.origin.y+floor((bounds.size.height-height)/2.0) }];

    return self;
}

- (BOOL)isFormEntry
{
    return gFlags.isFormEntry;
}

- (void)setFormEntry:(int)flag
{
    gFlags.isFormEntry = flag ? YES : NO; 
}

- (NSFont *)getFormEntry:(NSString **)stringPointer andColor:(NSColor **)color
/*
 * Gets the information which will be written out into the
 * form.info ASCII form entry description file.  Specifically,
 * it gets the color value, the actual name of the entry, and
 * the Font of the entry.
 */
{
    int crLocation;
    NSString *formText;

    if (gFlags.isFormEntry) {
	[drawText replaceCharactersInRange:(NSRange){0, [[drawText string] length]} withRTF:richTextData];
	[drawText setSelectedRange:(NSRange){0,0}];
        if (color) {
            if ([drawText respondsToSelector:@selector(selColor)]) {
                // Old text object...
                *color = [(id)drawText selColor];
            } else {
                *color = [drawText textColor];
            }
        }
	formText = [[drawText string] substringWithRange:(NSRange){0, [[drawText string] length]}];
	if ((crLocation = [formText rangeOfString:@"\n"].location) != NSNotFound) {
	    // Then only use string up to carriage return...
	    formText = [formText substringToIndex:crLocation];
	}
	*stringPointer = formText;
	return [drawText font];
    }

    return nil;
}

- (BOOL)writeFormEntryToMutableString:(NSMutableString *)string
/*
 * Writes out the ASCII representation of the location, color,
 * etc., of this form entry.  This is called only during
 * the saving of a Draw document.
 *
 * We MUST write the same format as always because this file is used by the fax
 * system and we don't really need/want two different formats.  Also, it would
 * be nice if we could have forward compatibility such that cover sheets created
 * in 4.0 can be user in 3.x.
 */
{
    NSFont *myFont = nil;
    NSColor *color = nil;
    NSString *formText = nil;
    NSColor *convertedColor;
    float whiteness;

    if ((myFont = [self getFormEntry:&formText andColor:&color])) {
        [string appendFormat:@"Entry: %@\n", formText];
        [string appendFormat:@"Font: %@\n", [myFont fontName]];
        [string appendFormat:@"Font Size: %f\n", [myFont pointSize]];
        convertedColor = [color colorUsingColorSpaceName:NSCalibratedWhiteColorSpace];
        if (convertedColor) {
            whiteness = [convertedColor whiteComponent];
        } else {
            whiteness = 0.0;
        }
        [string appendFormat:@"Text Gray: %f\n", whiteness];
        [string appendFormat:@"Location: x = %d, y = %d, w = %d, h = %d\n",
	    (int)bounds.origin.x, (int)bounds.origin.y, (int)bounds.size.width, (int)bounds.size.height];
	return YES;
    }

    return NO;
}

/* Factory methods overridden from superclass */

+ (BOOL)isEditable
{
    return YES;
}

+ (NSCursor *)cursor
{
    return [NSCursor IBeamCursor];
}

/* Instance methods overridden from superclass */

- (NSString *)title
{
    return TEXT_OP;
}

- (BOOL)create:(NSEvent *)event in:(GraphicView *)view
 /*
  * We are only interested in where the mouse goes up, that's
  * where we'll start editing.
  */
{
    NSRect viewBounds;

    event = [[view window] nextEventMatchingMask:NSLeftMouseUpMask];
    bounds.size.width = bounds.size.height = 0.0;
    bounds.origin = [event locationInWindow];
    bounds.origin = [view convertPoint:bounds.origin fromView:nil];
    viewBounds = [view bounds];
    gFlags.selected = NO;

    return NSMouseInRect(bounds.origin, viewBounds, NO);
}

- (BOOL)edit:(NSEvent *)event in:(NSView *)view
{
    id change;

    if (gFlags.isFormEntry && gFlags.localizeFormEntry) return NO;
    if ([self link]) return NO;

    editView = view;
    graphicView = (GraphicView *)[editView superview];
    
    /* Get the field editor in this window. */

    if (gFlags.isFormEntry) {
	gFlags.isFormEntry = NO;
        [(GraphicView *)[view superview] cache:[self extendedBounds]];	// gFlags.isFormEntry starts editing
	[[view window] flushWindow];
	gFlags.isFormEntry = YES;
    }

    change = [[StartEditingGraphicsChange alloc] initGraphic:self];
    [change startChange];
	[self prepareFieldEditor];
	if (event) {  
	    [fe setSelectedRange:NSMakeRange(0, 0)];	/* eliminates any existing selection */
	    [fe mouseDown:event]; /* Pass the event on to the Text object */
	}
    [change endChange];

    return YES;
}

- draw
 /*
  * If the region has already been created, then we must draw the text.
  * To do this, we first load up the shared drawText Text object with
  * our rich text.  We then set the frame of the drawText object
  * to be our bounds.  Finally, we add the Text object as a subview of
  * the view that is currently being drawn in ([NSApp focusView])
  * and tell the Text object to draw itself.  We then remove the Text
  * object view from the view heirarchy.
  */
{
    if (!fe && richTextData && (!gFlags.isFormEntry || [(NSDPSContext *)[NSDPSContext currentContext] isDrawingToScreen])) {
	[drawText replaceCharactersInRange:(NSRange){0, [[drawText string] length]} withRTF:richTextData];
	if (gFlags.isFormEntry) {
	    [self prepareFormEntry];
	} else {
	    [drawText setFrame:bounds];
	}
        [[graphicView window] setAutodisplay:NO]; // don't let addSubview: cause redisplay
	[[NSView focusView] addSubview:drawText];
        [drawText lockFocus];
        [drawText drawRect:[drawText bounds]];
        [drawText unlockFocus];
	[drawText removeFromSuperview];
        [[graphicView window] setAutodisplay:YES];
	if (DrawStatus == Resizing || gFlags.isFormEntry) {
	    PSsetgray(NSLightGray);
	    NSFrameRect(bounds);
	}
    }

    return self;
}

#if TEXT_UNDO_ENABLED
// This version of performTextMethod: is used when text undo is supported.
- (void)performTextMethod:(SEL)aSelector with:(void *)anArgument
/*
 * This performs the given aSelector on the text by loading up
 * a Text object and applying aSelector to it (with selectAll:
 * having been done first).  See PerformTextGraphicsChange.m
 * in graphicsUndo.subproj.
 */
{
    id change;

    if (richTextData) {
	change = [PerformTextGraphicsChange alloc];
	[change initGraphic:self view:graphicView];
	[change startChangeIn:graphicView];
	    [change loadGraphic];
	    [[change editText] performSelector:aSelector withObject:anArgument];
	    [change unloadGraphic];
	[change endChange];
    } 
}
#else
- (void)performTextMethod:(SEL)aSelector with:(void *)anArgument
/*
 * This performs the given aSelector on the text by loading up
 * a Text object and applying aSelector to it (with selectAll:
 * having been done first).
 */
{
    static id tempText = nil;
    static id tempWindow = nil;
    
    if (richTextData)  {
	NSRect graphicBounds;
	
	// Equivalent to [change initGraphic:self inView graphicView] above.
	if (!tempText)  {
	    tempText = [[DrawSpellText alloc] initWithFrame:(NSRect){{0,0},{0,0}}];
	    [tempText setRichText:YES];
	}
	if (!tempWindow)  {
	    tempWindow = [[NSWindow alloc] init];
	}
	
	// Equivalent to [change loadGraphic] above.
	[tempText replaceCharactersInRange:(NSRange){0, [[tempText string] length]} withRTF:richTextData];
	graphicBounds = [self bounds];
	[tempText setFrame:graphicBounds];
	[tempWindow setNextResponder:graphicView];
	[[tempWindow contentView] addSubview:tempText];
	[tempText selectAll:self];
	
	[tempText performSelector:aSelector withObject:anArgument];
	
	// Equivalent to [change unloadGraphic] above.
	[tempWindow setNextResponder:nil];
	[tempText removeFromSuperview];
	[tempText setSelectedRange:(NSRange){0,0}];
	[self setFont:[tempText font]];
	[self setRichTextData:[tempText RTFFromRange:(NSRange){0, [[tempText string] length]}]];
    } 
}
#endif

- (void)setFont:(NSFont *)aFont
{
    font = aFont;
}

- (NSData *)richTextData
{
    return richTextData;
}

- (void)setRichTextData:(NSData *)data
{
    if (richTextData) [richTextData autorelease];
    richTextData = [data copy];
}

- (void)changeFont:(id)sender
{
    [self performTextMethod:@selector(changeFont:) with:sender];
}

- (NSFont *)font
{
    if (!font && richTextData) {
	[drawText replaceCharactersInRange:(NSRange){0, [[drawText string] length]} withRTF:richTextData];
	[drawText setSelectedRange:(NSRange){0,0}];
	font = [drawText font];
    }

    return font;
}

- (BOOL)isOpaque
/*
 * We are never opaque.
 */
{
    return NO;
}

- (BOOL)isValid
/*
 * Any size TextGraphic is valid (since we fix up the size if it is
 * too small in our override of create:in:).
 */
{
    return YES;
}

- (NSColor *)lineColor
{
    return [NSColor blackColor];
}

- (NSColor *)fillColor
{
    return [NSColor whiteColor];
}

- (float)baseline
{
    float ascender, descender, lineHeight;

    if (!font) [self font];
    if (font) {
	// This function is defined in the old NSCStringText class,
	// but it doesn't actually have anything to do with the text object.
	// It uses only the font info.
	NSTextFontInfo(font, &ascender, &descender, &lineHeight);
	return bounds.origin.y + bounds.size.height + ascender;
    }

    return 0;
}

- (void)moveBaselineTo:(const float *)y
{
    float ascender, descender, lineHeight;

    if (y && !font) [self font];
    if (y && font) {
        // This function is defined in the old NSCStringText class,
        // but it doesn't actually have anything to do with the text object.
        // It uses only the font info.
	NSTextFontInfo(font, &ascender, &descender, &lineHeight);
	bounds.origin.y = *y - ascender - bounds.size.height;
    } 
}

- (void)updateEditingViewRect:(NSRect)updateRect
{
    updateRect = [graphicView convertRect:updateRect fromView:editView];
    [graphicView lockFocus];
    [graphicView drawRect:updateRect];
    [graphicView unlockFocus];
    [[graphicView window] flushWindow];
}

- (void)editorFrameChanged:(NSNotification *)arg
{
    NSRect currentEditingFrame = [[arg object] frame];
    if (!NSEqualRects(lastEditingFrame, NSZeroRect)) {
        if (lastEditingFrame.size.width > currentEditingFrame.size.width) {
            NSRect updateRect = lastEditingFrame;
            updateRect.origin.x = currentEditingFrame.origin.x + currentEditingFrame.size.width;
            [self updateEditingViewRect:updateRect];
        }
        if (lastEditingFrame.size.height > currentEditingFrame.size.height) {
            NSRect updateRect = lastEditingFrame;
            updateRect.origin.y = currentEditingFrame.origin.y + currentEditingFrame.size.height;
            [self updateEditingViewRect:updateRect];
        }
    }
    lastEditingFrame = currentEditingFrame;
}

/* Public methods */

- (void)prepareFieldEditor
/*
 * Here we are going to use the shared field editor for the window to
 * edit the text in the TextGraphic.  First, we must end any other editing
 * that is going on with the field editor in this window using endEditingFor:.
 * Next, we get the field editor from the window.  Normally, the field
 * editor ends editing when carriage return is pressed.  This is due to
 * the fact that its character filter is NSFieldFilter.  Since we want our
 * editing to be more like an editor (and less like a Form or TextField),
 * we set the character filter to be NSEditorFilter.  What is more, normally,
 * you can't change the font of a TextField or Form with the FontPanel
 * (since that might interfere with any real editable Text objects), but
 * in our case, we do want to be able to do that.  We also want to be
 * able to edit rich text, so we issue a setMonoFont:NO.  Editing is a bit
 * more efficient if we set the Text object to be opaque.  Note that
 * in textDidEnd:endChar: we will have to set the character filter,
 * FontPanelEnabled and mono-font back so that if there were any forms
 * or TextFields in the window, they would have a correctly configured
 * field editor.
 *
 * To let the field editor know exactly where editing is occurring and how
 * large the editable area may grow to, we must calculate and set the frame
 * of the field editor as well as its minimum and maximum size.
 *
 * We load up the field editor with our rich text (if any).
 *
 * Finally, we set self as the delegate (so that it will receive the
 * textDidEnd:endChar: message when editing is completed) and either
 * pass the mouse-down event onto the Text object, or, if a mouse-down
 * didn't cause editing to occur (i.e. we just created it), then we
 * simply put the blinking caret at the beginning of the editable area.
 *
 * The line marked with the "ack!" is kind of strange, but is necessary
 * since growable Text objects only work when they are subviews of a flipped
 * view.
 *
 * This is why GraphicView has an "editView" which is a flipped view that it
 * inserts as a subview of itself for the purposes of providing a superview
 * for the Text object.  The "ack!" line converts the bounds of the TextGraphic
 * (which are in GraphicView coordinates) to the coordinates of the Text
 * object's superview (the editView).  This limitation of the Text object
 * will be fixed post-1.0.  Note that the "ack!" line is the only one
 * concession we need to make to this limitation in this method (there is
 * another such line in resignFieldEditor).
 */
{
    NSSize maxSize, containerSize;
    NSRect viewBounds, frame;

    [NSApp sendAction:@selector(disableChanges:) to:nil from:self];
	[[graphicView window] endEditingFor:self];
	fe = (NSTextView *)[[graphicView window] fieldEditor:YES forObject:self];
	
	if ([self isSelected]) {
	    [self deselect];
	    [graphicView cache:[self extendedBounds] andUpdateLinks:NO];
	    [[graphicView selectedGraphics] removeObject:self];
	}
	
	[fe setFont:[[NSFontManager sharedFontManager] selectedFont]];
    
	/* Modify it so that it will edit Rich Text and use the FontPanel. */
    
	[fe setFieldEditor:NO];
	[fe setUsesFontPanel:YES];
	[fe setRichText:YES];
	[fe setDrawsBackground:NO];
    
	/*
	    * Determine the minimum and maximum size that the Text object can be.
	    * We let the Text object grow out to the edges of the GraphicView,
	    * but no further.
	    */
    
	viewBounds = [editView bounds];
	maxSize.width = viewBounds.origin.x+viewBounds.size.width- bounds.origin.x;
	maxSize.height = bounds.origin.y+bounds.size.height- viewBounds.origin.y;
	if (!bounds.size.height && !bounds.size.width) {
	    // These calls to pointSize in NSFont used to be calls to lineHeight in NSCStringText which was more accurate.
	    bounds.origin.y -= floor([[fe font] pointSize] / 2.0);
	    bounds.size.height = [[fe font] pointSize];
	    bounds.size.width = 5.0;
	}
	frame = bounds;
	frame = [editView convertRect:frame fromView:graphicView];	// ack!
	[fe setMinSize:bounds.size];
	[fe setMaxSize:maxSize];
	[fe setFrame:frame];
        [fe setVerticallyResizable:YES];
        lastEditingFrame = NSZeroRect;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(editorFrameChanged:) name:NSViewFrameDidChangeNotification object:fe];
    
	/*
	* If we already have text, then put it in the Text object (allowing
        * the Text object to grow downward if necessary), otherwise, put
	* no text in, set some initial parameters, and allow the Text object
	* to grow horizontally as well as vertically
        */
    
	if (richTextData) {
	    [fe setHorizontallyResizable:NO];
            [[fe textContainer] setWidthTracksTextView:YES];
            containerSize.width = bounds.size.width;
            containerSize.height = [[fe textContainer] containerSize].height;
            [[fe textContainer] setContainerSize:containerSize];
	    [fe replaceCharactersInRange:(NSRange){0, [[fe string] length]} withRTF:richTextData];
	} else {
	    [fe setHorizontallyResizable:YES];
            [[fe textContainer] setWidthTracksTextView:NO];
            containerSize.width = NSMaxX(viewBounds) - bounds.origin.x;
            containerSize.height = [[fe textContainer] containerSize].height;
            [[fe textContainer] setContainerSize:containerSize];
	    [fe setString:@""];
	    [fe setAlignment:NSLeftTextAlignment];
	    [fe setTextColor:[NSColor blackColor] range:[fe selectedRange]];
	    [fe unscript:self];
	}
    
	/*
	    * Add the Text object to the view heirarchy and set self as its delegate
	    * so that we will receive the textDidEnd:endChar: message when editing
	    * is finished.
	    */
    
	[fe setDelegate:self];
	[editView addSubview:fe];
    
	/*
	 * Make it the first responder.
	 */
    
	[[graphicView window] makeFirstResponder:fe];
    
	/* Change the ruler to be a text ruler. */
    
	[fe tryToPerform:@selector(showTextRuler:) with:fe];

	[fe setSelectedRange:(NSRange){0,0}];

        [graphicView cache:bounds];
    [NSApp sendAction:@selector(enableChanges:) to:nil from:self]; 
}

- (void)resignFieldEditor
/* 
 * We must extract the rich text the user has typed from the Text object,
 * and store it away. We also need to get the frame of the Text object
 * and make that our bounds (but, remember, since the Text object must
 * be a subview of a flipped view, we need to convert the bounds rectangle
 * to the coordinates of the unflipped GraphicView).  If the Text object
 * is empty, then we remove this TextGraphic from the GraphicView.
 * We must remove the Text object from the view heirarchy and, since
 * this Text object is going to be reused, we must set its delegate
 * back to nil.
 *
 * For further explanation of the "ack!" line, see edit:in: above.
 */
{
    NSRect redrawRect;
    int len;

    if (fe) {
        [NSApp sendAction:@selector(disableChanges:) to:nil from:self];
            if (richTextData) {
                [richTextData release];
                richTextData = NULL;
            }

            NSAssert1(editView == [fe superview], @"%@", "Fault in Text Graphic: Code 2");
            NSAssert1(graphicView == (GraphicView *)[editView superview], @"%@", "Fault in Text Graphic: Code 3");

            redrawRect = bounds;
            if ((len = [[fe string] length]) != 0) {
                [self setRichTextData: [fe RTFFromRange:(NSRange){0, len}]];
                bounds = [fe frame];
                bounds = [editView convertRect:bounds toView:graphicView];	// ack!
                redrawRect = NSUnionRect(bounds, redrawRect);
            }

            [[graphicView window] disableFlushWindow];
            [graphicView tryToPerform:@selector(hideRuler:) with:nil];
            [fe removeFromSuperview];
            [[NSNotificationCenter defaultCenter] removeObserver:self name:NSViewFrameDidChangeNotification object:fe];
            [fe setDelegate:nil];
            [fe setSelectedRange:(NSRange){0, 0}];
            font = [fe font];
            fe = nil;
            [graphicView cache:redrawRect];
            [[graphicView window] enableFlushWindow];
            [[graphicView window] flushWindow];
        [NSApp sendAction:@selector(enableChanges:) to:nil from:self];
    }
}

- (BOOL)isEmpty
{
    return richTextData ? NO : YES;
}

/* Text object delegate methods */

- (void)textDidEndEditing:(NSNotification *)notification
/*
 * This method is called when ever first responder is taken away from a
 * currently editing TextGraphic (i.e. when the user is done editing and
 * chooses to go do something else).  
 */
{
    id change;
    NSTextView *textObject = [notification object];

    NSAssert(fe == textObject, @"Fault in Text Graphic: Code 1");
    change = [[EndEditingGraphicsChange alloc] initGraphicView:graphicView  graphic:self];
    [change startChange];
        [self resignFieldEditor];
	if ([self isEmpty]) [graphicView removeGraphic:self];
    [change endChange];
}

/* Archiving methods */

#define RICH_TEXT_KEY @"TheText"

- (id)propertyList
{
    NSMutableDictionary *plist = [super propertyList];
    [plist setObject:richTextData forKey:RICH_TEXT_KEY];
    return plist;
}

- (NSString *)description
{
    return [(NSObject *)[self propertyList] description];
}

- initFromPropertyList:(id)plist inDirectory:(NSString *)directory
{
    [super initFromPropertyList:plist inDirectory:directory];
    richTextData = [[plist objectForKey:RICH_TEXT_KEY] retain];
    [[self class] initClassVars];
    return self;
}

@end
