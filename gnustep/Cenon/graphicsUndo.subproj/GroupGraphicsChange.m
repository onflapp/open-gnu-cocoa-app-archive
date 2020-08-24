/* GroupGraphicsChange.m
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

@interface GroupGraphicsChange(PrivateMethods)

- (void)undoDetails;
- (void)redoDetails;

@end

@implementation GroupGraphicsChange


- (void)dealloc
{
    [groups release];
    [layers release];
    [super dealloc];
}

- (NSString *)changeName
{
    return GROUP_OP;
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

- (void)noteGroup:aGroup layer:(LayerObject*)layer
{
    if (!groups)
    {   groups = [[NSMutableArray array] retain];
        layers = [[NSMutableArray array] retain];
    }
    [groups addObject:aGroup];
    [layers addObject:layer];
}

- (void)undoDetails
{   int		count, i;
    id		detail, graphic;
    NSArray	*layerList = [graphicView layerList];

    /* remove groups */
    for (i=0; i<(int)[groups count]; i++)
        [[layers objectAtIndex:i] removeObject:[groups objectAtIndex:i]];
    /* add graphics */
    count = [changeDetails count];
    for ( i = 0; i < count; i++ )
    {   LayerObject	*layer;

	detail = [changeDetails objectAtIndex:i];
	graphic = [detail graphic];
        layer = [layerList objectAtIndex:[(ChangeDetail*)detail layer]];
        [layer insertObject:graphic atIndex:Min([detail graphicPosition], [[layer list] count])];
    }
    [graphicView getSelection];
}

- (void)redoDetails
{   int             count, i;
    ChangeDetail    *detail;
    VGraphic        *graphic;

    /* remove graphics */
    count = [changeDetails count];
    for (i = 0; i < count; i++)
    {
        detail = [changeDetails objectAtIndex:i];
        graphic = [detail graphic];
        [graphicView removeGraphic:graphic];
    }
    /* add groups */
    for (i=0; i<(int)[layers count]; i++)
        [(LayerObject*)[layers objectAtIndex:i] insertObject:[groups objectAtIndex:i] atIndex:0];
    [graphicView getSelection]; 
}

@end
