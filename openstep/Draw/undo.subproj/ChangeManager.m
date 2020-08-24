#import "undochange.h"

/*
 * Please refer to external reference pages for complete
 * documentation on using the ChangeManager class.
 */

/* 
 * N_LEVEL_UNDO sets the maximum number of changes that the ChangeManager
 * will keep track of. Set this to 1 to get single level undo behaviour. 
 * Set it to a really big number if you want to offer nearly infinite undo.
 * Be careful if you do this because unless you explicity reset the 
 * ChangeManager from time to time, like whenever you save a document, the
 * ChangeManager will never forget changes and will eventually chew up
 * enourmous amounts of swapfile.
 */
#define	N_LEVEL_UNDO	10

@interface ChangeManager(PrivateMethods)

- (void)updateMenuItem:(id <NSMenuItem>) menuItem with:(NSString *)menuText;

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
    if (_lastChange == nil) {
        return NO;
    } else {
	NSAssert1(![_lastChange changeInProgress], @"%@", "Fault in Undo system: Code 1");
	NSAssert1(![_lastChange disabled], @"%@", "Fault in Undo system: Code 2");
	NSAssert1([_lastChange hasBeenDone], @"%@", "Fault in Undo system: Code 3");
        return YES;
    }
}

- (BOOL)canRedo
{
    if (_nextChange == nil) {
        return NO;
    } else {
	NSAssert1(![_nextChange changeInProgress], @"%@", "Fault in Undo system: Code 4");
	NSAssert1(![_nextChange disabled], @"%@", "Fault in Undo system: Code 5");
	NSAssert1(![_nextChange hasBeenDone], @"%@", "Fault in Undo system: Code 6");
        return YES;
    }
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

- (void)disableChanges:sender
/*
 * disableChanges: and enableChanges: work as a team, incrementing and
 * decrementing the _changesDisabled count. We use a count instead of
 * a BOOL so that nested disables will work correctly -- the outermost
 * disable and enable pair are the only ones that do anything.
 */
{
    _changesDisabled++; 
}

- (void)enableChanges:sender
/*
 * We're forgiving if we get an enableChanges: that doesn't match up
 * with any previous disableChanges: call.
 */
{
    if (_changesDisabled > 0)
        _changesDisabled--; 
}

- (void)undoOrRedoChange:sender
{
    if ([self canUndo]) {
        [self undoChange:sender];
    } else {
	if ([self canRedo]) {
	    [self redoChange:sender];
	}
    } 
}

- (void)undoChange:sender
{
    if ([self canUndo]) {
	[_lastChange finishChange];
	[self disableChanges:self];
	    [_lastChange undoChange];
	[self enableChanges:self];
	_nextChange = _lastChange;
	_lastChange = nil;
	_numberOfDoneChanges--;
	_numberOfUndoneChanges++;
	if (_numberOfDoneChanges > 0) {
	    _lastChange = [_changeList objectAtIndex:(_numberOfDoneChanges - 1)];
	}
	[self changeWasUndone];
    } 
}

- (void)redoChange:sender
{
    if ([self canRedo]) {
	[self disableChanges:self];
	    [_nextChange redoChange];
	[self enableChanges:self];
	_lastChange = _nextChange;
	_nextChange = nil;
	_numberOfDoneChanges++;
	_numberOfUndoneChanges--;
	if (_numberOfUndoneChanges > 0) {
	    _nextChange = [_changeList objectAtIndex:_numberOfDoneChanges];
	}
	[self changeWasRedone];
    } 
}

- (BOOL)validateMenuItem:(id <NSMenuItem>)anItem
/*
 * See the Draw code for a good example of how validateCell:
 * can be used to keep the application's menu items up to date.
 */
{
    SEL action;
    BOOL canUndo, canRedo, enableMenuItem = YES;
    NSString *menuText;

    action = [anItem action];
    
    if (action == @selector(undoOrRedoChange:)) {
        enableMenuItem = NO;
	canUndo = [self canUndo];
	if (canUndo) {
	    menuText = [NSString stringWithFormat:UNDO_SOMETHING_OPERATION, [_lastChange changeName]];
	    enableMenuItem = YES;
	} else {
	    canRedo = [self canRedo];
	    if (canRedo) {
	        menuText = [NSString stringWithFormat:REDO_SOMETHING_OPERATION, [_nextChange changeName]];
	        enableMenuItem = YES;
	    } else {
		menuText = [NSString stringWithFormat:UNDO_OPERATION];
	    }
	}
	[self updateMenuItem:anItem with:menuText];
    }

    if (action == @selector(undoChange:)) {
	canUndo = [self canUndo];
	if (!canUndo) {
	    menuText = [NSString stringWithFormat:UNDO_OPERATION];
	} else {
	    menuText = [NSString stringWithFormat:UNDO_SOMETHING_OPERATION, [_lastChange changeName]];
	}
        [self updateMenuItem:anItem with:menuText];
	enableMenuItem = canUndo;
    }

    if (action == @selector(redoChange:)) {
	canRedo = [self canRedo];
	if (!canRedo) {
	    menuText = [NSString stringWithFormat:REDO_OPERATION];
	} else {
	    menuText = [NSString stringWithFormat:REDO_SOMETHING_OPERATION, [_nextChange changeName]];
	}
        [self updateMenuItem:anItem with:menuText];
	enableMenuItem = canRedo;
    }

    return enableMenuItem;
}

/* Methods called by Change           */
/* DO NOT call these methods directly */

- (BOOL)changeInProgress:change
/*
 * The changeInProgress: and changeComplete: methods are the most
 * complicated part of the undo framework. Their behaviour is documented 
 * in the external reference sheets.
 */
{
    if (_changesDisabled > 0) {
	[change disable];
	return NO;
    } 
    
    if (_changeInProgress != nil) {
	if ([_changeInProgress incorporateChange:change]) {
	    /* 
	     * The _changeInProgress will keep a pointer to this
	     * change and make use of it, but we have no further
	     * responsibility for it.
	     */
	    [change saveBeforeChange];
	    return YES;
	} else {
	    /* 
	     * The _changeInProgress has no more interest in this
	     * change than we do, so we'll just disable it.
	     */
	    [change disable];
	    return NO;
	}
    } 
    
    if (_lastChange != nil) {
	if ([_lastChange subsumeChange:change]) {
	    /* 
	     * The _lastChange has subsumed this change and 
	     * may either make use of it or free it, but we
	     * have no further responsibility for it.
	     */
	    [change disable];
	    return NO;
	} else {
	    /* 
	     * The _lastChange was not able to subsume this change, 
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

- (BOOL)changeComplete:change
/*
 * The changeInProgress: and changeComplete: methods are the most
 * complicated part of the undo framework. Their behaviour is documented 
 * in the external reference sheets.
 */
{
    int i;
    
    NSAssert1(![change changeInProgress], @"%@", "Fault in Undo system: Code 7");
    NSAssert1(![change disabled], @"%@", "Fault in Undo system: Code 8");
    NSAssert1([change hasBeenDone], @"%@", "Fault in Undo system: Code 9");
    if (change != _changeInProgress) {
	/* 
	 * "Toto, I don't think we're in Kansas anymore."
	 *				- Dorthy
	 * Actually, we come here whenever a change is 
	 * incorportated or subsumed by another change 
	 * and later executes its endChange method.
	 */
        [change saveAfterChange];
	return NO;
    }
    
    if (_numberOfUndoneChanges > 0) {
	NSAssert1(_numberOfDoneChanges != N_LEVEL_UNDO, @"%@", "Fault in Undo system: Code 10");
	/* Remove and free all undone changes */
	for (i = (_numberOfDoneChanges + _numberOfUndoneChanges); i > _numberOfDoneChanges; i--) {
	[_changeList removeObjectAtIndex:(i - 1)];
	}
	_nextChange = nil;
	_numberOfUndoneChanges = 0;
	if (_numberOfDoneChanges < _numberOfDoneChangesAtLastClean)
	    _someChangesForgotten = YES;
    }
    if (_numberOfDoneChanges == N_LEVEL_UNDO) {
	NSAssert1(_numberOfUndoneChanges == 0, @"%@", "Fault in Undo system: Code 11");
	NSAssert1(_nextChange == nil, @"%@", "Fault in Undo system: Code 12");
	/* 
	    * The [_changeList removeObjectAt:0] call is order N.
	    * This will be slow if N_LEVEL_UNDO is large.
	    * Ideally the _changeList should be implemented as
	    * a circular queue, or List should do removeObjectAt:
	    * in a fixed time. In many applications (including
	    * Draw) doing the redisplay associated with the undo 
	    * will take MUCH longer than even an order N call to 
	    * removeObjectAt:, so it's not too important that 
	    * this be changed.
	    */
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

- (void)changeWasDone
/*
 * To be overridden 
 */
{
     
}

- (void)changeWasUndone
/*
 * To be overridden 
 */
{
     
}

- (void)changeWasRedone
/*
 * To be overridden 
 */
{
     
}

/* Private Methods    */

- (void)updateMenuItem:(id <NSMenuItem>)menuItem with:(NSString *)menuText
{
    [menuItem setTitleWithMnemonic:menuText];
}

@end
