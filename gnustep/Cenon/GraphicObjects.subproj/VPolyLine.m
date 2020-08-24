/* VPolyLine.m
 * Object of connected lines, either open or closed
 *
 * Copyright (C) 2001-2012 by vhf interservice GmbH
 * Author:   Ilonka Fleischmann
 *
 * created:  2001-07-31
 * modified: 2012-07-17 (*pts = NULL, *iPts = NULL initialized, if(iPts free()))
 *           2011-08-25 (-contour:inlay:splitCurves: (w == 0.0 && width == 0.0) instead of !w)
 *           2010-07-22 (-scale width fixed, -transform added)
 *           2010-02-18 (exit editing with right mouse click)
 *           2008-12-01 (drar unfilled with stroke color)
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
#include "VLine.h" // until the rest of line is eliminated
#include "VPolyLine.h"
#include "VPath.h"
#include "HiddenArea.h"
#include "../App.h"
#include "../DocView.h"
#include "../DocWindow.h" // create:in:
#include "../Inspectors.h" // create:in:

@interface VPolyLine(PrivateMethods)
- (void)setParameter;
- (id)contourOpen:(float)w;
- (id)contour:(float)w inlay:(BOOL)inlay splitCurves:(BOOL)splitCurves;
@end

@implementation VPolyLine

/*
 */
static NSPoint orthPointAtBegOrEnd(id g, float r, int dirInd, BOOL end)
{   float	b;
    NSPoint	p, grad, orthP;

    if ( !end )	/* calc to beg */
    {	[g getPoint:0 :&p];			/* start point of object */
        grad = [g gradientAt:0.0];		/* gradient of start-point for outline object */
    }
    else
    {   p = [g pointWithNum:MAXINT];		/* end point of object */
        grad = [g gradientAt:1.0];		/* gradient of start-point for outline object */
    }
    if ( !(b = sqrt(grad.x*grad.x+grad.y*grad.y)) )
        orthP = p;
    else
    {   orthP.x = p.x + grad.y*r*dirInd/b;
        orthP.y = p.y - grad.x*r*dirInd/b;
    }
    return orthP;
}

static float angleBetweenGraphicsInStartOrEnd(id g1, id g2, BOOL end)
{   NSPoint	p, t1End, t2End, gradB, gradA;

    if ( !end )	/* calc to beg */
    {	[g1 getPoint:0 :&p];				/* start point of object */
        gradB = [g1 gradientAt:0.0];			/* gradient of start-point object */
        gradA = [g2 gradientAt:1.0];			/* gradient of end-point for object */
    }
    else
    {	p = [g1 pointWithNum:MAXINT];			/* end point of object */
        gradA = [g1 gradientAt:1.0];			/* gradient of start-point for outline object */
        gradB = [g2 gradientAt:0.0];			/* gradient of end-point for prev object */
    }
    t1End.x = p.x - gradA.x;
    t1End.y = p.y - gradA.y;
    t2End.x = p.x + gradB.x;
    t2End.y = p.y + gradB.y;
    return vhfAngleBetweenPoints(t1End, p, t2End);	/* get angle (ccw) on right side */
}

static NSPoint parallelPointbetweenObjects(id g1, id g2, float angle, float r, int dirInd, BOOL end)
{   NSPoint	p, gradA, gradB, pG, newP;
    double	a, b, c, nr, na;

    /* get gradients to calc start and end points of outline
     */
    if ( !end )
    {	[g1 getPoint:0 :&p];
        gradB = [g1 gradientAt:0.0];			/* gradient of start-point for outline object */
        gradA = [g2 gradientAt:1.0];			/* gradient of end-point for prev object */
    }
    else
    {	p = [g1 pointWithNum:MAXINT];
        gradA = [g1 gradientAt:1.0];			/* gradient of start-point for outline object */
        gradB = [g2 gradientAt:0.0];			/* gradient of end-point for prev object */
    }
    a = sqrt(gradA.x*gradA.x+gradA.y*gradA.y);
    b = sqrt(gradB.x*gradB.x+gradB.y*gradB.y);	/* our gradient is orthogonal to the average of both gradients */
    pG.x = gradA.y/a + gradB.y/b;
    pG.y = -(gradA.x/a + gradB.x/b);
    if ( !pG.x && !pG.y )
    {	pG.x = - gradA.y/a;
        pG.y = + gradA.x/a;
    }
    c = sqrt(pG.x*pG.x+pG.y*pG.y);		/* end point for outline object */
    ( angle < 360.0-angle ) ? (na = angle/2.0) : (na = (360.0-angle)/2.0);
    nr = r / Sin(na);			/* need correct distance */
    newP.x = p.x + pG.x*nr*dirInd/c;
    newP.y = p.y + pG.y*nr*dirInd/c;
    return newP;
}

/* This sets the class version so that we can compatibly read old objects out of an archive.
 */
+ (void)initialize
{
    [VPolyLine setVersion:2];
    return;
}

+ (VPolyLine*)polyLine
{
    return [[[VPolyLine allocWithZone:[self zone]] init] autorelease];
}

/* initialize
 */
- init
{
    [self setParameter];
    ptsData = [[NSMutableData dataWithLength:maxcount * sizeof(NSPoint)] retain];
    ptslist = [ptsData mutableBytes];
    fillColor = [[NSColor blackColor] retain];
    endColor = [[NSColor blackColor] retain];
    radialCenter = NSMakePoint(0.5, 0.5);
    graduateList = nil;
    graduateDirty = YES;
    coordBounds = NSZeroRect;
    return [super init];
}

/* deep copy
 *
 * created:  2001-02-15
 * modified: 
 */
- copy
{   VPolyLine   *polyline = [[VPolyLine allocWithZone:[self zone]] init];
    int         i;

    [polyline setSelected:isSelected];
    [polyline setFilled:filled];
    [polyline setWidth:width];
    [polyline setColor:color];
    [polyline setFillColor:fillColor];
    [polyline setEndColor:endColor];
    [polyline setGraduateAngle:graduateAngle];
    [polyline setStepWidth:stepWidth];
    [polyline setRadialCenter:radialCenter];
    [polyline setLocked:NO];
    for (i=0; i<count; i++)
        [polyline addPoint:ptslist[i]];
    return polyline;
}

- (BOOL)isPathObject	{ return YES; }

/*
 * created: 25.09.95
 * purpose: initializes all the stuff needed after a -read:
 */
- (void)setParameter
{
    count = 0;
    maxcount = 3;
    selectedKnob = -1; 
    filled = 0;
    graduateAngle = 0.0;
    stepWidth = 7.0;
}

- (NSString*)description
{
    return [NSString stringWithFormat:@"VPolyLine: %i pts", count];
}

- (NSString*)title
{
    return @"Polyline";
}

#define AngleNotSmallEnoughPL(dir, w, angle) ((dir && w > 0 && angle > 150.0)  || (dir && w < 0 && angle < 210.0) || \
    (!dir && w < 0 && angle > 150.0) || (!dir && w > 0 && angle < 210.0))
#define NeedArcPL(dir, w, angle)	((dir && w > 0 && angle > 180.5)  || (dir && w < 0 && angle < 179.5) || \
    (!dir && w < 0 && angle > 180.5) || (!dir && w > 0 && angle < 179.5))
#define SmallAnglePL(dir, w, angle )	((dir && w > 0 && angle < 95.5) || (dir && w < 0 && angle > 265.5) || \
    (!dir && w < 0 && angle < 95.5) || (!dir && w > 0 && angle > 265.5))
- parallelObject:(NSPoint)begOr :(NSPoint)endOr :(NSPoint)beg :(NSPoint)end
{   VPath	*path;
    int		i, dir = 1; // right -> 1 left -> 0
    float	r = sqrt(SqrDistPoints(ptslist[0], begOr)); // the amount of growth
    float	dirInd=1.0, bAngle = 180.0, eAngle = 180.0, w = r*2.0, dx, dy, dx2, dy2;
    BOOL	inlay = 0;
    VLine	*gThis = [VLine line], *gPrev = [VLine line], *gNext = [VLine line];

    dx = ptslist[1].x - ptslist[0].x;
    dy = ptslist[1].y - ptslist[0].y;
    dx2 = begOr.x - ptslist[0].x;
    dy2 = begOr.y - ptslist[0].y;
    if ( dy > 0.0 && dx)
        dir = ( dx2 > 0 ) ? 1 : 0;
    else if ( dy < 0 && dx)
        dir = ( dx2 < 0 ) ? 1 : 0;
    else if ( dx )// && dy == 0
        dir = ( (dx > 0 && dy2 < 0) || (dx < 0 && dy2 > 0) ) ? 1 : 0;
    else // dx == 0
        dir = ( (dy > 0 && dx2 > 0) || (dy < 0 && dx2 < 0) ) ? 1 : 0;
    dirInd  = ( dir ) ? 1.0 : -1.0;			/* 1 = ccw, 0 = cw */

    path = [VPath path];
    [path setColor:color];

    /* what we do here:
     * step through elements of polyline
     * calculate start, end points for outline-elements in a distance to path (inside/outside)
     * calculate parallel elements through start and end points
     * we have to calculate each sub path separately, so we put them in real sub paths
     */

    // first object -> only end point
    // last object -> only start point

    /* walk through polyline */
    for ( i=0; i<count-1; i++ )
    {	id      g;
        NSPoint begO, endO,     /* start and endpoint of contour-object, if we don't add an arc (O = outline) */
                begOrth, endOrth, /* start and endpoint of contour-object, if we add an arc (orthogonal points) */
                center;			/* center point of arc if needed */
        int     needArc = 0;	/* wether we need an arc to build correct contour around current edge */
        BOOL    calcBegOWithCut = 0, calcEndOWithCut = 0;

        [gThis setVertices:ptslist[i] :ptslist[i+1]];
        if ( !i ) // gThis is first object -> no gPrev ! begO = beg
        {   begO = beg;
            begOrth = orthPointAtBegOrEnd(gThis, r, dirInd, 0);		/* beg orthogonal to beg of gThis */
        }
        else
        {   [gPrev setVertices:ptslist[i-1] :ptslist[i]];

            bAngle = angleBetweenGraphicsInStartOrEnd(gThis, gPrev, 0);
            begOrth = orthPointAtBegOrEnd(gThis, r, dirInd, 0);		/* beg orthogonal to beg of gThis */

            /* here we need to correct the hard edges for inlayworks into smoot edges - so it fits well
             * the cutting point of the opposite (inside) parallel graphics is our centerpoint of arc (added at end)
             * we move this point 2 times in our direction -> this is our begO
             */
            if ( NeedArcPL(dir, w, bAngle) && inlay )
            {   VGraphic    *pG, *thG;
                NSPoint     bPrevOrth, ePrevOrth, bThisOrth, eThisOrth, *iPts; /* points in opposite(inside) direction !*/
                int         iCnt;

                bPrevOrth = orthPointAtBegOrEnd(gPrev, r, dirInd*-1.0, 0);
                ePrevOrth = orthPointAtBegOrEnd(gPrev, r, dirInd*-1.0, 1);
                /* get parallel object to gPrev and gThis */
                pG = [gPrev parallelObject:bPrevOrth :ePrevOrth :bPrevOrth :ePrevOrth];
                bThisOrth = orthPointAtBegOrEnd(gThis, r, dirInd*-1.0, 0);
                eThisOrth = orthPointAtBegOrEnd(gThis, r, dirInd*-1.0, 1);
                thG = [gThis parallelObject:bThisOrth :eThisOrth :bThisOrth :eThisOrth];

                if ( pG && thG && (iCnt = [pG getIntersections:&iPts with:thG]) == 1 )
                {   NSMutableArray	*splitListThis=nil, *splitListPrev=nil;

                    /* tile graphic */
                    splitListThis = [thG getListOfObjectsSplittedFrom:iPts :iCnt];
                    splitListPrev = [pG getListOfObjectsSplittedFrom:iPts :iCnt];

                    /* add tiled graphics and notice */
                    if ( [splitListThis count] == 2 && [splitListPrev count] == 2 )
                    {   thG = [splitListThis objectAtIndex:1];
                        pG = [splitListPrev objectAtIndex:0];
                        bAngle = angleBetweenGraphicsInStartOrEnd(thG, pG, 0);
                        begO = orthPointAtBegOrEnd(thG, 2.0*r, dirInd, 0);
                    }
                    else
                        begO = begOrth;
                    if (iPts)
                        free(iPts);
                }
                else
                    begO = begOrth;
            }
            /* in this cases we need an arc between the graphics (added only at end points)
             * angle is greater than 180 at correction side
             */
            else if ( NeedArcPL(dir, w, bAngle) )
                begO = begOrth;
            else if ( ([gThis isKindOfClass:[VLine class]] && [gPrev isKindOfClass:[VLine class]])
                     || AngleNotSmallEnoughPL(dir, w, bAngle) )
                begO = parallelPointbetweenObjects(gThis, gPrev, bAngle, r, dirInd, 0);
            else
                calcBegOWithCut=1; // begO = parallelPointbetweenObjects(gThis, gPrev, bAngle, r, dirInd, 0);

            /* cut of prevG(parallel) with gThis(parallel) is begO
             */
            if ( calcBegOWithCut || SmallAnglePL(dir, w, bAngle) )
            {   VGraphic    *pG, *thG;
                NSPoint     bPrevOrth, ePrevOrth, *iPts = NULL;
                int         iCnt;

                bPrevOrth = orthPointAtBegOrEnd(gPrev, r, dirInd, 0);
                ePrevOrth = orthPointAtBegOrEnd(gPrev, r, dirInd, 1);
                /* get parallel object to gPrev and gThis */
                pG = [gPrev parallelObject:bPrevOrth :ePrevOrth :bPrevOrth :ePrevOrth];
                endOrth = orthPointAtBegOrEnd(gThis, r, dirInd, 1);
                thG = [gThis parallelObject:begOrth :endOrth :begOrth :endOrth];

                if ( pG && thG && (iCnt = [pG getIntersections:&iPts with:thG])==1 )
                    begO = iPts[0];
                else
                    begO = begOrth;
                if (iPts)
                    free(iPts);
            }
        }

        if ( i+1 == count-1 ) // gThis is last object -> no gNext ! endO = end
        {   endO = end;
            endOrth = orthPointAtBegOrEnd(gThis, r, dirInd, 1);		/* beg orthogonal to beg of gThis */
        }
        else
        {   [gNext setVertices:ptslist[i+1] :ptslist[i+2]];

            eAngle = angleBetweenGraphicsInStartOrEnd(gThis, gNext, 1);
            endOrth = orthPointAtBegOrEnd(gThis, r, dirInd, 1);		/* beg orthogonal to beg of gThis */

            /* here we need to correct the hard edges for inlayworks into smoot edges - so it fits well
             * the cutting point of the opposite (inside) parallel graphics is our centerpoint of arc
             * (added here at end)
             * we move this point 2 times in our direction -> this is our begO
             */
            if ( NeedArcPL(dir, w, eAngle) && inlay )
            {   VGraphic    *nG, *thG;
                NSPoint     bNextOrth, eNextOrth, bThisOrth, eThisOrth, *iPts; /* points in opposite(inside) direction !*/
                int         iCnt;

                bNextOrth = orthPointAtBegOrEnd(gNext, r, dirInd*-1.0, 0);
                eNextOrth = orthPointAtBegOrEnd(gNext, r, dirInd*-1.0, 1);
                /* get parallel object to gNext and gThis */
                nG = [gNext parallelObject:bNextOrth :eNextOrth :bNextOrth :eNextOrth];
                bThisOrth = orthPointAtBegOrEnd(gThis, r, dirInd*-1.0, 0);
                eThisOrth = orthPointAtBegOrEnd(gThis, r, dirInd*-1.0, 1);
                thG = [gThis parallelObject:bThisOrth :eThisOrth :bThisOrth :eThisOrth];

                if ( nG && thG && (iCnt = [nG getIntersections:&iPts with:thG]) == 1 )
                {   NSMutableArray	*splitListThis = nil, *splitListNext = nil;

                    /* tile graphic */
                    splitListThis = [thG getListOfObjectsSplittedFrom:iPts :iCnt];
                    splitListNext = [nG getListOfObjectsSplittedFrom:iPts :iCnt];

                    /* add tiled graphics and notice */
                    if ( [splitListThis count] == 2 && [splitListNext count] == 2 )
                    {   thG = [splitListThis objectAtIndex:0];
                        nG = [splitListNext objectAtIndex:1];
                        eAngle = angleBetweenGraphicsInStartOrEnd(thG, nG, 1);
                        endO = orthPointAtBegOrEnd(thG, 2.0*r, dirInd, 1);
                        center = iPts[0]; // need this point for our arc
                    }
                    else
                    {   endO = endOrth;
                        center = [gThis pointWithNum:MAXINT];
                    }
                    if ( iPts )
                        free(iPts);
                }
                else
                {   endO = endOrth;
                    center = [gThis pointWithNum:MAXINT];
                }
                needArc = 1;
            }
            else if ( NeedArcPL(dir, w, eAngle) )
            {   endO = endOrth;
                needArc = 1;
            }
            else if ( ([gThis isKindOfClass:[VLine class]] && [gNext isKindOfClass:[VLine class]])
                     || AngleNotSmallEnoughPL(dir, w, eAngle) )
                endO = parallelPointbetweenObjects(gThis, gNext, eAngle, r, dirInd, 1);
            else
                calcEndOWithCut = 1; // endO = parallelPointbetweenObjects(gThis, gNext, eAngle, r, dirInd, 1);

            /* intersect parallel of gThis with parallel of gNext. Intersection point: begO
             */
            if ( calcEndOWithCut || SmallAnglePL(dir, w, eAngle) )
            {   VGraphic    *nG, *thG;
                NSPoint     bNextOrth, eNextOrth, *iPts = NULL;
                int         iCnt;

                bNextOrth = orthPointAtBegOrEnd(gNext, r, dirInd, 0);
                eNextOrth = orthPointAtBegOrEnd(gNext, r, dirInd, 1);
                /* get parallel object to gNext and gThis */
                nG  = [gNext parallelObject:bNextOrth :eNextOrth :bNextOrth :eNextOrth];
                thG = [gThis parallelObject:begOrth   :endOrth   :begOrth   :endOrth];

                if ( nG && thG && (iCnt = [thG getIntersections:&iPts with:nG])==1 )
                    endO = iPts[0];
                else
                {   needArc = 2;	/* here we calc edge orhtogonal with an arc */
                    endO = endOrth;
                }
                if ( iPts )
                    free(iPts);
            }
        }
#if 0
// show points, display in e2Output->setDisplayGraphic muss auskommentiert sein!
            [[VGraphic currentView] lockFocus];
            [[NSColor blueColor] set];
            CROSS_45_s(begO);
            [[NSColor greenColor] set];
            CROSS_90_s(endO);
            [[NSColor blackColor] set];
            [[VGraphic currentView] unlockFocus];
            [[[VGraphic currentView] window] flushWindow];
#endif
        /* now we can calc our parallel object of gThis */
        if ( (g = [gThis parallelObject:begOrth :endOrth :begO :endO]) )	/* build parallel objects */
            [[path list] addObject:g];

        /* calulate arc to close ends
            * if we have to add an arc we use the end of gThis as center,
            * endO as start point, new angle is calculated
            */
        if ( needArc )
        {   VArc	*arc = [VArc arc];
            float	newA;

            [arc setWidth:[gThis width]];
            [arc setColor:[gThis color]];
            if ( needArc == 2 )
            {   ( eAngle > 360.0-eAngle ) ? (newA = (360-eAngle)+180.0) : (newA = eAngle+180.0);
                if ( (!dir && w > 0 && eAngle > 180.0) || (dir && w < 0 && eAngle > 180.0) )
                    newA *= -1.0;
            }	
            else
            {   /* eAngle > 180 */
                ( eAngle > 360.0-eAngle ) ? (newA = eAngle-180.0) : (newA = (360.0-eAngle)-180.0);
                if ( (!dir && w > 0 && eAngle < 180.0) || (dir && w < 0 && eAngle < 180.0) )
                    newA *= -1.0;	/* cw */
            }
            if ( !inlay || needArc == 2 )
                center = [gThis pointWithNum:MAXINT]; /* end point of object is arc center - with out smoot edges */
            [arc setCenter:center start:endO angle:newA];
            [[path list] addObject:arc];
        }
    }

//    if ( removeLoops )
//        [self removeIntersectionsInSubpaths:path :directionArray :insideArray :w];

    // if no arcs ar inside path -> we build a polyline ?

    return path;
}

