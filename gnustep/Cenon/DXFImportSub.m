/* DXFImportSub.m
 * Subclass of DXFImport managing the creation of graphic objects
 *
 * Copyright (C) 1996-2011 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1996-05-01
 * modified: 2011-04-04 (-addLine3D:... added)
 *           2007-07-13 (-setBounds: continue nur wenn object removed wird (Versatz))
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
#include "DXFImportSub.h"
#include "messages.h"
#include "Graphics.h"
#include "LayerObject.h"

@implementation DXFImportSub

/* here we create the layers needed to store the imported graphics
 * we return an autoreleased object
 */
- (id)allocateList:(NSArray*)layers
{   int	l;

    layerList = [[NSMutableArray alloc] init];

    /* create a layerList containing a layerObject for each layer */
    for (l=0; l<(int)[layers count]; l++)
    {   LayerObject	*layerObject = [LayerObject layerObject];
        NSDictionary	*dict = [layers objectAtIndex:l];

        [layerObject setString:[dict objectForKey:@"name"]];
        //if (!([layerInfo intForKey:@"flags"] & LAYERFLAG_FROZEN))
        // ...
        [layerList addObject:layerObject];
    }
    if (![layers count])
    {   LayerObject	*layerObject = [LayerObject layerObject];

        [layerObject setString:@"DXF"];
        [layerList addObject:layerObject];
    }

    return layerList;
}
- (NSMutableArray*)layerArrayWithName:(NSString*)name
{   int	l;

    /* AC2.10 seems to allow missing LAYER entries */
    if (!name && [layerList count])
        return [[layerList objectAtIndex:0] list];

    for (l=0; l<(int)[layerList count]; l++)
        if ([[[layerList objectAtIndex:l] string] isEqual:name])
            return [[layerList objectAtIndex:l] list];
    if ([layerList count])	// return first layer (default)
        return [[layerList objectAtIndex:0] list];
    return nil;
}

/* add list as filled path to layer
 * we simply add everything in a single list ignoring all layers
 */
- (void)addFillList:aList toLayer:(NSString*)layerName
{   NSMutableArray  *array = [self layerArrayWithName:layerName];
    VPath           *g = [VPath path];

    if (!array)
        array = [[layerList objectAtIndex:0] list];
    [g addList:aList at:[[g list] count]];
    [g sortList];
    [g setFilled:YES];
    [g setWidth:state.width];
    [g setColor:state.color];
    [g setFillColor:[state.color copy]];
    [array addObject:g];
}

/* add list as stroked path object to layer
 * we simply add everything in a single list ignoring all layers
 */
- (void)addStrokeList:aList toLayer:(NSString*)layerName
{   NSMutableArray	*array = [self layerArrayWithName:layerName];
    VPath			*g = [VPath path];

    [g addList:aList at:[[g list] count]];
    [g sortList];
    [g setFilled:NO];
    [g setColor:state.color];
    [g setFillColor:[state.color copy]];	// turning to filled will fill in the same color
    [g setWidth:state.width];
    [array addObject:g];
}

/* allocate a line object and add it to aList
 */
- (void)addLine:(NSPoint)beg :(NSPoint)end toList:(NSMutableArray*)aList
{   VLine	*g;

    g = [VLine line];
    [g setVertices:beg :end];
    [g setWidth:state.width];
    [g setColor:state.color];
    [aList addObject:g];
}
- (void)addLine:(NSPoint)beg :(NSPoint)end toLayer:(NSString*)layerName
{   NSMutableArray	*array = [self layerArrayWithName:layerName];
    VLine		*g;

    if (!array)
        array = [[layerList objectAtIndex:0] list];
    g = [VLine line];
    [g setVertices:beg :end];
    [g setWidth:state.width];
    [g setColor:state.color];
    [array addObject:g];
}

/* allocate a line object and add it to aList
 */
- (void)addLine3D:(V3Point)beg :(V3Point)end toList:(NSMutableArray*)aList
{   VLine3D	*g;

    g = [VLine3D line3DWithPoints:beg :end];
    [g setWidth:state.width];
    [g setColor:state.color];
    [aList addObject:g];
}
- (void)addLine3D:(V3Point)beg :(V3Point)end toLayer:(NSString*)layerName
{   NSMutableArray	*array = [self layerArrayWithName:layerName];
    VLine3D *g;

    if (!array)
        array = [[layerList objectAtIndex:0] list];
    g = [VLine3D line3DWithPoints:beg :end];
    [g setWidth:state.width];
    [g setColor:state.color];
    [array addObject:g];
}

/* allocate an arc object and add it to aList
 * center is the center of the arc
 * start is the start point
 * angle is the angle (negative for clockwise direction and positive for ccw direction)
 */
- (void)addArc:(NSPoint)center :(NSPoint)start :(float)angle toList:(NSMutableArray*)aList
{   VArc	*g;

    g = [VArc arc];
    [g setCenter:center start:start angle:angle];
    [g setWidth:state.width];
    [g setColor:state.color];
    [g setFillColor:[state.color copy]];
    [aList addObject:g];
}
- (void)addArc:(NSPoint)center :(NSPoint)start :(float)angle toLayer:(NSString*)layerName
{   NSMutableArray	*array = [self layerArrayWithName:layerName];
    VArc			*g;

    if (!array)
        array = [[layerList objectAtIndex:0] list];
    g = [VArc arc];
    [g setCenter:center start:start angle:angle];
    [g setWidth:state.width];
    [g setColor:state.color];
    [g setFillColor:[state.color copy]];
    [array addObject:g];
}

/* allocate a curve object and add it to aList
 */
