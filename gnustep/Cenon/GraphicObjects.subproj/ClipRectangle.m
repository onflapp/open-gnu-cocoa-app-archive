/* ClipRectangle.m
 * Cenon 2-D Clip rectangle
 *
 * Copyright (C) 1996-2006 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1996-09-17
 * modified: 2006-01-11
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
#include <VHFShared/types.h>
#include <VHFShared/vhfCommonFunctions.h>
#include "ClipRectangle.h"
#include "VPath.h"
#include "VArc.h"
#include "../App.h"
#include "../DocView.h"
#include "../DocWindow.h"
#include "../Inspectors.h"

@interface ClipRectangle(PrivateMethods)
- (void)setParameter;
@end

@implementation ClipRectangle

/* initialize
 */
- init
{
    [self setParameter];

    return [super init];
}

/*
 * created: 1995-09-25
 * purpose: initializes all the stuff needed after a -read:
 */
- (void)setParameter
{
    selectedKnob = -1; 
}

#define CREATEEVENTMASK NSLeftMouseDraggedMask|NSLeftMouseDownMask|NSLeftMouseUpMask|NSPeriodicMask
- (BOOL)create:(NSEvent *)event in:(DocView*)view
{   NSRect		viewBounds, gridBounds, drawBounds;
    NSPoint		start, last, gridPoint, drawPoint, rSize, p, lastPoint = NSZeroPoint;
    id			window = [view window];
    ClipRectangle 	*drawRectangleGraphic;
    BOOL		ok = YES, dragging = NO, hitEdge = NO, inTimerLoop = NO;
    float		grid = 1.0/*(float)[view rasterSpacing]*/;
    int			windowNum = [event windowNumber];
    //	BOOL		alternate = [NXApp alternate];

    //	[drawRectangleGraphic setUseColor:YES];
    //	[self setUseColor:YES];

    [[(App*)NSApp inspectorPanel] loadGraphic:self];	/* set the values of the inspector to self */

    start = [view convertPoint:[event locationInWindow] fromView:nil];	/* convert window to view coordinates */
    [view hitEdge:&start spare:self];			/* snap to point */
    start = [view grid:start];				/* set on grid */
    viewBounds = [view visibleRect];			/* get the bounds of the view */
    [view lockFocus];					/* and lock the focus on view */

    [self setVertices:start :start];
    drawRectangleGraphic = [self copy];
    [drawRectangleGraphic setColor:[NSColor lightGrayColor]];
    gridBounds = [self extendedBoundsWithScale:[view scaleFactor]];

    last = start;

    event = [NSApp nextEventMatchingMask:CREATEEVENTMASK untilDate:[NSDate distantFuture] inMode:NSEventTrackingRunLoopMode dequeue:YES];
    StartTimer(inTimerLoop);
    /* now entering the tracking loop
     */
    while ( ((!dragging && [event type] != NSLeftMouseDown) || (dragging && [event type] != NSLeftMouseUp)) && [event type] != NSAppKitDefined && [event type] != NSSystemDefined )
    {
        /* Since MouseMoved event is never send we use a periodic event instead */
        if ( [event type] == NSPeriodic )
            drawPoint = [[[self class] currentWindow] mouseLocationOutsideOfEventStream];
        else
            drawPoint = [event locationInWindow];

        /* display only if mouse has moved */
        if ( drawPoint.x != lastPoint.x || drawPoint.y != lastPoint.y )
        {
            lastPoint = drawPoint;

            /* delete line from screen */
            [view drawRect:gridBounds];
            drawPoint = [view convertPoint:drawPoint fromView:nil];
            if ( ([event type] == NSLeftMouseDragged)&&(!dragging) )
                dragging = YES;
            if (dragging)
            {	[view scrollPointToVisible:drawPoint];
                viewBounds = [view bounds];
            }
            gridPoint = drawPoint;
            hitEdge = [view hitEdge:&gridPoint spare:self];			/* snap to point */
            gridPoint = [view grid:gridPoint];					/* fix position to grid¼ */

            [window displayCoordinate:gridPoint ref:NO];

            p.x = Min(start.x, gridPoint.x);
            p.y = Min(start.y, gridPoint.y);
            rSize.x = Diff(gridPoint.x, start.x);
            rSize.y = Diff(gridPoint.y, start.y);
            [self setVertices:p :rSize];
            gridBounds = [self extendedBoundsWithScale:[view scaleFactor]];

            p.x = Min(start.x, drawPoint.x);
            p.y = Min(start.y, drawPoint.y);
            rSize.x = Diff(drawPoint.x, start.x);
            rSize.y = Diff(drawPoint.y, start.y);
            [drawRectangleGraphic setVertices:p :rSize];
            drawBounds = [drawRectangleGraphic extendedBoundsWithScale:[view scaleFactor]];
            gridBounds  = NSUnionRect(drawBounds , gridBounds);

            if ( NSContainsRect(viewBounds , gridBounds) )		/* line inside view ? */
            {   [drawRectangleGraphic drawWithPrincipal:view];
                [self drawWithPrincipal:view];
            }
            else
                drawPoint = gridPoint = start;				/* else set line invalid */

            [window flushWindow];
        }
        event = [NSApp nextEventMatchingMask:CREATEEVENTMASK untilDate:[NSDate distantFuture] inMode:NSEventTrackingRunLoopMode dequeue:YES];
    }
    StopTimer(inTimerLoop);

    [drawRectangleGraphic release];

    last = gridPoint;

    if ( fabs(last.x-start.x) <= grid && fabs(last.y-start.y) <= grid )	/* no length -> not valid */
        ok = NO;
    else if ( (!dragging && [event type]==NSLeftMouseDown)||(dragging && [event type]==NSLeftMouseUp) )
    {	/* double click or out of window -> not valid */
        if ([event clickCount] > 1 || [event windowNumber] != windowNum)
            ok = NO;
        else
            ok = NSMouseInRect(gridPoint , viewBounds , NO);
    }

    if ([event type] == NSAppKitDefined || [event type] == NSSystemDefined)
    ok = NO;

    [view unlockFocus];

    if (!ok)
    {	[view display];
        return NO;
    }
    else
        [view cacheGraphic:self];	/* add to graphic cache */

    return YES;
}

