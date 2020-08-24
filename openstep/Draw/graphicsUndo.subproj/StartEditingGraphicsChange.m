#import "drawundo.h"

/*
 * This change is created when the user begins editing a text
 * graphic, either by clicking in graphic while in the text tool
 * is selected or by creating a new graphic with the text tool. 
 * Undoing this change inserts the removes the text editing
 * cursor from the text. More significantly, undoing this
 * change swaps the contents of the field editor back into the
 * TextGraphic and redoing this change swaps the contents of the
 * TextGraphic into the field editor.
 */

@interface StartEditingGraphicsChange(PrivateMethods)

@end

@implementation StartEditingGraphicsChange

- initGraphic:aGraphic
{
    [super init];
    graphic = aGraphic;

    return self;
}

- (NSString *)changeName
{
    return START_EDITING_OP;
}

- (void)undoChange
{
    [graphic resignFieldEditor];
    [NSApp endEditMode];
    [super undoChange]; 
}

- (void)redoChange
{
    [graphic prepareFieldEditor];
    [NSApp startEditMode];
    [super redoChange]; 
}

@end
