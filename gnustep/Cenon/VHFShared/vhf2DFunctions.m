/* vhf2DFunctions.m
 * vhf 2-D graphic functions
 *
 * Copyright (C) 1996-2012 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1996-01-19
 * modified: 2012-01-25 (vhfConvert3DLineToLines() new)
 *           2011-04-26 (vhfConvertLineToLines(), vhfBoundsOfCurve())
 *           2008-02-17 (some clean-up)
 *           2008-08-18 (vhfIsIntValueInArray() added, valueInArray() is deprecated now)
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

#include <math.h>
#include "vhf2DFunctions.h"
#include "vhfMath.h"

/*
 * created:   04.09.93
 * modified:  04.09.93 31.10.93
 *
 * purpose:   get the distance between a points and a line without the sqrt
 *            means sqrt(of the return value) is the real distance
 * parameter: point, line
 * return:    distance point/line
 */
float distancePointLine(const NSPoint *p0, const NSPoint *p1, const NSPoint *point)
{
    return sqrt(sqrDistancePointLine(p0, p1, point));
}

/*
 * created:   04.09.93
 * modified:  04.09.93 31.10.93
 *
 * purpose:   get the distance between a points and a line without the sqrt
 *            means sqrt(of the return value) is the real distance
 * parameter: point, line
 * return:    distance point/line
 */
float sqrDistancePointLine(const NSPoint *p0, const NSPoint *p1, const NSPoint *point)
{   NSPoint	iPoint;

    return pointOnLineClosestToPoint(*p0, *p1, *point, &iPoint);
}
float vhfSqrDistancePointLine(NSPoint p0, NSPoint p1, NSPoint point)
{   NSPoint	iPoint;

    return pointOnLineClosestToPoint(p0, p1, point, &iPoint);
}

/* modified: 09.11.96
 */
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

/*
 * created:  1996-03-29
 * modified: 2001-07-25
 *
 * purpose:   get the square of the distance between a point and the frame of a rectangle
 *            -> distance = sqrt(return value)
 * parameter: point, rectangle
 * return:    square distance point/rectangle
 */
double sqrDistPointRect(NSPoint p, NSRect rect)
{   NSPoint	p0, p1;
    double	dist, newDist;

    p0 = rect.origin;
    p1.x = rect.origin.x; p1.y = rect.origin.y + rect.size.height;
    dist = sqrDistancePointLine(&p0, &p1, &p);
    p0 = p1;
    p1.x = rect.origin.x + rect.size.width; p1.y = rect.origin.y + rect.size.height;
    if ( (newDist=sqrDistancePointLine(&p0, &p1, &p)) < dist )
        dist = newDist;
    p0 = p1;
    p1.x = rect.origin.x + rect.size.width; p1.y = rect.origin.y;
    if ( (newDist=sqrDistancePointLine(&p0, &p1, &p)) < dist )
        dist = newDist;
    p0 = p1;
    p1 = rect.origin;
    if ( (newDist=sqrDistancePointLine(&p0, &p1, &p)) < dist )
        dist = newDist;
    return dist;
}

/*
 * created:  1996-03-22
 * modified: 2001-06-11
 *
 * purpose:   get the distance between a points and a line without the sqrt
 *            means sqrt(of the return value) is the real distance
 *            iPoint holds the point on the line nearest to point
 * parameter: line, point, intersection
 * return:    sqr distance point/line
 */
float pointOnLineClosestToPoint(NSPoint p0, NSPoint p1, NSPoint point, NSPoint *iPoint)
{
    /* line is vertical */
    if ( Diff(p0.x, p1.x) <= TOLERANCE )
    {
        iPoint->x = p0.x;
        if (point.y < Min(p0.y, p1.y))		/* below line */
            iPoint->y = Min(p0.y, p1.y);
        else if (point.y > Max(p0.y, p1.y))	/* above line */
            iPoint->y = Max(p0.y, p1.y);
        else
            iPoint->y = point.y;
        return SqrDistPoints(*iPoint, point);
    }
    /* line is horicontal */
    else if ( Diff(p0.y, p1.y) <= TOLERANCE )
    {
        iPoint->y = p0.y;
        if (point.x < Min(p0.x, p1.x))		/* left of line */
            iPoint->x = Min(p0.x, p1.x);
        else if (point.x > Max(p0.x, p1.x))	/* right of line */
            iPoint->x = Max(p0.x, p1.x);
        else
            iPoint->x = point.x;
        return SqrDistPoints(*iPoint, point);
    }
    /* line lying somehow */
    else
    {	NSPoint		da, db;

        da.x = (p1.x - p0.x);
        da.y = (p1.y - p0.y);
        db.x = da.y;
        db.y = -da.x;

        vhfIntersectVectors(p0, da, point, db, iPoint);

        if ( (p0.x < p1.x) && (iPoint->x < p0.x) )	/* point left of line */
            *iPoint = p0;
        else if ( (p0.x > p1.x) && (iPoint->x < p1.x) )	/* point left of line */
            *iPoint = p1;
        else if ( (p0.x < p1.x) && (iPoint->x > p1.x) )	/* point right of line */
            *iPoint = p1;
        else if ( (p0.x > p1.x) && (iPoint->x > p0.x) )	/* point right of line */
            *iPoint = p0;

        /* point lying between the line begin and end */
        return SqrDistPoints(*iPoint, point);
    }
}

