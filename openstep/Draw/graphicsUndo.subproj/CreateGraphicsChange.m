#import "drawundo.h"

@interface CreateGraphicsChange(PrivateMethods)

@end

@implementation CreateGraphicsChange

- initGraphicView:aGraphicView graphic:aGraphic
{
    [super init];
    graphicView = aGraphicView;
    graphic = aGraphic;
    startEditingChange = nil;

    return self;
}

- (void)dealloc
{
    if (![self hasBeenDone])
        [graphic release];
    if (startEditingChange)
        [startEditingChange release];
    [super dealloc];
}

- (NSString *)changeName
{
    return [NSString stringWithFormat:NEW_CHANGE_OP, [graphic title]];
}

- (void)undoChange
{
    if (startEditingChange)
        [startEditingChange undoChange];
    [graphicView removeGraphic:graphic];
    [[[NSApp inspectorPanel] delegate] loadGraphic:[graphicView selectedGraphic]]; 
    [super undoChange]; 
}

- (void)redoChange
{
    [graphicView insertGraphic:graphic];
    [[[NSApp inspectorPanel] delegate] loadGraphic:[graphicView selectedGraphic]];
    if (startEditingChange)
        [startEditingChange redoChange];
    [super redoChange]; 
}

- (BOOL)incorporateChange:change
/*
 * ChangeManager will call incorporateChange: if another change
 * is started while we are still in progress (after we've 
 * been sent startChange but before we've been sent endChange). 
 * We override incorporateChange: because we want to
 * incorporate a StartEditingGraphicsChange if it happens.
 * Rather than know how to undo and redo the start-editing stuff,
 * we'll simply keep a pointer to the StartEditingGraphicsChange
 * and ask it to undo and redo whenever we undo or redo.
 */
{
    if ([change isKindOfClass:[StartEditingGraphicsChange class]]) {
        startEditingChange = change;
        return YES;
    } else {
        return NO;
    }
}

@end