/* create
 * modified: 2010-02-18 (exit with right mouse click)
 */
#define CREATEEVENTMASK NSLeftMouseDraggedMask|NSLeftMouseDownMask|NSLeftMouseUpMask|NSRightMouseDownMask|NSPeriodicMask
- (BOOL)create:(NSEvent *)event in:(DocView*)view
{   NSRect	viewBounds, gridBounds, drawBounds;
    NSPoint	start, last, gridPoint, drawPoint, lastPoint, hitPoint, addedDrawPoint, goodDrawPoint;
    id		window = [view window];
    VLine	*drawLineGraphic, *drawSnapLine;
    BOOL	ok = YES, dragging = NO, hitEdge = NO;
    float	grid = 1.0 / [view scaleFactor];	// minimum accepted length
    int		windowNum = [event windowNumber];
    BOOL	inTimerLoop = NO;

    [[(App*)NSApp inspectorPanel] loadGraphic:self];	// set the values of the inspector to self

    /* get start location, convert window to view coordinates */
    start = [view convertPoint:[event locationInWindow] fromView:nil];
    hitPoint = start;
    hitEdge = [view hitEdge:&hitPoint spare:self];	// snap to point
    gridPoint = [view grid:start];			// set on grid
    if ( hitEdge &&
         ((gridPoint.x == start.x && gridPoint.y == start.y)  ||
          (SqrDistPoints(hitPoint, start) < SqrDistPoints(gridPoint, start))) )
        start = hitPoint; // we took the nearer one if we got a hitPoint
    else
        start = gridPoint;
    viewBounds = [view visibleRect];			// get the bounds of the view
    [view lockFocus];					// and lock the focus on view

    [self addPoint:start];
    drawLineGraphic = [VLine lineWithPoints:start :start];
    [drawLineGraphic setColor:[NSColor lightGrayColor]];
    drawSnapLine = [VLine lineWithPoints:start :start];
    gridBounds = [self extendedBoundsWithScale:[view scaleFactor]];

    addedDrawPoint = goodDrawPoint = lastPoint = last = start;

    event = [NSApp nextEventMatchingMask:CREATEEVENTMASK untilDate:[NSDate distantFuture]
                                  inMode:NSEventTrackingRunLoopMode dequeue:YES];
    StartTimer(inTimerLoop);
    /* now entering the tracking loop
     */
    while ( ok )
    {
        if ( count > 1 )
            event = [NSApp nextEventMatchingMask:CREATEEVENTMASK untilDate:[NSDate distantFuture]
                                          inMode:NSEventTrackingRunLoopMode dequeue:YES];

        while ( ((!dragging && ([event type] != NSLeftMouseDown && [event type] != NSRightMouseDown)) ||
                 (dragging && [event type] != NSLeftMouseUp)) &&
                [event type] != NSAppKitDefined && [event type] != NSSystemDefined )
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
                     (Diff(addedDrawPoint.x, drawPoint.x) > 3.0 ||
                      Diff(addedDrawPoint.y, drawPoint.y) > 3.0) )
                    dragging = YES;
                else if ( (dragging) && ([event type] != NSLeftMouseDragged) && ([event type] != NSPeriodic) )
                    dragging = NO;

                /* if user is dragging we scroll the view */
                if (dragging)
                {   [view scrollPointToVisible:drawPoint];
                    viewBounds = [view bounds];
                }
                /* fix position to grid */
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

                [drawLineGraphic setVertices:last :drawPoint];
                [drawSnapLine setVertices:last :gridPoint];

                drawBounds = [drawLineGraphic extendedBoundsWithScale:[view scaleFactor]];
                gridBounds = [drawSnapLine extendedBoundsWithScale:[view scaleFactor]];
                /* the united rect of the two rects we need to redraw the view */
                gridBounds = NSUnionRect(drawBounds, gridBounds);

                /* if line is not inside view we set it invalid */
                if ( NSContainsRect(viewBounds, gridBounds) )
                {   [drawLineGraphic drawWithPrincipal:view];
                    [drawSnapLine drawWithPrincipal:view];
                    goodDrawPoint = drawPoint;
                }
                else
                    drawPoint = gridPoint = NSMakePoint(-1.0, -1.0);
                [self drawWithPrincipal:view];

                [window flushWindow];
            }
            event = [NSApp nextEventMatchingMask:CREATEEVENTMASK untilDate:[NSDate distantFuture]
                                          inMode:NSEventTrackingRunLoopMode dequeue:YES];
        }
        last = gridPoint;

        if ( !NSPointInRect(ptslist[count-1], viewBounds) )
            ok = NO;
        else if ( fabs(ptslist[count-1].x-gridPoint.x) <= grid &&
                  fabs(ptslist[count-1].y-gridPoint.y) <= grid )
            ok = NO;
        else if ( (!dragging && ([event type]==NSLeftMouseDown || [event type]==NSRightMouseDown)) ||
                  ( dragging &&  [event type]==NSLeftMouseUp) )
        {
            if ([event clickCount] > 1 || [event windowNumber] != windowNum)	// double click or outside window
                ok = NO;
            else
                ok = NSMouseInRect(gridPoint, viewBounds , NO);
        }
        else
            ok = NO;

        if (ok)
        {   [self addPoint:gridPoint];
            addedDrawPoint = goodDrawPoint;
        }
        if ( [event type] == NSRightMouseDown || dragging )
            break;
    }
    StopTimer(inTimerLoop);

    last = gridPoint;

    if ( fabs(ptslist[count-1].x-ptslist[count-2].x) <= grid &&
         fabs(ptslist[count-1].y-ptslist[count-2].y) <= grid )
    {
        if ( count-1 >= 2 ) // ok
        {   ok = YES;
            [self removePointWithNum:count-1];
        }
        else
            ok = NO;
    }
    else if ( (!dragging && ([event type]==NSLeftMouseDown || [event type]==NSRightMouseDown)) ||
               (dragging && [event type]==NSLeftMouseUp) )
    {	//if ([event clickCount] > 1 || [event windowNumber] != windowNum)	// double click or outside window
        {   int	i;

            for (i=count-1; i>=0; i--)
            {
                if ( !NSPointInRect(ptslist[count-1], viewBounds))
                    [self removePointWithNum:count-1];
                else break;
            }
            if ( count > 1 || [event type]==NSRightMouseDown )
                ok = YES;
            else
                ok = NO;
        }
//        else ok = NSMouseInRect(gridPoint , viewBounds , NO);
    }

    if ( [event type] == NSAppKitDefined || [event type] == NSSystemDefined )
        ok = NO;

    [view unlockFocus];

    /* we duplicate the last click which ends the line,
     * so we can directly execute user actions in Tool-Panel etc.
     */
    if ([event windowNumber] != windowNum)
    {   NSEvent	*eventup = [NSEvent mouseEventWithType:NSLeftMouseUp
                                              location:[event locationInWindow]
                                         modifierFlags:[event modifierFlags]
                                             timestamp:[event timestamp]
                                          windowNumber:[event windowNumber]
                                               context:[event context]
                                           eventNumber:[event eventNumber]
                                            clickCount:1 pressure:[event pressure]];

        [window postEvent:eventup atStart:1];	// up
        [window postEvent:event atStart:1];	// down
    }
    if ( !ok )
    {
        /* selection of last line is done in mouseDown: by hit of nonselected objects */
        [view display];
        return NO;
    }

    dirty = YES;
    //[view cacheGraphic:self];	// add to graphic cache

    return YES;
}
- (int)ptsCount { return count; }

- (BOOL)filled { return filled; }

- (void)setFilled:(BOOL)flag
{
    if (flag && count)
    {
        if ( Diff(ptslist[0].x, ptslist[count-1].x) || Diff(ptslist[0].y, ptslist[count-1].y) )
        {
            if ( count+1 >= maxcount )
            {   [ptsData increaseLengthBy:10*sizeof(NSPoint)];
                ptslist = [ptsData mutableBytes];
                maxcount += 10;
            }
            ptslist[count++] = ptslist[0];
        }
        [self setDirectionCCW:[self isDirectionCCW]];
    }
    filled = flag;
    dirty = YES;
    graduateDirty = YES;
}

- (void)setFillColor:(NSColor*)col
{
    if (fillColor) [fillColor release];
    fillColor = [col retain];
    dirty = YES;
    graduateDirty = YES;
}
- (NSColor*)fillColor			{ return fillColor; }

- (void)setEndColor:(NSColor*)col
{
    if (endColor) [endColor release];
    endColor = [col retain];
    dirty = YES;
    graduateDirty = YES;
}
- (NSColor*)endColor                { return endColor; }

- (void)setGraduateAngle:(float)a   { graduateAngle = a; dirty = YES; graduateDirty = YES; }
- (float)graduateAngle              { return graduateAngle; }

- (void)setStepWidth:(float)sw      { stepWidth = sw; dirty = YES; graduateDirty = YES; }
- (float)stepWidth                  { return stepWidth; }

- (void)setRadialCenter:(NSPoint)rc { radialCenter = rc; dirty = YES; graduateDirty = YES; }
- (NSPoint)radialCenter             { return radialCenter; }

- (BOOL)closed
{   NSPoint p0 = ptslist[0], p1 = ptslist[count-1];

    if ( Diff(p0.x, p1.x) < TOLERANCE && Diff(p0.y, p1.y) < TOLERANCE )
        return YES;
    return NO;
}

/* set our vertices
 */
