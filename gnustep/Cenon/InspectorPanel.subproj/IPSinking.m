/* IPSinking.m
 * Sinking Inspector
 *
 * Copyright (C) 1995-2009 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  2000-09-18
 * modified: 2009-02-11 (-update: check for nil-title to please Apple)
 *           2008-07-19 (document units)
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
#include "../locations.h"
#include "InspectorPanel.h"
#include "IPSinking.h"

@interface IPSinking(PrivateMethods)
- (void)updateDiameterPopUp;
- (NSDictionary*)metricsAtIndex:(int)ix;
@end

@implementation IPSinking

- (void)update:sender
{   Document    *doc = [[self view] document];
    DocView     *view = [self view];
    VSinking    *g = sender;
    NSPoint     p;
    int         ix;

    [super update:sender];

    p = [view pointRelativeOrigin:[g pointWithNum:0]];
    [positionXField setStringValue:buildRoundedString([doc convertToUnit:p.x], LARGENEG_COORD, LARGE_COORD)];
    [positionYField setStringValue:buildRoundedString([doc convertToUnit:p.y], LARGENEG_COORD, LARGE_COORD)];

    [typeMatrix selectCellAtRow:0 column:[g type]];

    [unitPopUp selectItemAtIndex:[g unit]];

    [self updateDiameterPopUp];
    if ( [g name] && (ix = [diameterPopUp indexOfItemWithTitle:[g name]]) != -1 )
    {   [diameterPopUp selectItemAtIndex:ix];
        [metricsMatrix setEnabled:NO];
    }
    else
    {   [diameterPopUp selectItemAtIndex:[diameterPopUp numberOfItems]-1];
        [metricsMatrix setEnabled:YES];
    }

    [[metricsMatrix cellAtRow:METRICS_D1 column:0] setStringValue:buildRoundedString([doc convertToUnit:[g d1]], 0.0, LARGE_COORD)];
    [[metricsMatrix cellAtRow:METRICS_D2 column:0] setStringValue:buildRoundedString([doc convertToUnit:[g d2]], 0.0, LARGE_COORD)];
    [[metricsMatrix cellAtRow:METRICS_T1 column:0] setStringValue:buildRoundedString([doc convertToUnit:[g t1]], 0.0, LARGE_COORD)];
    [[metricsMatrix cellAtRow:METRICS_T2 column:0] setStringValue:buildRoundedString([doc convertToUnit:[g t2]], 0.0, LARGE_COORD)];
    [[metricsMatrix cellAtRow:METRICS_ST column:0] setStringValue:buildRoundedString([doc convertToUnit:[g stepSize]], 0.0, LARGE_COORD)];
}

/* create popUp from SinkingMetrics.plist file
 */
- (void)updateDiameterPopUp
{   static int	currentType = -1, currentUnit = -1;
    int         type = [typeMatrix selectedColumn], unit = [unitPopUp indexOfSelectedItem], i;
    NSArray     *typeArray;
    NSString    *path = nil;

    if ( !sinkingMetrics )
    {
        for (i=0; i<3; i++)
        {
            switch (i)
            {
                case 0:	// 1. user library
                    path = [userLibrary() stringByAppendingString:SINKINGMETRICS_NAME];
                    if ([[NSFileManager defaultManager] fileExistsAtPath:path])
                        sinkingMetrics = [[NSDictionary dictionaryWithContentsOfFile:path] retain];
                    break;
                case 1:	// 2. local library
                    path = [localLibrary() stringByAppendingString:SINKINGMETRICS_NAME];
                    if ([[NSFileManager defaultManager] fileExistsAtPath:path])
                        sinkingMetrics = [[NSDictionary dictionaryWithContentsOfFile:path] retain];
                    break;
                case 2:	// 3. main App bundle
                    path = [[[NSBundle mainBundle] resourcePath]
                            stringByAppendingPathComponent:SINKINGMETRICS_NAME];
                    if ([[NSFileManager defaultManager] fileExistsAtPath:path])
                        sinkingMetrics = [[NSDictionary dictionaryWithContentsOfFile:path] retain];
            }
        }
        if ( !sinkingMetrics )
        {   NSLog(@"VSinking, metrics: Cannot load sinking metrics file: %@", path);
            return;
        }
    }

    if ( currentType==type && currentUnit==unit )
        return;

    while ( [diameterPopUp numberOfItems] > 1 )	/* remove entries in popup list */
        [diameterPopUp removeItemAtIndex:0];

    typeArray = (type == SINKING_MEDIUM) ? [sinkingMetrics objectForKey:KEY_MEDIUM] : [sinkingMetrics objectForKey:KEY_FINE];
    if ( !typeArray )
        NSLog(@"VSinking metrics: Cannot extract type '%@' from metrics file", ((type == SINKING_MEDIUM) ? KEY_MEDIUM : KEY_FINE));
    for ( i=[typeArray count]-1; i>=0; i-- )
    {   NSDictionary	*dict = [typeArray objectAtIndex:i];

        [diameterPopUp insertItemWithTitle:[dict objectForKey:KEY_NAME] atIndex:0];
    }
    currentType = type;
    currentUnit = unit;
}

