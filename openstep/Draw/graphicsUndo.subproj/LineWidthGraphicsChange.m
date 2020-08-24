#import "drawundo.h"

@interface LineWidthGraphicsChange(PrivateMethods)

- (BOOL)subsumeIdenticalChange:change;

@end

@implementation LineWidthGraphicsChange

- initGraphicView:aGraphicView lineWidth:(float)aWidth
{
    [super initGraphicView:aGraphicView];
    widthValue = aWidth;
    return self;
}

- (NSString *)changeName
{
    return LINEWIDTH_OP;
}

- (Class)changeDetailClass
{
    return [LineWidthChangeDetail class];
}

- (float)lineWidth
{
    return widthValue;
}

- (BOOL)subsumeIdenticalChange:change
{
    widthValue = [(LineWidthGraphicsChange *)change lineWidth];
    return YES;
}

@end
