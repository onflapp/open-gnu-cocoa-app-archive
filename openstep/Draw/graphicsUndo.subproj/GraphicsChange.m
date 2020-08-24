#import "drawundo.h"

/*
 * Please refer to external documentation about Draw
 * with Undo for information about what GraphicsChange 
 * is and where it fits in.
 */

@interface GraphicsChange(PrivateMethods)

- (void)undoDetails;
- (void)redoDetails;

@end

@implementation GraphicsChange

- initGraphicView:aGraphicView
{
    [super init];
    graphicView = aGraphicView;
    graphics = nil;
    changeDetails = nil;

    return self;
}

- initGraphicView:aGraphicView forChangeToGraphic:aGraphic
{
    [self initGraphicView:aGraphicView];
    graphicsToChange = [[NSMutableArray alloc] init];
    [graphicsToChange addObject:aGraphic];
    return self;
}

- (void)dealloc
{
   [graphics release];
   [graphicsToChange release];
    if (changeDetails != nil) {
	[changeDetails removeAllObjects];
	[changeDetails release];
    }

    [super dealloc];
}

- (void)saveBeforeChange
{
    NSMutableArray *selectedGraphics;
    int i, count;
    Class changeDetailClass;
    id changeDetail;
    BOOL changeExpected = NO;

    if (!graphicsToChange) {
	selectedGraphics = [graphicView selectedGraphics];
    } else {
	selectedGraphics = graphicsToChange;
    }
    count = [selectedGraphics count];
    if (count == 0) {
        [self disable];
    } else {
	changeDetailClass = [self changeDetailClass];
	if (changeDetailClass != nil)
	    changeDetails = [[NSMutableArray alloc] init];
	else
	    changeExpected = YES;
	graphics = [[NSMutableArray alloc] init];
	for (i = 0; i < count; i++) {
	    [graphics addObject:[selectedGraphics objectAtIndex:i]];
	    if (changeDetailClass != nil) {
		changeDetail = [[changeDetailClass alloc] initGraphic:[selectedGraphics objectAtIndex:i] change:self];
		changeExpected = changeExpected || [changeDetail changeExpected];
		[changeDetails addObject:changeDetail];
	    }
	}
    }
    
    if (!changeExpected)
        [self disable]; 
}

- (void)undoChange
{
    [graphicView redrawGraphics:graphics afterChangeAgent:self performs:@selector(undoDetails)];
    [[graphicView window] flushWindow];
    [[[NSApp inspectorPanel] delegate] loadGraphic:[graphicView selectedGraphic]]; 

    [super undoChange]; 
}

- (void)redoChange
{
    [graphicView redrawGraphics:graphics afterChangeAgent:self performs:@selector(redoDetails)];
    [[graphicView window] flushWindow];
    [[[NSApp inspectorPanel] delegate] loadGraphic:[graphicView selectedGraphic]]; 

    [super redoChange]; 
}

- (Class)changeDetailClass
/*
 * To be overridden 
 */
{
    return [ChangeDetail class];
}

- (void)undoDetails
/*
 * To be overridden 
 */
{
     
}

- (void)redoDetails
/*
 * To be overridden 
 */
{
     
}

@end
