/*
 * VRectangle.h
 *
 * Copyright (C) 1996-2011 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1997-11-14
 * modified: 2008-06-08 2011-08-07 (-setDirectionCCW:)
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

#ifndef VHF_H_VRECTANGLE
#define VHF_H_VRECTANGLE

#include "VGraphic.h"
#include "VPath.h"

#define PTS_RECTANGLE	4
#define PT_LL		0
#define PT_UL		1
#define PT_UR		2
#define PT_LR		3

@interface VRectangle:VGraphic
{
    NSPoint         origin, size;   // the origin and size of the rectangle
    float           radius;         // the corner radius
    int             filled;         // 1 = fill 2 = graduated filled
    int             selectedKnob;   // index of the selected knob (0 - 3 or -1)
    float           rotAngle;       // the rotation angle
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

+ (VRectangle*)rectangle;
+ (VRectangle*)rectangleWithOrigin:(NSPoint)o size:(NSSize)s;

/* rectangle methods */
- (void)setVertices:(NSPoint)origin :(NSPoint)size;
- (void)getVertices:(NSPoint*)origin :(NSPoint*)size;
- (void)setRadius:(float)value;
- (float)radius;
- (void)setSize:(NSSize)size;
- (NSSize)size;
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
- (void)setRotAngle:(float)angle;
- (int)selectedKnobIndex;
- (VPath*)pathRepresentation;
- (NSArray*)clip:obj;
- (BOOL)isPointInside:(NSPoint)p;
- (int)isPointInsideOrOn:(NSPoint)p;
- (NSPoint)appendToBezierPath:(NSBezierPath*)bPath currentPoint:(NSPoint)currentPoint;

- (void)setDirectionCCW:(BOOL)ccw;

@end

#endif // VHF_H_VRECTANGLE
