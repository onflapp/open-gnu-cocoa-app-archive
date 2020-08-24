/* MoveMatrix.m
 *
 * Copyright (C) 1993-2005 by vhf interservice GmbH
 * Author: Georg Fleischmann
 *
 * Created:  1993-05-17
 * Modified: 2005-11-08
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
#include <VHFShared/vhfCompatibility.h>
#include "FlippedView.h"
#include "MoveCell.h"
#include "MoveMatrix.h"

@implementation MoveMatrix

- (id)initCellClass:aCellClass
{   NSRect	scrollRect, matrixRect;
    NSSize	interCellSpacing = {0.0, 0.0}, newCellSize;

    scrollRect = [[[self superview] superview] frame];	// get the scrollView's dimensions

    matrixRect.size = [NSScrollView contentSizeForFrameSize:(scrollRect.size)
                                      hasHorizontalScroller:NO hasVerticalScroller:YES
                                                 borderType:NSBezelBorder];

    //[self setMode:NSListModeMatrix];			// prepare a matrix to the right state
    //	Wenn dieser Status gesetzt ist, kommt das trackMouse nicht mehr in der LayerCell an
    //  Andererseits funktioniert dann das Move nicht mehr ganz so gut

    [self setCellClass:aCellClass];
    [self renewRows:0 columns:1];

    [self setIntercellSpacing:interCellSpacing];	// we don't want any space between the matrix's cells

    newCellSize = [self cellSize];			// resize the matrix's cells and size the
    newCellSize.width = NSWidth(matrixRect);		// matrix to contain them

    [self setCellSize:newCellSize];
    [self sizeToCells];
    [self setAutosizesCells:YES];
    [self setAutoscroll:YES];

    return self;
}

- (void)calcCellSize
{
    if ( [self numberOfRows] > 0 )
    {   id	cell = [self cellAtRow:0 column:0];
        NSSize	size = [cell cellSize];
        NSRect	frame = [[self superview] frame];

        if ( frame.size.width )
        {   size.width = frame.size.width;
            [self setCellSize:size];
        }
    }
}

/* Traegt automatisch in die neue Cell sich selbst als MoveMatrix ein
 */
- (NSCell *)makeCellAtRow:(int)row column:(int)col;
{   MoveCell	*newCell = (MoveCell*)[super makeCellAtRow:row column:col];

    if ( [newCell respondsToSelector:@selector(setMatrix:)] )
        [newCell setMatrix:self];
    else
        NSLog(@"MoveMatrix (makeCellAt::): Cell does not respond to setMatrix");

    return newCell;
}


/*
 * Timers used to automatically scroll when the mouse is
 * outside the drawing view and not moving.
 */
#define startTimer(inTimerLoop) if (!inTimerLoop) { [NSEvent startPeriodicEventsAfterDelay:0.1 withPeriod:0.01]; inTimerLoop=YES; }
#define stopTimer(inTimerLoop) if (inTimerLoop) { [NSEvent stopPeriodicEvents]; inTimerLoop=NO; }

#define MOVE_MASK NSLeftMouseUpMask|NSLeftMouseDraggedMask

extern NSEvent *periodicEventWithLocationSetToPoint(NSEvent *oldEvent, NSPoint point);

