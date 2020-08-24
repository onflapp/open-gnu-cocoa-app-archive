/* VPath.h
 * complex path
 *
 * Copyright (C) 1996-2011 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1996-01-19
 * modified: 2011-04-07
 *           2008-07-25 (-contour:useRaster:)
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

#ifndef VHF_H_VPATH
#define VHF_H_VPATH

#include "VGraphic.h"

@interface VPath:VGraphic
{
    NSMutableArray	*list;          // list holding the graphic objects
    int			filled;             // 1 = close and fill 2 = close and graduated filled
    int			selectedObject;
    NSColor		*fillColor;         // fillColor if we are filled
    NSColor		*endColor;          // endColor if we are graduated/radial filled
    float		graduateAngle;      // angle of graduate filling
    float		stepWidth;          // stepWidth the color will change by graduate/radial filling
    NSPoint		radialCenter;       // the center position for radial filling in percent to the bounds
    NSMutableArray	*graduateList;  // list holding the graduate filling graphic objects
    BOOL		graduateDirty;      // if we must update the graduateList (calculate the graduate filling new)
    NSRect		coordBounds;        // our coord bounding box
    NSRect		bounds;             // our bounding box
}

+ (VPath*)path;
+ (VPath*)pathWithBezierPath:(NSBezierPath*)bezierPath;

/* path methods
 */
- (void)setRectangle:(NSPoint)ll :(NSPoint)ur;
- (id)unnest;
- (NSMutableArray*)list;
- (void)setList:aList;
- (void)setList:aList optimize:(BOOL)optimize;
- (unsigned)count;
- (unsigned)countRecursive;
- (void)getEndPoints:(NSPoint*)p1 :(NSPoint*)p2;
- (int)selectedKnobIndex;
- (void)deselectAll;

- (void)setFilled:(BOOL)flag optimize:(BOOL)optimize;
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
- (NSMutableArray*)graduateList;

- (float)lengthFrom:(int)frIx to:(int)toIx; // return length of sub-path

- (BOOL)closed;
- (void)closePath;
- (void)addList:(NSArray*)addList at:(int)index;
- (void)sortList;
- (void)complexJoin:(NSMutableArray*)jlist distance:(float)dist;
- (void)join:obj;
- (void)splitTo:ulist;
- (void)setSize:(NSSize)size;
- (NSSize)size;
- (void)setBoundsZero;
- (NSPoint)nearestPointOnObject:(int*)objIndex distance:(float*)distance toPoint:(NSPoint)pt;
- (VGraphic*)addPointAt:(NSPoint)pt;
- (int)changedValuesForRemovePointUndo:(int*)changedIx :(int*)chPt_num :(NSPoint*)changedPt;
- (BOOL)removeGraphicsAroundPoint:(NSPoint)pt andIndex:(int)oldIndex;
- (BOOL)removePointWithNum:(int)pt_num;
//- (void)transferSubGraphicsTo:(NSMutableArray *)array at:(int)position;
- (void)drawGraduatedWithPrincipal:principal;
- (void)drawRadialWithPrincipal:principal;
- (void)drawAxialWithPrincipal:principal;
- (BOOL)isPointInside:(NSPoint)p;
- (int)isPointInsideOrOn:(NSPoint)p;
- (BOOL)pointArrayHitsCorner:(NSPoint*)pts :(int)ptsCnt;
- (void)pointWithNumBecomeStartPoint:(int)pt_num;   // makes point the start point of the path
- (void)setDirectionCCW:(BOOL)ccw;
- (BOOL)intersects:g;
- (BOOL)optimizePath:(float)w;
- (id)contour:(float)w useRaster:(BOOL)useRaster;
- (id)contour:(float)w inlay:(BOOL)inlay splitCurves:(BOOL)splitCurves useRaster:(BOOL)useRaster;
- (id)contour:(float)w inlay:(BOOL)inlay splitCurves:(BOOL)splitCurves;
- (id)contourOpen:(float)w;
- (id)clippedWithRect:(NSRect)rect close:(BOOL)close;
- (void)optimizeList:(NSMutableArray*)olist;
- (id)clippedFrom:(VGraphic*)cg;
- (VPath*)contourWithPixel:(float)w;

- (int)getLastObjectOfSubPath2:(int)startIx;        // work with open paths
- (int)getLastObjectOfSubPath:(int)startIx;
- (int)directionOfSubPath:(int)startIx :(int)endIx;
- (NSRect)coordBoundsOfSubPath:(int)startIx :(int)endIx;
- (BOOL)subPathInsidePath:(int)begIx :(int)endIx;

- (void)movePoint:(int)pt_num to:(NSPoint)p control:(BOOL)control;

@end

#endif // VHF_H_VPATH
