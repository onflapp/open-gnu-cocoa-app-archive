/* GerberExport.m
 * Gerber export object
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

#include "GerberExport.h"
//#import "locations.h" /* GERBER_EXT */
#include "../VHFShared/types.h"
#include "../VHFShared/VHFStringAdditions.h" // stringByReplacing -> eps export

#define RES 10000

@interface GerberExport(PrivateMethods)
@end

@implementation GerberExport

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
//    state.color = [NSColor blackColor];
//    state.setBounds = 1;
//    state.ll.x = state.ll.y = MAXCOORD;
//    state.ur.x = state.ur.y = 0.0;
    state.maxW = 0;
    grStr = [NSMutableString string];
    toolStr = [NSMutableString string];

    return self;
}

- (void)writeLine:(NSPoint)s :(NSPoint)e
{
    if ( (state.noPoint || Diff(state.point.x, s.x) > TOLERANCE || Diff(state.point.y, s.y) > TOLERANCE) )
    {
        [grStr appendFormat:@"X%.0fY%.0fD02*\n", s.x/INCH*RES, s.y/INCH*RES]; //  v*RES (1000)
        /*if ( state->setBounds )
        {   if ( state.ll.x > s.x ) state.ll.x = s.x;
            if ( state.ll.y > s.y ) state.ll.y = s.y;
            if ( state.ur.x < s.x ) state.ur.x = s.x;
            if ( state.ur.y < s.y ) state.ur.y = s.y;
        }*/
    }
    [grStr appendFormat:@"X%.0fY%.0fD01*\n", e.x/INCH*RES, e.y/INCH*RES];
    /*if ( state->setBounds )
    {   if ( state.ll.x > e.x ) state.ll.x = e.x;
        if ( state.ll.y > e.y ) state.ll.y = e.y;
        if ( state.ur.x < e.x ) state.ur.x = e.x;
        if ( state.ur.y < e.y ) state.ur.y = e.y;
    }*/
    state.point = e;
    state.noPoint = 0;
}

- (void)writeRectangle:(NSPoint)origin // we only flash rectangle else -> path !
{
    [grStr appendFormat:@"X%.0fY%.0fD03*\n", origin.x/INCH*RES, origin.y/INCH*RES];
    state.point = origin;
    state.noPoint = 0;
}

- (void)writeCircle:(NSPoint)center // we only flash circles else -> ?? !
{
    [grStr appendFormat:@"X%.0fY%.0fD03*\n", center.x/INCH*RES, center.y/INCH*RES];
    state.point = center;
    state.noPoint = 0;
}

- (void)writeArc:(NSPoint)center :(NSPoint)start :(NSPoint)end :(BOOL)ccw
{   NSPoint	scDiff;
    int		gVal = (ccw) ? 3 : 2; // G03 : G02

    scDiff.x = center.x - start.x; // i x diff from start to center
    scDiff.y = center.y - start.y; // j y ..

    // move if start is not the currentPoint
    if ( (state.noPoint || Diff(state.point.x, start.x) > TOLERANCE || Diff(state.point.y, start.y) > TOLERANCE) )
        [grStr appendFormat:@"G01X%.0fY%.0fD02*\n", start.x/INCH*RES, start.y/INCH*RES];

    [grStr appendFormat:@"G0%dX%.0fY%.0fI%.0fJ%.0fD01*G01*\n", gVal, end.x/INCH*RES, end.y/INCH*RES, scDiff.x/INCH*RES, scDiff.y/INCH*RES];
    state.point = end;
    state.noPoint = 0;
}

- (void)writeLayerPolarityMode:(BOOL)mode
{
    if (mode)
        [grStr appendFormat:@"%%LPC*%%\n"]; // all following graphics are clear
    else
        [grStr appendFormat:@"%%LPD*%%\n"]; // all following graphics are drawn black
}

- (void)writePolygonMode:(BOOL)mode
{
    if (mode)
        [grStr appendFormat:@"G36*\n"];
    else
        [grStr appendFormat:@"G37*\n"];
}

