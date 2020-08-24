/* Change.m
 *
 * Copyright (C) 1993-2002 by vhf interservice GmbH
 * Authors:  Georg Fleischmann
 *
 * created:  1993 based on the Draw example files
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

#include "undochange.h"

@interface Change(PrivateMethods)

- (id)calcTargetForAction :(SEL)theAction in:aView;

@end

@implementation Change

/* Methods called directly by your code */

- (id)init
{
    [super init];
    _changeFlags.disabled = NO;
    _changeFlags.hasBeenDone = NO;
    _changeFlags.changeInProgress = NO;
    _changeManager = nil;
    return self;
}

- (BOOL)startChange
{
    return [self startChangeIn:nil];
}

- (BOOL)startChangeIn:aView
{
    _changeFlags.changeInProgress = YES;
    _changeManager = [NSApp targetForAction:@selector(changeInProgress:)];

    if (_changeManager == nil && aView != nil)
        _changeManager = [self calcTargetForAction :@selector(changeInProgress:) in:aView];

    if (_changeManager != nil)
    {
        if (![_changeManager changeInProgress:self] || _changeFlags.disabled)
            return NO;
    }

    return YES;
}

- (BOOL)endChange
{
    if (_changeManager == nil || _changeFlags.disabled)
    {
        [self release];
        return NO;
    }
    else
    {
        _changeFlags.hasBeenDone = YES;
        _changeFlags.changeInProgress = NO;
        if (![_changeManager changeComplete:self])
            return NO;
    }
    return YES;
}

- (ChangeManager *)changeManager
{
    return _changeManager;
}

/* Methods called by ChangeManager or by your code */

- (void)disable
{
    _changeFlags.disabled = YES; 
}

- (BOOL)disabled
{
    return _changeFlags.disabled;
}

- (BOOL)hasBeenDone
{
    return _changeFlags.hasBeenDone;
}

- (BOOL)changeInProgress
{
    return _changeFlags.changeInProgress;
}

/* To be overridden 
 */
- (NSString *)changeName
{
    return @"";
}

/* Methods called by ChangeManager */
/* DO NOT call directly */

/* To be overridden 
 */
- (void)saveBeforeChange
{
}

/* To be overridden 
 */
- (void)saveAfterChange
{
}

/* To be overridden. End with: return [super undoChange];
 */
- (void)undoChange
{
    _changeFlags.hasBeenDone = NO;
}

/* To be overridden. End with: return [super redoChange];
 */
- (void)redoChange
{
    _changeFlags.hasBeenDone = YES;
}

/* To be overridden 
 */
- (BOOL)subsumeChange:change
{
    return NO;
}

/* To be overridden 
 */
- (BOOL)incorporateChange:change
{
    return NO;
}

/* To be overridden 
 */
- (void)finishChange
{
}

/* Private Methods */

/*
 * This method is intended to behave exactly like the Application
 * method calcTargetForAction:, except that that method always returns
 * nil if the application is not active, where we do our best to come
 * up with a target anyway.
 */
- (id)calcTargetForAction :(SEL)theAction in:aView
{   id responder, nextResponder;

    responder = [[aView window] firstResponder];
    while (![responder respondsToSelector:theAction])
    {
        nextResponder = nil;
        if ([responder respondsToSelector:@selector(nextResponder)])
            nextResponder = [responder nextResponder];
        if (nextResponder == nil && [responder isKindOfClass:[NSWindow class]])
            nextResponder = [responder delegate];
        if (nextResponder == nil)
            nextResponder = NSApp;
        if (nextResponder == nil && responder == NSApp)
            nextResponder = [responder delegate];
        responder = nextResponder;
    }
    return responder;
}

@end
