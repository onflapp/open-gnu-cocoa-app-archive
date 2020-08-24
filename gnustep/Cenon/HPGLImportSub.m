/* HPGLImportSub.m
 * Subclass of HPGL-import managing the creation of graphic objects
 *
 * Copyright (C) 1996-2005 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1996-05-03
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

#include <VHFShared/vhfCommonFunctions.h>
#include <VHFShared/types.h>
#include "HPGLImportSub.h"
#include "Graphics.h"

@implementation HPGLImportSub

/* allocate a list
 */
- allocateList
{
    return [[NSMutableArray allocWithZone:[self zone]] init];
}

/* allocate a filled path object
 * copy the objects in aList to this object, add the group to bList
 */
- (void)addFillList:aList toList:bList
{   VPath   *g = [VPath path];

    [g addList:aList at:[[g list] count]];
    [g setFilled:YES];
    [g setWidth:state.width];
    [g setColor:state.color];
    [g setFillColor:[state.color copy]];
    [bList addObject:g];
}

/* allocate a group object
 * copy the objects in aList to the group, add the group to bList
 */
- (void)addStrokeList:aList toList:bList
{   VPath       *g = [VPath path];

    [g addList:aList at:[[g list] count]];
    [g setFilled:NO];
    [g setColor:state.color];
    [g setWidth:state.width];
    [bList addObject:g];
}

/* allocate a line object and add it to aList
 */
- (void)addLine:(NSPoint)beg :(NSPoint)end toList:aList
{   VLine	*g = [VLine line];

    [g setVertices:beg :end];
    [g setWidth:state.width];
    [g setColor:state.color];
    [aList addObject:g];
}

/* allocate an arc object and add it to aList
 * center is the center of the arc
 * start is the start point
 * angle is the angle (negative for clockwise direction and positive for ccw direction)
 */
- (void)addArc:(NSPoint)center :(NSPoint)start :(float)angle toList:aList
{   VArc	*g = [VArc arc];

    [g setCenter:center start:start angle:angle];
    [g setWidth:state.width];
    [g setColor:state.color];
    [g setFillColor:[state.color copy]];
    [aList addObject:g];
}

/* allocate a curve object and add it to aList
 */
- (void)addCurve:(NSPoint)p0 :(NSPoint)p1 :(NSPoint)p2 :(NSPoint)p3 toList:aList
{   VCurve	*g = [VCurve curve];

    [g setVertices:p0 :p1 :p2 :p3];
    [g setWidth:state.width];
    [g setColor:state.color];
    [aList addObject:g];
}

/* allocate a text object and add it to aList
 * parameter:	text	the text string
 *			font	the font name, (make a copy if you want to keep it)
 *			angle	rotation angle
 *			size	the font size in pt
 *			ar		aspect ratio height/width
 *			aList	the destination list
 */
- (void)addText:(NSString*)text :(NSString*)font :(float)angle :(float)size :(float)ar at:(NSPoint)p toList:aList;
{   id		fontObject;
    VText	*g = (VText*)[VText graphic];

    [g setColor:state.color];
    [g setFillColor:[state.color copy]];
    if (!(fontObject = [NSFont fontWithName:font size:size]))
        fontObject = [NSFont userFixedPitchFontOfSize:size];	// default
    [g setFont:fontObject];
    [g setString:text];
    [g setRotAngle:angle];
    [g setBaseOrigin:p];
    [g setAspectRatio:ar];
    [aList addObject:g];

    //	[super addText:text :font :angle :size :ar at:p toList:aList];
}

/* set the bounds
 * we move the graphic to 0/0
 */
- (void)setBounds:(NSRect)bounds
{   int			i;
    NSPoint		p;
    NSMutableArray	*array = [self list];

    p.x = - bounds.origin.x + MMToInternal(10.0);
    p.y = - bounds.origin.y + MMToInternal(10.0);
    for (i=[array count]-1; i>=0; i--)
        [[array objectAtIndex:i] moveBy:p];
}

@end
