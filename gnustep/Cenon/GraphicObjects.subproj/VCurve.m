/* VCurve.m
 * 2-D Bezier curve
 *
 * Copyright (C) 1996-2012 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1996-01-29
 * modified: 2012-04-23 (-sqrDistanceLine:, -sqrDistanceLine::::, -length - corrected)
 *           2011-07-11 (-sqrDistance...; corrected)
 *           2011-03-11 (-contour: build outline of stroke width + 0 distance)
 *           2010-02-18 (exit editing with right mouse click)
 *           2008-08-06 (-getListOfObjectsSplittedFrom::)
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
#include "VCurve.h"
#include "VPath.h"
#include "VLine.h"
#include "VArc.h"
#include "../App.h"
#include "../DocView.h"
#include "../DocWindow.h"
#include "../Inspectors.h"

/* created:   08.07.93
 * modified:  19.03.96
 * purpose:   get bounds of curve
 *					we build the bounds from the points of the curve!
 * parameter: curve, bounds
 * return:    none
 */
NSRect fastBoundsOfCurve(const NSPoint ps[4])
{   NSRect	bounds;

    bounds.origin.x = Min(ps[0].x, Min(ps[1].x, Min(ps[2].x, ps[3].x)));
    bounds.origin.y = Min(ps[0].y, Min(ps[1].y, Min(ps[2].y, ps[3].y)));
    bounds.size.width  = Max(ps[0].x, Max(ps[1].x, Max(ps[2].x, ps[3].x))) - bounds.origin.x;
    bounds.size.height = Max(ps[0].y, Max(ps[1].y, Max(ps[2].y, ps[3].y))) - bounds.origin.y;
    return bounds;
}

/* created:   1993-07-08
 * modified:  1996-03-19
 * parameter: curve
 *            t (the t value where we split the curve)
 *            curves	(the curve segments)
 * purpose:   split 'curve' at 't'
 * return:    number of curve segments in 'curves'
 */
int tileCurveAt(const NSPoint pc[4], float t, NSPoint *pc1, NSPoint *pc2)
{   NSPoint	p;

    /* p0 of 1st curve */
    pc1[0] = pc[0];

    /* p1 of 1st curve */
    pc1[1].x = pc[0].x + (pc[1].x - pc[0].x) * t;
    pc1[1].y = pc[0].y + (pc[1].y - pc[0].y) * t;

    /* p2 of 1st curve */
    p.x = pc[1].x + (pc[2].x - pc[1].x) * t;
    p.y = pc[1].y + (pc[2].y - pc[1].y) * t;
    pc1[2].x = pc1[1].x + (p.x - pc1[1].x) * t;
    pc1[2].y = pc1[1].y + (p.y - pc1[1].y) * t;

    /* p2 of 2nd curve */
    pc2[2].x = pc[2].x + (pc[3].x - pc[2].x) * t;
    pc2[2].y = pc[2].y + (pc[3].y - pc[2].y) * t;

    /* p1 of 2nd curve */
    pc2[1].x = p.x + (pc2[2].x - p.x) * t;
    pc2[1].y = p.y + (pc2[2].y - p.y) * t;

    /* p3 (p0) of 1st (2nd) curve */
    pc1[3].x = pc2[0].x = pc1[2].x + (pc2[1].x - pc1[2].x) * t;
    pc1[3].y = pc2[0].y = pc1[2].y + (pc2[1].y - pc1[2].y) * t;

    /* p3 of 2nd curve */
    pc2[3] = pc[3];

    return 2;
}

/*
 * modified:  01.08.93 30.04.96
 * Author:    Martin Dietterle
 * purpose:   get bounds of curve
 * parameter: curve points, bounds
 * return:    none
 */
NSRect boundsOfCurve( const NSPoint pc[4] )
{   double	max, min, ft;
    double	ax, bx, cx, ay, by, cy, t, ts[2];
    int		i, cnt;
    NSRect	bounds;

    /* Berechnung und Festlegung der Bezierkurve durch die Gleichungen
     *  x(t) = ax*t^3 + bx*t^2 + cx*t + x(0)
     *  y(t) = ay*t^3 + by*t^2 + cy*t + y(0)
     */
    cx = 3.0*(pc[1].x - pc[0].x);
    bx = 3.0*(pc[2].x - pc[1].x) - cx;
    ax = pc[3].x - pc[0].x - bx - cx;
    cy = 3.0*(pc[1].y - pc[0].y);
    by = 3.0*(pc[2].y - pc[1].y) - cy;
    ay = pc[3].y - pc[0].y - by - cy;

    /* Ermittlung des maximalen und minimalen X-Wertes der Bezier-Kurve. */
    min = Min(pc[0].x, pc[3].x);
    max = Max(pc[0].x, pc[3].x);

    cnt = svPolynomial2(3.0 * ax, 2.0 * bx, cx, ts);
    for (i=0; i<cnt; i++)
    {
        t = ts[i];
        if ( t>0.0 && t<1.0)
        {
            ft = ax*t*t*t + bx*t*t + cx*t + pc[0].x;
            if (min > ft)
                min = ft;
            else if (max < ft)
                max = ft;
        }
    }

    bounds.origin.x = min;
    bounds.size.width = max - min;

    /* Ermittlung des maximalen und minimalen Y-Wertes der Bezier-Kurve. */
    min = Min(pc[0].y, pc[3].y);
    max = Max(pc[0].y, pc[3].y);

    cnt = svPolynomial2(3.0 * ay, 2.0 * by, cy, ts);
    for (i=0; i<cnt; i++)
    {
        t = ts[i];
        if ( t>0.0 && t<1.0)
        {
            ft = ay*t*t*t + by*t*t + cy*t + pc[0].y;
            if (min > ft)
                min = ft;
            else if (max < ft)
                max = ft;
        }
    }

    bounds.origin.y = min;
    bounds.size.height = max - min;
    return bounds;
}

/* created:   29.06.93
 * modified:  19.03.96
 * purpose:   get the point on 'curve' next to a 'point'
 *            we do the following:
 *            - 1st we split the passed curve in two
 *            - then we compare the distances of the new curve-points with 'point'
 *              and take the curve with the nearest point for further processing
 *            - after several loops we take the nearest curve-point as result
 * Author:    Georg Fleischmann
 * parameter: curvePoint (the result)
 *            pc (curve)
 *            point (a point)
 * return:    distance between the 'point' and 'curvePoint' or -1
 */
float pointOnCurveNextToPoint(NSPoint *curvePoint, const NSPoint *pc, const NSPoint *point)
{   NSPoint		cp[4], pc1[4], pc2[4];
    int			i;
    float		dist, newDist;
    NSRect		bounds;

    /* split curve
     */
    tileCurveAt(pc, 0.5, pc1, pc2);

    for (i=0; i<100; i++) // 20
    {
        /* we have two curves
        * and have to compare the distances between the curve-points and 'point'
        */

        /* nearest distance to 1st curve */
        dist = SqrDistPoints(pc1[0], *point);
        if ((newDist = SqrDistPoints(pc1[1], *point)) < dist)
            dist = newDist;
        if ((newDist = SqrDistPoints(pc1[2], *point)) < dist)
            dist = newDist;

        if ((newDist = SqrDistPoints(pc2[1], *point)) < dist)
        {    cp[0] = pc2[0]; cp[1] = pc2[1]; cp[2] = pc2[2]; cp[3] = pc2[3]; }
        else if ((newDist = SqrDistPoints(pc2[2], *point)) < dist)
        {    cp[0] = pc2[0]; cp[1] = pc2[1]; cp[2] = pc2[2]; cp[3] = pc2[3]; }
        else if ((newDist = SqrDistPoints(pc2[3], *point)) < dist)
        {    cp[0] = pc2[0]; cp[1] = pc2[1]; cp[2] = pc2[2]; cp[3] = pc2[3]; }
        else
        {    cp[0] = pc1[0]; cp[1] = pc1[1]; cp[2] = pc1[2]; cp[3] = pc1[3]; }

        bounds = fastBoundsOfCurve(cp);
        if (bounds.size.width < 50.0*TOLERANCE && bounds.size.height < 50.0*TOLERANCE)	/* 1/10 mm */
            break;
        tileCurveAt(cp, 0.5, pc1, pc2);
    }

    /* enough
     * now we return the curve-point next to 'point'
     */
    dist = SqrDistPoints(cp[0], *point);
    *curvePoint = cp[0];
    if ((newDist = SqrDistPoints(cp[1], *point)) < dist)
    {	dist = newDist;
        *curvePoint = cp[1];
    }
    if ((newDist = SqrDistPoints(cp[2], *point)) < dist)
    {	dist = newDist;
        *curvePoint = cp[2];
    }
    if ((newDist = SqrDistPoints(cp[3], *point)) < dist)
    {	dist = newDist;
        *curvePoint = cp[3];
    }

    return sqrt(dist);
}

/* created:   22.06.93
 * modified: 
 * purpose:   intersect two curves
 *            we do the following:
 *            - 1st we split the passed curves in two
 *            - then we check the intersection of the bounds between these curves
 *            and call intersectCurves() again to intersect the splitted curves
 *            - after several recursions we intersect the lines between the points of the two passed curves
 *            and return the intersection points by reference and the number of intersections
 * problems:  overlapping curves
 * parameter: pc1 (curve 1)
 *            pc2 (curve 2)
 *            points (intersections)
 * return:    number of intersections (0, 1, 2, 3, 4, 5, 6, 7, 8)
 */
#define MAXINTERSECTS 9
static int intersectCurves(NSPoint pc1[4], const NSPoint pc2[4], NSPoint *points)
{   NSPoint	pc1a[4], pc1b[4], pc2a[4], pc2b[4];
    int		iCnt=0;
    NSRect	bounds1, bounds2, bounds1a, bounds1b, bounds2a, bounds2b;
    NSPoint	ps[12];	/* if we get more than 9 intersections something goes wrong!! */
    BOOL	splitCurve1=YES , splitCurve2=YES;
    static int	recursions = 0;

    bounds1 = fastBoundsOfCurve(pc1);
    bounds2 = fastBoundsOfCurve(pc2);

    /* we allow a little tolerance for end points
     * if the curves are too small we may build a endless loop this way, so we process large curves only
     */
    if (bounds1.size.width+bounds1.size.height > 100.0*TOLERANCE && bounds2.size.width+bounds2.size.height > 100.0*TOLERANCE)
    {
        if (SqrDistPoints(pc1[0], pc2[0]) < (20.0*TOLERANCE)*(20.0*TOLERANCE)) // 10.0
        {   points[iCnt++] = pc1[0] = pc2[0];}
        else if (SqrDistPoints(pc1[0], pc2[3]) < (20.0*TOLERANCE)*(20.0*TOLERANCE))
        {   points[iCnt++] = pc1[0] = pc2[3];}
        if (SqrDistPoints(pc1[3], pc2[0]) < (20.0*TOLERANCE)*(20.0*TOLERANCE))
        {   points[iCnt++] = pc1[3] = pc2[0];}
        else if (SqrDistPoints(pc1[3], pc2[3]) < (20.0*TOLERANCE)*(20.0*TOLERANCE))
        {   points[iCnt++] = pc1[3] = pc2[3];}
        bounds1 = fastBoundsOfCurve(pc1);
        bounds2 = fastBoundsOfCurve(pc2);
    }

    /* a quick check for possible intersection */
    bounds2 = EnlargedRect(bounds2, TOLERANCE);
    if (!vhfIntersectsRect(bounds1, bounds2))
        return iCnt;

    /* if this value is too small we may loose some intersection points */
#   define LIMIT	TOLERANCE*10.0
    if (bounds1.size.width+bounds1.size.height < LIMIT)
        splitCurve1 = NO;
    if (bounds2.size.width+bounds2.size.height < LIMIT)
        splitCurve2 = NO;
    if ( recursions<100 && (splitCurve1 || splitCurve2) )
    {	int		i, j;
        static double	ts[] = {1.0/2.0, 3.0/8.0, 5.0/8.0, 1.0/4.0, 3.0/4.0, 1.0/8.0, 7.0/8.0};

        /* split 1st curve
         * we split at a point which is no intersection point
         */
        if ( splitCurve1 )
        {
            for (i=0; i<7; i++)
            {	tileCurveAt(pc1, ts[i], pc1a, pc1b);
                if (pointOnCurveNextToPoint(ps, pc2, &pc1a[3]) > TOLERANCE)
                    break;
            }
            /* the two curves overlap so we return the endpoints */
            if (i>=7)
            {
                if ( !iCnt )
                    points[iCnt++] = pc1[0];
                if ( iCnt==1 && !pointInArray(pc1[3], points, iCnt) )
                    points[iCnt++] = pc1[3];
                return iCnt;
            }
        }
        else
        {   pc1a[0] = pc1[0]; pc1a[1] = pc1[1]; pc1a[2] = pc1[2]; pc1a[3] = pc1[3];}

        /* split 2nd curve
         */
        if ( splitCurve2 )
        {
            for (i=0; i<7; i++)
            {   tileCurveAt(pc2, ts[i], pc2a, pc2b);
                if (pointOnCurveNextToPoint(ps, pc1, &pc2a[3]) > TOLERANCE)
                    break;
            }
            /* the two curves overlap so we return the endpoints */
            if (i>=7)
            {
                if ( !iCnt )
                    points[iCnt++] = pc2[0];
                if ( iCnt==1 && !pointInArray(pc2[3], points, iCnt) )
                    points[iCnt++] = pc2[3];
                return iCnt;
            }
        }
        else
        {   pc2a[0]=pc2[0]; pc2a[1]=pc2[1]; pc2a[2]=pc2[2]; pc2a[3]=pc2[3];}

        /* now, we have four curves
         * which we have to check for intersections
         * 1st of all we check the bounds for intersections
         * then we call intersectCurves again with the curves which seem to intersect
         */

        /* get bounds of curves */
        bounds1a = fastBoundsOfCurve(pc1a);
        bounds1b = fastBoundsOfCurve(pc1b);
        bounds2a = fastBoundsOfCurve(pc2a);
        bounds2b = fastBoundsOfCurve(pc2b);

        /* intersect the bounds and call intersectCurves() again to intersect the splitted curves
         */
        recursions++;
        if (vhfIntersectsRect(bounds1a, bounds2a))
        {
            if ((i = intersectCurves(pc1a, pc2a, ps)))
            {
                for (j=0; j<i; j++)	/* to avoid multiple equal points */
                    if (iCnt<MAXINTERSECTS && !pointInArray(ps[j], points, iCnt))
                        points[iCnt++] = ps[j];
            }
        }
        if (splitCurve2 && vhfIntersectsRect(bounds1a, bounds2b))
        {
            if ((i = intersectCurves(pc1a, pc2b, ps)))
            {
                for (j=0; j<i; j++)
                    if (iCnt<MAXINTERSECTS && !pointInArray(ps[j], points, iCnt))
                        points[iCnt++] = ps[j];
            }
        }
        if (splitCurve1 && vhfIntersectsRect(bounds1b, bounds2a))
        {
            if ((i = intersectCurves(pc1b, pc2a, ps)))
            {
                for (j=0; j<i; j++)
                    if (iCnt<MAXINTERSECTS && !pointInArray(ps[j], points, iCnt))
                        points[iCnt++] = ps[j];
            }
        }
        if (splitCurve1 && splitCurve2 && vhfIntersectsRect(bounds1b, bounds2b))
        {
            if ((i = intersectCurves(pc1b, pc2b, ps)))
            {
                for (j=0; j<i; j++)
                    if (iCnt<MAXINTERSECTS && !pointInArray(ps[j], points, iCnt))
                        points[iCnt++] = ps[j];
            }
        }
        recursions--;
    }
    /* enough recursion
     * now we intersect all lines between the vertices of the curves
     */
    else
    {	int	i, j, k, ic;

        for (i=0; i<3; i++)
        {   NSPoint	p0, p1;

            p0 = pc1[i];
            p1 = pc1[i+1];
            for (j=0; j<3; j++)
            {
                /* if we have an intersection then we add the intersection points to 'points'
                 * and increment our counter
                 */
                if ((ic = vhfIntersectLines(ps, p0, p1, pc2[j], pc2[j+1])))
                {
                    if (ic > 1)
                        break;
                    for (k=0; k<ic; k++)
                        if (iCnt<MAXINTERSECTS && !pointInArray(ps[k], points, iCnt))
                        {   points[iCnt++] = ps[k];
                            j=3; break;
                        }
                    break;
                }
            }
        }
        if (!iCnt)
        {   points[iCnt].x   = (pc1[0].x+pc1[3].x+pc2[0].x+pc2[3].x)/4.0;
            points[iCnt++].y = (pc1[0].y+pc1[3].y+pc2[0].y+pc2[3].y)/4.0;
        }
    }

    return iCnt;
}

