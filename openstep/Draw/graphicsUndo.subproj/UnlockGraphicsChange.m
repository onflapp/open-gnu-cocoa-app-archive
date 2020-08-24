#import "drawundo.h"

@interface UnlockGraphicsChange(PrivateMethods)

- (void)undoDetails;

@end

@implementation UnlockGraphicsChange

- (NSString *)changeName
{
    return UNLOCK_OP;

}

- (void)saveBeforeChange
{
    NSMutableArray *allGraphics;
    int i, count;
    id	graphic;

    graphics = [[NSMutableArray alloc] init];

    allGraphics = [graphicView graphics];
    count = [allGraphics count];
    for (i = 0; i < count; i++) {
        graphic = [allGraphics objectAtIndex:i];
	if ([graphic isLocked])
	    [graphics addObject:graphic];
    }

    if ([graphics count] == 0)
        [self disable]; 
}

- (void)redoChange
{
    [graphics makeObjectsPerform:@selector(unlock)];
    [graphicView resetLockedFlag];

    [super redoChange]; 
}

- (Class)changeDetailClass
{
    return nil;
}

- (void)undoDetails
{
    int i, count;
    NSMutableArray *selectedGraphics;
    id graphic;
    
    selectedGraphics = [graphicView selectedGraphics];
    count = [graphics count];
    for (i = 0; i < count; i++) {
        graphic = [graphics objectAtIndex:i];
	[graphic lockGraphic];
	[graphic deselect];
	[selectedGraphics removeObject:graphic];
    }
    [graphicView resetLockedFlag]; 
}

@end