/* mirror point at axis
 */
NSPoint pointMirroredAtAxis(NSPoint p, VHFLine axis)
{   NSPoint	ip, da, db;

    da = NSMakePoint(axis.p1.x - axis.p0.x, axis.p1.y - axis.p0.y);
    db = NSMakePoint(da.y, -da.x);
    if (!vhfIntersectVectors(axis.p0, da, p, db, &ip))
        NSLog(@"pointMirroredAtAxis() intersection expected !!");
    return NSMakePoint(ip.x + (ip.x - p.x), ip.y + (ip.y - p.y));
}


/* created:   29.06.93
 * modified:  20.07.93 06.09.93 22.03.96
 * purpose:   intersect two endless lines given with point and deltas
 * parameter: p0
 *            da
 *            p1
 *            db
 *            p (points of intersection)
 * return:    number of intersections
 */
int vhfIntersectVectors(NSPoint p0, NSPoint da, NSPoint p1, NSPoint db, NSPoint *p)
{   double	ma, mb, ba, bb;
    double	xf, yf;

    /* both lines are horicontal */
    if ( (Abs(da.y) <= TOLERANCE) && (Abs(db.y) <= TOLERANCE) )
    {
        if (SqrDistPoints(p0, p1) <= TOLERANCE*TOLERANCE)
            return 0;
        /*{   *p = p0;
            return 1;
        }*/
        return 0;
    }
    if ( Abs(da.x) <= TOLERANCE )			/* line1  vertical ? */
    {
        if ( Abs(db.x) <= TOLERANCE )			/* line2  vertical ? (lines parallel) */
        {
            if (SqrDistPoints(p0, p1) <= TOLERANCE*TOLERANCE)
                return 0;
            /*{	*p = p0;
                return 1;
            }*/
            return 0;					/* -> no intersection */
        }
        else						/* only line1 vertical */
        {   mb = (double)db.y / (double)db.x;		/* calculate gradient line2 */
            bb = (double)p1.y - mb*(double)p1.x;	/* calculate y-achsenabschnitt */
            xf = (double)p0.x;				/* xf = x0 from line1 */
            yf = mb*xf+bb;
        }						/* yf ! */
    }
    else
    {
        if ( Abs(db.x) <= TOLERANCE )			/* only line2 vertical */
        {   ma = (double)da.y / (double)da.x;
            ba = (double)p0.y - ma*(double)p0.x;	/* calculate y-achsenabschnitt */
            xf = (double)p1.x;				/* xf = x0 from line2 */
            yf = ma*xf+ba;				/* yf ! */
        }
        else
        {   ma = (double)da.y / (double)da.x;
            ba = (double)p0.y - ma*(double)p0.x;	/* calculate y-achsenabschnitt */
            mb = (double)db.y / (double)db.x;
            bb = (double)p1.y - mb*(double)p1.x;	/* calculate y-achsenabschnitt */
            /* to compare the gradients we need a smaler tolerance
             */
            if ( Diff(ma, mb) < 0.0001 )			/* lines are parallel */
                return 0;				/* no intersection */				
            else
            {	xf = ((bb-ba) / (ma-mb));
                yf = ma*xf+ba;
            }
        }
    }
    p->x = xf;
    p->y = yf;

    return 1;					/* 1 intersection */
}

/* intersect vector and rectangle
 * created:  2002-01-22
 * modified: 
 */
int vhfIntersectVectorAndRect(NSPoint p0, NSPoint d0, NSRect rect, NSPoint *pts)
{   NSPoint	p[4], pt[2];
    int		cnt = 0, i;
    NSRect	insetRect = NSInsetRect(rect, -0.5, -0.5);

    p[0] = rect.origin;
    p[1] = NSMakePoint(rect.origin.x + rect.size.width, rect.origin.y);
    p[2] = NSMakePoint(rect.origin.x + rect.size.width, rect.origin.y + rect.size.height);
    p[3] = NSMakePoint(rect.origin.x, rect.origin.y + rect.size.height);
    for (i=0; i<4; i++)
    {   int	n, j = (i<3) ? i+1 : 0;

        n = vhfIntersectVectors(p0, d0, p[i], NSMakePoint(p[j].x-p[i].x, p[j].y-p[i].y), pt);
        while ((--n) >= 0)
        {
            if (NSPointInRect(pt[n], insetRect))
                pts[cnt++] = pt[n];
        }
    }

    return cnt;
}

/* created:   18.03.96
 * modified:  17.09.96
 * purpose:   intersect line with a line
 * parameter: pArray (intersections)
 *            pl0, pl1
 * return:    number of intersections
 *            0, 1
 */
