/* VLine.m
 * 2-D Line object
 *
 * Copyright (C) 1996-2008 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1996-01-19
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

#ifndef VHF_H_VLINE
#define VHF_H_VLINE

#include "VGraphic.h"

#define  PTS_LINE	2

@interface VLine:VGraphic
{
    NSPoint	p0, p1;         // the vertices of the line
    int		selectedKnob;   // index of the selected knob (0 - 3 or -1)
}

/* class methods */
+ (VLine*)line;
+ (VLine*)lineWithPoints:(NSPoint)p0 :(NSPoint)p1;

/* line methods */
- (void)setVertices:(NSPoint)pv0 :(NSPoint)pv1;
- (void)getVertices:(NSPoint*)pv0 :(NSPoint*)pv1;
- (void)setAngle:(float)angle;
- (float)angle;
- (void)setLength:(float)length;
- (float)length;
- (void)changeDirection;
- (void)changePoint:(int)pt_num :(NSPoint)pt;
- (NSPoint)gradientAt:(float)t;
- (int)selectedKnobIndex;
- (NSPoint)appendToBezierPath:(NSBezierPath*)bPath currentPoint:(NSPoint)currentPoint;
- (int)intersectLine:(NSPoint*)pArray :(NSPoint)pl0 :(NSPoint)pl1;

@end

#endif // VHF_H_VLINE
