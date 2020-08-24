/* VGroup.m
 * Group of graphic objects
 *
 * Copyright (C) 1996-2012 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1996-01-29
 * modified: 2012-08-12 (-setSize: use coordBounds for correct scaling)
 *           2012-07-17 (*pts=NULL, *iPts=NULL initialized)
 *           2012-04-20 (-coordBounds zero size Bounds are not recognized)
 *           2010-07-08 (relocated -setList:)
 *
 * the group is implemented as follows:
 * - all objects are stored in a list with absolute coordinates
 * - if the group is selected then all objects within are selected
 * - if the group is handled when Alternate is pressed then the objects inside are handled
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
#include "../App.h"
#include "../DocView.h"
#include "VGraphic.h"
#include "VGroup.h"
#include "HiddenArea.h"

@implementation VGroup

/* This sets the class version so that we can compatibly read old objects out of an archive.
 */
+ (void)initialize
{
    [VGroup setVersion:2];
    return;
}

+ (VGroup*)group
{
    return [[[VGroup allocWithZone:[self zone]] init] autorelease];
}

/* modified: 18.10.96
 */
- init
{
    [super init];
    selectedObject = -1;
    coordBounds = bounds = NSZeroRect;
    list = [[NSMutableArray allocWithZone:[self zone]] init];
    uniColoring = NO;
    filled = NO;
    fillColor = [[NSColor blackColor] retain];
    endColor = [[NSColor blackColor] retain];
    graduateAngle = 0.0;
    stepWidth = 7.0;
    radialCenter = NSMakePoint(0.5, 0.5);
    return self;
}

/* init from file
 *
 * created:  02.03.97
 * modified: 23.03.97
 */
- initWithList:(NSArray*)aList
{
    [super init];
    selectedObject = -1;
    [self setList:[[aList mutableCopy] autorelease]];
    [self setColorNew];
    return self;
}

/* init from file
 *
 * created:  02.03.97
 * modified: 23.03.97
 */
- initWithFile:(NSString*)fileName
{
    [super init];
    selectedObject = -1;
    [self setList:[Document listFromFile:fileName]];
    return self;
}

/* deep copy
 *
 * created:  2001-02-15
 * modified: 
 */
- copy
{   id		group;
    int		i, cnt = [list count];

    group = [[VGroup allocWithZone:[self zone]] init];
    [group setSelected:isSelected];
    [group setLocked:isLocked];
/*    [group setFilled:filled optimize:NO];
    [group setWidth:width];
    [group setColor:color];
    [group setFillColor:fillColor];
    [group setEndColor:endColor];
    [group setGraduateAngle:graduateAngle];
    [group setStepWidth:stepWidth];
    [group setRadialCenter:radialCenter];*/
    for (i=0; i<cnt; i++)
        [[group list] addObject:[[[list objectAtIndex:i] copy] autorelease]];
    return group;
}

- (NSString*)title		{ return @"Group"; }

- (NSMutableArray*)list
{
    return list;
}
- (void)setList:(NSMutableArray*)aList
{
    [list release];
    list = [aList retain];
    [self setColorNew];
    coordBounds = bounds = NSZeroRect;
    dirty = YES;
}

- (unsigned)countRecursive
{   int	i, cnt = 0;

    for (i=[list count]-1; i>=0; i--)
    {	id	g = [list objectAtIndex:i];

        if ( [g isKindOfClass:[VGroup class]] ) // || [g isKindOfClass:[VPath class]] 
            cnt += [g countRecursive];
        else
            cnt++;
    }
    return cnt;
}
/* created 2005-08-19
 */
- (id)recursiveObjectAtIndex:(int)ix
{   int	i, cnt = [list count], cCnt = 0;

    for (i=0; i < cnt; i++)
    {	id	g = [list objectAtIndex:i];

        if ([g isKindOfClass:[VGroup class]])
        { int	gCnt = [g countRecursive];

            if (ix >= cCnt && ix < cCnt+gCnt) // obj is inside g
                return [g recursiveObjectAtIndex:(ix-cCnt)];
            cCnt += [g countRecursive];
        }
        else if (cCnt == ix)
            return g;
        else
            cCnt++;
    }
    return nil;
}
- (void)recursiveRemoveObjectAtIndex:(int)ix
{   int	i, cnt = [list count], cCnt = 0;

    for (i=0; i < cnt; i++)
    {	id	g = [list objectAtIndex:i];

        if ([g isKindOfClass:[VGroup class]])
        {   int	gCnt = [g countRecursive];

            if (ix >= cCnt && ix < cCnt+gCnt) // obj is inside g
            {   [g recursiveRemoveObjectAtIndex:(ix-cCnt)];
                return;
            }
            cCnt += [g countRecursive];
        }
        else if (cCnt == ix)
        {   [list removeObjectAtIndex:i];
            return;
        }
        else
            cCnt++;
    }
}
- (void)recursiveInsertObject:(id)obj atIndex:(int)ix
{   int	i, cnt = [list count], cCnt = 0;

    if (ix >= [self countRecursive])
    {
        if ([[list objectAtIndex:cnt-1] isKindOfClass:[VGroup class]]) // last obj is a group
            [[[list objectAtIndex:cnt-1] list] addObject:obj];
        else
            [list addObject:obj];
    }

    for (i=0; i < cnt; i++)
    {	id	g = [list objectAtIndex:i];

        if ([g isKindOfClass:[VGroup class]])
        {   int	gCnt = [g countRecursive];

            if (ix >= cCnt && ix < cCnt+gCnt) // obj is inside g
            {   [g recursiveInsertObject:obj atIndex:(ix-cCnt)];
                return;
            }
            cCnt += [g countRecursive];
        }
        else if (cCnt == ix)
        {   [list insertObject:obj atIndex:i];
            return;
        }
        else
            cCnt++;
    }
}

/* created:  1995-09-24
 * modified: 
 */
- (void)deselectAll
{   int	i;

    for (i=[list count]-1; i>=0; i--)
        [[list objectAtIndex:i] setSelected:NO];
}

