/* ChangeManager.m
 *
 * Copyright (C) 1993-2006 by vhf interservice GmbH
 * Authors:  Georg Fleischmann
 *
 * created:  1993 based on the Draw example files
 * modified: 2006-11-07
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

/* N_LEVEL_UNDO sets the maximum number of changes that the ChangeManager
 * will keep track of. Set this to 1 to get single level undo behaviour. 
 * Set it to a really big number if you want to offer nearly infinite undo.
 * Be careful if you do this because unless you explicity reset the 
 * ChangeManager from time to time, like whenever you save a document, the
 * ChangeManager will never forget changes and will eventually chew up
 * enourmous amounts of swapfile.
 */
#define	N_LEVEL_UNDO	25

@interface ChangeManager(PrivateMethods)

- (void)updateMenuItem:(NSMenuItem*) menuItem with:(NSString *)menuText;

@end

@implementation ChangeManager

/* Methods called directly by your code */

- (id)init
{
    [super init];

    _changeList = [[NSMutableArray alloc] initWithCapacity:N_LEVEL_UNDO];
    _numberOfDoneChanges = 0;
    _numberOfUndoneChanges = 0;
    _numberOfDoneChangesAtLastClean = 0;
    _someChangesForgotten = NO;
    _lastChange = nil;
    _nextChange = nil;
    _changeInProgress = nil;
    _changesDisabled = 0;

    return self;
}

- (void)dealloc
{
    [self reset:self];
    [_changeList release];
    [super dealloc];
}

- (BOOL)canUndo
{
    if (_lastChange == nil)
        return NO;
    NSAssert1(![_lastChange changeInProgress], @"%@", "Fault in Undo system: Code 1");
    NSAssert1(![_lastChange disabled], @"%@", "Fault in Undo system: Code 2");
    NSAssert1([_lastChange hasBeenDone], @"%@", "Fault in Undo system: Code 3");
    return YES;
}

- (BOOL)canRedo
{
    if (_nextChange == nil)
        return NO;
    NSAssert1(![_nextChange changeInProgress], @"%@", "Fault in Undo system: Code 4");
    NSAssert1(![_nextChange disabled], @"%@", "Fault in Undo system: Code 5");
    NSAssert1(![_nextChange hasBeenDone], @"%@", "Fault in Undo system: Code 6");
    return YES;
}

- (BOOL)isDirty
{
    return ((_numberOfDoneChanges != _numberOfDoneChangesAtLastClean)
            || _someChangesForgotten);
}

- (void)dirty:sender
{
    _someChangesForgotten = YES; 
}

- (void)clean:sender
{
    _someChangesForgotten = NO;
    _numberOfDoneChangesAtLastClean = _numberOfDoneChanges; 
}

- (void)reset:sender
{
    [_changeList removeAllObjects];
    _numberOfDoneChanges = 0;
    _numberOfUndoneChanges = 0;
    _numberOfDoneChangesAtLastClean = 0;
    _someChangesForgotten = NO;
    _lastChange = nil;
    _nextChange = nil;
    _changeInProgress = nil;
    _changesDisabled = 0; 
}

/*
 * disableChanges: and enableChanges: work as a team, incrementing and
 * decrementing the _changesDisabled count. We use a count instead of
 * a BOOL so that nested disables will work correctly -- the outermost
 * disable and enable pair are the only ones that do anything.
 */
- (void)disableChanges:sender
{
    _changesDisabled++; 
}

/*
 * We're forgiving if we get an enableChanges: that doesn't match up
 * with any previous disableChanges: call.
 */
- (void)enableChanges:sender
{
    if (_changesDisabled > 0)
        _changesDisabled--; 
}

- (void)undoOrRedoChange:sender
{
    if ([self canUndo])
        [self undoChange:sender];
    if ([self canRedo])
        [self redoChange:sender];
}

- (void)undoChange:sender
{
    if ([self canUndo])
    {
	[_lastChange finishChange];
	[self disableChanges:self];
	    [_lastChange undoChange];
	[self enableChanges:self];
	_nextChange = _lastChange;
	_lastChange = nil;
	_numberOfDoneChanges--;
	_numberOfUndoneChanges++;
	if (_numberOfDoneChanges > 0)
	    _lastChange = [_changeList objectAtIndex:(_numberOfDoneChanges - 1)];
	[self changeWasUndone];
    } 
}

- (void)redoChange:sender
{
    if ([self canRedo])
    {
	[self disableChanges:self];
	    [_nextChange redoChange];
	[self enableChanges:self];
	_lastChange = _nextChange;
	_nextChange = nil;
	_numberOfDoneChanges++;
	_numberOfUndoneChanges--;
	if (_numberOfUndoneChanges > 0)
	    _nextChange = [_changeList objectAtIndex:_numberOfDoneChanges];
	[self changeWasRedone];
    }
}

/*
 */
