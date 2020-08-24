/* VText.m
 * 2-D Text object
 *
 * Copyright (C) 1996-2012 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1996-02-15
 * modified: 2012-02-28 (-drawWithPrincipal: set frame twice to make mirrored text visible)
 *           2012-01-04 (-textDidEndEditing: if locked, we don't adjust the size of the text box)
 *           2010-07-29 (-drawWithPrincipal:...) move -setTextContainerInset: before -setFrame to make mirror on Apple visible
 *           2010-07-28 (+valueForKey:inArray:) new
 *           2009-12-29 (-drawWithPrincipal:): for GNUstep renew drawText after rotAngle
 *           2009-02-12 (-textDidEndEditing: add correction to height to make text appear safely on Apple)
 *           2009-02-11 (-getFlattenedObjectAt: set yOffset for mirrored text)
 *           2009-01-27 (-textDidEndEditing: remove empty text)
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the vhf Public License as
 * published by vhf interservice GmbH. Among other things, the
 * License requires that the copyright notices and this notice
 * be preserved on all copies.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the vhf Public License for more details.
 *
 * You should have received a copy of the vhf Public License along
 * with this program; see the file LICENSE. If not, write to vhf.
 *
 * vhf interservice GmbH, Im Marxle 3, 72119 Altingen, Germany
 * eMail: info@vhf.de
 * http://www.vhf.de
 */

#include <AppKit/AppKit.h>
#include <math.h>
#include "VText.h"
#include "../App.h"
#include "../DocView.h"
#include "../Document.h"
#include "../DocWindow.h"	// getFlattenedObject
#include "../PSImportSub.h"
#include "../FlippedView.h"
#include "../graphicsUndo.subproj/undo.h"

static NSTextView	*drawText = nil;	// shared Text object used for drawing
//static NSString	*fontListNoFill;	// list of fonts which shouldn't be filled
//static BOOL 		displayModeFilled = YES;

//#define FONTLIST_NAME	@"FontListNoFill"

@interface VText(PrivateMethods)
- (void)setParameter;
- (void)makeMutableAttributedString;
@end

@implementation VText

/*
 * Create the class variable drawText here.
 */
static void initClassVars()
{
    if (!drawText)
    {	drawText = [[NSTextView alloc] init];
        [[drawText textContainer] setWidthTracksTextView:YES];
        [[drawText textContainer] setHeightTracksTextView:YES];
        [drawText setHorizontallyResizable:NO];
        [drawText setVerticallyResizable:NO];
        [drawText setDrawsBackground:NO];
        [drawText setRichText:YES];
#ifndef GNUSTEP_BASE_VERSION		// workaround: GNUstep needs this enabled for some reason !
        [drawText setEditable:NO];
        [drawText setSelectable:NO];
#endif
        [drawText setMinSize:NSMakeSize(0.1, 0.1)];
        [drawText setMaxSize:NSMakeSize(LARGE_COORD, LARGE_COORD)];
        [drawText setFrameRotation:0.0];
/*	[drawText setDrawFunc:drawTextFun];*/
        [drawText setTextContainerInset:NSMakeSize(0.0, 0.0)];
        [[drawText textContainer] setLineFragmentPadding:0.0];
    }
}

+ (VText*)textGraphic
{
    return [[VText new] autorelease];
}

+ (NSTextView*)sharedText
{
    return drawText;
}

/*
 * This sets the class version so that we can compatibly read
 * old VGraphic objects out of an archive.
 */
+ (void)initialize
{   //NSString	*path;

    [VText setVersion:8];

    /* load font list of font which we should not fill */
    /*
     path = [userLibrary() stringByAppendingString:FONTLIST_NAME];
     if ( [[NSFileManager defaultManager] fileExistsAtPath:path] )
         fontListNoFill = [[NSString alloc] initWithContentsOfFile:path];
     else
     {   path = [localLibrary() stringByAppendingString:FONTLIST_NAME];
         if ( [[NSFileManager defaultManager] fileExistsAtPath:path] )
             fontListNoFill = [[NSString alloc] initWithContentsOfFile:path];
         else
         {   path = [[[NSBundle mainBundle] resourcePath]
                     stringByAppendingPathComponent:FONTLIST_NAME];
             fontListNoFill = [[NSString alloc] initWithContentsOfFile:path];
         }
     }*/

    return;
}

/* search given array of Graphics objects
 * and return the substring (value) of a text with a given key
 * ex: "#KEY#Returned String"
 * created: 2010-07-28
 */
+ (NSString*)valueForKey:(NSString*)key inArray:(NSArray*)array
{   int i, cnt = [array count];

    for ( i=0; i<cnt; i++ )
    {   VText   *g = [array objectAtIndex:i];

        if ( [g isKindOfClass:[VText class]] )
        {   NSString    *string = [g string];

            if ( [string hasPrefix:key] )
                return [string substringFromIndex:[key length]];
        }
    }
    return nil;
}

- (void)renewSharedText
{
    [[drawText textContainer] setWidthTracksTextView:YES];
    [[drawText textContainer] setHeightTracksTextView:YES];
    [drawText setDrawsBackground:NO];
    [drawText setRichText:YES];
#ifndef GNUSTEP_BASE_VERSION		// workaround: GNUstep needs this enabled for some reason !
    [drawText setEditable:NO];
    [drawText setSelectable:NO];
#endif
    [drawText setMinSize:NSMakeSize(0.1, 0.1)];
    [drawText setMaxSize:NSMakeSize(LARGE_COORD, LARGE_COORD)];
    [drawText setHorizontallyResizable:NO];
    [drawText setVerticallyResizable:NO];
    [drawText setFrameRotation:0.0];
    //[drawText setMarginLeft:0.0 right:0.0 top:0.0 bottom:0.0];
#ifdef __APPLE__	// workaround: crash in [NSText -replaceCharacters...]
    [[drawText textStorage] deleteCharactersInRange:NSMakeRange(0, [[drawText textStorage] length])];
#endif
}

- (void)updateDrawText
{   NSTextStorage	*ts = [drawText textStorage];

    [ts beginEditing];
    [ts setAttributedString:attributedString];
    [ts endEditing];
}

/* initialize
 */
- init
{
    [self setParameter];
    aspectRatio = 1.0;
    fillColor = [[NSColor blackColor] retain];
    endColor = [[NSColor blackColor] retain];
    graduateAngle = 0.0;
    stepWidth = 7.0;
    radialCenter = NSMakePoint(0.5, 0.5);
    //lineHeight = [[drawText font] pointSize];
    return [super init];
}

/*
 * created: 25.09.95
 * purpose: initializes all the stuff needed after a -read:
 */
- (void)setParameter
{
    initClassVars();
    filled = YES;
}

- (NSString*)description
{
    return [NSString stringWithFormat:@"VText: bounds=%f %f %f %f string=%@ angle=%f serial=%d fitHoricontal=%d centerVertical=%d",
            bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height, [self string], rotAngle, isSerialNumber, fitHorizontal, centerVertical];
}

- (NSString*)title
{
    return @"Text";
}

- (BOOL)filled			{ return filled; }
- (void)setFilled:(BOOL)flag	{ filled = flag; dirty = YES; }

/* modified: 2005-06-10
 */
- (void)setColor:(NSColor *)col
{
    [self setFillColor:col];
}

/* modified: 2005-06-10
 */
- (void)setFillColor:(NSColor*)col
{
    if (attributedString)
    {   NSTextStorage	*ts = [drawText textStorage];

        [ts beginEditing];
        [ts setAttributedString:attributedString];
        [ts endEditing];
        [drawText setTextColor:col];
        [drawText setFrame:bounds];
        [self setAttributedString:[ts attributedSubstringFromRange:NSMakeRange(0, [ts length])]];
    }
    [super setColor:col];
    if (fillColor) [fillColor release];
    fillColor = [col retain];
    dirty = YES;
}
- (NSColor*)fillColor { return fillColor; }

- (void)setEndColor:(NSColor*)col
{
    if (endColor) [endColor release];
    endColor = [col retain];
    dirty = YES;
}
- (NSColor*)endColor { return endColor; }

- (void)setGraduateAngle:(float)a	{ graduateAngle = a; dirty = YES; }
- (float)graduateAngle			{ return graduateAngle; }

- (void)setRadialCenter:(NSPoint)rc	{ radialCenter = rc; dirty = YES; }
- (NSPoint)radialCenter			{ return radialCenter; }

- (void)setStepWidth:(float)sw	{ stepWidth = sw; dirty = YES; }
- (float)stepWidth		{ return stepWidth; }

- (void)setTextPath:tPath	{ textPath = tPath; }

