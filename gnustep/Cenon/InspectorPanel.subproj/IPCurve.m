/* IPCurve.m
 * Curve inspector
 *
 * Copyright (C) 1995-2008 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1996-04-24
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
#include "IPCurve.h"

@implementation IPCurve

- (void)update:sender
{   Document    *doc = [[self view] document];
    DocView     *view = [self view];
    id          g = sender;
    NSPoint     p;

    graphic = g;

    [super update:sender];

    [g getPoint:0 :&p];
    p = [view pointRelativeOrigin:p];
    [xField setStringValue:buildRoundedString([doc convertToUnit:p.x], LARGENEG_COORD, LARGE_COORD)];
    [yField setStringValue:buildRoundedString([doc convertToUnit:p.y], LARGENEG_COORD, LARGE_COORD)];
    [g getPoint:1 :&p];
    p = [view pointRelativeOrigin:p];
    [xc1Field setStringValue:buildRoundedString([doc convertToUnit:p.x], LARGENEG_COORD, LARGE_COORD)];
    [yc1Field setStringValue:buildRoundedString([doc convertToUnit:p.y], LARGENEG_COORD, LARGE_COORD)];
    [g getPoint:2 :&p];
    p = [view pointRelativeOrigin:p];
    [xc2Field setStringValue:buildRoundedString([doc convertToUnit:p.x], LARGENEG_COORD, LARGE_COORD)];
    [yc2Field setStringValue:buildRoundedString([doc convertToUnit:p.y], LARGENEG_COORD, LARGE_COORD)];
    [g getPoint:3 :&p];
    p = [view pointRelativeOrigin:p];
    [xeField setStringValue:buildRoundedString([doc convertToUnit:p.x], LARGENEG_COORD, LARGE_COORD)];
    [yeField setStringValue:buildRoundedString([doc convertToUnit:p.y], LARGENEG_COORD, LARGE_COORD)];
}

- (void)setPointX:sender
{   Document    *doc = [[self view] document];
    float       min = LARGENEG_COORD, max = LARGE_COORD;
    BOOL        control = [(App*)NSApp control];
    int         n = ( (sender == xField      || sender == [xField controlView] ||
                       sender == xButtonLeft || sender == xButtonRight) ? 0 : 3);
                    /* ([graphic selectedKnobIndex] < 2) ? 0 : 3; */
    float       v = [((n == 0) ? xField : xeField) floatValue];

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
    [((n == 0) ? xField : xeField) setStringValue:vhfStringWithFloat(v)];

    v = [doc convertFrUnit:v];
    [[self view] movePoint:n to:[[self view] pointAbsolute:NSMakePoint(v, 0.0)] x:YES y:NO all:NO];
    [self update:graphic];
}

- (void)setPointY:sender
{   Document    *doc = [[self view] document];
    float       min = LARGENEG_COORD, max = LARGE_COORD;
    BOOL        control = [(App*)NSApp control];
    int         n = ( (sender == yField      || sender == [yField controlView] ||
                       sender == yButtonLeft || sender == yButtonRight) ? 0 : 3);
                    /* ([graphic selectedKnobIndex] < 2) ? 0 : 3; */
    float       v = [((n == 0) ? yField : yeField) floatValue];

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
    [((n == 0) ? yField : yeField) setStringValue:vhfStringWithFloat(v)];

    v = [doc convertFrUnit:v];
    [[self view] movePoint:n to:[[self view] pointAbsolute:NSMakePoint(0.0, v)] x:NO y:YES all:NO];
    [self update:graphic];
}

- (void)setControlX:sender
{   Document    *doc = [[self view] document];
    float       min = LARGENEG_COORD, max = LARGE_COORD;
    BOOL        control = [(App*)NSApp control];
    int         n = ( (sender == xc1Field || sender == [xc1Field controlView] ||
                       sender == xc1ButtonLeft || sender == xc1ButtonRight) ? 1 : 2);
                    /* ([graphic selectedKnobIndex] < 2) ? 1 : 2; */
    float       v = [((n == 1) ? xc1Field : xc2Field) floatValue];

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
    [((n == 1) ? xc1Field : xc2Field) setStringValue:vhfStringWithFloat(v)];

    v = [doc convertFrUnit:v];
    [[self view] movePoint:n to:[[self view] pointAbsolute:NSMakePoint(v, 0.0)] x:YES y:NO all:NO];
}

- (void)setControlY:sender
{   Document    *doc = [[self view] document];
    float       min = LARGENEG_COORD, max = LARGE_COORD;
    BOOL        control = [(App*)NSApp control];
    int         n = ( (sender == yc1Field || sender == [yc1Field controlView] ||
                       sender == yc1ButtonLeft || sender == yc1ButtonRight) ? 1 : 2);
                    /* ([graphic selectedKnobIndex] < 2) ? 1 : 2; */
    float       v = [((n == 1) ? yc1Field : yc2Field) floatValue];

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
    [((n == 1) ? yc1Field : yc2Field) setStringValue:vhfStringWithFloat(v)];

    v = [doc convertFrUnit:v];
    [[self view] movePoint:n to:[[self view] pointAbsolute:NSMakePoint(0.0, v)] x:NO y:YES all:NO];
}


- (void)displayWillEnd
{
}

@end