- (BOOL)validateMenuItem:(NSMenuItem*)anItem
{   SEL         action;
    BOOL        canUndo, canRedo, enableMenuItem = YES;
    NSString	*menuText;

    action = [anItem action];

    if (action == @selector(undoOrRedoChange:))
    {
        enableMenuItem = NO;
        canUndo = [self canUndo];
        if (canUndo)
        {   menuText = [NSString stringWithFormat:UNDO_SOMETHING_OPERATION, [_lastChange changeName]];
            enableMenuItem = YES;
        }
        else
        {
            canRedo = [self canRedo];
            if (canRedo)
            {   menuText = [NSString stringWithFormat:REDO_SOMETHING_OPERATION, [_nextChange changeName]];
                enableMenuItem = YES;
            }
            else
                menuText = [NSString stringWithFormat:UNDO_OPERATION];
        }
        [self updateMenuItem:anItem with:menuText];
    }

    if (action == @selector(undoChange:))
    {
        canUndo = [self canUndo];
        if (!canUndo)
            menuText = [NSString stringWithFormat:UNDO_OPERATION];
        else
            menuText = [NSString stringWithFormat:UNDO_SOMETHING_OPERATION, [_lastChange changeName]];
        [self updateMenuItem:anItem with:menuText];
        enableMenuItem = canUndo;
    }

    if (action == @selector(redoChange:))
    {
        canRedo = [self canRedo];
        if (!canRedo)
            menuText = [NSString stringWithFormat:REDO_OPERATION];
        else
            menuText = [NSString stringWithFormat:REDO_SOMETHING_OPERATION, [_nextChange changeName]];
        [self updateMenuItem:anItem with:menuText];
        enableMenuItem = canRedo;
    }

    return enableMenuItem;
}

/* Methods called by Change
 * DO NOT call these methods directly
 */

/*
 * The changeInProgress: and changeComplete: methods are the most
 * complicated part of the undo framework. Their behaviour is documented 
 * in the external reference sheets.
 */
- (BOOL)changeInProgress:change
{
    if (_changesDisabled > 0)
    {
	[change disable];
	return NO;
    }
    
    if (_changeInProgress != nil)
    {
	if ([_changeInProgress incorporateChange:change])
        {
	    /* The _changeInProgress will keep a pointer to this
	     * change and make use of it, but we have no further
	     * responsibility for it.
	     */
	    [change saveBeforeChange];
	    return YES;
	}
        else
        {
	    /* The _changeInProgress has no more interest in this
	     * change than we do, so we'll just disable it.
	     */
	    [change disable];
	    return NO;
	}
    }

    if (_lastChange != nil)
    {
	if ([_lastChange subsumeChange:change])
        {
	    /* The _lastChange has subsumed this change and 
	     * may either make use of it or free it, but we
	     * have no further responsibility for it.
	     */
	    [change disable];
	    return NO;
	}
        else
        {
	    /* The _lastChange was not able to subsume this change, 
	     * so we give the _lastChange a chance to finish and then
	     * welcome this change as the new _changeInProgress.
	     */
	    [_lastChange finishChange];
        }
    }

    /*
     * This will be a new, independent change.
     */
    [change saveBeforeChange];
    if (![change disabled])
        _changeInProgress = change;

    return YES;
}

/*
 * The changeInProgress: and changeComplete: methods are the most
 * complicated part of the undo framework. Their behaviour is documented 
 * in the external reference sheets.
 */
- (BOOL)changeComplete:change
{   int i;

    NSAssert1(![change changeInProgress], @"%@", "Fault in Undo system: Code 7");
    NSAssert1(![change disabled], @"%@", "Fault in Undo system: Code 8");
    NSAssert1([change hasBeenDone], @"%@", "Fault in Undo system: Code 9");
    if (change != _changeInProgress)
    {
        /* Actually, we come here whenever a change is 
         * incorportated or subsumed by another change 
         * and later executes its endChange method.
         */
        [change saveAfterChange];
        return NO;
    }

    if (_numberOfUndoneChanges > 0)
    {
        NSAssert1(_numberOfDoneChanges != N_LEVEL_UNDO, @"%@", "Fault in Undo system: Code 10");
        /* Remove and free all undone changes */
        for (i = (_numberOfDoneChanges + _numberOfUndoneChanges); i > _numberOfDoneChanges; i--)
            [_changeList removeObjectAtIndex:(i - 1)];
        _nextChange = nil;
        _numberOfUndoneChanges = 0;
        if (_numberOfDoneChanges < _numberOfDoneChangesAtLastClean)
            _someChangesForgotten = YES;
    }
    if (_numberOfDoneChanges == N_LEVEL_UNDO)
    {
        NSAssert1(_numberOfUndoneChanges == 0, @"%@", "Fault in Undo system: Code 11");
        NSAssert1(_nextChange == nil, @"%@", "Fault in Undo system: Code 12");
        [_changeList removeObjectAtIndex:0];
        _numberOfDoneChanges--;
        _someChangesForgotten = YES;
    }
    [_changeList addObject:change];
    _numberOfDoneChanges++;

    _lastChange = change;
    _changeInProgress = nil;

    [change saveAfterChange];
    [self changeWasDone];

    return YES;
}

/* Methods called by ChangeManager    */
/* DO NOT call these methods directly */

/* To be overridden 
 */
- (void)changeWasDone
{
}

/* To be overridden 
 */
- (void)changeWasUndone
{
}

/* To be overridden 
 */
- (void)changeWasRedone
{
}

/* Private Methods
 */

- (void)updateMenuItem:(NSMenuItem*)menuItem with:(NSString *)menuText
{
    [menuItem setTitleWithMnemonic:menuText];
}

@end