int vhfIntersectLines(NSPoint *pArray, NSPoint p0, NSPoint p1, NSPoint pl0, NSPoint pl1)
{   NSPoint	da, db;
    int		iCnt;

    da.x = p1.x - p0.x;   da.y = p1.y - p0.y;
    db.x = pl1.x - pl0.x; db.y = pl1.y - pl0.y;
    /* if the delta is in the range of TOLERANCE vhfIntersectVectors would identify the lines as parallel */
    if (da.x<=TOLERANCE || da.y<=TOLERANCE) {da.x = 10.0*p1.x -10.0*p0.x;  da.y = 10.0*p1.y -10.0*p0.y; };
    if (db.x<=TOLERANCE || db.y<=TOLERANCE) {db.x = 10.0*pl1.x-10.0*pl0.x; db.y = 10.0*pl1.y-10.0*pl0.y;};
    iCnt = vhfIntersectVectors(p0, da, pl0, db, pArray);

    if (iCnt)
    {   NSRect	rect1, rect2;

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

    return 0;
}

/* created:   2003-07-19
 * modified:  2009-12-27 (init pr1)
 * purpose:   intersect line with a rect
 * parameter: pts[2] (intersections)
 *            p0, p1
 *            rect
 * return:    number of intersections
 *            0, 1
 */
int vhfIntersectLineAndRect(NSPoint p0, NSPoint p1, NSRect rect, NSPoint *pts)
{   int		i, j, cnt, pCnt = 0;
    NSPoint	pr0, pr1, pArray[2];

    pr0 = pr1 = rect.origin;
    for (i=0; i<4; i++)
    {
        switch (i)
        {
            case 0: pr1 = NSMakePoint(rect.origin.x + rect.size.width, rect.origin.y); break;
            case 1: pr1 = NSMakePoint(rect.origin.x + rect.size.width, rect.origin.y + rect.size.height); break;
            case 2: pr1 = NSMakePoint(rect.origin.x, rect.origin.y + rect.size.height); break;
            case 3: pr1 = rect.origin;
        }
        if ( (cnt = vhfIntersectLines(pArray, p0, p1, pr0, pr1)) )
            for (j=0; j<cnt; j++)
                pts[pCnt++] = pArray[j];
        pr0 = pr1;
    }
    return pCnt;
}

/* return intersection between two circles
 * created: 2009-12-21
 *
 * r1*r1 - c1*c1 = r2*r2 - c2*c2, c2 = d-c1
 * r1: radius 1
 * r2: radius 2
 * d:  distance of centers
 * c:  distance from one center (on d) to the center of the intersections
 */
int vhfIntersectCircles(NSPoint cp1, float r1, NSPoint cp2, float r2, NSPoint *pts)
{   double  distCtr = sqrt(SqrDistPoints(cp1, cp2)); // distance between centers
    double  tol = TOLERANCE;
    double  c, at, mdx, mdy, px, py, v;

    /* a quick check for possible intersection */
    if ( r1+r2+tol < distCtr )
        return 0;

    c = ((r1*r1) - (r2*r2) + distCtr*distCtr) / (2.0*distCtr);
    at = ( Diff(r1+r2, distCtr) <= tol || Diff(Diff(r1, r2), distCtr) <= tol )
    ? 0.0                   // 1 intersection only
    : sqrt(r1*r1 - c*c);    // 2 intersections
    mdx = cp2.x - cp1.x;
    mdy = cp2.y - cp1.y;
    px = cp1.x + mdx*c/distCtr;
    py = cp1.y + mdy*c/distCtr;

    v = mdx; mdx = -mdy; mdy = v;
    pts[0].x = px + mdx*at/distCtr;
    pts[0].y = py + mdy*at/distCtr;
    pts[1].x = px - mdx*at/distCtr;
    pts[1].y = py - mdy*at/distCtr;

    return (!at) ? 1 : 2;
}

/* the problem of the OpenStep-Funktion is that a width or height of 0 gives no intersection
 */
BOOL vhfIntersectsRect(NSRect rect1, NSRect rect2)
{   NSPoint	ll, lr, ul, ur, ll2, lr2, ul2, ur2;

    if (rect1.size.width  < TOLERANCE) rect1.size.width  = TOLERANCE;
    if (rect1.size.height < TOLERANCE) rect1.size.height = TOLERANCE;
    if (rect2.size.width  < TOLERANCE) rect2.size.width  = TOLERANCE;
    if (rect2.size.height < TOLERANCE) rect2.size.height = TOLERANCE;
//    return !NSIsEmptyRect(NSIntersectionRect(rect1, rect2));

    ll = lr = ul = rect1.origin;
    lr.x = ur.x = rect1.origin.x+rect1.size.width;
    ul.y = ur.y = rect1.origin.y+rect1.size.height;

    ll2 = lr2 = ul2 = rect2.origin;
    lr2.x = ur2.x = rect2.origin.x+rect2.size.width;
    ul2.y = ur2.y = rect2.origin.y+rect2.size.height;

    if ( ( ll.x >= ll2.x && ll.x <= ur2.x && ll.y >= ll2.y && ll.y <= ur2.y )
        ||( lr.x >= ll2.x && lr.x <= ur2.x && lr.y >= ll2.y && lr.y <= ur2.y )
        ||( ur.x >= ll2.x && ur.x <= ur2.x && ur.y >= ll2.y && ur.y <= ur2.y )
        ||( ul.x >= ll2.x && ul.x <= ur2.x && ul.y >= ll2.y && ul.y <= ur2.y ) )
        return YES;
    if ( ( ll2.x >= ll.x && ll2.x <= ur.x && ll2.y >= ll.y && ll2.y <= ur.y )
        ||( lr2.x >= ll.x && lr2.x <= ur.x && lr2.y >= ll.y && lr2.y <= ur.y )
        ||( ur2.x >= ll.x && ur2.x <= ur.x && ur2.y >= ll.y && ur2.y <= ur.y )
        ||( ul2.x >= ll.x && ul2.x <= ur.x && ul2.y >= ll.y && ul2.y <= ur.y ) )
        return YES;
    if ( ( ll.x >= ll2.x && ll.x <= ur2.x && ll.y <= ll2.y && ur.y >= ur2.y )
        ||( ll.y >= ll2.y && ll.y <= ur2.y && ll.x <= ll2.x && ur.x >= ur2.x )
        ||( ll2.x >= ll.x && ll2.x <= ur.x && ll2.y <= ll.y && ur2.y >= ur.y )
        ||( ll2.y >= ll.y && ll2.y <= ur.y && ll2.x <= ll.x && ur2.x >= ur.x ) )
        return YES;
    return NO;
}


/* check whether p is inside the polygon defined by nPts points in pts
 */
BOOL vhfIsPointInsidePolygon(NSPoint p, NSPoint *pts, int nPts)
{   int		i, cnt, leftCnt = 0;
    NSPoint	p0, p1, *iPts = malloc(nPts * sizeof(NSPoint));
    NSRect	bRect = vhfBoundsOfPoints(pts, nPts);

    if ( nPts < 3
         || p.y < bRect.origin.y || p.y > bRect.origin.y+bRect.size.height
         || p.x < bRect.origin.x || p.x > bRect.origin.x+bRect.size.width )
        return NO;
    p0 = NSMakePoint(bRect.origin.x - 2000.0, p.y);
    p1 = NSMakePoint(bRect.origin.x + bRect.size.width+2000.0, p.y);

    cnt = 0;
    for (i=0; i<nPts; i++)
    {   NSPoint	pl0 = pts[i], pl1 = ((i<nPts-1) ? pts[i+1] : pts[0]), pt;
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
            if (cnt >= nPts)
            {   NSLog(@"vhfIsPointInsidePolyLine(): point memory too small! %d > %d", cnt, nPts);
                free(iPts);
                return NO;
            }
            iPts[cnt] = pt;
            cnt++;
        }
    }
    if (!cnt)
    {   free(iPts);
        return NO;
    }

    if ( !Even(cnt) )	// we hit an edge, this should never happen!
    {	NSLog(@"vhfIsPointInsidePolyLine(): hit edge! p: %.3f %.3f cnt: %i", p.x, p.y, cnt);
        free(iPts);
        return NO;
    }

    for (i=0; i<cnt; i++)			// count points left of p
        if (iPts[i].x < p.x)
            leftCnt++;

    free(iPts);
    return (Even(leftCnt)) ? NO : YES;		// odd number of points to the left -> p is inside
}

