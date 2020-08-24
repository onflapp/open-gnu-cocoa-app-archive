/* VPath.m
 * complex path
 *
 * Copyright (C) 1996-2012 by vhf interservice GmbH
 * Author:   Georg Fleischmann, Ilonka Fleischmann
 *
 * created:  1996-01-29
 * modified: 2012-12-12 (-drawGraduatedWithPrincipal: alpha added, another rounding problem exposed)
 *           2012-10-25 (-optimizePath: change position of inserted line for one -closeGapBetween::)
 *           2012-08-14 (-subPathInsidePath:: on check alot better)
 *           2012-07-17 (*pts = NULL, *iPts = NULL initialized)
 *           2012-06-12 (-optimizePath:, -pointWithNumBecomeStartPoint: corrected for open paths)
 *           2012-01-19 (-contour:inlay:splitCurves: simplified sc cases in two locations)
 *           2011-08-25 (-contour:inlay:splitCurves: pathCopy, and Autorelease pool)
 *                      (-subPathInsidePath::, -intersectionsForPtInside:with:, both, memory leaks closed)
 *           2011-05-02 (-contour:inlay:splitCurves: calc parallel points with cut if possible)
 *           2011-04-14 (-contour:inlay:splitCurves: replace curves with same curvePts in start/end)
 *           2011-04-06 (-pointWithNumBecomeStartPoint: added)
 *                      (-removePointWithNum:): [self deselectAll];
 *                      (-join:): getDirection
 *           2010-07-08 (-transform: added)
 *           2010-03-03 (-contour:inlay:splitCurves: and copy, setDirectionCCW:)
 *           2008-12-18 (-contour:inlay:splitCurves:, [gThis length] < 15.0*TOLERANCE)
 *           2008-12-01 (axial filling, draw unfilled path with stroke color)
 *           2008-10-16 (-uniteWith:)
 *           2008-10-11 (-changeDirection - open paths added)
 *           2008-07-14 (-directionOfSubPath::, -subPathInsidePath::, 360 arc inside Path)
 *           2008-07-25 (-contour:inlay:removeLoops: does not call -contourWithPixel any more !)
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
#include <VHFShared/vhfMath.h>
#include <VHFShared/vhf2DFunctions.h>
#include <VHFShared/vhfCommonFunctions.h>
#include <VHFShared/types.h>
#include "../App.h"
#include "../DocView.h"
#include "../DocWindow.h"
#include "VLine.h"
#include "VCurve.h"
#include "VPath.h"
#include "PathContour.h"
#include "VArc.h"
#include "HiddenArea.h"
#include "../Inspectors.h"

static float angleBetweenGraphicsInStartOrEnd(id g1, id g2, BOOL end);

/* Private methods
 */
@interface VPath(PrivateMethods)
- (void)addToClosestEnd:obj;
- (BOOL)closeGapBetween:(VGraphic*)g1 and:(VGraphic*)g2;
- (int)isPointInsideOrOn:(NSPoint)p dist:(float)dist;
- (int)isPointInsideOrOn:(NSPoint)p dist:(float)dist subPath:(int)begIx :(int)endIx;
//- (int)getLastObjectOfSubPath:(int)startIx;
//- (int)directionOfSubPath:(int)startIx :(int)endIx;
- (void)optimize;
//- (BOOL)subPathInsidePath:(int)begIx :(int)endIx;
- (void)optimizeSubPathsToClosedPath:(VPath*)path :(float)w :(int*)subPathSplitted;
- (void)removeFaultGraphicsInSubpaths:(VPath*)path :(float)w;
- (void)setDirectionCCW:(BOOL)ccw;
- (id)contourOpen:(float)w;
- (int)getFirstObjectOfSubPath:(int)ix;
- (void)changeDirectionOfSubPath:(int)startIx :(int)endIx;

//- (int)getLastObjectOfSubPath:(int)startIx tolerance:(float)tolerance;
@end

@implementation VPath

/*
 * This sets the class version so that we can compatibly read
 * old VGraphic objects out of an archive.
 */
+ (void)initialize
{
    [VPath setVersion:3];
}

+ (VPath*)path
{
    return [[[VPath allocWithZone:[self zone]] init] autorelease];
}

+ (VPath*)pathWithBezierPath:(NSBezierPath*)bezierPath
{   int		i, cnt = [bezierPath elementCount];
    VPath	*path;
    id		g;
    NSPoint	p0, pts[3], startP = NSZeroPoint;

    if (!cnt)
        return nil;
    path = [VPath path];
    for (i=0; i<cnt; i++)
    {
        switch ([bezierPath elementAtIndex:i associatedPoints:pts])
        {
            case NSMoveToBezierPathElement:
                p0 = startP = pts[0];
                break;
            case NSLineToBezierPathElement:
                g = [VLine lineWithPoints:p0 :pts[0]];
                [[path list] addObject:g];
                p0 = pts[0];
                break;
            case NSCurveToBezierPathElement:
                g = [VCurve curveWithPoints:p0 :pts[0] :pts[1] :pts[2]];
                [[path list] addObject:g];
                p0 = pts[2];
                break;
            case NSClosePathBezierPathElement:
                g = [VLine lineWithPoints:p0 :startP];
                [[path list] addObject:g];
        }
    }
    return path;
}

- init
{
    [super init];
    selectedObject = -1;
    list = [[NSMutableArray allocWithZone:[self zone]] init];
    fillColor = [[NSColor blackColor] retain];
    endColor  = [[NSColor blackColor] retain];
    graduateAngle = 0.0;
    stepWidth = 7.0;
    radialCenter = NSMakePoint(0.5, 0.5);
    graduateList = nil;
    graduateDirty = YES;
    coordBounds = bounds = NSZeroRect;
    return self;
}

/* deep copy
 *
 * created:  2001-02-15
 * modified: 2010-03-03 (setDirectionCCW:)
 */
- copy
{   VPath   *path;
    int		i, cnt = [list count];

    path = [[VPath allocWithZone:[self zone]] init];
    [path setFilled:filled optimize:NO];
    [path setDirectionCCW:isDirectionCCW];
    [path setWidth:width];
    [path setSelected:isSelected];
    [path setLocked:NO];
    [path setColor:color];
    [path setFillColor:fillColor];
    [path setEndColor:endColor];
    [path setGraduateAngle:graduateAngle];
    [path setStepWidth:stepWidth];
    [path setRadialCenter:radialCenter];
    for (i=0; i<cnt; i++)
        [[path list] addObject:[[[list objectAtIndex:i] copy] autorelease]];
    return path;
}

- (NSString*)description
{   NSRect  bnds = [self bounds];

    return [NSString stringWithFormat:@"VPath: %f %f %f %f", bnds.origin.x, bnds.origin.y, bnds.size.width, bnds.size.height];
}

- (NSString*)title		{ return @"Path"; }

/* whether we are a path object
 * eg. line, polyline, arc, curve, rectangle, path
 * group is not a path object because we don't know what is inside!
 */
- (BOOL)isPathObject	{ return YES; }

- (void)setRectangle:(NSPoint)ll :(NSPoint)ur
{   VLine	*line;
    NSPoint	p0, p1;

    if (!list)
        list = [[NSMutableArray allocWithZone:[self zone]] init];
    else
        [list removeAllObjects];

    line = [VLine line];
    [line setColor:color];
    [line setWidth:width];
    p0 = ll;
    p1.x = ur.x; p1.y = ll.y;
    [line setVertices:p0 :p1];
    [list addObject:line];

    line = [VLine line];
    [line setColor:color];
    [line setWidth:width];
    p0 = p1;
    p1 = ur;
    [line setVertices:p0 :p1];
    [list addObject:line];

    line = [VLine line];
    [line setColor:color];
    [line setWidth:width];
    p0 = p1;
    p1.x = ll.x; p1.y = ur.y;
    [line setVertices:p0 :p1];
    [list addObject:line];

    line = [VLine line];
    [line setColor:color];
    [line setWidth:width];
    p0 = p1;
    p1 = ll;
    [line setVertices:p0 :p1];
    [list addObject:line];
    dirty = YES;
}

#define CREATEEVENTMASK NSLeftMouseDraggedMask|NSLeftMouseDownMask|NSLeftMouseUpMask|NSPeriodicMask
- (BOOL)create:(NSEvent *)event in:(DocView*)view
{   NSRect		viewBounds, gridBounds, drawBounds;
    NSPoint		start, last, gridPoint, drawPoint, lastPoint = NSZeroPoint;
    id			window = [view window];
    BOOL		ok = YES, dragging = NO, inTimerLoop = NO;
    float		grid = 1.0/*(float)[view rasterSpacing]*/;
    int			windowNum = [event windowNumber];
    NSColor		*col = [self color];

    [[(App*)NSApp inspectorPanel] loadGraphic:self];	/* set the values of the inspector to self */

    start = [event locationInWindow];
    start = [view convertPoint:start fromView:nil];	/* convert window to view coordinates */
    [view hitEdge:&start spare:self];			/* snap to point */
    start = [view grid:start];				/* set on grid */
    viewBounds = [view visibleRect];			/* get the bounds of the view */
    [view lockFocus];					/* and lock the focus on view */

    [self setRectangle:start :start];
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
            /* if user is dragging we scroll the view */
            if (dragging)
            {   [view scrollPointToVisible:drawPoint];
                viewBounds = [view bounds];
            }
            gridPoint = drawPoint;
            /* snap to point */
            [view hitEdge:&gridPoint spare:self];
            /* fix position to grid */
            gridPoint = [view grid:gridPoint];

            [window displayCoordinate:gridPoint ref:NO];

            [self setColor:[NSColor lightGrayColor]];
            [self setRectangle:start :drawPoint];
            drawBounds = [self extendedBoundsWithScale:[view scaleFactor]];
            if ( NSContainsRect(viewBounds , drawBounds) )	/* line inside view ? */
                [self drawWithPrincipal:view];

            [self setColor:col];
            [self setRectangle:start :gridPoint];
            gridBounds = [self extendedBoundsWithScale:[view scaleFactor]];
            /* if line is not inside view we set it invalid */
            if ( NSContainsRect(viewBounds , gridBounds) )
                [self drawWithPrincipal:view];
            else
                drawPoint = gridPoint = start;
            /* the united rect of the two rects we need to redraw the view */
            gridBounds = NSUnionRect(drawBounds, gridBounds);

            [window flushWindow];
        }
        event = [NSApp nextEventMatchingMask:CREATEEVENTMASK untilDate:[NSDate distantFuture] inMode:NSEventTrackingRunLoopMode dequeue:YES];
    }
    StopTimer(inTimerLoop);

    last = gridPoint;
    if ( fabs(last.x-start.x) <= grid && fabs(last.y-start.y) <= grid )		/* no length -> not valid */
        ok = NO;
    else if ( (!dragging && [event type]==NSLeftMouseDown)||(dragging && [event type]==NSLeftMouseUp) )
    {   /* double click or out of window -> not valid */
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

    dirty = YES;
    [view cacheGraphic:self];	// add to graphic cache

    return YES;
}

/* copy subpath-lists to main list
 */
- (id)unnest
{   NSMutableArray	*pList = [NSMutableArray array];
    int             i, cnt = [self count];

    for ( i=0; i<cnt; i++ )
    {	int         j, jCnt;
        VGraphic	*g = [[self list] objectAtIndex:i];

        if ([g isKindOfClass:[VPath class]])
        {
            jCnt = [(VPath*)g count];
            for ( j=0; j<jCnt; j++ )
                [pList addObject:[[(VPath*)g list] objectAtIndex:j]];
            [[(VPath*)g list] removeAllObjects];
        }
        else
            [pList addObject:g];
    }
    [self setList:pList];
    return self;
}

- (NSMutableArray*)list
{
    return list;
}

/* set new list and return the old list
 */
- (void)setList:aList
{
    [self setList:aList optimize:YES];
}
- (void)setList:aList optimize:(BOOL)optimize
{
    if (list)
        [list release];
    list = [aList retain];
    if ( optimize )
        [self optimize];
    coordBounds = bounds = NSZeroRect;
    dirty = YES;
    graduateDirty = YES;
}

/* returns the endpoints of an open path
 */
- (void)getEndPoints:(NSPoint*)p1 :(NSPoint*)p2
{
    *p1 = [[list objectAtIndex:0] pointWithNum:0];
    *p2 = [[list objectAtIndex:[list count]-1] pointWithNum:MAXINT]; 
}

- (unsigned)count
{
    return [list count];
}

- (unsigned)countRecursive
{   int	i, cnt = [list count];

    for (i=[list count]-1; i>=0; i--)
    {	id	g = [list objectAtIndex:i];

        if ([g isKindOfClass:[VPath class]])
            cnt += [g countRecursive];
    }
    return cnt;
}

/* created:  24.09.95
 * modified: 
 * purpose:  deselect all planes
 */
- (void)deselectAll
{   int	i;

    for (i=[list count]-1; i>=0; i--)
        [[list objectAtIndex:i] setSelected:NO];
}

/*
 * returns the selected knob (0 or 1) or -1
 */
- (int)selectedKnobIndex
{
    if ( ![list count] || selectedObject < 0)
        return -1;

    {   int	i, cnt, pCnt = 0, prevPCnt = 0;

        for (i=0, cnt = [list count]; i<cnt; i++)
        {   pCnt += [[list objectAtIndex:i] numPoints];
            if ( i == selectedObject )
                break;		// this object is our selected object
            prevPCnt = pCnt;	// count of pts befor this gr
        }
        return prevPCnt + [[list objectAtIndex:i] selectedKnobIndex];
    }
    return -1;
}

/*
 * set selection
 */
- (void)setSelected:(BOOL)flag
{
    if (!flag)
    {
	if (selectedObject >= 0)
            [[list objectAtIndex:selectedObject] setSelected:NO];
        selectedObject = -1;
    }
    [super setSelected:flag];
}

- (BOOL)filled
{
    return filled;
}

- (void)setFilled:(BOOL)flag
{
    [self setFilled:flag optimize:YES];
}
- (void)setFilled:(BOOL)flag optimize:(BOOL)optimize
{
    if (flag && optimize)
    {   [self closePath];
        [self setDirectionCCW:[self isDirectionCCW]];
    }
    filled = flag;
    if (optimize)
        [self optimize];
    dirty = YES;
    graduateDirty = YES;
}

- (void)setWidth:(float)w
{   int	i, cnt;

    for (i=0, cnt = [list count]; i<cnt; i++)
        [(VGraphic*)[list objectAtIndex:i] setWidth:w];

    width = w;
    dirty = YES;
}

- (void)setFillColor:(NSColor*)col
{
    if (fillColor) [fillColor release];
    fillColor = [((col) ? col : [NSColor blackColor]) retain];
    dirty = YES;
    graduateDirty = YES;
}
- (NSColor*)fillColor			{ return fillColor; }

- (void)setEndColor:(NSColor*)col
{
    if (endColor) [endColor release];
    endColor = [((col) ? col : [NSColor blackColor]) retain];
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

- (NSMutableArray*)graduateList     { return graduateList; }

/* length of sub-path
 * this returns the length of objects from index to index in list
 * frIndex <= index <= toIndex
 *
 * created:  2008-01-13
 * modified: 2008-01-17
 */
- (float)lengthFrom:(int)frIx to:(int)toIx
{   float   len = 0.0;
    int     i;

    if (toIx >= [list count])
        toIx = [list count] - 1;
    for(i=frIx; i<=toIx; i++)
    {   VGraphic    *g = [list objectAtIndex:i];
        len += [g length];
    }
    return len;
}

/*
 * add a list to our list
 * after the operation we are selected, all of our objects are deselected
 */
- (void)addList:(NSArray*)addList at:(int)index
{   int	i, cnt;

    if (!list)
        list = [[NSMutableArray allocWithZone:[self zone]] init];

    cnt = [addList count];
    for (i=0; i<cnt; i++)
    {	id	g = [addList objectAtIndex:i];

        [g setSelected:NO];
        if ([g isKindOfClass:[VPath class]])	/* we dont want a path inside a path ! */
            [self addList:[g list] at:[list count]];
        else
            [list insertObject:g atIndex:index++];
    }
    [self optimize];
    coordBounds = bounds = NSZeroRect;
    dirty = YES;
    graduateDirty = YES;
}

/* optimize subpaths inside list of path
 * inner subpaths before outer subpaths (smallest first)
 */
- (NSRect)boundsOfSubpathFrom:(int)beg to:(int)end
{   int		i;
    NSRect	rect, bbox;

    bbox = [[list objectAtIndex:0] bounds];
    for ( i=beg; i<end; i++ )
    {   id	g = [list objectAtIndex:i];

        rect = [g bounds];
        bbox = NSUnionRect(rect, bbox);
    }
    return bbox;
}
- (void)optimize
{   int             i, j, k, l, kcnt, cnt, beg1, end1, beg2, end2;
    NSMutableArray	*subpaths = [NSMutableArray array];
    NSMutableArray 	*array1 = [NSMutableArray array], *array2 = [NSMutableArray array];
    NSRect          bounds1, bounds2;

    if ( !filled )
        return;

    /* array of indexes of subpaths (0 - 3 - 8) */
    [subpaths addObject:[NSNumber numberWithInt:0]];
    for ( i=0, cnt=[list count]; i<cnt; i=j+1 )
    {
        j = [self getLastObjectOfSubPath:i];
        [subpaths addObject:[NSNumber numberWithInt:j+1]];
    }

    /* compare bounds of subpath -> exchange if necessary */
    for ( i=0; i < (int)[subpaths count]-2; i++ )
    {
        beg1 = [[subpaths objectAtIndex:i] intValue];
        end1 = [[subpaths objectAtIndex:i+1] intValue]-1;
        bounds1 = [self boundsOfSubpathFrom:beg1 to:end1];

        for ( j=i+1; j<(int)[subpaths count]-1; j++ )
        {
            beg2 = [[subpaths objectAtIndex:j] intValue];
            end2 = [[subpaths objectAtIndex:j+1] intValue]-1;
            bounds2 = [self boundsOfSubpathFrom:beg2 to:end2];
            if ( bounds1.size.width*bounds1.size.height > bounds2.size.width*bounds2.size.height )
            {   NSAutoreleasePool	*pool;

                /* swap subpaths in list */
                [array1 replaceObjectsInRange:NSMakeRange(0, [array1 count]) withObjectsFromArray:list range:NSMakeRange(beg1, end1-beg1+1)];
                [array2 replaceObjectsInRange:NSMakeRange(0, [array2 count]) withObjectsFromArray:list range:NSMakeRange(beg2, end2-beg2+1)];
                [list replaceObjectsInRange:NSMakeRange(beg2, end2-beg2+1) withObjectsFromArray:array1];
                [list replaceObjectsInRange:NSMakeRange(beg1, end1-beg1+1) withObjectsFromArray:array2];

                /* update array of indexes of subpaths (0 - 3 - 8) */
                [subpaths removeAllObjects];
                pool = [NSAutoreleasePool new];
                [subpaths addObject:[NSNumber numberWithInt:0]];
                for ( k=0, kcnt=[list count]; k<kcnt; k=l+1 )
                {
                    l = [self getLastObjectOfSubPath:k];
                    [subpaths addObject:[NSNumber numberWithInt:l+1]];
                }
                [pool release];
                dirty = YES;
                i--; j=cnt;
            }
        }
    }

/*
    for ( i=0, cnt=[list count]; i<cnt; i=j+1 )
    {
        j = [self getLastObjectOfSubPath:i];
        NSLog(@"b:%d n:%d", i, j-i+1);
    }
*/
}

/* end point of g1 must fit to start point of g2
 */
- (BOOL)closeGapBetween:(VGraphic*)g1 and:(VGraphic*)g2
{   NSPoint	p, p0, p1;

    if ( ![g1 isKindOfClass:[VArc class]] )		/* g1 != arc */
    {
        if ( [g1 isKindOfClass:[VLine class]] && ![g2 isKindOfClass:[VArc class]] )
        {   NSPoint	p2, p3;

            [(VLine*)g1 getVertices:&p0 :&p1];
            p2 = [g2 pointWithNum:0];
            p3 = [g2 pointWithNum:MAXINT];
            if ( Diff(p0.y, p1.y) < TOLERANCE ) // g1 horicontal
            {
                if ( Diff(p1.y, p2.y) > TOLERANCE )
                    [g2 movePoint:0 to:p1]; // correct y difference of g2
                else if ( Diff(p1.x, p2.x) > TOLERANCE )
                    [g1 movePoint:MAXINT to:p2]; // correct x difference
            }
            else if ( Diff(p0.x, p1.x) < TOLERANCE ) // g1 vertical
            {
                if ( Diff(p1.x, p2.x) > TOLERANCE )
                    [g2 movePoint:0 to:p1]; // correct x difference
                else if ( Diff(p1.y, p2.y) > TOLERANCE )
                    [g1 movePoint:MAXINT to:p2]; // correct y difference
            }
            else
            {   p = [g2 pointWithNum:0];
                [g1 movePoint:MAXINT to:p];
            }
        }
        else
        {   p = [g2 pointWithNum:0];
            [g1 movePoint:MAXINT to:p];
        }
    }
    else if ( ![g2 isKindOfClass:[VArc class]] )	/* g2 != arc - g1 is an arc */
    {
        p = [g1 pointWithNum:MAXINT];
        [g2 movePoint:0 to:p];
    }
    else					/* g1, g2 == arc -> insert line */
    {	p0 = [g1 pointWithNum:MAXINT];
        p1 = [g2 pointWithNum:0];
        if ( Diff(p0.x, p1.x) || Diff(p0.y, p1.y) )
        {   VLine	*line = [VLine line];
            [line setColor:[g1 color]];
            [line setWidth:[g1 width]];
            [line setVertices:p0 :p1];
            [list insertObject:line atIndex:[list indexOfObject:g1]+1];
            return YES;
        }
    }
    dirty = YES;
    return NO;
}

- (BOOL)closed
{   int		i, cnt = [list count];
    id		g0, g1 = 0;
    NSPoint	beg, p0, p1;

    if ( !cnt )
        return YES;
    g0 = [list objectAtIndex:0];
    beg = [g0 pointWithNum:0];
    for (i=1; i<cnt; i++)
    {	g1 = [list objectAtIndex:i];

        p0 = [g0 pointWithNum:MAXINT];
        p1 = [g1 pointWithNum:0];
        /* connected with next object -> ok, continue */
        if ( Diff(p0.x, p1.x)<TOLERANCE && Diff(p0.y, p1.y)<TOLERANCE )
        {   g0 = g1;
            continue;
        }
        /* connected with beg -> ok, p1 is our new beg, continue */
        else if ( Diff(p0.x, beg.x)<TOLERANCE && Diff(p0.y, beg.y)<TOLERANCE )
        {   g0 = g1;
            beg = p1;
            continue;
        }
        /* not connected -> open end */
        return NO;
    }
    /* last object connected with beg -> ok */
    p0 = [g0 pointWithNum:MAXINT];
    if ( Diff(p0.x, beg.x)<TOLERANCE && Diff(p0.y, beg.y)<TOLERANCE )
        return YES;
    return NO;
}

- (void)closePath
{   int         i, iCnt;
    VGraphic    *g0, *g1 = nil;
    NSPoint     beg, p0, p1;
    float       dx=0, dy=0, dx0=0, dy0=0;

    if ( ![list count] )
        return;
    g0 = [list objectAtIndex:0];
    beg = [g0 pointWithNum:0];
    for ( i=1, iCnt = [list count]; i<iCnt; i++ )
    {	g1 = [list objectAtIndex:i];

        p0 = [g0 pointWithNum:MAXINT];
        p1 = [g1 pointWithNum:0];
        /* gap */
        dx = Diff(p0.x, p1.x);
        dy = Diff(p0.y, p1.y);
        if ( dx > 10*TOLERANCE || dy > 10*TOLERANCE )
        {
            /* if this is the end of a closed subpath we add no line */
            dx0 = Diff(p0.x, beg.x);
            dy0 = Diff(p0.y, beg.y);
            if ( dx0 > TOLERANCE || dy0 > TOLERANCE )
            {   VLine	*line = [VLine line];

                [line setColor:[g1 color]];
                [line setWidth:[g1 width]];

                // gap to next graphic smaller than to startgraphic -> close to nextG
                if ( dx < dx0 && dy < dy0 && dx < dy0 && dy < dx0 )
                {
                    [line setVertices:p0 :p1];
                    [list insertObject:line atIndex:i];
                    dirty = YES;
                    graduateDirty = YES;
                    i++; iCnt++;
                    g0 = g1;
                    continue;
                }
                [line setVertices:p0 :beg];
                [list insertObject:line atIndex:i];
                dirty = YES;
                graduateDirty = YES;
                i++; iCnt++;
            }
            g0 = g1;
            beg = p1;
        }
        else
            g0 = g1;
    }

    p0 = [g0 pointWithNum:MAXINT];
    p1 = beg;
    if ( /*iCnt==1 ||*/ Diff(p0.x, p1.x)>TOLERANCE || Diff(p0.y, p1.y)>TOLERANCE )
    {   VLine	*line = [VLine line];

        [line setColor:[g1 color]];
        [line setWidth:[g1 width]];
        [line setVertices:p0 :beg];
        [list addObject:line];
        dirty = YES;
        graduateDirty = YES;
    }
}
#if 0
- (void)closePath
{   int		i, iCnt;
    id		g0, g1 = 0;
    NSPoint	beg, p0, p1;

    if ( ![list count] )
        return;
    g0 = [list objectAtIndex:0];
    beg = [g0 pointWithNum:0];
    for ( i=1, iCnt = [list count]; i<iCnt; i++ )
    {	g1 = [list objectAtIndex:i];

        p0 = [g0 pointWithNum:MAXINT];
        p1 = [g1 pointWithNum:0];
        /* gap */
        if ( Diff(p0.x, p1.x)>10*TOLERANCE || Diff(p0.y, p1.y)>10*TOLERANCE )
        {
            /* if this is the end of a closed subpath we add no line */
            if ( Diff(p0.x, beg.x)>TOLERANCE || Diff(p0.y, beg.y)>TOLERANCE )
            {   VLine	*line = [VLine line];

                [line setColor:[g1 color]];
                [line setWidth:[g1 width]];
                [line setVertices:p0 :beg];
                [list insertObject:line atIndex:i];
                dirty = YES;
                i++; iCnt++;
            }
            g0 = g1;
            beg = p1;
        }
        else
            g0 = g1;
    }

    p0 = [g0 pointWithNum:MAXINT];
    p1 = beg;
    if ( /*iCnt==1 ||*/ Diff(p0.x, p1.x)>TOLERANCE || Diff(p0.y, p1.y)>TOLERANCE )
    {   VLine	*line = [VLine line];

        [line setColor:[g1 color]];
        [line setWidth:[g1 width]];
        [line setVertices:p0 :beg];
        [list addObject:line];
        dirty = YES;
    }
}
#endif

/* optimize objects in list, so that they line up correctly
 */
- (void)sortList
{   int			i, iCnt, begIx;
    NSPoint		beg, end, p;
    id			g;
    NSMutableArray	*jlist = list, *newList = [NSMutableArray array];
    float		dist = TOLERANCE;

    /* copy objects from jlist to nesList in correct order
     */
    while ( (iCnt = [jlist count]) )
    {
        g = [jlist objectAtIndex:0];
        [newList addObject:g];
        begIx = [newList count]-1;
        beg = [g pointWithNum:0];
        end = [g pointWithNum:MAXINT];
        [jlist removeObject:g];

        iCnt = [jlist count];
        for ( i=0; i<iCnt; i++ )
        {   g = [jlist objectAtIndex:i];
            p = [g pointWithNum:0];
            if ( SqrDistPoints(p, beg)<dist*dist )	/* start of new object fits to start of sequence */
            {	[g changeDirection];
                [newList insertObject:g atIndex:begIx];
                beg = [g pointWithNum:0];
            }
            else if ( SqrDistPoints(p, end)<dist*dist )	/* start of new object fits to end of sequence */
            {	[newList addObject:g];
                end = [g pointWithNum:MAXINT];
                dirty = YES;
            }
            else
            {	p = [g pointWithNum:MAXINT];
                if ( SqrDistPoints(p, beg)<dist*dist )	/* end of new object fits to start of sequence */
                {   [newList insertObject:g atIndex:begIx];
                    beg = [g pointWithNum:0];
                }
                else if ( SqrDistPoints(p, end)<dist*dist )	/* end of new object fits to end of sequence */
                {   [g changeDirection];
                    [newList addObject:g];
                    end = [g pointWithNum:MAXINT];
                }
                else
                    continue;
            }
            [jlist removeObject:g];	/* start from the beginning of jlist */
            iCnt = [jlist count];
            i = -1;
        }
    }
    [self setList:newList];
}

/* jlist	list of objects
 * dist		maximum distance between objects
 */
- (void)complexJoin:(NSMutableArray*)jlist distance:(float)dist
{   int         i;
    VGraphic    *g;

    // jlist is selected list
    [jlist removeObject:self];

    /* extract paths and add all objects inside jlist to list
     */
    for ( i=0; i < [jlist count]; i++ )
    {
	g = [jlist objectAtIndex:i];
        [g setOutputStream:nil];
        if ( [g isKindOfClass:[VRectangle class]] )
        {   g = [(VRectangle*)g pathRepresentation];
            [jlist replaceObjectAtIndex:i withObject:g];
        }
        if ( [g isKindOfClass:[VPath class]] )
        {   int	j, jCnt = [[(VPath*)g list] count];

            for ( j=0; j<jCnt; j++ )	/* copy object from g to jlist */
                [list addObject:[[(VPath*)g list] objectAtIndex:j]];
        }
        else
            [list addObject:g];
        [jlist removeObject:g];
        i--;
    }

    /* set new jlist
     */
    [self optimizePath:dist];

    [jlist addObject:self];
    [self setSelected:YES];

    /* if an object has no contact we close to the start of the sequence
     */
    if (filled)
        [self closePath];
    coordBounds = bounds = NSZeroRect;
    dirty = YES;
    graduateDirty = YES;
}
#if 0 // old
- (void)complexJoin:jlist distance:(float)dist
{   int		i, iCnt, begIx;
    NSPoint	beg, end, p;
    id		g;
    //BOOL	hasStart = NO;	/* it may happen that we join subpaths at their starting and end points! */

    [jlist removeObject:self];

    /* extract paths inside jlist to jlist
     */
    iCnt = [jlist count];
    for ( i=0; i<iCnt; i++ )
    {
	g = [jlist objectAtIndex:i];
        [g setOutputStream:nil];
        if ( [g isKindOfClass:[VRectangle class]] )
        {   g = [g pathRepresentation];
            [jlist replaceObjectAtIndex:i withObject:g];
        }
        if ( [g isKindOfClass:[VPath class]] )
        {   int	j, jCnt = [[g list] count];

            for ( j=0; j<jCnt; j++ )	/* copy object from g to jlist */
                [jlist addObject:[[g list] objectAtIndex:j]];
            [jlist removeObject:g];
            i--;
        }
    }

    /* copy objects from list to beginning of jlist
     */
    for ( i=[list count]-1; i>=0; i-- )
        [jlist insertObject:[list objectAtIndex:i] atIndex:0];
    [list removeAllObjects];

    /* copy objects from jlist to list in correct order
     */
    while ( (iCnt = [jlist count]) )
    {
        g = [jlist objectAtIndex:0];
        [list addObject:g];
        begIx = [list count]-1;
        beg = [g pointWithNum:0];
        end = [g pointWithNum:MAXINT];
        [jlist removeObject:g];

        iCnt = [jlist count];
        for ( i=0; i<iCnt; i++ )
        {   g = [jlist objectAtIndex:i];
            p = [g pointWithNum:0];
            if ( SqrDistPoints(p, beg)<dist*dist )	/* start of new object fits to start of sequence */
            {	[g changeDirection];
                [list insertObject:g atIndex:begIx];
                beg = [g pointWithNum:0];
                [self closeGapBetween:g and:[list objectAtIndex:begIx+1]];
            }
            else if ( SqrDistPoints(p, end)<dist*dist )	/* start of new object fits to end of sequence */
            {	[list addObject:g];
                end = [g pointWithNum:MAXINT];
                [self closeGapBetween:[list objectAtIndex:[list count]-2] and:g];
            }
            else
            {	p = [g pointWithNum:MAXINT];
                if ( SqrDistPoints(p, beg)<dist*dist )	/* end of new object fits to start of sequence */
                {   [list insertObject:g atIndex:begIx];
                    beg = [g pointWithNum:0];
                    [self closeGapBetween:g and:[list objectAtIndex:begIx+1]];
                }
                else if ( SqrDistPoints(p, end)<dist*dist )	/* end of new object fits to end of sequence */
                {   [g changeDirection];
                    [list addObject:g];
                    end = [g pointWithNum:MAXINT];
                    [self closeGapBetween:[list objectAtIndex:[list count]-2] and:g];
                }
                else if ( SqrDistPoints(beg, end) < TOLERANCE*TOLERANCE )
                    break; // closed sequence - time
                else // open sequence // close to start or search next obj
                    /* wenn current nicht closed zu start/beg / distance kleiner 1.0 */
                    /* hier muessen wir irgendwie das objekt mit dem kleinsten Abstand finden !? */
                    /* 4 distanzen merken ? - nur den kleinsten der 4 (zum Start oder continued !? - merken) */
                    /* objektIndex merken - flag setzen */
                    continue;
            }
            // if ( distanceObject ) beg / end setzen etc

            [jlist removeObject:g];	/* start from the beginning of jlist */
            iCnt = [jlist count];
            i = -1;
        }
    }

    /* if an object has no contact we close to the start of the sequence
     */
    if (filled)
        [self closePath];
    coordBounds = bounds = NSZeroRect;
    dirty = YES;
    graduateDirty = YES;
}
#endif

- (void)join:obj
{   BOOL    getDirection = NO;

    if (!list)
       list = [[NSMutableArray allocWithZone:[self zone]] init];

    if ( ![list count] )
        getDirection = YES;

    if ( [obj isKindOfClass:[VRectangle class]] )
        obj = [obj pathRepresentation];
    if ( [obj isKindOfClass:[NSMutableArray class]] )
    {
        [self complexJoin:obj distance:1.0]; // 0.1 30.0*TOLERANCE
    }
    /* two closed paths -> we simply place the objects of obj at the end of our list
     */
    else if ( ([obj isKindOfClass:[VPath class]] && [obj closed] && [self closed]) )
              //([obj isKindOfClass:[VPolyLine class]] && [obj filled] && [self closed]) 
    {	NSMutableArray	*olist = [obj list];
        int		i, cnt = [olist count];

        for (i=0; i<cnt; i++)
            [list addObject:[olist objectAtIndex:i]];
    }
    /* add other filled objects simply to the end of our list */
    else if ( [obj respondsToSelector:@selector(filled)] && [obj filled] && [self closed] )
    {
        [list addObject:obj];
    }
    /* add object to the end of ourself
     */
    else
    {
        if (![list count])	/* obj is the 1st object in list */
        {
            [list addObject:obj];
            [obj setOutputStream:nil];
        }
        else if ([obj selectedKnobIndex] != -1)	/* a knob of the new object is selected */
        {
            if ([self selectedKnobIndex] != -1)	/* a knob of us is selected */
                ;	/* add new object the way that both selected ends are connected */
            else
            {   [self addToClosestEnd:obj];	/* add new object with selected end to our closest end */
                [obj setOutputStream:nil];
            }
        }
        else	/* connect the closest endpoints */
        {   [self addToClosestEnd:obj];
            [obj setOutputStream:nil];
        }
    }

    //getDirection = YES; // for 1Line Font Direction editing ! ! !
    if ( getDirection )
    {   int sIx=0, eIx;

        eIx = [self getLastObjectOfSubPath2:sIx];
        isDirectionCCW = [self directionOfSubPath:sIx :eIx];
    }

    if ( filled || [self closed] )
        [self setDirectionCCW:[self isDirectionCCW]];
    [self optimize];
    [self deselectAll];
    selectedObject = -1;
    coordBounds = bounds = NSZeroRect;
    dirty = YES;
    graduateDirty = YES;
}

- (void)addToClosestEnd:obj
{   NSPoint	pa, pb, p1, p2;
    float	da1, da2, db1, db2, dist = 100.0*TOLERANCE;
    int		ix;
    VLine	*g = 0;

    if ([obj selectedKnobIndex] >= 0)	/* knob of obj is selected */
    {	pa = [obj pointWithNum:[obj selectedKnobIndex]];
        if ( [obj selectedKnobIndex]==0 )
            pb.x = pb.y = LARGE_COORD;
        else
            pb = pa, pa.x = pa.y = LARGE_COORD;
    }
    else	/* no knob of object selected */
    {	if ([obj isKindOfClass:[VPath class]])
        [obj getEndPoints:&pa :&pb];
        else
        {   pa = [obj pointWithNum:0];
            pb = [obj pointWithNum:MAXINT];
        }
    }
    [self getEndPoints:&p1 :&p2];

    /* closer 1st point (p1) -> add object at beginning of list */
    da1 = SqrDistPoints(pa, p1);
    da2 = SqrDistPoints(pa, p2);
    db1 = SqrDistPoints(pb, p1);
    db2 = SqrDistPoints(pb, p2);
    /* circle */
    if ( [obj isKindOfClass:[VArc class]] && Abs([obj angle]) >= 360.0 )
        ix = [list count];
    else if ( da1<da2 && da1<db1 && da1<db2 )	/* pa / p1 */
    {
        [obj changeDirection];
        if (da1 && da1 < dist)	// close the gap with a line
        //if (da1)	// close the gap with a line	2005-03-29
        {   g = [VLine line];
            [g setVertices:pa :p1];
            [list insertObject:g atIndex:0];
        }
        ix = 0;	/* the new object becomes our 1st object in the list */
    }
    else if ( da2<=da1 && da2<=db1 && da2<=db2 )	/* pa / p2 */
    {
        if (da2 && da2 < dist)	// close the gap with a line
        //if (da2)	// close the gap with a line	2005-03-29
        {   g = [VLine line];
            [g setVertices:p2 :pa];
            [list insertObject:g atIndex:[list count]];
        }
        ix = [list count];	/* the new object becomes our last object */
    }
    else if ( db1<=da1 && db1<=da2 && db1<=db2 )	/* pb / p1 */
    {
        if (db1 && db1 < dist)	// close the gap with a line
        //if (db1)	// close the gap with a line	2005-03-29
        {   g = [VLine line];
            [g setVertices:pb :p1];
            [list insertObject:g atIndex:0];
        }
        ix = 0;	/* the new object becomes our 1st object in the list */
    }
    else	/* pb / p2 */
    {
        [obj changeDirection];
        if (db2 && db2 < dist)	// close the gap with a line
        //if (db2)	// close the gap with a line	2005-03-29
        {   g = [VLine line];
            [g setVertices:p2 :pb];
            [list insertObject:g atIndex:[list count]];
        }
        ix = [list count];	/* the new object becomes our last object */
    }

    [g setColor:color];
    [g setWidth:width];
    if ([obj isKindOfClass:[VPath class]])
    {	[self addList:[obj list] at:ix];
        [[obj list] removeAllObjects];
    }
    else
        [list insertObject:obj atIndex:ix];
}

/* split
 * modified: 2012-01-20 ( use getLastObjectOfSubPath2: to split open paths faster)
 * copy all objects from the path to the ulist
 * the ungrouped objects are selected
 */
- (void)splitTo:ulist
{   int	i, begIx = 0, endIx = 0, cnt = [list count];

    endIx = [self getLastObjectOfSubPath2:begIx];

    /* path with subpaths splitted to paths ! */
    if (endIx != cnt-1)
    {
        while (endIx <= cnt-1)
        {

            if (begIx == endIx)
            {   VGraphic    *g = [list objectAtIndex:begIx];

                [g setSelected:YES];
                [g setColor:color];
                [g setWidth:width];
                if (([g isKindOfClass:[VArc class]] && Diff(Abs([g angle]), 360.0) <= TOLERANCE) ||
                     [g isKindOfClass:[VRectangle class]] || [g isKindOfClass:[VPolyLine class]])
                {
                    [g setFilled:NO];
                    if (fillColor)
                    {   [(VArc*)g setFillColor:fillColor];
                        [(VArc*)g setStepWidth:stepWidth];
                        [(VArc*)g setRadialCenter:radialCenter];
                    }
                }
                [ulist addObject:g];
            }
            else
            {   VPath	*pg = [VPath path];

                [pg setFilled:NO];
                [pg setSelected:YES];
                [pg setColor:color];
                if (fillColor)
                {   [pg setFillColor:fillColor];
                    [pg setStepWidth:stepWidth];
                    [pg setRadialCenter:radialCenter];
                }
                [pg setWidth:width];
                for (i=begIx; i<=endIx; i++)
                    [[pg list] addObject:[list objectAtIndex:i]];
                [ulist addObject:pg];
            }
            begIx = endIx+1;
            if (begIx > cnt-1)
                break;
            endIx = [self getLastObjectOfSubPath2:begIx]; //  tolerance:TOLERANCE
        }
    }
    else
        for ( i = 0, cnt = [list count]; i < cnt; i++ )
        {	VGraphic    *g = [list objectAtIndex:i];

            [g setSelected:YES];
            [g setColor:color];
            [g setWidth:width];
            [ulist addObject:g];
        }
}


- (void)setSize:(NSSize)newSize
{   NSRect	bRect = [self coordBounds];

    [self scale:((bRect.size.width)  ? newSize.width /bRect.size.width  : 1.0)
               :((bRect.size.height) ? newSize.height/bRect.size.height : 1.0)
     withCenter:bRect.origin];
}
- (NSSize)size
{   NSRect	bRect = [self coordBounds];
    return bRect.size;
}

- (void)setBoundsZero
{
    coordBounds = bounds = NSZeroRect;
}

/* created:  16.09.95
 * modified: 2000-11-03
 *
 * Returns the bounds.
 */
- (NSRect)coordBounds
{
    if ( ![list count] )
        return NSZeroRect;

    if (coordBounds.size.width == 0.0 && coordBounds.size.height == 0.0)
    {   NSRect	rect;
        int	i, cnt = [list count]-1;

        coordBounds = [[list objectAtIndex:cnt] coordBounds];
        for (i=cnt-1; i>=0; i--)
        {   rect = [[list objectAtIndex:i] coordBounds];
            coordBounds = VHFUnionRect(rect, coordBounds);
        }
    }
    return coordBounds;
}

- (NSRect)bounds
{
    if ( ![list count] )
        return NSZeroRect;

    if (bounds.size.width == 0.0 && bounds.size.height == 0.0)
    {   NSRect	rect;
        int	i, cnt = [list count]-1;

        bounds = [[list objectAtIndex:cnt] bounds];
        for (i=cnt-1; i>=0; i--)
        {   rect = [[list objectAtIndex:i] bounds];
            bounds = VHFUnionRect(rect, bounds);
        }
    }
    return bounds;
}

/*
- (NSRect)extendedBoundsWithScale:(float)scale
{   NSRect	rect, bRect;
    int		i, cnt = [list count]-1;

    if ( cnt<0 )
        return NSZeroRect;
    bRect = [[list objectAtIndex:cnt] extendedBoundsWithScale:scale];
    for (i=cnt-1; i>=0; i--)
    {	rect = [[list objectAtIndex:i] extendedBoundsWithScale:scale];
        bRect = NSUnionRect(rect , bRect);
    }
    return bRect;
}
*/
/* created:  22.10.95
 * modified: 28.02.97
 *
 * Returns the bounds at the given rotation.
 */
- (NSRect)boundsAtAngle:(float)angle withCenter:(NSPoint)cp
{   NSRect	rect, bRect;
    int		i, cnt = [list count]-1;

    bRect = [(VGraphic*)[list objectAtIndex:cnt] boundsAtAngle:angle withCenter:cp];
    for (i=cnt-1; i>=0; i--)
    {	rect = [(VGraphic*)[list objectAtIndex:i] boundsAtAngle:angle withCenter:cp];
        bRect = NSUnionRect(rect , bRect);
    }
    return bRect;
}

- (void)drawKnobs:(NSRect)rect direct:(BOOL)direct scaleFactor:(float)scaleFactor
{
    if ( (NSIsEmptyRect(rect) || !NSIsEmptyRect(NSIntersectionRect(rect, [self extendedBoundsWithScale:scaleFactor]))) )
    {
	if ( VHFIsDrawingToScreen() && isSelected )
        {   int	i, cnt = [list count], step = (cnt<2000) ? 1 : cnt/2000;

            for ( i=cnt-1; i>=0; i-=step )
            {	id	obj = [list objectAtIndex:i];

                if ( isSelected || [obj isSelected] )
                {   BOOL	sel = [obj isSelected];

                    [obj setSelected:YES];
                    [obj drawKnobs:rect direct:direct scaleFactor:scaleFactor];
                    [obj setSelected:sel];
                }
            }
        }
    }
}
- (void)drawControls:(NSRect)rect direct:(BOOL)direct scaleFactor:(float)scaleFactor
{
    if ( (NSIsEmptyRect(rect) ||
          !NSIsEmptyRect(NSIntersectionRect(rect, [self extendedBoundsWithScale:scaleFactor]))) )
    {
	if ( VHFIsDrawingToScreen() && isSelected )
        {   int	i, cnt = [list count], step = (cnt<2000) ? 1 : cnt/2000;

            for ( i=cnt-1; i>=0; i-=step )
            {	id	obj = [list objectAtIndex:i];
                BOOL	sel = [obj isSelected];

                [obj setSelected:YES];
                //[obj drawKnobs:rect direct:direct scaleFactor:scaleFactor];
                [obj drawControls:rect direct:direct scaleFactor:scaleFactor];
                [obj setSelected:sel];
                if ([obj isMemberOfClass:[VCurve class]])
                {   [NSBezierPath setDefaultLineWidth:1.0/scaleFactor];
                    [NSBezierPath strokeLineFromPoint:[obj pointWithNum:0] toPoint:[obj pointWithNum:1]];
                    [NSBezierPath strokeLineFromPoint:[obj pointWithNum:3] toPoint:[obj pointWithNum:2]];
                }
            }
        }
    }
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
{   VGraphic	*g = nil;

    if (pt_num != -1)
    {
        if ( pt_num >= [self numPoints] )
        {   g = [list objectAtIndex:[list count]-1];
            pt_num = MAXINT;
        }
        else if ( !pt_num )
            g = [list objectAtIndex:0];
        else
        {   int	i, cnt, pCnt = 0, prevPCnt = 0;

            for (i=0, cnt = [list count]; i<cnt; i++)
            {   pCnt += [[list objectAtIndex:i] numPoints];
                if ( pCnt > pt_num )
                    break;		// to this object refers our pt_num
                prevPCnt = pCnt;	// count of pts befor this gr
            }
            g = [list objectAtIndex:i];
            pt_num -= prevPCnt;
        }
        return [g scrollRect:pt_num inView:aView];
    }
    return [self bounds];
}

/* 
 * This method constains the point to the bounds of the view passed
 * in. Like the method above, the constaining is dependent on the
 * control point that has been selected.
 */
- (void)constrainPoint:(NSPoint *)aPt andNumber:(int)pt_num toView:aView
{   VGraphic	*g = nil;

    if (pt_num < 0)
        return;

    if ( pt_num >= [self numPoints] )
    {   g = [list objectAtIndex:[list count]-1];
        pt_num = MAXINT;
    }
    else if ( !pt_num )
        g = [list objectAtIndex:0];
    else
    {   int	i, cnt, pCnt = 0, prevPCnt = 0;

        for (i=0, cnt = [list count]; i<cnt; i++)
        {   pCnt += [[list objectAtIndex:i] numPoints];
            if ( pCnt > pt_num )
                break;		// to this object refers our pt_num
            prevPCnt = pCnt;	// count of pts befor this gr
        }
        g = [list objectAtIndex:i];
        pt_num -= prevPCnt;
    }
    [g constrainPoint:aPt andNumber:pt_num toView:aView];
}

- (NSPoint)nearestPointOnObject:(int*)objIndex distance:(float*)distance toPoint:(NSPoint)pt
{   int		i, cnt = [list count];
    NSPoint	cpt = NSZeroPoint, tpt;

    *distance = MAXCOORD;

    /* search nearest object to pt */
    for (i=0; i<cnt; i++)
    {	float		dist = MAXCOORD;
        VGraphic	*g = [list objectAtIndex:i];
        NSRect 		bRect = [g bounds];

        bRect = NSInsetRect(bRect, -2.0, -2.0);
        if ( !NSPointInRect(pt, bRect) )
            continue;
        if ([g isKindOfClass:[VLine class]])
        {   NSPoint	p0, p1;

            [(VLine*)g getVertices:&p0 :&p1];
            dist = pointOnLineClosestToPoint(p0, p1, pt, &tpt);
        }
        else if ([g isKindOfClass:[VArc class]])
            dist = [(VArc*)g getPointOnArcClosestToPoint:pt intersection:&tpt];
            //dist = pointOnArcClosestToPoint([g center], [g radius], [(VArc*)g begAngle], [g angle], pt, &tpt);
        else if ([g isKindOfClass:[VCurve class]])
        {   NSPoint	pc[4];

            [(VCurve*)g getVertices:&pc[0] :&pc[1] :&pc[2] :&pc[3]];
            dist = pointOnCurveNextToPoint(&tpt, pc, &pt);
        }
        else if ([g isKindOfClass:[VPolyLine class]])
        {   NSPoint	ppt;
            float	d;
            int		j, count = [g numPoints];

            dist = MAXCOORD;
            /* check nearest polyline line to pt */
            for (j=0; j<count-1; j++)
            {
                if ((d=pointOnLineClosestToPoint([g pointWithNum:j], [g pointWithNum:j+1], pt, &ppt)) <= dist)
                {   tpt = ppt;
                    dist = d;
                }
            }
        }
        else if ([g isKindOfClass:[VRectangle class]])
        {   VPath	*rp = [(VRectangle*)g pathRepresentation];
            int		j, rcnt = [[rp list] count];

            dist = MAXCOORD;
            for (j=0; j<rcnt; j++)
            {	float		d = MAXCOORD;
                VGraphic	*rg = [[rp list] objectAtIndex:j];
                NSRect 		bRect = [g bounds];
                NSPoint		rpt;

                bRect = NSInsetRect(bRect, -2.0, -2.0);
                if ( !NSPointInRect(pt, bRect) )
                    continue;
                if ([rg isKindOfClass:[VLine class]])
                {   NSPoint	p0, p1;

                    [(VLine*)rg getVertices:&p0 :&p1];
                    d = pointOnLineClosestToPoint(p0, p1, pt, &rpt);
                }
                else if ([rg isKindOfClass:[VArc class]])
                    d = [(VArc*)rg getPointOnArcClosestToPoint:pt intersection:&rpt];
                    //d = pointOnArcClosestToPoint([rg center], [rg radius], [(VArc*)rg begAngle], [rg angle], pt, &rpt);
                if (d <= dist)
                {   tpt = rpt;
                    dist = d;
                }
            }
        }
        if (dist <= *distance)
        {   cpt = tpt;
            *objIndex = i;
            *distance = dist;
        }
    }
    return cpt;
}

- (VGraphic*)addPointAt:(NSPoint)pt
{   NSMutableArray	*spList = nil;
    int			i, splitI = -1;
    NSPoint		cpt, start, end, sgStart, sgEnd;
    NSAutoreleasePool 	*pool = [NSAutoreleasePool new];
    float		distance=MAXCOORD;
    VGraphic		*splitg=nil;

    cpt = [self nearestPointOnObject:&splitI distance:&distance toPoint:pt];

    splitg = [list objectAtIndex:splitI];

    /* VPolyLine */
    if ([splitg isKindOfClass:[VPolyLine class]])
    {
        [(VPolyLine*)splitg addPointAt:pt];
        return self;
    }

    start = [self pointWithNum:0];
    end = [self pointWithNum:MAXINT];
    if ( (Diff(start.x, cpt.x) < 100.0*TOLERANCE && Diff(start.y, cpt.y) < 100.0*TOLERANCE) ||
         (Diff(end.x, cpt.x) < 100.0*TOLERANCE && Diff(end.y, cpt.y) < 100.0*TOLERANCE) )
    {   [pool release];
        return nil;
    }
    sgStart = [splitg pointWithNum:0];
    sgEnd = [splitg pointWithNum:MAXINT];
    if ((Diff(sgStart.x, cpt.x) > 100.0*TOLERANCE || Diff(sgStart.y, cpt.y) > 100.0*TOLERANCE) &&
        (Diff(sgEnd.x, cpt.x) > 100.0*TOLERANCE || Diff(sgEnd.y, cpt.y) > 100.0*TOLERANCE))
        spList = [splitg getListOfObjectsSplittedFrom:&cpt :1];
    else // nothing to add at s or e point
    {   [pool release];
        return nil;
    }
    /* remove splitg - add graphics from splist */
    [list removeObjectAtIndex:splitI];
    for (i=[spList count]-1; i>=0; i--)
        [list insertObject:[spList objectAtIndex:i] atIndex:splitI];

    [pool release];
    coordBounds = bounds = NSZeroRect;
    dirty = YES;
    graduateDirty = YES;
    return self;
}

/* the indices of the graphics around selected Point (which will be removed later) */
/* in correct order */
/* the index which will have the changed graphic will be returned */
- (int)changedValuesForRemovePointUndo:(int*)changedIx :(int*)chPt_num :(NSPoint*)changedPt
{   int		removedIx = -1, pt_num, begIx, endIx, nPts;
    VGraphic	*sg = [list objectAtIndex:selectedObject], *g1; // selectedObject
    NSPoint	sgPtStart, sgPtEnd;
    BOOL	connected = NO;

    if ( ![list count] || selectedObject < 0)
        return -4;

    pt_num = [sg selectedKnobIndex];
    nPts = [sg numPoints];

    /* point inside PolyLine */
    if ([sg isKindOfClass:[VPolyLine class]] && pt_num && pt_num < nPts-1 && nPts > 2)
    {
        chPt_num[0] = pt_num;   	     // we need pt_num inside PolyLine
        changedIx[0] = selectedObject; // and index of PolyLine inside Path
        removedIx = -1;
        return removedIx;
    }

    /* beg/end to selectedObjects subPath, + or - gr */
    begIx = [self getFirstObjectOfSubPath:selectedObject];
    endIx = [self getLastObjectOfSubPath:begIx];
    if (begIx == endIx)
        endIx = [list count]-1;

    if (([sg isKindOfClass:[VCurve class]] && (pt_num == 1 || pt_num == 2)) || 	// curve points 1,2
        ([sg isKindOfClass:[VArc class]] && pt_num == 2))			// arc center
        return -4;

    sgPtStart = [sg pointWithNum:0]; // notice old start point
    sgPtEnd = [sg pointWithNum:MAXINT]; // notice old end point

    /* get the connected Graphic to sg (selectedObject) */
    if (!pt_num) // corresponding gr is bevor sg
    {   NSPoint	g1PtEnd;

        g1 = (selectedObject-1>=begIx) ? [list objectAtIndex:selectedObject-1] : [list objectAtIndex:endIx];
        if ([sg isKindOfClass:[VArc class]] && [g1 isKindOfClass:[VArc class]])
            return -4; // two arcs we cant remove one and close the path Fix Me: open path and arc at end

        g1PtEnd = [g1 pointWithNum:MAXINT];
        if ( Diff(g1PtEnd.x, sgPtStart.x) < TOLERANCE && Diff(g1PtEnd.y, sgPtStart.y) < TOLERANCE)
            connected = YES;

        if (!connected && [sg isKindOfClass:[VPolyLine class]] && nPts > 2)
        {
            chPt_num[0] = pt_num;	 	// we need pt_num inside PolyLine
            changedIx[0] = selectedObject; // and index of PolyLine inside Path
            changedPt[0] = [sg pointWithNum:pt_num]; // old start point
            removedIx = -3;
            //[(VPolyLine*)g removePointWithNum:pt_num];
        }
        else if (!connected)
        {
            changedIx[0] = -1;
            removedIx = selectedObject; // notice the removed Graphic !
            changedPt[0] = [g1 pointWithNum:MAXINT]; // no point
            chPt_num[0] = -1;
            //[list removeObjectAtIndex:selectedObject];
        }

        else if ([sg isKindOfClass:[VPolyLine class]] && nPts > 2 && ![g1 isKindOfClass:[VArc class]])
        {
            chPt_num[0] = pt_num;	 // we need pt_num inside PolyLine // was pt_num+1
            changedIx[0] = selectedObject; // and index of PolyLine inside Path
            changedPt[0] = [sg pointWithNum:pt_num]; // old start point // was pt_num+1
            removedIx = -2;
            chPt_num[1] = MAXINT;
            changedIx[1] = (selectedObject-1>=begIx) ? (selectedObject-1) : (endIx);
            changedPt[1] = [g1 pointWithNum:MAXINT]; // g1 end will be moved to new sg start
            //[(VPolyLine*)g removePointWithNum:pt_num];
            //[g1 movePoint:MAXINT to:[g pointWithNum:0]]; // move g1 end to new start of polyLine
        }
        /* else if ([g1 isKindOfClass:[VPolyLine class]] && [g1 numPoints] > 2)
        {
            chPt_num[0] = [g1 numPoints]-2;	 // we need pt_num inside PolyLine
            changedIx[0] = (selectedObject-1>=begIx) ? (selectedObject-1) : (endIx); // and index of PolyLine inside Path
            changedPt[0] = [g1 pointWithNum:[g1 numPoints]-2]; // old start point
            removedIx = -3;
            //[(VPolyLine*)g1 removePointWithNum:MAXINT];
            //[g1 movePoint:MAXINT to:gPtStart];	// move previous (now last) point of polyline to close path
        } */
        else if ([g1 isKindOfClass:[VArc class]])			// remove g1
        {
            changedIx[0] = selectedObject;
            removedIx = (selectedObject-1>=begIx) ? (selectedObject-1) : (endIx);
            changedPt[0] = [sg pointWithNum:0]; // old start point
            chPt_num[0] = 0;
            //[g movePoint:0 to:[g1 pointWithNum:0]];	// close Gap with sg start to g1 start
            //[list removeObjectAtIndex:(selectedObject-1>=begIx) ? (selectedObject-1) : (endIx)];
        }
        else					// remove g
        {   
            changedIx[0] = (selectedObject-1>=begIx) ? (selectedObject-1) : (endIx);
            removedIx = selectedObject;
            changedPt[0] = [g1 pointWithNum:MAXINT]; // old end point
            chPt_num[0] = [g1 numPoints]-1;
            //[g1 movePoint:MAXINT to:gPtEnd]; 	// close Gap with g1 end to g end
            //[list removeObjectAtIndex:selectedObject];
        }
    }
    else // corresponding gr is behind g
    {   NSPoint	g1PtStart ;

        g1 = (selectedObject+1<=endIx) ? [list objectAtIndex:selectedObject+1] : [list objectAtIndex:begIx];

        if ([sg isKindOfClass:[VArc class]] && [g1 isKindOfClass:[VArc class]])
            return -4; // two arcs we cant remove one and close the path Fix Me: open path and arc at end

        g1PtStart = [g1 pointWithNum:0];
        if ( Diff(g1PtStart.x, sgPtEnd.x) < TOLERANCE && Diff(g1PtStart.y, sgPtEnd.y) < TOLERANCE)
            connected = YES;

        if (!connected && [sg isKindOfClass:[VPolyLine class]] && nPts > 2)
        {
            chPt_num[0] = nPts-1;	 // we need pt_num inside PolyLine
            changedIx[0] = selectedObject; // and index of PolyLine inside Path
            changedPt[0] = [sg pointWithNum:nPts-1]; // old start point
            removedIx = -3;
            //[(VPolyLine*)sg removePointWithNum:pt_num];
        }
        else if (!connected)
        {
            changedIx[0] = -1;
            removedIx = selectedObject; // notice only the removed Gr
            changedPt[0] = [sg pointWithNum:0];
            chPt_num[0] = -1;
            //[list removeObjectAtIndex:selectedObject];
        }

        else if ([g1 isKindOfClass:[VPolyLine class]] && [g1 numPoints] > 2 && ![sg isKindOfClass:[VArc class]])
        {
            chPt_num[0] = 0;	 // we need pt_num inside PolyLine // was 1
            changedIx[0] = (selectedObject+1 <= endIx) ? (selectedObject+1) : (begIx); // index of PolyLine inside Path
            changedPt[0] = [g1 pointWithNum:0]; // old point // was 1
            removedIx = -2;
            chPt_num[1] = MAXINT;
            changedIx[1] = selectedObject;
            changedPt[1] = [sg pointWithNum:MAXINT]; // sg end will be moved to new g1 start
            //[(VPolyLine*)g1 removePointWithNum:0];
            //[g movePoint:MAXINT to:[g1 pointWithNum:0]];	// move start of g to new start of polyline
        }
        /* else if ([sg isKindOfClass:[VPolyLine class]] && nPts > 2)
        {
            chPt_num[0] = nPts-2;	 // we need pt_num inside PolyLine
            changedIx[0] = selectedObject; // and index of PolyLine inside Path
            changedPt[0] = [sg pointWithNum:nPts-2]; // old start point
            removedIx = -3;
            //[(VPolyLine*)g removePointWithNum:MAXINT];
            //[g movePoint:MAXINT to:gPtEnd];	// move previous (now last) point of polyline to close path
        } */
        else if ([sg isKindOfClass:[VArc class]])		// remove g
        {
            changedIx[0] = (selectedObject+1 <= endIx) ? (selectedObject+1) : (begIx);
            removedIx = selectedObject;
            changedPt[0] = [g1 pointWithNum:0]; // old start point
            chPt_num[0] = 0;
            //[g1 movePoint:0 to:gPtStart]; 		// close Gap with g1 start to g start
            //[list removeObjectAtIndex:selectedObject];
        }
        else							// remove g1
        {   changedIx[0] = selectedObject;
            removedIx = (selectedObject+1<=endIx) ? (selectedObject+1) : (begIx);
            changedPt[0] = [sg pointWithNum:MAXINT]; // old end point
            chPt_num[0] = [sg numPoints]-1;
            //[g movePoint:MAXINT to:[g1 pointWithNum:MAXINT]];	// close Gap with g end to g1 end
            //[list removeObjectAtIndex:(selectedObject+1<=endIx) ? (selectedObject+1) : (begIx)];
        }
    }
    return removedIx;
}

/* return YES if we remove something - undo (from -AddPoint) must add the oldGraphic */
- (BOOL)removeGraphicsAroundPoint:(NSPoint)pt andIndex:(int)oldIndex
{   VGraphic	*atGr, *oGr;
    int		begIx, endIx;
    NSPoint	gPtStart, gPtEnd, oPt={0,0};

    atGr = [list objectAtIndex:oldIndex];
    if ([atGr isKindOfClass:[VPolyLine class]] && [atGr numPoints] > 2)
    {   int	pt_num; // num of pt in polyline

        pt_num = [(VPolyLine*)atGr removePoint:pt];
        /* close Gap to prev/next Object if start/end pt of polyline */
        if (!pt_num || pt_num >= [atGr numPoints]-1) // start or end point
            [atGr movePoint:pt_num to:pt]; // set new start/end pt to old start/end point

        return NO;
    }
    begIx = [self getFirstObjectOfSubPath:oldIndex];
    endIx = [self getLastObjectOfSubPath:begIx];
    if (begIx == endIx)
        endIx = [list count]-1;

    gPtStart = [atGr pointWithNum:0]; // start point
    gPtEnd   = [atGr pointWithNum:MAXINT]; // end point

    /* check graphic atIndex and behind */
    if ( Diff(gPtEnd.x, pt.x) <= TOLERANCE && Diff(gPtEnd.y, pt.y) <= TOLERANCE )
    {
        oGr = (oldIndex+1<=endIx) ? [list objectAtIndex:oldIndex+1] : [list objectAtIndex:begIx];
        oPt = [oGr pointWithNum:0];
        if ( Diff(gPtEnd.x, oPt.x) <= TOLERANCE && Diff(gPtEnd.y, oPt.y) <= TOLERANCE )
        {
            [list removeObjectAtIndex:(oldIndex+1<=endIx) ? (oldIndex+1) : (begIx)];
            [list removeObjectAtIndex:oldIndex];
        }
        else NSLog(@"VPath.m: removeGraphicsAroundPoint: normaly unpossible 1");
    }
    /* check graphic atIndex and befor */
    else if ( Diff(gPtEnd.x, pt.x) <= TOLERANCE && Diff(gPtEnd.y, pt.y) <= TOLERANCE )
    {
        oGr = (oldIndex-1>=begIx) ? [list objectAtIndex:oldIndex-1] : [list objectAtIndex:endIx];
        oPt = [oGr pointWithNum:MAXINT];
        if ( Diff(gPtStart.x, oPt.x) <= TOLERANCE && Diff(gPtStart.y, oPt.y) <= TOLERANCE )
        {
            [list removeObjectAtIndex:oldIndex];
            [list removeObjectAtIndex:(oldIndex-1<=endIx) ? (oldIndex-1) : (endIx)];
        }
        else NSLog(@"VPath.m: removeGraphicsAroundPoint: normaly unpossible 2");
    }
    else NSLog(@"VPath.m: removeGraphicsAroundPoint: normaly unpossible 3");

    return YES;
}

- (BOOL)removePointWithNum:(int)pt_num
{   VGraphic    *g=nil, *g1;
    int         begIx, endIx, curObject = -1, nPts;
    NSPoint     gPtStart, gPtEnd, gPtWithNum; // notice old end point
    BOOL        connected = NO;

    if ( ![list count] || pt_num < 0 )
        return YES;

    [self deselectAll];
    selectedObject = -1;

    /* beyond list -> point number of end point */
    if ( pt_num >= [self numPoints] )
    {   g = [list objectAtIndex:[list count]-1];
        pt_num = MAXINT;
        curObject = [list count]-1;
    }
    else if ( !pt_num )
    {   g = [list objectAtIndex:0];
        curObject = 0;
    }
    else
    {   int	i, cnt, pCnt = 0, prevPCnt = 0;

        for (i=0, cnt = [list count]; i<cnt; i++)
        {   pCnt += [[list objectAtIndex:i] numPoints];
            if ( pCnt > pt_num )
                break;		// to this object refers our pt_num
            prevPCnt = pCnt;	// count of pts befor this gr
        }
        g = [list objectAtIndex:i];
        pt_num -= prevPCnt;
        curObject = i;
    }
    if (!g)
        return YES;
    begIx = [self getFirstObjectOfSubPath:curObject];
    endIx = [self getLastObjectOfSubPath:begIx];
    if (begIx == endIx)
        endIx = [list count]-1;

    gPtStart = [g pointWithNum:0]; // notice old start point
    gPtEnd = [g pointWithNum:MAXINT]; // notice old end point
    gPtWithNum = [g pointWithNum:pt_num]; // notice old end point
    nPts = [g numPoints];

    if (([g isKindOfClass:[VCurve class]] && (pt_num == 1 || pt_num == 2)) || 	// curve points 1,2
        ([g isKindOfClass:[VArc class]] && pt_num == 2))			// arc center
        return YES;
    if ([g isKindOfClass:[VPolyLine class]] && nPts > 2 && pt_num && pt_num < nPts-1)
    {   [(VPolyLine*)g removePointWithNum:pt_num];
        return YES;
    }

    /* get the connected Graphic to g (curObject) */
    if (!pt_num) // corresponding gr is bevor g
    {   NSPoint	g1PtEnd;

        g1 = (curObject-1>=begIx) ? [list objectAtIndex:curObject-1] : [list objectAtIndex:endIx];
        if ([g isKindOfClass:[VArc class]] && [g1 isKindOfClass:[VArc class]])
            return YES; // two arcs we cant remove one and close the path Fix Me: open path and arc at end

        g1PtEnd = [g1 pointWithNum:MAXINT];
        if ( Diff(g1PtEnd.x, gPtStart.x) < TOLERANCE && Diff(g1PtEnd.y, gPtStart.y) < TOLERANCE)
            connected = YES;

        if (!connected && [g isKindOfClass:[VPolyLine class]] && nPts > 2)
        {
            [(VPolyLine*)g removePointWithNum:pt_num];
        }
        else if (!connected)
        {
            [list removeObjectAtIndex:curObject];
        }
        else if ([g isKindOfClass:[VPolyLine class]] && nPts > 2 && ![g1 isKindOfClass:[VArc class]])
        {
            [(VPolyLine*)g removePointWithNum:pt_num];
            [g1 movePoint:MAXINT to:[g pointWithNum:0]]; // move g1 end to new start of polyLine
        }
        /* else if ([g1 isKindOfClass:[VPolyLine class]] && [g1 numPoints] > 2)
        {
            [(VPolyLine*)g1 removePointWithNum:MAXINT];
            [g1 movePoint:MAXINT to:gPtStart];	// move previous (now last) point of polyline to close path
        } */
        else if ([g1 isKindOfClass:[VArc class]])			// remove g1
        {
            [g movePoint:0 to:[g1 pointWithNum:0]];	// close Gap with g start to g start
            [list removeObjectAtIndex:(curObject-1>=begIx) ? (curObject-1) : (endIx)];
        }
        else					// remove g
        {   [g1 movePoint:MAXINT to:gPtEnd]; 	// close Gap with g1 end to g end
            [list removeObjectAtIndex:curObject];
        }
    }
    else // corresponding gr is behind g
    {   NSPoint	g1PtStart;

        g1 = (curObject+1<=endIx) ? [list objectAtIndex:curObject+1] : [list objectAtIndex:begIx];

        if ([g isKindOfClass:[VArc class]] && [g1 isKindOfClass:[VArc class]])
            return YES; // two arcs we cant remove one and close the path Fix Me: open path and arc at end

        g1PtStart = [g1 pointWithNum:0];
        if ( Diff(g1PtStart.x, gPtEnd.x) < TOLERANCE && Diff(g1PtStart.y, gPtEnd.y) < TOLERANCE)
            connected = YES;

        if (!connected && [g isKindOfClass:[VPolyLine class]] && nPts > 2)
        {
            [(VPolyLine*)g removePointWithNum:pt_num];
        }
        else if (!connected)
        {
            [list removeObjectAtIndex:curObject];
        }
        else if ([g1 isKindOfClass:[VPolyLine class]] && [g1 numPoints] > 2 && ![g isKindOfClass:[VArc class]])
        {
            [(VPolyLine*)g1 removePointWithNum:0];
            [g movePoint:MAXINT to:[g1 pointWithNum:0]];	// move start of g to new start of polyline
        }
        /* else if ([g isKindOfClass:[VPolyLine class]] && nPts > 2)
        {
            [(VPolyLine*)g removePointWithNum:MAXINT];
            [g movePoint:MAXINT to:gPtEnd];	// move previous (now last) point of polyline to close path
        } */
        else if ([g isKindOfClass:[VArc class]])		// remove g
        {
            [g1 movePoint:0 to:gPtStart]; 		// close Gap with g1 start to g start
            [list removeObjectAtIndex:curObject];
        }
        else							// remove g1
        {   [g movePoint:MAXINT to:[g1 pointWithNum:MAXINT]];	// close Gap with g end to g1 end
            [list removeObjectAtIndex:(curObject+1<=endIx) ? (curObject+1) : (begIx)];
            
        }
    }

    if ( ![list count] )
        return NO; // hole graphic will removed in DocView.m -delete
    coordBounds = bounds = NSZeroRect;
    dirty = YES;
    graduateDirty = YES;
    return YES;
}

/*
 * pt_num is the changing control point. pt holds the relative change in each coordinate. 
 * The relative is needed and not the absolute because the closest inside control point
 * changes when one of the outside points change.
 */
- (void)movePoint:(int)pt_num to:(NSPoint)p
{   VGraphic	*g=nil, *g1;
    BOOL	control = [(App*)NSApp control];
    int		begIx, endIx, curObject = -1;
    NSPoint	gPtStart, gPtEnd, gPtWithNum; // notice old end point

    if ( ![list count] || pt_num < 0 )
        return;
    /* beyond list -> point number of end point */
    if ( pt_num >= [self numPoints] )
    {   g = [list objectAtIndex:[list count]-1];
        pt_num = MAXINT;
        curObject = [list count]-1;
    }
    else if ( !pt_num )
    {   g = [list objectAtIndex:0];
        curObject = 0;
    }
    else
    {   int	i, cnt, pCnt = 0, prevPCnt = 0;

        for (i=0, cnt = [list count]; i<cnt; i++)
        {   pCnt += [[list objectAtIndex:i] numPoints];
            if ( pCnt > pt_num )
                break;		// to this object refers our pt_num
            prevPCnt = pCnt;	// count of pts befor this gr
        }
        g = [list objectAtIndex:i];
        pt_num -= prevPCnt;
        curObject = i;
    }
    if (!g)
        return;

    if ( [g isKindOfClass:[VCurve class]] && (pt_num == 1 || pt_num == 2) )
    {
        [g movePoint:pt_num to:p]; // move only the control pt
        coordBounds = bounds = NSZeroRect;
        dirty = YES;
        graduateDirty = YES;
        return;
    }

    begIx = [self getFirstObjectOfSubPath:curObject];
    endIx = [self getLastObjectOfSubPath:begIx];
    if (begIx == endIx)
        endIx = [list count]-1;

    gPtStart = [g pointWithNum:0]; // notice old start point
    gPtEnd = [g pointWithNum:MAXINT]; // notice old end point
    gPtWithNum = [g pointWithNum:pt_num]; // notice old end point

    /* move point connected to pt_num */
    g1 = (curObject+1<=endIx) ? [list objectAtIndex:curObject+1] : [list objectAtIndex:begIx];
    if ([g isKindOfClass:[VArc class]])
    {   int	i = 2, stop = 0;
        NSPoint	g1PtEnd = [g1 pointWithNum:MAXINT]; // notice old end point

        [g movePoint:pt_num to:p];
        /* move graphics at end of arc g */
        if (DiffPoint([g1 pointWithNum:0], gPtEnd) <= TOLERANCE)
        {   /* move only if control is set (else point never match) or no arc */
            if (control || ![g1 isKindOfClass:[VArc class]])
                [g1 movePoint:0 to:[g pointWithNum:MAXINT]];
            if (control) // move also graphics at end of g1
            {
                while ([g1 isKindOfClass:[VArc class]] && g1 != g) // move graphic at g1 end
                {   VGraphic	*g2 = (curObject+i<=endIx) ? [list objectAtIndex:curObject+i]
                                         : [list objectAtIndex:begIx+(curObject+i-endIx)-1];

                    if ((g2 == g) ||
                        (DiffPoint(g1PtEnd, [g2 pointWithNum:0]) > TOLERANCE))
                    {   if (g1 == g) stop = 1;
                        break;
                    }
                    else // if (DiffPoint(g1PtEnd, [g2 pointWithNum:0]) <= TOLERANCE)
                    {   g1PtEnd = [g2 pointWithNum:MAXINT]; // notice old end point g2 will become g1
                        [g2 movePoint:0 to:[g1 pointWithNum:MAXINT]];
                    }
                    g1 = g2;
                    i++;
                }
                if (g1 == g) stop = 1;
            }
        }
        /* move graphics at start of arc g */
        if (!stop)
        {   i = 2;
            g1 = (curObject-1>=begIx) ? [list objectAtIndex:curObject-1] : [list objectAtIndex:endIx];
            /* move graphics at start of g */
            if (DiffPoint([g1 pointWithNum:MAXINT], gPtStart) <= TOLERANCE)
            {   NSPoint	g1PtStart = [g1 pointWithNum:0]; // notice old g1 start point

                /* move only if control is set (else point never match) or no arc */
                if (control || ![g1 isKindOfClass:[VArc class]])
                    [g1 movePoint:MAXINT to:[g pointWithNum:0]];
                if (control)
                {
                    while ([g1 isKindOfClass:[VArc class]] && g1 != g) // move graphics at g1 start
                    {   VGraphic	*g2 = (curObject-i>=begIx) ? [list objectAtIndex:curObject-i]
                                         : [list objectAtIndex:endIx-(begIx-(curObject-i))+1];

                        if ((g2 == g) ||
                            (DiffPoint(g1PtStart, [g2 pointWithNum:MAXINT]) > TOLERANCE))
                            break;
                        else
                        {   g1PtStart = [g2 pointWithNum:0]; // note: old g2 start pt -> will become g1
                            [g2 movePoint:MAXINT to:[g1 pointWithNum:0]];
                        }
                        g1 = g2;
                        i++;
                    }
                }
            }
        }
    }
    else if (!pt_num)// if (![g isKindOfClass:[VArc class]]) // g is no arc
    {   NSPoint	g1PtStart = NSZeroPoint; // old end point

        g1 = (curObject-1>=begIx) ? [list objectAtIndex:curObject-1] : [list objectAtIndex:endIx];
        if (DiffPoint([g1 pointWithNum:MAXINT], gPtWithNum) <= 5.0*TOLERANCE)
        {
            g1PtStart = [g1 pointWithNum:0];
            [g1 movePoint:MAXINT to:p];
            p = [g1 pointWithNum:MAXINT];
        }
        [g movePoint:pt_num to:p]; // no arc
        if (control)
        {   int	i = 2;

            while ([g1 isKindOfClass:[VArc class]] && g1 != g) // move graphic at g1 start
            {   VGraphic	*g2 = (curObject-i>=begIx) ? [list objectAtIndex:curObject-i]
                                                         : [list objectAtIndex:endIx-(begIx-(curObject-i))+1];

                if (DiffPoint(g1PtStart, [g2 pointWithNum:MAXINT]) <= TOLERANCE)
                {   g1PtStart = [g2 pointWithNum:0]; // note: old g2 start pt -> will become g1
                    [g2 movePoint:MAXINT to:[g1 pointWithNum:0]];
                }
                else break;
                if (g2 == g)
                    break;
                g1 = g2;
                i++;
            }
        }
    }
    else // if (![g isKindOfClass:[VArc class]]) // g is no arc
    {   NSPoint	g1PtEnd = [g1 pointWithNum:MAXINT]; // notice old end point

        if (DiffPoint([g1 pointWithNum:0], gPtWithNum) <= 5.0*TOLERANCE)
        {   [g1 movePoint:0 to:p]; // move g1 start to p
            p = [g1 pointWithNum:0];
        }
        [g movePoint:pt_num to:p]; // no arc !
        if (control)
        {   int	i = 2;

            while ([g1 isKindOfClass:[VArc class]] && g1 != g) // move graphic at g1 end
            {   VGraphic	*g2 = (curObject+i<=endIx) ? [list objectAtIndex:curObject+i]
                                                         : [list objectAtIndex:begIx+(curObject+i-endIx)-1];

                if (DiffPoint(g1PtEnd, [g2 pointWithNum:0]) <= TOLERANCE)
                {   g1PtEnd = [g2 pointWithNum:MAXINT]; // notice old end point g2 will become g1
                    [g2 movePoint:0 to:[g1 pointWithNum:MAXINT]];
                }
                else break;
                if (g2 == g)
                    break;
                g1 = g2;
                i++;
            }
        }
    }
    coordBounds = bounds = NSZeroRect;
    dirty = YES;
    graduateDirty = YES;
}

/* needed for undo
 * if control button is set -> the radius of an arc will changed (else not!)
 * for the way back we need the possibility to say "the button is set"
 */
- (void)movePoint:(int)pt_num to:(NSPoint)p control:(BOOL)control
{   VGraphic	*g=nil, *g1;
    int		begIx, endIx, curObject = -1;
    NSPoint	gPtStart, gPtEnd, gPtWithNum; // notice old end point

    if ( ![list count] || pt_num < 0 )
        return;
    /* beyond list -> point number of end point */
    if ( pt_num >= [self numPoints] )
    {   g = [list objectAtIndex:[list count]-1];
        pt_num = MAXINT;
        curObject = [list count]-1;
    }
    else if ( !pt_num )
    {   g = [list objectAtIndex:0];
        curObject = 0;
    }
    else
    {   int	i, cnt, pCnt = 0, prevPCnt = 0;

        for (i=0, cnt = [list count]; i<cnt; i++)
        {   pCnt += [[list objectAtIndex:i] numPoints];
            if ( pCnt > pt_num )
                break;		// to this object refers our pt_num
            prevPCnt = pCnt;	// count of pts befor this gr
        }
        g = [list objectAtIndex:i];
        pt_num -= prevPCnt;
        curObject = i;
    }
    if (!g)
        return;

    if ( [g isKindOfClass:[VCurve class]] && (pt_num == 1 || pt_num == 2) )
    {
        [g movePoint:pt_num to:p]; // move only the control pt
        coordBounds = bounds = NSZeroRect;
        dirty = YES;
        graduateDirty = YES;
        return;
    }

    begIx = [self getFirstObjectOfSubPath:curObject];
    endIx = [self getLastObjectOfSubPath:begIx];
    if (begIx == endIx)
        endIx = [list count]-1;

    gPtStart = [g pointWithNum:0]; // notice old start point
    gPtEnd = [g pointWithNum:MAXINT]; // notice old end point
    gPtWithNum = [g pointWithNum:pt_num]; // notice old end point

    /* move point connected to pt_num */
    g1 = (curObject+1<=endIx) ? [list objectAtIndex:curObject+1] : [list objectAtIndex:begIx];
    if ([g isKindOfClass:[VArc class]])
    {   int	i = 2, stop = 0;
        NSPoint	g1PtEnd = [g1 pointWithNum:MAXINT]; // notice old end point

        [(VArc*)g movePoint:pt_num to:p control:control];
        /* move graphics at end of arc g */
        if (DiffPoint([g1 pointWithNum:0], gPtEnd) <= TOLERANCE)
        {   /* move only if control is set (else point never match) or no arc */
            if (control || ![g1 isKindOfClass:[VArc class]])
            {
                if (![g1 isKindOfClass:[VArc class]])
                    [g1 movePoint:0 to:[g pointWithNum:MAXINT]];
                else
                    [(VArc*)g1 movePoint:0 to:[g pointWithNum:MAXINT] control:control];
            }
            if (control) // move also graphics at end of g1
            {
                while ([g1 isKindOfClass:[VArc class]] && g1 != g) // move graphic at g1 end
                {   VGraphic	*g2 = (curObject+i<=endIx) ? [list objectAtIndex:curObject+i]
                                         : [list objectAtIndex:begIx+(curObject+i-endIx)-1];

                    if ((g2 == g) ||
                        (DiffPoint(g1PtEnd, [g2 pointWithNum:0]) > TOLERANCE))
                    {   if (g1 == g) stop = 1;
                        break;
                    }
                    else // if (DiffPoint(g1PtEnd, [g2 pointWithNum:0]) <= TOLERANCE)
                    {   g1PtEnd = [g2 pointWithNum:MAXINT]; // notice old end point g2 will become g1
                        if (![g2 isKindOfClass:[VArc class]])
                            [g2 movePoint:0 to:[g1 pointWithNum:MAXINT]];
                        else
                            [(VArc*)g2 movePoint:0 to:[g1 pointWithNum:MAXINT] control:control];
                    }
                    g1 = g2;
                    i++;
                }
                if (g1 == g) stop = 1;
            }
        }
        /* move graphics at start of arc g */
        if (!stop)
        {   i = 2;
            g1 = (curObject-1>=begIx) ? [list objectAtIndex:curObject-1] : [list objectAtIndex:endIx];
            /* move graphics at start of g */
            if (DiffPoint([g1 pointWithNum:MAXINT], gPtStart) <= TOLERANCE)
            {   NSPoint	g1PtStart = [g1 pointWithNum:0]; // notice old g1 start point

                /* move only if control is set (else point never match) or no arc */
                if (control || ![g1 isKindOfClass:[VArc class]])
                {
                    if (![g1 isKindOfClass:[VArc class]])
                        [g1 movePoint:MAXINT to:[g pointWithNum:0]];
                    else
                        [(VArc*)g1 movePoint:MAXINT to:[g pointWithNum:0] control:control];
                }
                if (control)
                {
                    while ([g1 isKindOfClass:[VArc class]] && g1 != g) // move graphics at g1 start
                    {   VGraphic	*g2 = (curObject-i>=begIx) ? [list objectAtIndex:curObject-i]
                                         : [list objectAtIndex:endIx-(begIx-(curObject-i))+1];

                        if ((g2 == g) ||
                            (DiffPoint(g1PtStart, [g2 pointWithNum:MAXINT]) > TOLERANCE))
                            break;
                        else
                        {   g1PtStart = [g2 pointWithNum:0]; // note: old g2 start pt -> will become g1
                            if (![g2 isKindOfClass:[VArc class]])
                                [g2 movePoint:MAXINT to:[g1 pointWithNum:0]];
                            else
                                [(VArc*)g2 movePoint:MAXINT to:[g1 pointWithNum:0] control:control];
                        }
                        g1 = g2;
                        i++;
                    }
                }
            }
        }
    }
    else if (!pt_num)// if (![g isKindOfClass:[VArc class]]) // g is no arc
    {   NSPoint	g1PtStart = NSZeroPoint; // note: old end point

        g1 = (curObject-1>=begIx) ? [list objectAtIndex:curObject-1] : [list objectAtIndex:endIx];
        if (DiffPoint([g1 pointWithNum:MAXINT], gPtWithNum) <= 5.0*TOLERANCE)
        {
            g1PtStart = [g1 pointWithNum:0];
            if (![g1 isKindOfClass:[VArc class]])
                [g1 movePoint:MAXINT to:p];
            else
                [(VArc*)g1 movePoint:MAXINT to:p control:control];
            p = [g1 pointWithNum:MAXINT];
        }
        [g movePoint:pt_num to:p]; // no arc
        if (control)
        {   int	i = 2;

            while ([g1 isKindOfClass:[VArc class]] && g1 != g) // move graphic at g1 start
            {   VGraphic	*g2 = (curObject-i>=begIx) ? [list objectAtIndex:curObject-i]
                                                         : [list objectAtIndex:endIx-(begIx-(curObject-i))+1];

                if (DiffPoint(g1PtStart, [g2 pointWithNum:MAXINT]) <= TOLERANCE)
                {   g1PtStart = [g2 pointWithNum:0]; // note: old g2 start pt -> will become g1
                    if (![g2 isKindOfClass:[VArc class]])
                        [g2 movePoint:MAXINT to:[g1 pointWithNum:0]];
                    else
                        [(VArc*)g2 movePoint:MAXINT to:[g1 pointWithNum:0] control:control];
                }
                else break;
                if (g2 == g)
                    break;
                g1 = g2;
                i++;
            }
        }
    }
    else // if (![g isKindOfClass:[VArc class]]) // g is no arc
    {   NSPoint	g1PtEnd = [g1 pointWithNum:MAXINT]; // notice old end point

        if (DiffPoint([g1 pointWithNum:0], gPtWithNum) <= 5.0*TOLERANCE)
        {
            if (![g1 isKindOfClass:[VArc class]])
                [g1 movePoint:0 to:p]; // move g1 start to p
            else
                [(VArc*)g1 movePoint:0 to:p control:control]; // move g1 start to p
            p = [g1 pointWithNum:0];
        }
        [g movePoint:pt_num to:p]; // no arc !
        if (control)
        {   int	i = 2;

            while ([g1 isKindOfClass:[VArc class]] && g1 != g) // move graphic at g1 end
            {   VGraphic	*g2 = (curObject+i<=endIx) ? [list objectAtIndex:curObject+i]
                                                         : [list objectAtIndex:begIx+(curObject+i-endIx)-1];

                if (DiffPoint(g1PtEnd, [g2 pointWithNum:0]) <= TOLERANCE)
                {   g1PtEnd = [g2 pointWithNum:MAXINT]; // notice old end point g2 will become g1
                    if (![g2 isKindOfClass:[VArc class]])
                        [g2 movePoint:0 to:[g1 pointWithNum:MAXINT]];
                    else
                        [(VArc*)g2 movePoint:0 to:[g1 pointWithNum:MAXINT] control:control];
                }
                else break;
                if (g2 == g)
                    break;
                g1 = g2;
                i++;
            }
        }
    }
    coordBounds = bounds = NSZeroRect;
    dirty = YES;
    graduateDirty = YES;
}

/*
 * pt_num is the changing control point. pt holds the relative change in each coordinate. 
 * The relative is needed and not the absolute because the closest inside control point
 * changes when one of the outside points change.
 */
- (void)movePoint:(int)pt_num by:(NSPoint)pt
{   NSPoint	ptWithNum;

    if ( ![list count] || pt_num < 0 )
        return;

    ptWithNum = [self pointWithNum:pt_num];
    pt.x = ptWithNum.x + pt.x;
    pt.y = ptWithNum.y + pt.y;
    [self movePoint:pt_num to:pt];
    dirty = YES;
    graduateDirty = YES;
}

/* The pt argument holds the relative point change. */
- (void)moveBy:(NSPoint)pt
{   int	i;

    for (i=[list count]-1; i>=0; i--)
        [[list objectAtIndex:i] moveBy:pt];
    coordBounds = bounds = NSZeroRect;
    dirty = YES;
    if (!graduateDirty && graduateList)
    {
        for (i=[graduateList count]-1; i>=0; i--)
            [[graduateList objectAtIndex:i] moveBy:pt];
    }
}

/* Given the point number, return the point.
 * We either return the point of the path (nothing selected) or the selected object
 */
- (NSPoint)pointWithNum:(int)pt_num
{   int	i, cnt, pCnt = 0, prevPCnt = 0;

    if ( ![list count] || pt_num < 0 )
        return NSMakePoint( 0.0, 0.0);
    /* beyond list -> return point number of end point */
    if ( pt_num >= [self numPoints] )
        return [[list objectAtIndex:[list count]-1] pointWithNum:MAXINT];
    /* nothing selected -> return point of path */
    if ( !pt_num )
        return [[list objectAtIndex:0] pointWithNum:0];

    for (i=0, cnt = [list count]; i<cnt; i++)
    {   pCnt += [[list objectAtIndex:i] numPoints];
        if ( pCnt > pt_num )
            break;		// to this object refers our pt_num
        prevPCnt = pCnt;	// count of pts befor this gr
    }
    return [[list objectAtIndex:i] pointWithNum:pt_num - prevPCnt];
}

- (int)numPoints
{   int	i, cnt, pCnt = 0;

    for (i=0, cnt = [list count]; i<cnt; i++)
        pCnt += [[list objectAtIndex:i] numPoints];
    return pCnt;
}

/* modified: 2010-07-15
 *
 * we dont change the order (without split polylines)
 */
- (void)pointWithNumBecomeStartPoint:(int)pt_num
{   int	i, cnt, endIx, begIx = 0, curIx = -1, pCnt = 0, prevPCnt = 0;

    if ( !pt_num )
        return;

    if ( ![self closed] ) // only start / end points !
    {
        if ( pt_num == [self numPoints]-1 )
            [self changeDirection];
        return;
    }
 
    for (i=0, cnt = [list count]; i<cnt; i++)
    {   pCnt += [[list objectAtIndex:i] numPoints];
        curIx = i;
        if ( pCnt > pt_num )
            break;		// to this object refers our pt_num
        prevPCnt = pCnt;	// count of pts befor this gr
    }
    if ( pt_num-prevPCnt >= [[list objectAtIndex:curIx] numPoints]-1 ) // last point of Graphic
        curIx ++; // next Graphic is our start Graphic

    begIx = [self getFirstObjectOfSubPath:curIx];
    endIx = [self getLastObjectOfSubPath:begIx]; //  tolerance:TOLERANCE

    /* move objects bevor pt_num at the end of subpath */
    for (i=curIx-1; i >= begIx; i--)
    {
        [list insertObject:[list objectAtIndex:i] atIndex:endIx+1];
        [list removeObjectAtIndex:i];
        endIx --; // need the same place to insert (remove destroy position
    }
    [self deselectAll];
    selectedObject = -1;
}

- (void)mirrorAround:(NSPoint)mp;
{   int	i;

    for (i=[list count]-1; i>=0; i--)
        [(VGraphic*)[list objectAtIndex:i] mirrorAround:mp];
    coordBounds = bounds = NSZeroRect;
    dirty = YES;
    if (!graduateDirty && graduateList)
    {
        for (i=[graduateList count]-1; i>=0; i--)
            [(VGraphic*)[graduateList objectAtIndex:i] mirrorAround:mp];
    }
}

/* modified: 2008-10-11
 */
- (void)changeDirection
{
    if ( !filled && ![self closed] )
    {   [self changeDirectionOfSubPath:0 :[list count]-1];
        return;
    }

    [self setDirectionCCW:(isDirectionCCW) ? 0 : 1];
    dirty = YES;
}

/* created:   21.10.95
 * modified:  05.03.97
 * parameter: angle	angle
 *            cp	rotation center
 * purpose:   draws the plane with the given rotation angles
 */
- (void)drawAtAngle:(float)angle withCenter:(NSPoint)cp in:view
{   int	i;

    for ( i=[list count]-1; i>=0; i-- )
        [(VGraphic*)[list objectAtIndex:i] drawAtAngle:angle withCenter:cp in:view];
}

- (void)setAngle:(float)angle withCenter:(NSPoint)cp
{   int		i;

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
    for (i=[list count]-1; i>=0; i--)
        [(VGraphic*)[list objectAtIndex:i] setAngle:angle withCenter:cp];
    coordBounds = bounds = NSZeroRect;
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
    for ( i=[list count]-1; i >= 0; i-- )
        [[list objectAtIndex:i] transform:matrix];
    coordBounds = bounds = NSZeroRect;
    dirty = graduateDirty = YES;
}

- (void)scale:(float)x :(float)y withCenter:(NSPoint)cp
{   int		i;

    width *= (Abs(x)+Abs(y))/2.0;
    for (i=[list count]-1; i>=0; i--)
        [(VGraphic*)[list objectAtIndex:i] scale:x :y withCenter:cp];
    coordBounds = bounds = NSZeroRect;
    dirty = YES;
    graduateDirty = YES;
}

/* created:  1995-09-19
 * modified: 2008-08-26
 * purpose:  draw the path
 */
#define DEBUG_TRACE	0
- (void)drawWithPrincipal:principal
{   int             i, f;
    int             cnt = [self count];	/* [self countRecursive] for path in path ! */
    NSPoint         currentPoint = NSMakePoint(LARGENEG_COORD, LARGENEG_COORD);
    NSBezierPath    *bPath = [NSBezierPath bezierPath];
    BOOL            antialias = VHFAntialiasing();

    if (!cnt)
        return;

#if DEBUG_TRACE
    [[NSDPSContext currentContext] setOutputTraced:YES];
#endif

    for (f=0; f <= 1; f++)  // 0 = fill, 1 = stroke
    {   NSColor	*col;
        VFloat	w;

        if (!f && !filled) continue;            // fill run: nothing to fill or allready filled
#if !defined(__APPLE__)	// OpenStep 4.2, linux - FIXME: should be without antialiasing
        if (f && !(width || !filled)) continue; // stroke run: nothing to stroke
#else   // TODO: this is a workaround to make 0-width fillings visible, we should better add a wireframe mode
        if (f && !width && (filled > 1 || ! antialias) )
            continue;   // stroke run: nothing to stroke and color shading -> skip
#endif
        if (     !f && filled == 2 && (graduateDirty || !graduateList))
        {   [self drawGraduatedWithPrincipal:principal];
            continue;
        }
        else if (!f && filled == 3 && (graduateDirty || !graduateList))
        {   [self drawRadialWithPrincipal:principal];
            continue;
        }
        else if (!f && filled == 4 && (graduateDirty || !graduateList))
        {   [self drawAxialWithPrincipal:principal];
            continue;
        }
        else if (!f && (filled == 2 || filled == 3 || filled == 4) && graduateList && !graduateDirty)
        {   int gCnt = [graduateList count];

            /* draw graduateList */
            VHFSetAntialiasing(NO);
            for (i=0; i<gCnt; i++)
                [(VGraphic*)[graduateList objectAtIndex:i] drawWithPrincipal:principal];
            if (antialias) VHFSetAntialiasing(antialias);
            continue;
        }
        col = (!f || (!width && filled)) ? fillColor : color;
        w = (!f) ? (0.0) : ((width > 0.0) ? width : [NSBezierPath defaultLineWidth]);   // width
        if ( filled && width == 0.0 )  // if filled and no stroke width, we stroke very thin to make everything visible
        {   w = 0.1/[principal scaleFactor];
            if ( ! antialias && !f )
                w = 0.0;
        }

        /* colorSeparation */
        if (!VHFIsDrawingToScreen() && [principal separationColor])
            col = [self separationColor:col]; // get individual separation color

        if ( [principal mustDrawPale] )
        {   VFloat h, s, b, a;

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
        for (i=0; i<cnt; i++)
            currentPoint = [[list objectAtIndex:i] appendToBezierPath:bPath currentPoint:currentPoint];

        if (!f) // (filled)
        {   [bPath setWindingRule:NSEvenOddWindingRule];
            [bPath fill];
        }
        else
            [bPath stroke];
    }
    /* display directions */
    if ( [principal showDirection] )
    {   NSPoint le=NSZeroPoint;

        for (i=0; i<cnt; i++)
        {   NSPoint s = [[list objectAtIndex:i] pointWithNum:0];

            if ( !i || (Diff(le.x, s.x) > TOLERANCE || Diff(le.y, s.y) > TOLERANCE) )
                [[list objectAtIndex:i] drawDirectionAtScale:[principal scaleFactor]/2.0];
                //[[list objectAtIndex:i] drawStartAtScale:[principal scaleFactor]];
            else
                [[list objectAtIndex:i] drawDirectionAtScale:[principal scaleFactor]];
            le = [[list objectAtIndex:i] pointWithNum:MAXINT];
        }
    }

#if DEBUG_TRACE
    PSWait();
    [[NSDPSContext currentContext] setOutputTraced:NO];
#endif
}

/* modified: 2012-12-12 (alpha added, float -> double)
 * FIXME: there is a solid border between graduate steps, which is a rounding issue,
 *        and additionally probably the w = 0.1 in -drawWithPrincipal: => better to use method without stroke
 */
#define MAXSTEPS	1000
- (void)drawGraduatedWithPrincipal:principal
{   int			steps = 15, poolCnt = 0, oldFilled = filled;
    double		xMax, yMax, dx, dy, fsteps, angle = graduateAngle, length, rStepWidth = stepWidth;
    NSRect		bRect = [self coordBounds];
    NSPoint		p0, p1, ls, le, p0e, p1e, p0End;
    VLine		*line0, *line1, *line2, *line3;
    NSColor		*endCol = fillColor, *startCol = endColor;
    double		colDiff1  = 1.0, colDiff2  = 1.0, colDiff3  = 1.0, colDiff4  = 1.0;
    double		colStep1  = 1.0, colStep2  = 1.0, colStep3  = 1.0, colStep4  = 1.0, alphaStep  = 1.0;
    double		curCol1   = 1.0, curCol2   = 1.0, curCol3   = 1.0, curCol4   = 1.0, curAlpha   = 1.0;
    double		endCol1   = 1.0, endCol2   = 1.0, endCol3   = 1.0, endCol4   = 1.0, endAlpha   = 1.0;
    double		startCol1 = 1.0, startCol2 = 1.0, startCol3 = 1.0, startCol4 = 1.0, startAlpha = 1.0, mul = 1.0;
    VPath		*path, *rectP;
    NSAutoreleasePool	*pool, *pool1;
    NSString	*fcolSpaceName, *ecolSpaceName, *colSpaceName;
    BOOL		antialias = VHFAntialiasing();

    if (!bRect.size.width || !bRect.size.height)
        return;

    filled = 1;
    if ([startCol isEqual:endCol])
    {
        [self drawWithPrincipal:principal];
        filled = oldFilled;
        return;
    }

    /* convert fill/endColor to one colorSpaceName */
    fcolSpaceName = [fillColor colorSpaceName];
    ecolSpaceName = [endColor colorSpaceName];
    if ([fcolSpaceName isEqual:@"NSDeviceCMYKColorSpace"] || [ecolSpaceName isEqual:@"NSDeviceCMYKColorSpace"])
    {
        startCol = [endColor colorUsingColorSpaceName:@"NSDeviceCMYKColorSpace"];
        endCol   = [fillColor colorUsingColorSpaceName:@"NSDeviceCMYKColorSpace"];
        colSpaceName = @"NSDeviceCMYKColorSpace";
    }
    else if ([fcolSpaceName isEqual:@"NSCalibratedWhiteColorSpace"] &&
             [ecolSpaceName isEqual:@"NSCalibratedWhiteColorSpace"])
    {   startCol = [endColor colorUsingColorSpaceName:@"NSCalibratedWhiteColorSpace"];
        endCol   = [fillColor colorUsingColorSpaceName:@"NSCalibratedWhiteColorSpace"];
        colSpaceName = @"NSCalibratedWhiteColorSpace";
    }
    else
    {   startCol = [endColor colorUsingColorSpaceName:@"NSCalibratedRGBColorSpace"];
        endCol   = [fillColor colorUsingColorSpaceName:@"NSCalibratedRGBColorSpace"];
        colSpaceName = @"NSCalibratedRGBColorSpace";
    }
    if (!startCol || !endCol)
    {   NSLog(@"drawGraduatedWithPrincipal: ColorSpace not supported");
        [self drawWithPrincipal:principal];
        filled = oldFilled;
        return;
    }

    if (graduateList)
        [graduateList release];
    graduateList = [[NSMutableArray allocWithZone:[self zone]] init];
    graduateDirty = NO;

    pool = [NSAutoreleasePool new];
    if (!rStepWidth) rStepWidth = 2.0;

    angle = graduateAngle;
    if (angle >= 180.0)
    {   NSColor	*col;

        col = startCol;
        startCol = endCol;
        endCol = col;
        angle -= 180.0;
    }

    /* 135 > angle > 45
     * line y is fix and we calc start values for x start/end and dx
     */
    if (angle < 135.0 && angle > 45.0)
    {   NSColor	*col;

        col = startCol;
        startCol = endCol;
        endCol   = col;
        p0.y = bRect.origin.y - rStepWidth;
        p1.y = bRect.origin.y + bRect.size.height + rStepWidth;
        p0.x = p1.x = bRect.origin.x;
        ls = le = bRect.origin;
        le.x = bRect.origin.x + bRect.size.width;
        if (angle > 90.0)
        {   p0.x = bRect.origin.x;
            p1.x = p0.x - (bRect.size.height + 2.0*rStepWidth)/Tan(180.0-angle);
            ls.x = bRect.origin.x - bRect.size.height/Tan(180.0-angle);
            ls.y = le.y = bRect.origin.y + bRect.size.height;
        }
        else if (angle < 90.0)
        {   p1.x = bRect.origin.x;
            p0.x = p1.x - (bRect.size.height + 2.0*rStepWidth)/Tan(angle);
            ls.x = bRect.origin.x - bRect.size.height/Tan(angle);
            ls.y = le.y = bRect.origin.y;
        }
    }
    /* 135 <= angle <= 45
     * line x is fix and we calc start values for y start/end and dy
     */
    else
    {   p0.x = bRect.origin.x - rStepWidth;
        p1.x = bRect.origin.x + bRect.size.width + rStepWidth;
        p0.y = p1.y = bRect.origin.y;
        ls = le = bRect.origin;
        le.y = bRect.origin.y + bRect.size.height;

        if (angle && angle <= 45.0)
        {   p1.y = bRect.origin.y;
            p0.y = p1.y - (bRect.size.width + 2.0*rStepWidth)*Tan(angle);
            ls.x = le.x = bRect.origin.x;
            ls.y = bRect.origin.y - bRect.size.width*Tan(angle);
        }
        else if (angle)
        {   NSColor	*col;

            col = startCol;
            startCol = endCol;
            endCol = col;
            p0.y = bRect.origin.y;
            p1.y = p0.y - (bRect.size.width + 2.0*rStepWidth)*Tan(180.0-angle);
            ls.x = le.x = bRect.origin.x + bRect.size.width;
            ls.y = bRect.origin.y - bRect.size.width*Tan(180.0-angle);
        }
    }

    length = sqrt(SqrDistPoints(ls, le));
    fsteps = length / rStepWidth;
    steps = ((int)fsteps) + ((fsteps-((int)fsteps) > 0.0) ? 1 : 0);

    dx = Diff(ls.x, le.x)/(double)steps;
    dy = Diff(ls.y, le.y)/(double)steps;

    steps --; // for startCol

    /* build path - else we must rotate the rectangle (sqrt, sin, ..) */
    line0 = [VLine line];
    line1 = [VLine line];
    line2 = [VLine line];
    line3 = [VLine line];
    rectP = [VPath path];
    [rectP setFilled:1]; // simple filling
    [line0 setVertices:p0 :p1];
    [[rectP list] addObject:line0];
    [line1 setVertices:p1 :NSMakePoint(p1.x+dx, p1.y+dy)];
    [[rectP list] addObject:line1];
    [line2 setVertices:NSMakePoint(p1.x+dx, p1.y+dy) :NSMakePoint(p0.x+dx, p0.y+dy)];
    [[rectP list] addObject:line2];
    [line3 setVertices:NSMakePoint(p0.x+dx, p0.y+dy) :p0];
    [[rectP list] addObject:line3];

    pool1 = [NSAutoreleasePool new];

    yMax = bRect.origin.y+bRect.size.height;
    xMax = bRect.origin.x+bRect.size.width;
    while ( steps && ((!dx && (p0.y < yMax || p1.y < yMax)) || (!dy && (p0.x < xMax || p1.x < xMax))) )
    {
        path = [rectP clippedFrom:self];
        if (!path || ![[path list] count])
        {   //NSLog(@"VPolyLine -drawGraduatedWithPrincipal: troubles with extreme paths!");
            p0.x += dx; p0.y += dy;
            p1.x += dx; p1.y += dy;
            [[[rectP list] objectAtIndex:0] setVertices:p0 :p1];
            [[[rectP list] objectAtIndex:1] setVertices:p1 :NSMakePoint(p1.x+dx, p1.y+dy)];
            [[[rectP list] objectAtIndex:2] setVertices:NSMakePoint(p1.x+dx, p1.y+dy) :NSMakePoint(p0.x+dx, p0.y+dy)];
            [[[rectP list] objectAtIndex:3] setVertices:NSMakePoint(p0.x+dx, p0.y+dy) :p0];
            [rectP setBoundsZero];
            /* correct col steps */
            steps--;
        }
        else
            break; // start p0 p1 !
        poolCnt++;
        if (poolCnt > 50)
        {   [pool1 release];
            pool1 = [NSAutoreleasePool new];
            poolCnt = 0;
        }
    }
    p0e.x = p0.x + steps*dx;
    p0e.y = p0.y + steps*dy;
    p1e.x = p1.x + steps*dx;
    p1e.y = p1.y + steps*dy;
    [[[rectP list] objectAtIndex:0] setVertices:p0e :p1e];
    [[[rectP list] objectAtIndex:1] setVertices:p1e :NSMakePoint(p1e.x+dx, p1e.y+dy)];
    [[[rectP list] objectAtIndex:2] setVertices:NSMakePoint(p1e.x+dx, p1e.y+dy) :NSMakePoint(p0e.x+dx, p0e.y+dy)];
    [[[rectP list] objectAtIndex:3] setVertices:NSMakePoint(p0e.x+dx, p0e.y+dy) :p0e];
    [rectP setBoundsZero];
    while ( steps && ((!dx && (p0e.y < yMax || p1e.y < yMax)) || (!dy && (p0e.x < xMax || p1e.x < xMax))) )
    {
        path = [rectP clippedFrom:self];
        if (!path || ![[path list] count])
        {   //NSLog(@"VPolyLine -drawGraduatedWithPrincipal: troubles with extreme paths!");
            p0e.x -= dx; p0e.y -= dy;
            p1e.x -= dx; p1e.y -= dy;
            [[[rectP list] objectAtIndex:0] setVertices:p0e :p1e];
            [[[rectP list] objectAtIndex:1] setVertices:p1e :NSMakePoint(p1e.x+dx, p1e.y+dy)];
            [[[rectP list] objectAtIndex:2] setVertices:NSMakePoint(p1e.x+dx, p1e.y+dy) :NSMakePoint(p0e.x+dx, p0e.y+dy)];
            [[[rectP list] objectAtIndex:3] setVertices:NSMakePoint(p0e.x+dx, p0e.y+dy) :p0e];
            [rectP setBoundsZero];
            /* correct col steps */
            steps--;
            if (steps <= 1)
            {   [pool1 release]; [pool release];
                filled = oldFilled;
                return;
            }
        }
        else
            break; // end
        poolCnt++;
        if (poolCnt > 50)
        {   [pool1 release];
            pool1 = [NSAutoreleasePool new];
            poolCnt = 0;
        }
    }


    if ([colSpaceName isEqual:@"NSCalibratedRGBColorSpace"])
    {
        startCol1 = curCol1 = [startCol redComponent];
        startCol2 = curCol2 = [startCol greenComponent];
        startCol3 = curCol3 = [startCol blueComponent];
        endCol1 = [endCol redComponent];
        endCol2 = [endCol greenComponent];
        endCol3 = [endCol blueComponent];
    }
    else if ([colSpaceName isEqual:@"NSDeviceCMYKColorSpace"])
    {
        startCol1 = curCol1 = [startCol cyanComponent];
        startCol2 = curCol2 = [startCol magentaComponent];
        startCol3 = curCol3 = [startCol yellowComponent];
        startCol4 = curCol4 = [startCol blackComponent];
        endCol1 = [endCol cyanComponent];
        endCol2 = [endCol magentaComponent];
        endCol3 = [endCol yellowComponent];
        endCol4 = [endCol blackComponent];
    }
    else // NSCalibratedWhiteColorSpace
    {
        startCol1 = curCol1 = [startCol whiteComponent];
        endCol1   = [endCol whiteComponent];
    }
    startAlpha = curAlpha = [startCol alphaComponent];
    endAlpha              = [endCol   alphaComponent];

    /* correct steps */
    p0End.x = p0e.x + dx;
    p0End.y = p0e.y + dy;
    length = sqrt(SqrDistPoints(p0, p0End));
    if (steps > MAXSTEPS)
    {
        steps = MAXSTEPS;
        rStepWidth = length / steps;
        fsteps = length / rStepWidth;
        steps = ((int)fsteps) + ((fsteps-((int)fsteps) > 0.0) ? 1 : 0);
        dx = Diff(p0.x, p0End.x)/(double)steps;
        dy = Diff(p0.y, p0End.y)/(double)steps;
    }
    colDiff1 = Diff(curCol1, endCol1);
    colDiff2 = Diff(curCol2, endCol2);
    colDiff3 = Diff(curCol3, endCol3);
    colDiff4 = Diff(curCol4, endCol4);
    colStep1 = colDiff1/steps;
    colStep2 = colDiff2/steps;
    colStep3 = colDiff3/steps;
    colStep4 = colDiff4/steps;
    alphaStep = (endAlpha-startAlpha)/2.0 / steps;

    if (curCol1 > endCol1) colStep1 = -colStep1;
    if (curCol2 > endCol2) colStep2 = -colStep2;
    if (curCol3 > endCol3) colStep3 = -colStep3;
    if (curCol4 > endCol4) colStep4 = -colStep4;

    colStep1  = floor(colStep1 *1000000.0)/1000000.0;
    colStep2  = floor(colStep2 *1000000.0)/1000000.0;
    colStep3  = floor(colStep3 *1000000.0)/1000000.0;
    colStep4  = floor(colStep4 *1000000.0)/1000000.0;
    alphaStep = floor(alphaStep*1000000.0)/1000000.0;

    [[[rectP list] objectAtIndex:0] setVertices:p0 :p1];
    [[[rectP list] objectAtIndex:1] setVertices:p1 :NSMakePoint(p1.x+dx, p1.y+dy)];
    [[[rectP list] objectAtIndex:2] setVertices:NSMakePoint(p1.x+dx, p1.y+dy) :NSMakePoint(p0.x+dx, p0.y+dy)];
    [[[rectP list] objectAtIndex:3] setVertices:NSMakePoint(p0.x+dx, p0.y+dy) :p0];
    [rectP setBoundsZero];
    VHFSetAntialiasing(NO);
    while ( (!dx && (p0.y < yMax || p1.y < yMax)) || (!dy && (p0.x < xMax || p1.x < xMax)) )
    {
        path = [rectP clippedFrom:self];
        if (p0.y >= p0e.y && p0.x >= p0e.x && p1.y >= p1e.y && p1.x >= p1e.x && (!path || ![[path list] count]))
            break;
        [path sortList];
        if ([colSpaceName isEqual:@"NSCalibratedRGBColorSpace"])
            [path setFillColor:[NSColor colorWithCalibratedRed:curCol1 green:curCol2 blue:curCol3 alpha:curAlpha]];
        else if ([colSpaceName isEqual:@"NSDeviceCMYKColorSpace"])
            [path setFillColor:[NSColor colorWithDeviceCyan:curCol1 magenta:curCol2 yellow:curCol3 black:curCol4 alpha:curAlpha]];
        else
            [path setFillColor:[NSColor colorWithCalibratedWhite:curCol1 alpha:curAlpha]];
        [path drawWithPrincipal:principal]; // we want to fill online
        /* Fix me
         * clipfehler im openstep
         * path links und rechts vom clipbereich -> dann wird innerhalb des clipbereichs eine linie dargestellt
         */
        /* moeglicher workaround
         * den pfad zerlegen in mehrere pfade
         * - check if path innerhalb einer der anderen nicht vergessen !!!
        {   int		j, pCnt = [[path list] count];
            BOOL	startIx = 0, endIx = 0;

            while (startIx < pCnt)
            {
                endIx = [path getLastObjectOfSubPath:startIx];
                if (startIx == endIx)
                {   startIx++;
                    continue;
                }
                else
                {   VPath	*p = [VPath path];

                    [p setFilled:1];
                    if ([colSpaceName isEqual:@"NSCalibratedRGBColorSpace"])
                        [path setFillColor:[NSColor colorWithCalibratedRed:curCol1 green:curCol2 blue:curCol3 alpha:1.0]];
                    else if ([colSpaceName isEqual:@"NSDeviceCMYKColorSpace"])
                        [path setFillColor:[NSColor colorWithDeviceCyan:curCol1 magenta:curCol2 yellow:curCol3 black:curCol4 alpha:1.0]];
                    else
                        [path setFillColor:[NSColor colorWithCalibratedWhite:curCol1 alpha:1.0]];
                    for (j = startIx; j<=endIx; j++)
                        [[p list] addObject:[[path list] objectAtIndex:j]];

                    [graduateList addObject:[[p copy] autorelease]];
                }
                startIx = endIx+1;
            }
        }
         */
        [graduateList addObject:[[path copy] autorelease]];

        curCol1  = startCol1  + mul*colStep1;
        curCol2  = startCol2  + mul*colStep2;
        curCol3  = startCol3  + mul*colStep3;
        curCol4  = startCol4  + mul*colStep4;
        curAlpha = startAlpha + mul*alphaStep;
        mul += 1.0;
        p0.x += dx; p0.y += dy;
        p1.x += dx; p1.y += dy;
        /* build new path - else we must rotate the rectangle (sqrt, sin, ..) */
        [[[rectP list] objectAtIndex:0] setVertices:p0 :p1];
        [[[rectP list] objectAtIndex:1] setVertices:p1 :NSMakePoint(p1.x+dx, p1.y+dy)];
        [[[rectP list] objectAtIndex:2] setVertices:NSMakePoint(p1.x+dx, p1.y+dy) :NSMakePoint(p0.x+dx, p0.y+dy)];
        [[[rectP list] objectAtIndex:3] setVertices:NSMakePoint(p0.x+dx, p0.y+dy) :p0];
        [rectP setBoundsZero];

        poolCnt++;
        if (poolCnt > 50)
        {   [pool1 release];
            pool1 = [NSAutoreleasePool new];
            poolCnt = 0;
        }
    }
    if (antialias) VHFSetAntialiasing(antialias);

    [pool1 release];
    [pool release];
    filled = oldFilled;
}

- (void)drawRadialWithPrincipal:principal
{   int			steps = 15, poolCnt = 0, oldFilled = filled;
    float		fsteps, rRadius, endRadius, overlap = 1.0, rStepWidth = stepWidth;
    NSRect		bRect = [self coordBounds];
    NSPoint		rCenter, ll, lr, ur, ul, maxDistP;
    VArc		*theArc, *theArc2;
    NSColor		*endCol = fillColor, *startCol = endColor;
    double		colDiff1 = 1.0, colDiff2 = 1.0, colDiff3 = 1.0, colDiff4 = 1.0, distance, minRadius;
    double		colStep1 = 1.0, colStep2 = 1.0, colStep3 = 1.0, colStep4 = 1.0;
    double		curCol1 = 1.0, curCol2 = 1.0, curCol3 = 1.0, curCol4 = 1.0;
    double		endCol1 = 1.0, endCol2 = 1.0, endCol3 = 1.0, endCol4 = 1.0;
    double		startCol1 = 1.0, startCol2 = 1.0, startCol3 = 1.0, startCol4 = 1.0, mul = 1.0;
    VPath		*path, *arcPath;
    NSAutoreleasePool   *pool, *pool1;
    NSString            *fcolSpaceName, *ecolSpaceName, *colSpaceName;
    BOOL                antialias = VHFAntialiasing();

    if (!bRect.size.width || !bRect.size.height)
        return;

    filled = 1;
    if ([startCol isEqual:endCol])
    {
        [self drawWithPrincipal:principal];
        filled = oldFilled;
        return;
    }

    /* convert fill/endColor to one colorSpaceName */
    fcolSpaceName = [fillColor colorSpaceName];
    ecolSpaceName = [endColor  colorSpaceName];
    if ([fcolSpaceName isEqual:@"NSDeviceCMYKColorSpace"] || [ecolSpaceName isEqual:@"NSDeviceCMYKColorSpace"])
    {
        startCol = [endColor  colorUsingColorSpaceName:@"NSDeviceCMYKColorSpace"];
        endCol   = [fillColor colorUsingColorSpaceName:@"NSDeviceCMYKColorSpace"];
        colSpaceName = @"NSDeviceCMYKColorSpace";
    }
    else if ([fcolSpaceName isEqual:@"NSCalibratedWhiteColorSpace"] &&
             [ecolSpaceName isEqual:@"NSCalibratedWhiteColorSpace"])
    {   startCol = [endColor  colorUsingColorSpaceName:@"NSCalibratedWhiteColorSpace"];
        endCol   = [fillColor colorUsingColorSpaceName:@"NSCalibratedWhiteColorSpace"];
        colSpaceName = @"NSCalibratedWhiteColorSpace";
    }
    else
    {   startCol = [endColor  colorUsingColorSpaceName:@"NSCalibratedRGBColorSpace"];
        endCol   = [fillColor colorUsingColorSpaceName:@"NSCalibratedRGBColorSpace"];
        colSpaceName = @"NSCalibratedRGBColorSpace";
    }
    if (!startCol || !endCol)
    {   NSLog(@"drawGraduatedWithPrincipal: ColorSpace not supported");
        [self drawWithPrincipal:principal];
        filled = oldFilled;
        return;
    }

    if (graduateList)
        [graduateList release];
    graduateList = [[NSMutableArray allocWithZone:[self zone]] init];
    graduateDirty = NO;

    pool = [NSAutoreleasePool new];
    if (!rStepWidth) rStepWidth = 2.0;

    rCenter.x = bRect.origin.x + bRect.size.width*radialCenter.x;
    rCenter.y = bRect.origin.y + bRect.size.height*radialCenter.y;

    ll = bRect.origin;
    ul = NSMakePoint(bRect.origin.x, bRect.origin.y+bRect.size.height);
    ur = NSMakePoint(bRect.origin.x+bRect.size.width, bRect.origin.y+bRect.size.height);
    lr = NSMakePoint(bRect.origin.x+bRect.size.width, bRect.origin.y);
    maxDistP = (SqrDistPoints(ll, rCenter) > SqrDistPoints(lr, rCenter)) ? ll : lr;
    if (SqrDistPoints(ul, rCenter) > SqrDistPoints(maxDistP, rCenter))
        maxDistP = ul;
    if (SqrDistPoints(ur, rCenter) > SqrDistPoints(maxDistP, rCenter))
        maxDistP = ur;
    rRadius = sqrt(SqrDistPoints(rCenter, maxDistP));
    /* our ring */
    arcPath = [VPath path];
    theArc = [VArc arc];
    theArc2 = [VArc arc];
    [arcPath setFilled:1];
    [theArc setFilled:1];
    [theArc setCenter:rCenter start:NSMakePoint(rCenter.x+rRadius, rCenter.y) angle:360.0];
    [[arcPath list] addObject:theArc];
    [theArc2 setCenter:rCenter start:NSMakePoint(rCenter.x+rRadius-rStepWidth, rCenter.y) angle:360.0];
    [[arcPath list] addObject:theArc2];

    fsteps = rRadius / rStepWidth;
    steps = ((int)fsteps) + ((fsteps-((int)fsteps) > 0.0) ? 1 : 0);
    steps --; // for startCol

    pool1 = [NSAutoreleasePool new];

    while (rRadius > TOLERANCE*10.0)
    {
        path = [arcPath clippedFrom:self];
        if (!path || [[path list] count] <= 1)
        {
            rRadius -= rStepWidth;
            [[[arcPath list] objectAtIndex:0] setCenter:rCenter start:NSMakePoint(rCenter.x+rRadius, rCenter.y)
                                                  angle:360.0];
            [[[arcPath list] objectAtIndex:1] setCenter:rCenter
                                                  start:NSMakePoint(rCenter.x+rRadius-rStepWidth, rCenter.y)
                                                  angle:360.0];
            [arcPath setBoundsZero];
            steps--; // correct col steps
        }
        else
            break; // start theArc
        poolCnt++;
        if (poolCnt > 50)
        {   [pool1 release];
            pool1 = [NSAutoreleasePool new];
            poolCnt = 0;
        }
    }
    endRadius = rStepWidth;
    [[[arcPath list] objectAtIndex:0] setCenter:rCenter start:NSMakePoint(rCenter.x+endRadius, rCenter.y)
                                          angle:360.0];
    [[[arcPath list] objectAtIndex:1] setCenter:rCenter start:NSMakePoint(rCenter.x+endRadius-rStepWidth, rCenter.y)
                                          angle:360.0];
    [arcPath setBoundsZero];
    while (endRadius < rRadius)
    {
        path = [arcPath clippedFrom:self];
        if (!path || [[path list] count] <= 1)
        {
            endRadius += rStepWidth;
            [[[arcPath list] objectAtIndex:0] setCenter:rCenter start:NSMakePoint(rCenter.x+endRadius, rCenter.y)
                                                  angle:360.0];
            [[[arcPath list] objectAtIndex:1] setCenter:rCenter
                                                  start:NSMakePoint(rCenter.x+endRadius-rStepWidth, rCenter.y)
                                                  angle:360.0];
            [arcPath setBoundsZero];
            steps--; // correct col steps
            if (steps <= 1)
            {   [pool1 release]; [pool release];
                filled = oldFilled;
                return;
            }
        }
        else
            break; // end
        poolCnt++;
        if (poolCnt > 50)
        {   [pool1 release];
            pool1 = [NSAutoreleasePool new];
            poolCnt = 0;
        }
    }

    if ([colSpaceName isEqual:@"NSCalibratedRGBColorSpace"])
    {
        startCol1 = curCol1 = [startCol redComponent];
        startCol2 = curCol2 = [startCol greenComponent];
        startCol3 = curCol3 = [startCol blueComponent];
        endCol1 = [endCol redComponent];
        endCol2 = [endCol greenComponent];
        endCol3 = [endCol blueComponent];
    }
    else if ([colSpaceName isEqual:@"NSDeviceCMYKColorSpace"])
    {
        startCol1 = curCol1 = [startCol cyanComponent];
        startCol2 = curCol2 = [startCol magentaComponent];
        startCol3 = curCol3 = [startCol yellowComponent];
        startCol4 = curCol4 = [startCol blackComponent];
        endCol1 = [endCol cyanComponent];
        endCol2 = [endCol magentaComponent];
        endCol3 = [endCol yellowComponent];
        endCol4 = [endCol blackComponent];
    }
    else // NSCalibratedWhiteColorSpace
    {
        startCol1 = curCol1 = [startCol whiteComponent];
        endCol1 = [endCol whiteComponent];
    }
    colDiff1 = Diff(curCol1, endCol1);
    colDiff2 = Diff(curCol2, endCol2);
    colDiff3 = Diff(curCol3, endCol3);
    colDiff4 = Diff(curCol4, endCol4);
    colStep1 = colDiff1/steps;
    colStep2 = colDiff2/steps;
    colStep3 = colDiff3/steps;
    colStep4 = colDiff4/steps;

    distance = (rRadius-(endRadius-rStepWidth));
    minRadius = endRadius-rStepWidth;

    if (steps > MAXSTEPS)
    {
        steps = MAXSTEPS;
        colStep1 = colDiff1/steps;
        colStep2 = colDiff2/steps;
        colStep3 = colDiff3/steps;
        colStep4 = colDiff4/steps;
        rStepWidth = distance/steps;
    }

#if 0
/* ultimative hack !!! */
    for (i=0; i<4; i++)
    {   double	testCol, colStep, colDiff;

        switch (i)
        {   case 0: colStep = colStep1; colDiff = colDiff1; break;
            case 1: colStep = colStep2; colDiff = colDiff2; break;
            case 2: colStep = colStep3; colDiff = colDiff3; break;
            default: colStep = colStep4; colDiff = colDiff4;
        }
        testCol = (1.0/colStep)/(([colSpaceName isEqual:@"NSDeviceCMYKColorSpace"]) ? 4.0 : 3.0);
        testCol = testCol-((int)testCol);
        while ( steps > 1 && colStep && /*(testCol < 0.15 || 1.0-testCol < 0.15)*/
                (([colSpaceName isEqual:@"NSDeviceCMYKColorSpace"] &&
                  (Diff(testCol, 0.2) < 0.07 || Diff(1.0-testCol, 0.2) < 0.07)) || // 0.6 - 0.15
                 (/*![colSpaceName isEqual:@"NSDeviceCMYKColorSpace"] &&*/ (testCol < 0.15 || 1.0-testCol < 0.15))))

        {
            steps--;
            colStep1 = colDiff1/steps;
            colStep2 = colDiff2/steps;
            colStep3 = colDiff3/steps;
            colStep4 = colDiff4/steps;
            rStepWidth = distance/steps;
            switch (i)
            {   case 0: colStep = colStep1; break;
                case 1: colStep = colStep2; break;
                case 2: colStep = colStep3; break;
                default: colStep = colStep4;
            }
            testCol = (1.0/colStep)/(([colSpaceName isEqual:@"NSDeviceCMYKColorSpace"]) ? 4.0 : 3.0);
            testCol = testCol-((int)testCol);
            if (steps == 1)
                break;
        }
    }
#endif

    if (curCol1 > endCol1) colStep1 = -colStep1;
    if (curCol2 > endCol2) colStep2 = -colStep2;
    if (curCol3 > endCol3) colStep3 = -colStep3;
    if (curCol4 > endCol4) colStep4 = -colStep4;

    colStep1 = floor(colStep1*1000000.0)/1000000.0;
    colStep2 = floor(colStep2*1000000.0)/1000000.0;
    colStep3 = floor(colStep3*1000000.0)/1000000.0;
    colStep4 = floor(colStep4*1000000.0)/1000000.0;

#if 0
NSLog(@"colStep1: %.15f testCol1: %.15f steps: %d\n", colStep1, ((1.0/colStep1)/(([colSpaceName isEqual:@"NSDeviceCMYKColorSpace"]) ? 4.0 : 3.0))), steps;
NSLog(@"colStep2: %.15f testCol2: %.15f\n", colStep2, ((1.0/colStep2)/(([colSpaceName isEqual:@"NSDeviceCMYKColorSpace"]) ? 4.0 : 3.0)));
NSLog(@"colStep3: %.15f testCol3: %.15f\n", colStep3, ((1.0/colStep3)/(([colSpaceName isEqual:@"NSDeviceCMYKColorSpace"]) ? 4.0 : 3.0)));
#endif

    /* so we get a continuous image if we move the center
     * because the radius of the inner circle is always rStepWidth
     */
    fsteps = distance/rStepWidth;
//    fsteps = rRadius/rStepWidth;
    fsteps = ((int)fsteps) + ((fsteps-((int)fsteps) > 0.0) ? 1 : 0);
//    rRadius = fsteps*rStepWidth;
    distance = fsteps*rStepWidth;
    rRadius = distance + minRadius;
    endRadius = minRadius+rStepWidth;

    if (rStepWidth < 3.0)
       overlap = rStepWidth * 0.2;

    /* build our ring */
    [[[arcPath list] objectAtIndex:0] setCenter:rCenter
                                          start:NSMakePoint(rCenter.x+rRadius, rCenter.y)
                                          angle:360.0];
    if ((rRadius-rStepWidth-overlap) <= 0.0)
        [[[arcPath list] objectAtIndex:1] setCenter:rCenter
                                              start:NSMakePoint(rCenter.x, rCenter.y)
                                              angle:360.0];
    else
        [[[arcPath list] objectAtIndex:1] setCenter:rCenter
                                              start:NSMakePoint(rCenter.x+rRadius-rStepWidth-overlap, rCenter.y)
                                              angle:360.0];
    [arcPath setBoundsZero];

    VHFSetAntialiasing(NO);
    while (rRadius > TOLERANCE*10.0)
    {
        path = [arcPath clippedFrom:self];
        if (rRadius <= endRadius && (!path || [[path list] count] <= 1))
            break;
        if ([[path list] count] > 1)
        {   [path sortList];
            if ([colSpaceName isEqual:@"NSCalibratedRGBColorSpace"])
                [path setFillColor:[NSColor colorWithCalibratedRed:curCol1 green:curCol2 blue:curCol3 alpha:1.0]];
            else if ([colSpaceName isEqual:@"NSDeviceCMYKColorSpace"])
                [path setFillColor:[NSColor colorWithDeviceCyan:curCol1 magenta:curCol2 yellow:curCol3 black:curCol4 alpha:1.0]];
            else
                [path setFillColor:[NSColor colorWithCalibratedWhite:curCol1 alpha:1.0]];
            [path drawWithPrincipal:principal];
            [graduateList addObject:[[path copy] autorelease]];
        }
//else
//    NSLog(@"fault in radialFilling\n");
        curCol1 = startCol1 + mul*colStep1;
        curCol2 = startCol2 + mul*colStep2;
        curCol3 = startCol3 + mul*colStep3;
        curCol4 = startCol4 + mul*colStep4;
        mul += 1.0;
        rRadius -= rStepWidth;
        [[[arcPath list] objectAtIndex:0] setCenter:rCenter
                                              start:NSMakePoint(rCenter.x+rRadius, rCenter.y)
                                              angle:360.0];
        if ((rRadius-rStepWidth-overlap) <= 0.0)
            [[[arcPath list] objectAtIndex:1] setCenter:rCenter
                                                  start:NSMakePoint(rCenter.x, rCenter.y)
                                                  angle:360.0];
        else
            [[[arcPath list] objectAtIndex:1] setCenter:rCenter
                                                  start:NSMakePoint(rCenter.x+rRadius-rStepWidth-overlap, rCenter.y)
                                                  angle:360.0];
        [arcPath setBoundsZero];
        poolCnt++;
        if (poolCnt > 50)
        {   [pool1 release];
            pool1 = [NSAutoreleasePool new];
            poolCnt = 0;
        }
    }
    if (antialias) VHFSetAntialiasing(antialias);

    [pool1 release];
    [pool release];
    filled = oldFilled;
}

- (void)drawAxialWithPrincipal:principal
{   int			steps = 15, poolCnt = 0, oldFilled = filled;
    double		fsteps, rRadius, stepAngle, startAngle, endAngle, rStepWidth = stepWidth;
    NSRect		bRect = [self coordBounds];
    NSPoint		rCenter, ll, lr, ur, ul, maxDistP, startArc, endArc;
    VArc		*theArc;
    VLine		*ecline, *csline;
    NSColor		*endCol = fillColor, *startCol = endColor;
    double		colStep1 = 1.0, colStep2 = 1.0, colStep3 = 1.0, colStep4 = 1.0;
    double		curCol1 = 1.0, curCol2 = 1.0, curCol3 = 1.0, curCol4 = 1.0;
    double		endCol1 = 1.0, endCol2 = 1.0, endCol3 = 1.0, endCol4 = 1.0;
    double		startCol1 = 1.0, startCol2 = 1.0, startCol3 = 1.0, startCol4 = 1.0, mul = 1.0;
    VPath		*path, *cakePath;
    NSAutoreleasePool	*pool, *pool1;
    NSString		*fcolSpaceName, *ecolSpaceName, *colSpaceName;
    BOOL		antialias = VHFAntialiasing();

    if (!bRect.size.width || !bRect.size.height)
        return;

    filled = 1;
    if ([startCol isEqual:endCol])
    {
        [self drawWithPrincipal:principal];
        filled = oldFilled;
        return;
    }

    /* convert fill/endColor to one colorSpaceName */
    fcolSpaceName = [fillColor colorSpaceName];
    ecolSpaceName = [endColor colorSpaceName];
    if ([fcolSpaceName isEqual:@"NSDeviceCMYKColorSpace"] || [ecolSpaceName isEqual:@"NSDeviceCMYKColorSpace"])
    {
        startCol = [endColor colorUsingColorSpaceName:@"NSDeviceCMYKColorSpace"];
        endCol = [fillColor colorUsingColorSpaceName:@"NSDeviceCMYKColorSpace"];
        colSpaceName = @"NSDeviceCMYKColorSpace";
    }
    else if ([fcolSpaceName isEqual:@"NSCalibratedWhiteColorSpace"] &&
             [ecolSpaceName isEqual:@"NSCalibratedWhiteColorSpace"])
    {   startCol = [endColor colorUsingColorSpaceName:@"NSCalibratedWhiteColorSpace"];
        endCol = [fillColor colorUsingColorSpaceName:@"NSCalibratedWhiteColorSpace"];
        colSpaceName = @"NSCalibratedWhiteColorSpace";
    }
    else
    {   startCol = [endColor colorUsingColorSpaceName:@"NSCalibratedRGBColorSpace"];
        endCol = [fillColor colorUsingColorSpaceName:@"NSCalibratedRGBColorSpace"];
        colSpaceName = @"NSCalibratedRGBColorSpace";
    }
    if (!startCol || !endCol)
    {   NSLog(@"drawRadialWithPrincipal: ColorSpace not supported");
        [self drawWithPrincipal:principal];
        filled = oldFilled;
        return;
    }

    if (graduateList)
        [graduateList release];
    graduateList = [[NSMutableArray allocWithZone:[self zone]] init];
    graduateDirty = NO;

    pool = [NSAutoreleasePool new];
    if (!rStepWidth) rStepWidth = 2.0;

    rCenter.x = bRect.origin.x + bRect.size.width*radialCenter.x;
    rCenter.y = bRect.origin.y + bRect.size.height*radialCenter.y;

    ll = bRect.origin;
    ul = NSMakePoint(bRect.origin.x, bRect.origin.y+bRect.size.height);
    ur = NSMakePoint(bRect.origin.x+bRect.size.width, bRect.origin.y+bRect.size.height);
    lr = NSMakePoint(bRect.origin.x+bRect.size.width, bRect.origin.y);
    maxDistP = (SqrDistPoints(ll, rCenter) > SqrDistPoints(lr, rCenter)) ? ll : lr;
    if (SqrDistPoints(ul, rCenter) > SqrDistPoints(maxDistP, rCenter))
        maxDistP = ul;
    if (SqrDistPoints(ur, rCenter) > SqrDistPoints(maxDistP, rCenter))
        maxDistP = ur;
    rRadius = sqrt(SqrDistPoints(rCenter, maxDistP));

    fsteps = (2.0*Pi*rRadius)/rStepWidth;
    steps = ((int)fsteps) + ((fsteps-((int)fsteps) > 0.0) ? 1 : 0);
    steps --; // for startCol

    if (steps > MAXSTEPS)
    {
        steps = MAXSTEPS;
        rStepWidth = (2.0*Pi*rRadius)/steps;
        fsteps = (2.0*Pi*rRadius)/rStepWidth;
        steps = ((int)fsteps) + ((fsteps-((int)fsteps) > 0.0) ? 1 : 0);
    }

    stepAngle = 360.0/(double)steps; // umfang / rStepWidth = cnt, 360 / cnt = stepAngle

    /* our cake */
    startAngle = endAngle = graduateAngle;
    endAngle += 360.0;
    if (startAngle == 360.0) { startAngle = 0.0; endAngle = 360.0; }

    /* korrekt start/endAngle if radCenter laying on bRect frame */
    if ( Diff(rCenter.y, bRect.origin.y) <= 0.0001 ) // down
    {
        if ( Diff(rCenter.x, bRect.origin.x) <= 0.0001 && (!startAngle || startAngle >= 90.0) ) // down left
        {
            startAngle = 0.0;
            endAngle = 90.0;
            fsteps /= 4.0;
        }
        else if ( Diff(rCenter.x, bRect.origin.x+bRect.size.width) <= 0.0001 &&
             (startAngle >= 180.0 || startAngle <= 90.0) ) // down right
        {
            startAngle = 90.0;
            endAngle = 180.0;
            fsteps /= 4.0;
        }
        else if ( !startAngle || startAngle >= 180.0 )
        {
            startAngle = 0.0;
            endAngle = 180.0;
            fsteps /= 2.0;
        }
    }
    else if ( Diff(rCenter.y, bRect.origin.y+bRect.size.height) <= 0.0001 ) // up
    {
        if ( Diff(rCenter.x, bRect.origin.x) <= 0.0001 && startAngle >= 0.0  && startAngle <= 270.0 ) // up left
        {
            startAngle = 270.0;
            endAngle = 360.0;
            fsteps /= 4.0;
        }
        else if ( Diff(rCenter.x, bRect.origin.x+bRect.size.width) <= 0.0001 &&
             (startAngle >= 270.0 || startAngle <= 180.0) ) // up right
        {
            startAngle = 180.0;
            endAngle = 270.0;
            fsteps /= 4.0;
        }
        else if ( startAngle <= 180.0 )
        {
            startAngle = 180.0;
            endAngle = 360.0;
            fsteps /= 2.0;
        }
    }
    else if ( Diff(rCenter.x, bRect.origin.x) <= 0.0001 && startAngle >= 90.0 && startAngle <= 270.0 ) // left
    {
        startAngle = 270.0;
        endAngle = 450.0;
        fsteps /= 2.0;
    }
    else if ( Diff(rCenter.x, bRect.origin.x+bRect.size.width) <= 0.0001 && (startAngle <= 90.0 || startAngle >= 270.0) ) // right
    {
        startAngle = 90.0;
        endAngle = 270.0;
        fsteps /= 2.0;
    }
    steps = ((int)fsteps) + ((fsteps-((int)fsteps) > 0.0) ? 1 : 0);

    startArc = vhfPointAngleFromRefPoint(rCenter, NSMakePoint(rCenter.x+rRadius, rCenter.y), startAngle);
    endArc = vhfPointAngleFromRefPoint(rCenter, startArc, stepAngle);
    cakePath = [VPath path];
    [cakePath setFilled:1];
    ecline = [VLine line];
    [ecline setVertices:endArc :rCenter];
    [[cakePath list] addObject:ecline];
    csline = [VLine line];
    [csline setVertices:rCenter :startArc];
    [[cakePath list] addObject:csline];
    theArc = [VArc arc];
    [theArc setCenter:rCenter start:startArc angle:stepAngle];
    [[cakePath list] addObject:theArc];

    pool1 = [NSAutoreleasePool new];

    while (startAngle < endAngle)
    {
        path = [cakePath clippedFrom:self];
        if (!path || [[path list] count] <= 1)
        {
            startArc = endArc;
            endArc = vhfPointAngleFromRefPoint(rCenter, startArc, stepAngle);
            [[[cakePath list] objectAtIndex:0] setVertices:endArc :rCenter];
            [[[cakePath list] objectAtIndex:1] setVertices:rCenter :startArc];
            [[[cakePath list] objectAtIndex:2] setCenter:rCenter start:startArc angle:stepAngle];
            [cakePath setBoundsZero];
            /* set coordBounds to NSZeroRect */
            [cakePath setList:[[cakePath list] retain] optimize:NO];
            [[cakePath list] release];
            steps--; // correct col steps
            startAngle += stepAngle; // correct startAngle !
        }
        else
            break; // start theArc
        poolCnt++;
        if (poolCnt > 50)
        {   [pool1 release];
            pool1 = [NSAutoreleasePool new];
            poolCnt = 0;
        }
    }
    startArc = vhfPointAngleFromRefPoint(rCenter, NSMakePoint(rCenter.x+rRadius, rCenter.y), endAngle); // -360.0
    endArc = vhfPointAngleFromRefPoint(rCenter, startArc, -stepAngle);
    [[[cakePath list] objectAtIndex:0] setVertices:endArc :rCenter];
    [[[cakePath list] objectAtIndex:1] setVertices:rCenter :startArc];
    [[[cakePath list] objectAtIndex:2] setCenter:rCenter start:startArc angle:-stepAngle];
    [cakePath setBoundsZero];
    /* set coordBounds to NSZeroRect */
    [cakePath setList:[[cakePath list] retain] optimize:NO];
    [[cakePath list] release];

    while (endAngle > graduateAngle-360.0)
    {
        path = [cakePath clippedFrom:self];
        if (!path || [[path list] count] <= 1)
        {
            startArc = endArc;
            endArc = vhfPointAngleFromRefPoint(rCenter, startArc, -stepAngle);
            [[[cakePath list] objectAtIndex:0] setVertices:endArc :rCenter];
            [[[cakePath list] objectAtIndex:1] setVertices:rCenter :startArc];
            [[[cakePath list] objectAtIndex:2] setCenter:rCenter start:startArc angle:-stepAngle];
            [cakePath setBoundsZero];
            /* set coordBounds to NSZeroRect */
            [cakePath setList:[[cakePath list] retain] optimize:NO];
            [[cakePath list] release];
            steps--; // correct col steps
            endAngle -= stepAngle; // correct endAngle !
            if (steps <= 1)
            {   [pool1 release]; [pool release];
                filled = oldFilled;
                return;
            }
        }
        else
            break; // end
        poolCnt++;
        if (poolCnt > 50)
        {   [pool1 release];
            pool1 = [NSAutoreleasePool new];
            poolCnt = 0;
        }
    }

    if ([colSpaceName isEqual:@"NSCalibratedRGBColorSpace"])
    {
        startCol1 = curCol1 = [startCol redComponent];
        startCol2 = curCol2 = [startCol greenComponent];
        startCol3 = curCol3 = [startCol blueComponent];
        endCol1 = [endCol redComponent];
        endCol2 = [endCol greenComponent];
        endCol3 = [endCol blueComponent];
    }
    else if ([colSpaceName isEqual:@"NSDeviceCMYKColorSpace"])
    {
        startCol1 = curCol1 = [startCol cyanComponent];
        startCol2 = curCol2 = [startCol magentaComponent];
        startCol3 = curCol3 = [startCol yellowComponent];
        startCol4 = curCol4 = [startCol blackComponent];
        endCol1 = [endCol cyanComponent];
        endCol2 = [endCol magentaComponent];
        endCol3 = [endCol yellowComponent];
        endCol4 = [endCol blackComponent];
    }
    else // NSCalibratedWhiteColorSpace
    {
        startCol1 = curCol1 = [startCol whiteComponent];
        endCol1 = [endCol whiteComponent];
    }

    colStep1 = Diff(curCol1, endCol1);
    colStep2 = Diff(curCol2, endCol2);
    colStep3 = Diff(curCol3, endCol3);
    colStep4 = Diff(curCol4, endCol4);
    colStep1 /= steps;
    colStep2 /= steps;
    colStep3 /= steps;
    colStep4 /= steps;
    if (curCol1 > endCol1) colStep1 = -colStep1;
    if (curCol2 > endCol2) colStep2 = -colStep2;
    if (curCol3 > endCol3) colStep3 = -colStep3;
    if (curCol4 > endCol4) colStep4 = -colStep4;

    colStep1 = floor(colStep1*1000000.0)/1000000.0;
    colStep2 = floor(colStep2*1000000.0)/1000000.0;
    colStep3 = floor(colStep3*1000000.0)/1000000.0;
    colStep4 = floor(colStep4*1000000.0)/1000000.0;

    /* build our cake */
    if (startAngle >= 360.0)	startAngle -= 360.0;
    if (startAngle < 0.0)	startAngle += 360.0;
    startArc = vhfPointAngleFromRefPoint(rCenter, NSMakePoint(rCenter.x+rRadius, rCenter.y), startAngle);
    endArc = vhfPointAngleFromRefPoint(rCenter, startArc, stepAngle);
    [[[cakePath list] objectAtIndex:0] setVertices:endArc :rCenter];
    [[[cakePath list] objectAtIndex:1] setVertices:rCenter :startArc];
    [[[cakePath list] objectAtIndex:2] setCenter:rCenter start:startArc angle:stepAngle];
    [cakePath setBoundsZero];
    /* set coordBounds to NSZeroRect */
    [cakePath setList:[[cakePath list] retain] optimize:NO];
    [[cakePath list] release];

    VHFSetAntialiasing(NO);
    while (startAngle <= endAngle-stepAngle+10.0*TOLERANCE)
    {
        path = [cakePath clippedFrom:self];
        if (startAngle > endAngle-stepAngle && (!path || [[path list] count] <= 1))
            break;
        if ([[path list] count] > 1)
        {   [path sortList];
            if ([colSpaceName isEqual:@"NSCalibratedRGBColorSpace"])
                [path setFillColor:[NSColor colorWithCalibratedRed:curCol1 green:curCol2 blue:curCol3 alpha:1.0]];
            else if ([colSpaceName isEqual:@"NSDeviceCMYKColorSpace"])
                [path setFillColor:[NSColor colorWithDeviceCyan:curCol1 magenta:curCol2 yellow:curCol3 black:curCol4 alpha:1.0]];
            else
                [path setFillColor:[NSColor colorWithCalibratedWhite:curCol1 alpha:1.0]];
            [path drawWithPrincipal:principal];
            [graduateList addObject:[[path copy] autorelease]];
        }
        curCol1 = startCol1 + mul*colStep1;
        curCol2 = startCol2 + mul*colStep2;
        curCol3 = startCol3 + mul*colStep3;
        curCol4 = startCol4 + mul*colStep4;
        mul += 1.0;
        startArc = endArc;
        endArc = vhfPointAngleFromRefPoint(rCenter, startArc, stepAngle);
        [[[cakePath list] objectAtIndex:0] setVertices:endArc :rCenter];
        [[[cakePath list] objectAtIndex:1] setVertices:rCenter :startArc];
        [[[cakePath list] objectAtIndex:2] setCenter:rCenter start:startArc angle:stepAngle];
        [cakePath setBoundsZero];
        /* set coordBounds to NSZeroRect */
        [cakePath setList:[[cakePath list] retain] optimize:NO];
        [[cakePath list] release];
        startAngle += stepAngle;
        poolCnt++;
        if (poolCnt > 50)
        {   [pool1 release];
            pool1 = [NSAutoreleasePool new];
            poolCnt = 0;
        }
    }
    if (antialias) VHFSetAntialiasing(antialias);

    [pool1 release];
    [pool release];
    filled = oldFilled;
}

/*
 * Check for a control point hit. Return the point number hit in the pt argument.
 * Does not set the graphic selection!!
 */
- (BOOL)hitEdge:(NSPoint)p fuzz:(float)fuzz :(NSPoint*)pt :(float)controlsize
{   int	i;

    for (i=[list count]-1; i>=0; i--)
    {	id obj = [list objectAtIndex:i];

        if ([obj hitEdge:p fuzz:fuzz :pt :controlsize])
        {   NSPoint	p0, plast, prevPt;
            int		begIx = [self getFirstObjectOfSubPath:i];
            int		endIx = [self getLastObjectOfSubPath:begIx];

            p0 = [obj pointWithNum:0];
            /* pt mit 0 oder 1 checken */
            if ( Diff((*pt).x, p0.x) <= TOLERANCE && Diff((*pt).y, p0.y) <= TOLERANCE )
            {	int	prevI = (i-1 < begIx) ? (endIx) : (i-1);
                id	prevG = [list objectAtIndex:prevI];

                prevPt = [prevG pointWithNum:MAXINT];
                /* previous graphic is connected and give us no hit */
                if ( Diff(prevPt.x, p0.x) <= TOLERANCE && Diff(prevPt.y, p0.y) <= TOLERANCE &&
                     ![prevG hitEdge:p fuzz:fuzz :&plast :controlsize] )
                    continue;
                return YES;
            }
            plast = [obj pointWithNum:MAXINT];
            if ( Diff((*pt).x, plast.x) <= TOLERANCE && Diff((*pt).y, plast.y) <= TOLERANCE )
            {	int	nextI = (i+1 > endIx) ? (begIx) : (i+1);
                id	nextG = [list objectAtIndex:nextI];

                prevPt = [nextG pointWithNum:0];
                /* next graphic is connected and give us no hit */
                if ( Diff(prevPt.x, plast.x) <= TOLERANCE && Diff(prevPt.y, plast.y) <= TOLERANCE &&
                     ![nextG hitEdge:p fuzz:fuzz :&p0 :controlsize] )
                    continue;
                return YES;
            }
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
{   int		i, j, cnt = [list count], pCnt = 0;
    BOOL	control = [(App*)NSApp control];

    for (i=0; i<cnt; i++)
    {	id obj = [list objectAtIndex:i];

        if ([obj hitControl:p :pt_num controlSize:controlsize])
        {
            /* check if we must grap the next/prev control pt (curves only) */
            if ( control && (!(*pt_num) || (*pt_num) == [obj numPoints]-1) )
            {   int	begIx = [self getFirstObjectOfSubPath:i];
                int	endIx = [self getLastObjectOfSubPath:begIx];

                /* check prev connected graphic */
                if ( !(*pt_num) )
                {   NSPoint	p0, prevPt;
                    int		pnum=0, prevI = (i-1 < begIx) ? (endIx) : (i-1);
                    id		prevG = [list objectAtIndex:prevI];

                    p0 = [obj pointWithNum:0];
                    prevPt = [prevG pointWithNum:MAXINT];
                    /* previous graphic is connected and give us a hit != last */
                    if ( Diff(prevPt.x, p0.x) <= TOLERANCE && Diff(prevPt.y, p0.y) <= TOLERANCE )
                    {
                        if ( [prevG hitControl:p :&pnum controlSize:controlsize] &&
                             pnum != [prevG numPoints]-1 )
                        {
                            /* now we must take prev graphic */
                            if ( selectedObject >= 0 && selectedObject != prevI )
                            {   [[list objectAtIndex:selectedObject] setSelected:NO];
                                selectedObject = -1;
                            }
                            *pt_num = pnum;
                            if (*pt_num == [prevG selectedKnobIndex]) // arc center we do not select the object
                                selectedObject = prevI;
                            /* correct pCnt */
                            pCnt = 0;
                            for (j=0; j<prevI; j++)
                                pCnt += [[list objectAtIndex:j] numPoints];
                            *pt_num += pCnt;
                            [self setSelected:YES];
                            return YES;
                        }
                    }
                }
                else /* check next connected graphic */
                {   NSPoint	pl, nextPt;
                    int		pnum=0, nextI = (i+1 > endIx) ? (begIx) : (i+1);
                    id		nextG = [list objectAtIndex:nextI];

                    nextPt = [nextG pointWithNum:0];
                    pl = [obj pointWithNum:MAXINT];
                    /* previous graphic is connected and give us a hit != last */
                    if ( Diff(nextPt.x, pl.x) <= TOLERANCE && Diff(nextPt.y, pl.y) <= TOLERANCE )
                    {
                        if ( [nextG hitControl:p :&pnum controlSize:controlsize] && pnum )
                        {
                            /* now we must take prev graphic */
                            if ( selectedObject >= 0 && selectedObject != nextI )
                            {   [[list objectAtIndex:selectedObject] setSelected:NO];
                                selectedObject = -1;
                            }
                            *pt_num = pnum;
                            if (*pt_num == [nextG selectedKnobIndex]) // arc center we do not select the object
                                selectedObject = nextI;
                            /* correct pCnt */
                            if ( nextI != i+1 )
                            {	pCnt = 0;
                                for (j=0; j<nextI; j++)
                                    pCnt += [[list objectAtIndex:j] numPoints];
                            }
                            else
                                pCnt += [obj numPoints];
                            *pt_num += pCnt;
                            [self setSelected:YES];
                            return YES;
                        }
                    }
                }
            }
            if ( selectedObject >= 0 && selectedObject != i )
            {   [[list objectAtIndex:selectedObject] setSelected:NO];
                selectedObject = -1;
            }
            if (*pt_num == [obj selectedKnobIndex]) // arc center we do not select the object
                selectedObject = i;
            *pt_num += pCnt;
            [self setSelected:YES];
            return YES;
        }
        pCnt += [obj numPoints];
    }
    return NO;
}

/* created:   16.09.95
 * modified:  2001-08-18
 * parameter: p	clicked point
 * purpose:   check whether point hits object
 */
- (BOOL)hit:(NSPoint)p fuzz:(float)fuzz
{   int		i;
    int		hit = NO;
    BOOL	alternate = [(App*)NSApp alternate];

    if ( !Prefs_SelectByBorder && filled && [self isPointInside:p] )
        return YES;

    for (i=[list count]-1; i>=0; i--)
    {	id obj = [list objectAtIndex:i];

        if ([obj hit:p fuzz:fuzz])
        {	hit = YES;
            [self deselectAll];
            if (alternate)
            {	[obj setSelected:YES];
                if (selectedObject >= 0 && selectedObject != i)
                    [[list objectAtIndex:selectedObject] setSelected:NO];
                selectedObject = i;
            }
            break;
        }
    }

    return (BOOL)hit;
}

- (void)changeDirectionOfSubPath:(int)startIx :(int)endIx
{   int	i, j;

    for (i=startIx, j=endIx; i<=j; i++, j--)
    {	id	obj;

        [[list objectAtIndex:i] changeDirection];
        if ( i==j )
            break;
        [[list objectAtIndex:j] changeDirection];
        obj = [[list objectAtIndex:j] retain];
        [list replaceObjectAtIndex:j withObject:[list objectAtIndex:i]];
        [list replaceObjectAtIndex:i withObject:obj];
        [obj release];
    }
    dirty = YES;
}

/* created:  1998-04-02
 * modified: 2012-01-20 (open path do not change direction here - allways wrong)
 *           2008-10-11 (use getLastObjectOfSubPath2 to allow open paths -- no)
 * optimize the way that the outer paths are optimized in ccw (cw) direction
 * and the inner paths are optimized in cw (ccw) direction
 * outer paths are the one with an even intersection count
 */
- (void)setDirectionCCW:(BOOL)ccw
{   int		begIx = 0, endIx = 0, cnt = [list count], i, lCount=0, iCntTot;
    NSPoint	p, p0, p1, *pts = NULL;
    BOOL	isCCW, needCCW;
    VLine	*line = [VLine line];
    NSRect	bRect;
    float	y, yMin, yMax, stepWi;

    /* open path - we cant determine direction */
    if ( ![self closed] )
    {   isDirectionCCW = ccw;
        return;
    }

    while ( begIx < cnt )
    {
        /* localize path */
        endIx = [self getLastObjectOfSubPath:begIx]; //  tolerance:TOLERANCE

        /* single element (hack?) */
        if ( begIx == endIx && ![[list objectAtIndex:begIx] isKindOfClass:[VArc class]] &&
             ![[list objectAtIndex:begIx] isKindOfClass:[VPolyLine class]])
        {   begIx = endIx + 1;
            continue;
        }

        /* count intersections of a horizontal line (with intersects our subpath) with the path */
        [[list objectAtIndex:begIx] getPoint:&p at:0];
        bRect = [self coordBounds];
        p0.x = bRect.origin.x - 2000.0; p1.x = bRect.origin.x+bRect.size.width + 2000.0;
        bRect = [self coordBoundsOfSubPath:begIx :endIx];
        yMin = bRect.origin.y;
        yMax = bRect.origin.y + bRect.size.height;
        stepWi = Max((yMax - yMin) / 10.0, TOLERANCE);
        for ( y=yMin+stepWi; y<yMax; y+=stepWi )
        {
            p0.y = p1.y = y;
            [line setVertices:p0 :p1];
            /* determine x for comparison left/right */
            for (i=begIx; i<=endIx; i++)
            {
                if ( [[list objectAtIndex:i] getIntersections:&pts with:line] )
                {   p.x = pts[0].x;
                    free(pts); pts = NULL;
                    break;
                }
            }
            for (i=[list count]-1, lCount=0, iCntTot=0; i>=0; i--)
            {   int	j, iCnt;

                if ( i >= begIx && i <= endIx )
                    continue;
                if ( (iCnt = [[list objectAtIndex:i] getIntersections:&pts with:line]) )
                {   iCntTot += iCnt;
                    for ( j=0; j<iCnt; j++ )
                        if ( pts[j].x < p.x )
                            lCount++;
                    free(pts); pts = NULL;
                }
            }
            //cnt = vhfFilterPoints(pts, cnt, 0.01)
            if ( Even(iCntTot) )	/* ok, we hit no edge */
                break;
        }

        /* if intersections to the left of our subpath are even this subpath becomes ccw (cw) */
        isCCW = [self directionOfSubPath:begIx :endIx];
        needCCW = (lCount%2) ? !ccw : ccw;
        if ( needCCW != isCCW )
            [self changeDirectionOfSubPath:begIx :endIx];
        begIx = endIx + 1;
    }
    isDirectionCCW = ccw;
}

- (int)getFirstObjectOfSubPath:(int)ix
{   int		i, cnt, begIx;
    NSPoint	beg, end;

    cnt = [list count];
    beg = [[list objectAtIndex:ix] pointWithNum:0];
    for ( i=ix-1; i>=0; i-- )
    {
        end = [[list objectAtIndex:i] pointWithNum:MAXINT];
        if ( !i || SqrDistPoints(beg, end) > (TOLERANCE*5)*(TOLERANCE*5) ) // small tolerance
        {   begIx = i;
            if (i)
                begIx += 1; // dist to i -> i
            return begIx;
        }
        beg = [[list objectAtIndex:i] pointWithNum:0];
    }
    return ix;
}

/* find end of sub-path by testing between graphics for small distance
 * If we find a greater distance -> we find our end
 *
 * Note: This method works also for open paths !
 * Attention for questionings like: If ( begIx == endIx ) for open paths !
 * modified: 2008-07-06
 */
- (int)getLastObjectOfSubPath2:(int)startIx
{   int		i, cnt, endIx = startIx;
    float	d;
    NSPoint	start, beg, end;

    cnt = [list count];
    if (cnt <= startIx)
        return startIx;
    start = [[list objectAtIndex:startIx] pointWithNum:0];
    end   = [[list objectAtIndex:startIx] pointWithNum:MAXINT];
    for ( i=startIx+1; i<cnt; i++ )
    {
        beg = [[list objectAtIndex:i] pointWithNum:0];
        if ( (d=SqrDistPoints(end, beg)) < (TOLERANCE*15)*(TOLERANCE*15) )
        {   end = [[list objectAtIndex:i] pointWithNum:MAXINT];
            endIx = i;
            continue; // graphics connectet
        }
        else
            return endIx;
    }
    return endIx;
}

/* find end of sub-path by testing path-points for a small distance
 * to start point.
 * If a point is closer to start than to the next point -> that's our end
 *
 * Note: This method only works for closed paths !
 */
- (int)getLastObjectOfSubPath:(int)startIx
{   int		i, cnt, endIx;
    NSPoint	beg, end;

    cnt = [list count];
    beg = [[list objectAtIndex:startIx] pointWithNum:0];
    for ( i=startIx; i<cnt; i++ )
    {
        /* for i == startIx we also check if the object is closed by itself (rectangle, circle, ...) */
        end = [[list objectAtIndex:i] pointWithNum:MAXINT];
        if ( SqrDistPoints(beg, end) < (TOLERANCE*15)*(TOLERANCE*15) )      // small tolerance for -removeSingleGraphicsAtEnd, setDirectionCCW, contour:inlay:removeloops
        {
            if (i+1 < cnt)
            {   NSPoint	begN = [[list objectAtIndex:i+1] pointWithNum:0];   // start of next element

                if ( SqrDistPoints(end, begN) < (TOLERANCE*15)*(TOLERANCE*15) )
                    continue; // distance to next start point is better -> we stay in sub-path
            }
            endIx = i;
            return endIx;
        }
    }
    return startIx;
}

#define GradientNear(g, t) ([g isKindOfClass:[VCurve class]]) ? [g gradientNear:t] : [g gradientAt:t]

static NSPoint orthPointAt(id g, float r, int dirInd, float at)
{   float	b;
    NSPoint	p, grad, orthP;

	p = [g pointAt:at];			/*  point of object */
	grad = GradientNear(g, at);		/* gradient of point for outline object */

    if ( !(b = sqrt(grad.x*grad.x+grad.y*grad.y)) )
        orthP = p;
    else
    {   orthP.x = p.x + grad.y*r*dirInd/b;
        orthP.y = p.y - grad.x*r*dirInd/b;
    }
    return orthP;
}

/* created:   2008-04-14
 * modified:  2008-04-14
 * purpose:   get the direction of the elements from startIx until endIx
 * parameter: startIx
 *            endIx
 * return:    1 = ccw / 0 = cw
 *
 * get a pt little left/right of one sp graphic which do not cut the subPath
 * look if pt is inside or outside of subPath -> so we have our direction
 *
 */
- (int)directionOfSubPath:(int)startIx :(int)endIx
{   int		i, j;
    float	dirInd = 1.0, d = 0.3; // right = 1.0 left = -1.0 ?????
	VLine	*tLine = [VLine line];
	NSRect	cBnds;

    if ( startIx == endIx )	// this is a 360 degree arc (circle)
    {	VGraphic	*obj = [list objectAtIndex:startIx];

        if ( [obj isKindOfClass:[VArc class]] )
            return ( [(VArc*)obj angle] > 0 ) ? 1 : 0;
        if ( [obj isKindOfClass:[VPolyLine class]] )
            return [(VPolyLine*)obj isDirectionCCW];
        return 1;
    }
    for ( i=startIx; i<=endIx; i++ )
    {	id			objI = [list objectAtIndex:i];
		NSPoint		oPt, beg = [objI pointAt:0.5]; // gradient at start
		int			cnt, intersection = NO, inside=-1;

		/* get pt orthogonal pt right of objI */
		oPt = orthPointAt(objI, d, dirInd, 0.5); // 0 is Beg
		[tLine setVertices:beg :oPt];

		/* check if the line between pt and p05  intersect our subPath */
		for (j=startIx; j<=endIx; j++)
		{	VGraphic	*objJ = [list objectAtIndex:j];
			NSPoint		*pts;
		
			if ( (cnt = [objJ getIntersections:&pts with:tLine]) )
			{
				free(pts); pts = NULL;
				if ( !(cnt == 1 && objJ == objI) )
				{
					intersection = YES;
					break;
				}
			}
		}
		/* else take the next graphic */
		if ( intersection )
			continue;

		/* get check if pt is inside or outside our subPath */
		/* 0 = outside * 1 = on * 2 = inside */
		inside = [self isPointInsideOrOn:oPt dist:TOLERANCE subPath:startIx :endIx];

		if ( inside == 1 )
			continue; // on ?
		/* outside - ccw - 1 */
		if ( !inside )
			return 1;
		/* inside - cw - 0 */
		else
			return 0;
	}

	dirInd = -1,0; // left
	/* check for points left of graphics */
	for ( i=startIx; i<=endIx; i++ )
    {	id			objI = [list objectAtIndex:i];
		NSPoint		oPt, beg = [objI pointAt:0.5]; // gradient at start
		int			cnt, intersection = NO, inside=-1;

		/* get pt orthogonal pt right of objI */
		oPt = orthPointAt(objI, d, dirInd, 0.5); // 0 is Beg
		[tLine setVertices:beg :oPt];

		/* check if the line between pt and p05  intersect our subPath */
		for (j=startIx; j<=endIx; j++)
		{	VGraphic	*objJ = [list objectAtIndex:j];
			NSPoint		*pts;
		
			if ( (cnt = [objJ getIntersections:&pts with:tLine]) )
			{
				free(pts); pts = NULL;
				if ( !(cnt == 1 && objJ == objI) )
				{
					intersection = YES;
					break;
				}
			}
		}
		/* else take the next graphic */
		if ( intersection )
			continue;

		/* get check if pt is inside or outside our subPath */
		/* 0 = outside * 1 = on * 2 = inside */
		inside = [self isPointInsideOrOn:oPt dist:TOLERANCE subPath:startIx :endIx];

		if ( inside == 1 )
			continue; // on ?
		/* outside - cw - 0 */
		if ( !inside )
			return 0;
		/* inside - ccw - 1 */
		else
			return 1;
	}
	cBnds = [self coordBoundsOfSubPath:startIx :endIx];
	if ( !(Diff(startIx, endIx) <= 10 && (cBnds.size.width < 10.0*TOLERANCE || cBnds.size.height < 10.0*TOLERANCE)) )
		NSLog(@"VPath.m: -directionOfSubPath: cant determine direction Bnds: o.x:%.2f o.y:%.2f s.w:%.2f s.h:%.2f",
			  cBnds.origin.x, cBnds.origin.y, cBnds.size.width, cBnds.size.height);
	return 0;
}
#if 0
/* created:   1996-06-08
 * modified:  2001-02-16
 * purpose:   get the direction of the elements from startIx until endIx
 * parameter: startIx
 *            endIx
 * return:    1 = ccw / 0 = cw
 *
 * rangles = sum of ccw angles
 * langles = sum of 360 - ccw angles
 *
 * rAngles = ccw angle between next Object to current Object
 *
 * extreme curves building a loop in the path are still a problem!
 */
- (int)directionOfSubPath:(int)startIx :(int)endIx
{   int		i;
    float	a = 0.0, rAngles = 0, lAngles = 0;

    if ( startIx == endIx )	// this is a 360 degree arc (circle)
    {	VGraphic	*obj = [list objectAtIndex:startIx];

        if ( [obj isKindOfClass:[VArc class]] )
            return ( [(VArc*)obj angle] > 0 ) ? 1 : 0;
        if ( [obj isKindOfClass:[VPolyLine class]] )
            return [(VPolyLine*)obj isDirectionCCW];
        return 1;
    }
    for ( i=startIx; i<=endIx; i++ )
    {	VGraphic	*objI = [list objectAtIndex:i];

        /* angle of object */
        if ( ([objI isKindOfClass:[VArc class]] || [objI isKindOfClass:[VCurve class]])
             && (a = [objI angle]) )
        {
            if ( [objI isKindOfClass:[VArc class]] )
            {
                /* we process the arc in quadrants and
                 * convert the arc angle into an angle between the tangents of
                 * the start and end points of each quadrant (180 - angle) and the rest:
                 * angle <=  90 -> 180 - angle
                 * angle <= 180 -> 90 + (180-(angle-90))
                 * angle <= 270 -> 90 + 90 + (180-(angle-180))
                 * all angles have to be positive (ccw) in the end !
                 */
                if (a >= 0.0)
                {   float	n = floor(a / 90.0);		// number of quadrants.
                    a = 180.0 - (a - n*90.0);			// convert rest of angle to tangent angle.
                    rAngles += n* 90.0;				// add tangent angles for quadrants, but
                    lAngles += n*270.0;				// leave rest for usual addition
                }
                else
                {   float	n = floor(a / -90.0);		// number of quadrants
                    a = 180.0 - (a - n*-90.0);			// convert rest to tangent angle
                    rAngles += n*270.0;
                    lAngles += n* 90.0;
                }

                /*s = [objI pointWithNum:0];	// this gives not the correct angle
                e = [objI pointWithNum:MAXINT];	// we should take the intersection of the tangents
                m = [(VArc*)objI pointAt:0.5];	// But, why not convert the angle of the arc?
                a = vhfAngleBetweenPoints(e, m, s);*/
            }
            rAngles += a;
            if ( [objI isKindOfClass:[VCurve class]] )	// curve builds two edges
                lAngles += 2*360.0 - a;
            else
                lAngles += 360 - a;
        }
        /* angle between end tangent and next start tangent */
        a = 360.0 - angleBetweenGraphicsInStartOrEnd(objI, (i<endIx) ? [list objectAtIndex:i+1]
                                                                     : [list objectAtIndex:startIx], YES);
        if ( Diff(a, 0.0) > 1 && Diff(a, 360.0) > 1 )	// 0.0 was > TOLERANCE
        {   rAngles += a;
            lAngles += 360.0 - a;
        }
    }
    return (rAngles < lAngles) ? 1 : 0;
}
#endif

/* created:   05.06.98
 * modified:  
 * purpose:   get the bounds of the elements from startIx until endIx
 * parameter: startIx
 *            endIx
 * return:    bounds
 */
- (NSRect)coordBoundsOfSubPath:(int)startIx :(int)endIx
{   int		i;
    NSRect	bbox, rect;

    bbox = [[list objectAtIndex:startIx] coordBounds];
    for ( i=startIx+1; i<=endIx; i++ )
    {
        rect = [[list objectAtIndex:i] coordBounds];
        bbox = VHFUnionRect(rect, bbox);
    }
    return bbox;
}

//#define Even(x) (((x)%2) ? 0 : 1)
#define SIDESTEP 0.15 // 0.3

- (BOOL)subPathInsidePath:(int)begIx :(int)endIx
{   int		k, lenSP = Min(100, [list count]), len = Min(100, [list count]);
    int		s, i, j, listCnt, iCnt=0, leftCnt, curSubPathEndIx = -1, spIcnt = 0, on = 0;
	float	tol = 0.1;
    NSPoint	end, lBeg, lEnd, *iPts, *spIpts; // iPts[[list count]], spIpts[[list count]];
    NSRect	bRect, spRect;
    VGraphic	*lineG = [VLine line];
        
    iPts = malloc(len * sizeof(NSPoint));
    spIpts = malloc(lenSP * sizeof(NSPoint));

    /* cut all graphics in path (but from begIx until endIx (our subPath))
     * with horicontal line through end of begIx graphic
     */
	spRect = [self coordBoundsOfSubPath:begIx :endIx];
    bRect = [self bounds];
	tol = (spRect.size.height/10.0); //*(spRect.size.height/10.0);

	for (k=begIx; k<=endIx; k++)
	{
        on = 0;
	    [[list objectAtIndex:k] getPoint:&end at:0.4];

		/*if ( k < endIx && (Diff(end.y, spRect.origin.y) <= tol ||
						   Diff(end.y, spRect.origin.y+spRect.size.height) <= tol) )
			continue;*/ // we check this now inside in an exacter way
		lBeg.y = lEnd.y = end.y;
		lBeg.x = bRect.origin.x -10.0;
		lEnd.x = bRect.origin.x + bRect.size.width + 10.0;
		[(VLine*)lineG setVertices:lBeg :lEnd];

		for (s=1; s<9; s++)
		{   int	left = 0, spLeft = 0, spRight = 0;
			NSRect	curRect=spRect;

            on = 0;
			spIcnt = 0;
			iCnt = 0;
			curSubPathEndIx = ( 0 == begIx ) ? (endIx) : ([self getLastObjectOfSubPath2:0]);
			if ( 0 != begIx )
				curRect = [self coordBoundsOfSubPath:0 :curSubPathEndIx];

			for ( i=0, listCnt = [list count]; i<listCnt; i++ )
			{   VGraphic	*g = [list objectAtIndex:i];
                NSRect      gBnds = [g coordBounds];
				NSPoint     *pts = NULL;
				int         cnt=0;

				if ( i > curSubPathEndIx)
				{
					/* add spIpts to iPts*/
					/* check if one spIpt is on end
					 * remove on point if spIpts are right of end odd (else add)
					 */
					spLeft = 0; spRight = 0;
					on = 0; left = 0;
					for (j=0; j<spIcnt; j++)
					{
						if ( Diff(spIpts[j].x, end.x) < 100.0*TOLERANCE )
						{   on++;
                            break;
						}
						else if ( spIpts[j].x < end.x )
							left++;
							
						if ( spIpts[j].x < spRect.origin.x )
							spLeft++;
						else if ( spIpts[j].x > spRect.origin.x+spRect.size.width )
							spRight++;
					}
                    if ( on )
                        break; // need other k graphic
					/* we dont add the hole subPath if on/it is on right side (else we shot our Even iCnt) */
					if ( !(on && Even(left)) && left && !(spLeft == spIcnt || spRight == spIcnt) )
					{
						if (iCnt+spIcnt >= len)
							iPts = realloc(iPts, (len+=spIcnt*2) * sizeof(NSPoint));
						for (j=0; j<spIcnt; j++)
							iPts[iCnt++] = spIpts[j];
					}
//					else if ( spIcnt )
//						NSLog(@"VPath.m:  -subPathInsidePath: checken !!!");

					spIcnt = 0;

					curSubPathEndIx = ( i == begIx ) ? (endIx) : ([self getLastObjectOfSubPath2:i]);
					if ( i != begIx )
						curRect = [self coordBoundsOfSubPath:i :curSubPathEndIx];
				}
				if ( i >= begIx && i <= endIx )
					continue;

				/* end.y is too near to other subPath up/down y */
				//if ( k < endIx && (Diff(end.y, curRect.origin.y) <= SIDESTEP*SIDESTEP ||
				//				   Diff(end.y, curRect.origin.y+curRect.size.height) <= SIDESTEP*SIDESTEP) )
				if ( k < endIx && gBnds.size.height < gBnds.size.width
                                /* gBnds width bereich sollte spRect treffen */
                                && ((gBnds.origin.x >= spRect.origin.x
                                     && gBnds.origin.x+gBnds.size.width <= spRect.origin.x+spRect.size.width)
                                    || (gBnds.origin.x <= spRect.origin.x
                                        && gBnds.origin.x+gBnds.size.width >= spRect.origin.x)
                                    || (gBnds.origin.x <= spRect.origin.x+spRect.size.width
                                        && gBnds.origin.x+gBnds.size.width >= spRect.origin.x+spRect.size.width))
                               && curRect.origin.x+curRect.size.width >= end.x-100.0*TOLERANCE
                               && (Diff(lEnd.y, gBnds.origin.y) <= 100.0*TOLERANCE ||
								   Diff(lEnd.y, gBnds.origin.y+gBnds.size.height) <= 100.0*TOLERANCE) )
				{
					k++;
					[[list objectAtIndex:k] getPoint:&end at:0.4];

					lBeg.y = lEnd.y = end.y;
					lBeg.x = bRect.origin.x -10.0;
					lEnd.x = bRect.origin.x + bRect.size.width + 10.0;
					[(VLine*)lineG setVertices:lBeg :lEnd];
					s = 1;
                    on++; //	iCnt = -1; no sidestep !
					break;
				}
					
				/* check bounds of current subPath to spRect - completly left or right or inside spRect - continue behind */
				if ( !vhfIntersectsRect(curRect, spRect) /*|| vhfContainsRect(spRect, curRect)*/ )
				{	i = curSubPathEndIx;
					continue;
				}

				cnt = [g getIntersections:&pts with:lineG];

				if ( cnt == 2 &&
					 ( [g isKindOfClass:[VLine class]] || 				// horicontal line
					  ([g isKindOfClass:[VArc class]] && pts[0].x == pts[1].x) ) )	// tangential arc
				{	iCnt = -1; // not even
					free(pts); pts = NULL;
					break;
				}
				else if ( cnt && [g isKindOfClass:[VRectangle class]] )
				{   NSRect	gBounds = [g coordBounds];

					/* if one intersectionpoint layes on the uppest OR lowest y value of the rectangle */
					for (j=0; j<cnt; j++)
					{
						if ( (Diff(pts[j].y, gBounds.origin.y) <= TOLERANCE) ||
							(Diff(pts[j].y, (gBounds.origin.y+gBounds.size.height)) <= TOLERANCE) )
						{
							free(pts); pts = NULL;
							iCnt = -1; // not even
							break;
						}
					}
				}
				else if ( [g isKindOfClass:[VCurve class]] && cnt )
				{   NSPoint	p0, p1, p2, p3, tpoints[3];
					int	cpt, realSol=0, numSol=0;
					double	cy, by, ay, t[3];

					[(VCurve*)g getVertices:&p0 :&p1 :&p2 :&p3];
					/* we must look if one of the intersection points lying on a extrem point of the curve
					 * represent the curve with the equations
					 * x(t) = ax*t^3 + bx*t^2 + cx*t + x(0)
					 * y(t) = ay*t^3 + by*t^2 + cy*t + y(0)
					 * -> 3ay*t^2 + 2by*t + cy = 0
					 */
					cy = 3*(p1.y - p0.y);
					by = 3*(p2.y - p1.y) - cy;
					ay = p3.y - p0.y - by - cy;

					/* get the ts in which the tangente is horicontal
					 */
					numSol = svPolynomial2( 3.0*ay, 2.0*by, cy, t);

					/* when t is on curve */
					realSol=0;
					for ( j=0 ; j<numSol ; j++)
						if ( t[j] >= 0.0 && t[j] <= 1.0 )
							tpoints[realSol++] = [(VCurve*)g pointAt:t[j]];

					/* if one intersection point is identical with one tpoint -> -1 */
					for ( j=0 ; j<realSol ;j++ )
						for ( cpt=0 ; cpt<cnt ; cpt++ )
							if ( Diff(tpoints[j].x, pts[cpt].x) <= TOLERANCE &&
								Diff(tpoints[j].y, pts[cpt].y) <= TOLERANCE )
							{
								free(pts); pts = NULL;
								iCnt = -1;
								break;
							}
				}
				else if ( cnt > 1 && [g isKindOfClass:[VPolyLine class]] )
				{   int	p, nPts = [g numPoints];
					NSPoint	pl0, pl1;

					/* check each line in PolyLine if horicontal */
					for (p=0; p < nPts-1; p++)
					{
						pl0 = [g pointWithNum:p];
						pl1 = [g pointWithNum:p+1];

						if (pointWithToleranceInArray(pl0, TOLERANCE, pts, cnt) && // both point are in pts
							pointWithToleranceInArray(pl1, TOLERANCE, pts, cnt))
						{
							free(pts); pts = NULL;
							iCnt = -1;
							break;
						}
					}
				}

				// add points if not allways inside pparray
				// else check if pt is edge pt of graphic -> return -1
				for (j=0; j<cnt && iCnt != -1; j++)
				{
					if (spIcnt+cnt >= lenSP)
						spIpts = realloc(spIpts, (lenSP+=cnt*2) * sizeof(NSPoint));

					if ( !pointWithToleranceInArray(pts[j], 2.0*TOLERANCE, spIpts, spIcnt) )
						spIpts[spIcnt++] = pts[j];
					else
					{   NSPoint	startG, endG;

						if ( [g isKindOfClass:[VLine class]] )		/* line */
							[(VLine*)g getVertices:&startG :&endG];
						else if ( [g isKindOfClass:[VArc class]] || [g isKindOfClass:[VCurve class]] )
						{   startG = [g pointWithNum:0];
							endG = [g pointWithNum:MAXINT];
						}
						else if ( [g isKindOfClass:[VRectangle class]] )
						{   NSPoint	ur, ul, size;
							[(VRectangle*)g getVertices:&startG :&size]; // origin size
							endG = startG; endG.x += size.x;
							ul = startG; ul.y += size.y;
							ur = endG; ur.y += size.y;
							if ( (Diff(pts[j].x, ul.x) + Diff(pts[j].y, ul.y) < 10.0*TOLERANCE) ||
								(Diff(pts[j].x, ur.x) + Diff(pts[j].y, ur.y) < 10.0*TOLERANCE) )
								continue; // do not add
						}
						else if ( [g isKindOfClass:[VPolyLine class]] )
						{   int	k, pCnt = [(VPolyLine*)g ptsCount], stop = 0;

							for (k=1; k<pCnt-1; k++)
							{   NSPoint	pt = [(VPolyLine*)g pointWithNum:k];
								if ( Diff(pts[j].x, pt.x) + Diff(pts[j].y, pt.y) < 10.0*TOLERANCE )
								{   stop = 1; break; }
							}
							if (stop)
								continue; // do not add
							[(VPolyLine*)g getEndPoints:&startG :&endG];
						}
						else
						{   startG.x = endG.x = pts[j].x; startG.y = endG.y = pts[j].y;
						}
						/* point is no edge point of g -> add */
						if ( (Diff(pts[j].x, startG.x) + Diff(pts[j].y, startG.y) > 10.0*TOLERANCE) &&
							(Diff(pts[j].x, endG.x) + Diff(pts[j].y, endG.y) > 10.0*TOLERANCE) )
							spIpts[spIcnt++] = pts[j];
						else
						{
							iCnt = -1; // /\ peek of this contraction twice force an error
							break;
						}
					}
				}
				if (pts)
                    free(pts);
				if ( iCnt < 0 )
					break; // sidestep !
			}
            if ( on )
                break; // need other k Graphic

			if ( iCnt < 0 )
			{   spIcnt = 0;
				lBeg.y = lEnd.y = end.y + ((s%2) ? (-SIDESTEP*s) : (SIDESTEP*s));
				while ( (lBeg.y < spRect.origin.y || lBeg.y > spRect.origin.y+spRect.size.width) && s < 7 )
				{
					s++;
					lBeg.y = lEnd.y = end.y + ((s%2) ? (-SIDESTEP*s) : (SIDESTEP*s));
				}
				[(VLine*)lineG setVertices:lBeg :lEnd];
				continue; // sidestep !
			}
			/* add spIpts */
			/* check if one spIpt is on end
			 * remove on point if spIpts are right of end odd (else add)
			 */
			spLeft = 0; spRight = 0;
			on = 0; left = 0;
			for (j=0; j<spIcnt; j++)
			{
				if ( Diff(spIpts[j].x, end.x) < 100.0*TOLERANCE )
				{   on++;
                    break;
				}
				else if ( spIpts[j].x < end.x )
					left++;

				if ( spIpts[j].x < spRect.origin.x )
					spLeft++;
				else if ( spIpts[j].x > spRect.origin.x+spRect.size.width )
					spRight++;
			}
            if ( on )
                break; // need other k Graphic
			/* we dont add the hole subPath if on/it is on right side (else we shot our Even iCnt) */
			if ( !(on && Even(left)) && left && !(spLeft == spIcnt || spRight == spIcnt) )
			{
				if (iCnt+spIcnt >= len)
					iPts = realloc(iPts, (len+=spIcnt*2) * sizeof(NSPoint));
				for (j=0; j<spIcnt; j++)
					iPts[iCnt++] = spIpts[j];
			}
			if ( (Even(iCnt) && iCnt) || (!iCnt && s == 1) ) // (cnt || s == 1) &&
				break;

			lBeg.y = lEnd.y = end.y + ((s%2) ? (-SIDESTEP*s) : (SIDESTEP*s));
			while ( (lBeg.y < spRect.origin.y || lBeg.y > spRect.origin.y+spRect.size.width) && s < 7 )
			{
				s++;
				lBeg.y = lEnd.y = end.y + ((s%2) ? (-SIDESTEP*s) : (SIDESTEP*s));
			}
			[(VLine*)lineG setVertices:lBeg :lEnd];
		}
		if ( !on && ((Even(iCnt) && iCnt) || (!iCnt && s == 1)) )
			break;
//		else
//			NSLog(@"VPath.m: -subPathInsidePath: take next graphic");
	}
	if ( iCnt < 0 )
	{
		NSLog(@"VPath.m: -subPathInsidePath: possible fault x:%.2f y:%.2f", end.x, end.y);
		return NO;
	}
    /* count iPts left of end */
    leftCnt = 0;
    for (i=0; i<iCnt; i++)
        if ( iPts[i].x < end.x || Diff(iPts[i].x, end.x) < 2.0*TOLERANCE )
            leftCnt++;

    /* release iPts */
    if ( [list count] )
    {   free(iPts);
        free(spIpts);
        //NSZoneFree((NSZone*)[(NSObject*)NSApp zone], *ppArray);
        iPts = spIpts = 0;
    }

    if ( !leftCnt || leftCnt == iCnt )	/* all points right or left of end */
        return NO;
    return ( Even(leftCnt) ) ? NO : YES;
}

/*
 * optimize path - return NO if we found a gap
 */
- (BOOL)optimizePath:(float)w
{   int		i1, i2, changeI, startIndex = 0;
    float	startDistance = MAXCOORD, dist = w*w, dHalf = (w/2.0)*(w/2.0), d1, d2, d, ds1, ds2;
    NSPoint	l1S, l1E, l2S, l2E, sGS = NSZeroPoint;
    BOOL    closedPath = NO; // after YES no insertion befor startIndex

    if ( ![list count] )
        return NO;

    for (i1 = 0; i1<(int)[list count]-1; i1++)
    {	VGraphic	*l1=[list objectAtIndex:i1];
        BOOL        insertAtStartIndex = NO;

        if ( [l1 isKindOfClass:[VRectangle class]] ||
             ([l1 isKindOfClass:[VArc class]] && Abs([(VArc*)l1 angle]) == 360.0) ||
             ([l1 isKindOfClass:[VPolyLine class]] &&
              SqrDistPoints([l1 pointWithNum:0], [l1 pointWithNum:MAXINT]) < TOLERANCE) )
        {   startIndex++;
            continue;
        }
        sGS = [[list objectAtIndex:startIndex] pointWithNum:0];
        startDistance = MAXCOORD;
        changeI = i1+1;
        l1S = [l1 pointWithNum:0];
        l1E = [l1 pointWithNum:MAXINT];
        for (i2=i1+1; i2<(int)[list count]; i2++)
        {   VGraphic	*l2=[list objectAtIndex:i2];

            l2S = [l2 pointWithNum:0];
            l2E = [l2 pointWithNum:MAXINT];
            d1 = SqrDistPoints(l1E, l2S); d2 = SqrDistPoints(l1E, l2E);
            if ( d1 < startDistance || d2 < startDistance )
            {
                if ( d2 < d1 )
                {   startDistance = d2;
                    [l2 changeDirection];
                    l2S = [l2 pointWithNum:0];
                    l2E = [l2 pointWithNum:MAXINT];
               }
                else
                    startDistance = d1;
                changeI = i2;
                insertAtStartIndex = NO;
                if ( Diff(startDistance, 0.0) == 0.0 )
                    break;
            }
            /* distance to start graphic start point ! - open paths */
            ds1 = SqrDistPoints(sGS, l2E); ds2 = SqrDistPoints(sGS, l2S);
            if ( closedPath == NO && (ds1 < startDistance || ds2 < startDistance) )
            {
                if ( ds2 < ds1 )
                {   startDistance = ds2;
                    [l2 changeDirection];
                }
                else
                    startDistance = ds1;
                changeI = i2;
                insertAtStartIndex = YES;
                if ( Diff(startDistance, 0.0) == 0.0 )
                    break;
            }
        }
        
        if ( insertAtStartIndex && startDistance ) /* close hole - also for open paths */
        {   VGraphic	*l2 = [list objectAtIndex:changeI], *sG = [list objectAtIndex:startIndex];

            d1 = SqrDistPoints(l1E, sGS);
            l2S = [l2 pointWithNum:0];
            l2E = [l2 pointWithNum:MAXINT];
            d = SqrDistPoints(l2E, sGS);
            /* if dist of l1E to startG is smaller than dist of nextG(l2) to l1S -> close to startG */
            if ( d && d1 < d )
            {   d = d1;
                [l2 changeDirection]; // endpoint is nearest, not good vor startIndex, and l2 become next startGraphic
                l2 = sG; l2S = sGS;
                if ( d && d <= dist )
                {	VGraphic	*lineG = [VLine line];

                    if ( d <= dHalf )
                    {
                        if ( [self closeGapBetween:l1 and:l2] ) // line added !
                        {   i1 += 1; changeI += 1; }            // behind l1 is correct here
                    }
                    else
                    {   [lineG setColor:[l2 color]];
                        [lineG setWidth:[l2 width]]; [lineG setSelected:NO];
                        [(VLine*)lineG setVertices:l1E :l2S];
                        [list insertObject:lineG atIndex:i1+1];
                        i1 += 1; changeI += 1;
                    }
                }
                else if ( startDistance > dist && d1 > dist )
                    NSLog(@"VPath.m: -optimizePath:: Gap 0"); // return NO;
                insertAtStartIndex = NO;
                closedPath = YES;
                startIndex = i1+1;
            }
            else if ( d <= dist ) // close dist from l2 (changeG) to sG
            {	VGraphic	*lineG = [VLine line];

                if ( d <= dHalf )
                {
                    if ( [self closeGapBetween:l2 and:sG] )
                    {   i1 += 1; changeI += 1;
                        lineG = [list objectAtIndex:changeI];
                        [list insertObject:lineG atIndex:startIndex];
                        [list removeObjectAtIndex:changeI+1];
                    } // line added behind l2 ! falsch oft immer muss vor sG !
                }
                else
                {   [lineG setColor:[l2 color]];
                    [lineG setWidth:[l2 width]]; [lineG setSelected:NO];
                    [(VLine*)lineG setVertices:l2E :sGS];
                    [list insertObject:lineG atIndex:startIndex];
                    i1 += 1; changeI += 1;
                }
            }
            else if ( startDistance > dist && d > dist )
                NSLog(@"VPath.m: -optimizePath:: Gap 0"); // return NO;
            if ( startDistance > dist )
                startIndex = i1+1;
        }
        else if ( startDistance ) /* close hole */
        {   VGraphic	*l2 = [list objectAtIndex:changeI], *sG = [list objectAtIndex:startIndex];

            d1 = SqrDistPoints(l1E, sGS);
            l2S = [l2 pointWithNum:0];
            d = SqrDistPoints(l1E, l2S);
            /* if dist to startG is smaller than dist to nextG -> close to startG*/
            if ( d && d1 < d )
            {   d = d1;
                l2 = sG; l2S = sGS;
                startIndex = i1+1;
                closedPath = YES;
            }
            if ( d && d <= dist )
            {	VGraphic	*lineG = [VLine line];

                if ( d <= dHalf )
                {
                    if ( [self closeGapBetween:l1 and:l2] ) // line added !
                    {   i1 += 1; changeI += 1; }            // behind l1 ist correct here
                }
                else
                {   [lineG setColor:[l2 color]];
                    [lineG setWidth:[l2 width]]; [lineG setSelected:NO];
                    [(VLine*)lineG setVertices:l1E :l2S];
                    [list insertObject:lineG atIndex:i1+1];
                    i1 += 1; changeI += 1;
                }
            }
            else if ( startDistance > dist && d1 > dist )
                NSLog(@"VPath.m: -optimizePath:: Gap"); // return NO;
            if ( startDistance > dist )
                startIndex = i1+1;
        }

        if ( insertAtStartIndex )
        {   VGraphic	*gCh=[list objectAtIndex:changeI];

            [list insertObject:gCh atIndex:startIndex];
            [list removeObjectAtIndex:changeI+1];
        }
        /* if the nearest element is not the next_in_list */
        else if ( changeI != (i1+1) )
        {   VGraphic	*gCh=[list objectAtIndex:changeI];

            [list insertObject:gCh atIndex:i1+1];
            [list removeObjectAtIndex:changeI+1];
        }
    }
    /* close hole from last to start element */
    {   VGraphic	*l1=[list objectAtIndex:[list count]-1];
        VGraphic	*l2= [list objectAtIndex:startIndex];

        l1E = [l1 pointWithNum:MAXINT];
        l2S = [l2 pointWithNum:0];
        if ( (d=SqrDistPoints(l1E, l2S)) && d <= dist )
        {   VGraphic	*lineG = [VLine line];

            if ( d <= dHalf )
                [self closeGapBetween:l1 and:l2];
            else
            {   [lineG setColor:[l2 color]];
                [lineG setWidth:[l2 width]]; [lineG setSelected:NO];
                [(VLine*)lineG setVertices:l1E :l2S];
                [list addObject:lineG];
            }
        }
        else if ( d )
            return NO;
    }

    dirty = YES;
    return YES;
}

/*
 * are the most meters of otherP inside path
 */
- (BOOL)isMostOfOtherPathInsidePath:(VPath*)otherP :(VPath*)path
{   int	i, cnt=[[otherP list] count], insideCnt=0, insideDist=0, outsideCnt=0, outsideDist=0;

    /* otherPath is tiled from path !
     * we count elements/distance of otherP wich are inside path and which not
     * if more than the half distance of hole otherP is inside path -> return YES
     */
    for (i=0; i<cnt;i++)
    {   VGraphic	*g = [[otherP list] objectAtIndex:i];
        NSPoint	pIn, start, end;

        [g getPoint:&pIn at:0.4];
        start = [g pointWithNum:0];
        end = [g pointWithNum:MAXINT];

        /* point inside path */
        if ( [path isPointInside:pIn] )
        {   insideCnt++;
            insideDist += SqrDistPoints(start, end);
        }
        else
        {   outsideCnt++;
            outsideDist += SqrDistPoints(start, end);
        }
    }
    if ( insideDist > (insideDist+outsideDist)/2.0 )
        return YES;
    return NO;
}

/* can only be used after optimize
 * remove graphics at list end which do not have two neighbours
 */
- (BOOL)isShortGraphic:g
{
    if ( [g isKindOfClass:[VLine class]] )
    {   NSPoint	p0, p1;
        [(VLine*)g getVertices:&p0 :&p1];
        if ( SqrDistPoints(p0, p1) < TOLERANCE*500.0 )
            return YES;
    }
    else if ( [g isKindOfClass:[VRectangle class]] )
    {   NSPoint	o, s;
        [(VRectangle*)g getVertices:&o :&s];
        if ( s.x < TOLERANCE*100.0 && s.y < TOLERANCE*100.0 )
            return YES;
    }
    else if ( [g isKindOfClass:[VArc class]] )
    {   float	r = [(VArc*)g radius], a = [(VArc*)g angle];
        if ( r < TOLERANCE*500.0 && Abs(a) < TOLERANCE*7000.0 )
            return YES;
    }
    else if ( [g isKindOfClass:[VCurve class]] )
    {   NSPoint	p0, p1, p2, p3;
        [(VCurve*)g getVertices:&p0 :&p1 :&p2 :&p3];
        if ( SqrDistPoints(p0, p3) < TOLERANCE*1000.0 && SqrDistPoints(p0, p1) < TOLERANCE*500.0 &&
            SqrDistPoints(p1, p2) < TOLERANCE*500.0 && SqrDistPoints(p2, p3) < TOLERANCE*500.0 )
            return YES;
    }
    return NO;
}

/*- (int)getLastObjectOfSubPath:(int)startIx tolerance:(float)tolerance
{   int		i, cnt, endIx;
    NSPoint	beg, end;

    cnt = [list count];
    beg = [[list objectAtIndex:startIx] pointWithNum:0];
    for ( i=startIx; i<cnt; i++ )
    {
        end = [[list objectAtIndex:i] pointWithNum:MAXINT];
        if ( SqrDistPoints(beg, end) < tolerance )
        {   endIx = i;
            return endIx;
        }
    }
    return startIx;
}*/

#define CLOSETOLERANCE 0.03
- (void)removeSingleGraphicsAtEnd:(VPath*)aPath
{   long	i, endIx;

    // for (i=[alist count]-1 ;i >= 0 ; i--)
    for (i=0; i < (int)[[aPath list] count]; i++)
    {   VGraphic	*gs = [[aPath list] objectAtIndex:i];

        endIx = [aPath getLastObjectOfSubPath:i]; // tolerance:TOLERANCE*3.0

        if ( i == endIx && [self isShortGraphic:gs] )
        {   [[aPath list] removeObjectAtIndex:i];
            i--;
        }
        else if ( i != endIx && Diff(i, endIx) < 3 ) // max 3 gr
        {   int	j, remove = 1;

            for (j=i ;j < endIx ; j++)
            {   if ( ![self isShortGraphic:[[aPath list] objectAtIndex:j]] )
                {   remove = 0;
                    break;
                }
            }
            if ( remove )
            {   for (j=i ;j < endIx ; j++)
                {   [[aPath list] removeObjectAtIndex:j];
                    j--;
                    endIx--;
                }
                i--;
            }
            else
                i = endIx;
        }
        else
            i = endIx;
    }
}

/* always two points refer to each other in array
 * j is index of first point-pair we check
 * i pair we must change - cant't explain
 */
BOOL begEndPairTwiceInArray(int ix, NSPoint *array, int cnt)
{   int	i;

    for (i=0; i<cnt-1; i+=2)
        if ( i != ix
            && Diff(array[ix].x, array[i+1].x) + Diff(array[ix].y, array[i+1].y) <= 30.0*TOLERANCE
            && Diff(array[ix+1].x, array[i].x) + Diff(array[ix+1].y, array[i].y) <= 30.0*TOLERANCE)
            return YES;
    return NO;
}

/* here we remove the loops
 * first we remove hole selected subPaths
 * than we join subPaths wich overlap each other
 * and now we look for overlaps inside subPath itself
 * and for loops in subPath
 * this three things we do only if we find conforming points !
 * and check if path is realy closed (closing little gaps)
 * modified: 2005-07-20
 */
- (void)optimizeSubPathsToClosedPath:(VPath*)path :(float)w :(int*)subPathSplitted
{   int		i, listCnt = [[path list] count], addedAtEnd[listCnt], addCnt = 0, noticeJ = -1, noticeK = -1;
    float	tol = 10.0*TOLERANCE; // 5.0
    BOOL	openPath = NO;

    /* remove subPaths were all graphics are selected */
    for (i=0; i<listCnt; i++)
    {	VPath		*sp = [[path list] objectAtIndex:i];
        int		j, spCnt = [[sp list] count], startJ = spCnt;

        /* search for a not selected graphic */
        for (j=0; j<spCnt; j++)
        {   VGraphic	*curG = [[sp list] objectAtIndex:j];
            NSPoint	s, e;

            s = [curG pointWithNum:0];
            e = [curG pointWithNum:MAXINT];

            if (![curG isSelected] /*&& SqrDistPoints(s, e) > minL*/ )
            {   startJ = j;
                break;
            }
        }
        /* no one found -> remove subPath */
        if (startJ >= spCnt)
        {
            [[sp list] removeAllObjects];
            subPathSplitted[i] = NO; // time
            continue;
        }
    }

    /* joine subPaths with each other */
    for (i=0, listCnt = [[path list] count]; i<listCnt; i++)
    {	VPath		*sp = [[path list] objectAtIndex:i];
        int		j, k, spCnt = [[sp list] count], startJ = spCnt, selected = 0;
        VGraphic	*startG=nil;

        if (!spCnt || subPathSplitted[i] == NO)
            continue;
        /* search for a not selected graphic */
        for (j=0; j<spCnt; j++)
        {   VGraphic	*curG = [[sp list] objectAtIndex:j];
            NSPoint	s, e;

            s = [curG pointWithNum:0];
            e = [curG pointWithNum:MAXINT];

            if (![curG isSelected] /*&& SqrDistPoints(s, e) > minL*/ )
            {   startJ = j;
                break;
            }
        }
        /* no one found -> remove subPath - also possible after we remove something */
        if (startJ >= spCnt)
        {
            [[sp list] removeAllObjects];
            subPathSplitted[i] = NO; // time
            continue;
        }
        /* subPathSplitted -> look for a not selected graphic - and next for a selected graphic */
        startG = [[sp list] objectAtIndex:startJ];
        for (j=startJ; j<spCnt; j++)
        {   VGraphic	*curG = [[sp list] objectAtIndex:j];
            NSPoint	ce;

            if ([curG isSelected])
                continue;

            ce = [curG pointWithNum:MAXINT];

            for (k=((j+1 < spCnt)?(j+1):0); k<((j+1 < spCnt)?spCnt:startJ); k++)
            {   VGraphic	*nextG = [[sp list] objectAtIndex:k];
                NSPoint		ns, ne;
                float		distance = MAXCOORD;
                int		l, m, n;

                ns = [nextG pointWithNum:0];
                ne = [nextG pointWithNum:MAXINT];
                distance = SqrDistPoints(ce, ns);
                if (Diff(distance, 0.0) <= TOLERANCE && ![nextG isSelected])
                {
                    break; // nothing to do graphics laying correct
                }
                else if ([nextG isSelected])
                {   int		selectedGs = 0;
                    BOOL	stop = NO, added = NO;
                    VGraphic	*cgp2 = [[sp list] objectAtIndex:(((k+1) < spCnt) ? (k+1):(0))];

                    /* search the end of the selected graphics */
                    for (l=((k+1 < spCnt) ? (k+1):0); l < ((k+1 < spCnt) ? spCnt:k); l++)
                    {   VGraphic	*lg = [[sp list] objectAtIndex:l];
                        NSPoint		s, e;

                        s = [lg pointWithNum:0];
                        e = [lg pointWithNum:MAXINT];
                        /* lg is selected */
                        if ([lg isSelected])
                        {
                            selectedGs++;
                            if (l+1 >= spCnt)
                                l = -1; // so we go on at 0
                            if (l == k)
                                break; // one time around !!!
                            continue;
                        }
                        /* lg close to curG end !! - this is a loop inside subPath */
                        else if (Diff(SqrDistPoints(ce, s), 0.0) <= TOLERANCE)
                        {   stop = YES;
                            break;
                        }
                        /* end of selected graphics in sp */
                        else
                        {   int		o, backSelected = 0;
                            VGraphic	*lgm1, *lgm2;
                            int		from = -1, to = -1;
                            int		possCnt = 2, possibleSi[3], possibleEi[3];
                            NSPoint	possibleS[3], possibleE[3], em1, em2;
                            NSPoint	nsp1 = [cgp2 pointWithNum:0]/*, nsm1 = [curG pointWithNum:0]*/;
                            float	sqrTolTen = (10.0*TOLERANCE)*(10.0*TOLERANCE);

                            /* check distance around - one/two graphic above end of selected graphic(s) */
                            lgm1 = [[sp list] objectAtIndex:(((l-1) < 0) ? (spCnt-1):(l-1))];
                            em1 = [lgm1 pointWithNum:MAXINT];
                            lgm2 = [[sp list] objectAtIndex:(((l-2) < 0) ? (spCnt+(l-2)):(l-2))];
                            em2 = [lgm2 pointWithNum:MAXINT];

                            possibleS[0] = ns; possibleSi[0] = k; // nextG start
                            possibleS[1] = nsp1; possibleSi[1] = ((k+1) < spCnt) ? (k+1) : (0); // nextG+1 start

                            possibleE[0] = em1; possibleEi[0] = ((l-1) < 0)?(spCnt-1):(l-1); // lgm1 end
                            possibleE[1] = em2; // lgm2 end
                            possibleEi[1] = ((l-2) < 0) ? (((l-2) == -1) ? (spCnt-1):(spCnt-2)) : (l-2);

                            if (!selectedGs)
                                possCnt = 1; // only one point pair possible - only one graphic is selected
                            else // if (selectedGs == 1)
                                possCnt = 2;

                            /* check if backward are selected elements in sp path !!!!! */
                            from = ((l-1) < 0) ? (spCnt-1) : (l-1);
                            to = k;
                            for (m=to; m >= ((!to || to < from) ? 0:from); m--)
                            {
                                if ([[[sp list] objectAtIndex:m] isSelected])
                                    backSelected++;
                                if (!m && to < from) // we step over 0 - second part until from !
                                {   m = spCnt;
                                    to = from+1; // little hack mh - second part until from !
                                }
                            }

                            /* search through other subPaths which are splitted */
                            for (o=0; o < listCnt; o++)
                            {   VPath	*oSp=nil;
                                BOOL	secondTime = NO;
                                BOOL	oStartIsSelected = YES;
                                int     notSelected = 0, selected = 0, oSpCnt, oStart = -1;
                                NSPoint	oStartPt = NSZeroPoint;

                                if (o == i || !subPathSplitted[o])
                                    continue;

                                oSp = [[path list] objectAtIndex:o];
                                oSpCnt = [[oSp list] count];

                                /* search in other subPath for graphic which hit one of possibleE/S */
                                /* with enoth space between ! */
                                /* selected or not selected is not interesting */
                                for (n=0; n < oSpCnt; n++)
                                {   VGraphic	*nlG = [[oSp list] objectAtIndex:n];
                                    VGraphic	*nlGm1 = nil, *nlGm2 = nil;
                                    NSPoint	nls, nle;

                                    nlGm1 = [[oSp list] objectAtIndex:(((n-1) < 0) ? (oSpCnt-1) : (n-1))];
                                    if (oSpCnt > 1)
                                        nlGm2 = [[oSp list] objectAtIndex:(((n-2) < 0)?(oSpCnt+(n-2)):(n-2))];

                                    if (n == oStart)
                                        break;
                                    nls = [nlG pointWithNum:0];
                                    nle = [nlG pointWithNum:MAXINT];
                                    /* nlG hit one of possibleE/possibleS */
                                    if ((oStart == -1 || secondTime == NO) &&
                                        (([nlG isSelected] && (![nlGm1 isSelected] || ![nlGm2 isSelected])) ||
                                         (![nlG isSelected] && ([nlGm1 isSelected] || [nlGm2 isSelected]))) &&
                                        (pointWithToleranceInArray(nls, tol, possibleE, possCnt) ||
                                         pointWithToleranceInArray(nls, tol, possibleS, possCnt)))
                                    {
                                        if (oStart != -1)
                                            secondTime = YES; // else we got a loop
                                        oStart = n; oStartPt = nls;
                                        if (![nlG isSelected]) // nlG is NOT selected - we search not sels
                                        {   oStartIsSelected = NO;
                                            selected = 0;
                                        }
                                        else
                                        {   oStartIsSelected = YES;
                                            notSelected = 0;
                                        }
                                    }
                                    if (oStart != -1 && oStartIsSelected == YES && ![nlG isSelected])
                                        notSelected++; // too much not selected elements to remove ! no join
                                    else if (oStart != -1 && oStartIsSelected == NO && [nlG isSelected])
                                        selected++; // too much selected elements ! no join
                                    /* lg is selected and close to nextG(k) start OR to lgm1 end */
                                    if (oStart != -1 &&
                                        ((oStartIsSelected == YES && notSelected > 2 && backSelected < 3) ||
                                         (oStartIsSelected == YES && notSelected < 3) ||
                                         (oStartIsSelected == NO && selected < 3)) &&
                                        SqrDistPoints(oStartPt, nle) > TOLERANCE &&
                                        ((pointWithToleranceInArray(oStartPt, tol, possibleE, possCnt) &&
                                          pointWithToleranceInArray(nle, tol, possibleS, possCnt)) ||
                                         (pointWithToleranceInArray(oStartPt, tol, possibleS, possCnt) &&
                                          pointWithToleranceInArray(nle, tol, possibleE, possCnt))))
                                    {   BOOL	changeDirection = NO;
                                        int		at = j+1, q;

                                        from = to = -1;
                                        /* remove graphics - from current subPath - sp */
                                        if (pointWithToleranceInArray(oStartPt, tol, possibleE, possCnt))
                                        {
                                            for (q=0; q<possCnt; q++)
                                                if (SqrDistPoints(oStartPt, possibleE[q]) < sqrTolTen)
                                                {
                                                    to = possibleEi[q];
                                                    break;
                                                }
                                            for (q=0; q<possCnt; q++)
                                                if (SqrDistPoints(nle, possibleS[q]) < sqrTolTen)
                                                {
                                                    from = possibleSi[q];
                                                    at = from;
                                                    break;
                                                }
                                        }
                                        else
                                        {   for (q=0; q<possCnt; q++)
                                                if (SqrDistPoints(oStartPt, possibleS[q]) < sqrTolTen)
                                                {
                                                    from = possibleSi[q];
                                                    at = from;
                                                    break;
                                                }
                                            for (q=0; q<possCnt; q++)
                                                if (SqrDistPoints(nle, possibleE[q]) < sqrTolTen)
                                                {
                                                    to = possibleEi[q];
                                                    break;
                                                }
                                        }
                                        if (from == -1 || to == -1)
                                            break;
                                        for (m=to; m >= ((!to || to < from) ? 0:from); m--)
                                        {
                                            [[sp list] removeObjectAtIndex:m];
                                            spCnt--;
                                            /* we removed befor j -> j move one down in list !!! */
                                            if (m < from) { from--; to--; }
                                            if (m < j) j--;
                                            if (m < startJ) startJ--;
                                            if (m < at) at--;

                                            if (!m && to < from) // we step over 0 - second part until from !
                                            {   m = spCnt;
                                                to = from+1; // little hack mh - second part until from !
                                            }
                                        }
                                        /* sort graphics from oSp into sp */
                                        changeDirection = NO;
                                        if (pointWithToleranceInArray(nle, tol, possibleS, possCnt))
                                        {
                                            if (oStartIsSelected == YES)
                                            {
                                                from = (n+1 < oSpCnt) ? (n+1) : 0; // n if remove
                                                to = ((oStart-1) < 0) ? (oSpCnt-1):(oStart-1);
                                            }
                                            else
                                            {   from = oStart;
                                                to = n;
                                                changeDirection = YES;
                                            }
                                        }
                                        else
                                        {   if (oStartIsSelected == YES)
                                            {   from = (n+1 < oSpCnt) ? (n+1) : 0;
                                                to = ((oStart-1) < 0) ? (oSpCnt-1):(oStart-1);
                                                changeDirection = YES;
                                            }
                                            else
                                            {   to = n;
                                                from = oStart;
                                            }
                                        }
                                        /* insert other subPath (from oStart to -end- (n) || to - from) */
                                        /* at cur subPath j+1 */
                                         /* remove graphics in other subPath */
                                        if (!spCnt)
                                            at = 0;	
                                        for (m=to; m >= ((!to || to < from) ? 0:from); m--)
                                        {   VGraphic	*g = [[oSp list] objectAtIndex:m];

                                            if (changeDirection)
                                                [g changeDirection];
                                            [[sp list] insertObject:g atIndex:at];
                                            spCnt++;
                                            //if (notSelected > 2)
                                            {   [[oSp list] removeObjectAtIndex:m];
                                                oSpCnt--;
                                                if (m < from) { from--; to--; }
                                            }
                                            if (!m && to < from) // we step over 0 - second part until from !
                                            {   m = oSpCnt;
                                                to = from+1; // little hack mh - second part until from !
                                            }
                                        }
                                        /* check oSp if only selected inside !!! */
                                        //if (notSelected > 2)
                                        {   notSelected = 0;
                                            for (m=0; m<oSpCnt; m++)
                                            {
                                                if (![[[oSp list] objectAtIndex:m] isSelected])
                                                {   notSelected++;
                                                    if (notSelected > 2)
                                                        break; // we do not remove this subpath
                                                }
                                            }
                                        }
                                        /* remove other subPath graphics */
                                        /* and subPathSplitted[o] = NO */
                                        if (notSelected < 3)
                                        {   [[oSp list] removeAllObjects];
                                            subPathSplitted[o] = NO; // time
                                        }
                                        added = YES;
                                       // j = -1; // start new for removes at begin of sp with this oSp
                                        break;
                                    }
                                    if (n+1 >= oSpCnt && oStart != -1)
                                        n = -1;
                                }
                                if (added == YES)
                                    break; // o loop
                            }
                        }
                        break; // l loop
                    }
                    if (stop == YES || added == YES)
                        break; // k loop - look for next selectedG
                }
            }
        }
        /*move subPath at end of list perhaps two other paths must first join with each other
         * to get the right points
         */
        if (subPathSplitted[i] == YES)
        {
            for (j=0; j<spCnt; j++)
            {
                if ([[[sp list] objectAtIndex:j] isSelected])
                {   selected++;
                    if (selected > 1 && !valueInArray(i, addedAtEnd, addCnt))
                    {
                        [[path list] insertObject:sp atIndex:listCnt];
                        [[path list] removeObjectAtIndex:i];
                        subPathSplitted[listCnt] = subPathSplitted[i];
                        for (k=i; k<listCnt; k++)
                            subPathSplitted[k] = subPathSplitted[k+1];

                        for (k=0; k<addCnt; k++)
                            addedAtEnd[k]--; // index step one back !
                        addedAtEnd[addCnt++] = listCnt-1;
                        i--;
                        break;
                    }
                    else if (selected > 1)
                        break;
                }
            }
        }
    }

    /* search for overlaps inside subPath
     * and for loops
     */
    for (i=0, listCnt = [[path list] count]; i<listCnt; i++)
    {	VPath		*sp = [[path list] objectAtIndex:i];
        int		j, k, spCnt = [[sp list] count], startJ = spCnt;
        VGraphic	*startG=nil;

        if (!spCnt)
            continue;
        /* search for a not selected graphic */
        for (j=0; j<spCnt; j++)
        {   VGraphic	*curG = [[sp list] objectAtIndex:j];
            NSPoint	s, e;

            s = [curG pointWithNum:0];
            e = [curG pointWithNum:MAXINT];

            if (![curG isSelected] /*&& SqrDistPoints(s, e) > minL*/ )
            {   startJ = j;
                break;
            }
        }
        /* no one found -> remove subPath */
        if (startJ >= spCnt)
        {
            [[sp list] removeAllObjects];
            subPathSplitted[i] = NO; // time
            continue;
        }
        /* search for a selected graphic after a not selected graphic */
        startG = [[sp list] objectAtIndex:startJ];
        for (j=startJ; j<spCnt; j++)
        {   VGraphic	*curG = [[sp list] objectAtIndex:j];
            NSPoint	ce;

            if ([curG isSelected])
                continue;

            ce = [curG pointWithNum:MAXINT];

            for (k=((j+1 < spCnt)?(j+1):0); k<((j+1 < spCnt)?spCnt:startJ); k++)
            {   VGraphic	*nextG = [[sp list] objectAtIndex:k];
                NSPoint		ns, ne;
                float		distance = MAXCOORD;
                int		l, m, n;

                ns = [nextG pointWithNum:0];
                ne = [nextG pointWithNum:MAXINT];
                distance = SqrDistPoints(ce, ns);
                if (Diff(distance, 0.0) <= TOLERANCE && ![nextG isSelected])
                {
                    break; // nothing to do graphics laying correct
                }
                else if ([nextG isSelected])
                {   int		selectedGs = 0;
                    VGraphic	*cgp2, *cgp3;
                    NSPoint	cep3;

                    /* check distance around - one/two graphics behind selected graphic(s) */
                    cgp2 = [[sp list] objectAtIndex:(((k+1) < spCnt) ? (k+1):(0))];
                    cgp3 = [[sp list] objectAtIndex:(((k+2) < spCnt) ? (k+2) : ((k+2) - spCnt))];
                    cep3 = [cgp3 pointWithNum:MAXINT];

                    for (l=((k+1 < spCnt) ? (k+1):0); l < ((k+1 < spCnt) ? spCnt:k); l++)
                    {   VGraphic	*lg = [[sp list] objectAtIndex:l];
                        NSPoint		s, e;

                        s = [lg pointWithNum:0];
                        e = [lg pointWithNum:MAXINT];
                        /* lg is selected */
                        if ([lg isSelected])
                        {
                            selectedGs++;
                            if (l+1 >= spCnt)
                                l = -1; // so we go on at 0
                            if (l == k)
                                break; // one time around !!!
                            continue;
                        }
                        /* lg close to curG end !! - loop */
                        else if (Diff(SqrDistPoints(ce, s), 0.0) <= TOLERANCE)
                        {   int	from = k; // nextG
                            int	to = ((l-1) < 0)?(spCnt-1):(l-1); // l-1

                            /* remove objects from k-(l-1) */
                            for (m=to; m >= ((!to || to < from) ? 0:from); m--)
                            {
                                [[sp list] removeObjectAtIndex:m];
                                spCnt--;
                                if (m < from) { from--; to--; }
                                if (m < j) j--; // we removed befor j -> j and k and l move one down in list !!!
                                if (m < startJ) startJ--;

                                if (!m && to < from) // we step over 0 - second part until from !
                                {   m = spCnt;
                                    to = from+1; // little hack mh - second part until from !
                                }
                            }
                            break;
                        }
                        /* search for overlaps
                         * and loops which are need more tolerance to find
                         */
                        else
                        {   VGraphic	*lgm1, *lgm2;
                            NSPoint	em1;
                            int		from = -1, to = -1;
                            int		km2 = ((k-2) < 0) ? (spCnt+(k-2)) : (k-2);
                            int		kp3 = ((k+3) < spCnt) ? (k+3) : ((k+3) - spCnt);
                            BOOL	removeLoop = NO;

                            /* check distance around - one/two graphic above end of selected graphic(s) */
                            lgm1 = [[sp list] objectAtIndex:(((l-1) < 0) ? (spCnt-1):(l-1))];
                            em1 = [lgm1 pointWithNum:MAXINT];
                            lgm2 = [[sp list] objectAtIndex:(((l-2) < 0) ? (spCnt+(l-2)):(l-2))];

                            {   int	sStart = -1, notSelected=0, from = -1, to = -1;
                                int	possCnt = 3, possibleSi[3], possibleEi[3];
                                BOOL	removed = NO;
                                NSPoint	possibleS[3], possibleE[3], sStartPt = {0.0, 0.0};
                                NSPoint	nsp1 = [cgp2 pointWithNum:0], em2 = [lgm2 pointWithNum:MAXINT];
                                NSPoint	nsm1 = [curG pointWithNum:0];
                                float	sqrTolTen = (10.0*TOLERANCE)*(10.0*TOLERANCE);

                                possibleS[0] = ns; possibleSi[0] = k; // nextG start
                                possibleS[1] = nsp1; possibleSi[1] = ((k+1) < spCnt) ? (k+1) : (0); // nextG+1 start
                                possibleS[2] = nsm1; possibleSi[2] = ((k-1) < 0)?(spCnt-1):(k-1); // nextG-1 start

                                possibleE[0] = em1; possibleEi[0] = ((l-1) < 0)?(spCnt-1):(l-1); // lgm1 end
                                possibleE[1] = em2; // lgm2 end
                                possibleEi[1] = ((l-2) < 0) ? (((l-2) == -1) ? (spCnt-1):(spCnt-2)) : (l-2);
                                possibleE[2] = e; possibleEi[2] = l; // lg end

                                /* search for other graphics which hit possibleE/S */
                                for (n=((l+1 < spCnt) ? (l+1):0); n < ((l+1 < spCnt) ? spCnt:k); n++)
                                {   VGraphic	*nlG = [[sp list] objectAtIndex:n];
                                    NSPoint	nls, nle;

                                    if (n == k)
                                        break; // one round finished
                                    nls = [nlG pointWithNum:0];
                                    nle = [nlG pointWithNum:MAXINT];
                                    /* nlg is selected and hit a point from possibleE array */
                                    if ((sStart == -1 || notSelected > 2) && [nlG isSelected] &&
                                        (Diff(j, n) > 2 && Diff(Diff(j, n), spCnt) > 2) &&
                                        (Diff(l, n) > 2 && Diff(Diff(l, n), spCnt) > 2) &&
                                        pointWithToleranceInArray(nls, tol, possibleE, possCnt) )
                                    {
                                        sStart = n; sStartPt = nls;
                                        notSelected = 0; // second try perhaps
                                    }
                                    if (sStart != -1 && ![nlG isSelected])
                                        notSelected++; // too much not selected elements to remove !
                                    /* nlg is hit a point from possibleS array */
                                    if (sStart != -1 /*&& notSelected < 3*/ &&
                                        (Diff(j, n) > 2 && Diff(Diff(j, n), spCnt) > 2) &&
                                        (Diff(l, n) > 2 && Diff(Diff(l, n), spCnt) > 2) &&
                                        Diff(SqrDistPoints(sStartPt, nle), 0.0) > TOLERANCE &&
                                        pointWithToleranceInArray(nle, tol, possibleS, possCnt) )
                                    {   VPath 	*subP = nil;
                                        int	q, sEnd1 = -1;

                                        removed = YES;
                                        for (q=0; q<possCnt; q++)
                                            if (SqrDistPoints(sStartPt, possibleE[q]) < sqrTolTen)
                                            {   to = possibleEi[q];
                                                sEnd1 = ((possibleEi[q]+1) < spCnt) ? (possibleEi[q]+1) : (0);
                                                break;
                                            }
                                        for (q=0; q<possCnt; q++)
                                            if (SqrDistPoints(nle, possibleS[q]) < sqrTolTen)
                                            {   from = possibleSi[q];
                                                break;
                                            }
                                        if (from == -1 || to == -1)
                                            break;
                                        /* remove first part of selected graphics */
                                        for (m=to; m >= ((!to || to < from) ? 0:from); m--)
                                        {
                                            [[sp list] removeObjectAtIndex:m];
                                            spCnt--;
                                            /* we removed befor j -> j move one down in list !!! */
                                            if (m < from) { from--; to--; }
                                            if (m < j) j--;
                                            if (m < startJ) startJ--;
                                            if (m < n) n--;
                                            if (m < sStart) sStart--;
                                            if (m < sEnd1) sEnd1--;

                                            if (!m && to < from) // we step over 0 - second part until from !
                                            {   m = spCnt;
                                                to = from+1; // little hack mh - second part until from !
                                            }
                                        }
                                        /* than we build a new subPath and add other graphics to this
                                         * so we can remove the rest of selected graphics later in i loop
                                         */
                                        if (notSelected >= 3)
                                        {   subP = [VPath path];
                                            [subP setColor:[sp color]];
                                            [subP setWidth:[sp width]];
                                            [subP setFilled:[sp filled]];
                                        }
                                        from = sStart; // first second selected Graphic
                                        to = n;
                                        for (m=to; m >= ((!to || to < from) ? 0:from) && spCnt > m; m--)
                                        {   VGraphic	*g = [[sp list] objectAtIndex:m];

                                            if (notSelected >= 3)
                                                [[subP list] insertObject:g atIndex:0]; // backwart !
                                            [[sp list] removeObjectAtIndex:m];
                                            spCnt--;
                                            if (m < from) { from--; to--; }
                                            if (m < j) j--;
                                            if (m < startJ) startJ--;
                                            if (m < sStart) sStart--;
                                            if (m < sEnd1) sEnd1--;

                                            if (!m && to < from) // we step over 0 - second part until from !
                                            {   m = spCnt;
                                                to = from+1; // little hack mh - second part until from !
                                            }
                                        }
                                        if (notSelected >= 3)
                                        {   [[path list] addObject:subP];
                                            subPathSplitted[listCnt] = YES;
                                            listCnt++;
                                        }
                                        /* sort graphics behind/after overlap (overlap allways create two supPaths)
                                         * in a new subPath */
                                        subP = [VPath path];
                                        [subP setColor:[sp color]];
                                        [subP setWidth:[sp width]];
                                        [subP setFilled:[sp filled]];
                                        from = sEnd1;
                                        to = ((sStart-1) < 0) ? (spCnt-1):(sStart-1); // bevor second selection
                                        for (m=to; m >= ((!to || to < from) ? 0:from) && spCnt > m; m--)
                                        {   VGraphic	*g = [[sp list] objectAtIndex:m];

                                            [[subP list] insertObject:g atIndex:0]; // backwart !
                                            [[sp list] removeObjectAtIndex:m]; // remove from cur sp
                                            spCnt--;
                                            if (m < from) { from--; to--; }
                                            if (m < j) j--;
                                            if (m < startJ) startJ--;
                                            if (!m && to < from) // we step over 0 - second part until from !
                                            {   m = spCnt;
                                                to = from+1; // little hack mh - second part until from !
                                            }
                                        }
                                        [[path list] addObject:subP];
                                        subPathSplitted[listCnt] = YES;
                                        listCnt++;
                                        j--; // check from curG new !!
                                        break;
                                    }
                                    if (n+1 >= spCnt)
                                        n = -1; // so we go on at 0
                                }
                                if (removed)
                                    break;
                            }

                            /* now (no overlap) we search for a loop
                             * which start/end points not exactly at notSelected/selected frontiers
                             */
                            /*if (spCnt < selectedGs+8) // correct km2
                            {
                                if (spCnt < selectedGs+3)
                                    km2 = k; // none back
                                else if (spCnt < selectedGs+5)
                                    km2 = j; // one back
                                else //  < ..+7
                                    km2 = ((k-2) < 0) ? (spCnt+(k-2)) : (k-2); // two back
                            }*/

                            if (selectedGs < 4) // correct kp3
                            {
                                if (selectedGs < 1)
                                    kp3 = k; // none forward
                                else if (selectedGs < 2)
                                    kp3 = ((k+1) < spCnt) ? (k+1) : ((k+1) - spCnt); // one forward
                                else // if (selectedGs <= 4)
                                    kp3 = ((k+2) < spCnt) ? (k+2) : ((k+2) - spCnt); // two forward
                            }

                            for (n=kp3; n >= ((kp3 < km2) ? 0 : km2); n--)
                            {   VGraphic	*gn = [[sp list] objectAtIndex:n]; // --
                                NSPoint		gns = [gn pointWithNum:0];
                                int		o, lp1 = ((l+1) < spCnt) ? (l+1) : ((l+1) - spCnt);
//                                int		lm3 = (((l-3) < 0) ? (spCnt+(l-3)) : (l-3));
                                int		lm3 = ((n+1) < spCnt) ? (n+1) : ((n+1) - spCnt);

                                if (selectedGs < 4) // correct lm3
                                {
                                    if (selectedGs < 1)
                                        lm3 = l; // none backward
                                    else if (selectedGs < 2)
                                        lm3 = (((l-1) < 0) ? (spCnt+(l-1)) : (l-1)); // one backward
                                    else // if (selectedGs <= 4)
                                        lm3 = (((l-2) < 0) ? (spCnt+(l-2)) : (l-2)); // two backward
                                }

                                if (n == (((j-1) < 0)?(spCnt-1):(j-1)) ||
                                    n == (((j-2) < 0) ? (spCnt+(j-2)) : (j-2)))
                                    lm3 = k; // else perhaps we remove only bevor j !!

                                /*if (spCnt < selectedGs+8) // correct km2 / lp1
                                {
                                    if (spCnt < selectedGs+3)
                                        lp1 = ((l-1) < 0) ? (spCnt+(l-1)) : (l-1); // none forward
                                    else if (spCnt < selectedGs+5)
                                        lp1 = l; // one forward
                                    else //  < ..+7
                                        lp1 = ((l+1) < spCnt) ? (l+1) : ((l+1) - spCnt); // two forward
                                }*/

                                for (o=lm3; o <= ((lm3 <= lp1) ? lp1 : spCnt-1); o++)
                                {   VGraphic	*go = [[sp list] objectAtIndex:(o = (o < spCnt) ? o : 0)]; // ++
                                    NSPoint	goe = [go pointWithNum:MAXINT];

                                    /* mal braucht man >= 1 und mal > 1 ? o > n sonst wird alles removed ! */
                                    if (((Diff(n, o) > 1 || (Diff(n, o) == 1 && o > n)) &&
                                         Diff(Diff(n, o), spCnt) > 1)
                                        && SqrDistPoints(gns, goe) < (15.0*TOLERANCE)*(15.0*TOLERANCE))
                                    {
                                        if ( Diff(n, o) == 1 )
                                            NSLog(@"VPath.m: Diff(n, o) == 1, look here if calculation fault\n");
                                        from = n;
                                        to = o;
                                        /* remove objects from k-(l-1) */
                                        for (m=to; m >= ((!to || to < from) ? 0:from); m--)
                                        {
                                            [[sp list] removeObjectAtIndex:m];
                                            spCnt--;
                                            if (m < from) { from--; to--; }
                                            if (m < j) j--;
                                            if (m < startJ) startJ--;

                                            if (!m && to < from) // we step over 0 - second part until from !
                                            {   m = spCnt;
                                                to = from+1; // little hack mh - second part until from !
                                            }
                                        }
                                        removeLoop = YES;
                                        break;
                                    }
                                    if (o == spCnt-1 && lm3 > lp1) // ++
                                    {   o = -1;
                                        lm3 = lp1-1; // hack to stop at lp1 - after spCnt
                                    }
                                }
                                if (removeLoop)
                                    break;
                                if (!n && kp3 < km2) // --
                                {   n = spCnt;
                                    kp3 = km2+1; // hack to go on after 0 at kp3
                                }
                            }
                            break;
                        }
                    }
                    break;
                }
                else if (Diff(distance, 0.0) > TOLERANCE)
                {
                    if ( !openPath )
                    {   noticeK = k;
                        noticeJ = j;
                        openPath = YES;
                    }
                    continue;
                }
            }
        }
    }
    if (openPath)
        NSLog(@"VPath.m - optimizeSubPathsToClosedPath j:%d k:%d", noticeJ, noticeK);
    openPath = NO;

    /* check if closed and close little gaps */
    for (i=0; i<listCnt; i++)
    {	VPath	*sp = [[path list] objectAtIndex:i];
        int	j, spCnt = [[sp list] count];

        /* check end to next start */
        for (j=0; j<spCnt; j++)
        {   VGraphic	*curG = nil, *nextG = nil;
            NSPoint	e, ns;
            float	dist;

            if (j == spCnt-1) // last object !!!!!!!
            {   curG = [[sp list] objectAtIndex:j];
                nextG = [[sp list] objectAtIndex:0]; // startG
            }
            else
            {   curG = [[sp list] objectAtIndex:j];
                nextG = [[sp list] objectAtIndex:j+1];
            }
            //s = [curG pointWithNum:0];
            e = [curG pointWithNum:MAXINT];
            ns = [nextG pointWithNum:0];
            dist = SqrDistPoints(e, ns);

            if (dist > TOLERANCE*TOLERANCE && dist < 5.0*TOLERANCE)
            {
                if (![nextG isKindOfClass:[VArc class]])
                {
                    [nextG movePoint:0 to:e];
                }
                else if (![curG isKindOfClass:[VArc class]])
                {
                    [curG movePoint:MAXINT to:ns];
                }
                else
                {   id	g = [VLine lineWithPoints:e :ns];

                    [[sp list] insertObject:g atIndex:j+1];
                    spCnt++;
                }
            }
            else if (dist > TOLERANCE*TOLERANCE && dist < 50*TOLERANCE)
            {   id	g = [VLine lineWithPoints:e :ns];

                [[sp list] insertObject:g atIndex:j+1];
                spCnt++;
            }
            /* 1 -> dublicate to close path ! */
            else if (dist > TOLERANCE*TOLERANCE && j == spCnt-1 && spCnt == 1) // only one Object -> no 360 arc
            {   VGraphic	*gr = [curG copy];

                [gr changeDirection];
                [[sp list] addObject:gr];
                spCnt++;
            }
            else if (dist > TOLERANCE*TOLERANCE && !openPath)
            {
                openPath = YES;
                noticeJ = j;
                noticeK = i;
            }
        }
    }
    if ( openPath )
        NSLog(@"VPath - optimizeSubPathsToClosedPath -- i: %d j: %d", noticeK, noticeJ);
}

/* here we split graphics which intersect each other
 * inside subPaths itself
 * and subPath to subPaths
 * AND we set graphics which start/middle/end point is laying too near to hold the distance of tool width
 */
- (void)removeFaultGraphicsInSubpaths:(VPath*)path :(float)w
{   int		i, listCnt, subPathSplitted[[[path list] count]+Min(10, [[path list] count])];
    float	r;

    /* we need more subPathSplitted[] for possible additions in - optimizeSubPathsToClosedPath */

    r = Abs((width + w) / 2.0);	// the amount of growth
    // r -= Min(0.05, r/50.0); // 0.05 60.0 - 0.1 35.0 - 0.1 25.0
    r -= 0.0094; // 0.0075 0.0055 // Min(0.0055, r/100.0); // 0.01 r/100.0 - 0.005 is ArcArc tangentintersection !!
//r -= 0.005;

    /* split each sub path itself
     */
    for ( i=0, listCnt = [[path list] count]; i<listCnt; i++ )
    {	VPath	*sp = [[path list] objectAtIndex:i];
        int	j, k, l, interCnt, spCnt = [[sp list] count];

        /* intersect and tile elements of subpath
         */
        for ( j=0; j<spCnt; j++ )
        {   VGraphic	*gJ = [[sp list] objectAtIndex:j];
            NSRect	jBounds = [gJ coordBounds];
            BOOL	splitted = NO;

            for ( k=j+1; k<spCnt; k++ )
            {   VGraphic	*gK = [[sp list] objectAtIndex:k];
                NSPoint		*interPts;
                NSRect		kBounds = [gJ coordBounds];

                if (j == k || /*((j+1 < spCnt) ? (j+1) : (0)) == k || (((j-1) < 0) ? (spCnt-1):(j-1)) == k ||*/
                    !vhfIntersectsRect(jBounds, kBounds))
                    continue;

                /* intersect graphics */
                if ( (interCnt = [gJ getIntersections:&interPts with:gK]) )
                {   NSMutableArray	*splitListJ=nil, *splitListK=nil;

                    /* tile graphics */
                    splitListJ = [gJ getListOfObjectsSplittedFrom:interPts :interCnt];
                    splitListK = [gK getListOfObjectsSplittedFrom:interPts :interCnt];

                    /* insert tiled graphics */
                    if ( [splitListJ count] > 1 )
                    {
                        splitted = YES;
                        for (l=[splitListJ count]-1; l>=0; l--)
                        {   VGraphic	*g = [splitListJ objectAtIndex:l];

                            [[sp list] insertObject:g atIndex:j+1];
                            spCnt++;
                            if (k > j)
                                k++;
                        }
                        [[sp list] removeObjectAtIndex:j];
                        spCnt--;
                        if (k > j)
                            k--;
                        j--;
                    }
                    if ( [splitListK count] > 1 )
                    {
//                        splitted = YES; // gJ perhaps not splitted - but later !!!
                        for (l=[splitListK count]-1; l>=0; l--)
                        {   VGraphic	*g = [splitListK objectAtIndex:l];

                            [[sp list] insertObject:g atIndex:k+1];
                            spCnt++;
                            //if (j > k) // not possible if k = j+1
                            //    j++;
                        }
                        [[sp list] removeObjectAtIndex:k];
                        spCnt--;
                        //if (j > k)
                        //    j--;
                    }
                    free(interPts);
                    if (splitted)
                        break;
                }
            }
        }

    }

    /* split subpaths from each other !!!
     */
    listCnt = [[path list] count];
    for ( i=0; i<listCnt; i++ )
        subPathSplitted[i] = NO; // initialize !

    for ( i=0; i<listCnt; i++ )
    {	VPath	*sp = [[path list] objectAtIndex:i];
        int	j, c, o, l, spCnt = [[sp list] count], splittedPath = NO, oSpCnt=0;

        for ( j=i+1; j<listCnt; j++ )
        {   VPath	*oSp;
            BOOL	oSplittedPath = NO;

            if ( j==i )
                continue;	/* not the same path ! */

            oSp = [[path list] objectAtIndex:j];	/* other subpath */
            oSpCnt = [[oSp list] count];

            /* intersect and tile elements of subpath -> with otherPaths */
            for ( c=0; c<spCnt; c++ )
            {   VGraphic	*gC = [[sp list] objectAtIndex:c];
                NSRect		cBounds = [gC coordBounds];

                for ( o=0; o<oSpCnt; o++ )
                {   VGraphic	*gO = [[oSp list] objectAtIndex:o];
                    NSPoint	*interPts;
                    NSRect	oBounds = [gO coordBounds];
                    int		interCnt;
                    BOOL	splitted = NO;

                    if (!vhfIntersectsRect(cBounds, oBounds))
                        continue;

                    /* intersect graphics */
                    if ( (interCnt = [gC getIntersections:&interPts with:gO]) )
                    {   NSMutableArray	*splitListC=nil, *splitListO=nil;

                        /* tile graphics */
                        splitListC = [gC getListOfObjectsSplittedFrom:interPts :interCnt];
                        splitListO = [gO getListOfObjectsSplittedFrom:interPts :interCnt];

                        /* insert tiled graphics */
                        if ( [splitListC count] > 1 )
                        {
                            splitted = YES;
                            splittedPath = YES;
                            for (l=[splitListC count]-1; l>=0; l--)
                            {   VGraphic	*g = [splitListC objectAtIndex:l];

                                [[sp list] insertObject:g atIndex:c+1];
                                spCnt++;
                            }
                            [[sp list] removeObjectAtIndex:c];
                            spCnt--;
                            gC = [[sp list] objectAtIndex:c];
                            cBounds = [gC coordBounds];
                        }
                        if ( [splitListO count] > 1 )
                        {
                            splitted = YES;
                            oSplittedPath = YES;
                            for (l=[splitListO count]-1; l>=0; l--)
                            {   VGraphic	*g = [splitListO objectAtIndex:l];

                                [[oSp list] insertObject:g atIndex:o+1];
                                oSpCnt++;
                            }
                            [[oSp list] removeObjectAtIndex:o];
                            oSpCnt--;
                        }
                        free(interPts);
                        if (splitted)
                            o = -1; // start at 0 ! for new current c graphics
                    }
                }
            }
            if (oSplittedPath && subPathSplitted[j] == NO)
                subPathSplitted[j] = YES; // perhaps allready set and not splitted any more ! ?
        }
        if (splittedPath && subPathSplitted[i] == NO) // perhaps allready set and not splitted any more ! ?
            subPathSplitted[i] = YES;
    }

    /* set objects selected - which distance is too small to original path (self) */
    for ( i=0, listCnt = [[path list] count]; i<listCnt; i++ )
    {	VPath	*sp = [[path list] objectAtIndex:i];
        int	j, spCnt = [[sp list] count];

        spCnt = [[sp list] count];
        for ( j=spCnt-1; j>=0; j-- )
        {   VGraphic	*g = [[sp list] objectAtIndex:j];
            NSPoint	s, e, m, sa;
            VArc	*arc1 = [VArc arc], *arc2 = [VArc arc], *arc3 = [VArc arc];

/*            if ([g isSelected])
{
//                [[sp list] removeObjectAtIndex:j]; // debugging purpose only
                continue;
}*/
            [g getPoint:&m at:0.4];
            s = [g pointWithNum:0];
            e = [g pointWithNum:MAXINT];
            sa = s; sa.x += r;
            [arc1 setCenter:s start:sa angle:360.0];
            sa = e; sa.x += r;
            [arc2 setCenter:e start:sa angle:360.0];
            sa = m; sa.x += r;
            [arc3 setCenter:m start:sa angle:360.0];

            /* graphic nearer than r to original path (self) */
            if ( /*SqrDistPoints(s, e) < 0.001 ||*/
                 ![arc1 tangentIntersectionWithPath:self] || ![arc2 tangentIntersectionWithPath:self] ||
                 ![arc3 tangentIntersectionWithPath:self] || (w < 0 && !width && ![self isPointInside:m]) ||
                 (w > 0 && [self isPointInside:m]) )
            {
//                [[sp list] removeObjectAtIndex:j]; // debugging purpose only
                [g setSelected:YES];
            }
            else
                [g setSelected:NO];
        }
    }

    /* optimize to close path */
    [self optimizeSubPathsToClosedPath:path :w :subPathSplitted];
}

/* return a path representing the outline of us
 * the path holds two lines and two arcs
 * if we need not build a contour a copy of self is returned
 */
#define AngleNotSmallEnough(dir, w, angle) ((dir && w >= 0 && angle > 150.0) || (dir  && w <  0 && angle < 210.0) || \
                                           (!dir && w <  0 && angle > 150.0) || (!dir && w >= 0 && angle < 210.0))
#define NeedArc(dir, w, angle)	((dir && w >= 0 && angle > 180.5) || (dir  && w <  0 && angle < 179.5) || \
                                (!dir && w <  0 && angle > 180.5) || (!dir && w >= 0 && angle < 179.5))
/*#define SmallAngle(dir, w, angle )	((dir && w > 0 && angle < 89.5) || (dir && w < 0 && angle > 270.5) || \
    (!dir && w < 0 && angle < 89.5) || (!dir && w > 0 && angle > 270.5))*/
/*#define SmallAngle(dir, w, angle )	((dir && w > 0 && angle < 85.5) || (dir && w < 0 && angle > 275.5) || \
    (!dir && w < 0 && angle < 85.5) || (!dir && w > 0 && angle > 275.5))*/
#define SmallAngle(dir, w, angle )	((dir && w >= 0 && angle < 95.5) || (dir  && w <  0 && angle > 265.5) || \
                                    (!dir && w <  0 && angle < 95.5) || (!dir && w >= 0 && angle > 265.5))
/*#define SmallAngle(dir, w, angle )	((dir && w > 0 && angle < 120.0) || (dir && w < 0 && angle > 240.0) || \
    (!dir && w < 0 && angle < 120.0) || (!dir && w > 0 && angle > 240.0))*/
/* created:  1997-07-07
 * modified: 1997-07-07
 * get gradient
 * if a curve has several vertices in one point (gradient = 0, 0) we take the next vertice to get the gradient
 */
//#define GradientNear(g, t) ([g isKindOfClass:[VCurve class]]) ? [g gradientNear:t] : [g gradientAt:t]

static NSPoint orthPointAtBegOrEnd(id g, float r, int dirInd, BOOL end)
{   float	b;
    NSPoint	p, grad, orthP;

    if ( !end )	/* calc to beg */
    {
        p = [g pointWithNum:0];             /* start point of object */
        grad = GradientNear(g, 0.0);		/* gradient of start-point for outline object */
    }
    else
    {   p = [g pointWithNum:MAXINT];		/* end point of object */
        grad = GradientNear(g, 1.0);		/* gradient of start-point for outline object */
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
    {
        p = [g1 pointWithNum:0];			/* start point of object */
        gradB = GradientNear(g1, 0.0);			/* gradient of start-point object */
        gradA = GradientNear(g2, 1.0);			/* gradient of end-point for object */
    }
    else
    {   p = [g1 pointWithNum:MAXINT];			/* end point of object */
        gradA = GradientNear(g1, 1.0);			/* gradient of start-point for outline object */
        gradB = GradientNear(g2, 0.0);			/* gradient of end-point for prev object */
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
    {
        p = [g1 pointWithNum:0];
        gradB = GradientNear(g1, 0.0);			/* gradient of start-point for outline object */
        gradA = GradientNear(g2, 1.0);			/* gradient of end-point for prev object */
    }
    else
    {   p = [g1 pointWithNum:MAXINT];
        gradA = GradientNear(g1, 1.0);			/* gradient of start-point for outline object */
        gradB = GradientNear(g2, 0.0);			/* gradient of end-point for prev object */
    }
    a = sqrt(gradA.x*gradA.x+gradA.y*gradA.y);
    b = sqrt(gradB.x*gradB.x+gradB.y*gradB.y);	/* our gradient is orthogonal to the average of both gradients */
    pG.x = gradA.y/a + gradB.y/b;
    pG.y = -(gradA.x/a + gradB.x/b);
    if ( !pG.x && !pG.y )
    {	pG.x = - gradA.y/a;
        pG.y = + gradA.x/a;
    }
    c = sqrt(pG.x*pG.x+pG.y*pG.y);	// end point for outline object
    ( angle < 360.0-angle ) ? (na = angle/2.0) : (na = (360.0-angle)/2.0);
    nr = r / Sin(na);			// need correct distance
    newP.x = p.x + pG.x*nr*dirInd/c;
    newP.y = p.y + pG.y*nr*dirInd/c;
    return newP;
}

- (id)contour:(float)w useRaster:(BOOL)useRaster
{
    if ( [self filled] )
        return (useRaster) ? [self contourWithPixel:w]
                           : [self contour:w inlay:NO splitCurves:YES];
    else
        return [self contourOpen:w];
}
- (id)contour:(float)w
{
    if ( [self filled] )
        return [self contour:w inlay:NO splitCurves:YES];
    else
        return [self contourOpen:w];
}
- (id)contour:(float)w inlay:(BOOL)inlay splitCurves:(BOOL)splitCurves useRaster:(BOOL)useRaster
{
    return (useRaster) ? [self contourWithPixel:w]
                       : [self contour:w inlay:inlay splitCurves:splitCurves];
}
- (id)contour:(float)w inlay:(BOOL)inlay splitCurves:(BOOL)splitCurves
{   VPath	*path, *subPath = nil, *pathCopy = nil;
    //VLine   *line = [VLine new], *linePrev = [VLine new], *lineNext = [VLine new]; // to replace Curve if necessarie
    VLine   *line = nil, *linePrev = nil, *lineNext = nil; // to replace Curve if necessarie
    int		i, listCnt = [list count], begIx=0, endIx=0, dir=0;
    int		direction, inside, directionArray[listCnt], insideArray[listCnt], dirInsideCnt=0;
    float	r, dirInd=1.0, bAngle, eAngle;
    int		cnt=0;
    NSAutoreleasePool   *pool;

    /* we just return a copy */
    if ( (!filled && Abs(w)>width) || (Diff(w, 0.0) < 0.0001 && Diff(width, 0.0) < 0.0001)
         || (w<0.0 && Abs(w) == width) )
        return [[self copy] autorelease];

    //if ( Prefs_UseRaster )  // FIXME: use version with useRaster flag in parameter!
    //    return [self contourWithPixel:w];

    pathCopy = [[self copy] autorelease];
    if (inlay)
    {   VPath	*oPath;

        /* gegenrichtung contour mit w bilden */
        oPath = [pathCopy contour:-w inlay:NO splitCurves:YES]; // self
        [oPath setFilled:YES optimize:NO];
        path = [oPath contour:2.0*w inlay:NO splitCurves:NO];
        return path;
    }

    r = (w + width) / 2.0;	// the amount of growth

    path = [VPath path];
    [path setColor:color];
    [path setDirectionCCW:isDirectionCCW];

    pool = [NSAutoreleasePool new];
    line = [VLine line]; linePrev = [VLine line]; lineNext = [VLine line];

    /* remove Elements with no length
     * the problem is that we destroy our closed path!
     */
    for ( i=0, listCnt = [[pathCopy list] count]; i<listCnt; i++ )
    {	VGraphic	*gThis = [[pathCopy list] objectAtIndex:i];

        if ( [gThis length] < 15.0*TOLERANCE )
        {
            [[pathCopy list] removeObject:gThis];
            i--;
            //[self closePath];
            listCnt = [[pathCopy list] count];
            continue;
        }
    }

    /* what we do here:
     * step through elements of path
     * calculate start, end points for outline-elements in a distance to path (inside/outside)
     * calculate parallel elements through start and end points
     * we have to calculate each sub path separately, so we put them in real sub paths
     */

    /* walk through path list
     */
    for ( i=0, listCnt = [[pathCopy list] count]; i<listCnt; i++ )
    {	VGraphic        *g,
                        *gThis, *gPrev, *gNext; /* this object, previous object, next object */
        NSPoint         begO = NSZeroPoint, endO = NSZeroPoint, /* start and endpoint of contour-object, if we dont add an arc (O = outline) */
                        begOrth, endOrth,       /* start and endpoint of contour-object, if we add an arc (orthogonal points) */
                        center;                 /* center point of arc if needed */
        int             sc, needArc = 0;        /* wether we need an arc to build correct contour around current edge */
        NSMutableArray  *splittedCurves = nil;

        gThis = [[pathCopy list] objectAtIndex:i];	// this object

        if ( [gThis isKindOfClass:[VCurve class]] )
        {   NSPoint p0, p1, p2, p3;

            [(VCurve*)gThis getVertices:&p0 :&p1 :&p2 :&p3];
            /* both Curve points are in its Start/End points - we build a line */
            if ( SqrDistPoints(p0, p1) < 10*TOLERANCE && SqrDistPoints(p2, p3) < 10*TOLERANCE )
            {
                [line setVertices:p0 :p3];
                gThis = line;
            }
        }

        /* new sub path
         */
        if ( !i || i>endIx )		// new sub path
        {   subPath = [VPath path];
            [[path list] addObject:subPath];
            begIx = i;
            //endIx = [self getLastObjectOfSubPath:begIx];
            endIx = [pathCopy getLastObjectOfSubPath:begIx]; //  tolerance:TOLERANCE

            cnt = 0;	// counter for cutIndex array

            /* only one element in subpath, so this must be an arc */
            if ( begIx == endIx )
            {	VGraphic    *arc;
                int         oldFillStyle=[gThis filled];

                if ( !([gThis isKindOfClass:[VArc class]] && Abs([(VArc*)gThis angle]) == 360.0) &&
                     ![gThis isKindOfClass:[VRectangle class]] &&
                     ![gThis isKindOfClass:[VPolyLine class]] )	// nothing
                {   insideArray[dirInsideCnt] = 0;
                    directionArray[dirInsideCnt++] = 0; /* doesnt matter */
                    continue;
                }
                [gThis setFilled:YES];
                if ( [pathCopy subPathInsidePath:begIx :endIx] )
                {
                    if ( [gThis width] ) // special
                    {   VArc	*gTh = [gThis copy];

                        [gTh setWidth:0.0];
                        [gTh setRadius:[gThis radius]-([gThis width]/2.0)];
                        arc = [gTh contour:-w];
                    }
                    else
                        arc = [gThis contour:-w];
                    insideArray[dirInsideCnt] = 1;
                }
                else
                {   arc = [gThis contour:w];
                    insideArray[dirInsideCnt] = 0;
                }
                directionArray[dirInsideCnt++] = 0; /* doesnt matter if only one object */
                //arc = ( [self subPathInsidePath:begIx :endIx] ) ? ([gThis contour:-w]) : ([gThis contour:w]);
                if ([arc isKindOfClass:[VPath class]])
                {   int	j, spCnt = [[(VPath*)arc list] count];

                    for (j=0; j<spCnt; j++)
                        [[subPath list] addObject:[[(VPath*)arc list] objectAtIndex:j]];
                }
                else if (arc)
                    [[subPath list] addObject:arc];
                [gThis setFilled:oldFillStyle];
                continue;
            }
            /* determine direction indicator inside(1), outside(-1) */
            direction = [pathCopy directionOfSubPath:begIx :endIx];	// 1 = ccw, 0 = cw
            if ( (inside = [pathCopy subPathInsidePath:begIx :endIx]) )
            	dir = ( direction ) ? 0 : 1;
            else
                dir = direction;
            dirInd  = ( dir ) ? 1.0 : -1.0;			// 1 = ccw, 0 = cw

            directionArray[dirInsideCnt] = direction;
            insideArray[dirInsideCnt++] = inside;
        }

        /* split curves for better results */
        if ( splitCurves && [(VGraphic*)gThis length] > 1000.0*TOLERANCE && [gThis isKindOfClass:[VCurve class]] )
        {   NSArray	*splittedCurves1 = nil, *splittedCurves2 = nil;
            NSArray	*splittedCurves3 = nil, *splittedCurves4 = nil;

            splittedCurves = [NSMutableArray arrayWithCapacity:5];
            splittedCurves1 = [(VCurve*)gThis splittedObjectsAt:0.333]; // 0.333 0.3

            splittedCurves2 = [[splittedCurves1 objectAtIndex:0] splittedObjectsAt:0.4]; // 0.2 0.4
            [splittedCurves addObject:[splittedCurves2 objectAtIndex:0]];
            [splittedCurves addObject:[splittedCurves2 objectAtIndex:1]];

            splittedCurves3 = [[splittedCurves1 objectAtIndex:1] splittedObjectsAt:0.5]; // 0.5 4/7
            [splittedCurves addObject:[splittedCurves3 objectAtIndex:0]];

            splittedCurves4 = [[splittedCurves3 objectAtIndex:1] splittedObjectsAt:0.6]; // 0.8 0.6
            [splittedCurves addObject:[splittedCurves4 objectAtIndex:0]];
            [splittedCurves addObject:[splittedCurves4 objectAtIndex:1]];
        }
        for ( sc=0; sc < ((splittedCurves) ? 5 : 1); sc++ )
        {   BOOL	/*calcBegOWithCut = 0, */calcEndOWithCut = 0;

            if ( splittedCurves )
                gThis = [splittedCurves objectAtIndex:sc];

            if ( sc >= 1 && sc <= 4 )   // 2012-01-19
                gPrev = [splittedCurves objectAtIndex:sc-1];
            else
            {
                gPrev = (i>begIx) ? [[pathCopy list] objectAtIndex:i-1] : [[pathCopy list] objectAtIndex:endIx];

                if ( [gPrev isKindOfClass:[VCurve class]] )
                {   NSPoint p0, p1, p2, p3;

                    [(VCurve*)gPrev getVertices:&p0 :&p1 :&p2 :&p3];
                    /* both Curve points are in its Start/End points - we build a line */
                    if ( SqrDistPoints(p0, p1) < 10*TOLERANCE && SqrDistPoints(p2, p3) < 10*TOLERANCE )
                    {
                        [linePrev setVertices:p0 :p3];
                        gPrev = linePrev;
                    }
                }
                if ( splitCurves && [(VGraphic*)gPrev length] > 1000.0*TOLERANCE &&
                     [gPrev isKindOfClass:[VCurve class]] )
                {   NSArray	*splittedCurvePrev = nil, *splittedC = nil;

                    splittedC = [(VCurve*)gPrev splittedObjectsAt:0.666]; // 0.666 4/7
                    if ( (splittedCurvePrev = [[splittedC objectAtIndex:1] splittedObjectsAt:0.6]) ) // 0.8 0.6
                        gPrev = [splittedCurvePrev objectAtIndex:1]; // the last of third parts of prev curve
                }
            }
            bAngle = angleBetweenGraphicsInStartOrEnd(gThis, gPrev, 0);
            begOrth = orthPointAtBegOrEnd(gThis, r, dirInd, 0);		/* beg orthogonal to beg of gThis */

            /* in this cases we need an arc between the graphics (added only at end points)
             * angle is greater than 180 at correction side
             */
            if ( NeedArc(dir, w, bAngle) )
                begO = begOrth;
/* so war es */
#if 0
            else if ( ([gThis isKindOfClass:[VLine class]] && [gPrev isKindOfClass:[VLine class]])
                     || AngleNotSmallEnough(dir, w, bAngle) )
                begO = parallelPointbetweenObjects(gThis, gPrev, bAngle, r, dirInd, 0);
            else
                calcBegOWithCut=1; // begO = parallelPointbetweenObjects(gThis, gPrev, bAngle, r, dirInd, 0);

            /* cut of prevG(parallel) with gThis(parallel) is begO
             */
            if ( calcBegOWithCut || SmallAngle(dir, w, bAngle) )
            {   VGraphic	*pG, *thG;
                NSPoint		bPrevOrth, ePrevOrth, *iPts = NULL;
                int         iCnt = 0;

                bPrevOrth = orthPointAtBegOrEnd(gPrev, r, dirInd, 0);
                ePrevOrth = orthPointAtBegOrEnd(gPrev, r, dirInd, 1);
                // get parallel object to gPrev and gThis
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
#endif
/* neu */
#if 1
            /* cut of prevG(parallel) with gThis(parallel) is begO
             */
            else
            {   VGraphic	*pG, *thG;
                NSPoint		bPrevOrth, ePrevOrth, *iPts = NULL;
                int         iCnt = 0;

                bPrevOrth = orthPointAtBegOrEnd(gPrev, r, dirInd, 0);
                ePrevOrth = orthPointAtBegOrEnd(gPrev, r, dirInd, 1);
                // get parallel object to gPrev and gThis
                pG = [gPrev parallelObject:bPrevOrth :ePrevOrth :bPrevOrth :ePrevOrth];
                endOrth = orthPointAtBegOrEnd(gThis, r, dirInd, 1);
                thG = [gThis parallelObject:begOrth :endOrth :begOrth :endOrth];

                if ( pG && thG && (iCnt = [pG getIntersections:&iPts with:thG]) )
                {
                    if ( iCnt == 1 )
                        begO = iPts[0];
                    else
                    {   NSPoint bO = parallelPointbetweenObjects(gThis, gPrev, bAngle, r, dirInd, 0);
                        float   d=0, dist = MAXCOORD;
                        int     x;

                        for (x=0; x < iCnt; x++)
                        {
                            if ( (d = SqrDistPoints(iPts[x], bO)) < dist)
                            {   begO = iPts[x];
                                dist = d;
                            }
                        }
                    }
                }
                else if ( /*([gThis isKindOfClass:[VLine class]] && [gPrev isKindOfClass:[VLine class]])
                          ||*/ AngleNotSmallEnough(dir, w, bAngle) )
                    begO = parallelPointbetweenObjects(gThis, gPrev, bAngle, r, dirInd, 0);
                else
                    begO = begOrth;
                if (iPts)
                    free(iPts);
            }
#endif

            if ( splittedCurves && sc >= 0 && sc <= 3 ) // 2012-01-19
                gNext = [splittedCurves objectAtIndex:sc+1];
            else
            {   gNext = (i<endIx) ? [[pathCopy list] objectAtIndex:i+1] : [[pathCopy list] objectAtIndex:begIx];

                if ( [gNext isKindOfClass:[VCurve class]] )
                {   NSPoint p0, p1, p2, p3;

                    [(VCurve*)gNext getVertices:&p0 :&p1 :&p2 :&p3];
                    /* both Curve points are in its Start/End points - we build a line */
                    if ( SqrDistPoints(p0, p1) < 10*TOLERANCE && SqrDistPoints(p2, p3) < 10*TOLERANCE )
                    {
                        [lineNext setVertices:p0 :p3];
                        gNext = lineNext;
                    }
                }
                if ( splitCurves && [(VGraphic*)gNext length] > 1000.0*TOLERANCE &&
                     [gNext isKindOfClass:[VCurve class]] )
                {   NSArray	*splittedCurveNext = nil, *splittedC = nil;

                    splittedC = [(VCurve*)gNext splittedObjectsAt:0.333]; // 0.333 0.3
                    if ( (splittedCurveNext=[[splittedC objectAtIndex:0] splittedObjectsAt:0.4]) ) // 0.2 0.4
                        gNext = [splittedCurveNext objectAtIndex:0]; // the first of third parts of next curve
                }
            }
            eAngle = angleBetweenGraphicsInStartOrEnd(gThis, gNext, 1);
            endOrth = orthPointAtBegOrEnd(gThis, r, dirInd, 1);		// beg orthogonal to beg of gThis

            if ( NeedArc(dir, w, eAngle) )
            {   endO = endOrth;
                needArc = 1;
            }
/* so war es */
#if 0

            else if ( ([gThis isKindOfClass:[VLine class]] && [gNext isKindOfClass:[VLine class]])
                     || AngleNotSmallEnough(dir, w, eAngle) )
                endO = parallelPointbetweenObjects(gThis, gNext, eAngle, r, dirInd, 1);
            else
                calcEndOWithCut = 1; // endO = parallelPointbetweenObjects(gThis, gNext, eAngle, r, dirInd, 1);

            if ( calcEndOWithCut || SmallAngle(dir, w, eAngle) )
            {   VGraphic	*nG, *thG;
                NSPoint		bNextOrth, eNextOrth, *iPts = NULL;
                int         iCnt = 0;

                bNextOrth = orthPointAtBegOrEnd(gNext, r, dirInd, 0);
                eNextOrth = orthPointAtBegOrEnd(gNext, r, dirInd, 1);
                // get parallel object to gNext and gThis
                nG  = [gNext parallelObject:bNextOrth :eNextOrth :bNextOrth :eNextOrth];
                thG = [gThis parallelObject:begOrth   :endOrth   :begOrth   :endOrth];

                if ( nG && thG && (iCnt = [thG getIntersections:&iPts with:nG])==1 )
                    endO = iPts[0];
                else
                {
                    needArc = 2;	// here we calc edge orhtogonal with an arc
                    endO = endOrth;
                }
                if (iPts)
                    free(iPts);
            }

#endif

/* neu */
#if 1
            /* intersect parallel of gThis with parallel of gNext. Intersection point: begO
             */
            else
            {   VGraphic	*nG, *thG;
                NSPoint		bNextOrth, eNextOrth, *iPts = NULL;
                int         iCnt = 0;

                bNextOrth = orthPointAtBegOrEnd(gNext, r, dirInd, 0);
                eNextOrth = orthPointAtBegOrEnd(gNext, r, dirInd, 1);
                // get parallel object to gNext and gThis
                nG  = [gNext parallelObject:bNextOrth :eNextOrth :bNextOrth :eNextOrth];
                thG = [gThis parallelObject:begOrth   :endOrth   :begOrth   :endOrth];

                if ( nG && thG && (iCnt = [thG getIntersections:&iPts with:nG]) )
                {
                    if ( iCnt == 1 )
                        endO = iPts[0];
                    else // new
                    {   NSPoint eO = parallelPointbetweenObjects(gThis, gNext, eAngle, r, dirInd, 1);
                        float   d=0, dist = MAXCOORD;
                        int     x;

                        for (x=0; x < iCnt; x++)
                        {
                            if ( (d = SqrDistPoints(iPts[x], eO)) < dist)
                            {   endO = iPts[x];
                                dist = d;
                            }
                        }
                    }
                }
                else if ( /*([gThis isKindOfClass:[VLine class]] && [gNext isKindOfClass:[VLine class]])
                          ||*/ AngleNotSmallEnough(dir, w, eAngle) )
                    endO = parallelPointbetweenObjects(gThis, gNext, eAngle, r, dirInd, 1);
                else
                {   calcEndOWithCut = 1;
                    needArc = 2;	// here we calc edge orhtogonal with an arc
                    endO = endOrth;
                }
                if (iPts)
                    free(iPts);
            }
#endif

            /* now we can calc our parallel object of gThis */
            if ( (g = [gThis parallelObject:begOrth :endOrth :begO :endO]) )	/* build parallel objects */
            {
                if ( [g isKindOfClass:[VPath class]] ) // VPolyLine
                {   int	j, gCnt = [[(VPath*)g list] count];

                    for (j=0; j<gCnt; j++)
                        [[subPath list] addObject:[[(VPath*)g list] objectAtIndex:j]];
                }
                else
                    [[subPath list] addObject:g];
            }

            /* calulate arc to close ends
             * if we have to add an arc we use the end of gThis as center,
             * endO as start point, new angle is calculated
             */
            if ( needArc )
            {   VArc	*arc = [VArc arc];
                float	newA;

                [arc setWidth:[gThis width]];
                [arc setColor:[gThis color]];
                if ( needArc == 2 )	// not cut
                {
                    newA = ( eAngle > 360.0-eAngle ) ? ((360-eAngle)+180.0) : (eAngle+180.0);
                    if ( (!dir && w >= 0 && eAngle > 180.0) || (dir && w <= 0 && eAngle > 180.0) )
                    {   newA *= -1.0;
                        if ( width && (calcEndOWithCut || SmallAngle(dir, w, eAngle)) )
                        {   newA = 360.0 + newA;
                            if (newA < -360.0) newA += 360.0;
                        }
                    }
                    else if ( width && (calcEndOWithCut || SmallAngle(dir, w, eAngle)) )
                    {   newA = - (360.0-newA);
                        if (newA < -360.0) newA += 360.0;
                    }
                }	
                else
                {   /* eAngle > 180 */
                    newA = ( eAngle > 360.0-eAngle ) ? (eAngle-180.0) : ((360.0-eAngle)-180.0);
                    if ( (!dir && w >= 0 && eAngle < 180.0) || (dir && w <= 0 && eAngle < 180.0) )
                        newA *= -1.0;	/* cw */
                }
                center = [gThis pointWithNum:MAXINT]; // end pt of object is arc center - with out smoot edges
                if (Abs(newA) < 235.0) // we dont want arc greater than 180 degree (not possible in a contour)
                {   [arc setCenter:center start:endO angle:newA];
                    [[subPath list] addObject:arc];
                }
            }
        }
    }
    /* if (splitCurves) // debugging only */
    [self removeFaultGraphicsInSubpaths:path :w];

    [path unnest];	/* copy elements of subpath to list of path */
    [path setSelected:[self isSelected]];

    [pool release];
    return path;
}
#if 0 /* 4 Curves a 0.3/0.7 */
- (id)contour:(float)w inlay:(BOOL)inlay removeLoops:(BOOL)removeLoops
{   VPath	*path, *subPath=nil;
    int		i, listCnt = [list count], begIx=0, endIx=0, dir=0;
    int		direction, inside, directionArray[listCnt], insideArray[listCnt], dirInsideCnt=0;
    float	r, dirInd=1.0, bAngle, eAngle;
    int		cnt=0;

    /* we just return a copy */
    if ( (!filled && Abs(w)>width) || Diff(w, 0.0) < 0.0001 || (w<0.0 && Abs(w) == width) )
        return [[self copy] autorelease];

    //if ( Prefs_UseRaster )    // raster algorith must be called directly !
    //    return [self contourWithPixel:w];

    r = (w + width) / 2.0;	// the amount of growth

    path = [VPath path];
    [path setColor:color];

    /* remove Elements with no length
     * the problem is that we destroy our closed path!
     */
    for ( i=0, listCnt = [list count]; i<listCnt; i++ )
    {	VGraphic	*gThis = [list objectAtIndex:i];

        if ( [gThis length] < 10.0*TOLERANCE )
        {
            [list removeObject:gThis];
            i--;
            //[self closePath];
            listCnt = [list count];
            continue;
        }
    }

    /* what we do here:
     * step through elements of path
     * calculate start, end points for outline-elements in a distance to path (inside/outside)
     * calculate parallel elements through start and end points
     * we have to calculate each sub path separately, so we put them in real sub paths
     */

    /* walk through path list
     */
    for ( i=0, listCnt = [list count]; i<listCnt; i++ )
    {	id	g,
                gThis, gPrev, gNext;	/* this object, previous object, next object */
        NSPoint	begO, endO,	  /* start and endpoint of contour-object, if we dont add an arc (O = outline) */
                begOrth, endOrth, /* start and endpoint of contour-object, if we add an arc (orthogonal points) */
                center;			/* center point of arc if needed */
        int	sc, needArc = 0;	/* wether we need an arc to build correct contour around current edge */
        NSMutableArray	*splittedCurves = nil;

        gThis = [list objectAtIndex:i];	/* this object */

        /* new sub path
         */
        if ( !i || i>endIx )	/* new sub path */
        {   subPath = [VPath path];
            [[path list] addObject:subPath];
            begIx = i;
            //endIx = [self getLastObjectOfSubPath:begIx];
            endIx = [self getLastObjectOfSubPath:begIx]; //  tolerance:TOLERANCE

            cnt = 0;	/* counter for cutIndex array */

            /* only one element in subpath, so this must be an arc */
            if ( begIx == endIx )
            {	VGraphic	*arc;
                int	oldFillStyle=[gThis filled];

                if ( !([gThis isKindOfClass:[VArc class]] && Abs([(VArc*)gThis angle]) == 360.0) &&
                     ![gThis isKindOfClass:[VRectangle class]] ) /* nothing */
                {   insideArray[dirInsideCnt] = 0;
                    directionArray[dirInsideCnt++] = 0; /* doesnt matter */
                    continue;
                }
                [gThis setFilled:YES];
                if ( [self subPathInsidePath:begIx :endIx] )
                {   arc = [gThis contour:-w];
                    insideArray[dirInsideCnt] = 1;
                }
                else
                {   arc = [gThis contour:w];
                    insideArray[dirInsideCnt] = 0;
                }
                directionArray[dirInsideCnt++] = 0; /* doesnt matter if only one object */
//                ( [self subPathInsidePath:begIx :endIx] ) ? (arc = [gThis contour:-w]) : (arc = [gThis contour:w]);
                if (arc)
                    [[subPath list] addObject:arc];
                [gThis setFilled:oldFillStyle];
                continue;
            }
            /* determine direction indicator inside(1), outside(-1)
             */
            direction = [self directionOfSubPath:begIx :endIx];	/* 1 = ccw, 0 = cw */
            if ( (inside = [self subPathInsidePath:begIx :endIx]) )
            	dir = ( direction ) ? 0 : 1;
            else
                dir = direction;
            dirInd  = ( dir ) ? 1.0 : -1.0;			/* 1 = ccw, 0 = cw */

            directionArray[dirInsideCnt] = direction;
            insideArray[dirInsideCnt++] = inside;
        }

        /* split curves for better results */
        if ( [gThis isKindOfClass:[VCurve class]] )
        {   NSArray	*splittedCurves1 = nil, *splittedCurves2 = nil, *splittedCurves3 = nil;

            splittedCurves = [NSMutableArray arrayWithCapacity:4];
            splittedCurves1 = [gThis splittedObjectsAt:0.5];

            splittedCurves2 = [[splittedCurves1 objectAtIndex:0] splittedObjectsAt:0.3];
            [splittedCurves addObject:[splittedCurves2 objectAtIndex:0]];
            [splittedCurves addObject:[splittedCurves2 objectAtIndex:1]];
            splittedCurves3 = [[splittedCurves1 objectAtIndex:1] splittedObjectsAt:0.7];
            [splittedCurves addObject:[splittedCurves3 objectAtIndex:0]];
            [splittedCurves addObject:[splittedCurves3 objectAtIndex:1]];
        }
        for ( sc=0; sc < ((splittedCurves) ? 4 : 1); sc++ )
        {   BOOL	calcBegOWithCut = 0, calcEndOWithCut = 0;

            if ( splittedCurves )
                gThis = [splittedCurves objectAtIndex:sc];

            if ( sc == 1 )
                gPrev = [splittedCurves objectAtIndex:0];
            else if ( sc == 2 )
                gPrev = [splittedCurves objectAtIndex:1];
            else if ( sc == 3 )
                gPrev = [splittedCurves objectAtIndex:2];
            else
            {
                gPrev = (i>begIx) ? [list objectAtIndex:i-1] : [list objectAtIndex:endIx];
                if ( [gPrev isKindOfClass:[VCurve class]] )
                {   NSArray	*splittedCurvePrev = nil, *splittHalf = nil;

                    splittHalf = [gPrev splittedObjectsAt:0.5];
                    if ( (splittedCurvePrev = [[splittHalf objectAtIndex:1] splittedObjectsAt:0.7]) )
                        gPrev = [splittedCurvePrev objectAtIndex:1]; // the last of third parts of prev curve
                }
            }
            bAngle = angleBetweenGraphicsInStartOrEnd(gThis, gPrev, 0);
            begOrth = orthPointAtBegOrEnd(gThis, r, dirInd, 0);		/* beg orthogonal to beg of gThis */

            /* in this cases we need an arc between the graphics (added only at end points)
             * angle is greater than 180 at correction side
             */
            if ( NeedArc(dir, w, bAngle) )
                begO = begOrth;
            else if ( ([gThis isKindOfClass:[VLine class]] && [gPrev isKindOfClass:[VLine class]])
                     || AngleNotSmallEnough(dir, w, bAngle) )
                begO = parallelPointbetweenObjects(gThis, gPrev, bAngle, r, dirInd, 0);
            else
                calcBegOWithCut=1; // begO = parallelPointbetweenObjects(gThis, gPrev, bAngle, r, dirInd, 0);

            /* cut of prevG(parallel) with gThis(parallel) is begO
             */
            if ( calcBegOWithCut || SmallAngle(dir, w, bAngle) )
            {   VGraphic    *pG, *thG;
                NSPoint     bPrevOrth, ePrevOrth, *iPts = NULL;
                int         iCnt = 0;

                bPrevOrth = orthPointAtBegOrEnd(gPrev, r, dirInd, 0);
                ePrevOrth = orthPointAtBegOrEnd(gPrev, r, dirInd, 1);
                // get parallel object to gPrev and gThis
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

            if ( !sc && splittedCurves )
                gNext = [splittedCurves objectAtIndex:1];
            else if ( sc == 1 && splittedCurves )
                gNext = [splittedCurves objectAtIndex:2];
            else if ( sc == 2 && splittedCurves )
                gNext = [splittedCurves objectAtIndex:3];
            else
            {   gNext = (i<endIx) ? [list objectAtIndex:i+1] : [list objectAtIndex:begIx];
                if ( [gNext isKindOfClass:[VCurve class]] )
                {   NSArray	*splittedCurveNext = nil, *splittHalf = nil;

                    splittHalf = [gNext splittedObjectsAt:0.5];
                    if ( (splittedCurveNext=[[splittHalf objectAtIndex:0] splittedObjectsAt:0.3]) )
                        gNext = [splittedCurveNext objectAtIndex:0]; // the first of third parts of next curve
                }
            }
            eAngle = angleBetweenGraphicsInStartOrEnd(gThis, gNext, 1);
            endOrth = orthPointAtBegOrEnd(gThis, r, dirInd, 1);		/* beg orthogonal to beg of gThis */

            if ( NeedArc(dir, w, eAngle) )
            {   endO = endOrth;
                needArc = 1;
            }
            else if ( ([gThis isKindOfClass:[VLine class]] && [gNext isKindOfClass:[VLine class]])
                     || AngleNotSmallEnough(dir, w, eAngle) )
                endO = parallelPointbetweenObjects(gThis, gNext, eAngle, r, dirInd, 1);
            else
                calcEndOWithCut = 1; // endO = parallelPointbetweenObjects(gThis, gNext, eAngle, r, dirInd, 1);

            /* intersect parallel of gThis with parallel of gNext. Intersection point: begO
             */
            if ( calcEndOWithCut || SmallAngle(dir, w, eAngle) )
            {   VGraphic	*nG, *thG;
                NSPoint	bNextOrth, eNextOrth, *iPts = NULL;
                int		iCnt;

                bNextOrth = orthPointAtBegOrEnd(gNext, r, dirInd, 0);
                eNextOrth = orthPointAtBegOrEnd(gNext, r, dirInd, 1);
                // get parallel object to gNext and gThis
                nG = [gNext parallelObject:bNextOrth :eNextOrth :bNextOrth :eNextOrth];
                thG = [gThis parallelObject:begOrth :endOrth :begOrth :endOrth];

                if ( nG && thG && (iCnt = [thG getIntersections:&iPts with:nG])==1 )
                    endO = iPts[0];
                else
                {
                    needArc = 2;	// here we calc edge orhtogonal with an arc
                    endO = endOrth;
                }
                if (iPts)
                    free(iPts);
            }

            /* now we can calc our parallel object of gThis */
            if ( (g = [gThis parallelObject:begOrth :endOrth :begO :endO]) )	/* build parallel objects */
            {
                if ( [g isKindOfClass:[VPath class]] ) // VPolyLine
                {   int	j, gCnt = [[g list] count];

                    for (j=0; j<gCnt; j++)
                        [[subPath list] addObject:[[g list] objectAtIndex:j]];
                }
                else
                    [[subPath list] addObject:g];
            }

            /* calulate arc to close ends
             * if we have to add an arc we use the end of gThis as center,
             * endO as start point, new angle is calculated
             */
            if ( needArc )
            {   VArc	*arc = [VArc arc];
                float	newA;

                [arc setWidth:[gThis width]];
                [arc setColor:[gThis color]];
                if ( needArc == 2 )	// not cut
                {   ( eAngle > 360.0-eAngle ) ? (newA = (360-eAngle)+180.0) : (newA = eAngle+180.0);
                    if ( (!dir && w >= 0 && eAngle > 180.0) || (dir && w <= 0 && eAngle > 180.0) )
                    {   newA *= -1.0;
                        if ( width && (calcEndOWithCut || SmallAngle(dir, w, eAngle)) )
                        {   newA = 360.0 + newA;
                            if (newA < -360.0) newA += 360.0;
                        }
                    }
                    else if ( width && (calcEndOWithCut || SmallAngle(dir, w, eAngle)) )
                    {   newA = - (360.0-newA);
                        if (newA < -360.0) newA += 360.0;
                    }
                }	
                else
                {   /* eAngle > 180 */
                    newA = ( eAngle > 360.0-eAngle ) ? (eAngle-180.0) : ((360.0-eAngle)-180.0);
                    if ( (!dir && w >= 0 && eAngle < 180.0) || (dir && w <= 0 && eAngle < 180.0) )
                        newA *= -1.0;	/* cw */
                }
                center = [gThis pointWithNum:MAXINT]; // end pt of object is arc center - with out smoot edges
                if (Abs(newA) < 235.0) // we dont want arc greater than 180 degree (not possible in a contour)
                {   [arc setCenter:center start:endO angle:newA];
                    [[subPath list] addObject:arc];
                }
            }
        }
    }

    [self removeFaultGraphicsInSubpaths:path :w];

    [path unnest];	/* copy elements of subpath to list of path */
    [path setSelected:[self isSelected]];

    return path;
}
#endif

/* Build Contour of unfilled path
 * modified: 2011-03-11 (build outline with stroke width + distance)
 */
- (id)contourOpen:(float)w
{   VPath	*path = [VPath path];
    int		i, cnt = [list count];
    float	cw = (w + width), oldWidth = 0.0;

    /* we just return a copy */
    //if ( (w < 0.0 && Abs(w) >= width) || Diff(w, 0.0) < 0.0001 )
    if ( (Diff(w, 0.0) < 0.0001 && width == 0.0) || (w < 0.0 && Abs(w) >= width) )
        return [[self copy] autorelease];

    /* remove Elements with no length
     * the problem is that we destroy our closed path!
     */
    for ( i=0, cnt = [list count]; i<cnt; i++ )
    {	VGraphic	*gThis = [list objectAtIndex:i];

        if ( [gThis length] < 10.0*TOLERANCE )
        {
            [list removeObject:gThis];
            i--;
            //[self closePath];
            cnt = [list count];
            continue;
        }
    }

    [path setColor:[self color]];
    // build contour of all elements in path
    for (i=0; i<cnt; i++)
    {   VGraphic    *gr = [list objectAtIndex:i], *ng;

        //if ( [gr isKindOfClass:[VLine class]] ) // line did not have a width here ! arc/rect eigentlich auch nicht ?
        // falls doch -> [gr setWidth:0.0]; // nachher alten fillstyle wieder setzen ???
        oldWidth = [gr width];
        [gr setWidth:0.0];
        ng = [gr contour:cw];
        [gr setWidth:oldWidth];
        if ( [ng isKindOfClass:[VPath class]] ) // line, open arc
            [(VPath*)ng setFilled:YES optimize:NO]; // allready optimized
        else // full arc, rectangle
            [ng setFilled:YES]; // need objects filled for uniteAreas
        [[path list] addObject:ng];
    }

    // unite these elements
    {   HiddenArea	*hiddenArea = [HiddenArea new];
        [hiddenArea uniteAreas:[path list]];
        [hiddenArea release];
    }
    // unfill
    [path unnest];
    [path setFilled:NO];
    return path;
}

/* get contour with pixels
 * return the calculated path and the linePath (with the up and down engraving lines)
 */
- (VPath*)contourWithPixel:(float)w
{   PathContour	*pathContour;
    VPath	*path;

    if ( !(w+width) )
    {	NSMutableData	*data;
        NSArchiver      *ts;
        NSUnarchiver	*tsu;

        /* writes the path to a stream and reads it back from this stream */
        data = [[NSMutableData alloc] init];
        ts = [[NSArchiver alloc] initForWritingWithMutableData:data];
        [ts encodeRootObject:self];
        [ts release];
        tsu = [[NSUnarchiver alloc] initForReadingWithData:data];
        path = [[tsu decodeObject] retain];
        [tsu release];
        [data release];

        [path setFilled:NO];
        [path setSelected:[self isSelected]];

        return path;
    }

    pathContour = [[PathContour new] autorelease];

    return [pathContour contourPath:self width:w];
}

/* returns a flattened copy of path
 */
/*- flattenedObject
{   VPath		*newPath = [[self copy] autorelease];
    NSMutableArray	*plist;
    int			i, cnt;

    cnt = [list count];
    plist = [NSMutableArray array];
    for ( i=0; i<cnt; i++)
    {	id	fg, g = [list objectAtIndex:i];

        fg = [g flattenedObject];
        if ( [fg isKindOfClass:[VPath class]] )	// copy list of fg to path list
        {   int	j;

            for (j=0; j<[fg count]; j++)
                [plist addObject:[[fg list] objectAtIndex:j]];
        }
        else if (fg)
            [plist addObject:fg];
    }
    [newPath setList:plist];
    [newPath setSelected:[self isSelected]];

    return newPath;
}*/

- (NSMutableArray*)getListOfObjectsSplittedFromGraphic:g
{   NSMutableArray	*splitList = [NSMutableArray array], *spList = nil;
    int			i, j, cnt = [list count];
    NSAutoreleasePool 	*pool = [NSAutoreleasePool new];

    /* tile each graphic from path with pArray
     * add splitted objects to splitList (else object)
     */
    for (i=0; i<cnt; i++)
    {	VGraphic	*gr = [list objectAtIndex:i];

        spList = [gr getListOfObjectsSplittedFromGraphic:g];
        if ( spList )
        {   for ( j=0; j<(int)[spList count]; j++ )
                [splitList addObject:[spList objectAtIndex:j]];
        }
        else
            [splitList addObject:[[gr copy] autorelease]];
    }
    [pool release];
    if ( [splitList count] > [list count] )
        return splitList;
    return nil;
}

- getListOfObjectsSplittedFrom:(NSPoint*)pArray :(int)iCnt
{   NSMutableArray	*splitList = [NSMutableArray array], *spList = nil;
    int			i, j, cnt = [list count];
    NSAutoreleasePool 	*pool = [NSAutoreleasePool new];

    /* tile each graphic from path with pArray
     * add splitted objects to splitList (else object)
     */
    for (i=0; i<cnt; i++)
    {	VGraphic	*g = [list objectAtIndex:i];

        spList = [g getListOfObjectsSplittedFrom:pArray :iCnt];
        if ( spList )
        {   for ( j=0; j<(int)[spList count]; j++ )
                [splitList addObject:[spList objectAtIndex:j]];
        }
        else
            [splitList addObject:[[g copy] autorelease]];
    }
    [pool release];
    if ( [splitList count] > [list count] )
        return splitList;
    return nil;
}

- (NSMutableArray*)getListOfObjectsSplittedAtPoint:(NSPoint)pt
{   NSMutableArray	*splitList = [NSMutableArray array], *spList = nil;
    int			i, cnt = [list count], splitI = -1;
    NSPoint		cpt, start, end, sgStart, sgEnd;
    NSAutoreleasePool 	*pool = [NSAutoreleasePool new];
    float		distance=MAXCOORD;
    VGraphic		*splitg=nil;

    cpt = [self nearestPointOnObject:&splitI distance:&distance toPoint:pt];

    start = [self pointWithNum:0];
    end = [self pointWithNum:MAXINT];
    if ( (Diff(start.x, cpt.x) < 100.0*TOLERANCE && Diff(start.y, cpt.y) < 100.0*TOLERANCE) ||
         (Diff(end.x, cpt.x) < 100.0*TOLERANCE && Diff(end.y, cpt.y) < 100.0*TOLERANCE) )
    {   [pool release];
        return nil;
    }
    splitg = [list objectAtIndex:splitI];
    sgStart = [splitg pointWithNum:0];
    sgEnd = [splitg pointWithNum:MAXINT];
    if ((Diff(sgStart.x, cpt.x) > 100.0*TOLERANCE || Diff(sgStart.y, cpt.y) > 100.0*TOLERANCE) &&
        (Diff(sgEnd.x, cpt.x) > 100.0*TOLERANCE || Diff(sgEnd.y, cpt.y) > 100.0*TOLERANCE))
        spList = [splitg getListOfObjectsSplittedFrom:&cpt :1];
    if (splitI == 0 && Diff(sgEnd.x, cpt.x) <= 100.0*TOLERANCE && Diff(sgEnd.y, cpt.y) <= 100.0*TOLERANCE)
        splitI = 1; // (splitI+1 < cnt) ? (splitI+1) : (0);

    if (splitI != -1)
    {   VPath		*sPath = [VPath path];
        VGraphic	*gr;

        [sPath setWidth:width];
        [sPath setColor:color];
        for (i=0; i<splitI; i++)
        {
            if ([[sPath list] count] > 0)
            {   NSPoint	pEnd, cBeg;

                pEnd = [[[sPath list] objectAtIndex:[[sPath list] count]-1] pointWithNum:MAXINT];
                cBeg = [[list objectAtIndex:i] pointWithNum:0];
                if (SqrDistPoints(pEnd, cBeg) < (TOLERANCE*15.0)*(TOLERANCE*15.0))
                    [[sPath list] addObject:[[[list objectAtIndex:i] copy] autorelease]];
                else
                {
                    if ([[sPath list] count] == 1)
                        [splitList addObject:[[sPath list] objectAtIndex:0]];
                    else
                        [splitList addObject:sPath];
                    sPath = [VPath path];
                    [sPath setWidth:width];
                    [sPath setColor:color];
                    [[sPath list] addObject:[[[list objectAtIndex:i] copy] autorelease]];
                }
            }
            else
                [[sPath list] addObject:[[[list objectAtIndex:i] copy] autorelease]];
        }
        if ([spList count] > 1)
        {
            gr = [spList objectAtIndex:0];
            if ([gr isKindOfClass:[VPath class]])
            {   int j, pCnt = [[(VPath*)gr list] count];

                if ([[sPath list] count] > 0)
                {   NSPoint	pEnd, cBeg;

                    pEnd = [[[sPath list] objectAtIndex:[[sPath list] count]-1] pointWithNum:MAXINT];
                    cBeg = [gr pointWithNum:0];
                    if (SqrDistPoints(pEnd, cBeg) < (TOLERANCE*15.0)*(TOLERANCE*15.0))
                    {
                        for (j=1; j<pCnt; j++)
                            [[sPath list] addObject:[[(VPath*)gr list] objectAtIndex:j]];
                    }
                    else
                    {   if ([[sPath list] count] == 1)
                        [splitList addObject:[[sPath list] objectAtIndex:0]];
                        else
                            [splitList addObject:sPath];
                        sPath = [VPath path];
                        [sPath setWidth:width];
                        [sPath setColor:color];
                        for (j=1; j<pCnt; j++)
                            [[sPath list] addObject:[[(VPath*)gr list] objectAtIndex:j]];
                    }
                }
                else
                    for (j=1; j<pCnt; j++)
                        [[sPath list] addObject:[[(VPath*)gr list] objectAtIndex:j]];
            }
            else
            {
                if ([[sPath list] count] > 0)
                {   NSPoint	pEnd, cBeg;

                    pEnd = [[[sPath list] objectAtIndex:[[sPath list] count]-1] pointWithNum:MAXINT];
                    cBeg = [gr pointWithNum:0];
                    if (SqrDistPoints(pEnd, cBeg) < (TOLERANCE*15.0)*(TOLERANCE*15.0))
                        [[sPath list] addObject:gr];
                    else
                    {   if ([[sPath list] count] == 1)
                            [splitList addObject:[[sPath list] objectAtIndex:0]];
                        else
                            [splitList addObject:sPath];
                        sPath = [VPath path];
                        [sPath setWidth:width];
                        [sPath setColor:color];
                        [[sPath list] addObject:gr];
                    }
                }
                else
                    [[sPath list] addObject:gr];
            }
        }
        if ([[sPath list] count] == 1) // 360 Arc or Rectangle
            [splitList addObject:[[sPath list] objectAtIndex:0]];
        else
            [splitList addObject:sPath];


        sPath = [VPath path];
        [sPath setWidth:width];
        [sPath setColor:color];
        if ([spList count] > 1)
        {
            gr = [spList objectAtIndex:1];
            if ([gr isKindOfClass:[VPath class]])
            {   int j, pCnt = [[(VPath*)gr list] count];

                for (j=1; j<pCnt; j++)
                    [[sPath list] addObject:[[(VPath*)gr list] objectAtIndex:j]];
            }
            else
                [[sPath list] addObject:gr];
        }
        for (i=(([spList count] > 1) ? splitI+1 : splitI); i<cnt; i++)
        {
            if ([[sPath list] count] > 0)
            {   NSPoint	pEnd, cBeg;

                pEnd = [[[sPath list] objectAtIndex:[[sPath list] count]-1] pointWithNum:MAXINT];
                cBeg = [[list objectAtIndex:i] pointWithNum:0];
                if (SqrDistPoints(pEnd, cBeg) < (TOLERANCE*15.0)*(TOLERANCE*15.0))
                    [[sPath list] addObject:[[[list objectAtIndex:i] copy] autorelease]];
                else
                {
                    if ([[sPath list] count] == 1)
                        [splitList addObject:[[sPath list] objectAtIndex:0]];
                    else
                        [splitList addObject:sPath];
                    sPath = [VPath path];
                    [sPath setWidth:width];
                    [sPath setColor:color];
                    [[sPath list] addObject:[[[list objectAtIndex:i] copy] autorelease]];
                }
            }
            else
                [[sPath list] addObject:[[[list objectAtIndex:i] copy] autorelease]];
        }
        if ([[sPath list] count] == 1) // 360 Arc or Rectangle
            [splitList addObject:[[sPath list] objectAtIndex:0]];
        else
            [splitList addObject:sPath];
    }
    [pool release];
    if ([splitList count])
        return splitList;
    return nil;
}

- (BOOL)intersects:g
{   NSPoint	*pts;

    if ( [self getIntersections:&pts with:g] )
    {   free(pts);
        return YES;
    }
    return NO;
}
- (int)getIntersections:(NSPoint**)ppArray with:g
{   int			i, j, iCnt = 0;
    int			len = Min(100, [self numPoints]);
    NSPoint		*pts = NULL;
    //NSMutableData	*data = [NSMutableData dataWithLength:([list count]*9) * sizeof(NSPoint)];
    NSAutoreleasePool	*pool = [NSAutoreleasePool new];

    //*ppArray = [data mutableBytes];
    *ppArray = malloc(len * sizeof(NSPoint));
    //*ppArray = NSZoneMalloc((NSZone*)[(NSObject*)NSApp zone], len * sizeof(NSPoint));
    for (i=[list count]-1; i>=0; i--)
    {	id	gp = [list objectAtIndex:i];
        int	cnt, oldCnt = iCnt;

        if ( gp == g )
            continue;

        cnt = [gp getIntersections:&pts with:g];	/* line, arc, curve, rectangle */
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
            {   NSPoint	start, end;

                if ( [gp isKindOfClass:[VLine class]] )		/* line */
                    [(VLine*)gp getVertices:&start :&end];
                else if ( [gp isKindOfClass:[VArc class]] || [gp isKindOfClass:[VCurve class]] )
                {   start = [gp pointWithNum:0];
                    end = [gp pointWithNum:MAXINT];
                }
                else if ( [gp isKindOfClass:[VRectangle class]] )
                {   NSPoint	ur, ul, size;
                    [(VRectangle*)gp getVertices:&start :&size]; // origin size
                    end = start; end.x += size.x;
                    ul = start; ul.y += size.y;
                    ur = end; ur.y += size.y;
                    if ( (Diff(pts[j].x, ul.x) + Diff(pts[j].y, ul.y) < 10.0*TOLERANCE) ||
                         (Diff(pts[j].x, ur.x) + Diff(pts[j].y, ur.y) < 10.0*TOLERANCE) )
                        continue; // do not add
                }
                else if ( [gp isKindOfClass:[VPolyLine class]] )
                {   int	k, pCnt = [(VPolyLine*)gp ptsCount], stop = 0;

                    for (k=1; k<pCnt-1; k++)
                    {   NSPoint	pt = [(VPolyLine*)gp pointWithNum:k];
                        if ( Diff(pts[j].x, pt.x) + Diff(pts[j].y, pt.y) < 10.0*TOLERANCE )
                        {   stop = 1; break; }
                    }
                    if (stop)
                        continue; // do not add
                    [(VPolyLine*)gp getEndPoints:&start :&end];
                }
                else
                {
                    start.x = end.x = pts[j].x; start.y = end.y = pts[j].y;
                }
                /* point is no edge point of gp -> add */
                if ( (Diff(pts[j].x, start.x) + Diff(pts[j].y, start.y) > 10.0*TOLERANCE) &&
                     (Diff(pts[j].x, end.x) + Diff(pts[j].y, end.y) > 10.0*TOLERANCE) )
                    (*ppArray)[iCnt++] = pts[j];
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
    [pool release];
    return iCnt;
}
#if 0

/*
 * FIXME: better intersection function - should be used for point in polygon test
 *
 * schiebt start/end punkte von horizontaler linie weg
 */
- (int)getIntersectionsForFilling:(NSPoint**)ppArray with:g
{   int			i, j, iCnt = 0;
    int			len = Min(100, [self numPoints]);
    NSPoint		*pts = NULL, ls, le;

    *ppArray = malloc(len * sizeof(NSPoint));
    //*ppArray = NSZoneMalloc((NSZone*)[(NSObject*)NSApp zone], len * sizeof(NSPoint));

    /* g is allways a line here */
    [g getVertices:&ls :&le];

    for (i=[list count]-1; i>=0; i--)
    {	id	gp = [list objectAtIndex:i], tgp = nil;
        int	cnt = 0, oldCnt = iCnt;
        float	d=0.0;

        if ( gp == g )
            continue;

        /* here we must move the s/e pts of gp far away from line */
        if ( [gp isKindOfClass:[VLine class]] )
        {   NSPoint	p0, p1;

            [(VLine*)gp getVertices:&p0 :&p1];
            d = p0.y - ls.y;
            if (d >= 0.0 && d <= 3.0*TOLERANCE)
                p0.y += 3.0*TOLERANCE;
            if (d < 0.0 && -d <= 3.0*TOLERANCE)
                p0.y -= 3.0*TOLERANCE;
            d = p1.y - ls.y;
            if (d >= 0.0 && d <= 3.0*TOLERANCE)
                p1.y += 3.0*TOLERANCE;
            if (d < 0.0 && -d <= 3.0*TOLERANCE)
                p1.y -= 3.0*TOLERANCE;

            tgp = [[VLine allocWithZone:[self zone]] init];
            [tgp setVertices:p0 :p1];
        }
        else if ( [gp isKindOfClass:[VCurve class]] )
        {   NSPoint	p0, p1, p2, p3;

            [(VCurve*)gp getVertices:&p0 :&p1 :&p2 :&p3];
            d = p0.y - ls.y;
            if (d >= 0.0 && d <= 3.0*TOLERANCE)
            {   p0.y += 3.0*TOLERANCE;
                p1.y += 3.0*TOLERANCE;
            }
            if (d < 0.0 && -d <= 3.0*TOLERANCE)
            {   p0.y -= 3.0*TOLERANCE;
                p1.y -= 3.0*TOLERANCE;
            }
            d = p3.y - ls.y;
            if (d >= 0.0 && d <= 3.0*TOLERANCE)
            {   p3.y += 3.0*TOLERANCE;
                p2.y += 3.0*TOLERANCE;
            }
            if (d < 0.0 && -d <= 3.0*TOLERANCE)
            {   p3.y -= 3.0*TOLERANCE;
                p2.y -= 3.0*TOLERANCE;
            }
            tgp = [[VCurve allocWithZone:[self zone]] init];
            [(VCurve*)tgp setVertices:p0 :p1 :p2 :p3];
        }
        else if ( [gp isKindOfClass:[VRectangle class]] )
        {   NSPoint	o, s;

            [(VRectangle*)gp getVertices:&o :&s];
            d = o.y - ls.y;
            if (d >= 0.0 && d <= 3.0*TOLERANCE)
                o.y += 3.0*TOLERANCE;
            if (d < 0.0 && -d <= 3.0*TOLERANCE)
                o.y -= 3.0*TOLERANCE;
            d = (o.y+s.y) - ls.y; // upper line - Fix me: - - - -  rotation not checked !
            if (d >= 0.0 && d <= 3.0*TOLERANCE)
                o.y += 3.0*TOLERANCE; // we move also the origin
            if (d < 0.0 && -d <= 3.0*TOLERANCE)
                o.y -= 3.0*TOLERANCE;
            tgp = [[VRectangle allocWithZone:[self zone]] init];
            [(VRectangle*)tgp setVertices:o :s];
        }
        else if ( [gp isKindOfClass:[VArc class]] )
        {   NSPoint	p0=[(VArc*)gp pointWithNum:0], p1=[(VArc*)gp pointWithNum:MAXINT];

            tgp = [(VArc*)gp copy];

            d = p0.y - ls.y;
            if (d >= 0.0 && d <= 3.0*TOLERANCE)
                [tgp movePoint:0 by:NSMakePoint(0.0, 3.0*TOLERANCE)];
            if (d < 0.0 && -d <= 3.0*TOLERANCE)
                [tgp movePoint:0 by:NSMakePoint(0.0, -3.0*TOLERANCE)];
            d = p1.y - ls.y;
            if (d >= 0.0 && d <= 3.0*TOLERANCE)
                [tgp movePoint:MAXINT by:NSMakePoint(0.0, 3.0*TOLERANCE)];
            if (d < 0.0 && -d <= 3.0*TOLERANCE)
                [tgp movePoint:MAXINT by:NSMakePoint(0.0, -3.0*TOLERANCE)];
        }
        else if ( [gp isKindOfClass:[VPolyLine class]] )
        {   int		pCnt = [gp ptsCount];

            cnt = 0;
            pts = malloc(pCnt * sizeof(NSPoint));

            /* each line by itself */
            for (j=0; j < pCnt-1; j++)
            {   NSPoint	pl0 = [gp pointWithNum:j], pl1 = [gp pointWithNum:j+1], pt;

                /* we move the points away from our intersecting line, so we don't hit an edge */
                d = pl0.y - ls.y;
                if (d >= 0.0 && d <= 3.0*TOLERANCE)
                    pl0.y += 3.0*TOLERANCE;
                if (d < 0.0 && -d <= 3.0*TOLERANCE)
                    pl0.y -= 3.0*TOLERANCE;
                d = pl1.y - ls.y;
                if (d >= 0.0 && d <= 3.0*TOLERANCE)
                    pl1.y += 3.0*TOLERANCE;
                if (d < 0.0 && -d <= 3.0*TOLERANCE)
                    pl1.y -= 3.0*TOLERANCE;

                if (vhfIntersectLines(&pt, ls, le, pl0, pl1))
                {
                    pts[cnt++] = pt;
if (cnt >= pCnt)
    NSLog(@"'VPath.m Fuck");
                }
            }
        }

        if ( ![gp isKindOfClass:[VPolyLine class]] )
            cnt = [tgp getIntersections:&pts with:g];	/* line, arc, curve, rectangle */

        if (iCnt+cnt >= len)
            *ppArray = realloc(*ppArray, (len+=cnt*2) * sizeof(NSPoint));

        for (j=0; j<cnt; j++)
        {
            if ( !pointInArray(pts[j], *ppArray, oldCnt) )
                (*ppArray)[iCnt++] = pts[j];

            /* we need this allways - RubOut z.B. kann aufeinanderliegende linien erzeugen ! */
            else
            {   NSPoint	start, end;

                if ( [gp isKindOfClass:[VLine class]] )		/* line */
                    [(VLine*)gp getVertices:&start :&end];
                else if ( [gp isKindOfClass:[VArc class]] || [gp isKindOfClass:[VCurve class]] )
                {   start = [gp pointWithNum:0];
                    end = [gp pointWithNum:MAXINT];
                }
                else if ( [gp isKindOfClass:[VRectangle class]] )
                {   NSPoint	ur, ul, size;
                    [(VRectangle*)gp getVertices:&start :&size]; // origin size
                    end = start; end.x += size.x;
                    ul = start; ul.y += size.y;
                    ur = end; ur.y += size.y;
                    if ( (Diff(pts[j].x, ul.x) + Diff(pts[j].y, ul.y) < 10.0*TOLERANCE) ||
                         (Diff(pts[j].x, ur.x) + Diff(pts[j].y, ur.y) < 10.0*TOLERANCE) )
                        continue; // do not add
                }
                else if ( [gp isKindOfClass:[VPolyLine class]] )
                {   int	k, pCnt = [(VPolyLine*)gp ptsCount], stop = 0;

                    for (k=1; k<pCnt-1; k++)
                    {   NSPoint	pt = [(VPolyLine*)gp pointWithNum:k];
                        if ( Diff(pts[j].x, pt.x) + Diff(pts[j].y, pt.y) < 10.0*TOLERANCE )
                        {   stop = 1; break; }
                    }
                    if (stop)
                        continue; // do not add
                    [(VPolyLine*)gp getEndPoints:&start :&end];
                }
                else
                {
                    start.x = end.x = pts[j].x; start.y = end.y = pts[j].y;
                }
                /* point is no edge point of gp -> add */
                if ( (Diff(pts[j].x, start.x) + Diff(pts[j].y, start.y) > 10.0*TOLERANCE) &&
                     (Diff(pts[j].x, end.x) + Diff(pts[j].y, end.y) > 10.0*TOLERANCE) )
                    (*ppArray)[iCnt++] = pts[j];
//                else
//                    NSLog(@"VPath.m -getIntersectionsForFilling: point not added !!");
            }
        }
        if ( tgp )
            [tgp release];
        if ( cnt )
            free(pts);
        pts = 0;
    }

    if (!iCnt)
    {   free(*ppArray);
        //NSZoneFree((NSZone*)[(NSObject*)NSApp zone], *ppArray);
        *ppArray = NULL;
    }
    return iCnt;
}
#endif

/* get intersections with line segment
 */
- (int)intersectLine:(NSPoint*)pArray :(NSPoint)pl0 :(NSPoint)pl1
{   NSPoint	*pts;
    VLine	*line = [VLine lineWithPoints:pl0 :pl1];
    int		cnt;

    if ( (cnt = [self getIntersections:&pts with:line]) )
    {   free(pts);
        return cnt;
    }
    return 0;
}

#define	INFO_OK			0
#define	INFO_HORICONTAL_UP	1
#define	INFO_HORICONTAL_DOWN	2
#define	INFO_TANGENT		3
#define	INFO_EDGE_UP		4
#define	INFO_EDGE_DOWN		5

#if 0 // new
- (int)intersectionsForPtInside:(NSPoint**)ppArray :(int**)ppInfo with:g
{   int		i, j, listCnt = [list count], iCnt = 0, horicontals = 0;
    NSPoint	p0 = [g pointWithNum:0]; // allway a line !
    NSRect	gBounds = [g bounds];

    *ppArray = malloc([self numPoints] * sizeof(NSPoint));
    *ppInfo = malloc([self numPoints] * sizeof(int));
    for (i=0; i<listCnt; i++)
    {	id      gp = [list objectAtIndex:i];
        int     cnt, oldCnt = iCnt;
        NSRect  gpBounds = [gp bounds];
        NSPoint	*pts = NULL;

        if ( gp == g )
            continue;
        // check bounds
        if ( NSIsEmptyRect(NSIntersectionRect(gBounds , gpBounds)) )
            continue;

        cnt = [gp getIntersections:&pts with:g];	// line, arc, curve, rectangle
        if ( cnt == 2 &&
             ( [gp isKindOfClass:[VLine class]] ||
              ([gp isKindOfClass:[VArc class]] && pts[0].x == pts[1].x) ) )
        {   int	info0 = INFO_HORICONTAL_UP, info1 = INFO_HORICONTAL_UP;

            /* if there are two intersections with horicontal line the line of the polygon is allso horicontal */
            /* or an arc tangent */
            if ([gp isKindOfClass:[VLine class]])
            {   VGraphic    *prevG = nil, *nextG = nil;
                NSPoint     start, end, s, e;
                int         k, l;

                if (pointInArray(pts[0], *ppArray, oldCnt))
                {   /* remove all edge points */
                    for (k=0; k<oldCnt; k++)
                        if ( (*ppInfo)[k] >= INFO_EDGE_UP &&
                             SqrDistPoints(pts[0], (*ppArray)[k]) < (10.0*TOLERANCE)*(10.0*TOLERANCE) )
                        {
                            for (l=k; l<oldCnt-1; l++)
                            {   (*ppArray)[l] = (*ppArray)[l+1];
                                (*ppInfo)[l] = (*ppInfo)[l+1];
                            }
                            oldCnt--; k--; iCnt--;
                        }
                }
                if (pointInArray(pts[1], *ppArray, oldCnt))
                {   /* remove all edge points */
                    for (k=0; k<oldCnt; k++)
                        if ( (*ppInfo)[k] >= INFO_EDGE_UP &&
                             SqrDistPoints(pts[1], (*ppArray)[k]) < (10.0*TOLERANCE)*(10.0*TOLERANCE) )
                        {
                            for (l=k; l<oldCnt-1; l++)
                            {   (*ppArray)[l] = (*ppArray)[l+1];
                                (*ppInfo)[l] = (*ppInfo)[l+1];
                            }
                            oldCnt--; k--; iCnt--;
                        }
                }
                /* search prevG/nextG */
                prevG = nextG = nil;
                [(VLine*)gp getVertices:&start :&end];
                for (k=0; k<listCnt;k++)
                {   VGraphic	*gr = [list objectAtIndex:k];

                    if (k == i)
                        continue;

                    s = [gr pointWithNum:0];
                    e = [gr pointWithNum:MAXINT];
                    if (!prevG && SqrDistPoints(e, start) <= TOLERANCE) // prevG found
                        prevG = gr;
                    if (!nextG && SqrDistPoints(s, end) <= TOLERANCE) // nextG found
                        nextG = gr;
                    if (prevG && nextG)
                        break;
                }
                /* check if prevG/nextG come from up and/or down */
                if ( [prevG isKindOfClass:[VLine class]] )		/* prevG is a line */
                {   [(VLine*)prevG getVertices:&start :&end]; // horicontals are not down !
                    info0 = (start.y < pts[0].y - TOLERANCE) ? INFO_HORICONTAL_DOWN : INFO_HORICONTAL_UP;
                }
                else if ( [prevG isKindOfClass:[VArc class]] || [prevG isKindOfClass:[VCurve class]] )
                {   start = [prevG pointAt:0.85];
                    info0 = (start.y < pts[0].y) ? INFO_HORICONTAL_DOWN : INFO_HORICONTAL_UP;
                }
                else if ( [prevG isKindOfClass:[VPolyLine class]] )
                {   int		pCnt = [(VPolyLine*)prevG ptsCount];
                    NSPoint	pt = [(VPolyLine*)prevG pointWithNum:pCnt-2];

                    info0 = (pt.y < pts[0].y - TOLERANCE) ? INFO_HORICONTAL_DOWN : INFO_HORICONTAL_UP;
                }
                if ( [nextG isKindOfClass:[VLine class]] )		/* nextG is a line */
                {   [(VLine*)nextG getVertices:&start :&end]; // horicontals are not down !
                    info1 = (end.y < pts[0].y - 2.0*TOLERANCE) ? INFO_HORICONTAL_DOWN : INFO_HORICONTAL_UP;
                }
                else if ( [nextG isKindOfClass:[VArc class]] || [nextG isKindOfClass:[VCurve class]] )
                {   end = [nextG pointAt:0.15];
                    info1 = (end.y < pts[0].y) ? INFO_HORICONTAL_DOWN : INFO_HORICONTAL_UP;
                }
                else if ( [nextG isKindOfClass:[VPolyLine class]] )
                {   NSPoint	pt = [(VPolyLine*)nextG pointWithNum:1];

                    info1 = (pt.y < pts[0].y - TOLERANCE) ? INFO_HORICONTAL_DOWN : INFO_HORICONTAL_UP;
                }
                if (info0 != info1)
                    horicontals++;
            }
            (*ppArray)[iCnt] = pts[0];
            (*ppInfo)[iCnt++] = ([gp isKindOfClass:[VArc class]]) ? INFO_TANGENT : info0;
            (*ppArray)[iCnt] = pts[1];
            (*ppInfo)[iCnt++] = ([gp isKindOfClass:[VArc class]]) ? INFO_TANGENT : info1;
            if (pts)
                free(pts);
            continue;
        }
        else if ( [gp isKindOfClass:[VRectangle class]] && cnt == 2 )
        {   /* if one intersectionpoint layes on the uppest OR lowest y value of the rectangle
            * -> -1 !!! (horicontal...)
            */
            for (j=0; j<cnt; j++)
            {
                if ( (Diff(pts[j].y, gpBounds.origin.y) <= TOLERANCE) ||
                     (Diff(pts[j].y, (gpBounds.origin.y+gpBounds.size.height)) <= TOLERANCE) )
                {
                    if ( cnt > 1 )
                    {
                        (*ppArray)[iCnt].x = gpBounds.origin.x;
                        (*ppArray)[iCnt].y = pts[j].y;
                        (*ppInfo)[iCnt++] = INFO_HORICONTAL_DOWN;
                        (*ppArray)[iCnt].x = gpBounds.origin.x + gpBounds.size.width;
                        (*ppArray)[iCnt].y = pts[j].y;
                        (*ppInfo)[iCnt++] = INFO_HORICONTAL_DOWN;
                    }
                    else
                    {   (*ppArray)[iCnt] = pts[j];
                        (*ppInfo)[iCnt++] = INFO_HORICONTAL_DOWN;
                        (*ppArray)[iCnt] = pts[j];
                        (*ppInfo)[iCnt++] = INFO_HORICONTAL_DOWN;
                    }
                    free(pts);
                    continue;
                }
            }
        }
        else if ( [gp isKindOfClass:[VCurve class]] && cnt )
        {   NSPoint	p0, p1, p2, p3, tpoints[3];
            int		i, cpt, realSol=0, numSol=0, stop = 0;
            double	cy, by, ay, t[3];

            [gp getVertices:&p0 :&p1 :&p2 :&p3];
            /* we must look if one of the intersection points lying on a extrem point of the curve
                * represent the curve with the equations
                * x(t) = ax*t^3 + bx*t^2 + cx*t + x(0)
                * y(t) = ay*t^3 + by*t^2 + cy*t + y(0)
                * -> 3ay*t^2 + 2by*t + cy = 0
                */
            cy = 3*(p1.y - p0.y);
            by = 3*(p2.y - p1.y) - cy;
            ay = p3.y - p0.y - by - cy;

            /* get the ts in which the tangente is horicontal
                */
            numSol = svPolynomial2( 3.0*ay, 2.0*by, cy, t);

            /* when t is on curve */
            realSol=0;
            for ( i=0 ; i<numSol ; i++)
                if ( t[i] >= 0.0 && t[i] <= 1.0 )
                    tpoints[realSol++] = [gp pointAt:t[i]];

            /* if intersection point is a tangent point */
            for ( i=0 ; i<realSol ;i++ )
            {
                for ( cpt=0 ; cpt<cnt ; cpt++ )
                    if ( Diff(tpoints[i].x, pts[cpt].x) <= 25.0*TOLERANCE &&
                         Diff(tpoints[i].y, pts[cpt].y) <= 25.0*TOLERANCE)
                    {
                        (*ppArray)[iCnt] = pts[cpt];
                        (*ppInfo)[iCnt++] = INFO_TANGENT;
                        (*ppArray)[iCnt] = pts[cpt];
                        (*ppInfo)[iCnt++] = INFO_TANGENT;
                        if (cnt == 1)
                        {   free(pts);
                            stop = 1;
                            break;
                        }
                        else
                        {   for (j = cpt; j<cnt-1; j++)
                               pts[j] = pts[j+1];
                            cnt--; cpt--;
                        }
                    }
                    if (stop)
                        break;
            }
            if (stop)
            {   free(pts);
                continue;
            }
        }
        // polyline ?
        else if ( [gp isKindOfClass:[VPolyLine class]] && cnt )
            NSLog(@"VPath.m - intersectionsForPtInside::with:: VPolyLine not implemented");

        /* add points if not allways inside pparray
         * else check if pt is edge pt of graphic
         */
        for (j=0; j<cnt; j++)
        {   NSPoint	start, end;
            BOOL	edgePoint = NO, edgeInfo = NO;

            /* check if edge point of gp */
            /* and check if gp laying up or down the graphic */
            if ( [gp isKindOfClass:[VLine class]] )		/* line */
            {    [(VLine*)gp getVertices:&start :&end];
                if (((Diff(pts[j].x, end.x) + Diff(pts[j].y, end.y) < 10.0*TOLERANCE) &&
                     (start.y > pts[j].y /* + 2.0*TOLERANCE */)) ||
                    ((Diff(pts[j].x, start.x) + Diff(pts[j].y, start.y) < 10.0*TOLERANCE) &&
                     (end.y > pts[j].y /* + 2.0*TOLERANCE */)))
                {    edgePoint = YES; edgeInfo = INFO_EDGE_UP; }
                else if (((Diff(pts[j].x, end.x) + Diff(pts[j].y, end.y) < 10.0*TOLERANCE) &&
                          (start.y < pts[j].y /* - 2.0*TOLERANCE */)) ||
                         ((Diff(pts[j].x, start.x) + Diff(pts[j].y, start.y) < 10.0*TOLERANCE) &&
                          (end.y < pts[j].y /* - 2.0*TOLERANCE */)))
                {    edgePoint = YES; edgeInfo = INFO_EDGE_DOWN; }
                else if ((Diff(pts[j].x, end.x) + Diff(pts[j].y, end.y) < 10.0*TOLERANCE) ||
                         (Diff(pts[j].x, start.x) + Diff(pts[j].y, start.y) < 10.0*TOLERANCE))
                    NSLog(@"VPath.m -intersectionsForPtInside::with:: line is not up or down ??");
            }
            else if ( [gp isKindOfClass:[VArc class]] || [gp isKindOfClass:[VCurve class]] )
            {   start = [gp pointWithNum:0];
                end = [gp pointWithNum:MAXINT];

                if ((Diff(pts[j].x, start.x) + Diff(pts[j].y, start.y) < 10.0*TOLERANCE) ||
                    (Diff(pts[j].x, end.x) + Diff(pts[j].y, end.y) < 10.0*TOLERANCE))
                {   NSPoint	p12 = {0,0};

                    edgePoint = YES;
                    if ((Diff(pts[j].x, start.x) + Diff(pts[j].y, start.y) < 10.0*TOLERANCE))
                        p12 = [gp pointAt:0.15];	
                    else
                        p12 = [gp pointAt:0.85];
                    edgeInfo = (p12.y > pts[j].y) ? INFO_EDGE_UP : INFO_EDGE_DOWN;
                }
            }
            else if ( [gp isKindOfClass:[VRectangle class]] )
            {   NSPoint	ur, ul, size;
                [(VRectangle*)gp getVertices:&start :&size]; // origin size
                end = start; end.x += size.x;
                ul = start; ul.y += size.y;
                ur = end; ur.y += size.y;
                if ( (Diff(pts[j].x, ul.x) + Diff(pts[j].y, ul.y) < 10.0*TOLERANCE) ||
                     (Diff(pts[j].x, ur.x) + Diff(pts[j].y, ur.y) < 10.0*TOLERANCE) )
                {   edgePoint = YES;
                    edgeInfo = INFO_EDGE_DOWN;
                }
                else if ( (Diff(pts[j].x, start.x) + Diff(pts[j].y, start.y) < 10.0*TOLERANCE) &&
                          (Diff(pts[j].x, end.x) + Diff(pts[j].y, end.y) < 10.0*TOLERANCE) )
                {   edgePoint = YES;
                    edgeInfo = INFO_EDGE_UP;
                }
            }
            else if ( [gp isKindOfClass:[VPolyLine class]] )
            {   int	k, pCnt = [(VPolyLine*)gp ptsCount];
                NSPoint	pt = [(VPolyLine*)gp pointWithNum:1];

                for (k=1; k<pCnt-1; k++)
                {   NSPoint	pt = [(VPolyLine*)gp pointWithNum:k];
                    if ( Diff(pts[j].x, pt.x) + Diff(pts[j].y, pt.y) < 10.0*TOLERANCE )
                    {   NSPoint	pm1 = [(VPolyLine*)gp pointWithNum:(((k-1) < 0)?(pCnt-1):(k-1))];
                        NSPoint	pp1 = [(VPolyLine*)gp pointWithNum:(((k+1) < pCnt) ? (k+1):(0))];

                        if ((pm1.y > pts[j].y /* + 2.0*TOLERANCE */ && pp1.y > pts[j].y + 2.0*TOLERANCE) ||
                            (pm1.y < pts[j].y /* - 2.0*TOLERANCE */ && pp1.y < pts[j].y - 2.0*TOLERANCE))
                        {   edgePoint = YES; break; }
                    }
                }
                if (edgePoint == YES)
                    continue; // do not add !!!!!!!!!!!!!!

                pt = [(VPolyLine*)gp pointWithNum:1];
                [(VPolyLine*)gp getEndPoints:&start :&end];
                if (Diff(pts[j].x, start.x) + Diff(pts[j].y, start.y) < 10.0*TOLERANCE)
                {   edgePoint = YES;
                    edgeInfo = (pt.y > pts[j].y /* + 2.0*TOLERANCE */) ? INFO_EDGE_UP : INFO_EDGE_DOWN;
                }
                if (Diff(pts[j].x, end.x) + Diff(pts[j].y, end.y) < 10.0*TOLERANCE)
                {   edgePoint = YES;
                    pt = [(VPolyLine*)gp pointWithNum:pCnt-2];
                    edgeInfo = (pt.y > pts[j].y /* + 2.0*TOLERANCE */) ? INFO_EDGE_UP : INFO_EDGE_DOWN;
                }
            }
            else
                NSLog(@"VPath.m -intersectionsForPtInside::with:: unknown graphic ");

            /* point is not in array OR no edge point of gp -> add */
            if ( !pointInArray(pts[j], *ppArray, oldCnt) || edgePoint == NO )
            {   (*ppArray)[iCnt] = pts[j];
                (*ppInfo)[iCnt++] = (edgePoint == YES) ? edgeInfo : INFO_OK;
            }
            else if (edgePoint == YES) // check if prevG/curG(gp) up end down the line
            {   int	k, l;

                for (k=0; k<oldCnt; k++)
                    if ( SqrDistPoints(pts[j], (*ppArray)[k]) < (10.0*TOLERANCE)*(10.0*TOLERANCE) )
                    {
                        /* up and down - do not add second point */
                        if (((*ppInfo)[k] == INFO_EDGE_UP && edgeInfo == INFO_EDGE_DOWN) ||
                            ((*ppInfo)[k] == INFO_EDGE_DOWN && edgeInfo == INFO_EDGE_UP))
                            continue;
                        else if ((*ppInfo)[k] >= INFO_EDGE_UP) // remove only edge points from ppArray !!
                        {   /* only up or on/down remove allso other edge from point array - but horicontal points ! */
                            for (l=k; l<oldCnt-1; l++)
                            {   (*ppArray)[l] = (*ppArray)[l+1];
                                (*ppInfo)[l] = (*ppInfo)[l+1];
                            }
                            oldCnt--; k--; iCnt--;
                        }
                    }
            }
        }
        if (pts)
            free(pts);
    }
    /* sort points from left to right */
    for (i=0; i<iCnt-1; i++)
    {	int	j, jMin, info;
        float	lastDist, newDist;
        NSPoint	p;

        jMin = iCnt;
        lastDist=SqrDistPoints((*ppArray)[i], p0);
        for (j=i+1; j<iCnt; j++)
        {
            if ((newDist=SqrDistPoints((*ppArray)[j], p0)) < lastDist)
            {	lastDist = newDist;
                jMin = j;
            }
        }
        if (jMin<iCnt)
        {   p = (*ppArray)[i];
            info = (*ppInfo)[i];
            (*ppArray)[i] = (*ppArray)[jMin];
            (*ppInfo)[i] = (*ppInfo)[jMin];
            (*ppArray)[jMin] = p;
            (*ppInfo)[jMin] = info;
        }
    }

    if ((Even(horicontals) && !Even(iCnt)) || (!Even(horicontals) && Even(iCnt)))
        NSLog(@"VPath.m -intersectionsForPtInside:.with: one point less; y: %.3f, cnt: %d, hs: %d", p0.y, iCnt, horicontals);

    if (!iCnt)
    {	free(*ppArray); *ppArray = NULL;
     	free(*ppInfo);  *ppInfo  = NULL;
    }
    return iCnt;
}
#endif

/* return -1 if we hit a horicontal graphic or tangential point
 * return -2 if pt is ON a horicontal graphic or ON the tangential point
 */
- (int)intersectionsForPtInside:(NSPoint**)ppArray with:g :(NSPoint)pt
{   int		i, j, iCnt = 0, ptsCnt = Min(100, [self numPoints]);
    NSRect	gBounds = [g bounds];
    BOOL	tangential = NO;

    *ppArray = malloc(ptsCnt * sizeof(NSPoint));
    for (i=[list count]-1; i>=0; i--)
    {	id      gp = [list objectAtIndex:i];
        int     cnt, oldCnt = iCnt;
        NSRect  gpBounds = [gp bounds];
        NSPoint	*pts = NULL;

        if ( gp == g )
            continue;
        // check bounds
        if ( NSIsEmptyRect(NSIntersectionRect(gBounds, gpBounds)) )
            continue;

        cnt = [gp getIntersections:&pts with:g];	// line, arc, curve, rectangle
        if ( cnt == 2 &&
             ( [gp isKindOfClass:[VLine class]] ||
              ([gp isKindOfClass:[VArc class]] &&
               (pts[0].x == pts[1].x ||
                ((pt.x >= pts[0].x && pt.x <= pts[1].x) || (pt.x <= pts[0].x && pt.x >= pts[1].x)))) ) )
        {
            /* if there are two intersections with horicontal line the line of the polygon is allso horicontal */
            /* or an arc tangent */
            if ([gp isKindOfClass:[VLine class]] || ([gp isKindOfClass:[VArc class]] && pts[0].x == pts[1].x))
            {   tangential = YES;
                (*ppArray)[0] = pts[0];
                (*ppArray)[1] = pts[1];
            }
            if ([gp isKindOfClass:[VLine class]] &&
                ((pt.x >= pts[0].x && pt.x <= pts[1].x) || (pt.x <= pts[0].x && pt.x >= pts[1].x)))
            {   free(pts);
                return -2; // on
            }
            else if ( pts[0].x != pts[1].x &&
                      ((pt.x >= pts[0].x && pt.x <= pts[1].x) || (pt.x <= pts[0].x && pt.x >= pts[1].x)) )
            {	NSPoint	p0 = [g pointWithNum:0], p1 = [g pointWithNum:MAXINT], *aPts;
                int	aCnt = 0;

                /* we have made a sidestep */
                if (Diff(pt.y, p0.y) > TOLERANCE/2.0)
                {   VLine	*line = [VLine line];

                    p0.y = p1.y = pt.y;
                    [line setVertices:p0 :p1];
                    if (!(aCnt = [line getIntersections:&aPts with:gp]) || aCnt == 2)
                    {
                        if (!aCnt || aPts[0].x == aPts[1].x)
                        {
                            /* not inside  !! */
                            free(pts);
                            free(aPts);
                            return -1; // need a sidestep to other side !
                        }
                    }
                }
                if (aCnt)
                    free(aPts);
            }
            else if ([gp isKindOfClass:[VArc class]] && Diff(pt.x, pts[0].x) <= 5.0*TOLERANCE)
            {   free(pts);
                return -2; // on
            }
            else if ([gp isKindOfClass:[VArc class]])
            {	NSPoint	tpt = pts[0], p0 = [g pointWithNum:0], p1 = [g pointWithNum:MAXINT], *aPts;
                VLine	*line = [VLine line];
                int	aCnt = 0;

                p0.y += TOLERANCE;
                p1.y += TOLERANCE;
                [line setVertices:p0 :p1];
                aCnt = [line getIntersections:&aPts with:gp];
                if (!aCnt)
                {   p0.y -= 2.0*TOLERANCE;
                    p1.y -= 2.0*TOLERANCE;
                    [line setVertices:p0 :p1];
                    aCnt = [line getIntersections:&aPts with:gp];
                }
                if (((aCnt == 2 &&
                      ((pt.x >= aPts[0].x && pt.x <= aPts[1].x) || (pt.x <= aPts[0].x && pt.x >= aPts[1].x)))) ||
                    (aCnt == 1 &&
                     ((pt.x >= aPts[0].x && pt.x <= tpt.x) || (pt.x <= aPts[0].x && pt.x >= tpt.x))))
                {   free(pts);
                    free(aPts);
                    return -2; // on
                }
                if (aCnt)
                    free(aPts);
            }
        }
        else if ( [gp isKindOfClass:[VRectangle class]] && cnt )
        {   /* if one intersectionpoint layes on the uppest OR lowest y value of the rectangle
             * -> -1 !!! (horicontal...)
             */
            for (j=0; j<cnt; j++)
            {
                if ( (Diff(pts[j].y, gpBounds.origin.y) <= TOLERANCE) ||
                    (Diff(pts[j].y, (gpBounds.origin.y+gpBounds.size.height)) <= TOLERANCE) )
                {   //free(*ppArray); *ppArray = NULL;
                    if ( cnt > 1 )
                    {   if ( Diff(pts[j].y, gpBounds.origin.y) <= TOLERANCE )
                        {   (*ppArray)[0].x = gpBounds.origin.x;
                            (*ppArray)[1].x = gpBounds.origin.x + gpBounds.size.width;
                        }
                        else
                        {   (*ppArray)[0].x = gpBounds.origin.x;
                            (*ppArray)[1].x = gpBounds.origin.x + gpBounds.size.width;
                        }
                        (*ppArray)[0].y = (*ppArray)[1].y = pts[j].y;
                    }
                    else
                    {   (*ppArray)[0] = (*ppArray)[1] = pts[j]; }

                    if ((pt.x >= (*ppArray)[0].x && pt.x <= (*ppArray)[1].x) ||
                        (pt.x <= (*ppArray)[0].x && pt.x >= (*ppArray)[1].x))
                    {   free(pts);
                        return -2; // on
                    }
                    tangential = YES;
                }
            }
        }
        else if ( [gp isKindOfClass:[VCurve class]] && cnt )
        {   NSPoint	p0, p1, p2, p3, tpoints[3];
            int		i, cpt, realSol=0, numSol=0;
            double	cy, by, ay, t[3];

            [gp getVertices:&p0 :&p1 :&p2 :&p3];
            /* we must look if one of the intersection points lying on a extrem point of the curve
             * represent the curve with the equations
             * x(t) = ax*t^3 + bx*t^2 + cx*t + x(0)
             * y(t) = ay*t^3 + by*t^2 + cy*t + y(0)
             * -> 3ay*t^2 + 2by*t + cy = 0
             */
            cy = 3*(p1.y - p0.y);
            by = 3*(p2.y - p1.y) - cy;
            ay = p3.y - p0.y - by - cy;

            /* get the ts in which the tangente is horicontal
             */
            numSol = svPolynomial2( 3.0*ay, 2.0*by, cy, t);

            /* when t is on curve */
            realSol=0;
            for ( i=0 ; i<numSol ; i++)
                if ( t[i] >= 0.0 && t[i] <= 1.0 )
                    tpoints[realSol++] = [gp pointAt:t[i]];

            /* if one intersection point is identical with one tpoint -> -1 */
            for ( i=0 ; i<realSol ;i++ )
                for ( cpt=0 ; cpt<cnt ; cpt++ )
                    if (Diff(tpoints[i].x, pts[cpt].x) <= TOLERANCE && Diff(tpoints[i].y, pts[cpt].y) <= TOLERANCE)
                    {   //free(*ppArray);
                        //*ppArray = NULL;
                        (*ppArray)[0] = (*ppArray)[1] = pts[cpt];
                        if (Diff(pt.x, pts[cpt].x) <= TOLERANCE)
                        {   free(pts);
                            return -2; // on
                        }
                        tangential = YES;
                    }
        }
        else if ( cnt > 1 && [gp isKindOfClass:[VPolyLine class]] )
        {   int		p, nPts = [gp numPoints];
            NSPoint	pl0, pl1;

            /* check each line in PolyLine if horicontal */
            for (p=0; p < nPts-1; p++)
            {
                pl0 = [gp pointWithNum:p];
                pl1 = [gp pointWithNum:p+1];

                if (pointWithToleranceInArray(pl0, TOLERANCE, pts, cnt) && // both point are in pts
                    pointWithToleranceInArray(pl1, TOLERANCE, pts, cnt))
                {
                    tangential = YES;
                    (*ppArray)[0] = pts[0];
                    (*ppArray)[1] = pts[1];
                    if ((pt.x >= pts[0].x && pt.x <= pts[1].x) || (pt.x <= pts[0].x && pt.x >= pts[1].x))
                    {
                        free(pts);
                        return -2; // on
                    }
                }
            }
        }

        if (iCnt+cnt >= ptsCnt)
            *ppArray = realloc(*ppArray, (ptsCnt+=cnt*2) * sizeof(NSPoint));

        // add points if not allways inside pparray
        // else check if pt is edge pt of graphic -> return -1
        for (j=0; j<cnt; j++)
        {
            if ( !pointInArray(pts[j], *ppArray, oldCnt) )
                (*ppArray)[iCnt++] = pts[j];
            else
            {   NSPoint	start, end;

                if ( [gp isKindOfClass:[VLine class]] )		/* line */
                    [(VLine*)gp getVertices:&start :&end];
                else if ( [gp isKindOfClass:[VArc class]] || [gp isKindOfClass:[VCurve class]] )
                {   start = [gp pointWithNum:0];
                    end = [gp pointWithNum:MAXINT];
                }
                else if ( [gp isKindOfClass:[VRectangle class]] )
                {   NSPoint	ur, ul, size;
                    [(VRectangle*)gp getVertices:&start :&size]; // origin size
                    end = start; end.x += size.x;
                    ul = start; ul.y += size.y;
                    ur = end;   ur.y += size.y;
                    if ( (Diff(pts[j].x, ul.x) + Diff(pts[j].y, ul.y) < 10.0*TOLERANCE) ||
                        (Diff(pts[j].x, ur.x) + Diff(pts[j].y, ur.y) < 10.0*TOLERANCE) )
                        continue; // do not add
                }
                else if ( [gp isKindOfClass:[VPolyLine class]] )
                {   int	k, pCnt = [(VPolyLine*)gp ptsCount], stop = 0;

                    for (k=1; k<pCnt-1; k++)
                    {   NSPoint	pt = [(VPolyLine*)gp pointWithNum:k];
                        if ( Diff(pts[j].x, pt.x) + Diff(pts[j].y, pt.y) < 10.0*TOLERANCE )
                        {   stop = 1; break; }
                    }
                    if (stop)
                        continue; // do not add
                    [(VPolyLine*)gp getEndPoints:&start :&end];
                }
                else
                {   start.x = end.x = pts[j].x; start.y = end.y = pts[j].y;
                }
                /* point is no edge point of gp -> add */
                if ( (Diff(pts[j].x, start.x) + Diff(pts[j].y, start.y) > 10.0*TOLERANCE) &&
                     (Diff(pts[j].x, end.x)   + Diff(pts[j].y, end.y)   > 10.0*TOLERANCE) )
                    (*ppArray)[iCnt++] = pts[j];
                else
                {   (*ppArray)[0] = (*ppArray)[1] = pts[j];
                    if (Diff(pt.x, pts[j].x) <= TOLERANCE)
                    {   free(pts);
                        return -2; // on
                    }
                    tangential = YES;
                }
            }
        }
        if (pts)
            free(pts);
    }
    if (!iCnt)
    {	free(*ppArray);
        *ppArray = NULL;
    }
    else if (tangential)
        return -1;
    return iCnt;
}

- (int)intersectionsForPtInside:(NSPoint**)ppArray with:g :(NSPoint)pt subPath:(int)begIx :(int)endIx
{   int		i, j, iCnt = 0, ptsCnt = Min(100, [self numPoints]);
    NSRect	gBounds = [g bounds];
    BOOL	tangential = NO;

    *ppArray = malloc(ptsCnt * sizeof(NSPoint));
    for (i=endIx; i>=begIx; i--)
    {	id	gp = [list objectAtIndex:i];
        int	cnt, oldCnt = iCnt;
        NSRect	gpBounds = [gp bounds];
        NSPoint	*pts = NULL;

        if ( gp == g )
            continue;
        // check bounds
        if ( NSIsEmptyRect(NSIntersectionRect(gBounds, gpBounds)) )
            continue;

        cnt = [gp getIntersections:&pts with:g];	// line, arc, curve, rectangle
        if ( cnt == 2 &&
             ( [gp isKindOfClass:[VLine class]] ||
              ([gp isKindOfClass:[VArc class]] &&
               (pts[0].x == pts[1].x ||
                ((pt.x >= pts[0].x && pt.x <= pts[1].x) || (pt.x <= pts[0].x && pt.x >= pts[1].x)))) ) )
        {
            /* if there are two intersections with horicontal line the line of the polygon is allso horicontal */
            /* or an arc tangent */
            if ([gp isKindOfClass:[VLine class]] || ([gp isKindOfClass:[VArc class]] && pts[0].x == pts[1].x))
            {   tangential = YES;
                (*ppArray)[0] = pts[0];
                (*ppArray)[1] = pts[1];
            }
            if ([gp isKindOfClass:[VLine class]] &&
                ((pt.x >= pts[0].x && pt.x <= pts[1].x) || (pt.x <= pts[0].x && pt.x >= pts[1].x)))
            {   free(pts);
                return -2; // on
            }
            else if ( pts[0].x != pts[1].x &&
                      ((pt.x >= pts[0].x && pt.x <= pts[1].x) || (pt.x <= pts[0].x && pt.x >= pts[1].x)) )
            {	NSPoint	p0 = [g pointWithNum:0], p1 = [g pointWithNum:MAXINT], *aPts;
                int	aCnt = 0;

                /* we have made a sidestep */
                if (Diff(pt.y, p0.y) > TOLERANCE/2.0)
                {   VLine	*line = [VLine line];

                    p0.y = p1.y = pt.y;
                    [line setVertices:p0 :p1];
                    if (!(aCnt = [line getIntersections:&aPts with:gp]) || aCnt == 2)
                    {
                        if (!aCnt || aPts[0].x == aPts[1].x)
                        {
                            /* not inside  !! */
                            free(pts);
                            free(aPts);
                            return -1; // need a sidestep to other side !
                        }
                    }
                }
                if (aCnt)
                    free(aPts);
            }
            else if ([gp isKindOfClass:[VArc class]] && Diff(pt.x, pts[0].x) <= 5.0*TOLERANCE)
            {   free(pts);
                return -2; // on
            }
            else if ([gp isKindOfClass:[VArc class]])
            {	NSPoint	tpt = pts[0], p0 = [g pointWithNum:0], p1 = [g pointWithNum:MAXINT], *aPts;
                VLine	*line = [VLine line];
                int	aCnt = 0;

                p0.y += TOLERANCE;
                p1.y += TOLERANCE;
                [line setVertices:p0 :p1];
                aCnt = [line getIntersections:&aPts with:gp];
                if (!aCnt)
                {   p0.y -= 2.0*TOLERANCE;
                    p1.y -= 2.0*TOLERANCE;
                    [line setVertices:p0 :p1];
                    aCnt = [line getIntersections:&aPts with:gp];
                }
                if (((aCnt == 2 &&
                      ((pt.x >= aPts[0].x && pt.x <= aPts[1].x) || (pt.x <= aPts[0].x && pt.x >= aPts[1].x)))) ||
                    (aCnt == 1 &&
                     ((pt.x >= aPts[0].x && pt.x <= tpt.x) || (pt.x <= aPts[0].x && pt.x >= tpt.x))))
                {   free(pts);
                    free(aPts);
                    return -2; // on
                }
                if (aCnt)
                    free(aPts);
            }
        }
        else if ( [gp isKindOfClass:[VRectangle class]] && cnt )
        {   /* if one intersectionpoint layes on the uppest OR lowest y value of the rectangle
             * -> -1 !!! (horicontal...)
             */
            for (j=0; j<cnt; j++)
            {
                if ( (Diff(pts[j].y, gpBounds.origin.y) <= TOLERANCE) ||
                    (Diff(pts[j].y, (gpBounds.origin.y+gpBounds.size.height)) <= TOLERANCE) )
                {   //free(*ppArray); *ppArray = NULL;
                    if ( cnt > 1 )
                    {   if ( Diff(pts[j].y, gpBounds.origin.y) <= TOLERANCE )
                        {   (*ppArray)[0].x = gpBounds.origin.x;
                            (*ppArray)[1].x = gpBounds.origin.x + gpBounds.size.width;
                        }
                        else
                        {   (*ppArray)[0].x = gpBounds.origin.x;
                            (*ppArray)[1].x = gpBounds.origin.x + gpBounds.size.width;
                        }
                        (*ppArray)[0].y = (*ppArray)[1].y = pts[j].y;
                    }
                    else
                    {   (*ppArray)[0] = (*ppArray)[1] = pts[j]; }

                    if ((pt.x >= (*ppArray)[0].x && pt.x <= (*ppArray)[1].x) ||
                        (pt.x <= (*ppArray)[0].x && pt.x >= (*ppArray)[1].x))
                    {   free(pts);
                        return -2; // on
                    }
                    tangential = YES;
                }
            }
        }
        else if ( [gp isKindOfClass:[VCurve class]] && cnt )
        {   NSPoint	p0, p1, p2, p3, tpoints[3];
            int		i, cpt, realSol=0, numSol=0;
            double	cy, by, ay, t[3];

            [gp getVertices:&p0 :&p1 :&p2 :&p3];
            /* we must look if one of the intersection points lying on a extrem point of the curve
             * represent the curve with the equations
             * x(t) = ax*t^3 + bx*t^2 + cx*t + x(0)
             * y(t) = ay*t^3 + by*t^2 + cy*t + y(0)
             * -> 3ay*t^2 + 2by*t + cy = 0
             */
            cy = 3*(p1.y - p0.y);
            by = 3*(p2.y - p1.y) - cy;
            ay = p3.y - p0.y - by - cy;

            /* get the ts in which the tangente is horicontal
             */
            numSol = svPolynomial2( 3.0*ay, 2.0*by, cy, t);

            /* when t is on curve */
            realSol=0;
            for ( i=0 ; i<numSol ; i++)
                if ( t[i] >= 0.0 && t[i] <= 1.0 )
                    tpoints[realSol++] = [gp pointAt:t[i]];

            /* if one intersection point is identical with one tpoint -> -1 */
            for ( i=0 ; i<realSol ;i++ )
                for ( cpt=0 ; cpt<cnt ; cpt++ )
                    if (Diff(tpoints[i].x, pts[cpt].x) <= TOLERANCE && Diff(tpoints[i].y, pts[cpt].y) <= TOLERANCE)
                    {   //free(*ppArray);
                        //*ppArray = NULL;
                        (*ppArray)[0] = (*ppArray)[1] = pts[cpt];
                        if (Diff(pt.x, pts[cpt].x) <= TOLERANCE)
                        {   free(pts);
                            return -2; // on
                        }
                        tangential = YES;
                    }
        }
        else if ( cnt > 1 && [gp isKindOfClass:[VPolyLine class]] )
        {   int		p, nPts = [gp numPoints];
            NSPoint	pl0, pl1;

            /* check each line in PolyLine if horicontal */
            for (p=0; p < nPts-1; p++)
            {
                pl0 = [gp pointWithNum:p];
                pl1 = [gp pointWithNum:p+1];

                if (pointWithToleranceInArray(pl0, TOLERANCE, pts, cnt) && // both point are in pts
                    pointWithToleranceInArray(pl1, TOLERANCE, pts, cnt))
                {
                    tangential = YES;
                    (*ppArray)[0] = pts[0];
                    (*ppArray)[1] = pts[1];
                    if ((pt.x >= pts[0].x && pt.x <= pts[1].x) || (pt.x <= pts[0].x && pt.x >= pts[1].x))
                    {
                        free(pts);
                        return -2; // on
                    }
                }
            }
        }

        if (iCnt+cnt >= ptsCnt)
            *ppArray = realloc(*ppArray, (ptsCnt+=cnt*2) * sizeof(NSPoint));

        // add points if not allways inside pparray
        // else check if pt is edge pt of graphic -> return -1
        for (j=0; j<cnt; j++)
        {
            if ( !pointInArray(pts[j], *ppArray, oldCnt) )
                (*ppArray)[iCnt++] = pts[j];
            else
            {   NSPoint	start, end;

                if ( [gp isKindOfClass:[VLine class]] )		/* line */
                    [(VLine*)gp getVertices:&start :&end];
                else if ( [gp isKindOfClass:[VArc class]] || [gp isKindOfClass:[VCurve class]] )
                {   start = [gp pointWithNum:0];
                    end = [gp pointWithNum:MAXINT];
                }
                else if ( [gp isKindOfClass:[VRectangle class]] )
                {   NSPoint	ur, ul, size;
                    [(VRectangle*)gp getVertices:&start :&size]; // origin size
                    end = start; end.x += size.x;
                    ul = start; ul.y += size.y;
                    ur = end;   ur.y += size.y;
                    if ( (Diff(pts[j].x, ul.x) + Diff(pts[j].y, ul.y) < 10.0*TOLERANCE) ||
                        (Diff(pts[j].x, ur.x) + Diff(pts[j].y, ur.y) < 10.0*TOLERANCE) )
                        continue; // do not add
                }
                else if ( [gp isKindOfClass:[VPolyLine class]] )
                {   int	k, pCnt = [(VPolyLine*)gp ptsCount], stop = 0;

                    for (k=1; k<pCnt-1; k++)
                    {   NSPoint	pt = [(VPolyLine*)gp pointWithNum:k];
                        if ( Diff(pts[j].x, pt.x) + Diff(pts[j].y, pt.y) < 10.0*TOLERANCE )
                        {   stop = 1; break; }
                    }
                    if (stop)
                        continue; // do not add
                    [(VPolyLine*)gp getEndPoints:&start :&end];
                }
                else
                {   start.x = end.x = pts[j].x; start.y = end.y = pts[j].y;
                }
                /* point is no edge point of gp -> add */
                if ( (Diff(pts[j].x, start.x) + Diff(pts[j].y, start.y) > 10.0*TOLERANCE) &&
                     (Diff(pts[j].x, end.x)   + Diff(pts[j].y, end.y)   > 10.0*TOLERANCE) )
                    (*ppArray)[iCnt++] = pts[j];
                else
                {   (*ppArray)[0] = (*ppArray)[1] = pts[j];
                    if (Diff(pt.x, pts[j].x) <= TOLERANCE)
                    {   free(pts);
                        return -2; // on
                    }
                    tangential = YES;
                }
            }
        }
        if (pts)
            free(pts);
    }
    if (!iCnt)
    {	free(*ppArray);
        *ppArray = NULL;
    }
    else if (tangential)
        return -1;
    return iCnt;
}

- (float)sqrDistanceGraphic:g
{   int		i;
    float	dist, distance = MAXCOORD;

    for (i=[list count]-1; i>=0; i--)
    {	id	gp = [list objectAtIndex:i];

        if ( (dist=[gp sqrDistanceGraphic:g]) < distance)
            distance = dist;
    }
    return distance;
}

- (float)distanceGraphic:g
{   float	distance;

    distance = [self sqrDistanceGraphic:g];
    return sqrt(distance);
}

- (BOOL)isPointInside:(NSPoint)p
{   int	iVal=0;

    return ( !(iVal=[self isPointInsideOrOn:p dist: TOLERANCE]) || iVal == 1 ) ? NO : YES;
}

/*- (BOOL)isPointInside:(NSPoint)p
{
    return ([self isPointInside:p dist:TOLERANCE]) ? YES : NO;
}*/

- (int)isPointInsideOrOn:(NSPoint)p
{
    return [self isPointInsideOrOn:p dist:TOLERANCE];
}

/* return
 * 0 = outside
 * 1 = on
 * 2 = inside
 */
#if 0 // new !!!!!!
- (int)isPointInsideOrOn:(NSPoint)p dist:(float)dist
{   int		i, cnt, leftCnt=0, *info, horicontals = 0, hStart_upDown = -1;
    BOOL	hStart = NO;
    NSPoint	p0, p1, *pts = NULL;
    VLine	*line;
    NSRect	bRect;

    bRect = [self coordBounds];

    line = [VLine line];
    p0.x = bRect.origin.x - 2000.0; p1.x = bRect.origin.x + bRect.size.width+2000.0;
    p0.y = p1.y = p.y;

    [line setVertices:p0 :p1];
    if ( !(cnt = [self intersectionsForPtInside:&pts :&info with:line]) )
        return 0; // outside

    hStart = NO;
    for (i=0; i<cnt; i++)	/* count points left of p */
    {
        if (Diff(pts[i].x, p.x) <= dist) // *7.0
        {   free(pts);
            free(info);
            return 1; // on
        }
        if (pts[i].x < p.x)
        {    leftCnt++;
            if (hStart == NO && (info[i] == INFO_HORICONTAL_UP || info[i] == INFO_HORICONTAL_DOWN))
            {   hStart = YES;
                hStart_upDown = info[i];
            }
            else if (hStart == YES && (info[i] == INFO_HORICONTAL_UP || info[i] == INFO_HORICONTAL_DOWN))
            {   hStart = NO;
                if (hStart_upDown != info[i])
                    horicontals++; // only changes from up to down change the even/odd creteria
            }
        }
        else
            break;
    }
    if (pts)
        free(pts);
    if (info)
        free(info);

    if (hStart == YES)
        return 1; // on

    /* odd number of points on the left and p is inside the polygon */
    /* inside : outside */
    return ((Even(horicontals) && Even(leftCnt)) || (!Even(horicontals) && !Even(leftCnt))) ? 0 : 2;
}
#endif

//#if 0 // original
/* return
 * 0 = outside
 * 1 = on
 * 2 = inside
 */
- (int)isPointInsideOrOn:(NSPoint)p dist:(float)dist
{   int		i, cnt, leftCnt=0, iByBreak = 0;
    NSPoint	p0, p1, *pts = NULL;
    VLine	*line;
    NSRect	bRect;

    bRect = [self coordBounds];
//    if ( !NSPointInRect(p , bRect) )
//        return 0;

    line = [VLine line];
    p0.x = bRect.origin.x - 2000.0; p1.x = bRect.origin.x + bRect.size.width+2000.0;
    p0.y = p1.y = p.y;

    for (i=2; i<16; i++)	/* we need to find a position where we don't hit an edge */
    {
        [line setVertices:p0 :p1];
        p0.y = p1.y = p.y + ((i%2) ? (-i*(TOLERANCE/2.0)) : (i*(TOLERANCE/2.0))); // i*(TOLERANCE/2.0);
        if ( !(cnt = [self intersectionsForPtInside:&pts with:line :p]) && i==2 )
            return 0;
        if ( i == 2 && cnt == -2 )
        {
            /* we checked all horicontals in this range if point is on ! */
            free(pts);
            return 1; // on
        }
        if ( cnt && Even(cnt) )
        {   if ( i != 2 )
                iByBreak = i;// /2.0;
            break;
        }
        if (pts)
        {   free(pts); pts = NULL;
        }
    }
    if ( cnt <= 1 || !Even(cnt) )	/* we hit an edge */
    {	if (cnt > 0)
            NSLog(@"VPath, -isPointInside: hit edge! p: %.3f %.3f cnt: %i", p.x, p.y, cnt);
        if (pts)
            free(pts);
        return 0;
    }
    sortPointArray(pts, cnt, p0);	/* sort from left to right */

// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    /* p is on the border of the polygon
     */
    for (i=0; i<cnt; i++)	// on polygon 
        if ( Diff(pts[i].x, p.x) <= dist+(iByBreak*TOLERANCE) ) // *7.0
        {   free(pts);
            return 1;
//            return 0; // on meens not inside !
        }

    for (i=0; i<cnt && pts[i].x < p.x; i++)	/* count points left of p */
        leftCnt++;

    if (pts)
        free(pts);

    /* p is at the top or at the bottom of the polygon
     */
    if ( !Even(leftCnt) && (Diff(bRect.origin.y, p.y) <= dist*1.5
                           || Diff(bRect.origin.y+bRect.size.height, p.y) <= dist*1.5) )
        return 1;
//        return 0; // on meens not inside !

    return (Even(leftCnt)) ? 0 : 2;	/* odd number of points on the left and p is inside the polygon */
}

/* return
 * 0 = outside
 * 1 = on
 * 2 = inside
 */
- (int)isPointInsideOrOn:(NSPoint)p dist:(float)dist subPath:(int)begIx :(int)endIx
{   int		i, cnt, leftCnt=0, iByBreak = 0;
    NSPoint	p0, p1, *pts = NULL;
    VLine	*line;
    NSRect	bRect;

    bRect = [self coordBoundsOfSubPath:begIx :endIx];
//    if ( !NSPointInRect(p , bRect) )
//        return 0;

    line = [VLine line];
    p0.x = bRect.origin.x - 2000.0; p1.x = bRect.origin.x + bRect.size.width+2000.0;
    p0.y = p1.y = p.y;

    for (i=2; i<16; i++)	/* we need to find a position where we don't hit an edge */
    {
        [line setVertices:p0 :p1];
        p0.y = p1.y = p.y + ((i%2) ? (-i*(TOLERANCE/2.0)) : (i*(TOLERANCE/2.0))); // i*(TOLERANCE/2.0);
        if ( !(cnt = [self intersectionsForPtInside:&pts with:line :p subPath:begIx :endIx]) && i==2 )
            return 0;
        if ( i == 2 && cnt == -2 )
        {
            /* we checked all horicontals in this range if point is on ! */
            free(pts);
            return 1; // on
        }
        if ( cnt && Even(cnt) )
        {   if ( i != 2 )
                iByBreak = i;// /2.0;
            break;
        }
        if (pts)
        {   free(pts); pts = NULL;
        }
    }
    if ( cnt <= 1 || !Even(cnt) )	/* we hit an edge */
    {	if (cnt > 0)
            NSLog(@"VPath, -isPointInside: hit edge! p: %.3f %.3f cnt: %i", p.x, p.y, cnt);
        if (pts)
            free(pts);
        return 0;
    }
    sortPointArray(pts, cnt, p0);	/* sort from left to right */

// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    /* p is on the border of the polygon
     */
    for (i=0; i<cnt; i++)	// on polygon 
        if ( Diff(pts[i].x, p.x) <= dist+(iByBreak*TOLERANCE) ) // *7.0
        {   free(pts);
            return 1;
//            return 0; // on meens not inside !
        }

    for (i=0; i<cnt && pts[i].x < p.x; i++)	/* count points left of p */
        leftCnt++;

    if (pts)
        free(pts);

    /* p is at the top or at the bottom of the polygon
     */
    if ( !Even(leftCnt) && (Diff(bRect.origin.y, p.y) <= dist*1.5
                           || Diff(bRect.origin.y+bRect.size.height, p.y) <= dist*1.5) )
        return 1;
//        return 0; // on meens not inside !

    return (Even(leftCnt)) ? 0 : 2;	/* odd number of points on the left and p is inside the polygon */
}

//#endif
#if 0
- (int)isPointInside:(NSPoint)p dist:(float)dist
{   int		i, cnt, leftCnt=0;
    NSPoint	p0, p1, *pts = NULL;
    VLine	*line;
    NSRect	bRect;

    bRect = [self coordBounds];
    if ( !NSPointInRect(p , bRect) )
        return 0;

    line = [VLine line];
    p0.x = bRect.origin.x - 2000.0; p1.x = bRect.origin.x + bRect.size.width+2000.0;
    p0.y = p1.y = p.y;

    for (i=0; i<10; i++)	/* we need to find a position where we don't hit an edge */
    {
        [line setVertices:p0 :p1];
        p0.y = p1.y = p0.y + 10.0*TOLERANCE;
        if ( !(cnt = [self getIntersections:&pts with:line]) )
            return 0;
        sortPointArray(pts, cnt, p0);	/* sort from left to right */
        if ( Even(cnt) )
            break;
    }
    if ( cnt <= 1 || !Even(cnt) )	/* we hit an edge */
    {	NSLog(@"VPath, -isPointInside: hit edge!");
        if (pts)
            free(pts);
        return 0;
    }


    /* p is on the border of the polygon
     */
    for (i=0; i<cnt; i++)	/* on polygon */
        if ( DiffPoint(pts[i], p) <= dist )
        {   free(pts);
            return 1;
        }

    for (i=0; i<cnt && pts[i].x < p.x; i++)	/* count points left of p */
        leftCnt++;

    if (pts)
        free(pts);

    /* p is at the top or at the bottom of the polygon
     */
    if ( !Even(leftCnt) && (Diff(bRect.origin.y, p.y)<=dist || Diff(bRect.origin.y+bRect.size.height, p.y)<=dist) )
        return 1;

    return (Even(leftCnt)) ? 0 : 2;	/* odd number of points on the left and p is inside the polygon */
}
#endif

/* created:  1996-10-03
 * modified: 2001-04-10
 * check for all endpoints of the path, whether a point of our Array is on an endpoint
 */
- (BOOL)pointArrayHitsCorner:(NSPoint*)pts :(int)ptsCnt
{   int	i;

    for (i=[list count]-1; i>=0; i--)
    {	id	obj = [list objectAtIndex:i];
        NSPoint	p;

        [obj getPoint:&p at:0];	/* start point */
        if (pointWithToleranceInArray(p, 0.003, pts, ptsCnt)) /* was 0.03 */
            return YES;
        [obj getPoint:&p at:3];	/* end point */
        if (pointWithToleranceInArray(p, 0.003, pts, ptsCnt)) /* was 0.03 */
            return YES;
    }

    return NO;
}

- (id)clippedWithRect:(NSRect)rect
{
    return [self clippedWithRect:rect close:NO];
}
- (id)clippedWithRect:(NSRect)rect close:(BOOL)close
{   NSMutableArray	*clipList = [NSMutableArray array];
    id			cObj;
    NSArray		*cList;
    int			i, cnt, c, cCnt;
    VPath		*path;

    /* clip objects */
    for (i=0, cnt = [list count]; i<cnt; i++)
    {
        if (!(cObj = [[list objectAtIndex:i] clippedWithRect:rect]))
            continue;
        if ([cObj isMemberOfClass:[VGroup class]])
        {
            cList = [cObj list];
            for (c=0, cCnt = [cList count]; c<cCnt; c++)
                [clipList addObject:[cList objectAtIndex:c]];
        }
        else
            [clipList addObject:cObj];
    }

    if (![clipList count])
        return nil;

    path = [VPath path];
    if (close)
    {   VRectangle	*rectangle = [VRectangle rectangle];
        NSArray		*splitList;

        [rectangle setVertices:rect.origin :NSMakePoint(rect.size.width, rect.size.height)];

        /* clip rectangle and add parts of rectangle which are inside path */
        if ( [(splitList = [rectangle getListOfObjectsSplittedFromGraphic:self]) count] > 1 )
            for (i=0; i<(int)[splitList count]; i++)
                if ( [self isPointInside:[[splitList objectAtIndex:i] pointAt:0.5]] )
                    [clipList addObject:[splitList objectAtIndex:i]];

        /* optimize */
        [path setList:clipList];
        [path sortList];
    }
    else
        [path setList:clipList];

    return path;
}

- getIntersectionsAndSplittedObjects:(NSPoint**)ppArray :(int*)iCnt with:g
{   int                 i, j, lCnt = [list count], ptsCnt = Min(100, [self numPoints]);
    NSRect              gBounds = [g bounds];
    NSMutableArray      *splitList = [NSMutableArray array], *spList = nil;
    NSAutoreleasePool   *pool = [NSAutoreleasePool new];

    *iCnt = 0;
    *ppArray = malloc(ptsCnt * sizeof(NSPoint));
//    for (i=[list count]-1; i>=0; i--)
    for (i=0; i<lCnt; i++)
    {	id      gp = [list objectAtIndex:i];
        int     cnt, oldCnt = *iCnt;
        NSRect	gpBounds = [gp bounds];
        NSPoint *pts = NULL;

        if ( gp == g )
            continue;
        // check bounds
        if ( NSIsEmptyRect(NSIntersectionRect(gBounds , gpBounds)) )
        {
            // add to splitList
            [splitList addObject:[[gp copy] autorelease]];
            continue;
        }
        /* line, arc, curve */
        if ( !(cnt = [gp getIntersections:&pts with:g]) )
            [splitList addObject:[[gp copy] autorelease]];
        else
        {   spList = [gp getListOfObjectsSplittedFrom:pts :cnt];
            if ( spList )
            {   for ( j=0; j<(int)[spList count]; j++ )
                    [splitList addObject:[spList objectAtIndex:j]];
            }
            else
                [splitList addObject:[[gp copy] autorelease]];
        }
        if ((*iCnt)+cnt >= ptsCnt)
            *ppArray = realloc(*ppArray, (ptsCnt+=cnt*2) * sizeof(NSPoint));

        for (j=0; j<cnt; j++)
        {
            if ( !pointInArray(pts[j], *ppArray, oldCnt) )
                (*ppArray)[(*iCnt)++] = pts[j];
            else
            {   NSPoint	start, end;

                if ( [gp isKindOfClass:[VLine class]] )		/* line */
                    [(VLine*)gp getVertices:&start :&end];
                else if ( [gp isKindOfClass:[VArc class]] || [gp isKindOfClass:[VCurve class]] )
                {   start = [gp pointWithNum:0];
                    end = [gp pointWithNum:MAXINT];
                }
                else if ( [gp isKindOfClass:[VRectangle class]] )
                {   NSPoint	ur, ul, size;
                    [(VRectangle*)gp getVertices:&start :&size]; // origin size
                    end = start; end.x += size.x;
                    ul = start; ul.y += size.y;
                    ur = end; ur.y += size.y;
                    if ( (Diff(pts[j].x, ul.x) + Diff(pts[j].y, ul.y) < 10.0*TOLERANCE) ||
                        (Diff(pts[j].x, ur.x) + Diff(pts[j].y, ur.y) < 10.0*TOLERANCE) )
                        continue; // do not add
                }
                else if ( [gp isKindOfClass:[VPolyLine class]] )
                {   int	k, pCnt = [(VPolyLine*)gp ptsCount], stop = 0;

                    for (k=1; k<pCnt-1; k++)
                    {   NSPoint	pt = [(VPolyLine*)gp pointWithNum:k];
                        if ( Diff(pts[j].x, pt.x) + Diff(pts[j].y, pt.y) < 10.0*TOLERANCE )
                        {   stop = 1; break; }
                    }
                    if (stop)
                        continue; // do not add
                    [(VPolyLine*)gp getEndPoints:&start :&end];
                }
                else
                {   start.x = end.x = pts[j].x; start.y = end.y = pts[j].y;
                }
                /* point is no edge point of gp -> add */
                if ( (Diff(pts[j].x, start.x) + Diff(pts[j].y, start.y) > 10.0*TOLERANCE) &&
                    (Diff(pts[j].x, end.x) + Diff(pts[j].y, end.y) > 10.0*TOLERANCE) )
                    (*ppArray)[(*iCnt)++] = pts[j];
            }
        }
        if (pts)
            free(pts);
    }

    if (!(*iCnt))
    {	free(*ppArray);
        *ppArray = NULL;
    }
    [pool release];
    if ( [splitList count] > [list count] )
        return splitList;
    return nil;
}

/* optimize list from uniteWith with same tolerance - we did not close gaps here ???
 */
- (void)optimizeList:(NSMutableArray*)olist
{   int		k, i1, i2, changeI, startIndex = 0;
    float	startDistance=MAXCOORD, d1, d2;
    float	tol = 10.0*TOLERANCE;
    NSPoint	s1, e1, s2, e2;

    if ( ![olist count] )
        return;

    for (i1 = 0; i1<(int)[olist count]-1; i1++)
    {	VGraphic	*g1 = [olist objectAtIndex:i1];
        int		closeK = -1;
	BOOL		changeDirection = NO;

        startDistance = MAXCOORD;
        changeI = i1+1;
        s1 = [g1 pointWithNum:0];
        e1 = [g1 pointWithNum:MAXINT];
        for (i2 = i1+1; i2 < (int)[olist count]; i2++)
        {   VGraphic	*g2 = [olist objectAtIndex:i2];

            s2 = [g2 pointWithNum:0];
            e2 = [g2 pointWithNum:MAXINT];
            d1 = SqrDistPoints(e1, s2); d2 = SqrDistPoints(e1, e2);
            if ( d1 < startDistance || d2 < startDistance )
            {
                if ( d2 < d1 )
                {   startDistance = d2;
                    changeDirection = YES;
                }
                else
                {   startDistance = d1;
                    changeDirection = NO;
                }
                changeI = i2;
                if ( startDistance < TOLERANCE*TOLERANCE )
                    break;
            }
        }
        closeK = changeI;
        /* if the nearest element is not the next_in_list */
        /* search until connected part end - in both directions ! */
        if (changeI != (i1+1) && changeDirection) // search backward
        {   NSPoint	prevS = e1; // first k == j == startPt

            for ( k=changeI; k >= i1+1; k-- )
            {   VGraphic	*gk;
                NSPoint		sk, ek;

                gk = [olist objectAtIndex:k];
                sk = [gk pointWithNum:0];
                ek = [gk pointWithNum:MAXINT];

                if (SqrDistPoints(prevS, ek) >= tol*tol || k == i1+1)
                {   closeK = (k == i1+1 || k == changeI) ? k : (k+1);
                    break; // end of connected part
                }
                prevS = sk;
            }

        }
        else if (changeI != (i1+1)) // search forward
        {   NSPoint	prevE = e1;

            for ( k=changeI; k < [olist count]; k++ )
            {   VGraphic	*gk;
                NSPoint		sk, ek;

                gk = [olist objectAtIndex:k];
                sk = [gk pointWithNum:0];
                ek = [gk pointWithNum:MAXINT];

                if (SqrDistPoints(prevE, sk) >= tol*tol || k == [olist count]-1)
                {   closeK = (k == [olist count]-1 || k == changeI) ? k : (k-1);
                    break; // end of connected part
                }
                prevE = ek;
            }
        }

        if ( startDistance > TOLERANCE*TOLERANCE ) /* close hole */
        {   VGraphic	*g2;
            float	dist = MAXCOORD;

            g2 = [olist objectAtIndex:( startDistance <= tol*tol ) ? changeI : startIndex];
            if ( startDistance <= tol*tol && changeDirection)
            {   s2 = [g2 pointWithNum:MAXINT];
                e2 = [g2 pointWithNum:0];
            }
            else
            {   s2 = [g2 pointWithNum:0];
                e2 = [g2 pointWithNum:MAXINT];
            }
            if ( (dist=SqrDistPoints(e1, s2)) > TOLERANCE*TOLERANCE && dist <= tol*tol )
            {	VGraphic	*lineG = [VLine line];

                [(VLine*)lineG setVertices:e1 :s2];
                [olist insertObject:lineG atIndex:i1+1];
                i1 += 1; changeI += 1; closeK += 1;
            }
            if ( startDistance > tol*tol )
            {
                /* g2 is start graphic ! if ( startDistance > tol*tol ) */
                //if ( dist > tol*tol )
                    //NSLog(@"VPath.m: -optimizeList: distance: s: %.3f %.3f e: %.3f %.3f", s1.x, s1.y, e1.x, e1.y);
                startIndex = i1+1;
            }
        }

        if ( changeI != (i1+1) && startDistance < tol*tol)
        {   int	m, insertCnt = 0, from = changeI, to = closeK;

            if (changeDirection)
            {
                for (m=to; m <= from; m++)
                {   VGraphic	*g = [olist objectAtIndex:m];

                    [g changeDirection];
                    if (m != i1+1)
                    {   [olist insertObject:g atIndex:i1+1];
                        [olist removeObjectAtIndex:m+1];
                    }
                }
            }
            else
            {   for (m=to; m >= from; m--)
                {   VGraphic	*g = [olist objectAtIndex:m+insertCnt];

                    [olist insertObject:g atIndex:i1+1];
                    insertCnt++;
                    [olist removeObjectAtIndex:m+insertCnt];
                }
            }
            if (insertCnt)
                i1 += insertCnt-1;
        }
        else if (changeDirection && startDistance < tol*tol) // else we destroy our sorted blocks !
        {   VGraphic	*g2 = [olist objectAtIndex:changeI];

            [g2 changeDirection];
        }
    }
    /* close hole from last to start element */
    if ([olist count] > 1)
    {   VGraphic	*g1=[olist objectAtIndex:[olist count]-1];
        VGraphic	*g2= [olist objectAtIndex:startIndex];
        float		dist = MAXCOORD;

        s1 = [g1 pointWithNum:0];
        e1 = [g1 pointWithNum:MAXINT];
        s2 = [g2 pointWithNum:0];
        e2 = [g2 pointWithNum:MAXINT];
        if ( (dist=SqrDistPoints(e1, s2)) > TOLERANCE*TOLERANCE && dist <= tol+tol )
        {   VGraphic	*lineG = [VLine line];

            [(VLine*)lineG setVertices:e1 :s2];
            [olist addObject:lineG];
        }
        //else if ( dist > TOLERANCE*TOLERANCE )
        //    NSLog(@"VPath.m: -optimizeList: distance 2: s: %.3f %.3f e: %.3f %.3f", s1.x, s1.y, e1.x, e1.y);
    }
    return;
}
/* unite
 * returns a new graphic or nil
 *
 * modified: 2006-01-11 2008-10-16
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
    NSPoint             gPrevE = NSZeroPoint;

    if ( ![ug isKindOfClass:[VPath class]] && ![ug isKindOfClass:[VArc class]] && ![ug isKindOfClass:[VPolyLine class]]
        && ![ug isKindOfClass:[VRectangle class]] && ![ug isKindOfClass:[VGroup class]] )
        return nil;

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

    if ( ![[ng list] count] )
        for (i=0; i<(int)[list count]; i++)
            [[ng list] addObject:[[[list objectAtIndex:i] copy] autorelease]];

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
            NSLog(@"VPath.m: -uniteWith: endIx not found !");
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
            /* correct all uStartIs behind i */
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
    for ( i=startI, listCnt = [[ng list] count]; startI != -1 && (first || i != startI); i++ )
    {	id	gThis;
        // NSPoint	gPrevE = NSZeroPoint;
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
//                            NSLog(@"VPath.m: -uniteWith: one startPt pair was currently removed");
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
        {   NSPoint	p;

            [pool release];
            /* ug is inside self -> self is ok can remove ug later */
            [ug getPoint:&p at:0.4];
            if ( [self isPointInside:p] )
                return ng;

            /* self is inside ug -> ug is it */
            [[list objectAtIndex:0] getPoint:&p at:0.4];
            if ( [(id)ug isPointInside:p] )
                return [[ug copy] autorelease];
            return nil;	// nothing to unite
        }
        [pool release];
        return nil;
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
                        [gj identicalWith:[[ng list] objectAtIndex:startIs[si]]]))
                        //(endIs[si] < listCnt &&
                        // [gj identicalWith:[[ng list] objectAtIndex:endIs[si]]])
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
                                {
                                    if ((d=SqrDistPoints(ekn, endPts[l])) < dekn)
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
                                         [gkn identicalWith:[[ng list] objectAtIndex:startIs[si]]]))
                                        //(endIs[si] < listCnt &&
                                        // [gkn identicalWith:[[ng list] objectAtIndex:endIs[si]]])
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
                                         [gkp identicalWith:[[ng list] objectAtIndex:startIs[si]]]))
                                        //(endIs[si] < listCnt &&
                                        // [gkp identicalWith:[[ng list] objectAtIndex:endIs[si]]])
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
                {   int		added = 0, from = closeK, to = j, m=0;
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
                        NSLog(@"VPath.m: -uniteWith: this should be not possible");

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

					/* here we remove this endPair from endPts */
                    /* k is our ePairs index - eI0 is our endPts/endIs index - eptCnt 1 or 2 epts */
                    /* remove endPts (1 or 2) / remove endIs (1 or 2) */
                    /* remove ePairsCnts (1) */
                    /* ePairsCnt -- */
                    if ( eptCnt == 2 )
                    {   for (m=eI0+1; m < eCnt-1; m++)
                        {   endIs[m] = endIs[m+1];
                            endPts[m] = endPts[m+1];
                        }
                        eCnt--;
                    }
                    for (m=eI0; m < eCnt-1; m++)
                    {   endIs[m] = endIs[m+1];
                        endPts[m] = endPts[m+1];
                    }
                    eCnt--;
                    for (m=k; m < ePairsCnt-1; m++)
                        ePairsCnts[m] = ePairsCnts[m+1];
                    ePairsCnt--;

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
                                NSLog(@"VPAth.m -uniteWith: not yet implemented");
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

    /* add closed shapes from splitListUg to ng */
    if (uStartIsCnt > 1 && [splitListUg count])
    {
        for (i=0; i<uStartIsCnt-1; i++)
        {
            if (uStartIs[i+1]-1 == uStartIs[i] && [splitListUg count] == 1) // only one object
            {   VGraphic	*g = [splitListUg objectAtIndex:uStartIs[i]];

                if ([g isKindOfClass:[VArc class]] && Abs([(VArc*)g angle]) == 360.0)
                    [[ng list] addObject:[splitListUg objectAtIndex:uStartIs[i]]];
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
        [self optimizeList:[ng list]];

    [pool release];

    return ng;
}

/* return self - if self is completely inside cg
 * return ug   - if cg is completely inside self
 * return the intersection path of both
 */
- (id)clippedFrom:(VGraphic*)cg
{   int			i, j, cnt, nothingRemoved = 0;
    VPath		*ng;
    NSMutableArray	*splitListG, *splitListUg;
    NSAutoreleasePool	*pool;

    if ( ![cg isKindOfClass:[VPath class]] && ![cg isKindOfClass:[VArc class]] && ![cg isKindOfClass:[VPolyLine class]]
        && ![cg isKindOfClass:[VRectangle class]] && ![cg isKindOfClass:[VGroup class]] )
        return NO;

    ng = [VPath path];
    [ng setColor:[self color]];
    [ng setFilled:filled optimize:NO];
    [ng setWidth:0.0];
    [ng setSelected:NO];

    /* split self */
    if ( (splitListG = [self getListOfObjectsSplittedFromGraphic:cg]) )
        [ng setList:splitListG optimize:NO];

    pool = [NSAutoreleasePool new];

    if ( ![[ng list] count] )
        for (i=0; i<(int)[list count]; i++)
            [[ng list] addObject:[[[list objectAtIndex:i] copy] autorelease]];

    /* split cg */
    if ( !(splitListUg = [cg getListOfObjectsSplittedFromGraphic:self]) )
    {
        splitListUg = [NSMutableArray array];
        if ( [cg isKindOfClass:[VPath class]] )
            for (i=0; i<(int)[[(VPath*)cg list] count]; i++)
                [splitListUg addObject:[[[[(VPath*)cg list] objectAtIndex:i] copy] autorelease]];
        else
            [splitListUg addObject:[[cg copy] autorelease]];
    }

    /* cg is'nt a path and not splitted now there are two possibilities
     * self is in cg or cg is in self else -> nothing to unite - NO
     */
    if ( ![cg isKindOfClass:[VPath class]] && [splitListUg count] == 1 && ![cg isKindOfClass:[VGroup class]])
    {   NSPoint	p;
        [pool release];

        /* return self - if self is completely inside cg
         * return cg   - if cg is completely inside self
         */
        /* cg is inside self */
        [cg getPoint:&p at:0.4];
        if ( [self isPointInside:p] )
            return [[cg copy] autorelease];

        /* self is inside cg -> self is it */
        [[list objectAtIndex:0] getPoint:&p at:0.4];
        if ( [(id)cg isPointInside:p] )
            return ng;
        return NO;	/* nothing to clip */
    }

    /* now remove the graphictiles from cg wich are outside
     * if no tile is removed -> NO
     */
    {   HiddenArea	*hiddenArea = [HiddenArea new];
        
        /* return self - if self is completely inside cg
         * return cg   - if cg is completely inside self
         */
        if ( ![hiddenArea removeGraphics:splitListUg outside:self] )
            nothingRemoved++;

        /* now remove the graphic tiles from ng(self splitted) wich are outside or on cg */
        if ( ![hiddenArea removeGraphics:[ng list] outside:cg] && nothingRemoved )
        {   [hiddenArea release];
            [pool release];
            return ng; // self comletly inside cg
        }

        /* add graphics from splitListUg to ng list */
        for (i=0; i<(int)[splitListUg count]; i++)
            [[ng list] addObject:[[[splitListUg objectAtIndex:i] copy] autorelease]];

        /* we must remove identical graphics in list */
        cnt = ([[ng list] count]-[splitListUg count]);

        /* we check only added objects !!!!!!!!!! */
        for (i=[[ng list] count]-1; i >= cnt; i--)
        {   VGraphic	*g = [[ng list] objectAtIndex:i];

            for (j=0; j<(int)[[ng list] count]; j++)
            {   VGraphic	*g2 = [[ng list] objectAtIndex:j];

                if ( g2 == g )
                    continue;
                if ( [g2 identicalWith:g] )
                {
                    [[ng list] removeObject:g];
                    break;
                }
            }
        }

        [hiddenArea removeSingleGraphicsInList:[ng list] :[cg bounds]];
        [hiddenArea release];
    }

    [pool release];
    return ng;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [super encodeWithCoder:aCoder];
    [aCoder encodeObject:list]; // [aCoder encodeValuesOfObjCTypes:"@", &list];
    [aCoder encodeValuesOfObjCTypes:"c", &isDirectionCCW];
    [aCoder encodeValuesOfObjCTypes:"i", &filled]; // 2002-07-07
    [aCoder encodeObject:fillColor];
    [aCoder encodeObject:endColor];
    [aCoder encodeValuesOfObjCTypes:"ff", &graduateAngle, &stepWidth];
    //[aCoder encodeValuesOfObjCTypes:"{NSPoint=ff}", &radialCenter];
    [aCoder encodePoint:radialCenter];          // 2012-01-08
}
- (id)initWithCoder:(NSCoder *)aDecoder
{   int		version;

    [super initWithCoder:aDecoder];
    version = [aDecoder versionForClassName:@"VPath"];
    list = [[aDecoder decodeObject] retain];    // [aDecoder decodeValuesOfObjCTypes:"@", &list];
    if ( version < 1 )
        [aDecoder decodeValuesOfObjCTypes:"c", &filled];
    else if (version < 2) // 07.04.98
        [aDecoder decodeValuesOfObjCTypes:"cc", &filled, &isDirectionCCW];
    else // 2002-07-07
    {   [aDecoder decodeValuesOfObjCTypes:"c", &isDirectionCCW];
        [aDecoder decodeValuesOfObjCTypes:"i", &filled];
        fillColor = [[aDecoder decodeObject] retain];
        endColor  = [[aDecoder decodeObject] retain];
        [aDecoder decodeValuesOfObjCTypes:"ff", &graduateAngle , &stepWidth];
        //[aDecoder decodeValuesOfObjCTypes:"{NSPoint=ff}", &radialCenter];
        radialCenter = [aDecoder decodePoint];  // 2012-01-08
    }

    if ( version < 2 )
    {   UPath	fillUPath;

        [aDecoder decodeValuesOfObjCTypes:"ii", &fillUPath.num_ops, &fillUPath.num_pts];
        if ( fillUPath.num_ops )	// old
        {
            fillUPath.ops = malloc((fillUPath.num_ops+10) * sizeof(char));
            fillUPath.pts = malloc((fillUPath.num_pts+10) * sizeof(float));
            [aDecoder decodeArrayOfObjCType:"c" count:fillUPath.num_ops at:fillUPath.ops];
            [aDecoder decodeArrayOfObjCType:"f" count:fillUPath.num_pts at:fillUPath.pts];
            free(fillUPath.ops);
            free(fillUPath.pts);
        }
    }

    selectedObject = -1;
    graduateDirty = YES;
    graduateList = nil;

    return self;
}

/* archiving with property list
 */
- (id)propertyList
{   NSMutableDictionary	*plist = [super propertyList];

    [plist setObject:propertyListFromArray(list)                forKey:@"list"];
    if (filled)
        [plist setObject:propertyListFromInt(filled)            forKey:@"filled"];
    // FIXME: it is not reliable to compare with "!=", it needs "isEqual:"
    //if (fillColor != [NSColor blackColor])
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
{
    [super initFromPropertyList:plist inDirectory:directory];
    list = arrayFromPropertyList([plist objectForKey:@"list"], directory, [self zone]);
    filled = [plist intForKey:@"filled"];
    if (!filled && [plist objectForKey:@"filled"])
        filled = 1;
    // Note: VPath, VArc, VRectangle
    //       if fillColor == nil, we may have an old file where color == fillColor
    if (!(fillColor = colorFromPropertyList([plist objectForKey:@"fillColor"], [self zone])))
    {   [self setFillColor:[NSColor blackColor]/*[color copy]*/];
        //[self setFillColor:[color copy]]; // loads old file format with color only
    }
    if (!(endColor  = colorFromPropertyList([plist objectForKey:@"endColor"],  [self zone])))
        [self setEndColor:[NSColor blackColor]];
    graduateAngle = [plist floatForKey:@"graduateAngle"];
    if ( !(stepWidth = [plist floatForKey:@"stepWidth"]))
        stepWidth = 7.0;	// default;
    if ([plist objectForKey:@"radialCenter"])
        radialCenter = pointFromPropertyList([plist objectForKey:@"radialCenter"]);
    else
        radialCenter = NSMakePoint(0.5, 0.5);	// default

    selectedObject = -1;
    graduateDirty = YES;
    graduateList = nil;
    return self;
}


- (void)dealloc
{
    [fillColor release];
    [endColor  release];
    [list release];
    list = nil;
    if (graduateList)
    {   [graduateList release];
        graduateList = nil;
    }
    [super dealloc];
}

@end
