#import "drawundo.h"

@interface GroupGraphicsChange(PrivateMethods)

- (void)undoDetails;
- (void)redoDetails;

@end

@implementation GroupGraphicsChange


- (NSString *)changeName
{
    return GROUP_OP;
}

- (void)saveBeforeChange
{
    [super saveBeforeChange];
    [changeDetails makeObjectsPerform:@selector(recordGraphicPositionIn:) withObject:[graphicView graphics]]; 
}

- (Class)changeDetailClass
{
    return [OrderChangeDetail class];
}

- (void)noteGroup:aGroup
{
    group = aGroup;
    [group retain]; 
}

- (void)undoDetails
{
    int count, i;
    id detail, graphic;
    NSMutableArray *allGraphics;

    allGraphics = [graphicView graphics];
    [allGraphics removeObject:group];
    count = [changeDetails count];
    for (i = 0; i < count; i++) {
	detail = [changeDetails objectAtIndex:i];
	graphic = [detail graphic];
	[graphic setCacheable:YES];
        [allGraphics insertObject:graphic atIndex:[detail graphicPosition]];
    }
    [graphicView getSelection];
    [graphicView resetGroupInSlist]; 
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
	[graphic setCacheable:NO];
        [selectedGraphics removeObject:graphic];
        [allGraphics removeObject:graphic];
    }
    [allGraphics insertObject:group atIndex:0];
    [graphicView setGroupInSlist:YES];
    [graphicView getSelection]; 
}

@end