/* the problem of the OpenStep-Funktion is that a width or height of 0 is never contained
 */
BOOL vhfContainsRect(NSRect rect1, NSRect rect2)
{
    if (rect1.size.width  < TOLERANCE) rect1.size.width  = TOLERANCE;
    if (rect1.size.height < TOLERANCE) rect1.size.height = TOLERANCE;
    if (rect2.size.width  < TOLERANCE) rect2.size.width  = TOLERANCE;
    if (rect2.size.height < TOLERANCE) rect2.size.height = TOLERANCE;
    return NSContainsRect(rect1, rect2);
}


/*
 * Rotation
 */

/* cw
 */
NSPoint vhfPointRotatedAroundCenter(NSPoint p, float a, NSPoint cp)
{   NSPoint	rp, np;

    rp.x = p.x - cp.x;
    rp.y = p.y - cp.y;
    np.x = rp.x * cos(DegToRad(-a)) + rp.y * sin(DegToRad(-a));
    np.y = rp.y * cos(DegToRad(-a)) - rp.x * sin(DegToRad(-a));
    p.x = np.x + cp.x;
    p.y = np.y + cp.y;
    return p;
}

/* cw
 */
void vhfRotatePointAroundCenter(NSPoint *p, NSPoint cp, float a)
{   NSPoint	rp, np;

    rp.x = p->x - cp.x;
    rp.y = p->y - cp.y;
    np.x = rp.x * cos(DegToRad(-a)) + rp.y * sin(DegToRad(-a));
    np.y = rp.y * cos(DegToRad(-a)) - rp.x * sin(DegToRad(-a));
    p->x = np.x + cp.x;
    p->y = np.y + cp.y;
}


/*
 * Angle
 */

/* calculate the angle of p relative cp
 * right of cp = 0, up = 90, left = 180, down = 270
 */
float vhfAngleOfPointRelativeCenter(NSPoint p, NSPoint cp)
{   float a, dx = p.x - cp.x, dy = p.y - cp.y;

    if (!dx)
        a = (dy >= 0) ? 90.0 : 270.0;
    else
    {	a = RadToDeg(atan(dy / dx));
        if (dx<0) a += 180;         // 2, 3
        if (dx>0 && dy<0) a += 360; // 4
    }
    return a;
}

/* calculates a point on the radius with a distance of angle (degree) from a reference point
 */
NSPoint vhfPointAngleFromRefPoint(NSPoint cp, NSPoint refP, float angle)
{
    return vhfPointRotatedAroundCenter(refP, angle, cp);
}

/* 1996-06-??
 * return the angle between the 3 points ccw
 */