- (NSString*)string
{
    return [attributedString string];
}
- (void)setString:(NSString *)s
{
    [self setString:s lineHeight:0.0];
}
- (void)setString:(NSString *)s lineHeight:(float)lineHeight
{   NSTextStorage	*ts = [drawText textStorage];

    if (!s)
        return;

    [self renewSharedText];
//    bounds.size = [(View*)[VGraphic currentView] bounds].size;
    bounds.size.width = bounds.size.height = 1000.0;
    [drawText setFrame:bounds];
    [[drawText textContainer] setWidthTracksTextView:NO];
    [[drawText textContainer] setHeightTracksTextView:NO];
    [drawText setHorizontallyResizable:YES];
    [drawText setVerticallyResizable:YES];
    [ts beginEditing];
    if (attributedString)
        [ts setAttributedString:attributedString];
    [ts endEditing];
    [drawText setAlignment:NSLeftTextAlignment];
    [drawText setString:s];
    if (font)
    {   NSMutableParagraphStyle	*paraStyle;

        [drawText setFont:font];
        if (!lineHeight)
            lineHeight = [font pointSize] - [font descender];
        [drawText setFrameRotation:0.0];
        if ( ![ts length] )
            paraStyle = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
        else
            paraStyle = [[[[drawText textStorage] attribute:NSParagraphStyleAttributeName
                                                    atIndex:0 effectiveRange:NULL] mutableCopy] autorelease];
        [paraStyle setMinimumLineHeight:lineHeight];
        [paraStyle setMaximumLineHeight:lineHeight];
        if ( paraStyle )
            [ts addAttribute:NSParagraphStyleAttributeName
                       value:paraStyle
                       range:NSMakeRange(0, [[drawText string] length])];
    }
    if (color)
        [drawText setTextColor:color];
    [drawText sizeToFit];	// collapses to zero for text larger bounds ???

    [self setAttributedString:[ts attributedSubstringFromRange:NSMakeRange(0, [ts length])]];
    [[drawText textContainer] setWidthTracksTextView:YES];
    [[drawText textContainer] setHeightTracksTextView:YES];
    [drawText setHorizontallyResizable:NO];
    [drawText setVerticallyResizable:NO];
    bounds.size = [drawText bounds].size;
}
- (void)setString:(NSString*)string font:(NSFont*)aFont color:(NSColor*)aColor
{
    [self setString:string font:aFont lineHeight:0.0 color:aColor];
}
- (void)setString:(NSString*)string font:(NSFont*)aFont lineHeight:(float)lineHeight color:(NSColor*)aColor
{
    if (aFont)
    {   [font release];
        font = [aFont retain];
    }
    if (aColor)
        [self setColor:aColor];	// 2005-06-10
    [self setString:string lineHeight:lineHeight];
    dirty = YES;
}

- (void)setAlignment:(NSTextAlignment)mode
{
    [self makeMutableAttributedString];
    [attributedString setAlignment:mode
                             range:NSMakeRange(0, [attributedString length])];
}

- (void)sizeToFit
{   BOOL h = [drawText isHorizontallyResizable], v = [drawText isVerticallyResizable];
    BOOL hc = [[drawText textContainer] widthTracksTextView],
         vc = [[drawText textContainer] heightTracksTextView];

    [self renewSharedText];	// important to remove possible frame rotation
    //[[drawText textContainer] setContainerSize:NSMakeSize(1000.0, 1000.0)];
    bounds.size.width = bounds.size.height = LARGE_COORD;
    [drawText setFrame:bounds];
    [[drawText textContainer] setWidthTracksTextView:NO];	// if != NO sizeToFit will collapse to 0
    [[drawText textContainer] setHeightTracksTextView:NO];	// must be placed behind setFrame !!!
    [drawText setHorizontallyResizable:YES];
    [drawText setVerticallyResizable:YES];
    [self updateDrawText];
    [drawText sizeToFit];
    bounds.size = [drawText bounds].size;
    bounds.size.width += 1.0;	// width is always a little too small
    bounds.size.height += 0.1;	// height is sometimes a little too small
    [[drawText textContainer] setWidthTracksTextView:hc];
    [[drawText textContainer] setHeightTracksTextView:vc];
    [drawText setHorizontallyResizable:h];
    [drawText setVerticallyResizable:v];
    dirty = YES;
}

- (void)replaceTextWithString:(NSString*)string
{
    if (string)
    {
        [self makeMutableAttributedString];
        [attributedString replaceCharactersInRange:NSMakeRange(0, [attributedString length])
                                        withString:string];
        if ( [self fitHorizontal] )
            [self kernToFitHorizontal];
    }
}
- (void)replaceCharactersInRange:(NSRange)range withString:(NSString*)string
{
    if (string)
    {
        [self makeMutableAttributedString];
        [attributedString replaceCharactersInRange:range withString:string];
        if ( [self fitHorizontal] )
            [self kernToFitHorizontal];
    }
}
/* created: 2005-09-01
 */
- (void)replaceSubstring:(NSString*)substring withString:(NSString*)string
{
    if (string)
    {   NSRange	range = [[attributedString string] rangeOfString:substring];

        if (range.length)
        {   [self makeMutableAttributedString];
            [attributedString replaceCharactersInRange:range withString:string];
            if ( [self fitHorizontal] )
                [self kernToFitHorizontal];
        }
    }
}

- (void)makeMutableAttributedString
{
    if ( ![attributedString isKindOfClass:[NSMutableAttributedString class]] )
        attributedString = [[attributedString autorelease] mutableCopy];
}
- (NSAttributedString*)attributedString
{
    return attributedString;
}
- (void)setAttributedString:(NSAttributedString*)as
{
    [attributedString release];
    attributedString = [as copy];	// 'retain' doesn't work with Apple
    dirty = YES;
}

- (NSData*)richTextData
{
    if (attributedString)
    {   NSTextStorage	*ts = [drawText textStorage];

        [ts beginEditing];
        [ts setAttributedString:attributedString];
        [ts endEditing];
        return [drawText RTFFromRange:NSMakeRange(0, [[drawText textStorage] length])];
    }
    return nil;
}
- (void)setRichTextData:(NSData*)data
{
    if (data)
    {   //NSTextStorage	*ts = [drawText textStorage];

        //[drawText replaceCharactersInRange:NSMakeRange(0, [ts length]) withRTF:data];
        //[self setAttributedString:[ts attributedSubstringFromRange:NSMakeRange(0, [ts length])]];

        [self setAttributedString:[[[NSAttributedString alloc] initWithRTF:data
                                                        documentAttributes:NULL] autorelease]];
    }
    else
        [self setAttributedString:[[NSAttributedString new] autorelease]];
}

/*
 * We are only interested in where the mouse goes up, that's
 * where we'll start editing.
 */
- (BOOL)create:(NSEvent *)event in:view
{   NSRect viewBounds;

    [self setColor:[NSColor blackColor]];
    event = [NSApp nextEventMatchingMask:NSLeftMouseUpMask untilDate:[NSDate distantFuture]
                                  inMode:NSEventTrackingRunLoopMode dequeue:YES];
    bounds.size.width = bounds.size.height = 0.0;
    bounds.origin = [event locationInWindow];
    bounds.origin = [view convertPoint:bounds.origin fromView:nil];
    bounds.origin = [view grid:bounds.origin];
    viewBounds = [view bounds];
    dirty = YES;

    /* Here we keep the frame of the editview always 100%, whatever happens */
    /*{   NSRect  editFrame = [editView frame], newFrame = [view frame];

        editView = [view editView];
        newFrame.size.width = NSWidth([view frame]) / [view scaleFactor];
        printf("editView = %.1f bounds = %.1f  newFrame = %.1f  scale = %.1f\n", editFrame.size.width, viewBounds.size.width, newFrame.size.width, [view scaleFactor]);
        if ( Diff(newFrame.size.width, editFrame.size.width) > 0.1 )
        {
            newFrame.size.height = NSHeight([view frame]) / [view scaleFactor];
            NSLog(@"Note for createText: editView corrected to view size {%.1f %.1f} -> {%.1f %.1f}",
                  editFrame.size.width, editFrame.size.height, newFrame.size.width, newFrame.size.height);
            [[view editView] setFrame:newFrame];
        }
    }*/

    return NSMouseInRect(bounds.origin, viewBounds, NO);
}

/*
 * modified: 2006-09-20 (scroll text to visible)
 *
 * Here we are going to use the shared field editor for the window to
 * edit the text in the VText.  First, we must end any other editing
 * that is going on with the field editor in this window using endEditingFor:.
 * Next, we get the field editor from the window.  Normally, the field
 * editor ends editing when carriage return is pressed.  This is due to
 * the fact that its character filter is NXFieldFilter.  Since we want our
 * editing to be more like an editor (and less like a Form or TextField),
 * we set the character filter to be NXEditorFilter.  What is more, normally,
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
 * for the Text object.  The "ack!" line converts the bounds of the VText
 * (which are in GraphicView coordinates) to the coordinates of the Text
 * object's superview (the editView).
 * Note that the "ack!" line is the only one concession we need to make to
 * this limitation in this method (there are two more acks in textDidEnd:endChar:).
 */
