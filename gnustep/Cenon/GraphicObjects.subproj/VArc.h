/* VArc.h
 * 2-D Arc object
 *
 * Copyright (C) 1996-2006 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1996-03-13
 * modified: 2006-11-24
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

#ifndef VHF_H_VARC
#define VHF_H_VARC

#include "VGraphic.h"
#include "VPath.h"

#define PTS_ARC		3

#define PT_START	0
#define	PT_CENTER	1
#define PT_END		2

@interface VArc: VGraphic
{
    NSPoint		center;		// origin
    NSPoint		start;		// startpoint
    float		angle;		// angle in degree (-360.0 to 360.0)
    int			selectedKnob;	// index of the selected knob (0 - 3 or -1)
    int			filled;		// 1 = fill, 2 = graduated filled

    /* the variables below will not be saved, we generate them for faster drawing */
    float		radius;		// radius
    float		begAngle;	// begin angle
    NSPoint		end;		// endpoint
    NSColor		*fillColor;	// fillColor if we are filled
    NSColor		*endColor;	// endColor if we are graduated/radial filled
    float		graduateAngle;	// angle of graduate filling
    float		stepWidth;	// stepWidth the color will change by graduate/radial filling
    NSPoint		radialCenter;	// the center position for radial filling in percent to the bounds
    NSMutableArray	*graduateList;	// list holding the graduate filling graphic objects
    BOOL		graduateDirty;	// if we must update the graduateList (calculate the graduate filling new)
    NSRect		coordBounds;	/* our coord bounding box */
}

/* class methods */
+ (VArc*)arc;
+ (VArc*)arcWithCenter:(NSPoint)p radius:(float)r filled:(BOOL)flag;

/* arc methods */
- (void)changeDirection;
- (int)selectedKnobIndex;

- (NSColor*)fillColor;
- (void)setFillColor:(NSColor*)col;
- (NSColor*)endColor;
- (void)setEndColor:(NSColor*)col;
- (float)graduateAngle;
- (void)setGraduateAngle:(float)a;
- (void)setStepWidth:(float)sw;
- (float)stepWidth;
- (void)setRadialCenter:(NSPoint)rc;
- (NSPoint)radialCenter;

- (void)setFullArcWithCenter:(NSPoint)p radius:(float)r;
- (void)setCenter:(NSPoint)p start:(NSPoint)s angle:(float)a;
- (void)getCenter:(NSPoint*)p start:(NSPoint*)s angle:(float*)a;
- (float)radius;
- (void)setRadius:(float)r;
- (float)angle;
- (void)setAngle:(float)a;
- (float)begAngle;
- (void)setBegAngle:(float)a;
- (void)calcAddedValues;
- (NSPoint)appendToBezierPath:(NSBezierPath*)bPath currentPoint:(NSPoint)currentPoint;
- (NSPoint)gradientAt:(float)t;
- (BOOL)isPointInside:(NSPoint)p;
- (int)isPointInsideOrOn:(NSPoint)p;
- (float)getPointOnArcClosestToPoint:(NSPoint)point intersection:(NSPoint*)iPoint;
- (VPath*)pathRepresentation;
- flattenedObjectWithFlatness:(float)flatness;

- (int)intersectLine:(NSPoint*)pArray :(NSPoint)pl0 :(NSPoint)pl1;
- (int)intersectCurve:(NSPoint*)pArray :(NSPoint)pc0 :(NSPoint)pc1 :(NSPoint)pc2 :(NSPoint)pc3;
- (int)intersectArc:(NSPoint*)pArray :(NSPoint)center1 :(NSPoint)start1 :(float)angle1 :(NSRect*)bounds1;
- (int)intersectCurve :(NSPoint*)points :(NSPoint*)pc;
- (NSMutableArray*)curveRepresentation;

- (BOOL)tangentIntersectionWithPath:path;

- (void)movePoint:(int)pt_num to:(NSPoint)p control:(BOOL)control;

- (id)clippedFrom:(VGraphic*)cg;

@end

#endif // VHF_H_VARC
