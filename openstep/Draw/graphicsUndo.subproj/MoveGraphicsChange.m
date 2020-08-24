#import "drawundo.h"

@interface MoveGraphicsChange(PrivateMethods)

- (BOOL)subsumeIdenticalChange:change;

@end

@implementation MoveGraphicsChange

- initGraphicView:aGraphicView vector:(NSPoint)aVector
{
    [super initGraphicView:aGraphicView];
    redoVector.x = aVector.x;
    redoVector.y = aVector.y;
    undoVector.x = -redoVector.x;
    undoVector.y = -redoVector.y;

    return self;
}

- (NSString *)changeName
{
    return MOVE_OP;
}

- (Class)changeDetailClass
{
    return [MoveChangeDetail class];
}

- (NSPoint)undoVector
{
    return undoVector;
}

- (NSPoint)redoVector
{
    return redoVector;
}

- (BOOL)subsumeIdenticalChange:change
{
    MoveGraphicsChange	*moveChange;
    
    moveChange = (MoveGraphicsChange *)change;
    undoVector.x += moveChange->undoVector.x;
    undoVector.y += moveChange->undoVector.y;
    redoVector.x += moveChange->redoVector.x;
    redoVector.y += moveChange->redoVector.y;
    
    return YES;
}

@end
