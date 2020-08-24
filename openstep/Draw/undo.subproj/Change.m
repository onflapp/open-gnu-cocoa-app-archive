#import "undochange.h"

/*
 * Please refer to external reference pages for complete
 * documentation on using the Change class.
 */

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

    if(_changeManager != nil) {
	if (![_changeManager changeInProgress:self] || _changeFlags.disabled)
	    return NO;
    }

    return YES;
}

- (BOOL)endChange
{
    if (_changeManager == nil || _changeFlags.disabled) {
	[self release];
	return NO;
    } else {
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

- (NSString *)changeName
/*
 * To be overridden 
 */
{
    return @"";
}

/* Methods called by ChangeManager */
/* DO NOT call directly */

- (void)saveBeforeChange
/*
 * To be overridden 
 */
{
     
}

- (void)saveAfterChange
/*
 * To be overridden 
 */
{
     
}

- (void)undoChange
/*
 * To be overridden. End with:
 * return [super undoChange];
 */
{
    _changeFlags.hasBeenDone = NO; 
}

- (void)redoChange
/*
 * To be overridden. End with:
 * return [super redoChange];
 */
{
    _changeFlags.hasBeenDone = YES; 
}

- (BOOL)subsumeChange:change
/*
 * To be overridden 
 */
{
    return NO;
}

- (BOOL)incorporateChange:change
/*
 * To be overridden 
 */
{
    return NO;
}

- (void)finishChange
/*
 * To be overridden 
 */
{
     
}

/* Private Methods */

- (id)calcTargetForAction :(SEL)theAction in:aView
/*
 * This method is intended to behave exactly like the Application
 * method calcTargetForAction:, except that that method always returns
 * nil if the application is not active, where we do our best to come
 * up with a target anyway.
 */
{
    id responder, nextResponder;

    responder = [[aView window] firstResponder];
    while (![responder respondsToSelector:theAction]) {
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
