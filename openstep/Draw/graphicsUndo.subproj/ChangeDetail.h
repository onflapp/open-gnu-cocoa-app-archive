/*
 * Please refer to external documentation about Draw
 * with Undo for information about what ChangeDetails 
 * are and where they fit in.
 *
 * The ChangeDetail.h and ChangeDetail.m files contain
 * the @interfaces and @implementations for the 11 
 * subclasses of ChangeDetail, as well as for ChangeDetail
 * itself. We grouped all the classes into one pair of 
 * files because the classes are so tiny and their behavior
 * is so similar.
 *
 * ChangeDetail
 *     ArrowChangeDetail
 *     DimensionsChangeDetail
 *     FillColorChangeDetail
 *     FillModeChangeDetail
 *     LineCapChangeDetail
 *     LineColorChangeDetail
 *     LineJoinChangeDetail
 *     LineWidthChangeDetail
 *     MoveChangeDetail
 *     OrderChangeDetail
 * 
 */

@interface ChangeDetail : NSObject
{
    Graphic	*graphic;	 /* the Graphic that we serve */
    id		change;		 /* the Change object that we belong to */
    NSMutableArray	*detailsDetails; /* If the Graphic that this ChangeDetail
    				  * serves is a Group then detailsDetails
				  * is used to keep track of the
				  * ChangeDetails that serve the component
				  * Graphics of the Group.
				  */
    BOOL	changeExpected;
}

- initGraphic:aGraphic change:aChange;
- (Graphic *)graphic;
- (BOOL)useNestedDetails;
- (BOOL)changeExpected;
- (void)recordDetail;
- (void)undoDetail;
- (void)redoDetail;
- (void)recordIt;
- (void)undoIt;
- (void)redoIt;

@end

@interface ArrowChangeDetail : ChangeDetail
{
    int		oldLineArrow;
}

- (void)recordIt;
- (void)undoIt;
- (void)redoIt;

@end

@interface DimensionsChangeDetail : ChangeDetail
{
    NSRect 	oldBounds;
    NSRect 	newBounds;
}

- (BOOL)useNestedDetails;
- (void)recordDetail;
- (void)undoDetail;
- (void)redoDetail;

@end

@interface FillChangeDetail : ChangeDetail
{
    NSColor *	oldFillColor;
    int		oldFillMode;
    NSColor *	newFillColor;
    int		newFillMode;
}

- (void)recordIt;
- (void)undoIt;
- (void)redoIt;

@end

@interface LineCapChangeDetail : ChangeDetail
{
    int		oldLineCap;
}

- (void)recordIt;
- (void)undoIt;
- (void)redoIt;

@end

@interface LineColorChangeDetail : ChangeDetail
{
    NSColor *	oldColor;
    BOOL	oldIsOutlined;
}

- (void)recordIt;
- (void)undoIt;
- (void)redoIt;

@end

@interface LineJoinChangeDetail : ChangeDetail
{
    int		oldLineJoin;
}

- (void)recordIt;
- (void)undoIt;
- (void)redoIt;

@end

@interface LineWidthChangeDetail : ChangeDetail
{
    float	oldLineWidth;
}

- (void)recordIt;
- (void)undoIt;
- (void)redoIt;

@end

@interface MoveChangeDetail : ChangeDetail
{

}

- (BOOL)useNestedDetails;
- (void)undoDetail;
- (void)redoDetail;

@end

@interface OrderChangeDetail : ChangeDetail
{
    unsigned	graphicPosition;
}

- (BOOL)useNestedDetails;
- (void)recordGraphicPositionIn:graphicList;
- (unsigned)graphicPosition;

@end