- (BOOL)uniColored;
{
    return uniColoring;
}
- (void)setUniColoringNew
{   int		i, cnt, fild0=0, fild1=0;
    VGraphic	*gr0, *gr1;
    NSColor	*col0, *fcol0 = nil, *ecol0 = nil, *col1 = nil, *fcol1 = nil, *ecol1 = nil;
    float	w0=0, ga0=0, w1=0, ga1=0;
    NSPoint	rc0={0.5,0.5}, rc1={0.5,0.5};

    uniColoring = NO;
    if (![list count])
        return;
    gr0 = [list objectAtIndex:0];
    if ( [gr0 isKindOfClass:[VGroup class]] && [(VGroup*)gr0 uniColored] == NO )
        return;

    col0 = [gr0 color]; // set color
    w0 = [gr0 width];
    if ( [gr0 respondsToSelector:@selector(fillColor)] )
    {
        fild0 = [(VPath*)gr0 filled];
        fcol0 = [(VPath*)gr0 fillColor];
        ecol0 = [(VPath*)gr0 endColor];
        ga0 = [(VPath*)gr0 graduateAngle];
        rc0 = [(VPath*)gr0 radialCenter];
    }
    for (i=1, cnt=[list count]; i<cnt; i++)
    {
        gr1 = [list objectAtIndex:i];
        if ( [gr1 isKindOfClass:[VGroup class]] && [(VGroup*)gr1 uniColored] == NO ) // gr1 group
            return;
        col1 = [gr1 color];
        w1 = [gr1 width];
        if ( [gr1 respondsToSelector:@selector(fillColor)] )
        {
            fild1 = [(VPath*)gr1 filled];
            fcol1 = [(VPath*)gr1 fillColor];
            ecol1 = [(VPath*)gr1 endColor];
            ga1 = [(VPath*)gr1 graduateAngle];
            rc1 = [(VPath*)gr1 radialCenter];
        }
        if (!(((((w0 && w0 == w1) || (!w0 && !w1 && !fild0 && !fild1)) && [col0 isEqual:col1]) ||
               (!w0 && !w1 && fild0 && fild0 == fild1)) &&
              ((fild0 >= 1 && fild0 == fild1 && [fcol0 isEqual:fcol1]) || (!fild0 && !fild1)) && // fillColors
              ((fild0 > 1 && fild0 == fild1 && [ecol0 isEqual:ecol1]) || (fild0 <= 1 && fild0 == fild1)) && // ecols
              (((fild0 == 2 || fild0 == 4) && fild0 == fild1 && Diff(ga0, ga1) < TOLERANCE) ||
               ((fild0 <= 1 || fild0 == 3) && fild0 == fild1)) && // ga
              (((fild0 == 3 || fild0 == 4) && fild0 == fild1 && Diff(rc0.x, rc1.x)<TOLERANCE &&
                Diff(rc0.y, rc1.y)<TOLERANCE) || ((fild0 <= 1 || fild0 == 2) && fild0 == fild1))) )
            return;
    }
    uniColoring = YES;
}

- (void)setColorNew
{   int		i, cnt, fild0 = 0, fild1 = 0;
    VGraphic	*gr0, *gr1;
    NSColor	*col0, *fcol0 = nil, *ecol0 = nil, *col1, *fcol1 = nil, *ecol1 = nil;
    float	w0 = 0, ga0 = 0, w1 = 0, ga1 = 0;
    NSPoint	rc0 = {0.5,0.5}, rc1 = {0.5,0.5};

    /* init color */
    uniColoring = NO;
    [super setColor:[NSColor blackColor]];
    width = 0.0;
    filled = NO;
    fillColor = [[NSColor blackColor] retain];
    endColor  = [[NSColor blackColor] retain];
    graduateAngle = 0.0;
    stepWidth = 7.0;
    radialCenter = NSMakePoint(0.5, 0.5);

    if (![list count])	// empty group
        return;
    gr0 = [list objectAtIndex:0];
    if ( [gr0 isKindOfClass:[VGroup class]] && [(VGroup*)gr0 uniColored] == NO )
        return;

    col0 = [gr0 color]; // set color
    w0 = [gr0 width];
    if ( [gr0 respondsToSelector:@selector(fillColor)] )
    {
        fild0 = [(VPath*)gr0 filled];
        fcol0 = [(VPath*)gr0 fillColor];
        ecol0 = [(VPath*)gr0 endColor];
        ga0 = [(VPath*)gr0 graduateAngle];
        rc0 = [(VPath*)gr0 radialCenter];
    }
    for (i=1, cnt=[list count]; i<cnt; i++)
    {
        gr1 = [list objectAtIndex:i];
        if ( [gr1 isKindOfClass:[VGroup class]] && [(VGroup*)gr1 uniColored] == NO ) // gr1 group
            return;
        col1 = [gr1 color];
        w1 = [gr1 width];
        if ( [gr1 respondsToSelector:@selector(fillColor)] )
        {
            fild1 = [(VPath*)gr1 filled];
            fcol1 = [(VPath*)gr1 fillColor];
            ecol1 = [(VPath*)gr1 endColor];
            ga1 = [(VPath*)gr1 graduateAngle];
            rc1 = [(VPath*)gr1 radialCenter];
        }
        if (!(((((w0 && w0 == w1) || (!w0 && !w1 && !fild0 && !fild1)) && [col0 isEqual:col1]) ||
               (!w0 && !w1 && fild0 && fild0 == fild1)) &&
              ((fild0 >= 1 && fild0 == fild1 && [fcol0 isEqual:fcol1]) || (!fild0 && !fild1)) && // fillColors
              ((fild0 > 1 && fild0 == fild1 && [ecol0 isEqual:ecol1]) || (fild0 <= 1 && fild0 == fild1)) && // ecols
              (((fild0 == 2 || fild0 == 4) && fild0 == fild1 && Diff(ga0, ga1) < TOLERANCE) ||
               ((fild0 <= 1 || fild0 == 3) && fild0 == fild1)) && // ga
              (((fild0 == 3 || fild0 == 4) && fild0 == fild1 && Diff(rc0.x, rc1.x)<TOLERANCE &&
                Diff(rc0.y, rc1.y)<TOLERANCE) || ((fild0 <= 1 || fild0 == 2) && fild0 == fild1))) )
            return;
    }
    uniColoring = YES;
    /* set colors */
    [super setColor:col0];
    width = w0;
    if ( [gr0 respondsToSelector:@selector(fillColor)] )
    {
        filled = fild0;
        if (fillColor) [fillColor release];
        fillColor = [fcol0 retain];
        if (endColor) [endColor release];
        endColor = [ecol0 retain];
        graduateAngle = ga0;
        stepWidth = [(VPath*)gr0 stepWidth];
        radialCenter = rc0;
    }
}

- (void)setColor:(NSColor *)col
{   int	i, cnt = [list count];

    for ( i=0; i<cnt; i++)
        [[list objectAtIndex:i] setColor:col];
    [super setColor:col];
    [self setUniColoringNew];

}

- (void)setWidth:(float)w
{   int	i, cnt;

    for (i=0, cnt = [list count]; i<cnt; i++)
        [(VGraphic*)[list objectAtIndex:i] setWidth:w];

    width = w;
    [self setUniColoringNew];
    dirty = YES;
}

- (BOOL)filled
{
    return filled;
}

- (void)setFilled:(BOOL)flag
{   int	i, cnt;

    for (i=0, cnt = [list count]; i<cnt; i++)
    {   VGraphic	*g = [list objectAtIndex:i];

        if ( [g respondsToSelector:@selector(setFilled:)] )
            [(VPath*)g setFilled:flag];
    }
    filled = flag;
    [self setUniColoringNew];
    dirty = YES;
}

- (void)setFillColor:(NSColor*)col
{   int	i, cnt;

    for (i=0, cnt = [list count]; i<cnt; i++)
    {   VGraphic	*g = [list objectAtIndex:i];

        if ( [g respondsToSelector:@selector(setFillColor:)] )
            [(VPath*)g setFillColor:col];
    }
    if (fillColor) [fillColor release];
    fillColor = [col retain];
    [self setUniColoringNew];
    dirty = YES;
}
- (NSColor*)fillColor			{ return fillColor; }

- (void)setEndColor:(NSColor*)col
{   int	i, cnt;

    for (i=0, cnt = [list count]; i<cnt; i++)
    {   VGraphic	*g = [list objectAtIndex:i];

        if ( [g respondsToSelector:@selector(setEndColor:)] )
            [(VPath*)g setEndColor:col];
    }
    if (endColor) [endColor release];
    endColor = [col retain];
    [self setUniColoringNew];
    dirty = YES;
}
- (NSColor*)endColor 			{ return endColor; }