- (void)addPoint:(NSPoint)p
{
    if ( count+1 >= maxcount )
    {   [ptsData increaseLengthBy:10*sizeof(NSPoint)];
        ptslist = [ptsData mutableBytes];
        maxcount += 10;
    }
    ptslist[count++] = p;
    // first and last point must be
    if ( count > 2 && SqrDistPoints(ptslist[count-2], ptslist[count-1]) < 0.001*TOLERANCE )
    {   ptslist[count-2] = ptslist[count-1];
        count--;
    }
    // remove first two near points
    if ( count == 3 && SqrDistPoints(ptslist[0], ptslist[1]) < 0.001*TOLERANCE )
    {   ptslist[1] = ptslist[2];
        count--;
    }
    coordBounds = NSZeroRect;
    dirty = graduateDirty = YES;
}

- (NSPoint)nearestPointInPtlist:(int*)pt_num distance:(float*)distance toPoint:(NSPoint)pt
{   int		i;
    NSPoint	cpt = NSZeroPoint, tpt;

    *distance = MAXCOORD;
        
    /* search nearest line to pt */
    for (i=0; i<count-1; i++)
    {	float	dist;

        if ((dist=pointOnLineClosestToPoint(ptslist[i], ptslist[i+1], pt, &tpt)) <= *distance)
        {   cpt = tpt;
            *pt_num = i;
            *distance = dist;
        }
    }
    return cpt;
}
- (VGraphic*)addPointAt:(NSPoint)pt
{   int			splitI = -1;
    NSPoint		cpt;
    float		distance=MAXCOORD;

    cpt = [self nearestPointInPtlist:&splitI distance:&distance toPoint:pt];

    if ((Diff(ptslist[splitI].x, cpt.x) > TOLERANCE || Diff(ptslist[splitI].y, cpt.y) > TOLERANCE) &&
        (Diff(ptslist[splitI+1].x, cpt.x) > TOLERANCE || Diff(ptslist[splitI+1].y, cpt.y) > TOLERANCE))
    {   int	i;

        selectedKnob = splitI+1;

        if ( count+1 >= maxcount )
        {   [ptsData increaseLengthBy:10*sizeof(NSPoint)];
            ptslist = [ptsData mutableBytes];
            maxcount += 10;
        }

        for (i=count-1; i>splitI; i--)
            ptslist[i+1] = ptslist[i];
        ptslist[splitI+1] = cpt;
        count++;

        coordBounds = NSZeroRect;
        dirty = YES;
        graduateDirty = YES;
    }
    else
        return nil;

    return self;
}
- (void)addPoint:(NSPoint)pt atNum:(int)pt_num
{   int	i;

    if ( count+1 >= maxcount )
    {   [ptsData increaseLengthBy:10*sizeof(NSPoint)];
        ptslist = [ptsData mutableBytes];
        maxcount += 10;
    }

    selectedKnob = pt_num;

    for (i=count-1; i>=pt_num; i--)
        ptslist[i+1] = ptslist[i];
    ptslist[pt_num] = pt;
    count++;

    if ( filled )
    {   if (!pt_num )
            ptslist[count-1] = ptslist[0];
        else if ( pt_num >= count-1 )
            ptslist[0] = ptslist[count-1];
    }
    coordBounds = NSZeroRect;
    dirty = YES;
    graduateDirty = YES;
}

- (BOOL)removePoint:(NSPoint)pt;
{   int i;

    for (i=0; i<count; i++)
    {   if ( Diff(pt.x, ptslist[i].x) <= TOLERANCE && Diff(pt.y, ptslist[i].y) <= TOLERANCE )
        {
            [self removePointWithNum:i];
            coordBounds = NSZeroRect;
            dirty = YES;
            graduateDirty = YES;
            return YES;
        }
    }
    return NO;
}

- (BOOL)removePointWithNum:(int)pt_num
{   int	i;

    if ( count <= pt_num )
        pt_num = count-1;
    if ( selectedKnob == pt_num )
        selectedKnob = -1;

    for (i=pt_num; i<count-1; i++)
        ptslist[i] = ptslist[i+1];
    count--;

    if (!count)
        return NO; // hole graphic will removed in DocView.m -delete

    if ( filled && !pt_num )
        ptslist[count-1] = ptslist[0];
    coordBounds = NSZeroRect;
    dirty = YES;
    graduateDirty = YES;
    return YES;
}

- (void)truncate
{
    [ptsData setLength:count*sizeof(NSPoint)];
    maxcount = count;
}

- (float)length
{   int		i;
    float	len = 0;

    for (i=0; i<count-1; i++)
        len += sqrt(SqrDistPoints(ptslist[i], ptslist[i+1]));
    return len;
}

/* returns the endpoints of an open path
 */
- (void)getEndPoints:(NSPoint*)p1 :(NSPoint*)p2
{
    *p1 = ptslist[0];
    *p2 = ptslist[count-1];
}

/* created:   17.03.96
 * modified:
 * parameter: p  the point
 *            t  0 <= t <= 1
 * purpose:   get a point on the line at t
 */
- (NSPoint)pointAt:(float)t
{
    if (!t)
        return ptslist[0];
    else if ( t == 1.0 )
        return ptslist[count-1];
    else
    {	float	dx = ptslist[1].x - ptslist[0].x, dy = ptslist[1].y - ptslist[0].y;
        return NSMakePoint( ptslist[0].x + dx * t, ptslist[0].y + dy * t );
    }
}

/* created: 2003-06-20
 */
- (void)setDirectionCCW:(BOOL)ccw
{
    if ( ccw != [self isDirectionCCW] )
        [self changeDirection];
    isDirectionCCW = ccw;
}

/*
 * changes the direction of the line p1<->p2
 */
- (void)changeDirection
{   NSPoint	pts[count];
    int		i, cnt = 0;

    for (i=count-1; i>=0; i--)
        pts[cnt++] = ptslist[i];

    for (i=0; i<cnt; i++)
        ptslist[i] = pts[i];

    isDirectionCCW = (isDirectionCCW) ? 0 : 1;
}

/* created: 04.01.95
 * purpose: return the gradient (delta x, y, z) of the line at t
 */
