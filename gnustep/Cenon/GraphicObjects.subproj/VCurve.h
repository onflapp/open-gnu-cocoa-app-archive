/* VCurve.h
 * 2-D Bezier curve
 *
 * Copyright (C) 1996-2002 by vhf interservice GmbH
 * Author:  Georg Fleischmann
 *
 * created:  1996-01-29
 * modified: 2002-07-07
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

#ifndef VHF_H_VCURVE
#define VHF_H_VCURVE

#include "VGraphic.h"

#define PTS_BEZIER	4
#define OPS_BEZIER	2

#define	LLX(pts)	(pts[0])
#define	LLY(pts)	(pts[1])
#define	URX(pts)	(pts[2])
#define	URY(pts)	(pts[3])

NSRect fastBoundsOfCurve(const NSPoint ps[4]);
NSRect boundsOfCurve( const NSPoint pc[4] );
int tileCurveAt(const NSPoint pc[4], float t, NSPoint *pc1, NSPoint *pc2);
float pointOnCurveNextToPoint(NSPoint *curvePoint, const NSPoint *pc, const NSPoint *point);

@interface VCurve:VGraphic
{
    NSPoint	p0, p1, p2, p3; // the vertices of the curve
    UPath	path;           // Holds the user path description
    int		selectedKnob;   // index of the selected knob (0 - 3 or -1)
    NSRect	coordBounds;    // our coord bounding box
}

/* class methods*/
+ (VCurve*)curve;
+ (VCurve*)curveWithPoints:(NSPoint)p0 :(NSPoint)p1 :(NSPoint)p2 :(NSPoint)p3;

/* curve methods*/
- (NSRect)fastBounds;
- (void)setVertices:(NSPoint)pv0 :(NSPoint)pv1 :(NSPoint)pv2 :(NSPoint)pv3;
- (void)getVertices:(NSPoint*)pv0 :(NSPoint*)pv1 :(NSPoint*)pv2 :(NSPoint*)pv3;
- (void)changePoint:(int)pt_num :(NSPoint)pt;
- (void)calcVerticesFromPoints:(NSPoint)pv0 :(NSPoint)pv1 :(NSPoint)pv2 :(NSPoint)pv3;
- (NSPoint)gradientAt:(float)t;
- (NSPoint)gradientNear:(float)t;
- (int)intersectVector:(NSPoint*)pArray :(NSPoint)pl :(NSPoint)dl;
- (int)intersectLine:(NSPoint*)pArray :(NSPoint)pl0 :(NSPoint)pl1;
- (int)intersectCurve:(NSPoint*)pArray :(NSPoint)pc0 :(NSPoint)pc1 :(NSPoint)pc2 :(NSPoint)pc3;
- (double)getTForPointOnCurve:(NSPoint)point;
- splittedObjectsAt:(float)t;
- flattenedObjectWithFlatness:(float)flatness;

- (NSPoint)appendToBezierPath:(NSBezierPath*)bPath currentPoint:(NSPoint)currentPoint;
- (void)updateBounds;
- (int)selectedKnobIndex;

@end

#endif // VHF_H_VCURVE
