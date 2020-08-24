/*
 * apContour.m
 *
 * Copyright (C) 1996-2011 by vhf interservice GmbH
 * Author:  Georg Fleischmann
 *
 * created:  1996-04-10
 * modified: 2006-11-21
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

#include <AppKit/AppKit.h>
#include <VHFShared/VHFSystemAdditions.h>
#include <VHFShared/vhfCommonFunctions.h>
#include "App.h"
#include "functions.h"
#include "DocView.h"

static BOOL	buildContour = NO;

@interface App(PrivateMethods)
@end

@implementation App(Contour)

- showContourPanel:sender
{   id	retObj;

    if (!contourPanel)
    {
        if (![NSBundle loadModelNamed:@"Contour" owner:self])
            NSLog(@"Cannot load Contour model");
        contourUnit = UNIT_MM; //default
        [self updateContourPanel:sender];
    }

    [contourPanel setFrameAutosaveName:[contourPanel title]];

    [contourPanel setDelegate:self];

    if (contourPanel)
        [self runModalForWindow:contourPanel];
    retObj = (buildContour) ? self : nil;
    buildContour = NO;

    return retObj;
}

- contourPanel
{
    return contourPanel;
}

/*
 * converts a value from internal unit to the current unit
 */
- (float)resolution
{
    switch ( contourUnit )
    {
        case UNIT_MM:    return 72.0/25.4;
        case UNIT_INCH:  return 72.0;
        case UNIT_POINT: return 1.0;
    }
    return 1.0;
}

- (float)contour
{
    /* hier muss die angegebene Unit genommen werden */
    contourUnit = [[contourUnitPopup selectedItem] tag];

    return [contourField floatValue] * [self resolution];
}

#define	SWITCH_REMOVESOURCE	0
#define	SWITCH_USERASTER	1
- (BOOL)contourUseRaster;
{
    return ([(NSCell*)[contourSwitchMatrix cellAtRow:SWITCH_USERASTER    column:0] state]) ? YES : NO;
}
- (BOOL)contourRemoveSource;
{
    return ([(NSCell*)[contourSwitchMatrix cellAtRow:SWITCH_REMOVESOURCE column:0] state]) ? YES : NO;
}

/*
 * modified: 16.10.95
 */
- (void)okContourPanel:sender
{
    [contourPanel orderOut:self];
    buildContour = YES;
    [NSApp stopModalWithCode:YES];
}

- (void)setUnit:sender
{
    contourUnit = [[contourUnitPopup selectedItem] tag];
}

/*
 * modified: 2004-10-06
 */
- (void)doContourPanel:sender
{   float	v, res = [self resolution];
    float	min = res*-100.0, max = res+100.0;

    if ( [sender isKindOfClass:[NSSlider class]] )
        v = [contourSlider floatValue];
    else
        v = [contourField  floatValue];

    if (v < min) v = min;
    if (v > max) v = max;
    [contourField setStringValue:vhfStringWithFloat(v)];
    [contourSlider setFloatValue:v];
}

/*
 * modified: 16.10.95
 * updatePreferencesPanel: is used to copy the existing situation into
 * the Prefences panel.
 */
- (void)updateContourPanel:sender
{
}

@end