- (void)setGraduateAngle:(float)a
{   int	i, cnt;

    for (i=0, cnt = [list count]; i<cnt; i++)
    {   VGraphic	*g = [list objectAtIndex:i];

        if ( [g respondsToSelector:@selector(setGraduateAngle:)] )
            [(VPath*)g setGraduateAngle:a];
    }
    graduateAngle = a;
    [self setUniColoringNew];
    dirty = YES;
}
- (float)graduateAngle			{ return graduateAngle; }

- (void)setStepWidth:(float)sw
{   int	i, cnt;

    for (i=0, cnt = [list count]; i<cnt; i++)
    {   VGraphic	*g = [list objectAtIndex:i];

        if ( [g respondsToSelector:@selector(setStepWidth:)] )
            [(VPath*)g setStepWidth:sw];
    }
    stepWidth = sw;
    dirty = YES;
}
- (float)stepWidth			{ return stepWidth; }

- (void)setRadialCenter:(NSPoint)rc
{   int	i, cnt;

    for (i=0, cnt = [list count]; i<cnt; i++)
    {   VGraphic	*g = [list objectAtIndex:i];

        if ( [g respondsToSelector:@selector(setRadialCenter:)] )
            [(VPath*)g setRadialCenter:rc];
    }
    radialCenter = rc;
    [self setUniColoringNew];
    dirty = YES;
}
- (NSPoint)radialCenter			{ return radialCenter; }

- (int)selectedKnobIndex
{
    if ( ![list count] || selectedObject < 0)
        return -1;

    {   int	i, cnt, pCnt = 0, prevPCnt = 0;

        for (i=0, cnt = [list count]; i<cnt; i++)
        {   pCnt += [[list objectAtIndex:i] numPoints];
            if ( i == selectedObject )
                break;		// this object is our selected object
            prevPCnt = pCnt;	// count of pts befor this gr
        }
        return prevPCnt + [[list objectAtIndex:i] selectedKnobIndex];
    }
    return -1;
}

/*
 * set selection
 */
- (void)setSelected:(BOOL)flag
{
    if (!flag)
    {
        if (selectedObject >= 0)
            [[list objectAtIndex:selectedObject] setSelected:NO];
        selectedObject = -1;
    }
    [super setSelected:flag];
}

- (void)addObject:(VGraphic*)g
{
    [list addObject:g];
    [g setSelected:NO];
    coordBounds = bounds = NSZeroRect;

    /* check and set the colors */
    if ( ([list count] > 1 && uniColoring == NO) ||
         ([g isKindOfClass:[VGroup class]] && [(VGroup*)g uniColored] == NO) )
    {
        if (uniColoring == YES )
        {   /* init color */
            uniColoring = NO;
            [super setColor:[NSColor blackColor]];
            width = 0.0;
            filled = NO;
            fillColor = [[NSColor blackColor] retain];
            endColor = [[NSColor blackColor] retain];
            graduateAngle = 0.0;
            stepWidth = 7.0;
            radialCenter = NSMakePoint(0.5, 0.5);
        }
        return; // we have different colors
    }
    if ( [list count] == 1 )
    {
        uniColoring = YES;
        /* set colors */
        [super setColor:[g color]];
        width = [g width];
        if ( [g respondsToSelector:@selector(fillColor)] )
        {
            filled = [(VPath*)g filled];
            if (fillColor) [fillColor release];
            fillColor = [[(VPath*)g fillColor] retain];
            if (endColor) [endColor release];
            endColor = [[(VPath*)g endColor] retain];
            graduateAngle = [(VPath*)g graduateAngle];
            stepWidth = [(VPath*)g stepWidth];
            radialCenter = [(VPath*)g radialCenter];
        }
    }
    else // uniColoring == YES compare g colors with our
    {   int         fild0 = 0, fild1 = 0;
        NSColor		*col0, *fcol0 = nil, *ecol0 = nil, *col1, *fcol1 = nil, *ecol1 = nil;
        float		w0 = 0, ga0 = 0, w1 = 0, ga1 = 0;
        NSPoint		rc0 = {0.5,0.5}, rc1 = {0.5,0.5};

        col0 = color;
        w0 = width;
        fild0 = filled;
        fcol0 = fillColor;
        ecol0 = endColor;
        ga0 = graduateAngle;
        rc0 = radialCenter;

        col1 = [g color];
        w1 = [g width];
        if ( [g respondsToSelector:@selector(fillColor)] )
        {
            fild1 = [(VPath*)g filled];
            fcol1 = [(VPath*)g fillColor];
            ecol1 = [(VPath*)g endColor];
            ga1 = [(VPath*)g graduateAngle];
            rc1 = [(VPath*)g radialCenter];
        }
        if (!(((((w0 && w0 == w1) || (!w0 && !w1 && !fild0 && !fild1)) && [col0 isEqual:col1]) ||
               (!w0 && !w1 && fild0 && fild0 == fild1)) &&
              ((fild0 >= 1 && fild0 == fild1 && [fcol0 isEqual:fcol1]) || (!fild0 && !fild1)) && // fillColors
              ((fild0 > 1 && fild0 == fild1 && [ecol0 isEqual:ecol1]) || (fild0 <= 1 && fild0 == fild1)) && // ecols
              (((fild0 == 2 || fild0 == 4) && fild0 == fild1 && Diff(ga0, ga1) < TOLERANCE) ||
               ((fild0 <= 1 || fild0 == 3) && fild0 == fild1)) && // ga
              (((fild0 == 3 || fild0 == 4) && fild0 == fild1 && Diff(rc0.x, rc1.x)<TOLERANCE &&
                Diff(rc0.y, rc1.y)<TOLERANCE) || ((fild0 <= 1 || fild0 == 2) && fild0 == fild1))) )
        {   /* init color */
            uniColoring = NO;
            [super setColor:[NSColor blackColor]];
            width = 0.0;
            filled = NO;
            fillColor = [[NSColor blackColor] retain];
            endColor = [[NSColor blackColor] retain];
            graduateAngle = 0.0;
            stepWidth = 7.0;
            radialCenter = NSMakePoint(0.5, 0.5);
        }
    }
}

/*
 * add a list to our list
 * after the operation we are selected, all of our objects are deselected
 */
- (void)add:(NSArray*)addList
{   int	i, cnt;

    if (!list)
        list = [[NSMutableArray allocWithZone:[self zone]] init];
    for (i=0, cnt=[addList count]; i<cnt; i++)
    {	id	g = [addList objectAtIndex:i];

        [g setSelected:NO];
        [list addObject:g];
    }
    [self setSelected:YES];
    coordBounds = bounds = NSZeroRect;
}

/* modified: 13.07.97
 *
 * ungroup
 * after the operation we are freed, all of our objects are added to ulist
 * the ungrouped objects are selected
 */
- (void)ungroupTo:(id)ulist
{   int	i, cnt;

    for (i=0, cnt=[list count]; i<cnt; i++)
    {	id	g = [list objectAtIndex:i];

        [g setSelected:YES];
        [ulist addObject:g];
    }
}
- (void)ungroupRecursiveTo:(id)ulist
{   int	i, cnt;

    for (i=0, cnt=[list count]; i<cnt; i++)
    {	id	g = [list objectAtIndex:i];

        if ([g isKindOfClass:[VGroup class]])
            [g ungroupRecursiveTo:ulist];
        else
        {   [g setSelected:YES];
            [ulist addObject:g];
        }
    }
}

