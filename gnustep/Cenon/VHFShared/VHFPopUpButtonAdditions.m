/* VHFPopUpButtonAdditions.m
 * vhf NSPopUpButton additions
 *
 * Copyright (C) 1997-2012 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1997-10-24
 * modified: 2012-01-06
 *
 * This file is part of the vhf Shared Library.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the vhf Public License as
 * published by the vhf interservice GmbH. Among other things,
 * the License requires that the copyright notices and this notice
 * be preserved on all copies.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the vhf Public License for more details.
 *
 * You should have received a copy of the vhf Public License along
 * with this library; see the file LICENSE. If not, write to vhf.
 *
 * If you want to link this library to your proprietary software,
 * or for other uses which are not covered by the definitions
 * laid down in the vhf Public License, vhf also offers a proprietary
 * license scheme. See the vhf internet pages or ask for details.
 *
 * vhf interservice GmbH, Im Marxle 3, 72119 Altingen, Germany
 * eMail: info@vhf.de
 * http://www.vhf.de
 */

#include "VHFPopUpButtonAdditions.h"

@implementation NSPopUpButton(VHFPopUpButtonAdditions)

/* created:  1997-10-24
 */
- (NSMenuItem*)itemWithTag:(NSInteger)tag
{   NSInteger   row;

    for ( row=0; row<[self numberOfItems]; row++ )
        if ( [[self itemAtIndex:row] tag] == tag )
            return [self itemAtIndex:row];
    return nil;
}

/* created:  1997-10-24
 * modified: 2006-02-06 (BOOL to be compatible, Apple followed with this method in 10.4)
 */
- (BOOL)selectItemWithTag:(NSInteger)tag
{   NSInteger   row;

    for ( row=0; row<[self numberOfItems]; row++ )
        if ( [[self itemAtIndex:row] tag] == tag )
        {   [self selectItemAtIndex:row];
            return YES;
        }
    return NO;
}

/*
 * fill the device popup 'devicePopup' with menu cells
 *
 * begin:    2006-01-27
 * modified: 2006-01-27
 *
 * items     the items for the popup
 * fromIx    the index of the first item of the popuplist to be removed
 */
- (void)replaceItemsFromArray:(NSArray*)items fromIndex:(NSInteger)fromIx
{   NSInteger   i, cnt, selectedIx = [self indexOfSelectedItem];

    if (!items)
    {	[self setEnabled:NO];
        return;
    }

    /* remove entries from popup list, but keep items before removeIx */
    if (fromIx <= 0)
        [self removeAllItems];
    else
        while ( [self numberOfItems] > fromIx )
            [self removeItemAtIndex:[self numberOfItems]-1];

    for ( i=0, cnt=[items count]; i<cnt; i++ )
        [self addItemWithTitle:[items objectAtIndex:i]];
    //sortPopup(self, fromIx);

    /* enable popup list when having any entries */
    [self setEnabled:([self numberOfItems]) ? YES : NO];
    if ( [self numberOfItems] > selectedIx )
        [self selectItemAtIndex:selectedIx];
}

@end
