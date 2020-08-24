/* HPGLImport.h
 * HPGL import object
 *
 * Copyright (C) 1996 - 2010 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1996-05-03
 * modified: 2010-07-08
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

#define MAXPEN          20

#define	HPGL_LINE       0
#define	HPGL_ARC        1

#define	POLYGON_MODE    1

typedef struct _HPGLState
{
    NSColor 		*color;		// color of object
    float		width;		// width of object

    int			pen;
    int			pd;		// 1 = draw(pen down), 2=move(pen up)
    int			pa;		// 1 = absolut, otherwise relative point
    int			relArc;		// 1 = relative arc
    NSPoint		point;		// current point
    int			g;		// current graphic (HPGL_LINE, HPGL_ARC)
    NSSize		labelSize;	// current size of labels
    float		labelDir;	// current direction of labels
    float		labelSlant;	// current slant of labels
    int			lineType;	// current line type
    float		patternLength;	// pattern length
    int			plottedLength;	// the lengh of the pattern length in % that has already been plotted
    int			mode;		// 0 or POLYGON_MODE
    NSPoint		p1, p2;		// scaling points
    int			draw;		// 1 = following coordinates are valid
}HPGLState;

#define HPGL_InitOps() (HPGLOps){0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, {0}}
typedef struct _HPGLOps
{
    NSString	*selectPen,
                *inputWindow,
                *penUp,
                *penDown,
                *circle,
                *arcAbs,
                *arcRel,
                *plotAbs,
                *plotRel,
                *polygonDef,
                *label,
                *labelSize,
                *labelDir,
                *labelSlant,
                *labelTermi,
                *inputp1p2,
                *lineType,
                *seper,
                *termi;
    //NSCharacterSet	*beginNew;
}HPGLOps;

#ifndef HPGLColor
typedef struct _HPGLColor
{	float	r, g, b;
}HPGLColor;
#endif

@interface HPGLImport:NSObject
{
    NSCharacterSet  *digitsSet, *invDigitsSet, *jumpSet, *termiSet, *labelTermiSet;
    id              list;               /* the base list for all contents */
    int             penCount;           /* number of available pens */
    HPGLColor       penColor[MAXPEN];   /* pen color in SVColor for pen numbers from 0 to penCount-1 */
    float           penWidth[MAXPEN];   /* pen width for pen numbers from 0 to penCount-1 */
    HPGLState       state;              /* the current state */
    HPGLOps         ops;
    NSPoint         ll, ur;             /* bounds */
    float           res;                /* device resolution in pixel per inch */
}

/* load parameter file
 */
- (BOOL)loadParameter:(NSString*)fileName;

/* start import
 */
- importHPGL:(NSData *)hpglStream;

/* the graphics list
 */
- (id)list;

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
- (void)addLine:(NSPoint)beg :(NSPoint)end toList:aList;
- (void)addArc:(NSPoint)center :(NSPoint)start :(float)angle toList:aList;
- (void)addCurve:(NSPoint)p0 :(NSPoint)p1 :(NSPoint)p2 :(NSPoint)p3 toList:aList;
- (void)addText:(NSString*)text :(NSString*)font :(float)angle :(float)size :(float)ar at:(NSPoint)p toList:aList;
- (void)addStrokeList:aList toList:bList;
- (void)addFillList:aList toList:bList;
- (void)setBounds:(NSRect)bounds;

@end
