/* VLine.m
 * 2-D Line object
 *
 * Copyright (C) 1996-2012 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1996-01-29
 * modified: 2011-07-11 (-sqrDistanceGraphic:::, -sqrDistanceGraphic:; some new graphics recognized)
 *           2010-02-18 (exit with right mouse click added)
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
#include "VLine.h"
#include "VPath.h"
#include "VArc.h"
#include "../App.h"
#include "../DocView.h"
#include "../DocWindow.h"
#include "../Inspectors.h"

@interface VLine(PrivateMethods)
- (void)setParameter;
- (float)sqrDistanceLine:(NSPoint)pl0 :(NSPoint)pl1;
@end

@implementation VLine

/* This sets the class version so that we can compatibly read old objects out of an archive.
 */
+ (void)initialize
{
    [VLine setVersion:1];
    return;
}

+ (VLine*)line
{
    return [[[VLine allocWithZone:[self zone]] init] autorelease];
}
+ (VLine*)lineWithPoints:(NSPoint)pl0 :(NSPoint)pl1
{   VLine	*line = [[[[self class] allocWithZone:[self zone]] init] autorelease];

    [line setVertices:pl0 :pl1];
    return line;
}

/* initialize
 */
- init
{
    [self setParameter];
    return [super init];
}

/* deep copy
 *
 * created:  2001-02-15
 * modified: 
 */
- copy
{   VLine   *line = [[VLine allocWithZone:[self zone]] init];

    [line setWidth:width];
    [line setSelected:isSelected];
    [line setLocked:NO];
    [line setColor:color];
    [line setVertices:p0 :p1];
    return line;
}

/*
 * created: 25.09.95
 * purpose: initializes all the stuff needed after a -read:
 */
- (void)setParameter
{
    selectedKnob = -1; 
}

- (NSString*)description
{
    return [NSString stringWithFormat:@"VLine: %f %f %f %f", p0.x, p0.y, p1.x, p1.y];
}

- (NSString*)title
{
    return @"Line";
}

/* whether we are a path object
 * eg. line, polyline, arc, curve, rectangle, path
 * group is not a path object because we don't know what is inside!
 */
- (BOOL)isPathObject	{ return YES; }

- parallelObject:(NSPoint)begO :(NSPoint)endO :(NSPoint)beg :(NSPoint)end
{   VLine	*line = [[self copy] autorelease];

    [line setVertices:beg :end];

    return line;
}

/* create
 * modified: 2010-02-18 (exit with right mouse click)
 */
#define CREATEEVENTMASK NSLeftMouseDraggedMask|NSLeftMouseDownMask|NSLeftMouseUpMask|NSRightMouseDownMask|NSPeriodicMask
- (BOOL)create:(NSEvent *)event in:(DocView*)view
{   NSRect		viewBounds, gridBounds, drawBounds;
    NSPoint		start, last, gridPoint, drawPoint, lastPoint, hitPoint;
    id			window = [view window];
    VLine		*drawLineGraphic;
    BOOL		ok = YES, dragging = NO, hitEdge = NO;
    float		grid = 1.0 / [view scaleFactor];	// minimum accepted length
    int			windowNum = [event windowNumber];
    BOOL		alternate = [(App*)NSApp alternate], inTimerLoop = NO;

    [[(App*)NSApp inspectorPanel] loadGraphic:self];	// set the values of the inspector to self

    /* get start location, convert window to view coordinates */
    start     = [view convertPoint:[event locationInWindow] fromView:nil];
    hitPoint  = start;
    hitEdge   = [view hitEdge:&hitPoint spare:self];	// snap to point
    gridPoint = [view grid:start];			// set on grid
    if ( hitEdge &&
         ((gridPoint.x == start.x && gridPoint.y == start.y)  ||
          (SqrDistPoints(hitPoint, start) < SqrDistPoints(gridPoint, start))) )
        start = hitPoint; // we took the nearer one if we got a hitPoint
    else
        start = gridPoint;
    viewBounds = [view visibleRect];			// get the bounds of the view
    [view lockFocus];					// and lock the focus on view

    [self setVertices:start :start];
    drawLineGraphic = [[self copy] autorelease];
    [drawLineGraphic setColor:[NSColor lightGrayColor]];
    gridBounds = [self extendedBoundsWithScale:[view scaleFactor]];
    lastPoint = last = gridPoint = drawPoint = start; // init

    event = [NSApp nextEventMatchingMask:CREATEEVENTMASK untilDate:[NSDate distantFuture] inMode:NSEventTrackingRunLoopMode dequeue:YES];
    StartTimer(inTimerLoop);
    /* now entering the tracking loop
     */
    while ( ((Diff(p0.x, p1.x) <= grid && Diff(p0.y, p1.y) <= grid) ||
             (!dragging && [event type] != NSLeftMouseDown) ||
              (dragging && [event type] != NSLeftMouseUp))
            && [event type] != NSRightMouseDown
            && [event type] != NSAppKitDefined && [event type] != NSSystemDefined &&
            !([event type] == NSLeftMouseDown && [event clickCount] > 1) )
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
            if ( (!dragging) && ([event type] == NSLeftMouseDragged) &&
                 (Diff(p0.x, p1.x) > 3.0*grid || Diff(p0.y, p1.y) > 3.0*grid) )
                dragging = YES;
            /* if user is dragging we scroll the view */
            if (dragging)
            {   [view scrollPointToVisible:drawPoint];
                viewBounds = [view bounds];
            }

            /* fix position to grid¼ */
            gridPoint = drawPoint;
            gridPoint = [view grid:gridPoint];
            /* snap to point */
            hitPoint = drawPoint;
            hitEdge = [view hitEdge:&hitPoint spare:self];
            if ( hitEdge &&
                 ((gridPoint.x == drawPoint.x && gridPoint.y == drawPoint.y)  ||
                  (SqrDistPoints(hitPoint, drawPoint) < SqrDistPoints(gridPoint, drawPoint))) )
                gridPoint = hitPoint; // we took the nearer one if we got a hitPoint

            [window displayCoordinate:gridPoint ref:NO];

            [self setVertices:start :gridPoint];
            gridBounds = [self extendedBoundsWithScale:[view scaleFactor]];	// get bounds of the grid line

            [drawLineGraphic setVertices:start :drawPoint];
            drawBounds = [drawLineGraphic extendedBoundsWithScale:[view scaleFactor]];
            /* the united rect of the two rectÂs we need to redraw the view */
            gridBounds = NSUnionRect(drawBounds, gridBounds);

            /* if line is not inside view we set it invalid */
            if ( NSContainsRect(viewBounds , gridBounds) )
            {   [drawLineGraphic drawWithPrincipal:view];
                [self drawWithPrincipal:view];
            }
            else
                drawPoint = gridPoint = start;

            [window flushWindow];
        }
        event = [NSApp nextEventMatchingMask:CREATEEVENTMASK untilDate:[NSDate distantFuture] inMode:NSEventTrackingRunLoopMode dequeue:YES];
    }
    StopTimer(inTimerLoop);
    last = gridPoint;

    if ( fabs(last.x-start.x) <= grid && fabs(last.y-start.y) <= grid )		/* no length -> not valid */
        ok = NO;
    else if ( (!dragging && [event type]==NSLeftMouseDown)||(dragging && [event type]==NSLeftMouseUp) )
    {
        if ([event clickCount] > 1 || [event windowNumber] != windowNum)	// double click or outside window
            ok = NO;
        else
            ok = NSMouseInRect(gridPoint , viewBounds , NO);
    }

    if ( [event type] == NSAppKitDefined || [event type] == NSSystemDefined )
        ok = NO;

    [view unlockFocus];

    if ( !ok )
    {
        /* we duplicate the last click which ends the line,
         * so we can directly execute user actions in Tool-Panel etc.
         *
         * we must close the mouseDown event else object will be moved from DocView
         */
        if ([event windowNumber] != windowNum || [event type] == NSLeftMouseDown)
        {   NSEvent	*eventup = [NSEvent mouseEventWithType:NSLeftMouseUp
                                                  location:[event locationInWindow]
                                             modifierFlags:[event modifierFlags]
                                                 timestamp:[event timestamp]
                                              windowNumber:[event windowNumber]
                                                   context:[event context]
                                               eventNumber:[event eventNumber]
                                                clickCount:1 pressure:[event pressure]];

            [window postEvent:eventup atStart:1];	// up
            if ([event windowNumber] != windowNum)
                [window postEvent:event atStart:1];	// down
        }
        /* selection of last line is done in mouseDown: by hit of nonselected objects */
        [view display];
        return NO;
    }

    dirty = YES;
    //[view cacheGraphic:self];	// add to graphic cache
    if ( !hitEdge && !alternate )
        [window postEvent:event atStart:1];	// init new line

    return YES;
}

