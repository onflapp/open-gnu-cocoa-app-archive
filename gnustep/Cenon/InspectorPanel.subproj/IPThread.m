/* IPThread.h
 * Thread Inspector
 *
 * Copyright (C) 1995-2008 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  2000-07-12
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
#include "InspectorPanel.h"
#include "IPThread.h"

@implementation IPThread

- (void)update:sender
{   Document    *doc = [[self view] document];
    id          g = sender;

    [super update:sender];
    [diameterField setStringValue:buildRoundedString([doc convertToUnit:[g radius]*2.0], 0.0, LARGE_COORD)];
    [pitchField    setStringValue:buildRoundedString([doc convertToUnit:[g pitch]],      0.0, LARGE_COORD)];
    [(NSButton*)leftTurnSwitch setState:([g angle] < 0.0) ? 1 : 0];
    [(NSButton*)externalSwitch setState:([g external]) ? 1 : 0];
}

- (void)setDiameter:sender
{   Document    *doc = [[self view] document];
    float       min = 0.0, max = LARGE_COORD;
    float       v = [diameterField floatValue];
    BOOL        control = [(App*)NSApp control];

    if ([sender isKindOfClass:[NSButton class]])
    {
        switch ([(NSButton*)sender tag])
        {
            case BUTTONLEFT:	v -= ((control) ? 10.0 : 1.0); break;
            case BUTTONRIGHT:	v += ((control) ? 10.0 : 1.0);
        }
    }

    if (v < min)	v = min;
    if (v > max)	v = max;
    [diameterField setStringValue:vhfStringWithFloat(v)];

    v = [doc convertFrUnit:v/2.0];
    [[self view] takeRadius:v];
}

- (void)setPitch:sender
{   Document    *doc = [[self view] document];
    int         i, l, cnt;
    NSArray     *slayList = [[self view] slayList];
    float       min = 0.0, max = LARGE_COORD;
    float       v = [pitchField floatValue];
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
    [pitchField setStringValue:vhfStringWithFloat(v)];

    v = [doc convertFrUnit:v];

    /* set width of all objects */
    cnt = [slayList count];
    for (l=0; l<cnt; l++)
    {	NSMutableArray *slist = [slayList objectAtIndex:l];

        if (![[[[self view] layerList] objectAtIndex:l] editable])
            continue;
        for (i=[slist count]-1; i>=0; i--)
        {   id		g = [slist objectAtIndex:i];

            if ([g respondsToSelector:@selector(setPitch:)])
                [(VThread*)g setPitch:v];
        }
    }

    [[self view] drawAndDisplay];
}

/* left turn = negative angle
 */
- (void)setLeftTurn:sender
{   int		i, l, cnt;
    id		view = [self view];
    NSArray *slayList = [view slayList];
    BOOL	flag = [(NSButton*)leftTurnSwitch state];
    //id		change;

    /* set right turn for all objects */
    //change = [[LockGraphicsChange alloc] initGraphicView:view];
    //[change startChange];
        cnt = [slayList count];
        for ( l=0; l<cnt; l++ )
        {   NSMutableArray *slist = [slayList objectAtIndex:l];

            if ( ![[[view layerList] objectAtIndex:l] editable] )
                continue;
            for ( i=[slist count]-1; i>=0; i-- )
            {   VThread	*g = [slist objectAtIndex:i];
                float	a = Abs([g angle]);

                if ( [g respondsToSelector:@selector(setAngle:)] )
                    [g setAngle:(flag) ? -a : a];
            }
        }
    //[change endChange];

    [[(App*)NSApp currentDocument] setDirty:YES];
    [view drawAndDisplay];
}

/* set external thread
 * NOTE: this is done by inside/outside correction of the layer (is this better now ?)
 */
- (void)setExternal:sender
{   int		i, l, cnt;
    id		view = [self view];
    NSArray *slayList = [view slayList];
    BOOL	flag = [(NSButton*)externalSwitch state];
    //id		change;

    //change = [[LockGraphicsChange alloc] initGraphicView:view];   // TODO
    //[change startChange];
        cnt = [slayList count];
        for ( l=0; l<cnt; l++ )
        {   NSMutableArray *slist = [slayList objectAtIndex:l];

            if ( ![[[view layerList] objectAtIndex:l] editable] )
                continue;
            for ( i=[slist count]-1; i>=0; i-- )
            {   VThread	*g = [slist objectAtIndex:i];

                if ( [g respondsToSelector:@selector(setExternal:)] )
                    [g setExternal:flag];
            }
        }
    //[change endChange];

    [[(App*)NSApp currentDocument] setDirty:YES];
    [view drawAndDisplay];
}

@end
