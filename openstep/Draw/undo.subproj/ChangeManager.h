/*
 * Please refer to external reference pages for complete
 * documentation on using the ChangeManager class.
 */

@interface ChangeManager : NSResponder
{
    NSMutableArray *_changeList;			/* done, undone and redone changes */
    Change *_lastChange;		/* the last done or redone change */
    Change *_nextChange;		/* the most recently undone change */
    Change *_changeInProgress;		/* the current change in progress */
    int _numberOfDoneChanges;		/* number of done or redone changes 
    					   recorded in the changeList */
    int _numberOfUndoneChanges;		/* undone changes in the changeList */
    int _numberOfDoneChangesAtLastClean;/* number at time clean last message */
    BOOL _someChangesForgotten;		/* YES whenever we don't remember 
    					   enough to return to a clean state */
    int _changesDisabled;		/* YES between outermost calls to
    					   disableChanges: and enableChanges:*/
}

/* Methods called directly by your code */

- (id)init;			/* start with [super init] if overriding */
- (void)dealloc;			/* end with [super free] if overriding */
- (BOOL)canUndo;	/* DO NOT override */
- (BOOL)canRedo;	/* DO NOT override */
- (BOOL)isDirty;	/* DO NOT override */

- (void)dirty:sender;		/* start with [super dirty:sender] if overriding */
- (void)clean:sender;		/* start with [super clean:sender] if overriding */
- (void)reset:sender;		/* start with [super reset:sender] if overriding */
- (void)disableChanges:sender;	/* DO NOT override */
- (void)enableChanges:sender;		/* DO NOT override */
- (void)undoOrRedoChange:sender;	/* DO NOT override */
- (void)undoChange:sender;		/* DO NOT override */
- (void)redoChange:sender;		/* DO NOT override */
			/* end with [super validateCommand:] if overriding */

/* Methods called by Change           */
/* DO NOT call these methods directly */

- (BOOL)changeInProgress:change;	/* DO NOT override */
- (BOOL)changeComplete:change;		/* DO NOT override */

/* Methods called by ChangeManager    */
/* DO NOT call these methods directly */

- (void)changeWasDone;		/* override at will */
- (void)changeWasUndone;		/* override at will */
- (void)changeWasRedone;		/* override at will */

- (BOOL)validateMenuItem:(id <NSMenuItem>)anItem;

@end