/* set our vertices
 */
- (void)setVertices:(NSPoint)pv0 :(NSPoint)pv1
{
    p0 = pv0;
    p1 = pv1;
    dirty = YES;
}

/* return our vertices
 */
- (void)getVertices:(NSPoint*)pv0 :(NSPoint*)pv1
{
    *pv0 = p0;
    *pv1 = p1;
}

- (void)setAngle:(float)angle
{   double	l = [self length], dx = 0.0, dy;

    dy = l * Sin(angle);
    if ( l*l - dy*dy > TOLERANCE )
        dx = sqrt( l*l - dy*dy );
    if ( angle>90.0 && angle<270.0 )
        dx = -dx;
    p1 = NSMakePoint(p0.x+dx, p0.y+dy);
    dirty = YES;
}
- (float)angle
{   double	dy = p1.y-p0.y, l = [self length], a, g;

    if (!l)
        return 0.0;
    g = dy / l;
    if (g < -1.0) return 270.0;
    if (g > 1.0)  return 90.0;
    a = Asin(g);
    if ( a < 0.0 )	a += 360.0;
    if ( p1.x < p0.x )	a = 180.0 - a;
    if ( a < 0.0 )	a += 360.0;

    return a;
}

- (void)setLength:(float)length
{   double	a = [self angle], dx = 0.0, dy;

    dy = length * Sin(a);
    if ( length*length - dy*dy > TOLERANCE )
        dx = sqrt( length*length - dy*dy );
    if (Cos(a) < 0.0)
        dx = -dx;
    p1 = NSMakePoint(p0.x+dx, p0.y+dy);
    dirty = YES;
}
- (float)length
{
    return sqrt(SqrDistPoints(p0, p1));
}

/* created:   17.03.96
 * modified:
 * parameter: p  the point
 *            t  0 <= t <= 1
 * purpose:   get a point on the line at t
 */
- (NSPoint)pointAt:(float)t
{   float	dx, dy;

    dx = p1.x - p0.x;
    dy = p1.y - p0.y;
    return NSMakePoint( p0.x + dx * t, p0.y + dy * t );
}

/*
 * changes the direction of the line p1<->p2
 */
- (void)changeDirection
{   NSPoint	p = p0;

    p0 = p1;
    p1 = p;
    dirty = YES;
}

/* created: 04.01.95
 * purpose: return the gradient (delta x, y, z) of the line at t
 */
- (NSPoint)gradientAt:(float)t
{   NSPoint	p;

    p.x = p1.x - p0.x;
    p.y = p1.y - p0.y;
    return p;
}

/* created:   18.03.96
 * modified:  
 * purpose:   intersect line with a line
 * parameter: pArray (intersections)
 *            pl0, pl1
 * return:    number of intersections
 *            0, 1
 */
