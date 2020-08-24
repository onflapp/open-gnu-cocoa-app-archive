/* ChangeDetail.m
 *
 * Copyright (C) 1993-2011 by vhf interservice GmbH
 * Authors:  Georg Fleischmann
 *
 * created:  1993 based on the Draw example files
 * modified: 2011-05-28 (ExcludeChangeDetail added)
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
 *     StepWidthChangeDetail
 *     RadialCenterChangeDetail
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the vhf Public License as
 * published by vhf interservice GmbH. Among other things, the
 * License requires that the copyright notices and this notice
 * be preserved on all copies.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the vhf Public License for more details.
 *
 * You should have received a copy of the vhf Public License along
 * with this program; see the file LICENSE. If not, write to vhf.
 *
 * vhf interservice GmbH, Im Marxle 3, 72119 Altingen, Germany
 * eMail: info@vhf.de
 * http://www.vhf.de
 */

#include "undo.h"

@interface ChangeDetail(PrivateMethods)
- (BOOL)personalChangeExpected;
@end

@implementation ChangeDetail

- initGraphic:aGraphic change:aChange
{   NSMutableArray *subGraphics;
    int count, i;
    id changeDetail;

    graphic = aGraphic;
    change = aChange;

    if ([graphic isKindOfClass:[VGroup class]] && [self useNestedDetails])
    {
        detailsDetails = [[NSMutableArray alloc] init];
	subGraphics = [(VGroup *)graphic list];
	count = [subGraphics count];
	changeExpected = NO;
	for (i = 0; i < count; i++)
	{   changeDetail = [[[aChange changeDetailClass] alloc] initGraphic:[subGraphics objectAtIndex:i] change:aChange]; // here the changeExpected of the changeDetail will set !

            if (![changeDetail changeExpected]) // check if changeExpected from changeDetail !
            {   [changeDetail release]; // no changeDetail for this object (line but radialCenter Change)
                continue;
            }
	    changeExpected = YES; // changeExpected || [changeDetail changeExpected];
	    [detailsDetails addObject:changeDetail];
            [changeDetail release];
	}
    }
    else
    {
        detailsDetails = nil;
	changeExpected = [self personalChangeExpected];
    }
    return self;
}

- (void)dealloc
{
    [detailsDetails removeAllObjects];
    [detailsDetails release];
    [super dealloc];
}

- (void)setLayer:(int)lay
{
    layer = lay;
}
- (int)layer
{
    return layer;
}

- (VGraphic *)graphic
{
    return graphic;
}

- (BOOL)useNestedDetails
{
    return YES;
}

- (BOOL)changeExpected
{
    return changeExpected;
}

- (void)recordDetail
{
    if (detailsDetails)
        [detailsDetails makeObjectsPerformSelector:@selector(recordDetail)];
    else
      [self recordIt]; 
}

- (void)undoDetail
{
    if (detailsDetails)
        [detailsDetails makeObjectsPerformSelector:@selector(undoDetail)];
    else
      [self undoIt]; 
}

- (void)redoDetail
{
    if (detailsDetails)
        [detailsDetails makeObjectsPerformSelector:@selector(redoDetail)];
    else
      [self redoIt]; 
}

- (void)recordIt
{
    /* Implemented by subclasses */
     
}

- (void)undoIt
{
    /* Implemented by subclasses */
     
}

- (void)redoIt
{
    /* Implemented by subclasses */
     
}

- (BOOL)personalChangeExpected
{
    return YES;
}

@end


@implementation DimensionsChangeDetail
- (BOOL)useNestedDetails
{
    return NO;
}
- (void)recordDetail
{
    oldBounds.size = [graphic size];
    oldWidth       = [graphic width];
}
- (void)undoDetail
{
    newBounds.size = [graphic size];
    [graphic setSize:oldBounds.size];
    newWidth       = [graphic width];
    [graphic setWidth:oldWidth];
}
- (void)redoDetail
{
    [graphic setSize:newBounds.size];
    [graphic setWidth:newWidth];
}
@end