- (BOOL)edit:(NSEvent *)event in:view
{   NSSize		maxSize, containerSize;
    NSRect		viewBounds, frame;
    NSPoint		o;
    //NSColor		*col;
    //id		editView = view;
    NSTextView		*fe;
    NSTextStorage	*ts;

    editView = view;
    graphicView = [editView superview];

    /* Get the field editor in this window. */
    [[view window] endEditingFor:self];
    if ( !(fe = (NSTextView *)[[view window] fieldEditor:YES forObject:self]) )
        return NO;
    ts = [fe textStorage];

#if 0
    if ( [self isSelected] )
    {
        [self deselect];
        [view cache:[self extendedBoundsWithScale:[view scaleFactor]] andUpdateLinks:NO];
        [[view selectedGraphics] removeObject:self];
    }
#endif

    if ([[NSFontManager sharedFontManager] selectedFont])
        [fe setFont:[[NSFontManager sharedFontManager] selectedFont]];

    /* Modify it so that it will edit Rich Text and use the FontPanel. */
    [fe setFieldEditor:NO];
    [fe setUsesFontPanel:YES];
    [fe setRichText:YES];
    [fe setDrawsBackground:YES];

    //[fe setFrameRotation:360.0-rotAngle];
    [fe scaleUnitSquareToSize:NSMakeSize(1.0, aspectRatio)];

    if ([fe respondsToSelector:@selector(setTextContainerInset:)])	// not on GNUstep
    {
        [fe setTextContainerInset:NSMakeSize(0.0, 0.0)];
        [[fe textContainer] setLineFragmentPadding:0.0];
    }

    /* Determine the minimum and maximum size that the Text object can be.
     * We let the Text object grow out to the edges of the GraphicView,
     * but no further.
     */
    viewBounds = [editView bounds];
    maxSize.width = viewBounds.origin.x+viewBounds.size.width-bounds.origin.x;
    maxSize.height = bounds.origin.y+bounds.size.height-viewBounds.origin.y;
    if (!bounds.size.height && !bounds.size.width)
    {	bounds.origin.y -= floor([[fe font] pointSize]/ 2.0);
        bounds.size.height = [[fe font] pointSize];
        bounds.size.width = 5.0;
    }
    frame = bounds;
    o = bounds.origin;
    frame.origin.y += frame.size.height;
    vhfRotatePointAroundCenter(&frame.origin, o, rotAngle);
    frame.origin.y -= frame.size.height;

    frame = [editView convertRect:frame fromView:[view superview]]; // ack!
    [fe setMinSize:frame.size];
    [fe setMaxSize:maxSize];
    [fe setFrame:frame];
//	[fe setDrawSize:frame.size.width :frame.size.height];
    [fe setVerticallyResizable:YES];
    lastEditingFrame = NSZeroRect;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(editorFrameChanged:)
                                                 name:NSViewFrameDidChangeNotification object:fe];

    /* If we already have text, then put it in the Text object (allowing
     * the Text object to grow downward if necessary), otherwise, put
     * no text in, set some initial parameters, and allow the Text object
     * to grow horizontally as well as vertically
     */
    if (attributedString)
    {	[fe setHorizontallyResizable:NO];
        [[fe textContainer] setWidthTracksTextView:YES];
        containerSize.width = bounds.size.width;
        containerSize.height = [[fe textContainer] containerSize].height;
        [[fe textContainer] setContainerSize:containerSize];
        [ts beginEditing];
        [ts setAttributedString:attributedString];
        [ts endEditing];
    }
    else
    {	[fe setHorizontallyResizable:YES];
        [[fe textContainer] setWidthTracksTextView:NO];
        containerSize.width = NSMaxX(viewBounds) - bounds.origin.x;
        containerSize.height = [[fe textContainer] containerSize].height;
        [[fe textContainer] setContainerSize:containerSize];
        [fe setString:@""];
        [fe setAlignment:NSLeftTextAlignment];
        //[fe setTextColor:[NSColor blackColor] range:[fe selectedRange]];
        [fe unscript:self];
    }
#if 0
    /* if we set the color we set the color over the hole attributedString !!!
     * single characters in other color will be also set to color !
     */
    if ( [(col=[self color]) isEqual:[NSColor whiteColor]] )
        col = [NSColor blackColor];
    [fe setTextColor:col];
#endif
    /* Add the Text object to the view heirarchy and set self as its delegate
     * so that we will receive the textDidEnd:endChar: message when editing
     * is finished.
     */
    [fe setDelegate:self];
    [editView addSubview:fe];

/* doesn't work ! #ifdef __APPLE__    // Workaround: display Single Line Fonts
    if ( VHFAntialiasing() && [[font fontName] hasSuffix:@"-1Line"] )
        VHFSetAntialiasing(NO);
#endif*/

    //[fe display];	/* redraw because although we may have black background we edit on a white background*/

    /* Make it the first responder.
     */
    [[view window] makeFirstResponder:fe];

    /* Either pass the mouse-down event on to the Text object, or set
     * the selection at the beginning of the text.
     */
    if (event)
    {	[fe setSelectedRange:(NSRange){0,0}];	// eliminates any existing selection
        [fe mouseDown:event];
    }
    else
	[fe setSelectedRange:(NSRange){0,0}];

    [fe toggleRuler:self];
    [view scrollRectToVisible:frame];	// if ruler covers text -> scroll text to visible

    return YES;
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
{   NSRect  currentEditingFrame = [[arg object] frame];

    if (!NSEqualRects(lastEditingFrame, NSZeroRect))
    {
        if (lastEditingFrame.size.width > currentEditingFrame.size.width)
        {   NSRect  updateRect = lastEditingFrame;

            updateRect.origin.x = currentEditingFrame.origin.x + currentEditingFrame.size.width;
            [self updateEditingViewRect:updateRect];
        }
        if (lastEditingFrame.size.height > currentEditingFrame.size.height)
        {   NSRect updateRect = lastEditingFrame;

            updateRect.origin.y = currentEditingFrame.origin.y + currentEditingFrame.size.height;
            [self updateEditingViewRect:updateRect];
        }
    }
    lastEditingFrame = currentEditingFrame;
}

- (float)rotAngle
{
    return rotAngle;
}

- (void)setRotAngle:(float)angle
{
    rotAngle = angle;
    if ( rotAngle > 360.0 )
        rotAngle -= 360.0;
    if ( rotAngle < -360.0 )
        rotAngle += 360.0;
    dirty = YES;
}

- (void)scale:(float)x :(float)y withCenter:(NSPoint)cp
{
    aspectRatio *= y/x;
    bounds.size.width *= x;
    bounds.size.height *= y;
    bounds.origin.x = ScaleValue(bounds.origin.x, cp.x, x);
    bounds.origin.y = ScaleValue(bounds.origin.y, cp.y, y);
    [self setFont:[NSFont fontWithName:[font fontName] size:[font pointSize]*x]];
    dirty = YES;
}

- (void)setAspectRatio:(float)a
{
    if (!aspectRatio)
        return;
    aspectRatio = a; 
    dirty = YES;
}

/* set the origin (p is the baseline origin)
 * we have to convert the origin of rotation from the baseline to the origin of the text box
 */
- (void)setBaseOrigin:(NSPoint)p
{
    bounds.origin = p;
    if (font)
    {
        //bounds.origin.y = p.y - ascender - bounds.size.height;
       	bounds.origin.y = p.y + [font descender];
        if (rotAngle)	/* convert rotation from baseline to origin of text */
            vhfRotatePointAroundCenter(&bounds.origin, p, rotAngle);
    }
    dirty = YES;
}

/* set our vertices
 */
- (void)setFont:(NSFont *)aFont
{   float	lineHeight;

    if ( !aFont )
        return;
    [font release];
    font = [aFont retain];
    lineHeight = [font pointSize] - [font descender];

    [self makeMutableAttributedString];
    [attributedString addAttribute:NSFontAttributeName
                             value:aFont
                             range:NSMakeRange(0, [attributedString length])];
    [self setLineHeight:lineHeight];
    dirty = YES;
}

- (NSFont*)font
{
    if (!font && [attributedString length])
        font = [[attributedString attribute:NSFontAttributeName atIndex:0 effectiveRange:NULL] retain];
    return font;
}

/* set and return capHeight, because pointSize has the descender in it
 */
- (void)setFontSize:(float)v
{   float	capHeight = [[self font] capHeight];

    if ( capHeight == 0.0)	// GNUstep workaround
        capHeight = [[self font] ascender];
    [self setFont:[NSFont fontWithName:[[self font] fontName]
                                  size:v * [[self font] pointSize] / capHeight ]];
    dirty = YES;
}
- (float)fontSize
{   float	capHeight = [[self font] capHeight];

    if ( capHeight == 0.0)	// GNUstep workaround
        capHeight = [[self font] ascender];
    return capHeight;
}

