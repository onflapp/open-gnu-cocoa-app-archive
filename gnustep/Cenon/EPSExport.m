/* EPSExport.m
 *
 * Copyright (C) 2000-2012 by vhf interservice GmbH
 * Author:   Ilonka Fleischmann
 *
 * created:  2000-12-21
 * modified: 2012-09-13 (-writeToFile: workaround: keep scaleFactor >= 1.0 not to clip graphics)
 *           2012-02-07 (-writeToFile: use writeToFile:...encoding:error:)
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

#include <AppKit/AppKit.h>
#include <VHFShared/vhfCommonFunctions.h>
#include <VHFShared/VHFStringAdditions.h> // stringByReplacing -> eps export, -writeToFile:... 10.5 compatibility
#include "App.h"
#include "EPSExport.h"
#include "Graphics.h"
#include "messages.h"
#include "locations.h"
#include "PreferencesMacros.h"

@interface EPSExport(PrivateMethods)
@end

@implementation EPSExport

+ (EPSExport*)epsExport
{
    return [[[EPSExport allocWithZone:[self zone]] init] autorelease];
}

/* initialize
 */
- init
{
    return [super init];
}

- (void)setDocumentView:view
{
    docView = view;
}

typedef struct _EPSState
{
    int		noPoint;
    NSPoint	point;
    BOOL	setBounds; // if we have an clipRect
    float	maxW;
    NSPoint	ll;
    NSPoint	ur;
    float	width;
    NSColor	*color;
    BOOL	fill;
}EPSState;

- (NSString*)epsLine:(VLine*)g :(EPSState*)epsState
{   NSPoint	s, e;
    NSString	*str=@"";
    [(VLine*)g getVertices:&s :&e];

    if ( /*!epsState->pathMode &&*/
         (epsState->noPoint || Diff(epsState->point.x, s.x) > TOLERANCE || Diff(epsState->point.y, s.y) > TOLERANCE) )
    {
        if ( !epsState->noPoint )
            str = [str stringByAppendingFormat:@"stroke\n"]; // so we stroke previous graphics

        str = [str stringByAppendingFormat:@"%.0f %.0f moveto\n", s.x, s.y];
        if ( epsState->setBounds )
        {   if ( epsState->ll.x > s.x ) epsState->ll.x = s.x;
            if ( epsState->ll.y > s.y ) epsState->ll.y = s.y;
            if ( epsState->ur.x < s.x ) epsState->ur.x = s.x;
            if ( epsState->ur.y < s.y ) epsState->ur.y = s.y;
        }
    }
    str = [str stringByAppendingFormat:@"%.0f %.0f lineto\n", e.x, e.y];
    if ( epsState->setBounds )
    {   if ( epsState->ll.x > e.x ) epsState->ll.x = e.x;
        if ( epsState->ll.y > e.y ) epsState->ll.y = e.y;
        if ( epsState->ur.x < e.x ) epsState->ur.x = e.x;
        if ( epsState->ur.y < e.y ) epsState->ur.y = e.y;
    }
    epsState->point = e;
    epsState->noPoint = 0;
    return str;
}

- (NSString*)epsRectangle:(VRectangle*)g :(EPSState*)epsState
{   NSPoint	o, s;
    NSString	*str=@"";
    [(VRectangle*)g getVertices:&o :&s];

    if ( !epsState->noPoint ) // else we have no previous graphics
        str = [str stringByAppendingFormat:@"stroke\n"]; // so we stroke previous graphics

//    if ( /*!epsState->pathMode &&*/
//         (epsState->noPoint || Diff(epsState->point.x, o.x) > TOLERANCE || Diff(epsState->point.y, o.y) > TOLERANCE) )
    {   str = [str stringByAppendingFormat:@"%.0f %.0f moveto\n", o.x, o.y];
        if ( epsState->setBounds )
        {   if ( epsState->ll.x > o.x ) epsState->ll.x = o.x;
            if ( epsState->ll.y > o.y ) epsState->ll.y = o.y;
        }
    }
    if ( [g filled] )
        str = [str stringByAppendingFormat:@"%.0f %.0f %.0f %.0f rectfill\n", o.x, o.y, s.x, s.y];
    else
        str = [str stringByAppendingFormat:@"%.0f %.0f %.0f %.0f rectstroke\n", o.x, o.y, s.x, s.y];
    if ( epsState->setBounds )
    {   if ( epsState->ur.x < o.x+s.x ) epsState->ur.x = o.x+s.x;
        if ( epsState->ur.y < o.y+s.y ) epsState->ur.y = o.y+s.y;
    }
    return str;
}

