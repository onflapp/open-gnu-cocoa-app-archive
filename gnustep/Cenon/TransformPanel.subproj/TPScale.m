/* TPScale.m
 * Transform panel for scaling objects
 *
 * Copyright (C) 1996-2011 by vhf interservice GmbH
 * Author: Georg Fleischmann
 *
 * Created:  1996-04-22
 * Modified: 2011-03-03
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

#include "TransformPanel.h"
#include "TPScale.h"
#include "../App.h"
#include "../DocView.h"
#include "../locations.h"
#include "../messages.h"


@interface TPScale(PrivateMethods)
- (void)updateUnit;
@end

@implementation TPScale

- init
{
    [super init];
    [self update:self];
    return self;
}

- (void)update:sender
{
    [scaleYField setEnabled:([(NSButton*)uniformScaleSwitch state]) ? NO : YES];
    [self updateUnit];
    // TODO: add observer like in WorkingArea to keep unit up to date
}

- (void)updateUnit
{   Document            *doc = [(App*)NSApp currentDocument];
    static NSString     *wStr = nil, *hStr = nil;;
    static CenonUnit    myUnit = -1;

    //if (!wStr || [doc baseUnit] != myUnit)
    {   NSString    *unitStr;

        myUnit = [doc baseUnit];
        if (!wStr)
        {
            wStr = [scaleXField title];
            wStr = [[wStr stringByReplacing:@"UNIT" by:@"%@"] retain];
            hStr = [scaleYField title];
            hStr = [[hStr stringByReplacing:@"UNIT" by:@"%@"] retain];
        }
        if ( [scalePopup indexOfSelectedItem] != 1 )
            unitStr = @"%";
        else
            switch (myUnit)
            {
                default:
                case UNIT_MM:    unitStr = @"mm";   break;
                case UNIT_INCH:  unitStr = @"inch"; break;
                case UNIT_POINT: unitStr = @"point";
            }
        [scaleXField setTitle:[NSString stringWithFormat:wStr, unitStr]];
        [scaleYField setTitle:[NSString stringWithFormat:hStr, unitStr]];
    }
}

/* scale popup
 * created: 2011-03-03
 */
- (void)setHowToScale:sender
{   int ix = [sender indexOfSelectedItem];

    switch (ix)
    {
        default:    // %
            [scaleXField setIntValue:100];
            [scaleYField setIntValue:100];
            break;
        case 1:     // size to
            // TODO: set size of 1st selected object in docView
            [scaleXField setIntValue:0.0];
            [scaleYField setIntValue:0.0];
            break;
    }
    [self updateUnit];
}

- (void)setUniformScale:sender
{
    [scaleYField setEnabled:([(NSButton*)uniformScaleSwitch state]) ? NO : YES];
}

- (void)setScale:sender
{   id          view = [[(App*)NSApp currentDocument] documentView];
    float       x, y;
    Document    *doc = [(App*)NSApp currentDocument];

    if ( [scalePopup indexOfSelectedItem] != 1 )
    {
        x = [scaleXField floatValue] / 100.0;
        y = ([(NSButton*)uniformScaleSwitch state]) ? x : [scaleYField floatValue]/100.0;
        if (!x || !y)
            return;
        [view scaleG:x :y];
    }
    else
    {
        x = [doc convertFrUnit:[scaleXField floatValue]];
        if ( x == 0.0 )
            return;
        y = ([(NSButton*)uniformScaleSwitch state]) ? 0.0 : [doc convertFrUnit:[scaleYField floatValue]];
        [view scaleGTo:x :y];
    }
}

@end
