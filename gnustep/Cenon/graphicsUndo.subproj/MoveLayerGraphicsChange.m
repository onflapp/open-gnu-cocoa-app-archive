/* MoveLayerGraphicsChange.m
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

@interface MoveInfo: NSObject
{
    int 	layerIx;
    NSPoint	d;
}
+ (id)moveInfoWithOffset:(NSPoint)offset layerIndex:(int)ix;
- (id)initWithOffset:(NSPoint)offset layerIndex:(int)ix;
- (int)layerIx;
- (NSPoint)offset;
- (NSPoint)invOffset;
@end
@implementation MoveInfo
+ (id)moveInfoWithOffset:(NSPoint)offset layerIndex:(int)ix
{
    return [[[MoveInfo alloc] initWithOffset:offset layerIndex:ix] autorelease];
}
- (id)initWithOffset:(NSPoint)offset layerIndex:(int)ix
{
    [super init];
    layerIx = ix;
    d = offset;
    return self;
}
- (int)layerIx		{ return layerIx; }
- (NSPoint)offset	{ return d; }
- (NSPoint)invOffset	{ return NSMakePoint(-d.x, -d.y); }
@end

@implementation MoveLayerGraphicsChange

- initGraphicView:aGraphicView
{
    graphicView = aGraphicView;
    [super init];
    return self;
}

- (void)setOffset:(NSPoint)offset forLayerIndex:(int)layerIx
{   MoveInfo	*moveInfo = [MoveInfo moveInfoWithOffset:offset layerIndex:layerIx];

    if (!infoArray)
        infoArray = [[NSMutableArray alloc] init];
    [infoArray addObject:moveInfo];
}

- (void)dealloc
{
    [infoArray release];
    [super dealloc];
}

- (NSString *)changeName
{
    return ALIGN_OP;
}

- (void)undoChange
{   NSArray	*layerList = [graphicView layerList];
    int		l, i;

    for (l=0; l<(int)[infoArray count]; l++)
    {   MoveInfo	*moveInfo = [infoArray objectAtIndex:l];
        LayerObject	*layer = [layerList objectAtIndex:[moveInfo layerIx]];
        NSArray		*list = [layer list];
        NSPoint		d = [moveInfo invOffset];

        for (i=0; i<(int)[list count]; i++)
        {   VGraphic	*g = [list objectAtIndex:i];

            if ( [g respondsToSelector:@selector(moveBy:)] )
            {   [g moveBy:d];
                [layer updateObject:g];
            }
        }
    }

    [graphicView drawAndDisplay];
    [[(App*)NSApp inspectorPanel] loadList:[graphicView slayList]];

    [super undoChange];
}

- (void)redoChange
{   NSArray	*layerList = [graphicView layerList];
    int		l, i;

    for (l=0; l<(int)[infoArray count]; l++)
    {   MoveInfo	*moveInfo = [infoArray objectAtIndex:l];
        LayerObject	*layer = [layerList objectAtIndex:[moveInfo layerIx]];
        NSArray		*list = [layer list];
        NSPoint		d = [moveInfo offset];

        for (i=0; i<(int)[list count]; i++)
        {   VGraphic	*g = [list objectAtIndex:i];

            if ( [g respondsToSelector:@selector(moveBy:)] )
            {   [g moveBy:d];
                [layer updateObject:g];
            }
        }
    }

    [graphicView drawAndDisplay];
    [[(App*)NSApp inspectorPanel] loadGraphic:[graphicView slayList]];
    [super redoChange];
}

/*
 * ChangeManager will call incorporateChange: if another change
 * is started while we are still in progress (after we've 
 * been sent startChange but before we've been sent endChange). 
 * We override incorporateChange: because we want to
 * incorporate a StartEditingGraphicsChange if it happens.
 * Rather than know how to undo and redo the start-editing stuff,
 * we'll simply keep a pointer to the StartEditingGraphicsChange
 * and ask it to undo and redo whenever we undo or redo.
 */
- (BOOL)incorporateChange:change
{
    return NO;
}

@end
