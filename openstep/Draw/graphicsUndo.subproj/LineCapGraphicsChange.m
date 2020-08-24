#import "drawundo.h"

@interface LineCapGraphicsChange(PrivateMethods)

@end

@implementation LineCapGraphicsChange

- initGraphicView:aGraphicView lineCap:(int)aCapValue
{
    [super initGraphicView:aGraphicView];
    capValue = aCapValue;
    return self;
}

- (NSString *)changeName
{
    return LINECAP_OP;
}

- (Class)changeDetailClass
{
    return [LineCapChangeDetail class];
}

- (int)lineCap
{
    return capValue;
}

@end
