/* IPMark.m
 * Mark Inspector
 * Copyright (C) 1999-2011 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1997-11-13
 * modified: 2005-07-19 (document units)
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
#include "../graphicsUndo.subproj/undo.h"
#include "InspectorPanel.h"
#include "IPMark.h"

@implementation IPMark

- (void)update:sender
{   Document    *doc = [[self view] document];
    DocView     *view = [self view];
    VMark       *g = sender;
    NSPoint     p;

    [super update:sender];

    p = [view pointRelativeOrigin:[g pointWithNum:0]];
    [xField setStringValue:buildRoundedString([doc convertToUnit:p.x], LARGENEG_COORD, LARGE_COORD)];
    [yField setStringValue:buildRoundedString([doc convertToUnit:p.y], LARGENEG_COORD, LARGE_COORD)];

    [(NSButton*)zSwitch setState:([g is3D]) ? YES : NO];
    //[[zSwitch controlView] display]; // matrix wouldn't not update without
    [zField setStringValue:buildRoundedString([doc convertToUnit:[g z]], LARGENEG_COORD, LARGE_COORD)];
    [zField setEnabled:[g is3D]];
    [zLeftButton  setEnabled:[g is3D]];
    [zRightButton setEnabled:[g is3D]];

    [nameField setStringValue:([g label]) ? [g label] : @""]; // DEPRECATED: connect to labelField
}

- (void)setPointX:sender
{   Document    *doc = [[self view] document];
    float       min = LARGENEG_COORD, max = LARGE_COORD;
    float       v = [xField floatValue];
    BOOL        control = [(App*)NSApp control];

    if ([sender isKindOfClass:[NSButton class]])
    {
        switch ([(NSButton*)sender tag])
        {
            case BUTTONLEFT:	v -= ((control) ? 10.0 : 1.0); break;
            case BUTTONRIGHT:	v += ((control) ? 10.0 : 1.0);
        }
    }

    if (v < min) v = min;
    if (v > max) v = max;
    [xField setStringValue:vhfStringWithFloat(v)];

    v = [doc convertFrUnit:v];
    [[self view] movePoint:0 to:[[self view] pointAbsolute:NSMakePoint(v, 0.0)] x:YES y:NO all:NO];
}

- (void)setPointY:sender
{   Document    *doc = [[self view] document];
    float       min = LARGENEG_COORD, max = LARGE_COORD;
    float       v = [yField floatValue];
    BOOL        control = [(App*)NSApp control];

    if ([sender isKindOfClass:[NSButton class]])
    {
        switch ([(NSButton*)sender tag])
        {
            case BUTTONLEFT:	v -= ((control) ? 10.0 : 1.0); break;
            case BUTTONRIGHT:	v += ((control) ? 10.0 : 1.0);
        }
    }

    if (v < min) v = min;
    if (v > max) v = max;
    [yField setStringValue:vhfStringWithFloat(v)];

    v = [doc convertFrUnit:v];
    [[self view] movePoint:0 to:[[self view] pointAbsolute:NSMakePoint(0.0, v)] x:NO y:YES all:NO];
}

- (void)setPointZ:sender
{   Document    *doc = [[self view] document];
    DocView     *view = [self view];
    float       min = LARGENEG_COORD, max = LARGE_COORD;
    float       v = [zField floatValue];
    BOOL        control = [(App*)NSApp control];
    int         l, cnt, i;
    //id		change;	// FIXME
    NSArray     *slayList = [view slayList];

    if ( sender == zSwitch ||   // switch
        ([sender isKindOfClass:[NSMatrix class]] && [sender selectedCell] == zSwitch) )
    {
        //change = [[LockGraphicsChange alloc] initGraphicView:view];   // TODO
        //[change startChange];
            cnt = [slayList count];
            for ( l=0; l<cnt; l++ )
            {   NSMutableArray *slist = [slayList objectAtIndex:l];

                if ( ![[[view layerList] objectAtIndex:l] editable] )
                    continue;
                for ( i=[slist count]-1; i>=0; i-- )
                {   id	g = [slist objectAtIndex:i];

                    if ( [g respondsToSelector:@selector(set3D:)] )
                        [g set3D:[(NSButton*)zSwitch state]];
                }
            }
        //[change endChange];
        [zField       setEnabled:[(NSButton*)zSwitch state]];
        [zLeftButton  setEnabled:[(NSButton*)zSwitch state]];
        [zRightButton setEnabled:[(NSButton*)zSwitch state]];
        return;
    }

    if ([sender isKindOfClass:[NSButton class]])
    {
        switch ([(NSButton*)sender tag])
        {
            case BUTTONLEFT:	v -= ((control) ? 10.0 : 1.0); break;
            case BUTTONRIGHT:	v += ((control) ? 10.0 : 1.0);
        }
    }

    if (v < min) v = min;
    if (v > max) v = max;
    [zField setStringValue:vhfStringWithFloat(v)];

    v = [doc convertFrUnit:v];

    /* set z for all objects */
    //change = [[LockGraphicsChange alloc] initGraphicView:view];
    //[change startChange];
        cnt = [slayList count];
        for ( l=0; l<cnt; l++ )
        {   NSMutableArray *slist = [slayList objectAtIndex:l];

            if ( ![[[view layerList] objectAtIndex:l] editable] )
                continue;
            for ( i=[slist count]-1; i>=0; i-- )
            {   id	g = [slist objectAtIndex:i];

                if ( [g respondsToSelector:@selector(setZ:)] )
                    [g setZ:v];
            }
        }
    //[change endChange];
}

// DEPRECATED: change interface to labelField, -setLabel:
- (void)setName:sender
{   id		view = [self view];
    NSArray *slayList = [view slayList];
    int		l, cnt, i;
    id		change;

    change = [[LabelGraphicsChange alloc] initGraphicView:view label:[nameField stringValue]];
    [change startChange];
    cnt = [slayList count];
    for ( l=0; l<cnt; l++ )
    {   NSMutableArray *slist = [slayList objectAtIndex:l];

        if ( ![[[view layerList] objectAtIndex:l] editable] )
            continue;
        for ( i=[slist count]-1; i>=0; i-- )
        {   VGraphic    *g = [slist objectAtIndex:i];

            [g setLabel:[nameField stringValue]];
        }
    }
    [change endChange];
}

- (void)displayWillEnd
{
}

@end