- (void)setLineHeight:(float)v
{   NSMutableParagraphStyle	*paraStyle;

    if ( attributedString )
    {
        if ( ![attributedString length] )
            paraStyle = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
        else
            paraStyle = [[[attributedString attribute:NSParagraphStyleAttributeName
                                              atIndex:0 effectiveRange:NULL] mutableCopy] autorelease];
        [paraStyle setMinimumLineHeight:v];
        [paraStyle setMaximumLineHeight:v];
        if ( paraStyle )
        {   [self makeMutableAttributedString];
            [attributedString addAttribute:NSParagraphStyleAttributeName value:paraStyle
                                     range:NSMakeRange(0, [attributedString length])];
        }
        dirty = YES;
    }
}
- (float)lineHeight
{
    if (attributedString)
    {   float	lh;

        if ( [attributedString length] &&
             (lh = [[attributedString attribute:NSParagraphStyleAttributeName
                                        atIndex:0 effectiveRange:NULL] minimumLineHeight]) )
            return lh;
        else
            return [[self font] pointSize] - [[self font] descender];
    }
    return 0.0;
}

- (BOOL)centerVertical
{
    return centerVertical;
}
- (void)setCenterVertical:(BOOL)flag
{
    centerVertical = flag;
    dirty = YES;
}

- (BOOL)fitHorizontal
{
    return fitHorizontal;
}
- (void)setFitHorizontal:(BOOL)flag
{
    fitHorizontal = flag;
    if ( fitHorizontal )
        [self kernToFitHorizontal];
    else
        [self setKerning:0.0];
    dirty = YES;
}

/* reduce kerning to fit text in width of text box
 */
- (void)kernToFitHorizontal
{   NSLayoutManager	*lm = [drawText layoutManager];
    NSRect		rect;
    int			lines, l, i;
    float		f, min = -bounds.size.width/2.0, max = 0.0;

    if ( !fitHorizontal )
        return;
    [self updateDrawText];
    lines = [[drawText string] appearanceCountOfCharacter:'\n']+1;
    if ( bounds.size.height < 1000.0 )
    {	NSRect	rect = bounds;
        rect.size.height = 1000.0;
        [drawText setFrame:rect];
    }
    [self setKerning:0];
    for ( i=0, f=0; i<100; i++, f=(min+max)/2.0 )
    {
        [self setKerning:f+0.05];
        [self updateDrawText];
        // NOTE: on Apple this method returns heights that are less than our lineHeight
        rect = [lm boundingRectForGlyphRange:NSMakeRange(0, [lm numberOfGlyphs])
                             inTextContainer:[[lm textContainers] objectAtIndex:0]];
        l = (rect.size.height+0.5) / Min([[self font] pointSize], [self lineHeight]);
        if ( l <= lines )   // no line break any more -> kerning is small enough or too small
        {
            if (!i || i>10)
            {   [self setKerning:f];
                break;
            }
            min = f;
        }
        else                // kerning is too big
            max = f;
    }
    [drawText setFrame:bounds];
}

- (void)setKerning:(float)v
{
    if (attributedString)
    {
        [self makeMutableAttributedString];
        [attributedString addAttribute:NSKernAttributeName value:[NSNumber numberWithFloat:v]
                                 range:NSMakeRange(0, [attributedString length])];
        dirty = YES;
    }
}
- (float)kerning
{
    if (attributedString)
    {   id	number;

        if ( (number = [attributedString attribute:NSKernAttributeName atIndex:0 effectiveRange:NULL]) )
            return [number floatValue];
    }
    return 0.0;
}


- (int)stringLength
{
    return [[attributedString string] length];
}
- (float)characterOffsetAtIndex:(int)ix
{   NSLayoutManager	*lm = [drawText layoutManager];
    NSPoint		p;

    [self renewSharedText];
    [self updateDrawText];
    p = [lm locationForGlyphAtIndex:ix];
    return p.x;
}
- (NSRect)boundingRectAtIndex:(int)ix
{   NSLayoutManager	*lm = [drawText layoutManager];

    [self renewSharedText];
    [self updateDrawText];
    return [lm boundingRectForGlyphRange:NSMakeRange(ix, 1) inTextContainer:[[lm textContainers] objectAtIndex:0]];
}

- (VText*)subTextWithRange:(NSRange)range
{   VText		*charText = [[self copy] autorelease];
    NSAttributedString	*as;

    as = [attributedString attributedSubstringFromRange:range];
    [charText setAttributedString:as];
    return charText;
}


- (void)setSerialNumber:(BOOL)flag
{
    if (isSerialNumber!=flag)
    {
        isSerialNumber = flag;
        dirty = YES;
    }
}
- (BOOL)isSerialNumber
{
    return isSerialNumber;
}

/* created:  1995-10-21
 * modified: 
 * purpose:  draw the graphic rotated around cp
 */
- (void)drawAtAngle:(float)angle withCenter:(NSPoint)cp in:view
{   float	saveAngle = rotAngle;
    NSRect	saveBounds = bounds;

    [self setAngle:rotAngle+angle withCenter:cp];
    [self drawWithPrincipal:view];
    rotAngle = saveAngle;
    bounds = saveBounds;
}

/* created:  1995-10-21
 * modified: 2012-02-27 (make sure angle is within 0 and 360 deg)
 * purpose:  rotate the graphic around cp
 */
- (void)setAngle:(float)angle withCenter:(NSPoint)cp
{
    if (angle <= -360.0) angle += 360.0; // 2012-02-27
    if (angle >=  360.0) angle -= 360.0;

    if (filled)
    {   graduateAngle -= angle;
        if (graduateAngle <    0.0) graduateAngle += 360.0;
        if (graduateAngle >= 360.0) graduateAngle -= 360.0;
        //vhfRotatePointAroundCenter(&radialCenter, NSMakePoint(0.5, 0.5), -angle);
    }
    vhfRotatePointAroundCenter(&bounds.origin, cp, -angle);
    rotAngle -= angle;
    //if (rotAngle <    0.0) rotAngle += 360.0;
    //if (rotAngle >= 360.0) rotAngle -= 360.0;   // 2012-02-27
    rotAngle = vhfModulo(rotAngle, 360.0);
    dirty = YES;
}

- (void)mirrorAround:(NSPoint)p
{   NSPoint	d = NSMakePoint( 0.0, bounds.size.height);

    bounds.origin.y = p.y - (bounds.origin.y - p.y);
    if ( rotAngle )
        vhfRotatePointAroundCenter(&d, NSMakePoint(0.0, 0.0), -rotAngle);
    bounds.origin.x -= d.x;
    bounds.origin.y -= d.y;

    rotAngle = -rotAngle;

    aspectRatio = -aspectRatio;
    dirty = YES;
}

/*
 * draws the text
 */
