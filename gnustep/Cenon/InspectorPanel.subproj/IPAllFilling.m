/* IPAllFilling.m
 * Fill Inspector for all objects
 *
 * Copyright (C) 2002-2008 by vhf interservice GmbH
 * Author:   Ilonka Fleischmann
 *
 * created:  2002-06-27
 * modified: 2008-03-21
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
#include "InspectorPanel.h"
#include "IPAllFilling.h"
#include "SliderBox.h"

@implementation IPAllFilling

- init
{
    [super init];
    [fillPopup setTarget:self];
    [fillPopup setAction:@selector(setFillState:)];
    [fillPopup setAutoenablesItems:NO];
    [sliderBox setTarget: self];
    [sliderBox setAction: @selector(setRadialCenter:)];
    //[[NSColorPanel sharedColorPanel] setShowsAlpha:YES];
    return self;
}

- (void)update:sender
{   id		g = sender;
    float	a = 0.0;
    int		fillState = [g filled], fillSel=0;
    BOOL	fill0=YES, fill1=YES, fill2=YES, fill3=YES , fill4=YES;
    BOOL	colFill=YES, colEnd=YES, angle=YES, step=YES, center=YES;

    if (graphic != g)
    {   [(NSColorWell*)colorWell deactivate];
        [(NSColorWell*)colorWellGraduated deactivate];
    }
    graphic = sender;
    if ([g filled] && [g respondsToSelector:@selector(fillColor)])
    {
        [(NSColorWell*)colorWell          setColor:(([g fillColor]) ? [g fillColor] : [NSColor blackColor])];
        [(NSColorWell*)colorWellGraduated setColor:(([g endColor])  ? [g endColor]  : [NSColor blackColor])];
        [angleSlider setFloatValue:[g graduateAngle]];
        [angleField setStringValue:buildRoundedString([g graduateAngle], 0.0, 360.0)];
        [stepForm setStringValue:buildRoundedString([g stepWidth], 0.1, 100.0)];
    }
    else
    {   [(NSColorWell*)colorWell setColor:[NSColor blackColor]];
        [(NSColorWell*)colorWellGraduated setColor:[NSColor blackColor]];
        [angleSlider setFloatValue:a];
        [angleField  setStringValue:buildRoundedString(a, 0.0, 360.0)];
        [stepForm    setStringValue:buildRoundedString(a, 0.1, 100.0)];
    }
    /* Text, TextPath - only basic filling possible */
    if ([g isKindOfClass:[VText class]] || [g isKindOfClass:[VTextPath class]])
    {   //colFill = YES;
        colEnd = NO;
        angle = NO;
        step = NO;
        center = NO;
        fillSel = 1;
        fill0 = NO; fill2 = NO; fill3 = NO; fill4 = NO;
        [(NSColorWell*)colorWell setColor:(([g fillColor]) ? [g fillColor] : [NSColor blackColor])];
    }
    else if (!g || [g isKindOfClass:[VImage class]]      || [g isKindOfClass:[VThread class]] ||
                   [g isKindOfClass:[VSinking class]]    || [g isKindOfClass:[VMark class]]   ||
                   [g isKindOfClass:[VCrosshairs class]] || [g isKindOfClass:[VCurve class]]  ||
                   [g isKindOfClass:[VLine class]])
    {	/* everything is disabled */
        colFill = NO; colEnd = NO;
        angle = NO;
        step = NO;
        center = NO;
        fillSel = 0;
        fill1 = NO; fill2 = NO; fill3 = NO; fill4 = NO;
    }
    else if (fillState)
    {	fillSel = fillState;
        [(NSColorWell*)colorWell setColor:(([g fillColor]) ? [g fillColor] : [NSColor blackColor])];

        if (fillState == 4)
        {   a = [g graduateAngle];
            [(NSColorWell*)colorWellGraduated setColor:[g endColor]];
            [stepForm setStringValue:buildRoundedString([g stepWidth], 0.1, 100.0)];
            [sliderBox setLocation:[g radialCenter]];
            [angleField setStringValue:buildRoundedString(a, 0.0, 360.0)];
            [angleSlider setFloatValue:a];
        }
        else if (fillState == 3)
        {   a = [g graduateAngle];
            [(NSColorWell*)colorWellGraduated setColor:[g endColor]];
            [stepForm setStringValue:buildRoundedString([g stepWidth], 0.1, 100.0)];
            [sliderBox setLocation:[g radialCenter]];
            angle = NO;
        }
        else if (fillState == 2)
        {   a = [g graduateAngle];
            [(NSColorWell*)colorWellGraduated setColor:[g endColor]];
            [angleField setStringValue:buildRoundedString(a, 0.0, 360.0)];
            [angleSlider setFloatValue:a];
            [stepForm setStringValue:buildRoundedString([g stepWidth], 0.1, 100.0)];
            center = NO;
        }
        else
        {   colEnd = NO;
            angle = NO;
            step = NO;
            center = NO;
        }
    }
    else
    {	fillSel = fillState;
        colFill = NO; colEnd = NO;
        angle = NO;
        step = NO;
        center = NO;
    }

    [fillPopup selectItemAtIndex:fillSel];
    [[fillPopup itemAtIndex:0] setEnabled:fill0];
    [[fillPopup itemAtIndex:1] setEnabled:fill1];
    [[fillPopup itemAtIndex:2] setEnabled:fill2];
    [[fillPopup itemAtIndex:3] setEnabled:fill3];
    [[fillPopup itemAtIndex:4] setEnabled:fill4];
    [(NSColorWell*)colorWell setEnabled:colFill];
    [(NSColorWell*)colorWellGraduated setEnabled:colEnd];
    [angleField setEnabled:angle];
    [angleSlider setEnabled:angle];
    [angleButtonLeft setEnabled:angle];
    [angleButtonRight setEnabled:angle];
    [sliderBox setEnabled:center];
    [radialCenterText setEnabled:center];
    [stepForm setEnabled:step];
    [stepButtonLeft setEnabled:step];
    [stepButtonRight setEnabled:step];
}