- (void)mouseDown:(NSEvent *)theEvent
{   NSPoint		mouseDownLocation, mouseUpLocation, mouseLocation;
    NSInteger	row, column, newRow;
    NSRect		visibleRect, cellCacheBounds, cellFrame;
    float		dy;
    NSEvent		*event;
    BOOL 		scrolled = NO, inTimerLoop = NO;

    if ( ! ([theEvent modifierFlags] & NSControlKeyMask) )
    {	if ( [theEvent clickCount] == 1 )   // we only handle single click here to avoid issues
            [super mouseDown:theEvent];
        //else  // double click is making trouble (see commetn in IPLayerCell.m -trackMouse)
        //    NSLog(@"Double click");
        return;
    }

    /* shuffle Cell */

    /* prepare the cell and matrix cache windows */
    [self setupCache];

    /* find the cell that got clicked on and select it */
    mouseDownLocation = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    [self getRow:&row column:&column forPoint:mouseDownLocation];
    activeCell = [[self cellAtRow:row column:column] retain];
    [self selectCell:activeCell];
    cellFrame = [self cellFrameAtRow:row column:column];

    /* do whatever's required for a single-click */
    [self sendAction];

    /* draw a "well" in place of the selected cell (see drawSelf::) */
    [self display];

    /* copy what's currently visible into the matrix cache */
#if defined(GNUSTEP_BASE_VERSION)
    [matrixCache lockFocus];
    visibleRect = [self convertRect:[self visibleRect] toView:nil];
    PScomposite(NSMinX(visibleRect), NSMinY(visibleRect), NSWidth(visibleRect), NSHeight(visibleRect), [[self window] gState], 0.0, 0.0, NSCompositeCopy);
    [matrixCache unlockFocus];
#elif defined(__APPLE__)
    [matrixCache release];
    matrixCache = [[NSImage alloc] initWithData:[self dataWithPDFInsideRect:[self visibleRect]]];
#else
    [matrixCache lockFocus];
    visibleRect = [self convertRect:[self visibleRect] toView:nil];
    PScomposite(NSMinX(visibleRect), NSMinY(visibleRect), NSWidth(visibleRect), NSHeight(visibleRect), [[self window] gState], 0.0, NSHeight(visibleRect), NSCompositeCopy);
    [matrixCache unlockFocus];
#endif

/* debug: draw cache into document view */
/*{   NSRect	bRect = [self bounds];
    [[[NSApp currentDocument] documentView] lockFocus];
    [matrixCache compositeToPoint:NSZeroPoint
                         fromRect:NSMakeRect(0.0, 0.0, bRect.size.width, bRect.size.height)
                        operation:NSCompositeCopy];
    [[[NSApp currentDocument] documentView] unlockFocus];
    [[[NSApp currentDocument] window] flushWindow];
}*/

    PSWait();

    /* image the cell into its cache */
    [cellCache lockFocus];
    cellCacheBounds.origin = NSZeroPoint;
    cellCacheBounds.size = [cellCache size];
    [activeCell drawWithFrame:cellCacheBounds inView:[NSView focusView]];
    [cellCache unlockFocus];

    /* save the mouse's location relative to the cell's origin */
    dy = mouseDownLocation.y - cellFrame.origin.y;

    /* from now on we'll be drawing into ourself */
    [self lockFocus];

    event = theEvent;
    while ([event type] != NSLeftMouseUp)
    {
        /* erase the active cell using the image in the matrix cache */
	visibleRect = [self visibleRect];
#ifdef GNUSTEP_BASE_VERSION
        /* origin y of cellFrame is upper/left, composite origin is lower/left on GNUstep */
        /*[matrixCache compositeToPoint:NSMakePoint(NSMinX(cellFrame), NSMinY(cellFrame))
                             fromRect:NSMakeRect(0.0, NSHeight(visibleRect) - NSMinY(cellFrame) +
                                                      NSMinY(visibleRect) - NSHeight(cellFrame),
                                                 NSWidth(cellFrame), NSHeight(cellFrame))
                            operation:NSCompositeCopy];*/
        /* there is something wrong with NSImage on GNUstep, the obove doesn't work */
        [matrixCache compositeToPoint:NSMakePoint(NSMinX(cellFrame), NSMaxY(visibleRect))
                             fromRect:NSMakeRect(0.0, 0.0, NSWidth(cellFrame), NSHeight(visibleRect))
                            operation:NSCompositeCopy];
#else
        [matrixCache compositeToPoint:NSMakePoint(NSMinX(cellFrame), NSMaxY(cellFrame))
                             fromRect:NSMakeRect(0.0, NSHeight(visibleRect) - NSMinY(cellFrame) +
                                                      NSMinY(visibleRect) - NSHeight(cellFrame),
                                                 NSWidth(cellFrame), NSHeight(cellFrame))
                            operation:NSCompositeCopy];
#endif

        /* move the active cell */
        mouseLocation = [self convertPoint:[event locationInWindow] fromView:nil];
        cellFrame.origin.y = mouseLocation.y - dy;

        /* constrain the cell's location to our bounds */
	if (NSMinY(cellFrame) < NSMinX([self bounds]) )
	    cellFrame.origin.y = NSMinX([self bounds]);
        else if (NSMaxY(cellFrame) > NSMaxY([self bounds]))
            cellFrame.origin.y = NSHeight([self bounds]) - NSHeight(cellFrame);

        /* make sure the cell will be entirely visible in its new location (if
         * we're in a scrollView, it may not be)
         */
        if (!NSContainsRect(visibleRect, cellFrame) && [self isAutoscroll])
        {
            /* the cell won't be entirely visible, so scroll, dood, scroll, but
	         * don't display on-screen yet
	         */
            [[self window] disableFlushWindow];
            [self scrollRectToVisible:cellFrame];
            [[self window] enableFlushWindow];

            /* copy the new image to the matrix cache */
            [matrixCache lockFocus];
            //visibleRect = [self convertRect:[self visibleRect] fromView:[self superview]];
            //visibleRect = [self convertRect:visibleRect toView:nil];
            visibleRect = [self convertRect:[self visibleRect] toView:nil];
#ifdef GNUSTEP_BASE_VERSION
            PScomposite(NSMinX(visibleRect), NSMinY(visibleRect), NSWidth(visibleRect), NSHeight(visibleRect),
                        [[self window] gState], 0.0, 0.0, NSCompositeCopy);
#else
            PScomposite(NSMinX(visibleRect), NSMinY(visibleRect), NSWidth(visibleRect), NSHeight(visibleRect),
                        [[self window] gState], 0.0, NSHeight(visibleRect), NSCompositeCopy);
#endif
            [matrixCache unlockFocus];

            /* note that we scrolled and start generating timer events for autoscrolling */
            scrolled = YES;
            startTimer(inTimerLoop);
        }
        else
            stopTimer(inTimerLoop);

        /* composite the active cell's image on top of ourself */
        [cellCache compositeToPoint:NSMakePoint(cellFrame.origin.x, NSMaxY(cellFrame))
                           fromRect:NSMakeRect(0.0, 0.0, NSWidth(cellFrame), NSHeight(cellFrame))
                          operation:NSCompositeCopy];

        /* now show what we've done */
        [[self window] flushWindow];

        if (scrolled)		// if we autoscrolled, flush any lingering
        {   PSWait();		// window server events to make the scrolling
            scrolled = NO;	// smooth
        }

        /* save the current mouse location, just in case we need it again */
        mouseLocation = [event locationInWindow];

        /* no mouse moved available, then take mouseMoved, mouseUp, or timer */
        if (![[self window] nextEventMatchingMask:MOVE_MASK untilDate:[NSDate date]
                                           inMode:NSEventTrackingRunLoopMode dequeue:NO])
            event = [[self window] nextEventMatchingMask:MOVE_MASK | NSPeriodicMask];
        else
            event = [[self window] nextEventMatchingMask:MOVE_MASK];

        if ([event type] == NSPeriodic)
            event = periodicEventWithLocationSetToPoint(event, mouseLocation);
    }

    stopTimer(inTimerLoop);
    [self unlockFocus];

    /* find the cell under the mouse's location */
    mouseUpLocation = [event locationInWindow];
    mouseUpLocation = [self convertPoint:mouseUpLocation fromView:nil];
    if (![self getRow:&newRow column:&column forPoint:mouseUpLocation])
        [self getRow:&newRow column:&column forPoint:(cellFrame.origin)];

    /* we need to shuffle cells if the active cell's going to a new location */
    if ( ![[self cellAtRow:row column:0] dependant] && ![[self cellAtRow:newRow column:0] dependant] )
    {   [self shuffleCell:row to:newRow];
        if ( [[self cellAtRow:(row<newRow)?row:row+1 column:0] dependant] )
            [self shuffleCell:(row<newRow)?row:row+1 to:(row<newRow)?newRow:newRow+1];
    }

    /* make sure the active cell's visible if we're autoscrolling */
    if ([self isAutoscroll])
        [self scrollCellToVisibleAtRow:newRow column:0];

    /* no longer dragging the cell */
    [activeCell release];
    activeCell = 0;

    /* size to cells after all this shuffling and turn autodisplay back on */
    [self sizeToCells];
    [self display];
}


