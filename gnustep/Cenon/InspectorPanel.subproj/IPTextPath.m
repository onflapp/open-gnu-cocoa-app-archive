/*
 * IPTextPath.m
 * TextPath Inspector
 *
 * Copyright (C) 2000-2011 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1996-08-??
 * modified: 2008-02-14
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

#include "../App.h"
#include "../DocView.h"
#include "../Graphics.h"
#include "../LayerObject.h"
#include "InspectorPanel.h"
#include "IPTextPath.h"
#include "../graphicsUndo.subproj/undo.h"

@implementation IPTextPath

- (void)update:sender
{   VTextPath   *g = sender;

    [graphic release];
    graphic = [sender retain];

    [super update:sender];
    [(NSButton*)showPathSwitch     setState:[g showsPath]];
    [(NSButton*)serialNumberSwitch setState:[g isSerialNumber]];
}

- (NSScrollView*)pathView;
{
    return pathView;
}

- (void)setShowPath:sender
{   int		l, cnt, i;
    NSArray *slayList = [[self view] slayList];
    BOOL	flag = [(NSButton*)showPathSwitch state];

    cnt = [slayList count];
    for (l=0; l<cnt; l++)
    {	NSMutableArray *slist = [slayList objectAtIndex:l];

        if ( ![[[[self view] layerList] objectAtIndex:l] editable] )
            continue;
        for (i=[slist count]-1; i>=0; i--)
        {   VTextPath	*g = [slist objectAtIndex:i];

            if ( [g respondsToSelector:@selector(setShowPath:)] )
                [g setShowPath:flag];
        }
    }

    [[self view] drawAndDisplay];
}

- (void)setSerialNumber:sender
{   int		l, cnt, i;
    NSArray *slayList = [[self view] slayList];
    BOOL	flag = [(NSButton*)serialNumberSwitch state];

    cnt = [slayList count];
    for (l=0; l<cnt; l++)
    {	NSMutableArray *slist = [slayList objectAtIndex:l];

        if (![[[[self view] layerList] objectAtIndex:l] editable])
            continue;
        for (i=[slist count]-1; i>=0; i--)
        {   VTextPath	*g = [slist objectAtIndex:i];

            if ( [g respondsToSelector:@selector(setSerialNumber:)] )
            {   [g setSerialNumber:flag];
                [[[[self view] layerList] objectAtIndex:l] setDirty:YES];   // 2008-02-14
                [[[self view] document] setDirty:YES];                      // 2008-02-05
            }
        }
    }

    [[self view] drawAndDisplay];
}

- (void)displayWillEnd
{	 
}

@end
