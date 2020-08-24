/* IPAccText.m
 * Accessory Text Inspector used for all Text objects
 *
 * Copyright (C) 2008 by vhf interservice GmbH
 * Author:   Ilonka Fleischmann
 *
 * created:  2008-03-13
 * modified: 2008-07-19 (document units)
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
#include "IPAccText.h"

@implementation IPAccText

+ (BOOL)servesObject:(NSObject*)g
{
    if ([g isKindOfClass:[VText class]] || [g isKindOfClass:[VTextPath class]])
        return YES;
    return NO;
}

- (NSString*)name
{
    return [self title];
}

- (void)update:sender
{   Document    *doc = [[self view] document];
    id          g = sender;

    graphic = sender;

    if ([g isKindOfClass:[VText class]])
    {   [lineHeightField setEnabled:YES];
        [lineHeightField setStringValue:buildRoundedString([doc convertToUnit:[g lineHeight]], 0.0, LARGE_COORD)];
        [lineButtonLeft setEnabled:YES];
        [lineButtonRight setEnabled:YES];
    }
    else
    {   [lineHeightField setStringValue:buildRoundedString(0.0, 0.0, LARGE_COORD)];
        [lineHeightField setEnabled:NO];
        [lineButtonLeft setEnabled:NO];
        [lineButtonRight setEnabled:NO];
    }
    if ([g isKindOfClass:[VText class]] || [g isKindOfClass:[VTextPath class]])
    {   [fontSizeField setEnabled:YES];
        [fontSizeField setStringValue:buildRoundedString([doc convertToUnit:[g fontSize]], 0.0, LARGE_COORD)];
        [fontButtonLeft setEnabled:YES];
        [fontButtonRight setEnabled:YES];
    }
    else
    {   [fontSizeField setStringValue:buildRoundedString(0.0, 0.0, LARGE_COORD)];
        [fontSizeField setEnabled:NO];
        [fontButtonLeft setEnabled:NO];
        [fontButtonRight setEnabled:NO];
    }
}

- (void)setLineHeight:sender
{   int         i, l, cnt;
    DocView     *view = [self view];
    Document    *doc = [[self view] document];
    NSArray     *slayList = [view slayList];
    float       min = 0.0, max = LARGE_COORD;
    float       v = [lineHeightField floatValue];
    BOOL        control = [(App*)NSApp control], dirty = NO;

    if ([sender isKindOfClass:[NSButton class]])
    {
        switch ([(NSButton*)sender tag])
        {
            case BUTTONLEFT:	v -= ((control) ? 1.0 : 0.1); break;
            case BUTTONRIGHT:	v += ((control) ? 1.0 : 0.1);
        }
    }

    if (v < min)	v = min;
    if (v > max)	v = max;
    [lineHeightField setStringValue:vhfStringWithFloat(v)];

    v = [doc convertFrUnit:v];

    /* set width of all objects */
    cnt = [slayList count];
    for (l=0; l<cnt; l++)
    {	NSMutableArray *slist = [slayList objectAtIndex:l];

        if (![[[view layerList] objectAtIndex:l] editable])
            continue;
        for (i=[slist count]-1; i>=0; i--)
        {   id		g = [slist objectAtIndex:i];

            if ([g respondsToSelector:@selector(setLineHeight:)])
            {   [(VText*)g setLineHeight:v];
                dirty = YES;
                [[[view layerList] objectAtIndex:l] setDirty:YES];
            }
        }
    }
    if (dirty)
        [[view document] setDirty:YES];
    [view drawAndDisplay];
}

- (void)setFontSize:sender
{   int         i, l, cnt;
    DocView     *view = [self view];
    Document    *doc = [[self view] document];
    NSArray     *slayList = [[self view] slayList];
    float       min = 0.0, max = LARGE_COORD;
    float       v = [fontSizeField floatValue];
    BOOL        control = [(App*)NSApp control], dirty = NO;

    if ([sender isKindOfClass:[NSButton class]])
    {
        switch ([(NSButton*)sender tag])
        {
            case BUTTONLEFT:	v -= ((control) ? 1.0 : 0.1); break;
            case BUTTONRIGHT:	v += ((control) ? 1.0 : 0.1);
        }
    }

    if (v < min)	v = min;
    if (v > max)	v = max;
    [fontSizeField setStringValue:vhfStringWithFloat(v)];

    v = [doc convertFrUnit:v];

    /* set width of all objects */
    cnt = [slayList count];
    for (l=0; l<cnt; l++)
    {	NSMutableArray *slist = [slayList objectAtIndex:l];

        if (![[[view layerList] objectAtIndex:l] editable])
            continue;
        for (i=[slist count]-1; i>=0; i--)
        {   id	g = [slist objectAtIndex:i];

            if ( [g respondsToSelector:@selector(setFontSize:)] )
            {   [(VText*)g setFontSize:v];
                if ( !dirty && [g isKindOfClass:[VText class]] )
                {   [lineHeightField setStringValue:
                    buildRoundedString([doc convertToUnit:[g lineHeight]], 0.0, LARGE_COORD)];
                    [[[view layerList] objectAtIndex:l] setDirty:YES];
                    dirty = YES;
                }
            }
        }
    }
    if (dirty)
        [[view document] setDirty:YES];
    [view drawAndDisplay];
}

- (void)displayWillEnd
{	 
}

@end
