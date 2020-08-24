/* SVGImportSub.m
 * Subclass of SVG-import managing the creation of graphic objects
 *
 * Copyright (C) 2010 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  2010-07-04
 * modified: 2010-07-05
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

#include <VHFShared/vhfCommonFunctions.h>
#include <VHFShared/types.h>
#include "SVGImportSub.h"
#include "Graphics.h"

typedef struct _SVGGradient
{
    int         state;      // 0 = no color, 1 = solid, 2 = graduate, 3 = radial
    NSColor     *begColor, *endColor;
    float       gradAngle;
    NSPoint     radCenter;  // center point
}SVGGradient;

@implementation SVGImportSub

/* serves us the color state as we need it
 */
static SVGGradient svgColorState(id color, NSDictionary *defs)
{   SVGGradient colorState = {0, nil, nil, 0.0, {0.0, 0.0}};

    if ( [color isKindOfClass:[NSColor class]] )
    {   colorState.state = 1;
        colorState.begColor = color;
    }
    else if ( [color isKindOfClass:[NSString class]] )
    {   NSDictionary    *grad = [defs objectForKey:color];

        colorState.state = 2;
        if ( [grad objectForKey:@"cx"] )
            colorState.state = 3;
        colorState.begColor = [grad objectForKey:@"begCol"];
        colorState.endColor = [grad objectForKey:@"endCol"];
        colorState.radCenter.x = Min([grad floatForKey:@"cx"], 1.0);
        colorState.radCenter.y = Min([grad floatForKey:@"cy"], 1.0);
        // TODO: offset
    }
    return colorState;
}

/* allocate a list
 */
- allocateList
{
    return [[NSMutableArray allocWithZone:[self zone]] init];
}

/* allocate a filled path object
 * copy the objects in aList to this object, add the group to bList
 */
- (void)addFillList:(NSArray*)aList toList:bList
{   VPath       *g = [VPath path];
    SVGGradient fillState   = svgColorState(state.fillColor,   defs);
    SVGGradient strokeState = svgColorState(state.strokeColor, defs);

    if ( ![aList count] )
        return;
    [g addList:aList at:[(NSArray*)[g list] count]];
    [g setFilled:fillState.state optimize:NO];  // 0 = not filled, 1 = filled, 2 = graduate, 3 = radial, 4 = axial
    if ( strokeState.begColor )
    {   [g setWidth:state.width];
        [g setColor:strokeState.begColor];
    }
    [g setFillColor:fillState.begColor];
    if ( fillState.endColor )
        [g setEndColor:fillState.endColor];
    if ( fillState.state == 2 )
    {   [g setStepWidth:1];
        [g setGraduateAngle:fillState.gradAngle];
    }
    else if ( fillState.state == 3 )
    {   [g setStepWidth:1];
        [g setRadialCenter:fillState.radCenter];
    }
    [bList addObject:g];
}

/* allocate a group object
 * copy the objects in aList to the group, add the group to bList
 */
- (void)addGroupList:(NSArray*)aList toList:bList
{   VGroup          *g = [VGroup group];
    int             i;
    NSMutableArray  *mutArray = [NSMutableArray array];
    SVGGradient     fillState   = svgColorState(state.fillColor,   defs);
    SVGGradient     strokeState = svgColorState(state.strokeColor, defs);

    for (i=0; i<[aList count]; i++)
    {   id  g = [aList objectAtIndex:i];

        if ( [g isKindOfClass:[VGraphic class]] )
            [mutArray addObject:g];
    }
    aList = mutArray;
    if ( ![aList count] )
        return;
    [g setFilled:NO];
    [g setFillColor:fillState.begColor];
    [g setColor:strokeState.begColor];
    [g setWidth:state.width];
    [g setList:aList];
    [bList addObject:g];
}

- (void)addGroupList:(NSArray*)aList toList:bList withTransform:(NSAffineTransform*)matrix
{   VGroup          *g = [VGroup group];
    int             i;
    NSMutableArray  *mutArray = [NSMutableArray array];
    SVGGradient     fillState   = svgColorState(state.fillColor,   defs);
    SVGGradient     strokeState = svgColorState(state.strokeColor, defs);

    for (i=0; i<[aList count]; i++)
    {   id  g = [aList objectAtIndex:i];

        if ( [g isKindOfClass:[VGraphic class]] )
            [mutArray addObject:[g copy]];
        /*else if ( [g isKindOfClass:[NSDictionary class]] )
            style = g;*/
    }
    aList = mutArray;
    if ( ![aList count] )
        return;
    [g setFilled:NO];
    [g setFillColor:fillState.begColor];   // this is applied to all elements !
    [g setColor:strokeState.begColor];
    [g setWidth:state.width];
    [g setList:aList];
    if ( matrix )
        [g transform:matrix];
    [bList addObject:g];
}

/* allocate a line object and add it to aList
 */
- (void)addLine:(NSPoint)beg :(NSPoint)end toList:aList
{   VLine       *g = [VLine line];
    SVGGradient strokeState = svgColorState(state.strokeColor, defs);

    [g setVertices:beg :end];
    [g setWidth:state.width];
    [g setColor:strokeState.begColor];
    [aList addObject:g];
}

/* allocate a PolyLine object and add it to aList
 */
