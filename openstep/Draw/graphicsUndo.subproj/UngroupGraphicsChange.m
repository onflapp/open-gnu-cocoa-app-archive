#import "drawundo.h"

@interface UngroupGraphicsChange(PrivateMethods)

@end

@implementation UngroupGraphicsChange

- initGraphicView:aGraphicView
{
    [super init];
    graphicView = aGraphicView;
    changeDetails = nil;
    groups = nil;

    return self;
}

- (void)dealloc
{
    int i, count;
    id group;

    if ([self hasBeenDone]) {
	count = [groups count];
	for (i = 0; i < count; i++) {
	    group = [groups objectAtIndex:i];
	    [[group subGraphics] removeAllObjects];
	    [group release];
	}
    }
    [groups release];
    if (changeDetails != nil) {
	[changeDetails removeAllObjects];
	[changeDetails release];
    }
    [super dealloc];
}

- (NSString *)changeName
{
    return UNGROUP_OP;
}

- (void)saveBeforeChange
{
    NSMutableArray *selectedGraphics;
    int i, count;
    id g;
    id changeDetailClass;

    groups = [[NSMutableArray alloc] init];
    changeDetailClass = [self changeDetailClass];
    changeDetails = [[NSMutableArray alloc] init];

    selectedGraphics = [graphicView selectedGraphics];
    count = [selectedGraphics count];
    for (i = 0; i < count; i++) {
	g = [selectedGraphics objectAtIndex:i];
	if ([g isKindOfClass:[Group class]]) {
	    [groups addObject:g];
	    [changeDetails addObject:[[changeDetailClass alloc] initGraphic:g change:self]];
	}
    }
    [changeDetails makeObjectsPerform:@selector(recordGraphicPositionIn:) withObject:[graphicView graphics]];

    count = [groups count];
    if (count == 0)
        [self disable]; 
}

- (void)undoChange
{
    NSMutableArray *allGraphics, *graphics;
    int i, j, count, graphicCount;
    NSRect affectedBounds;
    id group, graphic, detail;

    allGraphics = [graphicView graphics];
    count = [changeDetails count];
    for (i = 0; i < count; i++) {
        detail = [changeDetails objectAtIndex:i];
	group = [detail graphic];
	graphics = [group subGraphics];
	graphicCount = [graphics count];
	for (j = 0; j < graphicCount; j++) {
	    graphic = [graphics objectAtIndex:j];
	    [graphic setCacheable:NO];
	    [allGraphics removeObject:graphic];
	}
	[allGraphics insertObject:group atIndex:[detail graphicPosition]];
    }
    
    [graphicView getSelection];
    [graphicView setGroupInSlist:YES];
    affectedBounds = [graphicView getBBoxOfArray:groups];
    [graphicView cache:affectedBounds];
    [[graphicView window] flushWindow];
    [[[NSApp inspectorPanel] delegate] loadGraphic:[graphicView selectedGraphic]]; 

    [super undoChange]; 
}

- (void)redoChange
{
    NSMutableArray *allGraphics;
    int k;
    int i, count;
    NSRect affectedBounds;
    id group;

    affectedBounds = [graphicView getBBoxOfArray:groups];

    allGraphics = [graphicView graphics];
    count = [groups count];
    for (i = 0; i < count; i++) {
        group = [groups objectAtIndex:i];
	k = [allGraphics indexOfObject:group];
	[allGraphics removeObjectAtIndex:k];
	[group transferSubGraphicsTo:allGraphics at:k];
    }

    [graphicView getSelection];
    [graphicView resetGroupInSlist];
    [graphicView cache:affectedBounds];
    [[graphicView window] flushWindow];
    [[[NSApp inspectorPanel] delegate] loadGraphic:[graphicView selectedGraphic]]; 


    [super redoChange]; 
}

- (Class)changeDetailClass
{
    return [OrderChangeDetail class];
}

@end
