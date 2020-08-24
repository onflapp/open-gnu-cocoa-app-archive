#import "drawundo.h"

@interface DimensionsGraphicsChange(PrivateMethods)

@end

@implementation DimensionsGraphicsChange

- (NSString *)changeName
{
    return DIMENSION_OP;
}

- (Class)changeDetailClass
{
    return [DimensionsChangeDetail class];
}

@end