float vhfAngleBetweenPoints(const NSPoint start, const NSPoint middle, const NSPoint end)
{   double	dx, dy;
    float	angle0, angle1;

    /* calculate angle of start to 0 degree
     */
    dx = start.x - middle.x;
    dy = start.y - middle.y;
    if (!dx)
        angle0 = (dy >= 0) ? 90.0 : 270;
    else
    {	angle0 = RadToDeg(atan(dy / dx));
        if (dx<0)           /* 2nd, 3rd quadrant */
            angle0 += 180;
        if (dx>0 && dy<0)   /* 4th quadrant */
            angle0 += 360;
    }

    /* calculate angle of end to 0 degree
     */
    dx = end.x - middle.x;
    dy = end.y - middle.y;
    if (!dx)
        angle1 = (dy >= 0) ? 90.0 : 270;
    else
    {	angle1 = RadToDeg(atan(dy / dx));
        if (dx<0)           /* 2nd, 3rd quadrant */
            angle1 += 180;
        if (dx>0 && dy<0)   /* 4th quadrant */
            angle1 += 360;
    }

    if (angle1 < angle0)
        angle1 += 360;
    return angle1 - angle0;
}


/*
 * Sorting
 */

/* created:   19.03.96
 * modified:  
 * purpose:   sort array of points with increasing distance to p0
 * parameter: pArray
 *            p0
 * return:    void
 */
void sortPointArray(NSPoint *pArray, int cnt, NSPoint p0)
{   int		i;

    for (i=0; i<cnt-1; i++)
    {	int     j, jMin;
        float   lastDist, newDist;
        NSPoint p;

        jMin = cnt;
        lastDist = SqrDistPoints(pArray[i], p0);
        for (j=i+1; j<cnt; j++)
        {
            if ((newDist = SqrDistPoints(pArray[j], p0)) < lastDist)
            {	lastDist = newDist;
                jMin = j;
            }
        }
        if (jMin < cnt)
        {   p = pArray[i];
            pArray[i] = pArray[jMin];
            pArray[jMin] = p;
        }
    }
}

/* created:   19.03.96
 * modified:  
 * purpose:   sort array of values with increasing distance to v0
 * parameter: vArray
 *            v0
 * return:    void
 */
void vhfSortValues(float *vArray, int cnt, float v0)
{   int		i;

    for (i=0; i<cnt-1; i++)
    {	int	j, jMin;
        float	lastDist, newDist;
        float	v;

        jMin = cnt;
        lastDist = Diff(vArray[i], v0);
        for (j=i+1; j<cnt; j++)
        {
            if ((newDist = Diff(vArray[j], v0)) < lastDist)
            {	lastDist = newDist;
                jMin = j;
            }
        }
        if (jMin<cnt)
        {   v = vArray[i];
            vArray[i] = vArray[jMin];
            vArray[jMin] = v;
        }
    }
}

NSRect vhfBoundsOfPoints(NSPoint *pts, int nPts)
{   int		i;
    NSPoint	ll = NSMakePoint(MAXCOORD, MAXCOORD), ur = NSMakePoint(MINCOORD, MINCOORD);

    for (i=0; i<nPts; i++)
    {
        if (pts[i].x < ll.x)
            ll.x = pts[i].x;
        if (pts[i].x > ur.x)
            ur.x = pts[i].x;
        if (pts[i].y < ll.y)
            ll.y = pts[i].y;
        if (pts[i].y > ur.y)
            ur.y = pts[i].y;
    }

    return NSMakeRect(ll.x, ll.y, ur.x-ll.x, ur.y-ll.y);
}

/* created:   08.07.93
 * modified:  19.03.96
 * purpose:   return YES, if point is in array
 *            use a tolerance for comparison!
 *            svIntersectCurveCurve needs this extremely large Tolerance!!
 * parameter: 
 */
BOOL pointInArray(NSPoint point, const NSPoint *array, int cnt)
{   int	i;

    for (i=0; i<cnt; i++)
        if (SqrDistPoints(point, array[i]) < (10.0*TOLERANCE)*(10.0*TOLERANCE))
            return YES;
    return NO;
}

BOOL pointWithToleranceInArray(NSPoint point, float tol, const NSPoint *array, int cnt)
{   int	i;

    for (i=0; i<cnt; i++)
        if (SqrDistPoints(point, array[i]) < (tol)*(tol))
            return YES;
    return NO;
}

/* created:  1996-06-19
 * modified: 
 * purpose:  return YES, if value is in array
 */
BOOL valueInArray(int val, int* array, int cnt) // DEPRECATED, use vhfIsIntValueInArray()
{   int	i;

    for (i=0; i<cnt; i++)
        if ( array[i] == val )
            return YES;
    return NO;
}
/* created:  1996-06-19
 * modified: 2008-08-18
 * purpose:  return YES, if value is in array
 */
BOOL vhfIsIntValueInArray(int val, int* array, int cnt)
{   int	i;
    
    for (i=0; i<cnt; i++)
        if ( array[i] == val )
            return YES;
    return NO;
}

/* created:   1993-07-08
 * modified:  2001-02-15
 */
int removePointFromArray(NSPoint p, NSPoint *pArray, int cnt)
{   int	i, j;

    for (i=0; i<cnt; i++)
        if ( SqrDistPoints(p, pArray[i]) < (2.0*TOLERANCE)*(2.0*TOLERANCE) )
        {
            for (j=i; j<cnt-1; j++)
                pArray[j] = pArray[j+1];
            cnt--; i--;
        }
    return cnt;
}
int removePointWithToleranceFromArray(NSPoint p, float tol, NSPoint *pArray, int cnt)
{   int	i, j;

    for (i=0; i<cnt; i++)
        if ( SqrDistPoints(p, pArray[i]) < tol*tol )
        {
            for (j=i; j<cnt-1; j++)
                pArray[j] = pArray[j+1];
            cnt--; i--;
        }
    return cnt;
}

