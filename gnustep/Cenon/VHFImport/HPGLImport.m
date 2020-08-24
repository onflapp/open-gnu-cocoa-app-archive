/* HPGLImport.m
 * HPGL import object
 *
 * Copyright (C) 1996-2012 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1996-05-03
 * modified: 2012-01-05 (-getLabelSize: scanDouble and make it work with all sizes of NSPoint)
 *           2008-06-15 (-getGraphicFromData: imply PD if we get an arc)
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

#include <math.h>

#include "HPGLImport.h"
#include "../VHFShared/vhfCFGFunctions.h"
#include "../VHFShared/types.h"

#define DIGITS		@".+-0123456789"
#define JUMPDIGITS	@",.+-0123456789"
#define NOP		@" \t\r\n,"

/* r in points/inch */
#define	InternalToDeviceRes(a, r)	((float)(a) * (float)(r) / 72.0)
#define	DeviceResToInternal(a, r)	((float)(a) * 72.0 / (float)(r))

//static int linePattern[9][9] = {{0, -1, -1, -1, -1, -1, -1, -1, -1}, {0, 100, -1, -1, -1, -1, -1, -1, -1}, {50, 50, -1, -1, -1, -1, -1, -1, -1}, {70, 30, -1, -1, -1, -1, -1, -1, -1}, {80, 10, 0, 10, -1, -1, -1, -1, -1}, {70, 10, 10, 10, -1, -1, -1, -1, -1}, {50, 10, 10, 10, 10, 10, -1, -1, -1}, {70, 10, 0, 10, 0, 10, -1, -1, -1}, {50, 10, 0, 10, 10, 10, 0, 10, -1}};

static NSPoint rotatePointAroundCenter(NSPoint p, NSPoint cp, float a);
//static void addToBeginNew(NSString *newOp, NSMutableString *beginNew);

@interface HPGLImport(PrivateMethods)
- (BOOL)interpret:(NSString*)dataP;
- (BOOL)getGraphicFromData:(NSScanner*)scanner :cList;
- (BOOL)getPen:(NSScanner*)scanner;
- (BOOL)getLabelSize:(NSScanner*)scanner;
- (BOOL)getLabelSlant:(NSScanner*)scanner;
- (BOOL)getLabelDir:(NSScanner*)scanner;
- (BOOL)getPoint:(NSScanner*)scanner;
- (BOOL)getLine:(NSScanner*)scanner :(NSPoint*)p0 :(NSPoint*)p1;
- (BOOL)getCircle:(NSScanner*)scanner :(NSPoint*)ctr :(NSPoint*)start :(float*)angle;
- (BOOL)getArc:(NSScanner*)scanner :(NSPoint*)ctr :(NSPoint*)start :(float*)angle;
- (BOOL)getLabel :(NSScanner*)scanner :(NSString**)string :(float*)angle :(NSPoint*)origin :(float*)size :(float*)ar;
- (BOOL)getPolygon:(NSScanner*)scanner :cList;
- (BOOL)getInputWindow:(NSScanner*)scanner;
- (BOOL)getLineType:(NSScanner*)scanner;
- (BOOL)getInputP1P2:(NSScanner*)scanner;
- (void)updateBounds:(NSPoint)p;
@end

@implementation HPGLImport

static NSPoint rotatePointAroundCenter(NSPoint p, NSPoint cp, float a)
{   NSPoint	rp, np;

    rp.x = p.x - cp.x;
    rp.y = p.y - cp.y;
    np.x = rp.x * cos(DegToRad(-a)) + rp.y * sin(DegToRad(-a));
    np.y = rp.y * cos(DegToRad(-a)) - rp.x * sin(DegToRad(-a));
    p.x = np.x + cp.x;
    p.y = np.y + cp.y;
    return p;
}

#if 0
/* created:  05.05.93
 * modified: 05.05.93 05.05.96 07.03.97
 *
 * add the first character of an operand to the beginNew string.
 * beginNew is used for an easy way to jump to a relevant position in the data
 */
