/* ChangeDetail.h
 *
 * Copyright (C) 1993-2012 by vhf interservice GmbH
 * Authors:  Georg Fleischmann
 *
 * created:  1993
 * modified: 2011-05-28 (ExcludeChangeDetail added)
 *
 * The ChangeDetail files contain the @interfaces and @implementations
 * for the subclasses of ChangeDetail, as well as for ChangeDetail
 * itself. We grouped all the classes into one pair of files
 * because the classes are so tiny and their behavior is so similar.
 *
 * ChangeDetail
 *     DimensionsChangeDetail
 *     FillColorChangeDetail
 *     LineColorChangeDetail
 *     LineWidthChangeDetail
 *     MoveChangeDetail
 *     OrderChangeDetail
 *     StepWidthChangeDetail
 *     RadialCenterChangeDetail
 */

@interface ChangeDetail : NSObject
{
    VGraphic        *graphic;	 // the VGraphic that we serve
    int             layer;		 // the layer of the graphics
    id              change;		 // the Change object that we belong to
    NSMutableArray  *detailsDetails; /* If the Graphic that this ChangeDetail
                                      * serves is a Group then detailsDetails
                                      * is used to keep track of the
                                      * ChangeDetails that serve the component
                                      * Graphics of the Group.
                                      */
    BOOL            changeExpected;
}
- initGraphic:aGraphic change:aChange;
- (VGraphic *)graphic;
- (void)setLayer:(int)lay;
- (int)layer;
- (BOOL)useNestedDetails;
- (BOOL)changeExpected;
- (void)recordDetail;
- (void)undoDetail;
- (void)redoDetail;
- (void)recordIt;
- (void)undoIt;
- (void)redoIt;
@end

@interface DimensionsChangeDetail: ChangeDetail
{
    NSRect 	oldBounds;
    VFloat  oldWidth;   // stroke width
    NSRect 	newBounds;
    VFloat  newWidth;
}
- (BOOL)useNestedDetails;
- (void)recordDetail;
- (void)undoDetail;
- (void)redoDetail;
@end

@interface RadiusChangeDetail: ChangeDetail
{
    float	oldRadius, newRadius;
}
- (BOOL)useNestedDetails;
- (void)recordDetail;
- (void)undoDetail;
- (void)redoDetail;
@end

@interface ExcludeChangeDetail: ChangeDetail
{
    BOOL	isExcluded;
}
- (BOOL)useNestedDetails;
- (void)recordDetail;
- (void)undoDetail;
- (void)redoDetail;
@end

@interface LockChangeDetail: ChangeDetail
{
    BOOL	isLocked;
}
- (BOOL)useNestedDetails;
- (void)recordDetail;
- (void)undoDetail;
- (void)redoDetail;
@end

@interface FillChangeDetail: ChangeDetail
{
    int		oldFillMode;
    int		newFillMode;
}
- (void)recordIt;
- (void)undoIt;
- (void)redoIt;
@end

@interface ColorChangeDetail: ChangeDetail
{
    NSColor *oldColor;
}
- (void)recordIt;
- (void)undoIt;
- (void)redoIt;
@end

@interface LabelChangeDetail: ChangeDetail
{
    NSString	*oldLabel;
}
- (void)recordIt;
- (void)undoIt;
- (void)redoIt;
@end

@interface WidthChangeDetail: ChangeDetail
{
    float	oldLineWidth;
}
- (void)recordIt;
- (void)undoIt;
- (void)redoIt;
@end

@interface LengthChangeDetail: ChangeDetail
{
    float	oldLength;
}
- (void)recordIt;
- (void)undoIt;
- (void)redoIt;
@end

@interface MoveChangeDetail: ChangeDetail
{
}
- (BOOL)useNestedDetails;
- (void)undoDetail;
- (void)redoDetail;
@end

@interface MovePointChangeDetail: ChangeDetail
{
    int		ptNum;
    NSPoint	oldPoint, newPoint;
    BOOL	control;
}
- (void)recordIt;
- (BOOL)useNestedDetails;
- (void)undoIt;
- (void)redoIt;
@end

@interface AddPointChangeDetail: ChangeDetail
{
    VGraphic	*oldGraphic;	// VPath
    int		oldIx, pt_num;	// VPath, VPolyLine
    NSPoint	newPoint;	// VPath and VPolyLine
}
- (void)recordIt;
- (BOOL)useNestedDetails;
- (void)undoIt;
- (void)redoIt;
@end

@interface RemovePointChangeDetail: ChangeDetail
{
    VGraphic	*removedGr;						// VPath
    int		removedIx, changedIx[2], remPt_num, chPt_num[2];	// VPath, VPolyLine
    NSPoint	removedPt, changedPt[2];				// VPath and VPolyLine
}
- (void)recordIt;
- (BOOL)useNestedDetails;
- (void)undoIt;
- (void)redoIt;
@end

@interface RotateChangeDetail: ChangeDetail
{
}
- (BOOL)useNestedDetails;
- (void)undoDetail;
- (void)redoDetail;
@end

@interface MirrorChangeDetail: ChangeDetail
{
}
- (BOOL)useNestedDetails;
- (void)undoDetail;
- (void)redoDetail;
@end

@interface ScaleChangeDetail: ChangeDetail
{
}
- (BOOL)useNestedDetails;
- (void)undoDetail;
- (void)redoDetail;
@end

@interface AngleChangeDetail: ChangeDetail
{
    float	undoAngle;
}
- (BOOL)useNestedDetails;
- (void)recordDetail;
- (void)undoDetail;
- (void)redoDetail;
@end

@interface OrderChangeDetail : ChangeDetail
{
    unsigned	graphicPosition;
}
- (BOOL)useNestedDetails;
- (void)recordGraphicPositionIn:(NSArray*)layList;
- (unsigned)graphicPosition;
@end

@interface StepWidthChangeDetail: ChangeDetail
{
    float	oldStepWidth;
}
- (void)recordIt;
- (void)undoIt;
- (void)redoIt;
@end

@interface RadialCenterChangeDetail: ChangeDetail
{
    NSPoint	oldRadialCenter;
}
- (void)recordIt;
- (void)undoIt;
- (void)redoIt;
@end