/* set our vertices
 */
- (void)setVertices:(NSPoint)theOrigin :(NSPoint)theSize
{
    origin = theOrigin;
    size = theSize;
}

/*
 * return our vertices
 */
- (void)getVertices:(NSPoint*)theOrigin :(NSPoint*)theSize
{
    *theOrigin = origin;
    *theSize = size;
}





/* subclassed methods
 */

/*
 * returns the selected knob or -1
 */
- (int)selectedKnobIndex
{
    return selectedKnob;
}

/*
 * set the selection of the plane
 */
- (void)setSelected:(BOOL)flag
{
    if (!flag)
        selectedKnob = -1;
    [super setSelected:flag];
}

/*
 * draw
 */
- (void)draw
{   float	defaultWidth = [NSBezierPath defaultLineWidth];

    [color set];
    [NSBezierPath setDefaultLineWidth:(width > 0.0) ? width : defaultWidth];
    [NSBezierPath setDefaultLineCapStyle: NSRoundLineCapStyle];
    [NSBezierPath setDefaultLineJoinStyle:NSRoundLineJoinStyle];
    [NSBezierPath strokeRect:NSMakeRect(origin.x, origin.y, size.x, size.y)];
    [NSBezierPath setDefaultLineWidth:defaultWidth];
}

/*
 * Returns the bounds.  The flag variable determines whether the
 * knobs should be factored in. They may need to be for drawing but
 * might not if needed for constraining reasons.
 */
- (NSRect)coordBounds
{   NSPoint	ll, ur;
    NSRect	bRect;

    ll.x = origin.x + ((size.x<0.0) ? size.x : 0.0); ll.y = origin.y + ((size.y<0.0) ? size.y : 0.0);
    ur.x = origin.x + ((size.x>0.0) ? size.x : 0.0); ur.y = origin.y + ((size.y>0.0) ? size.y : 0.0);

    bRect.origin = ll;
    bRect.size.width  = MAX(ur.x - ll.x, 0.1);
    bRect.size.height = MAX(ur.y - ll.y, 0.1);

    return bRect;
}

/*
 * Returns the bounds with the given rotation.
 */
- (NSRect)boundsAtAngle:(float)angle withCenter:(NSPoint)cp
{   NSRect	bRect;

    bRect.origin = origin;
    bRect.size.width  = size.x;
    bRect.size.height = size.y;
    return bRect;
}

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
    NSRect	aRect;

    if (pt_num == -1)
        aRect = [self bounds];
    else
    {	NSPoint	p;

        [self getPoint:pt_num :&p];
        aRect.origin.x = p.x;
        aRect.origin.y = p.y;
        aRect.size.width = 0;
        aRect.size.height = 0;
    }

    knobsize = -[aView controlPointSize]/2.0;
    aRect = NSInsetRect(aRect, knobsize, knobsize);
    return aRect;
}

/* 
 * This method constains the point to the bounds of the view passed
 * in. Like the method above, the constaining is dependent on the
 * control point that has been selected.
 */