static void addToBeginNew(NSString *newOp, NSMutableString *beginNew)
{
    if (!newOp || ![newOp length])
        return;

    /* do not add the operand if the 1st character is already in beginNew
     */
    if ( [beginNew rangeOfString:[newOp substringToIndex:1]].length )
        return;

    /* add 1st character of newOp
     */
    [beginNew appendString:[newOp substringToIndex:1]];
}
#endif

- init
{
    [super init];

    res = 1021.0;
    penCount = 0;

    state.pen = 0;
    state.pd = 0;
    state.pa = 1;
    state.relArc = 0;
    state.point.x = state.point.y = LARGENEG_COORD;
    state.labelSize.width = state.labelSize.height = 5.67;
    state.labelDir = 0.0;
    state.labelSlant = 0.0;
    state.lineType = -1;
    state.patternLength = 1;
    state.plottedLength = 0;
    state.mode = 0;
    state.p1.x = state.p1.y = 0.0;
    state.p2.x = 8128.0; state.p2.y = 10160.0;
    state.draw = 0;

    return self;
}

/* created:   03.05.96
 * modified:  09.03.97
 * parameter: fileName
 * purpose:   load parameter file
 */
- (BOOL)loadParameter:(NSString*)fileName
{   NSMutableString	*parmData;
    LONG		value;
    WORD		i;
    //NSMutableString	*beginNew = [NSMutableString string];

    if ( !(parmData = [[NSMutableString stringWithContentsOfFile:fileName] retain]) )
        return NO;

    vhfGetTypesFromData(parmData, @"L", @"#NPN", &penCount);
    vhfGetTypesFromData(parmData, @"C", @"#RES", &res);

    /* pen color, one entry for each pen */
    for (i=0; i < penCount; i++)
    {	LONG	r,g,b;

        if (!vhfGetTypesFromData(parmData, @"LLL", @"#PCO", &r, &g, &b))
            break;
        penColor[i].r = (float) r / 1000.0;
        penColor[i].g = (float) g / 1000.0;
        penColor[i].b = (float) b / 1000.0;
    }

    /* pen width, one entry for each pen */
    for (i=0; i<penCount; i++)
    {	if ( !vhfGetTypesFromData(parmData, @"L", @"#PWI", &value) )
            break;
        penWidth[i] = MMToInternal((float)value/1000.0);
    }
    penCount = i;

    ops.selectPen = vhfGetStringFromData(parmData, @"#IPN");
    ops.penUp = vhfGetStringFromData(parmData, @"#MOV");
    ops.penDown = vhfGetStringFromData(parmData, @"#DRW");
    ops.plotAbs = vhfGetStringFromData(parmData, @"#ABS");
    ops.plotRel = vhfGetStringFromData(parmData, @"#REL");
    ops.seper = vhfGetStringFromData(parmData, @"#SEP");
    if ( !(ops.termi = vhfGetStringFromData(parmData, @"#ITR")) )
        ops.termi = [NSString stringWithFormat:@"%c", 3];
    if ( !(ops.polygonDef = vhfGetStringFromData(parmData, @"#IPO")) )
        ops.polygonDef = @"PM";
    ops.circle = vhfGetStringFromData(parmData, @"#ICI");
    ops.arcAbs = vhfGetStringFromData(parmData, @"#IAA");
    ops.arcRel = vhfGetStringFromData(parmData, @"#IAR");
    ops.label = vhfGetStringFromData(parmData, @"#LBL");
    ops.labelSize = vhfGetStringFromData(parmData, @"#LSI");
    ops.labelDir = vhfGetStringFromData(parmData, @"#LDI");
    ops.labelSlant = vhfGetStringFromData(parmData, @"#LSL");
    ops.labelTermi = vhfGetStringFromData(parmData, @"#LTM");

    if ( !(ops.inputWindow = vhfGetStringFromData(parmData, @"#WIN")) )
        ops.inputWindow = @"IW";
    if ( !(ops.lineType = vhfGetStringFromData(parmData, @"#ILT")) )
        ops.lineType = @"LT";
    if ( !(ops.inputp1p2 = vhfGetStringFromData(parmData, @"#IIP")) )
        ops.inputp1p2 = @"IP";

#if 0
    /* beginNew contains the first characters of all the operators
     */
    addToBeginNew(ops.selectPen, beginNew);
    addToBeginNew(ops.penUp, beginNew);
    addToBeginNew(ops.penDown, beginNew);
    addToBeginNew(ops.plotAbs, beginNew);
    addToBeginNew(ops.plotRel, beginNew);
    addToBeginNew(ops.polygonDef, beginNew);
    addToBeginNew(ops.circle, beginNew);
    addToBeginNew(ops.arcAbs, beginNew);
    addToBeginNew(ops.arcRel, beginNew);
    addToBeginNew(ops.label, beginNew);
    addToBeginNew(ops.labelSize, beginNew);
    addToBeginNew(ops.labelDir, beginNew);
    addToBeginNew(ops.labelSlant, beginNew);
    //	addToBeginNew(ops.labelTermi, beginNew);
    addToBeginNew(ops.seper, beginNew);
    addToBeginNew(ops.termi, beginNew);
    addToBeginNew(ops.inputWindow, beginNew);
    [beginNew appendString:DIGITS];

    ops.beginNew = [NSCharacterSet characterSetWithCharactersInString:beginNew];
#endif

    [parmData release];

    return YES;
}

