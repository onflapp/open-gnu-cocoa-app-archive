/* vhf2DFunctions.h
 * vhf 2-D graphic functions
 *
 * Copyright (C) 1996-2012 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1996-01-19
 * modified: 2012-01-25 (vhfConvert3DLineToLines() new)
 *           2011-04-26 (vhfConvertLineToLines(), vhfBoundsOfCurve())
 *           2010-06-11 (SqrDistPoints(), SqrPoint() casted to double)
 *           2008-02-17 (SqrPoint() added)
 *           2008-08-18 (vhfIsIntValueInArray() added, valueInArray() is deprecated now)
 *
 * This file is part of the vhf Shared Library.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the vhf Public License as
 * published by the vhf interservice GmbH. Among other things,
 * the License requires that the copyright notices and this notice
 * be preserved on all copies.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the vhf Public License for more details.
 *
 * You should have received a copy of the vhf Public License along
 * with this library; see the file LICENSE. If not, write to vhf.
 *
 * If you want to link this library to your proprietary software,
 * or for other uses which are not covered by the definitions
 * laid down in the vhf Public License, vhf also offers a proprietary
 * license scheme. See the vhf internet pages or ask for details.
 *
 * vhf interservice GmbH, Im Marxle 3, 72119 Altingen, Germany
 * eMail: info@vhf.de
 * http://www.vhf.de
 */

#ifndef VHF_H_2DFUNCTIONS
#define VHF_H_2DFUNCTIONS

#include "types.h"

//#define	SqrDistPoints(p1, p2)   (((p1).x-(p2).x)*((p1).x-(p2).x)+((p1).y-(p2).y)*((p1).y-(p2).y))
#define	SqrDistPointsM(p1, p2)  (((double)(p1).x-(double)(p2).x)*((double)(p1).x-(double)(p2).x)+((double)(p1).y-(double)(p2).y)*((double)(p1).y-(double)(p2).y))
static __inline__ double SqrDistPoints(NSPoint p1, NSPoint p2)
{   double	x1 = p1.x, y1 = p1.y, x2 = p2.x, y2 = p2.y;
    return ((x1-x2)*(x1-x2)+(y1-y2)*(y1-y2));
}
//#define	SqrPoint(p)             ((p).x*(p).x + (p).y*(p).y)
//#define	SqrPoint(p)             ((double)(p).x*(double)(p).x + (double)(p).y*(double)(p).y)
static __inline__ double SqrPoint(NSPoint p)
{   double	x = p.x, y = p.y;
    return x*x + y*y;
}

/* distance */
float distancePointLine(const NSPoint *p0, const NSPoint *p1, const NSPoint *point);
float sqrDistancePointLine(const NSPoint *p0, const NSPoint *p1, const NSPoint *point);	// deprecated
float vhfSqrDistancePointLine(NSPoint p0, NSPoint p1, NSPoint point);
float distancePointArc(NSPoint pt, NSPoint cp, float r, float ba, float angle);
double sqrDistPointRect(NSPoint p, NSRect rect);

/* object border tests */
float pointOnLineClosestToPoint(NSPoint p0, NSPoint p1, NSPoint point, NSPoint *iPoint);

/* mirror */
NSPoint pointMirroredAtAxis(NSPoint p, VHFLine axis);

/* intersection */
int vhfIntersectVectors(NSPoint p0, NSPoint da, NSPoint p1, NSPoint db, NSPoint *p);
int vhfIntersectVectorAndRect(NSPoint p0, NSPoint d0, NSRect rect, NSPoint *pts);
int vhfIntersectLines(NSPoint *pArray, NSPoint p0, NSPoint p1, NSPoint pl0, NSPoint pl1);
int vhfIntersectLineAndRect(NSPoint p0, NSPoint p1, NSRect rect, NSPoint *pts);
int vhfIntersectCircles(NSPoint cp1, float r1, NSPoint cp2, float r2, NSPoint *pts);
BOOL vhfIntersectsRect(NSRect rect1, NSRect rect2);

/* inside tests */
BOOL    vhfIsPointInsidePolygon(NSPoint p, NSPoint *pts, int nPts);
BOOL    vhfContainsRect(NSRect rect1, NSRect rect2);

/* rotation */
NSPoint vhfPointRotatedAroundCenter(NSPoint p, float a, NSPoint cp);	// ccw
void    vhfRotatePointAroundCenter(NSPoint* p, NSPoint cp, float a);	// ccw (deprecated!)

/* angle */
float   vhfAngleOfPointRelativeCenter(NSPoint p, NSPoint cp);
NSPoint vhfPointAngleFromRefPoint(NSPoint cp, NSPoint refP, float angle);   // right = 0, up = 90, ccw
float   vhfAngleBetweenPoints(const NSPoint start, const NSPoint middle, const NSPoint end);	// ccw

/* sort */
void    sortPointArray(NSPoint *pArray, int cnt, NSPoint p0);
void    vhfSortValues(float *vArray, int cnt, float v0);

/* value and point arrays */
NSRect  vhfBoundsOfPoints(NSPoint *pts, int nPts);
BOOL    pointInArray(NSPoint point, const NSPoint *array, int cnt);
BOOL    pointWithToleranceInArray(NSPoint point, float tol, const NSPoint *array, int cnt);
BOOL    valueInArray(int val, int* array, int cnt); // DEPRECATED, use vhfIsIntValueInArray()
BOOL    vhfIsIntValueInArray(int val, int* array, int cnt);
int     removePointFromArray(NSPoint p, NSPoint *pArray, int cnt);
int     removePointWithToleranceFromArray(NSPoint p, float tol, NSPoint *pArray, int cnt);
int     vhfFilterPoints(NSPoint *pArray, int cnt, float tol);

/* bezier curve */
NSRect  vhfBoundsOfCurve( NSPoint pc[4] );
int     vhfSplitCurveAt(const NSPoint pc[4], float t, NSPoint *pc1, NSPoint *pc2);
BOOL    vhfGetPointOnCurveAt(NSPoint *p, NSPoint pc[4], float t);
BOOL    vhfGetGradientOfCurveAt(NSPoint *p, NSPoint pc[4], float t);
BOOL    vhfConvertCurveToArc(NSPoint pc[4], NSPoint *center, NSPoint *start, float *angle);
int     vhfConvertCurveToLines(NSPoint pc[4], float flatness, NSPoint **pts);

/* arc */
NSRect  vhfBoundsOfArc(NSPoint center, float radius, float begAngle, float angle);
int     vhfConvertArcToLines(NSPoint center, float radius, float begAngle, float angle, float flatness, NSPoint **pts);

/* line, 3D-Line */
int     vhfConvertLineToLines  (NSPoint pc[2], float flatness, NSPoint **pts);
int     vhfConvert3DLineToLines(V3Point pc[2], float flatness, V3Point **pts);

#endif // VHF_H_2DFUNCTIONS