- (void)writeCircleTool:(float)dia
{   NSRange	range;
    int		toolnew = state.curTool;

    range = [toolStr rangeOfString:[NSString stringWithFormat:@"C,%.4f*", dia/INCH]];
    if (!range.length) // tool not yet in toolStr
    {   NSMutableDictionary	*dict = [NSMutableDictionary dictionary];

        [toolStr appendFormat:@"%%ADD%dC,%.4f*%%\n", ++(state.toolCnt), dia/INCH];
        [dict setObject:[NSString stringWithFormat:@"C"] forKey:@"formCode"]; // C R
        [dict setObject:[NSNumber numberWithFloat:dia] forKey:@"width"];
        [dict setObject:[NSNumber numberWithFloat:dia] forKey:@"height"];
        [toolDict setObject:dict forKey:[NSString stringWithFormat:@"%d", state.toolCnt]]; // 10 11 ..
        toolnew = state.toolCnt;
    }
    else // search tool in toolDict
    {   int	d;

        for (d=[toolDict count]+9; d>=10; d--) // we start with D10
        {   float dn = [[[toolDict objectForKey:[NSString stringWithFormat:@"%d", d]] objectForKey:@"width"] floatValue];
            if (Diff(dn, dia) < TOLERANCE)
            {
                toolnew = d;
                break;
            }
        }
    }
    if (state.curTool != toolnew)
    {   [grStr appendFormat:@"D%d*\n", toolnew];
        state.curTool = toolnew;
    }
}
- (void)writeRectangleTool:(float)w :(float)h
{   NSRange	range;
    int		toolnew = state.curTool;

    range = [toolStr rangeOfString:[NSString stringWithFormat:@"R,%.4fX%.4f*", w/INCH, h/INCH]];
    if (!range.length) // tool not yet in toolStr
    {   NSMutableDictionary	*dict = [NSMutableDictionary dictionary];

        [toolStr appendFormat:@"%%ADD%dR,%.4fX%.4f*%%\n", ++(state.toolCnt), w/INCH, h/INCH];
        [dict setObject:[NSString stringWithFormat:@"R"] forKey:@"formCode"]; // C R
        [dict setObject:[NSNumber numberWithFloat:w] forKey:@"width"];
        [dict setObject:[NSNumber numberWithFloat:h] forKey:@"height"];
        [toolDict setObject:dict forKey:[NSString stringWithFormat:@"%d", state.toolCnt]]; // 10 11 ..
        toolnew = state.toolCnt;
    }
    else // search tool in toolDict
    {   int	d;

        for (d=[toolDict count]+9; d>=10; d--) // we start with D10
        {	NSDictionary	*tdict=[toolDict objectForKey:[NSString stringWithFormat:@"%d", d]];
            float		wn = [[tdict objectForKey:@"width"] floatValue];
            float		hn = [[tdict objectForKey:@"height"] floatValue];

            if (Diff(wn, w) < TOLERANCE && Diff(hn, h) < TOLERANCE)
            {
                toolnew = d;
                break;
            }
        }
    }

    if (state.curTool != toolnew)
    {   [grStr appendFormat:@"D%d*\n", toolnew];
        state.curTool = toolnew;
    }
}

- (BOOL)saveToFile:(NSString*)filename
{   BOOL        savedOk = NO;
    NSString    *gerberStr = @"";

    /* FormatStatement mm */
    gerberStr = [gerberStr stringByAppendingFormat:@"%%MOIN*%%\n"]; // inch
    gerberStr = [gerberStr stringByAppendingFormat:@"%%FSLAX54Y54*%%\n"]; // leading zeros absolut values 5.3

    /* tools */
    gerberStr = [gerberStr stringByAppendingString:toolStr]; // %ADD10C,0.5*%\n
    gerberStr = [gerberStr stringByAppendingFormat:@"G75*\n"]; // 360 circular interpolation

    /* graphics */
    gerberStr = [gerberStr stringByAppendingString:grStr];

    /* pen up - move to 0, 0 - select NO pen */
    gerberStr = [gerberStr stringByAppendingFormat:@"M02*\n"]; // end of programm

    //savedOk = [gerberStr writeToFile:filename atomically:YES];
    savedOk = [gerberStr writeToFile:filename atomically:YES
                            encoding:NSUTF8StringEncoding error:NULL];  // >= 10.5

    return savedOk;
}

- (void)dealloc
{
    [super dealloc];
}

@end
