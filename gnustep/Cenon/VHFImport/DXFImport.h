/* DXFImport.h
 * DXF import object
 *
 * Copyright (C) 1996-2011 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1996-05-01
 * modified: 2011-04-04 (DXFGroup: z coordinates added)
 *           2009-02-06 (parameter for extrusion direction added)
 *
 * This file is part of the vhf Import Library.
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

#include <Foundation/Foundation.h>
#include <AppKit/NSColor.h>
#include "../VHFShared/types.h"

#define	MODE_NORMAL	0
#define	MODE_VERTEX	1

#define	MODE_CLOSED	1

/* layer flags */
#define LAYERFLAG_FROZEN	1
#define LAYERFLAG_FROZENNEW	2
#define LAYERFLAG_LOCKED	4

typedef struct _DXFGroup
{
    NSString    *text;
    NSString    *name;
    NSString    *layer;
    NSString    *handle;
    int         lineType;
    float       x0, y0, z0;
    float       x1, y1, z1;
    float       x2, y2, z2;
    float       x3, y3, z3;
    float       width;
    float       endWidth;
    float       a;
    float       begAngle, endAngle;
    int         color;
    int         more;
    int         flags;
    int         genFlags;
    float       adjust;
    int         numGrp;
    float       extX, extY, extZ;   // extrusion direction
}DXFGroup;

typedef struct _DXFState
{
    NSColor     *color;         // color of object
    float       width;          // width of object

    int         mode;           // mode for loop in svDXFGetGraphicFromData
    float       begWidth, endWidth;	// begin and end width for polylines
    float       bw, ew;         // begin and end width for vertex elements
    NSPoint     point;          // coordinates, used in polyline
    float       A;              // Ausbuchtung for vertex
    int         id;             // id, used in vertex elements
    NSPoint     first;          // for vertex, the first coordinate for close
    int         modeClosed;     // for vertex to close

    NSPoint     offset;         // offset to move inserts by
    float       rotAngle;       // angle to rotate inserts by
}DXFState;

@interface DXFImport:NSObject
{
    id          list;           // the base list for all contents
    DXFState    state;          // the current gstate
    NSPoint     extMin, extMax; // bounds from header
    NSPoint     ll, ur;         // bounds of data
    float       res;            // device resolution in pixel per inch
    NSArray     *table;         // layer table
    NSArray     *visibleList;   // array of visible objects (from IDBUFFER) or nil for all visible
    DXFGroup    group;          // contents of current group

    NSScanner   *blockScanner;  // global block scanner
}

/* start import
 */
- (void)setRes:(float)rs;
- importDXF:(NSData*)dxfData;

/* dealloc import object
 */
- (void)dealloc;

/* methods needed to be sub classed
 *
 * create and return a list of the layers
 *  - allocateList:(NSArray*)layers
 * make a line-object and add it to aList or layer
 *  - addLine:(NXPoint)beg :(NXPoint)end toList:aList
 *  - addLine:(NXPoint)beg :(NXPoint)end toLayer:layerName
 * make a arc-object and add it to aList or layer
 *  - (void)addArc:(NSPoint)center :(NSPoint)start :(float)angle toList:aList
 *  - (void)addArc:(NSPoint)center :(NSPoint)start :(float)angle toLayer:layerName
 * make a curve-object and add it to aList or layer
 *  - addCurve:(NXPoint)p0 :(NXPoint)p1 :(NXPoint)p2 :(NXPoint)p3 toList:aList
 *  - addCurve:(NXPoint)p0 :(NXPoint)p1 :(NXPoint)p2 :(NXPoint)p3 toLayer:layerName
 * make a text-object and add it to layer
 * - addText:(NSString*)text :(NSString*)font :(NXCoord)angle ofSize:(NXCoord)size :ar at:(NXPoint)p toLayer:layerName
 * add aList as a stroked path to layer
 *  - addStrokeList:aList toLayer:layerName
 * add aList as a filled path to layer
 *  - addFillList:aList toLayer:layerName
 */
- (id)allocateList:(NSArray*)layers;
- (void)addLine:(NSPoint)beg :(NSPoint)end toList:(NSMutableArray*)aList;
- (void)addLine3D:(V3Point)beg :(V3Point)end toList:(NSMutableArray*)aList;
- (void)addLine:(NSPoint)beg :(NSPoint)end toLayer:(NSString*)layerName;
- (void)addLine3D:(V3Point)beg :(V3Point)end toLayer:(NSString*)layerName;
- (void)addArc:(NSPoint)center :(NSPoint)start :(float)angle toList:(NSMutableArray*)aList;
- (void)addArc:(NSPoint)center :(NSPoint)start :(float)angle toLayer:(NSString*)layerName;
- (void)addCurve:(NSPoint)p0 :(NSPoint)p1 :(NSPoint)p2 :(NSPoint)p3 toList:(NSMutableArray*)aList;
- (void)addCurve:(NSPoint)p0 :(NSPoint)p1 :(NSPoint)p2 :(NSPoint)p3 toLayer:(NSString*)layerName;
- (void)add3DFace:(V3Point*)pts toLayer:(NSString*)layerName;
- (void)addText:(NSString*)text :(NSString*)font :(float)angle :(float)size :(float)ar :(int)alignment at:(NSPoint)p toLayer:(NSString*)layerName;
- (void)addStrokeList:aList toLayer:(NSString*)layerName;
- (void)addFillList:aList toLayer:(NSString*)layerName;
- (void)setBounds:(NSRect)bounds;

@end
