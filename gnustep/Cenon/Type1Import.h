/* Type1Import.h
 * Import class for Type1 fonts
 *
 * Copyright (C) 2000 - 2005 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  2000-11-14
 * modified: 2005-01-06
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

#ifndef VHF_H_TYPE1IMPORT
#define VHF_H_TYPE1IMPORT

#include <AppKit/AppKit.h>
#include "type1Funs.h"
#include "Type1Font.h"

/* you can use the state to get width and color
 * but you must not change it
 */
typedef struct _Type1State
{
    NSColor	*color;		/* color */
    float	width;		/* line width */
}Type1State;

@interface Type1Import:NSObject
{
    Type1Font		*fontObject;
    id			list;		/* the base list for all contents */
    id			pList;		/* the current polygon list */
    Type1State		state;		/* the current gstate */
    NSPoint		ll, ur;		/* bounds */
    float		gridOffset;

//    T1FontInfo		fontInfo;
//    char		*fontName;
    int			encodingCnt;
    Encoding		*encoding;
//    int			paintType;
//    int			fontType;
//    float		fontMatrix[6];
//    float		fontBBox[4];
//    long		uniqueID;
    //metrics;
    int			strokeWidth;
    Private		privateDict;  // need only subrs
    int			charStringCnt;
    CharStrings		charStrings[256];
    //FID;
}

/* start import
 */
- importType1:(NSData*)psStream;

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
- allocateFontObject;
- allocateList;
- (void)addLine:(NSPoint)beg :(NSPoint)end toList:aList;
- (void)addArc:(NSPoint)center :(NSPoint)start :(float)angle toList:aList;
- (void)addCurve:(NSPoint)p0 :(NSPoint)p1 :(NSPoint)p2 :(NSPoint)p3 toList:aList;
- (void)addStrokeList:aList toList:bList;
- (void)addFillList:aList toList:bList;
- (void)addText:(NSString*)text :(NSString*)font :(float)angle :(float)size :(float)ar at:(NSPoint)p toList:aList;
- (void)setBounds:(NSRect)bounds;

@end

#endif // VHF_H_TYPE1IMPORT