@interface VCurve(PrivateMethods)
- (void)buildUPath;
- (void)calcVerticesFromPointsAndParallelCurve:(NSPoint)pv0 :(NSPoint)pv3 :curve;
- (float)sqrDistanceLine:(NSPoint)pl0 :(NSPoint)pl1;
- (float)sqrDistanceLine:(NSPoint)pl0 :(NSPoint)pl1 :(NSPoint*)pg1 :(NSPoint*)pg2;
- (float)sqrDistanceCurve:(NSPoint*)pc1;
- (float)sqrDistanceCurve:(NSPoint*)pc1 :(NSPoint*)pg1 :(NSPoint*)pg2;
- (void)setParameter;
@end

@implementation VCurve

/* This sets the class version so that we can compatibly read old objects out of an archive.
 */
+ (void)initialize
{
    [VCurve setVersion:2];
    return;
}

+ (VCurve*)curve
{
    return [[[VCurve allocWithZone:[self zone]] init] autorelease];
}

+ (VCurve*)curveWithPoints:(NSPoint)pt0 :(NSPoint)pt1 :(NSPoint)pt2 :(NSPoint)pt3
{   VCurve	*curve = [VCurve curve];

    [curve setVertices:pt0 :pt1 :pt2 :pt3];
    return curve;
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
{   VCurve *curve = [[VCurve allocWithZone:[self zone]] init];

    [curve setWidth:width];
    [curve setColor:color];
    [curve setLocked:NO];
    [curve setVertices:p0 :p1 :p2 :p3];
    [curve setSelected:[self isSelected]];
    return curve;
}

- (NSString*)description
{
    return [NSString stringWithFormat:@"VCurve: %f %f %f %f %f %f %f %f", p0.x, p0.y, p1.x, p1.y, p2.x, p2.y, p3.x, p3.y];
}
- (NSString*)title		{ return @"Curve"; }

/*
 * created: 25.09.95
 * purpose: initializes all the stuff needed after a -read:
 */
- (void)setParameter
{
    path.pts = malloc((PTS_BEZIER*2 + 4) * sizeof(float));
    selectedKnob = -1;
    coordBounds = NSZeroRect;
}

/* whether we are a path object
 * eg. line, polyline, arc, curve, rectangle, path
 * group is not a path object because we don't know what is inside!
 */
- (BOOL)isPathObject	{ return YES; }

/* modified: 04.07.97
 */
- (float)length
{
    /*if ( !SqrDistPoints(p0, p3) ) // wrong, a vertex could still be there
     return 0.0;*/
    return sqrt(SqrDistPoints(p0, p1)) + sqrt(SqrDistPoints(p1, p2)) + sqrt(SqrDistPoints(p2, p3));
}

- (float)angle
{
#if 0
    NSPoint	p, t1End, t2End, gradB, gradA;
    float	angle;

    p = NSMakePoint(0.0, 0.0);
    gradA = [self gradientAt:0.0];          // gradient of start-point object
    gradB = [self gradientAt:1.0/3.0];      // gradient of end-point for object
    t1End.x = p.x - gradA.x;
    t1End.y = p.y - gradA.y;
    t2End.x = p.x + gradB.x;
    t2End.y = p.y + gradB.y;
    angle = vhfAngleBetweenPoints(t1End, p, t2End); // get angle (ccw) on right side

    gradA = [self gradientAt:2.0/3.0];      // gradient of start-point object
    gradB = [self gradientAt:1.0];          // gradient of end-point for object
    t1End.x = p.x - gradA.x;
    t1End.y = p.y - gradA.y;
    t2End.x = p.x + gradB.x;
    t2End.y = p.y + gradB.y;
#endif
#if 0
    //return vhfAngleBetweenPoints(p0, p1, p2) + vhfAngleBetweenPoints(p1, p2, p3);
    if ( p3.x==p2.x && p3.y==p2.y )
        return ( vhfAngleBetweenPoints(p3, p1, p0) + 180.0 );
    if ( (p2.x==p1.x && p2.y==p1.y) || (p1.x==p0.x && p1.y==p0.y) )
        return ( vhfAngleBetweenPoints(p3, p2, p0) + 180.0 );
    return vhfAngleBetweenPoints(p3, p2, p1) + vhfAngleBetweenPoints(p2, p1, p0);
#endif

    {   NSPoint	pArray[2];
        float	a1, a2;

        if ( (Diff(p3.x, p2.x)<=TOLERANCE && Diff(p3.y, p2.y)<=TOLERANCE) ||
             (Diff(p0.x, p2.x)<=TOLERANCE && Diff(p0.y, p2.y)<=TOLERANCE) )
            return ( vhfAngleBetweenPoints(p3, p1, p0) + 180.0 );
        if ( (Diff(p2.x, p1.x)<=TOLERANCE && Diff(p2.y, p1.y)<=TOLERANCE) ||
             (Diff(p1.x, p0.x)<=TOLERANCE && Diff(p1.y, p0.y)<=TOLERANCE) ||
             (Diff(p3.x, p1.x)<=TOLERANCE && Diff(p3.y, p1.y)<=TOLERANCE) )
        //if ( (p2.x==p1.x && p2.y==p1.y) || (p1.x==p0.x && p1.y==p0.y) )
            return ( vhfAngleBetweenPoints(p3, p2, p0) + 180.0 );

        /* line from p0 to p1 intersect line from p2 to p3 */
        if ( vhfIntersectLines(pArray, p0, p1, p3, p2) )
        {   NSPoint	mP;
            mP.x = Min(p1.x, p2.x) + ((Max(p1.x, p2.x)-Min(p1.x, p2.x))/2.0);
            mP.y = Min(p1.y, p2.y) + ((Max(p1.y, p2.y)-Min(p1.y, p2.y))/2.0);
            return vhfAngleBetweenPoints(p3, mP, p0) + 180.0;
        }
        /* must not be 0 ! */
        a1 = vhfAngleBetweenPoints(p3, p2, p1);
        a2 = vhfAngleBetweenPoints(p2, p1, p0);
        if ( a1 < 1.0 || a2 < 1.0 || a1 > 359.0 || a2 > 359.0 )
        {
            if ( a1 < 1.0 || a1 > 359.0 ) a1 = 180.0;
            if ( a2 < 1.0 || a2 > 359.0 ) a2 = 180.0;
        }
        return a1 + a2;
    }
}

/* created: 05.03.97
 */
- (NSPoint)center
{   NSRect	rect;
    NSPoint	p;

    rect = [self coordBounds];
    p.x = rect.origin.x + rect.size.width/2.0;
    p.y = rect.origin.y + rect.size.height/2.0;
    return p;
}

- parallelObject:(NSPoint)begO :(NSPoint)endO :(NSPoint)beg :(NSPoint)end
{   VCurve		*curve = [[self copy] autorelease];
    NSMutableArray	*splitList = 0;
    NSPoint		pts[2];

    /* here we tile the curve
     * 1st we check if curve needs to be splitted at start and end
     * if the curve isn't split on both sides we check the start point
     * if the curve isn't split on start side we check the end point
     */
    if ( !(SqrDistPoints(beg, begO) < TOLERANCE) && !(SqrDistPoints(end, endO) < TOLERANCE) )
    {
        [curve setVertices:begO :p1 :p2 :endO];
        [curve calcVerticesFromPointsAndParallelCurve:begO :endO :self];
        pts[0] = beg;
        pts[1] = end;
        splitList = [curve getListOfObjectsSplittedFrom:pts :2];
        if ( [splitList count] == 3 )
        {   curve = [splitList objectAtIndex:1];		/* we need the curve in the middle */
            return curve;
        }
    }
    else if ( !(SqrDistPoints(beg, begO) < TOLERANCE) )	/* check start */
    {
        [curve setVertices:begO :p1 :p2 :endO];
        [curve calcVerticesFromPointsAndParallelCurve:begO :endO :self];
        pts[0] = beg;
        splitList = [curve getListOfObjectsSplittedFrom:pts :1];
        if ( [splitList count] == 2 )
        {   curve = [splitList objectAtIndex:1];		/* we need the second curve */
            return curve;
        }
    }
    else if ( !(SqrDistPoints(end, endO) < TOLERANCE) )	/* check end */
    {
        [curve setVertices:begO :p1 :p2 :endO];
        [curve calcVerticesFromPointsAndParallelCurve:begO :endO :self];
        pts[0] = end;
        splitList = [curve getListOfObjectsSplittedFrom:pts :1];
        if ( [splitList count] == 2 )
        {   curve = [splitList objectAtIndex:0];		/* we need the first curve */
            return curve;
        }
    }

    /* if curve didn't split or difference between endpoints is too small (beg/begO)
     * calc parallel curve directly with new points
     */
    curve = [[self copy] autorelease];
    [curve setVertices:beg :p1 :p2 :end];
    [curve calcVerticesFromPointsAndParallelCurve:beg :end :self];

    return curve;
}

/* create
 * modified: 2010-02-18 (exit with right mouse click)
 */
#define CREATEEVENTMASK NSLeftMouseDraggedMask|NSLeftMouseDownMask|NSLeftMouseUpMask|NSRightMouseDownMask|NSPeriodicMask
- (BOOL)create:(NSEvent *)event in:(DocView*)view
{   NSRect	viewBounds, gridBounds, drawBounds;
    NSPoint	start, last, gridPoint, drawPoint, lastPoint = NSZeroPoint, hitPoint;
    id		window = [view window];
    VCurve 	*drawCurveGraphic;
    BOOL	ok = YES, dragging = NO, hitEdge = NO, p3HitEdge = NO, inTimerLoop = NO;
    float	grid = 1.0 / [view scaleFactor];	// minimum accepted length
    int		windowNum = [event windowNumber];
    NSEvent	*nextEvent = nil;
    VLine	*drawFirstControlLine = [VLine line];
    VLine	*drawSecondControlLine = [VLine line];
    BOOL    alternate = [(App*)NSApp alternate];

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

    [self setVertices:start :start :start :start];
    drawCurveGraphic = [[self copy] autorelease];
    [drawCurveGraphic setColor:[NSColor lightGrayColor]];
    gridBounds = [self extendedBoundsWithScale:[view scaleFactor]];

    last = start;

    event = [NSApp nextEventMatchingMask:CREATEEVENTMASK untilDate:[NSDate distantFuture] inMode:NSEventTrackingRunLoopMode dequeue:YES];
    StartTimer(inTimerLoop);
    /* now entering the tracking loop
     * get endpoint of curve
     */
    while ( [event type] != NSLeftMouseDown && [event type] != NSRightMouseDown &&
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
                 (Diff(p0.x, drawPoint.x) > 3.0*grid || Diff(p0.y, drawPoint.y) > 3.0*grid) )
                dragging = YES;
            else
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
            p3HitEdge = [view hitEdge:&hitPoint spare:self];
            if ( p3HitEdge &&
                 ((gridPoint.x == drawPoint.x && gridPoint.y == drawPoint.y)  ||
                  (SqrDistPoints(hitPoint, drawPoint) < SqrDistPoints(gridPoint, drawPoint))) )
                gridPoint = hitPoint; // we took the nearer one if we got a hitPoint

            [window displayCoordinate:gridPoint ref:NO];

            [self setVertices:start :start :gridPoint :gridPoint];
            gridBounds = [self extendedBoundsWithScale:[view scaleFactor]];

            [drawCurveGraphic setVertices:start :start :drawPoint :drawPoint];
            drawBounds = [drawCurveGraphic extendedBoundsWithScale:[view scaleFactor]];
            gridBounds  = NSUnionRect(drawBounds , gridBounds);

            if ( NSContainsRect(viewBounds , gridBounds) )
            {   [drawCurveGraphic drawWithPrincipal:view];
                [self drawWithPrincipal:view];
            }
            else
                drawPoint = gridPoint = start;				// else set line invalid

            [window flushWindow];
        }
        nextEvent = (event = [NSApp nextEventMatchingMask:CREATEEVENTMASK untilDate:[NSDate distantFuture] inMode:NSEventTrackingRunLoopMode dequeue:YES]);
    }

    if ( [event type] == NSRightMouseDown ||
         (fabs(gridPoint.x-start.x) <= grid && fabs(gridPoint.y-start.y) <= grid) ) // no length -> not valid
        ok = NO;
    else if ( [event type] == NSLeftMouseDown )
    {
        if ([event clickCount] > 1 || [event windowNumber] != windowNum)	// double click or out of window
            ok = NO;
        else
            ok = NSMouseInRect(gridPoint , viewBounds , NO);
    }
    else
        ok = NO;

    /*
     * get first vertice of curve
     */
    if ( ok )
    {
        [drawFirstControlLine setColor:[NSColor lightGrayColor]];

        event = [NSApp nextEventMatchingMask:CREATEEVENTMASK
                                   untilDate:[NSDate distantFuture]
                                      inMode:NSEventTrackingRunLoopMode dequeue:YES];
        while ([event type] != NSLeftMouseDown && [event type] != NSRightMouseDown &&
               [event type] != NSAppKitDefined && [event type] != NSSystemDefined)
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

                [drawFirstControlLine setVertices:p0 :gridPoint];

                [self setVertices:p0 :gridPoint :p3 :p3];
                gridBounds = [self extendedBoundsWithScale:[view scaleFactor]];

                [drawCurveGraphic setVertices:p0 :drawPoint :p3 :p3];
                drawBounds = [drawCurveGraphic extendedBoundsWithScale:[view scaleFactor]];
                gridBounds  = NSUnionRect(drawBounds , gridBounds);

                if ( NSContainsRect(viewBounds , gridBounds) )
                {   [drawFirstControlLine drawWithPrincipal:view];
//[self drawControls:(NSRect)rect direct:YES scaleFactor:(float)scaleFactor];
                    [drawCurveGraphic drawWithPrincipal:view];
                    [self drawWithPrincipal:view];
                }
                else
                    drawPoint = gridPoint = start;			// else set line invalid

                [window flushWindow];
            }
            event = [NSApp nextEventMatchingMask:CREATEEVENTMASK
                                       untilDate:[NSDate distantFuture]
                                          inMode:NSEventTrackingRunLoopMode dequeue:YES];
        }
    }

    if ( [event type] == NSLeftMouseDown )
    {
        if ([event clickCount] > 1 || [event windowNumber] != windowNum) // double click or out of window
            ok = NO;
        else
            ok = NSMouseInRect(gridPoint , viewBounds , NO);
    }
    else
        ok = NO;

    if ( ok )
    {
        [drawSecondControlLine setColor:[NSColor lightGrayColor]];

        event = [NSApp nextEventMatchingMask:CREATEEVENTMASK
                                   untilDate:[NSDate distantFuture]
                                      inMode:NSEventTrackingRunLoopMode dequeue:YES];
        while ([event type] != NSLeftMouseDown && [event type] != NSRightMouseDown &&
               [event type] != NSAppKitDefined && [event type] != NSSystemDefined)
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

                /* delete curve from screen */
                [view drawRect:gridBounds];
                drawPoint = [view convertPoint:drawPoint fromView:nil];

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

                [drawSecondControlLine setVertices:p3 :gridPoint];

                [self setVertices:p0 :p1 :gridPoint :p3];
                gridBounds = [self extendedBoundsWithScale:[view scaleFactor]];

                [drawCurveGraphic setVertices:p0 :p1 :drawPoint :p3];
                drawBounds = [drawCurveGraphic extendedBoundsWithScale:[view scaleFactor]];
                /* the united rect of the two rect's we need to redraw the view */
                gridBounds  = NSUnionRect(drawBounds , gridBounds);

                /* if line is not inside view we set it invalid */
                if ( NSContainsRect(viewBounds , gridBounds) )
                {   [drawFirstControlLine drawWithPrincipal:view];
                    [drawSecondControlLine drawWithPrincipal:view];
                    [drawCurveGraphic drawWithPrincipal:view];
                    [self drawWithPrincipal:view];
                }
                else
                    drawPoint = gridPoint = start;			// else set line invalid

                [window flushWindow];
            }
            event = [NSApp nextEventMatchingMask:CREATEEVENTMASK
                                       untilDate:[NSDate distantFuture]
                                          inMode:NSEventTrackingRunLoopMode dequeue:YES];
        }
    }
    StopTimer(inTimerLoop);

    last = gridPoint;

    if ( fabs(last.x-start.x) <= grid && fabs(last.y-start.y) <= grid )	// no length -> not valid
        ok = NO;
    else if ( ok && ([event type] == NSLeftMouseDown || [event type] == NSRightMouseDown) )
    {
        /* double click or out of window -> not valid */
        if ([event clickCount] > 1 || [event windowNumber] != windowNum)
            ok = NO;
        else
            ok = NSMouseInRect(gridPoint , viewBounds , NO);
    }
    else if ([event type] == NSAppKitDefined || [event type] == NSSystemDefined)
        ok = NO;

    [view unlockFocus];

    if (!ok)
    {
        /* we duplicate the last click which ends the line,
         * so we can directly execute user actions in Tool-Panel etc.
         *
         * we must close the mouseDown event else object will be moved from DocView
         */
        if ([event windowNumber] != windowNum || [event type] == NSLeftMouseDown || [event type] == NSRightMouseDown)
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
    [view cacheGraphic:self];	// add to graphic cache
    if ( !p3HitEdge && !alternate && [event type] != NSRightMouseDown )
        [window postEvent:nextEvent atStart:1];	// init new line

    return YES;
}

