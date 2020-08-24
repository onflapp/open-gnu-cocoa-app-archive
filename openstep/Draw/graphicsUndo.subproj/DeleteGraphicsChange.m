#import "drawundo.h"

@interface DeleteGraphicsChange(PrivateMethods)

- (void)undoDetails;
- (void)redoDetails;

@end

@implementation DeleteGraphicsChange

- (void)dealloc
{
    if ([self hasBeenDone])
        [graphics removeAllObjects];
    [super dealloc];
}

- (NSString *)changeName
{
    return DELETE_OP;
}

- (void)saveBeforeChange
{
    [super saveBeforeChange];
    [changeDetails makeObjectsPerform:@selector(recordGraphicPositionIn:) withObject:[graphicView graphics]]; 
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
        [allGraphics insertObject:graphic atIndex:[detail graphicPosition]];
	[graphic wasAddedTo:graphicView];
    }
    [graphicView getSelection]; 
}

- (void)redoDetails
{
    int count, i;
    id detail, graphic;
    NSMutableArray *selectedGraphics;
    NSMutableArray *allGraphics;

    selectedGraphics = [graphicView selectedGraphics];
    allGraphics = [graphicView graphics];
    count = [changeDetails count];
    for (i = 0; i < count; i++) {
	detail = [changeDetails objectAtIndex:i];
	graphic = [detail graphic];
        [selectedGraphics removeObject:graphic];
        [allGraphics removeObject:graphic];
	[graphic wasRemovedFrom:graphicView];
    }
    [graphicView resetGroupInSlist]; 
}

- (Class)changeDetailClass
{
    return [OrderChangeDetail class];
}

@end
