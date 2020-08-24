/* PSImportSub.m
 * Subclass of PostScript-import managing the creation of graphic objects
 *
 * Copyright (C) 1996-2005 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1996-02-09
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

#include <VHFShared/types.h>
#include <VHFShared/vhfCommonFunctions.h>
#include "PSImportSub.h"
#include "Graphics.h"

@implementation PSImportSub

- init
{
    moveToOrigin = YES;
    return [super init];
}

- (void)moveToOrigin:(BOOL)flag
{
    moveToOrigin = flag;
}

/* allocate a list
 */
- allocateList
{
    return [[NSMutableArray alloc] init];
}

/* allocate a filled path object
 * copy the objects in aList to this object, add the group to bList
 */
- (void)addFillList:(NSArray*)aList toList:(NSMutableArray*)bList
{
    if ( [aList count] > 0 )
    {   VPath   *g = [VPath path];

        [g addList:aList at:[[g list] count]];
        [g sortList];
        [g setFilled:YES];
        [g setWidth:0.0];
        [g setColor:state.color];
        [g setFillColor:state.color];
        [g setSelected:NO];
        [bList addObject:g];
    }
}

/* allocate a path object
 * copy the objects in aList to the path, add the path to bList
 */
- (void)addStrokeList:(NSArray*)aList toList:(NSMutableArray*)bList
{
    if ([aList count] == 1)
        [bList addObject:[aList objectAtIndex:0]];
    else if ( [aList count] > 0 )
    {	VPath   *g = [VPath path];

        [g addList:aList at:[[g list] count]];
        [g sortList];
        [g setFilled:NO];
        [g setColor:state.color];
        [g setWidth:state.width];
        [g setSelected:NO];
        [bList addObject:g];
    }
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
    [g setFillColor:state.color];
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
 *		font	the font name, (make a copy if you want to keep it)
 *		angle	rotation angle
 *		size	the font size in pt
 *		ar	aspect ratio height/width
 *		aList	the destination list
 */
- (void)addText:(NSString*)text :(NSString*)font :(float)angle :(float)size :(float)ar at:(NSPoint)p toList:aList;
{   id		fontObject;
    VText	*g = [VText textGraphic];
    NSRect	bRect;

    if ( [font hasPrefix:@"_"] )	// Adobe Illustrator files redefines the fonts
        font = [font substringFromIndex:1];
    if ( !(fontObject = [NSFont fontWithName:font size:size]) )
        fontObject = [NSFont userFixedPitchFontOfSize:size];	// default
    [g setColor:state.color];
    [g setFillColor:state.color];
    [g setFont:fontObject];
    [g setString:text];
    [g setRotAngle:angle];
    [g setBaseOrigin:p];
    [g setAspectRatio:ar];
    [aList addObject:g];

    bRect = [g bounds];	/* we don't know the real text bounds, so we set it here */
    [self updateBounds:NSMakePoint(bRect.origin.x+bRect.size.width, bRect.origin.y+bRect.size.height)];

    //	[super addText:text :font :angle :size :ar at:p toList:aList];
}

/* set the bounds
 * we move the graphic to 0/0
 */
- (void)setBounds:(NSRect)bounds
{   int		i;
    NSPoint	p;
    NSRect	rect;

    if (!moveToOrigin || ![(NSArray*)list count])
        return;

    /* we overwrite the bounds and calculate our own
     * to have the real bounds of curves (not just the positions of the vertices)
     */
    bounds = [[list objectAtIndex:0] coordBounds];
    for (i=[(NSArray*)list count]-1; i>0; i--)
    {
        rect = [[list objectAtIndex:i] coordBounds];
        bounds = VHFUnionRect(rect, bounds);
    }

    p.x = - bounds.origin.x + MMToInternal(10.0);
    p.y = - bounds.origin.y + MMToInternal(10.0);
    for (i=[(NSArray*)list count]-1; i>=0; i--)
        [[list objectAtIndex:i] moveBy:p];
}

@end