/* set our vertices
 */
- (void)setVertices:(NSPoint)pv0 :(NSPoint)pv1 :(NSPoint)pv2 :(NSPoint)pv3
{
    p0 = pv0;
    p1 = pv1;
    p2 = pv2;
    p3 = pv3;
    [self buildUPath];
    coordBounds = NSZeroRect;
    dirty = YES;
}

/*
 * return our vertices
 */
- (void)getVertices:(NSPoint*)pv0 :(NSPoint*)pv1 :(NSPoint*)pv2 :(NSPoint*)pv3
{
    *pv0 = p0;
    *pv1 = p1;
    *pv2 = p2;
    *pv3 = p3;
}

/*
 * changes the direction of the line p1<->p2
 */
- (void)changeDirection
{   NSPoint	p;

    p = p0; p0 = p3; p3 = p;
    p = p1; p1 = p2; p2 = p;
    [self buildUPath];
    dirty = YES;
}

/* created:	
 * modified:
 * parameter: p  the point
 *            t  0 <= t <= 1
 * purpose:   get a point on the curve at t
 */
- (NSPoint)pointAt:(float)t
{   NSPoint	pt[3], p;

    pt[0].x=p0.x+t*(p1.x-p0.x);
    pt[0].y=p0.y+t*(p1.y-p0.y);
    pt[1].x=p1.x+t*(p2.x-p1.x);
    pt[1].y=p1.y+t*(p2.y-p1.y);
    pt[2].x=p2.x+t*(p3.x-p2.x);
    pt[2].y=p2.y+t*(p3.y-p2.y);

    pt[0].x=pt[0].x+t*(pt[1].x-pt[0].x);
    pt[0].y=pt[0].y+t*(pt[1].y-pt[0].y);
    pt[1].x=pt[1].x+t*(pt[2].x-pt[1].x);
    pt[1].y=pt[1].y+t*(pt[2].y-pt[1].y);

    p.x=pt[0].x+t*(pt[1].x-pt[0].x);
    p.y=pt[0].y+t*(pt[1].y-pt[0].y);

    return p;
}

/* created:   18.07.95
 * modified:  14.03.96
 * purpose:   calculate our vertices from 4 points on the curve
 *            The two points (pv1, pv2) should lay at 1/3 and 2/3 of the curve to achieve best results.
 *            This function works perfectly for curves not changing the direction (1 extrema).
 *            Otherwise the function will build the flattest curve that fits.
 *            pv0 and pv3 are the endpoints of the curve
 * parameter: pv0, pv1, pv2, pv3
 */
- (void)calcVerticesFromPoints:(NSPoint)pv0 :(NSPoint)pv1 :(NSPoint)pv2 :(NSPoint)pv3
{   double	t;
    double	m[3][3], x123[3], y123[3], abcX[3], abcY[3];

    x123[0] = pv1.x - pv0.x;
    y123[0] = pv1.y - pv0.y;
    x123[1] = pv2.x - pv0.x;
    y123[1] = pv2.y - pv0.y;
    x123[2] = pv3.x - pv0.x;
    y123[2] = pv3.y - pv0.y;

    t = 1.0 / 3.0;
    m[0][0] = t * t * t;
    m[0][1] = t * t;
    m[0][2] = t;
    t = 2.0 / 3.0;
    m[1][0] = t * t * t;
    m[1][1] = t * t;
    m[1][2] = t;
    t = 1.0;
    m[2][0] = t * t * t;
    m[2][1] = t * t;
    m[2][2] = t;

    /* calculate a, b, c of the curve segment
     */
    if (!solveEquation3(m, x123, abcX) || !solveEquation3(m, y123, abcY))
    {   NSLog(@"VCurve, - calcVerticesFromPoints: %f %f %f %f", pv0, pv1, pv2, pv3);
        return;
    }

    /* calculate the curve points for the segment
     * x1 = x0 + cx/3			y1 = y0 + cy/3
     * x2 = x1 + (cx + bx)/3	y2 = y1 + (cy + by)/3
     * x3 = x0 + cx + bx + ax	y3 = y0 + cy + by + ay
     */
    p0 = pv0;
    p1.x = pv0.x + abcX[2]/3.0;
    p1.y = pv0.y + abcY[2]/3.0;
    p2.x = p1.x + (abcX[2] + abcX[1])/3.0;
    p2.y = p1.y + (abcY[2] + abcY[1])/3.0;
    //	p3.x = pv0.x + abcX[2] + abcX[1] + abcX[0];
    //	p3.y = pv0.y + abcY[2] + abcY[1] + abcY[0];
    p3 = pv3;

    [self buildUPath];
    dirty = YES;
}

/* created:      08.04.96
 * modified:     28.02.97
 * purpose:      calculate our vertices from the 2 end-points and the relationships between the length
 *		- new p0 and p3 are given
 *		- length(0/1) / length(2/3) is equal for both curves
 *		- lengthTot = length(0/1) + length(1/2) + length(2/3)
 *		- length1(0/3) / length2(0/3) = length1Tot / length2Tot
 * parameter:    pv0, pv3, parallel curve
 * return value: self
 */
- (void)calcVerticesFromPointsAndParallelCurve:(NSPoint)pv0 :(NSPoint)pv3 :curve
{   NSPoint	pcOld[4];	/* old curve vertices */
    double	len03, len01, len12, len23, len03Old, len12Old, len01Old, len23Old, lenTot, lenTotOld,
                n;
    NSPoint	d0, d3;

    [curve getVertices:&pcOld[0] :&pcOld[1] :&pcOld[2] :&pcOld[3]];
    d0.x = pcOld[1].x - pcOld[0].x; d0.y = pcOld[1].y - pcOld[0].y;
    if (Diff(d0.x, 0.0)+Diff(d0.y, 0.0) < TOLERANCE)
    {	d0.x = pcOld[2].x - pcOld[0].x; d0.y = pcOld[2].y - pcOld[0].y;}
    if (Diff(d0.x, 0.0)+Diff(d0.y, 0.0) < TOLERANCE)
    {	d0.x = pcOld[3].x - pcOld[0].x; d0.y = pcOld[3].y - pcOld[0].y;}
    d3.x = pcOld[2].x - pcOld[3].x; d3.y = pcOld[2].y - pcOld[3].y;
    if (Diff(d3.x, 0.0)+Diff(d3.y, 0.0) < TOLERANCE)
    {	d3.x = pcOld[1].x - pcOld[3].x; d3.y = pcOld[1].y - pcOld[3].y;}
    if (Diff(d0.x, 0.0)+Diff(d0.y, 0.0) < TOLERANCE)
    {	d3.x = pcOld[0].x - pcOld[3].x; d3.y = pcOld[0].y - pcOld[3].y;}

    p0 = pv0;
    p3 = pv3;

    len03 = sqrt(SqrDistPoints(p0, p3));
    if ( !(len03Old = sqrt(SqrDistPoints(pcOld[0], pcOld[3]))) )
    {   NSLog(@"calcVerticesFromPointsAndParallelCurve::: VCurve has zero length: x0/x3:%f y0/y3:%f", pcOld[0].x, pcOld[0].y);
        p1 = pcOld[1]; p2 = pcOld[2];
        [self buildUPath];
        return;
    }

    len01Old = sqrt(SqrDistPoints(pcOld[0], pcOld[1]));
    len12Old = sqrt(SqrDistPoints(pcOld[1], pcOld[2]));
    len23Old = sqrt(SqrDistPoints(pcOld[2], pcOld[3]));

    len12 = len12Old * len03/len03Old;
    lenTotOld = len01Old + len12Old + len23Old;
    lenTot = lenTotOld * len03/len03Old;

    /* len01Old/len23Old = len01/len23, len23 = lenTot-len12 */
    if (Diff(len01Old, 0.0) < TOLERANCE)	/* p1 = p0 ! */
        len01Old = (Diff(len12Old, 0.0) < TOLERANCE) ? len23Old : len12Old;
    if (Diff(len23Old, 0.0) < TOLERANCE)	/* p2 = p3 ! */
        len23Old = (Diff(len12Old, 0.0) < TOLERANCE) ? len01Old : len12Old;
    n = len01Old / len23Old;
    len01 = ((lenTot - len12)*n) / (1+n);
    p1.x = (!len01Old) ? pcOld[1].x : p0.x + (len01*d0.x)/len01Old;
    p1.y = (!len01Old) ? pcOld[1].y : p0.y + (len01*d0.y)/len01Old;

    len23 = lenTot - len01 - len12;
    p2.x = (!len23Old) ? pcOld[2].x : p3.x + (len23*d3.x)/len23Old;
    p2.y = (!len23Old) ? pcOld[2].y : p3.y + (len23*d3.y)/len23Old;

    [self buildUPath];
    dirty = YES;
}

#if 0
/* created:   04.04.96
 * modified:  28.02.97
 * purpose:   calculate our vertices from 4 points on the curve
 *            The two points (pv1, pv2) should lay at 1/3 and 2/3 of the curve to achieve best results.
 *            This function works perfectly for curves not changing the direction (1 extrema).
 *            Otherwise the function will build the flattest curve that fits.
 *            pv0 and pv3 are the endpoints of the curve
 * parameter: pv0, pv1, pv2, pv3
 */
- (void)calcVerticesFromPointsAndGradient:(NSPoint)pv0 :(NSPoint)d0 :(NSPoint)pv1 :(NSPoint)d1 :(NSPoint)pv2 :(NSPoint)d3 :(NSPoint)pv3 :curve
{   double	t, g;
    double	m[6][6], aIn[6], abc[6];
//    double	ax=abcIn[0], bx=abcIn[1], cx=abcIn[2], ay=abcIn[3], by=abcIn[4], cy=abcIn[5];
    NSPoint	ps[4];

    /* 0 -> (3*ax*t*t + 2*bx*t + cx) / (3*ay*t*t + 3*by*t + cy) = dx / dy   for p0
     * 1 -> (3*ax*t*t + 2*bx*t + cx) / (3*ay*t*t + 3*by*t + cy) = dx / dy   for p3
     * 2 -> (cx/3+bx/3) / (cy/3+by/3) = d12.x / d12.y
     * 3 -> ay*t*t*t + by*t*t + cy*t = p2y
     * 4 -> ax*t*t*t + bx*t*t + cx*t = p3x
     * 5 -> ay*t*t*t + by*t*t + cy*t = p3y
     *
     * m[y][0] = ax, m[y][1] = bx, m[y][2] = cx, m[y][3] = ay, m[y][4] = by, m[y][5] = cy
     */
    t = 0.0;
    g = d0.x / d0.y;		/* gradient */
    m[0][0] = 3.0 * t * t;	/* ax */
    m[0][1] = 2.0 * t;		/* bx */
    m[0][2] = 1.0;		/* cx */
    m[0][3] = -3.0 * t * t * g;	/* ay */
    m[0][4] = -2.0 * t * g;	/* by */
    m[0][5] = -1.0 * g;		/* cy */
    aIn[0] = 0.0;

    t = 2.0 / 3.0;
    m[1][0] = t * t * t;	/* ax */
    m[1][1] = t * t;		/* bx */
    m[1][2] = t;		/* cx */
    m[1][3] = 0.0;		/* ay */
    m[1][4] = 0.0;		/* by */
    m[1][5] = 0.0;		/* cy */
    aIn[1] = pv2.x - pv0.x;

    m[2][0] = 0.0;		/* ax */
    m[2][1] = 0.0;		/* bx */
    m[2][2] = 0.0;		/* cx */
    m[2][3] = t * t * t;	/* ay */
    m[2][4] = t * t;		/* by */
    m[2][5] = t;		/* cy */
    aIn[2] = pv2.y - pv0.y;

    t = 1.0;
    m[3][0] = t * t * t;	/* ax */
    m[3][1] = t * t;		/* bx */
    m[3][2] = t;		/* cx */
    m[3][3] = 0.0;		/* ay */
    m[3][4] = 0.0;		/* by */
    m[3][5] = 0.0;		/* cy */
    aIn[3] = pv3.x - pv0.x;

    m[4][0] = 0.0;		/* ax */
    m[4][1] = 0.0;		/* bx */
    m[4][2] = 0.0;		/* cx */
    m[4][3] = t * t * t;	/* ay */
    m[4][4] = t * t;		/* by */
    m[4][5] = t;		/* cy */
    aIn[4] = pv3.y - pv0.y;

    t = 1.0;
    g = d3.x / d3.y;		/* gradient */
    m[5][0] = 3.0 * t * t;	/* ax */
    m[5][1] = 2.0 * t;		/* bx */
    m[5][2] = 1.0;		/* cx */
    m[5][3] = -3.0 * t * t * g;	/* ay */
    m[5][4] = -2.0 * t * g;	/* by */
    m[5][5] = -1.0 * g;		/* cy */
    aIn[5] = 0.0;

#if 0
    /* p3x = p3x+dx * (p3y/(p3y+dy)), x component of line through p3 parallel to originating curves line between p2/p3 */
    g = (pv3.y-pv0.y) + d3.y;
    m[4][0] = g;		/* ax */
    m[4][1] = g;		/* bx */
    m[4][2] = g;		/* cx */
    m[4][3] = -d3.x;			/* ay */
    m[4][4] = -d3.x;			/* by */
    m[4][5] = -d3.x;			/* cy */
    aIn[4] = (pv3.x - pv0.x) * g;

    /* p3y = p3y+dy * (p3x/(p3x+dx)), y component of line through p3 parallel to originating curves line between p2/p3 */
    g = (pv3.x-pv0.x) + d3.x;
    m[5][0] = -d3.y;			/* ax */
    m[5][1] = -d3.y;			/* bx */
    m[5][2] = -d3.y;			/* cx */
    m[5][3] = g;				/* ay */
    m[5][4] = g;				/* by */
    m[5][5] = g;				/* cy */
    aIn[5] = (pv3.y - pv0.y) * g;
#endif

#if 0
    t = 1.0;
    m[5][0] = t * t * t;		/* ax */
    m[5][1] = t * t;			/* bx */
    m[5][2] = t;				/* cx */
    m[5][3] = 0.0;				/* ay */
    m[5][4] = 0.0;				/* by */
    m[5][5] = 0.0;				/* cy */
    aIn[5] = pv3.x - pv0.x;
#endif

#if 0
    d3.x = -d3.x;
    g = (pv3.y-pv0.y) + d3.y;
    m[5][0] = g;				/* ax */
    m[5][1] = g;				/* bx */
    m[5][2] = g;				/* cx */
    m[5][3] = -d3.x;			/* ay */
    m[5][4] = -d3.x;			/* by */
    m[5][5] = -d3.x;			/* cy */
    aIn[5] = (pv3.x - pv0.x) * g;
#endif

    /* calculate a, b, c of the curve segment
     */
    if ( !solveEquationN(m, aIn, abc, 6) )
    {	NSLog(@"VCurve, - calcVerticesFromPointsAndGradient: no solution");
        [self calcVerticesFromPoints:pv0 :pv1 :pv2 :pv3];
        return self;
    }

    /* calculate the curve points for the segment
     * x1 = x0 + cx/3			y1 = y0 + cy/3
     * x2 = x1 + (cx + bx)/3	y2 = y1 + (cy + by)/3
     * x3 = x0 + cx + bx + ax	y3 = y0 + cy + by + ay
     *
     * x3 = x2 + cx/3 + 2/3*bx + ax
     *
     * abc[0] = ax, abc[1] = bx, abc[2] = cx, abc[3] = ay, abc[4] = by, abc[5] = cy
     */
    p0 = pv0;
    p1.x = pv0.x + abc[2]/3.0;
    p1.y = pv0.y + abc[5]/3.0;
    p2.x = p1.x + (abc[2] + abc[1])/3.0;
    p2.y = p1.y + (abc[5] + abc[4])/3.0;
    p3.x = pv0.x + abc[2] + abc[1] + abc[0];
    p3.y = pv0.y + abc[5] + abc[4] + abc[3];
//	p3 = pv3;

    {	NSPoint	p, d;
        float	v;

        [self getPoint:&p at:1.0/3.0];
        d = [self gradientAt:1.0/3.0]; v = d.x; d.x = d.y; d.y = -v;
        if (![curve intersectVector:ps :p :d] || SqrDistPoints(ps[0], p) > TOLERANCE*100.0)
        {   [self calcVerticesFromPoints:pv0 :pv1 :pv2 :pv3];
            return self;
        }
    }
    [self buildUPath];
    dirty = YES;
}
#endif

