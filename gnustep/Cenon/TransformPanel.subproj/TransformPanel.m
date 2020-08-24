/* TransformPanel.m
 * Cenon panel for transforming graphic objects
 *
 * Copyright (C) 1996-2006 by vhf interservice GmbH
 * Author: Georg Fleischmann
 *
 * Created:  1996-04-22
 * Modified: 2006-11-13
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

#include <VHFShared/VHFSystemAdditions.h>
#include "TransformPanel.h"
#include "TPBasicLevel.h"
#include "TPScale.h"
#include "TPMove.h"
#include "TPRotate.h"

#define SCALE_STRING NSLocalizedString(@"Scale", NULL)
#define MOVE_STRING NSLocalizedString(@"Move", NULL)
#define ALIGN_STRING NSLocalizedString(@"Align", NULL)
#define ROTATE_STRING NSLocalizedString(@"Rotate", NULL)
#define MIX_STRING NSLocalizedString(@"Mix", NULL)

@implementation TransformPanel

- init
{
    [levRadio setTarget:self];
    [levRadio setAction:@selector(setLevel:)];
    [self setLevel:self];

    return [super init];
}

- (void)update:sender
{
	 
}

- (void)setLevel:sender
{
    [self setLevelAt:Max(0, [levRadio selectedColumn])];
}

/* attention with the -init if it is not subclassed you will loss the window!
 */
- (void)setLevelAt:(int)level
{
    [activeWindow displayWillEnd];
    if (level < 10)
        [levRadio selectCellAtRow:0 column:level];
    switch (level)
    {
        case TP_SCALE:	// scale
            [self windowAt:TP_SCALE];
            [levBox setTitle: SCALE_STRING];
            [self setLevelView:[scalePanel contentView]];
            activeWindow = scalePanel;
            break;
        case TP_MOVE:	// move
            [self windowAt:TP_MOVE];
            [levBox setTitle: MOVE_STRING];
            [self setLevelView:[movePanel contentView]];
            activeWindow = movePanel;
            break;
        case TP_ALIGN:	// align
            [self windowAt:TP_ALIGN];
            [levBox setTitle: ALIGN_STRING];
            [self setLevelView:[alignPanel contentView]];
            activeWindow = alignPanel;
            break;
        case TP_MIX:	// mix
            [self windowAt:TP_MIX];
            [levBox setTitle: MIX_STRING];
            [self setLevelView:[mixPanel contentView]];
            activeWindow = mixPanel;
            break;
        case TP_ROTATE:	// rotate
            [self windowAt:TP_ROTATE];
            [levBox setTitle: ROTATE_STRING];
            [self setLevelView:[rotatePanel contentView]];
            activeWindow = rotatePanel;
            break;
        default:
            [self setLevelView:NULL];
            activeWindow = self;
            return;
    }

    [activeWindow update:self];
    [self orderFront:self];
}

- (void)setLevelView:theView
{
    [levView setContentView:[theView retain]];
    dataView = theView;
    [dataView setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];

    [self display];
    [self flushWindow]; 
}
#if 0
{   NSRect	rect;

    [dataView removeFromSuperview];
    [[self contentView] addSubview:theView];
    rect = [levView frame];
    [theView setFrame:rect];
    dataView = theView;
    [levView setAutoresizesSubviews:YES];
    [dataView setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];

    [self display];
    [self flushWindow];
}
#endif

- windowAt:(int)level
{
    switch (level)
    {
        case TP_SCALE:
            if (!scalePanel)
            {
                if (![NSBundle loadModelNamed:@"TPScale" owner:self])
                    NSLog(@"Cannot load TPScale model");
                [[scalePanel init] setWindow:self];
            }
            return scalePanel;
        case TP_MOVE:
            if (!movePanel)
            {
                if (![NSBundle loadModelNamed:@"TPMove" owner:self])
                    NSLog(@"Cannot load TPMove model");
                [[movePanel init] setWindow:self];
            }
            return movePanel;
        case TP_ALIGN:
            if (!alignPanel)
            {
                if (![NSBundle loadModelNamed:@"TPAlign" owner:self])
                    NSLog(@"Cannot load TPAlign model");
                [[alignPanel init] setWindow:self];
            }
            return alignPanel;
        case TP_MIX:
            if (!mixPanel)
            {
                if (![NSBundle loadModelNamed:@"TPMix" owner:self])
                    NSLog(@"Cannot load TPMix model");
                [[mixPanel init] setWindow:self];
            }
            return mixPanel;
        case TP_ROTATE:
            if (!rotatePanel)
            {
                if (![NSBundle loadModelNamed:@"TPRotate" owner:self])
                    NSLog(@"Cannot load TPRotate model");
                [[rotatePanel init] setWindow:self];
            }
            return rotatePanel;
        default: return nil;
    }
}

@end
