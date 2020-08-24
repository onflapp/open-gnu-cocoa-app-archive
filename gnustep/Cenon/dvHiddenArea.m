/* dvHiddenArea.m
 * Additions for Cenon DocView class to remove hidden areas
 *
 * Copyright (C) 1996-2012 by vhf interservice GmbH
 * Author:   Ilonka Fleischmann
 *
 * created:  1996-09-24
 * modified: 2012-07-17 (-removePartsOf:hiddenBy: free(iPts))
 *           2006-02-06
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
#include <VHFShared/types.h>
#include <VHFShared/vhf2DFunctions.h>
#include "App.h"
#include "DocView.h"

/* Private methods
*/
@interface DocView(PrivateMethods)
- (void)optimizeList:(NSMutableArray*)list;
- (void)removeSingleGraphicsInList:(NSMutableArray*)list;
- (BOOL)addGraphics:(NSMutableArray*)splitList inside:(id)graphic toList:(NSMutableArray*)list;
- (BOOL)removePartsOf:(VGraphic**)curG hiddenBy:(id)og;
@end

@implementation DocView(HiddenArea)

/* remove parts of graphic objects coverd by other graphics
 * first graphic in list is covered by all following graphics in list etc.
 */
- (void)removeHiddenAreas:(NSMutableArray*)list
{   long	c, o, prevCnt;

    /* beginning with the first graphic
     */
    for ( c=0; c < (int)[list count]-1; c++ )
    {	id	cg = [list objectAtIndex:c];
        NSRect	cBounds;

        prevCnt = [list count];
        cBounds = [cg bounds];

        /* look if the cg lies under one of the other (o) graphics
         * if the two graphics has the same colour they will be united later !
         * else: the hidden areas of the hidden graphic will be removed or the hole hiddenG
         */
        for ( o=c+1; o < (int)[list count]; o++ )
        {   id		og = [list objectAtIndex:o];
            NSRect	oBounds;

            oBounds = [og bounds];

            if ( !NSIsEmptyRect(NSIntersectionRect(cBounds , oBounds)) )
            {	NSColor	*cColor = [cg color], *oColor = [og color];

                if ( ![cColor isEqual:oColor] )
                {
                    if ( [self removePartsOf:&cg hiddenBy:og] )
                    {	/* if the hidden graphic is in the og we remove the hiddenG */
                        [list removeObjectAtIndex:c];  /* cg is oldCg */;
                        c--;
                        break;
                    }
                    [list removeObjectAtIndex:c];
                    [list insertObject:cg atIndex:c];	/* is a new cg */
                }
            }
        }
        /* if there is only one graphic behind unite/removed
         * this cg (also for the last in list?) will not optimize -> need c < lCnt-1
         */
        if ( prevCnt != (int)[list count] && c < (int)[list count]-1 )
        {   if ( c != -1 )
            c--;
        }
    }
    [self uniteAreas:list];
}

/* unite graphics in list which have the same color - remove other graphic
 */
- (void)uniteAreas:(NSMutableArray*)list
{   long	c, o, prevCnt;

    /* start with first graphic
    */
    for ( c=0; c < (int)[list count]; c++ )
    {	VGraphic	*cg = [list objectAtIndex:c];
        NSRect	cBounds;

        /* lines, curves, full/unfilled arcs or unfilled paths can't be filled
         */
        if ( [cg isKindOfClass:[VLine class]] || [cg isKindOfClass:[VCurve class]] ||
            ([cg isKindOfClass:[VArc class]] && (Abs([(VArc*)cg angle]) != 360.0 || ![cg filled])) ||
            ([cg isKindOfClass:[VPath class]] && ![cg filled]) )
            continue;
        prevCnt = [list count];
        cBounds = [cg bounds];

        for ( o=c+1; o < (int)[list count]; o++ )
        {   VGraphic	*og = [list objectAtIndex:o];
            NSRect	oBounds;

            if ( [og isKindOfClass:[VLine class]] || [og isKindOfClass:[VCurve class]] ||
                ([og isKindOfClass:[VArc class]] && (Abs([(VArc*)og angle]) != 360.0 || ![og filled])) ||
                ([og isKindOfClass:[VPath class]] && ![og filled]) )
                continue;

            oBounds = [og bounds];
            if ( !NSIsEmptyRect(NSIntersectionRect(cBounds , oBounds)) )
            {	NSColor *cColor = [cg color], *oColor = [og color];
                VGraphic	*ng;

                if ( [cColor isEqual:oColor] && (ng = [cg uniteWith:og]) )
                {
                    [list removeObjectAtIndex:c];
                    [list insertObject:ng atIndex:c];
                    [list removeObjectAtIndex:o];	/* if the graphics are united we remove the og */
                    cg = [list objectAtIndex:c];
                    cBounds = [cg bounds];
                    o--;
                }
            }	
        }
        /* if there is only one graphic left after uniting cg
         * (is this also true for the last in list?) we do not optimize -> need c < [list count]-1
         */
        if ( prevCnt != (int)[list count] && c < (int)[list count]-1 )
        {   if ( c != -1 )
            c--;
        }
        else if ( [[list objectAtIndex:c] isKindOfClass:[VPath class]] )
            /* optimize list only once for each united graphic */
            [self optimizeList:[(VPath*)[list objectAtIndex:c] list]];
    }
}