- (NSPoint)gradientAt:(float)t
{   NSPoint	p;

    if (!t)
    {   p.x = ptslist[1].x - ptslist[0].x;
        p.y = ptslist[1].y - ptslist[0].y;
    }
    else
    {   p.x = ptslist[count-1].x - ptslist[count-2].x;
        p.y = ptslist[count-1].y - ptslist[count-2].y;
    }
    return p;
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

/* created:   1995-10-21
 * modified:  2006-01-16
 * purpose:   draw the graphic rotated around cp
 */
- (void)drawAtAngle:(float)angle withCenter:(NSPoint)cp in:view
{   NSBezierPath	*bPath = [NSBezierPath bezierPath];
    int			i;

    [color set];
    [bPath setLineWidth:1.0/[view scaleFactor]];
    [bPath moveToPoint:vhfPointRotatedAroundCenter(ptslist[0], -angle, cp)];
    for (i=1; i<count; i++)
        [bPath lineToPoint:vhfPointRotatedAroundCenter(ptslist[i], -angle, cp)];
    [bPath stroke];
}

/* created:   1995-10-21
 * modified:  2002-12-04
 * purpose:   rotate the graphic around cp
 */
- (void)setAngle:(float)angle withCenter:(NSPoint)cp
{   int	i;

    if (filled)
    {   graduateAngle -= angle;
        if (graduateAngle < 0.0)
            graduateAngle += 360.0;
        if (graduateAngle > 360.0)
            graduateAngle -= 360.0;
        vhfRotatePointAroundCenter(&radialCenter, NSMakePoint(0.5, 0.5), -angle);
        if (radialCenter.x > 1.0) radialCenter.x = 1.0;
        if (radialCenter.x < 0.0) radialCenter.x = 0.0;
        if (radialCenter.y > 1.0) radialCenter.y = 1.0;
        if (radialCenter.y < 0.0) radialCenter.y = 0.0;
        graduateDirty = YES;
    }
    for (i=0; i<count; i++)
        ptslist[i] = vhfPointRotatedAroundCenter(ptslist[i], -angle, cp);
    coordBounds = NSZeroRect;
    dirty = YES;
    if (!graduateDirty && graduateList)
    {
        for (i=[graduateList count]-1; i>=0; i--)
            [(VGraphic*)[graduateList objectAtIndex:i] setAngle:angle withCenter:cp];
    }
}

- (void)transform:(NSAffineTransform*)matrix
{   int     i;
    NSSize  size = NSMakeSize(width, width);

    size = [matrix transformSize:size];
    width = (Abs(size.width) + Abs(size.height)) / 2;
    for (i=0; i<count; i++)
        ptslist[i] = [matrix transformPoint:ptslist[i]];
    coordBounds = NSZeroRect;
    dirty = graduateDirty = YES;
}

- (void)scale:(float)x :(float)y withCenter:(NSPoint)cp
{   int	i;

    width *= (Abs(x)+Abs(y))/2.0;
    for (i=0; i<count; i++)
    {   ptslist[i].x = ScaleValue(ptslist[i].x, cp.x, x);
        ptslist[i].y = ScaleValue(ptslist[i].y, cp.y, y);
    }
    coordBounds = NSZeroRect;
    dirty = graduateDirty = YES;
}

- (void)mirrorAround:(NSPoint)p
{   int	i;

    for (i=0; i<count; i++)
        ptslist[i].y = p.y - (ptslist[i].y - p.y);
    coordBounds = NSZeroRect;
    dirty = YES;
    if (!graduateDirty && graduateList)
    {
        for (i=[graduateList count]-1; i>=0; i--)
            [(VGraphic*)[graduateList objectAtIndex:i] mirrorAround:p];
    }
}

- (VPath*)pathRepresentation
{   VPath	*pathG = [VPath path];
    VLine	*line;
    int		i;

    [pathG setDirectionCCW:[self isDirectionCCW]];

    for (i=0; i<count-1; i++)
    {
        line = [VLine line];
        [line setVertices:ptslist[i] :ptslist[i+1]];
        [line setColor:color];
        [[pathG list] addObject:line];
    }
    [pathG setFilled:filled optimize:NO]; // must set filled first else fillColor become color
    [pathG setWidth:width]; // must set width first else color become fillColor
    [pathG setColor:color];
    [pathG setFillColor:fillColor];
    [pathG setEndColor:endColor];
    [pathG setGraduateAngle:graduateAngle];
    [pathG setRadialCenter:radialCenter];
    [pathG setStepWidth:stepWidth];

    return pathG;
}

/* created: 2003-07-10
 * return YES if p is inside us (we have to be closed)
 */
- (BOOL)isPointInside:(NSPoint)p
{   int		i, cnt, leftCnt = 0, ptsCnt = Min(100, count+1);
    NSPoint	p0, p1, *pts = malloc(ptsCnt * sizeof(NSPoint));
    NSRect	bRect = [self coordBounds];

    if (count < 4 || p.y < bRect.origin.y || p.y > bRect.origin.y+bRect.size.height)
        return NO;
    if (DiffPoint([self pointWithNum:0], [self pointWithNum:count-1]) > TOLERANCE)
    {   NSLog(@"VPolyLine: -isPointInside called for open PolyLine");
        return NO;
    }
    p0 = NSMakePoint(bRect.origin.x - 2000.0, p.y);
    p1 = NSMakePoint(bRect.origin.x + bRect.size.width+2000.0, p.y);

    cnt = 0;
    for (i=0; i<count-1; i++)
    {   NSPoint	pl0 = ptslist[i], pl1 = ptslist[i+1], pt;
        float	d;

        /* we move the points away from our intersecting line, so we don't hit an edge */
        d = pl0.y - p.y;
        if (d >= 0.0 && d <= 3.0*TOLERANCE)
            pl0.y += 3.0*TOLERANCE;
        if (d < 0.0 && -d <= 3.0*TOLERANCE)
            pl0.y -= 3.0*TOLERANCE;
        d = pl1.y - p.y;
        if (d >= 0.0 && d <= 3.0*TOLERANCE)
            pl1.y += 3.0*TOLERANCE;
        if (d < 0.0 && -d <= 3.0*TOLERANCE)
            pl1.y -= 3.0*TOLERANCE;
        if (vhfIntersectLines(&pt, p0, p1, pl0, pl1))
        {
            if (cnt+1 >= ptsCnt)
            {
                pts = realloc(pts, (ptsCnt+10) * sizeof(NSPoint));
                //NSLog(@"isPointInsideOrOn: point memory too small! %d > %d", cnt, count);
            }
            pts[cnt++] = pt;
        }
    }
    if (!cnt)
    {   free(pts);
        return NO;
    }

    if ( !Even(cnt) )	// we hit an edge
    {	NSLog(@"VPolyLine, -isPointInside: hit edge! p: %.3f %.3f cnt: %i", p.x, p.y, cnt);
        free(pts);
        return NO;
    }
    for (i=0; i<cnt; i++)		// count points left of p
        if (pts[i].x < p.x)
            leftCnt++;

    free(pts);
    return (Even(leftCnt)) ? NO : YES;	// odd number of points to the left -> p is inside
}
/*{   int	iVal=0;

    if ( !(iVal=[self isPointInsideOrOn:p dist:TOLERANCE]) || iVal == 1 )
        return NO;
    return YES;
}*/

/* created: 2003-07-10
 * return YES if p is inside us (we have to be closed)
 * 0 = outside
 * 1 = on
 * 2 = inside
 */
- (int)isPointInsideOrOn:(NSPoint)p
{
    return [[self pathRepresentation] isPointInsideOrOn:p];
}

/*
 * draws the line
 */
- (void)drawWithPrincipal:principal
{   NSBezierPath	*bPath = [NSBezierPath bezierPath];
    int             i, f;

    for (f=0; f<2; f++)
    {   NSColor	*col;
        float	w;

        if (!f && !filled) continue; // nothing to fill or allready filled
#if !defined(__APPLE__) // OpenStep 4.2, linux - FIXME: should be without antialiasing
        if (f && !(width || !filled)) continue; // stroke run: nothing to stroke
#else                   // FIXME: should be with antialiasing
        if (f && !width && filled > 1 ) continue; // stroke run: nothing to stroke and color shading -> skip
#endif
        if (!f && (filled == 2 || filled == 3 || filled == 4) && (graduateDirty || !graduateList))
        {   VPath	*pathRep = [self pathRepresentation];

            if (graduateList)
                [graduateList release];
            if (filled == 2)
                [pathRep drawGraduatedWithPrincipal:principal];
            else if (filled == 3)
                [pathRep drawRadialWithPrincipal:principal];
            else if (filled == 4)
                [pathRep drawAxialWithPrincipal:principal];
            graduateList = [[pathRep graduateList] retain];
            graduateDirty = NO;
            continue;
        }        
        else if (!f && (filled == 2 || filled == 3 || filled == 4) && graduateList && !graduateDirty)
        {   int		gCnt = [graduateList count];
            BOOL	antialias = VHFAntialiasing();

            /* draw graduateList */
            VHFSetAntialiasing(NO);
            for (i=0; i<gCnt; i++)
                [(VGraphic*)[graduateList objectAtIndex:i] drawWithPrincipal:principal];
            if (antialias) VHFSetAntialiasing(antialias);
            continue;
        }
        col = (!f || (!width && filled)) ? fillColor : color;
        w = (!f) ? (0.0) : ((width > 0.0) ? width : [NSBezierPath defaultLineWidth]);   // width
        if ( filled && width == 0.0 )   // if filled and no stroke width, we stroke very thin to make everything visible
            w = 0.1/[principal scaleFactor];

        /* colorSeparation */
        if (!VHFIsDrawingToScreen() && [principal separationColor])
            col = [self separationColor:col]; // get individual separation color

        if ( [principal mustDrawPale] )
        {   CGFloat h, s, b, a;

            [[col colorUsingColorSpaceName:NSDeviceRGBColorSpace] getHue:&h saturation:&s brightness:&b alpha:&a];
            [[NSColor colorWithCalibratedHue:h saturation:s brightness:(b<0.5) ? 0.5 : b alpha:a] set];
        }
#if !defined(GNUSTEP_BASE_VERSION) && !defined(__APPLE__)	// OpenStep 4.2
        else if (VHFIsDrawingToScreen() && [[col colorSpaceName] isEqualToString:NSDeviceCMYKColorSpace])
            [[col colorUsingColorSpaceName:NSCalibratedRGBColorSpace] set];
#endif
        else
            [col set];

        [bPath setLineWidth:w];
        [bPath setLineCapStyle:NSRoundLineCapStyle];
        [bPath setLineJoinStyle:NSRoundLineJoinStyle];
        [bPath moveToPoint:ptslist[0]];
        for (i=1; i<count; i++)
            [bPath lineToPoint:ptslist[i]];

        if (!f) // (filled)
        {   [bPath setWindingRule:NSEvenOddWindingRule];
            [bPath fill];
        }
        else
            [bPath stroke];
    }
    if ([principal showDirection])
        [self drawDirectionAtScale:[principal scaleFactor]];
}

/*
 * Returns the bounds.  The flag variable determines whether the
 * knobs should be factored in. They may need to be for drawing but
 * might not if needed for constraining reasons.
 */
- (NSRect)coordBounds
{
    if (coordBounds.size.width == 0.0 && coordBounds.size.height == 0.0)
    {   NSPoint	ll={MAXCOORD, MAXCOORD}, ur={-MAXCOORD, -MAXCOORD};
        int		i;

        for (i=0; i<count; i++)
        {
            ll.x = Min(ptslist[i].x, ll.x); ll.y = Min(ptslist[i].y, ll.y);
            ur.x = Max(ptslist[i].x, ur.x); ur.y = Max(ptslist[i].y, ur.y);
        }
        coordBounds.origin = ll;
        coordBounds.size.width  = ur.x - ll.x;
        coordBounds.size.height = ur.y - ll.y;
    }
    return coordBounds;
}
- (NSRect)bounds
{   NSRect	bRect;

    bRect = [self coordBounds];
    bRect.origin.x -= width/2.0; bRect.origin.y -= width/2.0;
    bRect.size.width += width; bRect.size.height += width;
    bRect.size.width  = MAX(bRect.size.width,  0.001);
    bRect.size.height = MAX(bRect.size.height, 0.001);
    return bRect;
}

/*
 * Returns the bounds with the given rotation.
 */
- (NSRect)boundsAtAngle:(float)angle withCenter:(NSPoint)cp
{   NSPoint	p, ll={MAXCOORD, MAXCOORD}, ur={-MAXCOORD, -MAXCOORD};
    NSRect	bRect;
    int		i;

    for (i=0; i<count; i++)
    {
        p = ptslist[i];
        vhfRotatePointAroundCenter(&p, cp, -angle);

        ll.x = Min(p.x, ll.x); ll.y = Min(p.y, ll.y);
        ur.x = Max(p.x, ur.x); ur.y = Max(p.y, ur.y);
    }
    bRect.origin = ll;
    bRect.size.width  = ur.x - ll.x;
    bRect.size.height = ur.y - ll.y;
    bRect.origin.x -= width/2.0; bRect.origin.y -= width/2.0;
    bRect.size.width += width; bRect.size.height += width;

    return bRect;
}

- (NSPoint)appendToBezierPath:(NSBezierPath*)bPath currentPoint:(NSPoint)currentPoint
{   int	j;

    if (Diff(currentPoint.x, ptslist[0].x) > 0.01 || Diff(currentPoint.y, ptslist[0].y) > 0.01)
        [bPath moveToPoint:ptslist[0]];
    for (j=1; j<count; j++)
        [bPath lineToPoint:ptslist[j]];
    return ptslist[count-1];
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
    {
        aRect.origin.x = ptslist[pt_num].x;
        aRect.origin.y = ptslist[pt_num].y;
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
{
    if (pt_num >= count)
        pt_num = count-1;
    ptslist[pt_num].x += pt.x;
    ptslist[pt_num].y += pt.y;
    coordBounds = NSZeroRect;
    dirty = YES;
    graduateDirty = YES;
}

/*
 * created:   1995-09-25
 * modified:  
 * parameter: pt_num  number of vertices
 *            p       the new position in
 * purpose:   Sets a vertice to a new position.
 *            If it is a edge move the vertices with it
 *            Default must be the last point!
 */
- (void)movePoint:(int)pt_num to:(NSPoint)p
{   NSPoint	pt;

    if (pt_num >= count)
        pt_num = count-1;
    pt.x = p.x - ptslist[pt_num].x;
    pt.y = p.y - ptslist[pt_num].y;
    [self movePoint:pt_num by:pt];
}

/*
 * pt_num is the changing control point. pt holds the relative change in each coordinate. 
 * The relative is needed and not the absolute because the closest inside control point
 * changes when one of the outside points change.
 */
- (void)movePoint:(int)pt_num by:(NSPoint)pt
{
    if (pt_num >= count)
        pt_num = count-1;
    [self changePoint:pt_num :pt];
    if ( filled && !pt_num )
        [self changePoint:count-1 :pt];
}

/* The pt argument holds the relative point change
 */
- (void)moveBy:(NSPoint)pt
{   int		i;
    BOOL	oldGraduateDirty = graduateDirty;

    for (i=0; i<count; i++)
        [self changePoint:i :pt]; // set graduateDirty to YES ! but we move the objects !
    if (!oldGraduateDirty && graduateList)
    {
        for (i=[graduateList count]-1; i>=0; i--)
            [[graduateList objectAtIndex:i] moveBy:pt];
        graduateDirty = oldGraduateDirty;
    }
}

- (int)numPoints
{
    return count;
}

/* Given the point number, return the point.
 * Default must be p1
 */
- (NSPoint)pointWithNum:(int)pt_num
{
    if ( !count )
        return NSMakePoint(0.0, 0.0);
    if (pt_num >= count)
        return ptslist[count-1];
    if (pt_num < 0)
        return NSMakePoint( 0.0, 0.0);

    return ptslist[pt_num];
}

/*
 * Check for a edge point hit.
 * do not snap to selectedKnob and dont change the selectedKnob (hitControl does it)
 *
 * parameter: p	the mouse position
 *            fuzz		the distance inside we snap to a point
 *            pt			the edge point
 *            controlsize	the size of the controls
 *
 * modified: 2005-10-27
 */
- (BOOL)hitEdge:(NSPoint)p fuzz:(float)fuzz :(NSPoint*)pt :(float)controlsize
{   NSRect	knobRect, hitRect;
    float	conrolsize2 = controlsize/2.0;
    int		i;
    BOOL    gotHit = NO;
    NSPoint hitP = p;
    double  sqrDistBest = MAXFLOAT;

    hitRect.origin.x = p.x -fuzz/2.0;
    hitRect.origin.y = p.y -fuzz/2.0;
    hitRect.size.width = hitRect.size.height = fuzz;
    knobRect.size.width = knobRect.size.height = controlsize;

    for (i=0; i<count; i++)
    {
        knobRect.origin.x = ptslist[i].x - conrolsize2;
        knobRect.origin.y = ptslist[i].y - conrolsize2;
        if ( i != selectedKnob && !NSIsEmptyRect(NSIntersectionRect(hitRect , knobRect)) )
        {   //*pt = ptslist[i];
            //return YES;
            if ( SqrDistPoints(ptslist[i], p) < sqrDistBest )
            {   gotHit = YES;
                hitP = ptslist[i];
                sqrDistBest = SqrDistPoints(ptslist[i], p);
            }
        }
    }
    if (gotHit)
    {   *pt = hitP;
        return YES;
    }
    return NO;
}

/*
 * Check for a control point hit. No need to perform the hit detection in
 * the server since its a simple rectangle intersection check. Return the
 * point number hit in the pt_num argument.
 */
- (BOOL)hitControl:(NSPoint)p :(int *)pt_num controlSize:(float)controlsize;
{   NSRect	knobRect;
    float	conrolsize2 = controlsize/2.0;
    int		i;

    knobRect.size.width = knobRect.size.height = controlsize;

    for (i=0; i<count; i++)
    {
        knobRect.origin.x = ptslist[i].x - conrolsize2;
        knobRect.origin.y = ptslist[i].y - conrolsize2;
        if ( NSPointInRect(p, knobRect) )
        {
            /* dieser und letzter gleich - den letzten nehmen ! */
            if ( Diff(ptslist[i].x, ptslist[count-1].x) <= 0 && Diff(ptslist[i].y, ptslist[count-1].y) <= 0 )
             	i = count-1;
            *pt_num = i;
            selectedKnob = i;
            [self setSelected:YES];
            return YES;
        }
    }

    return NO;
}

- (BOOL)hit:(NSPoint)p fuzz:(float)fuzz
{   NSRect	bRect = [self bounds];
    int		i;

    bRect.origin.x -= fuzz;
    bRect.origin.y -= fuzz;
    bRect.size.width  += 2.0 * fuzz;
    bRect.size.height += 2.0 * fuzz;
    if ( !NSPointInRect(p, bRect) )
        return NO;

    if ( !Prefs_SelectByBorder && filled && [self isPointInside:p] )
        return YES;

    for (i=0; i<count-1; i++)
    {   NSPoint	ll, ur;

        ll.x = Min(ptslist[i].x, ptslist[i+1].x); ll.y = Min(ptslist[i].y, ptslist[i+1].y);
        ur.x = Max(ptslist[i].x, ptslist[i+1].x); ur.y = Max(ptslist[i].y, ptslist[i+1].y);

        bRect.origin = ll;
        bRect.size.width  = ur.x - ll.x;
        bRect.size.height = ur.y - ll.y;
        bRect.origin.x -= fuzz;
        bRect.origin.y -= fuzz;
        bRect.size.width  += 2.0 * fuzz;
        bRect.size.height += 2.0 * fuzz;

        if ( NSPointInRect(p, bRect) && sqrDistancePointLine(&ptslist[i], &ptslist[i+1], &p) <= fuzz*fuzz)
            return YES;
    }
    return NO;
}

/*
 * return a path representing the outline of us
 * the path holds two lines and two arcs
 * if we need not build a contour a copy of self is returned
 */
- (id)contour:(float)w
{
    if (filled)
        return [self contour:w inlay:NO splitCurves:YES];
    //return [self contourOpen:w];
    return [[self pathRepresentation] contour:w];
}

- (id)contour:(float)w inlay:(BOOL)inlay splitCurves:(BOOL)splitCurves
{
    if ( (w < 0.0 && Abs(w) == width) || (w == 0.0 && width == 0.0) )
        return [[self copy] autorelease];
    return [[self pathRepresentation] contour:w];
}

- (id)contourOpen:(float)w
{   VPath               *path = [VPath path];
    int                 i;
    float               cw = (w + width);
    NSAutoreleasePool   *pool = [NSAutoreleasePool new];
    VLine               *line = [VLine line];


    [path setColor:[self color]];
    // build contour of all lines in polyline
    for (i=0; i<count-1; i++)
    {	VGraphic	*ng;

        [line setVertices:ptslist[i] :ptslist[i+1]];
        ng = [line contour:cw];
        [(VPath*)ng setFilled:YES optimize:NO]; // allready optimized
        [[path list] addObject:ng];
    }
    // unite these elements
    {   HiddenArea	*hiddenArea = [HiddenArea new];
        [hiddenArea uniteAreas:[path list]];
        [hiddenArea release];
    }
    // unfill
    //[path unnest];
    [path setFilled:NO];
    [pool release];
    return path;
}

- (NSMutableArray*)getListOfObjectsSplittedAtPoint:(NSPoint)pt
{   NSMutableArray	*splitList = [NSMutableArray array], *spList = nil;
    int			i, splitI = -1;
    NSPoint		cpt;
    VPolyLine		*pLine=nil;
    NSAutoreleasePool 	*pool = [NSAutoreleasePool new];
    float		distance=MAXCOORD;

    cpt = [self nearestPointInPtlist:&splitI distance:&distance toPoint:pt];

    if ((Diff(ptslist[splitI].x, cpt.x) > TOLERANCE || Diff(ptslist[splitI].y, cpt.y) > TOLERANCE) &&
        (Diff(ptslist[splitI+1].x, cpt.x) > TOLERANCE || Diff(ptslist[splitI+1].y, cpt.y) > TOLERANCE))
    {   VLine	*line = [VLine line];

        [line setColor:color];
        [line setWidth:width];
        [line setVertices:ptslist[splitI] :ptslist[splitI+1]];

        spList = [line getListOfObjectsSplittedFrom:&cpt :1];
    }
    if ( (Diff(ptslist[0].x, cpt.x) < TOLERANCE && Diff(ptslist[0].y, cpt.y) < TOLERANCE) ||
         (Diff(ptslist[count-1].x, cpt.x) < TOLERANCE && Diff(ptslist[count-1].y, cpt.y) < TOLERANCE) )
    {   [pool release];
        return nil;
    }
    //if (!splitI && [spList count] < 1)
    //    splitI = 1;
    /* one line and one polyline */
    if ( (!splitI /*&& [spList count] > 1*/) || (splitI == 1 && [spList count] <= 1))
    {   VLine	*line = [VLine line];

        [line setWidth:width];
        [line setColor:color];
        [line setVertices:ptslist[0] :(([spList count] > 1) ? cpt : ptslist[1])];
        [splitList addObject:line];

        if ([spList count] < 1 && count == 3) //([pLine numPoints] == 2)
        {
            line = [VLine line];
            [line setWidth:width];
            [line setColor:color];
            [line setVertices:ptslist[1] :ptslist[2]];
            [splitList addObject:line];
        }
        else
        {   pLine = [VPolyLine polyLine];
            [pLine setWidth:width];
            [pLine setColor:color];
            if ([spList count] > 1)
                [pLine addPoint:cpt];
            for (i=1; i<count; i++)
                [pLine addPoint:ptslist[i]];
            [splitList addObject:pLine];
        }
    }
    /* one polyline and one line */
    else if (splitI == count-2)
    {   VLine	*line = [VLine line];

        pLine = [VPolyLine polyLine];
        [pLine setWidth:width];
        [pLine setColor:color];
        for (i=0; i<=count-2; i++)
            [pLine addPoint:ptslist[i]];
        if ([spList count] > 1)
            [pLine addPoint:cpt];
        [splitList addObject:pLine];

        [line setWidth:width];
        [line setColor:color];
        [line setVertices:(([spList count] > 1) ? cpt : ptslist[count-2]) :ptslist[count-1]];
        [splitList addObject:line];
    }
    /* two polylines */
    else if (splitI != -1)
    {
        pLine = [VPolyLine polyLine];
        [pLine setWidth:width];
        [pLine setColor:color];
        for (i=0; i<=splitI; i++)
            [pLine addPoint:ptslist[i]];
        if ([spList count] > 1)
            [pLine addPoint:cpt];
        [splitList addObject:pLine];

        pLine = [VPolyLine polyLine];
        [pLine setWidth:width];
        [pLine setColor:color];
        if ([spList count] > 1)
            [pLine addPoint:cpt];
        for (i=(([spList count] > 1) ? splitI+1 : splitI); i<count; i++)
            [pLine addPoint:ptslist[i]];
        [splitList addObject:pLine];
    }
    [pool release];
    if ([splitList count])
        return splitList;
    return nil;
}

- (NSMutableArray*)getListOfObjectsSplittedFromGraphic:g
{   NSMutableArray	*splitList = [NSMutableArray array], *spList = nil;
    int			i, j;
    NSAutoreleasePool 	*pool = [NSAutoreleasePool new];
    VLine		*line = [VLine line];

    [line setColor:color];
    [line setWidth:width];

    /* tile each line between points single from pts
     * add splitted objects to splitList (else line)
     */
    for (i=0; i<count-1; i++)
    {
        [line setVertices:ptslist[i] :ptslist[i+1]];

        spList = [line getListOfObjectsSplittedFromGraphic:g];
        if ( [spList count] > 1 )
        {
            for ( j=0; j<(int)[spList count]; j++ )
                [splitList addObject:[spList objectAtIndex:j]];
        }
        else
            [splitList addObject:[[line copy] autorelease]];
    }
    [pool release];
    if ( [splitList count] > 1 )
        return splitList;
    return nil;
}

- getListOfObjectsSplittedFrom:(NSPoint*)pArray :(int)iCnt
{   NSMutableArray	*splitList = [NSMutableArray array], *spList = nil;
    int			i, j, ptCnt = 0;
    NSPoint		start, end;
    VPolyLine		*pLine=nil;
    NSAutoreleasePool 	*pool = [NSAutoreleasePool new];
    VLine		*line = [VLine line];

    [line setColor:color];
    [line setWidth:width];

    /* tile each line between points single from pts
     * add splitted objects to splitList (else line)
     */
    for (i=0; i<count-1; i++)
    {
        [line setVertices:ptslist[i] :ptslist[i+1]];

        spList = [line getListOfObjectsSplittedFrom:pArray :iCnt];
        if ( [spList count] > 1 )
        {
            for ( j=0; j<(int)[spList count]; j++ )
            {
                if ( !j )
                {
                    if ( !i )
                        [splitList addObject:[spList objectAtIndex:j]]; // first single line
                    else // add to polyline
                    {   [[spList objectAtIndex:j] getVertices:&start :&end];
                        if ( ptCnt )
                        {   [pLine addPoint:end]; // else // start polyline - here we must have allways a polyline
                            ptCnt += 1;
                        }
                    }
                }
                else if ( j == 1 )
                {
                    if ( [spList count] == 3 )
                    {   if ( ptCnt ) [splitList addObject:pLine];
                        [splitList addObject:[spList objectAtIndex:j]]; // allways a single line
                    }
                    // splist count is 2
                    else if ( i+1 >= count-1 ) // last line in polyline
                    {   if ( ptCnt ) [splitList addObject:pLine];
                        [splitList addObject:[spList objectAtIndex:j]]; // last single line
                    }
                    else // start polyline
                    {   if ( ptCnt ) [splitList addObject:pLine]; // first add prev polyline
                        pLine = [VPolyLine polyLine];
                        [pLine setWidth:width];
                        [pLine setColor:color];
                        [[spList objectAtIndex:j] getVertices:&start :&end];
                        [pLine addPoint:start];
                        [pLine addPoint:end];
                        ptCnt = 2;
                    }
                }
                else // j == 2
                {    // splist count is 2
                    if ( i+1 >= count-1 ) // last line in polyline
                        [splitList addObject:[spList objectAtIndex:j]]; // last single line
                    else // start polyline
                    {   pLine = [VPolyLine polyLine];
                        [pLine setWidth:width];
                        [pLine setColor:color];
                        [[spList objectAtIndex:j] getVertices:&start :&end];
                        [pLine addPoint:start];
                        [pLine addPoint:end];
                        ptCnt = 2;
                    }
                }
            }
        }
        else
        {
            // pArray pts != ptslist pts !!! - pointInArray()

            if ( !i ) // first line
            {   if ( pointInArray(ptslist[i+1], pArray, iCnt) )
                    [splitList addObject:[[line copy] autorelease]];
                else // start polyline
                {
                    pLine = [VPolyLine polyLine];
                    [pLine setWidth:width];
                    [pLine setColor:color];
                    [pLine addPoint:ptslist[i]];
                    [pLine addPoint:ptslist[i+1]];
                    ptCnt = 2;
                }
            }
            else if ( i+1 >= count-1 ) // last line
            {   if ( pointInArray(ptslist[i], pArray, iCnt) )
                {   if ( ptCnt ) [splitList addObject:pLine]; // first add pLine
                    [splitList addObject:[[line copy] autorelease]]; // last single line
                }
                else if ( ptCnt ) // add last point to polyline
                {   [pLine addPoint:ptslist[i+1]];
                    [splitList addObject:pLine];
                }
                else
                    [splitList addObject:[[line copy] autorelease]]; // last single line
            }
            else
            {   if ( pointInArray(ptslist[i], pArray, iCnt) )
                {   if ( ptCnt ) [splitList addObject:pLine]; // first add pLine

                    // start polyline
                    pLine = [VPolyLine polyLine];
                    [pLine setWidth:width];
                    [pLine setColor:color];
                    [pLine addPoint:ptslist[i]];
                    [pLine addPoint:ptslist[i+1]];
                    ptCnt = 2;
                }
                else if ( pointInArray(ptslist[i+1], pArray, iCnt) )
                {
                    if ( ptCnt )
                    {   [pLine addPoint:ptslist[i+1]];
                        [splitList addObject:pLine];
                    }
                    else
                        [splitList addObject:[[line copy] autorelease]]; // add line

                    // start polyline
                    pLine = [VPolyLine polyLine];
                    [pLine setWidth:width];
                    [pLine setColor:color];
                    [pLine addPoint:ptslist[i+1]];
                    ptCnt = 1;
                }
                else if ( ptCnt )
                {   [pLine addPoint:ptslist[i+1]];
                    ptCnt++;
                }
                else // start polyline
                {   pLine = [VPolyLine polyLine];
                    [pLine setWidth:width];
                    [pLine setColor:color];
                    [pLine addPoint:ptslist[i]];
                    [pLine addPoint:ptslist[i+1]];
                    ptCnt = 2;
                }
            }
        }
    }
    [pool release];
    if ( [splitList count] > 1 ) // more than one polyline
        return splitList;
    return nil;
}

- (int)getIntersections:(NSPoint**)ppArray with:g
{   int		i, j, iCnt = 0;
    int		len;
    NSPoint	*pts = NULL;
    id		gp = [VLine line];

    //NSMutableData	*data = [NSMutableData dataWithLength:([list count]*9) * sizeof(NSPoint)];

/*    if ([g isKindOfClass:[VPath class]] || [g isKindOfClass:[VGroup class]])
    {
        iCnt = [g getIntersections:ppArray with:self];
        if (iCnt)
            sortPointArray(*ppArray, iCnt, p0);
        else
        {	free(*ppArray);
            *ppArray = NULL;
        }

        return iCnt;
    }
*/
    /* g - line, arc, curve, rectangle */
    len = Min(count+1, 100);
    //*ppArray = [data mutableBytes];
    *ppArray = malloc(len * sizeof(NSPoint));
    //*ppArray = NSZoneMalloc((NSZone*)[(NSObject*)NSApp zone], len * sizeof(NSPoint));
    for (i=count-1; i>0; i--)
    {   int	cnt, oldCnt = iCnt;

        [(VLine*)gp setVertices:ptslist[i] :ptslist[i-1]];

        cnt = [gp getIntersections:&pts with:g];
        if (iCnt+cnt >= len)
        {   //[data increaseLengthBy:cnt];
            //*ppArray = [data mutableBytes];
            *ppArray = realloc(*ppArray, (len+=cnt*2) * sizeof(NSPoint));
	    //*ppArray = NSZoneRealloc((NSZone*)[(NSObject*)NSApp zone], *ppArray, (len+=cnt) * sizeof(NSPoint));
        }
        for (j=0; j<cnt; j++)
        {
            if ( !pointInArray(pts[j], *ppArray, oldCnt) )
                (*ppArray)[iCnt++] = pts[j];
            else
            {   /* point is no edge point of gp -> add */
                if ( (Diff(pts[j].x, ptslist[i].x) + Diff(pts[j].y, ptslist[i].y) > 10.0*TOLERANCE) &&
                     (Diff(pts[j].x, ptslist[i-1].x) + Diff(pts[j].y, ptslist[i-1].y) > 10.0*TOLERANCE) )
                    (*ppArray)[iCnt++] = pts[j];

                /* point is an edge point identical with ptslist[i] or i-1
                 * if edge point is at the top/bottom of lines like /\ or \/
                 * we need two points !
                 */
                else if (Diff(pts[j].x, ptslist[i].x) + Diff(pts[j].y, ptslist[i].y) <= 10.0*TOLERANCE)
                {
                    if ((pts[j].y > ptslist[i+1].y && pts[j].y > ptslist[i-1].y) ||	//  edge at top
                        (pts[j].y < ptslist[i+1].y && pts[j].y < ptslist[i-1].y))	//  edge at bottom
                        (*ppArray)[iCnt++] = pts[j];
                }
                else // (Diff(pts[j].x, ptslist[i-1].x) + Diff(pts[j].y, ptslist[i-1].y) <= 10.0*TOLERANCE)
                {   /* is the last line ! - we go backward ! */
                    if ((pts[j].y > ptslist[count-2].y && pts[j].y > ptslist[i].y) ||	//  edge at top
                        (pts[j].y < ptslist[count-2].y && pts[j].y < ptslist[i].y))	//  edge at bottom
                        (*ppArray)[iCnt++] = pts[j];
                }
            }
        }
        if (pts)
            free(pts);
    }

    if (!iCnt)
    {   free(*ppArray);
        //NSZoneFree((NSZone*)[(NSObject*)NSApp zone], *ppArray);
        *ppArray = NULL;
    }

    return iCnt;
}

/* intersect with rectangle
 */
- (int)intersections:(NSPoint**)pArray withRect:(NSRect)rect
{   int		i, j, iCnt = 0, cnt, ptsCnt = Min(100, count+1);
    NSPoint	p0, p1, pts[2];

    *pArray = malloc(ptsCnt * sizeof(NSPoint));
    for (i=count-1; i>0; i--)
    {
        p0 = [self pointWithNum:i];
        p1 = [self pointWithNum:i-1];
        if ( (cnt = vhfIntersectLineAndRect(p0, p1, rect, pts)) )
        {
            if (cnt+iCnt >= ptsCnt)
                *pArray = realloc(*pArray, (ptsCnt += cnt*2) * sizeof(NSPoint));

            for (j=0; j<cnt; j++)
                (*pArray)[iCnt++] = pts[j];
        }
    }

    if (!iCnt)
    {   free(*pArray);
        *pArray = 0;
    }

    return iCnt;
}

- (float)sqrDistanceGraphic:g
{   int		i;
    float	dist, distance = MAXCOORD;
    VLine	*line = [VLine line];

    [line setColor:color];
    [line setWidth:width];

    for (i=0; i<count-1; i++)
    {
        [line setVertices:ptslist[i] :ptslist[i+1]];
        if ( (dist=[g sqrDistanceGraphic:line]) < distance)
            distance = dist;
    }
    return distance;
}

- (float)distanceGraphic:g
{   float	distance;

    distance = [self sqrDistanceGraphic:g];
    return sqrt(distance);
}

- (id)clippedWithRect:(NSRect)rect
{   NSMutableArray	*clipList = [NSMutableArray array], *cList;
    NSPoint		iPoints[count*2], p, rp[4];
    int			iCnt = 0, i, j;
    VGroup		*group = nil;

    rp[0] = rect.origin;
    rp[1].x = rect.origin.x + rect.size.width; rp[1].y = rect.origin.y;
    rp[2].x = rect.origin.x + rect.size.width; rp[2].y = rect.origin.y + rect.size.height;
    rp[3].x = rect.origin.x; rp[3].y = rect.origin.y + rect.size.height;

    for (j=0; j<count-1; j++)
    {
        //if ( ptslist[j] ptslist[j+1] ) // one pt outside rect -> cut
            for (i=0; i<4; i++)
                iCnt += vhfIntersectLines(iPoints+iCnt, ptslist[j], ptslist[j+1], rp[i], (i+1<4) ? rp[i+1] : rp[0]);
    }
    if ( !iCnt || !(cList = [self getListOfObjectsSplittedFrom:iPoints :iCnt]) )
    {   if ( NSPointInRect(ptslist[0], rect) )
            return [[self copy] autorelease];
        else return nil; // nothing from polyline inside
    }
    else
    {	for (j=0; j<(int)[cList count]; j++)
            [clipList addObject:[cList objectAtIndex:j]]; // [[[cList objectAtIndex:j] copy] autorelease]
        [cList removeAllObjects];
    }

    for (i=0; i<(int)[clipList count];i++)
    {	[[clipList objectAtIndex:i] getPoint:&p at:0.5];
        if ( !NSPointInRect(p, rect) )
        {   [clipList removeObjectAtIndex:i];
            i--;
        }
    }

    group = [VGroup group];
    [group setList:clipList];
    return group;
}

/* NO if not united
 *
 * created:  2001-02-15
 * modified: 2004-02-28
 */
- uniteWith:(id)ug
{   int			i, j = 0, k, l, endIx=0, uStartIs[1000], startI, listCnt, uStartIsCnt = 0, uListCnt;
    int			sPairsCnt = 0, ePairsCnt = 0, sPairsCnts[500], ePairsCnts[500];
    int			removedFromUg = 0, removedFromNg = 0, sCnt=0, eCnt=0, startIs[1000], endIs[1000];
    float		tol = (10.0*TOLERANCE);
    VPath		*ng;
    NSMutableArray	*splitListG, *splitListUg;
    NSPoint		p, startPts[1000], endPts[1000];   // start/end point of removed graphic(s)
    BOOL		first = YES, removing = NO;
    NSAutoreleasePool	*pool;

    if ( ![ug isKindOfClass:[VPath class]] && ![ug isKindOfClass:[VArc class]] && ![ug isKindOfClass:[VPolyLine class]]
        && ![ug isKindOfClass:[VRectangle class]] && ![ug isKindOfClass:[VGroup class]] )
        return NO;

    ng = [VPath path];
    [ng setColor:[self color]];
    [ng setFillColor:[self fillColor]];
    [ng setEndColor:[self endColor]];
    [ng setRadialCenter:[self radialCenter]];
    [ng setStepWidth:[self stepWidth]];
    [ng setGraduateAngle:[self graduateAngle]];
    [ng setFilled:YES optimize:NO];
    [ng setWidth:[self width]];
    [ng setSelected:[self isSelected]];

    /* split self */
    if ( (splitListG = [self getListOfObjectsSplittedFromGraphic:ug]) )
        [ng setList:splitListG optimize:NO];
    else
        [[ng list] addObject:[[self copy] autorelease]];

    pool = [NSAutoreleasePool new];

    /* split ug */
    if ( !(splitListUg = [ug getListOfObjectsSplittedFromGraphic:self]) )
    {
        splitListUg = [NSMutableArray array];
        if ( [ug isKindOfClass:[VPath class]] )
            for (i=0; i<(int)[[(VPath*)ug list] count]; i++)
                [splitListUg addObject:[[[[(VPath*)ug list] objectAtIndex:i] copy] autorelease]];
        else
            [splitListUg addObject:[[ug copy] autorelease]];
    }

    /* get startIndexes from splitListUg */
    uStartIsCnt = 1;
    uStartIs[0] = 0;
    uListCnt = [splitListUg count];
    while (endIx != uListCnt-1)
    {   NSPoint	startPt, e;
        VGraphic	*sg = [splitListUg objectAtIndex:uStartIs[uStartIsCnt-1]];

        endIx = -1;

        startPt = [sg pointWithNum:0];
        for ( i=uStartIs[uStartIsCnt-1]; i < uListCnt; i++ )
        {
            e = [[splitListUg objectAtIndex:i] pointWithNum:MAXINT];
            if ( SqrDistPoints(startPt, e) < tol*tol )
            {
                if (i+1 < uListCnt)
                {   NSPoint	begN = [[splitListUg objectAtIndex:i+1] pointWithNum:0];

                    if ( SqrDistPoints(e, begN) < (TOLERANCE*15)*(TOLERANCE*15) )
                        continue; // dist to next gr is smaller !
                }
                endIx = i;
                break;
            }
        }
        if (endIx == -1)
        {   uStartIs[uStartIsCnt++] = uListCnt-1;
            NSLog(@"VArc.m: -uniteWith: endIx not found !");
            break;
        }
        else
            uStartIs[uStartIsCnt++] = endIx+1;
    }

    /* first remove graphics from splitListUg inside self */
    for (i=0; i<[splitListUg count]; i++)
    {   VGraphic	*gr = [splitListUg objectAtIndex:i];

        p = [gr pointAt:0.4];
        if ( [self isPointInside:p] )
        {   [splitListUg removeObjectAtIndex:i];
            /* korrect all uStartIs behind i */
            for (k=0; k < uStartIsCnt; k++)
                if (uStartIs[k] > i) uStartIs[k] -= 1;
            i--;
            removedFromUg++;
        }
    }
    /* we must check if we remove a hole subpath */
    for (i=0; i< uStartIsCnt-1; i++)
    {
        if (uStartIs[i] == uStartIs[i+1])
        {
            for (l=i; l < uStartIsCnt-1; l++)
                uStartIs[l] = uStartIs[l+1];
            uStartIsCnt--;
            i--; // perhaps we remove two or three
        }
    }
    /* searching for our startI (not inside ug) */
    startI = -1;
    for ( i=0, listCnt = [[ng list] count]; i<listCnt; i++ )
    {	id	gThis;

        gThis = [[ng list] objectAtIndex:i];	/* this object */

        /* first line normaly not possible !!! after split everything must be a path !! ! */
        p = [gThis pointAt:0.4];
        if ( ![ug isPointInside:p] )
        {
            startI = i;
            break;
        }
    }

    /* self is inside ug -> ug is it */
    if (startI == -1 && !removedFromUg)
    {
        [pool release];
        return [[ug copy] autorelease];
    }

    /* now we remove the parts of ng which are inside ug
     * and notice the start and end points ..
     */
    first = YES;
    removing = NO;
    for ( i=startI, listCnt = [[ng list] count]; first || i != startI; i++ )
    {	id	gThis;
        NSPoint	gPrevE = NSZeroPoint;
        BOOL	currentlyRemoved = NO;

        i = (i >= listCnt) ? 0 : i;
        if (!first && i == startI)
            break;

        gThis = [[ng list] objectAtIndex:i];	/* this object */
        first = NO;

        if (removing && SqrDistPoints(gPrevE, [gThis pointWithNum:0]) > tol*tol)
            removing = NO; // last object removed but first object is not the same subpath and also removed
        gPrevE = [gThis pointWithNum:MAXINT];

        /* first line normaly not possible !!! after split everything must be a path !! ! */
        p = ( [gThis isKindOfClass:[VPath class]] ) ? [[[(VPath*)gThis list] objectAtIndex:0] pointAt:0.4]
                                                    : [gThis pointAt:0.4];
        if ( [ug isPointInside:p] )
        {
            removedFromNg++;
            currentlyRemoved = YES;
            if (!removing)
            {   int	l, prevI = -1;

                removing = YES;
                eCnt++;
                sPairsCnt++;
                ePairsCnt++;
                ePairsCnts[ePairsCnt-1] = 0; // for check of second startPts[] / removing endpts
                sPairsCnts[sPairsCnt-1] = 1;
                startIs[sCnt] = ((i-1 < 0) ? (listCnt-1) : (i-1));
                startPts[sCnt++] = [gThis pointWithNum:0];
                /* search prevG for startPts[1]  */ /* no prevG found - should be not possible ! */
                prevI = ((i-1 < 0) ? (listCnt-1) : i-1);
                for (l=prevI; l != i; l--)
                {   VGraphic	*gr = [[ng list] objectAtIndex:l];
                    NSPoint	e;

                    e = [gr pointWithNum:MAXINT];
                    if (SqrDistPoints(e, startPts[sCnt-1]) <= tol*tol) // prevG found
                    {   NSPoint	s = [gr pointWithNum:0];

                        startIs[sCnt-1] = l; // this is realy the right index !

                        startIs[sCnt] = ((l-1 < 0) ? (listCnt-1) : (l-1));
                        startPts[sCnt++] = s;
                        sPairsCnts[sPairsCnt-1] = 2;
                        break;
                    }
                    if (!l)
                        l = listCnt; // go around until i !!
                }
            }
            ePairsCnts[ePairsCnt-1] = 1;
            endIs[eCnt-1] = i;
            endPts[eCnt-1] = [gThis pointWithNum:MAXINT];
            [[ng list] removeObjectAtIndex:i];

            /* check if we remove a second startPt !!!!!!!!! */
            {   int	l, si0 = 0, spCnt = sPairsCnts[0];

                for (k=0; k < sPairsCnt; k++)
                {
                    spCnt = sPairsCnts[k];
                    if (i == startIs[si0] /*|| (spCnt > 1 && i == startIs[si0+1])*/)
                    {   int	removeI = si0;

                        if (spCnt > 1 && i == startIs[si0]) // remove both points !
                        {
                            for (l=k; l < sPairsCnt-1; l++)
                                sPairsCnts[l] = sPairsCnts[l+1];
                            sPairsCnt--;
                            removeI = sCnt; // nothing more to remove
                            for (l=si0; l < sCnt-2; l++)
                            {
                                startPts[l] = startPts[l+2];
                                startIs[l] = startIs[l+2];
                            }
                            sCnt--; // we remove two points !
//                            NSLog(@"VArc.m: -uniteWith: one startPt pair was currently removed");
                        }
                        else if (spCnt > 1 && i == startIs[si0+1])
                        {
                            break;
                            sPairsCnts[k] = 1;
                            removeI = si0+1;
                        }
                        else
                        {
                            for (l=k; l < sPairsCnt-1; l++)
                                sPairsCnts[l] = sPairsCnts[l+1];
                            sPairsCnt--;
                            removeI = si0;
                        }
                        /* remove startPts from startPts !!!!!!!!! */
                        for (l=removeI; l < sCnt-1; l++)
                        {
                            startPts[l] = startPts[l+1];
                            startIs[l] = startIs[l+1];
                        }
                        sCnt--;
                        break;
                    }
                    si0 += sPairsCnts[k];
                }
            }
            /* correct all startIs/endIs behind i !! */
            for (j=0; j < sCnt; j++)
                if (i <= startIs[j] && startIs[j]) startIs[j] -= 1;
            for (j=0; j < eCnt; j++)
                if (i < endIs[j] && endIs[j]) endIs[j] -= 1;

            if (i < startI)
                startI--;
            i = (i-1 < -1) ? (listCnt-2) : (i-1);
            listCnt--;
        }
        /* close gap with graphics from splitListUg */
        if ((!currentlyRemoved && removing == YES) // i+1
            || (removing == YES && !first && ((i+1 >= listCnt) ? (0) : (i+1)) == startI)) // last endpts to start gr
        {   NSPoint	s;

            /* search nextG for endPts[1]   no nextG found - startG == endG - only one Graphic ! */
            if (!currentlyRemoved)
            {   NSPoint	e = [gThis pointWithNum:MAXINT];

                endIs[eCnt] = i; // ++++++++++++++++1 ((i+1 >= listCnt) ? 0 : i+1);
                endPts[eCnt++] = e;
                ePairsCnts[ePairsCnt-1] = 2;
            }
            else // currentlyRemoved -> i perhaps -1
            {   int	l, nextI = ((i+1 >= listCnt) ? 0 : i+1);

                /* correct endIs[eCnt-1] !!! - we remove the last graphic in list to startI */
                if (i+1 >= listCnt) // endIs[eCnt-1]++ ! - nextI wird i+2 !
                {
                    /* we have to correct only the index !!! */
                    for (l=nextI; l != ((i < 0) ? (listCnt-1) : i); l++)
                    {   VGraphic	*gr = [[ng list] objectAtIndex:l];
                        
                    // if (k == i) break; // one time around
                        s = [gr pointWithNum:0];
                        if (SqrDistPoints(s, endPts[eCnt-1]) <= tol*tol) // nextG found
                        {   //NSPoint	e = [gr pointWithNum:MAXINT];

                            endIs[eCnt-1] = l;
                            //endPts[eCnt-1] = e;
                            break;
                        }
                        if (l == listCnt-1)
                            l = -1; // go around until i !
                    }
                   //nextI = ((nextI+1 >= listCnt) ? 0 : nextI+1);
                }

                for (l=nextI; l != ((i < 0) ? (listCnt-1) : i); l++)
                {   VGraphic	*gr = [[ng list] objectAtIndex:l];
                    
                    // if (k == i) break; // one time around
                    s = [gr pointWithNum:0];
                    if (SqrDistPoints(s, endPts[eCnt-1]) <= tol*tol) // nextG found
                    {   NSPoint	e = [gr pointWithNum:MAXINT];

                        endIs[eCnt] = l; // ++++++++++++++++++++++1
                        endPts[eCnt++] = e;
                        ePairsCnts[ePairsCnt-1] = 2;
                        break;
                    }
                    if (l == listCnt-1)
                        l = -1; // go around until i !
                }
            }
            removing = NO;
        }
    }

    if (!removedFromNg || !removedFromUg)
    {
        /* look if graphics in splitListUg are identical with graphics in [ng list] */
        for (i=0; i<[splitListUg count]; i++)
        {   VGraphic	*gi = [splitListUg objectAtIndex:i];

            for (j=0; j<listCnt; j++)
            {   VGraphic	*gj = [[ng list] objectAtIndex:j];

                if ([gi identicalWith:gj])
                {   [splitListUg removeObjectAtIndex:i];
                    /* korrect all uStartIs behind i */
                    for (k=0; k < uStartIsCnt; k++)
                        if (uStartIs[k] > i) uStartIs[k] -= 1;
                    i--;
                    removedFromUg++;
                    break;
                }
            }
        }
        /* we must check if we remove a hole subpath */
        for (i=0; i< uStartIsCnt-1; i++)
        {
            if (uStartIs[i] == uStartIs[i+1])
            {
                for (l=i; l < uStartIsCnt-1; l++)
                    uStartIs[l] = uStartIs[l+1];
                uStartIsCnt--;
                i--; // perhaps we remove two or three
            }
        }
        if (![splitListUg count])
        {   [pool release];
            return ng;
        }
    }

    if (!removedFromNg && !removedFromUg)
    {
        /* ug is'nt a path and not splitted now there are two possibilities
        * self is in ug or ug is in self else -> nothing to unite - NO
        */
        if ( ![ug isKindOfClass:[VPath class]] && [splitListUg count] == 1 && ![ug isKindOfClass:[VGroup class]])
        {	NSPoint	p;

            [pool release];
            /* ug is inside self -> self is ok can remove ug later */
            ( [ug isKindOfClass:[VPath class]] ) ? [[[(VPath*)ug list] objectAtIndex:0] getPoint:&p at:0.4] :
                [ug getPoint:&p at:0.4];
            if ( [self isPointInside:p] )
                return [[self copy] autorelease];

            /* self is inside ug -> ug is it */
            [self getPoint:&p at:0.4];
            if ( [(id)ug isPointInside:p] )
                return [[ug copy] autorelease];
            return NO;	/* nothing to unite */
        }
        [pool release];
        return NO;
    }

    /* search graphics in splitListUg which close the gaps in ng */
    /* our orientation we get through the startPts / sePairsCnt */
    for (i=0; i< sPairsCnt; i++)
    {   int	sptCnt = sPairsCnts[i], eptCnt = ePairsCnts[i], sIx = 1;
        int	sIs[2], eIs[2], sI0 = -1, eI0 = -1, endI = -1;
        NSPoint	sPts[2], ePts[2] = {NSZeroPoint, NSZeroPoint};

        /* count with i and sePairsCnts to the current startIs/startPts index */
        sI0 = 0;
        for (j=0; j < i; j++)
            sI0 += sPairsCnts[j];

        sIs[0] = startIs[sI0];
        sPts[0] = startPts[sI0];
        if (sptCnt == 2)
        {   sIs[1] = startIs[sI0+1];
            sPts[1] = startPts[sI0+1];
        }

        sIx = 1; // is the startIx of the next subPath !
        for (j=0; j<[splitListUg count]; j++)
        {   VGraphic	*gj = [splitListUg objectAtIndex:j];
            NSPoint	sj, ej;

            if (j >= uStartIs[sIx])
                sIx++;

            sj = [gj pointWithNum:0];
            ej = [gj pointWithNum:MAXINT];

            if (pointWithToleranceInArray(sj, tol, sPts, sptCnt) ||
                pointWithToleranceInArray(ej, tol, sPts, sptCnt))
            {   int	closeK = -1, si = 0;
                BOOL	ejIsNearer = NO, gjRemoved = NO, jumpOverOneEnd = NO;
                NSPoint	closePt;

                /* check if gj is a double graphic */
                for (k=0; k < sPairsCnt; k++)
                {
                    if ((startIs[si] < listCnt &&
                        [gj identicalWith:[[ng list] objectAtIndex:startIs[si]]]) ||
                        (endIs[si] < listCnt &&
                         [gj identicalWith:[[ng list] objectAtIndex:endIs[si]]]))
                    {
                        [splitListUg removeObjectAtIndex:j];
                        /* korrect all uStartIs behind j */
                        for (l=0; l < uStartIsCnt; l++)
                            if (uStartIs[l] > j) uStartIs[l] -= 1;
                        j--;
                        gjRemoved = YES;
                        break;
                    }
                    si += sPairsCnts[k];
                }
                if (gjRemoved)
                    continue;

                /* ej == sPts[1] && sj != sPts[0]  and sPts[1] is also in endPts */
                if (SqrDistPoints(ej, sPts[1]) < tol*tol && SqrDistPoints(sj, sPts[0]) > tol*tol)
                {   VGraphic	*gjn;
                    NSPoint	sjn;

                    /* ej == sPts[1] && sPts[1] is also in endPts */
                    if (pointWithToleranceInArray(ej, tol, endPts, eCnt))
                        continue;
                    // ej to sPts[1] check if gjn s is to sPts[0]
                    gjn = [splitListUg objectAtIndex:((j+1 >= uStartIs[sIx]) ? uStartIs[sIx-1] : (j+1))];
                    sjn = [gjn pointWithNum:0];
                    if (SqrDistPoints(sjn, sPts[0]) < tol*tol)
                        continue; // took sj to sPts[0]
                }

                if (pointWithToleranceInArray(sj, tol, sPts, sptCnt) &&
                    pointWithToleranceInArray(ej, tol, sPts, sptCnt))
                {   float	ds, de;

                    /* check if ej is nearer to sPts -> search backward / take next start */
                    ds = SqrDistPoints(sj, sPts[0]);
                    de = SqrDistPoints(ej, sPts[0]);
                    if (sptCnt > 1)
                    {   ds = Min(ds, SqrDistPoints(sj, sPts[1]));
                        de = Min(de, SqrDistPoints(ej, sPts[1]));
                    }
                    if (de < ds)
                        ejIsNearer = YES;

               	    if (SqrDistPoints(ej, sPts[0]) < tol*tol)
                    {   VGraphic	*gjn;
                        NSPoint		sjn;

                        /* ej to sPts[0] check if gjn s is to sPts[0] */
                        gjn = [splitListUg objectAtIndex:((j+1 >= uStartIs[sIx]) ? uStartIs[sIx-1] : (j+1))];
                        sjn = [gjn pointWithNum:0];
                        if (SqrDistPoints(sjn, sPts[0]) < tol*tol)
                            continue; // took gjn with sj to sPts[0]
                    }
                }
                /* search forward in splitListUg */
                if (!ejIsNearer && pointWithToleranceInArray(sj, tol, sPts, sptCnt))
                {   BOOL	firstK = YES;
                    NSPoint	prevE = sj; // first k == j == startPt

                    closeK = -1;
                    for ( k=j; firstK || k != j; k++ )
                    {   VGraphic	*gk, *gkn;
                        NSPoint		sk, ek, skn, ekn;

                        k = (k >= uStartIs[sIx]) ? uStartIs[sIx-1] : k;
                        if (!firstK && k == j)
                            break;
                        firstK = NO;

                        gk = [splitListUg objectAtIndex:k];
                        sk = [gk pointWithNum:0];
                        ek = [gk pointWithNum:MAXINT];

                        if (SqrDistPoints(prevE, sk) >= tol*tol)
                            break; // nothing to close gap in ug splitlist

                        if (pointWithToleranceInArray(ek, tol, endPts, eCnt))
                        {
                            gkn = [splitListUg objectAtIndex:((k+1 >= uStartIs[sIx]) ? uStartIs[sIx-1] : (k+1))];
                            skn = [gkn pointWithNum:0];
                            ekn = [gkn pointWithNum:MAXINT];
                            if (SqrDistPoints(ek, skn) < tol*tol &&
                                pointWithToleranceInArray(ekn, tol, endPts, eCnt))
                            {   float	dek = MAXCOORD, dekn = MAXCOORD, d;
                                BOOL	gknIsDouble = NO, eknIs0ePt = YES;
                                int	eki = 0, ekni = 0;

                                for (l=0; l < eCnt; l++)
                                {   if ((d=SqrDistPoints(ekn, endPts[l])) < dekn)
                                    {   dekn = d;
                                        ekni = l;
                                    }
                                    if ((d=SqrDistPoints(ek, endPts[l])) < dek)
                                    {   dek = d;
                                        eki = l;
                                    }
                                }
                                /* both endPts must be 0 ePts ! to use this !! */
                                if (dekn <= dek)
                                {   int	eknI = 0, epCnt; // ekI = 0

                                    for (l=0; l < ePairsCnt; l++)
                                    {
                                        epCnt = ePairsCnts[l];
                                        if (eknI == ekni || (epCnt == 2 && eknI+1 == ekni))
                                        {
                                            if (epCnt == 2 && eknI+1 == ekni)
                                                eknIs0ePt = NO;
                                            break;
                                        }
                                        eknI += ePairsCnts[l];
                                        /*if (ekI == eki || (epCnt == 2 && ekI+1 == eki))
                                        {
                                            if (epCnt == 2 && ekI+1 == eki)
                                                ekIs0ePt = NO;
                                            break;
                                        }
                                        ekI += ePairsCnts[l];*/
                                    }
                                }
                                /* check if gkn is a double graphic */
                                si = 0;
                                for (l=0; l < sPairsCnt; l++)
                                {
                                    if ((startIs[si] < listCnt &&
                                         [gkn identicalWith:[[ng list] objectAtIndex:startIs[si]]]) ||
                                        (endIs[si] < listCnt &&
                                         [gkn identicalWith:[[ng list] objectAtIndex:endIs[si]]]))
                                    {
                                        gknIsDouble = YES;
                                        break;
                                    }
                                    si += sPairsCnts[l];
                                }
                                if (!gknIsDouble && eknIs0ePt && (dekn < dek || (dekn <= dek && eki != ekni)))
                                {   prevE = ek;
                                    if (eki != ekni) // this is when we jump over an [ng list] graphic !!
                                        jumpOverOneEnd = YES;
                                    continue; // next gk is our close gk
                                }
                            }
                            closePt = ek;
                            closeK = k;
                            break; // we can close the gap
                        }
                        prevE = ek;
                    }
                }
                else // backward searching
                {   BOOL	firstK = YES;
                    NSPoint	prevS = ej; // first k == j == startPt

                    closeK = -1;
                    for ( k=j; firstK || k != j; k-- )
                    {   VGraphic	*gk, *gkp;
                        NSPoint		sk, ek, skp, ekp;

                        k = (k < uStartIs[sIx-1]) ? (uStartIs[sIx]-1) : k;

                        if (!firstK && k == j)
                            break;
                        firstK = NO;

                        gk = [splitListUg objectAtIndex:k];
                        sk = [gk pointWithNum:0];
                        ek = [gk pointWithNum:MAXINT];

                        if (SqrDistPoints(prevS, ek) >= tol*tol)
                            break; // nothing to close gap in path
                        if (pointWithToleranceInArray(sk, tol, endPts, eCnt))
                        {
                            gkp = [splitListUg objectAtIndex:((k-1 < uStartIs[sIx-1]) ? (uStartIs[sIx]-1) : (k-1))];
                            skp = [gkp pointWithNum:0];
                            ekp = [gkp pointWithNum:MAXINT];
                            if (SqrDistPoints(sk, ekp) < tol*tol &&
                                pointWithToleranceInArray(skp, tol, endPts, eCnt))
                            {   float	dek = MAXCOORD, dekp = MAXCOORD, d;
                                BOOL	gkpIsDouble = NO, ekpIs0ePt = YES;
                                int	eki = 0, ekpi = 0;

                                for (l=0; l < eCnt; l++)
                                {   if ((d=SqrDistPoints(ekp, endPts[l])) < dekp)
                                    {   dekp = d;
                                        ekpi = l;
                                    }
                                    if ((d=SqrDistPoints(ek, endPts[l])) < dek)
                                    {   dek = d;
                                        eki = l;
                                    }
                                }
                                /* both endPts must be 0 ePts ! to use this !! */
                                if (dekp <= dek)
                                {   int	ekpI = 0, epCnt;

                                    for (l=0; l < ePairsCnt; l++)
                                    {
                                        epCnt = ePairsCnts[l];
                                        if (ekpI == ekpi || (epCnt == 2 && ekpI+1 == ekpi))
                                        {
                                            if (epCnt == 2 && ekpI+1 == ekpi)
                                                ekpIs0ePt = NO;
                                            break;
                                        }
                                        ekpI += ePairsCnts[l];
                                    }
                                }
                                /* check if gkp is a double graphic */
                                si = 0;
                                for (l=0; l < sPairsCnt; l++)
                                {
                                    if ((startIs[si] < listCnt &&
                                         [gkp identicalWith:[[ng list] objectAtIndex:startIs[si]]]) ||
                                        (endIs[si] < listCnt &&
                                         [gkp identicalWith:[[ng list] objectAtIndex:endIs[si]]]))
                                    {
                                        gkpIsDouble = YES;
                                        break;
                                    }
                                    si += sPairsCnts[l];
                                }
                                if (!gkpIsDouble && ekpIs0ePt && (dekp < dek || (dekp <= dek && eki != ekpi)))
                                {   prevS = sk;
                                    if (eki != ekpi) // this is when we jump over an [ng list] graphic !!
                                        jumpOverOneEnd = YES;
                                    continue; // next gk is our close gk
                                }
                            }
                            closePt = sk;
                            closeK = k;
                            break; // we can close the gap
                        }
                        prevS = sk;
                    }
                }
                if (closeK != -1)
                {   int		added = 0, from = closeK, to = j;
                    float	dist = MAXCOORD;

                    /* get endI, eptCnt and eI0 */
                    if (pointWithToleranceInArray(closePt, tol, endPts, eCnt))
                    {
                        for (k=0; k < eCnt; k++)
                            if (SqrDistPoints(closePt, endPts[k]) < tol*tol)
                            {   endI = k;
                                break;
                            }
                    }
                    else
                        NSLog(@"VArc.m: -uniteWith: this should be not possible");

                    eI0 = 0;
                    for (k=0; k < ePairsCnt; k++)
                    {
                        eptCnt = ePairsCnts[k];
                        if (eI0 == endI || (eptCnt == 2 && eI0+1 == endI))
                            break;
                        eI0 += ePairsCnts[k];
                    }
                    eIs[0] = endIs[eI0];
                    ePts[0] = endPts[eI0];
                    if (eptCnt == 2)
                    {   eIs[1] = endIs[eI0+1];
                        ePts[1] = endPts[eI0+1];
                    }

                    /* little gap will close from optimize list correctlier */
                    if (SqrDistPoints(sPts[0], ePts[0]) < tol*tol ||
                        (!pointWithToleranceInArray(sj, tol, sPts, sptCnt) && SqrDistPoints(closePt, ej) < tol*tol) ||
                        (pointWithToleranceInArray(sj, tol, sPts, sptCnt) && SqrDistPoints(closePt, sj) < tol*tol))
                        continue; // little gap will close from optimize list correctlier

                    /* if eCnt/sCnt > 1
                    * && ej/sj... gleich zu ..Pts[1] -> ..Is[0] aus [ng list] removen !!!!!!!!!! */
                    if (sptCnt > 1 &&
                        (((dist=SqrDistPoints(ej, sPts[1])) < tol*tol && dist < SqrDistPoints(ej, sPts[0])) ||
                         ((dist=SqrDistPoints(sj, sPts[1])) < tol*tol && dist < SqrDistPoints(sj, sPts[0]))) &&
                        !pointWithToleranceInArray(sPts[1], tol, endPts, eCnt))
                    {   /* remove object at sIs[0] from [ng list] */
                        [[ng list] removeObjectAtIndex:sIs[0]];
                        if (startI > sIs[0])
                            startI--;
                        
                        /* correct all startIs/endIs behind sIs[0] !! */
                        for (k=0; k < sCnt; k++)
                            if (startIs[k] >= sIs[0] && startIs[k]) startIs[k] -= 1;
                        for (k=0; k < eCnt; k++)
                            if (endIs[k] > sIs[0] && endIs[k]) endIs[k] -= 1;
                        if (eIs[0] > sIs[0]) eIs[0] -= 1;
                        sIs[0]--;
                        listCnt--;
                    }

                    if ((eptCnt > 1 &&
                         ((dist=SqrDistPoints(closePt, ePts[1])) < tol*tol &&
                          dist < SqrDistPoints(closePt, ePts[0]) && // tol*tol
                          !pointWithToleranceInArray(ePts[1], tol, startPts, sCnt)))
                        || (jumpOverOneEnd && eptCnt > 1 && SqrDistPoints(closePt, ePts[0]) < tol*tol))
                    {	int	ri = eIs[0];

                        if (jumpOverOneEnd && eptCnt > 1 && SqrDistPoints(closePt, ePts[0]) < tol*tol)
                        {
                            if (sIs[0]+1 == eIs[0]-1)
                                ri = sIs[0]+1;
                            else if (Diff(sIs[0], eIs[0]) == 1 || Diff(sIs[0], eIs[0]) > 3)
                                ri = -1; // nothing to remove
                            else
                            {   ri = -1;
                                NSLog(@"VArc.m -uniteWith: not yet implemented");
                            }
                        }
                        if (ri != -1)
                        {   /* remove object at ri (eIs[0]) from [ng list] */
                            [[ng list] removeObjectAtIndex:ri];

                            /* correct all startIs/endIs befor ri !! */
                            for (k=0; k < sCnt; k++)
                                if (startIs[k] >= ri && startIs[k]) startIs[k] -= 1;
                            for (k=0; k < eCnt; k++)
                                if (endIs[k] > ri && endIs[k]) endIs[k] -= 1;
                            if (sIs[0] >= ri) sIs[0] -= 1;
                            listCnt--;
                        }
                    }

                    if (!pointWithToleranceInArray(sj, tol, sPts, sptCnt)) //  war  ej ohne !
                    {
                        //if (pointWithToleranceInArray(ej, tol, sPts, sptCnt))
                        {   to = closeK;
                            from = j;
                        }
                        /* insert graphics forward */ /* dont stop with 0 (k) <= -1 (from) */
                        for (k=to; k <= ((to > from) ? (uStartIs[sIx]-1) : (from)) && from >= uStartIs[sIx-1]; k++)
                        {   VGraphic	*gk = [splitListUg objectAtIndex:k];

                            [gk changeDirection];
                            [[ng list] insertObject:gk atIndex:((sIs[0]==[[ng list] count]) ? (sIs[0]) : (sIs[0]+1))];
                            added++;
                            if (k <= from) { from--; to--; }
                            [splitListUg removeObjectAtIndex:k];
                            /* korrect all uStartIs behind k */
                            for (l=0; l < uStartIsCnt; l++)
                                if (uStartIs[l] > k) uStartIs[l] -= 1;
                            k--;
                            if (k+1 >= uStartIs[sIx] && to > from)
                            {   k = uStartIs[sIx-1] - 1; // 0 - 1
                                to = from-1; // little hack mh - second part until list end !
                            }
                        }
                    }
                    else
                    {   //if (pointWithToleranceInArray(sj, tol, sPts, sptCnt))
                        {   to = closeK;
                            from = j;
                        }
                        /* insert graphics from backward (closeK-j) */
                        for (k=to; k >= ((!to || to < from) ? uStartIs[sIx-1] : from); k--)
                        {   VGraphic	*gk = [splitListUg objectAtIndex:k];
                            
                            [[ng list] insertObject:gk atIndex:((sIs[0]==[[ng list] count]) ? (sIs[0]) : (sIs[0]+1))];
                            [splitListUg removeObjectAtIndex:k];
                            /* korrect all uStartIs behind k */
                            for (l=0; l < uStartIsCnt; l++)
                                if (uStartIs[l] > k) uStartIs[l] -= 1;
                            added++;
                            if (k < from) { from--; to--; }

                            if (k <= uStartIs[sIx-1] && to < from) // we step over 0 - second part until from !
                            {   k = uStartIs[sIx]; // [splitListUg count]
                                to = from+1; // little hack mh - second part until from !
                            }
                        }
                    }
                    /* we must check if we remove a hole subpath */
                    for (k=0; k< uStartIsCnt-1; k++)
                    {
                        if (uStartIs[k] == uStartIs[k+1])
                        {
                            for (l=k; l < uStartIsCnt-1; l++)
                                uStartIs[l] = uStartIs[l+1];
                            uStartIsCnt--;
                            k--; // perhaps we remove two or three
                        }
                    }
                    /* correct all startIs/endIs behind sIs[0] !! */
                    for (k=0; k < sCnt; k++)
                        if (startIs[k] >= sIs[0]) startIs[k] += added;
                    for (k=0; k < eCnt; k++)
                        if (endIs[k] >= sIs[0]) endIs[k] += added;

                    listCnt += added;
                    break;
                }
            }
        }
    }

    /* add closed chapes from splitListUg to ng */
    if (uStartIsCnt > 1 && [splitListUg count])
    {
        for (i=0; i<uStartIsCnt-1; i++)
        {
            if (uStartIs[i+1]-1 == uStartIs[i] && [splitListUg count] == 1) // only one object
            {   VGraphic	*g = [splitListUg objectAtIndex:uStartIs[i]];

                if ([g isKindOfClass:[VArc class]] && Abs([(VArc*)g angle]) == 360.0)
                    [[ng list] addObject:[splitListUg objectAtIndex:j]];
                continue;
            }
            else if ([splitListUg count] >= uStartIs[i+1]-1)
            {   VGraphic	*gs = [splitListUg objectAtIndex:uStartIs[i]];
                VGraphic	*ge = [splitListUg objectAtIndex:uStartIs[i+1]-1];
                NSPoint		s, e;

                s = [gs pointWithNum:0];
                e = [ge pointWithNum:MAXINT];
                if (SqrDistPoints(s, e) <= tol*tol) /*&& (sPairsCnt || (!sPairsCnt && !removedFromUg))*/
                {   BOOL	doNotAdd = NO;

                    for (j=uStartIs[i]; j < uStartIs[i+1]-1; j++)
                    {   VGraphic	*gs = [splitListUg objectAtIndex:j];
                        VGraphic	*ge = [splitListUg objectAtIndex:j+1];
                        NSPoint		s, e;

                        e = [gs pointWithNum:MAXINT];
                        s = [ge pointWithNum:0];
                        if (SqrDistPoints(e, s) <= tol*tol)
                            continue;
                        else
                        {   doNotAdd = YES;
                            break;
                        }
                    }
                    if (doNotAdd)
                        continue;

                    for (j=uStartIs[i]; j < uStartIs[i+1]; j++)
                        [[ng list] addObject:[splitListUg objectAtIndex:j]];
                }
            }
        }
    }

    if (sPairsCnt > 1) // aukommentieren fuer debugging zwecke !!!!!!!!!!!!!!!!
        [ng optimizeList:[ng list]];

    [pool release];

    return ng;
}

/* joins two polylines. The joined polyline is appended by a line, if necessary.
 * a polyline cannot contain other polylines! Use a path object to hold two or more PolyLines..
 */
- (void)join:obj
{   NSPoint	pa, pb, p1, p2;
    float	da1, da2, db1, db2;
    int		ix, closeGap = 0;

    if ( ![obj isKindOfClass:[VLine class]] && ![obj isKindOfClass:[VPolyLine class]] )
        return;

    if ([obj selectedKnobIndex] >= 0 && ![obj isKindOfClass:[VPolyLine class]])	/* knob of obj is selected */
    {   [obj getPoint:[obj selectedKnobIndex] :&pa];
        if ( [obj selectedKnobIndex]==0 )
            pb.x = pb.y = LARGE_COORD;
        else
            pb = pa, pa.x = pa.y = LARGE_COORD;
    }
    else	/* no knob of object selected */
    {   if ( [obj isKindOfClass:[VLine class]] )
        [obj getVertices:&pa :&pb];
        else
        {   pa = [obj pointWithNum:0];
            pb = [obj pointWithNum:[obj ptsCount]-1];
        }
    }
    p1 = ptslist[0]; p2 = ptslist[count-1];

    /* closer 1st point (p1) -> add object at beginning of list */
    da1 = SqrDistPoints(pa, p1);
    da2 = SqrDistPoints(pa, p2);
    db1 = SqrDistPoints(pb, p1);
    db2 = SqrDistPoints(pb, p2);
    if ( da1<da2 && da1<db1 && da1<db2 )	/* pa / p1 */
    {
        [obj changeDirection];
        if (da1) closeGap = 1;	/* close the gap */
        ix = 0; // add at begin of polyline
    }
    else if ( da2<=da1 && da2<=db1 && da2<=db2 )	/* pa / p2 */
    {
        if (da2) closeGap = 1;	/* close the gap */
        ix = count;
    }
    else if ( db1<=da1 && db1<=da2 && db1<=db2 )	/* pb / p1 */
    {
        if (db1)	closeGap = 1;	/* close the gap */
        ix = 0; // add at begin of polyline
    }
    else	/* pb / p2 */
    {
        [obj changeDirection];
        if (db2) closeGap = 1;	/* close the gap */
        ix = count; // add at end of polyline
    }

    if ( ix == count )
    {
        if ( closeGap )
            [self addPoint:[obj pointWithNum:0]];
        if ( [obj isKindOfClass:[VLine class]] )
        {   pb = [obj pointWithNum:3];
            [self addPoint:pb];
        }
        else
        {   int	i, cnt = [obj ptsCount];
            for (i=1; i<cnt; i++) // without start point
                [self addPoint:[obj pointWithNum:i]];
        }
    }
    else
    {   NSPoint	pts[count];
        int		i, cnt = 0;

        for (i=0; i<count; i++) // copy ptslist
            pts[cnt++] = ptslist[i];

        count = 0; // first add object points
        if ( [obj isKindOfClass:[VLine class]] )
        {   [obj getVertices:&pa :&pb];
            [self addPoint:pa];
            [self addPoint:pb];
        }
        else
        {   int	oCnt = [obj ptsCount];
            for (i=0; i<oCnt; i++)
                [self addPoint:[obj pointWithNum:i]];
        }
        if (closeGap)	/* close the gap */
            [self addPoint:pts[0]];

        for (i=1; i<cnt; i++) // now self without start
            [self addPoint:pts[i]];
    }	
}

- (void)getPointBeside:(NSPoint*)point :(int)left :(float)dist
{   float	dx, dy, c;
    NSPoint	pM;

    //[self getPoint:&pM at:0.4];
    dx = ptslist[1].x - ptslist[0].x;
    dy = ptslist[1].y - ptslist[0].y;
    pM = NSMakePoint( ptslist[0].x + dx * 0.4, ptslist[0].y + dy * 0.4 );

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
{   NSPoint	pt;
    int		i;

    if (![g isKindOfClass:[VPolyLine class]] || count != [(VPolyLine*)g ptsCount])
        return NO;

    pt = [(VPolyLine*)g pointWithNum:0];
    if ( Diff(ptslist[0].x, pt.x) <= TOLERANCE && Diff(ptslist[0].y, pt.y) <= TOLERANCE )
    {
        for (i=0; i<count; i++)
        {   pt = [(VPolyLine*)g pointWithNum:i];
            if ( Diff(ptslist[i].x, pt.x) > TOLERANCE || Diff(ptslist[i].y, pt.y) > TOLERANCE )
                return NO;
        }
    }
    else // check controverse direction
    {   for (i=0; i<count; i++)
        {   pt = [(VPolyLine*)g pointWithNum:count-1-i];
            if ( Diff(ptslist[i].x, pt.x) > TOLERANCE || Diff(ptslist[i].y, pt.y) > TOLERANCE )
                return NO;
        }
    }
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [super encodeWithCoder:aCoder];
    [aCoder encodeValuesOfObjCTypes:"i", &count];
    [aCoder encodeObject:ptsData];
    // 2002-07-07
    [aCoder encodeValuesOfObjCTypes:"i", &filled];
    [aCoder encodeObject:fillColor];
    [aCoder encodeObject:endColor];
    [aCoder encodeValuesOfObjCTypes:"ff", &graduateAngle, &stepWidth];
    //[aCoder encodeValuesOfObjCTypes:"{NSPoint=ff}", &radialCenter];
    [aCoder encodePoint:radialCenter];  // 2012-01-08
}
- (id)initWithCoder:(NSCoder *)aDecoder
{   int	version;

    [self setParameter];

    [super initWithCoder:aDecoder];
    version = [aDecoder versionForClassName:@"VPolyLine"];

    [aDecoder decodeValuesOfObjCTypes:"i", &count];
    ptsData = [[aDecoder decodeObject] retain];
    ptslist = [ptsData mutableBytes];
    if (version == 1)
        [aDecoder decodeValuesOfObjCTypes:"c", &filled];
    else // 2002-07-07
    {   [aDecoder decodeValuesOfObjCTypes:"i", &filled];
        fillColor = [[aDecoder decodeObject] retain];
        endColor = [[aDecoder decodeObject] retain];
        [aDecoder decodeValuesOfObjCTypes:"ff", &graduateAngle , &stepWidth];
        //[aDecoder decodeValuesOfObjCTypes:"{NSPoint=ff}", &radialCenter];
        radialCenter = [aDecoder decodePoint];  // 2012-01-08
    }
    graduateDirty = YES;
    graduateList = nil;
    return self;
}

/* archiving with property list
 */
- (id)propertyList
{   NSMutableDictionary *plist = [super propertyList];
    NSMutableString     *dataStr;
    int                 i;

    [plist setObject:propertyListFromInt(count)                 forKey:@"count"];

    dataStr = [NSMutableString stringWithFormat:@"%f %f", ptslist[0].x, ptslist[0].y];
    for (i=1; i<count; i++)
        [dataStr appendFormat:@" %f %f", ptslist[i].x, ptslist[i].y];
    [plist setObject:dataStr                                    forKey:@"ptsData"];
    if (filled)
        [plist setObject:propertyListFromInt(filled)            forKey:@"filled"];
    //if (fillColor != [NSColor blackColor])  // should compare to color, not Black
    //if ( ! [fillColor isEqual:color] )  // 2012-03-05
        [plist setObject:propertyListFromNSColor(fillColor)     forKey:@"fillColor"];
    if (endColor  != [NSColor blackColor])
        [plist setObject:propertyListFromNSColor(endColor)      forKey:@"endColor"];
    if (graduateAngle)
        [plist setObject:propertyListFromFloat(graduateAngle)   forKey:@"graduateAngle"];
    if (stepWidth != 7)
        [plist setObject:propertyListFromFloat(stepWidth)       forKey:@"stepWidth"];
    if (!(radialCenter.x == 0.5 && radialCenter.y == 0.5))
        [plist setObject:propertyListFromNSPoint(radialCenter)  forKey:@"radialCenter"];
    return plist;
}
- (id)initFromPropertyList:(id)plist inDirectory:(NSString *)directory
{   id	pData;
    int	i=0;

    [super initFromPropertyList:plist inDirectory:directory];
    count = [plist intForKey:@"count"];

    pData = [plist objectForKey:@"ptsData"];
    if ([pData isKindOfClass:[NSString class]])
    {   NSScanner	*scanner = [NSScanner scannerWithString:pData];

        maxcount = count;
        ptsData = [[NSMutableData dataWithLength:maxcount * sizeof(NSPoint)] retain];
        ptslist = [ptsData mutableBytes];

        while ( ![scanner isAtEnd] )
        {   double  d;

            [scanner scanDouble:&d]; ptslist[i].x = d;
            [scanner scanDouble:&d]; ptslist[i].y = d;
            i++;
        }
    }
    else
        ptsData = ([pData isKindOfClass:[NSMutableData class]]) ? [pData retain] : [pData mutableCopy];
    ptslist = [ptsData mutableBytes];

    filled = [plist intForKey:@"filled"];
    if (!filled && [plist objectForKey:@"filled"])
        filled = 1;
    // FIXME: when writing we don't write Black color, when reading we default to color !!!
    if (!(fillColor = colorFromPropertyList([plist objectForKey:@"fillColor"], [self zone])))
        [self setFillColor:[color copy]];
    if (!(endColor  = colorFromPropertyList([plist objectForKey:@"endColor"],  [self zone])))
        [self setEndColor:[NSColor blackColor]];
    graduateAngle = [plist floatForKey:@"graduateAngle"];
    if ( !(stepWidth = [plist floatForKey:@"stepWidth"]))
        stepWidth = 7.0;	// default;
    if ([plist objectForKey:@"radialCenter"])
        radialCenter = pointFromPropertyList([plist objectForKey:@"radialCenter"]);
    else
        radialCenter = NSMakePoint(0.5, 0.5);	// default
    selectedKnob = -1;
    graduateDirty = YES;
    graduateList = nil;
    return self;
}


- (void)dealloc
{
    [fillColor release];
    [endColor release];
    [ptsData release];
    ptsData = nil;
    ptslist = 0;
    if (graduateList)
    {   [graduateList release];
        graduateList = nil;
    }
    [super dealloc];
}

@end
