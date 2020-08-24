/* PSImport.h
 * PostScript import object
 *
 * Copyright (C) 1996-2011 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1996-01-25
 * modified: 2005-11-19
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

#define PS_TMPPATH	@"/tmp"	// path to directory for temporary files

/* you can use the state to get width and color
 * but you must not change it
 */
typedef struct _PSState
{
    NSColor	*color;		/* color */
    float	width;		/* line width */
    id		*clipList;	/* list of lists representing the active clipping path */
}PSState;

@interface PSImport:NSObject
{
    NSCharacterSet	*coordinateSet, *invCoordinateSet;
    id			target;		/* the target object */
    //NSArray		*states;	/* the states */
    id			list;		/* the base list for all contents */
    PSState		state;		/* the current gstate */
    NSPoint		ll, ur;		/* bounds */
    BOOL		flattenText;	/* whether we have to flatten the text */
    BOOL		preferArcs;	/* whether to build arcs from curves if possible */
}

/* whether we have to flatten the text, default = NO
 */
- (void)flattenText:(BOOL)flag;
/* we want arcs rather than curves
 */
- (void)preferArcs:(BOOL)flag;

- (NSString*)gsPath;

/* start import
 */
- importPDFFromFile:(NSString*)pdfFile;
- importPDF:(NSData*)pdfData;
- importPS:(NSData*)psStream;

/* this method builds the bounds of the graphic
 * in case of text it may be useful to set this from the sub class
 */
- (void)updateBounds:(NSPoint)p;

/* dealloc ps-import object
 * no graphic objects (line, curve) will be dealloced
 * the list returned by importPS will not be dealloced either
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
