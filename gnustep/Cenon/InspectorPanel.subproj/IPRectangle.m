/* IPRectangle.m
 * Rectangle Inspector
 *
 * Copyright (C) 1995-2012 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1997-11-14
 * modified: 2012-02-28 (-update: set modulo of rotAngle, -setAngle: set modulo of angle)
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
#include "../Graphics.h"
#include "../LayerObject.h"
#include "InspectorPanel.h"
#include "IPRectangle.h"
#include "../graphicsUndo.subproj/undo.h"

@implementation IPRectangle

- (void)update:sender
{   Document    *doc = [[self view] document];
    DocView     *view = [self view];
    id          g = sender;
    NSPoint     p;
    NSSize      s;

    [super update:sender];
    [angleField setStringValue:buildRoundedString(vhfModulo([g rotAngle], 360.0), 0.0, 360.0)];
    p = [view pointRelativeOrigin:[g pointWithNum:PT_LL]];
    [xField setStringValue:buildRoundedString([doc convertToUnit:p.x], LARGENEG_COORD, LARGE_COORD)];
    [yField setStringValue:buildRoundedString([doc convertToUnit:p.y], LARGENEG_COORD, LARGE_COORD)];
    s = [g size];
    [sizeWidthField  setStringValue:buildRoundedString([doc convertToUnit:s.width],    0.0, LARGE_COORD)];
    [sizeHeightField setStringValue:buildRoundedString([doc convertToUnit:s.height],   0.0, LARGE_COORD)];
    [radiusField     setStringValue:buildRoundedString([doc convertToUnit:[g radius]], 0.0, LARGE_COORD)];
}

- (void)setAngle:sender
{   int		i, l, cnt;
    NSArray *slayList = [[self view] slayList];
    //float	min = 0.0, max = 360.0;
    float	v = [angleField floatValue];
    BOOL	control = [(App*)NSApp control];
    id		change;

    if ([sender isKindOfClass:[NSSlider class]])	/* slider */
        v = [angleSlider floatValue];
    else if ([sender isKindOfClass:[NSButton class]])
        switch ([(NSButton*)sender tag])
        {
            case BUTTONLEFT:	v -= ((control) ? 5.0 : 1.0); break;
            case BUTTONRIGHT:	v += ((control) ? 5.0 : 1.0);
        }

    //if (v < min) v = min;
    //if (v > max) v = max;
    v = vhfModulo(v, 360.0);
    [angleField setStringValue:vhfStringWithFloat(v)];

    change = [[RotateGraphicsChange alloc] initGraphicView:[self view] angle:-v];
    [change startChange];
        cnt = [slayList count];
        for (l=0; l<cnt; l++)
        {   NSMutableArray *slist = [slayList objectAtIndex:l];

            if (![[[[self view] layerList] objectAtIndex:l] editable])
                continue;
            for (i=[slist count]-1; i>=0; i--)
            {   id	g = [slist objectAtIndex:i];

                if ([g respondsToSelector:@selector(setRotAngle:)] && [g isKindOfClass:[VRectangle class]])
                {   [(VRectangle*)g setRotAngle:v];
                    [[[[self view] layerList] objectAtIndex:l] updateObject:g];
                }
            }
        }
        [[self view] drawAndDisplay];
    [change endChange];
}

- (void)setX:sender
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
    [[self view] movePointTo:[[self view] pointAbsolute:NSMakePoint(v, 0.0)] x:YES y:NO all:YES];
}

- (void)setY:sender
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
    [[self view] movePointTo:[[self view] pointAbsolute:NSMakePoint(0.0, v)] x:NO y:YES all:YES];
}

- (void)setSizeWidth:sender
{   Document    *doc = [[self view] document];
    float       min = 0.0, max = LARGE_COORD;
    float       v = [sizeWidthField floatValue];
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
    [sizeWidthField setStringValue:vhfStringWithFloat(v)];

    v = [doc convertFrUnit:v];
    [[self view] takeWidth:v height:0.0];
}

- (void)setSizeHeight:sender
{   Document    *doc = [[self view] document];
    float       min = 0.0, max = LARGE_COORD;
    float       v = [sizeHeightField floatValue];
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
    [sizeHeightField setStringValue:vhfStringWithFloat(v)];

    v = [doc convertFrUnit:v];
    [[self view] takeWidth:0.0 height:v];

    [[self view] drawAndDisplay];
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

- (void)displayWillEnd
{	 
}

@end
