/* ICUTImportSub.m
 * Subclass of icut-import managing the creation of graphic objects
 *
 * Copyright (C) 1996-2005 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  2011-09-16
 * modified: 2012-06-22 (shape added, any layer with names possible)
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
#include "ICUTImportSub.h"
#include "Graphics.h"
#include "DocView.h"

@implementation ICUTImportSub

/* allocate a list
 */
- allocateList
{
    layerList = [[NSMutableArray allocWithZone:[self zone]] init];

    {   LayerObject	*layerObject = [LayerObject layerObject];

        [layerObject setString:@"Kamera Marker"];
        [layerObject setType:LAYER_CAMERA];
        [layerList addObject:layerObject];
    }
    return layerList;
}

- (NSMutableArray*)layerArrayWithName:(NSString*)name
{   int	l;

    if (!layerList)
        layerList = [[NSMutableArray allocWithZone:[self zone]] init];
    if (!name)
        name = ops.cutcontour;

    if (![layerList count])
    {   LayerObject	*layerObject = [LayerObject layerObject];

        [layerObject setString:@"Kamera Marker"];
        [layerObject setType:LAYER_CAMERA];
        [layerList addObject:layerObject];
    }

    for (l=0; l<(int)[layerList count]; l++)
        if ([[[layerList objectAtIndex:l] string] isEqual:name])
            return [[layerList objectAtIndex:l] list];

    /* not yet in layerList */
    {   LayerObject	*layerObject = [LayerObject layerObject];

        [layerObject setString:name];
        [layerList insertObject:layerObject atIndex:0];
        return [layerObject list];
    }
    return nil;
}


/* add list as filled path to layer
 * we simply add everything in a single list ignoring all layers
 */
- (void)addFillList:aList toLayer:(NSString*)layerName
{   NSMutableArray  *array = [self layerArrayWithName:layerName];
    VPath           *g = [VPath path];

    if (!array)
        array = [[layerList objectAtIndex:0] list];
    [g addList:aList at:[[g list] count]];
    [g setFilled:YES];
    [array addObject:g];
}
/* allocate a filled path object
 * copy the objects in aList to this object, add the group to bList
 */
- (void)addFillList:aList toList:(NSMutableArray*)bList
{   VPath   *g = [VPath path];

    [g addList:aList at:[(NSArray*)[g list] count]];
    [g setFilled:YES];
    [bList addObject:g];
}

/* add list as filled path to layer
 * we simply add everything in a single list ignoring all layers
 */
- (void)addStrokeList:(NSArray*)aList toLayer:(NSString*)layerName
{   NSMutableArray  *array = [self layerArrayWithName:layerName];
    VPath           *g = [VPath path];

    if (!array)
        array = [[layerList objectAtIndex:0] list];
    if ( [aList count] == 1 )
        g = [aList objectAtIndex:0];
    else
    {   [g addList:aList at:[[g list] count]];
        [g setFilled:NO];
    }
    [array addObject:g];
}
/* allocate a group object
 * copy the objects in aList to the group, add the group to bList
 */
- (void)addStrokeList:(NSArray*)aList toList:(NSMutableArray*)bList
{   VPath   *g = [VPath path];

    if ( [aList count] == 1 )
        g = [aList objectAtIndex:0];
    else
    {   [g addList:aList at:[[g list] count]];
        [g setFilled:NO];
    }
    [bList addObject:g];
}

- (void)addLine:(NSPoint)beg :(NSPoint)end toLayer:(NSString*)layerName
{   NSMutableArray	*array = [self layerArrayWithName:layerName];
    VLine		*g;

    if (!array)
        array = [[layerList objectAtIndex:0] list];
    g = [VLine line];
    [g setVertices:beg :end];
    [array addObject:g];
}
/* allocate a line object and add it to aList
 */
- (void)addLine:(NSPoint)beg :(NSPoint)end toList:(NSMutableArray*)aList
{   VLine	*g = [VLine line];

    [g setVertices:beg :end];
    [aList addObject:g];
}