/* created:   1996-01-25
 * modified:  2002-10-26
 * parameter: hpglData	the HPGL data stream
 * purpose:   start interpretation of the contents of hpglData
 */
- importHPGL:(NSData*)hpglData
{
    state.color = [NSColor colorWithCalibratedRed:0.0 green:0.0 blue:0.0 alpha:1.0];
    state.width = 0.0;

    /* interpret data */
    if ( ![self interpret:[[[NSString alloc] initWithData:hpglData
                                                 encoding:NSASCIIStringEncoding] autorelease]] )
        return nil;

    return [list autorelease];
}

/* private methods
 */
- (BOOL)interpret:(NSString*)dataP
{   id              cList;			// current list
    NSRect          bounds;
    NSScanner       *scanner = [NSScanner scannerWithString:dataP];
    NSCharacterSet  *skipSet = [NSCharacterSet characterSetWithCharactersInString:NOP];

    digitsSet = [NSCharacterSet characterSetWithCharactersInString:DIGITS];
    invDigitsSet = [digitsSet invertedSet];
    jumpSet = [NSCharacterSet characterSetWithCharactersInString:JUMPDIGITS];
    termiSet = [NSCharacterSet characterSetWithCharactersInString:ops.termi];
//    labelTermiSet = [NSCharacterSet characterSetWithCharactersInString:ops.termi];
    labelTermiSet = [NSCharacterSet characterSetWithCharactersInString:[NSString stringWithFormat:@"%c", 3]];

    /* init bounds */
    ll.x = ll.y = LARGE_COORD;
    ur.x = ur.y = LARGENEG_COORD;

    list = [self allocateList];
    cList = [[self allocateList] autorelease];

    [scanner setCharactersToBeSkipped:skipSet];
    while ( ![scanner isAtEnd] )
        if ( ![self getGraphicFromData:scanner :cList] )
            break;

    if ( [cList count] )
    {   [self addStrokeList:cList toList:list];
        [cList removeAllObjects];
    }

    bounds.origin = ll;
    bounds.size.width = ur.x - ll.x;
    bounds.size.height = ur.y - ll.y;
    [self setBounds:bounds];

    return YES;
}

/* the graphics list
 */
- (id)list;
{
    return list;
}

/* we need cp on a number !
 * modified: 2008-06-15
 */