- (void)drawWithPrincipal:principal
{   id              window = [principal window];
    BOOL            saveAutoDisplay = [window isAutodisplay];
    NSLayoutManager *lm = [drawText layoutManager];

#ifdef __APPLE__    // Workaround: display Single Line Fonts
    BOOL    antialias = VHFAntialiasing();
    if ( antialias && [[font fontName] hasSuffix:@"-1Line"] )
        VHFSetAntialiasing(NO);
    /*if ( NSAppKitVersionNumber < NSAppKitVersionNumber10_6  // < 10.6
         && [[font fontName] hasSuffix:@"-1Line"] )         // Single Line Font
    {   VPath   *path = [self getFlattenedObjectAt:NSMakePoint(0.0, 0.0) withOffset:0];
        [path drawWithPrincipal:principal];
        return;
    }*/
#endif

    editView = [principal editView];	// needed in flatten object

    if (attributedString /*&& (NXDrawingStatus == NX_DRAWING)*/)
    {
        [self renewSharedText];
        [[drawText textStorage] beginEditing];
        /* check color */
        if ((!VHFIsDrawingToScreen() && [principal separationColor]) || [principal mustDrawPale])
        {   NSMutableAttributedString   *mas = [attributedString mutableCopyWithZone:[self zone]];
            int                         i, cnt = [mas length];

            for (i=0; i<cnt; i++)
            {   NSRange	range;
                NSColor	*colorAtt;

                colorAtt = [mas attribute:@"NSColor" atIndex:i longestEffectiveRange:&range
                                  inRange:NSMakeRange(0, cnt)];
                if (!colorAtt)
                    colorAtt = fillColor;
                if ([principal mustDrawPale])
                {   CGFloat h, s, b, a;

                    [[colorAtt colorUsingColorSpaceName:NSDeviceRGBColorSpace] getHue:&h
                                                                           saturation:&s
                                                                       brightness:&b alpha:&a];
                    colorAtt = [NSColor colorWithCalibratedHue:h saturation:s
                                                    brightness:(b<0.5) ? 0.5 : b alpha:a];
                }
                else
                    colorAtt = [self separationColor:colorAtt];
                if (colorAtt)
                    [mas addAttribute:@"NSColor" value:colorAtt range:range];
                i += range.length-1;
            }
            [[drawText textStorage] setAttributedString:mas];
            [mas release];
        }
#if !defined(GNUSTEP_BASE_VERSION) && !defined(__APPLE__)	// OpenStep 4.2
        else if (VHFIsDrawingToScreen() && [[color colorSpaceName] isEqualToString:NSDeviceCMYKColorSpace])
        {   NSMutableAttributedString   *mas = [attributedString mutableCopyWithZone:[self zone]];
            int                         i, cnt = [mas length];

            for (i=0; i<cnt; i++)
            {   NSRange range;
                NSColor *colorAtt;

                colorAtt = [mas attribute:@"NSColor" atIndex:i longestEffectiveRange:&range
                                  inRange:NSMakeRange(0, cnt)];
                if (!colorAtt)
                    colorAtt = [fillColor colorUsingColorSpaceName:NSCalibratedRGBColorSpace];	
                else
                    colorAtt = [colorAtt colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
                [mas addAttribute:@"NSColor" value:colorAtt range:range];
                i += range.length-1;
            }
            [[drawText textStorage] setAttributedString:mas];
            [mas release];
        }
#endif
        else // here we must not change the (copy of) attributed string
            [[drawText textStorage] setAttributedString:attributedString];

        [[drawText textStorage] endEditing];
        [drawText setTextContainerInset:NSMakeSize(0.0, 0.0)];  // 2010-07-29: moved before setFrame: for Apple mirror
        [drawText setFrame:bounds];
        [drawText setFrame:bounds]; // 2012-02-28: well, without this extra invitation Apple doesn't draw mirrored text !
        //[drawText writeRTFDToFile:@"/tmp/text.rtf" atomically:NO];	// debugging
        //[drawText setFrame:bounds];

        if ( centerVertical )	// vertical center: (bounds.size.height-textHeight)/2
        {   NSRect	rect = [lm boundingRectForGlyphRange:NSMakeRange(0, [lm numberOfGlyphs])
                                         inTextContainer:[drawText textContainer]];
            [drawText setTextContainerInset:NSMakeSize(0.0, Max(0.0, (bounds.size.height-rect.size.height-1.0)/2.0))];
        }

        [drawText setFrameRotation:rotAngle];
        [drawText scaleUnitSquareToSize:NSMakeSize(1.0, aspectRatio)];
        //displayModeFilled = filled;
        [window setAutodisplay:NO]; // don't let addSubview: cause redisplay (not wanted for resize)
        /* focusView is either cache or DocView
         *   DocView        -> editView (FlippedView)
         *                  -> drawText
         *   cache (NSView) -> drawText
         */
        [[NSView focusView] addSubview:drawText];   // cache (NSView) / DocView -> drawText
        [drawText lockFocus];
        [drawText drawRect:[drawText bounds]];
        [drawText unlockFocus];
        [drawText removeFromSuperview];
        [window setAutodisplay:saveAutoDisplay];
        //[[NSView focusView] setNeedsDisplay:NO];
        [drawText scaleUnitSquareToSize:NSMakeSize(1.0, 1.0/aspectRatio)];
#   ifdef GNUSTEP_BASE_VERSION  // 2009-12-29 gui 0.17.1: GNUstep workaround, rotation screws up everything
        if ( rotAngle != 0.0 )
        {   [drawText release]; drawText = nil;
            initClassVars();
        }
//#   else
//        [drawText release]; drawText = nil;
//        initClassVars();
#   endif
        //[drawText setFrameRotation:0.0];
    	/*if (DrawStatus == Resizing)
    	{   [[NSColor lightGrayColor] set];
            NSFrameRect(bounds);
    	}*/
    }

#   ifdef __APPLE__    // Workaround: display Single Line Fonts
    if (antialias)
        VHFSetAntialiasing(antialias);
#   endif
}

/* extract number from data, increment this number and add it to data. Then write string to drawText
 */
- (void)setSerialTextFor:(NSTextView*)drawText withOffset:(int)o setData:(BOOL)setData
{   int         i, lennew, lentot;
    NSString    *string, *prefix, *valueStr;

    if (attributedString && o)
    {	NSRange		range;

        [self updateDrawText];
        string = [attributedString string];

        range.location = 0;
        for (i=[string length]-1; i>=0; i--)		// extract serial number
        {   range = [[string substringFromIndex:i] rangeOfCharacterFromSet:[NSCharacterSet decimalDigitCharacterSet]];
            if ( (range.location || i==0) && range.length )
                break;
        }
        if (i<0)
            i = [string length]-1;
        prefix = [string substringToIndex:(range.location) ? i+1 : i];		// "serial-number"
        valueStr = [string substringFromIndex:(range.location) ? i+1 : i];	// "0099"

        lentot = [valueStr length];		// append incremented number
        //if ( lentot=[valueStr length] )	// append incremented number
        {   NSMutableString	*zeros = [NSMutableString string];

            valueStr = [NSString stringWithFormat:@"%d", [valueStr intValue]+o];	// "100"
            lennew = [valueStr length];

            for (i=0; i<lentot-lennew; i++)	// 0
                [zeros appendString:@"0"];
            string = [prefix stringByAppendingFormat:@"%@%@", zeros, valueStr];
        }

        [drawText replaceCharactersInRange:NSMakeRange(0, [[drawText textStorage] length]) withString:string];

        if ( setData )
        {
            [self makeMutableAttributedString];
            [attributedString replaceCharactersInRange:NSMakeRange(0, [attributedString length])
                                            withString:string];
            dirty = YES;
        }
    }
}

- (void)incrementSerialNumberBy:(int)o
{
    [self setSerialTextFor:drawText withOffset:o setData:YES];
}

/*
 * draws the text
 */
- (void)drawSerialNumberAt:(NSPoint)p withOffset:(int)o
{   NSRect	bRect = bounds;
    id		window = [[self class] currentWindow];

    if (attributedString)
    {
        [self setSerialTextFor:drawText withOffset:o setData:NO];

        bRect.origin.x += p.x; bRect.origin.y += p.y;
        [drawText setFrame:bRect];
        [drawText setFrameRotation:rotAngle];
        [drawText scaleUnitSquareToSize:NSMakeSize(1.0, aspectRatio)];
        //displayModeFilled = filled;
        [window setAutodisplay:NO]; // don't let addSubview: cause redisplay
        [[NSView focusView] addSubview:drawText];
        //[drawText display];
        [drawText lockFocus];
        [drawText drawRect:[drawText bounds]];
        [drawText unlockFocus];
        [drawText removeFromSuperview];
        [window setAutodisplay:YES];
        [drawText scaleUnitSquareToSize:NSMakeSize(1.0, 1.0/aspectRatio)];
    }
}

/*
 * Returns the bounds.  The flag variable determines whether the
 * knobs should be factored in. They may need to be for drawing but
 * might not if needed for constraining reasons.
 */
- (NSRect)coordBounds
{   NSPoint	p, ll, ur;
    NSRect	bRect;

    ll = ur = bounds.origin;

    p.x = bounds.origin.x+bounds.size.width;
    p.y = bounds.origin.y;
    vhfRotatePointAroundCenter(&p, bounds.origin, rotAngle);
    ll.x = Min(ll.x, p.x); ll.y = Min(ll.y, p.y);
    ur.x = Max(ur.x, p.x); ur.y = Max(ur.y, p.y);

    p.x = bounds.origin.x+bounds.size.width;
    p.y = bounds.origin.y+bounds.size.height;
    vhfRotatePointAroundCenter(&p, bounds.origin, rotAngle);
    ll.x = Min(ll.x, p.x); ll.y = Min(ll.y, p.y);
    ur.x = Max(ur.x, p.x); ur.y = Max(ur.y, p.y);

    p.x = bounds.origin.x;
    p.y = bounds.origin.y+bounds.size.height;
    vhfRotatePointAroundCenter(&p, bounds.origin, rotAngle);
    ll.x = Min(ll.x, p.x); ll.y = Min(ll.y, p.y);
    ur.x = Max(ur.x, p.x); ur.y = Max(ur.y, p.y);

    bRect.origin = ll;
    bRect.size.width  = ur.x-ll.x;
    bRect.size.height = ur.y-ll.y;

    return bRect;
}

/*
 * Returns the bounds with the given rotation.
 */
- (NSRect)boundsAtAngle:(float)angle withCenter:(NSPoint)cp
{   NSPoint	p, ll, ur;
    NSRect	bRect;

    bRect = bounds;
    p = bounds.origin;
    vhfRotatePointAroundCenter(&p, cp, -angle);
    ll = ur = p;

    p.x = bounds.origin.x+bounds.size.width;
    p.y = bounds.origin.y;
    vhfRotatePointAroundCenter(&p, bounds.origin, -rotAngle);
    vhfRotatePointAroundCenter(&p, cp, -angle);
    ll.x = Min(ll.x, p.x); ll.y = Min(ll.y, p.y);
    ur.x = Max(ur.x, p.x); ur.y = Max(ur.y, p.y);

    p.x = bounds.origin.x+bounds.size.width;
    p.y = bounds.origin.y+bounds.size.height;
    vhfRotatePointAroundCenter(&p, bounds.origin, -rotAngle);
    vhfRotatePointAroundCenter(&p, cp, -angle);
    ll.x = Min(ll.x, p.x); ll.y = Min(ll.y, p.y);
    ur.x = Max(ur.x, p.x); ur.y = Max(ur.y, p.y);

    p.x = bounds.origin.x;
    p.y = bounds.origin.y+bounds.size.height;
    vhfRotatePointAroundCenter(&p, bounds.origin, -rotAngle);
    vhfRotatePointAroundCenter(&p, cp, -angle);
    ll.x = Min(ll.x, p.x); ll.y = Min(ll.y, p.y);
    ur.x = Max(ur.x, p.x); ur.y = Max(ur.y, p.y);

    bRect.origin = ll;
    bRect.size.width  = ur.x-ll.x;
    bRect.size.height = ur.y-ll.y;

    return bRect;
}

- (NSRect)textBox		{ return bounds; }
- (void)setTextBox:(NSRect)rect	{ bounds = rect; [self kernToFitHorizontal]; dirty = YES; } // 2008-02-05

/*
 * Depending on the pt_num passed in, return the rectangle
 * that should be used for scrolling purposes. When the rectangle
 * passes out of the visible rectangle then the screen should
 * scroll. If the first and last points are selected, then the second
 * and third points are included in the rectangle. If the second and
 * third points are selected, then they are used by themselves.
 */
- (NSRect)scrollRect:(int)pt_num inView:(id)aView
{   float	knobsize;
    NSPoint	p;
    NSRect	aRect;

    if (pt_num == -1)
        aRect = [self bounds];
    else
    {
        [self getPoint:pt_num :&p];
        aRect.origin = p;
        aRect.size.width = 0;
        aRect.size.height = 0;
    }

    knobsize = -[VGraphic maxKnobSizeWithScale:[aView scaleFactor]]/2.0;
    aRect = NSInsetRect(aRect, knobsize, knobsize);
    return aRect;
}

/* 
 * This method constains the point to the bounds of the view passed
 * in. Like the method above, the constaining is dependent on the
 * control point that has been selected.
 */
- (void)constrainPoint:(NSPoint *)aPt andNumber:(int)pt_num toView:(DocView*)aView
{   NSPoint	viewMax;
    NSRect	viewRect;

    viewRect = [aView bounds];
    viewMax.x = viewRect.origin.x + viewRect.size.width;
    viewMax.y = viewRect.origin.y + viewRect.size.height;

    viewMax.x -= MARGIN;
    viewMax.y -= MARGIN;
    viewRect.origin.x += MARGIN;
    viewRect.origin.y += MARGIN;

    aPt->x = MAX(viewRect.origin.x, aPt->x);
    aPt->y = MAX(viewRect.origin.y, aPt->y);

    aPt->x = MIN(viewMax.x, aPt->x);
    aPt->y = MIN(viewMax.y, aPt->y);
}

/*
 * created:   25.09.95
 * modified:
 * parameter: ptNum  number of vertices
 *            p      the new position in
 * purpose:   Sets a vertice to a new position.
 *            If it is a edge move the vertices with it
 */
- (void)movePoint:(int)ptNum to:(NSPoint)p
{   NSPoint	pc, pt;

    [self getPoint:ptNum :&pc];
    pt.x = p.x - pc.x;
    pt.y = p.y - pc.y;
    [self movePoint:ptNum by:pt];
}

/*
 * pt_num is the changing control point. pt holds the relative change in each coordinate. 
 * The relative is needed and not the absolute because the closest inside control point
 * changes when one of the outside points change.
 */
- (void)movePoint:(int)pt_num by:(NSPoint)pt
{   NSPoint	p, d, cp = NSMakePoint(0, 0);

    [self getPoint:pt_num :&p];
    p.x += pt.x; p.y += pt.y;
    d = pt;
    vhfRotatePointAroundCenter(&d, cp, -rotAngle);
    switch (pt_num)
    {
        case PT_LOWERLEFT:
            bounds.size.width  -= d.x;
            bounds.size.height -= d.y;
            bounds.origin = p;
            break;
        case PT_MIDLEFT:
            d.y = 0;
            bounds.size.width -= d.x;
            vhfRotatePointAroundCenter(&d, cp, rotAngle);
            bounds.origin.x += d.x;
            bounds.origin.y += d.y;
            break;
        case PT_UPPERLEFT:
            bounds.size.width  -= d.x;
            bounds.size.height += d.y;
            d.y = 0;
            vhfRotatePointAroundCenter(&d, cp, rotAngle);
            bounds.origin.x += d.x;
            bounds.origin.y += d.y;
            break;
        case PT_LOWERMID:
            d.x = 0;
            bounds.size.height -= d.y;
            vhfRotatePointAroundCenter(&d, cp, rotAngle);
            bounds.origin.x += d.x;
            bounds.origin.y += d.y;
            break;
        case PT_LOWERRIGHT:
            bounds.size.width  += d.x;
            bounds.size.height -= d.y;
            d.x = 0;
            vhfRotatePointAroundCenter(&d, cp, rotAngle);
            bounds.origin.x += d.x;
            bounds.origin.y += d.y;
            break;
        case PT_MIDRIGHT:
            d.y = 0;
            bounds.size.width += d.x;
            break;
        case PT_UPPERRIGHT:
            bounds.size.width  += d.x;
            bounds.size.height += d.y;
            break;
        case PT_UPPERMID:
            d.x = 0;
            bounds.size.height += d.y;
    }
    bounds.size.width = Abs(bounds.size.width);
    bounds.size.height = Abs(bounds.size.height);

    [self kernToFitHorizontal];
    dirty = YES;
}

/* The pt argument holds the relative point change. */
- (void)moveBy:(NSPoint)pt
{
    bounds.origin.x += pt.x;
    bounds.origin.y += pt.y;
    dirty = YES;
}

- (int)numPoints
{
    return PTS_TEXT;
}

/* Given the point number, return the point. */
- (NSPoint)pointWithNum:(int)pt_num
{   NSRect	bnd = bounds;
    NSPoint	p;

    switch (pt_num)
    {
        default:		p = bnd.origin; break;
        case PT_MIDLEFT:	p.x = bnd.origin.x; p.y = bnd.origin.y + bnd.size.height/2.0; break;
        case PT_UPPERLEFT:	p.x = bnd.origin.x; p.y = bnd.origin.y + bnd.size.height; break;
        case PT_LOWERMID:	p.x = bnd.origin.x + bnd.size.width/2.0; p.y = bnd.origin.y; break;
        case PT_LOWERRIGHT:	p.x = bnd.origin.x + bnd.size.width; p.y = bnd.origin.y; break;
        case PT_MIDRIGHT:	p.x = bnd.origin.x + bnd.size.width; p.y = bnd.origin.y + bnd.size.height/2.0; break;
        case PT_UPPERRIGHT:	p.x = bnd.origin.x + bnd.size.width; p.y = bnd.origin.y + bnd.size.height; break;
        case PT_UPPERMID:	p.x = bnd.origin.x + bnd.size.width/2.0; p.y = bnd.origin.y + bnd.size.height;
    }

    if (rotAngle)
        vhfRotatePointAroundCenter(&p, bnd.origin, rotAngle);
    return p;
}

/*
 * Check for a edge point hit.
 * parameter:	p		the mouse position
 *		fuzz		the distance inside we snap to a point
 *		pt		the edge point
 *		controlsize	the size of the controls
 */
- (BOOL)hitEdge:(NSPoint)p fuzz:(float)fuzz :(NSPoint*)pt :(float)controlsize
{   NSRect	knobRect, hitRect;
    NSPoint	pc;
    int		i;

    hitRect.origin.x = p.x -fuzz/2.0;
    hitRect.origin.y = p.y -fuzz/2.0;
    hitRect.size.width = hitRect.size.height = fuzz;
    knobRect.size.width = knobRect.size.height = controlsize;

    for (i=0; i<PTS_TEXT; i++)
    {	[self getPoint:i :&pc];
        knobRect.origin.x = pc.x - controlsize/2.0;
        knobRect.origin.y = pc.y - controlsize/2.0;
        if (!NSIsEmptyRect(NSIntersectionRect(hitRect , knobRect)))
        {   *pt = pc;
            return YES;
        }
    }

    return NO;
}

/*
 * Check for a control point hit.
 * Return the point number hit in the pt_num argument.
 */
- (BOOL)hitControl:(NSPoint)p :(int*)pt_num controlSize:(float)controlsize
{   NSRect	knobRect;
    int		i;

    knobRect.size.width = knobRect.size.height = controlsize;

    for (i=0; i<PTS_TEXT; i++)
    {	NSPoint	pt = [self pointWithNum:i];

        knobRect.origin.x = pt.x - controlsize/2.0;
        knobRect.origin.y = pt.y - controlsize/2.0;
        if ( NSPointInRect(p, knobRect) )
        {
            *pt_num = i;
            return YES;
        }
    }
    return NO;
}

- (BOOL)hit:(NSPoint)p fuzz:(float)fuzz
{   NSRect	bRect = [self bounds];

    bRect.origin.x -= fuzz;
    bRect.origin.y -= fuzz;
    bRect.size.width  += 2.0 * fuzz;
    bRect.size.height += 2.0 * fuzz;
    if ( NSPointInRect(p, bRect) )
        return YES;
    return NO;
}

/*
 * return a path representing the outline of us
 * the path holds two lines and two arcs
 * if we need not build a contour a copy of self is returned
 */
- contour:(float)w
{
    return [[self getFlattenedObject] contour:w];
}

/*
 * This method is called when ever first responder is taken away from a
 * currently editing VText (i.e. when the user is done editing and
 * chooses to go do something else).  We must extract the rich text the user
 * has typed from the Text object, and store it away.  We also need to
 * get the frame of the Text object and make that our bounds (but,
 * remember, since the Text object must be a subview of a flipped view,
 * we need to convert the bounds rectangle to the coordinates of the
 * unflipped GraphicView).  If the Text object is empty, then we remove
 * this VText from the GraphicView and delayedFree: it.
 * We must remove the Text object from the view heirarchy and, since
 * this Text object is going to be reused, we must set its delegate
 * back to nil.
 * For further explanation of the two "ack!" lines, see edit:in: above.
 *
 * modified: 2012-01-04 (if isLocked, we don't adjust the size of the text box)
 *           2009-02-12
 */
- (void)textDidEndEditing:(NSNotification *)notification
{   NSTextView          *fe = [notification object];
    NSRect              oldBounds;
    NSPoint             o;
    float               correction = 2.0;	// ? we use this to increase the bounds that contain the text
    NSAttributedString  *as;

    if ( fe )
    {
        editView = [fe superview];
        graphicView = [editView superview];

        if ([fe isRulerVisible])
            [fe toggleRuler:self];

        if ( [[fe string] length] || attributedString )
        {   id	change = nil;

            if ( ![[fe string] length] )
                [fe setString:@"EMPTY TEXT"];

            if ( attributedString )
            {   change = [[EndEditingGraphicsChange alloc] initGraphicView:graphicView graphic:self];
                correction = 0.0;
            }

            [change startChange];
                [drawText setString:@""];	// needed for linux
                as = [[fe textStorage] attributedSubstringFromRange:NSMakeRange(0, [[fe textStorage] length])];
                [self setAttributedString:as];
            [change endChange];

            oldBounds = [self extendedBoundsWithScale:[graphicView scaleFactor]];
            [fe setVerticallyResizable:YES];
            if ( ! isLocked )
            {   [fe sizeToFit];
                bounds = [fe frame];
                bounds.size = [fe bounds].size;
                bounds.size.width  += correction;
                bounds.size.height += correction;   // origin = upper/left here!
                bounds = [editView convertRect:bounds toView:graphicView];  // ack!
            }
            //bounds = [graphicView centerScanRect:bounds];	/* center pixels */
            //redrawRect = NSUnionRect(bounds, redrawRect);

            [font release];
            font = [[fe font] retain];
            [self kernToFitHorizontal];

            dirty = YES;
            [textPath setDirty:YES];
            //[[graphicView window] disableFlushWindow];
            o = bounds.origin;
            o.y += bounds.size.height;
            vhfRotatePointAroundCenter(&bounds.origin, o, rotAngle); // new origin
            oldBounds = NSUnionRect(bounds, oldBounds);
            [[graphicView layerOfGraphic:self] updateObject:self];  // 2008-02-05
            [(DocView*)graphicView cache:oldBounds];
            //[graphicView draw:oldBounds];	/* update cache */
            //[(NSView*)graphicView lockFocus];
            //[(NSView*)graphicView drawRect:oldBounds];
            //[(NSView*)graphicView unlockFocus];
            //[[graphicView window] enableFlushWindow];
            //[[graphicView window] flushWindow];
            [[(App*)NSApp currentDocument] setDirty:YES];
        }
        else
            [graphicView removeGraphic:self];
        [fe scaleUnitSquareToSize:NSMakeSize(1.0, 1.0/aspectRatio)];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:NSViewFrameDidChangeNotification object:fe];
        [fe setDelegate:nil];
        [fe removeFromSuperview];
        [fe setSelectedRange:NSMakeRange(0, 0)];
    }
}

