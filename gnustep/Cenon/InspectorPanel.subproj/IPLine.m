/* IPLine.m
 * Line Inspector
 *
 * Copyright (C) 1995-2012 by vhf interservice GmbH
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
#include "IPLine.h"

@implementation IPLine

- (void)update:sender
{   Document    *doc = [[self view] document];
    DocView     *view = [self view];
    VGraphic    *g = sender;
    NSPoint     p;
    float       f;

    [graphic release];
    graphic = [sender retain];

    [super update:sender];

    /*[xField setEnabled:([g selectedKnobIndex]>=0) ? YES : NO];
    [yField setEnabled:([g selectedKnobIndex]>=0) ? YES : NO];
    if ( [g selectedKnobIndex]>=0 )
    {	NSPoint	p = [g pointWithNum:[g selectedKnobIndex]];
        [xField setStringValue:buildRoundedString(convertToUnit(p.x), LARGENEG_COORD, LARGE_COORD)];
        [yField setStringValue:buildRoundedString(convertToUnit(p.y), LARGENEG_COORD, LARGE_COORD)];
    }*/

    p = [view pointRelativeOrigin:[g pointWithNum:0]];
    [xField setStringValue:buildRoundedString([doc convertToUnit:p.x], LARGENEG_COORD, LARGE_COORD)];
    [yField setStringValue:buildRoundedString([doc convertToUnit:p.y], LARGENEG_COORD, LARGE_COORD)];

    f = [g angle];
    [angleField setStringValue:buildRoundedString(f, LARGENEG_COORD, LARGE_COORD)];
    [angleSlider setFloatValue:f];

    [lengthField setStringValue:buildRoundedString([doc convertToUnit:[g length]], LARGENEG_COORD, LARGE_COORD)];

    p = [view pointRelativeOrigin:[g pointWithNum:1]];
    [endXField setStringValue:buildRoundedString([doc convertToUnit:p.x], LARGENEG_COORD, LARGE_COORD)];
    [endYField setStringValue:buildRoundedString([doc convertToUnit:p.y], LARGENEG_COORD, LARGE_COORD)];
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

    if (v < min)	v = min;
    if (v > max)	v = max;
    //[xField setStringValue:vhfStringWithFloat(v)];

    v = [doc convertFrUnit:v];
    [[self view] movePoint:0 to:[[self view] pointAbsolute:NSMakePoint(v, 0.0)] x:YES y:NO all:NO];
    [self update:graphic];
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

    if (v < min)	v = min;
    if (v > max)	v = max;
    //[yField setStringValue:vhfStringWithFloat(v)];

    v = [doc convertFrUnit:v];
    [[self view] movePoint:0 to:[[self view] pointAbsolute:NSMakePoint(0.0, v)] x:NO y:YES all:NO];
    [self update:graphic];
}

- (void)setAngle:sender
{   //float	min = 0.0, max = 360.0;
    float	v = [angleField floatValue];
    BOOL	control = [(App*)NSApp control];

    if ( [sender isKindOfClass:[NSSlider class]] )  // slider
        v = [angleSlider floatValue];
    else if ( [sender isKindOfClass:[NSButton class]] )
        switch ( [(NSButton*)sender tag] )
        {
            case BUTTONLEFT:	v -= ((control) ? 5.0 : 1.0); break;
            case BUTTONRIGHT:	v += ((control) ? 5.0 : 1.0);
        }

    //if ( v < 0.0 )
    //    v += 360.0;
    //if (v < min) v = min;
    //if (v > max) v = max;
    v = vhfModulo(v, 360.0);
    //[angleField setStringValue:vhfStringWithFloat(v)];
    //[angleSlider setFloatValue:v];

    [[self view] takeAngle:v angleNum:1];
    [self update:graphic];
}

- (void)setLength:sender
{   Document    *doc = [[self view] document];
    float       min = 0.0, max = LARGE_COORD;
    float       v = [lengthField floatValue];
    BOOL        control = [(App*)NSApp control];

    if ( [sender isKindOfClass:[NSButton class]] )
        switch ( [(NSButton*)sender tag] )
        {
            case BUTTONLEFT:	v -= ((control) ? 1.0 : 0.1); break;
            case BUTTONRIGHT:	v += ((control) ? 1.0 : 0.1);
        }

    if (v < min) v = min;
    if (v > max) v = max;
    //[lengthField setStringValue:vhfStringWithFloat(v)];

    v = [doc convertFrUnit:v];
    [[self view] takeLength:v];
    [self update:graphic];
}

- (void)setEndX:sender
{   Document    *doc = [[self view] document];
    float       min = LARGENEG_COORD, max = LARGE_COORD;
    float       v = [endXField floatValue];
    BOOL        control = [(App*)NSApp control];

    if ([sender isKindOfClass:[NSButton class]])
        switch ([(NSButton*)sender tag])
        {
            case BUTTONLEFT:	v -= ((control) ? 10.0 : 1.0); break;
            case BUTTONRIGHT:	v += ((control) ? 10.0 : 1.0);
        }

    if (v < min)	v = min;
    if (v > max)	v = max;
    //[endXField setStringValue:vhfStringWithFloat(v)];

    v = [doc convertFrUnit:v];
    [[self view] movePoint:1 to:[[self view] pointAbsolute:NSMakePoint(v, 0.0)] x:YES y:NO all:NO];
    [self update:graphic];
}
- (void)setEndY:sender
{   Document    *doc = [[self view] document];
    float       min = LARGENEG_COORD, max = LARGE_COORD;
    float       v = [endYField floatValue];
    BOOL        control = [(App*)NSApp control];

    if ([sender isKindOfClass:[NSButton class]])
        switch ([(NSButton*)sender tag])
        {
            case BUTTONLEFT:	v -= ((control) ? 10.0 : 1.0); break;
            case BUTTONRIGHT:	v += ((control) ? 10.0 : 1.0);
        }

    if (v < min)	v = min;
    if (v > max)	v = max;
    //[endYField setStringValue:vhfStringWithFloat(v)];

    v = [doc convertFrUnit:v];
    [[self view] movePoint:1 to:[[self view] pointAbsolute:NSMakePoint(0.0, v)] x:NO y:YES all:NO];
    [self update:graphic];
}

- (void)displayWillEnd
{
}

@end