- (BOOL)getGraphicFromData:(NSScanner*)scanner :cList
{   NSPoint	p0, p1;
    int		location;

    /* if this is no legal character, this must be an unsupported command */
    location = [scanner scanLocation];

    /* if status == pd -> get coordinates */
    if ( [scanner scanFloat:NULL] )	/* coordinate */
    {
        if (state.pd == 1)
        {
            if (!state.draw)	/* skip digits */
                return YES;
            [scanner setScanLocation:location];
            switch (state.g)
            {
                case HPGL_LINE:
                    if ( [self getLine:scanner :&p0 :&p1] )
                        [self addLine:p0 :p1 toList:list];
                    break;
                case HPGL_ARC:
                {   NSPoint	ctr, start;
                    float	angle;

                    if ( [self getArc:scanner :&ctr :&start :&angle] )
                        [self addArc:ctr :start :angle toList:list];
                    state.g = HPGL_LINE;
                    break;
                }
                default:
                    NSLog(@"Internal: 'state.g' must be of 'HPGL_LINE' or 'HPGL_ARC'");
            }
            if ( [scanner scanCharactersFromSet:termiSet intoString:NULL] )
            	state.draw = 0;
        }
        /* we need a coordinate pair */
        else if ( [scanner scanFloat:NULL] )
        {   [scanner setScanLocation:location];
            [self getPoint:scanner];
        }
        return YES;
    }
    if ( [scanner scanString:ops.penDown intoString:NULL] )
    {   state.g = HPGL_LINE;
        state.pd   = 1;
        state.draw = 1;
    }
    else if ( [scanner scanString:ops.circle intoString:NULL] )
    {	NSPoint	ctr, start;
        float	angle;

        [self getCircle:scanner :&ctr :&start :&angle];
        [self addArc:ctr :start :angle toList:list];
        state.g = HPGL_LINE;
        state.draw = 1;
    }
    else if ( [scanner scanString:ops.arcAbs intoString:NULL] )
    {	state.g = HPGL_ARC;
        state.relArc = 0;
        state.pd   = 1; // we can imply a pen down for this
        state.draw = 1;
    }
    else if ( [scanner scanString:ops.arcRel intoString:NULL] )
    {	state.g = HPGL_ARC;
        state.relArc = 1;
        state.pd   = 1; // we can imply a pen down for this
        state.draw = 1;
    }
    else if ( [scanner scanString:ops.polygonDef intoString:NULL] )
    {	[self getPolygon:scanner :cList];
    }
    else if ( [scanner scanString:ops.penUp intoString:NULL] )
    {	state.pd = 2;
        state.plottedLength = 0;
    }
    else if ( [scanner scanString:ops.inputWindow intoString:NULL] )
    {	state.pd = 2;
        state.draw = 0;
    }
    else if ( [scanner scanString:ops.selectPen intoString:NULL] )
    {   [self getPen:scanner];
    	state.draw = 0;
    }
    else if ( [scanner scanString:ops.plotAbs intoString:NULL] )
    {	state.draw = 1;
	state.pa = 1;
    }
    else if ( [scanner scanString:ops.plotRel intoString:NULL] )
    {	state.draw = 1;
	state.pa = 0;
    }
    else if ( [scanner scanString:ops.labelSize intoString:NULL] )  // label size
        [self getLabelSize:scanner];
    else if ( [scanner scanString:ops.labelDir intoString:NULL] )   // label direction
        [self getLabelDir:scanner];
    else if ( [scanner scanString:ops.labelSlant intoString:NULL] ) // label slant
        [self getLabelSlant:scanner];
    else if ( [scanner scanString:ops.label intoString:NULL] )      // label
    {	NSPoint	origin;
        float		angle, size, ar;
        NSString	*string;

        if ([self getLabel:scanner :&string :&angle :&origin :&size :&ar])
            [self addText:string :@"Courier" :angle :size :ar at:origin toList:list];
    }
    else if ( [scanner scanString:ops.lineType intoString:NULL] )   // lineType
        [self getLineType:scanner];
    else if ( [scanner scanString:ops.inputp1p2 intoString:NULL] )  // inputp1p2
        [self getInputP1P2:scanner];
    else if ( [scanner scanCharactersFromSet:termiSet intoString:NULL] )
    {	state.draw = 0;
    }
    else	/* jump behind this command */
    {
        [scanner scanCharactersFromSet:[NSCharacterSet alphanumericCharacterSet] intoString:NULL];
        [scanner scanCharactersFromSet:jumpSet intoString:NULL];	/* go behind digits */
        [scanner scanCharactersFromSet:termiSet intoString:NULL];	/* go behind terminator */
        if ( (int)[scanner scanLocation] == location )
            [scanner setScanLocation:location+1];
        return YES;
    }
    [scanner scanCharactersFromSet:termiSet intoString:NULL];	/* skip terminator */

    return YES;
}