- (NSString*)epsArc:(VArc*)g :(EPSState*)epsState
{   NSString	*str=@"";
    NSPoint	c, s;
    float	a, ba, r;

    [(VArc*)g getCenter:&c start:&s angle:&a];
    ba = [(VArc*)g begAngle];
    r = [(VArc*)g radius];

    if ( a == 360.0 && !epsState->noPoint ) // else we have no previous graphics
        str = [str stringByAppendingFormat:@"stroke\n"]; // so we stroke previous graphics

    if ( /*!epsState->pathMode &&*/
         (epsState->noPoint || Diff(epsState->point.x, s.x) > TOLERANCE || Diff(epsState->point.y, s.y) > TOLERANCE) )
        str = [str stringByAppendingFormat:@"%.0f %.0f moveto\n", s.x, s.y];
    if ( a > 0 )
    {   float           ea = ba+a;
        if (ea > 360.0) ea -= 360.0;
        str = [str stringByAppendingFormat:@"%.0f %.0f %.0f %.0f %.0f arc\n", c.x, c.y, r, ba, ea];
    }
    else
    {   float           ea = ba+a;
        if (ea < 0)     ea += 360.0;
        str = [str stringByAppendingFormat:@"%.0f %.0f %.0f %.0f %.0f arcn\n", c.x, c.y, r, ba, ea];
    }
    if ( epsState->setBounds )
    {   NSRect	b = [(VArc*)g bounds];
        if ( epsState->ll.x > b.origin.x ) epsState->ll.x = b.origin.x;
        if ( epsState->ll.y > b.origin.y ) epsState->ll.y = b.origin.y;
        if ( epsState->ur.x < b.origin.x+b.size.width ) epsState->ur.x = b.origin.x+b.size.width;
        if ( epsState->ur.y < b.origin.y+b.size.height ) epsState->ur.y = b.origin.y+b.size.height;
    }
    epsState->point = [(VArc*)g pointWithNum:-1]; // default is end
    epsState->noPoint = 0;

    return str;
}

- (NSString*)epsCurve:(VCurve*)g :(EPSState*)epsState
{   NSPoint	p0, p1, p2, p3;
    NSString	*str=@"";
    [(VCurve*)g getVertices:&p0 :&p1 :&p2 :&p3];

    if ( /*!epsState->pathMode &&*/
         (epsState->noPoint || Diff(epsState->point.x, p0.x) > TOLERANCE || Diff(epsState->point.y, p0.y) > TOLERANCE) )
        str = [str stringByAppendingFormat:@"%.0f %.0f moveto\n", p0.x, p0.y];
    str = [str stringByAppendingFormat:@"%.0f %.0f %.0f %.0f %.0f %.0f curveto\n", p1.x, p1.y, p2.x, p2.y, p3.x, p3.y];
    if ( epsState->setBounds )
    {   NSRect	b = [(VArc*)g bounds];
        if ( epsState->ll.x > b.origin.x ) epsState->ll.x = b.origin.x;
        if ( epsState->ll.y > b.origin.y ) epsState->ll.y = b.origin.y;
        if ( epsState->ur.x < b.origin.x+b.size.width ) epsState->ur.x = b.origin.x+b.size.width;
        if ( epsState->ur.y < b.origin.y+b.size.height ) epsState->ur.y = b.origin.y+b.size.height;
    }
    epsState->point = p3;
    epsState->noPoint = 0;
    return str;
}