- (int)intersectLine:(NSPoint*)pArray :(NSPoint)pl0 :(NSPoint)pl1
{   NSPoint	da, db;
    int		iCnt;

    da.x = p1.x - p0.x;   da.y = p1.y - p0.y;
    db.x = pl1.x - pl0.x; db.y = pl1.y - pl0.y;
    /* if the delta is in the range of TOLERANCE vhfIntersectVectors would identify the lines as parallel */
    if (da.x<=TOLERANCE || da.y<=TOLERANCE) {da.x = 10.0*p1.x -10.0*p0.x;  da.y = 10.0*p1.y -10.0*p0.y; };
    if (db.x<=TOLERANCE || db.y<=TOLERANCE) {db.x = 10.0*pl1.x-10.0*pl0.x; db.y = 10.0*pl1.y-10.0*pl0.y;};
    iCnt = vhfIntersectVectors(p0, da, pl0, db, pArray);

    if (iCnt)
    {	NSRect	rect1, rect2;

        rect1.origin.x = Min(p0.x, p1.x) - TOLERANCE;
        rect1.origin.y = Min(p0.y, p1.y) - TOLERANCE;
        rect1.size.width  = Max(p0.x, p1.x) - rect1.origin.x + 2.0*TOLERANCE;
        rect1.size.height = Max(p0.y, p1.y) - rect1.origin.y + 2.0*TOLERANCE;
        rect2.origin.x = Min(pl0.x, pl1.x) - TOLERANCE;
        rect2.origin.y = Min(pl0.y, pl1.y) - TOLERANCE;
        rect2.size.width  = Max(pl0.x, pl1.x) - rect2.origin.x + 2.0*TOLERANCE;
        rect2.size.height = Max(pl0.y, pl1.y) - rect2.origin.y + 2.0*TOLERANCE;
        if (NSPointInRect(pArray[0] , rect1) && NSPointInRect(pArray[0] , rect2))
            return iCnt;
    }
    else /* search parallel intersections */
    {
        if ( (da.x <= TOLERANCE && db.x <= TOLERANCE) ||
            (da.y <= TOLERANCE && db.y <= TOLERANCE) ||
            (da.x != 0 && db.x != 0 && Diff(((double)da.y / (double)da.x), ((double)db.y / (double)db.x)) < 0.0001) )
        {   int		cnt = 0;
            NSPoint	dtest;

            dtest.x = p1.x - pl1.x; dtest.y = p1.y - pl1.y; /* line between lines have not the same gradient */
            if ( (Diff(da.x, 0.0) <= TOLERANCE && Diff(dtest.x, 0.0) > TOLERANCE) ||
                 (Diff(da.x, 0.0) > TOLERANCE && Diff(dtest.x, 0.0) <= TOLERANCE) ||
                 (Diff(da.y, 0.0) <= TOLERANCE && Diff(dtest.y, 0.0) > TOLERANCE) ||
                 (Diff(da.y, 0.0) > TOLERANCE && Diff(dtest.y, 0.0) <= TOLERANCE) ||
                 (da.x != 0 && dtest.x != 0 && Diff(((double)da.y / (double)da.x), ((double)dtest.y / (double)dtest.x)) > 0.0001) ||
                 (da.y != 0 && dtest.y != 0 && Diff(((double)da.x / (double)da.y), ((double)dtest.x / (double)dtest.y)) > 0.0001))
                return 0;

            /* start line1 on line2 ? */
            if ( p0.y>=Min(pl0.y,pl1.y)-TOLERANCE && p0.y<=Max(pl0.y,pl1.y)+TOLERANCE &&
                p0.x>=Min(pl0.x,pl1.x)-TOLERANCE && p0.x<=Max(pl0.x,pl1.x)+TOLERANCE &&
                !pointWithToleranceInArray(p0, TOLERANCE, pArray, cnt) )
            {	pArray[cnt].x = p0.x;
                pArray[cnt++].y = p0.y;
            }
            /* end line1 on line2 ? */
            if ( p1.y>=Min(pl0.y,pl1.y)-TOLERANCE && p1.y<=Max(pl0.y,pl1.y)+TOLERANCE &&
                p1.x>=Min(pl0.x,pl1.x)-TOLERANCE && p1.x<=Max(pl0.x,pl1.x)+TOLERANCE &&
                !pointWithToleranceInArray(p1, TOLERANCE, pArray, cnt) )
            {	pArray[cnt].x = p1.x;
                pArray[cnt++].y = p1.y;
            }
            /* start line2 on line1 ? */
            if ( pl0.y>=Min(p0.y,p1.y)-TOLERANCE && pl0.y<=Max(p0.y,p1.y)+TOLERANCE &&
                pl0.x>=Min(p0.x,p1.x)-TOLERANCE && pl0.x<=Max(p0.x,p1.x)+TOLERANCE &&
                !pointWithToleranceInArray(pl0, TOLERANCE, pArray, cnt) )
            {	pArray[cnt].x=pl0.x;
                pArray[cnt++].y=pl0.y;
            }
            /* end line2 on line1 ? */
            if ( pl1.y>=Min(p0.y,p1.y)-TOLERANCE && pl1.y<=Max(p0.y,p1.y)+TOLERANCE &&
                pl1.x>=Min(p0.x,p1.x)-TOLERANCE && pl1.x<=Max(p0.x,p1.x)+TOLERANCE &&
                !pointWithToleranceInArray(pl1, TOLERANCE, pArray, cnt) )
            {	pArray[cnt].x=pl1.x;
                pArray[cnt++].y=pl1.y;
            }
            return cnt;
        }
    }

    return 0;
}

/* created:   2001-10-22
 * modified:  
 * purpose:   distance between two lines
 * parameter: pl0, pl1
 * return:    squar distance, nearest point of each line
 */
