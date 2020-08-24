/*
 * TileScrollView.m
 *
 * Copyright (C) 1996-2012 by vhf interservice GmbH
 * Author: Georg Fleischmann
 *
 * Created:  1993
 * Modified: 2012-08-13 (call of [document -scale:...] with NSSize, scaleFactor, scale -> VFloat)
 *           2009-09-22 (-magnifyRegion: zero region -> scale to next zoom step, not 5000%)
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
#include <VHFShared/types.h>
#include "TileScrollView.h"
#include "App.h"

@implementation TileScrollView


/* instance methods */

/*+ (NSSize)frameSizeForContentSize:(NSSize)contentSize hasHorizontalScroller:(BOOL)hFlag hasVerticalScroller:(BOOL)vFlag borderType:(NSBorderType)borderType
{   NSSize	size;

    size = [super frameSizeForContentSize:contentSize hasHorizontalScroller:hFlag hasVerticalScroller:vFlag borderType:borderType];
    size.height += 28.0;

    return size;
}

+ (NSSize)contentSizeForFrameSize:(NSSize)frameSize hasHorizontalScroller:(BOOL)hFlag hasVerticalScroller:(BOOL)vFlag borderType:(NSBorderType)borderType
{   NSSize	size;

    size = [super contentSizeForFrameSize:frameSize hasHorizontalScroller:hFlag hasVerticalScroller:vFlag borderType:borderType];
    size.height -= 28.0;

    return size;
}*/

- initWithFrame:(NSRect)theFrame
{
    [super initWithFrame:theFrame];

    /* remember the current scale factor */
    oldScaleFactor = 1.0;

#ifdef __APPLE__
    [self setDrawsBackground:NO];
#endif

    return self;
}

- (void)setDocument:docu
{   int i;

    document = docu; 

    [resPopupListButton setTarget:self];
    [resPopupListButton setAction:@selector(changeScale:)];
    if ( (i = [resPopupListButton indexOfItemWithTag:100]) >= 0 )   // GNUstep: set to 100%
        [resPopupListButton selectItemAtIndex:i];
}

/* created:  1993-07-04
 * modified: 2012-08-13
 * 
 * increment and decrement an entry in the popup menu
 */
- (void)zoomIn:sender
{   int		row;
    VFloat	scaleFactor;
    NSPoint	center;
    NSRect	bRect;

    for (row=0; row<[resPopupListButton numberOfItems]; row++)
        if (Diff((VFloat)[[resPopupListButton itemAtIndex:row] tag] / 100.0, oldScaleFactor) < 0.001)
            break;
    row++;
    if (row >= [resPopupListButton numberOfItems])
        return;
    [resPopupListButton setTitle:[resPopupListButton itemTitleAtIndex:row]];

    scaleFactor = [[resPopupListButton itemAtIndex:row] tag] / 100.0;

    bRect = [[self documentView] visibleRect];
    center.x = bRect.origin.x+bRect.size.width/2.0;
    center.y = bRect.origin.y+bRect.size.height/2.0;

    [document scale:NSMakeSize(scaleFactor/oldScaleFactor, scaleFactor/oldScaleFactor) withCenter:center];
    oldScaleFactor = scaleFactor;

    [[self window] makeFirstResponder:[document documentView]];
}

- (void)zoomOut:sender
{   int		row;
    VFloat	scaleFactor;
    NSPoint	center;
    NSRect	bRect;

    for (row=0; row<[resPopupListButton numberOfItems]; row++)
        if (Diff((float)[[resPopupListButton itemAtIndex:row] tag] / 100.0, oldScaleFactor) < 0.001)
            break;
    row--;
    if (row < 0)
        return;

    scaleFactor = (VFloat)[[resPopupListButton itemAtIndex:row] tag] / 100.0;

#if !defined(GNUSTEP_BASE_VERSION) && !defined(__APPLE__)	// OpenStep 4.2
    bRect = [[self documentView] bounds];
    if ( ![[self documentView] caching] &&
         Max(bRect.size.width, bRect.size.height)/scaleFactor >= 10000.0)
        return;
#endif

    [resPopupListButton setTitle:[resPopupListButton itemTitleAtIndex:row]];

    bRect = [[self documentView] visibleRect];
    center.x = bRect.origin.x+bRect.size.width /2.0;
    center.y = bRect.origin.y+bRect.size.height/2.0;

    [document scale:NSMakeSize(scaleFactor/oldScaleFactor, scaleFactor/oldScaleFactor) withCenter:center];
    oldScaleFactor = scaleFactor;

    [[self window] makeFirstResponder:[document documentView]];
}

