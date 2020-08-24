#import "drawundo.h"

@interface PasteGraphicsChange(PrivateMethods)

- (void)undoDetails;
- (void)redoDetails;

@end

@implementation PasteGraphicsChange

- initGraphicView:aGraphicView graphics:theGraphics
{
    int i, count;
    
    [super initGraphicView:aGraphicView];
    graphics = [[NSMutableArray alloc] init];
    count = [theGraphics count];
    for (i = 0; i < count; i++) {
	[graphics addObject:[theGraphics objectAtIndex:i]];
    }

    return self;
}

- (void)dealloc
{
    if (![self hasBeenDone])
        [graphics removeAllObjects];
    [super dealloc];
}

- (NSString *)changeName
{
    return PASTE_OP;
}

- (void)saveBeforeChange
{
     
}

- (Class)changeDetailClass
{
    return nil;
}

- (void)undoDetails
{
    int count, i;
    id graphic;
    NSMutableArray *selectedGraphics;
    NSMutableArray *allGraphics;

    selectedGraphics = [graphicView selectedGraphics];
    allGraphics = [graphicView graphics];
    count = [graphics count];
    for (i = 0; i < count; i++) {
	graphic = [graphics objectAtIndex:i];
        [selectedGraphics removeObject:graphic];
        [allGraphics removeObject:graphic];
	[graphic wasRemovedFrom:graphicView];
    }
    [graphicView resetGroupInSlist]; 
}

- (void)redoDetails
{
    int count, i;
    id graphic;
    NSMutableArray *selectedGraphics;
    NSMutableArray *allGraphics;

    selectedGraphics = [graphicView selectedGraphics];
    allGraphics = [graphicView graphics];
    count = [graphics count];
    i = count;
    while (i--) {
	graphic = [graphics objectAtIndex:i];
	[selectedGraphics insertObject:graphic atIndex:0];
	[allGraphics insertObject:graphic atIndex:0];
	[graphic wasAddedTo:graphicView];
        if ([graphic isKindOfClass:[Group class]]) [graphicView setGroupInSlist:YES];
    } 
}

@end
