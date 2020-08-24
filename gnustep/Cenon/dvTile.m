/* dvTile.m
 * DocView addition for batch production
 *
 * Copyright (C) 1996-2011 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1996-05-10
 * modified: 2011-09-08 (-setTileWithLimits:, -buildTileCopies: sort sequence from down to up to down)
 *           2008-07-24 (Prefs_IncrementSerial removed in -incrementSerialNumbers)
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
#include "TilePanel.h"
#include "TileObject.h"
#include "PreferencesMacros.h"

@implementation DocView(Tile)

- (NSMutableArray*)tileOriginList	{ return tileOriginList; }
- (BOOL)tileLimitSize			{ return tileLimitSize; }
- (NSPoint)tileDistance			{ return tileDistance; }
//- (NSPoint)useAbsoluteDistance		{ return useAbsoluteDistance; }
- (NSPoint)tileLimits			{ return tileLimits; }
//- (BOOL)mustMoveMasterToOrigin	{ return moveMasterToOrigin; }

- (int)numberOfTiles
{   int	xCnt, yCnt;

    if (tileLimitSize)
    {   NSRect	rect = [self tileBounds];

        xCnt = tileLimits.x / (rect.size.width  + tileDistance.x);
        yCnt = tileLimits.y / (rect.size.height + tileDistance.y);
    }
    else
    {
        xCnt = tileLimits.x;
        yCnt = tileLimits.y;
    }
    return xCnt * yCnt;
}


/*
 * limits    the size or number of items in x/y direction
 * distance  the distance between tiles
 *
 * modified: 2005-10-15
 */
- (void)setTileWithLimits:(NSPoint)limits
                limitSize:(BOOL)limitSize
                 distance:(NSPoint)dist
             moveToOrigin:(BOOL)moveToOrigin
{   NSRect	rect;
    int		l, x, xCnt, y, yCnt;
    BOOL	setDirty = NO;
    NSPoint	pOrigin = [origin pointWithNum:0], pMaster;

    if (tileDistance.x != dist.x || tileDistance.y != dist.y)
    {   setDirty = YES;
        tileDistance = dist;
    }
    if (tileLimits.x != limits.x || tileLimits.y != limits.y)
    {   setDirty = YES;
        tileLimits = limits;
    }
    if (tileLimitSize != limitSize)
    {   setDirty = YES;
        tileLimitSize = limitSize;
    }
    [self serialNumber];	// determine serial number
    rect = [self tileBounds];

    if (!tileLimits.x || !tileLimits.y)
    {
        [tileOriginList release];
        tileOriginList = nil;
        return;
    }

    [tileOriginList release];
    tileOriginList = [[NSMutableArray allocWithZone:[self zone]] init];

    /* move master to lower/left position
     */
    if ( moveToOrigin &&
         (rect.origin.x != tileDistance.x || rect.origin.y != tileDistance.y) )
    {	NSPoint	p;
        int	i;

        p.x = pOrigin.x - rect.origin.x;
        p.y = pOrigin.y - rect.origin.y;
        //p.x = tileDistance.x - rect.origin.x;
        //p.y = tileDistance.y - rect.origin.y;
        for (l=[layerList count]-1; l>=0; l--)
        {   NSMutableArray	*list = [[layerList objectAtIndex:l] list];

            if ( ![[layerList objectAtIndex:l] useForTile] )
                continue;
            for (i=[list count]-1; i>=0; i--)
                [[list objectAtIndex:i] moveBy:p];
        }
    }

    if (setDirty)
    {
        for ( l=[layerList count]-1; l>=0; l-- )
            if ( [[layerList objectAtIndex:l] useForTile] )
                [[layerList objectAtIndex:l] setDirty:YES];
        [document setDirty:YES];
    }

    /* create tileOriginList */
    pMaster = [self tileBounds].origin;
    xCnt = (int)(tileLimitSize) ? (limits.x/(rect.size.width  + tileDistance.x)) : limits.x;
    yCnt = (int)(tileLimitSize) ? (limits.y/(rect.size.height + tileDistance.y)) : limits.y;
    for ( x=0; x<xCnt; x++)
    {
        //for (y=0; y<yCnt; y++)
        for ( (Even(x)) ? (y=0) : (y=yCnt-1); (Even(x)) ? (y<yCnt) : (y>=0); (Even(x)) ? (y++) : (y--) )
        {   TileObject	*obj;
            NSPoint	p;

            obj = [[TileObject allocWithZone:[self zone]] autorelease];
            p.x = pMaster.x/*tileDistance.x*/ + x * (rect.size.width +tileDistance.x);
            p.y = pMaster.y/*tileDistance.y*/ + y * (rect.size.height+tileDistance.y);
            [obj setPosition:p];
            [tileOriginList addObject:obj];
        }
    }

    /* increase working area, if necessary */
    {   NSSize	size, frameSize = [self frame].size;

        size = NSMakeSize(xCnt*(rect.size.width +tileDistance.x), yCnt*(rect.size.height+tileDistance.y));
        [self setFrameSize:NSMakeSize(Max(frameSize.width,  size.width*scale),
                                      Max(frameSize.height, size.height*scale))];
    }

    [self drawAndDisplay];
}

- (void)removeTiles
{   int	l;

    for ( l=[layerList count]-1; l>=0; l-- )
        if ( [[layerList objectAtIndex:l] useForTile] )
            [[layerList objectAtIndex:l] setDirty:YES];
    [document setDirty:YES];

    [tileOriginList removeAllObjects];
    [tileOriginList release];
    tileOriginList = nil;

    [self drawAndDisplay];
}