/* remove points which apear more then one time in array
 * we change the order of the points in the array!
 */
int vhfFilterPoints(NSPoint *pArray, int cnt, float tol)
{   int	i, j;

    for ( i=0; i<cnt-1; i++ )
        for ( j=i+1; j<cnt; j++ )
            if ( DiffPoint(pArray[i], pArray[j]) < tol )
            {	pArray[j] = pArray[cnt-1];	/* exchange with last point */
                cnt--; j--;
            }
    return cnt;
}


/*
 * Bezier
 */

/* created:   
 * modified:  
 * parameter: p		the point
 *            pc[4]	curve points
 *            t		0 <= t <= 1
 * purpose:   get a point on the curve at t
 */
BOOL vhfGetPointOnCurveAt(NSPoint *p, NSPoint pc[4], float t)
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

    p->x=pt[0].x+t*(pt[1].x-pt[0].x);
    p->y=pt[0].y+t*(pt[1].y-pt[0].y);

    return YES;
}

/* created:   1993-07-08
 * modified:  1996-03-19
 * parameter: curve
 *            t (the t value where we split the curve)
 *            curves	(the curve segments)
 * purpose:   split 'curve' at 't'
 * return:    number of curve segments in 'curves'
 */
int vhfSplitCurveAt(const NSPoint pc[4], float t, NSPoint *pc1, NSPoint *pc2)
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

/* created: 04.01.95
 * purpose: return the gradient (delta x, y) of the curve at t
 */
BOOL vhfGetGradientOfCurveAt(NSPoint *p, NSPoint pc[4], float t)
{   float	ax, bx, cx, ay, by, cy;

    /* represent the curve with the equations
    * x(t) = ax*t^3 + bx*t^2 + cx*t + x(0)
    *
    * calculate a, b, c
    * x1 = x0 + cx/3
    * x2 = x1 + (cx + bx)/3
    * x3 = x0 + cx + bx + ax
    */
    cx = 3.0*(pc[1].x - pc[0].x);
    bx = 3.0*(pc[2].x - pc[1].x) - cx;
    ax = pc[3].x - pc[0].x - bx - cx;
    cy = 3.0*(pc[1].y - pc[0].y);
    by = 3.0*(pc[2].y - pc[1].y) - cy;
    ay = pc[3].y - pc[0].y - by - cy;

    /* get the gradient at t.
        * dx = 3*ax*t^2 + 2*bx*t + cx
        * dy = 3*ay*t^2 + 2*by*t + cy
        */
    p->x = 3.0*ax*t*t + 2.0*bx*t + cx;
    p->y = 3.0*ay*t*t + 2.0*by*t + cy;

    return YES;
}

/* flatten line
 *
 * return: number of points in pts
 *         pts has to be freed using NSZoneFree(NSDefaultMallocZone(), pts)
 *
 * modified: 2011-04-23
 */
int vhfConvertLineToLines(NSPoint pc[2], float flatness, NSPoint **pts)
{   NSZone  *zone = NSDefaultMallocZone();
    double	dx = pc[1].x-pc[0].x, dy = pc[1].y -pc[0].y;
    double  length2 = dx*dx + dy*dy;
    NSPoint *ptsPtr;

    if ( flatness < 0.02 )
        flatness = 0.02;

    if (length2 > flatness * flatness)
    {   NSZone  *zone = NSDefaultMallocZone();
        int     i, n = Max(1, (int)ceil(sqrt(length2 / (flatness*flatness))));
        NSPoint	len = (NSPoint){dx / (double)n, dy / (double)n};

        *pts = NSZoneMalloc(zone, (n+1) * sizeof(NSPoint));
        ptsPtr = *pts;

        ptsPtr[0] = pc[0];

        for (i=1; i<=n; i++)
        {   ptsPtr[i].x = pc[0].x + (double)i * len.x;
            ptsPtr[i].y = pc[0].y + (double)i * len.y;
        }
        return n+1;
    }
    *pts = NSZoneMalloc(zone, 2 * sizeof(NSPoint));
    (*pts)[0] = pc[0];
    (*pts)[1] = pc[1];
    return 2;
}

/* flatten 3D line
 *
 * return: number of points in pts
 *         pts has to be freed using NSZoneFree(NSDefaultMallocZone(), pts)
 *
 * modified: 2011-12-19
 */
int vhfConvert3DLineToLines(V3Point pc[2], float flatness, V3Point **pts)
{   NSZone  *zone = NSDefaultMallocZone();
    double	dx = pc[1].x-pc[0].x, dy = pc[1].y -pc[0].y, dz = pc[1].z -pc[0].z;
    double  length2 = dx*dx + dy*dy + dz*dz;
    V3Point *ptsPtr;

    if ( flatness < 0.02 )
        flatness = 0.02;

    if (length2 > flatness * flatness)
    {   int     i, n = Max(1, (int)ceil(sqrt(length2 / (flatness*flatness))));
        V3Point	len = (V3Point){dx / (double)n, dy / (double)n, dz / (double)n};

        *pts = NSZoneMalloc(zone, (n+1) * sizeof(V3Point));
        ptsPtr = *pts;

        ptsPtr[0] = pc[0];

        for (i=1; i<=n; i++)
        {   ptsPtr[i].x = pc[0].x + (double)i * len.x;
            ptsPtr[i].y = pc[0].y + (double)i * len.y;
            ptsPtr[i].z = pc[0].z + (double)i * len.z;
        }
        return n+1;
    }
    *pts = NSZoneMalloc(zone, 2 * sizeof(V3Point));
    (*pts)[0] = pc[0];
    (*pts)[1] = pc[1];
    return 2;
}

