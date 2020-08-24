/* GerberImport.m
 * Gerber import object (RS274X)
 *
 * Copyright (C) 1996-2011 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *           Ilonka Fleischmann
 *
 * created:  1996-05-03
 * modified: 2010-12-30 (state.zeros == 2 Trailing Zeros fixed)
 *           2009-07-10 (// state.g = 0; -getLayerPolarity: ![scanner isAtEnd])
 *           2006-03-24
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
#include "GerberImport.h"
#include "../VHFShared/vhfCFGFunctions.h"
#include "../VHFShared/types.h"
#include "../VHFShared/VHFStringAdditions.h"
#include "../VHFShared/vhf2DFunctions.h"

/* r in points/inch */
#define	InternalToDeviceRes(a, r)	((float)(a) * (float)(r) / 72.0)
#define	DeviceResToInternal(a, r)	((float)(a) * 72.0 / (float)(r))

/* this is the maximum string length used for temporary string handling */
#define STRING_LEN	1000

/* the following characters may apear as digits in a coordinate */
#define DIGITS @".+-0123456789"

static float calcAngleOfPointRelativeCenter(NSPoint p, NSPoint cp);
//static void addToBeginNew(NSString *newOp, NSMutableString *beginNew);

@interface GerberImport(PrivateMethods)
- (BOOL)interpret:(NSString*)dataP;
- (BOOL)getGraphicFromData:(NSScanner*)scanner :cList;
- (BOOL)getFormatStatement:(NSScanner*)scanner;
- (BOOL)getToolFromData:(NSScanner*)scanner :(NSString*)macroData :(NSString**)code :(float*)w :(float*)h :(NSString**)formCode :(NSString**)macroStr;
- (BOOL)getApertureCircle:(NSScanner*)scanner :(float*)w :(float*)h :(NSString**)formCode;
- (BOOL)getApertureRectangle:(NSScanner*)scanner :(float*)w :(float*)h :(NSString**)formCode;
- (BOOL)getApertureObround:(NSScanner*)scanner :(float*)w :(float*)h :(NSString**)formCode;
- (BOOL)getAperturePolygon:(NSScanner*)scanner :(float*)w :(float*)h :(NSString**)formCode;
- (BOOL)getApertureMacro:(NSScanner*)scanner :(NSString*)macroData :(NSString**)formCode :(NSString**)macroStr;
- (BOOL)getLayerPolarity:(NSScanner*)scanner;
- (BOOL)getTool:(NSScanner*)scanner;
- (BOOL)getPlotAbs:(NSScanner*)scanner;
- (BOOL)getPlotRel:(NSScanner*)scanner;
- (void)getMacroCircle:(NSScanner*)scanner :mList :(NSPoint*)llur;
- (void)getMacroRectLine:(NSScanner*)scanner :mList :(NSPoint*)llur;
- (void)getMacroRectCenter:(NSScanner*)scanner :mList :(NSPoint*)llur;
- (void)getMacroRect:(NSScanner*)scanner :mList :(NSPoint*)llur;
- (void)getMacroOutline:(NSScanner*)scanner :mList :(NSPoint*)llur;
- (void)getMacroPolygon:(NSScanner*)scanner :mList :(NSPoint*)llur;
- (void)getMacroMoire:(NSScanner*)scanner :mList :(NSPoint*)llur;
- (void)getMacroThermal:(NSScanner*)scanner :mList :(NSPoint*)llur;
- (void)setLine:cList;
- (void)setPad:cList;
- (void)setArc:cList;
- (void)setPath:(NSScanner*)scanner :cList;
- (void)updateBounds:(NSPoint)p;
@end

@implementation GerberImport

/* calculate the angle of p relative cp
 */
static float calcAngleOfPointRelativeCenter(NSPoint p, NSPoint cp)
{   float a, dx = p.x-cp.x, dy = p.y-cp.y;

    if (!dx)
        a = (dy >= 0) ? 90.0 : 270.0;
    else
    {	a = RadToDeg(atan(dy / dx));
        if (dx<0) a += 180; /* 2, 3 */
        if (dx>0 && dy<0) a += 360;	/* 4 */
    }
    return a;
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
    self = [super init];

    [self setDefaultParameter];

    res = 1000.0;

    state.tool = 0;
    state.pa = 1;
    state.point.x = state.point.y = LARGENEG_COORD;
    state.g = 0;
    state.x = state.y = 0.0;
    state.i = state.j = 0.0;
    state.lightCode = 2;
    state.inch = 1; // inch !
    state.pos = 1;
    state.path = 0;
    state.LPCSet = 0;
    state.LPC = 0;

    return self;
}

- (void)setDefaultParameter
{
    ops.reset = @"X0Y0D2*\n";
    ops.selectTool = @"D";
    ops.selectTool2 = @"DX";
    ops.move = @"D2";
    ops.draw = @"D1";
    ops.flash = @"D3";
    ops.draw01 = @"D01";
    ops.move02 = @"D02";
    ops.flash03 = @"D03";
    ops.coordX = @"x";
    ops.coordY = @"Y";
    ops.coordI = @"I";
    ops.coordJ = @"J";
    //ops.circle = @"G75*G02";
    //ops.arc = @"G75";
    ops.plotAbs = @"G90";
    ops.plotRel = @"G91";
    ops.termi = @"*";
    ops.RS274X = @"%";
    ops.polyBegin = @"G36";
    ops.polyEnd = @"G37";
    ops.comment = @"G04";
    ops.line = @"G01";
    ops.ipolQuarter = @"G74";
    ops.ipolFull = @"G75";
    ops.circleCW = @"G02";
    ops.circleCCW = @"G03";
    formC = @"C";
    formR = @"R";
    formO = @"O";
    formOR = @"OR";
    formM = @"M";
    formP = @"P";
}

/* created:   03.05.96
 * modified:  07.03.97
 * parameter: fileName
 * purpose:   load parameter file
 */
- (BOOL)loadParameter:(NSString*)fileName
{   NSMutableString	*parmData;
    //float		value;
    //NSMutableString	*beginNew = [NSMutableString string];

    [self setDefaultParameter];

    if ( !(parmData = [NSMutableString stringWithContentsOfFile:fileName]) )
        return NO;

    vhfGetTypesFromData(parmData, @"f", @"#RES", &res);
    //	vhfGetTypesFromData(parmData, @"L", @"#XMX", &value);
    //	size.width = (NXCoord)value * MM;
    //	vhfGetTypesFromData(parmData, @"L", @"#YMX", &value);
    //	size.height = (NXCoord)value * MM;

    ops.init = vhfGetStringFromData(parmData, @"#INI");
    ops.reset = vhfGetStringFromData(parmData, @"#RST");
    ops.selectTool = vhfGetStringFromData(parmData, @"#IT0");
    ops.selectTool2 = vhfGetStringFromData(parmData, @"#IT1");

    ops.move = vhfGetStringFromData(parmData, @"#IMO");
    ops.draw = vhfGetStringFromData(parmData, @"#IDR");
    ops.flash = vhfGetStringFromData(parmData, @"#IFS");
    ops.coordX = vhfGetStringFromData(parmData, @"#IXP");
    ops.coordY = vhfGetStringFromData(parmData, @"#IYP");
    ops.coordI = vhfGetStringFromData(parmData, @"#IIP");
    ops.coordJ = vhfGetStringFromData(parmData, @"#IJP");
    //ops.circle = vhfGetStringFromData(parmData, @"#ICI");
    //ops.arc = vhfGetStringFromData(parmData, @"#IAR");
    ops.plotAbs = vhfGetStringFromData(parmData, @"#ABS");
    ops.plotRel = vhfGetStringFromData(parmData, @"#REL");
    ops.termi = vhfGetStringFromData(parmData, @"#ITR");

    typeL = vhfGetStringFromData(parmData, @"#TL");
    typeP = vhfGetStringFromData(parmData, @"#TP");
    typeA = vhfGetStringFromData(parmData, @"#TA");

    formC = vhfGetStringFromData(parmData, @"#FC");
    formR = vhfGetStringFromData(parmData, @"#FR");
    formO = vhfGetStringFromData(parmData, @"#FO");

#if 0
    /* beginNew contains the first characters of all the operators
     */
    addToBeginNew(ops.selectTool, beginNew);
    addToBeginNew(ops.selectTool2, beginNew);
    addToBeginNew(ops.circle, beginNew);
    addToBeginNew(ops.plotAbs, beginNew);
    addToBeginNew(ops.plotRel, beginNew);
    addToBeginNew(ops.flash, beginNew);
    addToBeginNew(ops.move, beginNew);
    addToBeginNew(ops.draw, beginNew);
    addToBeginNew(ops.coordX, beginNew);
    addToBeginNew(ops.coordY, beginNew);
    addToBeginNew(ops.coordI, beginNew);
    addToBeginNew(ops.coordJ, beginNew);
    addToBeginNew(ops.termi, beginNew);
    [beginNew appendString:DIGITS];

    ops.beginNew = [NSCharacterSet characterSetWithCharactersInString:beginNew];
#endif

    return YES;
}

/*
 * modified:  03.05.93 05.05.96 19.09.96 07.03.97
 * purpose:   load tools from aperture table
 * parameter: filename
 *
 * "code" = "D10"
 * "formCode" = "C", "O" or "R"
 * "typeCode" = "L", "P", or "A"
 * "width" = width of tool
 * "height" = height od tool
 */
- (BOOL)loadApertures:(NSString*)fileName
{   NSMutableString	*toolData;

    if ( !(toolData = [NSMutableString stringWithContentsOfFile:fileName]) )
        return NO;

    [tools release];
    tools = [[NSMutableArray array] retain];

    /* pen width, one entry for each pen */
    while ( 1 )
    {	float			w, h;
        NSString		*code, *formCode, *typeCode;
        NSMutableDictionary	*dict = [NSMutableDictionary dictionary];

        if (!vhfGetTypesFromData(toolData, @"sSCCS", @"#DCD", &code, &typeCode, &w, &h, &formCode))
            break;
        [dict setObject:code forKey:@"code"];
        [dict setObject:typeCode forKey:@"typeCode"];
        [dict setObject:formCode forKey:@"formCode"];
        [dict setObject:[NSNumber numberWithFloat:w * INCH / 1000.0] forKey:@"width"];
        [dict setObject:[NSNumber numberWithFloat:h * INCH / 1000.0] forKey:@"height"];
        [tools addObject:dict];
    }

    return YES;
}

