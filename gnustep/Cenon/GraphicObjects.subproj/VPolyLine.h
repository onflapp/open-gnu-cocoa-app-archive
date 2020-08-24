/* VPolyLine.h
 * Object of connected lines, either open or closed
 *
 * Copyright (C) 2001-2010 by vhf interservice GmbH
 * Author:   Ilonka Fleischmann
 *
 * created:  2001-07-31
 * modified: 2008-10-11
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

#ifndef VHF_H_VPOLYLINE
#define VHF_H_VPOLYLINE

#include "VGraphic.h"
#include "VPath.h"

@interface VPolyLine:VGraphic
{
    int             maxcount;
    int             count;
    NSMutableData   *ptsData;
    NSPoint         *ptslist;       // the vertices of the line
    int             selectedKnob;   // index of the selected knob (0 - 3 or -1)
    int             filled;
    NSColor         *fillColor;     // fillColor if we are filled
    NSColor         *endColor;      // endColor if we are graduated/radial filled
    float           graduateAngle;  // angle of graduate filling
    float           stepWidth;      // stepWidth the color will change by graduate/radial filling
    NSPoint         radialCenter;   // the center position for radial filling in percent to the bounds
    NSMutableArray  *graduateList;  // list holding the graduate filling graphic objects
    BOOL            graduateDirty;  // if we must update the graduateList (calculate the graduate filling new)
    NSRect          coordBounds;    // our coord bounding box
}

/* class methods */
+ (VPolyLine*)polyLine;

/* line methods */
- (int)ptsCount;
- (void)setFilled:(BOOL)flag;
- (BOOL)filled;
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
- (BOOL)closed; // whether PolyLine is closed (end point fits start point)
- (NSPoint)nearestPointInPtlist:(int*)pt_num distance:(float*)distance toPoint:(NSPoint)pt;
- (void)addPoint:(NSPoint)p;
- (VGraphic*)addPointAt:(NSPoint)pt;
- (void)addPoint:(NSPoint)pt atNum:(int)pt_num;
- (BOOL)removePoint:(NSPoint)pt;
- (BOOL)removePointWithNum:(int)pt_num;
- (void)truncate;
- (void)getEndPoints:(NSPoint*)p1 :(NSPoint*)p2;
- (float)length;
- (void)setDirectionCCW:(BOOL)ccw;
- (void)changeDirection;
- (void)changePoint:(int)pt_num :(NSPoint)pt;
- (NSPoint)gradientAt:(float)t;
- (BOOL)isPointInside:(NSPoint)p;
- (int)isPointInsideOrOn:(NSPoint)p;
- (int)selectedKnobIndex;
- (NSPoint)appendToBezierPath:(NSBezierPath*)bPath currentPoint:(NSPoint)currentPoint;
- (id)contour:(float)w inlay:(BOOL)inlay splitCurves:(BOOL)splitCurves;
- (void)join:obj;
- (VPath*)pathRepresentation;
- (int)intersections:(NSPoint**)pArray withRect:(NSRect)rect;

@end

#endif // VHF_H_VPOLYLINE