- (void)addPolyLine:(NSPoint*)pts count:(int)pCnt toList:aList
{   VPolyLine   *g = [VPolyLine polyLine];
    SVGGradient fillState   = svgColorState(state.fillColor,   defs);
    SVGGradient strokeState = svgColorState(state.strokeColor, defs);
    int         i;

    for ( i=0; i<pCnt; i++ )
        [g addPoint:pts[i]];
    [g setWidth:state.width];
    [g setColor:strokeState.begColor];
    [g setFilled:fillState.state];  // 0 = not filled, 1 = filled, 2 = graduate, 3 = radial, 4 = axial
    [g setFillColor:fillState.begColor];
    if ( fillState.endColor )
        [g setEndColor:fillState.endColor];
    if ( fillState.state == 2 )
    {   [g setStepWidth:1];
        [g setGraduateAngle:fillState.gradAngle];
    }
    else if ( fillState.state == 3 )
    {   [g setStepWidth:1];
        [g setRadialCenter:fillState.radCenter];
    }
    [aList addObject:g];
}

/* allocate a line object and add it to aList
 */
- (void)addRectangle:(NSRect)rect toList:aList
{   VRectangle  *g = [VRectangle rectangleWithOrigin:rect.origin size:rect.size];
    SVGGradient fillState   = svgColorState(state.fillColor,   defs);
    SVGGradient strokeState = svgColorState(state.strokeColor, defs);

    [g setWidth:state.width];
    [g setColor:strokeState.begColor];
    [g setFilled:fillState.state];  // 0 = not filled, 1 = filled, 2 = graduate, 3 = radial, 4 = axial
    [g setFillColor:fillState.begColor];
    if ( fillState.endColor )
        [g setEndColor:fillState.endColor];
    if ( fillState.state == 2 )
    {   [g setStepWidth:1];
        [g setGraduateAngle:fillState.gradAngle];
    }
    else if ( fillState.state == 3 )
    {   [g setStepWidth:1];
        [g setRadialCenter:fillState.radCenter];
    }
    [aList addObject:g];
}

/* allocate an arc object and add it to aList
 * center is the center of the arc
 * start is the start point
 * angle is the angle (negative for clockwise direction and positive for ccw direction)
 */
- (void)addArc:(NSPoint)center :(NSPoint)start :(float)angle toList:aList
{   VArc        *g = [VArc arc];
    SVGGradient fillState   = svgColorState(state.fillColor,   defs);
    SVGGradient strokeState = svgColorState(state.strokeColor, defs);

    [g setCenter:center start:start angle:angle];
    [g setWidth:state.width];
    [g setColor:strokeState.begColor];
    [g setFilled:fillState.state];  // 0 = not filled, 1 = filled, 2 = graduate, 3 = radial, 4 = axial
    [g setFillColor:fillState.begColor];
    if ( fillState.endColor )
        [g setEndColor:fillState.endColor];
    if ( fillState.state == 2 )
    {   [g setStepWidth:1];
        [g setGraduateAngle:fillState.gradAngle];
    }
    else if ( fillState.state == 3 )
    {   [g setStepWidth:1];
        [g setRadialCenter:fillState.radCenter];
    }
    [aList addObject:g];
}

/* allocate a curve object and add it to aList
 */
- (void)addCurve:(NSPoint)p0 :(NSPoint)p1 :(NSPoint)p2 :(NSPoint)p3 toList:aList
{   VCurve      *g = [VCurve curve];
    SVGGradient strokeState = svgColorState(state.strokeColor, defs);

    [g setVertices:p0 :p1 :p2 :p3];
    [g setWidth:state.width];
    [g setColor:strokeState.begColor];
    [aList addObject:g];
}

/* allocate a text object and add it to aList
 * parameter:	text	the text string
 *			font	the font name, (make a copy if you want to keep it)
 *			angle	rotation angle
 *			size	the font size in pt
 *			ar		aspect ratio height/width
 *			aList	the destination list
 */
- (void)addText:(NSString*)text :(NSString*)font :(float)angle :(float)size :(float)ar at:(NSPoint)p toList:aList;
{   id		fontObject;
    VText	*g = (VText*)[VText graphic];

    [g setColor:state.strokeColor];
    [g setFillColor:state.fillColor];
    if (!(fontObject = [NSFont fontWithName:font size:size]))
        fontObject = [NSFont userFixedPitchFontOfSize:size];	// default
    [g setFont:fontObject];
    [g setString:text];
    [g setRotAngle:angle];
    [g setBaseOrigin:p];
    [g setAspectRatio:ar];
    [aList addObject:g];

    //	[super addText:text :font :angle :size :ar at:p toList:aList];
}

/* set the bounds
 * bounds are in svg coordinates here
 */
- (void)setBounds:(NSRect)bounds
{   int             i;
    NSMutableArray  *array = [self list];
    NSPoint         p, p1, scaleCenter = NSZeroPoint;

    p  = NSMakePoint(-bounds.origin.x,   -bounds.origin.y);
    p1 = NSMakePoint(MMToInternal(10.0), MMToInternal(10.0));
    for (i=[array count]-1; i>=0; i--)
    {   id  g = [array objectAtIndex:i];

        //if ( ll.x < 0.0 || ll.y < 0.0 )
            [g moveBy:p];   // move graphics to 0/0
        /* Flip */
        if ( flipHeight )
        {   [g scale:1.0 :-1.0 withCenter:scaleCenter];
            [g moveBy:NSMakePoint(0.0, bounds.size.height)];
            //[g moveBy:NSMakePoint(0.0, flipHeight)];
        }
        /* Scale */
        if ( scale != 1.0 )
            [g scale:scale :scale withCenter:scaleCenter];
        /* Move */
        [g moveBy:p1];      // move scaled graphics to 10/10
    }

    /* change order of elements in list */
    /*for (i=[array count]-1; i>=0; i--)
    {
        
    }*/
}

@end
