/* VRectangle.m
 * 2-D Rectangle object
 *
 * Copyright (C) 1996-2010 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1996-09-17
 * modified: 2010-07-17 (-transform added, -scale: scales width correctly with negative scales (flip))
 *           2010-03-03 (-copy setDirectionCCW, -pathRepresentation edges build with r, not radius)
 *           2006-02-08
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
#include "VRectangle.h"
#include "VPath.h"
#include "HiddenArea.h"
#include "VArc.h"
#include "../App.h"
#include "../DocView.h"
#include "../DocWindow.h"
#include "../Inspectors.h"

@interface VRectangle(PrivateMethods)
- (void)setParameter;
@end

@implementation VRectangle

/*
 * This sets the class version so that we can compatibly read
 * old VGraphic objects out of an archive.
 */
+ (void)initialize
{
    [VRectangle setVersion:5];
}

+ (VRectangle*)rectangle
{
    return [[[VRectangle allocWithZone:[self zone]] init] autorelease];
}
+ (VRectangle*)rectangleWithOrigin:(NSPoint)o size:(NSSize)s
{   VRectangle	*r = [[[VRectangle allocWithZone:[self zone]] init] autorelease];

    [r setVertices:o :NSMakePoint(s.width, s.height)];
    return r;
}

/* initialize
 */
- init
{
    [self setParameter];
    fillColor = [[NSColor blackColor] retain];
    endColor  = [[NSColor blackColor] retain];
    graduateAngle = 0.0;
    stepWidth = 7.0;
    radialCenter = NSMakePoint(0.5, 0.5);
    graduateList = nil;
    graduateDirty = YES;
    coordBounds = NSZeroRect;
    return [super init];
}

/* deep copy
 *
 * created:  2001-02-15
 * modified: 2012-01-06
 */
- copy
{   VRectangle  *rectangle = [[VRectangle allocWithZone:[self zone]] init];

    [rectangle setSelected:isSelected];
    [rectangle setLocked:NO];
    [rectangle setFilled:filled];
    [rectangle setWidth:width];
    [rectangle setColor:color];
    [rectangle setVertices:origin :size];
    [rectangle setRadius:radius];
    [rectangle setFillColor:fillColor];
    [rectangle setEndColor:endColor];
    [rectangle setGraduateAngle:graduateAngle];
    [rectangle setStepWidth:stepWidth];
    [rectangle setRadialCenter:radialCenter];
    [rectangle setRotAngle:rotAngle];
    return rectangle;
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
    return [NSString stringWithFormat:@"VRectangle: %f %f %f %f", origin.x, origin.y, size.x, size.y];
}
- (NSString*)title		{ return @"Rectangle"; }

/* whether we are a path object
 * eg. line, polyline, arc, curve, rectangle, path
 * group is not a path object because we don't know what is inside!
 */
- (BOOL)isPathObject	{ return YES; }

- (float)length
{
    return (size.x + size.y) * 2.0;
}

#define CREATEEVENTMASK NSLeftMouseDraggedMask|NSLeftMouseDownMask|NSLeftMouseUpMask|NSPeriodicMask
- (BOOL)create:(NSEvent *)event in:(DocView*)view
{   NSRect	viewBounds, gridBounds, drawBounds;
    NSPoint	start, last, gridPoint, drawPoint, rSize, p, lastPoint = NSZeroPoint, hitPoint;
    id		window = [view window];
    VRectangle 	*drawRectangleGraphic;
    BOOL	ok = YES, dragging = NO, hitEdge = NO, inTimerLoop = NO;
    float	grid = 1.0 / [view scaleFactor];	// minimum accepted length
    int		windowNum = [event windowNumber];
    //	BOOL	alternate = [NXApp alternate];

    [[(App*)NSApp inspectorPanel] loadGraphic:self];	/* set the values of the inspector to self */

    start = [view convertPoint:[event locationInWindow] fromView:nil];	/* convert window to view coordinates */
    hitPoint = start;
    hitEdge = [view hitEdge:&hitPoint spare:self];	// snap to point
    gridPoint = [view grid:start];			// set on grid
    if ( hitEdge &&
         ((gridPoint.x == start.x && gridPoint.y == start.y)  ||
          (SqrDistPoints(hitPoint, start) < SqrDistPoints(gridPoint, start))) )
        start = hitPoint; // we took the nearer one if we got a hitPoint
    else
        start = gridPoint;
    viewBounds = [view visibleRect];			/* get the bounds of the view */
    [view lockFocus];					/* and lock the focus on view */

    [self setVertices:start :start];
    drawRectangleGraphic = [[self copy] autorelease];
    [drawRectangleGraphic setColor:[NSColor lightGrayColor]];
    gridBounds = [self extendedBoundsWithScale:[view scaleFactor]];

    last = start;

    event = [NSApp nextEventMatchingMask:CREATEEVENTMASK untilDate:[NSDate distantFuture] inMode:NSEventTrackingRunLoopMode dequeue:YES];
    StartTimer(inTimerLoop);
    /* now entering the tracking loop
     */
    while ( ((!dragging && [event type] != NSLeftMouseDown) ||
              (dragging && [event type] != NSLeftMouseUp  )) &&
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
            if ( ([event type] == NSLeftMouseDragged)&&(!dragging) &&
                 (Diff(origin.x, drawPoint.x) > 3.0*grid || Diff(origin.y, drawPoint.y) > 3.0*grid) )
                dragging = YES;
            if (dragging)
            {	[view scrollPointToVisible:drawPoint];
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

            p.x = Min(start.x, gridPoint.x);
            p.y = Min(start.y, gridPoint.y);
            rSize.x = Diff(gridPoint.x, start.x);
            rSize.y = Diff(gridPoint.y, start.y);
            [self setVertices:p :rSize];
            gridBounds = [self extendedBoundsWithScale:[view scaleFactor]];	// get bounds of the grid line

            p.x = Min(start.x, drawPoint.x);
            p.y = Min(start.y, drawPoint.y);
            rSize.x = Diff(drawPoint.x, start.x);
            rSize.y = Diff(drawPoint.y, start.y);
            [drawRectangleGraphic setVertices:p :rSize];
            drawBounds = [drawRectangleGraphic extendedBoundsWithScale:[view scaleFactor]];
            gridBounds  = NSUnionRect(drawBounds, gridBounds);

            if ( NSContainsRect(viewBounds, gridBounds) )		// line inside view ?
            {   [drawRectangleGraphic drawWithPrincipal:view];
                [self drawWithPrincipal:view];
            }
            else
                drawPoint = gridPoint = start;				// else set line invalid

            [window flushWindow];
        }
        event = [NSApp nextEventMatchingMask:CREATEEVENTMASK untilDate:[NSDate distantFuture] inMode:NSEventTrackingRunLoopMode dequeue:YES];
    }
    StopTimer(inTimerLoop);

    last = gridPoint;

    if ( fabs(last.x-start.x) <= grid && fabs(last.y-start.y) <= grid )	/* no length -> not valid */
        ok = NO;
    else if ( (!dragging && [event type]==NSLeftMouseDown)||(dragging && [event type]==NSLeftMouseUp) )
    {
        /* double click or out of window -> not valid */
        if ([event clickCount] > 1 || [event windowNumber] != windowNum)
            ok = NO;
        else
            ok = NSMouseInRect(gridPoint , viewBounds , NO);
    }

    if ([event type] == NSAppKitDefined || [event type] == NSSystemDefined)
        ok = NO;

    [view unlockFocus];

    if (!ok)
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
        [view display];
        return NO;
    }
    dirty = YES;
    [view cacheGraphic:self];

    return YES;
}

