#import "drawundo.h"

@interface LockGraphicsChange(PrivateMethods)

- (void)redoDetails;

@end

@implementation LockGraphicsChange

- (NSString *)changeName
{
    return LOCK_OP;
}

- (void)undoChange
{
    [graphics makeObjectsPerform:@selector(unlock)];
    [graphics makeObjectsPerform:@selector(select)];
    [graphicView resetLockedFlag];
    [graphicView getSelection];

    [super undoChange]; 
}

- (Class)changeDetailClass
{
    return nil;
}

- (void)redoDetails
{
    int i, count;
    NSMutableArray *selectedGraphics;
    id graphic;
    
    selectedGraphics = [graphicView selectedGraphics];
    count = [graphics count];
    for (i = 0; i < count; i++) {
        graphic = [graphics objectAtIndex:i];
	[graphic unlockGraphic];
	[graphic deselect];
	[selectedGraphics removeObject:graphic];
    }
    [graphicView resetLockedFlag]; 
}

@end
