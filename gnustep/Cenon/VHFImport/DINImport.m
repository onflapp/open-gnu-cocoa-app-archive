/* DINImport.m
 * DIN import object (Drill data import)
 *
 * Copyright (C) 1996-2012 by vhf interservice GmbH
 * Author:   Ilonka Fleischmann
 *
 * created:  1996-05-03
 * modified: 2012-06-18 (leading zero support added (LZ), clean-up)
 *           2006-11-04
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

#include "DINImport.h"
#include "../VHFShared/vhfCFGFunctions.h"
#include "../VHFShared/types.h"
#include "../VHFShared/VHFStringAdditions.h"
#include "../VHFShared/vhf2DFunctions.h"

/* r in points/inch */
#define	InternalToDeviceRes(a, r)	((float)(a) * (float)(r) / 72.0)
#define	DeviceResToInternal(a, r)	((float)(a) * 72.0 / (float)(r))

/* the following characters may apear as digits in a coordinate */
#define DIGITS @".+-0123456789"


@interface DINImport(PrivateMethods)
- importDIN:(NSData*)DINData;
- (BOOL)checkFileFormat:(NSString*)dinStr;
- (BOOL)loadApertures:(NSString*)toolStr;
- (void)loadSM1000Apertures:(NSScanner*)scanner;
- (void)loadSM3000Apertures:(NSScanner*)scanner;
- (void)loadExcellonApertures:(NSScanner*)scanner;
- (BOOL)interpret:(NSString*)dataP;
- (BOOL)getGraphicFromData:(NSScanner*)scanner :cList;
- (BOOL)getToolFromData:(NSScanner*)scanner :(NSString*)macroData :(NSString**)code :(float*)w :(float*)h :(NSString**)formCode :(NSString**)macroStr;
- (BOOL)getTool:(NSScanner*)scanner;
- (BOOL)getPlotAbs:(NSScanner*)scanner;
- (BOOL)getPlotRel:(NSScanner*)scanner;
- (void)setArc:cList;
- (void)setLine:cList;
- (void)setMark:cList;
- (void)updateBounds:(NSPoint)p;
@end

@implementation DINImport

- init
{
    self = [super init];

    [self setDefaultParameter];
    parameterLoaded = 0;
    fileFormat = 0;

    res = 1000.0;
    tz = YES;       // trailing zeros

    state.inch = 1; // inch
    state.pa   = 1;

    state.tool = 0;
    state.point.x = state.point.y = LARGENEG_COORD;
    state.g = 0;
    state.x = state.y = 0.0;
    state.a = state.c = 0.0;
    state.path = 0;
    state.offset = 0;
    return self;
}

- (void)setDefaultParameter
{
    switch (fileFormat)
    {
        case DIN_SM3000:
            ops.start = @"%%3000";
            res = 25400.0;
            ops.prgend = @"$";
            ops.coordC = @"D";  // diameter of tool
            break;
        case DIN_SM1000:
            ops.start = @"%%1000";
            res = 25400.0;
            ops.prgend = @"$";
            ops.coordC = @"";   // diameter of tool
            break;
        default:
            ops.start = @"%";
            res = 10000.0;
            ops.prgend = @"M30";
            ops.coordC = @"C";  // diameter of tool
    }
    resMM = 25400.0;
    tz    = YES;                // trailing zeros
    ops.offset      = @"M50";
    ops.mm          = @"M71";
    ops.reset       = @"";
    ops.selectTool  = @"T";
    ops.coordX      = @"X";
    ops.coordY      = @"Y";
    ops.coordR      = @"R";     // radius of circle
    ops.plotAbs     = @"G90";
    ops.plotRel     = @"G91";
    ops.termi       = @"\n";
    //ops.polyBegin = @"G41";   // left
    //ops.polyBegin2 = @"G42";  // right
    //ops.polyEnd = @"G40";
    ops.comment     = @"/";
    ops.line        = @"G1";    // G01
    ops.circleCW    = @"G2";    // G02
    ops.circleCCW   = @"G3";    // G03
    ops.drill       = @"G05";
}

