/* WorkingAreaPanel.m
 * Panel for input of working area
 *
 * Copyright 1996-2012 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  2000-08-24
 * modified: 2012-01-25 (-awakeFromNib: make cells resond to Tab)
 *           2008-07-19 (use Documents convertTo/FrUnit:, update unit and working-area on document/unit changes)
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
#include <VHFShared/vhfCommonFunctions.h>
#include "WorkingAreaPanel.h"
#include "App.h"
#include "DocView.h"
#include "PreferencesPanel.subproj/NotificationNames.h"  // PrefsUnitHasChanged notification

@interface WorkingAreaPanel(PrivateMethods)
@end

@implementation WorkingAreaPanel

- (void)awakeFromNib
{   NSNotificationCenter	*notificationCenter = [NSNotificationCenter defaultCenter];
    NSArray                 *cells;
    int                     i;

    /* notification that the units of measurement have changed */
    [notificationCenter addObserver:self
                           selector:@selector(unitHasChanged:)
                               name:PrefsUnitHasChanged
                             object:nil];

    /* notification that the DocWindow has changed */
    [notificationCenter addObserver:self
                           selector:@selector(documentHasChanged:)
                               name:DocWindowDidChange
                             object:nil];

    /* make cells responsive to Tab (not only enter) */
    cells = [sizeMatrix cells];
    for (i=0; i<[cells count]; i++)
        [[cells objectAtIndex:i] setSendsActionOnEndEditing:YES];
}

/*
 * modified: 2008-07-19
 */
- (void)setWorkingArea:sender
{   Document    *doc = [(App*)NSApp currentDocument];
    DocView     *view = [doc documentView];
    double      width, height, scale = [view scaleFactor];

    width  = [doc convertFrUnit:[[sizeMatrix cellAtRow:0 column:0] floatValue]] * scale;
    height = [doc convertFrUnit:[[sizeMatrix cellAtRow:1 column:0] floatValue]] * scale;
    [view setFrameSize:NSMakeSize(width, height)];
    [view drawAndDisplay];
    [doc setDirty:YES];
}

/*
 * modified: 2008-07-19
 */
- (void)update:sender
{   Document    *doc = ([sender isKindOfClass:[Document class]]) ? sender : [(App*)NSApp currentDocument];
    DocView     *view = [doc documentView];
    NSRect      bRect = [view bounds];
    float       v;

    v = [doc convertToUnit:bRect.size.width];
    [[sizeMatrix cellAtRow:0 column:0] setStringValue:buildRoundedString(v, 0.0, MMToInternal(10000.0))];
    v = [doc convertToUnit:bRect.size.height];
    [[sizeMatrix cellAtRow:1 column:0] setStringValue:buildRoundedString(v, 0.0, MMToInternal(10000.0))];

    {   static NSString     *wStr = nil, *hStr = nil;
        static CenonUnit    myUnit = -1;

        if (!wStr || [doc baseUnit] != myUnit)
        {   NSString    *unitStr;

            myUnit = [doc baseUnit];
            if (!wStr)
            {
                wStr = [[sizeMatrix cellAtRow:0 column:0] title];
                wStr = [[wStr stringByReplacing:@"UNIT" by:@"%@"] retain];
                hStr = [[sizeMatrix cellAtRow:1 column:0] title];
                hStr = [[hStr stringByReplacing:@"UNIT" by:@"%@"] retain];
            }
            switch (myUnit)
            {
                default:
                case UNIT_MM:    unitStr = @"mm";   break;
                case UNIT_INCH:  unitStr = @"inch"; break;
                case UNIT_POINT: unitStr = @"point";
            }
            [[sizeMatrix cellAtRow:0 column:0] setTitle:[NSString stringWithFormat:wStr, unitStr]];
            [[sizeMatrix cellAtRow:1 column:0] setTitle:[NSString stringWithFormat:hStr, unitStr]];
        }
    }
}

/* notification that the unit of measurement has changed
 */
- (void)unitHasChanged:(NSNotification*)notification
{
    [self update:[notification object]];
}

/* notification that the DocWindow has changed
 */
- (void)documentHasChanged:(NSNotification*)notification
{
    [self update:[notification object]];
}

@end