- (float)sqrDistanceLine:(NSPoint)pl0 :(NSPoint)pl1 :(NSPoint*)pg1 :(NSPoint*)pg2
{   float	distance = -1.0, dist;
    NSPoint	da, db, pt;
    int		iCnt;

    da.x = p1.x - p0.x;   da.y = p1.y - p0.y;
    db.x = pl1.x - pl0.x; db.y = pl1.y - pl0.y;
    /* if the delta is in the range of TOLERANCE vhfIntersectVectors would identify the lines as parallel */
    if (da.x<=TOLERANCE || da.y<=TOLERANCE) {da.x = 10.0*p1.x -10.0*p0.x;  da.y = 10.0*p1.y -10.0*p0.y; };
    if (db.x<=TOLERANCE || db.y<=TOLERANCE) {db.x = 10.0*pl1.x-10.0*pl0.x; db.y = 10.0*pl1.y-10.0*pl0.y;};
    iCnt = vhfIntersectVectors(p0, da, pl0, db, &pt);

    if (iCnt)
    {	NSRect	rect1, rect2;

        rect1.origin.x = Min(p0.x, p1.x) - TOLERANCE;
        rect1.origin.y = Min(p0.y, p1.y) - TOLERANCE;
        rect1.size.width  = Max(p0.x, p1.x) - rect1.origin.x + 2.0*TOLERANCE;
        rect1.size.height = Max(p0.y, p1.y) - rect1.origin.y + 2.0*TOLERANCE;
        rect2.origin.x = Min(pl0.x, pl1.x) - TOLERANCE;
        rect2.origin.y = Min(pl0.y, pl1.y) - TOLERANCE;
        rect2.size.width  = Max(pl0.x, pl1.x) - rect2.origin.x + 2.0*TOLERANCE;
        rect2.size.height = Max(pl0.y, pl1.y) - rect2.origin.y + 2.0*TOLERANCE;
        if (NSPointInRect(pt , rect1) && NSPointInRect(pt , rect2))
        {   *pg1 = *pg2 = pt;
            return iCnt;
        }
    }
    // we check only if begin/end of both lines near enought of other line
    distance = pointOnLineClosestToPoint(p0, p1, pl0, &pt); // beg of l2 to self
    *pg1 = pt; *pg2 = pl0;
    if ((dist=pointOnLineClosestToPoint(p0, p1, pl1, &pt)) < distance) // end of l2 to self
    {   *pg1 = pt; *pg2 = pl1;
        distance = dist;
    }
    if ((dist=pointOnLineClosestToPoint(pl0, pl1, p0, &pt)) < distance) // beg of self to l2
    {   *pg1 = p0; *pg2 = pt;
        distance = dist;
    }
    if ((dist=pointOnLineClosestToPoint(pl0, pl1, p1, &pt)) < distance) // end of self to l2
    {   *pg1 = p1; *pg2 = pt;
        distance = dist;
    }
    return distance;
}

/* created:   2001-10-22
 * modified:  
 * purpose:   distance between two lines
 * parameter: pl0, pl1
 * return:    squar distance
 */
