/* VArc.m
 * 2-D Arc object
 *
 * Copyright (C) 1996-2012 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1996-03-13
 * modified: 2012-01-20 (-intersectArc:::: use special tolerance to compare angles)
 *           2011-07-11 (-sqrDistance...: all corrected or new)
 *           2011-03-11 (-contour: build outline of stroke width + 0 distance)
 *           2010-06-11 (-getListOfObjectsSplittedFrom:: r2, SqrDistPoints() casted to double)
 *           2010-06-11 (-intersectLine::: dx, dy, underTheSqrt casted to double)
 *           2010-05-29 (-parallelObject:::: calculation of c with cast to double - work on Apple too)
 *           2009-09-16 (-parallelObject::::)
 *           2008-08-27 2008-10-16 (-getListOfObjectsSplittedFrom...)
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
#include <VHFShared/vhf2DFunctions.h>
#include "../App.h"
#include "VArc.h"
#include "VCurve.h"
#include "VLine.h"
#include "VMark.h"
#include "VPath.h"
#include "HiddenArea.h"
#include "../DocView.h"
#include "../DocWindow.h"
#include "../Inspectors.h"		// Prefs..., loadGraphic

#define	CalcRadius() 	sqrt((center.x-start.x)*(center.x-start.x)+(center.y-start.y)*(center.y-start.y))

//float distancePointArc(const NSPoint p, const NSPoint cp, float r, float ba, float angle);

/* modified: 09.11.96
 */
#if 0
float distancePointArc(NSPoint pt, NSPoint cp, float r, float ba, float angle)
{   float	dist;		// the distance to the full circle
    float	dx, dy, c;
    float	an;		// angle of point
    NSPoint	p0, pa;
    float	da, db;		// distances to endpoints
    float	ea = ba + angle;

    /* we need positive angles with ea > ba */
    if (angle < 0.0)
    {   float	v; v=ba; ba = ea; ea = v;}
    if (ba < 0.0) ba += 360.0;
    if (ba >= 360.0) ba -= 360.0;
    ea = ba + Abs(angle);

    dx = pt.x - cp.x; dy = pt.y - cp.y;
    c = sqrt(dx*dx+dy*dy);
    dist = Diff(r, c);	/* distance to full circle */

    if (Diff(ba, ea) >= 360.0)	/* this is a full arc */
        return dist;

    /* compare angle of p */
    an = vhfAngleOfPointRelativeCenter(pt, cp);
    if (an < ba) an += 360.0;
    if (an >= ba && an <= ea)	/* we are inside the angles */
        return dist;

    /* distance to endpoints */
    p0.x = cp.x + r; p0.y = cp.y;
    pa = vhfPointAngleFromRefPoint(cp, p0, ba);
    da = SqrDistPoints(pa, pt);
    pa = vhfPointAngleFromRefPoint(cp, p0, ea);
    db = SqrDistPoints(pa, pt);

    return sqrt((da < db) ? da : db);	/* distance to endpoint */
}
#endif

/*
 * created:  2002-09-13
 * modified: 2002-09-13
 *
 * purpose:   get the distance between a points and a line without the sqrt
 *            means sqrt(of the return value) is the real distance
 *            iPoint holds the point on the line nearest to point
 * parameter: arc, point, intersection
 * return:    sqr distance point/line
 */
#if 0
float pointOnArcClosestToPoint(NSPoint cp, float r, float ba, float angle, NSPoint point, NSPoint *iPoint)
{   NSPoint	pArray[2], s, pa, s0;
    VArc	*arc = [VArc arc];
    float	ea = ba + angle;

    /* we need positive angles with ea > ba */
    if (angle < 0.0)
    {    float	v; v=ba; ba = ea; ea = v;}
    if (ba < 0.0) ba += 360.0;
    if (ba >= 360.0) ba -= 360.0;
       ea = ba + Abs(angle);

    s0.x = cp.x + r; s0.y = cp.y;
    s = vhfPointAngleFromRefPoint(cp, s0, ba);
    [arc setCenter:cp start:s angle:Abs(angle)];
    /* line from center to point cut arc */
    if ([arc intersectLine:pArray :cp :point])
    {
        *iPoint = pArray[0];
        return SqrDistPoints(pArray[0], point);
    }
    else
    {   float	da, db;

        /* distance to endpoints */
        da = SqrDistPoints(s, point);
        pa = vhfPointAngleFromRefPoint(cp, s0, ea);
        db = SqrDistPoints(pa, point);

        *iPoint = (da < db) ? s : pa;
        return (da < db) ? da : db;	/* distance to endpoint */
    }
}
#endif

@interface VArc(PrivateMethods)
- (void)setParameter;
@end

@implementation VArc

/*
 * This sets the class version so that we can compatibly read
 * old VGraphic objects out of an archive.
 */
+ (void)initialize
{
    [VArc setVersion:5];
}

+ (VArc*)arc
{
    return [[[VArc allocWithZone:[self zone]] init] autorelease];
}
+ (VArc*)arcWithCenter:(NSPoint)p radius:(float)r filled:(BOOL)flag
{   VArc	*arc = [self arc];

    [arc setCenter:p start:NSMakePoint(p.x+r, p.y) angle:360.0];
    [arc setFilled:flag];
    return arc;
}

/* initialize
 */