/*
 * created:   xx.12.92
 * modified:  2001-11-26
 * purpose:   get pen
 * parameter: scanner (location set behind pen command)
 */
- (BOOL)getPen:(NSScanner*)scanner
{   float	value;
    HPGLColor	col;

    if ( ![scanner scanFloat:&value] )
        state.pen = 0;
    else
    {   state.pen = (int)value - 1;
        if (state.pen < 0)
            state.pen = 0;
        if (state.pen >= penCount)
            state.pen = 0;
    }
    col = penColor[state.pen];
    state.color = [NSColor colorWithCalibratedRed:col.r green:col.g blue:col.b alpha:1.0];
    state.width = penWidth[state.pen];

    return YES;
}

/*
 * created:   1994-04-18
 * modified:  2012-01-05 (scanDouble and make it work with all sizes of NSPoint)
 * purpose:   get label size
 *            the size comes in cm, we store it in internal units
 * parameter: cp (at or behind command)
 */
- (BOOL)getLabelSize:(NSScanner*)scanner
{   double  d;

    [scanner scanString:ops.labelSize intoString:NULL];

    state.labelSize = NSZeroSize;
    if ( [scanner scanDouble:&d] )
    {   state.labelSize.width = d;
        if ( [scanner scanDouble:&d] )
            state.labelSize.height = d;
        else
            NSLog(@"%@ (height) expected at location:%d", ops.labelSize, [scanner scanLocation]);
    }

    if ( state.labelSize.width == 0.0 )	// default size
        state.labelSize.width = 11.5 * PT;
    else
        state.labelSize.width *= MM*10.0;

    if (state.labelSize.height == 0.0)	// default size
        state.labelSize.height = 11.5 * PT;
    else
        state.labelSize.height *= MM*10.0;

    return YES;
}

/*
 * created:   18.04.94
 * modified:  18.04.94 04.05.96 09.03.97
 * purpose:   get label slant
 * parameter: scanner (at or behind command)
 */
- (BOOL)getLabelSlant:(NSScanner*)scanner
{   double	value = 0.0;

    [scanner scanString:ops.labelSlant intoString:NULL];

    if ( ![scanner scanDouble:&value] )
        value = 0.0;
    state.labelSlant = -RadToDeg(atan((double)value));

    return YES;
}

/* created:   18.04.94
 * modified:  18.04.94 04.05.96
 * purpose:   get label direction
 * parameter: scanner (at or behind command)
 */
- (BOOL)getLabelDir:(NSScanner*)scanner
{   float	run = 0.0, rise = 0.0;

    [scanner scanString:ops.labelDir intoString:NULL];

    if ( ![scanner scanFloat:&run] )
        run = rise = 0.0;
    else if ( ![scanner scanFloat:&rise] )
        NSLog(@"'%@' (rise) expected at location: %d", ops.labelDir, [scanner scanLocation]);

    if (run == 0.0 && rise == 0.0)
        state.labelDir = 0.0;
    else if (run == 0.0 && rise == 1.0)
        state.labelDir = 90.0;
    else if (run == 0.0 && rise == -1.0)
        state.labelDir = 270.0;
    else
    {	state.labelDir = RadToDeg( atan((double)(rise/run)));

        /* 2nd and 3rd quadrant */
        if (run < 0)
            state.labelDir += 180.0;
        if (state.labelDir < 0)
            state.labelDir += 360.0;
    }

    return YES;
}

/* created:   xx.12.92
 * modified:  21.01.93 04.05.96 09.03.97
 * purpose:   get point
 * parameter: scanner (at values)
 */
