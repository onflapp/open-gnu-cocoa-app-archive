#import "drawundo.h"

@interface ReorderGraphicsChange(PrivateMethods)

- (void)undoDetails;

@end

@implementation ReorderGraphicsChange

- (void)saveBeforeChange
{
    [super saveBeforeChange];
    [changeDetails makeObjectsPerform:@selector(recordGraphicPositionIn:) withObject:[graphicView graphics]]; 
}

- (Class)changeDetailClass
{
    return [OrderChangeDetail class];
}

- (void)undoDetails
{
    int count, i;
    id detail, graphic;
    NSMutableArray *allGraphics;

    count = [changeDetails count];
    allGraphics = [graphicView graphics];
    for (i = 0; i < count; i++) {
	detail = [changeDetails objectAtIndex:i];
	graphic = [detail graphic];
        [allGraphics removeObject:graphic];
    }
    for (i = 0; i < count; i++) {
	detail = [changeDetails objectAtIndex:i];
	graphic = [detail graphic];
        [allGraphics insertObject:graphic atIndex:[detail graphicPosition]];
    } 
}

@end