/* optimize list
 */
- (void)optimizeList:(NSMutableArray*)list
{   long 	i1, i2,  changeIndex=1, cnt=[list count];
    float	startDist=MAXCOORD, distS, distE;
    NSPoint	e1, s2, e2;

    if (!cnt)
        return;

    for ( i1 = 0 ; i1 < (cnt-1)  ; i1++ )
    {	VGraphic	*g1=[list objectAtIndex:i1];

        if ( [g1 isKindOfClass:[VPath class]] )
        {   [self optimizeList:[(VPath*)g1 list]];
            [[[(VPath*)g1 list] objectAtIndex:0] getPoint:3 :&e1];
        }
        else
            [g1 getPoint:3 :&e1];

        for ( i2 = i1+1 ; i2 < cnt ; i2++ )
        {   VGraphic	*g2=[list objectAtIndex:i2];

            if ( [g2 isKindOfClass:[VPath class]] )
            {	[[[(VPath*)g2 list] objectAtIndex:0] getPoint:0 :&s2];
                e2 = s2;
            }
            else
            {	[g2 getPoint:0 :&s2];
                [g2 getPoint:3 :&e2];
            }
            distS = SqrDistPoints(e1, s2);
            distE = SqrDistPoints(e1, e2);

            if ( Min(distS, distE) < startDist )
            {
                if ( distE < distS )
                    [g2 changeDirection];
                startDist = Min(distS, distE);
                changeIndex = i2;
                if ( Diff(startDist, 0.0) <= TOLERANCE )
                    break;
            }
        }
        /* if the nearest element is not the next_in_list */
        if ( changeIndex != (i1 + 1) )	/* changeIndex graphic get place after i1 -> i1+1 */
        {   [list insertObject:[list objectAtIndex:changeIndex] atIndex:i1+1];
            [list removeObjectAtIndex:changeIndex+1];
        }

        startDist = MAXCOORD;
    } 
}

/* remove graphics from list which has only one neighbour
 */
#define CLOSETOLERANCE 0.03
- (void)removeSingleGraphicsInList:(NSMutableArray*)list
{   int		oneNeighbour=0, otherNeighbour=0;
    long	i, j;

    for ( i=0; i < (int)[list count]; i++ )
    {   VGraphic	*g1 = [list objectAtIndex:i];
        NSPoint	s1, e1, s2, e2; ;

        /* paths and full arcs must not remove */
        if ( [g1 isKindOfClass:[VPath class]] )
        {
            [self removeSingleGraphicsInList:[(VPath*)g1 list]];
            continue;
        }
        if ( ([g1 isKindOfClass:[VArc class]] && Abs([(VArc*)g1 angle]) == 360) )
            continue;

        /* count the neightbours if we have one neightbour we searching only for the other neightbour
         */
        [g1 getPoint:0 :&s1]; [g1 getPoint:3 :&e1];
        oneNeighbour = otherNeighbour = 0;

        for ( j=0; j < (int)[list count]; j++ )
        {   VGraphic	*g2 = [list objectAtIndex:j];

            if ( j == i  || [g2 isKindOfClass:[VPath class]] ||
                ([g2 isKindOfClass:[VArc class]] && Abs([(VArc*)g2 angle]) == 360) ) /* can't be neighbour */
                continue;

            [g2 getPoint:0 :&s2];
            [g2 getPoint:3 :&e2];
            if ( !oneNeighbour )
                if ( SqrDistPoints(s1, s2) <= CLOSETOLERANCE || SqrDistPoints(s1, e2) <= CLOSETOLERANCE )
                    oneNeighbour++;
            if ( !otherNeighbour )
                if ( SqrDistPoints(e1, s2) <= CLOSETOLERANCE || SqrDistPoints(e1, e2) <= CLOSETOLERANCE )
                    otherNeighbour++;
            if ( oneNeighbour && otherNeighbour )
                break;
        }
        if ( !oneNeighbour || !otherNeighbour )
        {   [list removeObjectAtIndex:i];
            i--;
        }
    }
}

