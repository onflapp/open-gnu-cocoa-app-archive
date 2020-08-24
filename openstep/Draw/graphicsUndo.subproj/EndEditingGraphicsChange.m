#import "drawundo.h"

/*
 * This change is created when the user finishes editing a text
 * graphic. Undoing this change inserts the re-inserts the text
 * editing cursor in the text. More significantly, undoing this
 * change swaps the contents of the TextGraphic back into the
 * field editor so that it is ready to edit.
 */

@interface EndEditingGraphicsChange(PrivateMethods)

@end

@implementation EndEditingGraphicsChange

- initGraphicView:aGraphicView graphic:aGraphic
{
    [super init];
    graphicView = aGraphicView;
    graphic = aGraphic;

    return self;
}

- (void)dealloc
{
    if ([self hasBeenDone] && [graphic isEmpty])
        [graphic release];
    [super dealloc];
}

- (NSString *)changeName
{
    return END_EDITING_OP;
}

- (void)undoChange
{
    if ([graphic isEmpty])
	[graphicView insertGraphic:graphic];
    [graphic prepareFieldEditor];    
    [NSApp startEditMode];
    [super undoChange]; 
}

- (void)redoChange
{
/* 
 * The order of the next two statements is important.
 * If endEditMode were sent before resignFieldEditor 
 * it would send resetCursor to the document which would
 * make the window the first responder which would end
 * up sending textDidEnd:endChar: to the TextGraphic.
 * Then in the next line we'd send resignFieldEditor to
 * the TextGraphic even though it had already resigned 
 * the field editor.
 */
    [graphic resignFieldEditor];
    [NSApp endEditMode];
    if ([graphic isEmpty])
	[graphicView removeGraphic:graphic];
    [super redoChange]; 
}

@end