/* set our vertices
 */
- (void)setVertices:(NSPoint)theOrigin :(NSPoint)theSize
{
    origin = theOrigin;
    size = theSize;
    coordBounds = NSZeroRect;
    dirty = YES;
    graduateDirty = YES;
}

/*
 * return our vertices
 */
- (void)getVertices:(NSPoint*)theOrigin :(NSPoint*)theSize
{
    *theOrigin = origin;
    *theSize = size;
}

- (float)rotAngle
{
    return rotAngle;
}

- (void)setRotAngle:(float)angle
{
    rotAngle = angle;
    coordBounds = NSZeroRect;
    dirty = YES;
    graduateDirty = YES;
}

- (void)setRadius:(float)r
{
    radius = r;
    if ( radius > Min(Abs(size.x), Abs(size.y))/2.0 )
        radius = Min(Abs(size.x), Abs(size.y))/2.0;
    coordBounds = NSZeroRect;
    dirty = YES;
    graduateDirty = YES;
}
- (float)radius
{
    return radius;
}

- (void)setSize:(NSSize)value
{
    size.x = value.width;
    size.y = value.height;
    [self setRadius:radius];
    coordBounds = NSZeroRect;
    dirty = YES;
    graduateDirty = YES;
}
- (NSSize)size
{
    return NSMakeSize(size.x, size.y);
}

/* return a path representation of the arc
 * returns an autoreleased object
 * modified: 2010-03-03 (edges build with r, not radius)
 *           2005-11-22 (max radius = 1/2 size, skip zero lines)
 */
- (VPath*)pathRepresentation
{   VPath		*pathG = [VPath path];
    VLine		*line;
    VArc		*arc;
    int			i, j;
    BOOL		ccw = [self isDirectionCCW];
    NSPoint		p0, p1, c, pts[5];
    float		a = (ccw) ? 90.0 : -90.0, r = radius;

    [pathG setDirectionCCW:ccw];

    pts[0] = pts[4] = origin;
    pts[1].x = origin.x + size.x; pts[1].y = origin.y;
    pts[2].x = origin.x + size.x; pts[2].y = origin.y + size.y;
    pts[3].x = origin.x; pts[3].y = origin.y + size.y;
    if (size.x < r*2.0 || size.y < r*2.0)
        r = Min(size.x, size.y) / 2.0;

    for ( i=(ccw)?0:4; (ccw)?i<4:i; (ccw)?i++:i-- )
    {
        j = (ccw) ? i+1 : i-1;
        p0.x = pts[i].x + ((pts[i].x<pts[j].x) ? r : ((pts[i].x>pts[j].x) ? -r : 0));
        p0.y = pts[i].y + ((pts[i].y<pts[j].y) ? r : ((pts[i].y>pts[j].y) ? -r : 0));
        p1.x = pts[j].x + ((pts[i].x<pts[j].x) ? -r : ((pts[i].x>pts[j].x) ? r : 0));
        p1.y = pts[j].y + ((pts[i].y<pts[j].y) ? -r : ((pts[i].y>pts[j].y) ? r : 0));
        if ( r == 0.0 || p0.x != p1.x || p0.y != p1.y )
        {   line = [VLine line];
            [line setVertices:p0 :p1];
            [line setColor:color];
            [[pathG list] addObject:line];
        }
        if ( r )
        {
            c.x = pts[j].x + ((pts[j].x>pts[0].x) ? -r : r);
            c.y = pts[j].y + ((pts[j].y>pts[0].y) ? -r : r);
            arc = [VArc arc];
            [arc setCenter:c start:p1 angle:a];
            [arc setColor:color];
            [[pathG list] addObject:arc];
        }
    }

    [pathG setFilled:filled optimize:NO]; // must set filled first else fillColor become color
    [pathG setWidth:width]; // must set width first else color become fillColor
    [pathG setColor:color];
    [pathG setFillColor:fillColor];
    [pathG setEndColor:endColor];
    [pathG setStepWidth:stepWidth];
    if ( rotAngle )
        [pathG setAngle:-rotAngle withCenter:origin];
    [pathG setGraduateAngle:graduateAngle]; // else the color will be rotated wrong
    [pathG setRadialCenter:radialCenter];

    return pathG;
}

- (BOOL)isPointInside:(NSPoint)p
{   int	iVal=0;

    if ( !(iVal=[self isPointInsideOrOn:p]) || iVal == 1 )
        return NO;
    return YES;
}

