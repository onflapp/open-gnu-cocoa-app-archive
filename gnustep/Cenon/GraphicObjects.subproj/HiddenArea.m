/* HiddenArea.m
 * Object for calculation of hidden areas
 *
 * Copyright (C) 1996-2006 by vhf interservice GmbH
 * Author:   Ilonka Fleischmann
 *
 * created:  1996-09-24
 * modified: 2006-11-07
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
#include "../App.h"
#include "../Graphics.h"
#include "HiddenArea.h"

/* Private methods
*/
@interface HiddenArea(PrivateMethods)
- (void)optimizeList:(NSMutableArray*)list;
- (BOOL)addGraphics:(NSMutableArray*)splitList inside:(id)graphic toList:(NSMutableArray*)list;
- (BOOL)removePartsOf:(VGraphic**)curG hiddenBy:(VGraphic*)og;
@end

@implementation HiddenArea

/* remove parts of graphic objects coverd by other graphics
 * first graphic in list is covered by all following graphics in list etc.
 * modified: 2006-06-07
 */
- (void)removeHiddenAreas:(NSMutableArray*)list
{   long	c, o;

    if ( ![list count] )
        return;

    /* beginning with the first graphic
     */
    for ( c=0; c < (int)[list count]-1; c++ )
    {	VGraphic    *cg = [list objectAtIndex:c];
        NSColor     *cColor = [[cg color] colorUsingColorSpaceName:@"NSCalibratedRGBColorSpace"];
        NSColor     *cFillColor=nil, *oFillColor=nil, *cEndColor=nil, *oEndColor=nil;
        NSRect      cBounds;
        float       cw = [cg width], ow;
        int         cf = 0, of = 0;
        int         ic=0, icCnt = 1;

        if ( [cg isKindOfClass:[VText class]] || [cg isKindOfClass:[VTextPath class]] )
            continue;	// skip text	// FIXME: convert text to path

        /* group must be in it self removeHiddenAreas */
        if ( [cg isKindOfClass:[VGroup class]] )
        {   VGroup	*grp = [VGroup group];
            int		i, gCnt = [[(VGroup*)cg list] count];

            for (i=0; i< gCnt; i++)
                [grp addObject:[[(VGroup*)cg list] objectAtIndex:i]];

            [list removeObjectAtIndex:c];
            [list insertObject:grp atIndex:c];
            cg = [list objectAtIndex:c];

            [self removeHiddenAreas:[(VGroup*)cg list]];
        }

        if ([cg isKindOfClass:[VGroup class]])
            icCnt = [(VGroup*)cg countRecursive]; // [[cg list] count];

        for (ic=0; ic < icCnt; ic++)
        {   VGraphic    *icg = cg;

            if ([cg isKindOfClass:[VGroup class]])
                icg = [(VGroup*)cg recursiveObjectAtIndex:ic]; // [[cg list] objectAtIndex:ic];

            if ( [icg isKindOfClass:[VText class]] || [icg isKindOfClass:[VTextPath class]] )
                continue;	// skip text	// FIXME: convert text to path

            if ([icg respondsToSelector:@selector(fillColor)])
            {
                cf = [icg filled];
                cFillColor = [[(VPath*)icg fillColor] colorUsingColorSpaceName:@"NSCalibratedRGBColorSpace"];
                cEndColor  = [[(VPath*)icg endColor] colorUsingColorSpaceName:@"NSCalibratedRGBColorSpace"];
            }

            cBounds = [icg bounds];

            /* look if the cg lies under one of the other (o) graphics
             * if the two graphics has the same colour they will be united later !
             * else: the hidden areas of the hidden graphic will be removed or the hole hiddenG
             */
            for ( o=c+1; o < (int)[list count]; o++ )
            {   VGraphic    *og = [list objectAtIndex:o];
                NSRect      oBounds;
                int         io=0, ioCnt = 1;

                if ( [og isKindOfClass:[VText class]] || [og isKindOfClass:[VTextPath class]] )
                    continue;	// skip text	// FIXME: convert text to path
/*                {   id	txtGr = [og pathRepresentation];

                    [list removeObjectAtIndex:o];
                    [list insertObject:txtGr atIndex:o];
                    og = [list objectAtIndex:o];
                } // konvertiert text in pfad ist dann aber definitiv ein Pfad !!!???
*/
                if ([og isKindOfClass:[VGroup class]])
                    ioCnt = [(VGroup*)og countRecursive]; // [[og list] count];

                for (io=0; io < ioCnt; io++)
                {   VGraphic	*iog = og;

                    if ([og isKindOfClass:[VGroup class]])
                        iog = [(VGroup*)og recursiveObjectAtIndex:io]; // [[og list] objectAtIndex:io];

                    if ( [iog isKindOfClass:[VText class]] || [iog isKindOfClass:[VTextPath class]] )
                        continue;	// skip text	// FIXME: convert text to path

                    oBounds = [iog bounds];
                    
            //if ( !NSIsEmptyRect(NSIntersectionRect(cBounds , oBounds)) )
                    if (vhfIntersectsRect(cBounds , oBounds))
                    {   NSColor	*oColor = [[iog color] colorUsingColorSpaceName:@"NSCalibratedRGBColorSpace"];

                        of = 0;
                        ow = [iog width];
                        if ([iog respondsToSelector:@selector(fillColor)])
                        {
                            of = [iog filled];
                            oFillColor = [[(VPath*)iog fillColor] colorUsingColorSpaceName:@"NSCalibratedRGBColorSpace"];
                            oEndColor  = [[(VPath*)iog endColor] colorUsingColorSpaceName:@"NSCalibratedRGBColorSpace"];
                        }

                        if (!(((((cw && cw == ow) || (!cw && !ow && !cf && !of)) && [cColor isEqual:oColor]) ||
                               (!cw && !ow && cf && cf == of)) &&
                              ((cf >= 1 && cf == of && [cFillColor isEqual:oFillColor]) || (!cf && !of)) && // fillColors
                              ((cf > 1 && cf == of && [cEndColor isEqual:oEndColor]) || (cf <= 1 && cf == of)))) // endColors
//                if ( ![cColor isEqual:oColor] )
                        {
                            if ( [self removePartsOf:&icg hiddenBy:iog] )
                            {	/* if the hidden graphic is in the iog we remove the hiddenG */

                                if ([cg isKindOfClass:[VGroup class]])
                                {   [(VGroup*)cg recursiveRemoveObjectAtIndex:ic]; // [[cg list] removeObjectAtIndex:ic];
                                    icCnt--;
                                    ic--;
                                }
                                else
                                {   [list removeObjectAtIndex:c];  /* cg is oldCg */;
                                    c--;
                                    cg = nil;
                                }
                                break;
                            }
                            if ([cg isKindOfClass:[VGroup class]])
                            {   [(VGroup*)cg recursiveRemoveObjectAtIndex:ic];      // [[cg list] removeObjectAtIndex:ic];
                                [(VGroup*)cg recursiveInsertObject:icg atIndex:ic]; // [[cg list] insertObject:icg atIndex:ic];
                            }
                            else
                            {   [list removeObjectAtIndex:c];
                                [list insertObject:icg atIndex:c];	/* is a new cg */
                                cg = icg = [list objectAtIndex:c];
                            }
                        }
                    }
                }
            }
        }
        if ([cg isKindOfClass:[VGroup class]] && ![(VGroup*)cg countRecursive])
        {
            [list removeObjectAtIndex:c];
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
    for ( c=0 ; c < (int)[list count] ; c++ )
    {   NSAutoreleasePool	*pool;
        VGraphic            *cg = [list objectAtIndex:c];
        NSColor             *cColor;
        NSColor             *cFillColor=nil, *oFillColor=nil, *cEndColor=nil, *oEndColor=nil;
        float               cw = [cg width], ow;
        int                 cf = 0, of = 0;
        NSRect              cBounds;
        int                 ic=0, icCnt = 1;

        /* lines, curves, full/unfilled arcs or unfilled paths can't be united */
        if ( [cg isKindOfClass:[VLine class]] || [cg isKindOfClass:[VCurve class]] ||
             ([cg isKindOfClass:[VArc class]] && (Abs([(VArc*)cg angle]) != 360.0 || ![cg filled])) ||
             ([cg isKindOfClass:[VPath class]] && ![cg filled]) ||
             ([cg isKindOfClass:[VPolyLine class]] && ![cg filled]) ||
             ([cg isKindOfClass:[VRectangle class]] && ![cg filled]) )
            continue;

        /* group must be in it self united */
        if ( [cg isKindOfClass:[VGroup class]] )
        {   VGroup	*grp = [[cg copy] autorelease];

            [list removeObjectAtIndex:c];
            [list insertObject:grp atIndex:c];
            cg = [list objectAtIndex:c];

            [self uniteAreas:[(VGroup*)cg list]];
        }

        if ([cg isKindOfClass:[VGroup class]])
            icCnt = [(VGroup*)cg countRecursive]; // [[cg list] count];

        for (ic=0; ic < icCnt; ic++)
        {   id	icg = cg;

            if ([cg isKindOfClass:[VGroup class]])
            {   icg = [(VGroup*)cg recursiveObjectAtIndex:ic]; // [[cg list] objectAtIndex:ic];
                prevCnt = icCnt;
            }
            else
                prevCnt = [list count];

            cColor = [[icg color] colorUsingColorSpaceName:@"NSCalibratedRGBColorSpace"];
            if ([icg respondsToSelector:@selector(fillColor)])
            {
                cf = [icg filled];
                cFillColor = [[(VPath*)icg fillColor] colorUsingColorSpaceName:@"NSCalibratedRGBColorSpace"];
                cEndColor  = [[(VPath*)icg endColor] colorUsingColorSpaceName:@"NSCalibratedRGBColorSpace"];
            }

            pool = [NSAutoreleasePool new];
            
//prevCnt = [list count];
            cBounds = [icg bounds];

            for ( o=c+1; o < (int)[list count]; o++ )
            {   NSAutoreleasePool	*pool1;
                id			og = [list objectAtIndex:o];
                NSRect			oBounds;
                BOOL			setcColorsNew = NO;
                int			io=0, ioCnt = 1;

                if ( [og isKindOfClass:[VLine class]] || [og isKindOfClass:[VCurve class]] ||
                     ([og isKindOfClass:[VArc class]] && (Abs([(VArc*)og angle]) != 360.0 || ![og filled])) ||
                     ([og isKindOfClass:[VPath class]] && ![og filled]) ||
                     ([og isKindOfClass:[VPolyLine class]] && ![og filled]) ||
                     ([og isKindOfClass:[VRectangle class]] && ![og filled]) )
                    continue;

                if ([og isKindOfClass:[VGroup class]])
                {   VGroup	*grp = [[og copy] autorelease];

                    [list removeObjectAtIndex:o];
                    [list insertObject:grp atIndex:o];
                    og = [list objectAtIndex:o];

                    ioCnt = [og countRecursive]; // [[og list] count];
                }

                for (io=0; io < ioCnt; io++)
                {   VGraphic	*iog = og;

                    if ([og isKindOfClass:[VGroup class]])
                        iog = [og recursiveObjectAtIndex:io]; // [[og list] objectAtIndex:io];

                    oBounds = [iog bounds];
                    pool1 = [NSAutoreleasePool new];

                    if (vhfIntersectsRect(cBounds , oBounds))
                    {   NSColor		*oColor = [[og color] colorUsingColorSpaceName:@"NSCalibratedRGBColorSpace"];
                        VGraphic	*ng;

                        of = 0;
                        ow = [iog width];
                        if ([iog respondsToSelector:@selector(fillColor)])
                        {
                            of = [iog filled];
                            oFillColor = [[(VPath*)iog fillColor]
                                                      colorUsingColorSpaceName:@"NSCalibratedRGBColorSpace"];
                            oEndColor  = [[(VPath*)iog endColor]
                                                      colorUsingColorSpaceName:@"NSCalibratedRGBColorSpace"];
                        }

                        if ((((((cw && cw == ow) || (!cw && !ow && !cf && !of)) && [cColor isEqual:oColor]) ||
                              (!cw && !ow && cf && cf == of)) &&
                             ((cf >= 1 && cf == of && [cFillColor isEqual:oFillColor]) || (!cf && !of)) && // fillCol
                             ((cf > 1 && cf == of && [cEndColor isEqual:oEndColor]) || (cf <= 1 && cf == of))) && //end
                            (ng = [icg uniteWith:iog]))
//                	if ( [cColor isEqual:oColor] && (ng = [icg uniteWith:iog]) )
                        {
                            if ([cg isKindOfClass:[VGroup class]])
                            {
                                [(VGroup*)cg recursiveRemoveObjectAtIndex:ic];
                                [(VGroup*)cg recursiveInsertObject:ng atIndex:ic];
                                if ([og isKindOfClass:[VGroup class]])
                                {   [og recursiveRemoveObjectAtIndex:io];
                                    io--;
                                }
                                else
                                {   [list removeObjectAtIndex:o]; // if the graphics are united we remove the og
                                    o--;
                                }
                                icg = [(VGroup*)cg recursiveObjectAtIndex:ic];
                                cBounds = [icg bounds];
                                /* cg will be removed perhaps -> we must set the c colors new !!!! */
                                setcColorsNew = YES;
                            }
                            else
                            {
                                [list removeObjectAtIndex:c];
                                [list insertObject:ng atIndex:c];
                                if ([og isKindOfClass:[VGroup class]])
                                {   [og recursiveRemoveObjectAtIndex:io];
                                    io--;
                                }
                                else
                                {   [list removeObjectAtIndex:o]; // if the graphics are united we remove the og
                                    o--;
                                }
                                cg = icg = [list objectAtIndex:c];
                                cBounds = [icg bounds];
                                /* cg will be removed perhaps -> we must set the c colors new !!!! */
                                setcColorsNew = YES;
                            }
                        }
                    }
                    [pool1 release];
                    if (setcColorsNew)
                    {   cColor = [[icg color] colorUsingColorSpaceName:@"NSCalibratedRGBColorSpace"];
                        if ([icg respondsToSelector:@selector(fillColor)])
                        {
                            cf = [icg filled];
                            cFillColor = [[(VPath*)icg fillColor]
                                                       colorUsingColorSpaceName:@"NSCalibratedRGBColorSpace"];
                            cEndColor  = [[(VPath*)icg endColor]
                                                       colorUsingColorSpaceName:@"NSCalibratedRGBColorSpace"];
                        }
                    }
                }
            }
            /* if there is only one graphic left after uniting cg
                * (is this also true for the last in list?) we do not optimize -> need c < [list count]-1
                */
            if ( [cg isKindOfClass:[VGroup class]] && prevCnt != icCnt && ic < icCnt-1 && ic != -1 )
                ic--;
            else if ( ![cg isKindOfClass:[VGroup class]] && prevCnt != (int)[list count] && c < (int)[list count]-1 )
            {   if ( c != -1 )
                    c--;
            }
            else if ( [cg isKindOfClass:[VGroup class]] && [icg isKindOfClass:[VPath class]] )
                [icg optimizeList:[(VPath*)icg list]];
            else if ( ![cg isKindOfClass:[VGroup class]] && [[list objectAtIndex:c] isKindOfClass:[VPath class]] )
                /* optimize list only once for each united graphic */
            //[self optimizeList:[(VPath*)[list objectAtIndex:c] list]];
                [[list objectAtIndex:c] optimizeList:[(VPath*)[list objectAtIndex:c] list]];

            [pool release];
        }
    }
}

#define CLOSETOLERANCE (TOLERANCE*50.0)*(TOLERANCE*50.0) // 0.0009

/* optimize list
 */
- (void)optimizeList:(NSMutableArray*)list
{   long	i1, i2,  changeIndex=1, cnt=[list count], startIndex = 0;
    float	startDist=MAXCOORD, distS, distE;
    NSPoint	e1, s2, e2;

    if (!cnt)
        return;

    for ( i1 = 0 ; i1 < (cnt-1)  ; i1++ )
    {	VGraphic	*g1=[list objectAtIndex:i1];

        if ( [g1 isKindOfClass:[VPath class]] )
        {	[self optimizeList:[(VPath*)g1 list]];
            e1 = [[[(VPath*)g1 list] objectAtIndex:0] pointWithNum:MAXINT];
        }
        else
            e1 = [g1 pointWithNum:MAXINT];

        for ( i2 = i1+1 ; i2 < cnt ; i2++ )
        {   VGraphic	*g2=[list objectAtIndex:i2];

            if ( [g2 isKindOfClass:[VPath class]] )
            {	s2 = [[[(VPath*)g2 list] objectAtIndex:0] pointWithNum:0];
                e2 = s2;
            }
            else
            {	s2 = [g2 pointWithNum:0];
                e2 = [g2 pointWithNum:MAXINT];
            }
            distS = SqrDistPoints(e1, s2);	distE = SqrDistPoints(e1, e2);

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
        if ( startDist ) /* close hole */
        {   VGraphic	*g2 = [list objectAtIndex:changeIndex];
            float	d;

            s2 = [g2 pointWithNum:0];
            if ( (d=SqrDistPoints(e1, s2)) > TOLERANCE && d <= CLOSETOLERANCE)
            {   VGraphic	*lineG = [VLine line];

                [lineG setColor:[g2 color]]; [lineG setWidth:[g2 width]]; [lineG setSelected:NO];
                [(VLine*)lineG setVertices:e1 :s2];
                [list insertObject:lineG atIndex:i1+1];
                i1 += 1; changeIndex += 1;
            }
            else
            {   VGraphic	*g3 = [list objectAtIndex:startIndex];
                float		d3 = SqrDistPoints(e1, [g3 pointWithNum:0]);

                if (d3 > TOLERANCE && d3 < d && d3 <= CLOSETOLERANCE) // close to startG
                {   VGraphic	*lineG = [VLine line];

                    [lineG setColor:[g2 color]]; [lineG setWidth:[g2 width]]; [lineG setSelected:NO];
                    [(VLine*)lineG setVertices:e1 :[g3 pointWithNum:0]];
                    [list insertObject:lineG atIndex:i1+1];
                    i1 += 1; changeIndex += 1;
                    startIndex = i1+1;
                }
                else if (d3 < d && d <= CLOSETOLERANCE)
                    startIndex = i1+1;
            }
            if ( startDist > CLOSETOLERANCE )
                startIndex = i1+1;
        }
        /* if the nearest element is not the next_in_list
            */
        if ( changeIndex != (i1 + 1) )	/* changeIndex graphic get place after i1 -> i1+1 */
        {   [list insertObject:[list objectAtIndex:changeIndex] atIndex:i1+1];
            [list removeObjectAtIndex:changeIndex+1];
        }

        startDist = MAXCOORD;
    }
    /* close hole from last to start element */
    {   VGraphic	*g1=[list objectAtIndex:(int)[list count]-1];
        VGraphic 	*g2= [list objectAtIndex:startIndex];
        float		d = SqrDistPoints([g1 pointWithNum:MAXINT], [g2 pointWithNum:0]);

        if (d > TOLERANCE && d <= CLOSETOLERANCE) // close to startG
        {   VGraphic	*lineG = [VLine line];

            [lineG setColor:[g2 color]]; [lineG setWidth:[g2 width]]; [lineG setSelected:NO];
            [(VLine*)lineG setVertices:[g1 pointWithNum:MAXINT] :[g2 pointWithNum:0]];
            [list addObject:lineG];
        }
    }
}

/* remove graphics from list which has only one neighbour
 */
- (void)removeSingleGraphicsInList:(NSMutableArray*)list :(NSRect)rect
{   int			oneNeighbour=0, otherNeighbour=0;
    long		i, j;
    //NSRect		tRect = NSInsetRect(rect, -TOLERANCE*5.0, -TOLERANCE*5.0);
    NSAutoreleasePool	*pool = [NSAutoreleasePool new];
    float		singleDist = (5.0*TOLERANCE)*(5.0*TOLERANCE);

    for ( i=0; i < (int)[list count]; i++ )
    {   VGraphic	*g1 = [list objectAtIndex:i];
        NSPoint		s1, e1, s2, e2; ;

        /* paths and full arcs must not remove */
        if ( [g1 isKindOfClass:[VPath class]] )
        {
            [self removeSingleGraphicsInList:[(VPath*)g1 list] :rect];
            continue;
        }
        if ( ([g1 isKindOfClass:[VArc class]] && Abs([(VArc*)g1 angle]) == 360)
             || [g1 isKindOfClass:[VRectangle class]]
             || ([g1 isKindOfClass:[VPolyLine class]] && [g1 filled]) )
            continue;

        /* count the neightbours if we have one neightbour we searching only for the other neightbour
         */
        s1 = [g1 pointWithNum:0]; e1 = [g1 pointWithNum:MAXINT];
        oneNeighbour = otherNeighbour = 0;

        //if (!NSPointInRect(s1, tRect) && !NSPointInRect(e1, tRect))
        if (!NSPointInRect(s1, rect) && !NSPointInRect(e1, rect))
            continue;

        for ( j=0 ; j < [list count] ; j++ )
        {   VGraphic	*g2 = [list objectAtIndex:j];

            if ( j == i  || [g2 isKindOfClass:[VPath class]] || [g2 isKindOfClass:[VRectangle class]]
                 || ([g2 isKindOfClass:[VArc class]] && Abs([(VArc*)g2 angle]) == 360)
                 || ([g2 isKindOfClass:[VPolyLine class]] && [g2 filled]) ) // can't be neighbour
                continue;

            s2 = [g2 pointWithNum:0];
            e2 = [g2 pointWithNum:MAXINT];
            if ( !oneNeighbour )
                if ( SqrDistPoints(s1, s2) <= singleDist || SqrDistPoints(s1, e2) <= singleDist )
                    oneNeighbour++;
            if ( !otherNeighbour )
                if ( SqrDistPoints(e1, s2) <= singleDist || SqrDistPoints(e1, e2) <= singleDist )
                    otherNeighbour++;
            if ( oneNeighbour && otherNeighbour )
                break;
        }
        if ( !oneNeighbour || !otherNeighbour )
        {   [list removeObjectAtIndex:i];
            i--;
        }
    }
    [pool release];
}

/* add graphics from splitList to list which are inside graphic
 * return YES if a graphic was added
 * modified: 2006-06-07 (respondsToSelector:)
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

        if ( [graphic respondsToSelector:@selector(isPointInside:)] && [graphic isPointInside:p] )
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
{   int			i, prevCnt;
    NSAutoreleasePool	*pool = [NSAutoreleasePool new];

    prevCnt = [list count];
    for (i=0; i<(int)[list count]; i++)
    {	VGraphic	*g = [list objectAtIndex:i];

        if ( [g isKindOfClass:[VPath class]] )
        {   [self removeGraphics:[(VPath*)g list] inside:graphic];
            // hole path is removed
            if ( ![[(VPath*)g list] count] )
            {
                [list removeObjectAtIndex:i];
                i--;
            }
        }
        else if ( [g isKindOfClass:[VGroup class]] )
        {   [self removeGraphics:[(VGroup*)g list] inside:graphic];
            // hole path is removed
            if ( ![[(VGroup*)g list] count] )
            {
                [list removeObjectAtIndex:i];
                i--;
            }
        }
        else
        {   NSPoint	p;

            p = ( [g isKindOfClass:[VPath class]] ) ? [[[(VPath*)g list] objectAtIndex:0] pointAt:0.4]
                                                    : [g pointAt:0.4];
            if ( [graphic isPointInside:p] )
            {
                [list removeObjectAtIndex:i];
                i--;
            }
        }
    }
    [pool release];
    return ( prevCnt == (int)[list count] ) ? NO : YES;
}

/* remove graphics in list witch are outside graphic
 * return YES if we have remove something
 */
- (BOOL)removeGraphics:(NSMutableArray*)list outside:(id)graphic
{   int		i, prevCnt;

    prevCnt = [list count];
    for (i=0; i<(int)[list count]; i++)
    {	VGraphic	*g = [list objectAtIndex:i];

        if ( [g isKindOfClass:[VPath class]] )
        {   [self removeGraphics:[(VPath*)g list] outside:graphic];
            // hole VGroup is removed
            if ( ![[(VPath*)g list] count] )
            {
                [list removeObjectAtIndex:i];
                i--;
            }
        }
        else if ( [g isKindOfClass:[VGroup class]] )
        {   [self removeGraphics:[(VGroup*)g list] outside:graphic];
            // hole VGroup is removed
            if ( ![[(VGroup*)g list] count] )
            {
                [list removeObjectAtIndex:i];
                i--;
            }
        }
        else
        {   NSPoint	p;

            ( [g isKindOfClass:[VPath class]] ) ? [[[(VPath*)g list] objectAtIndex:0] getPoint:&p at:0.4]
                                                : [g getPoint:&p at:0.4];
            if ( ![graphic isPointInsideOrOn:p] )
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
    if ( !([og isKindOfClass:[VPath class]] && [og filled]) && !([og isKindOfClass:[VArc class]] && Abs([og angle]) == 360 && [og filled]) && !([og isKindOfClass:[VRectangle class]] && [og filled]) && !([og isKindOfClass:[VPolyLine class]] && [og filled]) )
    {
        *curG = [[cg copy] autorelease];
        return NO;	/* cg will replace from new curG - in each case */
    }
    ng = [VPath path];
    [ng setColor:[cg color]];
    if ([cg respondsToSelector:@selector(fillColor)])
    {   [ng setFillColor:    [(VPath*)cg fillColor]];
        [ng setEndColor:     [(VPath*)cg endColor]];
        [ng setRadialCenter: [(VPath*)cg radialCenter]];
        [ng setStepWidth:    [(VPath*)cg stepWidth]];
        [ng setGraduateAngle:[(VPath*)cg graduateAngle]];
    }
    [ng setFilled:[cg filled] optimize:NO];
    [ng setWidth:[cg width]];
    [ng setSelected:[cg isSelected]];

    /* tile hiddenG from the otherG */
    if ( (iCnt = [cg getIntersections:&iPts with:og]) )
    {	NSMutableArray *splitList;

        if ( (splitList = [cg getListOfObjectsSplittedFrom:iPts :iCnt]) )
        {
            [ng setList:splitList optimize:NO];
            //for (i=0; i<[splitList count]; i++)
            //    [[ng list] addObject:[[[splitList objectAtIndex:i] copy] autorelease]];
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
    if ( ([cg isKindOfClass:[VPath class]] && ![cg filled]) || [cg isKindOfClass:[VLine class]] ||
         ([cg isKindOfClass:[VArc class]] && (Abs([cg angle]) != 360 || ![cg filled])) ||
         [cg isKindOfClass:[VCurve class]] || ([cg isKindOfClass:[VRectangle class]] && ![cg filled]) ||
         ([cg isKindOfClass:[VPolyLine class]] && ![cg filled]) )
    {
        if (iCnt) free(iPts);
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
            if ( [[ng list] count] )	// ng is now curG
            {
                if ( [[ng list] count] == 1 )	// ng is now curG
                    *curG = [[[[ng list] objectAtIndex:0] copy] autorelease];
                else
                    *curG = [[ng copy] autorelease];
                return NO;
            }
            else
                return YES;		// cg completly inside og
        }
    }

    /* if cg is'nt tiled
     * the hiddenG (cg) is in the otherG or the otherG is in the hiddenG else -> FALSE
     */
    if ( ([cg isKindOfClass:[VPath class]] && [[ng list] count] == [[(VPath*)cg list] count]) ||
        ([cg isKindOfClass:[VArc class]] && [[ng list] count] == 1) ||
        ([cg isKindOfClass:[VRectangle class]] && [[ng list] count] == 1) ||
        ([cg isKindOfClass:[VPolyLine class]] && [[ng list] count] == 1) )
    {	NSPoint	p;

        if (iCnt) free(iPts);
        /* cg inside og - cg will removed
        */
        ( [cg isKindOfClass:[VPath class]] ) ? [[[(VPath*)cg list] objectAtIndex:0] getPoint:&p at:0.4] : [cg getPoint:&p at:0.4];
        if ( [og isPointInside:p] )
            return YES;
        /* og inside cg - add og to ng -> curG
         */
        ( [og isKindOfClass:[VPath class]] ) ? [[[(VPath*)og list] objectAtIndex:0] getPoint:&p at:0.4] : [og getPoint:&p at:0.4];
        if ( ([cg isKindOfClass:[VPath class]] || [cg isKindOfClass:[VArc class]] ||
              [cg isKindOfClass:[VRectangle class]] || [cg isKindOfClass:[VPolyLine class]]) && [(VRectangle*)cg isPointInside:p] )
        {
            if ( [og isKindOfClass:[VPath class]] )
                for (i=0; i<(int)[[(VPath*)og list] count]; i++)
                    [[ng list] addObject:[[[(VPath*)og list] objectAtIndex:i] copy]];	// add og elements to ng
            else
                [[ng list] addObject:[[og copy] autorelease]];	// add og to ng

            *curG = [[ng copy] autorelease];
        }
        else /* graphics did not intersect - nothing to do but copy curG */
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
    [self removeSingleGraphicsInList:[ng list] :[og bounds]];

    *curG = [[ng copy] autorelease];
    return NO;
}

@end
