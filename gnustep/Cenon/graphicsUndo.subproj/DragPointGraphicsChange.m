/* DragPointGraphicsChange.m
 *
 * Copyright (C) 1993-2003 by vhf interservice GmbH
 * Authors:  Georg Fleischmann
 *
 * created:  1993
 * modified: 2003-06-26
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

@interface DragPointGraphicsChange(PrivateMethods)
- (void)undoDetails;
- (void)redoDetails;
@end

@implementation DragPointGraphicsChange

- initGraphicView:aGraphicView graphic:aGraphic
{
    [super initGraphicView:aGraphicView];
    graphic = aGraphic;
    return self;
}

- (NSString *)changeName
{
    return MOVEPOINT_OP;
}

- (void)saveBeforeChange
{
    //graphics = [[NSMutableArray alloc] init];
    //[graphics addObject:graphic];
    //ptNum = [graphic selectedKnobIndex];
    //oldPoint = [graphic pointWithNum:ptNum];
}

- (void)setPointNum:(int)num
{
    ptNum = num;
    oldPoint = [graphic pointWithNum:ptNum];
    control = [(App*)NSApp control];
}

- (Class)changeDetailClass
{
    return nil;
}

- (void)undoDetails
{
    newPoint = [graphic pointWithNum:ptNum];
    if (control && [graphic isKindOfClass:[VArc class]])
        [(VArc*)graphic movePoint:ptNum to:oldPoint control:control];
    else if (control && [graphic isKindOfClass:[VPath class]])
        [(VPath*)graphic movePoint:ptNum to:oldPoint control:control];
    else if (control && [graphic isKindOfClass:[VGroup class]])
        [(VGroup*)graphic movePoint:ptNum to:oldPoint control:control];
    else
        [graphic movePoint:ptNum to:oldPoint];
}

- (void)redoDetails
{
    if (control && ([graphic isKindOfClass:[VArc class]]))
        [(VArc*)graphic movePoint:ptNum to:newPoint control:control];
    else if (control && [graphic isKindOfClass:[VPath class]])
        [(VPath*)graphic movePoint:ptNum to:newPoint control:control];
    else if (control && [graphic isKindOfClass:[VGroup class]])
        [(VGroup*)graphic movePoint:ptNum to:newPoint control:control];
    else
        [graphic movePoint:ptNum to:newPoint];
}

@end
