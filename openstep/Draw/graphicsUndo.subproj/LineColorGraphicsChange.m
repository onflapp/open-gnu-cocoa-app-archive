#import "drawundo.h"

@interface LineColorGraphicsChange(PrivateMethods)

- (BOOL)subsumeIdenticalChange:change;

@end

@implementation LineColorGraphicsChange

- initGraphicView:aGraphicView color:(NSColor *)aColor
{
    [super initGraphicView:aGraphicView];
    color = [aColor copyWithZone:(NSZone *)[self zone]];
    return self;
}

- (NSString *)changeName
{
    return LINECOLOR_OP;
}

- (Class)changeDetailClass
{
    return [LineColorChangeDetail class];
}

- (NSColor *)lineColor
{
    return color;
}

- (BOOL)subsumeIdenticalChange:change
{
    color = [(LineColorGraphicsChange *)change lineColor];
    return YES;
}

- (void)dealloc
{
    [color release];
    [super dealloc];
}

@end