/* created: 04.01.95
 * purpose: return the gradient (delta x, y) of the curve at t
 */
- (NSPoint)gradientAt:(float)t
{   float	ax, bx, cx, ay, by, cy;
    NSPoint	p;

    /* represent the curve with the equations
     * x(t) = ax*t^3 + bx*t^2 + cx*t + x(0)
     *
     * calculate a, b, c
     * x1 = x0 + cx/3
     * x2 = x1 + (cx + bx)/3
     * x3 = x0 + cx + bx + ax
     */
    cx = 3.0*(p1.x - p0.x);
    bx = 3.0*(p2.x - p1.x) - cx;
    ax = p3.x - p0.x - bx - cx;
    cy = 3.0*(p1.y - p0.y);
    by = 3.0*(p2.y - p1.y) - cy;
    ay = p3.y - p0.y - by - cy;

    /* get the gradient at t.
     * dx = 3*ax*t^2 + 2*bx*t + cx
     * dy = 3*ay*t^2 + 2*by*t + cy
     */
    p.x = 3.0*ax*t*t + 2.0*bx*t + cx;
    p.y = 3.0*ay*t*t + 2.0*by*t + cy;

    if ( !p.x && !p.y && (t == 0.0 || t == 1.0) )
    {
        if ( SqrDistPoints(p0, p1) < TOLERANCE && SqrDistPoints(p2, p3) < TOLERANCE )
        {   p.x = p3.x - p0.x;
            p.y = p3.y - p0.y;
        }
        else if ( SqrDistPoints(p0, p1) < TOLERANCE )
        {   p.x = p2.x - p0.x;
            p.y = p2.y - p0.y;
        }
        else if ( SqrDistPoints(p2, p3) < TOLERANCE )
        {   p.x = p3.x - p1.x;
            p.y = p3.y - p1.y;
        }
    }
    return p;
}

- (NSPoint)gradientNear:(float)t
{   NSPoint	grad = NSMakePoint(0.0, 0.0);

    if ( t<0.5 )	/* calc to beg */
    {
        for ( ; !grad.x && !grad.y && t<=1.0; t+=1.0/3.0 )
            grad = [self gradientAt:t];
    }
    else
    {
        for ( ; !grad.x && !grad.y && t>=0.0; t-=1.0/3.0 )
            grad = [self gradientAt:t];
    }
    return grad;
}

/* created:   22.06.93
 * modified:	
 * purpose:   intersect a line and a curve
 * parameter: line
 *            curve
 *            points (intersections)
 * return:    number of intersections
 *            0, 1, 2, 3
 */
- (int)intersectVector:(NSPoint*)pArray :(NSPoint)pl :(NSPoint)dl
{   double	m=0.0, x0=0.0, ax, bx, cx, ay, by, cy, sol[3];
    int		numSol=0, n, n1;
    NSPoint	*points = pArray;

    /* represent the curve with the equations
     * x(t) = ax*t^3 + bx*t^2 + cx*t + x(0)
     * y(t) = ay*t^3 + by*t^2 + cy*t + y(0)
     */
    cx = 3.0*(p1.x - p0.x); bx = 3.0*(p2.x - p1.x) - cx; ax = p3.x - p0.x - bx - cx;
    cy = 3.0*(p1.y - p0.y); by = 3.0*(p2.y - p1.y) - cy; ay = p3.y - p0.y - by - cy;

    /* represent the line with the equation
     * g(x) = m*x + x(0)
     */
    if ( Diff(dl.x, 0) > TOLERANCE )
    {	m  = dl.y / dl.x;
        x0 = pl.y - m * pl.x;

        /* calculate the t values of the intersection
         * ax*t^3 + bx*t^2 + cx*t + dx = x
         * ay*t^3 + by*t^2 + cy*t + dy = m * x + x0
         *
         * (m*ax-ay)*t^3 + (m*bx-by)*t^2 + (m*cx-cy)*t - m*x(0)-y(0) = 0
         */
        n1 = svPolynomial3( m*ax-ay, m*bx-by, m*cx-cy, m*p0.x-p0.y+x0, sol);
    }
    /* line is vertical
     * x(t) = ax*t^3 + bx*t^2 + cx*t + x(0)
     * with x(t) = x of line
     */
    else
        n1 = svPolynomial3( ax, bx, cx, p0.x-pl.x, sol);

    for (n = 0; n < n1; n++)
    {
        if (sol[n] < -TOLERANCE || sol[n] > 1.0+TOLERANCE)
            continue;
        if ( Diff(dl.x, 0) > TOLERANCE )
        {	points->x = ax*sol[n]*sol[n]*sol[n] + bx*sol[n]*sol[n] + cx*sol[n] + p0.x;
            points->y = m*points->x+x0;
            points++;
            numSol++;
        }
        else	/* vertical line */
        {	points->y = ay*sol[n]*sol[n]*sol[n] + by*sol[n]*sol[n] + cy*sol[n] + p0.y;
            points->x = pl.x;
            points++;
            numSol++;
        }
    }

    for (n=0; n<numSol; n++)
    {	if (SqrDistPoints(points[n], p0) < TOLERANCE)
        points[n] = p0;
        else if (SqrDistPoints(points[n], p3) < TOLERANCE)
            points[n] = p3;
    }

    return(numSol);
}

/* created:   22.06.93
 * modified:  03.10.96 08.04.97
 * purpose:   intersect a line and a curve
 * parameter: line
 *            curve
 *            points (intersections)
 * return:    number of intersections
 *            0, 1, 2, 3
 */
- (int)intersectLine:(NSPoint*)pArray :(NSPoint)pl0 :(NSPoint)pl1
{   double	dx, dy, m=0.0, x0=0.0, ax, bx, cx, ay, by, cy, sol[3];
    float	max, min;
    int		numSol=0, n, n1;
    NSRect	cBounds, lBounds;
    NSPoint	*points = pArray, *pp;
    int		tangentCnt = 0;

    /* we allow a little tolerance for end points
     */
    if (Diff(pl0.x, p0.x) + Diff(pl0.y, p0.y) <= TOLERANCE)
        pl0 = p0;
    if (Diff(pl0.x, p3.x) + Diff(pl0.y, p3.y) <= TOLERANCE)
        pl0 = p3;
    if (Diff(pl1.x, p0.x) + Diff(pl1.y, p0.y) <= TOLERANCE)
        pl1 = p0;
    if (Diff(pl1.x, p3.x) + Diff(pl1.y, p3.y) <= TOLERANCE)
        pl1 = p3;

    /* a quick check for possible intersection */
    cBounds = [self bounds];
    lBounds.origin.x = Min(pl0.x, pl1.x) - TOLERANCE;
    lBounds.origin.y = Min(pl0.y, pl1.y) - TOLERANCE;
    lBounds.size.width  = Max(pl0.x, pl1.x) - lBounds.origin.x + 2.0*TOLERANCE;
    lBounds.size.height = Max(pl0.y, pl1.y) - lBounds.origin.y + 2.0*TOLERANCE;
    if (NSIsEmptyRect(NSIntersectionRect(cBounds , lBounds)))
        return 0;

    /* represent the curve with the equations
     * x(t) = ax*t^3 + bx*t^2 + cx*t + x(0)
     * y(t) = ay*t^3 + by*t^2 + cy*t + y(0)
     */
    cx = 3.0*(p1.x - p0.x); bx = 3.0*(p2.x - p1.x) - cx; ax = p3.x - p0.x - bx - cx;
    cy = 3.0*(p1.y - p0.y); by = 3.0*(p2.y - p1.y) - cy; ay = p3.y - p0.y - by - cy;

    /* represent the line with the equation
     * g(x) = m*x + x(0)
     */
    dx = pl1.x - pl0.x;
    dy = pl1.y - pl0.y;
    /* line is vertical
     * x(t) = ax*t^3 + bx*t^2 + cx*t + x(0)
     * with x(t) = x of line
     */
    if ( Diff(dx, 0) < TOLERANCE || (Diff(dx, 0) < Diff(dy, 0) && Diff(dx, 0) < 5.0*TOLERANCE) )
    {	n1 = svPolynomial3( ax, bx, cx, p0.x-pl0.x, sol);

        /* used to test, if points are between the endpoints of our line */
        min = Min(pl0.y, pl1.y) - 2.0*TOLERANCE;
        max = Max(pl0.y, pl1.y) + 2.0*TOLERANCE;
    }
    else // if ( Diff(dx, 0) > TOLERANCE )
    {	m  = (pl1.y - pl0.y) / dx;
        x0 = pl0.y - m * pl0.x;

        /* calculate the t values of the intersection
         * ax*t^3 + bx*t^2 + cx*t + dx = x
         * ay*t^3 + by*t^2 + cy*t + dy = m * x + x0
         *
         * (m*ax-ay)*t^3 + (m*bx-by)*t^2 + (m*cx-cy)*t - m*x(0)-y(0) = 0
         */
        n1 = svPolynomial3( m*ax-ay, m*bx-by, m*cx-cy, m*p0.x-p0.y+x0, sol);

        /* used to test, if points are between the endpoints of our line */
        min = Min(pl0.x, pl1.x) - 2.0*TOLERANCE;
        max = Max(pl0.x, pl1.x) + 2.0*TOLERANCE;
    }

    for (n = 0; n < n1; n++)
    {	NSPoint	p, gc, gl;

        if (sol[n] > 1.0)
        {   [self getPoint:&p at:sol[n]];
            if ( Diff(p.x, p3.x) + Diff(p.y, p3.y) > TOLERANCE)
                continue;
        }
        else if (sol[n] < 0.0)
        {   [self getPoint:&p at:sol[n]];
            if ( Diff(p.x, p0.x) + Diff(p.y, p0.y) > TOLERANCE)
                continue;
        }
        /* vertical line */
        if ( Diff(dx, 0) < TOLERANCE || (Diff(dx, 0) < Diff(dy, 0) && Diff(dx, 0) < 5.0*TOLERANCE) )
        {   points->y = ay*sol[n]*sol[n]*sol[n] + by*sol[n]*sol[n] + cy*sol[n] + p0.y;
            if ( points->y >= min && points->y <= max)
            {	points->x = pl0.x;
                points++;
                numSol++;
            }
            else
                continue;
        }
        else //if ( Diff(dx, 0) > TOLERANCE )
        {   points->x = ax*sol[n]*sol[n]*sol[n] + bx*sol[n]*sol[n] + cx*sol[n] + p0.x;
            if ( points->x >= min && points->x <= max)
            {	points->y = m*points->x+x0;
                points++;
                numSol++;
            }
            else
                continue;
        }

        /* special treatment for endpoints, since they should lay exactly on an endpoint
         */
        pp = points-1;
        if (SqrDistPoints(*pp, p0) < TOLERANCE*TOLERANCE)
        {   *pp = p0; continue;}
        else if (SqrDistPoints(*pp, p3) < TOLERANCE*TOLERANCE)
        {   *pp = p3; continue;}
        else if (SqrDistPoints(*pp, pl0) < TOLERANCE*TOLERANCE)
        {   *pp = pl0; continue;}
        else if (SqrDistPoints(*pp, pl1) < TOLERANCE*TOLERANCE)
        {   *pp = pl1; continue;}

        /* tangent (not endpoints!) -> return two intersections in intersection point
         */
        gc = [self gradientAt:sol[n]];
        gl.x = pl1.x - pl0.x; gl.y = pl1.y - pl0.y;
        if ( (gc.x && gl.x && Diff(gc.y/gc.x, gl.y/gl.x) < 0.05) ||
             (gc.y && gl.y && Diff(gc.x/gc.y, gl.x/gl.y) < 0.05) )
        {   int		i, extremaCnt;
            double	extremas[2];

            /* test if point lay in an extrema */
            if ( Diff(dx, 0) < TOLERANCE || (Diff(dx, 0) < Diff(dy, 0) && Diff(dx, 0) < 5.0*TOLERANCE) )
                extremaCnt = svExtrema3(ax, bx, cx, extremas); // vertical line
            else // if ( Diff(dx, 0) > TOLERANCE )
                extremaCnt = svExtrema3(m*ax-ay, m*bx-by, m*cx-cy, extremas);

            for (i=0; i<extremaCnt; i++)
                if ( Diff(sol[n], extremas[i]) < 0.00001 )
                {   points->x = (points-1)->x;
                    points->y = (points-1)->y;
                    points++;
                    numSol++;
                    tangentCnt++;
                    break;
                }
        }
    }

    /* if we have more than 2 points in one point we have to remove these points
     * we also remove tangent points, if we have more than one tangent -> they can't be true
     */
    if ( numSol >= 3 )
    {   int	i, j, k, n;

        for (i=0; i<numSol-1; i++)
        {   n = 1;
            for (j=i+1; j<numSol; j++)
                if ( SqrDistPoints(pArray[i], pArray[j]) < TOLERANCE*TOLERANCE )
                {   n++;
                    if (n>2 || tangentCnt>=2)	/* remove point at j */
                    {	for (k=j; k<numSol-1; k++)
                            pArray[k] = pArray[k+1];
                        numSol--; j--;
                    }
                }
        }
    }

    return(numSol);
}

/* created:   22.06.93
 * modified:  19.03.96
 * purpose:   intersect two curves
 * parameter: pArray
 *            pc0, pc1, pc2, pc3
 * return:    number of intersections (0, 1, 2, 3, 4, 5, 6, 7, 8)
 */
