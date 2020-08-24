/* GerberImportSub.m
 * Subclass of Gerber-import managing the creation of graphic objects
 *
 * Copyright (C) 1996-2008 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1996-05-03
 * modified: 2003-06-26
 *
 * This file is part of the vhf Import Library.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the vhf Public License as
 * published by the vhf interservice GmbH. Among other things,
 * the License requires that the copyright notices and this notice
 * be preserved on all copies.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the vhf Public License for more details.
 *
 * You should have received a copy of the vhf Public License along
 * with this library; see the file LICENSE. If not, write to vhf.
 *
 * If you want to link this library to your proprietary software,
 * or for other uses which are not covered by the definitions
 * laid down in the vhf Public License, vhf also offers a proprietary
 * license scheme. See the vhf internet pages or ask for details.
 *
 * vhf interservice GmbH, Im Marxle 3, 72119 Altingen, Germany
 * eMail: info@vhf.de
 * http://www.vhf.de
 */

#include <ctype.h>
#include <VHFShared/vhfCommonFunctions.h>
#include <VHFShared/types.h>
#include "GerberImportSub.h"
#include "Graphics.h"
#include "GraphicObjects.subproj/HiddenArea.h"

@implementation GerberImportSub

/* allocate a list
 */
- allocateList
{
    return [[NSMutableArray allocWithZone:[self zone]] init];
}

- (void)removeClearLayers:bList
{   int		i;
    NSColor	*whiteColor = [NSColor colorWithCalibratedRed:1.0 green:1.0 blue:1.0 alpha:1.0];

    [[[HiddenArea new] autorelease] removeHiddenAreas:bList];

    for (i=(int)[(NSArray*)bList count]-1; i>=0; i--)
    {	VGraphic	*g=[bList objectAtIndex:i];

        /* remove the white graphics */
        if ( [[g color] isEqual:whiteColor] )
            [bList removeObjectAtIndex:i];
    }
}
/* laying a rectangle (4 lines) around hole list
 * AND build one polygon of the hole list -> so we change black to white and vice versa
 */
- (void)changeListPolarity:bList bounds:(NSRect)bounds
{   VPath       *g = [VPath path];
    VLine       *l = [VLine line];
    NSPoint     beg, end;
    int         i, cnt=[(NSArray*)bList count];

    [g setFilled:YES];
    [g setColor:state.color];
    [g setWidth:state.width];

    beg = end = bounds.origin;
    beg.x -= 10.0; beg.y -= 10.0; end.y -= 10.0;
    end.x += bounds.size.width + 10.0;
    [l setVertices:beg :end];
    [l setWidth:state.width];
    [l setColor:state.color];
    [[g list] addObject:l];
    beg = end;
    end.y += bounds.size.height + 20.0;
    l = [VLine line];
    [l setVertices:beg :end];
    [l setWidth:state.width];
    [l setColor:state.color];
    [[g list] addObject:l];
    beg = end;
    end.x -= bounds.size.width + 20.0;
    l = [VLine line];
    [l setVertices:beg :end];
    [l setWidth:state.width];
    [l setColor:state.color];
    [[g list] addObject:l];
    beg = end;
    end.y -= bounds.size.height + 20.0;
    l = [VLine line];
    [l setVertices:beg :end];
    [l setWidth:state.width];
    [l setColor:state.color];
    [[g list] addObject:l];

    for (i=0; i<cnt; i++)
    {	VGraphic	*gr = [bList objectAtIndex:i];

        if ( [gr isKindOfClass:[VPath class]] )
            [g addList:[(VPath*)gr list] at:[[g list] count]];
        else
            [[g list] addObject:l];
    }

    [bList removeAllObjects];
    [bList addObject:g];
}

/* allocate a group object
 * copy the objects in aList to the group, add the group to bList
 */
- (void)addStrokeList:(NSArray*)aList toList:(NSMutableArray*)bList
{   VGraphic    *g;

    if ([aList count] == 1)
        g = [aList objectAtIndex:0];
    else
    {   g = [VPath path];
        [(VPath*)g addList:aList at:[[(VPath*)g list] count]];
    }
    [g setFilled:NO];
    [g setWidth:state.width];
    [g setColor:state.color];
    [bList addObject:g];
}

