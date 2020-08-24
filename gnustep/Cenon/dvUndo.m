/* dvUndo.h
 * Undo additions for Cenon DocView class
 *
 * Copyright (C) 1999-2009 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1999-
 * modified: 2009-03-06 (-rotate: -deselectLockedLayers:..)
 *           2005-07-28 (-addPointTo: added)
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

#include <AppKit/AppKit.h>
#include "DocView.h"
#include "App.h"
#include "messages.h"
#include "graphicsUndo.subproj/undo.h"

@implementation DocView(Undo)

- (void)graphicsPerform:(SEL)aSelector with:(void *)argument
{   int		l, cnt, i;
    NSRect	affectedBounds = NSZeroRect;

    for ( l=0, cnt = [slayList count]; l<cnt; l++ )
    {	NSMutableArray  *slist = [slayList  objectAtIndex:l];
        LayerObject     *layer = [layerList objectAtIndex:l];

        if (![layer editable])
            continue;
        for (i=[slist count]-1; i>=0; i--)
        {   id	g = [slist objectAtIndex:i];

            if ( [g respondsToSelector:aSelector] )
            {
                affectedBounds = (affectedBounds.size.width)
                                   ? NSUnionRect([g extendedBoundsWithScale:scale], affectedBounds)
                                   : [g extendedBoundsWithScale:scale];
                [g performSelector:aSelector withObject:argument];
                [layer updateObject:g];
                affectedBounds = (affectedBounds.size.width)
                                   ? NSUnionRect([g extendedBoundsWithScale:scale], affectedBounds)
                                   : [g extendedBoundsWithScale:scale];
            }
        }
    }
    [self cache:affectedBounds];
}

/*- (void)graphicsPerform:(SEL)aSelector with:(void *)argument
{   int		l, cnt;

    for ( l=0, cnt = [slayList count]; l<cnt; l++ )
    {
        if (![[layerList objectAtIndex:l] editable])
            continue;
        [[slayList objectAtIndex:l] makeObjectsPerformSelector:@selector(moveBy_ptr:) withObject:argument];
    }
}*/

/*
 * Target/Action methods to change VGraphic parameters from a Control.
 * If the sender is a PopUpList, then the indexOfSelectedItem is used to
 * determine the value to use (for linecap, linearrow, etc.) otherwise, the
 * sender's floatValue or intValue is used (whichever is appropriate).
 * This allows interface builders the flexibility to design different
 * ways of setting those values.
 */
/*- (void)takeColorFrom:sender
{   id		change;
    NSColor	*color = [sender color];

    change = [[ColorGraphicsChange alloc] initGraphicView:self color:color];
    [change startChange];
	[self graphicsPerform:@selector(setColor:) with:color];
        [document setDirty:YES];
    [change endChange];
}*/
- (void)takeColorFrom:sender colorNum:(int)colorNum
{   id		change;
    NSColor	*color = [sender color];

    change = [[ColorGraphicsChange alloc] initGraphicView:self color:color colorNum:colorNum];
    [change startChange];
        switch (colorNum)
        {
            default: [self graphicsPerform:@selector(setColor:)     with:color]; break;
            case 1:  [self graphicsPerform:@selector(setFillColor:) with:color]; break;
            case 2:  [self graphicsPerform:@selector(setEndColor:)  with:color];
        }
        [document setDirty:YES];
    [change endChange];
}
/*
{   id		change;
    int		l, cnt, i;
    NSColor	*color = [sender color];
//    NSRect	affectedBounds = NSMakeRect(0, 0, 0, 0);

    change = [[ColorGraphicsChange alloc] initGraphicView:self color:color colorNum:colorNum];
    [change startChange];
        cnt = [slayList count];
        for (l=0; l<cnt; l++)
        {   NSMutableArray	*slist = [slayList objectAtIndex:l];
            LayerObject		*layer = [layerList objectAtIndex:l];

            if (![layer editable])
                continue;
            for (i=[slist count]-1; i>=0; i--)
            {   VGraphic	*g = [slist objectAtIndex:i];

//                affectedBounds = (affectedBounds.size.width) ? NSUnionRect([g extendedBoundsWithScale:scale], affectedBounds) : [g extendedBoundsWithScale:scale];
                if ( [g respondsToSelector:@selector(setColor:)] )
                {
                    switch (colorNum)
                    {
                        default: [g setColor:color]; break;
                        case 1:  [(VPolyLineg setFillColor:color];
                        case 2:  [g setEndColor:color];
                    }
                    [layer updateObject:g];
                }
//                affectedBounds = NSUnionRect([g extendedBoundsWithScale:scale], affectedBounds);
            }
        }
        [document setDirty:YES];
//        [self cache:affectedBounds];
    [change endChange];
}*/

