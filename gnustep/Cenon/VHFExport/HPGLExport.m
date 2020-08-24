/* HPGLExport.m
 * HPGL export object
 *
 * Copyright (C) 2002-2012 by vhf interservice GmbH
 * Author:   Ilonka Fleischmann
 *
 * created:  2002-04-28
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

#include "HPGLExport.h"
#include "../VHFShared/types.h"
#include "../VHFShared/VHFStringAdditions.h" // stringByReplacing -> eps export

#define RES 1000

@interface HPGLExport(PrivateMethods)
@end

@implementation HPGLExport

/* initialize
 */
- init
{
    [super init];

//    toolDict = [NSMutableDictionary dictionary];
    state.res = 1021.0;
    state.toolCnt = 9; // we start with D10
    state.curTool = 0;
    state.noPoint = 1;
    state.fill = 0;
    state.color = [NSColor blackColor];
    state.setBounds = 1;
    state.ll.x = state.ll.y = MAXCOORD;
    state.ur.x = state.ur.y = 0.0;
    state.maxW = 0;
    grStr = [NSMutableString string];
//    toolStr = @"";

    return self;
}

- (void)writeLine:(NSPoint)s :(NSPoint)e
{
    if ( (state.noPoint || Diff(state.point.x, s.x) > TOLERANCE || Diff(state.point.y, s.y) > TOLERANCE) )
    {
        [grStr appendFormat:@"PU;PA%.0f,%.0f;\nPD;", s.x*state.res/INCH, s.y*state.res/INCH];
        if ( state.setBounds )
        {   if ( state.ll.x > s.x ) state.ll.x = s.x;
            if ( state.ll.y > s.y ) state.ll.y = s.y;
            if ( state.ur.x < s.x ) state.ur.x = s.x;
            if ( state.ur.y < s.y ) state.ur.y = s.y;
        }
    }
    [grStr appendFormat:@"PA%.0f,%.0f;\n", e.x*state.res/INCH, e.y*state.res/INCH];
    if ( state.setBounds )
    {   if ( state.ll.x > e.x ) state.ll.x = e.x;
        if ( state.ll.y > e.y ) state.ll.y = e.y;
        if ( state.ur.x < e.x ) state.ur.x = e.x;
        if ( state.ur.y < e.y ) state.ur.y = e.y;
    }
    state.point = e;
    state.noPoint = 0;
}

/*- (void)writeRectangle:(NSPoint)origin // we only flash rectangle else -> path !
{
    grStr = [grStr stringByAppendingFormat:@"X%.0fY%.0fD03*\n", origin.x/INCH*RES, origin.y/INCH*RES];
    state.point = origin;
    state.noPoint = 0;
}*/

- (void)writeCircle:(NSPoint)center :(float)radius
{
    if ( (state.noPoint || Diff(state.point.x, center.x) > TOLERANCE || Diff(state.point.y, center.y) > TOLERANCE) )
    {
        [grStr appendFormat:@"PU;PA%.0f,%.0f;\nPD;", center.x*state.res/INCH, center.y*state.res/INCH];
    }
    [grStr appendFormat:@"CI%.0f;\n", radius/INCH*RES];
    if ( state.setBounds )
    {   if ( state.ll.x > center.x-radius ) state.ll.x = center.x-radius;
        if ( state.ll.y > center.y-radius ) state.ll.y = center.y-radius;
        if ( state.ur.x < center.x+radius ) state.ur.x = center.x+radius;
        if ( state.ur.y < center.y+radius ) state.ur.y = center.y+radius;
    }
    state.point = center;
    state.noPoint = 0;
}

- (void)writeArc:(NSPoint)center :(NSPoint)start :(NSPoint)end :(float)angle
{
    if ( (state.noPoint || Diff(state.point.x, start.x) > TOLERANCE || Diff(state.point.y, start.y) > TOLERANCE) )
    {
        [grStr appendFormat:@"PU;PA%.0f,%.0f;\nPD;", start.x*state.res/INCH, start.y*state.res/INCH];
        if ( state.setBounds )
        {   if ( state.ll.x > start.x ) state.ll.x = start.x;
            if ( state.ll.y > start.y ) state.ll.y = start.y;
            if ( state.ur.x < start.x ) state.ur.x = start.x;
            if ( state.ur.y < start.y ) state.ur.y = start.y;
        }
    }
    [grStr appendFormat:@"AA%.0f,%.0f,%.3f;\n", center.x*state.res/INCH, center.y*state.res/INCH, angle];
    if ( state.setBounds )
    {   if ( state.ll.x > end.x ) state.ll.x = end.x;
        if ( state.ll.y > end.y ) state.ll.y = end.y;
        if ( state.ur.x < end.x ) state.ur.x = end.x;
        if ( state.ur.y < end.y ) state.ur.y = end.y;
    }
    state.point = end;
    state.noPoint = 0;
}

/*- (void)writePolygonMode:(BOOL)mode
{
    if (mode)
        grStr = [grStr stringByAppendingFormat:@"G36*\n"];
    else
        grStr = [grStr stringByAppendingFormat:@"G37*\n"];
}

- (void)writeCircleTool:(float)dia
{   NSRange	range;
    int		toolnew = state.curTool;

    range = [toolStr rangeOfString:[NSString stringWithFormat:@"C,%.4f*", dia/INCH]];
    if (!range.length) // tool not yet in toolStr
    {   NSMutableDictionary	*dict = [NSMutableDictionary dictionary];

        toolStr = [toolStr stringByAppendingFormat:@"%%ADD%dC,%.4f*%%\n", ++(state.toolCnt), dia/INCH];
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
    {   grStr = [grStr stringByAppendingFormat:@"D%d*\n", toolnew];
        state.curTool = toolnew;
    }
}
- (void)writeRectangleTool:(float)w :(float)h
{   NSRange	range;
    int		toolnew = state.curTool;

    range = [toolStr rangeOfString:[NSString stringWithFormat:@"R,%.4fX%.4f*", w/INCH, h/INCH]];
    if (!range.length) // tool not yet in toolStr
    {   NSMutableDictionary	*dict = [NSMutableDictionary dictionary];

        toolStr = [toolStr stringByAppendingFormat:@"%%ADD%dR,%.4fX%.4f*%%\n", ++(state.toolCnt), w/INCH, h/INCH];
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
    {   grStr = [grStr stringByAppendingFormat:@"D%d*\n", toolnew];
        state.curTool = toolnew;
    }
}
*/

- (BOOL)saveToFile:(NSString*)filename
{   BOOL        savedOk = NO;
    NSString    *hpglStr = @"";

	/* INit - IW, bounds - pen up - selectPen (color) */
	hpglStr = [hpglStr stringByAppendingFormat:@"IN;IW0,0,%.0f,%.0f;\n", state.ur.x*state.res/INCH, state.ur.y*state.res/INCH];
	hpglStr = [hpglStr stringByAppendingFormat:@"SP1;\n"]; // select pen

	/* graphics */
	hpglStr = [hpglStr stringByAppendingString:grStr];

	/* pen up - move to 0, 0 - select NO pen */
	hpglStr = [hpglStr stringByAppendingFormat:@"PU;PA0,0;SP;\n"];


    //savedOk = [hpglStr writeToFile:filename atomically:YES];
    savedOk = [hpglStr writeToFile:filename atomically:YES
                          encoding:NSUTF8StringEncoding error:NULL];    // >= 10.5

    return savedOk;
}

- (void)dealloc
{
    [super dealloc];
}

@end