/* allocate an mark object and add it to aList
 */
 - (void)addMark:(NSPoint)origin toLayer:(NSString*)layerName
{   NSMutableArray	*array = [self layerArrayWithName:@"Kamera Marker"]; // allways to Kamera Marker
    VArc	*g = [VMark markWithOrigin:origin diameter:MMToInternal(5.0)];
    int     i, cnt = 0;
    BOOL    DoNotAdd = NO;

    if (!array)
        array = [[layerList objectAtIndex:0] list];
    cnt = [array count];
    /* check if allready in list */
    for (i=0; i < cnt ; i++)
    {   NSPoint originGr = [[array objectAtIndex:i] pointWithNum:0];

        if ( SqrDistPoints(origin, originGr) < TOLERANCE )
        {   DoNotAdd = YES;
            break;
        }
    }
    if ( !DoNotAdd )
        [array addObject:g];
}
- (void)addMark:(NSPoint)origin toList:(NSMutableArray*)aList
{   VArc	*g = [VMark markWithOrigin:origin diameter:MMToInternal(5.0)];
    int     i, cnt = [(NSArray*)aList count];
    BOOL    DoNotAdd = NO;

    /* check if allready in list */
    for (i=0; i < cnt ; i++)
    {   NSPoint originGr = [[aList objectAtIndex:i] pointWithNum:0];

        if ( SqrDistPoints(origin, originGr) < TOLERANCE )
        {   DoNotAdd = YES;
            break;
        }
    }
    if ( !DoNotAdd )
        [aList addObject:g];
}

- (void)addRect:(NSPoint)origin :(NSPoint)rsize toLayer:(NSString*)layerName
{   NSMutableArray	*array = [self layerArrayWithName:layerName];
    VRectangle	*g = [VRectangle rectangle];

    if (!array)
        array = [[layerList objectAtIndex:0] list];
    [g setVertices:origin :rsize];
    [array addObject:g];
}
- (void)addRect:(NSPoint)origin :(NSPoint)rsize toList:(NSMutableArray*)aList
{   VRectangle	*g = [VRectangle rectangle];

    [g setVertices:origin :rsize];
    [aList addObject:g];
}

/* allocate a curve object and add it to aList
 */
- (void)addCurve:(NSPoint)p0 :(NSPoint)p1 :(NSPoint)p2 :(NSPoint)p3 toLayer:(NSString*)layerName
{   NSMutableArray  *array = [self layerArrayWithName:layerName];
    VCurve          *g = [VCurve curve];

    if (!array)
        array = [[layerList objectAtIndex:0] list];
    [g setVertices:p0 :p1 :p2 :p3];
    [array addObject:g];
}
- (void)addCurve:(NSPoint)p0 :(NSPoint)p1 :(NSPoint)p2 :(NSPoint)p3 toList:(NSMutableArray*)aList
{   VCurve	*g = [VCurve curve];

    [g setVertices:p0 :p1 :p2 :p3];
    [aList addObject:g];
}

/* set the bounds
 * we move the graphic to 0/0
 */
- (void)setBounds:(NSRect)bounds
{   int			i, j;
    NSPoint		p;
    NSMutableArray	*array = [self list]; // LayerObjects !

    p.x = - bounds.origin.x + MMToInternal(10.0);
    p.y = - bounds.origin.y + MMToInternal(10.0);
    for (i=[array count]-1; i>=0; i--)
    {   NSMutableArray *llist = [[array objectAtIndex:i] list];

        for (j=[llist count]-1; j>=0; j--)
            [[llist objectAtIndex:j] moveBy:p];
    }

    if ( originUL )
    {
        bounds.origin.x += p.x;
        bounds.origin.y += p.y;
        p.x = bounds.origin.x + bounds.size.width / 2.0;
        p.y = bounds.origin.y + bounds.size.height / 2.0;

        for (i=[array count]-1; i>=0; i--)
        {   NSMutableArray *llist = [[array objectAtIndex:i] list];

            for (j=[llist count]-1; j>=0; j--)
                [[llist objectAtIndex:j] mirrorAround:p];
        }
    }
}


@end
