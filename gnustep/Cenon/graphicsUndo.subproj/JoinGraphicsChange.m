/* JoinGraphicsChange.m
 *
 * Copyright (C) 1993-2012 by vhf interservice GmbH
 * Authors:  Georg Fleischmann
 *
 * created:  1993
 * modified: 2012-02-28 (-undo, -redo, correct directions of graphic)
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the vhf Public License as
 * published by vhf interservice GmbH. Among other things, the
 * License requires that the copyright notices and this notice
 * be preserved on all copies.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the vhf Public License for more details.
 *
 * You should have received a copy of the vhf Public License along
 * with this program; see the file LICENSE. If not, write to vhf.
 *
 * vhf interservice GmbH, Im Marxle 3, 72119 Altingen, Germany
 * eMail: info@vhf.de
 * http://www.vhf.de
 */

#include "undo.h"

@interface JoinGraphicsChange(PrivateMethods)

- (void)undoDetails;
- (void)redoDetails;

@end

@implementation JoinGraphicsChange


- (void)dealloc
{
    [pathBefore release];
    [path release];
    [super dealloc];
}

- (NSString *)changeName
{
    return JOIN_OP;
}

- (void)saveBeforeChange
{
    [super saveBeforeChange];
    [changeDetails makeObjectsPerformSelector:@selector(recordGraphicPositionIn:) withObject:[graphicView layerList]]; 
}

- (Class)changeDetailClass
{
    return [OrderChangeDetail class];
}

/* FIXME: we should note the layer too (see group),
 * since someone may want to joing graphics on several layers !!!
 */
- (void)notePathBefore:aPath
{
    pathBefore = aPath; // [aPath copy];
    [pathBefore retain];
}

- (void)notePath:aPath
{
    path = aPath;   // is a new one
    [path retain];
}

- (void)correctDirectionOfGraphic:(VGraphic*)graphic
{   int     i, cnt = 0;
    NSPoint end1, beg2;

    if ( ![graphic isKindOfClass:[VPath class]] )
        return;

    cnt = [[(VPath*)graphic list] count];
    if ( cnt < 2 )
        return;
    end1 = [[[(VPath*)graphic list] objectAtIndex:0] pointWithNum:MAXINT];
    beg2 = [[[(VPath*)graphic list] objectAtIndex:1] pointWithNum:0];

    if ( SqrDistPoints(end1, beg2) > TOLERANCE*TOLERANCE )
        for ( i = 0; i < cnt; i++ )
            [[[(VPath*)graphic list] objectAtIndex:i] changeDirection];
}

- (void)correctDirectionOfPath
{   int sIx=0, eIx, cnt = 0;

    if ( ![path isKindOfClass:[VPath class]] )
        return;

    cnt = [[path list] count];
    /* each subpath itself ! */
    while ( sIx < cnt )
    {   eIx = [path getLastObjectOfSubPath2:sIx];

        if ( eIx == sIx )
        {
            if ( [[[path list] objectAtIndex:sIx] respondsToSelector:@selector(closed)] &&
                 [[[path list] objectAtIndex:sIx] closed] )
            {   sIx = eIx+1;
                continue;
            }
            [[[path list] objectAtIndex:sIx] changeDirection];
        }
        sIx = eIx+1;
    }
}

/* remove path build during punch operation (path)
 * add objects (and path before manipulation) involved in punch operation
 * FIXME: undo of join with more than one layer doesn't work correctly
 */
- (void)undoDetails
{   int                 count, i;
    OrderChangeDetail   *detail;
    VGraphic            *graphic;
    NSArray             *layerList = [graphicView layerList];

    [graphicView removeGraphic:path];
    count = [changeDetails count];
    for ( i = 0; i < count; i++ )
    {   LayerObject	*layer;

        detail = [changeDetails objectAtIndex:i];
        graphic = [detail graphic];
        [self correctDirectionOfGraphic:graphic]; // join change direction evtl
        if ( pathBefore && graphic == path )    // ?? noch notwendig ?
            graphic = pathBefore;
        layer = [layerList objectAtIndex:[detail layer]];
        [layer insertObject:graphic atIndex:Min([detail graphicPosition], [[layer list] count])];
    }
    [graphicView getSelection];
}

/* remove graphics involved in punch operation
 * add path build during punch operation
 */
- (void)redoDetails
{   int             count, i;
    ChangeDetail    *detail = nil;
    VGraphic        *graphic = nil;
    NSArray         *layerList = [graphicView layerList];
    LayerObject     *layer;

    count = [changeDetails count];
    for (i = 0; i < count; i++)
    {
        detail = [changeDetails objectAtIndex:i];
        graphic = [detail graphic];
        if ( pathBefore && graphic == path )    // ?? noch notwendig ?
            graphic = pathBefore;
        [graphicView removeGraphic:graphic];
    }
    [self correctDirectionOfPath]; // join change direction evtl
    layer = [layerList objectAtIndex:[detail layer]];
    [layer insertObject:path atIndex:0];
    [graphicView getSelection]; 
}

@end
