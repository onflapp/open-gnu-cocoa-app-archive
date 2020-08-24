/* TPMove.m
 * Transform panel for moving objects
 *
 * Copyright (C) 2002-2008 by vhf interservice GmbH
 * Author: Georg Fleischmann
 *
 * Created:  2002-11-20
 * Modified: 2008-07-19 (document units)
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
#include "TPMove.h"
#include "../App.h"
#include "../DocView.h"
#include "../functions.h"

#define TPMOVE_RELATIVE	0
#define TPMOVE_ABSOLUTE	1

@interface TPMove(PrivateMethods)
@end

@implementation TPMove

- init
{
    [super init];
    [self update:self];
    return self;
}

- (void)update:sender
{
}

- (void)set:sender
{   Document    *doc = [(App*)NSApp currentDocument];
    DocView     *view = [doc documentView];
    float       x, y;

    x = [doc convertFrUnit:[xField floatValue]];
    y = [doc convertFrUnit:[yField floatValue]];

    if ([popUp indexOfSelectedItem] == TPMOVE_RELATIVE)
        [view moveGraphicsBy:NSMakePoint(x, y) andDraw:YES];
    else
        [view movePointTo:[view pointAbsolute:NSMakePoint(x, y)] x:YES y:YES all:YES];
}

@end