/* modified: 2005-10-15
 */
- (void)buildTileCopies:(NSPoint)limits
              limitSize:(BOOL)limitSize
               distance:(NSPoint)dist
           moveToOrigin:(BOOL)moveToOrigin
{   NSRect		rect;
    int			i, iCnt, l, x, xCnt, y, yCnt, copyCnt = 1;
    NSMutableArray	*masterIndexes = [NSMutableArray array];
    NSPoint		pOrigin = [origin pointWithNum:0];

    tileDistance           = dist;
    //tileAbsoluteDistance   = absoluteDistance;
    tileLimits             = limits;
    tileLimitSize          = limitSize;
    //tileMoveMasterToOrigin = moveToOrigin;
    [self serialNumber];
    rect = [self tileBounds];

    [tileOriginList release];
    tileOriginList = nil;

    /* move master to lower/left position (crosshair origin)
     */
    if ( moveToOrigin &&
         (rect.origin.x != tileDistance.x || rect.origin.y != tileDistance.y) )
    {	NSPoint	p;

        p.x = pOrigin.x - rect.origin.x;
        p.y = pOrigin.y - rect.origin.y;
        //p.x = tileDistance.x - rect.origin.x;
        //p.y = tileDistance.y - rect.origin.y;
        for (l=[layerList count]-1; l>=0; l--)
        {   NSMutableArray	*list = [[layerList objectAtIndex:l] list];

            if ( ![[layerList objectAtIndex:l] useForTile] )
                continue;
            for (i=[list count]-1; i>=0; i--)
                [[list objectAtIndex:i] moveBy:p];
        }
    }

    [document setDirty:YES];

    /* remember master indexes */
    for (l=0; l<(int)[layerList count]; l++)
        [masterIndexes addObject:[NSNumber numberWithInt:[[[layerList objectAtIndex:l] list] count]]];

    xCnt = (int)(tileLimitSize) ? (limits.x/(rect.size.width  + tileDistance.x)) : limits.x;
    yCnt = (int)(tileLimitSize) ? (limits.y/(rect.size.height + tileDistance.y)) : limits.y;
    for ( x=0; x<xCnt; x++ )
    {
        //for ( y=0; y<yCnt; y++ )
        for ( (Even(x)) ? (y=0) : (y=yCnt-1); (Even(x)) ? (y<yCnt) : (y>=0); (Even(x)) ? (y++) : (y--) )
        {   NSPoint	p;

            if ( !x && !y )
                continue;
            p.x = x * (rect.size.width +tileDistance.x);
            p.y = y * (rect.size.height+tileDistance.y);
            for (l=[layerList count]-1; l>=0; l--)
            {   LayerObject	*layer = [layerList objectAtIndex:l];
                NSMutableArray	*slist = [slayList objectAtIndex:l];

                if ( ![[layerList objectAtIndex:l] useForTile] )
                    continue;
                for (i=0, iCnt=[[masterIndexes objectAtIndex:l] intValue]; i<iCnt; i++)
                {   id	g = [[[[layer list] objectAtIndex:i] copy] autorelease];

                    if ( [g respondsToSelector:@selector(isSerialNumber)] && [g isSerialNumber] )
                        [g incrementSerialNumberBy:copyCnt];
                    [g moveBy:p];
                    [layer addObjectWithoutCheck:g];	// faster
                    if ( [g isSelected] )
                        [slist addObject:g];
                }
            }
            copyCnt++;
        }
    }

    /* increase working area, if necessary */
    {   NSSize	size, frameSize = [self frame].size;

        size = NSMakeSize(xCnt*(rect.size.width +tileDistance.x), yCnt*(rect.size.height+tileDistance.y));
        [self setFrameSize:NSMakeSize(Max(frameSize.width,  size.width*scale),
                                      Max(frameSize.height, size.height*scale))];
    }

    if ( [self window] && [[self window] windowNumber] >= 0 )
        [self drawAndDisplay];
}

/* get the serial number
 */
- (id)serialNumber
{   int	l, i;

    serialNumber = nil;
    for (l=[layerList count]-1; l>=0; l--)
    {	NSMutableArray	*list = [[layerList objectAtIndex:l] list];

        if ( ![[layerList objectAtIndex:l] useForTile] )
            continue;
        for (i=[list count]-1; i>=0; i--)
        {   id	g = [list objectAtIndex:i];

            if ( [g respondsToSelector:@selector(isSerialNumber)] && [g isSerialNumber] )
            {	serialNumber = g;
                l = 0;
                break;
            }
        }
    }
    return serialNumber;
}

- (void)incrementSerialNumbers
{   int	cnt = 1;

    if (tileOriginList)
        cnt = [self numberOfTiles];

    [[self serialNumber] incrementSerialNumberBy:cnt];

    [document setDirty:YES];
    [self drawAndDisplay];
}

- (NSRect)tileBounds
{   int		l;
    NSRect	bRect = NSZeroRect, rect;

    tileSize.width = tileSize.height = 0.0;
    for (l=[layerList count]-1; l>=0; l--)
    {	NSMutableArray	*list = [[layerList objectAtIndex:l] list];

        if ( ![[layerList objectAtIndex:l] useForTile] )
            continue;
        rect = [self coordBoundsOfArray:list];
        if (rect.origin.x || rect.origin.y || rect.size.width || rect.size.height)
            bRect = (!bRect.size.width && !bRect.size.height) ? rect : VHFUnionRect(rect, bRect);
    }

    tileSize = bRect.size;
    return bRect;
}

@end