/* add graphics from splitList to list which are inside graphic
 * return YES if a graphic was added
 */
- (BOOL)addGraphics:(NSMutableArray*)splitList inside:(id)graphic toList:(NSMutableArray*)list
{   int		cnt, i, status=NO;
    NSPoint	p;

    cnt=[splitList count];
    for ( i=0 ; i<cnt ; i++ )
    {	VGraphic	*g = [splitList objectAtIndex:i];

        if ( [g isKindOfClass:[VPath class]] )
        {   [self addGraphics:[(VPath*)g list] inside:graphic toList:list];
            continue;
        }
        ( [g isKindOfClass:[VPath class]] ) ? [[[(VPath*)g list] objectAtIndex:0] getPoint:&p at:0.4] : [g getPoint:&p at:0.4];

        if ( [graphic isPointInside:p] )
        {   LONG	j, count=[list count];

            for ( j=0 ; j<count; j++ )
            {	VGraphic *gr=[list objectAtIndex:j];

                if ( [g identicalWith:gr] )
                    break;
            }
            /* add g only if is'nt allready in list */
            if ( j >= count )
            {	[g setColor:[[list objectAtIndex:0] color]];
                [list addObject:[[g copy] autorelease]];
                status=YES;
            }
        }
    }
    return status;
}

/* remove graphics in list witch are inside graphic
 * return YES if we have remove something
 */
- (BOOL)removeGraphics:(NSMutableArray*)list inside:(id)graphic
{   int		i, prevCnt;

    prevCnt = [list count];
    for (i=0; i<(int)[list count]; i++)
    {	VGraphic	*g = [list objectAtIndex:i];

        if ( [g isKindOfClass:[VPath class]] )
            [self removeGraphics:[(VPath*)g list] inside:graphic];
        else
        {   NSPoint	p;

            ( [g isKindOfClass:[VPath class]] ) ? [[[(VPath*)g list] objectAtIndex:0] getPoint:&p at:0.4] : [g getPoint:&p at:0.4];
            if ( [graphic isPointInside:p] )
            {
                [list removeObjectAtIndex:i];
                i--;
            }
        }
    }
    return ( prevCnt == (int)[list count] ) ? NO : YES;
}

/* return YES if cg is completly inside og
 */