- init
{
    [self setParameter];

    start.x = 20.0; start.y = 10.0;
    angle = 360.0;
    // [self calcAddedValues];
    radius = 10.0;
    begAngle = 0.0;
    end = start;
    center.x = center.y = 10.0;
    fillColor = [[NSColor blackColor] retain];
    endColor = [[NSColor blackColor] retain];
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
 * modified: 
 */
- copy
{   VArc    *arc = [[[self class] allocWithZone:[self zone]] init];

    [arc setFilled:filled];
    [arc setWidth:width];
    [arc setSelected:isSelected];
    [arc setLocked:NO];
    [arc setColor:color];
    [arc setFillColor:fillColor];
    [arc setEndColor:endColor];
    [arc setGraduateAngle:graduateAngle];
    [arc setStepWidth:stepWidth];
    [arc setRadialCenter:radialCenter];
    [arc setCenter:center start:start angle:angle];

    return arc;
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
    return [NSString stringWithFormat:@"VArc: center:%f %f radius:%f angle:%f start:%f %f end:%f %f", center.x, center.y, radius, angle, start.x, start.y, end.x, end.y];
}
- (NSString*)title		{ return @"Arc"; }

/* whether we are a path object
 * eg. line, polyline, arc, curve, rectangle, path
 * group is not a path object because we don't know what is inside!
 */
- (BOOL)isPathObject	{ return YES; }

- (float)length
{
    return Abs(2.0 * Pi * radius * angle/360.0);
}

/* created: 1998-10-12
 */
- (NSPoint)center
{
    return center;
}

/* calculate arc from begP to endP, use same center
 *
 * we take the average of c.y
 * Sqr(e.x-c.x) + Sqr(e.y-c.y) = Sqr(s.x-c.x) + Sqr(s.y-c.y)
 * -> c.y = ...
 * modified: 2010-05-29 (calculation of c: cast to double to make it work well on Apple)
 */
- parallelObject:(NSPoint)begP :(NSPoint)endP :(NSPoint)newBeg :(NSPoint)newEnd
{   VArc    *arc = [[self copy] autorelease];
    float   ba, ea, an;
    NSPoint c = center, s = newBeg, e = newEnd;

    if ( Diff(e.y, s.y) > Diff(e.x, s.x) )  // new radius y > new radius x
    {   double  cx = center.x, sx = newBeg.x, sy = newBeg.y, ex = newEnd.x, ey = newEnd.y;

        //c.y = (Sqr(e.x-c.x)-Sqr(s.x-c.x)-Sqr(s.y)+Sqr(e.y)) / (2.0*e.y-2.0*s.y);
        //c.y = (float)( (Sqr((double)e.x-(double)c.x) - Sqr((double)s.x-(double)c.x)
        //               -Sqr((double)s.y) + Sqr((double)e.y)) / (2.00*(double)e.y-2.00*(double)s.y) );
        c.y = (float)( (Sqr(ex-cx) - Sqr(sx-cx) - Sqr(sy) + Sqr(ey)) / (2.00*ey-2.00*sy) );
    }
    else if ( Diff(e.y, s.y) > TOLERANCE || Diff(e.x, s.x) > TOLERANCE )
    {   double  cy = center.y, sx = newBeg.x, sy = newBeg.y, ex = newEnd.x, ey = newEnd.y;

        //c.x = (Sqr(e.y-c.y)-Sqr(s.y-c.y)-Sqr(s.x)+Sqr(e.x)) / (2.0*e.x-2.0*s.x);  // buggy on Apple
        //c.x = (float)( (Sqr((double)e.y-(double)c.y) - Sqr((double)s.y-(double)c.y)
        //               -Sqr((double)s.x) + Sqr((double)e.x)) / (2.00*(double)e.x-2.00*(double)s.x) );
        c.x = (float)( (Sqr(ey-cy) - Sqr(sy-cy) - Sqr(sx) + Sqr(ex)) / (2.00*ex-2.00*sx) );
    }
    else
    {
        /* radius nearly 0 */
        if ( SqrDistPoints(s, c) <= (2.0*TOLERANCE)*(2.0*TOLERANCE) ||
             SqrDistPoints(e, c) <= (2.0*TOLERANCE)*(2.0*TOLERANCE) )
        {   VLine   *line = [VLine lineWithPoints:s :e]; // build simply a line from newBeg to newEng

            [line setWidth:[arc width]];
            [line setColor:[arc color]];
            return line;
        }
        /* build Full Arc */
        [arc setCenter:c start:newBeg angle:360.0];
        return arc;
        //return nil; // s == e - only correct with a full arc and this is not possible here -> r will become 0
        //NSLog(@"er:%f sr:%f", sqrt(Sqr(e.x-c.x)+Sqr(e.y-c.y)), sqrt(Sqr(s.x-c.x)+Sqr(s.y-c.y)));
    }

    ba = vhfAngleOfPointRelativeCenter(newBeg, c);
    ea = vhfAngleOfPointRelativeCenter(newEnd, c);
    if (angle >= 0.0)
    {   if (ea <= ba) ea += 360.0;
        an = ea - ba;
    }
    else
    {	if (ba <= ea) ba += 360.0;
        an = ea - ba;
    }

    /* If angles are extremely different we just place a line from start to end.
     * This may happen if the passed beg/end points are twisted
     * or the arc is so small that start/end point ends up heigher than center.
     * FIXME: maybe we should check if the radius is small enough ?
     *        maybe also check if s/e switched the quadrant compared to start/end
     *        (ex: start.y < center.y but s.y > c.y) ?
     */
    if ( Diff(angle, an) > 50.0 )
    {   float   dx, dy, newDx, newDy;
        /*VLine   *line = [VLine lineWithPoints:s :e];

        [line setWidth:[arc width]];
        [line setColor:[arc color]];
        return line;*/

        dx = endP.x - begP.x; dy = endP.y - begP.y;
        newDx = newEnd.x - newBeg.x; newDy = newEnd.y - newBeg.y;

        if ( (dx > 0.0 && newDx < 0.0) || (dx < 0.0 && newDx > 0.0) ||
             (dy > 0.0 && newDy < 0.0) || (dy < 0.0 && newDy > 0.0) ||
             SqrDistPoints(s, c) <= (2.0*TOLERANCE)*(2.0*TOLERANCE) ||
             SqrDistPoints(e, c) <= (2.0*TOLERANCE)*(2.0*TOLERANCE) )
        {   VLine   *line = [VLine lineWithPoints:s :e];

            [line setWidth:[arc width]];
            [line setColor:[arc color]];
            return line;
        }

        /* hack: if angles are extremely different we invert the created arc
         * this may happen if the passed beg/end points are twisted
         * or arc is so small that start/end point ends up heigher than center
         * in latter case, this doesn't work !
         */
        /*float	dx, newDx, newDy, dy;

        dx = endP.x - begP.x; dy = endP.y - begP.y;
        newDx = newEnd.x - newBeg.x; newDy = newEnd.y - newBeg.y;
        if ( (dx > 0.0 && newDx < 0.0) || (dx < 0.0 && newDx > 0.0)
            || (dy > 0.0 && newDy < 0.0) || (dy < 0.0 && newDy > 0.0) )
        {   (an > 0) ? (an = -(360 - an)) : (an = 360 + an); }*/
    }

    [arc setCenter:c start:s angle:an];
    return arc;
}

/*
 * changes the direction of the arc
 */
- (void)changeDirection
{   NSPoint	p;

    angle = -angle;
    p = start;
    start = end;
    end = p;
    begAngle = vhfAngleOfPointRelativeCenter(start, center);
    dirty = YES;

    //vhfRotatePointAroundCenter(&start, center, angle);
    //angle = -angle;
    //[self calcAddedValues];
}

/* created: 04.01.95
 * purpose: return the gradient (delta x, y) of the arc at t (0 <= t <= 1)
 */
- (NSPoint)gradientAt:(float)t
{   NSPoint	p, arcP, d;

    [self getPoint:&arcP at:t];

    d.x = arcP.x - center.x;
    d.y = arcP.y - center.y;

    if ( angle > 0 )
    {	p.x = -d.y;
        p.y = d.x;
    }
    else
    {	p.x = d.y;
        p.y = -d.x;
    }
    return p;
}

- (BOOL)isPointInside:(NSPoint)p
{   int	iVal=0;

    if ( !(iVal=[self isPointInsideOrOn:p]) || iVal == 1 )
        return NO;
    return YES;
}
/* created: 1996-09-26
 * returns YES if p is inside us (must be full and filled)
 * 0 = outside
 * 1 = on
 * 2 = inside
 */
- (int)isPointInsideOrOn:(NSPoint)p
{   NSRect	bRect;
    float	dist=radius+10;

    if ( Abs([self angle]) != 360.0 /*|| ![self filled]*/ )
        return 0;

    bRect = [self coordBounds];
    if ( !NSPointInRect(p , bRect) )
        return 0;

    dist = sqrt(SqrDistPoints(p, center));
    /* on */
    if ( Diff(dist, radius) <= TOLERANCE )
        return 1;
    /* distance p center smaller radius -> YES */
    if ( dist < radius )
        return 2;
    return 0;
}

/*
 * created:  2002-09-13
 * modified: 2006-02-26 (changed from function to method)
 *
 * purpose:   get the distance between a points and a line without the sqrt
 *            means sqrt(of the return value) is the real distance
 *            iPoint holds the point on the line nearest to point
 * parameter: arc, point, intersection
 * return:    sqr distance point/line
 */
- (float)getPointOnArcClosestToPoint:(NSPoint)point intersection:(NSPoint*)iPoint
{   NSPoint	s, e, s0;
    double  r2 = (double)radius*(double)radius, distSqrt;
    double	ba = begAngle, ea = ba + angle, da, db, dpc, pAngle;

    dpc = SqrDistPointsM(center, point);

    pAngle = vhfAngleOfPointRelativeCenter(point, center); // atan 1x
    /* we need positive angles with ea > ba */
    ba = (angle>=0.0) ? begAngle : (begAngle+angle);
    if (ba < 0.0) ba += 360.0;
    if (ba > 360.0) ba -= 360.0;
    ea = ba + Abs(angle);
    if (ea >= 360.0) ea -= 360.0;

    // point on line between start and end (clAngle between beg/end angles)
    if ( (ba < ea && pAngle >= ba && pAngle <= ea) || (ba >= ea && (pAngle <= ea || pAngle >= ba)) )
    {
        s0.x = center.x + radius; s0.y = center.y;
        *iPoint = vhfPointAngleFromRefPoint(center, s0, pAngle); // cos 2x sin 2x
        distSqrt = sqrt(dpc);
        if ( dpc > r2 )
            return (distSqrt - radius)*(distSqrt - radius);
        return (radius - distSqrt)*(radius - distSqrt); // inside
    }

    s0.x = center.x + radius; s0.y = center.y;
    s = vhfPointAngleFromRefPoint(center, s0, ba); // cos 2x sin 2x

    /* distance to endpoints */
    da = SqrDistPointsM(s, point);
    e = vhfPointAngleFromRefPoint(center, s0, ea); // cos 2x sin 2x
    db = SqrDistPointsM(e, point);

    *iPoint = (da < db) ? s : e;
    return (da < db) ? da : db;	// distance to endpoints
}

/* 0 - other intersection than tangential intersection
 * 1 - tangential intersection
 * 2 - no intersection
 *
 * self is allways an 360.0 degree arc !
 */
#define T_OTHER	0
#define T_YES	1
#define T_NO	2
- (int)tangentIntersectionLine:(NSPoint)pl0 :(NSPoint)pl1 :(BOOL)FromLine :(int*)iCnt :(NSPoint*)iPoint
{   NSRect	aBounds, lBounds;	/* bounds */
    NSPoint	points[2];

    /* a quick check for possible intersection */
    aBounds = [self coordBounds];
    lBounds.origin.x = Min(pl0.x, pl1.x) - TOLERANCE;
    lBounds.origin.y = Min(pl0.y, pl1.y) - TOLERANCE;
    lBounds.size.width  = Max(pl0.x, pl1.x) - lBounds.origin.x + 2.0*TOLERANCE;
    lBounds.size.height = Max(pl0.y, pl1.y) - lBounds.origin.y + 2.0*TOLERANCE;
    if ( !vhfIntersectsRect(aBounds, lBounds) )
        return T_NO;

     /* tangent */
    /*if ( (FromLine && Diff(pointOnLineClosestToPoint(pl0, pl1, center, points), radius*radius) < 	(25.0*TOLERANCE)*(25.0*TOLERANCE))
        || (!FromLine && Diff(pointOnLineClosestToPoint(pl0, pl1, center, points), radius*radius) < 	(50.0*TOLERANCE)*(50.0*TOLERANCE)) ) // 50.0 */
//    if ( Diff(pointOnLineClosestToPoint(pl0, pl1, center, points), radius*radius)
//        < (50.0*TOLERANCE)*(50.0*TOLERANCE) ) // 50.0
    if ( Diff(pointOnLineClosestToPoint(pl0, pl1, center, points), radius*radius)
        < (40.0*TOLERANCE)*(40.0*TOLERANCE) ) // 50.0
    {   float	rMinusTol = radius*radius-(25.0*TOLERANCE)*(25.0*TOLERANCE); // 25.0

        if ( SqrDistPoints(pl0, center) < rMinusTol && SqrDistPoints(pl1, center) < rMinusTol )
            return T_OTHER;
        *iPoint = points[0];
        *iCnt = 1;
        return T_YES;
    }
    else if ( SqrDistPoints(points[0], center) < radius*radius )
        return T_OTHER;
    return T_NO;
}

/* created:   1993-05-14
 * modified:  2010-06-11 (dx, dy, underTheSqrt casted to double)
 *            2001-09-07
 * purpose:   intersect arc with a line
 * parameter: pArray (intersections)
 *		pl0, pl1
 * return:    number of intersections (0, 1, 2)
 */
- (int)intersectLine:(NSPoint*)pArray :(NSPoint)pl0 :(NSPoint)pl1
{   int		cnt = 2, iCnt = 0;
    NSRect	aBounds, lBounds;	/* bounds */
    double	a, b, c,	/* coefficients of equation x1, x2 = ( -b +- sqrt( b*b - 4*a*c) )/2*a  */
                underTheSqrt,
                dx,dy;			/* delta x, y */
    float	an, ba, ea;		/* angle */
    NSPoint	points[2];

    /* a quick check for possible intersection */
    aBounds = [self coordBounds];
    lBounds.origin.x = Min(pl0.x, pl1.x) - TOLERANCE;
    lBounds.origin.y = Min(pl0.y, pl1.y) - TOLERANCE;
    lBounds.size.width  = Max(pl0.x, pl1.x) - lBounds.origin.x + 2.0*TOLERANCE;
    lBounds.size.height = Max(pl0.y, pl1.y) - lBounds.origin.y + 2.0*TOLERANCE;
    if (NSIsEmptyRect(NSIntersectionRect(aBounds , lBounds)))
        return 0;

     /* tangent */
    if ( Diff(pointOnLineClosestToPoint(pl0, pl1, center, points), radius*radius) < (20.0*TOLERANCE)*(20.0*TOLERANCE))
//if ( Diff(pointOnLineClosestToPoint(pl0, pl1, center, points), radius*radius) < (5.0*TOLERANCE)*(5.0*TOLERANCE))
    {	cnt = 2;
        points[1] = points[0];
        /* points[0] may lay on 270 deg when arc ends at 268 deg -> we have to keep points[0] inside angles */
        ba = ((angle>=0.0) ? begAngle : (begAngle+angle));
        if (ba < 0.0) ba += 360.0;
        if (ba >= 360.0) ba -= 360.0;
        ea = ba + Abs(angle);
        an = vhfAngleOfPointRelativeCenter(points[0], center);
        if (an < ba) an += 360.0;
        if ( an<ba || an>ea )
        {
            if ( SqrDistPoints(points[0], start) <= (10.0*TOLERANCE)*(10.0*TOLERANCE) )
                points[0] = points[1] = start;
            else if ( SqrDistPoints(points[0], end) <= (10.0*TOLERANCE)*(10.0*TOLERANCE) )
                points[0] = points[1] = end;
        }
    }
    else if ( Diff(pl0.x, pl1.x) <= TOLERANCE ) /* vertical line */
    {
        points[0].x = points[1].x = pl0.x;
        //if ( Abs((dx=(double)(pl0.x-center.x))) < TOLERANCE )	/* through the center of the arc */
        if ( Abs((dx=((double)pl0.x-(double)center.x))) < TOLERANCE )	/* through the center of the arc */
        {   points[0].y = center.y + radius;
            points[1].y = center.y - radius;
        }
        else
        {
            //if ( Diff(underTheSqrt = (double)(radius*radius) - (dx*dx), 0.0) < TOLERANCE/100.0 )
            if ( Diff(underTheSqrt = ((double)radius*(double)radius) - (dx*dx), 0.0) < TOLERANCE/100.0 )
                underTheSqrt = 0.0;
            if (underTheSqrt<0.0)
                return(0);
            dy = sqrt((double)underTheSqrt);
            points[0].y = center.y + dy;
            points[1].y = center.y - dy;
        }
    }
    else if ( Diff(pl0.y, pl1.y) <= TOLERANCE ) /* horizontal line */
    {
        points[0].y = points[1].y = pl0.y;
        //if ( Abs((dy=(double)(pl0.y-center.y))) < TOLERANCE)	/* through the center of the arc */
        if ( Abs((dy=((double)pl0.y-(double)center.y))) < TOLERANCE)	/* through the center of the arc */
        {   points[0].x = center.x + radius;
            points[1].x = center.x - radius;
        }
        else
        {
            //if ( Diff(underTheSqrt = (double)(radius*radius) - (dy*dy), 0.0) < TOLERANCE/100.0 )
            if ( Diff(underTheSqrt = ((double)radius*(double)radius) - (dy*dy), 0.0) < TOLERANCE/100.0 )
                underTheSqrt = 0.0;
            if (underTheSqrt<0.0)
                return(0);
            dx = sqrt((double)underTheSqrt);
            points[0].x = center.x + dx;
            points[1].x = center.x - dx;
        }
    }
    /* other directions - more horicontal */
    else if ( Diff(pl0.y, pl1.y) < Diff(pl0.x, pl1.x) )
    {	double gradient,		// gradient of line (dx/dy)
               x_axPart;		// x_axis segment

        gradient = (double)(pl0.x - pl1.x) / (double)(pl0.y - pl1.y);
        x_axPart = (double)pl0.x - (double)(gradient * pl0.y);

        a = 1.0/(gradient*gradient) + 1.0;
        b = -2.0 * (double)( x_axPart/(gradient*gradient) + (double)center.y/gradient + (double)center.x );
        c = (double)((x_axPart*center.y)*(2.0/gradient)) + x_axPart*(x_axPart/(gradient*gradient)) +
            (double)((double)center.x*(double)center.x) + (double)((double)center.y*(double)center.y) -
            (double)((double)radius*(double)radius);

        if ( Diff((underTheSqrt = (b*b - 4.0*a*c)), 0.0) < TOLERANCE/100.0)
            underTheSqrt = 0.0;
        if ( underTheSqrt < 0 )
            return(0);
        underTheSqrt = sqrt(underTheSqrt);

        points[0].x = (-b + underTheSqrt)/(2.0*a);
        points[0].y = (double)(points[0].x - x_axPart) / gradient;
        if (!underTheSqrt)	/* tangent line -> only one intersection */
        {
            if (NSPointInRect(points[0] , lBounds))
            {   pArray[0] = pArray[1] = points[0];
                return 1;
            }
            return 0;
        }
        points[1].x = (-b - underTheSqrt)/(2.0*a);
        points[1].y = (double)(points[1].x - x_axPart) / gradient;
    }
    /* other directions - more vertical */
    else
    {	double gradient,		// gradient of line (dy/dx)
               y_axPart;		// y_axis segment

        gradient = (double)(pl0.y - pl1.y) / (double)(pl0.x - pl1.x);
        y_axPart = (double)pl0.y - (double)(gradient * pl0.x);

        a = 1.0/(gradient*gradient) + 1.0;
        b = -2.0 * (double)( y_axPart/(gradient*gradient) + (double)center.x/gradient + (double)center.y );
        c = (double)((y_axPart*center.x)*(2.0/gradient)) + y_axPart*(y_axPart/(gradient*gradient)) +
            (double)((double)center.x*(double)center.x) + (double)((double)center.y*(double)center.y) -
            (double)((double)radius*(double)radius);

        if ( Diff((underTheSqrt = (b*b - 4.0*a*c)), 0.0) < TOLERANCE/100.0)
            underTheSqrt = 0.0;
        if ( underTheSqrt < 0 )
            return(0);
        underTheSqrt = sqrt(underTheSqrt);

        points[0].y = (-b + underTheSqrt)/(2.0*a);
        points[0].x = (double)(points[0].y - y_axPart) / gradient;
        if (!underTheSqrt)	/* tangent line -> only one intersection */
        {
            if (NSPointInRect(points[0] , lBounds))
            {   pArray[0] = pArray[1] = points[0];
                return 1;
            }
            return 0;
        }
        points[1].y = (-b - underTheSqrt)/(2.0*a);
        points[1].x = (double)(points[1].y - y_axPart) / gradient;
    }

    /* full arc */
    if ( angle >= 360.0 )
    {
        if (NSPointInRect(points[0] , lBounds))
            pArray[iCnt++] = points[0];
        if (NSPointInRect(points[1] , lBounds))
            pArray[iCnt++] = points[1];
        return iCnt;
    }

    ba = ((angle>=0.0) ? begAngle : (begAngle+angle)) - 0.005; /* 0.1, 0.05 */
    if (ba < 0.0) ba += 360.0;
    if (ba >= 360.0) ba -= 360.0;
    ea = ba + Abs(angle) + 0.01;	/* 0.2, 0.1 */
    if (NSPointInRect(points[0] , lBounds))
    {	an = vhfAngleOfPointRelativeCenter(points[0], center);
        if (an < ba) an += 360.0;
        if ((an>=ba && an<=ea) ||
            (Diff(points[0].x, start.x) < 1.5*TOLERANCE && Diff(points[0].y, start.y) < 1.5*TOLERANCE) ||
            (Diff(points[0].x, end.x) < 1.5*TOLERANCE && Diff(points[0].y, end.y) < 1.5*TOLERANCE))
            pArray[iCnt++] = points[0];
    }
    if (cnt >= 2 && NSPointInRect(points[1], lBounds))
    {	an = vhfAngleOfPointRelativeCenter(points[1], center);
        if (an < ba) an += 360.0;
        if ((an>=ba && an<=ea) ||
            (Diff(points[1].x, start.x) < 1.5*TOLERANCE && Diff(points[1].y, start.y) < 1.5*TOLERANCE) ||
            (Diff(points[1].x, end.x) < 1.5*TOLERANCE && Diff(points[1].y, end.y) < 1.5*TOLERANCE))
            pArray[iCnt++] = points[1];
    }

    return iCnt;
}

- (int)intersectCurve:(NSPoint*)pArray :(NSPoint)pc0 :(NSPoint)pc1 :(NSPoint)pc2 :(NSPoint)pc3
{
    NSLog(@"VArc, -intersectCurve not implemented!");
    return 0;
}

/* 0 - other intersection than tangential intersection
 * 1 - tangential intersection
 * 2 - no intersection
 *
 * self is allways an 360.0 degree arc !
 */
- (int)tangentIntersectionArc:(NSPoint)center1 :(NSPoint)start1 :(float)angle1 :(float)radius1 :(NSRect*)bounds2 :(int*)iCnt :(NSPoint*)iPoint
{   NSRect	bounds1;
    NSPoint	md, p, pArray[2];
    double	d, c, at, a, v, a1, ba, ba1, ea, ea1, tol = 2.0*TOLERANCE, pa1=0.0; // , radius1
    int		cnt;

    /* a quick check for possible intersection */
    bounds1 = [self coordBounds];
    if ( !vhfIntersectsRect(bounds1, *bounds2) )
        return T_NO;

    //radius1 = sqrt(SqrDistPoints(center1, start1));
    d = sqrt(SqrDistPoints(center, center1));	/* distance between centers */
    if ( d<Max(radius, radius1)-Min(radius, radius1)-tol || d>radius+radius1+tol )
        return T_NO; // inside or outside

    /* r*r - c*c = r1*r1 - c1*c1, c1 = d-c
     */
    c = ((radius*radius)-(radius1*radius1)+d*d) / (2.0*d);
    at = ( Diff(radius+radius1, d) <= tol || Diff(Diff(radius, radius1), d) <= tol ) ? 0.0 : sqrt(radius*radius-c*c);

    md.x = center1.x-center.x;
    md.y = center1.y-center.y;
    p.x = center.x + md.x*c/d;
    p.y = center.y + md.y*c/d;

    v = md.x; md.x = -md.y; md.y = v;
    pArray[0].x = p.x + md.x*at/d;
    pArray[0].y = p.y + md.y*at/d;
    pArray[1].x = p.x - md.x*at/d;
    pArray[1].y = p.y - md.y*at/d;

    ba = ((angle>=0.0) ? begAngle : (begAngle+angle)) - TOLERANCE*5.0;
    if (ba < 0.0) ba += 360.0;
    if (ba > 360.0) ba -= 360.0;
    ea = ba + Abs(angle) + TOLERANCE*10.0;

    ba1 = vhfAngleOfPointRelativeCenter(start1, center1);
    ba1 = ((angle1>=0.0) ? ba1 : (ba1+angle1)) - TOLERANCE*5.0;
    if (ba1 < 0.0) ba1 += 360.0;
    if (ba1 > 360.0) ba1 -= 360.0;
    ea1 = ba1 + Abs(angle1) + TOLERANCE*10.0;

    cnt = 0;
    a = vhfAngleOfPointRelativeCenter(pArray[cnt], center);
    if (a<ba) a+=360.0;
    a1 = vhfAngleOfPointRelativeCenter(pArray[cnt], center1);
    if (a1<ba1) a1+=360.0;
    if ( a>=ba && a<=ea && a1>=ba1 && a1<=ea1 )
    {   cnt=1;
        pa1 = a1;
    }
    else
        ExchangePoints(pArray[0], pArray[1]);
    if ( DiffPoint(pArray[0], pArray[1])>TOLERANCE )
    {
        a = vhfAngleOfPointRelativeCenter(pArray[cnt], center);
        if (a<ba) a+=360.0;
        a1 = vhfAngleOfPointRelativeCenter(pArray[cnt], center1);
        if (a1<ba1) a1+=360.0;
        if ( a>=ba && a<=ea && a1>=ba1 && a1<=ea1 )
        {
            if ( !cnt )
                pa1 = a1;
            cnt++;
        }
    }
    if ( Diff(at, 0.0) < TOLERANCE/100.0 ||
         (angle1 < 360.0 && ((cnt == 1 && Diff(pa1, ba1) <= 0.2) || Diff(pa1, ea1) <= 0.2)) )
    {
        if ( Diff(Diff(radius, radius1), d) <= tol && radius > radius1 && Diff(radius1, radius) > TOLERANCE )
        //if ( radius > radius1 && Diff(radius1, radius) > TOLERANCE )  // before 2008-02-06
            return T_OTHER; // arc laying outside !!! of test radius (perhaps outside of hole path)

        *iPoint = pArray[0];
        *iCnt = 1;
        return T_YES; // Tangente
    }
    if ( angle1>=360.0 || cnt) // self is allways 360.0 degree
        return T_OTHER;

    return T_NO;
}

/*
 * modified: 2012-01-20 (use special tolerance to compare angles)
 *
 * Note: this can return more than 2 intersections for overlapping arcs (up to 4 intersections)
 */
- (int)intersectArc:(NSPoint*)pArray :(NSPoint)center1 :(NSPoint)start1 :(float)angle1 :(NSRect*)bounds2
{   NSRect	bounds1;
    double	mdx, mdy, px, py, tolAng = TOLERANCE_DEG;
    double	distCtr, c, at, a, v, radius1, a1, ba, ba1, ea, ea1, tol = 1.4*TOLERANCE; // 2.0*
    int		cnt = 0;

    /* a quick check for possible intersection */
    bounds1 = [self bounds];
    if (NSIsEmptyRect(NSIntersectionRect(bounds1 , *bounds2)))
        return 0;

    radius1 = sqrt(SqrDistPoints(center1, start1));
    /* tolerance relative radius, but still >= TOLERANCE and <= TOLERANCE*10 */
    //tolRel = Min( Max(TOLERANCE, Min(radius, radius1) / 1000.00), TOLERANCE*10.0 );

    distCtr = sqrt(SqrDistPoints(center, center1)); // distance between centers
    /* inside or outside */
    if ( distCtr<Max(radius, radius1)-Min(radius, radius1)-2.0*TOLERANCE
         || distCtr>radius+radius1+2.0*TOLERANCE )
        return 0;

    /* if the centers of the circles are nearly identical
     */
    if (Diff(center.x, center1.x) <= 2.0*TOLERANCE && Diff(center.y, center1.y) <= 2.0*TOLERANCE)
    {	double	pointsAngles[4];
        int	i, j, isect = 0, new = 0;
		/* if arc1 is full and the radius of the circles are identical
         * the points are the start end points of arc2 (and vice versa)
         */
        if (Diff(radius, radius1) > TOLERANCE)
            return 0;

        if (angle >= 360.0)
        {   pArray[0] = start1;
            pArray[1] = vhfPointAngleFromRefPoint(center1, start1, angle1);
            return 2;
        }
        else if (angle1 >= 360.0)
        {   pArray[0] = start;
            pArray[1] = end;
            return 2;
        }
        else
        {
            ba = ((angle>=0.0) ? begAngle : (begAngle+angle)) - TOLERANCE*5.0;
            if (ba < 0.0) ba += 360.0;
            if (ba > 360.0) ba -= 360.0;
            ea = ba + Abs(angle);
            if (ea > 360.0) ea -= 360.0;
            if (Diff(ea, 0) <= TOLERANCE)  ea += 360.0;

            ba1 = vhfAngleOfPointRelativeCenter(start1, center1);
            ba1 = ((angle1>=0.0) ? ba1 : (ba1+angle1)) - TOLERANCE*5.0;
            if (ba1 < 0.0) ba1 += 360.0;
            if (ba1 > 360.0) ba1 -= 360.0;
            ea1 = ba1 + Abs(angle1);
            if (ea1 > 360.0) ea1 -= 360.0;
            if (Diff(ea1, 0) <= TOLERANCE) ea1 += 360.0;

            /* look which angle of arc1 is between the angles of arc2 (and vice versa) */
            if (ba1 < ea1 && ba < ea)
            {
                if (ba > ea1 || ba1 > ea) // arcs laying in line
                    return 0;
                if ( (ba > ba1 || Diff(ba, ba1) <= tolAng) && (ba < ea1 || Diff(ba, ea1) <= tolAng) )
                    pointsAngles[isect++] = ba;
                if ( (ea > ba1 || Diff(ea, ba1) <= tolAng) && (ea < ea1 || Diff(ea, ea1) <= tolAng) )
                    pointsAngles[isect++] = ea;
                if ( (ba1 > ba || Diff(ba1, ba) <= tolAng) && (ba1 < ea || Diff(ba1, ea) <= tolAng) )
                    pointsAngles[isect++] = ba1;
                if ( (ea1 > ba || Diff(ea1, ba) <= tolAng) && (ea1 < ea || Diff(ea1, ea) <= tolAng) )
                    pointsAngles[isect++] = ea1;
            }
            /* both circles going over the 0 angle */
            else if (ba1 > ea1 && ba > ea)
            {
                if ( ba > ba1 || Diff(ba, ba1) <= tolAng )
                    pointsAngles[isect++] = ba;
                if ( ea < ea1 || Diff(ea, ea1) <= tolAng )
                    pointsAngles[isect++] = ea;
                if ( ba1 > ba || Diff(ba1, ba) <= tolAng )
                    pointsAngles[isect++] = ba1;
                if ( ea1 < ea || Diff(ea1, ea) <= tolAng )
                    pointsAngles[isect++] = ea1;
            }
            /* circle1 going over the 0 angle */
            else if (ba > ea)
            {
                if (ba > ea1 && ba1 > ea)
                    return 0;
                if ( (ba > ba1 || Diff(ba, ba1) <= tolAng) && (ba < ea1 || Diff(ba, ea1) <= tolAng) )
                    pointsAngles[isect++] = ba;
                if ( (ea > ba1 || Diff(ea, ba1) <= tolAng) && (ea < ea1 || Diff(ea, ea1) <= tolAng) )
                    pointsAngles[isect++] = ea;
                if ( (ba1 < ea || Diff(ba1, ea) <= tolAng) || (ba1 > ba || Diff(ba1, ba) <= tolAng) )
                    pointsAngles[isect++] = ba1;
                if ( (ea1 < ea || Diff(ea1, ea) <= tolAng) || (ea1 > ba || Diff(ea1, ba) <= tolAng) )
                    pointsAngles[isect++] = ea1;
            }
            /* circle2 going over the 0 angle */
            else
            {
                if (ba1 > ea && ba > ea1)
                    return 0;
                if ( (ba1 > ba || Diff(ba1, ba) <= tolAng) && (ba1 < ea || Diff(ba1, ea) <= tolAng) )
                    pointsAngles[isect++] = ba1;
                if ( (ea1 > ba || Diff(ea1, ba) <= tolAng) && (ea1 < ea || Diff(ea1, ea) <= tolAng) )
                    pointsAngles[isect++] = ea1;
                if ( (ba < ea1 || Diff(ba, ea1) <= tolAng) || (ba > ba1 || Diff(ba, ba1) <= tolAng) )
                    pointsAngles[isect++] = ba;
                if ( (ea < ea1 || Diff(ea, ea1) <= tolAng) || (ea > ba1 || Diff(ea, ba1) <= tolAng) )
                    pointsAngles[isect++] = ea;
            }
        }
        /* get the points to the angles if isect != 0 */
        if (!isect)
            return 0;
        /* eliminate identical angles */
        for (i=0; i<isect-1; i++)
        {
            for (j=i+1; j<isect; j++)
                if ( Diff(pointsAngles[i], pointsAngles[j]) <= TOLERANCE )
                    break;
            if (j >= isect)
                pointsAngles[new++] = pointsAngles[i];
        }
        pointsAngles[new++] = pointsAngles[isect-1];

        for (i=0; i<new; i++)
        {   NSPoint	s1;

            s1 = center1; s1.x += radius1;
            if (pointsAngles[i] >= 360.0) pointsAngles[i] -= 360.0;
            pArray[cnt++] = vhfPointAngleFromRefPoint(center1, s1, pointsAngles[i]);
        }
        return cnt;
    }
    /* r*r - c*c = r1*r1 - c1*c1, c1 = d-c
     * r:  radius
     * r1: radius 1
     * d:  distance of centers
     * c:  distance from one center (on d) to the center of the intersections
     */
    c = ((radius*radius) - (radius1*radius1) + distCtr*distCtr) / (2.0*distCtr);
    at = ( Diff(radius+radius1, distCtr) <= tol || Diff(Diff(radius, radius1), distCtr) <= tol )
        ? 0.0
        : sqrt(radius*radius - c*c);
    mdx = center1.x - center.x;
    mdy = center1.y - center.y;
    px = center.x + mdx*c/distCtr;
    py = center.y + mdy*c/distCtr;

    v = mdx; mdx = -mdy; mdy = v;
    pArray[0].x = px + mdx*at/distCtr;
    pArray[0].y = py + mdy*at/distCtr;
    pArray[1].x = px - mdx*at/distCtr;
    pArray[1].y = py - mdy*at/distCtr;

    if ( angle >= 360.0 && angle1>=360.0 )
        return 2;

    ba = ((angle>=0.0) ? begAngle : (begAngle+angle)) - TOLERANCE*5.0;
    if (ba < 0.0) ba += 360.0;
    if (ba > 360.0) ba -= 360.0;
    ea = ba + Abs(angle) + TOLERANCE*10.0;

    ba1 = vhfAngleOfPointRelativeCenter(start1, center1);
    ba1 = ((angle1>=0.0) ? ba1 : (ba1+angle1)) - TOLERANCE*5.0;
    if (ba1 < 0.0) ba1 += 360.0;
    if (ba1 > 360.0) ba1 -= 360.0;
    ea1 = ba1 + Abs(angle1) + TOLERANCE*10.0;

    cnt = 0;
    a = vhfAngleOfPointRelativeCenter(pArray[cnt], center);
    if (a<ba) a+=360.0;
    a1 = vhfAngleOfPointRelativeCenter(pArray[cnt], center1);
    if (a1<ba1) a1+=360.0;
    if ( a>=ba && a<=ea && a1>=ba1 && a1<=ea1 )
        cnt=1;
    else
        ExchangePoints(pArray[0], pArray[1]);
    if ( DiffPoint(pArray[0], pArray[1])>TOLERANCE )
    {	a = vhfAngleOfPointRelativeCenter(pArray[cnt], center);
        if (a<ba) a+=360.0;
        a1 = vhfAngleOfPointRelativeCenter(pArray[cnt], center1);
        if (a1<ba1) a1+=360.0;
        if ( a>=ba && a<=ea && a1>=ba1 && a1<=ea1 )
            cnt++;
    }
    else if ( cnt && Diff(at, 0.0) < TOLERANCE/100.0 )
        cnt = 2; // Tangente

    return cnt;
}

/* created:  22.03.96
 * modified: 24.08.98
 * purpose:  intersect curve and arc
 *		we do the following:
 *		- 1st we split the passed curve in two
 *		- then we check the intersection of the bounds between the curve and the arc
 *		 and call intersectCurve() again to intersect the splitted curves
 *		- after several recursions we intersect the lines between the vertices of the curve with the arc
 *		  and return the intersection points by reference and the number of intersections
 * problems:  
 * parameter: points
 *		pc (vertices of curve)
 * return:    number of intersections (0, 1, 2, 3, 4, 5, 6)
 */
#define MAXINTERSECTS 6
static int intersectCurve(NSPoint *points, NSPoint *pc, id arc, NSPoint *center, float radius, NSRect *aBounds)
{   NSPoint	p, pca[4], pcb[4];
    int		iCnt=0;
    NSRect	cBounds;
    NSPoint	ps[12];
    double	maxDist, minDist, newDist, sqrRadius;
    double	arcTol = MAX((((double)radius*(double)radius)*2.0*TOLERANCE)/100.0, TOLERANCE);
    BOOL	stopRecursion = NO;

    /* we start with a quick check for possible intersection */
    cBounds = fastBoundsOfCurve(pc);

    /* check whether curve is completely inside or outside circle */
    maxDist = SqrDistPoints(*center, cBounds.origin);
    p.x = cBounds.origin.x + cBounds.size.width;
    p.y = cBounds.origin.y;
    if ((newDist = SqrDistPoints(*center, p)) > maxDist) maxDist = newDist;
    p.x = cBounds.origin.x + cBounds.size.width;
    p.y = cBounds.origin.y + cBounds.size.height;
    if ((newDist = SqrDistPoints(*center, p)) > maxDist) maxDist = newDist;
    p.x = cBounds.origin.x;
    p.y = cBounds.origin.y + cBounds.size.height;
    if ((newDist = SqrDistPoints(*center, p)) > maxDist) maxDist = newDist;
    minDist = sqrDistPointRect(*center, cBounds);
    sqrRadius = (double)radius*(double)radius;
    if ( maxDist<sqrRadius-arcTol || (minDist>sqrRadius+arcTol && !NSPointInRect(*center, cBounds)) ) // TOLERANCE
        return iCnt;

    cBounds.origin.x -= TOLERANCE;
    cBounds.origin.y -= TOLERANCE;
    cBounds.size.width  += 2.0*TOLERANCE;
    cBounds.size.height += 2.0*TOLERANCE;
    if (aBounds->size.width+aBounds->size.height == 0.0)
        *aBounds = [arc bounds];
    if (NSIsEmptyRect(NSIntersectionRect(*aBounds , cBounds)))	/* bounds don't intersect */
        return iCnt;

    /* if this value is too small we may loose some intersection points */
//#	define LIMIT	TOLERANCE*10.0
#	define LIMIT	TOLERANCE*20.0
    if ( cBounds.size.width+cBounds.size.height > LIMIT )
    {	int				i, j;
        static double	ts[] = {1.0/2.0, 3.0/8.0, 5.0/8.0, 1.0/4.0, 3.0/4.0, 1.0/8.0, 7.0/8.0};

        /* split curve
         * we split at a point which is no intersection point
         */
        for (i=0; i<7; i++)
        {   tileCurveAt(pc, ts[i], pca, pcb);
            if ( Diff(SqrDistPoints(pca[3], *center), sqrRadius) > 10.0*TOLERANCE)
                break;
        }
        if (i<7)
        {
            /* now, we have two curves
             * which we have to check for intersections with the arc
             * 1st of all we check the bounds for intersections
             * then we call this method again with the curves which seem to intersect
             */

            /* call intersectCurve again to intersect the splitted curves
             */
            if ( (i = intersectCurve(ps, pca, arc, center, radius, aBounds)) )
            {
                for (j=0; j<i; j++)	/* to avoid multiple equal points */
                    if (iCnt<MAXINTERSECTS && !pointWithToleranceInArray(ps[j], 20.0*TOLERANCE, points, iCnt))
                        points[iCnt++] = ps[j];
            }
            if ( (i = intersectCurve(ps, pcb, arc, center, radius, aBounds)) )
            {
                for (j=0; j<i; j++)
                    if (iCnt<MAXINTERSECTS && !pointWithToleranceInArray(ps[j], 20.0*TOLERANCE, points, iCnt))
                        points[iCnt++] = ps[j];
            }
        }
        else		/* the curve is too small */
            stopRecursion = YES;
    }
    else
        stopRecursion = YES;

    /* enough recursion
     * now we are to intersect all lines between the points of the curves with the arc
     */
    if (stopRecursion)
    {	int	k, ic; // i, 

//        for (i=0; i<3; i++)
        {   NSPoint	p0, p1;

//            p0 = pc[i];
//            p1 = pc[i+1];

            p0 = pc[0];
            p1 = pc[3];

            /* if we have an intersection then we add the intersection point to 'points'
             * and increment our counter
             */
//NSLog(@"%d p0:%f %f p1:%f %f", i, p0.x, p0.y, p1.x, p1.y);
//NSLog(@"%d c:%f %f r:%f", i, center->x, center->y, radius);
            if ( (ic = [arc intersectLine:ps :p0 :p1]))
            {
                for (k=0; k<ic; k++)
                    if (iCnt<MAXINTERSECTS && !pointWithToleranceInArray(ps[k], 20.0*TOLERANCE, points, iCnt))
                        points[iCnt++] = ps[k];
//                break;
            }
        }
    }

    return iCnt;
}

#define C_YES	3

int cntPointsWithToleranceInArray(NSPoint point, float tol, const NSPoint *array, int cnt)
{   int	i, pCnt=0;

    for (i=0; i<cnt; i++)
        if (Diff(point.x, array[i].x) < tol && Diff(point.y, array[i].y) < tol)
            pCnt++;
    return pCnt;
}

//#define CRVRADIUSTOL (45.0*TOLERANCE)*(45.0*TOLERANCE) // too big
#define CRVRADIUSTOL (30.0*TOLERANCE)*(30.0*TOLERANCE)
#define WHTOL        300.0*TOLERANCE // 200.0
int distancePointCurveIsRadius(float r2, NSPoint *pc, NSPoint *point, NSRect *aBounds, float ts, float te, int *iCnt, NSPoint *iPts, float *dists)
{   NSPoint		pc1[4], pc2[4], p[8], iPoint = NSZeroPoint;
    float		t, dist = MAXCOORD, newDist, tdiff = Diff(ts, te)/6.0; // -> 7 pts including s/e
    NSRect		bounds;
    int			cnt=0;

    // get seven pts on curve
    for (t=ts; t<=te; t+=tdiff)
    {   NSPoint	pt[3];

        pt[0].x=pc[0].x+t*(pc[1].x-pc[0].x);
        pt[0].y=pc[0].y+t*(pc[1].y-pc[0].y);
        pt[1].x=pc[1].x+t*(pc[2].x-pc[1].x);
        pt[1].y=pc[1].y+t*(pc[2].y-pc[1].y);
        pt[2].x=pc[2].x+t*(pc[3].x-pc[2].x);
        pt[2].y=pc[2].y+t*(pc[3].y-pc[2].y);

        pt[0].x=pt[0].x+t*(pt[1].x-pt[0].x);
        pt[0].y=pt[0].y+t*(pt[1].y-pt[0].y);
        pt[1].x=pt[1].x+t*(pt[2].x-pt[1].x);
        pt[1].y=pt[1].y+t*(pt[2].y-pt[1].y);

        p[cnt].x   = pt[0].x+t*(pt[1].x-pt[0].x);
        p[cnt++].y = pt[0].y+t*(pt[1].y-pt[0].y);

        if ((newDist = SqrDistPoints(p[cnt-1], *point)) < dist)
        {   dist = newDist;
            iPoint = p[cnt-1];
        }
    }

    if ( dist < r2-CRVRADIUSTOL ) // curve cut arc
    {   *iCnt = 0;
        return T_OTHER;
    }
    if ( cnt < 7 )
    {
        if ( Diff(t, te) < tdiff/10.0 )
        {   NSPoint	pt[3];

            t = te; // floating calculation bug -> missing te
            pt[0].x=pc[0].x+t*(pc[1].x-pc[0].x);
            pt[0].y=pc[0].y+t*(pc[1].y-pc[0].y);
            pt[1].x=pc[1].x+t*(pc[2].x-pc[1].x);
            pt[1].y=pc[1].y+t*(pc[2].y-pc[1].y);
            pt[2].x=pc[2].x+t*(pc[3].x-pc[2].x);
            pt[2].y=pc[2].y+t*(pc[3].y-pc[2].y);

            pt[0].x=pt[0].x+t*(pt[1].x-pt[0].x);
            pt[0].y=pt[0].y+t*(pt[1].y-pt[0].y);
            pt[1].x=pt[1].x+t*(pt[2].x-pt[1].x);
            pt[1].y=pt[1].y+t*(pt[2].y-pt[1].y);

            p[cnt].x   = pt[0].x+t*(pt[1].x-pt[0].x);
            p[cnt++].y = pt[0].y+t*(pt[1].y-pt[0].y);

            if ((newDist = SqrDistPoints(p[cnt-1], *point)) < dist)
            {   dist = newDist;
                iPoint = p[cnt-1];
            }
        }
        else // if ( cnt < 7 )
        {   *iCnt = 0;
            return T_OTHER;
        }
    }
    pc1[0] = p[0]; pc1[1] = p[1]; pc1[2] = p[2]; pc1[3] = p[3];
    pc2[0] = p[3]; pc2[1] = p[4]; pc2[2] = p[5]; pc2[3] = p[6];

    // check bounds of each part
    // go on if bounds intersect and curve part is (too) long enough
    bounds = fastBoundsOfCurve(pc1); // get only the min max of the four points
    if ( vhfIntersectsRect(*aBounds, bounds) && (bounds.size.width > WHTOL || bounds.size.height > WHTOL) )
    //if ( vhfIntersectsRect(*aBounds, bounds) && bounds.size.width+bounds.size.height > 750.0*TOLERANCE )
    {   if ( !distancePointCurveIsRadius(r2, pc, point, aBounds, ts, ts+3.0*tdiff, iCnt, iPts, dists) )
        {   *iCnt = 0;
            return T_OTHER;
        }
    }
    else if (!(*iCnt))
    {
        dists[0] = dist;
        iPts[(*iCnt)++] = iPoint;
    }
    else
    {   int	i;

        for (i=0; i<*iCnt; i++)
        {
            if (dist < dists[0])
            {   iPts[0] = iPoint;
                dists[0] = dist;
                break;
            }
        }
    }
    bounds = fastBoundsOfCurve(pc2); // get only the min max of the four points
    if ( vhfIntersectsRect(*aBounds, bounds) && (bounds.size.width > WHTOL || bounds.size.height > WHTOL) )
    //if ( vhfIntersectsRect(*aBounds, bounds) && bounds.size.width+bounds.size.height > 750.0*TOLERANCE )
    {   if ( !distancePointCurveIsRadius(r2, pc, point, aBounds, ts+3.0*tdiff, te, iCnt, iPts, dists) )
        {   *iCnt = 0;
            return T_OTHER;
        }
    }
    else if (!(*iCnt))
    {
        dists[0] = dist;
        iPts[(*iCnt)++] = iPoint;
    }
    else
    {   int	i;

        for (i=0; i<*iCnt; i++)
        {
            if (dist < dists[0])
            {   iPts[0] = iPoint;
                dists[0] = dist;
                break;
            }
        }
    }
    return T_NO;
}

/* 0 - other intersection than tangential intersection
 * 1 - tangential intersection
 * 2 - no intersection
 *
 * self is allways an 360.0 degree arc !
 */
- (int)tangentIntersectionCurve:(NSPoint*)pc :(int*)iCnt :(NSPoint*)iPts
{   int		rVal;
    NSRect	cBounds, aBounds;
    float	r2 = radius*radius, dists[2];

    /* a quick check for possible intersection */
    cBounds = fastBoundsOfCurve(pc);
    aBounds = [self coordBounds];
    aBounds = EnlargedRect(aBounds, TOLERANCE);
    if ( !vhfIntersectsRect(aBounds, cBounds) )
        return T_NO;

    rVal = distancePointCurveIsRadius(r2, pc, &center, &aBounds, 0.0, 1.0, iCnt, iPts, dists);

    return rVal;
}

/* created:  22.03.96
 * modified:		
 * purpose:  intersect curve and arc
 *           we do the following:
 *           - 1st we split the passed curve in two
 *           - then we check the intersection of the bounds between the curve and the arc
 *             and call intersectCurve() again to intersect the splitted curves
 *           - after several recursions we intersect the lines between the vertices of the curve with the arc
 *             and return the intersection points by reference and the number of intersections
 * problems: 
 * parameter: points
 *            pc (vertices of curve)
 * return:   number of intersections (0, 1, 2, 3, 4, 5, 6)
 */
- (int)intersectCurve:(NSPoint*)points :(NSPoint*)pc
{   int		i, iCnt=0, endCnt = 0;
    NSRect	cBounds, aBounds;
    NSPoint	ps[12];

    /* we allow a little tolerance for end points
     */
    if (Diff(pc[0].x, start.x) + Diff(pc[0].y, start.y) <= TOLERANCE)
    {	points[iCnt++] = pc[0] = start;}
    if (Diff(pc[0].x, end.x) + Diff(pc[0].y, end.y) <= TOLERANCE)
    {	points[iCnt++] = pc[0] = end;}
    if (Diff(pc[3].x, start.x) + Diff(pc[3].y, start.y) <= TOLERANCE)
    {	points[iCnt++] = pc[3] = start;}
    if (Diff(pc[3].x, end.x) + Diff(pc[3].y, end.y) <= TOLERANCE)
    {	points[iCnt++] = pc[3] = end;}

    /* a quick check for possible intersection */
    cBounds = fastBoundsOfCurve(pc);
    aBounds = [self bounds];
    aBounds = EnlargedRect(aBounds, TOLERANCE);
    if ( !vhfIntersectsRect(aBounds, cBounds) )
    //if (NSIsEmptyRect(NSIntersectionRect(aBounds , cBounds)))
        return iCnt;

    if (iCnt)
    {	endCnt = iCnt;
        for (i=0; i<endCnt; i++)
            ps[i] = points[i];
    }

    iCnt = intersectCurve(points, pc, self, &center, radius, &aBounds);

    if ( endCnt )
    {	for (i=0; i<endCnt; i++)	/* to avoid multiple equal points */
        if (iCnt<MAXINTERSECTS+2 && !pointInArray(ps[i], points, iCnt))
            points[iCnt++] = ps[i];
    }

    return iCnt;
}

- (float)sqrDistanceLine:(NSPoint)pl0 :(NSPoint)pl1 :(NSPoint*)pg1 :(NSPoint*)pg2
{   float	distance, r2 = (radius*radius), distSqrt , clAngle;
    NSPoint	clPoint, iPoint, pts[2];
    float	dist, distS, distE, ba, ea;
    double  d0 = -1.0, d1 = -1.0;

    /* s or e inside Arc */
    if ( (d0=SqrDistPointsM(center, pl0)) <= r2 || (d1=SqrDistPointsM(center, pl1)) <= r2 )
    {
        if ( d1 < 0 )
            d1=SqrDistPointsM(center, pl1);

        if ( (Diff(angle, 360.0) <= TOLERANCE) && (d0 >= r2 || d1 >= r2) )
        {   [self intersectLine:pts :(d0 >= r2)?(pl0):(pl1) :center];
            *pg1 = *pg2 = pts[0];
            return 0.0; // cut
        }
        if ([self intersectLine:pts :pl0 :pl1])
        {   *pg1 = *pg2 = pts[0];
            return 0.0; // cut
        }
    }
    else // s and e of line are outside
    {
        distance = pointOnLineClosestToPoint(pl0, pl1, center, &clPoint); // center to line
        if (Diff(angle, 360.0) <= TOLERANCE)
        {
            if (distance >= r2)
            {   distSqrt = sqrt(distance);
                *pg1 = clPoint;
                [self intersectLine:pts :clPoint :center];
                *pg2 = pts[0];
                return (distSqrt - radius)*(distSqrt - radius);
            }
            [self intersectLine:pts :pl0 :pl1];
            *pg1 = *pg2 = pts[0];
            return 0.0; // arc cut line
        }

        if ( distance <= r2 && [self intersectLine:pts :pl0 :pl1])
        {   *pg1 = *pg2 = pts[0];
            return 0.0; // arc cut line
        }

        /* check if point on Line between sa/ea */
        if ( distance > r2 )
        {
            clAngle = vhfAngleOfPointRelativeCenter(clPoint, center); // atan
            ba = (angle>=0.0) ? begAngle : (begAngle+angle);
            if (ba < 0.0) ba += 360.0;
            if (ba > 360.0) ba -= 360.0;
            ea = ba + Abs(angle);
            if (ea >= 360.0) ea -= 360.0;

            // point on line between start and end (clAngle between beg/end angles)
            if ( (ba < ea && clAngle >= ba && clAngle <= ea) || (ba >= ea && (clAngle <= ea || clAngle >= ba)) )
            {
                [self intersectLine:pts :clPoint :center];
                *pg1 = clPoint; *pg2 = pts[0];
                distSqrt = sqrt(distance);
                return (distSqrt - radius)*(distSqrt - radius);
            }
        }
    }
    /* now nearest Distance of s/e of line or arc is it */
    dist = distS = pointOnLineClosestToPoint(pl0, pl1, start, &iPoint); // start arc to line
    *pg2 = iPoint;  *pg1 = start;
    if ( (distE = pointOnLineClosestToPoint(pl0, pl1, end, &iPoint)) < dist) // end arc to line
    {   *pg2 = iPoint;  *pg1 = end;
        dist = distE;
    }
    if ( (distS = [self getPointOnArcClosestToPoint:pl0 intersection:&iPoint]) < dist ) // start line to arc
    {   *pg2 = iPoint;  *pg1 = pl0;
        dist = distS;
    }
    if ( (distE = [self getPointOnArcClosestToPoint:pl1 intersection:&iPoint]) < dist ) // end line to arc
    {   *pg2 = iPoint;  *pg1 = pl1;
        dist = distS;
    }
    return dist;
}

- (float)sqrDistanceArc:(NSPoint)center1 :(NSPoint)start1 :(float)angle1 :(NSPoint*)pg1 :(NSPoint*)pg2
{   double	cDist, cDistSqrt, dist=MAXCOORD, distS, distE, radius1 = sqrt(SqrDistPoints(start1, center1));
    NSPoint	end1, p, pts[2];
    VArc    *arc1 = [VArc arc];

    [arc1 setCenter:center1 start:start1 angle:angle1];
    cDist = SqrDistPointsM(center1, center);
    cDistSqrt = sqrt(cDist);
    if ( Diff(angle1, 360.0) <= TOLERANCE && Diff(angle, 360.0) <= TOLERANCE ) // we check if centers near enough
    {
        [self intersectLine:pts :center1 :center];
        *pg1 = pts[0];
        [arc1 intersectLine:pts :center1 :center];
        *pg2 = pts[0];

        if ( cDistSqrt >= radius+radius1 )
            return (cDistSqrt - radius - radius1)*(cDistSqrt - radius - radius1);
        else if ( cDistSqrt >= Diff(radius, radius1) )
            return 0.0; // arcs cut each other
        else
            return (Max(radius, radius1) - cDistSqrt - Min(radius, radius1))*
                   (Max(radius, radius1) - cDistSqrt - Min(radius, radius1));
    }

    /* cDist small enough for possible intersection */
    if ( cDistSqrt <= radius+radius1 )
    {   NSRect  bnds = [self bounds];

        [arc1 setCenter:center1 start:start1 angle:angle1];
        if ( [arc1 intersectArc:pts :center :start :angle :&bnds] )
        {   *pg1 = *pg2 = pts[0];
            return 0.0; // cut
        }
    }
    else // if ( cDistSqrt >= radius+radius1 )
    {   double  c1Angle, cAngle, ba, ea, ba1, ea1, begAngle1;

        /* check if center pt line is inside each angle */

        /* angle on self of center1 inside self angles */
        c1Angle = vhfAngleOfPointRelativeCenter(center1, center); // atan
        ba = (angle>=0.0) ? begAngle : (begAngle+angle);
        if (ba < 0.0) ba += 360.0;
        if (ba > 360.0) ba -= 360.0;
        ea = ba + Abs(angle);
        if (ea >= 360.0) ea -= 360.0;

        /* angle1 on arc of center inside other angles */
        cAngle = vhfAngleOfPointRelativeCenter(center, center1); // atan
        begAngle1 = vhfAngleOfPointRelativeCenter(start1, center1);
        ba1 = (angle1>=0.0) ? begAngle1 : (begAngle1+angle1);
        if (ba1 < 0.0) ba1 += 360.0;
        if (ba1 > 360.0) ba1 -= 360.0;
        ea1 = ba1 + Abs(angle1);
        if (ea1 >= 360.0) ea1 -= 360.0;

        // point on line between start and end (clAngle between beg/end angles)
        if (( (ba < ea && c1Angle >= ba && c1Angle <= ea) || (ba >= ea && (c1Angle <= ea || c1Angle >= ba)))
         && ( (ba1 < ea1 && cAngle >= ba1 && cAngle <= ea1) || (ba1 >= ea1 && (cAngle <= ea1 || cAngle >= ba1))) )
        {
            [self intersectLine:pts :center1 :center];
            *pg1 = pts[0];
            [arc1 intersectLine:pts :center1 :center];
            *pg2 = pts[0];
            return (cDistSqrt - radius - radius1)*(cDistSqrt - radius - radius1);
        }
    }
    /* s / e points to each arc */
    end1 = vhfPointAngleFromRefPoint(center1, start1, angle1);
    dist = distS = [self getPointOnArcClosestToPoint:start1 intersection:&p];
    *pg1 = start1; *pg2 = p;
    if ( (distE = [self getPointOnArcClosestToPoint:end1 intersection:&p]) < dist )
    {   *pg1 = end1; *pg2 = p;
        dist = distE;
    }
    if ( (distS = [arc1 getPointOnArcClosestToPoint:start intersection:&p]) < dist )
    {   *pg1 = start; *pg2 = p;
        dist = distS;
    }
    if ( (distE = [arc1 getPointOnArcClosestToPoint:end intersection:&p]) < dist )
    {   *pg1 = end; *pg2 = p;
        dist = distE;
    }
    return dist;
}

/* created:   2001-10-22
 * modified:  
 * purpose:   distance between arc and line
 * parameter: pl0, pl1
 * return:    squar distance
 */
- (float)sqrDistanceLine:(NSPoint)pl0 :(NSPoint)pl1
{   float	distance, r2 = (radius*radius), distSqrt , clAngle;
    NSPoint	clPoint, iPoint, pts[2];
    float	dist, distS, distE, ba, ea;
    double  d0 = -1.0, d1 = -1.0;

    /* s or e inside Arc */
    if ( (d0=SqrDistPointsM(center, pl0)) <= r2 || (d1=SqrDistPointsM(center, pl1)) <= r2 )
    {
        if ( d1 < 0 )
            d1=SqrDistPointsM(center, pl1);

        if ( (Diff(angle, 360.0) <= TOLERANCE) && (d0 >= r2 || d1 >= r2) )
            return 0.0; // cut

        if ([self intersectLine:pts :pl0 :pl1])
            return 0.0; // cut
    }
    else // s and e of line are outside
    {
        distance = pointOnLineClosestToPoint(pl0, pl1, center, &clPoint); // center to line
        if (Diff(angle, 360.0) <= TOLERANCE)
        {
            if (distance >= r2)
            {   distSqrt = sqrt(distance);
                return (distSqrt - radius)*(distSqrt - radius);
            }
            return 0.0; // arc cut line
        }

        if ( distance <= r2 && [self intersectLine:pts :pl0 :pl1])
            return 0.0;

        /* check if point on Line between sa/ea */
        if ( distance > r2 )
        {
            clAngle = vhfAngleOfPointRelativeCenter(clPoint, center); // atan
            ba = (angle>=0.0) ? begAngle : (begAngle+angle);
            if (ba < 0.0) ba += 360.0;
            if (ba > 360.0) ba -= 360.0;
            ea = ba + Abs(angle);
            if (ea >= 360.0) ea -= 360.0;

            // point on line between start and end (clAngle between beg/end angles)
            if ( (ba < ea && clAngle >= ba && clAngle <= ea) || (ba >= ea && (clAngle <= ea || clAngle >= ba)) )
            {
                distSqrt = sqrt(distance);
                return (distSqrt - radius)*(distSqrt - radius);
            }
        }
    }
    /* now nearest Distance of s/e of line or arc is it */
    distS = pointOnLineClosestToPoint(pl0, pl1, start, &iPoint); // start arc to line
    distE = pointOnLineClosestToPoint(pl0, pl1, end, &iPoint); // end arc to line
    dist = (distS < distE) ? distS : distE;

    distS = [self getPointOnArcClosestToPoint:pl0 intersection:&iPoint]; // start line to arc
    distE = [self getPointOnArcClosestToPoint:pl1 intersection:&iPoint]; // end line to arc

    if (distS < dist )
        dist = distS;
    return ( distE < dist ) ? (distE) : (dist);
}

/* created:   2001-10-22
 * modified:  
 * purpose:   distance between arc and arc
 * parameter: pl0, pl1
 * return:    squar distance
 */
- (float)sqrDistanceArc:(NSPoint)center1 :(NSPoint)start1 :(float)angle1
{   double	cDist, cDistSqrt, dist=MAXCOORD, distS, distE, radius1 = sqrt(SqrDistPoints(start1, center1));
    NSPoint	end1, p;
    VArc    *arc1 = nil;

    cDist = SqrDistPointsM(center1, center);
    cDistSqrt = sqrt(cDist);
    if ( Diff(angle1, 360.0) <= TOLERANCE && Diff(angle, 360.0) <= TOLERANCE ) // we check if centers near enough
    {
        if ( cDistSqrt >= radius+radius1 )
            return (cDistSqrt - radius - radius1)*(cDistSqrt - radius - radius1);
        else if ( cDistSqrt >= Diff(radius, radius1) )
            return 0.0; // arcs cut each other
        else
            return (Max(radius, radius1) - cDistSqrt - Min(radius, radius1))*
                   (Max(radius, radius1) - cDistSqrt - Min(radius, radius1));
    }

    /* cDist small enough for possible intersection */
    if ( cDistSqrt <= radius+radius1 )
    {   NSPoint pArray[2];
        NSRect  bnds = [self bounds];

        arc1 = [VArc arc];
        [arc1 setCenter:center1 start:start1 angle:angle1];
        if ( [arc1 intersectArc:pArray :center :start :angle :&bnds] )
            return 0.0; // cut
    }
    else // if ( cDistSqrt >= radius+radius1 )
    {   double  c1Angle, cAngle, ba, ea, ba1, ea1, begAngle1;

        /* check if center pt line is inside each angle */

        /* angle on self of center1 inside self angles */
        c1Angle = vhfAngleOfPointRelativeCenter(center1, center); // atan
        ba = (angle>=0.0) ? begAngle : (begAngle+angle);
        if (ba < 0.0) ba += 360.0;
        if (ba > 360.0) ba -= 360.0;
        ea = ba + Abs(angle);
        if (ea >= 360.0) ea -= 360.0;

        /* angle1 on arc of center inside other angles */
        cAngle = vhfAngleOfPointRelativeCenter(center, center1); // atan
        begAngle1 = vhfAngleOfPointRelativeCenter(start1, center1);
        ba1 = (angle1>=0.0) ? begAngle1 : (begAngle1+angle1);
        if (ba1 < 0.0) ba1 += 360.0;
        if (ba1 > 360.0) ba1 -= 360.0;
        ea1 = ba1 + Abs(angle1);
        if (ea1 >= 360.0) ea1 -= 360.0;

        // point on line between start and end (clAngle between beg/end angles)
        if (( (ba < ea && c1Angle >= ba && c1Angle <= ea) || (ba >= ea && (c1Angle <= ea || c1Angle >= ba)))
         && ( (ba1 < ea1 && cAngle >= ba1 && cAngle <= ea1) || (ba1 >= ea1 && (cAngle <= ea1 || cAngle >= ba1))) )
            return (cDistSqrt - radius - radius1)*(cDistSqrt - radius - radius1);
    }
    /* s / e points to each arc */
    end1 = vhfPointAngleFromRefPoint(center1, start1, angle1);
    distS = [self getPointOnArcClosestToPoint:start1 intersection:&p];
    distE = [self getPointOnArcClosestToPoint:end1 intersection:&p];
    dist = (distS < distE) ? distS : distE;

    if ( !arc1 )
    {   arc1 = [VArc arc];
        [arc1 setCenter:center1 start:start1 angle:angle1];
    }
    distS = [arc1 getPointOnArcClosestToPoint:start intersection:&p];
    distE = [arc1 getPointOnArcClosestToPoint:end intersection:&p];

    if (distS < dist )
        dist = distS;
    return ( distE < dist ) ? (distE) : (dist);
}

- (float)sqrDistanceCurve:(NSPoint*)pc
{   int     i, j, cnt0 = 0, cnt1 = 0, n0, n1;
    NSPoint *pts0, *pts1;
    float   length1, distance = MAXCOORD, dist, flatness = 0.1; // 0.002
    float   p0Angle, pLAngle, pMAngle, ba, ea;
    double  t, tplus1;
    VCurve  *crv1 = [VCurve curve];
    
    [crv1 setVertices:pc[0] :pc[1] :pc[2] :pc[3]];
    length1 = [crv1 length];

    n1 = length1/flatness;
    
    pts1 = NSZoneMalloc([self zone], (n1+1)*sizeof(NSPoint));

    tplus1 = 1.0/(double)n1;

    for (i=0, t=0; i<n1 && t <= 1.0; i++, t+=tplus1)
    {   pts1[i] = [crv1 pointAt:t]; cnt1++; }
    pts1[cnt1++] = pc[3];

    /* distance between all points - and center */
    /* OR Angle of pts1[0] pts1[cnt1-1] between s/e angle */

    p0Angle = vhfAngleOfPointRelativeCenter(pts1[0], center); // atan
    pMAngle = vhfAngleOfPointRelativeCenter(pts1[cnt1/2], center); // atan
    pLAngle = vhfAngleOfPointRelativeCenter(pts1[cnt1-1], center); // atan
    ba = (angle>=0.0) ? begAngle : (begAngle+angle);
    if (ba < 0.0) ba += 360.0;
    if (ba > 360.0) ba -= 360.0;
    ea = ba + Abs(angle);
    if (ea >= 360.0) ea -= 360.0;

    if ( (((ba < ea && p0Angle >= ba && p0Angle <= ea) || (ba >= ea && (p0Angle <= ea || p0Angle >= ba))) &&
          ((ba < ea && pMAngle >= ba && pMAngle <= ea) || (ba >= ea && (pMAngle <= ea || pMAngle >= ba))) &&
          ((ba < ea && pLAngle >= ba && pLAngle <= ea) || (ba >= ea && (pLAngle <= ea || pLAngle >= ba))))
        ||  Diff(angle, 360.0) <= TOLERANCE )
    {
        for(i=0; i < cnt0; i++)
        {
            for(j=0; j < cnt1; j++)
            {
                if ( (dist=SqrDistPoints(center, pts1[j])) < distance )
                    distance = dist;
            }
        }
        NSZoneFree([self zone], pts1);
        if ( distance <= radius*radius )
            return 0.0;
        else
        {   float   distSqrt = sqrt(distance);
            return (distSqrt - radius)*(distSqrt - radius);
        }
    }
    else // like CurveCurve OR cnt1 times -getPointOnArcClosestToPoint:intersection:
    {   int         ix0m, ix0p, ix1m, ix1p, ix0 = 0, ix1 = 0;
        double		dx, chordAngle;
        NSPoint		ipt;


        /* calc chord angle */
        if ((dx = radius - (flatness/2.0)) <= 0.0)
            n0 = 1;
        else
        {	chordAngle = RadToDeg(acos(dx/radius))*2.0;
            if ( chordAngle < 0.5 )
                chordAngle = 0.5;
            n0 = (int)ceil(Abs(angle) / chordAngle);	/* number of lines */
        }
        chordAngle = angle / n0;	/* chord angle to get lines of equal length */

        pts0 = NSZoneMalloc([self zone], (n0+1)*sizeof(NSPoint));

        pts0[0] = start; cnt0++;
        for ( i=1; i<=n0; i++ )
        {	double	a = DegToRad( begAngle+(double)i*chordAngle );

            pts0[i].x = center.x + radius * cos(a);
            pts0[i].y = center.y + radius * sin(a);
            cnt0++;
        }

        for(i=0; i < cnt0; i++)
        {
            for(j=0; j < cnt1; j++)
            {
                if ( (dist=SqrDistPoints(pts0[i], pts1[j])) < distance )
                {   distance = dist; ix0 = i; ix1 = j; }
            }
        }
        ix0m = (ix0 > 0) ? (ix0-1) : (0);
        ix0p = (ix0 < cnt0-1) ? (ix0+1) : (cnt0-1);
        ix1m = (ix1 > 0) ? (ix1-1) : (0);
        ix1p = (ix1 < cnt1-1) ? (ix1+1) : (cnt1-1);

        if ( vhfIntersectLines(&ipt, pts0[ix0m], pts0[ix0], pts1[ix1m], pts1[ix1]))
        {   NSZoneFree([self zone], pts0); NSZoneFree([self zone], pts1);
            return 0.0;
        }
        if ( vhfIntersectLines(&ipt, pts0[ix0m], pts0[ix0], pts1[ix1], pts1[ix1p]))
        {   NSZoneFree([self zone], pts0); NSZoneFree([self zone], pts1);
            return 0.0;
        }
        if ( vhfIntersectLines(&ipt, pts0[ix0], pts0[ix0p], pts1[ix1m], pts1[ix1]))
        {   NSZoneFree([self zone], pts0); NSZoneFree([self zone], pts1);
            return 0.0;
        }
        if ( vhfIntersectLines(&ipt, pts0[ix0], pts0[ix0p], pts1[ix1], pts1[ix1p]))
        {   NSZoneFree([self zone], pts0); NSZoneFree([self zone], pts1);
            return 0.0;
        }

        if ((dist=pointOnLineClosestToPoint(pts1[ix1m], pts1[ix1], pts0[ix0], &ipt)) < distance) // end of l2 to self
            distance = dist;
        if ((dist=pointOnLineClosestToPoint(pts1[ix1], pts1[ix1p], pts0[ix0], &ipt)) < distance) // end of l2 to self
            distance = dist;
        if ((dist=pointOnLineClosestToPoint(pts0[ix0m], pts0[ix0], pts1[ix1], &ipt)) < distance) // beg of self to l2
            distance = dist;
        if ((dist=pointOnLineClosestToPoint(pts0[ix0], pts0[ix0p], pts1[ix1], &ipt)) < distance) // end of self to l2
            distance = dist;
        NSZoneFree([self zone], pts0);
    }
    NSZoneFree([self zone], pts1);
    return (distance < 0.000001) ? (0.0) : (distance);
}

- (float)sqrDistanceCurve:(NSPoint*)pc :(NSPoint*)pg1 :(NSPoint*)pg2
{   int     i, j, cnt0 = 0, cnt1 = 0, n0, n1;
    NSPoint *pts0, *pts1;
    float   length1, distance = MAXCOORD, dist, flatness = 0.1; // 0.002
    float   p0Angle, pLAngle, pMAngle, ba, ea;
    double  t, tplus1;
    VCurve  *crv1 = [VCurve curve];
    
    [crv1 setVertices:pc[0] :pc[1] :pc[2] :pc[3]];
    length1 = [crv1 length];

    n1 = length1/flatness;
    
    pts1 = NSZoneMalloc([self zone], (n1+1)*sizeof(NSPoint));

    tplus1 = 1.0/(double)n1;

    for (i=0, t=0; i<n1 && t <= 1.0; i++, t+=tplus1)
    {   pts1[i] = [crv1 pointAt:t]; cnt1++; }
    pts1[cnt1++] = pc[3];

    /* distance between all points - and center */
    /* OR Angle of pts1[0] pts1[cnt1-1] between s/e angle */

    p0Angle = vhfAngleOfPointRelativeCenter(pts1[0], center); // atan
    pMAngle = vhfAngleOfPointRelativeCenter(pts1[cnt1/2], center); // atan
    pLAngle = vhfAngleOfPointRelativeCenter(pts1[cnt1-1], center); // atan
    ba = (angle>=0.0) ? begAngle : (begAngle+angle);
    if (ba < 0.0) ba += 360.0;
    if (ba > 360.0) ba -= 360.0;
    ea = ba + Abs(angle);
    if (ea >= 360.0) ea -= 360.0;

    if ( (((ba < ea && p0Angle >= ba && p0Angle <= ea) || (ba >= ea && (p0Angle <= ea || p0Angle >= ba))) &&
          ((ba < ea && pMAngle >= ba && pMAngle <= ea) || (ba >= ea && (pMAngle <= ea || pMAngle >= ba))) &&
          ((ba < ea && pLAngle >= ba && pLAngle <= ea) || (ba >= ea && (pLAngle <= ea || pLAngle >= ba))))
        ||  Diff(angle, 360.0) <= TOLERANCE )
    {   NSPoint cPt = NSZeroPoint, pts[6];

        for (j=0; j < cnt1; j++)
        {
            if ( (dist = SqrDistPoints(center, pts1[j])) < distance )
            {   distance = dist;
                cPt = pts1[j]; // calc distance pts only one time
            }
        }
        NSZoneFree([self zone], pts1);
        if ( distance <= radius*radius )
        {
            [self intersectCurve:pts :pc];
            *pg1 = *pg2 = pts[0];
            return 0.0;
        }
        else
        {   float   distSqrt = sqrt(distance);

            [self intersectLine:pts :cPt :center];
            *pg1 = cPt; *pg2 = pts[0];
            return (distSqrt - radius)*(distSqrt - radius);
        }
    }
    else // like CurveCurve OR cnt1 times -getPointOnArcClosestToPoint:intersection:
    {   int         ix0m, ix0p, ix1m, ix1p, ix0 = 0, ix1 = 0;
        double		dx, chordAngle;
        NSPoint		ipt;


        /* calc chord angle */
        if ((dx = radius - (flatness/2.0)) <= 0.0)
            n0 = 1;
        else
        {	chordAngle = RadToDeg(acos(dx/radius))*2.0;
            if ( chordAngle < 0.5 )
                chordAngle = 0.5;
            n0 = (int)ceil(Abs(angle) / chordAngle);	/* number of lines */
        }
        chordAngle = angle / n0;	/* chord angle to get lines of equal length */

        pts0 = NSZoneMalloc([self zone], (n0+1)*sizeof(NSPoint));

        pts0[0] = start; cnt0++;
        for ( i=1; i<=n0; i++ )
        {	double	a = DegToRad( begAngle+(double)i*chordAngle );

            pts0[i].x = center.x + radius * cos(a);
            pts0[i].y = center.y + radius * sin(a);
            cnt0++;
        }

        for (i=0; i < cnt0; i++)
        {
            for (j=0; j < cnt1; j++)
            {
                if ( (dist=SqrDistPoints(pts0[i], pts1[j])) < distance )
                {   distance = dist; ix0 = i; ix1 = j;
                    *pg1 = pts0[i]; *pg2 = pts1[j];
                }
            }
        }

        ix0m = (ix0 > 0) ? (ix0-1) : (0);
        ix0p = (ix0 < cnt0-1) ? (ix0+1) : (cnt0-1);
        ix1m = (ix1 > 0) ? (ix1-1) : (0);
        ix1p = (ix1 < cnt1-1) ? (ix1+1) : (cnt1-1);

        if ( vhfIntersectLines(&ipt, pts0[ix0m], pts0[ix0], pts1[ix1m], pts1[ix1]))
        {   *pg2 = *pg1 = ipt;
            NSZoneFree([self zone], pts0); NSZoneFree([self zone], pts1);
            return 0.0;
        }
        if ( vhfIntersectLines(&ipt, pts0[ix0m], pts0[ix0], pts1[ix1], pts1[ix1p]))
        {   *pg2 = *pg1 = ipt;
            NSZoneFree([self zone], pts0); NSZoneFree([self zone], pts1);
            return 0.0;
        }
        if ( vhfIntersectLines(&ipt, pts0[ix0], pts0[ix0p], pts1[ix1m], pts1[ix1]))
        {   *pg2 = *pg1 = ipt;
            NSZoneFree([self zone], pts0); NSZoneFree([self zone], pts1);
            return 0.0;
        }
        if ( vhfIntersectLines(&ipt, pts0[ix0], pts0[ix0p], pts1[ix1], pts1[ix1p]))
        {   *pg2 = *pg1 = ipt;
            NSZoneFree([self zone], pts0); NSZoneFree([self zone], pts1);
            return 0.0;
        }

        if ((dist=pointOnLineClosestToPoint(pts1[ix1m], pts1[ix1], pts0[ix0], &ipt)) < distance) // end of l2 to self
        {   *pg1 = ipt; *pg2 = pts0[ix0];
            distance = dist;
        }
        if ((dist=pointOnLineClosestToPoint(pts1[ix1], pts1[ix1p], pts0[ix0], &ipt)) < distance) // end of l2 to self
        {   *pg1 = ipt; *pg2 = pts0[ix0];
            distance = dist;
        }
        if ((dist=pointOnLineClosestToPoint(pts0[ix0m], pts0[ix0], pts1[ix1], &ipt)) < distance) // beg of self to l2
        {   *pg1 = ipt; *pg2 = pts1[ix1];
            distance = dist;
        }
        if ((dist=pointOnLineClosestToPoint(pts0[ix0], pts0[ix0p], pts1[ix1], &ipt)) < distance) // end of self to l2
        {   *pg1 = ipt; *pg2 = pts1[ix1];
            distance = dist;
        }
        NSZoneFree([self zone], pts0);
    }
    NSZoneFree([self zone], pts1);
    return (distance < 0.000001) ? (0.0) : (distance);
}

/*
 * created:  02.09.93
 * modified: 21.03.96
 * Author:   Florian Wohlgemuth
 *
 * Convert an VArc to Bezier curves
 * Cubic spline interpolation (Bronstein p. 759)
 * Bezier curve (Adobe Systems: PostScript language reference manual p. 393)
 *
 * Algorithm: A Bezier-VCurve is a two-dimensional B-Spline. One for the x
 * and one for the y axis. Each of these splines ranges in x direction from 0 to 1.
 * Calculating the spline for, say, the x direction of the Bezier VCurve
 * we need the start and end points and the delta in these points. With
 * the standard calculation for splines with 2 given points and given deltas,
 * we get the spline. Operating accordingly with the y direction, we can
 * trive the Bezier-Points out of the spline formula.
 *
 * return a list of curves by reference (list)
 * return:   number of curves
 */
#define MAXTORTIES	4
- (NSMutableArray*)curveRepresentation
{   double		x0 = 0.0,
			x1 = 1.0, y0, y1, y_0, y_1,
			h = 1.0,  s0, s1,
			ax, bx, cx, ay, by, cy,
			cax=0, cbx=0, cay=0, cby=0;	/* Checkpoints */
    double		torty, segment;
    int			i, number;
    NSMutableArray	*curveList = 0;
    VCurve		*curve;
    float		an, ba, ea;
    NSPoint		pv0, pv1, pv2, pv3;

    /* We can't handle a complete closed arc, we have to split them.
     * The while-loop will refine the segments.
     * Make a domain transformation from degrees over RAD to an intervall of [0,1] of bezier curve.
     */

    torty = Abs(angle);
    if ( torty < 90.0 )
        number = 1;
    else if ( torty < 180.0 )
        number = 2;
    else if ( torty < 270.0 )
        number = 3;
    else
        number = 4; /* 4 or bigger */

    while (number <= MAXTORTIES)
    {
        segment = torty / number;
        for (i=1; i <= number; i++)
        {
            ba = begAngle + ((i-1) * segment);
            ea = ba + segment;
            an = ea - ba;

            /* Supposed our given arc is such a small beast, we build now a interpolating spline.
             * Out of this spline we get the control points of the bezier curve.
             */
            /* The X-Coordinate */
            y0 = radius * cos((ba + x0*an)*Pi/180.0);
            y1 = radius * cos((ba + x1*an)*Pi/180.0);

            /* VArc-Checkpoint in the middle */
            cax = radius * cos((ba + 0.5*an)*Pi/180.0);

            /* Steigung */
            y_0 = radius * -sin((ba + x0*an)*Pi/180.0) * an*Pi/180.0;
            y_1 = radius * -sin((ba + x1*an)*Pi/180.0) * an*Pi/180.0;

            s0 = -2/h*(2 * y_0 + y_1 - 3*(y1 - y0)/h );
            s1 = -2/h*(-2 * y_1 - y_0 + 3*(y1 - y0)/h );

            ax = (s0 - s1) / (-6.0*h);
            bx = (3.0*s0*x0 - 3.0*s0*x1) / (-6.0*h);
            cx = (-6.0*y1 - s0*(h*h) - 3.0*s1*(x0*x0) + 6.0*y0 + s1*(h*h) + 3.0*s0*(x1*x1)) / (-6.0*h);

            pv0.x = center.x + (-6.0*y0*x1 + 6.0*y1*x0 + s0*(h*h)*x1 - s0*x1*x1*x1 + s1*x0*x0*x0 - s1*(h*h)*x0) / (-6.0*h);
            pv1.x = pv0.x + cx/3.0;
            pv2.x = pv1.x + (cx + bx)/3.0;
            pv3.x = pv0.x + cx + bx + ax;

            /* Bezier-Checkpoint, again in the middle */
            cbx = ax*0.125 + bx*0.25 + cx*0.5 + pv0.x - center.x;

            /* The Y-Coordinate */
            y0 = radius * sin((ba + x0*an)*Pi/180.0);
            y1 = radius * sin((ba + x1*an)*Pi/180.0);

            /* VArc-Checkpoint in the middle */
            cay = radius * sin((ba + 0.5*an)*Pi/180.0);

            /* Steigung */
            y_0 = radius * cos((ba + x0*an)*Pi/180.0) * an*Pi/180.0;
            y_1 = radius * cos((ba + x1*an)*Pi/180.0) * an*Pi/180.0;

            s0 = -2.0/h*( 2.0 * y_0 + y_1 - 3.0*(y1 - y0)/h );
            s1 = -2.0/h*(-2.0 * y_1 - y_0 + 3.0*(y1 - y0)/h );

            ay = (s0 - s1) / (-6.0*h);
            by = (3.0*s0*x0 - 3.0*s0*x1) / (-6.0*h);
            cy = (-6.0*y1 - s0*(h*h) - 3.0*s1*(x0*x0) + 6.0*y0 + s1*(h*h) + 3.0*s0*(x1*x1)) / (-6.0*h);

            pv0.y = center.y + (-6.0*y0*x1 + 6.0*y1*x0 + s0*(h*h)*x1 - s0*x1*x1*x1 + s1*x0*x0*x0 - s1*(h*h)*x0) / (-6.0*h);
            pv1.y = pv0.y + cy/3.0;
            pv2.y = pv1.y + (cy + by)/3.0;
            pv3.y = pv0.y + cy + by + ay;

            /* Bezier-Checkpoint, again in the middle */
            cby = ay*0.125 + by*0.25 + cy*0.5 + pv0.y - center.y;

            curve = [VCurve curve];
            [curve setVertices:pv0 :pv1 :pv2 :pv3];
            if (!curveList)
                curveList = [[NSMutableArray allocWithZone:[self zone]] init];
            [curveList addObject:curve];

            if ( ((Abs(cax-cbx) > TOLERANCE) || (Abs(cay-cby) > TOLERANCE)) && number*2 <= MAXTORTIES)
            {	/* We refine the number of segments */
                number = number * 2;
                i = 0;
                break;
            }
        }
        if ( ((Abs(cax-cbx) < TOLERANCE) && (Abs(cay-cby) < TOLERANCE)) || i>=number)
            break;
    }
    return curveList;
}



/* subclassed methods
 */

#define CREATEEVENTMASK NSLeftMouseDraggedMask|NSLeftMouseDownMask|NSLeftMouseUpMask|NSPeriodicMask
- (BOOL)create:(NSEvent *)event in:(DocView*)view
{   NSRect		viewBounds, gridBounds, drawBounds;
    NSPoint		startP, last, gridPoint, drawPoint, lastPoint = NSZeroPoint, hitPoint;
    id			window = [view window];
    VArc 		*drawArcGraphic;
    BOOL		ok = YES, dragging = NO, inTimerLoop = NO, hitEdge = NO;
    float		grid = 1.0 / [view scaleFactor], snap = Prefs_Snap / [view scaleFactor];
    int			windowNum = [event windowNumber];
    float		ea, an;

    [[(App*)NSApp inspectorPanel] loadGraphic:self];	// set the values of the inspector to self

    /* get start location (center of arc), convert window to view coordinates */
    startP = [view convertPoint:[event locationInWindow] fromView:nil];
    hitPoint = startP;
    hitEdge = [view hitEdge:&hitPoint spare:self];	// snap to point
    gridPoint = [view grid:startP];			// set on grid
    if ( hitEdge &&
         ((gridPoint.x == startP.x && gridPoint.y == startP.y)  ||
          (SqrDistPoints(hitPoint, startP) < SqrDistPoints(gridPoint, startP))) )
        startP = hitPoint; // we took the nearer one if we got a hitPoint
    else
        startP = gridPoint;
    viewBounds = [view bounds];				// get the bounds of the view
    [view lockFocus];					// and lock the focus on view

    [self setCenter:startP start:center angle:360.0];
    drawArcGraphic = [[self copy] autorelease];
    [drawArcGraphic setColor:[NSColor lightGrayColor]];
    gridBounds = [self extendedBoundsWithScale:[view scaleFactor]];

    last = startP;

    event = [NSApp nextEventMatchingMask:CREATEEVENTMASK untilDate:[NSDate distantFuture] inMode:NSEventTrackingRunLoopMode dequeue:YES];
    /* now entering the tracking loop
     * get radius of arc
     */
    StartTimer(inTimerLoop);
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
            if ( ([event type] == NSLeftMouseDragged)&&(!dragging) &&
                (Diff(center.x, drawPoint.x) > 3.0*grid || Diff(center.y, drawPoint.y) > 3.0*grid) )
                dragging = YES;
            [view scrollPointToVisible:drawPoint];

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

            [self setCenter:startP start:gridPoint angle:360.0];
            gridBounds = [self extendedBoundsWithScale:[view scaleFactor]];
            [drawArcGraphic setCenter:startP start:drawPoint angle:360.0];
            drawBounds = [drawArcGraphic extendedBoundsWithScale:[view scaleFactor]];
            gridBounds = NSUnionRect(drawBounds, gridBounds);	// the united rect of the two rects we need to redraw the view
            //	[drawArcGraphic getBounds:&drawBounds withKnobs:YES];	// get the bounds of the drawn line
            //	NXUnionRect(&drawBounds, &gridBounds);

            if ( NSContainsRect(viewBounds, gridBounds) )		// arc inside view ?
            {   [drawArcGraphic drawWithPrincipal:view];
                [self drawWithPrincipal:view];
            }
            else
                drawPoint = gridPoint = start;			// else set line invalid

            [window flushWindow];
        }
        event = [NSApp nextEventMatchingMask:CREATEEVENTMASK untilDate:[NSDate distantFuture] inMode:NSEventTrackingRunLoopMode dequeue:YES];
    }

    if ( radius <= grid )		// no size -> not valid
        ok = NO;
    else if ( !NSContainsRect(viewBounds, gridBounds) ) // outside working area (view bounds)
        ok = NO;
    else if ( (!dragging && [event type]==NSLeftMouseDown)||(dragging && [event type]==NSLeftMouseUp) )
    {   /* double click or out of window -> don't set angle */
        if ( [event clickCount] > 1 )
        {   angle = 360.0;
            ok = NO;
        }
        else if ( [event windowNumber] != windowNum )
            ok = NO;
        else
            ok = NSMouseInRect(gridPoint , viewBounds , NO);
    }

    /* get end point of arc
     */
    if ( ok )
    {	event = [NSApp nextEventMatchingMask:CREATEEVENTMASK untilDate:[NSDate distantFuture] inMode:NSEventTrackingRunLoopMode dequeue:YES];
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

                /* delete arc from screen */
                [view drawRect:gridBounds];
                drawPoint = [view convertPoint:drawPoint fromView:nil];
                if ( ([event type] == NSLeftMouseDragged) && (!dragging) &&
                     (Diff(start.x, drawPoint.x) > 3.0*grid || Diff(start.y, drawPoint.y) > 3.0*grid) )
                    dragging = YES;
                [view scrollPointToVisible:drawPoint];
                gridPoint = drawPoint;
                if (![view hitEdge:&gridPoint spare:self])			// snap to point
                    if ( SqrDistPoints(gridPoint, start) <= snap*snap )
                    {   gridPoint = start;
                        vhfPlaySound(@"Pop");
                    }

                [window displayCoordinate:gridPoint ref:NO];
                gridPoint = [view grid:gridPoint];				// fix position to grid

                ea = vhfAngleOfPointRelativeCenter(gridPoint, center);
                an = ea - begAngle;
                if ( angle*an < 0.0 && Diff(angle, an) >= 180.0 )
                    an = (angle>0.0) ? 360.0+an : an-360.0;
                if (an<=TOLERANCE) an = 360.0;
                [self setCenter:center start:start angle:an];
                gridBounds = [self extendedBoundsWithScale:[view scaleFactor]];

                // ea = vhfAngleOfPointRelativeCenter(drawPoint, center);
                // an = ea - begAngle;
                // if ( angle*an < 0.0 && Diff(angle, an) >= 180.0 )
                //     an = 360.0-an;
                [drawArcGraphic setCenter:center start:start angle:an];
                drawBounds = [drawArcGraphic extendedBoundsWithScale:[view scaleFactor]];
                gridBounds = NSUnionRect(drawBounds, gridBounds);	// the united rect of the two rects we need to redraw the view

                if ( NSContainsRect(viewBounds , gridBounds) )		// arc inside view ?
                {   [drawArcGraphic drawWithPrincipal:view];
                    [self drawWithPrincipal:view];
                }
                else
                    drawPoint = gridPoint = start;			// else set line invalid

                [window flushWindow];
            }
            event = [NSApp nextEventMatchingMask:CREATEEVENTMASK untilDate:[NSDate distantFuture] inMode:NSEventTrackingRunLoopMode dequeue:YES];
        }
    }
    StopTimer(inTimerLoop);

    last = gridPoint;

    ok = YES;
    if ( radius <= grid || !angle )		// no length -> not valid
        ok = NO;
    else if ( !NSContainsRect(viewBounds, gridBounds) ) // outside working area (view bounds)
        ok = NO;
    else if ( (!dragging && [event type]==NSLeftMouseDown)||(dragging && [event type]==NSLeftMouseUp) )
    {	if ([event windowNumber] != windowNum)	// out of window -> not valid
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
            [window postEvent:event atStart:1];		// down
        }
	[view display];
        return NO;
    }

    dirty = YES;
    [self setSelected:YES];
    [view cacheGraphic:self];	/* add to graphic cache */

    return YES;
}

