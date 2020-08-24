/* IPLine3D.m
 * 3-D Line Inspector
 *
 * Copyright (C) 1995-2003 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  2002-08-20
 * modified: 2003-06-26
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
#include "IPLine3D.h"

@implementation IPLine3D

- (void)update:sender
{   VGraphic	*g = sender;
    NSPoint	p;
    float	zv0, zv1;
    id		view = [self view];

    [graphic release];
    graphic = [sender retain];

    [super update:sender];
    [(VLine3D*)g getZLevel:&zv0 :&zv1];
    p = [view pointRelativeOrigin:[g pointWithNum:0]];
    [xField setStringValue:buildRoundedString(convertToUnit(p.x), LARGENEG_COORD, LARGE_COORD)];
    [yField setStringValue:buildRoundedString(convertToUnit(p.y), LARGENEG_COORD, LARGE_COORD)];
    [zField setStringValue:buildRoundedString(convertToUnit(zv0), LARGENEG_COORD, LARGE_COORD)];

    [lengthField setStringValue:buildRoundedString(convertToUnit([g length]), LARGENEG_COORD, LARGE_COORD)];

    p = [view pointRelativeOrigin:[g pointWithNum:1]];
    [endXField setStringValue:buildRoundedString(convertToUnit(p.x), LARGENEG_COORD, LARGE_COORD)];
    [endYField setStringValue:buildRoundedString(convertToUnit(p.y), LARGENEG_COORD, LARGE_COORD)];
    [endZField setStringValue:buildRoundedString(convertToUnit(zv1), LARGENEG_COORD, LARGE_COORD)];
}

- (void)setEndX:(id)sender
{   float	min = LARGENEG_COORD, max = LARGE_COORD;
    float	v = [endXField floatValue];
    BOOL	control = [(App*)NSApp control];

    if ([sender isKindOfClass:[NSButton class]])
        switch ([sender tag])
        {
            case BUTTONLEFT:	v -= ((control) ? 10.0 : 1.0); break;
            case BUTTONRIGHT:	v += ((control) ? 10.0 : 1.0);
        }

    if (v < min) v = min;
    if (v > max) v = max;
    //[endXField setStringValue:vhfStringWithFloat(v)];

    v = convertFromUnit(v);
    [[self view] movePoint:1 to:[[self view] pointAbsolute:NSMakePoint(v, 0.0)] x:YES y:NO all:NO];
    [self update:graphic];
}

- (void)setEndY:(id)sender
{   float	min = LARGENEG_COORD, max = LARGE_COORD;
    float	v = [endYField floatValue];
    BOOL	control = [(App*)NSApp control];

    if ([sender isKindOfClass:[NSButton class]])
        switch ([sender tag])
        {
            case BUTTONLEFT:	v -= ((control) ? 10.0 : 1.0); break;
            case BUTTONRIGHT:	v += ((control) ? 10.0 : 1.0);
        }

    if (v < min) v = min;
    if (v > max) v = max;
    //[endYField setStringValue:vhfStringWithFloat(v)];

    v = convertFromUnit(v);
    [[self view] movePoint:1 to:[[self view] pointAbsolute:NSMakePoint(0.0, v)] x:NO y:YES all:NO];
    [self update:graphic];
}

- (void)setEndZ:(id)sender
{   int		l, cnt, i;
    id		slayList = [[self view] slayList];
    float	min = LARGENEG_COORD, max = LARGE_COORD;
    float	v = [endZField floatValue];
    BOOL	control = [(App*)NSApp control];

    if ([sender isKindOfClass:[NSButton class]])
        switch ([sender tag])
        {
            case BUTTONLEFT:	v -= ((control) ? 10.0 : 1.0); break;
            case BUTTONRIGHT:	v += ((control) ? 10.0 : 1.0);
        }

    if (v < min)	v = min;
    if (v > max)	v = max;
    //[endZField setStringValue:vhfStringWithFloat(v)];

    v = convertFromUnit(v);

    /* set z level of all objects */
    cnt = [slayList count];
    for (l=0; l<cnt; l++)
    {	NSMutableArray *slist = [slayList objectAtIndex:l];

        if (![[[[self view] layerList] objectAtIndex:l] editable])
            continue;
        for (i=[slist count]-1; i>=0; i--)
        {   id	g = [slist objectAtIndex:i];

            if ([g isMemberOfClass:[VLine3D class]]) // [g respondsToSelector:@selector(setZLevel:)]
            {   float	zv0, zv1;

                [(VLine3D*)g getZLevel:&zv0 :&zv1];
                [(VLine3D*)g setZLevel:zv0 :v];
                [[[self view] document] setDirty:YES];
            }
        }
    }

    [[self view] drawAndDisplay];
    [self update:graphic];
}