- (float)sqrDistanceLine:(NSPoint)pl0 :(NSPoint)pl1
{   float	distance = -1.0, dist;
    NSPoint	pt;

    // cut lines -> 0.0
    if ( vhfIntersectLines(&pt, p0, p1, pl0, pl1))
        return 0.0;

    // we check only if begin/end of both lines near enought of other line
    distance = pointOnLineClosestToPoint(p0, p1, pl0, &pt); // beg of l2 to self
    if ((dist=pointOnLineClosestToPoint(p0, p1, pl1, &pt)) < distance) // end of l2 to self
        distance = dist;
    if ((dist=pointOnLineClosestToPoint(pl0, pl1, p0, &pt)) < distance) // beg of self to l2
        distance = dist;
    if ((dist=pointOnLineClosestToPoint(pl0, pl1, p1, &pt)) < distance) // end of self to l2
        distance = dist;
    return distance;
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

/* created:  1995-10-21
 * modified: 2006-01-17
 * purpose:  draw the graphic rotated around cp
 */
- (void)drawAtAngle:(float)angle withCenter:(NSPoint)cp in:view
{
    [color set];
    [NSBezierPath setDefaultLineWidth:1.0/[view scaleFactor]];
    [NSBezierPath strokeLineFromPoint:vhfPointRotatedAroundCenter(p0, -angle, cp)
                              toPoint:vhfPointRotatedAroundCenter(p1, -angle, cp)];
}

/* created:  1995-10-21
 * modified: 2001-11-25
 * purpose:  rotate the graphic around cp
 */
- (void)setAngle:(float)angle withCenter:(NSPoint)cp
{
    p0 = vhfPointRotatedAroundCenter(p0, -angle, cp);
    p1 = vhfPointRotatedAroundCenter(p1, -angle, cp);
    dirty = YES;
}

- (void)transform:(NSAffineTransform*)matrix
{   NSSize  size = NSMakeSize(width, width);

    size = [matrix transformSize:size];
    width = (Abs(size.width) + Abs(size.height)) / 2;
    p0 = [matrix transformPoint:p0];
    p1 = [matrix transformPoint:p1];
}

- (void)scale:(float)x :(float)y withCenter:(NSPoint)cp
{
    width *= (x+y)/2.0;
    p0.x = ScaleValue(p0.x, cp.x, x);
    p0.y = ScaleValue(p0.y, cp.y, y);
    p1.x = ScaleValue(p1.x, cp.x, x);
    p1.y = ScaleValue(p1.y, cp.y, y);
    dirty = YES;
}

- (void)mirrorAround:(NSPoint)p
{
    p0.y = p.y - (p0.y - p.y);
    p1.y = p.y - (p1.y - p.y);
    dirty = YES;
}

/*
 * draws the line
 * modified: 2007-11-20
 */
- (void)drawWithPrincipal:principal
{   NSColor	*oldColor = nil;
    float	defaultWidth;

    /* colorSeparation */
    if (!VHFIsDrawingToScreen() && [principal separationColor])
    {   NSColor	*sepColor = [self separationColor:color]; // get individual separation color

        oldColor = [color retain];
        [self setColor:sepColor];
    }

    [super drawWithPrincipal:principal];

    defaultWidth = [NSBezierPath defaultLineWidth];
    [NSBezierPath setDefaultLineWidth:(width > 0.0) ? width : defaultWidth];
    [NSBezierPath setDefaultLineCapStyle:NSRoundLineCapStyle];
    [NSBezierPath setDefaultLineJoinStyle:NSRoundLineJoinStyle];
    [NSBezierPath strokeLineFromPoint:p0 toPoint:p1];
    [NSBezierPath setDefaultLineWidth:defaultWidth];

    if ([principal showDirection])
        [self drawDirectionAtScale:[principal scaleFactor]];


    if (!VHFIsDrawingToScreen() && [principal separationColor])
    {   [self setColor:oldColor];
        [oldColor release];
    }
}

/*
 * Returns the bounds.  The flag variable determines whether the
 * knobs should be factored in. They may need to be for drawing but
 * might not if needed for constraining reasons.
 */
- (NSRect)coordBounds
{   NSPoint	ll, ur;
    NSRect	bRect;

    ll.x = Min(p0.x, p1.x); ll.y = Min(p0.y, p1.y);
    ur.x = Max(p0.x, p1.x); ur.y = Max(p0.y, p1.y);

    bRect.origin = ll;
    bRect.size.width  = ur.x - ll.x;
    bRect.size.height = ur.y - ll.y;

    return bRect;
}

/*
 * Returns the bounds with the given rotation.
 */
- (NSRect)boundsAtAngle:(float)angle withCenter:(NSPoint)cp
{   NSPoint	p;
    float	x0, y0, x1, y1;
    NSRect	bRect;

    p = p0;
    vhfRotatePointAroundCenter(&p, cp, -angle);
    x0 = p.x; y0 = p.y;

    p = p1;
    vhfRotatePointAroundCenter(&p, cp, -angle);
    x1 = p.x; y1 = p.y;

    bRect.origin.x = Min(x0, x1);
    bRect.origin.y = Min(y0, y1);
    bRect.size.width  = Max(Max(x0, x1) - bRect.origin.x, 1.0);
    bRect.size.height = Max(Max(y0, y1) - bRect.origin.y, 1.0);
    return bRect;
}

- (NSPoint)appendToBezierPath:(NSBezierPath*)bPath currentPoint:(NSPoint)currentPoint
{
    if (Diff(currentPoint.x, p0.x) > 0.01 || Diff(currentPoint.y, p0.y) > 0.01)
        [bPath moveToPoint:p0];
    [bPath lineToPoint:p1];
    return p1;
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
    else if (pt_num == 0)
    {
        aRect.origin.x = p0.x;
        aRect.origin.y = p0.y;
        aRect.size.width = 0;
        aRect.size.height = 0;
    }
    else
    {
        aRect.origin.x = p1.x;
        aRect.origin.y = p1.y;
        aRect.size.width = 0;
        aRect.size.height = 0;
    }

    knobsize = -[VGraphic maxKnobSizeWithScale:[aView scaleFactor]]/2.0;
    aRect = NSInsetRect(aRect , knobsize , knobsize);
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
    float	margin = MARGIN / [aView scaleFactor];

    viewRect = [aView bounds];
    viewMax.x = viewRect.origin.x + viewRect.size.width;
    viewMax.y = viewRect.origin.y + viewRect.size.height;

    viewMax.x -= margin;
    viewMax.y -= margin;
    viewRect.origin.x += margin;
    viewRect.origin.y += margin;

    aPt->x = MAX(viewRect.origin.x, aPt->x);
    aPt->y = MAX(viewRect.origin.y, aPt->y);

    aPt->x = MIN(viewMax.x, aPt->x);
    aPt->y = MIN(viewMax.y, aPt->y);
}

/*
 * Change the point number passed in by the amount passed in in pt.
 * Recalculate the bounds because one of the bounding points could
 * have been the changed point.
 */
- (void)changePoint:(int)pt_num :(NSPoint)pt
{   NSPoint	*pc;

    /* set point */
    switch (pt_num)
    {
        case 0:		pc = &p0; break;
        default:	pc = &p1;
    }
    pc->x += pt.x;
    pc->y += pt.y;
    dirty = YES;
}

/*
 * created:   25.09.95
 * modified:  
 * parameter: pt_num  number of vertices
 *            p       the new position in
 * purpose:   Sets a vertice to a new position.
 *            If it is a edge move the vertices with it
 *            Default must be the last point!
 */
- (void)movePoint:(int)pt_num to:(NSPoint)p
{   NSPoint	pc;
    NSPoint	pt;

    switch (pt_num)
    {
        case 0:  pc = p0; break;
        default: pc = p1;
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
    [self changePoint:pt_num :pt]; 
}

/* The pt argument holds the relative point change
 */
- (void)moveBy:(NSPoint)pt
{
    [self changePoint:0 :pt];
    [self changePoint:1 :pt];
}

- (int)numPoints
{
    return PTS_LINE;
}

/* Given the point number, return the point.
 * Default must be p1
 */
- (NSPoint)pointWithNum:(int)pt_num
{
    switch (pt_num)
    {
        case 0:
            return p0;
        default:
            return p1;
    }
}

/*
 * Check for a edge point hit.
 * parameter: p	the mouse position
 *            fuzz		the distance inside we snap to a point
 *            pt		the edge point
 *            controlsize	the size of the controls
 */
- (BOOL)hitEdge:(NSPoint)p fuzz:(float)fuzz :(NSPoint*)pt :(float)controlsize
{   NSRect	knobRect, hitRect;

    hitRect.origin.x = p.x -fuzz/2.0;
    hitRect.origin.y = p.y -fuzz/2.0;
    hitRect.size.width = hitRect.size.height = fuzz;
    knobRect.size.width = knobRect.size.height = controlsize;

    knobRect.origin.x = p0.x - controlsize/2.0;
    knobRect.origin.y = p0.y - controlsize/2.0;
    if ((selectedKnob < 0 || selectedKnob == 1) && !NSIsEmptyRect(NSIntersectionRect(hitRect , knobRect)))
    {	*pt = p0;
        //selectedKnob = 0;
        return YES;
    }

    knobRect.origin.x = p1.x - controlsize/2.0;
    knobRect.origin.y = p1.y - controlsize/2.0;
    if (selectedKnob <= 0 && !NSIsEmptyRect(NSIntersectionRect(hitRect , knobRect)))
    {	*pt = p1;
        //selectedKnob = 1;
        return YES;
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
    for (i=0; i<PTS_LINE; i++)
    {	NSPoint	pt = [self pointWithNum:i];

        knobRect.origin.x = pt.x - controlsize/2.0;
        knobRect.origin.y = pt.y - controlsize/2.0;
        if ( NSPointInRect(p, knobRect) )
        {
            selectedKnob = i;
            [self setSelected:YES];
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
    if ( NSPointInRect(p, bRect) && sqrDistancePointLine(&p0, &p1, &p) <= fuzz*fuzz)
        return YES;
    return NO;
}

/*
 * return a path representing the outline of us
 * the path holds two lines and two arcs
 * if we need not build a contour a copy of self is returned
 */
- contour:(float)w
{   VPath		*path;
    NSMutableArray	*list;
    VArc			*arc;
    VLine		*line;
    float		r, dx, dy, c;
    NSPoint		ps[4];
    int			i;

    /* contour would collapse to a line */
    if ( (w == 0.0 && width == 0.0) || (w<0.0 && -w >= width) )
    {	line = [VLine line];
        [line setWidth:Abs(w)];
        [line setColor:color];
        [line setVertices:p0 :p1];
        [line setSelected:[self isSelected]];
        return line;
    }

    path = [VPath path];
    list = [NSMutableArray array];

    r = (width + w) / 2.0;	/* the amount of growth */
    if (r < 0.0) r = 0.0;

    [path setColor:color];
//	[path setFilled:YES];

    dx = p1.x - p0.x;
    dy = p1.y - p0.y;
    if (dx == 0.0 && dy == 0.0)
        dx = 1.0;
    c = sqrt(dx*dx+dy*dy);
    ps[0].x = p0.x + dy*r/c;
    ps[0].y = p0.y - dx*r/c;
    ps[1].x = p0.x - dy*r/c;
    ps[1].y = p0.y + dx*r/c;
    ps[2].x = p1.x - dy*r/c;
    ps[2].y = p1.y + dx*r/c;
    ps[3].x = p1.x + dy*r/c;
    ps[3].y = p1.y - dx*r/c;

    /* 0=arc, 1=line, 2=arc, 3=line ! */
    arc = [VArc arc];
    [arc setCenter:p0 start:ps[1] angle:180.0];
    [list addObject:arc];
    line = [VLine line];
    [line setVertices:ps[0] :ps[3]];
    [list addObject:line];
    arc = [VArc arc];
    [arc setCenter:p1 start:ps[3] angle:180.0];
    [list addObject:arc];
    line = [VLine line];
    [line setVertices:ps[2] :ps[1]];
    [list addObject:line];

    for (i=[list count]-1; i>=0; i--)
    {	VGraphic    *g = [list objectAtIndex:i];

        [g setWidth:0.0];
        [g setColor:color];
    }

    [path addList:list at:[[path list] count]];
    [path setSelected:[self isSelected]];

    return path;
}

- (NSMutableArray*)getListOfObjectsSplittedFromGraphic:g
{   NSMutableArray	*splitList = nil;
    int			i, cnt = 0;
    NSPoint		*ps, *iPts;
    NSAutoreleasePool	*pool;

    if ( !(cnt = [self getIntersections:&iPts with:g]) )
        return nil;

    ps = iPts;

    if (!cnt)
    {   free(ps);
        return nil;
    }
    splitList = [NSMutableArray array];
    pool = [NSAutoreleasePool new];

    cnt = removePointWithToleranceFromArray(p0, 5.0*TOLERANCE, ps, cnt);
    cnt = removePointWithToleranceFromArray(p1, 5.0*TOLERANCE, ps, cnt);

    cnt = vhfFilterPoints(ps, cnt, 10.0*TOLERANCE);
    sortPointArray(ps, cnt, p0);

    // correkt intersection points for horicontal/vertical lines
    // else we get no correct values in later calculations ! ! !
    if ( p0.x == p1.x )
    {   for ( i=0; i<cnt; i++ )
            ps[i].x = p0.x;
    }
    if ( p0.y == p1.y )
    {   for ( i=0; i<cnt; i++ )
            ps[i].y = p0.y;
    }

    for ( i=0; i<=cnt; i++ )
    {   VLine	*line = [VLine line];
        NSPoint	pv0, pv1;

        pv0 = (!i) ? p0 : ps[i-1];
        pv1 = (i>=cnt) ? p1 : ps[i];
        [line setWidth:width];
        [line setColor:color];
        [line setVertices:pv0 :pv1];
        [splitList addObject:line];
    }

    free(ps);
    [pool release];
    return splitList;
}

- getListOfObjectsSplittedFrom:(NSPoint*)pArray :(int)iCnt
{   NSMutableArray      *splitList = nil;
    int                 i, cnt = 0;
    NSPoint             *ps = malloc((iCnt) * sizeof(NSPoint)), bufp;
    NSRect              bounds;
    float               dx, dy;
    NSAutoreleasePool   *pool;

    bounds = [self coordBounds];
    /* only important for horicontal and vertical lines! */
    bounds.origin.x    -= 15.0*TOLERANCE;
    bounds.origin.y    -= 15.0*TOLERANCE;
    bounds.size.width  += 30.0*TOLERANCE;
    bounds.size.height += 30.0*TOLERANCE;
    dx = p1.x - p0.x;
    dy = p1.y - p0.y;
    for (i=0; i<iCnt; i++)
        if ( pointOnLineClosestToPoint(p0, p1, pArray[i], &bufp) < (TOLERANCE*4.0)*(TOLERANCE*4.0) )
        /*if (( SqrDistPoints(p0, pArray[i]) >= SqrDistPoints(p1, pArray[i]) && NSPointInRect(pArray[i], bounds)
             && ((Diff(dy, 0.0)<TOLERANCE && Diff((pArray[i].y-p0.y), 0.0)<TOLERANCE )
                 || (Diff(dx, 0.0)<TOLERANCE && Diff((pArray[i].x-p0.x), 0.0)<TOLERANCE )
                 || (dy != 0 && Abs(dy)>=Abs(dx) && (pArray[i].y-p0.y) != 0
                     && Diff(dx/dy, (pArray[i].x-p0.x)/(pArray[i].y-p0.y))<TOLERANCE)
                 || (dx != 0 && Abs(dx)>Abs(dy) && (pArray[i].x-p0.x) != 0
                     && Diff(dy/dx, (pArray[i].y-p0.y)/(pArray[i].x-p0.x))<TOLERANCE)) )
           || ( SqrDistPoints(p0, pArray[i]) < SqrDistPoints(p1, pArray[i]) && NSPointInRect(pArray[i], bounds)
                && ((Diff(dy, 0.0)<TOLERANCE && Diff((pArray[i].y-p0.y), 0.0)<TOLERANCE )
                    || (Diff(dx, 0.0)<TOLERANCE && Diff((pArray[i].x-p0.x), 0.0)<TOLERANCE )
                    || (dy != 0 && Abs(dy)>=Abs(dx) && (pArray[i].y-p0.y) != 0
                        && Diff(dx/dy, (p1.x-pArray[i].x)/(p1.y-pArray[i].y))<TOLERANCE)
                    || (dx != 0 && Abs(dx)>Abs(dy) && (pArray[i].x-p0.x) != 0
                        && Diff(dy/dx, (p1.y-pArray[i].y)/(p1.x-pArray[i].x))<TOLERANCE)) ))*/
            ps[cnt++] = pArray[i];
//        else if ( !((Diff(pArray[i].x, p0.x)<TOLERANCE && Diff(pArray[i].y, p0.y)<TOLERANCE) ||
//                 (Diff(pArray[i].x, p1.x)<TOLERANCE && Diff(pArray[i].y, p1.y)<TOLERANCE)) )
//            printf("oohhhh");

    if (!cnt)
    {   free(ps);
        return nil;
    }
    splitList = [NSMutableArray array];
    pool = [NSAutoreleasePool new];

    cnt = removePointWithToleranceFromArray(p0, 5.0*TOLERANCE, ps, cnt);
    cnt = removePointWithToleranceFromArray(p1, 5.0*TOLERANCE, ps, cnt);

    cnt = vhfFilterPoints(ps, cnt, 10.0*TOLERANCE);
    sortPointArray(ps, cnt, p0);

    // correkt intersection points for horicontal/vertical lines
    // else we get no correct values in later calculations ! ! !
    if ( p0.x == p1.x )
    {   for ( i=0; i<cnt; i++ )
            ps[i].x = p0.x;
    }
    if ( p0.y == p1.y )
    {   for ( i=0; i<cnt; i++ )
            ps[i].y = p0.y;
    }

    for ( i=0; i<=cnt; i++ )
    {   VLine	*line = [VLine line];
        NSPoint	pv0, pv1;

        pv0 = (!i) ? p0 : ps[i-1];
        pv1 = (i>=cnt) ? p1 : ps[i];
        [line setWidth:width];
        [line setColor:color];
        [line setVertices:pv0 :pv1];
        [splitList addObject:line];
    }

    free(ps);
    [pool release];
    return splitList;
}

- (NSMutableArray*)getListOfObjectsSplittedAtPoint:(NSPoint)pt;
{   NSPoint	ptOnLine;

    pointOnLineClosestToPoint(p0, p1, pt, &ptOnLine);
    return [self getListOfObjectsSplittedFrom:&ptOnLine :1];
}

- (int)getIntersections:(NSPoint**)ppArray with:g
{   int	iCnt;

    if ([g isKindOfClass:[VPath class]] || [g isKindOfClass:[VGroup class]] ||
        [g isKindOfClass:[VPolyLine class]])
        iCnt = [g getIntersections:ppArray with:self];
    else if ([g isKindOfClass:[VLine class]])
    {	NSPoint	pv0, pv1;

        *ppArray = malloc((10) * sizeof(NSPoint));
        [g getVertices:&pv0 :&pv1];
        iCnt = [self intersectLine:*ppArray :pv0 :pv1];
    }
    else if ([g isKindOfClass:[VCurve class]])
    {	*ppArray = malloc((20) * sizeof(NSPoint));
        iCnt = [g intersectLine:*ppArray :p0 :p1];
    }
    else if ([g isKindOfClass:[VArc class]])
    {	*ppArray = malloc((20) * sizeof(NSPoint));
        iCnt = [g intersectLine:*ppArray :p0 :p1];
    }
    else if ([g isKindOfClass:[VRectangle class]])
        iCnt = [g getIntersections:ppArray with:self];
    else
    {   NSLog(@"VLine, intersection with unknown class!");
        *ppArray = NULL;
        return 0;
    }

    if (iCnt)
        sortPointArray(*ppArray, iCnt, p0);
    else
    {	free(*ppArray);
        *ppArray = NULL;
    }

    return iCnt;
}

- (float)sqrDistanceGraphic:g :(NSPoint*)pg1 :(NSPoint*)pg2
{
    if ([g isKindOfClass:[VLine class]])
    {	NSPoint	pv0, pv1;

        [g getVertices:&pv0 :&pv1];
        return [self sqrDistanceLine:pv0 :pv1 :pg1 :pg2];
    }
    else if ( [g isKindOfClass:[VPath     class]] || [g isKindOfClass:[VGroup     class]] ||
              [g isKindOfClass:[VPolyLine class]] || [g isKindOfClass:[VRectangle class]] ||
              [g isKindOfClass:[VCurve    class]] || [g isKindOfClass:[VArc       class]] )
        return [g sqrDistanceGraphic:self :pg2 :pg1];
    else
    {   NSLog(@"VLine, distance (with two nearest points) with unknown class!");
        return -1.0;
    }
    return -1.0;
}

- (float)sqrDistanceGraphic:g
{
    if ( [g isKindOfClass:[VPath     class]] || [g isKindOfClass:[VGroup     class]] ||
         [g isKindOfClass:[VPolyLine class]] || [g isKindOfClass:[VRectangle class]] ||
         [g isKindOfClass:[VCurve    class]] || [g isKindOfClass:[VArc       class]] )
        return [g sqrDistanceGraphic:self];
    else if ([g isKindOfClass:[VLine class]])
    {	NSPoint	pv0, pv1;

        [g getVertices:&pv0 :&pv1];
        return [self sqrDistanceLine:pv0 :pv1];
    }
    else
    {   NSLog(@"VLine, distance with unknown class!");
        return -1.0;
    }
    return -1.0;
}

- (float)distanceGraphic:g
{   float	distance;

    distance = [self sqrDistanceGraphic:g];
    return sqrt(distance);
}

- (id)clippedWithRect:(NSRect)rect
{   NSMutableArray	*clipList = [NSMutableArray array], *cList;
    NSPoint		iPoints[8], p, rp[4];
    int			iCnt = 0, i, j;
    VGroup		*group = [VGroup group];

    rp[0] = rect.origin;
    rp[1].x = rect.origin.x + rect.size.width; rp[1].y = rect.origin.y;
    rp[2].x = rect.origin.x + rect.size.width; rp[2].y = rect.origin.y + rect.size.height;
    rp[3].x = rect.origin.x; rp[3].y = rect.origin.y + rect.size.height;

    for (i=0; i<4; i++)
        iCnt += vhfIntersectLines(iPoints+iCnt, p0, p1, rp[i], (i+1<4) ? rp[i+1] : rp[0]);

    if (!(cList = [self getListOfObjectsSplittedFrom:iPoints :iCnt]))
        [clipList addObject:[[self copy] autorelease]];
    else
    {	for (j=0; j<(int)[cList count]; j++)
            [clipList addObject:[cList objectAtIndex:j]];
        [cList removeAllObjects];
    }

    for (i=0; i<(int)[clipList count];i++)
    {	[[clipList objectAtIndex:i] getPoint:&p at:0.5];
        if ( !NSPointInRect(p, rect) )
        {   [clipList removeObjectAtIndex:i];
            i--;
        }
    }

    [group setList:clipList];
    return group;
}

- (void)getPointBeside:(NSPoint*)point :(int)left :(float)dist
{   float	dx, dy, c;
    NSPoint	pM;

    [self getPoint:&pM at:0.4];
    dx = p1.x - p0.x;
    dy = p1.y - p0.y;
    c = sqrt(dx*dx+dy*dy);
    if ( left )
    {	point->x = pM.x - dy*dist/c;
        point->y = pM.y + dx*dist/c;
    }
    else
    {	point->x = pM.x + dy*dist/c;
        point->y = pM.y - dx*dist/c;
    }
}

- (BOOL)identicalWith:(VGraphic*)g
{   NSPoint	s2, e2;

    if ( ![g isKindOfClass:[VLine class]] )
        return NO;

    [g getPoint:0 :&s2];
    [g getPoint:3 :&e2];
    if ( (Diff(p0.x, s2.x) <= TOLERANCE && Diff(p0.y, s2.y) <= TOLERANCE &&
          Diff(p1.x, e2.x) <= TOLERANCE && Diff(p1.y, e2.y) <= TOLERANCE) ||
         (Diff(p0.x, e2.x) <= TOLERANCE && Diff(p0.y, e2.y) <= TOLERANCE &&
          Diff(p1.x, s2.x) <= TOLERANCE && Diff(p1.y, s2.y) <= TOLERANCE) )
        return YES;
    return NO;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [super encodeWithCoder:aCoder];
    //[aCoder encodeValuesOfObjCTypes:"{NSPoint=ff}{NSPoint=ff}", &p0, &p1];
    [aCoder encodePoint:p0];    // 2012-01-08
    [aCoder encodePoint:p1];
}
- (id)initWithCoder:(NSCoder *)aDecoder
{   int	version;

    [super initWithCoder:aDecoder];
    version = [aDecoder versionForClassName:@"VLine"];
    if ( version < 1 )
        [aDecoder decodeValuesOfObjCTypes:"{ff}{ff}", &p0, &p1];
    else
    {   //[aDecoder decodeValuesOfObjCTypes:"{NSPoint=ff}{NSPoint=ff}", &p0, &p1];
        p0 = [aDecoder decodePoint];    // 2012-01-08
        p1 = [aDecoder decodePoint];
    }

    [self setParameter];
    return self;
}

/* archiving with property list
 */
- (id)propertyList
{   NSMutableDictionary	*plist = [super propertyList];

    [plist setObject:propertyListFromNSPoint(p0) forKey:@"p0"];
    [plist setObject:propertyListFromNSPoint(p1) forKey:@"p1"];
    return plist;
}
- (id)initFromPropertyList:(id)plist inDirectory:(NSString *)directory
{
    [super initFromPropertyList:plist inDirectory:directory];
    p0 = pointFromPropertyList([plist objectForKey:@"p0"]);
    p1 = pointFromPropertyList([plist objectForKey:@"p1"]);
    [self setParameter];
    return self;
}


- (void)dealloc
{
    [super dealloc];
}

@end
