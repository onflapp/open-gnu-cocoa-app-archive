/* ContourGraphicsChange.h
 *
 * Copyright (C) 1993-2011 by vhf interservice GmbH
 * Authors:  Georg Fleischmann
 *
 * created:  1993
 * modified: 2011-04-06 (-setRemoveSource: added)
 *           2006-11-21
 *
 * - It is important that the new elements are selected before endChange is called!
 * - It is also important that the new elements generated during operation,
 *   are really new objects, not just modified!
 *
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

@interface ContourGraphicsChange(PrivateMethods)

- (void)undoDetails;
- (void)redoDetails;

@end

@implementation ContourGraphicsChange

- (void)dealloc
{
    [newObjects removeAllObjects];
    [newObjects release];
    [super dealloc];
}

- (NSString *)changeName
{
    return CONTOUR_OP;
}

- (void)saveBeforeChange
{
    [super saveBeforeChange];
    removeSource = [(App*)NSApp contourRemoveSource];
    [changeDetails makeObjectsPerformSelector:@selector(recordGraphicPositionIn:) withObject:[graphicView layerList]]; 
}

- (void)setRemoveSource:(BOOL)flag
{
    removeSource = flag;
}

- (void)saveAfterChange
{   int	i, l;

    newObjects = [[NSMutableArray array] retain];
    for ( l=0; l<(int)[[graphicView slayList] count]; l++ )
    {	NSArray		*sList = [[graphicView slayList] objectAtIndex:l];
        NSMutableArray	*nList = [NSMutableArray array];

        [newObjects addObject:nList];
        for ( i=0; i<(int)[sList count]; i++ )
            [nList addObject:[sList objectAtIndex:i]];
    }
}

- (Class)changeDetailClass
{
    return [OrderChangeDetail class];
}

- (void)undoChange
{
    [self undoDetails];
    [graphicView cache:NSZeroRect];
    [[(App*)NSApp inspectorPanel] loadList:[graphicView slayList]];

    _changeFlags.hasBeenDone = NO;
    //[super undoChange];
}

- (void)redoChange
{
    [self redoDetails];
    [graphicView cache:NSZeroRect];
    [[(App*)NSApp inspectorPanel] loadList:[graphicView slayList]];

    _changeFlags.hasBeenDone = YES;
    //[super redoChange]; would undo and draw a second time: we should be a subclass of change
}

/* remove objects build during contour operation (newObjects)
 * add objects involved in contour operation
 */
- (void)undoDetails
{   int		count, i, l;
    id		detail, graphic;
    NSArray	*layerList = [graphicView layerList];

    /* remove objects build in contour operation */
    for ( l=0; l<(int)[newObjects count]; l++ )
    {   NSArray		*nList = [newObjects objectAtIndex:l];
        LayerObject	*layer = [layerList objectAtIndex:l];

        for ( i=0; i<(int)[nList count]; i++ )
            [layer removeObject:[nList objectAtIndex:i]];
    }

    /* add objects removed in contour operation - if removeSource set */
    if ( removeSource )
    {   count = [changeDetails count];
        for ( i = 0; i < count; i++ )
        {   LayerObject	*layer;

            detail = [changeDetails objectAtIndex:i];
            graphic = [detail graphic];
            layer = [layerList objectAtIndex:[(ChangeDetail*)detail layer]];
            [layer insertObject:graphic atIndex:Min([detail graphicPosition], [[layer list] count])];
        }
    }
    [graphicView getSelection];
}

/* remove graphics involved in contour operation
 * add newObjects build during contour operation
 */
- (void)redoDetails
{   int			count, i, l;
    id			detail = nil, graphic = nil;
    NSArray		*layerList = [graphicView layerList];

    /* remove objects removed in punch operation - if removeSource set */
    if ( removeSource )
    {   count = [changeDetails count];
        for (i = 0; i < count; i++)
        {
            detail = [changeDetails objectAtIndex:i];
            graphic = [detail graphic];
            [graphicView removeGraphic:graphic];
        }
    }
    /* add new objects */
    for ( l=0; l<(int)[newObjects count]; l++ )
    {   NSArray		*nList = [newObjects objectAtIndex:l];
        LayerObject	*layer = [layerList objectAtIndex:l];

        for ( i=0; i<(int)[nList count]; i++ )
            [layer insertObject:[nList objectAtIndex:i] atIndex:0];
    }
    [graphicView getSelection]; 
}

@end
