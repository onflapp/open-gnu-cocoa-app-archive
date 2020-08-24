/* TilePanel.m
 * Panel for batch production
 *
 * Copyright (C) 1996-2008 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1996-04-10
 * modified: 2008-07-19 (Document Units)
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
#include "TilePanel.h"
#include "functions.h"
#include "DocView.h"

@interface TilePanel(PrivateMethods)
@end

@implementation TilePanel

- (BOOL)useAbsoluteDistance
{
    return ( [distPopup indexOfSelectedItem] == 0 ) ? NO : YES;
}
- (void)setDistancePopup:sender
{   static int  prevSelectedItem = 0;
    Document    *doc = [(App*)NSApp currentDocument];
    DocView     *view = [doc documentView];
    int         min = 0, max = 99999;
    NSSize      size = [view tileBounds].size;
    NSPoint     dist = [self distance];
    NSString    *string;

    if ([distPopup indexOfSelectedItem] == prevSelectedItem)
        return;
    switch ([distPopup indexOfSelectedItem])
    {
        case 0:	// relative
            string = buildRoundedString([doc convertToUnit:dist.x-size.width],  min, max);
            [[distanceMatrix cellAtRow:0 column:0] setStringValue:string];
            string = buildRoundedString([doc convertToUnit:dist.y-size.height], min, max);
            [[distanceMatrix cellAtRow:1 column:0] setStringValue:string];
            break;
        case 1:	// absolute
            string = buildRoundedString([doc convertToUnit:size.width +dist.x], min, max);
            [[distanceMatrix cellAtRow:0 column:0] setStringValue:string];
            string = buildRoundedString([doc convertToUnit:size.height+dist.y], min, max);
            [[distanceMatrix cellAtRow:1 column:0] setStringValue:string];
    }
    prevSelectedItem = [distPopup indexOfSelectedItem];
}

- (NSPoint)distance
{   Document    *doc = [(App*)NSApp currentDocument];
    NSPoint	p;

    p.x = [doc convertFrUnit:[[distanceMatrix cellAtRow:0 column:0] floatValue]];
    p.y = [doc convertFrUnit:[[distanceMatrix cellAtRow:1 column:0] floatValue]];
    return p;
}
- (NSPoint)relativeDistance
{   NSPoint	p = [self distance];

    if ([distPopup indexOfSelectedItem] == 1)
    {   DocView	*view = [[(App*)NSApp currentDocument] documentView];
        NSSize	size = [view tileBounds].size;

        p.x = Max(p.x-size.width,  0.0);
        p.y = Max(p.y-size.height, 0.0);
    }
    return p;
}

- (BOOL)limitSize
{
    return ( [limitsPopUp indexOfSelectedItem] == 0 ) ? NO : YES;
}

- (NSPoint)limits
{   Document    *doc = [(App*)NSApp currentDocument];
    NSPoint	p;

    p.x = [[limitsMatrix cellAtRow:0 column:0] floatValue];
    p.y = [[limitsMatrix cellAtRow:1 column:0] floatValue];
    if ( [self limitSize] )
    {   p.x = [doc convertFrUnit:p.x];
        p.y = [doc convertFrUnit:p.y];
    }

    return p;
}

- (BOOL)mustMoveMasterToOrigin
{
    return ( [(NSButton*)originSwitch state] == 0 ) ? NO : YES;
}


- (void)createTilesAsCopy:(BOOL)buildCopy
{   Document    *doc = [(App*)NSApp currentDocument];
    DocView     *view = [doc documentView];
    NSSize      viewSize = [view bounds].size;
    NSPoint     dist         = [self relativeDistance], limits = [self limits];
    BOOL        limitSize    = [self limitSize];
    BOOL        moveToOrigin = [self mustMoveMasterToOrigin];

    /* check input */
    if ( [self limitSize] )
    {
        if ( viewSize.width<limits.x || viewSize.height<limits.y )
        {
            [[limitsMatrix cellAtRow:0 column:0] setStringValue:
                buildRoundedString([doc convertToUnit:limits.x], 0.0, [doc convertToUnit:viewSize.width])];
            [[limitsMatrix cellAtRow:1 column:0] setStringValue:
                buildRoundedString([doc convertToUnit:limits.y], 0.0, [doc convertToUnit:viewSize.height])];
            return;
        }
    }
    else
    {
    }

    if ( buildCopy )
        [view   buildTileCopies:limits limitSize:limitSize distance:dist moveToOrigin:moveToOrigin];
    else
        [view setTileWithLimits:limits limitSize:limitSize distance:dist moveToOrigin:moveToOrigin];
}

/*
 * modified: 1997-03-02
 */
- (void)set:sender
{
    [self createTilesAsCopy:NO];
}

/*
 * modified: 1997-03-02
 */
- (void)buildCopies:sender
{
    [self createTilesAsCopy:YES];
}

/*
 * modified: 1997-03-02
 */
- (void)removeTiles:sender
{
    [[[(App*)NSApp currentDocument] documentView] removeTiles];
}

/*
 * updatePanel: is used to copy the existing situation into the Tile panel
 * modified: 2008-07-19 (Document Units)
 */
- (void)updatePanel:sender
{   Document    *doc = ([sender isKindOfClass:[DocWindow class]])
                       ? [sender document] : [(App*)NSApp currentDocument];
    DocView     *view = [doc documentView];
    NSPoint     p;
    float       min = [doc convertMMToUnit:-500.0], max = [doc convertMMToUnit:500.0];
    NSSize      size = [view tileBounds].size;

    /* tile distance */
    p = [view tileDistance];	// this is always relative
    if ([distPopup indexOfSelectedItem] == 1)	// absolute distance
        p = NSMakePoint(p.x+size.width, p.y+size.height);
    [[distanceMatrix cellAtRow:0 column:0] setStringValue:buildRoundedString([doc convertToUnit:p.x], min, max)];
    [[distanceMatrix cellAtRow:1 column:0] setStringValue:buildRoundedString([doc convertToUnit:p.y], min, max)];

    /* update limits from panel - change of limit */
    if ( [sender isKindOfClass:[NSPopUpButton class]] )
    {
        // FIXME: pay attention to twist of selectedItem here ! it returns the old state!
    }
    /* Update limits from view - for window change or something like this */
    else
    {
        /* tile limits by size of material */
        if ( [view tileLimitSize] )
        {   NSPoint	lim = [view tileLimits];

            if ( [view tileLimitSize] )
                lim = NSMakePoint( [doc convertToUnit:lim.x],   [doc convertToUnit:lim.y] );
            else
                lim = NSMakePoint( [doc convertMMToUnit:100.0], [doc convertMMToUnit:100.0] );

            [[limitsMatrix cellAtRow:0 column:0] setStringValue:buildRoundedString(lim.x, min, max)];
            [[limitsMatrix cellAtRow:1 column:0] setStringValue:buildRoundedString(lim.y, min, max)];
            [limitsPopUp selectItemAtIndex:1];
        }
        /* tile limits by number of items */
        else
        {   NSPoint	lim = (![view tileLimitSize]) ? [view tileLimits] : NSMakePoint( 2.0, 2.0 );

            if ( !lim.x || !lim.y )
                lim = NSMakePoint( 2.0, 2.0 );
            [[limitsMatrix cellAtRow:0 column:0] setIntValue:(int)lim.x];
            [[limitsMatrix cellAtRow:1 column:0] setIntValue:(int)lim.y];
            [limitsPopUp selectItemAtIndex:0];
        }
    }
}

@end
