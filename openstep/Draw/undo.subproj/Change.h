/*
 * Please refer to external reference pages for complete
 * documentation on using the Change class.
 */

@class ChangeManager;

@interface Change : NSObject
{
    struct {
	unsigned int disabled: 1;	/* YES if disable message receieved */
	unsigned int hasBeenDone: 1;	/* YES if done or redone */
	unsigned int changeInProgress: 1; /* YES after startChange 
					     but before endChange */
	unsigned int padding: 29;
    } _changeFlags;
   ChangeManager *_changeManager;
}

/* Methods called directly by your code */

- (id)init;				/* start with [super init] if overriding */
- (BOOL)startChange;			/* DO NOT override */
- (BOOL)startChangeIn:aView;		/* DO NOT override */
- (BOOL)endChange;			/* DO NOT override */
- (ChangeManager *)changeManager;	/* DO NOT override */

/* Methods called by ChangeManager or by your code */

- (void)disable;			/* DO NOT override */
- (BOOL)disabled;		/* DO NOT override */
- (BOOL)hasBeenDone;		/* DO NOT override */
- (BOOL)changeInProgress;	/* DO NOT override */
- (NSString *)changeName;	/* override at will */

/* Methods called by ChangeManager */
/* DO NOT call directly */

- (void)saveBeforeChange;		/* override at will */
- (void)saveAfterChange;		/* override at will */
- (void)undoChange;			/* end with [super undoChange] if overriding */
- (void)redoChange;			/* end with [super redoChange] if overriding */
- (BOOL)subsumeChange:change;	/* override at will */
- (BOOL)incorporateChange:change;/* override at will */
- (void)finishChange;			/* override at will */

@end