- (int)intersectCurve:(NSPoint*)pArray :(NSPoint)pv0 :(NSPoint)pv1 :(NSPoint)pv2 :(NSPoint)pv3
{   NSPoint	pc1[4], pc2[4];

    pc1[0] = p0;  pc1[1] = p1;  pc1[2] = p2;  pc1[3] = p3;
    pc2[0] = pv0; pc2[1] = pv1; pc2[2] = pv2; pc2[3] = pv3;
    return intersectCurves(pc1, pc2, pArray);
}

/* created:   2001-10-22
 * modified:  2012-04-24 (!n1)
 * purpose:   distance between curve and line
 * parameter: pl0, pl1
 * return:    squar distance
 */
- (float)sqrDistanceLine:(NSPoint)pl0 :(NSPoint)pl1
{   int     i, cnt1 = 0, n1, ix = 0, ixm, ixp;
    NSPoint *pts1, ipt;
    float   length1, distance = MAXCOORD, dist, flatness = 0.01; // 0.002
    double  t, tplus1;
    
    length1 = [self length];

    n1 = length1/flatness;
    if ( !n1 )
        return pointOnLineClosestToPoint(pl0, pl1, p0, &ipt);

    pts1 = NSZoneMalloc([self zone], (n1+1)*sizeof(NSPoint));

    tplus1 = 1.0/(double)n1;

    for (i=0, t=0; i<n1 && t <= 1.0; i++, t+=tplus1)
    {   pts1[i] = [self pointAt:t]; cnt1++; }
    pts1[cnt1++] = p3;

    /* distance between all points - and pointOnLineClosestToPoint() */

    for(i=0; i < cnt1; i++)
    {
        if ( (dist=pointOnLineClosestToPoint(pl0, pl1, pts1[i], &ipt)) < distance )
        {   distance = dist; ix = i; }
    }
    ixm = (ix > 0) ? (ix-1) : (0);
    if ( vhfIntersectLines(&ipt, pts1[ixm], pts1[ix], pl0, pl1))
        return 0.0;
    ixp = (ix < cnt1-1) ? (ix+1) : (cnt1-1);
    if ( vhfIntersectLines(&ipt, pts1[ix], pts1[ixp], pl0, pl1))
        return 0.0;
#if 0
    // we check only if begin/end of both lines near enought of other line
    if ((dist=pointOnLineClosestToPoint(pts1[ixm], pts1[ixp], pl0, &ipt)) < distance) // end of l2 to self
        distance = dist;
    if ((dist=pointOnLineClosestToPoint(pts1[ixm], pts1[ixp], pl1, &ipt)) < distance) // end of l2 to self
        distance = dist;
    if ((dist=pointOnLineClosestToPoint(pl0, pl1, pts1[ixm], &ipt)) < distance) // beg of self to l2
        distance = dist;
    if ((dist=pointOnLineClosestToPoint(pl0, pl1, pts1[ixp], &ipt)) < distance) // end of self to l2
        distance = dist;
#endif

    NSZoneFree([self zone], pts1);
    return (distance < 0.000001) ? (0.0) : (distance);
}
#if 0 // -> Fix me -> is only distance between s/e points !
{   float	distance, dist;
    NSPoint	pc[4], iPoint, pts[10];

    if ([self intersectLine:pts :pl0 :pl1])
        return 0.0;

    pc[0] = p0; pc[1] = p1; pc[2] = p2; pc[3] = p3;
    distance = pointOnLineClosestToPoint(pl0, pl1, p0, &iPoint); // p0 to line
    if ((dist = pointOnLineClosestToPoint(pl0, pl1, p3, &iPoint)) < distance) // p3 to line
        distance = dist;
    if ((dist = pointOnCurveNextToPoint(&iPoint, pc, &pl0)) < distance) // start line to curve
        distance = dist;
    if ((dist = pointOnCurveNextToPoint(&iPoint, pc, &pl1)) < distance) // start line to curve
        distance = dist;
    return distance;
}
#endif

- (float)sqrDistanceLine:(NSPoint)pl0 :(NSPoint)pl1 :(NSPoint*)pg1 :(NSPoint*)pg2
{   int     i, cnt1 = 0, n1, ix = 0, ixm, ixp;
    NSPoint *pts1, ipt;
    float   length1, distance = MAXCOORD, dist, flatness = 0.01; // 0.002
    double  t, tplus1;
    
    length1 = [self length];

    n1 = length1/flatness;
    if ( !n1 )
        return pointOnLineClosestToPoint(pl0, pl1, p0, &ipt);

    pts1 = NSZoneMalloc([self zone], (n1+1)*sizeof(NSPoint));

    tplus1 = 1.0/(double)n1;

    for (i=0, t=0; i<n1 && t <= 1.0; i++, t+=tplus1)
    {   pts1[i] = [self pointAt:t]; cnt1++; }
    pts1[cnt1++] = p3;

    /* distance between all points - and pointOnLineClosestToPoint() */

    for(i=0; i < cnt1; i++)
    {
        if ( (dist=pointOnLineClosestToPoint(pl0, pl1, pts1[i], &ipt)) < distance )
        {   distance = dist; ix = i;
            *pg1 = pts1[i]; *pg2 = ipt;
        }
    }
    ixm = (ix > 0) ? (ix-1) : (0);
    if ( vhfIntersectLines(&ipt, pts1[ixm], pts1[ix], pl0, pl1))
    {   *pg1 = *pg2 = ipt;
        return 0.0;
    }
    ixp = (ix < cnt1-1) ? (ix+1) : (cnt1-1);
    if ( vhfIntersectLines(&ipt, pts1[ix], pts1[ixp], pl0, pl1))
    {   *pg1 = *pg2 = ipt;
        return 0.0;
    }
#if 0
    // we check only if begin/end of both lines near enought of other line
    if ((dist=pointOnLineClosestToPoint(pts1[ixm], pts1[ixp], pl0, &ipt)) < distance) // end of l2 to self
    {   *pg1 = ipt; *pg2 = pl0;
        distance = dist;
    }
    if ((dist=pointOnLineClosestToPoint(pts1[ixm], pts1[ixp], pl1, &ipt)) < distance) // end of l2 to self
    {   *pg1 = ipt; *pg2 = pl1;
        distance = dist;
    }
    if ((dist=pointOnLineClosestToPoint(pl0, pl1, pts1[ixm], &ipt)) < distance) // beg of self to l2
    {   *pg1 = ipt; *pg2 = pts1[ixm];
        distance = dist;
    }
    if ((dist=pointOnLineClosestToPoint(pl0, pl1, pts1[ixp], &ipt)) < distance) // end of self to l2
    {   *pg1 = ipt; *pg2 = pts1[ixp];
        distance = dist;
    }
#endif

    NSZoneFree([self zone], pts1);
    return (distance < 0.000001) ? (0.0) : (distance);
}

/* modified: 2011-07-11
 */
