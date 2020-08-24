/* SVGImport.h
 * SVG import object
 *
 * Copyright (C) 2010 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  2010-07-03
 * modified: 2010-07-19
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

#include <AppKit/AppKit.h>

typedef struct _SVGState
{
    NSColor     *fillColor;     // color of object
    NSColor     *strokeColor;   // color of object
    float		width;          // width of object
}SVGState;

@interface SVGImport:NSObject
{
    id                  list;           // the root list for all contents
    NSString            *title;         // title of document
    NSPoint             ll, ur;
    NSRect              viewRect;       // bounding box in svg units
    NSSize              tgtSize;        // target size in point
    float               flipHeight;     // we have to mirror coordinate system
    double              scale;
    NSMutableDictionary *defs;          // stuff to use
    NSAffineTransform   *ctm;           // current tranformation matrix

    BOOL                closedPath;     // whether closed and suitable for fill

    NSDictionary        *attributes;
    NSMutableArray      *elementStack;  // the hierarchy of elements
    NSMutableArray      *groupStack;    // the hierarchy of groups
    id                  groupList;      // current group list
    NSString            *groupId;       // id to geuse element
    NSMutableDictionary *useDict;       // dictionary to reuse elements
    BOOL                drawElements;   // whether the current elements are for drawing
    NSString            *stringFound;

    NSMutableDictionary *style, *styleGroup;
    SVGState    state;
    SVGState    stateGroup;

    NSString    *currentElement;
    NSString    *currentElemId;
}

/* start import
 */
- importSVG:(NSData *)svgStream;

/* the graphics list
 */
- (id)list;

/* free import object
 * no graphic objects (line, curve) will be freed
 * the list returned by importSVG will not be freed either
 */
- (void)dealloc;

/* methods needed to be sub classed
 *
 * allocate an array holding the graphic objects:
 *  - allocateList;
 * make a line-object and add it to aList
 *  - addLine:(NXPoint)beg :(NXPoint)end toList:aList;
 * make a curve-object and add it to aList
 *  - addCurve:(NXPoint)p0 :(NXPoint)p1 :(NXPoint)p2 :(NXPoint)p3 toList:aList;
 * make a text-object and add it to aList
 * - addText:(NSString*)text :(NSString*)font :(NXCoord)angle ofSize:(NXCoord)size :ar at:(NXPoint)p toList:aList;
 * add aList as a stroked path to bList
 *  - addStrokeList:aList toList:bList;
 * add aList as a filled path to bList
 *  - addFillList:aList toList:bList;
 */
- (id)allocateList;
- (void)addLine:(NSPoint)beg :(NSPoint)end toList:aList;
- (void)addPolyLine:(NSPoint*)pts count:(int)pCnt toList:aList;
- (void)addRectangle:(NSRect)rect toList:aList;
- (void)addArc:(NSPoint)center :(NSPoint)start :(float)angle toList:aList;
- (void)addCurve:(NSPoint)p0 :(NSPoint)p1 :(NSPoint)p2 :(NSPoint)p3 toList:aList;
- (void)addText:(NSString*)text :(NSString*)font :(float)angle :(float)size :(float)ar at:(NSPoint)p toList:aList;
- (void)addGroupList:aList toList:bList;
- (void)addGroupList:aList toList:bList withTransform:(NSAffineTransform*)matrix;
- (void)addFillList:aList toList:bList;
- (void)setBounds:(NSRect)bounds;

@end