/* sender is a NSPopupButton
 */
- (void)takeFillFrom:sender
{   id		change;
    int		l, cnt, i;
    NSRect	affectedBounds = NSZeroRect;
    int		filled = [sender indexOfSelectedItem];

    change = [[FillGraphicsChange alloc] initGraphicView:self fill:filled];
    [change startChange];
        //[self graphicsPerform:@selector(setFilled:) with:(void*)filled];
        //[document setDirty:YES];
        for (l=0, cnt = [slayList count]; l<cnt; l++)
        {   NSMutableArray	*slist = [slayList  objectAtIndex:l];
            LayerObject		*layer = [layerList objectAtIndex:l];

            if (![layer editable])
                continue;
            for (i=[slist count]-1; i>=0; i--)
            {   VGraphic    *g = [slist objectAtIndex:i];

                if ( [g respondsToSelector:@selector(setFilled:)] )
                {
                    affectedBounds = (affectedBounds.size.width)
                                        ? NSUnionRect([g extendedBoundsWithScale:scale], affectedBounds)
                                        : [g extendedBoundsWithScale:scale];
                    [g setFilled:filled];
                    [layer updateObject:g];
                    affectedBounds = NSUnionRect([g extendedBoundsWithScale:scale], affectedBounds);
                }
            }
        }
    [document setDirty:YES];
    [self cache:affectedBounds];
    [change endChange];
}

- (void)takeStepWidth:(float)stepWidth
{   id		change;
    int		l, cnt, i;
    NSRect	affectedBounds = NSZeroRect;

    change = [[StepWidthGraphicsChange alloc] initGraphicView:self stepWidth:stepWidth];
    [change startChange];
        cnt = [slayList count];
        for (l=0; l<cnt; l++)
        {   NSMutableArray	*slist = [slayList  objectAtIndex:l];
            LayerObject		*layer = [layerList objectAtIndex:l];

            if (![layer editable])
                continue;
            for (i=[slist count]-1; i>=0; i--)
            {   id	g = [slist objectAtIndex:i];

                affectedBounds = (affectedBounds.size.width) ? NSUnionRect([g extendedBoundsWithScale:scale], affectedBounds) : [g extendedBoundsWithScale:scale];
                if ( [g respondsToSelector:@selector(setStepWidth:)] )
                {
                    [g setStepWidth:stepWidth];
                    [layer updateObject:g];
                }
                affectedBounds = NSUnionRect([g extendedBoundsWithScale:scale], affectedBounds);
            }
        }
        [document setDirty:YES];
        [self cache:affectedBounds];
    [change endChange];
}

- (void)takeRadialCenter:(NSPoint)radialCenter
{   id		change;
    int		l, cnt, i;
    NSRect	affectedBounds = NSMakeRect(0, 0, 0, 0);

    change = [[RadialCenterGraphicsChange alloc] initGraphicView:self radialCenter:radialCenter];
    [change startChange];
        cnt = [slayList count];
        for (l=0; l<cnt; l++)
        {   NSMutableArray	*slist = [slayList objectAtIndex:l];
            LayerObject		*layer = [layerList objectAtIndex:l];

            if (![layer editable])
                continue;
            for (i=[slist count]-1; i>=0; i--)
            {   id	g = [slist objectAtIndex:i];

                affectedBounds = (affectedBounds.size.width) ? NSUnionRect([g extendedBoundsWithScale:scale], affectedBounds) : [g extendedBoundsWithScale:scale];
                if ( [g respondsToSelector:@selector(setRadialCenter:)] )
                {
                    [g setRadialCenter:radialCenter];
                    [layer updateObject:g];
                }
                affectedBounds = NSUnionRect([g extendedBoundsWithScale:scale], affectedBounds);
            }
        }
        [document setDirty:YES];
        [self cache:affectedBounds];
    [change endChange];
}

