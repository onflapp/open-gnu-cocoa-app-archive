/* SimpleGraphicsChange.m
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


@interface SimpleGraphicsChange(PrivateMethods)
- (void)undoDetails;
- (void)redoDetails;
- (BOOL)subsumeIdenticalChange:change;
@end


@implementation SimpleGraphicsChange

- (void)saveBeforeChange
{
    [super saveBeforeChange];
    [changeDetails makeObjectsPerformSelector:@selector(recordDetail)]; 
}

/*
 * ChangeManager will call subsumeChange: when we are the last 
 * completed change and a new change has just begun. We override
 * the subsumeChange: to offer our subclasses a chance to
 * consolidate multiple changes into a single change.
 * First we check to make sure that the new change is of the
 * same class as the last. If it is then we check to make sure
 * that it's operating on the same selection. If not we simply
 * return NO, declining to subsume it. If it does operate on
 * the same change then we offer our subclass a change to 
 * subsume it by sending [self subsumeIdenticalChange:change].
 *
 * For example, if the user presses the up arrow key to move
 * a graphic up one pixel, that immediately becomes a complete,
 * undoable change, as it should. If she continues to press
 * use the arrow keys we don't want to end up making hundreds
 * of independent move changes that would each have to be
 * undone seperately. So instead we have the first move
 * subsume all subsequent MoveGraphicsChanges that operate
 * on the same selection.
 */
- (BOOL)subsumeChange:change
{   BOOL	identicalChanges = NO;
    NSArray	*slayList = [graphicView slayList];
    int		i, l;

    if ([change isKindOfClass:[self class]])
    {
        if (!graphicsToChange)
        {
            identicalChanges = YES;
            if ( [slayList count] != [clayList count] )
                identicalChanges = NO;
            else
            {
                for ( l=0; (l<(int)[slayList count]) && identicalChanges; l++ )
                {   NSArray	*list = [slayList objectAtIndex:l];
                    NSArray	*cList = [clayList objectAtIndex:l];

                    if ( [list count] != [cList count] )
                        identicalChanges = NO;
                    else
                        for ( i = 0; i < (int)[list count]; i++ )
                        {
                            if ([cList objectAtIndex:i] != [list objectAtIndex:i])
                            {   identicalChanges = NO;
                                break;
                            }
                        }
                }
            }
	}
    } 
    if (identicalChanges)
        return [self subsumeIdenticalChange:change];
    else
        return NO;
}

- (void)undoDetails
{
    [changeDetails makeObjectsPerformSelector:@selector(undoDetail)]; 
}

- (void)redoDetails
{
    [changeDetails makeObjectsPerformSelector:@selector(redoDetail)]; 
}

- (BOOL)subsumeIdenticalChange:change
{
    return NO;
}

@end
