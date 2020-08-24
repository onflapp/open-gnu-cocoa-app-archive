/* IPPolyLine.m
 * PolyLine Inspector
 *
 * Copyright (C) 1995-2008 by vhf interservice GmbH
 * Author:   Ilonka Fleischmann
 *
 * created:  2001-08-30
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
#include "IPPolyLine.h"

@implementation IPPolyLine

- (void)update:sender
{   Document    *doc = [[self view] document];
    DocView     *view = [self view];
    id          g = sender;
    NSPoint     p;

    [super update:sender];
    [xField setEnabled:([g selectedKnobIndex] >= 0) ? YES : NO];
    [yField setEnabled:([g selectedKnobIndex] >= 0) ? YES : NO];
    [xButtonLeft  setEnabled:([g selectedKnobIndex] >= 0) ? YES : NO];
    [xButtonRight setEnabled:([g selectedKnobIndex] >= 0) ? YES : NO];
    [yButtonLeft  setEnabled:([g selectedKnobIndex] >= 0) ? YES : NO];
    [yButtonRight setEnabled:([g selectedKnobIndex] >= 0) ? YES : NO];
    if ( [g selectedKnobIndex] >= 0 )
        p = [view pointRelativeOrigin:[g pointWithNum:[g selectedKnobIndex]]];
    else
        p = NSMakePoint(0.0, 0.0);
    [xField setStringValue:buildRoundedString([doc convertToUnit:p.x], LARGENEG_COORD, LARGE_COORD)];
    [yField setStringValue:buildRoundedString([doc convertToUnit:p.y], LARGENEG_COORD, LARGE_COORD)];
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
    [[self view] movePointTo:[[self view] pointAbsolute:NSMakePoint(v, 0.0)] x:YES y:NO all:NO];
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
    [[self view] movePointTo:[[self view] pointAbsolute:NSMakePoint(0.0, v)] x:NO y:YES all:NO];
}

- (void)displayWillEnd
{
}

@end
