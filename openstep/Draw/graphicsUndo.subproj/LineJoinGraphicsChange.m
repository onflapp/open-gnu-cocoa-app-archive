#import "drawundo.h"

@interface LineJoinGraphicsChange(PrivateMethods)

@end

@implementation LineJoinGraphicsChange

- initGraphicView:aGraphicView lineJoin:(int)aJoinValue
{
    [super initGraphicView:aGraphicView];
    joinValue = aJoinValue;
    return self;
}

- (NSString *)changeName
{
    return LINEJOIN_OP;
}

- (int)lineJoin
{
    return joinValue;
}

- (Class)changeDetailClass
{
    return [LineJoinChangeDetail class];
}

@end