- (void)shuffleCell:(int)row to:(int)newRow
{   NSCell	*tmpCell;
    int		r = row, nr = newRow;
    int		selectedRow = [self selectedRow];

    if (newRow != row)
    {
	activeCell = [[self cellAtRow:row column:0] retain];
        if (newRow > row)
        {
            if (selectedRow <= newRow)					// adjust selected row if before
                selectedRow--;						// new active cell location

            while (row++ < newRow)					// push all cells above the active
            {	tmpCell = [self cellAtRow:row column:0];		// cell's new location up one row
                [self putCell:tmpCell atRow:row-1 column:0];		// so that we fill the vacant spot
                [tmpCell setTag:row-1];
            }

            [self putCell:activeCell atRow:newRow column:0];    // now place the active cell
            [(NSCell*)activeCell setTag:newRow];				// in its new home
        }
        else if (newRow < row)	
        {
            if (selectedRow >= newRow)                          // adjust selected row if after
                selectedRow++;                                  // new active cell location

            while (row-- > newRow)                              // push all cells below the active
            {	tmpCell = [self cellAtRow:row column:0];		// cell's new location down one
                [self putCell:tmpCell atRow:row+1 column:0];    // row so that we fill
                [tmpCell setTag:row+1];                         // the vacant spot
            }

            [self putCell:activeCell atRow:newRow column:0];    // now place the active cell
            [(NSCell*)activeCell setTag:newRow];                // in its new home
        }

        if ([activeCell state])                                 // if the active cell is selected,
            selectedRow = newRow;                               // note its new row
        [self selectCellAtRow:selectedRow column:0];

        activeCell = nil;						// no longer dragging the cell

        if (delegate && [delegate respondsToSelector:@selector(matrixDidShuffleCellFrom:to:)])
            [delegate matrixDidShuffleCellFrom:r to:nr];
    }
    else
        activeCell = nil;
}