- (BOOL)checkFileFormat:(NSString*)dinStr
{   NSScanner   *scanner = [NSScanner scannerWithString:dinStr];
    int         location;

    location = [scanner scanLocation];
    [scanner scanUpToString:@"%%1000" intoString:NULL];
    if ( [scanner scanString:@"%%1000" intoString:NULL] )
    {   fileFormat = DIN_SM1000;
        return YES;
    }
    [scanner setScanLocation:location];
    [scanner scanUpToString:@"%%3000" intoString:NULL];
    if ( [scanner scanString:@"%%3000" intoString:NULL] )
    {   fileFormat = DIN_SM3000;
        return YES;
    }
    fileFormat = DIN_EXCELLON;
    return YES;
/*
    [scanner setScanLocation:location];
    [scanner scanUpToString:@"G05" intoString:NULL]; // 2
    if ( [scanner scanString:@"G05" intoString:NULL] )
    {   fileFormat = DIN_EXCELLON;
        return YES;
    }
    [scanner setScanLocation:location];
    [scanner scanUpToString:@"G81" intoString:NULL]; // 1
    if ( [scanner scanString:@"G81" intoString:NULL] )
    {   fileFormat = DIN_EXCELLON;
        return YES;
    }
    [scanner setScanLocation:location];
    [scanner scanUpToString:@"M72" intoString:NULL];
    if ( [scanner scanString:@"M72" intoString:NULL] )
    {   fileFormat = DIN_EXCELLON;
        return YES;
    }
    [scanner setScanLocation:location];
    [scanner scanUpToString:@"M71" intoString:NULL];
    if ( [scanner scanString:@"M71" intoString:NULL] )
    {   fileFormat = DIN_EXCELLON;
        return YES;
    }
    [scanner setScanLocation:location];
    [scanner scanUpToString:@"INCH" intoString:NULL];
    if ( [scanner scanString:@"INCH" intoString:NULL] )
    {   fileFormat = DIN_EXCELLON;
        return YES;
    }

    [scanner setScanLocation:location];
    [scanner scanUpToString:@"METRIC" intoString:NULL];
    if ( [scanner scanString:@"METRIC" intoString:NULL] )
    {   fileFormat = DIN_EXCELLON;
        return YES;
    }
    return NO;
*/
}

/* created:   03.05.96
 * modified:  07.03.97
 * parameter: fileName
 * purpose:   load parameter file
 */
