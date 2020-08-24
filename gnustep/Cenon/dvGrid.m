/* dvGrid.m
 * Grid additions for Cenon DocView class
 *
 * Copyright (C) 1997-2012 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1997-11-05
 * modified: 2012-06-25 (display x10 grid even if x1 grid becomes too small)
 *           2012-02-13 (thicker line every 10 thin lines)
 *           2005-05-19 (line width set to 0.51)
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
#include "App.h"
#include "DocView.h"
#include "DocWindow.h"
#include "locations.h"
#include "functions.h"


@implementation DocView(Grid)

/* Methods to modify the grid of the GraphicView. */

- (void)drawGrid
{   VFloat  trueGridSpacing = gridSpacing;
    int     n = 10;

    if ( [self gridIsRelative] )
        trueGridSpacing = trueGridSpacing * [self resolution] * scale;
    if ( [self gridIsEnabled] && numGridRectsX && trueGridSpacing >= 1 )
    {   int     i, offX, offY;
        double  bigGridSpacing = gridSpacing * [self resolution] * n;   // larger grid (* 10)
        NSPoint pStart;

        /* fine grid */
        if ( trueGridSpacing >= 4 )
        {
            [[NSColor lightGrayColor] set];
            //[[NSColor colorWithDeviceRed:0.91 green:0.95 blue:1.0 alpha:1.0] set]; // light blue
            [NSBezierPath setDefaultLineWidth:(VHFIsDrawingToScreen() ? 1.0/scale : 0.1)];
            for ( i=0; i<numGridRectsX; i++ )
                [NSBezierPath strokeRect:gridListX[i]];
            for ( i=0; i<numGridRectsY; i++ )
                [NSBezierPath strokeRect:gridListY[i]];
        }

        /* we draw every n'th line stronger (centered at crosshair origin) */
        pStart = [self pointAbsolute:NSZeroPoint];   // this is the crosshair position
        pStart.x = pStart.x - floor(pStart.x / bigGridSpacing) * bigGridSpacing;
        pStart.y = pStart.y - floor(pStart.y / bigGridSpacing) * bigGridSpacing;
        for ( offX=0; offX < Min(n, numGridRectsX); offX++ )
            if ( gridListX[offX].origin.x + TOLERANCE >= pStart.x )
                break;
        for ( offY=0; offY < Min(n, numGridRectsY); offY++ )
            if ( gridListY[offY].origin.y + TOLERANCE >= pStart.y )
                break;
        [[NSColor grayColor] set];
        //[[NSColor colorWithDeviceRed:0.8 green:0.89 blue:1.0 alpha:1.0] set]; // light blue
        [NSBezierPath setDefaultLineWidth:(VHFIsDrawingToScreen() ? 1.0/scale : 0.1)];
        for ( i = offX; i < numGridRectsX; i += n ) // X
            [NSBezierPath strokeRect:gridListX[i]];
        for ( i = offY; i < numGridRectsY; i += n ) // Y
            [NSBezierPath strokeRect:gridListY[i]];
    }
}

- (void)setGridSpacing:(float)spacing
{
    if ( gridSpacing != spacing && spacing > 0 && spacing < 256 )
    {
        gridSpacing   = spacing;
        gridIsEnabled = YES;
        [self resetGrid];
        [self drawAndDisplay];
        [[self window] flushWindow];
    }
}

- (float)gridSpacing
{
    return gridSpacing;
}

- (void)toggleGrid:sender
{
    if ([sender respondsToSelector:@selector(tag)])
        [self setGridEnabled:[(NSMenuItem*)sender tag] ? YES : NO];
}

- (void)setGridEnabled:(BOOL)flag
{
    if (gridIsEnabled != flag)
    {
        gridIsEnabled = flag;
        if (flag)
            [self resetGrid];
        [self drawAndDisplay];
        [[self window] flushWindow];
    }
}

- (BOOL)gridIsEnabled
{
    return gridIsEnabled;
}

- (void)setGridUnit:(int)value
{
    if (gridUnit != value)
    {
        gridUnit = value;
        [self resetGrid];
        [self drawAndDisplay];
        [[self window] flushWindow];
    }
}

- (int)gridUnit
{
    return gridUnit;
}

/* relative unit (mm, inch, pt)
 */
- (BOOL)gridIsRelative;
{
    return (gridUnit > 3) ? NO : YES;
}

//#define GRID (gridIsEnabled ? (gridSpacing ? gridSpacing : 1.0) : 1.0)
#define GRID (gridIsEnabled ? (([self gridIsRelative]) ? gridSpacing*[self resolution] \
                                                       : gridSpacing/scale) : 1.0)
/*#define grid(point) \
	{ (point).x = floor(((point).x / GRID) + 0.5) * GRID; \
	  (point).y = floor(((point).y / GRID) + 0.5) * GRID; }*/

/* grid spacing including scale
 */
- (float)grid
{
    return GRID;
}

/* return closest point on grid
 */
- (NSPoint)grid:(NSPoint)p
{
    if ( gridIsEnabled )
    {   float	grid = GRID;

        p = [self pointRelativeOrigin:p];
        p.x = floor((p.x / grid) + 0.5) * grid;
        p.y = floor((p.y / grid) + 0.5) * grid;
        p = [self pointAbsolute:p];
    }
    return p;
}

/*
 * converts a value from internal unit to the current unit
 */
- (float)resolution
{
    switch ( gridUnit )
    {
        case UNIT_MM:    return 72.0/25.4;
        case UNIT_INCH:  return 72.0;
        case UNIT_POINT: return 1.0;
    }
    return 1.0;
}

/* we maintain a list of rectangles representing the horicontal and vertical lines of the grid.
 * We use Rectangles because they usually draw faster than lines
 */
- (void)resetGrid
{   int		x, y, i;
    float	w, h, res = [self resolution], relGrid;
    NSZone	*zone = [self zone];
    NSRect	bounds = [self bounds];
    NSPoint	p, offset;	// start offset for grid
    BOOL	gridIsRelative = [self gridIsRelative];

    if ( (!gridIsRelative && gridSpacing < 1) || (gridIsRelative && gridSpacing*res*scale < 1) )
        return;

    relGrid = (gridIsRelative) ? gridSpacing*res : gridSpacing/scale;

    x = (int)bounds.size.width  / relGrid;
    y = (int)bounds.size.height / relGrid;
    numGridRectsX = x + 1;
    numGridRectsY = y + 1;
    if (gridListX)
    {   NSZoneFree(zone, gridListX);
        NSZoneFree(zone, gridListY);
    }
    gridListX = NSZoneMalloc(zone, (numGridRectsX+2) * sizeof(NSRect));
    gridListY = NSZoneMalloc(zone, (numGridRectsY+2) * sizeof(NSRect));
    w = bounds.size.width;
    h = bounds.size.height;

    p = [self pointAbsolute:NSZeroPoint];
    offset.x = p.x - floor(p.x / relGrid) * relGrid;
    offset.y = p.y - floor(p.y / relGrid) * relGrid;

    for (i = 0; i <= y; i++)
    {
        gridListY[i].origin.x = 0.0;
        gridListY[i].origin.y = offset.y + i * relGrid;
        gridListY[i].size.width  = w;
        gridListY[i].size.height = 0.0;
    }
    for (i = 0; i <= x; i++)
    {
        gridListX[i].origin.x = offset.x + i * relGrid;
        gridListX[i].origin.y = 0.0;
        gridListX[i].size.width  = 0.0;
        gridListX[i].size.height = h;
    }
}

@end