@implementation RadiusChangeDetail
- (BOOL)useNestedDetails
{
    return NO;
}
- (void)recordDetail
{
    oldRadius = [graphic radius];
}
- (void)undoDetail
{
    newRadius = [graphic radius];
    [graphic setRadius:oldRadius];
}
- (void)redoDetail
{
    [graphic setRadius:newRadius];
}
@end

@implementation ExcludeChangeDetail
- (BOOL)useNestedDetails
{
    return NO;
}
- (void)recordDetail
{
    isExcluded = [graphic isExcluded];
}
- (void)undoDetail
{
    [graphic setExcluded:isExcluded];
}
- (void)redoDetail
{
    [graphic setExcluded:(isExcluded) ? NO : YES];
}
@end

@implementation LockChangeDetail
- (BOOL)useNestedDetails
{
    return NO;
}
- (void)recordDetail
{
    isLocked = [graphic isLocked];
}
- (void)undoDetail
{
    [graphic setLocked:isLocked];
}
- (void)redoDetail
{
    [graphic setLocked:(isLocked) ? NO : YES];
}
@end

@implementation FillChangeDetail
- (void)recordIt
{
    oldFillMode = [graphic filled];
}
- (void)undoIt
{
    newFillMode = [graphic filled];
    [graphic setFilled:oldFillMode];
}
- (void)redoIt
{
    [graphic setFilled:newFillMode];
}
- (BOOL)personalChangeExpected
{
    if (![graphic respondsToSelector:@selector(setFilled)])
        return NO;
    return ([graphic filled] != [(FillGraphicsChange*)change fill]);
}
@end

@implementation ColorChangeDetail
- (void)recordIt
{
    [oldColor release];
    switch ( [change colorNum] )
    {
        default: oldColor = [[graphic color] copy]; break;
        case 1:  oldColor = [[(VPolyLine*)graphic fillColor] copy]; break;
        case 2:  oldColor = [[(VPolyLine*)graphic endColor] copy];
    }
}
- (void)undoIt
{
    switch ( [change colorNum] )
    {
        default: [graphic setColor:oldColor]; break;
        case 1:  [(VPolyLine*)graphic setFillColor:oldColor]; break;
        case 2:  [(VPolyLine*)graphic setEndColor:oldColor];
    }
}
- (void)redoIt
{    NSColor * color = [change color];

    switch ( [change colorNum] )
    {
        default: [graphic setColor:color]; break;
        case 1:  [(VPolyLine*)graphic setFillColor:color]; break;
        case 2:  [(VPolyLine*)graphic setEndColor:color];
    }
}
- (BOOL)personalChangeExpected
{
    switch ( [change colorNum] )
    {
        default: return (![[graphic color] isEqual:[change color]]);
        case 1:
            if (![graphic respondsToSelector:@selector(fillColor)])
                return NO;
            return (![[(VPolyLine*)graphic fillColor] isEqual:[change color]]);
        case 2:
            if (![graphic respondsToSelector:@selector(endColor)])
                return NO;
            return (![[(VPolyLine*)graphic endColor] isEqual:[change color]]);
    }
}
@end

@implementation LabelChangeDetail
- (void)recordIt
{
    oldLabel = [[graphic label] copy];
}
- (void)undoIt
{
    [graphic setLabel:oldLabel];
}
- (void)redoIt
{
    [graphic setLabel:[(LabelGraphicsChange*)change label]];
}
- (void)dealloc
{
    [oldLabel release];
    [super dealloc];
}
@end

@implementation WidthChangeDetail
- (void)recordIt
{
    oldLineWidth = [graphic width]; 
}
- (void)undoIt
{
    [graphic setWidth:oldLineWidth]; 
}
- (void)redoIt
{
    float lineWidth = [(WidthGraphicsChange*)change lineWidth];
    [graphic setWidth:lineWidth]; 
}
- (BOOL)personalChangeExpected
{
    return ([graphic width] != [(WidthGraphicsChange*)change lineWidth]);
}
@end