- (BOOL)loadParameter:(NSString*)fileName
{   NSMutableString	*parmData;
    NSString		*val;

    [self setDefaultParameter];

    if ( !(parmData = [NSMutableString stringWithContentsOfFile:fileName]) )
        return NO;

    parameterLoaded = 1;

    if ( 1 )// fileFormat == DIN_EXCELLON 
    {   vhfGetTypesFromData(parmData, @"f", @"#RMM", &resMM);
        ops.comment = vhfGetStringFromData(parmData, @"#REM");
        ops.mm = vhfGetStringFromData(parmData, @"#UMM");
    }
    vhfGetTypesFromData(parmData, @"f", @"#RES", &res);

    ops.init = vhfGetStringFromData(parmData, @"#INI");
    ops.reset = vhfGetStringFromData(parmData, @"#RST");
    ops.selectTool = vhfGetStringFromData(parmData, @"#ITL");
    if ( (val = vhfGetStringFromData(parmData, @"#IST")) )
        ops.start = val;
    ops.coordX = vhfGetStringFromData(parmData, @"#IXP");
    ops.coordY = vhfGetStringFromData(parmData, @"#IYP");
    ops.coordC = vhfGetStringFromData(parmData, @"#IDM");
    //ops.coordI = vhfGetStringFromData(parmData, @"#IIP");
    //ops.coordJ = vhfGetStringFromData(parmData, @"#IJP");
    //ops.circle = vhfGetStringFromData(parmData, @"#ICI");
    //ops.arc = vhfGetStringFromData(parmData, @"#IAR");
    ops.termi = vhfGetStringFromData(parmData, @"#ITM");

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
- (BOOL)loadApertures:(NSString*)toolStr
{   NSScanner		*scanner = [NSScanner scannerWithString:toolStr];

    if ( !scanner )
        return NO;

    // NSScanner else jump over \n (default)
    [scanner setCharactersToBeSkipped:[NSCharacterSet whitespaceCharacterSet]];

    [tools release];
    tools = [[NSMutableArray array] retain];

    switch (fileFormat)
    {
        case DIN_SM1000:	[self loadSM1000Apertures:scanner]; break;
        case DIN_SM3000:	[self loadSM3000Apertures:scanner]; break;
        case DIN_EXCELLON:	[self loadExcellonApertures:scanner]; break;
        default: NSLog(@"DINImport: loadApertures no valid fileFormat.");
    }
    return YES;
}

- (void)loadSM1000Apertures:(NSScanner*)scanner
{   NSString    *parameter = @"$";
    int         i, value, cnt = 1;

    // $80$50$20$99$15$500 6 times $ at end

    while (![scanner isAtEnd])
    {
        for (i=1; i<7; i++) // six times
        {
            [scanner scanUpToString:parameter intoString:NULL];
            if ( [scanner scanString:parameter intoString:NULL] && i == 1 ) // first of six values is diameter
            {   NSMutableDictionary	*dict = [NSMutableDictionary dictionary];
                float	dia;

                if ( ![scanner scanInt:&value] )
                    return; // last $
                dia = DeviceResToInternal(value, res); // in same mannor like coordinates
                if ( !dia )
                    return; // last - format says 15 tools must be defined - we assume 0 is last
                [dict setObject:[NSString stringWithFormat:@"T%d", cnt] forKey:@"code"];
                [dict setObject:[NSNumber numberWithFloat:dia] forKey:@"diameter"];
                [tools addObject:dict];
                cnt++;
            }
        }
    }
}

- (void)loadSM3000Apertures:(NSScanner*)scanner
{   NSString    *parameter = @"$", *parmDia = @"D", *codeStr;
    int         i, value, location = [scanner scanLocation];
    float       dia;

    // $
    // T1D80S50F20R99N15A500T2D50...

    [scanner scanUpToString:parameter intoString:NULL];
    if ( ![scanner scanString:parameter intoString:NULL] )
        return; // no tools

    while (![scanner isAtEnd])
    {
        [scanner scanUpToString:ops.selectTool intoString:NULL];
        if ( [scanner scanString:ops.selectTool intoString:NULL] )
        {   NSMutableDictionary	*dict = [NSMutableDictionary dictionary];

            if ( ![scanner scanInt:&value] )
                return;
            codeStr = [NSString stringWithFormat:@"T%d", value];
            if ( [scanner scanString:parmDia intoString:NULL] )
            {   if ( ![scanner scanInt:&value] )
                    return;
            }
            dia = DeviceResToInternal(value, res); // in same mannor like coordinates
            if ( !dia )
                return; // we assume 0 is last
            [dict setObject:codeStr forKey:@"code"];
            [dict setObject:[NSNumber numberWithFloat:dia] forKey:@"diameter"];
            [tools addObject:dict];
        }
        else
            break; // no more tools
    }
    // if X|Y values are realy floatValues -> 01.123 -> -> res = 1.0 !!!!!!!!!!!!!
    [scanner setScanLocation:location];
    for (i=0; i<3 && ![scanner isAtEnd]; i++)
    {   [scanner scanUpToString:ops.coordX intoString:NULL];
        if ( [scanner scanString:ops.coordX intoString:NULL] )
        {   NSString	*str;
            NSCharacterSet	*stopSet = [NSCharacterSet characterSetWithCharactersInString:@"\nY"];

            if ( [scanner scanUpToCharactersFromSet:stopSet intoString:&str] )
            {   NSRange	range = [str rangeOfString:@"."];
                state.inch = 0;
                if ( range.length && state.inch )
                    res = 1.0;
                else if ( range.length && !state.inch )
                    res = 25.4;
                return;
            }
        }
    }
}

- (void)loadExcellonApertures:(NSScanner*)scanner
{   NSString        *parmDia = @"C", *codeStr;
    int             value, location = [scanner scanLocation], inchLoc=0, mmLoc=0;
    float           dia;
    NSCharacterSet  *stopSet = [NSCharacterSet characterSetWithCharactersInString:@"TC"];

    // get state.inch, state.pa and correct perhaps res

    [scanner scanUpToString:@"LZ" intoString:NULL];     // leading zeros
    if ( [scanner scanString:@"LZ" intoString:NULL] )
        tz = NO;    // leading zeros
    // TODO: there is also "TZ" = trailing zeros, and "FMAT,2"

    [scanner setScanLocation:location];
    [scanner scanUpToString:@"G91" intoString:NULL];    // relative
    if ( [scanner scanString:@"G91" intoString:NULL] )
        state.pa = 0;

    [scanner setScanLocation:location];
    [scanner scanUpToString:@"INCH" intoString:NULL];   // inch
    if ( [scanner scanString:@"INCH" intoString:NULL] )
        inchLoc = [scanner scanLocation];
    [scanner setScanLocation:location];
    [scanner scanUpToString:@"M72" intoString:NULL];    // inch
    if ( [scanner scanString:@"M72" intoString:NULL] )
    {   if ( !inchLoc || inchLoc > (int)[scanner scanLocation] )
            inchLoc = [scanner scanLocation];
    }
    [scanner setScanLocation:location];
    [scanner scanUpToString:@"M71" intoString:NULL];    // mm
    if ( [scanner scanString:@"M71" intoString:NULL] )
        mmLoc = [scanner scanLocation];
    [scanner setScanLocation:location];
    [scanner scanUpToString:@"METRIC" intoString:NULL]; // mm
    if ( [scanner scanString:@"METRIC" intoString:NULL] )
    {   if ( !mmLoc || mmLoc > (int)[scanner scanLocation] )
            mmLoc = [scanner scanLocation];
    }
    [scanner setScanLocation:location];
    [scanner scanUpToString:ops.mm intoString:NULL];    // mm (from device file)
    if ( [scanner scanString:ops.mm intoString:NULL] )
    {   if ( !mmLoc || mmLoc > (int)[scanner scanLocation] )
            mmLoc = [scanner scanLocation];
    }
    state.inch = ( (mmLoc && inchLoc && mmLoc < inchLoc) || (mmLoc && !inchLoc) ) ? 0 : 1; // mm is first

    // T1 C.04 F200 S65
    // T2 C.05 F200 S65
    // % // prg start

    // T1 C.04
    // X123Y234...

    // T1 no C follows is possible -> than C values must be befor % (start of prg)
    // else no tools are declared
    [scanner setScanLocation:location];
    while (![scanner isAtEnd])
    {
        [scanner scanUpToCharactersFromSet:stopSet intoString:NULL];

        if ( [scanner scanString:ops.selectTool intoString:NULL] ) // T
        {   NSMutableDictionary	*dict = [NSMutableDictionary dictionary];

            if (![scanner scanInt:&value])
                continue;
            codeStr = [NSString stringWithFormat:@"T%d", value];

            [scanner scanUpToCharactersFromSet:stopSet intoString:NULL];
            if (![scanner scanString:parmDia intoString:NULL]) // C
                continue; // METRIC or something ? break; // no C follows -> end of tool init
            if (![scanner scanFloat:&dia])
                continue;
            if (!state.inch)
                dia /= 25.4; // mm/ 25.4 -> inch
            dia *= INCH; // diameter is spezified with dot
            if ( !dia )
            {   state.inch = ( mmLoc > inchLoc ) ? 0 : 1;
                break; // we assume 0 is last
            }
            [dict setObject:codeStr forKey:@"code"];
            [dict setObject:[NSNumber numberWithFloat:dia] forKey:@"diameter"];
            [tools addObject:dict];
        }
        else if (![scanner isAtEnd])
            [scanner setScanLocation:[scanner scanLocation]+1]; // break; // no more tools
        else break;
    }
    state.inch = ( mmLoc > inchLoc ) ? 0 : 1;

    if ( !state.inch )
        res = resMM;

    // if X|Y values are realy floatValues -> 01.123 -> -> res = 1.0 !!!!!!!!!!!!!
    [scanner setScanLocation:location];
    [scanner scanUpToString:ops.coordX intoString:NULL];
    if ( [scanner scanString:ops.coordX intoString:NULL] )
    {   NSString	*str;
        NSCharacterSet	*stopSet = [NSCharacterSet characterSetWithCharactersInString:@"\nY"];

        if ( [scanner scanUpToCharactersFromSet:stopSet intoString:&str] )
        {   NSRange	range = [str rangeOfString:@"."];

            if ( range.length && state.inch )
                res = 1.0;
            else if ( range.length && !state.inch )
                res = 25.4;
        }
    }
}

/* created:   2001-01-27
 * modified:  2002-10-26
 * parameter: DINData	the DIN data stream
 * purpose:   start interpretation of the contents of DINData
 */
- importDIN:(NSData*)DINData
{   NSString	*dinStr = [[[NSString alloc] initWithData:DINData
                                                 encoding:NSASCIIStringEncoding] autorelease];

    state.color = [NSColor colorWithCalibratedRed:0.0 green:0.0 blue:0.0 alpha:1.0];
    state.width = 0.0;

    [self checkFileFormat:dinStr];

    if ( !parameterLoaded )
        [self setDefaultParameter];

    [self loadApertures:dinStr];

    if ( ![tools count] )
        NSLog(@"No tools loaded !");

    /* interpret data
     */
    if ( ![self interpret:dinStr] )
        return 0;

    return [list autorelease];
}

/* private methods
 */
- (BOOL)interpret:(NSString*)dataP
{   int         startLocation;
    NSRect      bounds;
    NSScanner   *scanner = [NSScanner scannerWithString:dataP];

    digitsSet = [NSCharacterSet characterSetWithCharactersInString:DIGITS];
    invDigitsSet = [digitsSet invertedSet];
    // NSScanner else jump over \n (default)
    [scanner setCharactersToBeSkipped:[NSCharacterSet whitespaceCharacterSet]];

    startLocation = [scanner scanLocation];
    /* init bounds */
    ll.x = ll.y = LARGE_COORD;
    ur.x = ur.y = LARGENEG_COORD;

    list = [self allocateList];

    // set scanner to start of programm (%%1000 or %%3000)
    // if ( fileFormat != DIN_EXCELLON )
    {
        [scanner scanUpToString:ops.start intoString:NULL];
        if ( ![scanner scanString:ops.start intoString:NULL] )
        {
            if ( fileFormat == DIN_EXCELLON )
                [scanner setScanLocation:startLocation];
            else
            {   NSLog(@"DINImport: No start sign (%@) found", ops.start);
                return NO;
            }
        }
    }

    while ( ![scanner isAtEnd] )
        if ( ![self getGraphicFromData:scanner :list] )
            break;

    bounds.origin      = ll;
    bounds.size.width  = ur.x - ll.x;
    bounds.size.height = ur.y - ll.y;

    [self setBounds:bounds];
    return YES;
}

/* we need cp on a number !
 */
- (BOOL)getGraphicFromData:(NSScanner*)scanner :cList
{   int         location;
    float       value;
    NSString    *str = nil;

    location = [scanner scanLocation];

    if ( [scanner scanString:ops.termi intoString:NULL] ) // else we jump over \n
    {
        if ( state.draw )
        {
            switch (state.g)
            {
                case DIN_LINE:
                    [self setLine:cList];
                    break;
                case DIN_ARC:
                    [self setArc:cList];
                    break;
                /*case DIN_PATH:
                    [self setPath:scanner :cList];
                    break;*/
                default:
                    [self setMark:cList];
            }
            if (!state.offset)
            {   state.point.x = state.x;
                state.point.y = state.y;
            }
            else state.offset = 0;
            state.draw = 0;
        }
    }
    else if ( [scanner scanString:ops.comment intoString:NULL] )
    {   [scanner scanUpToString:ops.termi intoString:NULL];
        [scanner scanString:ops.termi intoString:NULL];
    }
    else if ( [scanner scanString:ops.offset intoString:NULL] ) // relativ M50
        state.offset = 1;
    //else if ( [scanner scanString:ops.drill intoString:NULL] )
    //    state.g = 0;
    else if ( [scanner scanString:ops.line intoString:NULL] )
        state.g = DIN_LINE;
    else if ( [scanner scanString:ops.circleCW intoString:NULL] )
    {   state.g = DIN_ARC;
        state.ccw = 0;
    }
    else if ( [scanner scanString:ops.circleCCW intoString:NULL] )
    {   state.g = DIN_ARC;
        state.ccw = 1;
    }
    /*else if ( [scanner scanString:ops.polyBegin intoString:NULL] || [scanner scanString:ops.polyBegin2 intoString:NULL] )
    {   state.g = DIN_PATH;
        state.path = 1;
    }
    else if ( [scanner scanString:ops.polyEnd intoString:NULL] )	
    {   state.g = 0;
        state.path = 0;
    }*/
    else if ( [scanner scanString:ops.coordX intoString:NULL] )
    {
        if ( [scanner scanCharactersFromSet:digitsSet intoString:&str] )
        //if ( [scanner scanFloat:&value] )
        {   //state.point.x = state.x;
            value = [str floatValue];
            if ( ! tz ) // leading zeros
                value *= pow(10, 7 - [str length]);
            state.x = DeviceResToInternal(value, res);
            state.draw = 1;
        }
        else
        {   state.x = 0;
//            NSLog(@"Coordinate X expected at location: %d", [scanner scanLocation]);
        }
    }
    else if ( [scanner scanString:ops.coordY intoString:NULL] )
    {
        if ( [scanner scanCharactersFromSet:digitsSet intoString:&str] )
        //if ( [scanner scanFloat:&value] )
        {   //state.point.y = state.y;
            value = [str floatValue];
            if ( ! tz ) // leading zeros
                value *= pow(10, 7 - [str length]);
            state.y = DeviceResToInternal(value, res);
            state.draw = 1;
        }
        else
        {   state.y = 0;
//            NSLog(@"Coordinate Y expected at location: %d", [scanner scanLocation]);
        }
    }
    else if ( [scanner scanString:ops.coordR intoString:NULL] )
    {
        if ( [scanner scanCharactersFromSet:digitsSet intoString:&str] )
        //if ( [scanner scanFloat:&value] )
        {   value = [str floatValue];
            if ( ! tz ) // leading zeros
                value *= pow(10, 7 - [str length]);
            state.a = DeviceResToInternal(value, res);
            state.draw = 1;
        }
        else
            NSLog(@"Coordinate R expected at location: %d", [scanner scanLocation]);
    }
    else if ( [scanner scanString:ops.selectTool intoString:NULL] )
//        [self getTool:scanner];
    {   if (![self getTool:scanner])
        {   // move
            state.point.x = state.x;
            state.point.y = state.y;
//            state.draw = 0;
        }

    }
    else if ( [scanner scanString:ops.plotAbs intoString:NULL] )
        [self getPlotAbs:scanner];
    else if ( [scanner scanString:ops.plotRel intoString:NULL] )
        [self getPlotRel:scanner];
    else if ( [scanner scanString:ops.prgend intoString:NULL] )
        return NO;
    else
    {   // we cant step until termi cause we run over next statement if blank or \n follows !
        if ( [scanner isAtEnd] )
            return NO;
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

    if (![scanner scanInt:&d])
        return -2; // move - we need current tool
    for (i=0; i<cnt; i++)
    {	NSString	*code = [[tools objectAtIndex:i] objectForKey:@"code"];
        int		d1 = [[code substringFromIndex:[code rangeOfCharacterFromSet:digitsSet].location] intValue];

        if ( d==d1 )
            return i;
    }
    return -1;
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
{   int	val;

    if ( (val = [self toolFromString:scanner]) < -1 )
         return NO;
    else if ( val < 0 )
    {
        NSLog(@"Gerber import, Can't find tool at location %d. Default used.", [scanner scanLocation]);
        state.tool = state.tool + 1; //  = 0;
        return NO;
    }
    state.tool = val;
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

/*
 * created:   07.05.93
 * modified:  17.06.93 05.05.96
 * purpose:   set arc ccw
 * parameter: g
 */
- (void)setArc:cList
{   NSPoint		center, start, end;
    float		angle; // ba, ea
    NSDictionary	*tool = [tools objectAtIndex:state.tool];

    if ( !state.path )
        state.width = (tool) ? [[tool objectForKey:@"diameter"] floatValue] : 0.0;

/*    if (state.i || state.j)
    {
        // center
        center.x = state.point.x + state.i;
        center.y = state.point.y + state.j;

        start = state.point;

        end.x = state.x;
        end.y = state.y;

        // end angle 
        ba = calcAngleOfPointRelativeCenter(start, center);
        ea = calcAngleOfPointRelativeCenter(end, center);
        if ( ea <= ba+TOLERANCE ) ea += 360.0;

        if ( !state.ccw )
            angle = - (360.0 - (ea-ba));
        else
            angle = ea - ba;

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
        state.point = end;	// end point of arc
        state.i = state.j = 0; // important if i or j not set -> value is 0
    }
    else
*/
    {   float	b, radius = state.a;
        NSPoint	grad;

        start = state.point;
        end.x = state.x;
        end.y = state.y;
        grad.x = end.x - start.x;
        grad.y = end.y - start.y;
        if (SqrDistPoints(start, end) > (radius*radius)*2.0)
        {
            angle = 180.0;
            if ( !(b = sqrt(grad.x*grad.x+grad.y*grad.y)) )
            {   LineMiddlePoint(start, end, center); }
            else
            {   center.x = start.x + grad.y*radius*1.0/b;
                center.y = start.y + grad.x*radius*1.0/b;
            }
            [self addArc:center :start :angle toList:cList];
        }
        else if (state.a > 0) // angle smaller or equal 180 degree
        {   NSPoint	mp;
            float	hight;

            if ( !(b = sqrt(grad.x*grad.x+grad.y*grad.y)) )
                return;
            LineMiddlePoint(start, end, mp);
            hight = sqrt(radius*radius - SqrDistPoints(mp, start)); // pythagoras

            // (!state.ccw) -> orthogonal to the right !
            center.x = (!state.ccw) ? (mp.x + grad.y*hight*1.0/b) : (mp.x + grad.y*hight*-1.0/b);
            center.y = (!state.ccw) ? (mp.y - grad.x*hight*1.0/b) : (mp.y - grad.x*hight*-1.0/b);

            angle = vhfAngleBetweenPoints(start, center, end);	/* ccw */
            if (!state.ccw)
                angle = -(360.0 - angle);
            [self addArc:center :start :angle toList:cList];
        }
        else // angle greater 180 degree
        {   NSPoint	mp;
            float	hight;

            radius = -radius;
            if ( !(b = sqrt(grad.x*grad.x+grad.y*grad.y)) )
                return;
            LineMiddlePoint(start, end, mp);
            hight = sqrt(radius*radius - SqrDistPoints(mp, start)); // pythagoras

            // (!state.ccw) -> orthogonal to the left !
            center.x = (!state.ccw) ? (mp.x + grad.y*hight*-1.0/b) : (mp.x + grad.y*hight*1.0/b);
            center.y = (!state.ccw) ? (mp.y - grad.x*hight*-1.0/b) : (mp.y - grad.x*hight*1.0/b);

            angle = vhfAngleBetweenPoints(start, center, end);	/* ccw */
            if (!state.ccw)
                angle = -(360.0 - angle);
            [self addArc:center :start :angle toList:cList];
        }
    }
    [self updateBounds:center];
    [self updateBounds:start];
    [self updateBounds:end];
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
    NSDictionary	*tool; // = [tools objectAtIndex:state.tool];

    tool = ([tools count]) ? [tools objectAtIndex:state.tool] : nil;

    x = state.x;
    y = state.y;

    if ( !state.path )
        state.width = (tool) ? [[tool objectForKey:@"diameter"] floatValue] : 0.0;
    p0 = state.point;

    if (state.pa)
    {	p1.x = x;
        p1.y = y;
    }
    else
    {	p1.x = state.point.x + x;
        p1.y = state.point.y + y;
    }

    [self addLine:p0 :p1 toList:cList];

    state.point = p1;

    [self updateBounds:p0];
    [self updateBounds:p1];
}

- (void)setMark:cList
{   NSPoint         center, pll, pur;
    NSDictionary    *tool; // = [tools objectAtIndex:state.tool];

    tool = ([tools count]) ? [tools objectAtIndex:state.tool] : nil;

    state.g = 0; // else we go on with an arc

    // state.width = [[tool objectForKey:@"diameter"] floatValue];
    state.width = (tool) ? [[tool objectForKey:@"diameter"] floatValue] : state.tool;

    /* center */
    if (state.offset)
    {   center.x = state.point.x + state.x; // !state.x && !state.y -> return
        center.y = state.point.y + state.y;
    }
    else

    {   center.x = state.x;
        center.y = state.y;
    }
    [self addMark:center withDiameter:state.width toList:cList];

    pll.x = center.x - state.a; pll.y = center.y - state.a;
    pur.x = center.x + state.a; pur.y = center.y + state.a;
    [self updateBounds:pll];
    [self updateBounds:pur];
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

- (void)addMark:(NSPoint)pt withDiameter:(float)dia toList:aList;
{
    NSLog(@"addMark: %f %f %f", pt.x, pt.y, dia);
}

- (void)addLine:(NSPoint)beg :(NSPoint)end toList:aList
{
    NSLog(@"line: %f %f %f %f", beg.x, beg.y, end.x, end.y); 
}

- (void)addCircle:(NSPoint)center :(float)radius filled:(BOOL)fill toList:aList
{
    NSLog(@"circle: %f %f %f %d", center.x, center.y, radius, fill); 
}

- (void)addArc:(NSPoint)center :(NSPoint)start :(float)angle toList:aList
{
    NSLog(@"arc: %f %f %f %f %f", center.x, center.y, start.x, start.y, angle); 
}

- (void)addFillList:aList toList:bList
{
    NSLog(@"filled path.");
}

- (void)setBounds:(NSRect)bounds
{
    NSLog(@"bounds: %f %f %f %f", bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height);
}
@end