- (BOOL)getPoint:(NSScanner*)scanner
{   float	x, y;

    if ( ![scanner scanFloat:&x] )
        NSLog(@"getPoint: (x) expected at location: %d", [scanner scanLocation]);
    if ( ![scanner scanFloat:&y] )
        NSLog(@"getPoint: (y) expected at location: %d", [scanner scanLocation]);
    x = DeviceResToInternal(x, res);
    y = DeviceResToInternal(y, res);
    if (state.pa)
    {	state.point.x = x;
        state.point.y = y;
    }
    else
    {	state.point.x = state.point.x + x;
        state.point.y = state.point.y + y;
    }

    state.pd = 2;

    return YES;
}

/* created:   17.05.93
 * modified:  18.05.93 09.03.97
 *
 * purpose:   get line
 * parameter: scanner (at values)
 *		p0 (the destination for the element)
 *		p1
 */
- (BOOL)getLine:(NSScanner*)scanner :(NSPoint*)p0 :(NSPoint*)p1
{   float	x, y;

    *p0 = state.point;
    if ( ![scanner scanFloat:&x] )
        NSLog(@"getLine::: (x) expected at location: %d", [scanner scanLocation]);
    if ( ![scanner scanFloat:&y] )
        NSLog(@"getLine::: (y) expected at location: %d", [scanner scanLocation]);
    x = DeviceResToInternal(x, res);
    y = DeviceResToInternal(y, res);
    if (state.pa)
    {	p1->x = x;
        p1->y = y;
    }
    else
    {	p1->x = state.point.x + x;
        p1->y = state.point.y + y;
    }

    state.point = *p1;

    [self updateBounds:*p0];
    [self updateBounds:*p1];

    return YES;
}

/* created:   1993-05-17
 * modified:  2004-08-04
 *
 * purpose:   get circle
 * parameter: scanner	data
 *            ctr	center
 *            start	
 *            angle	360 degree
 */
- (BOOL)getCircle:(NSScanner*)scanner :(NSPoint*)ctr :(NSPoint*)start :(float*)angle
{   float	r;

    *ctr = state.point;
    *angle = 0.0;

    if ( ![scanner scanFloat:&r] )
        NSLog(@"getCircle::: radius expected at location: %d", [scanner scanLocation]);
    r = DeviceResToInternal(r, res);

    /* radius! */
    if (r)
    {
        start->x = ctr->x + r;
        start->y = ctr->y;

        *angle = 360.0;

        /* goto terminator */
        [scanner scanUpToCharactersFromSet:termiSet intoString:NULL];

        [self updateBounds:NSMakePoint(ctr->x+r, ctr->y+r)];
        [self updateBounds:NSMakePoint(ctr->x-r, ctr->y-r)];
    }

    return YES;
}

/* created:   1993-05-17
 * modified:  2004-05-27
 *
 * purpose:   get arc
 * parameter: scanner (at values)
 *            ctr
 *            start
 *            angle
 */
- (BOOL)getArc:(NSScanner*)scanner :(NSPoint*)ctr :(NSPoint*)start :(float*)angle
{   float	x, y, value;

    *angle = 0.0;
    if ( ![scanner scanFloat:&x] )
        NSLog(@"getArc::: center x expected at location: %d", [scanner scanLocation]);
    if ( ![scanner scanFloat:&y] )
        NSLog(@"getArc::: center y expected at location: %d", [scanner scanLocation]);
    x = DeviceResToInternal(x, res);
    y = DeviceResToInternal(y, res);
    if ( !state.relArc )
    {	ctr->x = x;
        ctr->y = y;
    }
    else
    {	ctr->x = state.point.x + x;
        ctr->y = state.point.y + y;
    }

    *start = state.point;

    if ( ![scanner scanFloat:&value] )
        NSLog(@"getLine::: angle expected at location: %d", [scanner scanLocation]);
    *angle = value;

    [scanner scanFloat:&value];

    state.point = *start;
    state.point = rotatePointAroundCenter(state.point, *ctr, *angle);

    [self updateBounds:state.point];
    [self updateBounds:*start];
    //rect = vhfBoundsOfArc(*ctr, ???, ???, *angle);
    //[self updateBounds:rect.origin];
    //[self updateBounds:NSMakePoint(rect.origin.x+rect.size.width, rect.origin.y)];
    //[self updateBounds:NSMakePoint(rect.origin.x+rect.size.width, rect.origin.y+rect.size.height)];
    //[self updateBounds:NSMakePoint(rect.origin.x, rect.origin.y+rect.size.height)];

    return YES;
}

