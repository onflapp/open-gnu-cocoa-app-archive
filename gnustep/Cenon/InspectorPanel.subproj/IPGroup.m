/* IPGroup.m
 * Group Inspector
 *
 * Copyright (C) 1995-2008 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1995-12-09
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
#include "IPGroup.h"
#include "../graphicsUndo.subproj/undo.h"

@implementation IPGroup

- (void)update:sender
{   Document    *doc = [[self view] document];
    DocView     *view = [self view];
    id          g = sender;
    NSPoint     p;
    NSRect      rect = [g coordBounds];

    [super update:sender];

    //[g getPoint:0 :&p];
    p = [view pointRelativeOrigin:rect.origin];
    [xField setStringValue:buildRoundedString([doc convertToUnit:p.x], LARGENEG_COORD, LARGE_COORD)];
    [yField setStringValue:buildRoundedString([doc convertToUnit:p.y], LARGENEG_COORD, LARGE_COORD)];

    [wField setStringValue:buildRoundedString([doc convertToUnit:rect.size.width], 0.0, LARGE_COORD)];
    [hField setStringValue:buildRoundedString([doc convertToUnit:rect.size.height], 0.0, LARGE_COORD)];
}

- (void)setPointX:sender
{   Document    *doc = [[self view] document];
    int         i, l, cnt;
    NSArray     *slayList = [[self view] slayList];
    float       min = LARGENEG_COORD, max = LARGE_COORD;
    float       v = [xField floatValue];
    BOOL        control = [(App*)NSApp control];
    id          change;

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
    v = [[self view] pointAbsolute:NSMakePoint(v, 0.0)].x;

    change = [[MovePointGraphicsChange alloc] initGraphicView:[self view] ptNum:0 moveAll:YES];
    [change startChange];
        cnt = [slayList count];
        for (l=0; l<cnt; l++)
        {   NSMutableArray *slist = [slayList objectAtIndex:l];

            if (![[[[self view] layerList] objectAtIndex:l] editable])
                continue;
            for (i=[slist count]-1; i>=0; i--)
            {   id	g = [slist objectAtIndex:i];

                if ( [g isKindOfClass:[VGroup class]] && [g respondsToSelector:@selector(moveBy:)])
                {   NSPoint	p = [g coordBounds].origin;

                    p.x = v - p.x;
                    p.y = 0.0;
                    [(VGraphic*)g moveBy:p];
                }
            }
        }
        [[self view] drawAndDisplay];
    [change endChange];
}

- (void)setPointY:sender
{   Document    *doc = [[self view] document];
    int         i, l, cnt;
    NSArray     *slayList = [[self view] slayList];
    float       min = LARGENEG_COORD, max = LARGE_COORD;
    float       v = [yField floatValue];
    BOOL        control = [(App*)NSApp control];
    id          change;

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
    [yField setStringValue:vhfStringWithFloat(v)];

    v = [doc convertFrUnit:v];
    v = [[self view] pointAbsolute:NSMakePoint(0.0, v)].y;
    //[[self view] movePoint:0 to:NSMakePoint(0.0, v) x:NO y:YES all:YES];

    change = [[MovePointGraphicsChange alloc] initGraphicView:[self view] ptNum:0 moveAll:YES];
    [change startChange];
        cnt = [slayList count];
        for (l=0; l<cnt; l++)
        {   NSMutableArray *slist = [slayList objectAtIndex:l];

            if (![[[[self view] layerList] objectAtIndex:l] editable])
                continue;
            for (i=[slist count]-1; i>=0; i--)
            {   id	g = [slist objectAtIndex:i];

                if ( [g isKindOfClass:[VGroup class]] && [g respondsToSelector:@selector(moveBy:)])
                {   NSPoint	p = [g coordBounds].origin;

                    p.x = 0.0;
                    p.y = v - p.y;
                    [(VGraphic*)g moveBy:p];
                }
            }
        }
        [[self view] drawAndDisplay];
    [change endChange];
}

- (void)setSizeW:sender
{   Document    *doc = [[self view] document];
    float       min = 0.0, max = LARGE_COORD;
    float       v = [wField floatValue];
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
    [wField setStringValue:vhfStringWithFloat(v)];

    v = [doc convertFrUnit:v];
    [[self view] takeWidth:v height:0.0];
}

- (void)setSizeH:sender
{   Document    *doc = [[self view] document];
    float       min = 0.0, max = LARGE_COORD;
    float       v = [hField floatValue];
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
    [hField setStringValue:vhfStringWithFloat(v)];

    v = [doc convertFrUnit:v];
    [[self view] takeWidth:0.0 height:v];
}

- (void)displayWillEnd
{
}

@end
