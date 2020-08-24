/* BringToFrontGraphicsChange.m
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

@interface BringToFrontGraphicsChange(PrivateMethods)

- (void)redoDetails;

@end

@implementation BringToFrontGraphicsChange

- (NSString *)changeName
{
    return BRING_TO_FRONT_OP;
}

- (void)redoDetails
{   int		count, i, l;
    id		detail, graphic;
    NSArray	*layerList = [graphicView layerList];

    count = [changeDetails count];
    for ( i = count-1; i >= 0; i-- )
    {
	detail = [changeDetails objectAtIndex:i];
	graphic = [detail graphic];
        for ( l=0; l<(int)[layerList count]; l++ )
        {   LayerObject	*layerObject = [layerList objectAtIndex:l];

            if ( [[layerObject list] containsObject:graphic] )
            {
                [layerObject removeObject:graphic];
                [layerObject addObject:graphic];
                break;
            }
        }
    } 
}

@end
