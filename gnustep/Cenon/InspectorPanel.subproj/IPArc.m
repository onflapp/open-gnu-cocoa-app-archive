/* IPArc.m
 * Arc Inspector
 *
 * Copyright (C) 1995-2012 by vhf interservice GmbH
 * Author:    Georg Fleischmann
 *
 * created:  1995-12-09
 * modified: 2012-02-28 (-setBegAngle: allow entering negative angle)
 *           2005-07-19 (document units)
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
#include "IPArc.h"
#include "../graphicsUndo.subproj/undo.h"

@implementation IPArc

- (void)update:sender
{   Document    *doc = [[self view] document];
    DocView     *view = [self view];
    id          g = sender;
    NSPoint     p, s;
    float       a;

    [super update:sender];
    [g getCenter:&p start:&s angle:&a];
    p = [view pointRelativeOrigin:p];
    [centerXField   setStringValue:buildRoundedString([doc convertToUnit:p.x], LARGENEG_COORD, LARGE_COORD)];
    [centerYField   setStringValue:buildRoundedString([doc convertToUnit:p.y], LARGENEG_COORD, LARGE_COORD)];
    [angleField     setStringValue:buildRoundedString(a, -360.0, 360.0)];
    [angleSlider    setFloatValue:a];
    [begAngleField  setStringValue:buildRoundedString([g begAngle], 0.0, 360.0)];
    [begAngleSlider setFloatValue:[g begAngle]];
    [radiusField    setStringValue:buildRoundedString([doc convertToUnit:[g radius]], 0.0, LARGE_COORD)];
}

- (void)setCenterX:sender
{   Document    *doc = [[self view] document];
    float       min = LARGENEG_COORD, max = LARGE_COORD;
    float       v = [centerXField floatValue];
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
    [centerXField setStringValue:vhfStringWithFloat(v)];

    v = [doc convertFrUnit:v];
    [[self view] movePoint:PT_CENTER to:[[self view] pointAbsolute:NSMakePoint(v, 0.0)] x:YES y:NO all:NO];
}

- (void)setCenterY:sender
{   Document    *doc = [[self view] document];
    float       min = LARGENEG_COORD, max = LARGE_COORD;
    float       v = [centerYField floatValue];
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
    [centerYField setStringValue:vhfStringWithFloat(v)];

    v = [doc convertFrUnit:v];
    [[self view] movePoint:PT_CENTER to:[[self view] pointAbsolute:NSMakePoint(0.0, v)] x:NO y:YES all:NO];
}

- (void)setRadius:sender
{   Document    *doc = [[self view] document];
    float       min = 0.0, max = LARGE_COORD;
    float       v = [radiusField floatValue];
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
    [radiusField setStringValue:vhfStringWithFloat(v)];

    v = [doc convertFrUnit:v];
    [[self view] takeRadius:v];
}

- (void)setBegAngle:sender
{   float	min = 0.0, max = 360.0;
    float	v = [begAngleField floatValue];
    BOOL	control = [(App*)NSApp control];

    if ([sender isKindOfClass:[NSSlider class]])	/* slider */
        v = [begAngleSlider floatValue];
    else if ([sender isKindOfClass:[NSButton class]])
    {
        switch ([(NSButton*)sender tag])
        {
            case BUTTONLEFT:	v -= ((control) ? 5.0 : 1.0); break;
            case BUTTONRIGHT:	v += ((control) ? 5.0 : 1.0);
        }
    }

    if ( v < 0.0 )  v += 360.0;
    if (v < min)    v = min;
    if (v > max)    v = max;
    [begAngleField setStringValue:vhfStringWithFloat(v)];
    [begAngleSlider setFloatValue:v];
    [[self view] takeAngle:v angleNum:0];
}

- (void)setAngle:sender
{   float	min = -360.0, max = 360.0;
    float	v = [angleField floatValue];
    BOOL	control = [(App*)NSApp control];

    if ([sender isKindOfClass:[NSSlider class]])	/* slider */
        v = [angleSlider floatValue];
    else if ([sender isKindOfClass:[NSButton class]])
    {
        switch ([(NSButton*)sender tag])
        {
            case BUTTONLEFT:	v -= ((control) ? 5.0 : 1.0); break;
            case BUTTONRIGHT:	v += ((control) ? 5.0 : 1.0);
        }
    }

    if (v < min) v = min;
    if (v > max) v = max;
    [angleField setStringValue:vhfStringWithFloat(v)];
    [angleSlider setFloatValue:v];
    [[self view] takeAngle:v angleNum:1];
}

@end
