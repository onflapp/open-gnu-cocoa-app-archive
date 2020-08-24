#import "drawundo.h"

@interface FillGraphicsChange(PrivateMethods)

- (BOOL)subsumeIdenticalChange:change;

@end

@implementation FillGraphicsChange

- initGraphicView:aGraphicView
{
    return [self initGraphicView:aGraphicView fill:-1];
}

- initGraphicView:aGraphicView fill:(int)fillValue
{
    [super initGraphicView:aGraphicView];
    fill = fillValue;
    return self;
}

- (NSString *)changeName
{
    return FILL_OP;
}

- (Class)changeDetailClass
{
    return [FillChangeDetail class];
}

- (BOOL)subsumeIdenticalChange:change
{
    return YES;
}

- (int)fill
{
    return fill;
}

@end
