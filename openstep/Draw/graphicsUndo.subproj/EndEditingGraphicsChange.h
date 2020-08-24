/*
 * This change is created when the user finishes editing a text
 * graphic. Undoing this change inserts the re-inserts the text
 * editing cursor in the text. More significantly, undoing this
 * change swaps the contents of the TextGraphic back into the
 * field editor so that it is ready to edit.
 */

@interface EndEditingGraphicsChange : Change
{
    id 		graphicView;
    TextGraphic	*graphic;
}

- initGraphicView:aGraphicView graphic:aGraphic;
- (NSString *)changeName;
- (void)undoChange;
- (void)redoChange;

@end
