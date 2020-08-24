#import "drawundo.h"

@interface AspectRatioGraphicsChange(PrivateMethods)

@end

@implementation AspectRatioGraphicsChange

- (NSString *)changeName
{
    return ASPECT_OP;
}

- (Class)changeDetailClass
{
    return [DimensionsChangeDetail class];
}

@end
