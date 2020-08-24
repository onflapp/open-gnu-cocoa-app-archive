/*
 * IPBasicLebel.m
 *
 * Copyright (C) 1996-2008 by vhf interservice GmbH
 * Author: Georg Fleischmann
 *
 * Created:  1996-03-23
 * Modified: 2008-03-17
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
#include "IPBasicLevel.h"
#include "../graphicsUndo.subproj/undo.h"
#include "IPCrosshairs.h" // (setLock: för Crosshair)

@implementation IPBasicLevel

+ (BOOL)servesObject:(NSObject*)g
{
    return NO;
}

- init
{
    [self setDelegate:self];

    return self;
}

- (void)setWindow:(id)win
{
    window = win; 
}
- window
{
    return window;
}

- view
{   id	docView = [window docView];

    return (docView) ? docView
                     : [[(App*)NSApp currentDocument] documentView];
}

- (NSString*)name
{
    return @"None";
}

- (void)update:sender
{   VGraphic    *g = sender;

    [labelField                 setStringValue:([g label]) ? [g label] : @""];
    [(NSButton*)excludeSwitch   setState:[g isExcluded]];
    [(NSButton*)lockSwitch      setState:[g isLocked]];
}


- (void)setLabel:sender
{   id		view = [self view];
    NSArray *slayList = [view slayList];
    int		l, cnt, i;
    id		change;

    change = [[LabelGraphicsChange alloc] initGraphicView:view
                                                    label:[labelField stringValue]];
    [change startChange];
    cnt = [slayList count];
    for ( l=0; l<cnt; l++ )
    {   NSMutableArray *slist = [slayList objectAtIndex:l];

        if ( ![[[view layerList] objectAtIndex:l] editable] )
            continue;
        for ( i=[slist count]-1; i>=0; i-- )
        {   VGraphic    *g = [slist objectAtIndex:i];

            if ( [g respondsToSelector:@selector(setLabel:)] )
                [g setLabel:[labelField stringValue]];
        }
    }
    [change endChange];
}

- (void)setExcluded:sender
{   int		i, l, cnt;
    id		view = [self view];
    NSArray *slayList = [view slayList];
    BOOL	flag = [(NSButton*)excludeSwitch state];
    id		change;

    if ( [self isKindOfClass:[IPCrosshairs class]] )
        return;

    /* set exclude flag for all objects */
    change = [[ExcludeGraphicsChange alloc] initGraphicView:view];
    [change startChange];
    for ( l=0, cnt = [slayList count]; l<cnt; l++ )
    {   NSMutableArray *slist = [slayList objectAtIndex:l];

        if ( ![[[view layerList] objectAtIndex:l] editable] )
            continue;
        for ( i=[slist count]-1; i>=0; i-- )
        {   id	g = [slist objectAtIndex:i];

            if ( [g respondsToSelector:@selector(setExcluded:)] )
                [(VGraphic*)g setExcluded:flag];
        }
    }
    [change endChange];

    [[(App*)NSApp currentDocument] setDirty:YES];
    [view drawAndDisplay];
}

- (void)setLock:sender
{   int		i, l, cnt;
    id		view = [self view];
    NSArray *slayList = [view slayList];
    BOOL	flag = [(NSButton*)lockSwitch state];
    id		change;

    if ( [self isKindOfClass:[IPCrosshairs class]] )
    {
        [[(DocView*)[self view] origin] setLocked:flag];
        [[(App*)NSApp currentDocument] setDirty:YES];
        [view drawAndDisplay];
        return;
    }
    /* set lock for all objects */
    change = [[LockGraphicsChange alloc] initGraphicView:view];
    [change startChange];
        cnt = [slayList count];
        for ( l=0; l<cnt; l++ )
        {   NSMutableArray *slist = [slayList objectAtIndex:l];

            if ( ![[[view layerList] objectAtIndex:l] editable] )
                continue;
            for ( i=[slist count]-1; i>=0; i-- )
            {   id	g = [slist objectAtIndex:i];

                if ( [g respondsToSelector:@selector(setLocked:)] )
                    [(VGraphic*)g setLocked:flag];
            }
        }
    [change endChange];

    [[(App*)NSApp currentDocument] setDirty:YES];
    [view drawAndDisplay];
}


/* delegate methods
 */
- (void)displayWillEnd
{
	 
}

@end
