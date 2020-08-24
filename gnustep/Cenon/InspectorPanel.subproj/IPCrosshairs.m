/* IPCrosshairs.m
 * Crosshair inspector
 *
 * Copyright (C) 1997-2012 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1995-12-09
 * modified: 2007-04-09
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
#include "../LayerObject.h"
#include "InspectorPanel.h"
#include "IPCrosshairs.h"

#define MAXWIDTH	100.0

@implementation IPCrosshairs

- (void)update:sender
{   Document    *doc = [[self view] document];
    id          g = sender;
    NSPoint     p;

    [super update:sender];

    [g getPoint:[g selectedKnobIndex] :&p];
    [xField setStringValue:buildRoundedString([doc convertToUnit:p.x], LARGENEG_COORD, LARGE_COORD)];
    [yField setStringValue:buildRoundedString([doc convertToUnit:p.y], LARGENEG_COORD, LARGE_COORD)];
}

- (void)setPointX:sender
{   Document    *doc = [[self view] document];
    DocView     *view = [self view];
    id          g;
    float       min = 0.0, max = LARGE_COORD;
    float       v = [xField floatValue];
    BOOL        control = [(App*)NSApp control];
    NSPoint     p;

    if ([sender isKindOfClass:[NSButton class]])
    {
        switch ([(NSButton*)sender tag])
        {
            case BUTTONLEFT:	v -= ((control) ? 1.0 : 0.1); break;
            case BUTTONRIGHT:	v += ((control) ? 1.0 : 0.1);
        }
    }

    if (v < min) v = min;
    if (v > max) v = max;
    [xField setStringValue:vhfStringWithFloat(v)];

    v = [doc convertFrUnit:v];

    g = [(DocView*)view origin];
    [g getPoint:[g selectedKnobIndex] :&p];
    p.x = v;
    if ([g respondsToSelector:@selector(movePoint:to:)])
        [(VGraphic*)g movePoint:[g selectedKnobIndex] to:p];

    [view resetGrid];
    [view cache:NSZeroRect];
}

- (void)setPointY:sender
{   Document    *doc = [[self view] document];
    DocView     *view = [self view];
    id          g;
    float       min = 0.0, max = LARGE_COORD;
    float       v = [yField floatValue];
    BOOL        control = [(App*)NSApp control];
    NSPoint     p;

    if ([sender isKindOfClass:[NSButton class]])
    {
        switch ([(NSButton*)sender tag])
        {
            case BUTTONLEFT:	v -= ((control) ? 1.0 : 0.1); break;
            case BUTTONRIGHT:	v += ((control) ? 1.0 : 0.1);
        }
    }

    if (v < min) v = min;
    if (v > max) v = max;
    [yField setStringValue:vhfStringWithFloat(v)];

    v = [doc convertFrUnit:v];

    g = [view origin];
    [g getPoint:[g selectedKnobIndex] :&p];
    p.y = v;
    if ([g respondsToSelector:@selector(movePoint:to:)])
        [(VGraphic*)g movePoint:[g selectedKnobIndex] to:p];

    [view resetGrid];
    [view cache:NSZeroRect];
}

- (void)displayWillEnd
{
}

@end