/* created: 26.09.96
 * returns YES if p is inside us (must be full and filled)
 * 0 = outside
 * 1 = on
 * 2 = inside
 */
- (int)isPointInsideOrOn:(NSPoint)p
{
    if ( !radius && !rotAngle )
    {
        if ( filled && p.x >= origin.x && p.x <= origin.x+size.x && p.y >= origin.y && p.y <= origin.y+size.y )
        {
            if ( Diff(p.x,origin.x) <= TOLERANCE || Diff(p.y,origin.y) <= TOLERANCE
                || Diff(p.x,origin.x+size.x) <= TOLERANCE || Diff(p.y,origin.y+size.y) <= TOLERANCE )
                return 1;
            return 2;
        }
        else
            return 0;
    }
    return [[self pathRepresentation] isPointInsideOrOn:p];
}

- (BOOL)filled
{
    return filled;
}
- (void)setFilled:(BOOL)flag
{
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
- (NSColor*)endColor 			{ return endColor; }

- (void)setGraduateAngle:(float)a	{ graduateAngle = a; dirty = YES; graduateDirty = YES; }
- (float)graduateAngle			{ return graduateAngle; }

- (void)setStepWidth:(float)sw		{ stepWidth = sw; dirty = YES; graduateDirty = YES; }
- (float)stepWidth			{ return stepWidth; }

- (void)setRadialCenter:(NSPoint)rc	{ radialCenter = rc; dirty = YES; graduateDirty = YES; }
- (NSPoint)radialCenter			{ return radialCenter; }

/* created:   05.04.98
 * modified:  
 * parameter: p the point
 *            t 0 <= t <= 1
 * purpose:   get a point on the rectangle at t
 *            (only used to display direction - t is allways 0)
 */
- (NSPoint)pointAt:(float)t
{
    return origin;
}

/* created: 05.04.98
 * purpose: return the gradient (delta x, y, z) at t
 * used to display direction
 */
- (NSPoint)gradientAt:(float)t
{   NSPoint	p, cp = NSMakePoint(0.0, 0.0);
    BOOL	ccw = [self isDirectionCCW];

    p.x = (ccw) ? size.x : 0.0;
    p.y = (ccw) ? 0 : size.y;
    vhfRotatePointAroundCenter(&p, cp, rotAngle);

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

- (void)transform:(NSAffineTransform*)matrix
{   NSSize  s = NSMakeSize(width, width);

    s = [matrix transformSize:s];
    width = (Abs(s.width) + Abs(s.height)) / 2;
    origin = [matrix transformPoint:origin];
    size   = [matrix transformPoint:size];
    if (size.x < 0.0)
    {   origin.x += size.x;
        size.x = -size.x;
    }
    if (size.y < 0.0)
    {   origin.y += size.y;
        size.y = -size.y;
    }
    dirty = graduateDirty = YES;
}

- (void)scale:(float)x :(float)y withCenter:(NSPoint)cp
{
    width *= (Abs(x)+Abs(y))/2.0;
    origin.x = ScaleValue(origin.x, cp.x, x);
    if ( x < 0.0)
        origin.x += size.x * x;
    origin.y = ScaleValue(origin.y, cp.y, y);
    if ( y < 0.0)
        origin.y += size.y * y;
    size.x *= Abs(x);
    size.y *= Abs(y);
    coordBounds = NSZeroRect;

    dirty = graduateDirty = YES;
}

- (void)mirrorAround:(NSPoint)p
{   NSPoint	d = NSMakePoint( 0.0, size.y);

    origin.y = p.y - (origin.y - p.y);
    if ( rotAngle )
        vhfRotatePointAroundCenter(&d, NSMakePoint(0.0, 0.0), -rotAngle);
    origin.x -= d.x;
    origin.y -= d.y;
    rotAngle = -rotAngle;
    coordBounds = NSZeroRect;

    dirty = YES;
    if (!graduateDirty && graduateList)
    {   int	i;

        for (i=[graduateList count]-1; i>=0; i--)
            [(VGraphic*)[graduateList objectAtIndex:i] mirrorAround:p];
    }
}

/* created:   15.07.98
 * modified: 
 * parameter: x, y	the angles to rotate in x/y direction
 *            p		the point we have to rotate around
 * purpose:   draw the graphic rotated around p with x and y
 */
- (void)drawAtAngle:(float)angle withCenter:(NSPoint)cp in:view
{
    [[self pathRepresentation] drawAtAngle:angle withCenter:cp in:view];
}

/* created:  15.07.98
 * modified: 
 * parameter: x, y	the angles to rotate in x/y direction
 *            cp	the point we have to rotate around
 * purpose:   rotate the graphic around cp with x and y
 */
- (void)setAngle:(float)angle withCenter:(NSPoint)cp
{
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
    vhfRotatePointAroundCenter(&origin, cp, -angle);
    rotAngle -= angle;
    if ( rotAngle>=360.0 )
        rotAngle -= 360.0;
    if ( rotAngle<=-360.0 )
        rotAngle += 360.0;
    coordBounds = NSZeroRect;
    dirty = YES;
    if (!graduateDirty && graduateList)
    {   int	i;

        for (i=[graduateList count]-1; i>=0; i--)
            [(VGraphic*)[graduateList objectAtIndex:i] setAngle:angle withCenter:cp];
    }
}

/*
 * draws the rectangle
 */
- (void)drawWithPrincipal:principal
{
    if ( !radius && !rotAngle && filled < 2 )
    {
        [NSBezierPath setDefaultLineCapStyle: NSRoundLineCapStyle];
        [NSBezierPath setDefaultLineJoinStyle:NSRoundLineJoinStyle];

        if ( filled )
        {   NSColor	*col = fillColor;

            /* colorSeparation */
            if (!VHFIsDrawingToScreen() && [principal separationColor])
                col = [self separationColor:fillColor]; // get individual separation color

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

            [NSBezierPath fillRect:NSMakeRect(origin.x, origin.y, size.x, size.y)];
        }
        if ( width > 0.0 || !filled || Diff(size.x, 0) < 500*TOLERANCE || Diff(size.y, 0) < 500*TOLERANCE )
        {   NSColor	*oldColor = nil;
            float	defaultWidth = [NSBezierPath defaultLineWidth];

            if ( filled && (Diff(size.x, 0) < 500*TOLERANCE || Diff(size.y, 0) < 500*TOLERANCE) )
                defaultWidth = 0.1 / [principal scaleFactor];   // make visible what actually is invisible

            if (!VHFIsDrawingToScreen() && [principal separationColor])
            {   NSColor	*sepColor = [self separationColor:color];   // get individual separation color

                oldColor = [color retain];
                [self setColor:sepColor];
            }
            [super drawWithPrincipal:principal];	// set color
            [NSBezierPath setDefaultLineWidth:(width > 0.0) ? width : defaultWidth];
            [NSBezierPath strokeRect:NSMakeRect(origin.x, origin.y, Max( 0.01, size.x), Max( 0.01, size.y))];
            [NSBezierPath setDefaultLineWidth:defaultWidth];

            if (!VHFIsDrawingToScreen() && [principal separationColor])
            {   [self setColor:oldColor];
                [oldColor release];
            }
        }
    }
    else if (filled <= 1)
    {   [[self pathRepresentation] drawWithPrincipal:principal];
        return;
    }
    else // filled is 2 or 3 or 4
    {   VPath	*pathRep = [self pathRepresentation];

        if (graduateDirty || !graduateList)
        {
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
        }
        else if (graduateList && !graduateDirty)
        {   int		i, gCnt = [graduateList count];
            BOOL	antialias = VHFAntialiasing();

            /* draw graduateList */
            VHFSetAntialiasing(NO);
            for (i=0; i<gCnt; i++)
                [(VGraphic*)[graduateList objectAtIndex:i] drawWithPrincipal:principal];
            if (antialias) VHFSetAntialiasing(antialias);
        }
        else
            NSLog(@"VRectangle: -drawWithPrincipal filling confusion\n");

        if (width) // stroke
        {   [pathRep setFilled:0 optimize:NO];
            [pathRep drawWithPrincipal:principal];
        }
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
    {   NSPoint	p, ll, ur;

        ll = ur = origin;

        p.x = origin.x+size.x;
        p.y = origin.y;
        if (rotAngle != 0.0)
            vhfRotatePointAroundCenter(&p, origin, rotAngle);
        ll.x = Min(ll.x, p.x); ll.y = Min(ll.y, p.y);
        ur.x = Max(ur.x, p.x); ur.y = Max(ur.y, p.y);

        p.x = origin.x+size.x;
        p.y = origin.y+size.y;
        if (rotAngle != 0.0)
            vhfRotatePointAroundCenter(&p, origin, rotAngle);
        ll.x = Min(ll.x, p.x); ll.y = Min(ll.y, p.y);
        ur.x = Max(ur.x, p.x); ur.y = Max(ur.y, p.y);

        p.x = origin.x;
        p.y = origin.y+size.y;
        if (rotAngle != 0.0)
            vhfRotatePointAroundCenter(&p, origin, rotAngle);
        ll.x = Min(ll.x, p.x); ll.y = Min(ll.y, p.y);
        ur.x = Max(ur.x, p.x); ur.y = Max(ur.y, p.y);

        coordBounds.origin = ll;
        coordBounds.size.width  = ur.x-ll.x;
        coordBounds.size.height = ur.y-ll.y;
    }
    return coordBounds;
}

/*
 * Returns the bounds with the given rotation.
 */
- (NSRect)boundsAtAngle:(float)angle withCenter:(NSPoint)cp
{   NSPoint	p, ll, ur;
    NSRect	bRect;

    p = origin;
    p = vhfPointRotatedAroundCenter(p, -angle, cp);
    ll = ur = p;

    p.x = origin.x + size.x;
    p.y = origin.y;
    if (rotAngle != 0.0)
        p = vhfPointRotatedAroundCenter(p, rotAngle, origin);
    p = vhfPointRotatedAroundCenter(p, -angle, cp);
    ll.x = Min(ll.x, p.x); ll.y = Min(ll.y, p.y);
    ur.x = Max(ur.x, p.x); ur.y = Max(ur.y, p.y);

    p.x = origin.x + size.x;
    p.y = origin.y + size.y;
    if (rotAngle != 0.0)
        vhfPointRotatedAroundCenter(p, rotAngle, origin);
    vhfPointRotatedAroundCenter(p, -angle, cp);
    ll.x = Min(ll.x, p.x); ll.y = Min(ll.y, p.y);
    ur.x = Max(ur.x, p.x); ur.y = Max(ur.y, p.y);

    p.x = origin.x;
    p.y = origin.y + size.y;
    if (rotAngle != 0.0)
        vhfPointRotatedAroundCenter(p, rotAngle, origin);
    vhfPointRotatedAroundCenter(p, -angle, cp);
    ll.x = Min(ll.x, p.x); ll.y = Min(ll.y, p.y);
    ur.x = Max(ur.x, p.x); ur.y = Max(ur.y, p.y);

    bRect.origin = ll;
    bRect.size.width  = Max(ur.x - bRect.origin.x, 1.0);
    bRect.size.height = Max(ur.y - bRect.origin.y, 1.0);
    return bRect;
}

/* modified: 2005-10-18 (rounded corners added)
 */
- (NSPoint)appendToBezierPath:(NSBezierPath*)bPath currentPoint:(NSPoint)currentPoint
{   int		i, j;
    BOOL	ccw = [self isDirectionCCW];
    NSPoint	p0, p1, c, pts[5];
    float	a = (ccw) ? 90.0 : -90.0, r = radius, begAngle;

    pts[0] = pts[4] = origin;
    pts[1].x = origin.x + size.x; pts[1].y = origin.y;
    pts[2].x = origin.x + size.x; pts[2].y = origin.y + size.y;
    pts[3].x = origin.x; pts[3].y = origin.y + size.y;
    if (size.x < r*2.0 || size.y < r*2.0)
        r = 0.0;

    for ( i=(ccw)?0:4; (ccw)?i<4:i; (ccw)?i++:i-- )
    {
        j = (ccw) ? i+1 : i-1;
        p0.x = pts[i].x + ((pts[i].x<pts[j].x) ? r : ((pts[i].x>pts[j].x) ? -r : 0));
        p0.y = pts[i].y + ((pts[i].y<pts[j].y) ? r : ((pts[i].y>pts[j].y) ? -r : 0));
        p1.x = pts[j].x + ((pts[i].x<pts[j].x) ? -r : ((pts[i].x>pts[j].x) ? r : 0));
        p1.y = pts[j].y + ((pts[i].y<pts[j].y) ? -r : ((pts[i].y>pts[j].y) ? r : 0));

        if (rotAngle != 0.0)
            p0 = vhfPointRotatedAroundCenter(p0, rotAngle, origin);

        if ( (!i || i == 4) && (Diff(currentPoint.x, p0.x) > 0.01 || Diff(currentPoint.y, p0.y) > 0.01) )
            [bPath moveToPoint:p0];

        if (rotAngle != 0.0)
            p1 = vhfPointRotatedAroundCenter(p1, rotAngle, origin);
        [bPath lineToPoint:p1];

        if ( r )
        {
            c.x = pts[j].x + ((pts[j].x>pts[0].x) ? -radius : radius);
            c.y = pts[j].y + ((pts[j].y>pts[0].y) ? -radius : radius);
            if (rotAngle != 0.0)
                c = vhfPointRotatedAroundCenter(c, rotAngle, origin);

            begAngle = vhfAngleOfPointRelativeCenter(p1, c);

            [bPath appendBezierPathWithArcWithCenter:c radius:radius
                                          startAngle:begAngle endAngle:begAngle+a clockwise:(a < 0.0)];
        }
    }

    return NSMakePoint(LARGENEG_COORD, LARGENEG_COORD);
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
 * parameter: pt_num number of vertices
 *            p      the new position in
 * purpose:   Sets a vertice to a new position.
 *            If it is a edge move the vertices with it
 *            Default must be the last point!
 */
- (void)movePoint:(int)pt_num to:(NSPoint)p
{   NSPoint	pc, pt;

    [self getPoint:pt_num :&pc];
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
{   NSPoint	p, d, cp = NSMakePoint(0, 0), oldSize = size;

    [self getPoint:pt_num :&p];
    p.x += pt.x; p.y += pt.y;
    d = pt;
    vhfRotatePointAroundCenter(&d, cp, -rotAngle);
    switch (pt_num)
    {
        case PT_LL:
            size.x = (size.x - d.x > 0.0) ? (size.x - d.x) : (0.0);
            size.y = (size.y - d.y > 0.0) ? (size.y - d.y) : (0.0);
            if (oldSize.x - d.x < 0.0)
                d.x = d.x - Abs(oldSize.x - d.x);
            if (oldSize.y - d.y < 0.0)
                d.y = d.y - Abs(oldSize.y - d.y);
            vhfRotatePointAroundCenter(&d, cp, rotAngle);
            origin.x += d.x;
            origin.y += d.y;
            break;
        case PT_UL:
            size.x = (size.x - d.x > 0.0) ? (size.x - d.x) : (0.0);
            size.y = (size.y + d.y > 0.0) ? (size.y + d.y) : (0.0);
            d.y = 0.0;
            if (oldSize.x - d.x < 0.0)
                d.x = d.x - Abs(oldSize.x - d.x);
            vhfRotatePointAroundCenter(&d, cp, rotAngle);
            origin.x += d.x;
            origin.y += d.y;
            break;
        case PT_LR:
            size.x = (size.x + d.x > 0.0) ? (size.x + d.x) : (0.0);
            size.y = (size.y - d.y > 0.0) ? (size.y - d.y) : (0.0);
            d.x = 0.0;
            if (oldSize.y - d.y < 0.0)
                d.y = d.y - Abs(oldSize.y - d.y);
            vhfRotatePointAroundCenter(&d, cp, rotAngle);
            origin.x += d.x;
            origin.y += d.y;
            break;
        case PT_UR:
        default:
            size.x += d.x;
            size.y += d.y;
            if (size.x <= 0)
                size.x = 0.0;
            if (size.y <= 0)
                size.y = 0.0;
    }
    coordBounds = NSZeroRect;
    dirty = YES;
    graduateDirty = YES;
}

/* The pt argument holds the relative point change. */
- (void)moveBy:(NSPoint)pt
{
    origin.x += pt.x;
    origin.y += pt.y;
    coordBounds = NSZeroRect;
    dirty = YES;
    if (!graduateDirty && graduateList)
    {   int	i;
        for (i=[graduateList count]-1; i>=0; i--)
            [[graduateList objectAtIndex:i] moveBy:pt];
    }
}

- (int)numPoints
{
    return PTS_RECTANGLE;
}

/* Given the point number, return the point.
 */
- (NSPoint)pointWithNum:(int)pt_num
{   NSPoint	p;

    switch (pt_num)
    {
        default:    // 2008-02-13 default changed from UL to LL
        case PT_LL:	p = origin; break;
        case PT_UL:	p.x = origin.x; p.y = origin.y + size.y; break;
        case PT_LR:	p.x = origin.x + size.x; p.y = origin.y; break;
        case PT_UR:	p.x = origin.x + size.x; p.y = origin.y + size.y; break;
    }
    if (rotAngle)
        vhfRotatePointAroundCenter(&p, origin, rotAngle);
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
        if (selectedKnob != i && !NSIsEmptyRect(NSIntersectionRect(hitRect , knobRect)))
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
            [self setSelected:YES];
            return YES;
        }
    }
    return NO;
}

- (BOOL)hit:(NSPoint)p fuzz:(float)fuzz
{   NSRect	bRect;

    if ( rotAngle )
        vhfRotatePointAroundCenter(&p, origin, -rotAngle);
    bRect.origin.x = origin.x - fuzz;
    bRect.origin.y = origin.y - fuzz;
    bRect.size.width  = size.x + 2.0*fuzz;
    bRect.size.height = size.y + 2.0*fuzz;
    if ( NSPointInRect(p, bRect) )
    {   int     i, j;
        BOOL    ccw = [self isDirectionCCW];
        NSPoint p0, p1, c, pts[5];
        float   a = (ccw) ? 90.0 : -90.0, r = radius;
        float   begAngles[4] = {270.0, 0.0, 90.0, 180.0};

        pts[0] = pts[4] = origin;
        pts[1].x = origin.x + size.x; pts[1].y = origin.y;
        pts[2].x = origin.x + size.x; pts[2].y = origin.y + size.y;
        pts[3].x = origin.x; pts[3].y = origin.y + size.y;
        if (size.x < r*2.0 || size.y < r*2.0)
            r = 0.0;

        if ( !Prefs_SelectByBorder && filled && !r )
            return YES;
        if ( !Prefs_SelectByBorder && filled && r )
            return [[self pathRepresentation] hit:p fuzz:fuzz];

        for ( i=(ccw)?0:4; (ccw)?i<4:i; (ccw)?i++:i-- )
        {
            j = (ccw) ? i+1 : i-1;
            p0.x = pts[i].x + ((pts[i].x<pts[j].x) ? r : ((pts[i].x>pts[j].x) ? -r : 0));
            p0.y = pts[i].y + ((pts[i].y<pts[j].y) ? r : ((pts[i].y>pts[j].y) ? -r : 0));
            p1.x = pts[j].x + ((pts[i].x<pts[j].x) ? -r : ((pts[i].x>pts[j].x) ? r : 0));
            p1.y = pts[j].y + ((pts[i].y<pts[j].y) ? -r : ((pts[i].y>pts[j].y) ? r : 0));

            if ( sqrDistancePointLine(&p0, &p1, &p) <= fuzz*fuzz )
                return YES;

            if ( r )
            {
                c.x = pts[j].x + ((pts[j].x>pts[0].x) ? -radius : radius);
                c.y = pts[j].y + ((pts[j].y>pts[0].y) ? -radius : radius);

                if ( distancePointArc(p, c, r, begAngles[i], a) <= fuzz )
                    return YES;
            }
        }

/*
        p0 = origin;
        p1 = NSMakePoint(origin.x+size.x, origin.y);
        p2 = NSMakePoint(origin.x+size.x, origin.y+size.y);
        p3 = NSMakePoint(origin.x, origin.y+size.y);


        if ( sqrDistancePointLine(&p0, &p1, &p) <= fuzz*fuzz ||
             sqrDistancePointLine(&p1, &p2, &p) <= fuzz*fuzz ||
             sqrDistancePointLine(&p2, &p3, &p) <= fuzz*fuzz ||
             sqrDistancePointLine(&p3, &p0, &p) <= fuzz*fuzz )
            return YES;
*/
    }
    return NO;
}

/* created: 1998-04-07
 */
- (void)setDirectionCCW:(BOOL)ccw
{
    isDirectionCCW = ccw;
    dirty = YES;
}

- (BOOL)isDirectionCCW
{
    return isDirectionCCW;
}

- (void)changeDirection
{
    isDirectionCCW = (isDirectionCCW) ? 0 : 1;
    dirty = YES;
}

/*
 * return a path representing the outline of us
 * modified: 2010-03-03 (setDirectionCCW:)
 *           2005-09-27
 */
- contour:(float)w
{
    if ( !radius && filled )
    {   VRectangle	*nr = [VRectangle rectangle];
        NSPoint		o, s;
        float		r;

        [nr setWidth:0.0];
        [nr setColor:color];
        [nr setRotAngle:rotAngle];
        [nr setFilled:NO];
        r = (w+width) / 2.0;	// the amount of growth
        o.x = origin.x - r;   o.y = origin.y - r;
        s.x = size.x + 2.0*r; s.y = size.y + 2.0*r;
        if ( s.x < 0.0 || s.y < 0.0 )
            return nil;
        o = vhfPointRotatedAroundCenter(o, rotAngle, origin);
        [nr setDirectionCCW: isDirectionCCW];
        [nr setVertices:o :s];
        return nr;
    }
    return [[self pathRepresentation] contour:w];
}

/* flatten rectangle
 */
- flattenedObject
{
    return [[self pathRepresentation] flattenedObject];
}

- (NSMutableArray*)getListOfObjectsSplittedFromGraphic:g
{
    return [[self pathRepresentation] getListOfObjectsSplittedFromGraphic:g];
}

/* modified: 
 * return a list of objects which are the result of intersecting us
 * the objects are sorted beginning at start 
 */
- (NSArray*)getListOfObjectsSplittedFrom:(NSPoint*)pArray :(int)iCnt
{
    return [[self pathRepresentation] getListOfObjectsSplittedFrom:pArray :iCnt];
}

- (NSMutableArray*)getListOfObjectsSplittedAtPoint:(NSPoint)pt
{
    return [[self pathRepresentation] getListOfObjectsSplittedAtPoint:pt];
}

/* return all the intersection points with g
 * start and end points of the arc are included
 * the intersection points are sorted from the start of the arc
 */
- (int)getIntersections:(NSPoint**)ppArray with:g
{
    return [[self pathRepresentation] getIntersections:ppArray with:g];
}

/* get intersections with line segment
 */
- (int)intersectLine:(NSPoint*)pArray :(NSPoint)pl0 :(NSPoint)pl1
{
    return [[self pathRepresentation] intersectLine:pArray :pl0 :pl1];
}

- (float)sqrDistanceLine:(NSPoint)pl0 :(NSPoint)pl1
{   int		i;
    float	distance = MAXCOORD, dist; // -1.0
    NSPoint	pt, p0 = origin, p1 = origin;

    /* line intersect rectangle */
    if ( ([self isPointInsideOrOn:pl0] && ![self isPointInsideOrOn:pl1]) ||
         ([self isPointInsideOrOn:pl1] && ![self isPointInsideOrOn:pl0]) )
        return 0.0;

    for (i=0; i<4; i++)
    {
        switch (i)
        {   case 0: p1.x += size.x; break; // p0 = p1 = origin; 
            case 1: p0 = p1; p1.y += size.y; break;
            case 2: p0 = p1; p1.x -= size.x; break;
            default: p0 = p1; p1.y -= size.y;
        }
        // cut lines -> 0.0
        if ( vhfIntersectLines(&pt, p0, p1, pl0, pl1))
            return 0.0;
        
        // we check only if begin/end of both lines near enought of other line
        if ((dist=pointOnLineClosestToPoint(p0, p1, pl0, &pt)) < distance) // beg of l2 to self
            distance = dist;
        if ((dist=pointOnLineClosestToPoint(p0, p1, pl1, &pt)) < distance) // end of l2 to self
            distance = dist;
        if ((dist=pointOnLineClosestToPoint(pl0, pl1, p0, &pt)) < distance) // beg of self to l2
            distance = dist;
        if ((dist=pointOnLineClosestToPoint(pl0, pl1, p1, &pt)) < distance) // end of self to l2
            distance = dist;
    }
    return distance;
}

- (float)sqrDistanceGraphic:g :(NSPoint*)pg1 :(NSPoint*)pg2
{   int		i;
    float	distance = MAXCOORD, dist; // -1.0
    NSPoint	pl0 = origin, pl1 = origin, p1, p2;
    VLine	*line = [VLine line];

    for (i=0; i<4; i++)
    {
        switch (i)
        {   case 0: pl1.x += size.x; break; // p0 = p1 = origin; 
            case 1: pl0 = pl1; pl1.y += size.y; break;
            case 2: pl0 = pl1; pl1.x -= size.x; break;
            default: pl0 = pl1; pl1.y -= size.y;
        }

        [line setVertices:pl0 :pl1];
        if ((dist=[g sqrDistanceGraphic:line :&p2 :&p1]) < distance)
        {
            distance = dist;
            *pg2 = p2;
            *pg1 = p1;
        }
    }
    return distance;
}

- (float)sqrDistanceGraphic:g
{
    if (!radius && !rotAngle && [g isKindOfClass:[VLine class]])
    {   NSPoint	p0, p1;
        [(VLine*)g getVertices:&p0 :&p1];
        return [self sqrDistanceLine:p0 :p1];
    }
    if ([g isKindOfClass:[VPath class]] || [g isKindOfClass:[VGroup class]] ||
        [g isKindOfClass:[VPolyLine class]] || [g isKindOfClass:[VCurve class]] ||
        [g isKindOfClass:[VArc class]] || [g isKindOfClass:[VRectangle class]] || [g isKindOfClass:[VLine class]])
        return [[self pathRepresentation] sqrDistanceGraphic:g];
    else if ([g isMemberOfClass:[VWeb class]])
    {   NSPoint	mOri = [(VWeb*)g origin];
        return [self sqrDistanceLine:mOri :mOri];
    }
    else if ([g isMemberOfClass:[VMark class]])
    {   NSPoint	mOri = [(VMark*)g origin];
        float	d1 = [self sqrDistanceLine:NSMakePoint(mOri.x-5.0, mOri.y) :NSMakePoint(mOri.x+5.0, mOri.y)];
        float	d2 = [self sqrDistanceLine:NSMakePoint(mOri.x, mOri.y-5.0) :NSMakePoint(mOri.x, mOri.y+5.0)];
        return Min(d1, d2);
    }
    else if ([g isKindOfClass:[VSinking class]])
    {   NSPoint	ori;
        float	dia = [(VSinking*)g d2];
        VArc	*arcG = [VArc arc];

        ori = [g pointWithNum:0];
        [arcG setCenter:ori start:NSMakePoint(ori.y, ori.x+dia/2.0) angle:360.0];
        return [[self pathRepresentation] sqrDistanceGraphic:arcG];
    }
    else if ([g isKindOfClass:[VImage class]] || [g isKindOfClass:[VText class]])
    {	NSRect		bounds = [g coordBounds];
        VRectangle	*rect = [VRectangle rectangle];
        [rect setVertices:bounds.origin :NSMakePoint(bounds.size.width, bounds.size.height)];
        return [[self pathRepresentation] sqrDistanceGraphic:rect];
    }
    else if ([g isKindOfClass:[VTextPath class]])
        return [[self pathRepresentation] sqrDistanceGraphic:[g path]]; // [g pathRepresentation] time !
    else
    {   NSLog(@"Rect, distance with unknown class!");
        return -1.0;
    }
    return -1.0;
}

- (float)distanceGraphic:g
{   float	distance;

    distance = [self sqrDistanceGraphic:g];
    return sqrt(distance);
}

/* used to clip other objects
 */
- (NSArray*)clip:obj
{   NSRect	rect;

    rect.origin = origin;
    rect.size.width = size.x; rect.size.height = size.y;
    return [obj clippedWithRect:rect];
}

/* used to be clipped by a rectangle
 */
- (id)clippedWithRect:(NSRect)rect
{
    return [[self pathRepresentation] clippedWithRect:rect];
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
            NSLog(@"VRectangle.m: -uniteWith: endIx not found !");
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
    for ( i=startI, listCnt = [[ng list] count]; startI != -1 && (first || i != startI); i++ )
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
//                            NSLog(@"VRectangle.m: -uniteWith: one startPt pair was currently removed");
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
                        [gj identicalWith:[[ng list] objectAtIndex:startIs[si]]]))
                         // || (endIs[si] < listCnt &&
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
                                         [gkn identicalWith:[[ng list] objectAtIndex:startIs[si]]]))
                                    // || (endIs[si] < listCnt &&
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
                                    // || (endIs[si] < listCnt &&
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
                        NSLog(@"VRectangle.m: -uniteWith: this should be not possible");

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
                                NSLog(@"VRectangle.m -uniteWith: not yet implemented");
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

