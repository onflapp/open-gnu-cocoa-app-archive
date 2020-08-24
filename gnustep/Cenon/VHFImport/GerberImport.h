/* GerberImport.m
 * Gerber import object (RS274X)
 *
 * Copyright (C) 1996-2003 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *           Ilonka Fleischmann
 *
 * created:  1996-05-03
 * modified: 2003-06-26
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

#define	Gerber_LINE	0
#define	Gerber_ARC	1
#define	Gerber_PATH	2

#define	POLYGON_MODE	1

typedef struct _GerberState
{
    NSColor 	*color;			/* color of object */
    float	width;			/* width of object */

    int		tool;
    int		pa;			/* 1 = absolut, otherwise relative point */
    NSPoint	point;			/* current point */
    int		g;			/* current graphic (Gerber_LINE, Gerber_ARC) */
    float	x, y, i, j;		/* new data */
    int		lightCode;		/* 1 = on, 2 = off, 3 = flash */
    int		inch;			/* inch or mm */
    NSPoint	formatX;
    NSPoint	formatY;		/* format in which values are .. */
    int		zeros;			// 1 = omit leading, 2 = omit trailing (if LTD zeros are omitted see FS)
    int		pos;			/* if image polarity is positive or negative(white pads etc) */
    int		draw;			/* if we have to draw now */
    int		LPC;			/* current layer polarity (dark or clear) */
    int		LPCSet;			/* if LPC was one time clear we must remove hidden areas */
    int		path;			/* if we are in path mode */
    int		ipolFull;		/* full (1) arc interpolytion or quarter (0)*/
    int		ccw;			/* counterclockwise (1) arc interpolation or clockwise (0)*/
}GerberState;

typedef struct _GerberOps
{
    NSString		*init,
                        *reset,
                        *selectTool,
                        *selectTool2,
                        //*circle,
                        //*arc,
                        *plotAbs,
                        *plotRel,
                        *flash,
                        *move,
                        *draw,
                        *flash03,
                        *move02,
                        *draw01,
                        *coordX,
                        *coordY,
                        *coordI,
                        *coordJ,
                        *termi,
                        *polyBegin,
                        *polyEnd,
                        *comment,
                        *line,
                        *ipolQuarter,
                        *ipolFull,
                        *circleCW,
                        *circleCCW,
                        *RS274X;
   //NSCharacterSet	*beginNew;
}GerberOps;

@interface GerberImport:NSObject
{
    NSCharacterSet	*digitsSet, *invDigitsSet;
    //NSString		*data;
    id			list;		/* the base list for all contents */
    NSString		*typeL;		/* "trace/line" */
    NSString		*typeP;		/* "flash/pad" */
    NSString		*typeA;		/* "both" */
    NSString		*formC;		/* "circle" */
    NSString		*formR;		/* "rectangle" */
    NSString		*formO;		/* "octagon" */
    NSString		*formOR;	/* "Obround" */
    NSString		*formM;		/* "Makro" */
    NSString		*formP;		/* "Polygon" */
    NSMutableArray	*tools;		/* tools */
    GerberState		state;		/* the current state */
    GerberOps		ops;
    NSPoint		ll, ur;		/* bounds */
    float		res;		/* device resolution in pixel per inch */
}

- (void)setDefaultParameter;

/* load parameter file
 */
- (BOOL)loadParameter:(NSString*)fileName;

/* load aperture table
 */
- (BOOL)loadApertures:(NSString*)fileName;
- (BOOL)loadRS274XApertures:(NSData*)data;

/* start import
 */
- importGerber:(NSData*)gerberStream;

/* free import object
 * no graphic objects (line, curve) will be freed
 * the list returned by importGerber will not be freed either
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
- (void)addRect:(NSPoint)origin :(NSSize)size filled:(BOOL)fill toList:aList;
- (void)addCircle:(NSPoint)center :(float)radius filled:(BOOL)fill toList:aList;
- (void)addOctagon:(NSPoint)center :(float)radius filled:(BOOL)fill toList:aList;
- (void)addObround:(NSPoint)center :(float)width :(float)height filled:(BOOL)fill toList:aList;
- (void)addPolygon:(NSPoint)center :(float)width :(int)sides filled:(BOOL)fill toList:aList;
- (void)addArc:(NSPoint)center :(NSPoint)start :(float)angle toList:aList;
- (void)addCurve:(NSPoint)p0 :(NSPoint)p1 :(NSPoint)p2 :(NSPoint)p3 toList:aList;
- (void)addText:(NSString*)text :(NSString*)font :(float)angle :(float)size :(float)ar at:(NSPoint)p toList:aList;
- (void)addStrokeList:aList toList:bList;
- (void)addFillList:aList toList:bList;
- (void)addFillPath:aList toList:bList;
- (void)changeListPolarity:bList bounds:(NSRect)bounds;
- (void)removeClearLayers:bList;
- (void)moveListBy:(NSPoint)pt :aList;
- (void)setBounds:(NSRect)bounds;

@end
