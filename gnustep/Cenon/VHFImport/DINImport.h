/* DINImport.h
 * DIN import object (drill data)
 *
 * Copyright (C) 1996-2012 by vhf interservice GmbH
 * Author:   Ilonka Fleischmann
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

#define	DIN_LINE        1
#define	DIN_ARC         2
#define	DIN_PATH        3

#define	DIN_SM1000		1
#define	DIN_SM3000		2
#define	DIN_EXCELLON	3

typedef struct _DINState
{
    NSColor     *color;		/* color of object */
    float       width;		/* width of object */

    int         tool;
    int         pa;			/* 1 = absolut, otherwise relative point */
    NSPoint     point;		/* current point */
    int         g;			/* current graphic (Gerber_LINE, Gerber_ARC) */
    float       x, y, a, c; /* new data */
    int         inch;		/* inch or mm */
    NSPoint     formatX;
    NSPoint     formatY;	/* format in which values are .. */
    int         zeros;		/* if LTD zeros are omitted see FS */
    int         draw;		/* if we have to draw now */
    int         ccw;		/* counterclockwise (1) arc interpolation or clockwise (0)*/
    int         path;		/* if we are in path mode */
    int         offset;		/* if offset is set */
}DINState;

typedef struct _DINOps
{
    NSString    *init,
                *reset,
                *selectTool,
                *plotAbs,
                *plotRel,
                *coordX,
                *coordY,
                *coordR,
                *coordC,
                *termi,
                *polyBegin,
                *polyBegin2,
                *polyEnd,
                *comment,
                *line,
                *circleCW,
                *circleCCW,
                *start,
                *drill,
                *mm,
                *prgend,
                *offset;
}DINOps;

@interface DINImport:NSObject
{
    NSCharacterSet  *digitsSet, *invDigitsSet, *termiSet;
    id              list;           /* the base list for all contents */
    NSMutableArray  *tools;         /* tools */
    DINState		state;          /* the current state */
    DINOps          ops;
    NSPoint         ll, ur;         /* bounds */
    float           res;            /* device resolution in dots per inch */
    float           resMM;
    BOOL            tz;             // trailing zeros
    BOOL            fileFormat;     /* flag which file format we got */
    BOOL            parameterLoaded; /* flag if we allways load the parameter (for default) */
}

- (void)setDefaultParameter;

/* load parameter file */
- (BOOL)loadParameter:(NSString*)fileName;

/* start import */
- importDIN:(NSData*)DINStream;

/* free import object
 * no graphic objects (line, curve) will be freed
 * the list returned by importGerber will not be freed either
 */
- (void)dealloc;

/* methods needed to be sub classed
 *
 * allocate an array holding the graphic objects:
 *  - allocateList;
 * make a mark-object and add it to aList
 *  - addMark:(NXPoint)pt withDiameter:(float)dia toList:aList;
 */
- (id)allocateList;
- (void)addMark:(NSPoint)pt withDiameter:(float)dia toList:aList;
- (void)addLine:(NSPoint)beg :(NSPoint)end toList:aList;
- (void)addCircle:(NSPoint)center :(float)radius filled:(BOOL)fill toList:aList;
- (void)addArc:(NSPoint)center :(NSPoint)start :(float)angle toList:aList;
- (void)addFillList:aList toList:bList;
- (void)setBounds:(NSRect)bounds;

@end
