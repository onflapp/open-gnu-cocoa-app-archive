/* MoveGraphicsChange.m
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

@interface MoveGraphicsChange(PrivateMethods)

- (BOOL)subsumeIdenticalChange:change;

@end

@implementation MoveGraphicsChange

- initGraphicView:aGraphicView vector:(NSPoint)aVector
{
    [super initGraphicView:aGraphicView];
    redoVector.x = aVector.x;
    redoVector.y = aVector.y;
    undoVector.x = -redoVector.x;
    undoVector.y = -redoVector.y;

    return self;
}

- (NSString *)changeName
{
    return MOVE_OP;
}

- (Class)changeDetailClass
{
    return [MoveChangeDetail class];
}

- (NSPoint)undoVector
{
    return undoVector;
}

- (NSPoint)redoVector
{
    return redoVector;
}

- (BOOL)subsumeIdenticalChange:change
{   MoveGraphicsChange	*moveChange;

    moveChange = (MoveGraphicsChange *)change;
    undoVector.x += moveChange->undoVector.x;
    undoVector.y += moveChange->undoVector.y;
    redoVector.x += moveChange->redoVector.x;
    redoVector.y += moveChange->redoVector.y;

    return YES;
}

@end
