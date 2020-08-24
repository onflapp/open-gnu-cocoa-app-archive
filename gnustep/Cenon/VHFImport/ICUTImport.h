/* ICUTImport.h
 * i-cut import object
 *
 * Copyright (C) 2012 by vhf interservice GmbH
 * Author:   Ilonka Fleischmann
 *
 * created:  2011-09-16
 * modified: 2012-06-22 (shape added, any layer with names possible)
 *           2011-09-16
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

#define	ICUT_LINE	0
#define	ICUT_CURVE	1

#define	POLYGON_MODE	1

typedef struct _ICUTState
{
    int			mode;               // Open or Closed Path
    int			path;               // path or end of path
    int			pindex;             // 0 - 3
    NSPoint		p0, p1, p2, p3;		// scaling points
}ICUTState;

#define ICUT_InitOps() (icutOps){0, 0, 0, 0, 0, 0, 0, 0}
typedef struct _ICUTOps
{
    NSString	*moveto,
                *lineto,
                *regmark,
                *shape,
                *corner,
                *bezier,
                *open,
                *closed,
                *cutcontour,
                *comma,
                *termi;
}ICUTOps;

@interface ICUTImport:NSObject
{
    NSCharacterSet	*digitsSet, *invDigitsSet, *jumpSet, *termiSet, *newLineSet;
    id              list;			/* the base list for all contents */
    ICUTState		state;			/* the current state */
    ICUTOps         ops;
    NSPoint         ll, ur;			/* bounds */
    BOOL            fillClosedPaths;
    BOOL            originUL;
    int             unit;			/* unit */
}

/* start import
 */
- importICUT:(NSData *)icutData;

/* the graphics list
 */
- (id)list;

- (void)fillClosedPaths:(BOOL)flag;
- (void)originUL:(BOOL)flag;

/* free import object
 * no graphic objects (line, curve) will be freed
 * the list returned by importHPGL will not be freed either
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
- (void)addLine:(NSPoint)beg :(NSPoint)end toLayer:(NSString*)layerName;
- (void)addLine:(NSPoint)beg :(NSPoint)end toList:(NSMutableArray*)aList;
//- (void)addArc:(NSPoint)center :(NSPoint)start :(float)angle toList:aList;
- (void)addCurve:(NSPoint)p0 :(NSPoint)p1 :(NSPoint)p2 :(NSPoint)p3 toLayer:(NSString*)layerName;
- (void)addCurve:(NSPoint)p0 :(NSPoint)p1 :(NSPoint)p2 :(NSPoint)p3 toList:(NSMutableArray*)aList;
- (void)addMark:(NSPoint)origin toLayer:(NSString*)layerName;
- (void)addMark:(NSPoint)origin toList:(NSMutableArray*)aList;
- (void)addRect:(NSPoint)origin :(NSPoint)rsize toLayer:(NSString*)layerName;
- (void)addRect:(NSPoint)origin :(NSPoint)rsize toList:(NSMutableArray*)aList;
//- (void)addText:(NSString*)text :(NSString*)font :(float)angle :(float)size :(float)ar at:(NSPoint)p toList:aList;
- (void)addStrokeList:aList toLayer:(NSString*)layerName;
- (void)addStrokeList:aList toList:(NSMutableArray*)bList;
- (void)addFillList:aList toLayer:(NSString*)layerName;
- (void)addFillList:aList toList:(NSMutableArray*)bList;
- (void)setBounds:(NSRect)bounds;

@end
