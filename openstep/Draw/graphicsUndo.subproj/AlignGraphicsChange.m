#import "drawundo.h"

@interface AlignGraphicsChange(PrivateMethods)

@end

@implementation AlignGraphicsChange

- (NSString *)changeName
{
    return ALIGN_OP;
}

- (Class)changeDetailClass
{
    return [DimensionsChangeDetail class];
}

@end