/*- (void)transferSubGraphicsTo:(NSMutableArray *)array at:(int)position
{   int	i;

    for ( i = [list count] - 1; i >= 0; i-- )
    {	id	g = [list objectAtIndex:i];

        [g setSelected:YES];
	[array insertObject:[list objectAtIndex:i] atIndex:position];
    }
}*/

- (void)setSize:(NSSize)newSize
{   NSRect	bRect = [self coordBounds];
    //int		i;

    //for (i=[list count]-1; i>=0; i--)
    //    [(VGraphic*)[list objectAtIndex:i] scale:x :y withCenter:cp];
    [self scale:newSize.width/bRect.size.width :newSize.height/bRect.size.height withCenter:bRect.origin];
}
- (NSSize)size
{   NSRect	bRect = [self coordBounds];

    return bRect.size;
}

/* created:  16.09.95
 * modified: 2000-11-03
 *
 * Returns the bounds.
 */

- (NSRect)bounds
{
    if (![list count])
        return NSZeroRect;

    if (bounds.size.width == 0.0 && bounds.size.height == 0.0)
    {   NSRect	rect;
        int	i, cnt = [list count]-1;

        bounds = [[list objectAtIndex:cnt] bounds];
        for (i=cnt-1; i>=0; i--)
        {   rect = [[list objectAtIndex:i] bounds];
            bounds = NSUnionRect(rect, bounds);
        }
    }
    return bounds;
}

- (NSRect)coordBounds
{
    if (![list count])
        return NSZeroRect;

    if (coordBounds.size.width == 0.0 && coordBounds.size.height == 0.0)
    {   NSRect	rect;
        int		i, cnt = [list count]-1;

        if (cnt<0)
            return NSZeroRect;
        coordBounds = [[list objectAtIndex:cnt] coordBounds];
        for (i=cnt-1; i>=0; i--)
        {   rect = [[list objectAtIndex:i] coordBounds];
            if ( rect.size.width > 0.0 || rect.size.height > 0.0 )    // in case we have a bogus object
                coordBounds = VHFUnionRect(rect, coordBounds);
        }
    }
    return coordBounds;
}
/*
- (NSRect)extendedBoundsWithScale:(float)scale
{   NSRect	rect, bRect;
    int		i, cnt = [list count]-1;

    bRect = [[list objectAtIndex:cnt] extendedBoundsWithScale:scale];
    for (i=cnt-1; i>=0; i--)
    {	rect = [[list objectAtIndex:i] extendedBoundsWithScale:scale];
        bRect = NSUnionRect(rect , bRect);
    }
    return bRect;
}
*/
/* created:  22.10.95
 * modified: 02.03.97
 *
 * Returns the bounds at the given rotation.
 */
- (NSRect)boundsAtAngle:(float)angle withCenter:(NSPoint)cp
{   NSRect	bRect, rect;
    int		i, cnt = [list count]-1;

    bRect = [(VGraphic*)[list objectAtIndex:cnt] boundsAtAngle:angle withCenter:cp];
    for (i=cnt-1; i>=0; i--)
    {	rect = [(VGraphic*)[list objectAtIndex:i] boundsAtAngle:angle withCenter:cp];
        bRect  = NSUnionRect(rect , bRect);
    }
    return bRect;
}

- (void)drawKnobs:(NSRect)rect direct:(BOOL)direct scaleFactor:(float)scaleFactor
{
    if ( (NSIsEmptyRect(rect) || !NSIsEmptyRect(NSIntersectionRect(rect, [self extendedBoundsWithScale:scaleFactor]))) )
    {
	if ( VHFIsDrawingToScreen() && isSelected )
        {   int	i, cnt = [list count], step = (cnt<2000) ? 1 : cnt/2000;

            for ( i=cnt-1; i>=0; i-=step )
            {	id	obj = [list objectAtIndex:i];

                if ( isSelected || [obj isSelected] )
                {   BOOL	sel = [obj isSelected];

                    [obj setSelected:YES];
                    [obj drawKnobs:rect direct:direct scaleFactor:scaleFactor];
                    [obj setSelected:sel];
                }
            }
        }
    }
}

- (void)drawControls:(NSRect)rect direct:(BOOL)direct scaleFactor:(float)scaleFactor
{
    if ( (NSIsEmptyRect(rect) ||
          !NSIsEmptyRect(NSIntersectionRect(rect, [self extendedBoundsWithScale:scaleFactor]))) )
    {
	if ( VHFIsDrawingToScreen() && isSelected )
        {   int	i, cnt = [list count], step = (cnt<2000) ? 1 : cnt/2000;

            for ( i=cnt-1; i>=0; i-=step )
            {	id	obj = [list objectAtIndex:i];
                BOOL	sel = [obj isSelected];

                [obj setSelected:YES];
                //[obj drawKnobs:rect direct:direct scaleFactor:scaleFactor];
                [obj drawControls:rect direct:direct scaleFactor:scaleFactor];
                [obj setSelected:sel];
                /*if ([obj isMemberOfClass:[VCurve class]])
                {   [NSBezierPath setDefaultLineWidth:1.0/scaleFactor];
                    [NSBezierPath strokeLineFromPoint:[obj pointWithNum:0] toPoint:[obj pointWithNum:1]];
                    [NSBezierPath strokeLineFromPoint:[obj pointWithNum:3] toPoint:[obj pointWithNum:2]];
                }*/
            }
        }
    }
}

/*
 * Depending on the pt_num passed in, return the rectangle
 * that should be used for scrolling purposes. When the rectangle
 * passes out of the visible rectangle then the screen should
 * scroll. If the first and last points are selected, then the second
 * and third points are included in the rectangle. If the second and
 * third points are selected, then they are used by themselves.
 */
- (NSRect)scrollRect:(int)pt_num inView:(id)aView
{   VGraphic	*g = nil;

    if (pt_num != -1 && ![(App*)NSApp alternate])
    {
        if ( pt_num >= [self numPoints] )
        {   g = [list objectAtIndex:[list count]-1];
            pt_num = MAXINT;
        }
        else if ( !pt_num )
            g = [list objectAtIndex:0];
        else
        {   int	i, cnt, pCnt = 0, prevPCnt = 0;

            for (i=0, cnt = [list count]; i<cnt; i++)
            {   pCnt += [[list objectAtIndex:i] numPoints];
                if ( pCnt > pt_num )
                    break;		// to this object refers our pt_num
                prevPCnt = pCnt;	// count of pts befor this gr
            }
            g = [list objectAtIndex:i];
            pt_num -= prevPCnt;
        }
        return [g scrollRect:pt_num inView:aView];
    }
    return [self bounds];
}
/*{
    if ( [(App*)NSApp alternate] )
        return [self bounds];	// ?
    else
        return [self bounds];
}*/

/* 
 * This method constains the point to the bounds of the view passed
 * in. Like the method above, the constaining is dependent on the
 * control point that has been selected.
 */
- (void)constrainPoint:(NSPoint *)aPt andNumber:(int)pt_num toView:aView
{   VGraphic	*g = nil;

    if (pt_num < 0)
        return;

    if ( pt_num >= [self numPoints] )
    {   g = [list objectAtIndex:[list count]-1];
        pt_num = MAXINT;
    }
    else if ( !pt_num )
        g = [list objectAtIndex:0];
    else
    {   int	i, cnt, pCnt = 0, prevPCnt = 0;

        for (i=0, cnt = [list count]; i<cnt; i++)
        {   pCnt += [[list objectAtIndex:i] numPoints];
            if ( pCnt > pt_num )
                break;		// to this object refers our pt_num
            prevPCnt = pCnt;	// count of pts befor this gr
        }
        g = [list objectAtIndex:i];
        pt_num -= prevPCnt;
    }
    [g constrainPoint:aPt andNumber:pt_num toView:aView];
}

