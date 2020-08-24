/* DXFExport.m
 * DXF export object
 *
 * Copyright (C) 2002-2012 by vhf interservice GmbH
 * Author:   Ilonka Fleischmann
 *
 * created:  2002-04-25
 * modified: 2012-02-07 (-saveToFile: use writeToFile:...encoding:error:)
 *
 * This file is part of the vhf Export Library.
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

#include "DXFExport.h"
#include "../VHFImport/dxfColorTable.h"
#include "../VHFShared/types.h"
#include "../VHFShared/VHFStringAdditions.h" // stringByReplacing:

#define RES 25.389

@interface DXFExport(PrivateMethods)
- (void)fillHeaderStr;
- (void)fillTableStr;
@end

@implementation DXFExport

/* initialize
 */
- init
{
    [super init];

    toolDict = [NSMutableDictionary dictionary];
    state.toolCnt = 9; // we start with D10

    state.curTool = 0;
    state.noPoint = 1;
    state.fill = 0;
    //state.setBounds = 1;
    state.ll.x = state.ll.y = MAXCOORD;
    state.ur.x = state.ur.y = 0.0;
    state.maxW = 0;
    state.curColor = 5;
    state.curLayer = @"0";
    state.ltypeCnt = 1;
    state.curLtype = @"CONTINUOUS";
    state.layerCnt = 0;
    state.layerNames = [NSMutableArray array];
    /* layer attribute: default 64; 1 not editable; 5 not editable and not visible (4+1) */
    state.layerAttrib[0] = 64;
    state.layerColor[0] = 5;
    state.res = 25.389;
    headerStr = @"";
    tableStr = @"";
    blockStr = @"";
    grStr = [NSMutableString string]; // entities

    return self;
}

#define COLTOL	TOLERANCE*25.0
int convertNSColorToDXFColor(NSColor *color)
{   int		i, dxfColIndex = 5;
    DXFColor	dxfCol;
    float	r, g, b, rd, gd, bd, maxdiff = 1.0;
    NSColor	*col = [color colorUsingColorSpaceName:@"NSCalibratedRGBColorSpace"];

    r = [col redComponent];
    g = [col greenComponent];
    b = [col blueComponent];
    for (i=0; i<254; i++)
    {
        dxfCol = colorTable[i];
        rd = Diff(r, dxfCol.r);
        gd = Diff(g, dxfCol.g);
        bd = Diff(b, dxfCol.b);
        if (rd <= maxdiff && gd <= maxdiff && bd <= maxdiff)
        {
            maxdiff = Max(rd, Max(gd, bd));
            dxfColIndex = i+1;
            if (maxdiff < COLTOL)
                return dxfColIndex;
        }
    }
    return dxfColIndex;
}

- (void)setRes:(float)res
{
    state.res = res;
}

