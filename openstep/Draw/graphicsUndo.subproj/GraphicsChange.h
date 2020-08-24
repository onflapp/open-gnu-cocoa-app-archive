/*
 * Please refer to external documentation about Draw
 * with Undo for information about what GraphicsChange 
 * is and where it fits in.
 */

@interface GraphicsChange : Change
{
    id graphicView;		/* the view this change is done in */
    NSMutableArray *changeDetails;	/* instances of ChangeDetail used to
    				   record information about the state
				   particular graphics involved in the
				   change */
    NSMutableArray *graphicsToChange;	/* list of graphics to affect if different
				   than the selected graphics */
    NSMutableArray *graphics;		/* the graphics involved in the change,
    				   usually the graphics that were 
				   selected at the time of the change */
}

/* Initializing a GraphicsChange */

- initGraphicView:aGraphicView;
- initGraphicView:aGraphicView forChangeToGraphic:aGraphic;

/* Methods overridden from Change */

- (void)saveBeforeChange;
- (void)undoChange;
- (void)redoChange;

/* Other public methods */

- (Class)changeDetailClass;

@end