/*
 * pt_num is the changing control point. pt holds the relative change in each coordinate. 
 * The relative is needed and not the absolute because the closest inside control point
 * changes when one of the outside points change.
 */
- (void)movePoint:(int)pt_num to:(NSPoint)p
{   VGraphic	*g = nil;

    if ( ![list count] || pt_num < 0 )
        return;
    /* beyond list -> point number of end point */
    if ( pt_num >= [self numPoints] )
    {   g = [list objectAtIndex:[list count]-1];
        pt_num = MAXINT;
    }
    else if ( !pt_num )
        g = [list objectAtIndex:0];
    else
    {   int	i, cnt, pCnt = 0, prevPCnt = 0;

        for (i=0, cnt = [list count]; i<cnt; i++)
        {   pCnt += [[list objectAtIndex:i] numPoints];
            if ( pCnt > pt_num )
                break;		// to this object refers our pt_num
            prevPCnt = pCnt;	// count of pts befor this gr
        }
        g = [list objectAtIndex:i];
        pt_num -= prevPCnt;
    }
    if (!g) return;

    [g movePoint:pt_num to:p];
    coordBounds = bounds = NSZeroRect;
}

/* needed for undo
 * if control button is set -> the radius of an arc will changed (else not!)
 * for the way back we need the possibility to say "the button is set"
 */
- (void)movePoint:(int)pt_num to:(NSPoint)p control:(BOOL)control
{   VGraphic	*g = nil;

    if ( ![list count] || pt_num < 0 )
        return;
    /* beyond list -> point number of end point */
    if ( pt_num >= [self numPoints] )
    {   g = [list objectAtIndex:[list count]-1];
        pt_num = MAXINT;
    }
    else if ( !pt_num )
        g = [list objectAtIndex:0];
    else
    {   int	i, cnt, pCnt = 0, prevPCnt = 0;

        for (i=0, cnt = [list count]; i<cnt; i++)
        {   pCnt += [[list objectAtIndex:i] numPoints];
            if ( pCnt > pt_num )
                break;		// to this object refers our pt_num
            prevPCnt = pCnt;	// count of pts befor this gr
        }
        g = [list objectAtIndex:i];
        pt_num -= prevPCnt;
    }
    if (!g) return;

    if ([g isKindOfClass:[VArc class]])
        [(VArc*)g movePoint:pt_num to:p control:control];
    else if ([g isKindOfClass:[VPath class]])
        [(VPath*)g movePoint:pt_num to:p control:control];
    else
        [g movePoint:pt_num to:p];
    coordBounds = bounds = NSZeroRect;
}

/*
 * pt_num is the changing control point. pt holds the relative change in each coordinate. 
 * The relative is needed and not the absolute because the closest inside control point
 * changes when one of the outside points change.
 */
- (void)movePoint:(int)pt_num by:(NSPoint)pt
{
    if ( ![list count] || pt_num < 0 )
        return;
    /* beyond list -> return point number of end point */
    if ( pt_num >= [self numPoints] )
        [[list objectAtIndex:[list count]-1] movePoint:MAXINT by:pt];
    else if ( !pt_num )
        [[list objectAtIndex:0] movePoint:0 by:pt];
    else
    {   int	i, cnt, pCnt = 0, prevPCnt = 0;

        for (i=0, cnt = [list count]; i<cnt; i++)
        {   pCnt += [[list objectAtIndex:i] numPoints];
            if ( pCnt > pt_num )
                break;		// to this object refers our pt_num
            prevPCnt = pCnt;	// count of pts befor this gr
        }
        [[list objectAtIndex:i] movePoint:pt_num - prevPCnt by:pt];
    }
    coordBounds = bounds = NSZeroRect;
    dirty = YES;
}
/*{
    if (selectedObject < 0)
        return;
    [[list objectAtIndex:selectedObject] movePoint:pt_num by:pt];
    dirty = YES;
}*/

/* The pt argument holds the relative point change. */
- (void)moveBy:(NSPoint)pt
{   int	i;

    for (i=[list count]-1; i>=0; i--)
        [[list objectAtIndex:i] moveBy:pt];
    coordBounds = bounds = NSZeroRect;
    dirty = YES;
}

/* Given the point number, return the point. */
- (NSPoint)pointWithNum:(int)pt_num
{
    if ( ![list count] || pt_num < 0 )
        return NSMakePoint( 0.0, 0.0);
    /* beyond list -> return point number of end point */
    if ( pt_num >= [self numPoints] )
        return [[list objectAtIndex:[list count]-1] pointWithNum:MAXINT];
    /* return point of group */
    {   int	i, cnt, pCnt = 0, prevPCnt = 0;

        if ( !pt_num )
            return [[list objectAtIndex:0] pointWithNum:0];

        for (i=0, cnt = [list count]; i<cnt; i++)
        {   pCnt += [[list objectAtIndex:i] numPoints];
            if ( pCnt > pt_num )
                break;		// to this object refers our pt_num
            prevPCnt = pCnt;	// count of pts befor this gr
        }
        return [[list objectAtIndex:i] pointWithNum:pt_num - prevPCnt];
    }
}
/*{
    if ( ![list count] )
        return NSMakePoint( 0.0, 0.0 );
    return [[list objectAtIndex:(selectedObject>=0) ? selectedObject : 0] pointWithNum:pt_num];
}*/

- (int)numPoints
{   int	i, cnt, pCnt = 0;

    for (i=0, cnt = [list count]; i<cnt; i++)
        pCnt += [[list objectAtIndex:i] numPoints];
    return pCnt;
}

- (void)mirrorAround:(NSPoint)mp;
{    int		i;

    for (i=[list count]-1; i>=0; i--)
        [(VGraphic*)[list objectAtIndex:i] mirrorAround:mp];
    coordBounds = bounds = NSZeroRect;
    dirty = YES;
}

/* created:   1995-10-21
 * modified:  2000-11-08
 * parameter: x, y
 * purpose:   draws the plane with the given rotation angles
 */
- (void)drawAtAngle:(float)angle withCenter:(NSPoint)cp in:view
{   int		i, iCnt;

    for ( i = 0, iCnt = [list count]; i<iCnt; i++ )
        [(VGraphic*)[list objectAtIndex:i] drawAtAngle:angle withCenter:cp in:view];
}

- (void)setAngle:(float)angle withCenter:(NSPoint)cp
{   int		i;

    for (i=[list count]-1; i>=0; i--)
        [(VGraphic*)[list objectAtIndex:i] setAngle:angle withCenter:cp];
    coordBounds = bounds = NSZeroRect;
    dirty = YES;
}

- (void)transform:(NSAffineTransform*)matrix
{   int	i;

    for ( i=[list count]-1; i >= 0; i-- )
        [[list objectAtIndex:i] transform:matrix];
    coordBounds = bounds = NSZeroRect;
    dirty = YES;
}

