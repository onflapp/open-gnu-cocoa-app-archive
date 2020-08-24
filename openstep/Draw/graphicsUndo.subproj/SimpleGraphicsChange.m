#import "drawundo.h"

/*
 * Please refer to external documentation about Draw
 * with Undo for information about what SimpleGraphicsChange 
 * is and where it fits in.
 */

@interface SimpleGraphicsChange(PrivateMethods)

- (void)undoDetails;
- (void)redoDetails;
- (BOOL)subsumeIdenticalChange:change;

@end

@implementation SimpleGraphicsChange

- (void)saveBeforeChange
{
    [super saveBeforeChange];
    [changeDetails makeObjectsPerform:@selector(recordDetail)]; 
}

- (BOOL)subsumeChange:change
/*
 * ChangeManager will call subsumeChange: when we are the last 
 * completed change and a new change has just begun. We override
 * the subsumeChange: to offer our subclasses a chance to
 * consolidate multiple changes into a single change.
 * First we check to make sure that the new change is of the
 * same class as the last. If it is then we check to make sure
 * that it's operating on the same selection. If not we simply
 * return NO, declining to subsume it. If it does operate on
 * the same change then we offer our subclass a change to 
 * subsume it by sending [self subsumeIdenticalChange:change].
 *
 * For example, if the user presses the up arrow key to move
 * a graphic up one pixel, that immediately becomes a complete,
 * undoable change, as it should. If she continues to press
 * use the arrow keys we don't want to end up making hundreds
 * of independent move changes that would each have to be
 * undone seperately. So instead we have the first move
 * subsume all subsequent MoveGraphicsChanges that operate
 * on the same selection.
 */
{
    BOOL		identicalChanges = NO;
    NSMutableArray		*selectedGraphics;
    int			count, i;

    if ([change isKindOfClass:[self class]]) {
	if (!graphicsToChange) {
	    identicalChanges = YES;
	    selectedGraphics = [graphicView selectedGraphics];
	    count = [selectedGraphics count];
	    for (i = 0; (i < count) && (identicalChanges); i++) {
		if ([graphics objectAtIndex:i] != [selectedGraphics objectAtIndex:i])
		    identicalChanges = NO;
	    }
	}
    } 
    if (identicalChanges)
        return [self subsumeIdenticalChange:change];
    else
        return NO;
}

- (void)undoDetails
{
    [changeDetails makeObjectsPerform:@selector(undoDetail)]; 
}

- (void)redoDetails
{
    [changeDetails makeObjectsPerform:@selector(redoDetail)]; 
}

- (BOOL)subsumeIdenticalChange:change
{
    return NO;
}

@end