- (VPath*)pathRepresentation
{
    return [self getFlattenedObjectAt:NSMakePoint(0.0, 0.0) withOffset:0];
}

/* build path
 */
- (id)getFlattenedObject
{
    return [self getFlattenedObjectAt:NSMakePoint(0.0, 0.0) withOffset:0];
}

/* build path
 */
- (id)getFlattenedObjectAt:(NSPoint)position withOffset:(int)o
{   VPath		*pathG = nil;
    VGroup		*group = nil;
    NSRect		bRect = bounds, rect;
    NSPoint		p;
    int			i, cnt;
    NSLayoutManager	*lm = [drawText layoutManager];

    if (!attributedString)
        return nil;

    [self renewSharedText];
    if (o)
        [self setSerialTextFor:drawText withOffset:o setData:NO];
    else
        [self updateDrawText];

    bRect.origin.x += position.x; bRect.origin.y += position.y;
    [drawText setFrame:bRect];

    [drawText setTextContainerInset:NSMakeSize(0.0, 0.0)];
    if ( centerVertical )	// (bounds.size.height-textHeight)/2
    {
        rect = [lm boundingRectForGlyphRange:NSMakeRange(0, [lm numberOfGlyphs])
                             inTextContainer:[[lm textContainers] objectAtIndex:0]];
        [drawText setTextContainerInset:
            NSMakeSize(0.0, Max(0.0, (bounds.size.height-rect.size.height-1.0)/2.0))];
    }
    [drawText setFrameRotation:rotAngle];

#ifdef __APPLE__
    {   NSBezierPath	*bezierPath = [NSBezierPath bezierPath];
        NSFont          *fnt;
        float           yOffset = 0.0;

        /* workaround for offset in older OS X versions, not knowing exactly when it was fixed
         * It seems vertical centered text needs this offset.
         */
        if ( centerVertical /*|| NSAppKitVersionNumber < 824.42*/ )   // Mac OS X < 10.4.10
            yOffset = Max(0.0, (bounds.size.height-rect.size.height-1.0)/2.0);
        if ( aspectRatio < 0.0 )    // mirrored text
            yOffset -= bounds.size.height; // Apple needs that

        cnt = [lm numberOfGlyphs];
        if (cnt > 1)
            group = [VGroup group];
        for (i=0; i<cnt; i++)
        {
            if ([lm notShownAttributeForGlyphAtIndex:i])
                continue;
            rect = [lm lineFragmentRectForGlyphAtIndex:i effectiveRange:NULL];
            p = [lm locationForGlyphAtIndex:i];
            [bezierPath removeAllPoints];
            [bezierPath moveToPoint:NSMakePoint(bRect.origin.x+rect.origin.x+p.x,
                                                bRect.origin.y+bRect.size.height-rect.origin.y-p.y-yOffset)];
            fnt = [[drawText textStorage] attribute:NSFontAttributeName atIndex:i effectiveRange:NULL];
            [bezierPath appendBezierPathWithGlyph:[lm glyphAtIndex:i] inFont:fnt];
            pathG = [VPath pathWithBezierPath:bezierPath];
            [pathG setWidth:0.0];
            //printf("y=%.0f h=%.0f lh=%.0f  oberkannte=%.0f  vorstellung=%.0f\n", bRect.origin.y, bRect.size.height, [self lineHeight], bRect.origin.y+bRect.size.height, bRect.origin.y+bRect.size.height-([self lineHeight]*aspectRatio/2.0));
             /* /2.0 war bis 2007-10-26, tut nicht mit 10.4.10 (824.42) */
            if (aspectRatio != 1.0)
                [pathG scale:1.0 :aspectRatio
                  withCenter:NSMakePoint(1.0, bRect.origin.y+bRect.size.height/1.0)];
            [pathG setAngle:-rotAngle withCenter:bRect.origin];
            /* FIXME: stroked fonts shouldn't be filled! */
            [pathG setFilled:YES optimize:NO];
            if ( group && [pathG count] )
                [group addObject:pathG];
        }

        return (group) ? (id)group : (id)pathG;
    }
#else
    /*
     * we draw the text inside editView, then writing it to postscript-data for interpretation
     */
    {	PSImportSub     *psImport;
        NSData          *psData;
        NSMutableArray  *list;

        if (!editView)
        {
            if (!(editView = [[[self class] currentView] editView]))
            {   NSArray	*windows = [NSApp windows];

                NSLog(@"VText, -getFlattenedObject: No editView !");
                /* we need the editView of the window we are in, so this doesn't work in all cases !!!
                 * why do we need the editView of the window we are in ???
                 */
                for (i=[windows count]-1; i>=0; i--)
                    if ( [[windows objectAtIndex:i] isMemberOfClass:[DocWindow class]] )
                    {
                        editView = [[[[windows objectAtIndex:i] document] documentView] editView];
                        break;
                    }
            }
        }

        [drawText scaleUnitSquareToSize:NSMakeSize(1.0, aspectRatio)];
        [[editView window] setAutodisplay:NO]; // don't let addSubview: cause redisplay
        [editView setFlipped:NO];
        [editView addSubview:drawText];
        p = bounds.origin;
        bounds.origin = bRect.origin;
        bRect = [self bounds];
        bounds.origin = p;

        /* write postscript data */
        psData = [editView dataWithEPSInsideRect:bRect];
        //[[[NSMutableString alloc] initWithData:psData encoding:NSASCIIStringEncoding]
        //                           writeToFile:@"/tmp/VText.eps" atomically:NO];

        [editView setFlipped:YES];
        [drawText removeFromSuperview];
        [drawText scaleUnitSquareToSize:NSMakeSize(1.0, 1.0/aspectRatio)];
        [[editView window] setAutodisplay:YES];

        /* import written postscript data */
        psImport = [[PSImportSub allocWithZone:[self zone]] init];
        [psImport flattenText:YES];
        [psImport moveToOrigin:NO];
        list = [[[psImport importPS:psData] retain] autorelease];
        [psImport release];

        cnt = [list count];
        if (cnt>1)	// put paths in a group to collect separated chars
            group = [VGroup group];
        for ( i=0; i<cnt; i++ )
        {
            pathG = [list objectAtIndex:i];
            [pathG setWidth:0.0];
            if ([[[self fillColor] colorSpaceName] isEqualToString:NSDeviceCMYKColorSpace])
                [pathG setFillColor:[[[list objectAtIndex:i]fillColor]
                                     colorUsingColorSpaceName:NSDeviceCMYKColorSpace]];
            if (cnt>1)
                [group addObject:pathG];	 //[[group list] addObject:pathG];
        }
        if ( !pathG )
            pathG = [VPath path];

        /*if (fontListNoFill)
        {   NSRange	range = [fontListNoFill rangeOfString:[font fontName]];
            if (fontListNoFill && range.location >= 0)
                [((cnt>1) ? (id)group : (id)pathG) setFilled:NO];
        }*/

        return (cnt>1) ? (id)group : (id)pathG;
    }
#endif
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [super encodeWithCoder:aCoder];
    [aCoder encodeValuesOfObjCTypes:"@", &attributedString];
    [aCoder encodeValuesOfObjCTypes:"@", &font];
    [aCoder encodeValuesOfObjCTypes:"ff", &rotAngle, &aspectRatio];
    //[aCoder encodeValuesOfObjCTypes:"{NSRect=ffff}", &bounds];    // doesn't work with 64 bit !
    [aCoder encodeRect:bounds];                 // 2012-01-08
    [aCoder encodeValuesOfObjCTypes:"ccc", &isSerialNumber, &fitHorizontal, &centerVertical];
    [aCoder encodeObject:fillColor];
    [aCoder encodeObject:endColor];
    [aCoder encodeValuesOfObjCTypes:"ff", &graduateAngle, &stepWidth];
    //[aCoder encodeValuesOfObjCTypes:"{NSPoint=ff}", &radialCenter];
    [aCoder encodePoint:radialCenter];          // 2012-01-08
}
- (id)initWithCoder:(NSCoder *)aDecoder
{   int	version;

    [super initWithCoder:aDecoder];
    version = [aDecoder versionForClassName:@"VText"];
    if ( version < 4 )	// 13.02.00
    {   float	length;
        [aDecoder decodeValuesOfObjCTypes:"i", &length];
    }
    if (version >= 7)
        [aDecoder decodeValuesOfObjCTypes:"@", &attributedString];
    else
    {   NSData	*data;

        [aDecoder decodeValuesOfObjCTypes:"@", &data];
        [self setRichTextData:data];
    }
    [aDecoder decodeValuesOfObjCTypes:"@", &font];
    [aDecoder decodeValuesOfObjCTypes:"ff", &rotAngle, &aspectRatio];
    if ( version < 5 )	// 04.05.00
        [aDecoder decodeValuesOfObjCTypes:"{ffff}", &bounds];
    else
        //[aDecoder decodeValuesOfObjCTypes:"{NSRect=ffff}", &bounds];
        bounds = [aDecoder decodeRect];         // 2012-01-08
    if ( version < 2 )
        [aDecoder decodeValuesOfObjCTypes:"c", &isSerialNumber];
    else if ( version < 3)
        [aDecoder decodeValuesOfObjCTypes:"cc", &isSerialNumber, &fitHorizontal];
    else
        [aDecoder decodeValuesOfObjCTypes:"ccc", &isSerialNumber, &fitHorizontal, &centerVertical];
    if ( version >= 6)
    {   fillColor = [[aDecoder decodeObject] retain];
        endColor  = [[aDecoder decodeObject] retain];
        [aDecoder decodeValuesOfObjCTypes:"ff", &graduateAngle , &stepWidth];
        //[aDecoder decodeValuesOfObjCTypes:"{NSPoint=ff}", &radialCenter];
        radialCenter = [aDecoder decodePoint];  // 2012-01-08
    }
    if ( version < 1 )
    {   float	f;
        [aDecoder decodeValuesOfObjCTypes:"f", &f];
    }
    [self kernToFitHorizontal];

    [self setParameter];

    return self;
}

