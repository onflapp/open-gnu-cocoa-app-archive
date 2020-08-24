#import "drawundo.h"

@interface BringToFrontGraphicsChange(PrivateMethods)

- (void)redoDetails;

@end

@implementation BringToFrontGraphicsChange

- (NSString *)changeName
{
    return BRING_TO_FRONT_OP;
}

- (void)redoDetails
{
    int count, i;
    id detail, graphic;
    NSMutableArray *allGraphics;

    allGraphics = [graphicView graphics];
    count = [changeDetails count];
    for (i = count; i >= 0; --i) {
	detail = [changeDetails objectAtIndex:i];
	graphic = [detail graphic];
        [allGraphics removeObject:graphic];
        [allGraphics insertObject:graphic atIndex:0];
    } 
}

@end
