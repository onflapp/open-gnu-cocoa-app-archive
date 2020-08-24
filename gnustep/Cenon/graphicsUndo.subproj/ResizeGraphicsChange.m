#import "drawundo.h"

@interface ResizeGraphicsChange(PrivateMethods)

- (void)undoDetails;
- (void)redoDetails;

@end

@implementation ResizeGraphicsChange

- initGraphicView:aGraphicView graphic:aGraphic
{
    [super initGraphicView:aGraphicView];
    graphic = aGraphic;
    return self;
}

- (NSString *)changeName
{
    return RESIZE_OP;
}

- (void)saveBeforeChange
{
    graphics = [[NSMutableArray alloc] init];
    [graphics addObject:graphic];
    oldSize = [graphic size];
}

- (Class)changeDetailClass
{
    return nil;
}

- (void)undoDetails
{
    newSize = [graphic size];
    [graphic setSize:oldSize]; 
}

- (void)redoDetails
{
    [graphic setSize:newSize]; 
}

@end