- (void)magnify:sender
{   BOOL	flag = ([[self documentView] magnify]) ? NO : YES;

    [[self documentView] setMagnify:flag];
    if ( flag )
        [self setDocumentCursor:[[NSCursor alloc] initWithImage:[NSImage imageNamed:@"cursorMagnify.tiff"]
                                                        hotSpot:NSMakePoint(7.0, 7.0)]];
}

/* modified: 2012-08-13
 */
- (void)magnifyRegion:(NSRect)region
{   NSPoint	center;
    int		row;
    VFloat	scaleFactor, scale = 0.0;
    NSRect	bRect;

    bRect = [[self documentView] visibleRect];
    if ( region.size.width && region.size.height )
        scale = (bRect.size.width+bRect.size.height) / (region.size.width+region.size.height);
    center.x = region.origin.x+region.size.width/2.0;
    center.y = region.origin.y+region.size.height/2.0;

    /* get row of popup relating to current scale */
    for (row=0; row<[resPopupListButton numberOfItems]; row++)
        if (Diff((VFloat)[[resPopupListButton itemAtIndex:row] tag] / 100.0, oldScaleFactor) < 0.001)
            break;
    row++;
    if (row >= [resPopupListButton numberOfItems])
        return;

    /* climb up the popup entries and get the new row */
    for ( ; scale > 0.0 && row<[resPopupListButton numberOfItems]-1; row++ )
    {
        scaleFactor = [[resPopupListButton itemAtIndex:row] tag] / 100.0;
        if (scaleFactor / oldScaleFactor >= scale)
            break;
    }

    [resPopupListButton setTitle:[resPopupListButton itemTitleAtIndex:row]];
    scaleFactor = [[resPopupListButton itemAtIndex:row] tag] / 100.0;

    [document scale:NSMakeSize(scaleFactor/oldScaleFactor, scaleFactor/oldScaleFactor) withCenter:center];
    oldScaleFactor = scaleFactor;
}

- (void)changeScale:sender
{   NSPoint	center;
    NSRect	bRect;
    VFloat	scaleFactor = [[sender selectedItem] tag] / 100.0;

    if (scaleFactor != oldScaleFactor)
    {

#if !defined(GNUSTEP_BASE_VERSION) && !defined(__APPLE__)	// OpenStep 4.2
        bRect = [[self documentView] bounds];
        if ( ![[self documentView] caching] &&
             Max(bRect.size.width, bRect.size.height)/scaleFactor >= 10000.0)
            return;
#endif

        //bRect = [[self documentView] bounds];
        bRect = [[self documentView] visibleRect];
        center.x = bRect.origin.x+bRect.size.width /2.0;
        center.y = bRect.origin.y+bRect.size.height/2.0;
        //[window disableDisplay];
        [document scale:NSMakeSize(scaleFactor/oldScaleFactor, scaleFactor/oldScaleFactor) withCenter:center];
        //[[self window] reenableDisplay];
        //[self display];
        oldScaleFactor = scaleFactor;
    }

    [[self window] makeFirstResponder:[document documentView]];
}

- (float)scaleFactor
{
    return oldScaleFactor;
}

- (void)setDocumentView:(NSView *)aView
{
    [super setDocumentView:aView];
}

/*
 * tile gets called whenever the scrollView changes size.  Its job is to resize
 * all of the scrollView's "tiled" views (scrollers, contentView and any other
 * views we might want to place in the scrollView's bounds).
 */
- (void)tile
{   static float    popupWidth = 0;
    NSRect          scrollerRect, buttonRect;

    /* resize and arrange the scrollers and contentView as usual */
    [super tile];

    /* FIXME: this is a hack to avoid crash with NSRulerView which is released too often
     * I have no idea where this release comes from!
     */
    {   int	i;

        for (i=[[self subviews] count]-1; i>=0; i-- )
        {   id	subview = [[self subviews] objectAtIndex:i];

            if ([subview isKindOfClass:[NSRulerView class]])
            {
                if ([subview retainCount] <= 2)
                    [subview retain];
                break;
            }
        }
    }

    if ( !box ) // on Apple we can't tile the scroller, it's too small (box = nil)
        return;

    if ([box superview] != self)	// make sure the popup list is subview of us
        [self addSubview:box];

    if (!popupWidth)			// get popup width
    {	buttonRect = [box frame];
        popupWidth = buttonRect.size.width;
    }

    scrollerRect = [[self horizontalScroller] frame];	// make the hScroller smaller + stick the popup next to it
    NSDivideRect(scrollerRect, &buttonRect, &scrollerRect, popupWidth, 2);
    [[self horizontalScroller] setFrame:scrollerRect];
    [box setFrame:buttonRect];
}

@end