- (void)setLength:(id)sender
{   float	min = 0.0, max = LARGE_COORD;
    float	v = [lengthField floatValue];
    BOOL	control = [(App*)NSApp control];

    if ( [sender isKindOfClass:[NSButton class]] )
        switch ( [sender tag] )
        {
            case BUTTONLEFT:	v -= ((control) ? 1.0 : 0.1); break;
            case BUTTONRIGHT:	v += ((control) ? 1.0 : 0.1);
        }

    if (v < min)	v = min;
    if (v > max)	v = max;
    //[lengthField setStringValue:vhfStringWithFloat(v)];

    v = convertFromUnit(v);
    [[self view] takeLength:v];
    [self update:graphic];
}

- (void)setLock:(id)sender
{
}

- (void)setPointX:(id)sender
{   float	min = LARGENEG_COORD, max = LARGE_COORD;
    float	v = [xField floatValue];
    BOOL	control = [(App*)NSApp control];

    if ([sender isKindOfClass:[NSButton class]])
    {
        switch ([sender tag])
        {
            case BUTTONLEFT:	v -= ((control) ? 10.0 : 1.0); break;
            case BUTTONRIGHT:	v += ((control) ? 10.0 : 1.0);
        }
    }

    if (v < min)	v = min;
    if (v > max)	v = max;
    //[xField setStringValue:vhfStringWithFloat(v)];

    v = convertFromUnit(v);
    [[self view] movePoint:0 to:[[self view] pointAbsolute:NSMakePoint(v, 0.0)] x:YES y:NO all:NO];
    [self update:graphic];
}

- (void)setPointY:(id)sender
{   float	min = LARGENEG_COORD, max = LARGE_COORD;
    float	v = [yField floatValue];
    BOOL	control = [(App*)NSApp control];

    if ([sender isKindOfClass:[NSButton class]])
    {
        switch ([sender tag])
        {
            case BUTTONLEFT:	v -= ((control) ? 10.0 : 1.0); break;
            case BUTTONRIGHT:	v += ((control) ? 10.0 : 1.0);
        }
    }

    if (v < min)	v = min;
    if (v > max)	v = max;
    //[yField setStringValue:vhfStringWithFloat(v)];

    v = convertFromUnit(v);
    [[self view] movePoint:0 to:[[self view] pointAbsolute:NSMakePoint(0.0, v)] x:NO y:YES all:NO];
    [self update:graphic];
}

- (void)setPointZ:(id)sender
{   int		l, cnt, i;
    id		slayList = [[self view] slayList];
    float	min = LARGENEG_COORD, max = LARGE_COORD;
    float	v = [zField floatValue];
    BOOL	control = [(App*)NSApp control];

    if ([sender isKindOfClass:[NSButton class]])
        switch ([sender tag])
        {
            case BUTTONLEFT:	v -= ((control) ? 10.0 : 1.0); break;
            case BUTTONRIGHT:	v += ((control) ? 10.0 : 1.0);
        }

    if (v < min)	v = min;
    if (v > max)	v = max;

    v = convertFromUnit(v);

    /* set z level of all objects */
    cnt = [slayList count];
    for (l=0; l<cnt; l++)
    {	NSMutableArray *slist = [slayList objectAtIndex:l];

        if (![[[[self view] layerList] objectAtIndex:l] editable])
            continue;
        for (i=[slist count]-1; i>=0; i--)
        {   id	g = [slist objectAtIndex:i];

            if ([g isMemberOfClass:[VLine3D class]])
            {   float	zv0, zv1;

                [(VLine3D*)g getZLevel:&zv0 :&zv1];
                [(VLine3D*)g setZLevel:v :zv1];
                [[[self view] document] setDirty:YES];
            }
        }
    }
    [[self view] drawAndDisplay];
    [self update:graphic];
}

- (void)displayWillEnd
{
}

@end