- (void)takeWidth:(float)width
{   id		change;
    int		l, cnt, i;
    NSRect	affectedBounds = NSMakeRect(0, 0, 0, 0);

    change = [[WidthGraphicsChange alloc] initGraphicView:self lineWidth:width];
    [change startChange];
        //[self graphicsPerform:@selector(setWidth_ptr:) with:&width];
        cnt = [slayList count];
        for (l=0; l<cnt; l++)
        {   NSMutableArray	*slist = [slayList  objectAtIndex:l];
            LayerObject		*layer = [layerList objectAtIndex:l];

            if (![layer editable])
                continue;
            for (i=[slist count]-1; i>=0; i--)
            {   VGraphic    *g = [slist objectAtIndex:i];

                affectedBounds = (affectedBounds.size.width) ? NSUnionRect([g extendedBoundsWithScale:scale], affectedBounds) : [g extendedBoundsWithScale:scale];
                if ( [g respondsToSelector:@selector(setWidth:)] )
                {
                    [g setWidth:width];
                    [layer updateObject:g];
                }
                affectedBounds = NSUnionRect([g extendedBoundsWithScale:scale], affectedBounds);
            }
        }
        [document setDirty:YES];
        [self cache:affectedBounds];
    [change endChange];
}

- (void)takeLength:(float)length
{   id		change;
    int		l, cnt, i;
    NSRect	affectedBounds = NSMakeRect(0, 0, 0, 0);

    change = [[LengthGraphicsChange alloc] initGraphicView:self length:length];
    [change startChange];
        cnt = [slayList count];
        for (l=0; l<cnt; l++)
        {   NSMutableArray	*slist = [slayList objectAtIndex:l];
            LayerObject		*layer = [layerList objectAtIndex:l];

            if (![layer editable])
                continue;
            for (i=[slist count]-1; i>=0; i--)
            {   VGraphic	*g = [slist objectAtIndex:i];

                affectedBounds = (affectedBounds.size.width) ? NSUnionRect([g extendedBoundsWithScale:scale], affectedBounds) : [g extendedBoundsWithScale:scale];
                if ( [g respondsToSelector:@selector(setLength:)] )
                {
                    [g setLength:length];
                    [layer updateObject:g];
                }
                affectedBounds = NSUnionRect([g extendedBoundsWithScale:scale], affectedBounds);
            }
        }
        [document setDirty:YES];
        [self cache:affectedBounds];
    [change endChange];
}

- (void)takeWidth:(float)width height:(float)height
{   id		change;
    int		l, cnt, i;
    NSRect	affectedBounds = NSMakeRect(0, 0, 0, 0);

    change = [[DimensionsGraphicsChange alloc] initGraphicView:self];
    [change startChange];
        cnt = [slayList count];
        for (l=0; l<cnt; l++)
        {   NSMutableArray	*slist = [slayList objectAtIndex:l];
            LayerObject		*layer = [layerList objectAtIndex:l];

            if (![layer editable])
                continue;
            for (i=[slist count]-1; i>=0; i--)
            {   id	g = [slist objectAtIndex:i];

                affectedBounds = (affectedBounds.size.width) ? NSUnionRect([g extendedBoundsWithScale:scale], affectedBounds) : [g extendedBoundsWithScale:scale];
                if ( [g respondsToSelector:@selector(setSize:)] )
                {   NSSize	s = [g size];

                    if ( height )
                        s.height = height;
                    if ( width )
                        s.width = width;
                    [g setSize:s];
                    [layer updateObject:g];
                }
                affectedBounds = NSUnionRect([g extendedBoundsWithScale:scale], affectedBounds);
            }
        }
        [document setDirty:YES];
        [self cache:affectedBounds];
    [change endChange];
}

- (void)takeRadius:(float)radius
{   id		change;
    int		l, cnt, i;
    NSRect	affectedBounds = NSMakeRect(0, 0, 0, 0);

    change = [[RadiusGraphicsChange alloc] initGraphicView:self];
    [change startChange];
        cnt = [slayList count];
        for (l=0; l<cnt; l++)
        {   NSMutableArray	*slist = [slayList objectAtIndex:l];
            LayerObject		*layer = [layerList objectAtIndex:l];

            if (![layer editable])
                continue;
            for (i=[slist count]-1; i>=0; i--)
            {   id	g = [slist objectAtIndex:i];

                affectedBounds = (affectedBounds.size.width) ? NSUnionRect([g extendedBoundsWithScale:scale], affectedBounds) : [g extendedBoundsWithScale:scale];
                if ( [g respondsToSelector:@selector(setRadius:)] )
                {
                    [g setRadius:radius];
                    [layer updateObject:g];
                }
                affectedBounds = NSUnionRect([g extendedBoundsWithScale:scale], affectedBounds);
            }
        }
        [document setDirty:YES];
        [self cache:affectedBounds];
    [change endChange];
}

