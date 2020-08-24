/* UngroupGraphicsChange.m
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

@interface UngroupGraphicsChange(PrivateMethods)

@end

@implementation UngroupGraphicsChange

- initGraphicView:aGraphicView
{
    [super init];
    graphicView = aGraphicView;
    changeDetails = nil;
    groups = nil;

    return self;
}

- (void)dealloc
{   int	i, count;
    id	group;

    if ([self hasBeenDone])
    {
	count = [groups count];
	for (i = 0; i < count; i++)
        {   group = [groups objectAtIndex:i];
	    [group release];
	}
    }
    [groups release];
    if (changeDetails != nil)
    {   [changeDetails removeAllObjects];
	[changeDetails release];
    }
    [super dealloc];
}

- (NSString *)changeName
{
    return UNGROUP_OP;
}

- (void)saveBeforeChange
{   int		l, i, count;
    id		g;
    id		changeDetailClass;
    NSArray	*slayList = [graphicView slayList];

    groups = [[NSMutableArray alloc] init];
    changeDetailClass = [self changeDetailClass];
    changeDetails = [[NSMutableArray alloc] init];

    for ( l=0; l<(int)[slayList count]; l++ )
    {   NSArray	*slist = [slayList objectAtIndex:l];

        for (i = 0, count=(int)[slist count]; i < count; i++)
        {
            g = [slist objectAtIndex:i];
            if ( [g isKindOfClass:[VGroup class]] )
            {
                [groups addObject:g];
                [changeDetails addObject:[[changeDetailClass alloc] initGraphic:g change:self]];
            }
        }
    }
    [changeDetails makeObjectsPerformSelector:@selector(recordGraphicPositionIn:) withObject:[graphicView layerList]];

    count = [groups count];
    if (count == 0)
        [self disable]; 
}

- (void)undoChange
{   NSMutableArray      *graphics;
    LayerObject         *layer;
    int                 i, j, count, graphicCount;
    NSRect              affectedBounds;
    VGroup              *group;
    VGraphic            *graphic;
    OrderChangeDetail   *detail;
    NSArray             *layerList = [graphicView layerList];

    count = [changeDetails count];
    for (i = 0; i < count; i++)
    {
        detail = [changeDetails objectAtIndex:i];
	group = (VGroup*)[detail graphic];
	graphics = [group list];
	graphicCount = [graphics count];
	for (j = 0; j < graphicCount; j++)
    {
	    graphic = [graphics objectAtIndex:j];
	    [graphicView removeGraphic:graphic];
	}
        layer = [layerList objectAtIndex:[detail layer]];
        [layer insertObject:group atIndex:[detail graphicPosition]];
    }
    [graphicView getSelection];
    affectedBounds = [graphicView boundsOfArray:groups withKnobs:YES];
    [graphicView cache:affectedBounds];
    [[graphicView window] flushWindow];
    [[(App*)NSApp inspectorPanel] loadList:[graphicView slayList]]; 

    [super undoChange]; 
}

- (void)redoChange
{   int                 i, j, count;
    NSRect              affectedBounds;
    VGroup              *group;
    OrderChangeDetail   *detail;
    NSArray             *layerList = [graphicView layerList];

    affectedBounds = [graphicView boundsOfArray:groups withKnobs:YES];

    count = [groups count];
    for (i = 0; i < count; i++)
    {   LayerObject	*layer;
        NSMutableArray	*list = [NSMutableArray array];

        group = [groups objectAtIndex:i];
        detail = [changeDetails objectAtIndex:i];
        layer = [layerList objectAtIndex:[detail layer]];
        [graphicView removeGraphic:group];
        [group ungroupTo:list];
        [layer removeObject:group];
        for (j=[list count]-1; j>=0; j--)
            [layer insertObject:[list objectAtIndex:j] atIndex:[detail graphicPosition]];
    }
    [graphicView getSelection];
    [graphicView cache:affectedBounds];
    [[graphicView window] flushWindow];
    [[(App*)NSApp inspectorPanel] loadList:[graphicView slayList]]; 

    [super redoChange]; 
}

- (Class)changeDetailClass
{
    return [OrderChangeDetail class];
}

@end