/* archiving with property list
 */
- (id)propertyList
{   NSMutableDictionary	*plist = [super propertyList];

    [plist setObject:propertyListFromFloat(rotAngle)            forKey:@"rotAngle"];
    [plist setObject:propertyListFromFloat(aspectRatio)         forKey:@"aspectRatio"];
    [plist setObject:[self richTextData] forKey:@"data"];
    [plist setObject:propertyListFromNSRect(bounds)             forKey:@"bounds"];
    if (isSerialNumber) [plist setObject:@"YES"                 forKey:@"isSerialNumber"];
    if (fitHorizontal)  [plist setObject:@"YES"                 forKey:@"fitHorizontal"];
    if (centerVertical) [plist setObject:@"YES"                 forKey:@"centerVertical"];

    if (fillColor != [NSColor blackColor])
        [plist setObject:propertyListFromNSColor(fillColor)     forKey:@"fillColor"];
    if (endColor != [NSColor blackColor])
        [plist setObject:propertyListFromNSColor(endColor)      forKey:@"endColor"];
    if (graduateAngle)
        [plist setObject:propertyListFromFloat(graduateAngle)   forKey:@"graduateAngle"];
    if (stepWidth != 7)
        [plist setObject:propertyListFromFloat(stepWidth)       forKey:@"stepWidth"];
    if (radialCenter.x != 0.5 && radialCenter.y != 0.5)
        [plist setObject:propertyListFromNSPoint(radialCenter)  forKey:@"radialCenter"];

    return plist;
}
- (id)initFromPropertyList:(id)plist inDirectory:(NSString *)directory
{
    [self setParameter];
    [super initFromPropertyList:plist inDirectory:directory];
    rotAngle       = [plist floatForKey:@"rotAngle"];
    aspectRatio    = [plist floatForKey:@"aspectRatio"];
    [self setRichTextData:[plist objectForKey:@"data"]];    // this also loads the text colors for paragraphs !
    bounds = rectFromPropertyList([plist objectForKey:@"bounds"]);
    isSerialNumber = ([plist objectForKey:@"isSerialNumber"] ? YES : NO);
    fitHorizontal  = ([plist objectForKey:@"fitHorizontal"]  ? YES : NO);
    centerVertical = ([plist objectForKey:@"centerVertical"] ? YES : NO);
    [self font];

    fillColor = colorFromPropertyList([plist objectForKey:@"fillColor"], [self zone]);
    /*if (!(fillColor = colorFromPropertyList([plist objectForKey:@"fillColor"], [self zone])))
        [self setFillColor:[color copy]];   // destroys paragraph colors !*/
    if (!(endColor = colorFromPropertyList([plist objectForKey:@"endColor"], [self zone])))
        [self setEndColor:[NSColor blackColor]];
    graduateAngle = [plist floatForKey:@"graduateAngle"];
    if ( !(stepWidth = [plist floatForKey:@"stepWidth"]))
        stepWidth = 7.0;	// default;
    if ([plist objectForKey:@"radialCenter"])
        radialCenter = pointFromPropertyList([plist objectForKey:@"radialCenter"]);
    else
        radialCenter = NSMakePoint(0.5, 0.5);	// default
    return self;
}


- (void)dealloc
{
    [fillColor release];
    [endColor release];
    [attributedString release];
    [serialStreams release];
    [super dealloc];
}

@end