- (void)setAngle:sender
{   float	min = 0.0, max = 360.0;
    float	v = [angleField floatValue];
    BOOL	control = [(App*)NSApp control];

    if ([sender isKindOfClass:[NSSlider class]])	// slider
        v = [angleSlider floatValue];
    else if ([sender isKindOfClass:[NSButton class]])
    {
        switch ([(NSButton*)sender tag])
        {
            case BUTTONLEFT:	v -= ((control) ? 5.0 : 1.0); break;
            case BUTTONRIGHT:	v += ((control) ? 5.0 : 1.0);
        }
    }

    if (v < min)	v = min;
    if (v > max)	v = max;
    [angleField setStringValue:vhfStringWithFloat(v)];
    [angleSlider setFloatValue:v];
    [[self view] takeAngle:v angleNum:2]; // 2 graduateAngle
    [self update:graphic];
}

- (void)setStepWidth:sender
{   float	min = 0.1, max = 100.0;
    float	v = [stepForm floatValue];
    BOOL	control = [(App*)NSApp control];

    if ([sender isKindOfClass:[NSButton class]])
    {
        switch ([(NSButton*)sender tag])
        {
            case BUTTONLEFT:	v -= ((control) ? 5.0 : ((v > 1.0) ? 1.0 : 0.1)); break;
            case BUTTONRIGHT:	v += ((control) ? 5.0 : ((v >= 1.0) ? 1.0 : 0.1));
        }
    }
//    v = (int)v;
    if (v < min)	v = min;
    if (v > max)	v = max;
    [stepForm setStringValue:vhfStringWithFloat(v)];
    [[self view] takeStepWidth:v];
    [self update:graphic];
}

- (void)setFillColor:sender
{
    if ([graphic respondsToSelector:@selector(setFillColor:)])
    {   [[self view] takeColorFrom:sender colorNum:1];
        [self update:graphic];
    }
}

- (void)setEndColor:(id)sender
{
    if ([graphic respondsToSelector:@selector(setEndColor:)])
    {   [[self view] takeColorFrom:sender colorNum:2];
        [self update:graphic];
    }
}

- (void)setFillState:(id)sender
{
    if ([graphic respondsToSelector:@selector(setFillColor:)])
    {   [[self view] takeFillFrom:sender];
        [self update:graphic];
    }
}

- (void)setRadialCenter:(id)sender
{    NSPoint	center = [sender locationInPercent]; // in percent

    [[self view] takeRadialCenter:center];
    [self update:graphic];
}

- (void)displayWillEnd
{
    [colorWell deactivate];
    [colorWellGraduated deactivate];
}

@end