@implementation LengthChangeDetail
- (void)recordIt
{
    oldLength = [graphic length]; 
}
- (void)undoIt
{
    [graphic setLength:oldLength]; 
}
- (void)redoIt
{
    float length = [(LengthGraphicsChange*)change length];
    [graphic setLength:length]; 
}
- (BOOL)personalChangeExpected
{
    if (![graphic respondsToSelector:@selector(setLength)])
        return NO;
    return ([graphic length] != [(LengthGraphicsChange*)change length]);
}
@end

@implementation MoveChangeDetail
- (BOOL)useNestedDetails
{
    return NO;
}
- (void)undoDetail
{
    NSPoint offset = [change undoVector];
    [graphic moveBy:offset];
}
- (void)redoDetail
{
    NSPoint offset = [change redoVector];
    [graphic moveBy:offset];
}
@end

@implementation MovePointChangeDetail
- (void)recordIt
{
    if ( [change ptNum]<0 )
        ptNum = ([change moveAll]) ? 0 : [graphic selectedKnobIndex];
    else
        ptNum = [change ptNum];

    control = [(App*)NSApp control];
    oldPoint = [graphic pointWithNum:ptNum];
}
- (BOOL)useNestedDetails
{
    return NO;
}
- (void)undoIt
{
    newPoint = [graphic pointWithNum:ptNum];
    if ( [change moveAll] )
        [graphic moveTo:oldPoint];
    else
    {   if (control && [graphic isKindOfClass:[VArc class]])
            [(VArc*)graphic movePoint:ptNum to:oldPoint control:control];
        else if (control && [graphic isKindOfClass:[VPath class]])
            [(VPath*)graphic movePoint:ptNum to:oldPoint control:control];
        else if (control && [graphic isKindOfClass:[VGroup class]])
            [(VGroup*)graphic movePoint:ptNum to:oldPoint control:control];
        else
            [graphic movePoint:ptNum to:oldPoint];
    }

}
- (void)redoIt
{
    if ( [change moveAll] )
        [graphic moveTo:newPoint];
    else
    {   if (control && ([graphic isKindOfClass:[VArc class]]))
            [(VArc*)graphic movePoint:ptNum to:newPoint control:control];
        else if (control && [graphic isKindOfClass:[VPath class]])
            [(VPath*)graphic movePoint:ptNum to:newPoint control:control];
        else if (control && [graphic isKindOfClass:[VGroup class]])
            [(VGroup*)graphic movePoint:ptNum to:newPoint control:control];
        else
            [graphic movePoint:ptNum to:newPoint];
    }

}
@end

@implementation AddPointChangeDetail
- (void)recordIt
{   float	distance = MAXCOORD;

    newPoint = [change point];
    if ([graphic isKindOfClass:[VPath class]])	// notice the hole old graphic+index (we cant recreate)
    {
        newPoint = [(VPath*)graphic nearestPointOnObject:&oldIx distance:&distance toPoint:newPoint];
        oldGraphic = [[[(VPath*)graphic list] objectAtIndex:oldIx] copy];
    }
    else // VPolyLine
    {   newPoint = [(VPolyLine*)graphic nearestPointInPtlist:&pt_num distance:&distance toPoint:newPoint];
        pt_num += 1; // pt_num is from point befor newPoint !
    }
}
- (BOOL)useNestedDetails
{
    return NO;
}
- (void)undoIt
{
    if ([graphic isKindOfClass:[VPath class]])
    {
        /* remove the rwo new objects around newPoint */
        /* if point is in a polyLine - nothing to insert ! */
        if ([(VPath*)graphic removeGraphicsAroundPoint:newPoint andIndex:oldIx]) 
            /* insert oldGraphicAt index oldIx - point not in a polyLine */
            [[(VPath*)graphic list] insertObject:oldGraphic atIndex:oldIx];
            /* update path bounds ! hier nicht ganz so wichtig */
    }
    else // VPolyLine
    {
        [(VPolyLine*)graphic removePointWithNum:pt_num];
    }
}
- (void)redoIt
{
    /* VPolyLine and Vpath the same */
    [(VPolyLine*)graphic addPointAt:newPoint];   
}
@end