/* allocate a filled path object
 * copy the objects in aList to this object, add the group to bList
 */
- (void)addFillList:(NSArray*)aList toList:(NSMutableArray*)bList
{   VGraphic    *g;

    if ([aList count] == 1)
        g = [aList objectAtIndex:0];
    else
    {   g = [VPath path];
        [(VPath*)g addList:aList at:[[(VPath*)g list] count]];
    }
    [g setFilled:YES];
    [g setWidth:0.0]; // instead state.width - only used in setPath and setPad -> need both width = 0 !
    [g setColor:state.color];
    if ([g respondsToSelector:@selector(fillColor)])
        [(VPath*)g setFillColor:[state.color copy]];
    [bList addObject:g];
}

- (void)addFillPath:(NSArray*)aList toList:(NSMutableArray*)bList
{   VGraphic    *g;

    if ([aList count] == 1)
        g = [aList objectAtIndex:0];
    else
    {   g = [VPath path];
        [(VPath*)g setList:aList];
    }
    [g setFilled:YES];
    [g setWidth:0.0];
    [g setColor:state.color];
    if ([g respondsToSelector:@selector(fillColor)])
        [(VPath*)g setFillColor:[state.color copy]];
    [bList addObject:g];
}

/* allocate a line object and add it to aList
 */
- (void)addLine:(NSPoint)beg :(NSPoint)end toList:aList
{   VLine   *g; // = [VLine line];

    if ( ![(NSArray*)aList count] )
    {   g = [VLine line];
        [g setVertices:beg :end];
        [g setWidth:state.width];
        [g setColor:state.color];
        [aList addObject:g];
    }
    else // check if last object is a line or polyline and has same end point like beg
    {   NSPoint e = {-1.0, -1.0};
        int     cnt = [(NSArray*)aList count];

        g = [aList objectAtIndex:cnt-1];
        if ( [g isKindOfClass:[VLine class]] )
            e = [g pointWithNum:1];
        else if ( [g isKindOfClass:[VPolyLine class]] )
            e = [(VPolyLine*)g pointWithNum:[(VPolyLine*)g ptsCount]-1];

        if ( e.x != -1.0 && e.y != -1.0 && SqrDistPoints(e, beg) < TOLERANCE
            && Diff(state.width, [g width]) < TOLERANCE && [state.color isEqual:[g color]] )
        {
            if ( [g isKindOfClass:[VLine class]] )
            {   VPolyLine	*pl = [VPolyLine polyLine];

                [pl setWidth:state.width];
                [pl setColor:state.color];
                [pl addPoint:[g pointWithNum:0]];
                [pl addPoint:e];
                [pl addPoint:end];
                [aList removeObjectAtIndex:cnt-1];
                [aList addObject:pl];
            }
            else
                [(VPolyLine*)g addPoint:end]; // we must add only the end point to last polyline in list
        }
        else
        {   g = [VLine line];
            [g setVertices:beg :end];
            [g setWidth:state.width];
            [g setColor:state.color];
            [aList addObject:g];
        }
    }
}

/* allocate a line object and add it to aList
 */
- (void)addRect:(NSPoint)origin :(NSSize)size filled:(BOOL)fill toList:aList
{   VLine           *line;
    VPath           *g = [VPath path];
    NSMutableArray  *pList = [NSMutableArray array];
    NSPoint         p0, p1;

    line = [VLine line];
    [line setColor:state.color];
    p0 = origin;
    p1.x = origin.x + size.width;
    p1.y = origin.y;
    [line setVertices:p0 :p1];
    [pList addObject:line];

    line = [VLine line];
    [line setColor:state.color];
    p0 = p1;
    p1.x = origin.x + size.width;
    p1.y = origin.y + size.height;
    [line setVertices:p0 :p1];
    [pList addObject:line];

    line = [VLine line];
    [line setColor:state.color];
    p0 = p1;
    p1.x = origin.x;
    p1.y = origin.y + size.height;
    [line setVertices:p0 :p1];
    [pList addObject:line];

    line = [VLine line];
    [line setColor:state.color];
    p0 = p1;
    p1.x = origin.x;
    p1.y = origin.y;
    [line setVertices:p0 :p1];
    [pList addObject:line];

    [g setList:pList];
    [g setFilled:YES];
    [g setWidth:(fill) ? 0.0 : state.width];
    [g setColor:state.color];
    [g setFillColor:[state.color copy]];
    [aList addObject:g];
}

