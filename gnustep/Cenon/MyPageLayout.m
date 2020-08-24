/*
 * MyPageLayout.m
 *
 * Copyright (C) 1993-2005 by vhf interservice GmbH
 * Author: Georg Fleischmann
 *
 * Created:  1993
 * Modified: 2002-07-15
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
#include "MyPageLayout.h"

@implementation MyPageLayout
/*
 * PageLayout is overridden so that the user can set the margins of
 * the page.  This is important in a Draw program where the user
 * typically wants to maximize the drawable area on the page.
 *
 * The accessory view is used to add the additional fields, and
 * pickedUnits: is overridden so that the margin is displayed in the
 * currently selected units.  Note that the accessoryView is set
 * in InterfaceBuilder using the outlet mechanism!
 *
 * This can be used as an example of how to override Application Kit panels.
 */

#ifdef WIN32
- (void)convertOldFactor:(float *)oldf newFactor:(float *)newf
{
    if (oldf) *oldf = 1.0;
    if (newf) *newf = 1.0;
}
#endif

/*
 * Called when the user selects different units (e.g. cm or inches).
 * Must update the margin fields.
 */
- (void)pickedUnits:(id)sender
{   float old, new;

    [self convertOldFactor:&old newFactor:&new];
    [leftMargin   setFloatValue:new * [leftMargin   floatValue] / old];
    [rightMargin  setFloatValue:new * [rightMargin  floatValue] / old];
    [topMargin    setFloatValue:new * [topMargin    floatValue] / old];
    [bottomMargin setFloatValue:new * [bottomMargin floatValue] / old];

#ifndef WIN32
    [super pickedUnits:sender];
#endif
}

- (void)readPrintInfo
/*
 * Sets the margin fields from the Application-wide PrintInfo.
 */
{   NSPrintInfo *pi;
    float conversion, dummy;

    [super readPrintInfo];
    pi = [self printInfo];
    [self convertOldFactor:&conversion newFactor:&dummy];
    [leftMargin setFloatValue:[pi leftMargin] * conversion];
    [rightMargin setFloatValue:[pi rightMargin] * conversion];
    [topMargin setFloatValue:[pi topMargin] * conversion];
    [bottomMargin setFloatValue:[pi bottomMargin] * conversion];
}

/*
 * Sets the margin values in the Application-wide PrintInfo from
 * the margin fields in the panel.
 */
- (void)writePrintInfo
{   NSPrintInfo *pi;
    float conversion, dummy;

    [super writePrintInfo];
    pi = [self printInfo];
    [self convertOldFactor:&conversion newFactor:&dummy];
    if (conversion)
    {
        [pi setLeftMargin:[leftMargin floatValue] / conversion];
        [pi setRightMargin:[rightMargin floatValue] / conversion];
        [pi setTopMargin:[topMargin floatValue] / conversion];
        [pi setBottomMargin:[bottomMargin floatValue] / conversion];
    }
}

/* outlet setting methods */

- (void)setTopBotForm:anObject
{
    topMargin = [anObject cellWithTag:5];
    bottomMargin = [anObject cellWithTag:6]; 
}

- (void)setSideForm:anObject
{
    leftMargin = [anObject cellWithTag:3];
    rightMargin = [anObject cellWithTag:4]; 
}

@end