/* created:   1996-03-17
 * modified:  
 * parameter: t  0 <= t <= 1
 * purpose:   get a point on the line at t
 */
- (NSPoint)pointAt:(float)t
{   float	a;

    a = angle * t;
    return vhfPointAngleFromRefPoint(center, start, a);
}

/*
 * returns the selected knob or -1
 */
- (int)selectedKnobIndex
{
    return selectedKnob;
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

- (void)setFullArcWithCenter:(NSPoint)p radius:(float)r
{
    center = p;
    start = p; start.x += r;
    angle = 360.0;
    radius = r;
    begAngle = 0.0;
    end = start;
    coordBounds = NSZeroRect;
    dirty = YES;
    graduateDirty = YES;
}

- (void)setCenter:(NSPoint)p start:(NSPoint)s angle:(float)a
{
    center = p;
    start = s;
    angle = a;
    [self calcAddedValues];
    coordBounds = NSZeroRect;
    dirty = YES;
    graduateDirty = YES;
}

- (void)getCenter:(NSPoint*)p start:(NSPoint*)s angle:(float*)a
{
    *p = center;
    *s = start;
    *a = angle;
}

- (float)radius
{
    return radius;
}

- (void)setRadius:(float)r
{
    radius = r;
    start.x = center.x + radius;
    start.y = center.y;
    start = vhfPointAngleFromRefPoint(center, start, begAngle);
    end = vhfPointAngleFromRefPoint(center, start, angle);
    coordBounds = NSZeroRect;
    dirty = YES;
    graduateDirty = YES;
}

- (float)begAngle
{
    if (begAngle < 0.0)
        begAngle = 0.0;
    if (begAngle >= 360.0)
        begAngle -= 360.0;
    return begAngle;
}

- (void)setBegAngle:(float)a
{
    begAngle = a;
    start.x = center.x + radius;
    start.y = center.y;
    start = vhfPointAngleFromRefPoint(center, start, begAngle);
    end = vhfPointAngleFromRefPoint(center, start, angle);
    coordBounds = NSZeroRect;
    dirty = YES;
    graduateDirty = YES;
}

- (float)angle
{
    if (angle < -360.0)
        angle = -360.0;
    if (angle > 360.0)
        angle = 360.0;
    return angle;
}

- (void)setAngle:(float)a
{
    angle = a;
    if (angle < -360.0)
        angle = -360.0;
    if (angle > 360.0)
        angle = 360.0;
    [self calcAddedValues];
    coordBounds = NSZeroRect;
    dirty = YES;
    graduateDirty = YES;
}

/* we need start, center, angle
 */
- (void)calcAddedValues
{
    radius = CalcRadius();
    begAngle = vhfAngleOfPointRelativeCenter(start, center);
    end = vhfPointAngleFromRefPoint(center, start, angle);
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
 * modified:  1998-10-12
 * parameter: x, y	the angles to rotate in x/y direction
 *            p		the point we have to rotate around
 * purpose:   draw the graphic rotated around p with x and y
 */
- (void)drawAtAngle:(float)a withCenter:(NSPoint)cp in:view
{   NSPoint		p;
    NSBezierPath	*bPath = [NSBezierPath bezierPath];

    p = vhfPointRotatedAroundCenter(center, -a, cp);

    [color set];
    [bPath setLineWidth:width];
    [bPath moveToPoint:vhfPointRotatedAroundCenter(start, -a, cp)];
    [bPath appendBezierPathWithArcWithCenter:p radius:radius
                                  startAngle:begAngle-a endAngle:begAngle+angle-a clockwise:(angle < 0.0)];
    [bPath stroke];
}

/* created:  1995-10-21
 * modified: 2002-12-04
 * parameter: x, y	the angles to rotate in x/y direction
 *	      cp	the point we have to rotate around
 * purpose:   rotate the graphic around cp with x and y
 */
- (void)setAngle:(float)a withCenter:(NSPoint)cp
{
    if (filled)
    {   graduateAngle -= a;
        if (graduateAngle < 0.0)
            graduateAngle += 360.0;
        if (graduateAngle > 360.0)
            graduateAngle -= 360.0;
        vhfRotatePointAroundCenter(&radialCenter, NSMakePoint(0.5, 0.5), -a);
        if (radialCenter.x > 1.0) radialCenter.x = 1.0;
        if (radialCenter.x < 0.0) radialCenter.x = 0.0;
        if (radialCenter.y > 1.0) radialCenter.y = 1.0;
        if (radialCenter.y < 0.0) radialCenter.y = 0.0;
        graduateDirty = YES;
    }
    vhfRotatePointAroundCenter(&center, cp, -a);
    vhfRotatePointAroundCenter(&start, cp, -a);
    [self calcAddedValues];
    coordBounds = NSZeroRect;
    dirty = YES;
    if (!graduateDirty && graduateList)
    {   int	i;

        for (i=[graduateList count]-1; i>=0; i--)
            [(VGraphic*)[graduateList objectAtIndex:i] setAngle:a withCenter:cp];
    }
}

- (void)transform:(NSAffineTransform*)matrix
{   NSSize  s;

    s = [matrix transformSize:NSMakeSize(width, width)];
    width = (Abs(s.width) + Abs(s.height)) / 2;
    center = [matrix transformPoint:center];
    s = [matrix transformSize:NSMakeSize(radius, radius)];
    radius = (Abs(s.width) + Abs(s.height)) / 2;
    dirty = graduateDirty = YES;
}

/* modified: 2010-07-18
 */
- (void)scale:(float)x :(float)y withCenter:(NSPoint)cp
{
    width *= (Abs(x)+Abs(y))/2.0;
    center.x = ScaleValue(center.x, cp.x, x);
    center.y = ScaleValue(center.y, cp.y, y);
    radius *= (Abs(x)+Abs(y))/2.0;

    start.x = center.x + radius;
    start.y = center.y;
    start = vhfPointAngleFromRefPoint(center, start, begAngle);
    begAngle = vhfAngleOfPointRelativeCenter(start, center);
    end = vhfPointAngleFromRefPoint(center, start, angle); 
    coordBounds = NSZeroRect;
    dirty = YES;
    graduateDirty = YES;
}

- (void)mirrorAround:(NSPoint)p
{
    center.y = p.y - (center.y - p.y);
    start.y = p.y - (start.y - p.y);
    angle = - angle;

    [self calcAddedValues];
    coordBounds = NSZeroRect;
    dirty = YES;
    if (!graduateDirty && graduateList)
    {   int	i;

        for (i=[graduateList count]-1; i>=0; i--)
            [(VGraphic*)[graduateList objectAtIndex:i] mirrorAround:p];
    }
}

/* return a path from the arc
 */
- (VPath*)pathRepresentation
{   VPath	*pathG = [VPath path];
    VLine	*line;
    VArc	*arc = [[self copy] autorelease];

    [pathG setDirectionCCW:[self isDirectionCCW]];

    [arc setFilled:NO];
    [[pathG list] addObject:arc];
    if ( abs(angle) < 360.0 )
    {
        line = [VLine line];
        [line setVertices:end :center];
        [line setColor:color];
        [[pathG list] addObject:line];
        line = [VLine line];
        [line setVertices:center :start];
        [line setColor:color];
        [[pathG list] addObject:line];
    }

    [pathG setFilled:filled optimize:NO];
    [pathG setWidth:width];
    [pathG setColor:color];
    [pathG setFillColor:fillColor];
    [pathG setEndColor:endColor];
    [pathG setGraduateAngle:graduateAngle];
    [pathG setStepWidth:stepWidth];
    [pathG setRadialCenter:radialCenter];

    return pathG;
}

/*
 * draws the arc
 * modified: 2007-04-20 (default width added)
 */
- (void)drawWithPrincipal:principal
{   NSBezierPath	*bPath;
    NSColor		*oldColor=nil;
    float		defaultWidth;

    if (filled == 1)
    {   [[self pathRepresentation] drawWithPrincipal:principal];
        return;
    }
    if ((filled == 2 || filled == 3 || filled == 4) && (graduateDirty || !graduateList))
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
    }
    else if ((filled == 2 || filled == 3 || filled == 4) && graduateList && !graduateDirty)
    {   int	i, gCnt = [graduateList count];
        BOOL	antialias = VHFAntialiasing();

        /* draw graduateList */
        VHFSetAntialiasing(NO);
        for (i=0; i<gCnt; i++)
            [(VGraphic*)[graduateList objectAtIndex:i] drawWithPrincipal:principal];
        if (antialias) VHFSetAntialiasing(antialias);
    }
    if (filled && !width) // do not stroke !
        return;

    /* colorSeparation */
    if (!VHFIsDrawingToScreen() && [principal separationColor])
    {   NSColor	*sepColor = [self separationColor:color]; // get individual separation color

        oldColor = [color retain];
        [self setColor:sepColor];
    }

    [super drawWithPrincipal:principal];

    defaultWidth = [NSBezierPath defaultLineWidth];
    bPath = [NSBezierPath bezierPath];
    [bPath setLineWidth:(width > 0.0) ? width : defaultWidth];	// 2007-04-20: defaultWidth
    [bPath setLineCapStyle: NSRoundLineCapStyle];
    [bPath setLineJoinStyle:NSRoundLineJoinStyle];
    [bPath moveToPoint:start];
    [bPath appendBezierPathWithArcWithCenter:center radius:radius
                                  startAngle:begAngle endAngle:begAngle+angle clockwise:(angle < 0.0)];
    [bPath stroke];

    if ([principal showDirection])
        [self drawDirectionAtScale:[principal scaleFactor]];

    if (!VHFIsDrawingToScreen() && [principal separationColor])
    {   [self setColor:oldColor];
        [oldColor release];
    }
}

/* modified: 08.11.96
 *
 * Returns the bounds.
 */
- (NSRect)bounds
{   NSPoint	ll, ur;
    NSRect	bRect = [self coordBounds];

    ll = bRect.origin;
    ur.x = bRect.origin.x + bRect.size.width;
    ur.y = bRect.origin.y + bRect.size.height;
    ll.x = Min(ll.x, center.x); ll.y = Min(ll.y, center.y);
    ur.x = Max(ur.x, center.x); ur.y = Max(ur.y, center.y);

    ll.x -= width/2.0;
    ll.y -= width/2.0;
    ur.x += width/2.0;
    ur.y += width/2.0;

    bRect.origin = ll;
    bRect.size.width  = MAX(ur.x - ll.x, 0.001);
    bRect.size.height = MAX(ur.y - ll.y, 0.001);

    return bRect;
}

- (NSRect)coordBounds
{
    if (coordBounds.size.width == 0.0 && coordBounds.size.height == 0.0)
    {   float	ba, ea;
        NSPoint	p, ll, ur;

        ll.x = Min(start.x, end.x); ll.y = Min(start.y, end.y);
        ur.x = Max(start.x, end.x); ur.y = Max(start.y, end.y);

        /* we need positive angles with ba < ea */
        ba = (angle>=0.0) ? begAngle : (begAngle+angle);
        if (ba < 0.0)   ba += 360.0;
        if (ba > 360.0) ba -= 360.0;
        ea = ba + Abs(angle);

        if ((ba < 360.0 || ba >= ea-360.0-TOLERANCE) && ea >= 360.0)	// 0 degree
        {   p.x = center.x+radius; p.y = center.y;
            ll.x = Min(ll.x, p.x); ll.y = Min(ll.y, p.y);
            ur.x = Max(ur.x, p.x); ur.y = Max(ur.y, p.y);
        }
        if ((ba <= 90.0 && ea >= 90.0) || (ba<=450 && ea>=450))		// 90 degree
        {   p.x = center.x; p.y = center.y+radius;
            ll.x = Min(ll.x, p.x); ll.y = Min(ll.y, p.y);
            ur.x = Max(ur.x, p.x); ur.y = Max(ur.y, p.y);
        }
        if ((ba <= 180.0 && ea >= 180.0) || (ba<=540 && ea>=540))	// 180 degree
        {   p.x = center.x-radius; p.y = center.y;
            ll.x = Min(ll.x, p.x); ll.y = Min(ll.y, p.y);
            ur.x = Max(ur.x, p.x); ur.y = Max(ur.y, p.y);
        }
        if ((ba <= 270.0 && ea >= 270.0) || (ba<=630 && ea>=630))	// 270 degree
        {   p.x = center.x; p.y = center.y-radius;
            ll.x = Min(ll.x, p.x); ll.y = Min(ll.y, p.y);
            ur.x = Max(ur.x, p.x); ur.y = Max(ur.y, p.y);
        }

        coordBounds.origin = ll;
        coordBounds.size.width  = MAX(ur.x - ll.x, 0.001); // 1.0
        coordBounds.size.height = MAX(ur.y - ll.y, 0.001);
    }
    return coordBounds;
}

/*
 * Returns the bounds with the given rotation.
 */
- (NSRect)boundsAtAngle:(float)a withCenter:(NSPoint)cp
{   NSPoint	p0, p1;
    NSPoint	ll, ur;
    NSRect	bRect;

    bRect = [self bounds];
    p0 = bRect.origin;
    vhfRotatePointAroundCenter(&p0, cp, -a);
    p1.x = bRect.origin.x + bRect.size.width;
    p1.y = bRect.origin.y;
    vhfRotatePointAroundCenter(&p1, cp, -a);
    ll.x = Min(p0.x, p1.x); ll.y = Min(p0.y, p1.y);
    ur.x = Max(p0.x, p1.x); ur.y = Max(p0.y, p1.y);

    p0.x = bRect.origin.x + bRect.size.width;
    p0.y = bRect.origin.y + bRect.size.height;
    vhfRotatePointAroundCenter(&p0, cp, -a);
    ll.x = Min(ll.x, p0.x); ll.y = Min(ll.y, p0.y);
    ur.x = Max(ur.x, p0.x); ur.y = Max(ur.y, p0.y);

    p0.x = bRect.origin.x;
    p0.y = bRect.origin.y + bRect.size.height;
    vhfRotatePointAroundCenter(&p0, cp, -a);
    ll.x = Min(ll.x, p0.x); ll.y = Min(ll.y, p0.y);
    ur.x = Max(ur.x, p0.x); ur.y = Max(ur.y, p0.y);

    bRect.origin = ll;
    bRect.size.width  = ur.x - ll.x;
    bRect.size.height = ur.y - ll.y;
    return bRect;
}

- (NSPoint)appendToBezierPath:(NSBezierPath*)bPath currentPoint:(NSPoint)currentPoint
{
    if (Diff(currentPoint.x, start.x) > 0.08 || Diff(currentPoint.y, start.y) > 0.08)
        [bPath moveToPoint:start];
    [bPath appendBezierPathWithArcWithCenter:center radius:radius
                                  startAngle:begAngle endAngle:begAngle+angle clockwise:(angle < 0.0)];
    return end;
}

/*
 * Depending on the pt_num passed in, return the rectangle
 * that should be used for scrolling purposes. When the rectangle
 * passes out of the visible rectangle then the screen should
 * scroll.
 */
- (NSRect)scrollRect:(int)pt_num inView:(id)aView
{   float	knobsize;
    NSRect	aRect;

    if (pt_num != 0 && pt_num != 1)
        aRect = [self bounds];
    else if (pt_num == 0)
    {
        aRect.origin.x = start.x;
        aRect.origin.y = start.y;
        aRect.size.width = 0;
        aRect.size.height = 0;
    }
    else
    {	NSPoint	p;

        p = start;
        vhfRotatePointAroundCenter(&p, center, -angle);
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
{	NSPoint		viewMax;
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
 * created:		25.09.95
 * modified:
 * parameter:	pt_num	number of vertices
 *				p		the new position in
 * purpose:		Sets a vertice to a new position.
 *				If it is a edge move the vertices with it
 */
- (void)movePoint:(int)pt_num to:(NSPoint)p
{   NSPoint	pc;
    NSPoint	pt;

    /* set point */
    switch (pt_num)
    {
        case PT_START:	pc = start; break;
        default:	pc = end; break;
        case PT_CENTER:	pc = center;
    }

    pt.x = p.x - pc.x;
    pt.y = p.y - pc.y;
    [self movePoint:pt_num by:pt];
}

/* needed for undo
 * if control button is set -> the radius of an arc will changed (else not!)
 * for the way back we need the possibility to say "the button is set"
 */
- (void)movePoint:(int)pt_num by:(NSPoint)pt control:(BOOL)control
{   float	dx, dy, a, c;
    NSPoint	p;

    /* set point */
    switch (pt_num)
    {
        case PT_START:	// start angle
            p.x = start.x + pt.x;
            p.y = start.y + pt.y;
            if (!control)	// don't change radius
            {   dx = p.x-center.x;
                dy = p.y-center.y;
                if ( (c = sqrt(dx*dx+dy*dy)) == 0.0 )
                    break;
                start.x = center.x + (dx*radius)/c;	// shorten vector to get a point on the arc
                start.y = center.y + (dy*radius)/c;
                a = begAngle + angle; if (a<0.0) a+=360.0; if (a>=360.0) a-=360.0;
                begAngle = vhfAngleOfPointRelativeCenter(start, center);
                a = a - begAngle;	/* we don't move the end point */
                if ( angle*a < 0.0 && Diff(angle, a) >= 180.0 )
                    a = (angle>0.0) ? 360.0+a : a-360.0;
                angle = a;
            }
            else
            {	float	ea = begAngle+angle;

                start = p;
                a = vhfAngleOfPointRelativeCenter(start, center);
                if (angle > 0 && ea-a < 0)
                    angle += (360.0 - a) + begAngle;
                else if (angle < 0 && ea-a > 0)
                    angle += (360.0 - begAngle) + a;
                else
                    angle = ea - a;
                if (angle > 360.0)  angle -= 360.0;
                if (angle < -360.0) angle += 360.0;
                begAngle = a;
                radius = CalcRadius();
                end = vhfPointAngleFromRefPoint(center, start, angle);
            }
            graduateDirty = YES;
            break;
        default:	// end angle
            p.x = end.x + pt.x;
            p.y = end.y + pt.y;
            if (!control)
            {   dx = p.x-center.x;
                dy = p.y-center.y;
                if ( (c = sqrt(dx*dx+dy*dy)) == 0.0 )
                    break;
                end.x = center.x + (dx*radius)/c;	// shorten vector to get a point on the arc
                end.y = center.y + (dy*radius)/c;
                a = vhfAngleOfPointRelativeCenter(end, center);
                a = a - begAngle;
                if ( angle*a < 0.0 && Diff(angle, a) >= 180.0 )
                    a = (angle>0.0) ? 360.0+a : a-360.0;
                angle = a;
            }
            else
            {   end = p;
                a = vhfAngleOfPointRelativeCenter(end, center);
                if (angle < 0 && a-begAngle > 0)
                    angle -= (360.0 - a) + (begAngle + angle);
                else if (angle > 0 && a-begAngle < 0)
                    angle += (360.0 - (begAngle + angle)) + a;
                 else
                    angle = a - begAngle;
                start = vhfPointAngleFromRefPoint(center, end, -angle);
                radius = CalcRadius();
            }
            graduateDirty = YES;
            break;
        case PT_CENTER:	// center
            [self moveBy:pt];
    }
    coordBounds = NSZeroRect;
    dirty = YES;
}
- (void)movePoint:(int)pt_num to:(NSPoint)p control:(BOOL)control
{   NSPoint	pc;
    NSPoint	pt;

    /* set point */
    switch (pt_num)
    {
        case PT_START:	pc = start; break;
        default:	pc = end; break;
        case PT_CENTER:	pc = center;
    }

    pt.x = p.x - pc.x;
    pt.y = p.y - pc.y;
    [self movePoint:pt_num by:pt control:control];
}

/*
 * pt_num is the changing control point. pt holds the relative change in each coordinate. 
 * The relative is needed and not the absolute because the closest inside control point
 * changes when one of the outside points change.
 */
- (void)movePoint:(int)pt_num by:(NSPoint)pt
{   float	dx, dy, a, c;
    NSPoint	p;
    BOOL	control = [(App*)NSApp control];

    /* set point */
    switch (pt_num)
    {
        case PT_START:	// start angle
            p.x = start.x + pt.x;
            p.y = start.y + pt.y;
            if (!control)	// don't change radius
            {   dx = p.x-center.x;
                dy = p.y-center.y;
                if ( (c = sqrt(dx*dx+dy*dy)) == 0.0 )
                    break;
                start.x = center.x + (dx*radius)/c;	// shorten vector to get a point on the arc
                start.y = center.y + (dy*radius)/c;
                a = begAngle + angle; if (a<0.0) a+=360.0; if (a>=360.0) a-=360.0;
                begAngle = vhfAngleOfPointRelativeCenter(start, center);
                a = a - begAngle;	/* we don't move the end point */
                if ( angle*a <= 0.0 && Diff(angle, a) >= 180.0 )
                    a = (angle>0.0) ? 360.0+a : a-360.0;
                angle = a;
            }
            else
            {	float	ea = begAngle+angle;

                start = p;
                a = vhfAngleOfPointRelativeCenter(start, center);
                if (angle > 0 && ea-a < 0)
                    angle += (360.0 - a) + begAngle;
                else if (angle < 0 && ea-a > 0)
                    angle += (360.0 - begAngle) + a;
                else
                    angle = ea - a;
                if (angle > 360.0)  angle -= 360.0;
                if (angle < -360.0) angle += 360.0;
                begAngle = a;
                radius = CalcRadius();
                end = vhfPointAngleFromRefPoint(center, start, angle);
            }
            graduateDirty = YES;
            break;
        default:	// end angle
            p.x = end.x + pt.x;
            p.y = end.y + pt.y;
            if (!control)
            {   dx = p.x-center.x;
                dy = p.y-center.y;
                if ( (c = sqrt(dx*dx+dy*dy)) == 0.0 )
                    break;
                end.x = center.x + (dx*radius)/c;	// shorten vector to get a point on the arc
                end.y = center.y + (dy*radius)/c;
                a = vhfAngleOfPointRelativeCenter(end, center);
                a = a - begAngle;
                if ( angle*a <= 0.0 && Diff(angle, a) >= 180.0 )
                    a = (angle>0.0) ? 360.0+a : a-360.0;
                angle = a;
            }
            else
            {   end = p;
                a = vhfAngleOfPointRelativeCenter(end, center);
                a = a - begAngle;
                if ( angle*a <= 0.0 && Diff(angle, a) >= 180.0 )
                    a = (angle>0.0) ? 360.0+a : a-360.0;
                angle = a;
                start = vhfPointAngleFromRefPoint(center, end, -angle);
                radius = CalcRadius();
            }
            graduateDirty = YES;
            break;
        case PT_CENTER:	// center
            [self moveBy:pt];
    }
    coordBounds = NSZeroRect;
    dirty = YES;
}

/* The pt argument holds the relative point change. */
- (void)moveBy:(NSPoint)pt
{
    center.x += pt.x;
    center.y += pt.y;
    start.x += pt.x;
    start.y += pt.y;
    [self calcAddedValues];
    coordBounds = NSZeroRect;
    dirty = YES;
    if (!graduateDirty && graduateList)
    {   int	i;
        for (i=[graduateList count]-1; i>=0; i--)
            [[graduateList objectAtIndex:i] moveBy:pt];
    }
}

- (void)moveTo:(NSPoint)p
{   NSPoint	p0 = [self pointWithNum:PT_CENTER];

    [self moveBy:NSMakePoint( p.x-p0.x, p.y-p0.y )];
}

- (int)numPoints
{
    return PTS_ARC;
}

/* Given the point number, return the point.
 * default must be the end point of the arc
 */
- (NSPoint)pointWithNum:(int)pt_num
{
    switch (pt_num)
    {
        case PT_START:
            return start;
        default:
            return end;
        case PT_CENTER:
            return center;
    }
}

/*
 * Check for a edge point hit.
 * parameter: p			the mouse position
 *            fuzz		the distance inside we snap to a point
 *            pt		the edge point
 *            controlsize	the size of the controls
 */
- (BOOL)hitEdge:(NSPoint)p fuzz:(float)fuzz :(NSPoint*)pt :(float)controlsize
{   NSRect	knobRect, hitRect;
    int		i;

    hitRect.origin.x = p.x -fuzz/2.0;
    hitRect.origin.y = p.y -fuzz/2.0;
    hitRect.size.width = hitRect.size.height = fuzz;
    knobRect.size.width = knobRect.size.height = controlsize;

    for (i=0; i<PTS_ARC; i++)
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
    for (i=PTS_ARC-1; i>=0; i--)
    {	NSPoint	pt = [self pointWithNum:i];

        knobRect.origin.x = pt.x - controlsize/2.0;
        knobRect.origin.y = pt.y - controlsize/2.0;
        if ( NSPointInRect(p, knobRect) )
        {
            //if ( i==PT_START || i==PT_END )
                selectedKnob = i; // needed for movePoint:to in VPath ?
            [self setSelected:YES];
            *pt_num = i;
            return YES;
        }
    }

    return NO;
}

- (BOOL)hit:(NSPoint)p fuzz:(float)fuzz
{   NSRect	bRect = [self bounds];

    if ( !Prefs_SelectByBorder && filled && [self isPointInside:p] )
        return YES;

    bRect.origin.x -= fuzz;
    bRect.origin.y -= fuzz;
    bRect.size.width  += 2.0 * fuzz;
    bRect.size.height += 2.0 * fuzz;
    if ( NSPointInRect(p, bRect) &&
         distancePointArc(p, center, radius, begAngle, angle) <= fuzz )
        return YES;
    return NO;
}

/* created: 07.04.98
 */
- (void)setDirectionCCW:(BOOL)ccw
{
    if ( ccw != [self isDirectionCCW] )
        [self changeDirection];
}

- (BOOL)isDirectionCCW
{
    return (angle >= 0) ? YES : NO;
}

/*
 * return a path representing the outline of us
 * the path holds at least two curves and two arcs
 * if we need not build a contour a copy of us is returned
 *
 * first we calculate 4 points on each side of us (with the distance w from us)
 * then we build a curve on each side through all 4 points
 *
 * modified: 2011-03-11 (build outline with stroke width + distance)
 */
- contour:(float)w
{   VPath           *path;
    NSMutableArray  *list;
    VArc            *arc;
    float           r;
    NSPoint         p, ps[4];
    int             i;

    if ( [self filled] )
    {
        if ( Abs(angle) < 360.0-TOLERANCE )
        {   VPath	*cPath, *path = [self pathRepresentation];

            cPath = [path contour:w];
            return cPath;
        }

        arc = [VArc arc];

        r = (width + w) / 2.0;			// the amount of growth/shrink
        if ( radius+r < 0.0 )
        {   NSLog(@"VArc contour: Tool diameter exceeding diameter of arc!");
            return nil;
        }
        p.x = center.x + Max(0.0, radius+r);	// we limit the shrink to zero
        p.y = center.y;
        [arc setWidth:0.0];
        [arc setColor:color];
        [arc setCenter:center start:p angle:angle];
        [arc setSelected:[self isSelected]];
        return arc;
    }
    else if ( (w == 0.0 && width == 0.0) || (w<0.0 && -w >= width) )
    {	arc = [VArc arc];
        [arc setWidth:0.0];
        [arc setColor:color];
        [arc setCenter:center start:start angle:angle];
        [arc setSelected:[self isSelected]];
        return arc;
    }

    path = [VPath path];
    list = [NSMutableArray array];

    r = (width + w) / 2.0;	/* the amount of growth */
    if (r < 0.0) r = 0.0;
    
//	[path setWidth:Abs(w)];
    [path setColor:color];
//	[path setFilled:YES];

    if ( Abs(angle) >= 360.0 )
    {
        arc = [VArc arc];
        p.x = center.x+radius+r;
        p.y = center.y;
        [arc setCenter:center start:p angle:360.0];
        [list addObject:arc];
        if ( radius > r )
        {   arc = [VArc arc];
            p.x = center.x+radius-r;
            p.y = center.y;
            [arc setCenter:center start:p angle:360.0];
            [list addObject:arc];
        }
    }
    else
    {
        ps[0].x = center.x+radius+r;
        ps[0].y = center.y;
        vhfRotatePointAroundCenter(&ps[0], center, begAngle);
        ps[3].x = center.x+radius+r;
        ps[3].y = center.y;
        vhfRotatePointAroundCenter(&ps[3], center, begAngle+angle);

        if ( radius > r )
        {   ps[1].x = center.x+radius-r;
            ps[1].y = center.y;
            vhfRotatePointAroundCenter(&ps[1], center, begAngle);
            ps[2].x = center.x+radius-r;
            ps[2].y = center.y;
            vhfRotatePointAroundCenter(&ps[2], center, begAngle+angle);
        }
        else
            ps[1] = ps[2] = center;

        p.x = (ps[0].x+ps[1].x)/2.0; p.y = (ps[0].y+ps[1].y)/2.0;
        arc = [VArc arc];
        [arc setCenter:p start:ps[1] angle:(angle>=0.0) ? 180.0 : -180.0];
        [list addObject:arc];

        arc = [VArc arc];
        [arc setCenter:center start:ps[0] angle:angle];
        [list addObject:arc];

        p.x = (ps[2].x+ps[3].x)/2.0; p.y = (ps[2].y+ps[3].y)/2.0;
        arc = [VArc arc];
        [arc setCenter:p start:ps[3] angle:(angle>=0.0) ? 180.0 : -180.0];
        [list addObject:arc];

        arc = [VArc arc];
        [arc setCenter:center start:ps[2] angle:-angle];
        [list addObject:arc];
    }

    for (i=[list count]-1; i>=0; i--)
    {	VGraphic    *g = [list objectAtIndex:i];

        [g setWidth:0.0];
        [g setColor:color];
    }

    [path addList:list at:[[path list] count]];
    [path setSelected:[self isSelected]];

    return path;
}

/* flatten arc
 * we use the flatness to get the roughtness of the arc
 */
- flattenedObjectWithFlatness:(float)flatness
{   VPath		*pathG;
    VLine		*line;
    NSMutableArray	*plist;
    double		dx, chordAngle;
    int			i, n;
    NSPoint		last, p;

    /* calc chord angle */
    if ((dx = radius - (flatness/2.0)) <= 0.0)
        n = 1;
    else
    {	chordAngle = RadToDeg(acos(dx/radius))*2.0;
        if ( chordAngle < 0.5 )
            chordAngle = 0.5;
        n = (int)ceil(Abs(angle) / chordAngle);	/* number of lines */
    }
    chordAngle = angle / n;	/* chord angle to get lines of equal length */

    pathG = [VPath path];
    plist = [NSMutableArray array];
    last = start;
    for ( i=1; i<=n; i++ )
    {	double	a = DegToRad( begAngle+(double)i*chordAngle );

        p.x = center.x + radius * cos(a);
        p.y = center.y + radius * sin(a);
        line = [VLine line];
        [line setVertices:last :p];
        [plist addObject:line];
        last = p;
    }

    [pathG addList:plist at:[[pathG list] count]];

    return pathG;
}

/* modified: 2010-06-11 (r2, SqrDistPoints() casted to double)
 *           2001-02-24 2008-10-16
 * return a list of objects which are the result of intersecting us
 * the objects are sorted beginning at start 
 */
- (NSMutableArray*)getListOfObjectsSplittedFrom:(NSPoint*)pArray :(int)iCnt
{   NSMutableArray      *splitList = nil;
    int                 i, cnt = 0, aCnt;
    NSPoint             *ps = malloc((iCnt) * sizeof(NSPoint));
    NSRect              bounds;
    float               *angles, ba, ea, a;
    double              r2;
    BOOL                pointsOK = NO;
    NSAutoreleasePool   *pool;

    /* filter points */
    bounds = [self bounds];
    bounds.origin.x -= 5.0*TOLERANCE;
    bounds.origin.y -= 5.0*TOLERANCE;
    bounds.size.width  += 10.0*TOLERANCE;
    bounds.size.height += 10.0*TOLERANCE;
    for (i=0, cnt=0; i<iCnt; i++)
        if ( NSPointInRect(pArray[i], bounds) && !pointInArray(pArray[i], ps, cnt) )
            ps[cnt++] = pArray[i];

    if (!cnt)
    {	free(ps);
        return nil;
    }
    if (Abs(angle) != 360.0)
    {   if ( (iCnt = removePointWithToleranceFromArray(start, Max(5.0*TOLERANCE, radius/10000.0), ps, cnt)) != cnt ) // Max(5.0*TOLERANCE, radius/1000.0)
            pointsOK = YES;
        if ( (cnt = removePointWithToleranceFromArray(end, Max(5.0*TOLERANCE, radius/10000.0), ps, iCnt)) != iCnt )
            pointsOK = YES;
    }
    // check distance point - center -> must be radius !
    r2 = (double)radius*(double)radius;
    for (i=0; i<cnt; i++)
        if ( Diff (SqrDistPoints(ps[i], center), r2) > Max(3.5*TOLERANCE, radius/3000.0) ) // 3000.0 + double SqrDistPoints
        {   cnt = removePointFromArray(ps[i], ps, cnt);
            i--;
        }

    if (!cnt)
    {	free(ps);
        return nil;
    }
    /* if angle < 0 change sequenze of ps */
    if ( angle < 0 )
    {   NSPoint	bufPs[cnt];

        for (i=0; i<cnt; i++)
            bufPs[i] = ps[cnt-1-i];
        for (i=0; i<cnt; i++)
            ps[i] = bufPs[i];
    }

    /* filter angles */
    angles = malloc((cnt) * sizeof(float));
    /* we need positive angles with ba < ea */
    ba = ((angle>=0.0) ? (begAngle) : (begAngle+angle)) - 4.5*TOLERANCE;
    if (ba < 0.0) ba += 360.0;
    if (ba >= 360.0) ba -= 360.0;
    ea = ba + Abs(angle) + 9.0*TOLERANCE;
    for (i=0, aCnt=0; i<cnt; i++)
    {	float	a1 = a = vhfAngleOfPointRelativeCenter(ps[i], center);

        if (a1 < ba) a1 += 360.0;
        if ( a1>=ba && a1<=ea )
        {   angles[aCnt++] = a;
            pointsOK = YES;
        }
        else
        {   cnt = removePointFromArray(ps[i], ps, cnt);
            i--;
        }
    }

    if (!pointsOK)
    {	free(ps);
        free(angles);
        return nil;
    }

    /* sort angles, start at begAngle
     * angles must be positive and between 0 and 360 degree
     */
    for (i=0; i<aCnt-1; i++)
    {	int		j, jMin;
        float	lastDist, newDist;
        float	v;
        NSPoint	p;

        jMin = cnt;
        if ( angle < 0 )
            lastDist = Diff( angles[i]-((angles[i]>begAngle) ? 360.0 : 0.0), begAngle);
        else
            lastDist = Diff( angles[i]+((angles[i]<begAngle) ? 360.0 : 0.0), begAngle);
        for (j=i+1; j<aCnt; j++)
        {
            if ( angle < 0 )
                newDist = Diff( angles[j]-((angles[j]>begAngle) ? 360.0 : 0.0), begAngle);
            else
                newDist = Diff( angles[j]+((angles[j]<begAngle) ? 360.0 : 0.0), begAngle);
            if ( newDist < lastDist )
            {	lastDist = newDist;
                jMin = j;
            }
        }
        if (jMin<cnt)
        {   v = angles[i];
            angles[i] = angles[jMin];
            angles[jMin] = v;
            p = ps[i];
            ps[i] = ps[jMin];
            ps[jMin] = p;
        }
    }

    /* we have an intersection
     */
    if (angle == 360.0 && aCnt < 2)
    {	free(ps);
        free(angles);
        return nil;
    }
    splitList = [NSMutableArray array];
    pool = [NSAutoreleasePool new];
    for ( i=0; i<=aCnt; i++ )
    {	VArc	*arc = [VArc arc];
        NSPoint	pv0, pv1;
        float	na;

        if (!i && angle == 360.0)
            continue; // we start at first intersection pt
        pv0 = (!i) ? start : ps[i-1];
        ba = (!i) ? begAngle : angles[i-1];
        pv1 = (i>=aCnt) ? ((angle==360.0) ? ps[0] : end) : ps[i];
        ea = (i>=aCnt) ? ((angle==360.0) ? angles[0] : begAngle+angle) : angles[i];
        if ( angle<0.0 )
        {	float v=ba; ba=ea; ea =v; }
        if ( ea < ba) ea += 360.0;

        //	if (angle<0.0  && ba<ea) ba += 360.0;
        //	if (angle>=0.0 && ea<ba) ea += 360.0;
        if ( Diff(ba, ea) > Abs(angle)+0.1 )
            ea -= 360.0;
        na = (angle < 0.0) ? -Diff(ea,ba) : Diff(ea,ba);
        if ( ((2.0*Pi*radius)/360.0)*Abs(na) > TOLERANCE)
        {   [arc setCenter:center start:pv0 angle:na];
            [splitList addObject:arc];
        }
    }

    free(ps);
    free(angles);
    [pool release];

    return splitList;
}

- (NSMutableArray*)getListOfObjectsSplittedAtPoint:(NSPoint)pt;
{   NSMutableArray	*splitList = nil;
    int			i;
    float		ptangle, ba, ea, a, a1;
    NSAutoreleasePool	*pool;

    /* we need positive angles with ba < ea */
    ba = ((angle>=0.0) ? begAngle : (begAngle+angle)) - 0.1;
    if (ba < 0.0) ba += 360.0;
    if (ba >= 360.0) ba -= 360.0;
    ea = ba + Abs(angle) + 0.2;

    a1 = a = vhfAngleOfPointRelativeCenter(pt, center);
    if (a1 < ba) a1 += 360.0;
    if ( a1>=ba && a1<=ea )
         ptangle = a;
    else
        return nil;

    /* angles must be positive and between 0 and 360 degree
     */
    if ( angle < 0 )
        ptangle -= ((ptangle>begAngle) ? 360.0 : 0.0);
    else
        ptangle += ((ptangle<begAngle) ? 360.0 : 0.0);    

    if (Diff(begAngle, ptangle) < 0.1)
        return nil;
    if (Diff((begAngle+angle), ptangle) < 0.1)
        return nil;

    pt = vhfPointAngleFromRefPoint(center, start, (angle<0.0) ? -Diff(ptangle,begAngle) : Diff(ptangle,begAngle));
    splitList = [NSMutableArray array];
    pool = [NSAutoreleasePool new];
    for ( i=0; i<=1; i++ )
    {	VArc	*arc = [VArc arc];
        NSPoint	pv0, pv1;
        float	na;

        pv0 = (!i) ? start : pt;
        ba = (!i) ? begAngle : ptangle;
        pv1 = (i>=1) ? end : pt;
        ea = (i>=1) ? begAngle+angle : ptangle;
        if ( angle<0.0 )
        {	float v=ba; ba=ea; ea =v; }
        if ( ea < ba) ea += 360.0;

        if ( Diff(ba, ea) > Abs(angle)+0.1 )
            ea -= 360.0;
        na = (angle < 0.0) ? -Diff(ea,ba) : Diff(ea,ba);
        if ( ((2.0*Pi*radius)/360.0)*Abs(na) > TOLERANCE)
        {   [arc setCenter:center start:pv0 angle:(angle<0.0)?-Diff(ea,ba):Diff(ea,ba)];
            [arc setWidth:width];
            [arc setColor:color];
            [splitList addObject:arc];
        }
    }
    [pool release];
    return splitList;
}

/* 0 - other intersection than tangential intersection
 * 1 - tangential intersection
 * 2 - no intersection
 */
- (int)tangentIntersectionWith:g :(int*)iCnt :(NSPoint**)iPts
{
    if ([g isKindOfClass:[VLine class]])
    {	NSPoint	pv0, pv1, iPoint;
        int	rVal, cnt = 0;

        [g getVertices:&pv0 :&pv1];
        rVal = [self tangentIntersectionLine:pv0 :pv1 :1 :&cnt :&iPoint];
        if (cnt && rVal) // only one is possible
        {   *iPts = malloc((1) * sizeof(NSPoint));
            (*iPts)[0] = iPoint;
            *iCnt = 1;
        }
        return rVal;
    }
    else if ([g isKindOfClass:[VPolyLine class]])
    {   int	i, cnt = [(VPolyLine*)g ptsCount];

        *iPts = malloc(cnt * sizeof(NSPoint));

        for (i=0; i<cnt-1; i++)
        {   NSPoint	pv0 = [(VPolyLine*)g pointWithNum:i], pv1 = [(VPolyLine*)g pointWithNum:i+1], iPoint;
            int		icnt = 0;

            if ( ![self tangentIntersectionLine:pv0 :pv1 :1 :&icnt :&iPoint] )
            {
                if (*iCnt)
                {   free(*iPts);
                    *iPts = 0;
                    *iCnt = 0;
                }
                return NO; // other than tangential intersection with g
            }
            if (icnt) // only one is by a line possible
                (*iPts)[(*iCnt)++] = iPoint;
        }
        return YES;
    }
    else if ([g isKindOfClass:[VCurve class]])
    {	NSPoint	ps[4], pts[2]; // ????
        int	i, cnt = 0, rVal;
/*        int	tangent;

        // [self setRadius:radius - TOLERANCE*3.0]; // 3.0
        radius -= TOLERANCE*3.0;
        start.x = end.x = center.x + radius;
        start.y = end.y = center.y;
        [g getVertices:&ps[0] :&ps[1] :&ps[2] :&ps[3]];
        tangent = [self tangentIntersectionCurve:ps];
        //[self setRadius:radius + TOLERANCE*3.0]; // 3.0
        radius += TOLERANCE*3.0;
        start.x = end.x = center.x + radius;
        start.y = end.y = center.y;
        return tangent;
*/
        [g getVertices:&ps[0] :&ps[1] :&ps[2] :&ps[3]];
        rVal =  [self tangentIntersectionCurve:ps :&cnt :pts];
        if (cnt && rVal)
        {   *iPts = malloc(cnt * sizeof(NSPoint));
            for (i=0; i<cnt; i++)
                (*iPts)[(*iCnt)++] = pts[i];
        }
        return rVal;
    }
    else if ([g isKindOfClass:[VArc class]])
    {	NSRect	bounds;
        NSPoint	c, s, iPoint;
        float	a;
        int	rVal, cnt = 0;

        bounds = [g coordBounds];
        [g getCenter:&c start:&s angle:&a];
        rVal = [self tangentIntersectionArc:c :s :a :[g radius] :&bounds :&cnt :&iPoint];
        if (cnt && rVal) // only one is possible
        {   *iPts = malloc((1) * sizeof(NSPoint));
            (*iPts)[0] = iPoint;
            *iCnt = 1;
        }
        return rVal;
    }
    else
    {	NSLog(@"VArc, tangentIntersectionWith with unknown class!");
        return 0;
    }
}

/* return YES if arc intersect g only in tangent points
 */
- (BOOL)tangentIntersectionWithPath:path
{   int		i; // iCnt = 0;
    NSRect	arcBounds = [self bounds];
    NSPoint	*pts; // allPts[([[path list] count] < 30) ? (30) : ([[path list] count])];

    for (i=[[path list] count]-1; i>=0; i--)
    {	id	gp = [[path list] objectAtIndex:i];
        int	cnt = 0; // j, pAmount=0;
        NSRect	gpBounds = [gp bounds];

        if ( !vhfIntersectsRect(arcBounds, gpBounds) )
            continue;

        /* 0 - other intersection than tangential intersection
         * 1 - tangential intersection
         * 2 - no intersection
         */
        if ( ![self tangentIntersectionWith:gp :&cnt :&pts] ) // line, arc, curve
        {   if (cnt)
                free(pts);
            return NO; // other than tangential intersection with gp
        }
/*
        // collect iPts - check iPts
        for (j=0; j<cnt; j++)
        {   if ( !(pAmount=cntPointsWithToleranceInArray(pts[j], 50.0*TOLERANCE, allPts, iCnt)) )
                allPts[iCnt++] = pts[j];
            else if (pAmount == 1) // point is one time in array
            {   NSPoint	s, e;

                // check if s/e of current graphic -> add
                s = [gp pointWithNum:0];
                e = [gp pointWithNum:MAXINT];
                if ((Diff(s.x, pts[j].x) < 50.0*TOLERANCE && Diff(s.y, pts[j].y) < 50.0*TOLERANCE) ||
                    (Diff(e.x, pts[j].x) < 50.0*TOLERANCE && Diff(e.y, pts[j].y) < 50.0*TOLERANCE))
                    allPts[iCnt++] = pts[j];
                // if not -> return NO
                else
                {   free(pts);
                    return NO; // more than one intersection in the same point (only for s/e points possible)
                }
            }
            else
            {   free(pts);
                return NO; // its the third point
            }
        }
*/
        if (cnt) free(pts);
    }
    return YES; // no intersection is also ok
}

/* return all the intersection points with g
 * start and end points of the arc are included
 * the intersection points are sorted from the start of the arc
 */
- (int)getIntersections:(NSPoint**)ppArray with:g
{   int		iCnt;

    if ([g isKindOfClass:[VPath class]] || [g isKindOfClass:[VGroup class]] ||
        [g isKindOfClass:[VPolyLine class]])
        iCnt = [g getIntersections:ppArray with:self];
    else if ([g isKindOfClass:[VLine class]])
    {	NSPoint	pv0, pv1;

        *ppArray = malloc((2) * sizeof(NSPoint));
        [g getVertices:&pv0 :&pv1];
        iCnt = [self intersectLine:*ppArray :pv0 :pv1];
    }
    else if ([g isKindOfClass:[VCurve class]])
    {	NSPoint	ps[4];

        *ppArray = malloc(10 * sizeof(NSPoint));
        [g getVertices:&ps[0] :&ps[1] :&ps[2] :&ps[3]];
        iCnt = [self intersectCurve:*ppArray :ps];
    }
    else if ([g isKindOfClass:[VArc class]])
    {	NSRect	bounds;

        *ppArray = malloc(10 * sizeof(NSPoint));
        bounds = [self bounds];
        iCnt = [g intersectArc:*ppArray :center :start :angle :&bounds];
    }
    else if ([g isKindOfClass:[VRectangle class]])
        iCnt = [g getIntersections:ppArray with:self];
    else
    {	NSLog(@"VArc, intersection with unknown class!");
        *ppArray = NULL;
        return 0;
    }

    if (iCnt)
        sortPointArray(*ppArray, iCnt, start);
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
    else if ([g isKindOfClass:[VCurve class]])
    {	NSPoint	pc[4];

        [g getVertices:&pc[0] :&pc[1] :&pc[2] :&pc[3]];
        return [self sqrDistanceCurve:pc :pg1 :pg2];
    }
    else if ([g isKindOfClass:[VArc class]])
        return [g sqrDistanceArc:center :start :angle :pg2 :pg1];
    else if ([g isKindOfClass:[VRectangle class]])
        return [g sqrDistanceGraphic:self :pg2 :pg1];
    else
    {   NSLog(@"VArc, distance (with two nearest points) with unknown class!");
        return -1.0;
    }
    return -1.0;
}

- (float)sqrDistanceGraphic:g
{
    if ([g isKindOfClass:[VPath class]] || [g isKindOfClass:[VGroup class]] ||
        [g isKindOfClass:[VPolyLine class]] || [g isKindOfClass:[VRectangle class]])
        return [g sqrDistanceGraphic:self];
    else if ([g isKindOfClass:[VLine class]])
    {	NSPoint	pv0, pv1;

        [g getVertices:&pv0 :&pv1];
        return [self sqrDistanceLine:pv0 :pv1];
    }
    else if ([g isKindOfClass:[VArc class]])
        return [g sqrDistanceArc:center :start :angle];
    else if ([g isKindOfClass:[VCurve class]])
    {	NSPoint	ps[4];

        [g getVertices:&ps[0] :&ps[1] :&ps[2] :&ps[3]];
        return [self sqrDistanceCurve:ps];
    }
    else
    {   NSLog(@"VArc, distance with unknown class!");
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
{   NSMutableArray	*clipList = [NSMutableArray array];
    NSArray		*cList;
    NSPoint		iPoints[16], p, rp[4];
    int			iCnt = 0, i, j;
    VGroup		*group = [VGroup group];

    if (NSContainsRect(rect, [self bounds]))	// object entirely inside rect
        return self;
    if (!NSIntersectsRect(rect, [self bounds]))	// object entirely outside rect
        return nil;

    rp[0] = rect.origin;
    rp[1].x = rect.origin.x + rect.size.width; rp[1].y = rect.origin.y;
    rp[2].x = rect.origin.x + rect.size.width; rp[2].y = rect.origin.y + rect.size.height;
    rp[3].x = rect.origin.x; rp[3].y = rect.origin.y + rect.size.height;

    for (i=0; i<4; i++)
        iCnt += [self intersectLine:iPoints+iCnt :rp[i] :((i+1<4) ? rp[i+1] : rp[0])];

    if (!iCnt || !(cList = [self getListOfObjectsSplittedFrom:iPoints :iCnt]))
        return nil;
    else
        for (j=0; j<(int)[cList count]; j++)
            [clipList addObject:[cList objectAtIndex:j]];

    for (i=0; i<(int)[clipList count];i++)
    {	[[clipList objectAtIndex:i] getPoint:&p at:0.5];
        if ( !NSPointInRect(p , rect) )
        {   [clipList removeObjectAtIndex:i];
            i--;
        }
    }

    [group setList:clipList];
    return group;
}

- (void)getPointBeside:(NSPoint*)point :(int)left :(float)dist
{   NSPoint	arcP, grad;
    float	c;

    [self getPoint:&arcP at:0.5];
    grad = [self gradientAt:0.5];

    c = sqrt(grad.x*grad.x+grad.y*grad.y);
    if ( left )
    {	point->x = arcP.x - grad.y*dist/c;
        point->y = arcP.y + grad.x*dist/c;
    }
    else
    {	point->x = arcP.x + grad.y*dist/c;
        point->y = arcP.y - grad.x*dist/c;
    }
}
/* modified:    2008-10-16 */
- (NSMutableArray*)getListOfObjectsSplittedFromGraphic:g
{   NSMutableArray	*splitList = nil;
    int			i, cnt = 0, aCnt, iCnt;
    NSPoint		*ps, *iPts;
    float		*angles, ba, ea, a;
    BOOL		pointsOK = NO;
    NSAutoreleasePool	*pool;


    if ( !(iCnt = [self getIntersections:&iPts with:g]) )
        return nil;

    ps = malloc((iCnt) * sizeof(NSPoint));
    for (i=0, cnt=0; i<iCnt; i++)
        if (!pointInArray(iPts[i], ps, cnt)) // tangential intersection -> 2 identical pts
            ps[cnt++] = iPts[i];

    /* filter start end points */
    if (Abs(angle) != 360.0)
    {   iCnt = cnt;
        if ( (iCnt = removePointWithToleranceFromArray(start, Max(5.0*TOLERANCE, radius/10000.0), ps, cnt)) != cnt ) // Max(5.0*TOLERANCE, radius/1000.0)
            pointsOK = YES;
        if ( (cnt = removePointWithToleranceFromArray(end, Max(5.0*TOLERANCE, radius/10000.0), ps, iCnt)) != iCnt )
            pointsOK = YES;
    }
    /* if angle < 0 change sequenze of ps */
    if ( angle < 0 )
    {   NSPoint	bufPs[cnt];

        for (i=0; i<cnt; i++)
            bufPs[i] = ps[cnt-1-i];
        for (i=0; i<cnt; i++)
            ps[i] = bufPs[i];
    }

    /* filter angles */
    angles = malloc((cnt) * sizeof(float));
    /* we need positive angles with ba < ea */
    ba = ((angle>=0.0) ? begAngle : (begAngle+angle)) - 0.1;
    if (ba < 0.0) ba += 360.0;
    if (ba >= 360.0) ba -= 360.0;
    ea = ba + Abs(angle) + 0.2;
    for (i=0, aCnt=0; i<cnt; i++)
    {	float	a1 = a = vhfAngleOfPointRelativeCenter(ps[i], center);

        if (a1 < ba) a1 += 360.0;
        if ( a1>=ba && a1<=ea )
        {   angles[aCnt++] = a;
            pointsOK = YES;
        }
        else
        {   cnt = removePointFromArray(ps[i], ps, cnt);
            i--;
        }
    }

    if (!pointsOK)
    {	free(ps);
     	free(iPts);
        free(angles);
        return nil;
    }

    /* sort angles, start at begAngle
     * angles must be positive and between 0 and 360 degree
     */
    for (i=0; i<aCnt-1; i++)
    {	int		j, jMin;
        float	lastDist, newDist;
        float	v;
        NSPoint	p;

        jMin = cnt;
        if ( angle < 0 )
            lastDist = Diff( angles[i]-((angles[i]>begAngle) ? 360.0 : 0.0), begAngle);
        else
            lastDist = Diff( angles[i]+((angles[i]<begAngle) ? 360.0 : 0.0), begAngle);
        for (j=i+1; j<aCnt; j++)
        {
            if ( angle < 0 )
                newDist = Diff( angles[j]-((angles[j]>begAngle) ? 360.0 : 0.0), begAngle);
            else
                newDist = Diff( angles[j]+((angles[j]<begAngle) ? 360.0 : 0.0), begAngle);
            if ( newDist < lastDist )
            {	lastDist = newDist;
                jMin = j;
            }
        }
        if (jMin<cnt)
        {   v = angles[i];
            angles[i] = angles[jMin];
            angles[jMin] = v;
            p = ps[i];
            ps[i] = ps[jMin];
            ps[jMin] = p;
        }
    }

    /* we have an intersection
     */
    if (angle == 360.0 && aCnt < 2)
    {	free(ps);
        free(angles);
     	free(iPts);
        return nil;
    }
    splitList = [NSMutableArray array];
    pool = [NSAutoreleasePool new];
    for ( i=0; i<=aCnt; i++ )
    {	VArc	*arc = [VArc arc];
        NSPoint	pv0, pv1;
        float	na;

        if (!i && angle == 360.0)
            continue; // we start at first intersection pt
        pv0 = (!i) ? start : ps[i-1];
        ba = (!i) ? begAngle : angles[i-1];
        pv1 = (i>=aCnt) ? ((angle==360.0) ? ps[0] : end) : ps[i];
        ea = (i>=aCnt) ? ((angle==360.0) ? angles[0] : begAngle+angle) : angles[i];
        if ( angle<0.0 )
        {	float v=ba; ba=ea; ea =v; }
        if ( ea < ba) ea += 360.0;

        //	if (angle<0.0  && ba<ea) ba += 360.0;
        //	if (angle>=0.0 && ea<ba) ea += 360.0;
        if ( Diff(ba, ea) > Abs(angle)+0.1 )
            ea -= 360.0;
        na = (angle < 0.0) ? -Diff(ea,ba) : Diff(ea,ba);
        if ( ((2.0*Pi*radius)/360.0)*Abs(na) > TOLERANCE)
        {   [arc setCenter:center start:pv0 angle:(angle<0.0)?-Diff(ea,ba):Diff(ea,ba)];
            [splitList addObject:arc];
        }
    }

    free(ps);
    free(iPts);
    free(angles);
    [pool release];

    return splitList;
}

/* modified: 2001-02-24
 * return a list of objects which are the result of intersecting us
 * the objects are sorted beginning at start 
 */
- getIntersectionsAndSplittedObjects:(NSPoint**)ppArray :(int*)iCnt with:g
{   NSMutableArray	*splitList = nil;
    int			i, cnt = 0, aCnt, tCnt;
    NSPoint		*ps;
    float		*angles, ba, ea, a;
    BOOL		pointsOK = NO;
    NSAutoreleasePool	*pool;


    if ( !((*iCnt) = [self getIntersections:ppArray with:g]) )
        return nil;

    ps = malloc((*iCnt) * sizeof(NSPoint));
    for (i=0, cnt=0; i<*iCnt; i++)
        ps[cnt++] = (*ppArray)[i];

    /* filter start end points */
    tCnt = cnt;
    if ( (tCnt = removePointWithToleranceFromArray(start, TOLERANCE*10.0, ps, cnt)) != cnt )
        pointsOK = YES;
    if ( (cnt = removePointWithToleranceFromArray(end, TOLERANCE*10.0, ps, tCnt)) != tCnt )
        pointsOK = YES;

    /* if angle < 0 change sequenze of ps */
    if ( angle < 0 )
    {   NSPoint	bufPs[cnt];

        for (i=0; i<cnt; i++)
            bufPs[i] = ps[cnt-1-i];
        for (i=0; i<cnt; i++)
            ps[i] = bufPs[i];
    }

    /* filter angles */
    angles = malloc((cnt) * sizeof(float));
    /* we need positive angles with ba < ea */
    ba = ((angle>=0.0) ? begAngle : (begAngle+angle)) - 0.1;
    if (ba < 0.0) ba += 360.0;
    if (ba >= 360.0) ba -= 360.0;
    ea = ba + Abs(angle) + 0.2;
    for (i=0, aCnt=0; i<cnt; i++)
    {	float	a1 = a = vhfAngleOfPointRelativeCenter(ps[i], center);

        if (a1 < ba) a1 += 360.0;
        if ( a1>=ba && a1<=ea )
        {   angles[aCnt++] = a;
            pointsOK = YES;
        }
        else
        {   cnt = removePointFromArray(ps[i], ps, cnt);
            i--;
        }
    }

    if (!pointsOK)
    {	free(ps);
        free(angles);
        return nil;
    }

    /* sort angles, start at begAngle
     * angles must be positive and between 0 and 360 degree
     */
    for (i=0; i<aCnt-1; i++)
    {	int		j, jMin;
        float	lastDist, newDist;
        float	v;
        NSPoint	p;

        jMin = cnt;
        if ( angle < 0 )
            lastDist = Diff( angles[i]-((angles[i]>begAngle) ? 360.0 : 0.0), begAngle);
        else
            lastDist = Diff( angles[i]+((angles[i]<begAngle) ? 360.0 : 0.0), begAngle);
        for (j=i+1; j<aCnt; j++)
        {
            if ( angle < 0 )
                newDist = Diff( angles[j]-((angles[j]>begAngle) ? 360.0 : 0.0), begAngle);
            else
                newDist = Diff( angles[j]+((angles[j]<begAngle) ? 360.0 : 0.0), begAngle);
            if ( newDist < lastDist )
            {	lastDist = newDist;
                jMin = j;
            }
        }
        if (jMin<cnt)
        {   v = angles[i];
            angles[i] = angles[jMin];
            angles[jMin] = v;
            p = ps[i];
            ps[i] = ps[jMin];
            ps[jMin] = p;
        }
    }

    /* we have an intersection
     */
    if (angle == 360.0 && aCnt < 2)
    {	free(ps);
        free(angles);
        return nil;
    }
    splitList = [NSMutableArray array];
    pool = [NSAutoreleasePool new];
    for ( i=0; i<=aCnt; i++ )
    {	VArc	*arc = [VArc arc];
        NSPoint	pv0, pv1;

        if (!i && angle == 360.0)
            continue; // we start at first intersection pt
        pv0 = (!i) ? start : ps[i-1];
        ba = (!i) ? begAngle : angles[i-1];
        pv1 = (i>=aCnt) ? ((angle==360.0) ? ps[0] : end) : ps[i];
        ea = (i>=aCnt) ? ((angle==360.0) ? angles[0] : begAngle+angle) : angles[i];
        if ( angle<0.0 )
        {	float v=ba; ba=ea; ea =v; }
        if ( ea < ba) ea += 360.0;

        //	if (angle<0.0  && ba<ea) ba += 360.0;
        //	if (angle>=0.0 && ea<ba) ea += 360.0;
        if ( Diff(ba, ea) > Abs(angle)+0.1 )
            ea -= 360.0;
        [arc setCenter:center start:pv0 angle:(angle<0.0)?-Diff(ea,ba):Diff(ea,ba)];
        [splitList addObject:arc];
    }

    free(ps);
    free(angles);
    [pool release];

    return splitList;
}

/* NO if not united
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
        NSPoint	sPts[2], ePts[2] = {{0.0, 0.0}, {0.0, 0.0}};

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

/* return self - if self is completely inside cg
 * return ug   - if cg is completely inside self
 * return the intersection path of both
 */
- (id)clippedFrom:(VGraphic*)cg
{   int			i, j, cnt, nothingRemoved = 0;
    VPath		*ng;
    NSMutableArray	*splitListG, *splitListUg;
    NSAutoreleasePool	*pool;

    if ( ![cg isKindOfClass:[VPath class]] && ![cg isKindOfClass:[VArc class]]
         && ![cg isKindOfClass:[VPolyLine class]]
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

    if ( ![[ng list] count] )
        [[ng list] addObject:[[self copy] autorelease]];

    pool = [NSAutoreleasePool new];

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
        {   [pool release];
            return [[cg copy] autorelease];
        }
        /* self is inside cg -> self is it */
        [self getPoint:&p at:0.4];
        if ( [(id)cg isPointInside:p] )
        {   [pool release];
            return [[self copy] autorelease];
        }
        return NO;	// nothing to clip
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

        // we check only added objects !!!!!!!!!!
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

- (BOOL)identicalWith:(VGraphic*)g
{   NSPoint	s, e, c;
    float	a, ArcAngleTolerance;

    if ( ![g isKindOfClass:[VArc class]] )
        return NO;

    [(VArc*)g getCenter:&c start:&s angle:&a];	[g getPoint:3 :&e];

    // 10*TOLERANCE / 2*Pi*r = a? / 360.0 -> (360.0*10*TOLERANCE)/2*Pi*r
    ArcAngleTolerance = (360.0*10*TOLERANCE)/2*Pi*radius; // instead 15.0*TOLERANCE

    if ( ((Diff(start.x, s.x) <= 10.0*TOLERANCE && Diff(start.y, s.y) <= 10.0*TOLERANCE
          && Diff(end.x, e.x) <= 10.0*TOLERANCE && Diff(end.y, e.y) <= 10.0*TOLERANCE)
         || (Diff(start.x, e.x) <= 10.0*TOLERANCE && Diff(start.y, e.y) <= 10.0*TOLERANCE
             && Diff(end.x, s.x) <= 10.0*TOLERANCE && Diff(end.y, s.y) <= 10.0*TOLERANCE)) &&
        Diff(center.x, c.x) <= 2.0*TOLERANCE && Diff(center.y, c.y) <= 2.0*TOLERANCE &&
        Diff(Abs(angle), Abs(a)) <= ArcAngleTolerance && Diff(radius, [(VArc*)g radius]) <= 2.0*TOLERANCE )
    /*if ( Diff(start.x, s.x) <= TOLERANCE && Diff(start.y, s.y) <= TOLERANCE &&
        Diff(end.x, e.x) <= TOLERANCE && Diff(end.y, e.y) <= TOLERANCE &&
        Diff(center.x, c.x) <= TOLERANCE && Diff(center.y, c.y) <= TOLERANCE &&
        Diff(angle, a) <= TOLERANCE && Diff(radius, [(VArc*)g radius]) <= TOLERANCE )*/
        return YES;
    return NO;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [super encodeWithCoder:aCoder];
    //[aCoder encodeValuesOfObjCTypes:"{NSPoint=ff}", &center];
    //[aCoder encodeValuesOfObjCTypes:"{NSPoint=ff}f", &start, &angle];
    [aCoder encodePoint:center];            // 2012-01-08
    [aCoder encodePoint:start];
    [aCoder encodeValuesOfObjCTypes:"f", &angle];
    // 2002-07-07
    [aCoder encodeValuesOfObjCTypes:"i", &filled];
    [aCoder encodeObject:fillColor];
    [aCoder encodeObject:endColor];
    [aCoder encodeValuesOfObjCTypes:"ff", &graduateAngle, &stepWidth];
    //[aCoder encodeValuesOfObjCTypes:"{NSPoint=ff}", &radialCenter];
    [aCoder encodePoint:radialCenter];
}
- (id)initWithCoder:(NSCoder *)aDecoder
{   int	version;

    [super initWithCoder:aDecoder];
    version = [aDecoder versionForClassName:@"VArc"];
    if ( version < 2 )
    {	[aDecoder decodeValuesOfObjCTypes:"{ff}", &center];
        [aDecoder decodeValuesOfObjCTypes:"{ff}{ff}", &start, &angle];
    }
    else
    {	//[aDecoder decodeValuesOfObjCTypes:"{NSPoint=ff}", &center];
        center = [aDecoder decodePoint];    // 2012-01-08
        if ( version < 3 )
            [aDecoder decodeValuesOfObjCTypes:"{NSPoint=ff}{NSPoint=ff}", &start, &angle];
        else
        {   //[aDecoder decodeValuesOfObjCTypes:"{NSPoint=ff}f", &start, &angle];
            start = [aDecoder decodePoint]; // 2012-01-08
            [aDecoder decodeValuesOfObjCTypes:"f", &angle];
        }
    }
    if ( version < 4 )
    {   UPath	fillUPath;

        [aDecoder decodeValuesOfObjCTypes:"c", &filled];

        [aDecoder decodeValuesOfObjCTypes:"ii", &fillUPath.num_ops, &fillUPath.num_pts];
        if ( fillUPath.num_ops )	// only used for output
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
    {   [aDecoder decodeValuesOfObjCTypes:"i", &filled];
        fillColor = [[aDecoder decodeObject] retain];
        endColor  = [[aDecoder decodeObject] retain];
        [aDecoder decodeValuesOfObjCTypes:"ff", &graduateAngle , &stepWidth];
        //[aDecoder decodeValuesOfObjCTypes:"{NSPoint=ff}", &radialCenter];
        radialCenter = [aDecoder decodePoint];  // 2012-01-08
    }
    [self calcAddedValues];
    [self setParameter];
    graduateDirty = YES;
    graduateList = nil;

    return self;
}

/* archiving with property list
 */
- (id)propertyList
{   NSMutableDictionary	*plist = [super propertyList];

    [plist setObject:propertyListFromNSPoint(center)            forKey:@"center"];
    [plist setObject:propertyListFromNSPoint(start)             forKey:@"start"];
    if (angle != 360.0)
        [plist setObject:propertyListFromFloat(angle)           forKey:@"angle"];
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
    center = pointFromPropertyList([plist objectForKey:@"center"]);
    start = pointFromPropertyList([plist objectForKey:@"start"]);
    if ( !(angle = [plist floatForKey:@"angle"]))
        angle = 360.0;	// default;
    filled = [plist intForKey:@"filled"];
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
    [self calcAddedValues];
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