- (void)addCurve:(NSPoint)p0 :(NSPoint)p1 :(NSPoint)p2 :(NSPoint)p3 toList:(NSMutableArray*)aList
{   VCurve	*g;

    g = [VCurve curve];
    [g setVertices:p0 :p1 :p2 :p3];
    [g setWidth:state.width];
    [g setColor:state.color];
    [aList addObject:g];
}
- (void)addCurve:(NSPoint)p0 :(NSPoint)p1 :(NSPoint)p2 :(NSPoint)p3 toLayer:(NSString*)layerName
{   NSMutableArray	*array = [self layerArrayWithName:layerName];
    VCurve		*g;

    if (!array)
        array = [[layerList objectAtIndex:0] list];
    g = [VCurve curve];
    [g setVertices:p0 :p1 :p2 :p3];
    [g setWidth:state.width];
    [g setColor:state.color];
    [array addObject:g];
}

/* 3D Surface
 */
- (void)add3DFace:(V3Point*)pts toLayer:(NSString*)layerName
{
    /* TODO: this should be a surface, not 4 lines */
    [self addLine3D:pts[0] :pts[1] toLayer:layerName];
    [self addLine3D:pts[1] :pts[2] toLayer:layerName];
    [self addLine3D:pts[2] :pts[3] toLayer:layerName];
    [self addLine3D:pts[3] :pts[0] toLayer:layerName];
}

/* allocate a text object and add it to the layer
 * parameter: text	the text string
 *            font	the font name
 *            angle	rotation angle
 *            size	the font size in pt
 *            ar	aspect ratio height/width
 *            alignment	see genFlags of MTEXT in DXF specs
 *            layerInfo	the destination layer
 */
- (void)addText:(NSString*)text :(NSString*)font :(float)angle :(float)size :(float)ar :(int)alignment at:(NSPoint)p toLayer:(NSString*)layerName
{   NSMutableArray	*array = [self layerArrayWithName:layerName];
    id			fontObject;
    VText		*g = [VText textGraphic];
    NSRect		bounds;

    if (!array)
        array = [[layerList objectAtIndex:0] list];
    [g setColor:state.color];
    [g setFillColor:[state.color copy]];
    if (!(fontObject = [NSFont fontWithName:font size:size]))
        fontObject = [NSFont userFixedPitchFontOfSize:size];	// default
    [g setFont:fontObject];
    [g setString:text];
    [g setRotAngle:angle];
    bounds = [g coordBounds];
    switch (alignment)
    {
        case 1:	// top left
            p.y -= bounds.size.height;
            break;
        case 2:	// top center
            p.x -= bounds.size.width / 2.0;
            p.y -= bounds.size.height;
            break;
        case 3:	// top right
            p.x -= bounds.size.width;
            p.y -= bounds.size.height;
            break;
        case 4:	// middle left
            p.y -= bounds.size.height / 2.0;
            break;
        case 5:	// middle center
            p.x -= bounds.size.width / 2.0;
            p.y -= bounds.size.height / 2.0;
            break;
        case 6:	// middle right
            p.x -= bounds.size.width;
            p.y -= bounds.size.height / 2.0;
            break;
        case 7:	// bottom left
            break;
        case 8:	// bottom center
            p.x -= bounds.size.width / 2.0;
            break;
        case 9:	// bottom right
            p.x -= bounds.size.width;
    }
    if (alignment >= 7 )	// bottom aligned
        [g setBaseOrigin:p];
    else
        [g moveTo:p];
    [g setAspectRatio:ar];
    [array addObject:g];
    //	[super addText:text :font :angle :size :ar at:p toList:aList];
}

/* set the bounds
 * we move the graphic to 0/0 and scale to acceptable size if necessary
 * modified: 2006-12-11
 */
- (void)setBounds:(NSRect)bounds
{   int		i, l, removed = 0;
    NSPoint	p;
    NSPoint	scaleCenter = NSZeroPoint;
    float	factor = 1.0;
    BOOL	scale = NO, delete = YES;

    bounds = EnlargedRect(bounds, TOLERANCE);

    p.x = - bounds.origin.x + MMToInternal(10.0);
    p.y = - bounds.origin.y + MMToInternal(10.0);

#if !defined(GNUSTEP_BASE_VERSION) && !defined(__APPLE__)	// OpenStep 4.2
    if ( Max(bounds.size.width, bounds.size.height) > 10000.0 )
    {
        NSRunAlertPanel(@"", DXFSIZE_STRING, OK_STRING, nil, nil);
        factor = Max(bounds.size.width, bounds.size.height);
        while ( factor > 10000.0 )
            factor /= 10.0;
        factor = factor / Max(bounds.size.width, bounds.size.height);
        scale = YES;
    }
#endif

    for (l=0; l<(int)[layerList count]; l++)
    {   NSMutableArray	*array = [[layerList objectAtIndex:l] list];

        for (i=[array count]-1; i>=0; i--)
        {   id	obj = [array objectAtIndex:i];

            /* object out of bounds */
            if (!vhfContainsRect(bounds, [obj bounds]) && !vhfIntersectsRect(bounds, [obj bounds]))
            {
                if (removed || (delete &&
                    NSRunAlertPanel(@"", DXFIMPORTOUTOFBOUNDS_STRING, DELETE_STRING, KEEP_STRING, nil)
                    == NSAlertDefaultReturn))
                {
                    [array removeObjectAtIndex:i];
                    removed ++;
                    continue;
                }
                else
                    delete = NO;
            }
            [obj moveBy:p];
            if ( scale )
                [obj scale:factor :factor withCenter:scaleCenter];
        }
        /* remove empty layers */
        if (![array count])
        {   [layerList removeObjectAtIndex:l];
            l--;
        }
    }
    if (removed)
        NSLog(@"DXF-Import: %d Objects removed, which are exceeding drawing extents!", removed);
}

@end
