#import "drawundo.h"

@interface SendToBackGraphicsChange(PrivateMethods)

- (void)redoDetails;

@end

@implementation SendToBackGraphicsChange

- (NSString *)changeName
{
    return SEND_TO_BACK_OP;
}

- (void)redoDetails
{
    int count, i;
    id detail, graphic;
    NSMutableArray *allGraphics;

    allGraphics = [graphicView graphics];
    count = [changeDetails count];
    for (i = 0; i < count; i++) {
	detail = [changeDetails objectAtIndex:i];
	graphic = [detail graphic];
        [allGraphics removeObject:graphic];
        [allGraphics addObject:graphic];
    } 
}

@end
