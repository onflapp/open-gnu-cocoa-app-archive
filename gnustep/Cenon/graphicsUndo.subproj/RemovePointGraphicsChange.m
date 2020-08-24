/* RemovePointGraphicsChange.m
 *
 * Copyright (C) 1993-2005 by vhf interservice GmbH
 * Authors:  Ilonka Fleischmann
 *
 * created:  2005
 * modified: 2005-07-03
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

@interface RemovePointGraphicsChange(PrivateMethods)

- (BOOL)subsumeIdenticalChange:change;

@end

@implementation RemovePointGraphicsChange

- initGraphicView:aGraphicView
{
    [super initGraphicView:aGraphicView];
    return self;
}

- (NSString *)changeName
{
    return REMOVEPOINT_OP;
}

- (Class)changeDetailClass
{
    return [RemovePointChangeDetail class];
}

- (BOOL)subsumeIdenticalChange:change
{
    return NO;
}

@end