- (void)scale:(float)x :(float)y withCenter:(NSPoint)cp
{   int		i;

    for (i=[list count]-1; i>=0; i--)
        [(VGraphic*)[list objectAtIndex:i] scale:x :y withCenter:cp];
    coordBounds = bounds = NSZeroRect;
    dirty = YES;
}

/* created:  19.09.95
 * modified: 02.03.97 02.02.00
 * purpose:  redraws the group
 */
- (void)drawWithPrincipal:principal
{   int	i, iCnt;

    for ( i = 0, iCnt = [list count]; i<iCnt; i++ )
        [(VGraphic*)[list objectAtIndex:i] drawWithPrincipal:principal];

#if 0
    /* display intersections within path */
    for (i=0; i<(int)[list count]-1; i++)
    {	id	g = [list objectAtIndex:i];
        NSPoint	*pts = NULL;
        int	cnt, j;

        cnt = [g getIntersections:&pts with:[list objectAtIndex:i+1]];
        for (j=0; j<cnt; j++)
            CROSS_45(pts[j]);
        if (pts)
            free(pts);
    }
#endif
}

/*
 * Check for a control point hit. Return the point number hit in the pt argument.
 * Does not set the graphic selection!!
 */
- (BOOL)hitEdge:(NSPoint)p fuzz:(float)fuzz :(NSPoint*)pt :(float)controlsize
{   int     i;
    BOOL    gotHit = NO;
    NSPoint hitP = p;
    double  sqrDistBest = MAXFLOAT;

    for (i=[list count]-1; i>=0; i--)
    {	id  obj = [list objectAtIndex:i];

        if ([obj hitEdge:p fuzz:fuzz :pt :controlsize])
        {   gotHit = YES;
            if ( SqrDistPoints(*pt, p) < sqrDistBest )
            {   hitP = *pt;
                sqrDistBest = SqrDistPoints(*pt, p);
            }
            //return YES;
        }
    }
    if (gotHit)
    {   *pt = hitP;
        return YES;
    }
    return NO;
}

/*
 * Check for a control point hit.
 * Return the point number hit in the pt_num argument.
 */
- (BOOL)hitControl:(NSPoint)p :(int *)pt_num controlSize:(float)controlsize
{   int	i, cnt = [list count], pCnt = 0;

    for (i=0; i<cnt; i++)
    {	id obj = [list objectAtIndex:i];

        if ([obj hitControl:p :pt_num controlSize:controlsize])
        {
            /* curvePt (1,2) or arc center we do not deselect selected Knob ! */
            if (*pt_num == [obj selectedKnobIndex] && selectedObject >= 0 && selectedObject != i)
                [[list objectAtIndex:selectedObject] setSelected:NO];
            if (*pt_num == [obj selectedKnobIndex])
                selectedObject = i;
            *pt_num += pCnt;
            return YES;
        }
        pCnt += [obj numPoints];
    }
    return NO;
}

/* created:   16.09.95
 * modified: 
 * parameter: p  clicked point
 * purpose:   check whether point hits object
 */
- (BOOL)hit:(NSPoint)p fuzz:(float)fuzz
{   int		i;
    int		hit = NO;
    BOOL	alternate = [(App*)NSApp alternate];

    for (i=[list count]-1; i>=0; i--)
    {	id obj = [list objectAtIndex:i];

        if ([obj hit:p fuzz:fuzz])
        {   hit = YES;
            [self deselectAll];
            if (alternate)
            {	[obj setSelected:YES];
                if (selectedObject >= 0 && selectedObject != i)
                    [[list objectAtIndex:selectedObject] setSelected:NO];
                selectedObject = i;
            }
            break;
        }
    }
    return (BOOL)hit;
}

/*
 * return a path representing the outline of us
 * the path holds two lines and two arcs
 * if we need not build a contour a copy of self is returned
 */
- contour:(float)w
{   VGroup		*group;
    NSMutableArray	*glist;
    int			i, cnt;

    group = [VGroup group];
    [group setColor:color];

    glist = [[NSMutableArray allocWithZone:[self zone]] init];

    cnt = [list count];
    for ( i=0; i<cnt; i++ )
    {   id	g = [[list objectAtIndex:i] contour:w];
        if ( g )
            [glist addObject:g];
    }

    [group add:glist];
    [glist release];
    [group setSelected:[self isSelected]];

    return group;
}

#if 0
- getListOfObjectsSplittedFrom:(NSPoint*)pArray :(int)iCnt
{   NSMutableArray	*splitList = [NSMutableArray array], *spList = nil;
    int			i, j, cnt = [list count];

    /* tile each graphic from path with pArray
     * add splitted objects to splitList (else object)
     */
    for (i=0; i<cnt; i++)
    {	VGraphic	*g = [list objectAtIndex:i];

        spList = [g getListOfObjectsSplittedFrom:pArray :iCnt];
        if ( spList )
        {   for ( j=0; j<(int)[spList count]; j++ )
                [splitList addObject:[spList objectAtIndex:j]];
        }
        else
            [splitList addObject:[[g copy] autorelease]];
    }
    if ( [splitList count] > [list count] )
        return splitList;
    return nil;
}

- (int)getIntersections:(NSPoint**)ppArray with:g
{   int		i, j, iCnt = 0, ptsCnt = Min(100, [self numPoints]);
    NSPoint	*pts = NULL;

    *ppArray = malloc(ptsCnt * sizeof(NSPoint));
    for (i=[list count]-1; i>=0; i--)
    {	id	gp = [list objectAtIndex:i];
        int	cnt, oldCnt = iCnt;

        if ( gp == g )
            continue;

        cnt = [gp getIntersections:&pts with:g];	/* line, arc, curve */
        if (iCnt+cnt >= ptsCnt)
            *ppArray = realloc(*ppArray, (ptsCnt+=cnt*2) * sizeof(NSPoint));

        for (j=0; j<cnt; j++)
        {
            if ( !pointInArray(pts[j], *ppArray, oldCnt) )
                (*ppArray)[iCnt++] = pts[j];
            else
            {   NSPoint	start, end;

                if ( [gp isKindOfClass:[VLine class]] )		/* line */
                    [(VLine*)gp getVertices:&start :&end];
                else if ( [gp isKindOfClass:[VArc class]] )
                {   [(VArc*)gp getPoint:0 :&start];
                    [(VArc*)gp getPoint:1 :&end];
                }
                else if ( [gp isKindOfClass:[VCurve class]] )
                {   [(VCurve*)gp getPoint:0 :&start];
                    [(VCurve*)gp getPoint:3 :&end];
                }
                else if ( [gp isKindOfClass:[VRectangle class]] )
                {   NSPoint	ur, ul, size;
                    [(VRectangle*)gp getVertices:&start :&size]; // origin size
                    end = start; end.x += size.x;
                    ul = start; ul.y += size.y;
                    ur = end; ur.y += size.y;
                    if ( (Diff(pts[j].x, ul.x) + Diff(pts[j].y, ul.y) < 10.0*TOLERANCE) ||
                         (Diff(pts[j].x, ur.x) + Diff(pts[j].y, ur.y) < 10.0*TOLERANCE) )
                        continue; // do not add
                }
                else if ( [gp isKindOfClass:[VPolyLine class]] )
                {   int	k, pCnt = [(VPolyLine*)gp ptsCount], stop = 0;

                    for (k=1; k<pCnt-1; k++)
                    {   NSPoint	pt = [(VPolyLine*)gp pointWithNum:k];
                        if ( Diff(pts[j].x, pt.x) + Diff(pts[j].y, pt.y) < 10.0*TOLERANCE )
                        {   stop = 1; break; }
                    }
                    if (stop)
                        continue; // do not add
                    [(VPolyLine*)gp getEndPoints:&start :&end];
                }
                else
                {   start.x = end.x = pts[j].x; start.y = end.y = pts[j].y;
                }
                /* point is no edge point of gp -> add */
                if ( (Diff(pts[j].x, start.x) + Diff(pts[j].y, start.y) > 10.0*TOLERANCE) &&
                    (Diff(pts[j].x, end.x) + Diff(pts[j].y, end.y) > 10.0*TOLERANCE) )
                    (*ppArray)[iCnt++] = pts[j];
            }
        }
        if (pts)
            free(pts);
    }

    if (!iCnt)
    {	free(*ppArray);
        *ppArray = NULL;
    }

    return iCnt;
}
#endif