@implementation RemovePointChangeDetail
- (void)recordIt
{
    remPt_num = [graphic selectedKnobIndex];
    removedPt = [graphic pointWithNum:remPt_num];

    if ([graphic isKindOfClass:[VPath class]])	// notice the hole removed graphic+index (we cant recreate)
    {
        // needed: removedGr, removedIx, changedIx, chPt_num, changedPt
        if ((removedIx = [(VPath*)graphic changedValuesForRemovePointUndo:changedIx :chPt_num :changedPt]) >= 0)
        {
            removedGr = [[[(VPath*)graphic list] objectAtIndex:removedIx] retain];
        }
    }
}
- (BOOL)useNestedDetails
{
    return NO;
}
- (void)undoIt
{
    if ([graphic isKindOfClass:[VPath class]])
    {
        if (changedIx[0] == -1) // add only the removed Gr (openPath)
        {
            [[(VPath*)graphic list] insertObject:removedGr atIndex:removedIx];
            [(VPath*)graphic setBoundsZero]; // update path bounds ! - for correct Drawing !
        }
        else if (removedIx == -1) // VPolyLine inside Path
        {   /* changedIx is the PolyLine obj in path and chPt_num is the pt_num we removed */
            [(VPolyLine*)[[(VPath*)graphic list] objectAtIndex:changedIx[0]] addPoint:removedPt atNum:chPt_num[0]];
        }
        else if (removedIx == -2) // VPolyLine inside Path - start/end point was removed
        {   /* changedIx is the PolyLine obj in path and chPt_num is the pt_num at which we must add */
            [(VPolyLine*)[[(VPath*)graphic list] objectAtIndex:changedIx[0]] addPoint:changedPt[0] atNum:chPt_num[0]];
            [[[(VPath*)graphic list] objectAtIndex:changedIx[1]] movePoint:chPt_num[1] to:changedPt[1]];
            [(VPath*)graphic setBoundsZero]; // update path bounds ! - for correct Drawing !
        }
        else if (removedIx == -3) // VPolyLine inside Path - start/end point was removed
        {   /* changedIx is the PolyLine obj in path and chPt_num is the pt_num at which we must add */
            [(VPolyLine*)[[(VPath*)graphic list] objectAtIndex:changedIx[0]] addPoint:changedPt[0] atNum:chPt_num[0]];
        }
        else if (removedIx >= 0)/* insert removedGr and move point back */
        {
            [[(VPath*)graphic list] insertObject:removedGr atIndex:removedIx];
            [[[(VPath*)graphic list] objectAtIndex:changedIx[0]] movePoint:chPt_num[0] to:changedPt[0]];
            [(VPath*)graphic setBoundsZero]; // update path bounds ! - for correct Drawing !
        }
    }
    else // VPolyLine
    {
        [(VPolyLine*)graphic addPoint:removedPt atNum:remPt_num];
    }
}
- (void)redoIt
{
    if ([graphic isKindOfClass:[VPath class]] && removedIx == -4)
        return;
    [(VPolyLine*)graphic removePointWithNum:remPt_num];   
}
@end

@implementation RotateChangeDetail
- (BOOL)useNestedDetails
{
    return NO;
}
- (void)undoDetail
{
    if ( [change useGraphicOrigin] )
        [graphic setAngle:[change undoAngle] withCenter:[graphic pointWithNum:0]];
    else
        [graphic setAngle:[change undoAngle] withCenter:[(RotateGraphicsChange*)change center]];
}
- (void)redoDetail
{
    if ( [change useGraphicOrigin] )
        [graphic setAngle:[change redoAngle] withCenter:[graphic pointWithNum:0]];
    else
        [graphic setAngle:[change redoAngle] withCenter:[(RotateGraphicsChange*)change center]];
}
@end