/* flatten curve
 *
 * return: number of points in pts
 *         pts has to be freed using NSZoneFree(NSDefaultMallocZone(), pts)
 *
 * modified: 2007-09-21
 */
int vhfConvertCurveToLines(NSPoint pc[4], float flatness, NSPoint **pts)
{   NSPoint     *apPointList[3], *pPointRead, *pPointWrite, curvePoint;
    double      aLength[3], ax, ay, bx, by, cx, cy, t, dist, maxdist;
    int         i, i2, n = 1;
    NSZone      *zone = NSDefaultMallocZone();

    if ( flatness < 0.02 )
        flatness = 0.02;
    (apPointList[0]) = NSZoneMalloc(zone, (ldexp(3, 9)+1) * sizeof(NSPoint));
    (apPointList[1]) = NSZoneMalloc(zone, (ldexp(3, 9)+1) * sizeof(NSPoint));
    apPointList[2]   = 0;

    * apPointList[0]    = pc[0];
    *(apPointList[0]+1) = pc[1];
    *(apPointList[0]+2) = pc[2];
    *(apPointList[0]+3) = pc[3];

    /* split curve in two curves until the wanted resolution has been achieved */
    do
    {   maxdist = dist = 0.0;

        if ( n >= 9 && !(apPointList[1] = NSZoneRealloc(zone, apPointList[1], (ldexp(3,n)+1) * sizeof(NSPoint))) )
        {   NSZoneFree(zone, apPointList[0]);
            return 0;
        }
        pPointRead  = apPointList[0];
        pPointWrite = apPointList[1];
        *pPointWrite = *pPointRead;

        /* scan curves in pPointRead */
        for ( i2 = ldexp(1,n-1); i2 > 0; i2--)
        {
            *(pPointWrite+6) = *(pPointRead+3);
            *(pPointWrite+1) = CenterPoint( * pPointRead,    *(pPointRead+1));
            *(pPointWrite+3) = CenterPoint( *(pPointRead+1), *(pPointRead+2));
            *(pPointWrite+5) = CenterPoint( *(pPointRead+2), *(pPointRead+3));
            *(pPointWrite+2) = CenterPoint( *(pPointWrite+1), *(pPointWrite+3));
            *(pPointWrite+4) = CenterPoint( *(pPointWrite+3), *(pPointWrite+5));
            *(pPointWrite+3) = CenterPoint( *(pPointWrite+2), *(pPointWrite+4));

            /* calculate the maximum deviation */
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
                
                /* calculation of the length of the single vector */
                aLength[0] = sqrt(SqrDistPoints(pPointWrite[0], pPointWrite[1]));
                aLength[1] = sqrt(SqrDistPoints(pPointWrite[1], pPointWrite[2]));
                aLength[2] = sqrt(SqrDistPoints(pPointWrite[2], pPointWrite[3]));
                
                /* deviation for P1 */
                t = aLength[0] + aLength[1] + aLength[2];
                if (t == 0)
                {   NSZoneFree(zone, apPointList[0]);
                    NSZoneFree(zone, apPointList[1]);
                    return 0;
                }
                t = aLength[0] / t;
                curvePoint.x = ax*t*t*t + bx*t*t + cx*t + pPointWrite->x;
                curvePoint.y = ay*t*t*t + by*t*t + cy*t + pPointWrite->y;
                dist = SqrDistPoints(pPointWrite[1], curvePoint);
                maxdist = (maxdist > dist) ? maxdist : dist;
                
                /* deviation for P2 */
                t = aLength[0] + aLength[1] + aLength[2];
                if (t == 0)
                {   NSZoneFree(zone, apPointList[0]);
                    NSZoneFree(zone, apPointList[1]);
                    return 0;
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

    NSZoneFree(zone, apPointList[1]);

    *pts = apPointList[0];

    /*{   NSPoint  pv0, pv1;

        pPointRead = apPointList[0];
        pv0 = *pPointRead++;
        for (i = ldexp(3, n-1); i > 0; i--)
        {   pv1 = *pPointRead++;
            printf("%.1f %.1f ", pv1.x, pv1.y);
            //[tmpStream appendLine:pv1.x :pv1.y];
        }
        printf("\n");
        //free(apPointList[0]);
    }*/

    return ldexp(3, n-1) + 1;
}

BOOL vhfConvertCurveToArc(NSPoint pc[4], NSPoint *center, NSPoint *start, float *angle)
{   NSPoint	pa, da, pb, db, ps[2];
    NSPoint	end = pc[3];
    float	ba, ea, a, v;

    *start = pc[0];

    if (!vhfGetPointOnCurveAt(&pa, pc, 0.5))
        return NO;
    da.x = pa.x - (pc[0].x+pc[3].x)/2.0;
    da.y = pa.y - (pc[0].y+pc[3].y)/2.0;

    pb = pc[0];
    if (!vhfGetGradientOfCurveAt(&db, pc, 0.0))
        return NO;
    v = db.x; db.x = -db.y; db.y = v;
    if ( vhfIntersectVectors(pa, da, pb, db, ps) == 1 )
    {
        *center = ps[0];
        ba = vhfAngleOfPointRelativeCenter(*start, *center);
        ea = vhfAngleOfPointRelativeCenter(end, *center);
        a = vhfAngleOfPointRelativeCenter(pa, *center);
        if (ea < ba) ea+=360.0;
        *angle = ea - ba;
        if (a<ba || a>ea)
            *angle = -(360.0 - *angle);
//		printf("%f %f %f\n",ba, ea, *angle);
//		printf("%f %f %f < %f\n", SqrDistPoints(pa, *center), SqrDistPoints(pb, *center),
//								Diff(SqrDistPoints(pa, *center), SqrDistPoints(pb, *center)), 100.0*TOLERANCE);
        if ( Diff(SqrDistPoints(pa, *center), SqrDistPoints(pb, *center)) <= 200.0*TOLERANCE )
            return YES;
    }

    return NO;
}

/* return rectangle fitting the start and end point of the arc and all quadrants in between
 * created:  2004-08-04
 * modified: 2004-08-04
 */
NSRect vhfBoundsOfArc(NSPoint center, float radius, float begAngle, float angle)
{   NSRect	bounds;
    float	ba, ea;
    NSPoint	p, ll, ur, start, end;

    if (Abs(angle) >= 360.0)
    {
        bounds.origin.x = center.x - radius;
        bounds.origin.y = center.y - radius;
        bounds.size.width = bounds.size.height = 2.0 * radius;
        return bounds;
    }
//printf("center = (%f %f) radius = %f begAngle = %f angle %f\n", center.x, center.y, radius, begAngle, angle);

    start = vhfPointRotatedAroundCenter(NSMakePoint(center.x+radius, center.y), begAngle, center);
    end   = vhfPointRotatedAroundCenter(start, angle, center);
//printf("start = (%f %f)  end = (%f %f)\n", start.x, start.y, end.x, end.y);

    ll.x = Min(start.x, end.x); ll.y = Min(start.y, end.y);
    ur.x = Max(start.x, end.x); ur.y = Max(start.y, end.y);

    /* we need positive angles with ba < ea */
    ba = (angle>=0.0) ? begAngle : (begAngle+angle);
    if (ba < 0.0)   ba += 360.0;
    if (ba > 360.0) ba -= 360.0;
    ea = ba + Abs(angle);
//printf("ba = %f ea = %f\n", ba, ea);

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
    if ((ba <= 180.0 && ea >= 180.0) || (ba<=540 && ea>=540))		// 180 degree
    {   p.x = center.x-radius; p.y = center.y;
        ll.x = Min(ll.x, p.x); ll.y = Min(ll.y, p.y);
        ur.x = Max(ur.x, p.x); ur.y = Max(ur.y, p.y);
    }
    if ((ba <= 270.0 && ea >= 270.0) || (ba<=630 && ea>=630))		// 270 degree
    {   p.x = center.x; p.y = center.y-radius;
        ll.x = Min(ll.x, p.x); ll.y = Min(ll.y, p.y);
        ur.x = Max(ur.x, p.x); ur.y = Max(ur.y, p.y);
    }

    bounds.origin = ll;
    bounds.size.width  = MAX(ur.x - ll.x, 0.001); // 1.0
    bounds.size.height = MAX(ur.y - ll.y, 0.001);

    return bounds;
}

/*
 * modified:  01.08.93 30.04.96
 * Author:    Martin Dietterle
 * purpose:   get bounds of curve
 * parameter: curve points, bounds
 * return:    none
 */
NSRect vhfBoundsOfCurve( NSPoint pc[4] )
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

/* flatten arc into lines
 * return: number of points in pts
 *         pts has to be freed using NSZoneFree(NSDefaultMallocZone(), pts)
 *
 * modified: 2007-09-22
 */
int vhfConvertArcToLines(NSPoint center, float radius, float begAngle, float angle, float flatness, NSPoint **pts)
{   double	chordAngle, dx = radius - flatness;  // we tune the flatness to make it smoother
    int         n, i, nPts = 0;
    NSPoint     startPoint, p, *ptsPtr;
    NSZone      *zone = NSDefaultMallocZone();

    startPoint = vhfPointRotatedAroundCenter(NSMakePoint(center.x+radius, center.y), begAngle, center);

    if (dx <= 0.0)
        n = 1;
    else
    {   chordAngle = RadToDeg(acos(dx/radius))*2.0;
        chordAngle = Limit(chordAngle, 0.1, 5.0);
        n = (int)ceil(Abs(angle) / chordAngle);         // number of lines
    }

    *pts = NSZoneMalloc(zone, (n+1) * sizeof(NSPoint));
    ptsPtr = *pts;

    chordAngle = angle / n;				// chord angle to get lines of equal length
    for ( i=1; i<=n; i++ )
    {   float	a = (double)i * chordAngle;

        p = vhfPointRotatedAroundCenter(startPoint, a, center);
        ptsPtr[nPts++] = p;
    }
    return nPts;
}
