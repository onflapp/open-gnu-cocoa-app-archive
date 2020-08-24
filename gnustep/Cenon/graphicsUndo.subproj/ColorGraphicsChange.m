/* ColorGraphicsChange.m
 *
 * Copyright (C) 1993-2002 by vhf interservice GmbH
 * Authors:  Georg Fleischmann
 *
 * created:  1993
 * modified: 2002-07-15
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

#include "undo.h"

@interface ColorGraphicsChange(PrivateMethods)

- (BOOL)subsumeIdenticalChange:change;

@end

@implementation ColorGraphicsChange

- initGraphicView:aGraphicView color:(NSColor*)aColor colorNum:(int)colNum
{
    [super initGraphicView:aGraphicView];
    color = [aColor copyWithZone:(NSZone*)[self zone]];
    colorNum = colNum;
    return self;
}

- (NSString *)changeName
{
    return COLOR_OP;
}

- (Class)changeDetailClass
{
    return [ColorChangeDetail class];
}

- (NSColor *)color
{
    return color;
}

- (int)colorNum
{
    return colorNum;
}

- (BOOL)subsumeIdenticalChange:change
{   ColorGraphicsChange	*colorChange = (ColorGraphicsChange*)change;

    if ( colorChange->colorNum != colorNum )
        return NO;
    color = [(ColorGraphicsChange *)change color];
    return YES;
}

- (void)dealloc
{
    [color release];
    [super dealloc];
}

@end