- (NSDictionary*)metricsAtIndex:(int)ix
{   int		type = [typeMatrix selectedColumn]/*, unit = [unitPopUp indexOfSelectedItem]*/;
    NSArray	*typeArray;

    /* FIXME: inch unit is not implemented yet !
     */
    typeArray = (type == SINKING_MEDIUM) ? [sinkingMetrics objectForKey:KEY_MEDIUM] : [sinkingMetrics objectForKey:KEY_FINE];
    return [typeArray objectAtIndex:ix];
}

- (void)setPositionX:sender
{   Document    *doc = [[self view] document];
    float       min = LARGENEG_COORD, max = LARGE_COORD;
    float       v = [positionXField floatValue];
    BOOL        control = [(App*)NSApp control];

    if ([sender isKindOfClass:[NSButton class]])
	switch ([(NSButton*)sender tag])
        {
            case BUTTONLEFT:	v -= ((control) ? 10.0 : 1.0); break;
            case BUTTONRIGHT:	v += ((control) ? 10.0 : 1.0);
        }

    if (v < min) v = min;
    if (v > max) v = max;
    [positionXField setStringValue:vhfStringWithFloat(v)];

    v = [doc convertFrUnit:v];
    [[self view] movePoint:0 to:[[self view] pointAbsolute:NSMakePoint(v, 0.0)] x:YES y:NO all:NO];
}
- (void)setPositionY:sender
{   Document    *doc = [[self view] document];
    float       min = LARGENEG_COORD, max = LARGE_COORD;
    float       v = [positionYField floatValue];
    BOOL        control = [(App*)NSApp control];

    if ([sender isKindOfClass:[NSButton class]])
        switch ([(NSButton*)sender tag])
        {
            case BUTTONLEFT:	v -= ((control) ? 10.0 : 1.0); break;
            case BUTTONRIGHT:	v += ((control) ? 10.0 : 1.0);
        }

    if (v < min) v = min;
    if (v > max) v = max;
    [positionYField setStringValue:vhfStringWithFloat(v)];

    v = [doc convertFrUnit:v];
    [[self view] movePoint:0 to:[[self view] pointAbsolute:NSMakePoint(0.0, v)] x:NO y:YES all:NO];
}

- (void)setType:sender
{   int     i, l, cnt;
    NSArray *slayList = [[self view] slayList];
    int     type = [typeMatrix selectedColumn];

    cnt = [slayList count];
    for (l=0; l<cnt; l++)
    {   NSMutableArray *slist = [slayList objectAtIndex:l];

        if ( ![[[[self view] layerList] objectAtIndex:l] editable] )
            continue;
        for ( i=[slist count]-1; i>=0; i-- )
        {   VSinking	*g = [slist objectAtIndex:i];

            if ( [g respondsToSelector:@selector(setType:)] )
                [g setType:type];
        }
    }

    [self updateDiameterPopUp];
}
- (void)setUnit:sender
{   int     i, l, cnt;
    NSArray *slayList = [[self view] slayList];
    int     unit = [unitPopUp indexOfSelectedItem];

    cnt = [slayList count];
    for (l=0; l<cnt; l++)
    {   NSMutableArray *slist = [slayList objectAtIndex:l];

        if ( ![[[[self view] layerList] objectAtIndex:l] editable] )
            continue;
        for ( i=[slist count]-1; i>=0; i-- )
        {   VSinking	*g = [slist objectAtIndex:i];

            if ( [g respondsToSelector:@selector(setUnit:)] )
                [g setUnit:unit];
        }
    }

    [self updateDiameterPopUp];
}

/* user selected entry in nominal diameter pop up
 */
