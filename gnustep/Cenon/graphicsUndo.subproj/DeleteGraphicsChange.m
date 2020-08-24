/* DeleteGraphicsChange.m
 *
 * Copyright (C) 1993-2002 by vhf interservice GmbH
 * Authors:  Georg Fleischmann
 *
 * created:  1993
 * modified: 2002-07-15
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

@interface DeleteGraphicsChange(PrivateMethods)

- (void)undoDetails;
- (void)redoDetails;

@end

@implementation DeleteGraphicsChange

- (void)dealloc
{
    if ([self hasBeenDone])
        [clayList removeAllObjects];
    [super dealloc];
}

- (NSString *)changeName
{
    return DELETE_OP;
}

- (void)saveBeforeChange
{
    [super saveBeforeChange];
    [changeDetails makeObjectsPerformSelector:@selector(recordGraphicPositionIn:) withObject:[graphicView layerList]]; 
}

- (void)undoDetails
{   int		count, i;
    NSArray	*layerList = [graphicView layerList];

    /* objects with lower graphicPosition should come first !! */
    for (i = 0, count = [changeDetails count]; i<count; i++)
    {   id          detail = [changeDetails objectAtIndex:i];
        LayerObject *layerObject = [layerList objectAtIndex:[(ChangeDetail*)detail layer]];
        id          graphic = [detail graphic];

        [layerObject insertObject:graphic atIndex:Min([detail graphicPosition], [[layerObject list] count])];
        [graphic setDirty:YES];
    }
    [graphicView getSelection]; 
}

- (void)redoDetails
{   int		count, i;

    count = [changeDetails count];
    for (i = 0; i < count; i++)
    {   id detail = [changeDetails objectAtIndex:i];
        [graphicView removeGraphic:[detail graphic]];
    }
}

- (Class)changeDetailClass
{
    return [OrderChangeDetail class];
}

@end
