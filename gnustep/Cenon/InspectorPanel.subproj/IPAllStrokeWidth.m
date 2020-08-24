/* IPAllStrokeWidth.m
 * Stroke Inspector for all graphic objects
 *
 * Copyright (C) 2002-2009 by vhf interservice GmbH
 * Author:   Ilonka Fleischmann
 *
 * created:  2002-06-27
 * modified: 2009-02-07 (-update: handle [g color] == nil)
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
#include "InspectorPanel.h"
#include "IPAllStrokeWidth.h"


#define MAXWIDTH	100.0

@implementation IPAllStrokeWidth

- init
{
    [super init];
    stroked = 0;
    [strokePopup setTarget:self];
    [strokePopup setAction:@selector(setStrokeState:)];
    [strokePopup setAutoenablesItems:NO];
    return self;
}

- (void)update:sender
{   VGraphic    *g = sender;
    Document    *doc = [[self view] document];

    /* multiple graphics ? (line, curve, arc, rectangle, polyline, path) */
    if ([g isMemberOfClass:[VCrosshairs class]])
    {   int     i, l, cnt;
        NSArray *slayList = [[self view] slayList];

        /* set width of all objects */
        cnt = [slayList count];
        for (l=0; l<cnt; l++)
        {   NSMutableArray *slist = [slayList objectAtIndex:l];

            if (![[[[self view] layerList] objectAtIndex:l] editable])
                continue;
            for (i=[slist count]-1; i>=0; i--)
            {   id	gr = [slist objectAtIndex:i];

                if ([gr isKindOfClass:[VImage        class]] || [gr isKindOfClass:[VThread   class]] ||
                    [gr isKindOfClass:[VSinking      class]] || [gr isMemberOfClass:[VMark   class]] ||
                    [gr isMemberOfClass:[VCrosshairs class]] || [gr isKindOfClass:[VGroup    class]] ||
                    [gr isKindOfClass:[VText         class]] || [gr isKindOfClass:[VTextPath class]])
                {
                    g = sender;
                    break;
                }
                else if ([g isMemberOfClass:[VCrosshairs class]])
                    g = gr;
            }
        }
    }

    if (graphic != g && ![g width])
        stroked = 0;

    if (graphic != g)
        [(NSColorWell*)colorWell deactivate];
    graphic = g;

    /* init */
    [(NSColorWell*)colorWell setColor:([g color]) ? [g color] : [NSColor blackColor]];
    [widthField setStringValue:buildRoundedString(0.0, LARGENEG_COORD, LARGE_COORD)];
    [widthSlider setMaxValue:[doc convertMMToUnit:MAXWIDTH]];
    [widthSlider setFloatValue:0.0];
    [[strokePopup itemAtIndex:0] setEnabled:YES]; // allways enabled

    if (!g || [g isKindOfClass:[VImage        class]] || [g isKindOfClass:[VThread class]] ||
              [g isKindOfClass:[VSinking      class]] || [g isMemberOfClass:[VMark class]] ||
              [g isMemberOfClass:[VCrosshairs class]] || [g isKindOfClass:[VText   class]] ||
              [g isKindOfClass:[VTextPath     class]])
    {
        [[strokePopup itemAtIndex:0] setEnabled:YES];
        [[strokePopup itemAtIndex:1] setEnabled:NO];
        [strokePopup selectItemAtIndex:0];
        [(NSColorWell*)colorWell setEnabled:NO];
        [widthField setEnabled:NO];
        [widthSlider setEnabled:NO];
        [widthButtonLeft setEnabled:NO];
        [widthButtonRight setEnabled:NO];
    }
    else
    {
        [[strokePopup itemAtIndex:0] setEnabled:YES];
        [[strokePopup itemAtIndex:1] setEnabled:YES];
        [(NSColorWell*)colorWell setEnabled:YES];
        [widthField setEnabled:YES];
        [widthSlider setEnabled:YES];
        [widthField setStringValue:buildRoundedString([doc convertToUnit:[g width]], LARGENEG_COORD, LARGE_COORD)];
        [widthSlider setMaxValue:[doc convertMMToUnit:MAXWIDTH]];
        [widthSlider setFloatValue:[doc convertToUnit:[g width]]];
        [widthButtonLeft setEnabled:YES];
        [widthButtonRight setEnabled:YES];

        if (stroked || [g width]) // everthing is enabled
            [strokePopup selectItemAtIndex:1];
        else
            [strokePopup selectItemAtIndex:0];
    }
}

- (void)setWidth:sender
{   Document    *doc = [[self view] document];
    float       min = 0.0, max = [doc convertMMToUnit:MAXWIDTH];
    float       v = [widthField floatValue];
    BOOL        control = [(App*)NSApp control];

    if ([sender isKindOfClass:[NSSlider class]])	/* slider */
        v = [widthSlider floatValue];
    else if ([sender isKindOfClass:[NSButton class]])
    {
        switch ([(NSButton*)sender tag])
        {
            case BUTTONLEFT:	v -= ((control) ? 1.0 : 0.1); break;
            case BUTTONRIGHT:	v += ((control) ? 1.0 : 0.1);
        }
    }

    if (v < min) v = min;
    if (v > max) v = max;
    [widthField setStringValue:vhfStringWithFloat(v)];
    [widthSlider setFloatValue:v];

    v = [doc convertFrUnit:v];
    if (!v && [[NSApp currentEvent] type] == NSLeftMouseUp) // != NSLeftMouseDragged
        stroked = 0;
    else
        stroked = 1;
    [[self view] takeWidth:v];
    [self update:graphic];
}

- (void)setColor:sender
{
    [[self view] takeColorFrom:sender colorNum:0];
    [self update:graphic];
}

- (void)setStrokeState:(id)sender
{
    stroked = [sender indexOfSelectedItem];
    if (!stroked)
        [[self view] takeWidth:0.0];
    else if (![graphic width])
        [[self view] takeWidth:1.0];
    [self update:graphic];
}

- (void)displayWillEnd
{
    [colorWell deactivate];
}

@end