- (void)takeAngle:(float)angle angleNum:(int)angleNum
{   id		change;
    int		l, cnt, i;
    NSRect	affectedBounds = NSMakeRect(0, 0, 0, 0);

    change = [[AngleGraphicsChange alloc] initGraphicView:self angle:angle angleNum:angleNum];
    [change startChange];
        cnt = [slayList count];
        for (l=0; l<cnt; l++)
        {   NSMutableArray	*slist = [slayList objectAtIndex:l];
            LayerObject		*layer = [layerList objectAtIndex:l];

            if (![layer editable])
                continue;
            for (i=[slist count]-1; i>=0; i--)
            {   VArc	*g = [slist objectAtIndex:i];

                affectedBounds = (affectedBounds.size.width) ? NSUnionRect([g extendedBoundsWithScale:scale], affectedBounds) : [g extendedBoundsWithScale:scale];
                if ( [g respondsToSelector:@selector(setRadius:)] )
                {
                    switch ( angleNum)
                    {
                        default: [g setBegAngle:angle]; break;
                        case 1:  [g setAngle:angle]; break;
                        case 2:  [(VPolyLine*)g setGraduateAngle:angle];
                    }
                    [layer updateObject:g];
                }
                affectedBounds = NSUnionRect([g extendedBoundsWithScale:scale], affectedBounds);
            }
        }
        [document setDirty:YES];
        [self cache:affectedBounds];
    [change endChange];
}

- (void)moveGraphicsBy:(NSPoint)vector andDraw:(BOOL)drawFlag
{   id	change;

    change = [[MoveGraphicsChange alloc] initGraphicView:self vector:vector];
    [change startChange];
	if (drawFlag)
	    [self graphicsPerform:@selector(moveBy_ptr:) with:(id)&vector];
        else
        {   int	l, cnt, i, iCnt;

            for ( l=0, cnt = [slayList count]; l<cnt; l++ )
            {   LayerObject	*layer = [layerList objectAtIndex:l];
                NSArray		*slist = [slayList objectAtIndex:l];

                if (![layer editable])
                    continue;
                [slist makeObjectsPerformSelector:@selector(moveBy_ptr:) withObject:(id)&vector];
                for (i=0, iCnt = [slist count]; i<iCnt; i++)
                    [layer updateObject:[slist objectAtIndex:i]];
            }
        }
    [change endChange];
}

/* move point or all points absolute
 * moveAll: move entire object
 */
- (void)movePointTo:(NSPoint)pt x:(BOOL)x y:(BOOL)y all:(BOOL)moveAll
{
    [self movePoint:-1 to:pt x:x y:y all:moveAll];
}
/* move point or all points absolute
 * ptNum:   point number or -1 to move selected point
 * moveAll: move entire object
 */
- (void)movePoint:(int)ptNum to:(NSPoint)pt x:(BOOL)x y:(BOOL)y all:(BOOL)moveAll
{   id		change;
    int		l, cnt, i;
    NSRect	affectedBounds = NSMakeRect(0, 0, 0, 0);

    change = [[MovePointGraphicsChange alloc] initGraphicView:self ptNum:ptNum moveAll:moveAll];
    [change startChange];
        cnt = [slayList count];
        for (l=0; l<cnt; l++)
        {   NSMutableArray	*slist = [slayList objectAtIndex:l];
            LayerObject		*layer = [layerList objectAtIndex:l];

            if ( ![layer editable] )
                continue;
            for ( i=[slist count]-1; i>=0; i-- )
            {   id	g = [slist objectAtIndex:i];

                affectedBounds = (affectedBounds.size.width) ? NSUnionRect([g extendedBoundsWithScale:scale], affectedBounds) : [g extendedBoundsWithScale:scale];
                if ( [g respondsToSelector:@selector(movePoint:to:)] )
                {   int		n = (ptNum<0) ? ((moveAll) ? 0 : [g selectedKnobIndex]) : ptNum;
                    NSPoint	p = [g pointWithNum:n];

                    if ( x )
                        p.x = pt.x;
                    if ( y )
                        p.y = pt.y;
                    if ( moveAll )
                        [g moveTo:p];
                    else
                        [g movePoint:n to:p];
                    [layer updateObject:g];
                }
                affectedBounds = NSUnionRect([g extendedBoundsWithScale:scale], affectedBounds);
            }
            [document setDirty:YES];
        }
        [self cache:affectedBounds];
    [change endChange];
}