/* created: 2001-02-15
 */
- (BOOL)identicalWith:(VGraphic*)g
{   NSPoint	o, s;

    if ( ![g isKindOfClass:[VRectangle class]] )
        return NO;

    [(VRectangle*)g getVertices:&o :&s];

    if ( Diff(origin.x, o.x) <= TOLERANCE && Diff(origin.y, o.y) <= TOLERANCE &&
        Diff(size.x, s.x) <= TOLERANCE && Diff(size.y, s.y) <= TOLERANCE )
        return YES;
    return NO;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [super encodeWithCoder:aCoder];
    //[aCoder encodeValuesOfObjCTypes:"{NSPoint=ff}{NSPoint=ff}", &origin, &size];
    [aCoder encodePoint:origin];            // 2012-01-08
    [aCoder encodePoint:size];  // size is actually a point !
    [aCoder encodeValuesOfObjCTypes:"f", &radius];
    [aCoder encodeValuesOfObjCTypes:"ic", &filled, &isDirectionCCW]; // 2002-07-07
    [aCoder encodeValuesOfObjCTypes:"f", &rotAngle];
    // 2002-07-07
    [aCoder encodeObject:fillColor];
    [aCoder encodeObject:endColor];
    [aCoder encodeValuesOfObjCTypes:"ff", &graduateAngle, &stepWidth];
    //[aCoder encodeValuesOfObjCTypes:"{NSPoint=ff}", &radialCenter];
    [aCoder encodePoint:radialCenter];      // 2012-01-08
}
- (id)initWithCoder:(NSCoder *)aDecoder
{   int	version;

    [super initWithCoder:aDecoder];
    version = [aDecoder versionForClassName:@"VRectangle"];
    if ( version < 3 )
        [aDecoder decodeValuesOfObjCTypes:"{ff}{ff}", &origin, &size];
    else
    {   //[aDecoder decodeValuesOfObjCTypes:"{NSPoint=ff}{NSPoint=ff}", &origin, &size];
        origin = [aDecoder decodePoint];    // 2012-01-08
        size   = [aDecoder decodePoint];
    }
    [aDecoder decodeValuesOfObjCTypes:"f", &radius];
    if ( version<1 )
        [aDecoder decodeValuesOfObjCTypes:"c", &filled];
    else if (version<4)	/* 07.04.98 */
        [aDecoder decodeValuesOfObjCTypes:"cc", &filled, &isDirectionCCW];
    else // 2002-07-07
        [aDecoder decodeValuesOfObjCTypes:"ic", &filled, &isDirectionCCW];
    if ( version>1 )	/* 03.11.99 */
        [aDecoder decodeValuesOfObjCTypes:"f", &rotAngle];
    if (version<4)	// 2000-09-28
    {   UPath	fillUPath;

        [aDecoder decodeValuesOfObjCTypes:"ii", &fillUPath.num_ops, &fillUPath.num_pts];
        if ( fillUPath.num_ops )
        {
            fillUPath.ops = malloc((fillUPath.num_ops) * sizeof(char));
            fillUPath.pts = malloc((fillUPath.num_pts) * sizeof(float));
            [aDecoder decodeArrayOfObjCType:"c" count:fillUPath.num_ops at:fillUPath.ops];
            [aDecoder decodeArrayOfObjCType:"f" count:fillUPath.num_pts at:fillUPath.pts];
            free(fillUPath.ops);
            free(fillUPath.pts);
        }
    }
    else // 2002-07-07
    {   fillColor = [[aDecoder decodeObject] retain];
        endColor = [[aDecoder decodeObject] retain];
        [aDecoder decodeValuesOfObjCTypes:"ff", &graduateAngle , &stepWidth];
        //[aDecoder decodeValuesOfObjCTypes:"{NSPoint=ff}", &radialCenter];
        radialCenter = [aDecoder decodePoint];  // 2012-01-08
    }
    [self setParameter];
    graduateDirty = YES;
    graduateList = nil;

    return self;
}

