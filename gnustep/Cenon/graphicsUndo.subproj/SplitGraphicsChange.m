/* SplitGraphicsChange.m
 *
 * Copyright (C) 1993-2012 by vhf interservice GmbH
 * Authors:  Georg Fleischmann
 *
 * created:  1993
 * modified: 2012-02-24 (-noteList: added fixed with this)
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

@interface SplitGraphicsChange(PrivateMethods)

@end

@implementation SplitGraphicsChange

- initGraphicView:aGraphicView
{
    [super init];
    graphicView = aGraphicView;
    changeDetails = nil;
    groups = nil;
    splitList = nil;

    return self;
}

- (void)dealloc
{
    [groups release];
    if (changeDetails != nil)
	[changeDetails release];
	[splitList release];
    [super dealloc];
}

- (NSString *)changeName
{
    return SPLIT_OP;
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

        for (i = 0, count=[slist count]; i < count; i++)
        {
            g = [slist objectAtIndex:i];
            if ( [g respondsToSelector:@selector(splitTo:)] )
            {
                [groups addObject:g];
                [changeDetails addObject:[[changeDetailClass alloc] initGraphic:g change:self]];
                if ([g isMemberOfClass:[VImage class]] && [(VImage*)g clipPath])
                {   [groups addObject:[(VImage*)g clipPath]];
                    [changeDetails addObject:[[changeDetailClass alloc] initGraphic:[(VImage*)g clipPath] change:self]];
                }
            }
        }
    }
    [changeDetails makeObjectsPerformSelector:@selector(recordGraphicPositionIn:) withObject:[graphicView layerList]];

    count = [groups count];
    if (count == 0)
        [self disable]; 
}

/* list from -splitTo: */
- (void)noteList:(NSArray*)aList
{   int i, cnt = [aList count];

    if (!splitList)
        splitList = [[NSMutableArray alloc] init];
        
    for (i = 0; i < cnt; i++)
        [splitList addObject:[aList objectAtIndex:i]];
}

- (void)undoChange
{   LayerObject         *layer;
    int                 i, j, count, graphicCount;
    NSRect              affectedBounds;
    VGraphic            *group;
    OrderChangeDetail   *detail;
    NSArray             *layerList = [graphicView layerList];

    count = [changeDetails count];
    for (i = 0; i < count; i++)
    {
        detail = [changeDetails objectAtIndex:i];
        group = [detail graphic];
        if ( [group respondsToSelector:@selector(list)] )   // path
        {
            graphicCount = [splitList count];
            for (j = 0; j < graphicCount; j++)
                [graphicView removeGraphic:[splitList objectAtIndex:j]];
        }
        else if ([group isMemberOfClass:[VImage class]])    // image
        {   id	nextDetail = [changeDetails objectAtIndex:i+1];
            id	nextGroup = [nextDetail graphic];

            [(VImage*)group join:nextGroup];
            [graphicView removeGraphic:nextGroup];
            i++; // jump over our clipPath
        }
        else                                                // VTextPath
        {
            [graphicView removeGraphic:[(VTextPath*)group textGraphic]];
            [graphicView removeGraphic:[(VTextPath*)group path]];
        }
        layer = [layerList objectAtIndex:[detail layer]];
        if (![group isMemberOfClass:[VImage class]])
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
{   int		i, count;
    NSRect	affectedBounds;
    NSArray	*layerList = [graphicView layerList];

    affectedBounds = [graphicView boundsOfArray:groups withKnobs:YES];

    count = [groups count];
    for (i = 0; i < count; i++)
    {   VGraphic        *group = [groups objectAtIndex:i];
        ChangeDetail    *detail = [changeDetails objectAtIndex:i];
        LayerObject     *layer = [layerList objectAtIndex:[detail layer]];
        int             j, location = [[layer list] indexOfObject:group];

        if ([group isMemberOfClass:[VImage class]])
            i++; // jump over clipPath
        [group retain];
        [graphicView removeGraphic:group]; // do everything
        if ( !i ) // only once
            for (j=[splitList count]-1; j>=0; j--)
                [layer insertObject:[splitList objectAtIndex:j] atIndex:location];
        [group release];
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