- (void)rotate:(float)rotAngle
{   int		i, l;
    NSRect	rect, drawRect;
    NSPoint	rotCenter;
    id		change;

    drawRect = [self boundsOfArray:slayList];
    [self deselectLockedLayers:YES lockedObjects:YES];

    rect = [self boundsOfArray:slayList withKnobs:NO];
    rotCenter.x = rect.origin.x + rect.size.width  / 2.0;
    rotCenter.y = rect.origin.y + rect.size.height / 2.0;

    change = [[RotateGraphicsChange alloc] initGraphicView:self angle:-rotAngle center:rotCenter];
    [change startChange];
        for (l=[slayList count]-1; l>=0; l--)
        {   NSMutableArray	*slist = [slayList objectAtIndex:l];
            LayerObject		*layer = [layerList objectAtIndex:l];

            if ( ![layer editable] )
                continue;
            for (i=[slist count]-1; i>=0; i--)
            {   VGraphic	*g = [slist objectAtIndex:i];

                [g setAngle:-rotAngle withCenter:rotCenter];
                [layer updateObject:g];
            }
        }

        rect = [self boundsOfArray:slayList];
        drawRect = NSUnionRect(rect, drawRect);
        [self cache:drawRect];
        [document setDirty:YES];
        [[(App*)NSApp inspectorPanel] loadList:slayList];
    [change endChange];
}

/* split object at point
 * created:  2002-11-27
 * modified: 
 *
 * get objects splitted at point
 * save changes for undo
 * add objects to current layer
 * remove old object from layer
 * redraw affected area (selection only)
 */
- (void)splitObject:(VGraphic*)g atPoint:(NSPoint)p redraw:(BOOL)redraw
{   id			change;
    int			l, cnt = [slayList count];
    NSRect		affectedBounds = [g extendedBoundsWithScale:scale]; // object bounds
    NSMutableArray	*nglist=nil;
    BOOL		gIsFilled = [g filled];

    change = [[ContourGraphicsChange alloc] initGraphicView:self];
    [change startChange];

        for (l=0; l<cnt; l++)
        {   NSMutableArray	*slist = [slayList objectAtIndex:l];
            LayerObject		*layer = [layerList objectAtIndex:l];

            if (![layer editable])
                continue;
            if ([[layer list] indexOfObject:g] != NSNotFound) // object in this layer
            {
                if ((nglist=[g getListOfObjectsSplittedAtPoint:p]))
                {   int i, ngCnt = [nglist count];

                    /* remove old object from list */
                    [slist removeObject:g];
                    [layer removeObject:g];
                    /* insert new objects in list */
                    for (i=0; i<ngCnt; i++)
                    {   id	ng = [nglist objectAtIndex:i];

                        [ng setSelected:YES];
                        [layer addObject:ng];
                        [slist addObject:ng];
                    }
                    break;
                }
            }
        }
        [document setDirty:YES];
        // NSLog(@"-mouseDown: hit object '%@' with knife tool", NSStringFromClass([g class]));
    [change endChange];
    if (gIsFilled)
        [self cache:affectedBounds];
    else
        [self drawRect:affectedBounds];
}

/* add an Point to object at point for VPath and VPolyLine
 * created:  2005-06-26
 * modified: 2005-07-28
 *
 * get objects splitted at point
 * save changes for undo
 * add objects to current layer
 * remove old object from layer
 * redraw affected area (selection only)
 */
- (void)addPointTo:(VGraphic*)g atPoint:(NSPoint)p redraw:(BOOL)redraw
{   id			change;
    int			l, cnt = [slayList count];
    NSRect		affectedBounds = [g extendedBoundsWithScale:scale]; // object bounds
    //VGraphic		*ng = nil;
    BOOL		gIsFilled = [g filled];

    change = [[AddPointGraphicsChange alloc] initGraphicView:self point:p];
    [change startChange];

        for (l=0; l<cnt; l++)
        {   //NSMutableArray	*slist = [slayList objectAtIndex:l];
            LayerObject		*layer = [layerList objectAtIndex:l];

            if (![layer editable])
                continue;
            if ([[layer list] indexOfObject:g] != NSNotFound) // object in this layer
            {
                if ([(VPath*)g addPointAt:p])
                {
                    break;
                }
            }
        }
        [document setDirty:YES];
        // NSLog(@"-mouseDown: hit object '%@' with knife tool", NSStringFromClass([g class]));
    [change endChange];
    if (gIsFilled)
        [self cache:affectedBounds];
    else
        [self drawRect:affectedBounds];
}

@end
