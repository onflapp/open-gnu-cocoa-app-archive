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

@interface StartEditingGraphicsChange : Change
{
    TextGraphic	*graphic;
}

- initGraphic:aGraphic;
- (NSString *)changeName;
- (void)undoChange;
- (void)redoChange;

@end
