/* GridPanel.m
 * Panel for setting up the grid
 *
 * Copyright (C) 1997-2012 by vhf interservice GmbH
 * Author:  Georg Fleischmann
 *
 * created:  2000-08-24
 * modified: 2012-06-17 ("####.###" number format to allow fractions again)
 *           2010-07-16 ("." as decimal separator)
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
#include <VHFShared/VHFPopUpButtonAdditions.h>
#include "GridPanel.h"
#include "App.h"
#include "DocView.h"

@interface GridPanel(PrivateMethods)
- (void)updateGridPanel:sender;
@end

@implementation GridPanel

/*
 */
- (void)update:sender
{   id                  view = [[(App*)NSApp currentDocument] documentView];
    NSNumberFormatter   *formatter = [gridField formatter];

    if ( ! formatter )  // Debugger: po formatter->_attributes
    {   formatter = [NSNumberFormatter new];
        [formatter setAllowsFloats:YES];
        [formatter setDecimalSeparator:@"."];
        [formatter setPositiveFormat:@"####.###"];  // without this we get integer numbers
        //[formatter setNumberStyle:NSNumberFormatterDecimalStyle];
        //[formatter setAlwaysShowsDecimalSeparator:YES];
        [gridField setFormatter:formatter];
    }
    [gridField setFloatValue:([view gridSpacing] == 0.0) ? 1.0 : [view gridSpacing]];
    [(NSPopUpButton*)unitPopUp selectItemWithTag:[view gridUnit]];
}

/*
 * modified: 
 */
- (void)setGrid:sender
{   id	view = [[(App*)NSApp currentDocument] documentView];

    [self orderOut:self];
    [NSApp stopModal];
    [view setGridSpacing:[gridField floatValue]];
    [view setGridUnit:[[unitPopUp selectedItem] tag]];
    [view setGridEnabled:YES];
}

@end