@implementation MirrorChangeDetail
- (BOOL)useNestedDetails
{
    return NO;
}
- (void)undoDetail
{
    [graphic mirrorAround:[(MirrorGraphicsChange*)change center]];
}
- (void)redoDetail
{
    [graphic mirrorAround:[(MirrorGraphicsChange*)change center]];
}
@end

@implementation ScaleChangeDetail
- (BOOL)useNestedDetails
{
    return NO;
}
- (void)undoDetail
{
    [graphic scale:1.0/[change xScale] :1.0/[change yScale] withCenter:[(ScaleGraphicsChange*)change center]];
}
- (void)redoDetail
{
    [graphic scale:[change xScale] :[change yScale] withCenter:[(ScaleGraphicsChange*)change center]];
}
@end

@implementation AngleChangeDetail
- (BOOL)useNestedDetails
{
    return NO;
}
- (void)recordDetail
{
    switch ( [change angleNum] )
    {
        default: undoAngle = [(VArc*)graphic begAngle]; break;
        case 1:  undoAngle = [(VArc*)graphic angle]; break;
        case 2:  undoAngle = [(VPolyLine*)graphic graduateAngle];
    }
}
- (void)undoDetail
{
    switch ( [change angleNum] )
    {
        default: [(VArc*)graphic setBegAngle:undoAngle]; break;
        case 1:  [(VArc*)graphic setAngle:undoAngle]; break;
        case 2:  [(VPolyLine*)graphic setGraduateAngle:undoAngle];
    }
}
- (void)redoDetail
{
    switch ( [change angleNum] )
    {
        default: [(VArc*)graphic setBegAngle:[change redoAngle]]; break;
        case 1:  [(VArc*)graphic setAngle:[change redoAngle]]; break;
        case 2:  [(VPolyLine*)graphic setGraduateAngle:[change redoAngle]];
    }
}
@end

@implementation OrderChangeDetail
- (BOOL)useNestedDetails
{
    return NO;
}
- (void)recordGraphicPositionIn:(NSArray*)layList
{   int	l, cnt;

    for ( l=0, cnt=[layList count]; l<cnt; l++ )
    {   NSArray     *list = [[layList objectAtIndex:l] list];
        NSInteger   ix;

        if ( (ix = [list indexOfObject:graphic]) != NSNotFound )
        {   graphicPosition = ix;
            layer = l;
            break;
        }
    }
}
- (unsigned)graphicPosition
{
    return graphicPosition;
}
@end

@implementation StepWidthChangeDetail
- (void)recordIt
{
    oldStepWidth = [(VArc*)graphic stepWidth]; 
}
- (void)undoIt
{
    [(VArc*)graphic setStepWidth:oldStepWidth]; 
}
- (void)redoIt
{
    float stepWidth = [change stepWidth];
    [(VArc*)graphic setStepWidth:stepWidth]; 
}
- (BOOL)personalChangeExpected
{
    if (![graphic respondsToSelector:@selector(stepWidth)])
        return NO;
    return ([(VArc*)graphic stepWidth] != [change stepWidth]);
}
@end

@implementation RadialCenterChangeDetail
- (void)recordIt
{
    oldRadialCenter = [(VArc*)graphic radialCenter]; 
}
- (void)undoIt
{
    [(VArc*)graphic setRadialCenter:oldRadialCenter]; 
}
- (void)redoIt
{
    NSPoint rCenter = [(RadialCenterGraphicsChange*)change radialCenter];
    [(VArc*)graphic setRadialCenter:rCenter]; 
}
- (BOOL)personalChangeExpected
{   NSPoint	gRC = {0.5, 0.5};
    NSPoint	cRC = [(RadialCenterGraphicsChange*)change radialCenter];

    if (![graphic respondsToSelector:@selector(radialCenter)])
        return NO;
    gRC = [(VArc*)graphic radialCenter];
    return (gRC.x != cRC.x || gRC.y != cRC.y);
}
@end