- (NSString*)epsPath:(VPath*)g :(EPSState*)epsState
{   NSString	*str=@"";
    int		i, cnt=[[g list] count];

    if ( !cnt )
        return str;

    str = [str stringByAppendingFormat:@"gsave\n"];

    str = [str stringByAppendingFormat:@"newpath\n"];
epsState->noPoint = 1;
    for (i=0; i<cnt; i++)
    {   VGraphic	*gr = [[g list] objectAtIndex:i];

//        if ( i == 1 ) epsState->pathMode = 1; // first graphic need a moveto

        if (  [gr isKindOfClass:[VLine class]] )
            str = [str stringByAppendingString:[self epsLine:(VLine*)gr :epsState]]; // move if possible and lineto
        else if (  [gr isKindOfClass:[VRectangle class]] )
            str = [str stringByAppendingString:[self epsRectangle:(VRectangle*)gr :epsState]];
        else if (  [gr isKindOfClass:[VArc class]] )
            str = [str stringByAppendingString:[self epsArc:(VArc*)gr :epsState]];
        else if (  [gr isKindOfClass:[VCurve class]] )
            str = [str stringByAppendingString:[self epsCurve:(VCurve*)gr :epsState]];
        else NSLog(@"epsPath gr type not implemented\n");
//        else if (  [g isKindOfClass:[VGroup class]] && [gr isKindOfClass:[VPath class]] )
//            str = [str stringByAppendingString:[self epsPath:gr :epsState]];
    }
    str = [str stringByAppendingFormat:@"closepath\n"];
    if ( [g filled] )
        str = [str stringByAppendingFormat:@"eofill\n"];
    else
        str = [str stringByAppendingFormat:@"stroke\n"];

    str = [str stringByAppendingFormat:@"grestore\n"]; // state is the same as before path !
    return str;
}

- (NSString*)epsGroup:(VGroup*)g :(EPSState*)epsState
{   NSString	*str=@"";
    int		i, cnt=[[g list] count];

    if ( !cnt )
        return str;

    for (i=0; i<cnt; i++)
    {   VGraphic	*gr = [[g list] objectAtIndex:i];

        if ( ![[gr color] isEqual:epsState->color] )
        {
            if ( [[[gr color] colorSpaceName] isEqual:@"NSCalibratedWhiteColorSpace"] )
                str = [str stringByAppendingFormat:@"%.2f setgray\n", [[gr color] whiteComponent]];
            else
                str = [str stringByAppendingFormat:@"%.2f %.2f %.2f setrgbcolor\n",
                    [[gr color] redComponent], [[gr color] greenComponent], [[gr color] blueComponent]];
            epsState->color = [gr color];
        }
        if ( epsState->width != [gr width] )
        {   str = [str stringByAppendingFormat:@"%.2f setlinewidth\n", [gr width]];
            epsState->width = [gr width];
            if ( epsState->maxW < epsState->width ) epsState->maxW = epsState->width;
        }

        if (  [gr isKindOfClass:[VLine class]] )
            str = [str stringByAppendingString:[self epsLine:(VLine*)gr :epsState]]; // move if possible and lineto
        else if (  [gr isKindOfClass:[VRectangle class]] )
            str = [str stringByAppendingString:[self epsRectangle:(VRectangle*)gr :epsState]];
        else if (  [gr isKindOfClass:[VArc class]] )
            str = [str stringByAppendingString:[self epsArc:(VArc*)gr :epsState]];
        else if (  [gr isKindOfClass:[VCurve class]] )
            str = [str stringByAppendingString:[self epsCurve:(VCurve*)gr :epsState]];
        else if (  [gr isKindOfClass:[VPath class]] )
            str = [str stringByAppendingString:[self epsPath:(VPath*)gr :epsState]];
        else if (  [gr isKindOfClass:[VGroup class]] )
            str = [str stringByAppendingString:[self epsGroup:(VGroup*)gr :epsState]];
        else NSLog(@"epsGroup gr type not implemented\n");
    }
    return str;
}

- (NSString*)epsImage:(VImage*)g :(EPSState*)epsState
{   NSString	*str=@"";

    
    return str;
}