- (void)constrainPoint:(NSPoint *)aPt andNumber:(int)pt_num toView:(DocView*)aView
{   NSPoint		viewMax;
    NSRect		viewRect;

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
 * parameter: pt_num	number of vertices
 *            p		the new position in
 * purpose:   Sets a vertice to a new position.
 *            If it is a edge move the vertices with it
 *            Default must be the last point!
 */
- (void)movePoint:(int)pt_num to:(NSPoint)p
{   NSPoint	pc;
    NSPoint	pt;

    /* set point */
    switch (pt_num)
    {
        case PT_LL:	pc = origin; break;
        case PT_UL:	pc.x = origin.x; pc.y = origin.y + size.y; break;
        case PT_LR:	pc.x = origin.x + size.x; pc.y = origin.y; break;
        default:
        case PT_UR:	pc.x = origin.x + size.x; pc.y = origin.y + size.y;
    }

    pt.x = p.x - pc.x;
    pt.y = p.y - pc.y;
    [self movePoint:pt_num by:pt];
}

/*
 * pt_num is the changing control point. pt holds the relative change in each coordinate. 
 * The relative is needed and not the absolute because the closest inside control point
 * changes when one of the outside points change.
 */
- (void)movePoint:(int)pt_num by:(NSPoint)pt
{
    /* set point */
    switch (pt_num)
    {
        case PT_LL:
            origin.x += pt.x;
            origin.y += pt.y;
            size.x -= pt.x;
            size.y -= pt.y;
            break;
        case PT_UL:
            origin.x += pt.x;
            size.x -= pt.x;
            size.y += pt.y;
            break;
        case PT_LR:
            origin.y += pt.y;
            size.x += pt.x;
            size.y -= pt.y;
            break;
        case PT_UR:
        default:
            size.x += pt.x;
            size.y += pt.y;
    }
}

/* The pt argument holds the relative point change. */
- (void)moveBy:(NSPoint)pt
{
    [self movePoint:PT_LL by:pt];
    [self movePoint:PT_UR by:pt];
}

/* Given the point number, return the point.
 */
- (NSPoint)pointWithNum:(int)pt_num
{
    switch (pt_num)
    {
        case PT_LL:	return origin;
        case PT_UL:	return NSMakePoint( origin.x, origin.y + size.y );
        case PT_LR:	return NSMakePoint( origin.x + size.x, origin.y );
        default:
        case PT_UR:	return NSMakePoint( origin.x + size.x, origin.y + size.y );
    }
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
    int		i;

    hitRect.origin.x = p.x -fuzz/2.0;
    hitRect.origin.y = p.y -fuzz/2.0;
    hitRect.size.width = hitRect.size.height = fuzz;
    knobRect.size.width = knobRect.size.height = controlsize;

    for (i=0; i<PTS_RECTANGLE; i++)
    {	NSPoint	p;

        [self getPoint:i :&p];
        knobRect.origin.x = p.x - controlsize/2.0;
        knobRect.origin.y = p.y - controlsize/2.0;
        if (!NSIsEmptyRect(NSIntersectionRect(hitRect , knobRect)))
        {   *pt = p;
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
    for (i=0; i<PTS_RECTANGLE; i++)
    {	NSPoint	pt = [self pointWithNum:i];

        knobRect.origin.x = pt.x - controlsize/2.0;
        knobRect.origin.y = pt.y - controlsize/2.0;
        if ( NSPointInRect(p, knobRect) )
        {   *pt_num = i;
            selectedKnob = i;
            return YES;
        }
    }
    return NO;
}

- (BOOL)hit:(NSPoint)p fuzz:(float)fuzz
{   NSRect	aRect, bRect;
    int		i;

    aRect.origin.x = floor(p.x - fuzz);
    aRect.origin.y = floor(p.y - fuzz);
    aRect.size.width = ceil(p.x + fuzz) - aRect.origin.x;
    aRect.size.height = ceil(p.y + fuzz) - aRect.origin.y;
    for (i=0; i<PTS_RECTANGLE; i++)
    {	NSPoint	p0, p1;

        [self getPoint:i :&p0];
        [self getPoint:((i+1<PTS_RECTANGLE) ? i+1 : 0) :&p1];

        bRect.origin.x = floor(Min(p0.x, p1.x) - 1);
        bRect.origin.y = floor(Min(p0.y, p1.y) - 1);
        bRect.size.width = ceil(Max(p0.x, p1.x) + 2) - bRect.origin.x;
        bRect.size.height = ceil(Max(p0.y, p1.y) + 2) - bRect.origin.y;
        if ( !NSIsEmptyRect(NSIntersectionRect(aRect , bRect)) )
            return YES;
    }
    return NO;
}

- (NSArray*)clip:obj
{   NSRect	rect;

    rect.origin = origin;
    rect.size.width = size.x; rect.size.height = size.y;
    return [obj clippedWithRect:rect];
}

- (id)initWithCoder:(NSCoder *)aDecoder
{   int	version;

    [super initWithCoder:aDecoder];
    version = [aDecoder versionForClassName:@"ClipRectangle"];
    [aDecoder decodeValuesOfObjCTypes:"{ff}{ff}", &origin, &size];
    [self setParameter];

    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [super encodeWithCoder:aCoder];
    [aCoder encodeValuesOfObjCTypes:"{ff}{ff}", &origin, &size];
}

- (void)dealloc
{
    [super dealloc];
}

@end