- (float)sqrDistanceGraphic:g
{   int		i;
    float	dist, distance = MAXCOORD;

    for (i=[list count]-1; i>=0; i--)
    {	id	gp = [list objectAtIndex:i];

        if ( (dist=[gp sqrDistanceGraphic:g]) < distance)
            distance = dist;
    }
    return distance;
}

- (float)distanceGraphic:g
{   float	distance;

    distance = [self sqrDistanceGraphic:g];
    return sqrt(distance);
}

- (BOOL)isPointInside:(NSPoint)p
{   int	i, cnt;

    for (i=0, cnt = [list count]; i<cnt; i++)
    {	id	gr = [list objectAtIndex:i];
        
        if ( [gr isKindOfClass:[VArc class]] || [gr isKindOfClass:[VRectangle class]]
            || [gr isKindOfClass:[VPath class]] || [gr isKindOfClass:[VGroup class]] )
        {
            if ( [gr isPointInside:p] )
                return YES;
        }
    }
    return NO;
}

- (id)clippedWithRect:(NSRect)rect
{   NSMutableArray	*clipList = [NSMutableArray array];
    id			cObj;
    NSArray		*cList;
    int			i, cnt, c, cCnt;
    VGroup		*group;

    for (i=0, cnt = [list count]; i<cnt; i++)
    {
        if (!(cObj = [[list objectAtIndex:i] clippedWithRect:rect]))
            continue;
        if ([cObj isMemberOfClass:[VGroup class]])
        {
            cList = [cObj list];
            for (c=0, cCnt = [cList count]; c<cCnt; c++)
                [clipList addObject:[cList objectAtIndex:c]];
        }
        else
            [clipList addObject:cObj];
    }

    if (![clipList count])
        return nil;
    group = [VGroup group];
    [group setList:clipList];
    return group;
}

/* returns a flattened copy of path
 */
/*- flattenedObject
{   VGroup		*newGroup = [[self copy] autorelease];
    int			i, cnt;

    cnt = [list count];
    for ( i=0; i<cnt; i++)
    {	id	fg, g = [list objectAtIndex:i];

        fg = [g flattenedObject];
        [list replaceObject:g withObject:fg];
    }
    [newGroup setSelected:[self isSelected]];

    return newGroup;
}*/
#if 0
- getIntersectionsAndSplittedObjects:(NSPoint**)ppArray :(int*)iCnt with:g
{   int             i, j, lCnt = [list count], ptsCnt = Min(100, [self numPoints]);
    NSPoint         *pts = NULL;
    NSRect          gBounds = [g bounds];
    NSMutableArray  *splitList = [NSMutableArray array], *spList = nil;

    *iCnt = 0;
    *ppArray = malloc(ptsCnt * sizeof(NSPoint));
//    for (i=[list count]-1; i>=0; i--)
    for (i=0; i<lCnt; i++)
    {	id	gp = [list objectAtIndex:i];
        int	cnt, oldCnt = *iCnt;
        NSRect	gpBounds = [gp bounds];

        if ( gp == g )
            continue;
        // check bounds
        if ( NSIsEmptyRect(NSIntersectionRect(gBounds , gpBounds)) )
        {
            // add to splitList
            [splitList addObject:[[gp copy] autorelease]];
            continue;
        }
        /* line, arc, curve */
        if ( !(cnt = [gp getIntersections:&pts with:g]) )
            [splitList addObject:[[gp copy] autorelease]];
        else
        {   spList = [gp getListOfObjectsSplittedFrom:pts :cnt];
            if ( spList )
            {   for ( j=0; j<(int)[spList count]; j++ )
                    [splitList addObject:[spList objectAtIndex:j]];
            }
            else
                [splitList addObject:[[gp copy] autorelease]];
        }

        if ((*iCnt)+cnt >= ptsCnt)
            *ppArray = realloc(*ppArray, (ptsCnt+=cnt*2) * sizeof(NSPoint));

        for (j=0; j<cnt; j++)
        {
            if ( !pointInArray(pts[j], *ppArray, oldCnt) )
                (*ppArray)[(*iCnt)++] = pts[j];
            else
            {   NSPoint	start, end;

                if ( [gp isKindOfClass:[VLine class]] )		/* line */
                    [(VLine*)gp getVertices:&start :&end];
                else if ( [gp isKindOfClass:[VArc class]] )
                {   [(VArc*)gp getPoint:0 :&start];
                    [(VArc*)gp getPoint:1 :&end];
                }
                else if ( [gp isKindOfClass:[VCurve class]] )
                {   [(VCurve*)gp getPoint:0 :&start];
                    [(VCurve*)gp getPoint:3 :&end];
                }
                else if ( [gp isKindOfClass:[VRectangle class]] )
                {   NSPoint	ur, ul, size;
                    [(VRectangle*)gp getVertices:&start :&size]; // origin size
                    end = start; end.x += size.x;
                    ul = start; ul.y += size.y;
                    ur = end; ur.y += size.y;
                    if ( (Diff(pts[j].x, ul.x) + Diff(pts[j].y, ul.y) < 20.0*TOLERANCE) ||
                        (Diff(pts[j].x, ur.x) + Diff(pts[j].y, ur.y) < 20.0*TOLERANCE) )
                        continue; // do not add
                }
                else
                {   start.x = end.x = pts[j].x; start.y = end.y = pts[j].y;
                }
                /* point is no edge point of gp -> add */
                if ( (Diff(pts[j].x, start.x) + Diff(pts[j].y, start.y) > 20.0*TOLERANCE) &&
                    (Diff(pts[j].x, end.x) + Diff(pts[j].y, end.y) > 20.0*TOLERANCE) )
                    (*ppArray)[(*iCnt)++] = pts[j];
            }
        }
        if (pts)
            free(pts);
    }

    if (!(*iCnt))
    {	free(*ppArray);
        *ppArray = NULL;
    }
    if ( [splitList count] > [list count] )
        return splitList;
    return nil;
}