- (NSString*)epsVText:(VText*)g :(EPSState*)epsState
{   NSString	*str = @"";
    NSRect	b = [g bounds];
    NSPoint	o;
    NSString	*curStr; // , *text = [g string];
    BOOL	filled = [g filled];
    float	lineHeight = [g lineHeight];
    NSScanner		*scanner = [NSScanner scannerWithString:[g string]];
    NSCharacterSet	*skipSet = [NSCharacterSet characterSetWithCharactersInString:@"\n\r"];
    int			first = 1;

    o = b.origin;
    o.y += b.size.height - lineHeight;  // ???
    str = [str stringByAppendingFormat:@"/%@ findfont\n", [[g font] fontName]];
    str = [str stringByAppendingFormat:@"%.1f scalefont setfont\n", [[g font] pointSize]];
    [scanner setCharactersToBeSkipped:[NSCharacterSet characterSetWithCharactersInString:@""]];
    [scanner scanCharactersFromSet:skipSet intoString:NULL];
    while ( ![scanner isAtEnd] )
    {
        /* up to location != ' ' */
        if ( ![scanner scanUpToCharactersFromSet:skipSet intoString:&curStr] )
            curStr = @"";

        curStr = [curStr stringByReplacing:@"\t" by:@"    "]; // \t -> 4 or 8 blanks

        if ( !first ) o.y -= lineHeight;
        first = 0;
        if ( ![curStr length] ) continue; // simpy \n

        if ( epsState->noPoint || Diff(epsState->point.x, o.x) > TOLERANCE || Diff(epsState->point.y, o.y) > TOLERANCE )
            str = [str stringByAppendingFormat:@"%.0f %.0f moveto\n", o.x, o.y];
        if ( filled )
        {   str = [str stringByAppendingFormat:@"(%@) true charpath\n", curStr]; // true -> no stroke !
            str = [str stringByAppendingFormat:@"eofill\n"];
        }
        else
        {   str = [str stringByAppendingFormat:@"(%@) false charpath\n"];
            str = [str stringByAppendingFormat:@"stroke\n"];
        }
        [scanner scanCharactersFromSet:skipSet intoString:NULL];
    }
    if ( filled ) str = [str stringByAppendingFormat:@"eofill\n"];
    else          str = [str stringByAppendingFormat:@"stroke\n"];

    if ( epsState->setBounds )
    {   if ( epsState->ll.x > b.origin.x ) epsState->ll.x = b.origin.x;
        if ( epsState->ll.y > b.origin.y ) epsState->ll.y = b.origin.y;
        if ( epsState->ur.x < b.origin.x+b.size.width ) epsState->ur.x = b.origin.x+b.size.width;
        if ( epsState->ur.y < b.origin.y+b.size.height ) epsState->ur.y = b.origin.y+b.size.height;
    }
    epsState->point = [g pointWithNum:PT_LOWERRIGHT];
    epsState->noPoint = 0;
    return str;
}

