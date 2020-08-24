/* PasteGraphicsChange.m
 *
 * Copyright (C) 1993-2003 by vhf interservice GmbH
 * Authors:  Georg Fleischmann
 *
 * created:  1993
 * modified: 2003-06-26
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

@interface PasteGraphicsChange(PrivateMethods)

- (void)undoDetails;
- (void)redoDetails;

@end

@implementation PasteGraphicsChange

- (void)dealloc
{
    if ( ![self hasBeenDone] )
        [clayList removeAllObjects];
    [super dealloc];
}

- (NSString *)changeName
{
    return PASTE_OP;
}

- (void)saveBeforeChange
{
    [super saveBeforeChange];
}

- (Class)changeDetailClass
{
    return nil;
}

- (void)undoChange
{
    [self undoDetails];
    [[(App*)NSApp inspectorPanel] loadList:[graphicView slayList]];

    _changeFlags.hasBeenDone = NO;
}

- (void)redoChange
{
    [self redoDetails];
    [[(App*)NSApp inspectorPanel] loadList:[graphicView slayList]];

    _changeFlags.hasBeenDone = YES;
}

/* we remove all objects which were selected when we called init...
 */
- (void)undoDetails
{   int		l, i;
    NSRect	affectedBounds = NSZeroRect;

    for ( l=0; l<(int)[clayList count]; l++ )
    {   NSArray		*clist = [clayList objectAtIndex:l];

        affectedBounds = (affectedBounds.size.width)
            ? NSUnionRect([graphicView boundsOfArray:clist], affectedBounds)
            : [graphicView boundsOfArray:clist];
        for (i = 0; i < (int)[clist count]; i++)
            [graphicView removeGraphic:[clist objectAtIndex:i]];
    }
    [graphicView cache:affectedBounds];
}

- (void)redoDetails
{   int		l, i;
    id		graphic;
    NSArray	*layerList = [graphicView layerList];
    NSRect	affectedBounds = NSZeroRect;

    for ( l=0; l<(int)[clayList count]; l++ )
    {   NSArray		*clist = [clayList objectAtIndex:l];
        LayerObject	*layer = [layerList objectAtIndex:l];

        for (i = 0; i < (int)[clist count]; i++)
        {   graphic = [clist objectAtIndex:i];
            [layer addObject:graphic];
            affectedBounds = (affectedBounds.size.width)
                ? NSUnionRect([graphic bounds], affectedBounds)
                : [graphic bounds];
        }
    }
    [graphicView cache:affectedBounds];
    [graphicView getSelection]; 
}

@end