- (void)addCircle:(NSPoint)center :(float)radius filled:(BOOL)fill toList:aList
{   VArc		*g;
    NSPoint	start;

    start.x = center.x + radius;
    start.y = center.y;

    g = [VArc arc];
    [g setCenter:center start:start angle:360.0];
    [g setFilled:fill];
    [g setWidth:(fill) ? 0.0 :state.width];
    [g setColor:state.color];
    [g setFillColor:[state.color copy]];
    [aList addObject:g];
}

- (void)addOctagon:(NSPoint)center :(float)radius filled:(BOOL)fill toList:aList
{   NSPoint         p[8];
    VLine           *line;
    VPath           *g = [VPath path];
    NSMutableArray  *pList = [NSMutableArray array];
    int             i;

    for (i=0; i<8; i++)
    {	double	angle = DegToRad(22.5 + i * 45.0);

        p[i].x = center.x + radius*cos(angle);
        p[i].y = center.y + radius*sin(angle);
    }

    for (i=0; i<8; i++)
    {	line = [VLine line];
        [line setColor:state.color];
        [line setVertices:p[i] :(i>=7) ? p[0] : p[i+1]];
        [pList addObject:line];
    }

    [g setList:pList];
    [g setFilled:YES];
    [g setWidth:(fill) ? 0.0 :state.width];
    [g setColor:state.color];
    [g setFillColor:[state.color copy]];
    [aList addObject:g];
}

- (void)addObround:(NSPoint)center :(float)width :(float)height filled:(BOOL)fill toList:aList
{
    if ( width == height ) // circle
    {   VArc	*g;
        NSPoint	start;

        start.x = center.x + width/2.0;
        start.y = center.y;

        g = [VArc arc];
        [g setCenter:center start:start angle:360.0];
        [g setWidth:(fill) ? 0.0 :state.width];
        [g setFilled:fill];
        [g setColor:state.color];
        [g setFillColor:[state.color copy]];
        [aList addObject:g];
        return;
    }

    if ( width < height ) // vertical aranged
    {   VArc	*arc;
        VLine	*line;
        VPath	*path;
        NSPoint	s, e, c;
        float	radius = width/2.0, lineHalf = (height - width)/2.0; // w, h is the hole width, height !

        path = [VPath path];

        [path setFilled:YES];
        [path setWidth:0.0];
        [path setColor:state.color];
        [path setFillColor:[state.color copy]];

        s.x = e.x = center.x + radius;
        s.y = center.y - lineHalf;
        e.y = center.y + lineHalf;
  	line = [VLine line];
        [line setVertices:s :e];
        [line setWidth:0.0];
        [line setColor:state.color];
        [[path list] addObject:line];

        s = e;
        c.x = center.x;
        c.y = center.y + lineHalf;
        arc = [VArc arc];
        [arc setCenter:c start:s angle:180.0];
        [arc setWidth:0.0];
        [arc setColor:state.color];
        [arc setFilled:NO];
        [[path list] addObject:arc];

        s.x = e.x = center.x - radius;
        s.y = center.y + lineHalf;
        e.y = center.y - lineHalf;
  	line = [VLine line];
        [line setVertices:s :e];
        [line setWidth:0.0];
        [line setColor:state.color];
        [[path list] addObject:line];

        s = e;
        c.x = center.x;
        c.y = center.y - lineHalf;
        arc = [VArc arc];
        [arc setCenter:c start:s angle:180.0];
        [arc setWidth:0.0];
        [arc setColor:state.color];
        [arc setFilled:NO];
        [[path list] addObject:arc];

        [aList addObject:path];
    }
    else // if ( width > height ) // horicontal aranged
    {   VArc	*arc;
        VLine	*line;
        VPath	*path;
        NSPoint	s, e, c;
        float	radius = height/2.0, lineHalf = (width - height)/2.0; // w, h is the hole width, height !

        path = [VPath path];

        [path setFilled:YES];
        [path setWidth:0.0];
        [path setColor:state.color];
        [path setFillColor:[state.color copy]];

        s.y = e.y = center.y - radius;
        s.x = center.x - lineHalf;
        e.x = center.x + lineHalf;
  	line = [VLine line];
        [line setVertices:s :e];
        [line setWidth:0.0];
        [line setColor:state.color];
        [[path list] addObject:line];

        s = e;
        c.x = center.x + lineHalf;
        c.y = center.y;
        arc = [VArc arc];
        [arc setCenter:c start:s angle:180.0];
        [arc setWidth:0.0];
        [arc setColor:state.color];
        [arc setFilled:NO];
        [[path list] addObject:arc];

        s.y = e.y = center.y + radius;
        s.x = center.x + lineHalf;
        e.x = center.x - lineHalf;
  	line = [VLine line];
        [line setVertices:s :e];
        [line setWidth:0.0];
        [line setColor:state.color];
        [[path list] addObject:line];

        s = e;
        c.x = center.x - lineHalf;
        c.y = center.y;
        arc = [VArc arc];
        [arc setCenter:c start:s angle:180.0];
        [arc setWidth:0.0];
        [arc setColor:state.color];
        [arc setFilled:NO];
        [[path list] addObject:arc];

        [aList addObject:path];
    }
}