- (void)drawRect:(NSRect)rect;
{   NSInteger   row, col;
    NSRect      cellBorder;
    NSRectEdge  sides[] = {NSMinXEdge, NSMinYEdge, NSMaxXEdge, NSMaxYEdge, NSMinXEdge, NSMinYEdge};
    CGFloat     grays[] = {NSDarkGray, NSDarkGray, NSWhite, NSWhite, NSBlack, NSBlack};

    /* do the regular drawing */
    [super drawRect:rect];

    /* draw a "well" if the user's dragging a cell */
    if (activeCell)
    {
        /* get the cell's frame */
        [self getRow:&row column:&col ofCell:activeCell];
        cellBorder = [self cellFrameAtRow:row column:col];
        /* draw the well */
        cellBorder = NSDrawTiledRects(cellBorder, cellBorder, sides, grays, 6);
        [[NSColor colorWithDeviceWhite:0.17 alpha:1.0] set];
        NSRectFill(cellBorder);
    }
}


- (void)setupCache
{   NSRect  visibleRect;

    /* create the matrix cache window */
    visibleRect = [self visibleRect];
    matrixCache = [self sizeCache:matrixCache to:(visibleRect.size)];

    /* create the cell cache window */
    cellCache = [self sizeCache:cellCache to:[self cellSize]];
}
- (NSImage*)sizeCache:(NSImage*)cache to:(NSSize)newSize
{
    /* This is a workaround for [NSImage setSize:] on GNUstep. */
#ifdef GNUSTEP_BASE_VERSION
    if (cache)
    {   [cache release];
        cache = nil;
    }
#endif
    if (!cache)
        cache = [[FlippedImage alloc] initWithSize:newSize];
    /* make sure the cache window's the right size */
    else
    {   NSSize	size = [cache size];

        if (size.width != newSize.width || size.height != newSize.height)
            [cache setSize:newSize];
    }
    return cache;
}


- (void)setDelegate:(id)anObject
{
    delegate = anObject;
}


- delegate
{
    return delegate;
}

- (void)dealloc
{
    [matrixCache release];
    [cellCache release];

    [super dealloc];
}

@end