- (void)setDiameter:sender
{   Document        *doc = [[self view] document];
    int             i, l, cnt;
    NSArray         *slayList = [[self view] slayList];
    NSString        *name = [diameterPopUp titleOfSelectedItem];
    int             selectedItem = [diameterPopUp indexOfSelectedItem];
    NSDictionary    *metricsDict;
    float           d1, d2, t1, t2, st;

    if ( selectedItem == [diameterPopUp numberOfItems]-1 )
    {   [metricsMatrix setEnabled:YES];
        return;
    }

    [metricsMatrix setEnabled:NO];

    metricsDict = [self metricsAtIndex:selectedItem];
    d1 = MMToInternal([metricsDict floatForKey:KEY_D1]);
    d2 = MMToInternal([metricsDict floatForKey:KEY_D2]);
    t1 = MMToInternal([metricsDict floatForKey:KEY_T1]);
    t2 = MMToInternal([metricsDict floatForKey:KEY_T2]);
    if (!(st = MMToInternal([metricsDict floatForKey:KEY_ST])))
        st = 0.1;

    cnt = [slayList count];
    for (l=0; l<cnt; l++)
    {   NSMutableArray *slist = [slayList objectAtIndex:l];

        if ( ![[[[self view] layerList] objectAtIndex:l] editable] )
            continue;
        for ( i=[slist count]-1; i>=0; i-- )
        {   VSinking	*g = [slist objectAtIndex:i];

            if ( [g respondsToSelector:@selector(setD1:)] )
            {
                [g setName:name];
                [g setD1:d1];
                [g setD2:d2];
                [g setT1:t1];
                [g setT2:t2];
                [g setStepSize:st];
            }
        }
    }

    d1 = [doc convertMMToUnit:[metricsDict floatForKey:KEY_D1]];
    [[metricsMatrix cellAtRow:METRICS_D1 column:0] setStringValue:buildRoundedString(d1, 0.0, LARGE_COORD)];
    d2 = [doc convertMMToUnit:[metricsDict floatForKey:KEY_D2]];
    [[metricsMatrix cellAtRow:METRICS_D2 column:0] setStringValue:buildRoundedString(d2, 0.0, LARGE_COORD)];
    t1 = [doc convertMMToUnit:[metricsDict floatForKey:KEY_T1]];
    [[metricsMatrix cellAtRow:METRICS_T1 column:0] setStringValue:buildRoundedString(t1, 0.0, LARGE_COORD)];
    t2 = [doc convertMMToUnit:[metricsDict floatForKey:KEY_T2]];
    [[metricsMatrix cellAtRow:METRICS_T2 column:0] setStringValue:buildRoundedString(t2, 0.0, t1)];
    st = [doc convertMMToUnit:[metricsDict floatForKey:KEY_ST]];
    [[metricsMatrix cellAtRow:METRICS_ST column:0] setStringValue:buildRoundedString(st, 0.0, t1)];

    [[self view] drawAndDisplay];
}
- (void)setMetrics:sender
{   Document    *doc = [[self view] document];
    int         i, l, cnt;
    NSArray     *slayList = [[self view] slayList];
    float       d1 = Limit([[metricsMatrix cellAtRow:METRICS_D1 column:0] floatValue], 0.0, LARGE_COORD);
    float       d2 = Limit([[metricsMatrix cellAtRow:METRICS_D2 column:0] floatValue], 0.0, LARGE_COORD);
    float       t1 = Limit([[metricsMatrix cellAtRow:METRICS_T1 column:0] floatValue], 0.0, LARGE_COORD);
    float       t2 = Limit([[metricsMatrix cellAtRow:METRICS_T2 column:0] floatValue], 0.0, t1);
    float       st = Limit([[metricsMatrix cellAtRow:METRICS_ST column:0] floatValue], 0.001, t1);

    [[metricsMatrix cellAtRow:METRICS_D1 column:0] setStringValue:vhfStringWithFloat(d1)];
    [[metricsMatrix cellAtRow:METRICS_D2 column:0] setStringValue:vhfStringWithFloat(d2)];
    [[metricsMatrix cellAtRow:METRICS_T1 column:0] setStringValue:vhfStringWithFloat(t1)];
    [[metricsMatrix cellAtRow:METRICS_T2 column:0] setStringValue:vhfStringWithFloat(t2)];
    [[metricsMatrix cellAtRow:METRICS_ST column:0] setStringValue:vhfStringWithFloat(st)];

    d1 = [doc convertFrUnit:d1];
    d2 = [doc convertFrUnit:d2];
    t1 = [doc convertFrUnit:t1];
    t2 = [doc convertFrUnit:t2];
    st = [doc convertFrUnit:st];

    cnt = [slayList count];
    for (l=0; l<cnt; l++)
    {   NSMutableArray *slist = [slayList objectAtIndex:l];

        if ( ![[[[self view] layerList] objectAtIndex:l] editable] )
            continue;
        for ( i=[slist count]-1; i>=0; i-- )
        {   VSinking	*g = [slist objectAtIndex:i];

            if ( [g respondsToSelector:@selector(setD1:)] )
            {
                [g setName:nil];
                [g setD1:d1];
                [g setD2:d2];
                [g setT1:t1];
                [g setT2:t2];
                [g setStepSize:st];
            }
        }
    }

    [[self view] drawAndDisplay];
}

- (void)displayWillEnd
{	 
}

@end