- uniteWith:(VGraphic*)ug
{   int                 i, j, iCnt, nothingRemoved = 0, cnt;
    VPath               *ng;
    NSMutableArray      *splitListG, *splitListUg;
    NSPoint             *iPts = NULL;
    NSAutoreleasePool   *pool;

    if ( ![ug isKindOfClass:[VPath class]] && ![ug isKindOfClass:[VArc class]]
        && ![ug isKindOfClass:[VRectangle class]] && ![ug isKindOfClass:[VGroup class]] )
        return NO;

    ng = [VPath path];
    [ng setColor:[self color]];
    [ng setFilled:YES optimize:NO];
    [ng setWidth:[self width]];
    [ng setSelected:[self isSelected]];

    /* split self */
    if ( (splitListG = [self getIntersectionsAndSplittedObjects:&iPts :&iCnt with:ug]) )
        [ng setList:splitListG optimize:NO];

    /*if ( (iCnt = [self getIntersections:&iPts with:ug]) )
    {
        if ( (splitListG = [self getListOfObjectsSplittedFrom:iPts :iCnt]) )
        {
            [ng setList:splitListG optimize:NO];
            //for (i=0; i<[splitListG count]; i++)
            //   [[ng list] addObject:[[[splitListG objectAtIndex:i] copy] autorelease]];
        }
    }*/
    if ( ![[ng list] count] )
        // [ng setList:list optimize:NO];
        for (i=0; i<(int)[list count]; i++)
            [[ng list] addObject:[[[list objectAtIndex:i] copy] autorelease]];

    pool = [NSAutoreleasePool new];
    /* split ug */
    if ( !(splitListUg = [ug getListOfObjectsSplittedFrom:iPts :iCnt]) )
    {
        splitListUg = [NSMutableArray array];
        if ( [ug isKindOfClass:[VPath class]] )
            for (i=0; i<(int)[[(VPath*)ug list] count]; i++)
                [splitListUg addObject:[[[[(VPath*)ug list] objectAtIndex:i] copy] autorelease]];
        else
            [splitListUg addObject:[[ug copy] autorelease]];
    }
    if (iPts)
        free(iPts);

    /* ug is'nt a path and not splitted now -> nothing to unite - NO */
    if ( ![ug isKindOfClass:[VPath class]] && [splitListUg count] == 1 )
    {   [pool release];
        return NO;	/* nothing to unite */
    }
    /* now remove the graphictiles from ug wich are inside or on self
     * if no tile is removed -> NO
     */
    {   HiddenArea	*hiddenArea = [HiddenArea new];
        
        // if ( ![[[HiddenArea new] autorelease] removeGraphics:splitListUg inside:self] )
        if ( ![hiddenArea removeGraphics:splitListUg inside:self] )
            nothingRemoved++;

        /* now remove the graphic tiles from ng(self splitted) wich are inside or on ug */
        if ( ![hiddenArea removeGraphics:[ng list] inside:ug] && nothingRemoved )
        {   [hiddenArea release];
            [pool release];
            return NO;
        }

        /* add graphics from splitListUg to ng list */
        for (i=0; i<(int)[splitListUg count]; i++)
            [[ng list] addObject:[[[splitListUg objectAtIndex:i] copy] autorelease]];

        /* we must remove identical graphics in list */
        cnt = ([[ng list] count] - [splitListUg count]);

        /* we check only added objects !!!!!!!!!! */
        for (i=[[ng list] count]-1; i >= cnt; i--)
        {   VGraphic	*g = [[ng list] objectAtIndex:i];

            for (j=0; j<(int)[[ng list] count]; j++)
            {   VGraphic	*g2 = [[ng list] objectAtIndex:j];

                if ( g2 == g )
                    continue;
                if ( [g2 identicalWith:g] )
                {
                    [[ng list] removeObject:g];
                    break;
                }
            }
        }
        [hiddenArea removeSingleGraphicsInList:[ng list] :[ug bounds]];
        [hiddenArea release];
    }

    [pool release];
    return ng;
}
#endif

- (void)writeFilesToDirectory:(NSString*)directory
{   int	i;

    for (i = [list count]-1; i >= 0; i--)
        [[list objectAtIndex:i] writeFilesToDirectory:directory];
}
- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [super encodeWithCoder:aCoder];
    [aCoder encodeValuesOfObjCTypes:"@", &list];
    [aCoder encodeValuesOfObjCTypes:"ic", &filled, &uniColoring]; // 2004-12-15
    [aCoder encodeObject:fillColor];
    [aCoder encodeObject:endColor];
    [aCoder encodeValuesOfObjCTypes:"ff", &graduateAngle, &stepWidth];
    //[aCoder encodeValuesOfObjCTypes:"{NSPoint=ff}", &radialCenter];
    [aCoder encodePoint:radialCenter];          // 2012-01-08
}
- (id)initWithCoder:(NSCoder *)aDecoder
{   int	version;

    [super initWithCoder:aDecoder];
    version = [aDecoder versionForClassName:@"VGroup"];
    [aDecoder decodeValuesOfObjCTypes:"@", &list];

    selectedObject = -1;

    if (version > 1)
    {
        [aDecoder decodeValuesOfObjCTypes:"ic", &filled, &uniColoring];
        fillColor = [[aDecoder decodeObject] retain];
        endColor = [[aDecoder decodeObject] retain];
        [aDecoder decodeValuesOfObjCTypes:"ff", &graduateAngle , &stepWidth];
        //[aDecoder decodeValuesOfObjCTypes:"{NSPoint=ff}", &radialCenter];
        radialCenter = [aDecoder decodePoint];  // 2012-01-08
    }
    else
        [self setColorNew];

    return self;
}

/* archiving with property list
 */
- (id)propertyList
{   NSMutableDictionary	*plist = [super propertyList];

    [plist setObject:propertyListFromArray(list) forKey:@"list"];
    if (uniColoring) [plist setObject:@"YES" forKey:@"uniColoring"];
    if (filled)
        [plist setObject:propertyListFromInt(filled) forKey:@"filled"];
    if (fillColor != [NSColor blackColor])
        [plist setObject:propertyListFromNSColor(fillColor) forKey:@"fillColor"];
    if (endColor != [NSColor blackColor])
        [plist setObject:propertyListFromNSColor(endColor) forKey:@"endColor"];
    if (graduateAngle)
        [plist setObject:propertyListFromFloat(graduateAngle) forKey:@"graduateAngle"];
    if (stepWidth != 7)
        [plist setObject:propertyListFromFloat(stepWidth) forKey:@"stepWidth"];
    if (radialCenter.x != 0.5 && radialCenter.y != 0.5)
        [plist setObject:propertyListFromNSPoint(radialCenter) forKey:@"radialCenter"];
    return plist;
}
- (id)initFromPropertyList:(id)plist inDirectory:(NSString *)directory
{
    [super initFromPropertyList:plist inDirectory:directory];
    list = arrayFromPropertyList([plist objectForKey:@"list"], directory, [self zone]);
    selectedObject = -1;
    uniColoring = ([plist objectForKey:@"uniColoring"] ? YES : NO);
    filled = [plist intForKey:@"filled"];
    if (!filled && [plist objectForKey:@"filled"])
        filled = 1;
    fillColor = colorFromPropertyList([plist objectForKey:@"fillColor"], [self zone]);
    endColor = colorFromPropertyList([plist objectForKey:@"endColor"], [self zone]);
    graduateAngle = [plist floatForKey:@"graduateAngle"];
    if ( !(stepWidth = [plist floatForKey:@"stepWidth"]))
        stepWidth = 7.0;	// default;
    if ([plist objectForKey:@"radialCenter"])
        radialCenter = pointFromPropertyList([plist objectForKey:@"radialCenter"]);
    else
        radialCenter = NSMakePoint(0.5, 0.5);	// default
    if (!fillColor || !endColor)
        [self setColorNew];

    return self;
}


- (void)dealloc
{
    [list release];
    [super dealloc];
}

@end