- (BOOL)removePartsOf:(VGraphic**)curG hiddenBy:(id)og
{   int             i, iCnt, nothingRemoved = 0;
    VGraphic        *cg = *curG;
    VPath           *ng;
    NSMutableArray  *splitListOg = nil;
    NSPoint         *iPts;

    /* cg can't be inside a line or curve or part of arc */
    if ( !([og isKindOfClass:[VPath class]] && [og filled]) && !([og isKindOfClass:[VArc class]] && Abs([og angle]) == 360 && [og filled]) && !([og isKindOfClass:[VRectangle class]] && [og filled]) )
    {
        *curG = [[cg copy] autorelease];
        return NO;	/* cg will replace from new curG - in each case */
    }
    ng = [VPath path];
    [ng setColor:[cg color]];
    [ng setFilled:[cg filled]];
    [ng setWidth:[cg width]];
    [ng setSelected:[cg isSelected]];

    /* tile hiddenG from the otherG */
    if ( (iCnt = [cg getIntersections:&iPts with:og]) )
    {	NSMutableArray *splitList;

        if ( (splitList = [cg getListOfObjectsSplittedFrom:iPts :iCnt]) )
        {   for (i=0; i<(int)[splitList count]; i++)
                [[ng list] addObject:[[[splitList objectAtIndex:i] copy] autorelease]];
        }
    }
    if ( ![[ng list] count] )
    {	if ( [cg isKindOfClass:[VPath class]] )
            for (i=0; i<(int)[[(VPath*)cg list] count]; i++)
                [[ng list] addObject:[[[[(VPath*)cg list] objectAtIndex:i] copy] autorelease]];
        else
            [[ng list] addObject:[[cg copy] autorelease]];
    }

    /* when hiddenG is a line, curve or part of arc or an empty path
     */
    if ( ([cg isKindOfClass:[VPath  class]] && ![cg filled]) || [cg isKindOfClass:[VLine class]] ||
         ([cg isKindOfClass:[VArc   class]] && (Abs([cg angle]) != 360 || ![cg filled])) ||
          [cg isKindOfClass:[VCurve class]] || ([cg isKindOfClass:[VRectangle class]] && ![cg filled]) )
    {
        /* when hiddenG is not tiled we must only look if inside og */
        if ( [[ng list] count] == 1 )
        {   NSPoint	p;

            ( [cg isKindOfClass:[VPath class]] ) ? [[[(VPath*)cg list] objectAtIndex:0] getPoint:&p at:0.4] : [cg getPoint:&p at:0.4];
            if ( ![og isPointInside:p] )
            {   *curG = [[cg copy] autorelease];
                return NO;
            }
            return YES;
        }
        /* we must only remove the hidden tiles in splitListCg
         * cg will become a path with rest elements of splitListCg
         */
        else
        {
            [self removeGraphics:[ng list] inside:og];
            if ( [[ng list] count] )		/* ng is now curG */
            {
                *curG = [[ng copy] autorelease];
                return NO;
            }
            else
                return YES;	/* cg completly inside og */
        }
    }

    /* if cg is'nt tiled
     * the hiddenG (cg) is in the otherG or the otherG is in the hiddenG else -> FALSE
     */
    if ( ([cg isKindOfClass:[VPath class]] && [[ng list] count] == [[(VPath*)cg list] count]) ||
        ([cg isKindOfClass:[VArc class]] && [[ng list] count] == 1) )
    {	NSPoint	p;

        /* cg inside og - cg will removed */
        ( [cg isKindOfClass:[VPath class]] ) ? [[[(VPath*)cg list] objectAtIndex:0] getPoint:&p at:0.4] : [cg getPoint:&p at:0.4];
        if ( [og isPointInside:p] )
            return YES;
        /* og inside cg - add og to ng -> curG */
        ( [og isKindOfClass:[VPath class]] ) ? [[[(VPath*)og list] objectAtIndex:0] getPoint:&p at:0.4] : [og getPoint:&p at:0.4];
        if ( ([cg isKindOfClass:[VPath class]] || [cg isKindOfClass:[VArc class]]) && [(VPath*)cg isPointInside:p] )
        {
            if ( [og isKindOfClass:[VPath class]] )
                for (i=0; i<(int)[[(VPath*)og list] count]; i++)
                    [[ng list] addObject:[[[(VPath*)og list] objectAtIndex:i] copy]];	// add og elements to ng
            else
                [[ng list] addObject:[[og copy] autorelease]];	// add og to ng

            *curG = [[ng copy] autorelease];
        }
        else // graphics did not intersect - nothing to do but copy curG
            *curG = [[cg copy] autorelease];
        return NO;
    }

    /* go on */

    /* tile otherG from the hiddenG */
    if ( iCnt )
    {   splitListOg = [og getListOfObjectsSplittedFrom:iPts :iCnt];
        free(iPts);
    }
    if ( !splitListOg )
    {	splitListOg = [NSMutableArray allocWithZone:[self zone]];
        if ( [og isKindOfClass:[VPath class]] )
            for (i=0; i<(int)[[(VPath*)og list] count]; i++)
                [splitListOg addObject:[[[[(VPath*)og list] objectAtIndex:i] copy] autorelease]];
        else
            [splitListOg addObject:[[og copy] autorelease]];
    }

    /* now remove tiles of hiddenG which are inside or on otherG */
    if ( ![self removeGraphics:[ng list] inside:og] )
        nothingRemoved++;

    /* add tiles of otherG which are inside or on the hiddenG to ng */
    if ( ![self addGraphics:splitListOg inside:cg toList:[ng list]] )
    {	/* nothing added */
        /* everything removed -> remove the hiddenG */
        if ( ![[ng list] count] )
            return YES;
        else	/* something removed(from hiddenG) -> do nothing (ng will become curG) */
        {
            *curG = [[ng copy] autorelease];
            return NO;
        }
    }

    /* have to look if one element has'nt an element on each side
     * (distance to the element is'nt 0.02) then we remove it
     */
    [self removeSingleGraphicsInList:[ng list]];

    *curG = [[ng copy] autorelease];
    return NO;
}

@end