- (void)addPolygon:(NSPoint)center :(float)width :(int)sides filled:(BOOL)fill toList:aList
{   int             i;
    VLine           *line;
    VPath           *g = [VPath path];
    NSMutableArray  *pList = [NSMutableArray array];
    NSPoint         p[sides];
    float           a = 0.0, radius, alpha = 360.0/sides;

    radius = (width/2.0) / cos(DegToRad(alpha/2.0));

    for (i=0; i<sides; i++)
    {	double	angle = DegToRad(a + i * alpha);

        p[i].x = center.x + radius*cos(angle);
        p[i].y = center.y + radius*sin(angle);
    }

    for (i=0; i<sides; i++)
    {	line = [VLine line];
        [line setColor:state.color];
        [line setVertices:p[i] :(i>=sides-1) ? p[0] : p[i+1]];
        [pList addObject:line];
    }

    [g setList:pList];
    [g setFilled:YES];
    [g setWidth:(fill) ? 0.0 :state.width];
    [g setColor:state.color];
    [g setFillColor:[state.color copy]];
    [aList addObject:g];
}

/* allocate an arc object and add it to aList
 * center is the center of the arc
 * start is the start point
 * angle is the angle (negative for clockwise direction and positive for ccw direction)
 */
- (void)addArc:(NSPoint)center :(NSPoint)start :(float)angle toList:aList
{   VArc	*g;

    g = [VArc arc];
    [g setCenter:center start:start angle:angle];
    [g setWidth:state.width];
    [g setColor:state.color];
    [g setFillColor:[state.color copy]];
    [aList addObject:g];
}

- (void)moveListBy:(NSPoint)pt :aList
{   int	i;

    for (i=[(NSArray*)aList count]-1; i>=0; i--)
        [[aList objectAtIndex:i] moveBy:pt];
}

/* set the bounds
 * we move the graphic to 0/0
 */
- (void)setBounds:(NSRect)bounds
{   int		i;
    NSPoint	p;

    p.x = - bounds.origin.x + MMToInternal(10.0);
    p.y = - bounds.origin.y + MMToInternal(10.0);
    for (i=[(NSArray*)list count]-1; i>=0; i--)
        [[list objectAtIndex:i] moveBy:p];
}

@end
