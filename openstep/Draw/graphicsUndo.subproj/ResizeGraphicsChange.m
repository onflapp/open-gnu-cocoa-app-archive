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
    oldBounds = [graphic bounds]; 
}

- (Class)changeDetailClass
{
    return nil;
}

- (void)undoDetails
{
    newBounds = [graphic bounds];
    [graphic setBounds:oldBounds]; 
}

- (void)redoDetails
{
    [graphic setBounds:newBounds]; 
}

@end
