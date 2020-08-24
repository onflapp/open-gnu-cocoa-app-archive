/* CreateGraphicsChange.m
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

@interface CreateGraphicsChange(PrivateMethods)

@end

@implementation CreateGraphicsChange

- initGraphicView:aGraphicView graphic:aGraphic
{
    [super init];
    graphicView = aGraphicView;
    graphic = [aGraphic retain];

    return self;
}

- (void)dealloc
{
    if (![self hasBeenDone])
        [graphic release];
    [super dealloc];
}

- (NSString *)changeName
{
    return [NSString stringWithFormat:NEW_CHANGE_OP, NSLocalizedString([graphic title], NULL)];
}

- (void)undoChange
{
    layer = [graphicView layerOfGraphic:graphic];
    [layer removeObject:graphic];
    [graphicView cache:[graphic extendedBoundsWithScale:[graphicView scaleFactor]]];
    [[(App*)NSApp inspectorPanel] loadList:[graphicView slayList]];
    [super undoChange];
}

- (void)redoChange
{
    [layer addObject:graphic];
    [graphicView cache:[graphic extendedBoundsWithScale:[graphicView scaleFactor]]];
    [[(App*)NSApp inspectorPanel] loadGraphic:[graphicView slayList]];
    [super redoChange];
}

- (BOOL)incorporateChange:change
/*
 * ChangeManager will call incorporateChange: if another change
 * is started while we are still in progress (after we've 
 * been sent startChange but before we've been sent endChange). 
 * We override incorporateChange: because we want to
 * incorporate a StartEditingGraphicsChange if it happens.
 * Rather than know how to undo and redo the start-editing stuff,
 * we'll simply keep a pointer to the StartEditingGraphicsChange
 * and ask it to undo and redo whenever we undo or redo.
 */
{
    //if ([change isKindOfClass:[StartEditingGraphicsChange class]]) {
    //    startEditingChange = change;
    //    return YES;
    //} else {
        return NO;
    //}
}

@end