/* created:   11.06.93
 * modified:  12.06.93 18.04.94 30.09.94 01.05.96 09.03.97
 *
 * purpose:   get text
 *		read a sv-polygon for each character
 *		then position and rotate it
 * parameter: cp (the dxf data)
 *		string
 *		angle
 *		origin
 *		size
 *		ar	aspect ratio
 */
- (BOOL)getLabel:(NSScanner*)scanner :(NSString**)string :(float*)angle :(NSPoint*)origin :(float*)size :(float*)ar
{   float	length;

    [scanner scanString:ops.label intoString:NULL];

    *origin = state.point;
    *size = state.labelSize.height *3.0/2.0;
    *angle = state.labelDir;
    *ar = 1.0;
    //	*ar = state.labelSize.height/state.labelSize.width;

    if ( ![scanner scanUpToCharactersFromSet:labelTermiSet intoString:string] )
    {   NSLog(@"'%@' string expected at location: %d", ops.label, [scanner scanLocation]);
        return NO;
    }
    /* end of text */
    length = [*string length] * state.labelSize.width * 1.1;
    state.point.x = origin->x + length;
    state.point = rotatePointAroundCenter(state.point, *origin, *angle);

    [self updateBounds:*origin];
    [self updateBounds:state.point];

    return YES;
}

/* created:   30.09.94
 * modified:  30.09.94 09.03.97
 *
 * purpose:   get polygon
 * parameter: cp (the hpgl data)
 *		cList
 */
- (BOOL)getPolygon:(NSScanner*)scanner :cList
{   float	value;

    if ( ![scanner scanFloat:&value] )
        NSLog(@"'%@' (polygon mode) expected at location: %d", ops.polygonDef, [scanner scanLocation]);

    switch ((int)value)
    {
        case 0:
            state.mode = POLYGON_MODE;
            break;
        default:
            state.mode = 0;
            return YES;
    }

    while ( ![scanner isAtEnd] && state.mode == POLYGON_MODE )
        if (![self getGraphicFromData:scanner :cList])
            return NO;

    return YES;
}

/*
 * created:   xx.12.92
 * modified:  21.02.93 09.03.97
 * purpose:   get input window
 * parameter: scanner (at or behind command)
 */
- (BOOL)getInputWindow:(NSScanner*)scanner
{   float	value;

    [scanner scanString:ops.inputWindow intoString:NULL];

    if ( ![scanner scanFloat:&value] )
        NSLog(@"'%@' (x) expected at location: %d", ops.inputWindow, [scanner scanLocation]);
    if ( ![scanner scanFloat:&value] )
        NSLog(@"'%@' (y) expected at location: %d", ops.inputWindow, [scanner scanLocation]);
    if ( ![scanner scanFloat:&value] )
        NSLog(@"'%@' (w) expected at location: %d", ops.inputWindow, [scanner scanLocation]);
    if ( ![scanner scanFloat:&value] )
        NSLog(@"'%@' (h) expected at location: %d", ops.inputWindow, [scanner scanLocation]);

    return YES;
}

/*
 * created:   27.07.95
 * modified:  27.07.95 04.05.96 19.03.97
 * purpose:   get line type
 * parameter: cp
 */
