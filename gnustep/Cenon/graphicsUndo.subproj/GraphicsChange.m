/* GraphicsChange.m
 * keeps track of changes in the graphic objects
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

@interface GraphicsChange(PrivateMethods)

- (void)undoDetails;
- (void)redoDetails;

@end

@implementation GraphicsChange

- initGraphicView:aGraphicView
{
    [super init];
    graphicView = aGraphicView;
    clayList = nil;
    changeDetails = nil;

    return self;
}

/*
- initGraphicView:aGraphicView forChangeToGraphic:aGraphic
{
    [self initGraphicView:aGraphicView];
    graphicsToChange = [[NSMutableArray alloc] init];
    [graphicsToChange addObject:aGraphic];
    return self;
}*/

- (void)dealloc
{
   [clayList release];
   [graphicsToChange release];
    if (changeDetails != nil) {
	[changeDetails removeAllObjects];
	[changeDetails release];
    }

    [super dealloc];
}

- (void)saveBeforeChange
{   int		i, l, count;
    Class	changeDetailClass;
    id		changeDetail;
    BOOL	changeExpected = NO;
    NSArray	*slayList;

    if (!graphicsToChange)
	slayList = [graphicView slayList];
    else
	slayList = graphicsToChange;
    for ( l=0, count=0; l<(int)[slayList count]; l++ )
        count += [(NSArray*)[slayList objectAtIndex:l] count];
    if (count == 0)
        [self disable];
    else
    {
	changeDetailClass = [self changeDetailClass];
	if (changeDetailClass != nil)
	    changeDetails = [[NSMutableArray alloc] init];
	else
	    changeExpected = YES;
	clayList = [[NSMutableArray alloc] init];
        for ( l=0; l<(int)[slayList count]; l++ )
        {   NSArray		*list = [slayList objectAtIndex:l];
            NSMutableArray	*cList = [NSMutableArray array];

            [clayList addObject:cList];
            for (i = 0; i < (int)[list count]; i++)
            {
                [cList addObject:[list objectAtIndex:i]];
                if (changeDetailClass != nil)
                {
                    changeDetail = [[changeDetailClass alloc] initGraphic:[list objectAtIndex:i] change:self];
                    changeExpected = changeExpected || [changeDetail changeExpected];
                    [changeDetails addObject:changeDetail];
                    [changeDetail release];
                }
            }
	}
    }

    if (!changeExpected)
        [self disable]; 
}

- (void)undoChange
{   int		l, cnt, i, iCnt;
    NSRect	affectedBounds = [graphicView boundsOfArray:clayList];

    [self undoDetails];

    /* update layer and get bounds for redraw */
    for (l=0, cnt = [clayList count]; l<cnt; l++)
    {   NSArray		*list = [clayList objectAtIndex:l];
        LayerObject	*layer = [[graphicView layerList] objectAtIndex:l];

        affectedBounds = NSUnionRect([graphicView boundsOfArray:list], affectedBounds);
        for (i=0, iCnt=[list count]; i < iCnt; i++)
            [layer updateObject:[list objectAtIndex:i]];	// update performance map
    }
    [graphicView cache:affectedBounds];
    [[(App*)NSApp inspectorPanel] loadList:[graphicView slayList]];

    [super undoChange];
}

- (void)redoChange
{   int		l, cnt, i, iCnt;
    NSRect	affectedBounds = [graphicView boundsOfArray:clayList];

    [self redoDetails];
    /* update layer and get bounds for redraw */
    for (l=0, cnt = [clayList count]; l<cnt; l++)
    {   NSArray		*list = [clayList objectAtIndex:l];
        LayerObject	*layer = [[graphicView layerList] objectAtIndex:l];

        affectedBounds = NSUnionRect([graphicView boundsOfArray:list], affectedBounds);
        for (i=0, iCnt=[list count]; i < iCnt; i++)
            [layer updateObject:[list objectAtIndex:i]];	// update performance map
    }
    [graphicView cache:affectedBounds];
    [[(App*)NSApp inspectorPanel] loadList:[graphicView slayList]];

    [super redoChange];
}

/* To be overridden 
 */
- (Class)changeDetailClass
{
    return [ChangeDetail class];
}

/* To be overridden 
 */
- (void)undoDetails
{
}

/* To be overridden 
 */
- (void)redoDetails
{
}

@end