- (float)sqrDistanceCurve:(NSPoint*)pc1
{   int     i, j, cnt0 = 0, cnt1 = 0, n0, n1, ix0 = 0, ix1 = 0, ix0m, ix0p, ix1m, ix1p;
    NSPoint *pts0, *pts1, ipt;
    float   length0 = [self length], length1, distance = MAXCOORD, dist, flatness = 0.1; // 0.002
    double  t, tplus0, tplus1;
    VCurve  *crv1 = [VCurve curve];
    
    [crv1 setVertices:pc1[0] :pc1[1] :pc1[2] :pc1[3]];
    length1 = [crv1 length];

    n0 = length0/flatness;
    n1 = length1/flatness;
    
    pts0 = NSZoneMalloc([self zone], (n0+1)*sizeof(NSPoint));
    pts1 = NSZoneMalloc([self zone], (n1+1)*sizeof(NSPoint));

    tplus0 = 1.0/(double)n0;
    tplus1 = 1.0/(double)n1;
    
    /* distance between all points - smallest is our */
    for (i=0, t=0; i<n0 && t <= 1.0; i++, t+=tplus0)
    {   pts0[i] = [self pointAt:t]; cnt0++; }
    pts0[cnt0++] = p3;

    for (i=0, t=0; i<n1 && t <= 1.0; i++, t+=tplus1)
    {   pts1[i] = [crv1 pointAt:t]; cnt1++; }
    pts1[cnt1++] = pc1[3];

    for(i=0; i < cnt0; i++)
    {
        for(j=0; j < cnt1; j++)
        {
            if ( (dist=SqrDistPoints(pts0[i], pts1[j])) < distance )
            {   distance = dist; ix0 = i; ix1 = j; } // *pg1 = pts0[i]; *pg2 = pts1[j];
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
    NSZoneFree([self zone], pts1);
    return (distance < 0.000001) ? (0.0) : (distance);
}
#if 0
/* FIXME: es werden nur die start/end punkte der curves zur anderen gescheckt
 * modified: 2008-02-25 (compare (&iPoint, pc, &pc1[0/3]) not pc[0/3])
 */
{   float	distance, dist;
    NSPoint	pc[4], iPoint;

    pc[0] = p0; pc[1] = p1; pc[2] = p2; pc[3] = p3;
    distance = pointOnCurveNextToPoint(&iPoint, pc1, &p0); // p0 to line
    if ((dist = pointOnCurveNextToPoint(&iPoint, pc1, &p3)) < distance) // p3 to line
        distance = dist;
    if ((dist = pointOnCurveNextToPoint(&iPoint, pc, &pc1[0])) < distance) // start line to curve
        distance = dist;
    if ((dist = pointOnCurveNextToPoint(&iPoint, pc, &pc1[3])) < distance) // start line to curve
        distance = dist;
    return distance;
}
#endif

- (float)sqrDistanceCurve:(NSPoint*)pc1 :(NSPoint*)pg1 :(NSPoint*)pg2
{   int     i, j, cnt0 = 0, cnt1 = 0, n0, n1, ix0 = 0, ix1 = 0, ix0m, ix0p, ix1m, ix1p;
    NSPoint *pts0, *pts1, ipt;
    float   length0 = [self length], length1, distance = MAXCOORD, dist, flatness = 0.1; // 0.002
    double  t, tplus0, tplus1;
    VCurve  *crv1 = [VCurve curve];
    
    [crv1 setVertices:pc1[0] :pc1[1] :pc1[2] :pc1[3]];
    length1 = [crv1 length];

    n0 = length0/flatness;
    n1 = length1/flatness;
    
    pts0 = NSZoneMalloc([self zone], (n0+1)*sizeof(NSPoint));
    pts1 = NSZoneMalloc([self zone], (n1+1)*sizeof(NSPoint));

    tplus0 = 1.0/(double)n0;
    tplus1 = 1.0/(double)n1;
    
    /* distance between all points - smallest is our */
    for (i=0, t=0; i<n0 && t <= 1.0; i++, t+=tplus0)
    {   pts0[i] = [self pointAt:t]; cnt0++; }
    pts0[cnt0++] = p3;

    for (i=0, t=0; i<n1 && t <= 1.0; i++, t+=tplus1)
    {   pts1[i] = [crv1 pointAt:t]; cnt1++; }
    pts1[cnt1++] = pc1[3];

    for(i=0; i < cnt0; i++)
    {
        for(j=0; j < cnt1; j++)
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
    NSZoneFree([self zone], pts1);
    return (distance < 0.000001) ? (0.0) : (distance);
}
#if 0
{   float	distance, dist;
    NSPoint	pc[4], iPoint;

    pc[0] = p0; pc[1] = p1; pc[2] = p2; pc[3] = p3;
    distance = pointOnCurveNextToPoint(&iPoint, pc1, &p0); // p0 to line
    *pg2 = iPoint; *pg1 = p0;
    if ((dist = pointOnCurveNextToPoint(&iPoint, pc1, &p3)) < distance) // p3 to line
    {   *pg2 = iPoint; *pg1 = p3;
        distance = dist;
    }
    if ((dist = pointOnCurveNextToPoint(&iPoint, pc, &pc1[0])) < distance) // start line to curve
    {   *pg2 = iPoint; *pg1 = pc1[0];
        distance = dist;
    }
    if ((dist = pointOnCurveNextToPoint(&iPoint, pc, &pc1[3])) < distance) // start line to curve
    {   *pg2 = iPoint; *pg1 = pc1[3];
        distance = dist;
    }
    return distance;
}
#endif

/* created:   1993-07-08
 * modified:  2002-07-17
 * purpose:   return t values for a point on the curve
 *            the returned values are allready sorted (smallest first)
 *            the t value can lay outside the curve bounds!!
 *            we don't expect loops in the curve! -> only one t value
 * parameter: t (returned)
 *            point
 *            curve
 * return:    number of t values
 */
- (double)getTForPointOnCurve:(NSPoint)point
{   double	sol[3], t = -1.0;
    int		i, cnt;
    double	dist, lastDist;
    NSRect	bounds = [self fastBounds];

#if 0
    /* curve is a vertical line
     */
    if (Diff(p1.x, p0.x) < 2*TOLERANCE && Diff(p1.x, p2.x) < 2*TOLERANCE && Diff(p2.x, p3.x) < 2*TOLERANCE)
    {	double	dx, dy, d, l;

        /* it's a line - we can't calculate t with tangents
         * we do it in a simpler way
         * d/l = t d-distance(p0, point) l-distance(p0, p3)
         */
        dx = p0.x - point.x; dy = p0.y - point.y;
        d = dx*dx + dy*dy;
        dx = p0.x - p3.x; dy = p0.y - p3.y;
        l = dx*dx + dy*dy;
        t = sqrt(d/l);
        return t;
    }
#endif

    /* represent the curve with the equations
     * calculate a, b, c
     * x(t) = ax*t^3 + bx*t^2 + cx*t + x(0)
     *
     * x1 = x0 + cx/3
     * x2 = x1 + (cx + bx)/3
     * x3 = x0 + cx + bx + ax
     */

    /* curve is more vertical */
    if (bounds.size.height > bounds.size.width)
    {   double	ay, by, cy;

        /* t: t^3 * ay + t^2 * by + t * cy + y0 = y1 */
        cy = 3.0*(p1.y - p0.y);
        by = 3.0*(p2.y - p1.y) - cy;
        ay = p3.y - p0.y - by - cy;
        if (!(cnt = svPolynomial3(ay, by, cy, p0.y-point.y, sol)))
        {   NSLog(@"VCurve, cannot calculate t value for point on curve!");
            return -1.0;
        }
    }
    /* curve is more horicontal */
    else
    {   double	ax, bx, cx;

        /* t: t^3 * ax + t^2 * bx + t * cx + x0 = x1 */
        cx = 3.0*(p1.x - p0.x);
        bx = 3.0*(p2.x - p1.x) - cx;
        ax = p3.x - p0.x - bx - cx;
        if (!(cnt = svPolynomial3(ax, bx, cx, p0.x-point.x, sol)))
        {   NSLog(@"VCurve, cannot calculate t value for point on curve!");
            return -1.0;
        }
    }

    /* test values
     * we test very tolerant because the intersection of curves may need it in extreme situations
     * the intersection of curves also needs values below 0 and over 1
     */
    lastDist = 0.0;
    for (i=0, t=-1.0; i<cnt; i++)
    {	NSPoint	p;

        if (sol[i] >= -0.1 && sol[i] <= 1.1)
        {   p = [self pointAt:sol[i]];
            if ( ((dist=SqrDistPoints(p, point)) < lastDist) || t==-1 )
            {	t = sol[i];
                lastDist = dist;
            }
        }
    }
    if ( t == -1.0 )
        NSLog(@"VCurve, cannot calculate t value for point on curve!");
    return t;
}

/* subclassed from graphic
 */
/*
 * builds the UPath
 */
- (void)buildUPath
{
    path.pts[4] = p0.x;
    path.pts[5] = p0.y;
    path.pts[6] = p1.x;
    path.pts[7] = p1.y;
    path.pts[8] = p2.x;
    path.pts[9] = p2.y;
    path.pts[10] = p3.x;
    path.pts[11] = p3.y;

    [self updateBounds];
}

- (NSPoint)appendToBezierPath:(NSBezierPath*)bPath currentPoint:(NSPoint)currentPoint
{
    if (Diff(currentPoint.x, p0.x) > 0.01 || Diff(currentPoint.y, p0.y) > 0.01)
        [bPath moveToPoint:p0];
    [bPath curveToPoint:p3 controlPoint1:p1 controlPoint2:p2];
    return p3;
}

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
 * parameter: x, y  the angles to rotate in x/y direction (2D)
 *            p     the point we have to rotate around (3D)
 * purpose:   draw the graphic rotated around p with x and y
 */
- (void)drawAtAngle:(float)angle withCenter:(NSPoint)cp in:view
{   NSPoint		p[4];
    NSBezierPath	*bPath = [NSBezierPath bezierPath];

    p[0] = vhfPointRotatedAroundCenter(p0, -angle, cp);
    p[1] = vhfPointRotatedAroundCenter(p1, -angle, cp);
    p[2] = vhfPointRotatedAroundCenter(p2, -angle, cp);
    p[3] = vhfPointRotatedAroundCenter(p3, -angle, cp);

    [color set];
    [bPath setLineWidth:1.0/[view scaleFactor]];
    [bPath moveToPoint:p[0]];
    [bPath curveToPoint:p[3] controlPoint1:p[1] controlPoint2:p[2]];
    [bPath stroke];
}

/* created:   21.10.95
 * modified:  
 * parameter: x, y	the angles to rotate in x/y direction
 *            cp	the point we have to rotate around
 * purpose:   rotate the graphic around cp with x and y
 */
- (void)setAngle:(float)angle withCenter:(NSPoint)cp
{
    vhfRotatePointAroundCenter(&p0, cp, -angle);
    vhfRotatePointAroundCenter(&p1, cp, -angle);
    vhfRotatePointAroundCenter(&p2, cp, -angle);
    vhfRotatePointAroundCenter(&p3, cp, -angle);
    [self buildUPath];
    coordBounds = NSZeroRect;
    dirty = YES;
}

- (void)transform:(NSAffineTransform*)matrix
{   NSSize  size = NSMakeSize(width, width);

    size = [matrix transformSize:size];
    width = (Abs(size.width) + Abs(size.height)) / 2;
    p0 = [matrix transformPoint:p0];
    p1 = [matrix transformPoint:p1];
    p2 = [matrix transformPoint:p2];
    p3 = [matrix transformPoint:p3];
    [self buildUPath];
    coordBounds = NSZeroRect;
    dirty = YES;
}

- (void)scale:(float)x :(float)y withCenter:(NSPoint)cp
{
    width *= (x+y)/2.0;
    p0.x = ScaleValue(p0.x, cp.x, x); p0.y = ScaleValue(p0.y, cp.y, y);
    p1.x = ScaleValue(p1.x, cp.x, x); p1.y = ScaleValue(p1.y, cp.y, y);
    p2.x = ScaleValue(p2.x, cp.x, x); p2.y = ScaleValue(p2.y, cp.y, y);
    p3.x = ScaleValue(p3.x, cp.x, x); p3.y = ScaleValue(p3.y, cp.y, y);
    [self buildUPath];
    coordBounds = NSZeroRect;
    dirty = YES;
}

- (void)mirrorAround:(NSPoint)p
{
    p0.y = p.y - (p0.y - p.y);
    p1.y = p.y - (p1.y - p.y);
    p2.y = p.y - (p2.y - p.y);
    p3.y = p.y - (p3.y - p.y);
    [self buildUPath];
    coordBounds = NSZeroRect;
    dirty = YES;
}

/*
 * draws the curve
 */
- (void)drawWithPrincipal:principal
{   NSBezierPath	*bPath = [NSBezierPath bezierPath];
    NSColor		*oldColor = nil;

    /* colorSeparation */
    if (!VHFIsDrawingToScreen() && [principal separationColor])
    {   NSColor	*sepColor = [self separationColor:color]; // get individual separation color

        oldColor = [color retain];
        [self setColor:sepColor];
    }

    [super drawWithPrincipal:principal];

    [bPath setLineWidth:width];
    [bPath setLineCapStyle:NSRoundLineCapStyle];
    [bPath setLineJoinStyle:NSRoundLineJoinStyle];
    [bPath moveToPoint:p0];
    [bPath curveToPoint:p3 controlPoint1:p1 controlPoint2:p2];
    [bPath stroke];

    if ([principal showDirection])
        [self drawDirectionAtScale:[principal scaleFactor]];

    if (!VHFIsDrawingToScreen() && [principal separationColor])
    {   [self setColor:oldColor];
        [oldColor release];
    }
}

/*
 * tell curve to update its bounds
 */
- (void)updateBounds
{   int	i;

    LLX(path.pts) = LLY(path.pts) = LARGE_COORD;
    URX(path.pts) = URY(path.pts) = LARGENEG_COORD;
    for (i = 0; i < PTS_BEZIER * 2; i += 2)
    {
        LLX(path.pts) = MIN(LLX(path.pts), path.pts[i + 4]);
        LLY(path.pts) = MIN(LLY(path.pts), path.pts[i + 5]);
        URX(path.pts) = MAX(URX(path.pts), path.pts[i + 4]);
        URY(path.pts) = MAX(URY(path.pts), path.pts[i + 5]);
    }
}

- (NSRect)coordBounds
{
    if (coordBounds.size.width == 0.0 && coordBounds.size.height == 0.0)
    {   NSPoint	pc[4];

        pc[0] = p0; pc[1] = p1; pc[2] = p2; pc[3] = p3;
        coordBounds = boundsOfCurve( pc );
    }
    return coordBounds;
}

- (NSRect)bounds
{   NSPoint	ll, ur;
    NSRect	bRect = [self coordBounds];

    ll = bRect.origin;
    ur.x = bRect.origin.x + bRect.size.width;
    ur.y = bRect.origin.y + bRect.size.height;
    ll.x = Min(ll.x, p1.x); ll.y = Min(ll.y, p1.y);
    ur.x = Max(ur.x, p1.x); ur.y = Max(ur.y, p1.y);
    ll.x = Min(ll.x, p2.x); ll.y = Min(ll.y, p2.y);
    ur.x = Max(ur.x, p2.x); ur.y = Max(ur.y, p2.y);

    ll.x -= width/2.0;
    ll.y -= width/2.0;
    ur.x += width/2.0;
    ur.y += width/2.0;

    bRect.origin = ll;
    bRect.size.width  = MAX(ur.x - ll.x, 0.001);
    bRect.size.height = MAX(ur.y - ll.y, 0.001);

    return bRect;
}

/*
 * Returns the fast bounds.
 * we only take the bounds of the vertices
 * never becomes zero!
 */
- (NSRect)fastBounds
{   NSRect	bRect;

    bRect.origin.x = LLX(path.pts) - width/2.0;
    bRect.origin.y = LLY(path.pts) - width/2.0;
    bRect.size.width  = MAX(URX(path.pts) - LLX(path.pts), 0.001) + width/2.0;
    bRect.size.height = MAX(URY(path.pts) - LLY(path.pts), 0.001) + width/2.0;
    return bRect;
}

/*
 * Returns the bounds with the given rotation.
 */
- (NSRect)boundsAtAngle:(float)angle withCenter:(NSPoint)cp
{   NSPoint	p;
    float	x0, y0, x1, y1, x2, y2, x3, y3;
    NSRect	bRect;

    p = p0;
    vhfRotatePointAroundCenter(&p, cp, -angle);
    x0 = p.x; y0 = p.y;

    p = p1;
    vhfRotatePointAroundCenter(&p, cp, -angle);
    x1 = p.x; y1 = p.y;

    p = p2;
    vhfRotatePointAroundCenter(&p, cp, -angle);
    x2 = p.x; y2 = p.y;

    p = p3;
    vhfRotatePointAroundCenter(&p, cp, -angle);
    x3 = p.x; y3 = p.y;

    bRect.origin.x = Min(Min(Min(x0, x1), x2), x3);
    bRect.origin.y = Min(Min(Min(y0, y1), y2), y3);
    bRect.size.width  = Max(Max(Max(Max(x0, x1), x2), x3) - bRect.origin.x, 1.0);
    bRect.size.height = Max(Max(Max(Max(y0, y1), y2), y3) - bRect.origin.y, 1.0);
    return bRect;
}

- (void)drawControls:(NSRect)rect direct:(BOOL)direct scaleFactor:(float)scaleFactor
{
    if ( (NSIsEmptyRect(rect) ||
          !NSIsEmptyRect(NSIntersectionRect(rect, [self extendedBoundsWithScale:scaleFactor]))) )
    {
	if ( VHFIsDrawingToScreen() && isSelected )
        {
            //[super drawKnobs:rect direct:direct scaleFactor:scaleFactor];
            [super drawControls:rect direct:direct scaleFactor:scaleFactor];    // 2008-02-07
            [NSBezierPath setDefaultLineWidth:1.0/scaleFactor];
            [NSBezierPath strokeLineFromPoint:p0 toPoint:p1];
            [NSBezierPath strokeLineFromPoint:p3 toPoint:p2];
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
{   float	knobsize;
    NSRect	aRect;

    if (pt_num == -1)
        aRect = [self bounds];
    else
    {
        aRect.origin.x = path.pts[pt_num*2 + 4];
        aRect.origin.y = path.pts[pt_num*2 + 5];
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
    //	NXPoint	*thisPt, *nextPt;
    NSRect	viewRect;
    float	margin = MARGIN / [aView scaleFactor];

    viewRect = [aView bounds];
    viewMax.x = viewRect.origin.x + viewRect.size.width;
    viewMax.y = viewRect.origin.y + viewRect.size.height;

/*    if (pt_num == 0 || pt_num == 3)
    {
        thisPt = (NSPoint *) &path.pts[pt_num*2 + 4];
        if (pt_num == 0)
            nextPt = (NSPoint*)&path.pts[6];
        else
            nextPt = (NSPoint*)&path.pts[8];

        if (thisPt->x  >  nextPt->x)
            viewRect.origin.x += thisPt->x  -  nextPt->x;
        else
            viewMax.x -= nextPt->x  -  thisPt->x;

        if (thisPt->y  >  nextPt->y)
            viewRect.origin.y += thisPt->y - nextPt->y;
        else
            viewMax.y -= nextPt->y - thisPt->y;
    }*/

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
{   int		i;
    NSPoint	*pc;

    path.pts[pt_num *2 + 4] += pt.x;
    path.pts[pt_num *2 + 5] += pt.y;

    LLX(path.pts) = LLY(path.pts) = 9999.0;
    URX(path.pts) = URY(path.pts) = -9999.0;
    for (i = 0; i < PTS_BEZIER * 2; i += 2)
    {
        LLX(path.pts) = MIN(LLX(path.pts), path.pts[i + 4]);
        LLY(path.pts) = MIN(LLY(path.pts), path.pts[i + 5]);
        URX(path.pts) = MAX(URX(path.pts), path.pts[i + 4]);
        URY(path.pts) = MAX(URY(path.pts), path.pts[i + 5]);
    }

    /* set point */
    switch (pt_num)
    {
        case 0:  pc = &p0; break;
        case 1:  pc = &p1; break;
        case 2:	 pc = &p2; break;
        default: pc = &p3;
    }

    pc->x += pt.x;
    pc->y += pt.y;

    [self buildUPath];
    coordBounds = NSZeroRect;
    dirty = YES;
}

/*
 * created:   25.09.95
 * modified:  
 * parameter: pt_num	number of vertices
 *            p		the new position in 3D
 * purpose:   Sets a vertice to a new position.
 *            If it is a edge move the vertices with it
 */
- (void)movePoint:(int)pt_num to:(NSPoint)p
{   NSPoint	pc;

    /* set point */
    switch (pt_num)
    {
	case 0:	 pc = p0; break;
        case 1:  pc = p1; break;
        case 2:  pc = p2; break;
        default: pc = p3;
                 pt_num = 3;
    }

    pc.x = p.x - pc.x;
    pc.y = p.y - pc.y;
    [self movePoint:pt_num by:pc];
}

/*
 * pt_num is the changing control point. pt holds the relative change in each coordinate. 
 * The relative is needed and not the absolute because the closest inside control point
 * changes when one of the outside points change.
 */
- (void)movePoint:(int)pt_num by:(NSPoint)pt
{
    [self changePoint:pt_num :pt];

    if (pt_num == 0)
        [self changePoint:1 :pt];
    else if (pt_num == 3)
        [self changePoint:2 :pt];
}

/* The pt argument holds the relative point change. */
- (void)moveBy:(NSPoint)pt
{   int	i;

    for (i = 0; i < PTS_BEZIER;  i++)
        [self changePoint:i :pt];
}

- (int)numPoints
{
    return PTS_BEZIER;
}
/* Given the point number, return the point.
 * default must be p3
 */
- (NSPoint)pointWithNum:(int)pt_num
{
    switch (pt_num)
    {
	case 0:	 return p0;
        case 1:  return p1;
        case 2:  return p2;
        default: return p3;
    }
}

/*
 * Check for a edge point hit.
 * parameter: p	the mouse position
 *            fuzz		the distance inside we snap to a point
 *            pt		the edge point
 *            controlsize	the size of the controls
 *            cubic		if we have to check (and return the point)
 */
- (BOOL)hitEdge:(NSPoint)p fuzz:(float)fuzz :(NSPoint*)pt :(float)controlsize
{   NSRect	knobRect, hitRect;

    hitRect.origin.x = p.x -fuzz/2.0;
    hitRect.origin.y = p.y -fuzz/2.0;
    hitRect.size.width = hitRect.size.height = fuzz;
    knobRect.size.width = knobRect.size.height = controlsize;

    //	if (!cubic)
    {	knobRect.origin.x = path.pts[4] - controlsize/2.0;
        knobRect.origin.y = path.pts[5] - controlsize/2.0;
        if (selectedKnob != 0 && selectedKnob != 1 && !NSIsEmptyRect(NSIntersectionRect(hitRect , knobRect)))
        {   *pt = p0;
            return YES;
        }
        knobRect.origin.x = path.pts[6] - controlsize/2.0;
        knobRect.origin.y = path.pts[7] - controlsize/2.0;
        if (selectedKnob != 1 && selectedKnob != 0 && !NSIsEmptyRect(NSIntersectionRect(hitRect , knobRect)))
        {   *pt = p1;
            return YES;
        }
        knobRect.origin.x = path.pts[8] - controlsize/2.0;
        knobRect.origin.y = path.pts[9] - controlsize/2.0;
        if (selectedKnob != 2 && selectedKnob != 3 && !NSIsEmptyRect(NSIntersectionRect(hitRect , knobRect)))
        {   *pt = p2;
            return YES;
        }
        knobRect.origin.x = path.pts[10] - controlsize/2.0;
        knobRect.origin.y = path.pts[11] - controlsize/2.0;
        if (selectedKnob != 3 && selectedKnob != 2 && !NSIsEmptyRect(NSIntersectionRect(hitRect , knobRect)))
        {   *pt = p3;
            return YES;
        }
    }

    return NO;
}

/*
 * Check for a control point hit.
 * Return the point number hit in the pt_num argument.
 * modified: 2005-09-03
 */
- (BOOL)hitControl:(NSPoint)p :(int *)pt_num controlSize:(float)controlsize
{   int		i;
    NSRect	knobRect;
    float	lastDist = LARGE_COORD, dist;
    BOOL	hit = NO;
    BOOL	control = [(App*)NSApp control];

    *pt_num = 0; // if p0==p1 or p3==p2 we take p0 or p3 !
    knobRect.size.width = knobRect.size.height = controlsize;
    for (i=0; i < PTS_BEZIER*2; i += 2)
    {
        knobRect.origin.x = path.pts[i + 4] - controlsize/2.0;
        knobRect.origin.y = path.pts[i + 5] - controlsize/2.0;
        if ( NSPointInRect(p, knobRect) )
        {
            dist = SqrDistPoints(NSMakePoint(path.pts[i+4], path.pts[i+5]), p);
            /* take the control point if control and both nearly identical */
            if ( (!control && ((dist < lastDist && !(*pt_num)) ||
                               ((dist <= lastDist || Diff(dist, lastDist) <= 5) && *pt_num))) ||
                 (control && (((dist <= lastDist || Diff(dist, lastDist) <= 5) && !(*pt_num)) ||
                              (dist < lastDist && Diff(dist, lastDist) > 5 && *pt_num))) )
            {
                lastDist = dist;
                *pt_num = i/2;
                selectedKnob = *pt_num;
                hit = YES;
                [self setSelected:YES];
            }
        }
    }
    return hit;
}

#define  NUM_POINTS_HIT		12
#define  NUM_OPS_HIT		6

- (BOOL)hit:(NSPoint)p fuzz:(float)fuzz
{   NSRect	bRect = [self bounds];

    bRect.origin.x -= fuzz;
    bRect.origin.y -= fuzz;
    bRect.size.width  += 2.0 * fuzz;
    bRect.size.height += 2.0 * fuzz;
    if ( NSPointInRect(p, bRect) )
    {   NSPoint	pts[10], ps[4], pc;
        VArc	*arc = [VArc arc];

        pc = p; pc.x += fuzz;
        [arc setCenter:p start:pc angle:360.0];
        ps[0] = p0; ps[1] = p1; ps[2] = p2; ps[3] = p3;
        if ([arc intersectCurve:pts :ps])
            return YES;
    }
    return NO;
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
{   VPath           *pathG;
    NSMutableArray  *list;
    VArc            *arc;
    VCurve          *curve;
    float           t, r, dx, dy, c;
    NSPoint         p, d0, d3, pas[4], pbs[4];	/* the points on curves a and b */
    int             i;
    float           ax, bx, cx, ay, by, cy;
    BOOL            alternative = YES;

    if ( (w == 0.0 && width == 0.0) || (w<0.0 && -w >= width) )
    {	curve = [VCurve curve];
        //[curve setWidth:Abs(w)];
        [curve setColor:color];
        [curve setVertices:p0 :p1 :p2 :p3];
        [curve setSelected:[self isSelected]];
        return curve;
    }

#if 0
    NSRect		bRect;
    float		dx1, dx2, dx3, dy1, dy2, dy3;

    dx1 = p1.x-p0.x; dx2 = p2.x-p0.x; dx3 = p3.x-p0.x;
    dy1 = p1.y-p0.y; dy2 = p2.y-p0.y; dy3 = p3.y-p0.y;
    NSLog(@"%f", dx1*dx2/(dy1*dy2));

    bRect = [self bounds];
    if ( bRect.origin.x<Min(p0.x, p3.x) || bRect.origin.x+bRect.size.width>Max(p0.x, p3.x)
        || (bRect.origin.y<Min(p0.y, p3.y) && bRect.origin.y+bRect.size.height>Max(p0.y, p3.y)) )
        alternative = YES;
#endif

    pathG = [VPath path];
    list = [NSMutableArray array];

    r = (width + w) / 2.0;	/* the amount of growth */
    if (r < 0.0) r = 0.0;

    //	[pathG setWidth:Abs(w)];
    [pathG setColor:color];
    //	[pathG setFilled:YES];

    /* represent the curve with the equations
     * calculate a, b, c
     * x(t) = ax*t^3 + bx*t^2 + cx*t + x(0)
     * y(t) = ay*t^3 + by*t^2 + cy*t + y(0)
     */
    cx = 3.0*(p1.x - p0.x);		 cy = 3.0*(p1.y - p0.y);
    bx = 3.0*(p2.x - p1.x) - cx; by = 3.0*(p2.y - p1.y) - cy;
    ax = p3.x - p0.x - bx - cx;	 ay = p3.y - p0.y - by - cy;

    /* p0 */
    t = 0.0;
    /* dy = 3*ax*t^2 + 2*bx*t + cx
     * dx = 3*ay*t^2 + 2*by*t + cx
     */
    dx = 3.0*ax*t*t + 2.0*bx*t + cx;
    dy = 3.0*ay*t*t + 2.0*by*t + cy;
    if (!dx && !dy)
    {	t = 0.01;
        dx = 3.0*ax*t*t + 2.0*bx*t + cx;
        dy = 3.0*ay*t*t + 2.0*by*t + cy;
    }
    if (!dx && !dy)
        NSLog(@"VCurve, -contour:p0, dx == dy == 0!");
    d0.x = dx; d0.y = dy;
    c = sqrt((dx * dx + dy *dy));
    pas[0].x = p0.x + dy*r/c; pas[0].y = p0.y - dx*r/c;
    pbs[0].x = p0.x - dy*r/c; pbs[0].y = p0.y + dx*r/c;

    if ( alternative )
    {
        /* p1 */
        t = 1.0/3.0;
        [self getPoint:&p at:t];
        dx = (3.0*ax*t*t + 2.0*bx*t + cx);
        dy = (3.0*ay*t*t + 2.0*by*t + cy);
        if (!dx && !dy)
            NSLog(@"VCurve, -contour:p1, dx == dy == 0!");
        c = sqrt((dx * dx + dy *dy));
        pas[1].x = p.x + dy*r/c; pas[1].y = p.y - dx*r/c;
        pbs[1].x = p.x - dy*r/c; pbs[1].y = p.y + dx*r/c;

        /* p2 */
        t = 2.0/3.0;
        [self getPoint:&p at:t];
        dx = (3.0*ax*t*t + 2.0*bx*t + cx);
        dy = (3.0*ay*t*t + 2.0*by*t + cy);
        if (!dx && !dy)
            NSLog(@"VCurve, -contour:p2, dx == dy == 0!");
        c = sqrt((dx * dx + dy *dy));
        pas[2].x = p.x + dy*r/c; pas[2].y = p.y - dx*r/c;
        pbs[2].x = p.x - dy*r/c; pbs[2].y = p.y + dx*r/c;
    }

    /* p3 */
    t = 1.0;
    dx = 3.0*ax*t*t + 2.0*bx*t + cx;
    dy = 3.0*ay*t*t + 2.0*by*t + cy;
    if (!dx && !dy)
    {	t = 0.99;
        dx = 3.0*ax*t*t + 2.0*bx*t + cx;
        dy = 3.0*ay*t*t + 2.0*by*t + cy;
    }
    if (!dx && !dy)
        NSLog(@"VCurve, -contour:p3, dx == dy == 0!");
    d3.x = dx; d3.y = dy;
    c = sqrt((dx * dx + dy *dy));
    pas[3].x = p3.x + dy*r/c; pas[3].y = p3.y - dx*r/c;
    pbs[3].x = p3.x - dy*r/c; pbs[3].y = p3.y + dx*r/c;

    /* 0=arc, 1=curve, 2=arc, 3=curve ! */
    arc = [VArc arc];
    [arc setCenter:p0 start:pbs[0] angle:180.0];
    [list addObject:arc];
    curve = [VCurve curve];
    if ( alternative )
    	[curve calcVerticesFromPoints:pas[0] :pas[1] :pas[2] :pas[3]];	/* 4 points */
    else
        [curve calcVerticesFromPointsAndParallelCurve:pas[0] :pas[3] :self];
    [list addObject:curve];
    arc = [VArc arc];
    [arc setCenter:p3 start:pas[3] angle:180.0];
    [list addObject:arc];
    curve = [VCurve curve];
    if ( alternative )
    	[curve calcVerticesFromPoints:pbs[0] :pbs[1] :pbs[2] :pbs[3]];	/* 4 points */
    else
        [curve calcVerticesFromPointsAndParallelCurve:pbs[0] :pbs[3] :self];
    [curve changeDirection];
    [list addObject:curve];

    for (i=[list count]-1; i>=0; i--)
    {	VGraphic    *g = [list objectAtIndex:i];

        [g setWidth:0.0];
        [g setColor:color];
    }

    [pathG addList:list at:[[pathG list] count]];
    [pathG setSelected:[self isSelected]];

    return pathG;
}

/* modified: 2000-11-05
 */
- flattenedObjectWithFlatness:(float)flatness
{   NSPoint		*apPointList[3], *pPointRead, *pPointWrite, curvePoint;
    double		aLength[3], ax, ay, bx, by, cx, cy, t, dist, maxdist;
    int			i, i2, n = 1;
    VPath		*pathG;
    VLine		*line;
    NSMutableArray	*plist;
    NSPoint		pv0, pv1;

    if (flatness < 0.02)
        flatness = 0.02;
    if (flatness > 10000.0)
        flatness = 10000.0;

    apPointList[0] = malloc((ldexp(3, 9)+1) * sizeof(NSPoint));
    apPointList[1] = malloc((ldexp(3, 9)+1) * sizeof(NSPoint));
    apPointList[2] = 0;

    * apPointList[0]    = p0;
    *(apPointList[0]+1) = p1;
    *(apPointList[0]+2) = p2;
    *(apPointList[0]+3) = p3;

    /* split curve in two curves until the wanted resolution has been achieved
     */
    do
    {	maxdist = dist = 0;

        if ( n >= 9 && !(apPointList[1] = realloc(apPointList[1], (ldexp(3,n)+1) * sizeof(NSPoint))) )
        {   free(apPointList[0]);
            return nil;
        }

        pPointRead  = apPointList[0];
        pPointWrite = apPointList[1];
        *pPointWrite = *pPointRead;

        /* scan curves in pPointRead
         */
        for ( i2 = ldexp(1,n-1); i2 > 0; i2--)
        {
            *(pPointWrite+6) = *(pPointRead+3);
            LineMiddlePoint( * pPointRead,    *(pPointRead+1), *(pPointWrite+1));
            LineMiddlePoint( *(pPointRead+1), *(pPointRead+2), *(pPointWrite+3));
            LineMiddlePoint( *(pPointRead+2), *(pPointRead+3), *(pPointWrite+5));
            LineMiddlePoint( *(pPointWrite+1), *(pPointWrite+3), *(pPointWrite+2));
            LineMiddlePoint( *(pPointWrite+3), *(pPointWrite+5), *(pPointWrite+4));
            LineMiddlePoint( *(pPointWrite+2), *(pPointWrite+4), *(pPointWrite+3));

            /* calculate the maximum deviation
             */
            for ( i = 1; i <= 2; i++, pPointWrite += 3)
            {
                /* calculation of the curve with the functions
                 * x(t) = ax*t^3 + bx*t^2 + cx*t + x0
                 * y(t) = ay*t^3 + by*t^2 + cy*t + y0
                 */
                cx = 3*((pPointWrite+1)->x - pPointWrite->x);
                bx = 3*((pPointWrite+2)->x - (pPointWrite+1)->x) - cx;
                ax = (pPointWrite+3)->x - pPointWrite->x - bx - cx;
                cy = 3*((pPointWrite+1)->y - pPointWrite->y);
                by = 3*((pPointWrite+2)->y - (pPointWrite+1)->y) - cy;
                ay = (pPointWrite+3)->y - pPointWrite->y - by - cy;

                /* calculation of the length of the single vector
                 */
                aLength[0] = sqrt(SqrDistPoints(pPointWrite[0], pPointWrite[1]));
                aLength[1] = sqrt(SqrDistPoints(pPointWrite[1], pPointWrite[2]));
                aLength[2] = sqrt(SqrDistPoints(pPointWrite[2], pPointWrite[3]));

                /* deviation for P1
                 */
                t = aLength[0] + aLength[1] + aLength[2];
                if (t == 0)
                {   free(apPointList[0]);
                    free(apPointList[1]);
                    return nil;
                }
                t = aLength[0] / t;
                curvePoint.x = ax*t*t*t + bx*t*t + cx*t + pPointWrite->x;
                curvePoint.y = ay*t*t*t + by*t*t + cy*t + pPointWrite->y;
                dist = SqrDistPoints(pPointWrite[1], curvePoint);
                maxdist = (maxdist > dist) ? maxdist : dist;

                /* deviation for P2
                 */
                t = aLength[0] + aLength[1] + aLength[2];
                if (t == 0)
                {   free(apPointList[0]);
                    free(apPointList[1]);
                    return nil;
                }
                t = (aLength[0] + aLength[1]) / t;
                curvePoint.x = ax*t*t*t + bx*t*t + cx*t + pPointWrite->x;
                curvePoint.y = ay*t*t*t + by*t*t + cy*t + pPointWrite->y;
                dist = SqrDistPoints(pPointWrite[2], curvePoint);
                maxdist = (maxdist > dist) ? maxdist : dist;

            }
            pPointRead  += 3;
        }

        apPointList[2] = apPointList[0];
        apPointList[0] = apPointList[1];
        apPointList[1] = apPointList[2];

        n++;

    } while ( maxdist > flatness*flatness);

    free(apPointList[1]);

    pathG = [VPath path];
    plist = [NSMutableArray array];
    pPointRead  = apPointList[0];
    pv0 = *pPointRead++;
    for ( i = ldexp(3, n-1); i > 0; i--)
    {
        line = [VLine line];
        pv1 = *pPointRead++;
        [line setVertices:pv0 :pv1];
        pv0 = pv1;
        [plist addObject:line];
    }
    free(apPointList[0]);
    [pathG addList:plist at:[[pathG list] count]];

    return pathG;
}

- splittedObjectsAt:(float)t
{   NSPoint	pc[4], pc1[4], pc2[4];
    VCurve	*c1, *c2;

    pc[0] = p0; pc[1] = p1; pc[2] = p2; pc[3] = p3;
    tileCurveAt(pc, t, pc1, pc2);
    c1 = [VCurve curve];
    [c1 setVertices:pc1[0] :pc1[1] :pc1[2] :pc1[3]];
    c2 = [VCurve curve];
    [c2 setVertices:pc2[0] :pc2[1] :pc2[2] :pc2[3]];
    return [NSArray arrayWithObjects:c1, c2, nil];
}

- (NSMutableArray*)getListOfObjectsSplittedFromGraphic:g
{   NSMutableArray	*splitList = nil;
    int			i, cnt, iCnt;
    float		v0;
    NSPoint		last, *ps, *iPts;
    double		*tValues, t, t0, t1, matrix[3][3], x123[3], y123[3], abcX[3], abcY[3];
    int			n1, n2;
    BOOL		pointsOK = NO;
    NSAutoreleasePool	*pool;

    if ( !(iCnt = [self getIntersections:&iPts with:g]) )
        return nil;

    ps = iPts;
/*    ps = malloc((*iCnt) * sizeof(NSPoint));
    for (i=0, cnt=0; i<*iCnt; i++)
        ps[cnt++] = (*ppArray)[i];*/

    cnt = iCnt;
    if (!cnt)
    {   free(ps);
        return nil;
    }

    tValues = malloc((iCnt+2) * sizeof(double));

    if ( (cnt = removePointWithToleranceFromArray(p0, TOLERANCE*5.0, ps, iCnt)) != iCnt )
        pointsOK = YES;
    if ( (iCnt = removePointWithToleranceFromArray(p3, TOLERANCE*5.0, ps, cnt)) != cnt )
        pointsOK = YES;

    /* get t values for points and sort them (smallest first)
     */
    for (i=0, cnt=0; i<iCnt; i++)
    {
	if ((t = [self getTForPointOnCurve:ps[i]]) < 0.0 || t > 1.000001)
        {   int	j;

            for (j=i; j+1 < iCnt; j++)
            {   ps[j] = ps[j+1]; // alle !!!!
            }
            if (i+1<iCnt) { i--, iCnt--; }
            continue;
        }
        tValues[cnt++] = t;
        pointsOK = YES;
    }
    if ( !cnt )
    {   free(ps);
        free(tValues);
        return nil;
    }
    tValues[cnt++] = 1.0;
    ps[cnt-1] = p3;

    /* sort t values and in the same way ps array */
    v0 = 0;
    for (i=0; i<cnt-1; i++)
    {	int	j, jMin;
        float	lastDist, newDist, v;
        NSPoint	p;

        jMin = cnt;
        lastDist = Diff(tValues[i], v0);
        for (j=i+1; j<cnt; j++)
        {
            if ((newDist = Diff(tValues[j], v0)) < lastDist)
            {	lastDist = newDist;
                jMin = j;
            }
        }
        if (jMin<cnt)
        {   v = tValues[i];
            tValues[i] = tValues[jMin];
            tValues[jMin] = v;
            p = ps[i];
            ps[i] = ps[jMin];
            ps[jMin] = p;
        }
    }

    if (!pointsOK)
    {   free(ps);
        free(tValues);
        return nil;
    }

    splitList = [NSMutableArray array];
    pool = [NSAutoreleasePool new];

    t0 = 0.0;
    last = p0;
    for (n1 = 0; n1 < cnt; n1++)
    {	VCurve	*curve;
        NSPoint	pv0, pv1, pv2, pv3;

        /* calculate 3 points on each tile of the curve
         */
        t1 = tValues[n1];
        if (Diff(t0, t1) < 0.0001)
            continue;
        for (n2 = 0; n2 < 3; n2++)
        {	NSPoint	p;

            t = t0 + (n2+1)*(t1-t0)/3.0;
            [self getPoint:&p at:t];
            x123[n2] = p.x - last.x;
            y123[n2] = p.y - last.y;

            /* shrink t for the curve segment */
            t = (double)(n2+1) / 3.0;

            matrix[n2][0] = t * t * t;
            matrix[n2][1] = t * t;
            matrix[n2][2] = t;
        }
        t0 = t1;

        /* calculate a, b, c of the curve segment
         */
        if (!solveEquation3(matrix, x123, abcX) || !solveEquation3(matrix, y123, abcY))
        {   NSLog(@"VCurve, cannot split curve!");
            continue;
        }

        /* calculate the curve points for the segment
         * x1 = x0 + cx/3			y1 = y0 + cy/3
         * x2 = x1 + (cx + bx)/3	y2 = y1 + (cy + by)/3
         * x3 = x0 + cx + bx + ax	y3 = y0 + cy + by + ay
         */
        pv0 = last;
        pv1.x = last.x + abcX[2]/3.0;
        pv1.y = last.y + abcY[2]/3.0;
        pv2.x = pv1.x + (abcX[2] + abcX[1])/3.0;
        pv2.y = pv1.y + (abcY[2] + abcY[1])/3.0;
        pv3 = ps[n1];

        curve = [VCurve curve];
        [curve setVertices:pv0 :pv1 :pv2 :pv3];
        [splitList addObject:curve];

        last = pv3;
    }

    free(ps);
    free(tValues);
    [pool release];
    return splitList;
}

- getListOfObjectsSplittedFrom:(NSPoint*)pArray :(int)iCnt
{   NSMutableArray	*splitList = nil;
    int			i, cnt;
    float		v0;
    NSPoint		last, *ps, crv[4];
    double		*tValues, t, t0, t1, matrix[3][3], x123[3], y123[3], abcX[3], abcY[3];
    int			n1, n2;
    NSRect		bounds;
    BOOL		pointsOK = NO;
    NSAutoreleasePool	*pool;

    ps = malloc((iCnt+2) * sizeof(NSPoint));
    //bounds = [self bounds];
    bounds = [self coordBounds];
    bounds.origin.x -= 20*TOLERANCE; bounds.origin.y -= 20*TOLERANCE;   // same like in intersectCurves()
    bounds.size.width += 40.0*TOLERANCE; bounds.size.height += 40.0*TOLERANCE;
    crv[0] = p0; crv[1] = p1; crv[2] = p2; crv[3] = p3;

    for (i=0, cnt=0; i<iCnt; i++)
        if ( NSPointInRect(pArray[i] , bounds) && !pointInArray(pArray[i], ps, cnt) &&
             pointOnCurveNextToPoint(&last, crv, &pArray[i]) <= 50.0*TOLERANCE )
            ps[cnt++] = pArray[i];

    if (!cnt)
    {   free(ps);
        return nil;
    }
    iCnt = cnt;

    tValues = malloc((iCnt+2) * sizeof(double));

    if ( (cnt = removePointWithToleranceFromArray(p0, TOLERANCE*5.0, ps, iCnt)) != iCnt )
        pointsOK = YES;
    if ( (iCnt = removePointWithToleranceFromArray(p3, TOLERANCE*5.0, ps, cnt)) != cnt )
        pointsOK = YES;

    /* get t values for points and sort them (smallest first)
     */
    for (i=0, cnt=0; i<iCnt; i++)
    {
	if ((t = [self getTForPointOnCurve:ps[i]]) < 0.0 || t > 1.000001)
        {   int	j;

            for (j=i; j+1 < iCnt; j++)
            {   ps[j] = ps[j+1]; // alle !!!!
            }
            if (i+1<iCnt) { i--, iCnt--; }
            continue;
        }
        tValues[cnt++] = t;
        pointsOK = YES;
    }
    if ( !cnt )
    {   free(ps);
        free(tValues);
        return nil;
    }
    tValues[cnt++] = 1.0;
    ps[cnt-1] = p3;

    /* sort t values and in the same way ps array */
    v0 = 0;
    for (i=0; i<cnt-1; i++)
    {	int	j, jMin;
        float	lastDist, newDist, v;
        NSPoint	p;

        jMin = cnt;
        lastDist = Diff(tValues[i], v0);
        for (j=i+1; j<cnt; j++)
        {
            if ((newDist = Diff(tValues[j], v0)) < lastDist)
            {	lastDist = newDist;
                jMin = j;
            }
        }
        if (jMin<cnt)
        {   v = tValues[i];
            tValues[i] = tValues[jMin];
            tValues[jMin] = v;
            p = ps[i];
            ps[i] = ps[jMin];
            ps[jMin] = p;
        }
    }

    if (!pointsOK)
    {   free(ps);
        free(tValues);
        return nil;
    }

    splitList = [NSMutableArray array];
    pool = [NSAutoreleasePool new];

    t0 = 0.0;
    last = p0;
    for (n1 = 0; n1 < cnt; n1++)
    {	VCurve	*curve;
        NSPoint	pv0, pv1, pv2, pv3;

        /* calculate 3 points on each tile of the curve
         */
        t1 = tValues[n1];
        if (Diff(t0, t1) < 0.0001)
            continue;
        for (n2 = 0; n2 < 3; n2++)
        {	NSPoint	p;

            t = t0 + (n2+1)*(t1-t0)/3.0;
            [self getPoint:&p at:t];
            x123[n2] = p.x - last.x;
            y123[n2] = p.y - last.y;

            /* shrink t for the curve segment */
            t = (double)(n2+1) / 3.0;

            matrix[n2][0] = t * t * t;
            matrix[n2][1] = t * t;
            matrix[n2][2] = t;
        }
        t0 = t1;

        /* calculate a, b, c of the curve segment
         */
        if (!solveEquation3(matrix, x123, abcX) || !solveEquation3(matrix, y123, abcY))
        {   NSLog(@"VCurve, cannot split curve!");
            continue;
        }

        /* calculate the curve points for the segment
         * x1 = x0 + cx/3			y1 = y0 + cy/3
         * x2 = x1 + (cx + bx)/3	y2 = y1 + (cy + by)/3
         * x3 = x0 + cx + bx + ax	y3 = y0 + cy + by + ay
         */
        pv0 = last;
        pv1.x = last.x + abcX[2]/3.0;
        pv1.y = last.y + abcY[2]/3.0;
        pv2.x = pv1.x + (abcX[2] + abcX[1])/3.0;
        pv2.y = pv1.y + (abcY[2] + abcY[1])/3.0;
        pv3 = ps[n1];

        curve = [VCurve curve];
        [curve setWidth:width];
        [curve setColor:color];
        [curve setVertices:pv0 :pv1 :pv2 :pv3];
        [splitList addObject:curve];

        last = pv3;
    }

    free(ps);
    free(tValues);
    [pool release];
    return splitList;
}

- (NSMutableArray*)getListOfObjectsSplittedAtPoint:(NSPoint)pt;
{
    return [self getListOfObjectsSplittedFrom:&pt :1];
}

- (int)getIntersections:(NSPoint**)ppArray with:g
{   int		iCnt;

    if ([g isKindOfClass:[VPath class]] || [g isKindOfClass:[VGroup class]] ||
        [g isKindOfClass:[VPolyLine class]])
        iCnt = [g getIntersections:ppArray with:self];
    else if ([g isKindOfClass:[VLine class]])
    {	NSPoint	pv0, pv1;

        *ppArray = malloc((10) * sizeof(NSPoint));
        [g getVertices:&pv0 :&pv1];
        iCnt = [self intersectLine:*ppArray :pv0 :pv1];	/* returns 2 points for tangent */
    }
    else if ([g isKindOfClass:[VCurve class]])
    {	*ppArray = malloc((20) * sizeof(NSPoint));
        iCnt = [g intersectCurve:*ppArray :p0 :p1 :p2 :p3];
        iCnt = vhfFilterPoints(*ppArray, iCnt, 0.1);
    }
    else if ([g isKindOfClass:[VArc class]])
    {	NSPoint	ps[4];

        *ppArray = malloc((20) * sizeof(NSPoint));
        ps[0] = p0; ps[1] = p1; ps[2] = p2; ps[3] = p3;
        iCnt = [g intersectCurve:*ppArray :ps];
    }
    else if ([g isKindOfClass:[VRectangle class]])
        iCnt = [g getIntersections:ppArray with:self];
    else
    {	NSLog(@"VCurve, intersection with unknown class!");
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

- (float)sqrDistanceGraphic:g
{
    if ([g isKindOfClass:[VPath class]] || [g isKindOfClass:[VGroup class]] ||
        [g isKindOfClass:[VPolyLine class]] || [g isKindOfClass:[VRectangle class]] || [g isKindOfClass:[VArc class]])
        return [g sqrDistanceGraphic:self];
    else if ([g isKindOfClass:[VLine class]])
    {	NSPoint	pv0, pv1;

        [g getVertices:&pv0 :&pv1];
        return [self sqrDistanceLine:pv0 :pv1];
    }
    else if ([g isKindOfClass:[VCurve class]])
    {	NSPoint	ps[4];

        [g getVertices:&ps[0] :&ps[1] :&ps[2] :&ps[3]];
        return [self sqrDistanceCurve:ps];
    }
    else
    {   NSLog(@"VCurve, distance with unknown class!");
        return -1.0;
    }
    return -1.0;
}

- (float)sqrDistanceGraphic:g :(NSPoint*)pg1 :(NSPoint*)pg2
{
    if ([g isKindOfClass:[VPath class]] || [g isKindOfClass:[VGroup class]] ||
        [g isKindOfClass:[VPolyLine class]] || [g isKindOfClass:[VRectangle class]] || [g isKindOfClass:[VArc class]])
        return [g sqrDistanceGraphic:self :pg1 :pg2];
    else if ([g isKindOfClass:[VLine class]])
    {	NSPoint	pv0, pv1;

        [g getVertices:&pv0 :&pv1];
        return [self sqrDistanceLine:pv0 :pv1 :pg1 :pg2];
    }
    else if ([g isKindOfClass:[VCurve class]])
    {	NSPoint	ps[4];

        [g getVertices:&ps[0] :&ps[1] :&ps[2] :&ps[3]];
        return [self sqrDistanceCurve:ps :pg1 :pg2];
    }
    else
    {   NSLog(@"VCurve, distance (with two nearest points) unknown class!");
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
    NSPoint		iPoints[16], p, rp[4];
    int			iCnt = 0, i, j;
    VGroup		*group = [VGroup group];

    rp[0] = rect.origin;
    rp[1].x = rect.origin.x + rect.size.width; rp[1].y = rect.origin.y;
    rp[2].x = rect.origin.x + rect.size.width; rp[2].y = rect.origin.y + rect.size.height;
    rp[3].x = rect.origin.x; rp[3].y = rect.origin.y + rect.size.height;

    for (i=0; i<4; i++)
        iCnt += [self intersectLine:iPoints+iCnt :rp[i] :((i+1<4) ? rp[i+1] : rp[0])];

    if (!iCnt || !(cList = [self getListOfObjectsSplittedFrom:iPoints :iCnt]))
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
{   NSPoint	curveP, grad;
    float	c;

    [self getPoint:&curveP at:0.4];
    grad = [self gradientAt:0.4];

    c = sqrt(grad.x*grad.x+grad.y*grad.y);
    if ( left )
    {	point->x = curveP.x - grad.y*dist/c;
        point->y = curveP.y + grad.x*dist/c;
    }
    else
    {	point->x = curveP.x + grad.y*dist/c;
        point->y = curveP.y - grad.x*dist/c;
    }
}

- (BOOL)identicalWith:(VGraphic*)g
{	NSPoint	c0, c1, c2, c3;

    if ( ![g isKindOfClass:[VCurve class]] )
            return NO;

    [g getPoint:0 :&c0]; [g getPoint:1 :&c1]; [g getPoint:2 :&c2]; [g getPoint:3 :&c3];
    if (	(Diff(p0.x, c0.x) <= TOLERANCE && Diff(p0.y, c0.y) <= TOLERANCE &&
         Diff(p1.x, c1.x) <= 10.0*TOLERANCE && Diff(p1.y, c1.y) <= 10.0*TOLERANCE &&
         Diff(p2.x, c2.x) <= 10.0*TOLERANCE && Diff(p2.y, c2.y) <= 10.0*TOLERANCE &&
         Diff(p3.x, c3.x) <= TOLERANCE && Diff(p3.y, c3.y) <= TOLERANCE) )
        return YES;
    return NO;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [super encodeWithCoder:aCoder];
    //[aCoder encodeValuesOfObjCTypes:"{NSPoint=ff}{NSPoint=ff}{NSPoint=ff}{NSPoint=ff}", &p0, &p1, &p2, &p3];
    [aCoder encodePoint:p0];            // 2012-01-08
    [aCoder encodePoint:p1];
    [aCoder encodePoint:p2];
    [aCoder encodePoint:p3];
}
- (id)initWithCoder:(NSCoder *)aDecoder
{   int	version;

    [super initWithCoder:aDecoder];
    version = [aDecoder versionForClassName:@"VCurve"];
    if ( version<2 )
        [aDecoder decodeValuesOfObjCTypes:"{ff}{ff}{ff}{ff}", &p0, &p1, &p2, &p3];
    else
    {   //[aDecoder decodeValuesOfObjCTypes:"{NSPoint=ff}{NSPoint=ff}{NSPoint=ff}{NSPoint=ff}", &p0, &p1, &p2, &p3];
        p0 = [aDecoder decodePoint];    // 2012-01-08
        p1 = [aDecoder decodePoint];
        p2 = [aDecoder decodePoint];
        p3 = [aDecoder decodePoint];
    }

    [self setParameter];
    [self buildUPath];

    return self;
}

/* archiving with property list
 */
- (id)propertyList
{   NSMutableDictionary	*plist = [super propertyList];

    [plist setObject:propertyListFromNSPoint(p0) forKey:@"p0"];
    [plist setObject:propertyListFromNSPoint(p1) forKey:@"p1"];
    [plist setObject:propertyListFromNSPoint(p2) forKey:@"p2"];
    [plist setObject:propertyListFromNSPoint(p3) forKey:@"p3"];
    return plist;
}
- (id)initFromPropertyList:(id)plist inDirectory:(NSString *)directory
{
    [super initFromPropertyList:plist inDirectory:directory];
    p0 = pointFromPropertyList([plist objectForKey:@"p0"]);
    p1 = pointFromPropertyList([plist objectForKey:@"p1"]);
    p2 = pointFromPropertyList([plist objectForKey:@"p2"]);
    p3 = pointFromPropertyList([plist objectForKey:@"p3"]);
    [self setParameter];
    [self buildUPath];
    return self;
}


- (void)dealloc
{
    free(path.pts);
    [super dealloc];
}

@end