/* archiving with property list
 */
- (id)propertyList
{   NSMutableDictionary	*plist = [super propertyList];

    [plist setObject:propertyListFromNSPoint(origin)            forKey:@"origin"];
    [plist setObject:propertyListFromNSPoint(size)              forKey:@"size"];
    if (radius)
        [plist setObject:propertyListFromFloat(radius)          forKey:@"radius"];
    if (rotAngle)
        [plist setObject:propertyListFromFloat(rotAngle)        forKey:@"rotAngle"];
    if (filled)
        [plist setObject:propertyListFromInt(filled)            forKey:@"filled"];
    if (fillColor != [NSColor blackColor])
        [plist setObject:propertyListFromNSColor(fillColor)     forKey:@"fillColor"];
    if (endColor != [NSColor blackColor])
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
    origin = pointFromPropertyList([plist objectForKey:@"origin"]);
    size   = pointFromPropertyList([plist objectForKey:@"size"]);
    radius   = [plist floatForKey:@"radius"];
    rotAngle = [plist floatForKey:@"rotAngle"];
    filled   = [plist intForKey:@"filled"];
    if (!filled && [plist objectForKey:@"filled"])
        filled = 1;
    if (!(fillColor = colorFromPropertyList([plist objectForKey:@"fillColor"], [self zone])))
        [self setFillColor:[NSColor blackColor]/*[color copy]*/];
    if (!(endColor = colorFromPropertyList([plist objectForKey:@"endColor"], [self zone])))
        [self setEndColor:[NSColor blackColor]];
    graduateAngle = [plist floatForKey:@"graduateAngle"];
    if ( !(stepWidth = [plist floatForKey:@"stepWidth"]))
        stepWidth = 7.0;	// default;
    if ([plist objectForKey:@"radialCenter"])
        radialCenter = pointFromPropertyList([plist objectForKey:@"radialCenter"]);
    else
        radialCenter = NSMakePoint(0.5, 0.5);	// default
    [self setParameter];
    graduateDirty = YES;
    graduateList = nil;
    return self;
}


- (void)dealloc
{
    if (graduateList)
    {   [graduateList release];
        graduateList = nil;
    }
    [fillColor release];
    [endColor release];
    [super dealloc];
}

@end
