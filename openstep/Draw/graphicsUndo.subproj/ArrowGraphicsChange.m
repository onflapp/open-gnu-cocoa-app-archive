#import "drawundo.h"

@interface ArrowGraphicsChange(PrivateMethods)

@end

@implementation ArrowGraphicsChange

- initGraphicView:aGraphicView lineArrow:(int)anArrowValue
{
    [super initGraphicView:aGraphicView];
    arrowValue = anArrowValue;
    return self;
}

- (NSString *)changeName
{
    return ARROW_OP;
}

- (Class)changeDetailClass
{
    return [ArrowChangeDetail class];
}

- (int)lineArrow
{
    return arrowValue;
}

@end