- (BOOL)getLineType:(NSScanner*)scanner
{   float	value, v1;

    [scanner scanString:ops.lineType intoString:NULL];

    if ( ![scanner scanFloat:&value] )	/* line type */
    {	state.lineType = -1;	/* solid line */
        [scanner scanUpToCharactersFromSet:termiSet intoString:NULL];
        return YES;
    }
    state.lineType = (int)value;

    if ( ![scanner scanFloat:&value] )	/* pattern length */
        return YES;

    if ( ![scanner scanFloat:&v1] )	/* mode */
        v1 = 0;

    if (((int)v1) == 1)	/* absolute mm */
        state.patternLength = value * MM;
    else	/* relative p1 and p2 */
    {	double	dx = Diff(state.p1.x, state.p2.x), dy = Diff(state.p1.y, state.p2.y);
        float	dist = sqrt(dx*dx+dy*dy);

        state.patternLength = dist * value / 100.0;
    }

    return YES;
}

/*
 * created:   27.07.95
 * modified:  27.07.95 09.03.97
 * purpose:   get input p1 p2
 * parameter: cp
 *		state
 *		parms
 */
- (BOOL)getInputP1P2:(NSScanner*)scanner
{   float	value;

    [scanner scanString:ops.inputp1p2 intoString:NULL];

    if ( ![scanner scanFloat:&value] )	/* input p1 p2 */
    {	state.p1.x = state.p1.y = 0.0;
        state.p2.x = DeviceResToInternal(8128.0, res);
        state.p2.y = DeviceResToInternal(10160.0, res);
        return YES;
    }
    state.p1.x = DeviceResToInternal(value, res);

    if ( ![scanner scanFloat:&value] )
        NSLog(@"'%@' (p1 y) expected at location: %d", ops.inputp1p2, [scanner scanLocation]);
    state.p1.y = DeviceResToInternal(value, res);

    if ( ![scanner scanFloat:&value] )
        NSLog(@"'%@' (p2 x) expected at location: %d", ops.inputp1p2, [scanner scanLocation]);
    state.p2.x = DeviceResToInternal(value, res);

    if ( ![scanner scanFloat:&value] )
        NSLog(@"'%@' (p2 y) expected at location: %d", ops.inputp1p2, [scanner scanLocation]);
    state.p2.y = DeviceResToInternal(value, res);

    return YES;
}

- (void)updateBounds:(NSPoint)p
{
    ll.x = Min(ll.x, p.x);
    ll.y = Min(ll.y, p.y);
    ur.x = Max(ur.x, p.x);
    ur.y = Max(ur.y, p.y);
}

- (void)dealloc
{
    [super dealloc];
}

/* methods to be subclassed
 */
- (id)allocateList
{
    return nil;
}

- (void)addFillList:aList toList:bList
{
    NSLog(@"filled path.");
}

- (void)addStrokeList:aList toList:bList
{
    NSLog(@"stroked path."); 
}

- (void)addLine:(NSPoint)beg :(NSPoint)end toList:aList
{
    NSLog(@"line: %f %f %f %f", beg.x, beg.y, end.x, end.y); 
}

- (void)addArc:(NSPoint)center :(NSPoint)start :(float)angle toList:aList
{
    NSLog(@"arc: %f %f %f %f %f", center.x, center.y, start.x, start.y, angle); 
}

- (void)addCurve:(NSPoint)p0 :(NSPoint)p1 :(NSPoint)p2 :(NSPoint)p3 toList:aList
{
    NSLog(@"curve: %f %f %f %f %f %f %f %f", p0.x, p0.y, p1.x, p1.y, p2.x, p2.y, p3.x, p3.y);
}

/* allocate a text object and add it to aList
 * parameter:	text	the text string
 *		font	the font name
 *		angle	rotation angle
 *		size	the font size in pt
 *		ar		aspect ratio height/width
 *		aList	the destination list
 */
- (void)addText:(NSString*)text :(NSString*)font :(float)angle :(float)size :(float)ar at:(NSPoint)p toList:aList
{
    NSLog(@"text: %f %f %f %f %f \"%s\" \"%s\"\n", p.x, p.y, angle, size, ar, text, font); 
}

- (void)setBounds:(NSRect)bounds
{
    NSLog(@"bounds: %f %f %f %f", bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height);
}
@end
