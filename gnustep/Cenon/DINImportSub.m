/* DINImportSub.m
 * Subclass of DIN-import managing the creation of graphic objects
 *
 * Copyright (C) 1996-2003 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  2001-01-20
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

#include <ctype.h>
#include <VHFShared/types.h>
#include <VHFShared/vhfCommonFunctions.h>
#include "DINImportSub.h"
#include "Graphics.h"
#include "messages.h"
#include "LayerObject.h"

@implementation DINImportSub

/* created: 2001-06-06
 * performcance map is not used, because we set this later when the layers are added to the view!
 */
static NSInteger sortLayer(id l1, id l2, void *context)
{   float       d1 = 0.0, d2 = 0.0;
    VGraphic    *g0 = [[l1 list] objectAtIndex:0], *g1 = [[l2 list] objectAtIndex:0];

    if ( [g0 isKindOfClass:[VMark class]] )
        d1 = [(VMark*)g0 diameter];
    else if ( [g0 isKindOfClass:[VLine class]] || [g0 isKindOfClass:[VArc class]] )
        d1 = [g0 width];
    if ( [g1 isKindOfClass:[VMark class]] )
        d2 = [(VMark*)g1 diameter];
    else if ( [g1 isKindOfClass:[VLine class]] || [g1 isKindOfClass:[VArc class]] )
        d2 = [g1 width];

    if (d1 < d2)
        return NSOrderedAscending;
    if (d1 > d2)
        return NSOrderedDescending;
    return NSOrderedSame;
}
+ (NSArray*)layerListFromGraphicList:(NSArray*)array
{   NSMutableArray  *layerList = [NSMutableArray array];
    int             i, l;

    /* extract objects per diameter */
    for (i=0; i<(int)[array count]; i++)
    {
        for (l=0; l<(int)[layerList count]; l++)
        {   NSMutableArray  *llist = [[layerList objectAtIndex:l] list];
            VGraphic        *g0 = [llist objectAtIndex:0], *g1 = [array objectAtIndex:i];
            float           diameter0 = 0.0, diameter1 = 0.0;

            if ( [g0 isKindOfClass:[VMark class]] )
                diameter0 = [(VMark*)g0 diameter];
            else if ( [g0 isKindOfClass:[VLine class]] || [g0 isKindOfClass:[VArc class]] )
                diameter0 = [g0 width];
            if ( [g1 isKindOfClass:[VMark class]] )
                diameter1 = [(VMark*)g1 diameter];
            else if ( [g1 isKindOfClass:[VLine class]] || [g1 isKindOfClass:[VArc class]] )
                diameter1 = [g1 width];

            if ( diameter0 == diameter1 )
            {
                [llist addObject:[array objectAtIndex:i]];
                break;
            }
        }
        /* create new layer */
        if (l >= (int)[layerList count])
        {   LayerObject *layer = [LayerObject layerObject];
            float       diameter = 0.0;
            VGraphic    *g = [array objectAtIndex:i];

            if ( [g isKindOfClass:[VMark class]] )
                diameter = [(VMark*)g diameter];
            else if ( [g isKindOfClass:[VLine class]] )
                diameter = [g width];
            else if ( [g isKindOfClass:[VArc class]] )
                diameter = [g radius]*2.0;

            [layer setString:[NSString stringWithFormat:DINLAYERNAME_STRING, InternalToMM(diameter)]];
            [[layer list] addObject:[array objectAtIndex:i]];
            [layerList addObject:layer];
        }
    }

    /* sort layers */
    [layerList sortUsingFunction:sortLayer context:nil];

    return layerList;
}

/* allocate a list
 */
- allocateList
{
    return [[NSMutableArray allocWithZone:[self zone]] init];
}

- (void)addMark:(NSPoint)pt withDiameter:(float)dia toList:aList
{   id	g = [[VMark new] autorelease];

    [g setOrigin:pt];
    [g setDiameter:dia];
    [aList addObject:g];
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

- (void)addCircle:(NSPoint)center :(float)radius filled:(BOOL)fill toList:aList
{   VArc		*g;
    NSPoint	start;

    start.x = center.x + radius;
    start.y = center.y;

    g = [VArc arc];
    [g setCenter:center start:start angle:360.0];
    [g setFilled:fill];
    [g setWidth:(fill) ? 0.0 :state.width];
    [g setColor:state.color];
    [g setFillColor:[state.color copy]];
    [aList addObject:g];
}

/* allocate an arc object and add it to aList
 * center is the center of the arc
 * start is the start point
 * angle is the angle (negative for clockwise direction and positive for ccw direction)
 */
- (void)addArc:(NSPoint)center :(NSPoint)start :(float)angle toList:aList
{   VArc	*g;

    g = [VArc arc];
    [g setCenter:center start:start angle:angle];
    [g setWidth:state.width];
    [g setColor:state.color];
    [g setFillColor:[state.color copy]];
    [aList addObject:g];
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

/* set the bounds
 * we move the graphic to 0/0
 */
- (void)setBounds:(NSRect)bounds
{   int		i;
    NSPoint	p;

    p.x = - bounds.origin.x + MMToInternal(10.0);
    p.y = - bounds.origin.y + MMToInternal(10.0);
    for (i=[(NSArray*)list count]-1; i>=0; i--)
        [[list objectAtIndex:i] moveBy:p];
}

@end