- (BOOL)loadRS274XApertures:(NSData*)data
{   NSString		*dataStr, *macroStr = nil;
    NSScanner		*scanner;
    int			location, firstLoc, RS274XGerberFile = 0;

    dataStr = [[[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding] autorelease];

    //if ( !(toolData = [NSMutableString stringWithContentsOfFile:fileName]) )
    if ( !dataStr )
        return NO;

    scanner = [NSScanner scannerWithString:dataStr];
    [scanner setCaseSensitive:YES];
    firstLoc  = location = [scanner scanLocation];
    [scanner scanUpToString:@"G71" intoString:NULL];
    if ( [scanner scanString:@"G71" intoString:NULL] )
        state.inch = 0; // millimeters

    [scanner setScanLocation:location];
    while ( [scanner scanUpToString:@"FS" intoString:NULL] )
    {
        if ( [scanner scanString:@"FS" intoString:NULL] )
        {
            if ([self getFormatStatement:scanner])
            {   RS274XGerberFile = 1;
                break;
            }
        }
    }

    [scanner setScanLocation:location];
    while ( [scanner scanUpToString:@"MO" intoString:NULL] )
    {   int	inch = 0;

        if ( [scanner scanString:@"MO" intoString:NULL] &&
            ((inch=[scanner scanString:@"IN" intoString:NULL]) || [scanner scanString:@"MM" intoString:NULL]) )
        {
            state.inch = ( inch ) ? 1 : 0;
            break;
        }
    }
    [scanner setScanLocation:location];
    while ( [scanner scanUpToString:@"IP" intoString:NULL] )
    {   int	pos = 0;

        if ( [scanner scanString:@"IP" intoString:NULL] &&
            ((pos=[scanner scanString:@"POS" intoString:NULL]) || [scanner scanString:@"NEG" intoString:NULL]) )
        {
            state.pos = ( pos ) ? 1 : 0;
            break;
        }
    }

    /* set parms->res */
    if ( RS274XGerberFile && state.inch )
    {
        res = ( !state.formatX.y ) ? 1.0 : pow(10.0, ((int)state.formatX.y));
    }
    else if ( RS274XGerberFile )
    {
        res = ( !state.formatX.y ) ? (1.0*25.4) : pow(10.0, ((int)state.formatX.y))*25.4;
    }

    // load Apertures
    [scanner setScanLocation:firstLoc];

    /* get number of tools in aperture table */
    [scanner scanUpToString:@"%AD" intoString:NULL];
    if ( ![scanner scanString:@"%AD" intoString:NULL] )
        return NO; // no tools !!!!!

    [tools release];
    tools = [[NSMutableArray array] retain];

    // get macro file fileName.mac
    [scanner setScanLocation:location];
    [scanner scanUpToString:@"%AM" intoString:NULL];
    if ( [scanner scanString:@"%AM" intoString:NULL] )
        macroStr = dataStr;

    /* pen width, one entry for each pen */
    [scanner setScanLocation:location];
    while ( ![scanner isAtEnd] )
    {	float			w, h;
        NSString		*code, *formCode, *typeCode=@"A", *macro=0;
        NSMutableDictionary	*dict = [NSMutableDictionary dictionary];

        if ( ![self getToolFromData:scanner :macroStr :&code :&w :&h :&formCode :&macro] )
            continue;
        [dict setObject:code forKey:@"code"];
        [dict setObject:typeCode forKey:@"typeCode"];
        [dict setObject:formCode forKey:@"formCode"];
        [dict setObject:[NSNumber numberWithFloat:w * INCH] forKey:@"width"];
        [dict setObject:[NSNumber numberWithFloat:h * INCH] forKey:@"height"];
        if ( macro )
            [dict setObject:macro forKey:@"macro"];
        [tools addObject:dict];
    }
    return YES;
}

/* created:   1996-01-25
 * modified:  2002-10-26
 * parameter: gerberData	the Gerber data stream
 * purpose:   start interpretation of the contents of gerberData
 */
- importGerber:(NSData*)gerberData
{
    state.color = [NSColor colorWithCalibratedRed:0.0 green:0.0 blue:0.0 alpha:1.0];
    state.width = 0.0;

    state.pa = 1;

    if ( ![tools count] )
    {
        NSLog(@"No apertures loaded! Call 'loadApertures:' to load an aperture table.");
        return nil;
    }

    /* interpret data
     */
    if ( ![self interpret:[[[NSString alloc] initWithData:gerberData
                                                 encoding:NSASCIIStringEncoding] autorelease]] )
        return nil;

    return [list autorelease];
}

/* private methods
 */
- (BOOL)interpret:(NSString*)dataP
{   NSRect		bounds;
    NSScanner		*scanner = [NSScanner scannerWithString:dataP];

    digitsSet = [NSCharacterSet characterSetWithCharactersInString:DIGITS];
    invDigitsSet = [digitsSet invertedSet];

    /* init bounds */
    ll.x = ll.y = LARGE_COORD;
    ur.x = ur.y = LARGENEG_COORD;

    list = [self allocateList];

    while ( ![scanner isAtEnd] )
        if ( ![self getGraphicFromData:scanner :list] )
            break;

    if ( state.LPCSet )
        [self removeClearLayers:list];

    bounds.origin = ll;
    bounds.size.width = ur.x - ll.x;
    bounds.size.height = ur.y - ll.y;

    if ( !state.pos )
    {   state.color = [NSColor colorWithCalibratedRed:0.0 green:0.0 blue:0.0 alpha:1.0];
        state.width = 0;
        [self changeListPolarity:list bounds:bounds];
        bounds.origin.x -= 10.0;
        bounds.origin.y -= 10.0;
        bounds.size.width += 20.0;
        bounds.size.height += 20.0;
    }
    [self setBounds:bounds];
    return YES;
}

/* we need cp on a number !
 */
- (BOOL)getGraphicFromData:(NSScanner*)scanner :cList
{   int		d = 0, location;
    float	value;

    /* get light codes (move, draw, flash)
     * we have to asure that a tool of D30 is not missinterpreted as a light code of D3
     */
    location = [scanner scanLocation];
    [scanner scanString:ops.selectTool intoString:NULL];
    [scanner scanInt:&d];
    [scanner setScanLocation:location];
    if ( ([scanner scanString:ops.draw intoString:NULL] ||
         [scanner scanString:ops.draw01 intoString:NULL]) && d==1 ) // D01
    {
        state.lightCode = 1;
        return YES;
    }
    else if ( ([scanner scanString:ops.move intoString:NULL] ||
              [scanner scanString:ops.move02 intoString:NULL]) && d==2) // D02
    {
        state.lightCode = 2;
        return YES;
    }
    else if ( ([scanner scanString:ops.flash intoString:NULL] ||
              [scanner scanString:ops.flash03 intoString:NULL]) && d==3 ) // D03
    {
        state.lightCode = 3;
        state.draw = 1; /* x123y123D02* D03* */
        return YES;
    }
    [scanner setScanLocation:location];

    if ( [scanner scanString:ops.RS274X intoString:NULL] )
    {   [self getLayerPolarity:scanner]; // else step over RS274X statement

        if (!state.LPC && state.LPCSet)
        {
            [self removeClearLayers:list];
            state.LPCSet = 0;
        }
    }
    else if ( [scanner scanString:ops.comment intoString:NULL] )
    {   [scanner scanUpToString:ops.termi intoString:NULL];
        [scanner scanString:ops.termi intoString:NULL];
    }
    else if ( [scanner scanString:ops.polyBegin intoString:NULL] ) // G36	
    {
        state.lightCode = 2; // off
        state.draw = 1;
        state.path = 1;
        state.g = Gerber_PATH;
    }
    else if ( [scanner scanString:ops.polyEnd intoString:NULL] ) // G37
    {
        state.lightCode = 2; // off
        state.path = 0;
    }
    else if ( [scanner scanString:ops.coordX intoString:NULL] )
    {   NSString    *str;

        if ( state.zeros != 2 && [scanner scanFloat:&value] ) // Leading Zeros and dezimal points
        {
            state.x = DeviceResToInternal(value, res);
            state.draw = 1;
        }
        else if ( state.zeros == 2 && [scanner scanCharactersFromSet:digitsSet intoString:&str] )
        {
            value = [str floatValue];
            value *= pow(10, ((int)(state.formatX.x+state.formatX.y) - (int)[str length]));
            state.x = DeviceResToInternal(value, res);
            state.draw = 1;
        }
        else
            NSLog(@"Coordinate X expected at location: %d", [scanner scanLocation]);
    }
    else if ( [scanner scanString:ops.coordY intoString:NULL] )
    {   NSString    *str;

        if ( state.zeros != 2 && [scanner scanFloat:&value] ) // Leading Zeros and dezimal points
        {   state.y = DeviceResToInternal(value, res);
            state.draw = 1;
        }
        else if ( state.zeros == 2 && [scanner scanCharactersFromSet:digitsSet intoString:&str] )
        {
            value = [str floatValue];
            value *= pow(10, ((int)(state.formatY.x+state.formatY.y) - (int)[str length]));
            state.y = DeviceResToInternal(value, res);
            state.draw = 1;
        }
        else
            NSLog(@"Coordinate Y expected at location: %d", [scanner scanLocation]);
    }
    else if ( [scanner scanString:ops.coordI intoString:NULL] )
    {   NSString    *str;

        if ( state.zeros != 2 && [scanner scanFloat:&value] ) // Leading Zeros and dezimal points
        {   state.i = DeviceResToInternal(value, res);
            state.draw = 1;
        }
        else if ( state.zeros == 2 && [scanner scanCharactersFromSet:digitsSet intoString:&str] )
        {
            value = [str floatValue];
            value *= pow(10, ((int)(state.formatX.x+state.formatX.y) - (int)[str length]));
            state.i = DeviceResToInternal(value, res);
            state.draw = 1;
        }
        else
            NSLog(@"Coordinate I expected at location: %d", [scanner scanLocation]);
    }
    else if ( [scanner scanString:ops.coordJ intoString:NULL] )
    {   NSString    *str;

        if ( state.zeros != 2 && [scanner scanFloat:&value] ) // Leading Zeros and dezimal points
        {   state.j = DeviceResToInternal(value, res);
            state.draw = 1;
        }
        else if ( state.zeros == 2 && [scanner scanCharactersFromSet:digitsSet intoString:&str] )
        {
            value = [str floatValue];
            value *= pow(10, ((int)(state.formatX.x+state.formatX.y) - (int)[str length]));
            state.j = DeviceResToInternal(value, res);
            state.draw = 1;
        }
        else
            NSLog(@"Coordinate J expected at location: %d", [scanner scanLocation]);
    }
    else if ( [scanner scanString:ops.ipolQuarter intoString:NULL] )
        state.ipolFull = 0;
    else if ( [scanner scanString:ops.ipolFull intoString:NULL] )
        state.ipolFull = 1;
    else if ( [scanner scanString:ops.line intoString:NULL] )
    {   state.g = 0;
        state.draw = 0; /* so we didnt draw to early if its on */
    }
    else if ( [scanner scanString:ops.circleCW intoString:NULL] )
    {   state.g = Gerber_ARC;
        state.ccw = 0;
        state.draw = 0; /* so we didnt draw to early if its on */
    }
    else if ( [scanner scanString:ops.circleCCW intoString:NULL] )
    {   state.g = Gerber_ARC;
        state.ccw = 1;
        state.draw = 0; /* so we didnt draw to early if its on */
    }
    /*else if ( [scanner scanString:ops.circle intoString:NULL] )
    {
        state.g = Gerber_ARC;
    }
    else if ( [scanner scanString:ops.arc intoString:NULL] )
    {
        state.g = Gerber_ARC;
    }*/
    else if ( [scanner scanString:ops.selectTool intoString:NULL] )
        [self getTool:scanner];
    else if ( [scanner scanString:ops.selectTool2 intoString:NULL] )
        [self getTool:scanner];
    else if ( [scanner scanString:ops.plotAbs intoString:NULL] )
        [self getPlotAbs:scanner];
    else if ( [scanner scanString:ops.plotRel intoString:NULL] )
        [self getPlotRel:scanner];
    else if ( [scanner scanString:ops.termi intoString:NULL] )
    {
        if ( state.draw )
        {
            switch (state.lightCode)
            {
                case 1: /* on */
                    switch (state.g)
                    {
                        case Gerber_ARC:
                            [self setArc:cList];
                            break;
                        default:
                            [self setLine:cList];
                    }
//                    state.g = 0;
                    break;
                case 3: /* flash */
                    [self setPad:list];
                    state.g = 0;
                    break;
                default: /* off */
                    if (state.path && [cList count])
                        [self setLine:cList];
                    else
                    {   state.point.x = state.x;
                        state.point.y = state.y;
                    }
                    if ( state.path && state.g == Gerber_PATH )
                        [self setPath:scanner :cList];
                state.g = 0;
            }
            state.draw = 0;
        }
    }
    else
    {   // we cant step until termi cause we run over next statement if blank or \n follows !
        //  [scanner scanUpToString:ops.termi intoString:NULL];
        //  if (![scanner scanString:ops.termi intoString:NULL])
            [scanner setScanLocation:location+1];
        return YES;
    }

    return YES;
}

/*
 * created:      02.05.93
 * modified:     02.05.93 19.07.93 05.05.96 07.03.97
 * purpose:      return tool number of specified tool (cp = "D10* ...")
 * parameter:    scanner
 * return value: index of tool
 */
- (int)toolFromString:(NSScanner*)scanner
{   int		i, d, cnt = [tools count];

    [scanner scanInt:&d];
    for (i=0; i<cnt; i++)
    {	NSString	*code = [[tools objectAtIndex:i] objectForKey:@"code"];
        int		d1 = [[code substringFromIndex:[code rangeOfCharacterFromSet:digitsSet].location] intValue];

        if ( d==d1 )
            return i;
    }
    return -1;
}

/*
 * created:  
 * modified:  
 * purpose:   get FS
 * parameter: scanner
 */
- (BOOL)getFormatStatement:(NSScanner*)scanner
{   int	set=0, location, ok = 0;

    /* init if no LTD follows */
    state.zeros = 1;

    location = [scanner scanLocation];
    if ( [scanner scanString:@"L" intoString:NULL] ) // leading zeros omitted
    {   state.zeros = 1; set = 1; }
    else
    {   [scanner setScanLocation:location];
        if ( [scanner scanString:@"T" intoString:NULL] ) // trailing zeros omitted
        {   state.zeros = 2; set = 1; }
        else
        {   [scanner setScanLocation:location];
            if ( [scanner scanString:@"D" intoString:NULL] ) // decimal point - no zeros omitted
            {   state.zeros = 3; set = 1; }
            else
                [scanner setScanLocation:location];
        }
    }
    if ( [scanner scanString:@"A" intoString:NULL] ) // absolute coordinate mode
        state.pa = 1;
    else
    {   [scanner setScanLocation:location + ((set)?1:0)];
        if ( [scanner scanString:@"I" intoString:NULL] ) // incremental coordinate mode
            state.pa = 0;
        else
            [scanner setScanLocation:location + ((set)?1:0)];
    }

    [scanner scanUpToString:@"X" intoString:NULL];
    if ( [scanner scanString:@"X" intoString:NULL] ) // formatX
    {   int	value;
        NSString	*str, *str1;

        if ( ![scanner scanInt:&value] )
            NSLog(@"GerberImport: getFormatStatement no X values");
        str = [NSString stringWithFormat:@"%d", value];
        if ( [str length] != 2 )
            return ok;
        str1 = [str substringToIndex:1]; // first
        state.formatX.x = [str1 intValue];
        str1 = [str substringFromIndex:1]; // second
        state.formatX.y = [str1 intValue];
        ok = 1;
    }
    if ( [scanner scanString:@"Y" intoString:NULL] ) // formatY
    {   int	value;
        NSString	*str, *str1;

        if ( ![scanner scanInt:&value] )
            NSLog(@"GerberImport: getFormatStatement no Y values");
        str = [NSString stringWithFormat:@"%d", value];
        if ( [str length] != 2 )
            return ok;
        str1 = [str substringToIndex:1]; // first
        state.formatY.x = [str1 intValue];
        str1 = [str substringFromIndex:1]; // second
        state.formatY.y = [str1 intValue];
        ok = 1;
    }
    return ok;
}

- (BOOL)getToolFromData:(NSScanner*)scanner :(NSString*)macroData :(NSString**)code :(float*)w :(float*)h :(NSString**)formCode :(NSString**)macroStr
{   int		intVal;

    [scanner scanUpToString:@"AD" intoString:NULL];
    if ( [scanner scanString:@"AD" intoString:NULL] )
    {
        if ( ![scanner scanString:@"D" intoString:NULL] ) // not a D code
        {   [scanner scanUpToString:ops.termi intoString:NULL];
            [scanner scanString:ops.termi intoString:NULL];
            return NO;
        }
        [scanner scanInt:&intVal];
        *code = [NSString stringWithFormat:@"D%d", intVal];
    }
    else
        return NO;
    if ( [scanner scanString:@"C," intoString:NULL] ) // circle
        return [self getApertureCircle:scanner :w :h :formCode];
    else if ( [scanner scanString:@"R," intoString:NULL] ) // rectangle
        return [self getApertureRectangle:scanner :w :h :formCode];
    else if ( [scanner scanString:@"O," intoString:NULL] ) // obround
        return [self getApertureObround:scanner :w :h :formCode];
    else if ( [scanner scanString:@"P," intoString:NULL] ) // polygon
        return [self getAperturePolygon:scanner :w :h :formCode];
    else // macro
        return [self getApertureMacro:scanner :macroData :formCode :macroStr];
    return NO;
}

- (BOOL)getApertureCircle:(NSScanner*)scanner :(float*)w :(float*)h :(NSString**)formCode
{   float	fVal;

    *formCode = @"C";
    [scanner scanFloat:&fVal];
    if ( !state.inch )
        fVal = InchToMM(fVal); // /25.4
    *w = *h = fVal;
    [scanner scanUpToString:ops.termi intoString:NULL];
    [scanner scanString:ops.termi intoString:NULL];
    return YES;
}

- (BOOL)getApertureRectangle:(NSScanner*)scanner :(float*)w :(float*)h :(NSString**)formCode
{
    *formCode = @"R";
    [scanner scanFloat:w];
    if ( !state.inch )
        *w = InchToMM(*w); // /25.4
    if ( ![scanner scanString:@"X" intoString:NULL] )
    {
        *h = 0.0;
        [scanner scanUpToString:ops.termi intoString:NULL];
        [scanner scanString:ops.termi intoString:NULL];
        return YES;
    }
    [scanner scanFloat:h];
    if ( !state.inch )
        *h = InchToMM(*h); // /25.4
    [scanner scanUpToString:ops.termi intoString:NULL];
    [scanner scanString:ops.termi intoString:NULL];
    return YES;
}

- (BOOL)getApertureObround:(NSScanner*)scanner :(float*)w :(float*)h :(NSString**)formCode
{
    *formCode = @"OR"; // else we take octagon instead
    [scanner scanFloat:w];
    if ( !state.inch )
        *w = InchToMM(*w); // /25.4
    if ( ![scanner scanString:@"X" intoString:NULL] )
    {
        *h = 0.0;
        [scanner scanUpToString:ops.termi intoString:NULL];
        [scanner scanString:ops.termi intoString:NULL];
        return YES;
    }
    [scanner scanFloat:h];
    if ( !state.inch )
        *h = InchToMM(*h); // /25.4
    [scanner scanUpToString:ops.termi intoString:NULL];
    [scanner scanString:ops.termi intoString:NULL];
    return YES;
}

- (BOOL)getAperturePolygon:(NSScanner*)scanner :(float*)w :(float*)h :(NSString**)formCode
{   int	sides;

    *formCode = @"P"; // else we take octagon instead
    [scanner scanFloat:w];
    if ( !state.inch )
        *w = InchToMM(*w); // /25.4
    if ( ![scanner scanString:@"X" intoString:NULL] )
    {
        *h = 3.0; // minimum three sides
        [scanner scanUpToString:ops.termi intoString:NULL];
        [scanner scanString:ops.termi intoString:NULL];
        return YES;
    }
    [scanner scanInt:&sides];
    if ( sides > 12 ) sides = 12; // maximum 12 sides
    if ( sides < 3 ) sides = 3;
    *h = sides;
    [scanner scanUpToString:ops.termi intoString:NULL];
    [scanner scanString:ops.termi intoString:NULL];
    return YES;
}

void replaceFromByTo(NSString** macroStr, NSString* from, NSString* to, int cnt, float *vals)
{   NSRange		range, ra;
    NSString		*fromEqual = [from stringByAppendingFormat:@"="];
    NSCharacterSet	*stopSet = [NSCharacterSet characterSetWithCharactersInString:@"*,"];

    ra = [*macroStr rangeOfString:from];
    range = [*macroStr rangeOfString:fromEqual];
    if ( !range.length || ra.location < range.location )
        *macroStr = [*macroStr stringByReplacing:from by:to all:0];
    else // replace all following from with toNew
    {   NSString	*toNew, *from2New;
        int		i;

        // get toNew from fromEqual until ,*
        toNew = [*macroStr substringFromIndex:range.location+[fromEqual length]];
        range = [toNew rangeOfCharacterFromSet:stopSet];
        toNew = [toNew substringToIndex:range.location];
        // first remove fromEqualtoNew* -> only an variable set
        from2New = [NSString stringWithFormat:@"%@%@*", fromEqual, toNew];
        *macroStr = [*macroStr stringByReplacing:from2New by:@"" all:0];
        // set Values for toNew !!
        for (i=0; i<cnt; i++)
        {   NSString	*from3 = [NSString stringWithFormat:@"$%d", i+1];
            NSString	*to3 = [NSString stringWithFormat:@"%.3f", vals[i]];

            toNew = [toNew stringByReplacing:from3 by:to3];
        }
        while (1) // now we must replace all following from values with these values
        {   replaceFromByTo(macroStr, from, toNew, cnt, vals);
            range = [*macroStr rangeOfString:from];
            if ( !range.length )
                break;
        }
    }
}

- (BOOL)getApertureMacro:(NSScanner*)scanner :(NSString*)macroData :(NSString**)formCode :(NSString**)macroStr
{   NSString		*macroName;
    NSCharacterSet	*stopSet = [NSCharacterSet characterSetWithCharactersInString:@"*,"];

    if ( ![scanner scanUpToCharactersFromSet:stopSet intoString:&macroName] )
    {   [scanner scanUpToString:ops.termi intoString:NULL];
        [scanner scanString:ops.termi intoString:NULL];
        return NO; // no Macro name
    }
    *formCode = @"M";

    if ( ![scanner scanString:ops.termi intoString:NULL] )
    {
        if ( ![scanner scanString:@"," intoString:NULL] )
        {   [scanner scanUpToString:ops.termi intoString:NULL];
            [scanner scanString:ops.termi intoString:NULL];
            return NO;
        }
        else // the values follows directly behind , (comma) -> we must combine them with $1 values in macroData
        {   NSScanner	*mScanner = [NSScanner scannerWithString:macroData];
            NSString	*searchStr = [NSString stringWithFormat:@"%%AM%@", macroName];
            NSRange	range, rangeHack;
            int		i, cnt = 0;
            float	vals[200]; // I hope no one will write an greater macro

            // get macroStr from macroData
            [mScanner scanUpToString:searchStr intoString:NULL];
            if ( [mScanner scanString:searchStr intoString:NULL] )
                [mScanner scanUpToString:ops.RS274X intoString:macroStr];
            else
            {   [scanner scanUpToString:ops.RS274X intoString:NULL];
                [scanner scanString:ops.RS274X intoString:NULL];
                return NO;
            }
            // get values from scanner
            while (1) // ( ![scanner scanString:ops.termi intoString:NULL] )
            {
                [scanner scanFloat:&vals[cnt++]];
                if ( ![scanner scanString:@"X" intoString:NULL] )
                    break;
            }
            // replace $1, $2 $n with values from scanner
            range = [*macroStr rangeOfString:@"="];
            /* Eagle WorkAround */
            rangeHack = [*macroStr rangeOfString:@"X$"];
            for (i=0; i<cnt; i++)
            {   NSString	*from = [NSString stringWithFormat:@"$%d", i+1];
                NSString	*to = [NSString stringWithFormat:@"%.3f", vals[i]];

                /* Eagle WorkAround */
                if ( rangeHack.length )
                {   NSScanner	*mcrScanner = [NSScanner scannerWithString:*macroStr];
                    NSString	*string;

                    NSLog(@"Eagle WorkAround wurde aktiviert\n");
                    /*  * 5,1,8,0,0,1.08239X$1,22.5  - werte zwischen den Kommas */
                    /* we must remove the float before/and the X */
                    /* and we must set the last float to 0 - rotation of polygon */

                    while ( ![mcrScanner isAtEnd] )
                    {
                        [mcrScanner scanUpToString:@"," intoString:&string];
                        rangeHack = [string rangeOfString:@"X$"];
                        /* this is our string part - wert zwischen den kommas */
                        if ( rangeHack.length )
                        {   NSScanner		*mmScanner = [NSScanner scannerWithString:string];
                            NSMutableString	*fromHack = [NSMutableString stringWithString:string], *toHack;
                            NSString		*restString;

                            [mcrScanner scanUpToString:@"*" intoString:&restString]; // ,22.5 rotation
                            [fromHack appendString:restString];

                            [mmScanner scanUpToString:@"$" intoString:NULL]; // bis $
                            [mmScanner scanUpToString:@"," intoString:&toHack]; // bis , -> $1 oder $3

                            /* and we must set the last float to 0 - rotation of polygon */
                            toHack = [NSMutableString stringWithString:toHack];
                            [toHack appendString:@",0"]; // no rotation
                            *macroStr = [*macroStr stringByReplacing:fromHack by:toHack];
                            break;
                        }
                        [mcrScanner scanString:@"," intoString:NULL];
                    }
                }

                if ( !range.length )
                    *macroStr = [*macroStr stringByReplacing:from by:to];
                else
                {
                    while (1)
                    {   replaceFromByTo(macroStr, from, to, cnt, vals);
                        range = [*macroStr rangeOfString:from];
                        if ( !range.length )
                            break;
                    }
                }
            }
            [scanner scanString:ops.termi intoString:NULL];
        }
    }
    else // only the name follows -> the values are in macroData
    {   NSScanner	*mScanner = [NSScanner scannerWithString:macroData];
        NSString	*searchStr = [NSString stringWithFormat:@"%%AM%@", macroName];

        // get macroStr from macroData
        [mScanner scanUpToString:searchStr intoString:NULL];
        if ( [mScanner scanString:searchStr intoString:NULL] )
            [mScanner scanUpToString:ops.RS274X intoString:macroStr];
        else
        {   [scanner scanUpToString:ops.termi intoString:NULL];
            [scanner scanString:ops.termi intoString:NULL];
            return NO;
        }
        [scanner scanString:ops.termi intoString:NULL];
    }
    // replace all X with ,
    *macroStr = [*macroStr stringByReplacing:@"X" by:@","];

    return YES;
}

/*
 * created:   12.01.01
 * modified:  12.01.01
 * purpose:   get layer polarity
 * parameter: scanner
 *            state
 *            parms
 */
- (BOOL)getLayerPolarity:(NSScanner*)scanner
{
    // until %
    while ( ![scanner scanString:ops.RS274X intoString:NULL] && ![scanner isAtEnd] )
    {
        if ( [scanner scanString:@"LP" intoString:NULL] ) // no layer polarity
        {
            if ( [scanner scanString:@"C" intoString:NULL] ) // no layer polarity
            {   state.LPC = 1;
                state.LPCSet = 1; // needed at end -> than we must remove hidden areas
                state.color = [NSColor colorWithCalibratedRed:1.0 green:1.0 blue:1.0 alpha:1.0];
            }
            else if ( [scanner scanString:@"D" intoString:NULL] ) // no layer polarity
            {   state.LPC = 0;
                state.color = [NSColor colorWithCalibratedRed:0.0 green:0.0 blue:0.0 alpha:1.0];
            }
            [scanner scanUpToString:ops.RS274X intoString:NULL];
        }
        else
        {   [scanner scanUpToString:ops.termi intoString:NULL];
            [scanner scanString:ops.termi intoString:NULL];
        }
    }
    return YES;
}

/*
 * created:   xx.12.92
 * modified:  02.05.93 19.07.93 05.05.96 08.03.97
 * purpose:   get tool
 * parameter: scanner
 *            state
 *            parms
 */
- (BOOL)getTool:(NSScanner*)scanner
{
    if ( (state.tool = [self toolFromString:scanner]) < 0 )
    {
        NSLog(@"Gerber import, Can't find tool at location %d. Default used.", [scanner scanLocation]);
        state.tool = 0;
    }
    [scanner scanUpToString:ops.termi intoString:NULL];
    [scanner scanString:ops.termi intoString:NULL];

    return YES;
}

/*
 * modified:  16.12.92
 * purpose:   get status plot absolut
 * parameter: cp
 * return:    cp
 */
- (BOOL)getPlotAbs:(NSScanner*)scanner
{
    state.pa = 1;
    return YES;
}

/*
 * modified:  16.12.92
 * purpose:   get status plot relativ
 * parameter: cp
 */
- (BOOL)getPlotRel:(NSScanner*)scanner
{
    state.pa = 0;
    return YES;
}

- (float)getMacroAngleValue:(NSScanner*)scanner
{   NSString		*valStr;
    NSCharacterSet	*calcSet = [NSCharacterSet characterSetWithCharactersInString:@"+-"];
    NSRange		range;
    float		val=0.0;

    if ( ![scanner scanUpToString:ops.termi intoString:&valStr] )
        return 0.0;
    range = [valStr rangeOfCharacterFromSet:calcSet];
    if ( range.length )
    {   NSScanner	*scnr = [NSScanner scannerWithString:valStr];
        float		f;

        while (![scnr isAtEnd])
        {
            if ( [scnr scanString:@"+" intoString:NULL] )
            {
                if ( ![scnr scanFloat:&f] ) return 0.0;
                val += f;
            }
            else if ( [scnr scanString:@"-" intoString:NULL] )
            {
                if ( ![scnr scanFloat:&f] ) return 0.0;
                val -= f;
            }
        }
    }
    else
        val = [valStr floatValue];
    return val;
}
- (float)getMacroFloatValue:(NSScanner*)scanner
{   NSString		*valStr;
    NSCharacterSet	*calcSet = [NSCharacterSet characterSetWithCharactersInString:@"+-/x"];
    NSRange		range;
    float		val=0.0;
    NSCharacterSet	*stopSet = [NSCharacterSet characterSetWithCharactersInString:@"*,"];

    if ( ![scanner scanUpToCharactersFromSet:stopSet intoString:&valStr] )
        return 0.0;
    range = [valStr rangeOfCharacterFromSet:calcSet];
    if ( range.length )
    {   NSScanner	*scnr = [NSScanner scannerWithString:valStr];
        float		f;

        if ( ![scnr scanFloat:&val] )
            return 0.0;

        while (![scnr isAtEnd])
        {
            if ( [scnr scanString:@"+" intoString:NULL] )
            {
                if ( ![scnr scanFloat:&f] ) return 0.0;
                val += f;
            }
            else if ( [scnr scanString:@"-" intoString:NULL] )
            {
                if ( ![scnr scanFloat:&f] ) return 0.0;
                val -= f;
            }
            else if ( [scnr scanString:@"/" intoString:NULL] )
            {
                if ( ![scnr scanFloat:&f] ) return 0.0;
                val /= f;
            }
            else if ( [scnr scanString:@"x" intoString:NULL] )
            {
                if ( ![scnr scanFloat:&f] ) return 0.0;
                val *= f;
            }
            else break;
        }
    }
    else
        val = [valStr floatValue];
    if ( !state.inch )
        val = InchToMM(val); // /25.4
    return val * INCH;
}

// ,i,f,f,f* // i == 0 -> color is white !
- (void)getMacroCircle:(NSScanner*)scanner :mList :(NSPoint*)llur
{   float	cx, cy, r;
    int		on;

    if ( ![scanner scanString:@"," intoString:NULL] )
        return;
    [scanner scanInt:&on];
    if ( ![scanner scanString:@"," intoString:NULL] )
        return;
    r = [self getMacroFloatValue:scanner]/2.0;
    if ( ![scanner scanString:@"," intoString:NULL] )
        return;
    cx = [self getMacroFloatValue:scanner];
    if ( ![scanner scanString:@"," intoString:NULL] )
        return;
    cy = [self getMacroFloatValue:scanner];

    if ( !on ) state.color = [NSColor colorWithCalibratedRed:1.0 green:1.0 blue:1.0 alpha:1.0];
    else      state.color = [NSColor colorWithCalibratedRed:0.0 green:0.0 blue:0.0 alpha:1.0];

    [self addCircle:NSMakePoint(cx, cy) :r filled:YES toList:mList];
    if ( (cx - r) < llur[0].x ) llur[0].x = cx - r;
    if ( (cy - r) < llur[0].y ) llur[0].y = cy - r;
    if ( (cx + r) > llur[1].x ) llur[1].x = cx + r;
    if ( (cy + r) > llur[1].y ) llur[1].y = cy + r;
}

// ,i,w,s,s,e,e,rot* // i == 0 -> color is white !
- (void)getMacroRectLine:(NSScanner*)scanner :mList :(NSPoint*)llur
{   float		w, h, sx, sy, ex, ey, a;
    int			on;
    NSPoint		c, pll, plr, pur, pul; // four points of line
    NSMutableArray	*pList=[[[self allocateList] init] autorelease];

    if ( ![scanner scanString:@"," intoString:NULL] )
        return;
    [scanner scanInt:&on];
    if ( ![scanner scanString:@"," intoString:NULL] )
        return;
    h = [self getMacroFloatValue:scanner];
    if ( ![scanner scanString:@"," intoString:NULL] )
        return;
    sx = [self getMacroFloatValue:scanner];
    if ( ![scanner scanString:@"," intoString:NULL] )
        return;
    sy = [self getMacroFloatValue:scanner];
    if ( ![scanner scanString:@"," intoString:NULL] )
        return;
    ex = [self getMacroFloatValue:scanner];
    if ( ![scanner scanString:@"," intoString:NULL] )
        return;
    ey = [self getMacroFloatValue:scanner];
    if ( ![scanner scanString:@"," intoString:NULL] )
        return;
    a = [self getMacroAngleValue:scanner];

    if ( !on ) state.color = [NSColor colorWithCalibratedRed:1.0 green:1.0 blue:1.0 alpha:1.0];
    else      state.color = [NSColor colorWithCalibratedRed:0.0 green:0.0 blue:0.0 alpha:1.0];

    // set 4 points
    w = Diff(sx, ex);
    c.x = sx + w/2.0; c.y = sy;
    pll.x = sx; pll.y = sy - h/2.0;
    plr.x = ex; plr.y = pll.y;
    pul.x = sx; pul.y = sy + h/2.0;
    pur.x = ex; pur.y = pul.y;

    if ( !h ) // add only one line !
    {
        if ( a ) // rotate two points
        {   pll = vhfPointRotatedAroundCenter(pll, a, c);
            plr = vhfPointRotatedAroundCenter(plr, a, c);
        }
        [self addLine:pll :plr toList:mList];
        return;
    }
    if ( a ) // rotate 4 points if necessary
    {   pll = vhfPointRotatedAroundCenter(pll, a, c);
        plr = vhfPointRotatedAroundCenter(plr, a, c);
        pur = vhfPointRotatedAroundCenter(pur, a, c);
        pul = vhfPointRotatedAroundCenter(pul, a, c);
    }
    // add 4 lines to pList
    [self addLine:pll :plr toList:pList];
    [self addLine:plr :pur toList:pList];
    [self addLine:pur :pul toList:pList];
    [self addLine:pul :pll toList:pList];

    if ( [pList count] )
    {
        [self addFillPath:pList toList:mList];
        c.x = Min(Min(Min(pll.x, plr.x), pur.x), pul.x);  c.y = Min(Min(Min(pll.y, plr.y), pur.y), pul.y);
        if ( c.x < llur[0].x ) llur[0].x = c.x;
        if ( c.y < llur[0].y ) llur[0].y = c.y;
        c.x = Max(Max(Max(pll.x, plr.x), pur.x), pul.x);  c.y = Max(Max(Max(pll.y, plr.y), pur.y), pul.y);
        if ( c.x > llur[1].x ) llur[1].x = c.x;
        if ( c.y > llur[1].y ) llur[1].y = c.y;
    }
}

// ,i,w,h,c,c,rot* // i == 0 -> color is white !
- (void)getMacroRectCenter:(NSScanner*)scanner :mList :(NSPoint*)llur
{   float		w, h, cx, cy, a;
    int			on;
    NSPoint		c, pll, plr, pur, pul; // four points of line
    NSMutableArray	*pList=[[[self allocateList] init] autorelease];

    if ( ![scanner scanString:@"," intoString:NULL] )
        return;
    [scanner scanInt:&on];
    if ( ![scanner scanString:@"," intoString:NULL] )
        return;
    w = [self getMacroFloatValue:scanner];
    if ( ![scanner scanString:@"," intoString:NULL] )
        return;
    h = [self getMacroFloatValue:scanner];
    if ( ![scanner scanString:@"," intoString:NULL] )
        return;
    if ( !w || !h )
        return;
    cx = [self getMacroFloatValue:scanner];
    if ( ![scanner scanString:@"," intoString:NULL] )
        return;
    cy = [self getMacroFloatValue:scanner];
    if ( ![scanner scanString:@"," intoString:NULL] )
        return;
    a = [self getMacroAngleValue:scanner];

    if ( !on ) state.color = [NSColor colorWithCalibratedRed:1.0 green:1.0 blue:1.0 alpha:1.0];
    else      state.color = [NSColor colorWithCalibratedRed:0.0 green:0.0 blue:0.0 alpha:1.0];

    // set 4 points
    pll.x = cx - w/2.0; pll.y = cy - h/2.0;
    plr.x = cx + w/2.0; plr.y = pll.y;
    pul.x = pll.x; pul.y = cy + h/2.0;
    pur.x = plr.x; pur.y = pul.y;

    if ( a ) // rotate 4 points if necessary
    {   c.x = cx; c.y = cy;
        pll = vhfPointRotatedAroundCenter(pll, a, c);
        plr = vhfPointRotatedAroundCenter(plr, a, c);
        pur = vhfPointRotatedAroundCenter(pur, a, c);
        pul = vhfPointRotatedAroundCenter(pul, a, c);
    }
    // add 4 lines to pList
    [self addLine:pll :plr toList:pList];
    [self addLine:plr :pur toList:pList];
    [self addLine:pur :pul toList:pList];
    [self addLine:pul :pll toList:pList];

    if ( [pList count] )
    {
        [self addFillPath:pList toList:mList];
        c.x = Min(Min(Min(pll.x, plr.x), pur.x), pul.x);  c.y = Min(Min(Min(pll.y, plr.y), pur.y), pul.y);
        if ( c.x < llur[0].x ) llur[0].x = c.x;
        if ( c.y < llur[0].y ) llur[0].y = c.y;
        c.x = Max(Max(Max(pll.x, plr.x), pur.x), pul.x);  c.y = Max(Max(Max(pll.y, plr.y), pur.y), pul.y);
        if ( c.x > llur[1].x ) llur[1].x = c.x;
        if ( c.y > llur[1].y ) llur[1].y = c.y;
    }
}

// ,i,w,h,ll,ll,rot* // i == 0 -> color is white !
- (void)getMacroRect:(NSScanner*)scanner :mList :(NSPoint*)llur
{   float		w, h, llx, lly, a;
    int			on;
    NSPoint		c, pll, plr, pur, pul; // four points of line
    NSMutableArray	*pList=[[[self allocateList] init] autorelease];

    if ( ![scanner scanString:@"," intoString:NULL] )
        return;
    [scanner scanInt:&on];
    if ( ![scanner scanString:@"," intoString:NULL] )
        return;
    w = [self getMacroFloatValue:scanner];
    if ( ![scanner scanString:@"," intoString:NULL] )
        return;
    h = [self getMacroFloatValue:scanner];
    if ( ![scanner scanString:@"," intoString:NULL] )
        return;
    if ( !w || !h )
        return;
    llx = [self getMacroFloatValue:scanner];
    if ( ![scanner scanString:@"," intoString:NULL] )
        return;
    lly = [self getMacroFloatValue:scanner];
    if ( ![scanner scanString:@"," intoString:NULL] )
        return;
    a = [self getMacroAngleValue:scanner];

    if ( !on ) state.color = [NSColor colorWithCalibratedRed:1.0 green:1.0 blue:1.0 alpha:1.0];
    else      state.color = [NSColor colorWithCalibratedRed:0.0 green:0.0 blue:0.0 alpha:1.0];

    // set 4 points
    pll.x = llx; pll.y = lly;
    plr.x = llx + w; plr.y = pll.y;
    pul.x = pll.x; pul.y = lly + h;
    pur.x = plr.x; pur.y = pul.y;

    if ( a ) // rotate 4 points if necessary
    {   c.x = pll.x + w/2.0;
        c.y = pll.y + h/2.0;
        pll = vhfPointRotatedAroundCenter(pll, a, c);
        plr = vhfPointRotatedAroundCenter(plr, a, c);
        pur = vhfPointRotatedAroundCenter(pur, a, c);
        pul = vhfPointRotatedAroundCenter(pul, a, c);
    }
    // add 4 lines to pList
    [self addLine:pll :plr toList:pList];
    [self addLine:plr :pur toList:pList];
    [self addLine:pur :pul toList:pList];
    [self addLine:pul :pll toList:pList];

    if ( [pList count] )
    {
        [self addFillPath:pList toList:mList];
        c.x = Min(Min(Min(pll.x, plr.x), pur.x), pul.x);  c.y = Min(Min(Min(pll.y, plr.y), pur.y), pul.y);
        if ( c.x < llur[0].x ) llur[0].x = c.x;
        if ( c.y < llur[0].y ) llur[0].y = c.y;
        c.x = Max(Max(Max(pll.x, plr.x), pur.x), pul.x);  c.y = Max(Max(Max(pll.y, plr.y), pur.y), pul.y);
        if ( c.x > llur[1].x ) llur[1].x = c.x;
        if ( c.y > llur[1].y ) llur[1].y = c.y;
    }
}

// ,i,n,h,s,s,p1,p1,...,rot* // i == 0 -> color is white ! ; n number of points ; closed first == last
- (void)getMacroOutline:(NSScanner*)scanner :mList :(NSPoint*)llur
{   float		a;
    int			i, on, n;
    NSPoint		p[51], pll, pur;
    NSMutableArray	*pList=[[[self allocateList] init] autorelease];

    if ( ![scanner scanString:@"," intoString:NULL] )
        return;
    [scanner scanInt:&on];
    if ( ![scanner scanString:@"," intoString:NULL] )
        return;
    [scanner scanInt:&n];
    if ( ![scanner scanString:@"," intoString:NULL] )
        return;
    if ( n > 50 )
        return;

    pll.x = pll.y = LARGE_COORD;
    pur.x = pur.y = LARGENEG_COORD;
    for (i=0; i<n+1; i++) // n are additional points !
    {
        p[i].x = [self getMacroFloatValue:scanner];
        if ( ![scanner scanString:@"," intoString:NULL] )
            return;
        p[i].y = [self getMacroFloatValue:scanner];
        if ( ![scanner scanString:@"," intoString:NULL] )
            return;
        if ( p[i].x < pll.x ) pll.x = p[i].x;
        if ( p[i].y < pll.y ) pll.y = p[i].y;
        if ( p[i].x > pur.x ) pur.x = p[i].x;
        if ( p[i].y > pur.y ) pur.y = p[i].y;
    }
    a = [self getMacroAngleValue:scanner];

    if ( !on ) state.color = [NSColor colorWithCalibratedRed:1.0 green:1.0 blue:1.0 alpha:1.0];
    else      state.color = [NSColor colorWithCalibratedRed:0.0 green:0.0 blue:0.0 alpha:1.0];

    if ( a ) // rotate points if necessary
    {   NSPoint	c;
        c.x = pll.x + Diff(pll.x, pur.x)/2.0;
        c.y = pll.y + Diff(pll.y, pur.y)/2.0;
        for (i=0; i<n+1; i++)
        {   p[i] = vhfPointRotatedAroundCenter(p[i], a, c);
            if ( p[i].x < pll.x ) pll.x = p[i].x;
            if ( p[i].y < pll.y ) pll.y = p[i].y;
            if ( p[i].x > pur.x ) pur.x = p[i].x;
            if ( p[i].y > pur.y ) pur.y = p[i].y;
        }
    }

    // add lines to pList
    for (i=0; i<n; i++) // i+1 is ok - we have n+1 points (start + n points)
        [self addLine:p[i] :p[i+1] toList:pList];

    if ( [pList count] )
    {
        [self addFillPath:pList toList:mList];
        if ( pll.x < llur[0].x ) llur[0].x = pll.x;
        if ( pll.y < llur[0].y ) llur[0].y = pll.y;
        if ( pur.x > llur[1].x ) llur[1].x = pur.x;
        if ( pur.y > llur[1].y ) llur[1].y = pur.y;
    }
}

// ,i,n,c,c,dia,rot* // i == 0 -> color is white !
- (void)getMacroPolygon:(NSScanner*)scanner :mList :(NSPoint*)llur
{   float		a, dia, cx, cy, r, alpha, a2;
    int			on, n, i;
    NSPoint		pll, pur, p[10]; // four points of line
    NSMutableArray	*pList=[[[self allocateList] init] autorelease];

    if ( ![scanner scanString:@"," intoString:NULL] )
        return;
    [scanner scanInt:&on];
    if ( ![scanner scanString:@"," intoString:NULL] )
        return;
    [scanner scanInt:&n];
    if ( ![scanner scanString:@"," intoString:NULL] )
        return;
    if ( n < 3 || n > 10 )
        return;
    cx = [self getMacroFloatValue:scanner];
    if ( ![scanner scanString:@"," intoString:NULL] )
        return;
    cy = [self getMacroFloatValue:scanner];
    if ( ![scanner scanString:@"," intoString:NULL] )
        return;
    dia = [self getMacroFloatValue:scanner];
    if ( ![scanner scanString:@"," intoString:NULL] )
        return;
    a = [self getMacroAngleValue:scanner];

    if ( !dia )
        return;

    if ( !on ) state.color = [NSColor colorWithCalibratedRed:1.0 green:1.0 blue:1.0 alpha:1.0];
    else      state.color = [NSColor colorWithCalibratedRed:0.0 green:0.0 blue:0.0 alpha:1.0];

    alpha = 360.0 / n; // angle per side
    a2 = alpha / 2.0;
    r = (dia/2.0) / cos(DegToRad(a2));

    // set points
    pll.x = pll.y = LARGE_COORD;
    pur.x = pur.y = LARGENEG_COORD;
    for (i=0; i<n; i++)
    {	double	angle = DegToRad(a + a2 + i * alpha);

        p[i].x = cx + r*cos(angle);
        p[i].y = cy + r*sin(angle);
        if ( p[i].x < pll.x ) pll.x = p[i].x;
        if ( p[i].y < pll.y ) pll.y = p[i].y;
        if ( p[i].x > pur.x ) pur.x = p[i].x;
        if ( p[i].y > pur.y ) pur.y = p[i].y;
    }
    // add lines to list
    for (i=0; i<n; i++)
        [self addLine:p[i] :(i >= n-1) ? p[0] : p[i+1] toList:pList];

    if ( [pList count] )
    {
        [self addFillPath:pList toList:mList];
        if ( pll.x < llur[0].x ) llur[0].x = pll.x;
        if ( pll.y < llur[0].y ) llur[0].y = pll.y;
        if ( pur.x > llur[1].x ) llur[1].x = pur.x;
        if ( pur.y > llur[1].y ) llur[1].y = pur.y;
    }
}

// ,c,c,dia,w,gap,n,wCr,lCr,rot*
- (void)getMacroMoire:(NSScanner*)scanner :mList :(NSPoint*)llur
{   float		a, dia, cx, cy, lineW, gap, wCross, lenCross, r1, r2;
    int			n, i;
    NSPoint		pll, pur, center; // four points of line

    if ( ![scanner scanString:@"," intoString:NULL] )
        return;
    cx = [self getMacroFloatValue:scanner];
    if ( ![scanner scanString:@"," intoString:NULL] )
        return;
    cy = [self getMacroFloatValue:scanner];
    if ( ![scanner scanString:@"," intoString:NULL] )
        return;
    dia = [self getMacroFloatValue:scanner];
    if ( ![scanner scanString:@"," intoString:NULL] )
        return;
    lineW = [self getMacroFloatValue:scanner];
    if ( ![scanner scanString:@"," intoString:NULL] )
        return;
    gap = [self getMacroFloatValue:scanner];
    if ( ![scanner scanString:@"," intoString:NULL] )
        return;
    [scanner scanInt:&n];
    if ( ![scanner scanString:@"," intoString:NULL] )
        return;
    wCross = [self getMacroFloatValue:scanner];
    if ( ![scanner scanString:@"," intoString:NULL] )
        return;
    lenCross = [self getMacroFloatValue:scanner];
    if ( ![scanner scanString:@"," intoString:NULL] )
        return;
    a = [self getMacroAngleValue:scanner];

    if ( !dia ) return;

    state.color = [NSColor colorWithCalibratedRed:0.0 green:0.0 blue:0.0 alpha:1.0];

    r1 = (dia/2.0);
    r2 = r1 - lineW;

    if ( lenCross > r1 ) // cross hair greater than circles
    {   pll.x = cx - lenCross/2.0; pll.y = cy - lenCross/2.0;
        pur.x = pll.x + lenCross; pur.y = pll.y + lenCross;
    }
    else
    {   pll.x = cx - r1; pll.y = cy - r1;
        pur.x = cx + r1; pur.y = cy + r1;
    }
    // add n filled donuts (path) to pList
    center.x = cx;
    center.y = cy;
    for (i=0; i<n; i++)
    {   NSMutableArray	*dList=[[[self allocateList] init] autorelease];

        [self addCircle:center :r1 filled:YES toList:dList];
        [self addCircle:center :r2 filled:YES toList:dList];
        r1 = r2 - gap;
        r2 = r1 - lineW;
        [self addFillPath:dList toList:mList];

        if ( r1 < 0 || r2 < 0 ) break;
    }
    // add crosshair to list
    if ( wCross && lenCross )
    {   NSMutableArray	*dList=[[[self allocateList] init] autorelease];
        NSPoint		p[4];

        // set 4 points of vertical ( | ) line
        p[0].x = cx - wCross/2.0; p[0].y = cy - lenCross/2.0;
        p[1].x = p[0].x + wCross; p[1].y = p[0].y;
        p[2].x = p[1].x; p[2].y = p[1].y + lenCross;
        p[3].x = p[0].x; p[3].y = p[2].y;

        if ( a ) // rotate 4 points if necessary
            for (i=0; i<4; i++)
            {   p[i] = vhfPointRotatedAroundCenter(p[i], a, center);
                if ( p[i].x < pll.x ) pll.x = p[i].x;
                if ( p[i].y < pll.y ) pll.y = p[i].y;
                if ( p[i].x > pur.x ) pur.x = p[i].x;
                if ( p[i].y > pur.y ) pur.y = p[i].y;
            }
        // add 4 lines to dList
        [self addLine:p[0] :p[1] toList:dList];
        [self addLine:p[1] :p[2] toList:dList];
        [self addLine:p[2] :p[3] toList:dList];
        [self addLine:p[3] :p[0] toList:dList];

        [self addFillPath:dList toList:mList];
        dList=[[[self allocateList] init] autorelease];

        // set 4 points of horicontal line
        p[0].x = cx - lenCross/2.0; p[0].y = cy - wCross/2.0;
        p[1].x = p[0].x + lenCross; p[1].y = p[0].y;
        p[2].x = p[1].x; p[2].y = p[1].y + wCross;
        p[3].x = p[0].x; p[3].y = p[2].y;

        if ( a ) // rotate 4 points if necessary
            for (i=0; i<4; i++)
            {   p[i] = vhfPointRotatedAroundCenter(p[i], a, center);
                if ( p[i].x < pll.x ) pll.x = p[i].x;
                if ( p[i].y < pll.y ) pll.y = p[i].y;
                if ( p[i].x > pur.x ) pur.x = p[i].x;
                if ( p[i].y > pur.y ) pur.y = p[i].y;
            }
        // add 4 lines to dList
        [self addLine:p[0] :p[1] toList:dList];
        [self addLine:p[1] :p[2] toList:dList];
        [self addLine:p[2] :p[3] toList:dList];
        [self addLine:p[3] :p[0] toList:dList];

        [self addFillPath:dList toList:mList];
    }
    if ( pll.x < llur[0].x ) llur[0].x = pll.x;
    if ( pll.y < llur[0].y ) llur[0].y = pll.y;
    if ( pur.x > llur[1].x ) llur[1].x = pur.x;
    if ( pur.y > llur[1].y ) llur[1].y = pur.y;
}

// ,c,c,dOut,dIn,wCr,rot*
- (void)getMacroThermal:(NSScanner*)scanner :mList :(NSPoint*)llur
{   float		a, dIn, dOut, cx, cy, wCross, dOut2;
    int			i;
    NSPoint		pll, pur, center; // four points of line

    if ( ![scanner scanString:@"," intoString:NULL] )
        return;
    cx = [self getMacroFloatValue:scanner];
    if ( ![scanner scanString:@"," intoString:NULL] )
        return;
    cy = [self getMacroFloatValue:scanner];
    if ( ![scanner scanString:@"," intoString:NULL] )
        return;
    dOut = [self getMacroFloatValue:scanner];
    if ( ![scanner scanString:@"," intoString:NULL] )
        return;
    dIn = [self getMacroFloatValue:scanner];
    if ( ![scanner scanString:@"," intoString:NULL] )
        return;
    wCross = [self getMacroFloatValue:scanner];
    if ( ![scanner scanString:@"," intoString:NULL] )
        return;
    a = [self getMacroAngleValue:scanner];

    if ( !dOut || !dIn || !wCross ) return;

    dOut2 = dOut/2.0;

    pll.x = cx - dOut2; pll.y = cy - dOut2;
    pur.x = cx + dOut2; pur.y = cy + dOut2;

    // add filled donuts (path) to mList
    state.color = [NSColor colorWithCalibratedRed:0.0 green:0.0 blue:0.0 alpha:1.0];
    center.x = cx;
    center.y = cy;
    {   NSMutableArray	*dList=[[[self allocateList] init] autorelease];

        [self addCircle:center :dOut2 filled:YES toList:dList];
        [self addCircle:center :dIn/2.0 filled:YES toList:dList];
        [self addFillPath:dList toList:mList];
    }
    // add crosshair to list
    state.color = [NSColor colorWithCalibratedRed:1.0 green:1.0 blue:1.0 alpha:1.0];
    {   NSMutableArray	*dList=[[[self allocateList] init] autorelease];
        NSPoint		p[4];

        // set 4 points of vertical ( | ) line
        p[0].x = cx - (wCross/2.0 + 1.0); p[0].y = cy - (dOut2 + 1.0);
        p[1].x = p[0].x + wCross + 2.0; p[1].y = p[0].y;
        p[2].x = p[1].x; p[2].y = p[1].y + dOut + 2.0;
        p[3].x = p[0].x; p[3].y = p[2].y;

        if ( a ) // rotate 4 points if necessary
            for (i=0; i<4; i++)
            {   p[i] = vhfPointRotatedAroundCenter(p[i], a, center);
                if ( p[i].x < pll.x ) pll.x = p[i].x;
                if ( p[i].y < pll.y ) pll.y = p[i].y;
                if ( p[i].x > pur.x ) pur.x = p[i].x;
                if ( p[i].y > pur.y ) pur.y = p[i].y;
            }
        // add 4 lines to dList
        [self addLine:p[0] :p[1] toList:dList];
        [self addLine:p[1] :p[2] toList:dList];
        [self addLine:p[2] :p[3] toList:dList];
        [self addLine:p[3] :p[0] toList:dList];

        [self addFillPath:dList toList:mList];

        // set 4 points of horicontal ( –  ) line
        p[0].x = cx - (dOut2 + 1.0); p[0].y = cy - (wCross/2.0 + 1.0);
        p[1].x = p[0].x + dOut + 2.0; p[1].y = p[0].y;
        p[2].x = p[1].x; p[2].y = p[1].y + wCross + 2.0;
        p[3].x = p[0].x; p[3].y = p[2].y;

        if ( a ) // rotate 4 points if necessary
            for (i=0; i<4; i++)
            {   p[i] = vhfPointRotatedAroundCenter(p[i], a, center);
                if ( p[i].x < pll.x ) pll.x = p[i].x;
                if ( p[i].y < pll.y ) pll.y = p[i].y;
                if ( p[i].x > pur.x ) pur.x = p[i].x;
                if ( p[i].y > pur.y ) pur.y = p[i].y;
            }
        // add 4 lines to dList
        [self addLine:p[0] :p[1] toList:dList];
        [self addLine:p[1] :p[2] toList:dList];
        [self addLine:p[2] :p[3] toList:dList];
        [self addLine:p[3] :p[0] toList:dList];

        [self addFillPath:dList toList:mList];
    }
    if ( pll.x < llur[0].x ) llur[0].x = pll.x;
    if ( pll.y < llur[0].y ) llur[0].y = pll.y;
    if ( pur.x > llur[1].x ) llur[1].x = pur.x;
    if ( pur.y > llur[1].y ) llur[1].y = pur.y;
}

/*
 * modified:  17.06.93 12.06.95
 * purpose:   get line
 * parameter: g
 *		state
 *		parms
 */
- (void)setLine:cList
{   float		x, y;
    NSPoint		p0, p1;
    NSDictionary	*tool = [tools objectAtIndex:state.tool];

    x = state.x;
    y = state.y;

    /* rectangular form and horizontal or vertical direktion -> rectangular PAD
     */
    if ( !state.path && [[tool objectForKey:@"formCode"] isEqual:formR]
        && (Diff(x, state.point.x)<=TOLERANCE || Diff(y, state.point.y)<=TOLERANCE) && state.pa)
    {	NSSize	s = NSMakeSize([[tool objectForKey:@"width"] floatValue], [[tool objectForKey:@"height"] floatValue]);
        NSPoint	origin, p;
        NSSize	size;

        origin.x = Min(state.point.x, x) - (s.width/2.0);
        origin.y = Min(state.point.y, y) - (s.height/2.0);
        p.x = Max(state.point.x, x) + (s.width /2.0);
        p.y = Max(state.point.y, y) + (s.height/2.0);
        size.width = p.x - origin.x;
        size.height = p.y - origin.y;

        [self addRect:origin :size filled:YES toList:cList];

        [self updateBounds:origin];
        [self updateBounds:p];

        state.point.x = x;
        state.point.y = y;

        return;
    }

    if ( !state.path )
        state.width = [[tool objectForKey:@"width"] floatValue];
    p0 = state.point;

    if (state.pa)
    {	p1.x = x;
        p1.y = y;
    }
    else
    {	p1.x = state.point.x + x;
        p1.y = state.point.y + y;
    }

    if (SqrDistPoints(p0, p1) > TOLERANCE*TOLERANCE)
        [self addLine:p0 :p1 toList:cList];

    state.point = p1;

    [self updateBounds:p0];
    [self updateBounds:p1];
}

/*
 * modified:  17.06.93 01.09.94 05.05.96
 * purpose:   get pad
 * parameter: g
 * return:    cp
 */
- (void)setPad:cList
{   NSPoint		p;
    NSDictionary	*tool = [tools objectAtIndex:state.tool];

    /* circle */
    if ( ![tool objectForKey:@"formCode"] || [[tool objectForKey:@"formCode"] isEqual:formC] )
    {	float	r = [[tool objectForKey:@"width"] floatValue] / 2.0;

        state.point.x = state.x;
        state.point.y = state.y;
        [self addCircle:state.point :r filled:YES toList:cList];
        p.x = state.point.x - r;  p.y = state.point.y - r;
        [self updateBounds:p];
        p.x = state.point.x + r;  p.y = state.point.y + r;
        [self updateBounds:p];
    }
    /* rectangle */
    else if ( [[tool objectForKey:@"formCode"] isEqual:formR] )
    {	NSPoint	origin;
        NSSize	size;

        size.width = [[tool objectForKey:@"width"] floatValue];
        size.height = [[tool objectForKey:@"height"] floatValue];
        origin.x = state.x - size.width/2;
        origin.y = state.y - size.height/2;
        p.x = origin.x + size.width; p.y = origin.y + size.height;
        [self addRect:origin :size filled:YES toList:cList];
        state.point = origin;
        [self updateBounds:origin];
        [self updateBounds:p];
    }
    /* octagon */
    else if ( [[tool objectForKey:@"formCode"] isEqual:formO] )
    {	float	r;

        /* calculate the radius */
        r = ([[tool objectForKey:@"width"] floatValue]/2.0) / cos(DegToRad(22.5));

        state.point.x = state.x;
        state.point.y = state.y;
        [self addOctagon:state.point :r filled:YES toList:cList];
        p.x = state.point.x - r;  p.y = state.point.y - r;
        [self updateBounds:p];
        p.x = state.point.x + r;  p.y = state.point.y + r;
        [self updateBounds:p];
    }
    /* obround */
    else if ( [[tool objectForKey:@"formCode"] isEqual:formOR] )
    {	float	w, h;

        /* get the width and height */
        w = [[tool objectForKey:@"width"] floatValue];
        h = [[tool objectForKey:@"height"] floatValue];

        state.point.x = state.x;
        state.point.y = state.y;
        [self addObround:state.point :w :h filled:YES toList:cList];
        p.x = state.point.x - w/2.0;  p.y = state.point.y - h/2.0;
        [self updateBounds:p];
        p.x = state.point.x + w/2.0;  p.y = state.point.y + h/2.0;
        [self updateBounds:p];
    }
    /* polygon */
    else if ( [[tool objectForKey:@"formCode"] isEqual:formP] )
    {	float	w, w2;
        int	sides;

        /* get the width and height */
        w = [[tool objectForKey:@"width"] floatValue];
        w2 = w/2.0;
        sides = (float)[[tool objectForKey:@"height"] intValue]/INCH;

        state.point.x = state.x;
        state.point.y = state.y;
        [self addPolygon:state.point :w :sides filled:YES toList:cList];
        p.x = state.point.x - w2;  p.y = state.point.y - w2;
        [self updateBounds:p];
        p.x = state.point.x + w2;  p.y = state.point.y + w2;
        [self updateBounds:p];
    }
    /* macro */
    else if ( [[tool objectForKey:@"formCode"] isEqual:formM] )
    {	NSScanner	*scanner = [NSScanner scannerWithString:[tool objectForKey:@"macro"]];
        NSMutableArray	*myList = [[[self allocateList] init] autorelease];
        int		location = [scanner scanLocation];
        NSPoint		llur[2]; // ll ur of macro !

        llur[0].x = llur[0].y = LARGE_COORD;
        llur[1].x = llur[1].y = LARGENEG_COORD;

        while ( ![scanner isAtEnd] )
        {   int	val;

            [scanner setScanLocation:location];
            [scanner scanUpToString:ops.termi intoString:NULL];
            if ( [scanner scanString:ops.termi intoString:NULL] ) // start new graphic || or end
            {
                [scanner scanUpToCharactersFromSet:digitsSet intoString:NULL];
                if ( ![scanner scanInt:&val] && [scanner scanString:ops.RS274X intoString:NULL] )
                    break; // end
            }
            // so we didnt step over one graphic and can step over * inside next methods
            location = [scanner scanLocation];
            switch (val)
            {
                case 1:
                    [self getMacroCircle:scanner :myList :llur];
                    break;
                case 2:
                case 20:
                    [self getMacroRectLine:scanner :myList :llur];
                    break;
                case 21:
                    [self getMacroRectCenter:scanner :myList :llur];
                    break;
                case 22:
                    [self getMacroRect:scanner :myList :llur];
                    break;
                case 4:
                    [self getMacroOutline:scanner :myList :llur];
                    break;
                case 5:
                    [self getMacroPolygon:scanner :myList :llur];
                    break;
                case 6:
                    [self getMacroMoire:scanner :myList :llur];
                    break;
                case 7:
                    [self getMacroThermal:scanner :myList :llur];
                    break;
                default:
                    NSLog(@"GerberImport: -setPad Macro -> unexpected graphic in macro .%d", val);
            }

        }
        // removeHiddenArea // remove white graphics
        [self removeClearLayers:myList];

        // must correct the color here
        if ( state.LPC ) state.color = [NSColor colorWithCalibratedRed:1.0 green:1.0 blue:1.0 alpha:1.0];
        else            state.color = [NSColor colorWithCalibratedRed:0.0 green:0.0 blue:0.0 alpha:1.0];

        llur[0].x += state.x; llur[0].y += state.y;
        llur[1].x += state.x; llur[1].y += state.y;
        [self updateBounds:llur[0]];
        [self updateBounds:llur[1]];

        // move list to point
        [self moveListBy:NSMakePoint(state.x, state.y) :myList];

        // add macro to cList
        if ( [myList count] )
        {   [self addFillList:myList toList:cList]; // remove path inside path done here
            [myList removeAllObjects];
        }

	state.point.x = state.x;
	state.point.y = state.y;
    }
}

/*
 * created:   07.05.93
 * modified:  17.06.93 05.05.96 2009-07-10 (//state.g = 0)
 * purpose:   set arc ccw
 * parameter: g
 */
- (void)setArc:cList
{   NSPoint		center, start, end;
    float		ba, ea, angle;
    NSDictionary	*tool = [tools objectAtIndex:state.tool];

//    state.g = 0; // else we go on with an arc

    if ( !state.path )
        state.width = [[tool objectForKey:@"width"] floatValue];

    /* center */
    center.x = state.point.x + state.i;
    center.y = state.point.y + state.j;

    start = state.point;

    end.x = state.x;
    end.y = state.y;

    /* end angle */
    ba = calcAngleOfPointRelativeCenter(start, center);
    ea = calcAngleOfPointRelativeCenter(end, center);
    if ( ea <= ba+TOLERANCE ) ea += 360.0;

    if ( !state.ccw )
        angle = - (360.0 - (ea-ba));
    else
        angle = ea - ba;

    if ( Diff(Abs(angle), 0.0) <= TOLERANCE || Diff(Abs(angle), 360.0) <= TOLERANCE )
        angle = (angle > 0) ? 360.0 : -360.0;

    if ( state.ipolFull && Diff(angle, 360.0) <= TOLERANCE )
    {
        if ( state.path )
            [self addCircle:center :sqrt(SqrDistPoints(start, center)) filled:YES toList:cList];
        else
            [self addCircle:center :sqrt(SqrDistPoints(start, center)) filled:NO toList:cList];
    }
    else
    {
        if ( !state.ipolFull) // 90 degree interpolation - both angles must be inside one quarter !
        {
            if ( ea <= ba+TOLERANCE )
                return;
            if ( (ba >= 0 && ba < 90) && (ea < 0 || ea > 90) )
                return;
            if ( (ba >= 90 && ba < 180) && (ea < 90 || ea > 180) )
                return;
            if ( (ba >= 180 && ba < 270) && (ea < 180 || ea > 270) )
                return;
            if ( (ba >= 270 && ba < 360) && (ea < 270 || ea > 360) )
                return;
        }
        [self addArc:center :start :angle toList:cList];
    }
    state.point = end;	/* end point of arc */
    state.i = state.j = 0; // important if i or j not set -> value is 0

    [self updateBounds:center];
    [self updateBounds:start];
    [self updateBounds:end];
}

/*
 * created:   07.05.93
 * modified:  17.06.93 05.05.96
 * purpose:   set arc ccw
 * parameter: g
 */
- (void)setPath:(NSScanner*)scanner :cList
{   NSMutableArray	*myList;				/* current list */
    
    state.g = 0; /* last thing was a move with state.g== PATH */

    [scanner scanString:ops.termi intoString:NULL]; // little bit faster

    myList = [[[self allocateList] init] autorelease];
    while (1)
    {
        if ( ![self getGraphicFromData:scanner :myList] )
            break;
        if ( !state.path )
            break;
    }
    //add to cList
    if ( [myList count] )
    {   [self addFillList:myList toList:cList];
        [myList removeAllObjects];
    }
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

- (void)removeClearLayers:bList;
{
    NSLog(@"Layer polarity was one time clear.");
}

- (void)changeListPolarity:bList bounds:(NSRect)bounds
{
    NSLog(@"Image polarity is negative.");
}

- (void)addFillList:aList toList:bList
{
    NSLog(@"filled path.");
}

- (void)addFillPath:aList toList:bList
{
    NSLog(@"add filled path to list !");
}

- (void)addStrokeList:aList toList:bList
{
    NSLog(@"stroked path."); 
}

- (void)addLine:(NSPoint)beg :(NSPoint)end toList:aList
{
    NSLog(@"line: %f %f %f %f", beg.x, beg.y, end.x, end.y); 
}

- (void)addRect:(NSPoint)origin :(NSSize)size filled:(BOOL)fill toList:aList
{
    NSLog(@"rect: %f %f %f %f %d", origin.x, origin.y, size.width, size.height, fill); 
}

- (void)addCircle:(NSPoint)center :(float)radius filled:(BOOL)fill toList:aList
{
    NSLog(@"circle: %f %f %f %d", center.x, center.y, radius, fill); 
}

- (void)addOctagon:(NSPoint)center :(float)radius filled:(BOOL)fill toList:aList
{
    NSLog(@"octagon: %f %f %f %d", center.x, center.y, radius, fill); 
}

- (void)addObround:(NSPoint)center :(float)width :(float)height filled:(BOOL)fill toList:aList
{
    NSLog(@"obround: %f %f %f %f %d", center.x, center.y, width, height, fill); 
}

- (void)addPolygon:(NSPoint)center :(float)width :(int)sides filled:(BOOL)fill toList:aList
{
    NSLog(@"obround: %f %f %f %d %d", center.x, center.y, width, sides, fill); 
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
    NSLog(@"text: %f %f %f %f %f \"%s\" \"%s\"", p.x, p.y, angle, size, ar, text, font); 
}

- (void)moveListBy:(NSPoint)pt :aList
{
    NSLog(@"moveListBy: %f %f", pt.x, pt.y);
}

- (void)setBounds:(NSRect)bounds
{
    NSLog(@"bounds: %f %f %f %f", bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height);
}
@end