- (void)addLayer:(NSString*)name :(NSColor*)color :(int)attribut
{   NSString		*nam = [name uppercaseString];
    NSCharacterSet	*set = [NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ-_$"], *invSet;
    NSRange         range;

    invSet = [set invertedSet];

    /* A-Z 0-9 - _ $ max 31 */
    nam = [NSString stringWithUTF8String:[nam lossyCString]];	// remove all umlauts
    range = [nam rangeOfCharacterFromSet:invSet];
    while (range.length)
    {   NSMutableString	*mutString = [NSMutableString string];

        [mutString appendString:[nam substringToIndex:range.location]]; // all chars until location
        [mutString appendString:@"_"]; // "replace" fault char with _
        [mutString appendString:[nam substringFromIndex:range.location+1]]; // add char behind fault char

        nam = [NSString stringWithString:mutString];
        range = [nam rangeOfCharacterFromSet:invSet];
    }
    if ([nam length] > 31)
        nam = [nam substringToIndex:31];
    [state.layerNames addObject:nam];
    state.curLayer = nam;
    state.layerColor[state.layerCnt] = state.curColor = convertNSColorToDXFColor(color);
    /* layer attribute: default 64; 1 not editable; 5 not editable and not visible (4+1) */
    state.layerAttrib[state.layerCnt] = attribut;
    state.layerCnt++;
}


- (void)setCurColor:(NSColor*)color
{
    state.curColor = convertNSColorToDXFColor(color);
}

- (void)writeLine:(NSPoint)s :(NSPoint)e :(float)width // width = 0
{
    [grStr appendFormat:@"0\n"];
    [grStr appendFormat:@"LINE\n"];
    [grStr appendFormat:@"8\n"];
    [grStr appendFormat:@"%@\n", state.curLayer]; // current layer
    [grStr appendFormat:@"6\n"];
    [grStr appendFormat:@"%@\n", state.curLtype]; // current ltype
    [grStr appendFormat:@"62\n"];
    [grStr appendFormat:@"%d\n", state.curColor]; // current color
    [grStr appendFormat:@"39\n"];
    [grStr appendFormat:@"%.4f\n", width*state.res/INCH];
    [grStr appendFormat:@"10\n"];
    [grStr appendFormat:@"%.4f\n", s.x*state.res/INCH];
    [grStr appendFormat:@"20\n"];
    [grStr appendFormat:@"%.4f\n", s.y*state.res/INCH];
    [grStr appendFormat:@"11\n"];
    [grStr appendFormat:@"%.4f\n", e.x*state.res/INCH];
    [grStr appendFormat:@"21\n"];
    [grStr appendFormat:@"%.4f\n", e.y*state.res/INCH];

    if ( state.ll.x > s.x ) state.ll.x = s.x;
    if ( state.ll.y > s.y ) state.ll.y = s.y;
    if ( state.ur.x < s.x ) state.ur.x = s.x;
    if ( state.ur.y < s.y ) state.ur.y = s.y;
    if ( state.ll.x > e.x ) state.ll.x = e.x;
    if ( state.ll.y > e.y ) state.ll.y = e.y;
    if ( state.ur.x < e.x ) state.ur.x = e.x;
    if ( state.ur.y < e.y ) state.ur.y = e.y;

    state.point = e;
    state.noPoint = 0;
}

- (void)writePolyLineVertex:(NSPoint)p // :(float)width
{
    [grStr appendFormat:@"0\n"];
    [grStr appendFormat:@"VERTEX\n"];
    [grStr appendFormat:@"8\n"];
    [grStr appendFormat:@"%@\n", state.curLayer]; // current layer
    [grStr appendFormat:@"6\n"];
    [grStr appendFormat:@"%@\n", state.curLtype]; // current ltype
    [grStr appendFormat:@"62\n"];
    [grStr appendFormat:@"%d\n", state.curColor]; // current color
//    [grStr appendFormat:@"70\n"];
//    [grStr appendFormat:@"32\n"]; // punkt einer 3D-Kurve (VPolyLine)
    [grStr appendFormat:@"10\n"];
    [grStr appendFormat:@"%.4f\n", p.x*state.res/INCH];
    [grStr appendFormat:@"20\n"];
    [grStr appendFormat:@"%.4f\n", p.y*state.res/INCH];
    /*[grStr appendFormat:@"40\n"];
    [grStr appendFormat:@"%.4f\n", width*state.res/INCH];
    [grStr appendFormat:@"41\n"];
    [grStr appendFormat:@"%.4f\n", width*state.res/INCH];*/
    if ( state.ll.x > p.x ) state.ll.x = p.x;
    if ( state.ll.y > p.y ) state.ll.y = p.y;
    if ( state.ur.x < p.x ) state.ur.x = p.x;
    if ( state.ur.y < p.y ) state.ur.y = p.y;

    state.point = p;
    state.noPoint = 0;
}

- (void)writePolyLineMode:(BOOL)mode :(float)width :(int)closed
{
    if (mode) // start polygon (POLYLINE with lines and arcsegments)
    {	[grStr appendFormat:@"0\n"];
        [grStr appendFormat:@"POLYLINE\n"];
        [grStr appendFormat:@"8\n"];
        [grStr appendFormat:@"%@\n", state.curLayer]; // current layer
        [grStr appendFormat:@"6\n"];
        [grStr appendFormat:@"%@\n", state.curLtype]; // current ltype
        [grStr appendFormat:@"62\n"];
        [grStr appendFormat:@"%d\n", state.curColor]; // current color
        [grStr appendFormat:@"66\n"];
        [grStr appendFormat:@"1\n"]; // vertex flag
        [grStr appendFormat:@"10\n"];
        [grStr appendFormat:@"0.0000\n"];
        [grStr appendFormat:@"20\n"];
        [grStr appendFormat:@"0.0000\n"];

        [grStr appendFormat:@"70\n"]; // bedeutung // 8 open 9 closed - only lines
        [grStr appendFormat:@"%d\n", closed]; // 0 - arcs and lines 1 - closed

        [grStr appendFormat:@"40\n"];
        [grStr appendFormat:@"%.4f\n", width*state.res/INCH];
        [grStr appendFormat:@"41\n"];
        [grStr appendFormat:@"%.4f\n", width*state.res/INCH];
    }
    else // end polygon
    {   [grStr appendFormat:@"0\n"];
        [grStr appendFormat:@"SEQEND\n"];
        [grStr appendFormat:@"8\n"];
        [grStr appendFormat:@"%@\n", state.curLayer]; // current layer
        [grStr appendFormat:@"6\n"];
        [grStr appendFormat:@"%@\n", state.curLtype]; // current ltype
        [grStr appendFormat:@"62\n"];
        [grStr appendFormat:@"%d\n", state.curColor]; // current color
    }
}

- (void)writeLineVertex:(NSPoint)s // :(float)width
{
    [grStr appendFormat:@"0\n"];
    [grStr appendFormat:@"VERTEX\n"];
    [grStr appendFormat:@"8\n"];
    [grStr appendFormat:@"%@\n", state.curLayer]; // current layer
    [grStr appendFormat:@"6\n"];
    [grStr appendFormat:@"%@\n", state.curLtype]; // current ltype
    [grStr appendFormat:@"62\n"];
    [grStr appendFormat:@"%d\n", state.curColor]; // current color
//    [grStr appendFormat:@"70\n"];
//    [grStr appendFormat:@"0\n"]; // punkt einer 2D-Kurve (line - 1 arc)
    [grStr appendFormat:@"10\n"];
    [grStr appendFormat:@"%.4f\n", s.x*state.res/INCH];
    [grStr appendFormat:@"20\n"];
    [grStr appendFormat:@"%.4f\n", s.y*state.res/INCH];
/*    [grStr appendFormat:@"40\n"];
    [grStr appendFormat:@"%.4f\n", width*state.res/INCH];
    [grStr appendFormat:@"41\n"];
    [grStr appendFormat:@"%.4f\n", width*state.res/INCH];*/
    if ( state.ll.x > s.x ) state.ll.x = s.x;
    if ( state.ll.y > s.y ) state.ll.y = s.y;
    if ( state.ur.x < s.x ) state.ur.x = s.x;
    if ( state.ur.y < s.y ) state.ur.y = s.y;

    state.point = s;
    state.noPoint = 0;
}

- (void)writeArcVertex:(NSPoint)e :(float)a :(NSPoint)center :(float)radius // :(float)t // :(float)width
{
    [grStr appendFormat:@"0\n"];
    [grStr appendFormat:@"VERTEX\n"];
    [grStr appendFormat:@"8\n"];
    [grStr appendFormat:@"%@\n", state.curLayer]; // current layer
    [grStr appendFormat:@"6\n"];
    [grStr appendFormat:@"%@\n", state.curLtype]; // current ltype
    [grStr appendFormat:@"62\n"];
    [grStr appendFormat:@"%d\n", state.curColor]; // current color
//    [grStr appendFormat:@"70\n"];
//    [grStr appendFormat:@"1\n"]; // punkt einer 2D-Kurve (0 line - 1 arc)
    [grStr appendFormat:@"42\n"]; // Ausbuchtung
    [grStr appendFormat:@"%.4f\n", a]; // *state.res/INCH
    //[grStr appendFormat:@"50\n"]; // Tangentenrichtung
    //[grStr appendFormat:@"%.4f\n", t*state.res/INCH];
    [grStr appendFormat:@"10\n"];
    [grStr appendFormat:@"%.4f\n", e.x*state.res/INCH];
    [grStr appendFormat:@"20\n"];
    [grStr appendFormat:@"%.4f\n", e.y*state.res/INCH];
/*    [grStr appendFormat:@"40\n"];
    [grStr appendFormat:@"%.4f\n", width*state.res/INCH];
    [grStr appendFormat:@"41\n"];
    [grStr appendFormat:@"%.4f\n", width*state.res/INCH];*/
    if ( state.ll.x > center.x-radius ) state.ll.x = center.x-radius;
    if ( state.ll.y > center.y-radius ) state.ll.y = center.y-radius;
    if ( state.ur.x < center.x+radius ) state.ur.x = center.x+radius;
    if ( state.ur.y < center.y+radius ) state.ur.y = center.y+radius;

    state.point = e;
    state.noPoint = 0;
}

- (void)writeCircle:(NSPoint)center :(float)radius :(float)width // only unfilled 360 degree
{
    [grStr appendFormat:@"0\n"];
    [grStr appendFormat:@"CIRCLE\n"];
    [grStr appendFormat:@"8\n"];
    [grStr appendFormat:@"%@\n", state.curLayer]; // current layer
    [grStr appendFormat:@"6\n"];
    [grStr appendFormat:@"%@\n", state.curLtype]; // current ltype
    [grStr appendFormat:@"62\n"];
    [grStr appendFormat:@"%d\n", state.curColor]; // current color
    [grStr appendFormat:@"39\n"];
    [grStr appendFormat:@"%.4f\n", width*state.res/INCH];
    [grStr appendFormat:@"10\n"];
    [grStr appendFormat:@"%.4f\n", center.x*state.res/INCH];
    [grStr appendFormat:@"20\n"];
    [grStr appendFormat:@"%.4f\n", center.y*state.res/INCH];
    [grStr appendFormat:@"40\n"];
    [grStr appendFormat:@"%.4f\n", radius*state.res/INCH];

    if ( state.ll.x > center.x-radius ) state.ll.x = center.x-radius;
    if ( state.ll.y > center.y-radius ) state.ll.y = center.y-radius;
    if ( state.ur.x < center.x+radius ) state.ur.x = center.x+radius;
    if ( state.ur.y < center.y+radius ) state.ur.y = center.y+radius;

    state.point = center;
    state.noPoint = 0;
}

// positive angles! < 360 sA != eA
- (void)writeArc:(NSPoint)center :(float)radius :(float)begAngle :(float)endAngle :(float)width
{
    [grStr appendFormat:@"0\n"];
    [grStr appendFormat:@"ARC\n"];
    [grStr appendFormat:@"8\n"];
    [grStr appendFormat:@"%@\n", state.curLayer]; // current layer
    [grStr appendFormat:@"6\n"];
    [grStr appendFormat:@"%@\n", state.curLtype]; // current ltype
    [grStr appendFormat:@"62\n"];
    [grStr appendFormat:@"%d\n", state.curColor]; // current color
    [grStr appendFormat:@"39\n"];
    [grStr appendFormat:@"%.4f\n", width*state.res/INCH];
    [grStr appendFormat:@"10\n"];
    [grStr appendFormat:@"%.4f\n", center.x*state.res/INCH];
    [grStr appendFormat:@"20\n"];
    [grStr appendFormat:@"%.4f\n", center.y*state.res/INCH];
    [grStr appendFormat:@"40\n"];
    [grStr appendFormat:@"%.4f\n", radius*state.res/INCH];
    [grStr appendFormat:@"50\n"];
    [grStr appendFormat:@"%.4f\n", begAngle];
    [grStr appendFormat:@"51\n"];
    [grStr appendFormat:@"%.4f\n", endAngle];

    if ( state.ll.x > center.x-radius ) state.ll.x = center.x-radius;
    if ( state.ll.y > center.y-radius ) state.ll.y = center.y-radius;
    if ( state.ur.x < center.x+radius ) state.ur.x = center.x+radius;
    if ( state.ur.y < center.y+radius ) state.ur.y = center.y+radius;

    state.point = center;
    state.noPoint = 0;
}

- (void)writeText:(NSPoint)o :(float)height :(float)degree :(float)iangle :(NSString*)textStr :(float)width
{
    [grStr appendFormat:@"0\n"];
    [grStr appendFormat:@"TEXT\n"];
    [grStr appendFormat:@"8\n"];
    [grStr appendFormat:@"%@\n", state.curLayer]; // current layer
    [grStr appendFormat:@"6\n"];
    [grStr appendFormat:@"%@\n", state.curLtype]; // current ltype
    [grStr appendFormat:@"62\n"];
    [grStr appendFormat:@"%d\n", state.curColor]; // current color
    [grStr appendFormat:@"10\n"];
    [grStr appendFormat:@"%.4f\n", o.x*state.res/INCH]; // ll corner
    [grStr appendFormat:@"20\n"];
    [grStr appendFormat:@"%.4f\n", o.y*state.res/INCH];
    [grStr appendFormat:@"40\n"];
    [grStr appendFormat:@"%.4f\n", height*state.res/INCH]; // text height
    [grStr appendFormat:@"1\n"];
    [grStr appendFormat:@"%@\n", textStr]; // text max 256 zeichen
    [grStr appendFormat:@"50\n"];
    [grStr appendFormat:@"%.4f\n", degree]; // drehwinkel cw 0 <= a < 360
    [grStr appendFormat:@"51\n"];
    [grStr appendFormat:@"0.0000\n"]; // , iangle text neigung - italicAngle
    [grStr appendFormat:@"7\n"];
    [grStr appendFormat:@"STANDARD\n"]; // text style TABLES STYLE default STANDARD
    //[grStr appendFormat:@"%@\n", style]; // text style TABLES STYLE default STANDARD
    //[grStr appendFormat:@"71\n"];
    //[grStr appendFormat:@"%d\n", mirror]; // spiegelung 0-not 2-x 4-y 6-x&y
/*    [grStr appendFormat:@"72\n"];
    [grStr appendFormat:@"%d\n", horicontal]; // horizontale ausrichtung
    [grStr appendFormat:@"73\n"];
    [grStr appendFormat:@"%d\n", vertical]; // vertikale ausrichtung
    [grStr appendFormat:@"11\n"];
    [grStr appendFormat:@"%.4f\n", a.x*state.res/INCH]; // ausrichtungs pt
    [grStr appendFormat:@"21\n"];
    [grStr appendFormat:@"%.4f\n", a.y*state.res/INCH];
*/
    if ( state.ll.x > o.x ) state.ll.x = o.x;
    if ( state.ll.y > o.y ) state.ll.y = o.y;
    if ( state.ur.x < o.x+width ) state.ur.x = o.x+width;
    if ( state.ur.y < o.y+height ) state.ur.y = o.y+height;

    state.point = o;
    state.noPoint = 0;
}

- (void)fillHeaderStr
{
    headerStr = [headerStr stringByAppendingFormat:@"9\n"];
    headerStr = [headerStr stringByAppendingFormat:@"$ANGBASE\n"];
    headerStr = [headerStr stringByAppendingFormat:@"50\n"];
    headerStr = [headerStr stringByAppendingFormat:@"0.0\n"]; // 0 degree to worldcoordinate system
    headerStr = [headerStr stringByAppendingFormat:@"9\n"];
    headerStr = [headerStr stringByAppendingFormat:@"$ANGDIR\n"];
    headerStr = [headerStr stringByAppendingFormat:@"70\n"];
    headerStr = [headerStr stringByAppendingFormat:@"0\n"]; // angles ccw are positive
    headerStr = [headerStr stringByAppendingFormat:@"9\n"];
    headerStr = [headerStr stringByAppendingFormat:@"$AUNITS\n"];
    headerStr = [headerStr stringByAppendingFormat:@"70\n"];
    headerStr = [headerStr stringByAppendingFormat:@"0\n"]; // angle units are degree with floating point
    headerStr = [headerStr stringByAppendingFormat:@"9\n"];
    headerStr = [headerStr stringByAppendingFormat:@"$AUPREC\n"];
    headerStr = [headerStr stringByAppendingFormat:@"70\n"];
    headerStr = [headerStr stringByAppendingFormat:@"4\n"];
    headerStr = [headerStr stringByAppendingFormat:@"9\n"];
    headerStr = [headerStr stringByAppendingFormat:@"$ATTMODE\n"];
    headerStr = [headerStr stringByAppendingFormat:@"70\n"];
    headerStr = [headerStr stringByAppendingFormat:@"1\n"];

    headerStr = [headerStr stringByAppendingFormat:@"9\n"];
    headerStr = [headerStr stringByAppendingFormat:@"$EXTMIN\n"];
    headerStr = [headerStr stringByAppendingFormat:@"10\n"]; // min x variable
    headerStr = [headerStr stringByAppendingFormat:@"%.4f\n", state.ll.x*state.res/INCH];
    headerStr = [headerStr stringByAppendingFormat:@"20\n"]; // min y variable
    headerStr = [headerStr stringByAppendingFormat:@"%.4f\n", state.ll.y*state.res/INCH];
    headerStr = [headerStr stringByAppendingFormat:@"30\n"]; // min z variable
    headerStr = [headerStr stringByAppendingFormat:@"0.0000\n"];
    headerStr = [headerStr stringByAppendingFormat:@"9\n"];
    headerStr = [headerStr stringByAppendingFormat:@"$EXTMAX\n"];
    headerStr = [headerStr stringByAppendingFormat:@"10\n"]; // max x variable
    headerStr = [headerStr stringByAppendingFormat:@"%.4f\n", state.ur.x*state.res/INCH];
    headerStr = [headerStr stringByAppendingFormat:@"20\n"]; // max y variable
    headerStr = [headerStr stringByAppendingFormat:@"%.4f\n", state.ur.y*state.res/INCH];
    headerStr = [headerStr stringByAppendingFormat:@"30\n"]; // max z variable
    headerStr = [headerStr stringByAppendingFormat:@"0.0000\n"];

    headerStr = [headerStr stringByAppendingFormat:@"9\n"];
    headerStr = [headerStr stringByAppendingFormat:@"$ENDCAPS\n"];
    headerStr = [headerStr stringByAppendingFormat:@"280\n"];
    headerStr = [headerStr stringByAppendingFormat:@"1\n"]; // round

    headerStr = [headerStr stringByAppendingFormat:@"9\n"];
    headerStr = [headerStr stringByAppendingFormat:@"$FILLMODE\n"];
    headerStr = [headerStr stringByAppendingFormat:@"70\n"];
    headerStr = [headerStr stringByAppendingFormat:@"1\n"]; // irgendwas wird bei draufsicht geföllt dargestellt

    headerStr = [headerStr stringByAppendingFormat:@"9\n"];
    headerStr = [headerStr stringByAppendingFormat:@"$INSBASE\n"];
    headerStr = [headerStr stringByAppendingFormat:@"10\n"];
    headerStr = [headerStr stringByAppendingFormat:@"0.0000\n"];
    headerStr = [headerStr stringByAppendingFormat:@"20\n"];
    headerStr = [headerStr stringByAppendingFormat:@"0.0000\n"];
    headerStr = [headerStr stringByAppendingFormat:@"30\n"];
    headerStr = [headerStr stringByAppendingFormat:@"0.0000\n"];
    headerStr = [headerStr stringByAppendingFormat:@"9\n"];
    headerStr = [headerStr stringByAppendingFormat:@"$LIMMIN\n"]; // limit min
    headerStr = [headerStr stringByAppendingFormat:@"10\n"];
    headerStr = [headerStr stringByAppendingFormat:@"0.0000\n"];
    headerStr = [headerStr stringByAppendingFormat:@"20\n"];
    headerStr = [headerStr stringByAppendingFormat:@"0.0000\n"];
    headerStr = [headerStr stringByAppendingFormat:@"9\n"];
    headerStr = [headerStr stringByAppendingFormat:@"$LIMMAX\n"]; // limit max
    headerStr = [headerStr stringByAppendingFormat:@"10\n"];
    headerStr = [headerStr stringByAppendingFormat:@"%.4f\n", state.ur.x*state.res/INCH];
    headerStr = [headerStr stringByAppendingFormat:@"20\n"];
    headerStr = [headerStr stringByAppendingFormat:@"%.4f\n", state.ur.y*state.res/INCH];

    headerStr = [headerStr stringByAppendingFormat:@"9\n"];
    headerStr = [headerStr stringByAppendingFormat:@"$JOINSTYLE\n"];
    headerStr = [headerStr stringByAppendingFormat:@"280\n"];
    headerStr = [headerStr stringByAppendingFormat:@"1\n"]; // round
    headerStr = [headerStr stringByAppendingFormat:@"9\n"];
    headerStr = [headerStr stringByAppendingFormat:@"$LUPREC\n"]; // line units precision
    headerStr = [headerStr stringByAppendingFormat:@"70\n"];
    headerStr = [headerStr stringByAppendingFormat:@"4\n"]; // 4 hinterkommastellen

    headerStr = [headerStr stringByAppendingFormat:@"9\n"];
    headerStr = [headerStr stringByAppendingFormat:@"$MEASUREMENT\n"];
    headerStr = [headerStr stringByAppendingFormat:@"70\n"];
    headerStr = [headerStr stringByAppendingFormat:@"0\n"]; // english (inch)
    headerStr = [headerStr stringByAppendingFormat:@"9\n"];
    headerStr = [headerStr stringByAppendingFormat:@"$SPLFRAME\n"];
    headerStr = [headerStr stringByAppendingFormat:@"70\n"];
    headerStr = [headerStr stringByAppendingFormat:@"1\n"]; // spline display on
}
- (void)fillTableStr
{   int	i;

    /* view port */
/*
    tableStr = [tableStr stringByAppendingFormat:@"0\n"];
    tableStr = [tableStr stringByAppendingFormat:@"TABLE\n"];
    tableStr = [tableStr stringByAppendingFormat:@"2\n"];
    tableStr = [tableStr stringByAppendingFormat:@"VPORT\n"]; // view port
    tableStr = [tableStr stringByAppendingFormat:@"0\n"];
    tableStr = [tableStr stringByAppendingFormat:@"ENDTAB\n"];
*/
    /* line type */
    tableStr = [tableStr stringByAppendingFormat:@"0\n"];
    tableStr = [tableStr stringByAppendingFormat:@"TABLE\n"];

    tableStr = [tableStr stringByAppendingFormat:@"2\n"];
    tableStr = [tableStr stringByAppendingFormat:@"LTYPE\n"]; // line type
    tableStr = [tableStr stringByAppendingFormat:@"70\n"];
    tableStr = [tableStr stringByAppendingFormat:@"%d\n", state.ltypeCnt]; // line type count

    tableStr = [tableStr stringByAppendingFormat:@"0\n"];
    tableStr = [tableStr stringByAppendingFormat:@"LTYPE\n"]; // line type
    tableStr = [tableStr stringByAppendingFormat:@"2\n"]; // layer name (0-9, A-Z, $, _, -)
    tableStr = [tableStr stringByAppendingFormat:@"CONTINUOUS\n"];
    tableStr = [tableStr stringByAppendingFormat:@"70\n"]; // ltype eigenschaften
    tableStr = [tableStr stringByAppendingFormat:@"64\n"];
    tableStr = [tableStr stringByAppendingFormat:@"3\n"]; // ltype beschreibung
    tableStr = [tableStr stringByAppendingFormat:@"CONTINUOUS\n"];
    tableStr = [tableStr stringByAppendingFormat:@"72\n"]; // ltype ausrichtung
    tableStr = [tableStr stringByAppendingFormat:@"65\n"];
    tableStr = [tableStr stringByAppendingFormat:@"73\n"]; // ltype length musterdefinition
    tableStr = [tableStr stringByAppendingFormat:@"0\n"];
    tableStr = [tableStr stringByAppendingFormat:@"40\n"]; // muster length
    tableStr = [tableStr stringByAppendingFormat:@"0.0000\n"];

    tableStr = [tableStr stringByAppendingFormat:@"0\n"];
    tableStr = [tableStr stringByAppendingFormat:@"ENDTAB\n"];
    /* layer */
    tableStr = [tableStr stringByAppendingFormat:@"0\n"];
    tableStr = [tableStr stringByAppendingFormat:@"TABLE\n"];

    tableStr = [tableStr stringByAppendingFormat:@"2\n"];
    tableStr = [tableStr stringByAppendingFormat:@"LAYER\n"]; // layer
    tableStr = [tableStr stringByAppendingFormat:@"70\n"];
    tableStr = [tableStr stringByAppendingFormat:@"%d\n", state.layerCnt]; // layer count
    for (i=0; i<state.layerCnt; i++)
    {
        tableStr = [tableStr stringByAppendingFormat:@"0\n"];
        tableStr = [tableStr stringByAppendingFormat:@"LAYER\n"];
        tableStr = [tableStr stringByAppendingFormat:@"2\n"]; // layer name (0-9, A-Z, $, _, -)
        tableStr = [tableStr stringByAppendingFormat:@"%@\n", [(state.layerNames) objectAtIndex:i]];
        tableStr = [tableStr stringByAppendingFormat:@"70\n"]; // eigenschaften
        /* layer attribute: default 64; 1 not editable; 5 not editable and not visible (4+1) */
        tableStr = [tableStr stringByAppendingFormat:@"%d\n", state.layerAttrib[i]];
        tableStr = [tableStr stringByAppendingFormat:@"62\n"]; // color
        tableStr = [tableStr stringByAppendingFormat:@"%d\n", state.layerColor[i]]; // default gelb 2
        tableStr = [tableStr stringByAppendingFormat:@"6\n"]; // line type - same like in TABLE LTYPE !
        tableStr = [tableStr stringByAppendingFormat:@"CONTINUOUS\n"];

    }
    tableStr = [tableStr stringByAppendingFormat:@"0\n"];
    tableStr = [tableStr stringByAppendingFormat:@"ENDTAB\n"];
    /* style */
/*
    tableStr = [tableStr stringByAppendingFormat:@"0\n"];
    tableStr = [tableStr stringByAppendingFormat:@"TABLE\n"];
    tableStr = [tableStr stringByAppendingFormat:@"2\n"];
    tableStr = [tableStr stringByAppendingFormat:@"STYLE\n"]; // style
    tableStr = [tableStr stringByAppendingFormat:@"0\n"];
    tableStr = [tableStr stringByAppendingFormat:@"ENDTAB\n"];

    // VIEW DIMSTYLE UCS APPID
*/
}

- (BOOL)saveToFile:(NSString*)filename
{   BOOL        savedOk = NO;
    NSString    *dxfStr = @"";

    /* FormatStatement mm */
    dxfStr = [dxfStr stringByAppendingFormat:@"0\n"];
    dxfStr = [dxfStr stringByAppendingFormat:@"SECTION\n"]; // begin section
    dxfStr = [dxfStr stringByAppendingFormat:@"2\n"];
    dxfStr = [dxfStr stringByAppendingFormat:@"HEADER\n"]; // header
[self fillHeaderStr];
    dxfStr = [dxfStr stringByAppendingString:headerStr];
    dxfStr = [dxfStr stringByAppendingFormat:@"0\n"];
    dxfStr = [dxfStr stringByAppendingFormat:@"ENDSEC\n"]; // end section

    dxfStr = [dxfStr stringByAppendingFormat:@"0\n"];
    dxfStr = [dxfStr stringByAppendingFormat:@"SECTION\n"]; // begin section
    dxfStr = [dxfStr stringByAppendingFormat:@"2\n"];
    dxfStr = [dxfStr stringByAppendingFormat:@"TABLES\n"]; // tables
[self fillTableStr];
    dxfStr = [dxfStr stringByAppendingString:tableStr];
    dxfStr = [dxfStr stringByAppendingFormat:@"0\n"];
    dxfStr = [dxfStr stringByAppendingFormat:@"ENDSEC\n"]; // end section

    dxfStr = [dxfStr stringByAppendingFormat:@"0\n"];
    dxfStr = [dxfStr stringByAppendingFormat:@"SECTION\n"]; // begin section
    dxfStr = [dxfStr stringByAppendingFormat:@"2\n"];
    dxfStr = [dxfStr stringByAppendingFormat:@"BLOCKS\n"]; // blocks
    dxfStr = [dxfStr stringByAppendingString:blockStr];
    dxfStr = [dxfStr stringByAppendingFormat:@"0\n"];
    dxfStr = [dxfStr stringByAppendingFormat:@"ENDSEC\n"]; // end section

    dxfStr = [dxfStr stringByAppendingFormat:@"0\n"];
    dxfStr = [dxfStr stringByAppendingFormat:@"SECTION\n"]; // begin section
    dxfStr = [dxfStr stringByAppendingFormat:@"2\n"];
    dxfStr = [dxfStr stringByAppendingFormat:@"ENTITIES\n"]; // entities
    dxfStr = [dxfStr stringByAppendingString:grStr];
    dxfStr = [dxfStr stringByAppendingFormat:@"0\n"];
    dxfStr = [dxfStr stringByAppendingFormat:@"ENDSEC\n"]; // end section

    dxfStr = [dxfStr stringByAppendingFormat:@"0\n"]; // end of programm
    dxfStr = [dxfStr stringByAppendingFormat:@"EOF\n"]; // end of programm

    //savedOk = [dxfStr writeToFile:filename atomically:YES];
    savedOk = [dxfStr writeToFile:filename atomically:YES
                         encoding:NSUTF8StringEncoding error:NULL]; // >= 10.5

    return savedOk;
}

- (void)dealloc
{
    [super dealloc];
}

@end