- (BOOL)writeToFile:(NSString*)filename
{   BOOL            savedOk = NO;
    NSString        *backupFilename;
    NSFileManager   *fileManager = [NSFileManager defaultManager];

    backupFilename = [[[filename stringByDeletingPathExtension] stringByAppendingString:@"~"]
                      stringByAppendingPathExtension:EPS_EXT];
    /* file not writable */
    if ( [fileManager fileExistsAtPath:filename] && ![fileManager isWritableFileAtPath:filename] )
    {   NSRunAlertPanel(SAVE_TITLE, CANT_CREATE_BACKUP, nil, nil, nil);
        return NO;
    }
    /* rename to backup */
    if ( ([fileManager fileExistsAtPath:backupFilename] && ![fileManager removeFileAtPath:backupFilename handler:nil]) || ([fileManager fileExistsAtPath:filename] && ![fileManager movePath:filename toPath:backupFilename handler:nil]) )
    {   NSRunAlertPanel(SAVE_TITLE, CANT_CREATE_BACKUP, nil, nil, nil);
        return NO;
    }

    {   NSArray		*list = [docView layerList];
        NSString	*string;
        NSData		*psData;
        NSRect		bRect;
        NSPoint		ll, ur;
        int         i, cnt;
        VFloat      sf = [docView scaleFactor];

        // bRect = [docView bounds];
        ll.x = ll.y = MAXCOORD;
        ur.x = ur.y = 0.0;
        cnt = [list count];
        for (i=0; i<cnt; i++)
        {   NSRect	rect;
            LayerObject	*lObj = [list objectAtIndex:i];

            //if ( [lObj type] == LAYER_CLIPPING ) // type
            //    continue;
            rect = [docView boundsOfArray:[lObj list]];
            if ( ![lObj state] || (!rect.size.width && !rect.size.height) )
                continue;
            if ( ll.x > rect.origin.x ) ll.x = rect.origin.x;
            if ( ll.y > rect.origin.y ) ll.y = rect.origin.y;
            if ( ur.x < rect.origin.x+rect.size.width )  ur.x = rect.origin.x+rect.size.width;
            if ( ur.y < rect.origin.y+rect.size.height ) ur.y = rect.origin.y+rect.size.height;
        }
        bRect.origin.x   = ll.x;        bRect.origin.y    = ll.y;
        bRect.size.width = ur.x - ll.x; bRect.size.height = ur.y - ll.y;
        //bRect.size.width  *= (sf > 0.0) ? (sf) : (1.0);
        //bRect.size.height *= (sf > 0.0) ? (sf) : (1.0);
        bRect.size.width  *= (sf < 1.0) ? (1.0) : (sf); // workaround Apple: otherwise graphics gets clipped
        bRect.size.height *= (sf < 1.0) ? (1.0) : (sf);
        psData = [docView dataWithEPSInsideRect:bRect];
        string = [[NSString alloc] initWithData:psData encoding:NSASCIIStringEncoding];
        //savedOk = [string writeToFile:filename atomically:YES];
        savedOk = [string writeToFile:filename atomically:YES
                             encoding:NSUTF8StringEncoding error:NULL]; // >= 10.5
        [string release];
    }

#if 0
    //else if ( isDirectory && [fileManager createDirectoryAtPath:filename attributes:nil] )
    //fileDirectory = [filename stringByDeletingLastPathComponent];
    /* save */
    //if ([fileManager isWritableFileAtPath:filename])
    {   NSString	*epsStr, *grStr=@"";
        NSRect		clipRect;
        id		layerList = [docView layerList];
        int		i, lCnt = [layerList count];
        EPSState	epsState;

        epsState.noPoint = 1;
        epsState.fill = 0;
        epsState.color = [NSColor blackColor];
        epsState.setBounds = 1;
        epsState.ll.x = epsState.ll.y = MAXCOORD;
        epsState.ur.x = epsState.ur.y = 0.0;
        epsState.maxW = 0;

        grStr = [grStr stringByAppendingFormat:@"1 setlinecap\n"];
        grStr = [grStr stringByAppendingFormat:@"1 setlinejoin\n"];

// 72 25400 div 72 25400 div scale\n

        // first clip rect
        clipRect.size.width = clipRect.size.height = 0.0;
        clipRect = [[docView clipObject] bounds];
        if ( clipRect.size.width && clipRect.size.height )
        {   grStr = [grStr stringByAppendingFormat:@"%.0f %.0f %.0f %.0f rectclip\n", clipRect.origin.x, clipRect.origin.y, clipRect.size.width, clipRect.size.height];
            epsState.ll.x = clipRect.origin.x;
            epsState.ll.y = clipRect.origin.y;
            epsState.ur.x = clipRect.origin.x + clipRect.size.width;
            epsState.ur.y = clipRect.origin.y + clipRect.size.height;
            epsState.setBounds = 0;
        }
        for (i=(int)[layerList count]-1 ; i >=0  ; i--)
        {   LayerObject	*lObj = [layerList objectAtIndex:i];

            if ([lObj type] == LAYER_CLIPPING || ![lObj state]) // visible - ????????????????????????
                continue;
            {   int	j, cnt = [[lObj list] count];

// PageBoundingBox
//        grStr = [grStr stringByAppendingFormat:@"%%Page: 0 1\n"]; // BeginPageSetup EndPageSetup PageTrailer
                for (j=0; j<cnt; j++)
                {   id	g = [[lObj list] objectAtIndex:j];

                    if ( ![g isKindOfClass:[VGroup class]] && ![[g color] isEqual:epsState.color] )
                    {
                        if ( [[[g color] colorSpaceName] isEqual:@"NSCalibratedWhiteColorSpace"] )
                            grStr = [grStr stringByAppendingFormat:@"%.2f setgray\n", [[g color] whiteComponent]];
                        else
                            grStr = [grStr stringByAppendingFormat:@"%.2f %.2f %.2f setrgbcolor\n",
                                [[g color] redComponent], [[g color] greenComponent], [[g color] blueComponent]];
                        epsState.color = [g color];
                    }
                    if ( ![g isKindOfClass:[VGroup class]] && epsState.width != [g width] )
                    {   grStr = [grStr stringByAppendingFormat:@"%.2f setlinewidth\n", [g width]];
                        epsState.width = [g width];
                        if ( epsState.maxW < epsState.width ) epsState.maxW = epsState.width;
                    }

                    if (  [g isKindOfClass:[VLine class]] )
                        grStr = [grStr stringByAppendingString:[self epsLine:g :&epsState]]; // move if possible and lineto
                    else if (  [g isKindOfClass:[VCurve class]] )
                        grStr = [grStr stringByAppendingString:[self epsCurve:(VCurve*)g :&epsState]];
                    else if (  [g isKindOfClass:[VRectangle class]] )
                        grStr = [grStr stringByAppendingString:[self epsRectangle:g :&epsState]];
                    else if (  [g isKindOfClass:[VArc class]] )
                        grStr = [grStr stringByAppendingString:[self epsArc:g :&epsState]];
                    else if (  [g isKindOfClass:[VPath class]] )
                        grStr = [grStr stringByAppendingString:[self epsPath:g :&epsState]];
                    else if (  [g isKindOfClass:[VGroup class]] )
                        grStr = [grStr stringByAppendingString:[self epsGroup:g :&epsState]];
                    else if (  [g isKindOfClass:[VImage class]] )
                        grStr = [grStr stringByAppendingString:[self epsImage:g :&epsState]];
                    else if (  [g isKindOfClass:[VText class]] )
                        grStr = [grStr stringByAppendingString:[self epsVText:(VText*)g :&epsState]];
                }
            }
        }
        if ( !epsState.noPoint && !epsState.fill )
            grStr = [grStr stringByAppendingFormat:@"stroke\n"];
        else if ( !epsState.noPoint && epsState.fill )
            grStr = [grStr stringByAppendingFormat:@"eofill\n"];

        epsState.ll.x -= epsState.maxW/2.0; epsState.ll.y -= epsState.maxW/2.0;
        epsState.ur.x += epsState.maxW/2.0; epsState.ur.y += epsState.maxW/2.0;

        // header
        epsStr = [NSString stringWithFormat:@"%%!PS-Adobe-3.0 EPSF-3.0\n"];
        epsStr = [epsStr stringByAppendingFormat:@"%%%%Creator: Cenon\n"];
        epsStr = [epsStr stringByAppendingFormat:@"%%%%Copyright 2003 by vhf interservice - all rights reserved\n"];
        epsStr = [epsStr stringByAppendingFormat:@"%%%%CreationDate: %@\n", [[NSCalendarDate date] descriptionWithCalendarFormat:@"%Y-%m-%d"]];
        epsStr = [epsStr stringByAppendingFormat:@"%%%%BoundingBox: %.0f %.0f %.0f %.0f\n", epsState.ll.x, epsState.ll.y, epsState.ll.x+Diff(epsState.ll.x, epsState.ur.x), epsState.ll.y+Diff(epsState.ll.y, epsState.ur.y)];
        epsStr = [epsStr stringByAppendingFormat:@"%%%%Pages: 0 1\n"];
        epsStr = [epsStr stringByAppendingFormat:@"%%%%EndComments\n"];

        // graphics
        epsStr = [epsStr stringByAppendingString:grStr];

        // Trailer
        epsStr = [epsStr stringByAppendingFormat:@"showpage\n"];
        epsStr = [epsStr stringByAppendingFormat:@"%%%%Trailer\n"];
/*%DocumentFonts: Helvetica-Light
%+ Helvetica-Bold
%+ Helvetica*/

        savedOk = [epsStr writeToFile:filename atomically:YES];
    }
    //else
    //    NSRunAlertPanel(SAVE_TITLE, DIR_NOT_WRITABLE, nil, nil, nil);
#endif

    /* restore backup */
    if (!savedOk)
    {
        [fileManager removeFileAtPath:filename handler:nil];	// remove what we just started to write
        [fileManager movePath:backupFilename toPath:filename handler:nil];	// restore backup
        NSRunAlertPanel(SAVE_TITLE, CANT_SAVE, nil, nil, nil);
    }
    else
    {
        if (Prefs_RemoveBackups)
            [fileManager removeFileAtPath:backupFilename handler:nil];
    }
    return YES;
}

- (void)dealloc
{
    [super dealloc];
}

@end
