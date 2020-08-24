/* DXFExportSub.m
 * subclass of DXFExport
 *
 * Copyright (C) 2002-2010 by vhf interservice GmbH
 * Author:   Ilonka Fleischmann
 *
 * created:  2002-04-25
 * modified: 2010-04-03 (-exportArc: export -360 angle correctly (not 0))
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
#include <VHFShared/VHFStringAdditions.h> // stringByReplacing -> eps export
#include "App.h"
#include "DXFExportSub.h"
#include "Graphics.h"
#include "messages.h"
#include "locations.h"
#include "PreferencesMacros.h"

//#define RES 1000

@interface DXFExportSub(PrivateMethods)
- (void)exportPolyLine:(VPolyLine*)g;
- (void)exportRectangle:(VRectangle*)g;
- (void)exportArc:(VArc*)g;
- (void)exportCurve:(VCurve*)g;
- (void)exportText:(VText*)g;
- (void)exportPath:(VPath*)path;
- (void)exportGroup:(VGroup*)group;
@end

@implementation DXFExportSub

- (void)setDocumentView:view
{
    docView = view;
}

- (void)exportPolyLine:(VPolyLine*)g
{   int	i, cnt = [(VPolyLine*)g numPoints];
    int	closed = ([g filled]) ? (1) : (0); // ([g filled]) ? (9) : (8); // 8 open 9 closed - only lines

    [self writePolyLineMode:YES :[g width] :closed];

    for (i=0; i<cnt-1; i++)
        [self writePolyLineVertex:[g pointWithNum:i]];
    if (!closed) // if (closed == 8) // open -> draw last point
        [self writePolyLineVertex:[g pointWithNum:cnt-1]];

    [self writePolyLineMode:NO :[g width] :closed];
}

- (void)exportRectangle:(VRectangle*)g
{   NSAutoreleasePool	*pool = [NSAutoreleasePool new];
    VPath	*path = [g pathRepresentation];

    [path setWidth:[g width]];
    [self exportPath:path];
    [pool release];
}

- (void)exportArc:(VArc*)g
{
    if (Abs([g angle]) != 360.0 || ![g filled])
    {   float	angle = [g angle], begAngle = [g begAngle], endAngle;

        // we need positive angles ! (ccw) 0 < bA,eA < 360 bA != eA
        if (begAngle <   0.0) begAngle += 360.0;
        if (begAngle > 360.0) begAngle -= 360.0;
        endAngle = begAngle + angle;
        if (endAngle <   0.0) endAngle += 360.0;
        if ( angle <= -360.0 && Diff(endAngle, begAngle) < TOLERANCE )
            endAngle = 360.0;   // special case for negative cicle
        if (endAngle > 360.0) endAngle -= 360.0;
        if (angle < 0.0)
            [self writeArc:[g center] :[g radius] :endAngle :begAngle :[g width]];
        else
            [self writeArc:[g center] :[g radius] :begAngle :endAngle :[g width]];
    }
    else
        [self writeCircle:[g center] :[g radius] :[g width]]; // CIRCLE
}

- (void)exportCurve:(VCurve*)g
{   NSAutoreleasePool	*pool = [NSAutoreleasePool new];
    VPath	*path;

    if ( (path = [g flattenedObjectWithFlatness:0.1]) )
    {   //int	i, cnt = [[path list] count];

        [path setWidth:[g width]];
        [self exportPath:path];
/*
        for (i=0; i<cnt; i++)
        {   id	line = [[path list] objectAtIndex:i];

            [self writeLine:[line pointWithNum:0] :[line pointWithNum:1]];
        }
*/
    }
    [pool release];
}

- (void)exportText:(VText*)g
{   NSAutoreleasePool	*pool = [NSAutoreleasePool new];
    id			text = [g pathRepresentation];

    if (Prefs_ExportFlattenText)
    {   if (text && [text isKindOfClass:[VPath class]])
           [self exportPath:text];
        else if (text /*&& [text isKindOfClass:[VGroup class]]*/)
            [self exportGroup:text];
    }
    else
    {	//int		mirror = 0; // 0-not 2-x 4-y 6-x&y
        float		lCnt = 0.0, degree = [g rotAngle], iangle = [[g font] italicAngle]; // cw to x axis
        float		pS=[[g font] pointSize], desc=[[g font] descender], lH=[g lineHeight];
        NSString	*str = [g string];
        NSRect		bounds = [g textBox], fbounds = [[g font] boundingRectForFont]; // bounds
        NSPoint		o = bounds.origin; // groundline left
        NSScanner	*scanner = [NSScanner scannerWithString:[g string]];
        //float	lS = [g lineSpacing]; // pS=[[g font] pointSize];

        // jede zeile einzeln max 256 asci zeichen
        while (![scanner isAtEnd])
        {
            [scanner scanUpToString:@"\n" intoString:&str];

            // we start at top - capHeight - half space between lineheight and ptSize of font
            o = bounds.origin;
            o.y = o.y + bounds.size.height;
            o.y = o.y - (fbounds.size.height + desc); // - (lH - pS)/2.0;
            o.y -= lCnt*lH; // + lCnt*lS + lS/2.0
            [self writeText:o :pS*2.0/3.0 :degree :iangle :str :bounds.size.width];
            lCnt += 1.0;
        }
    }
    [pool release];
}

- (void)exportPath:(VPath*)path
{   int		i, cnt=[[path list] count];
    int		closed = ([path filled]) ? (1) : (0); // lines and arcsegments
    int		begIx=0, endIx=0;


    for (i=0; i<cnt; i++)
    {   id	g = [[path list] objectAtIndex:i];


        if ( !i || i>endIx ) // each subpath itself !
        {
            if (i) // close polyline
                [self writePolyLineMode:NO :[path width] :closed];
            [self writePolyLineMode:YES :[path width] :closed];

            begIx = i;
            //endIx = [self getLastObjectOfSubPath:begIx];
            endIx = [path getLastObjectOfSubPath:begIx]; //  tolerance:TOLERANCE
        }

        // end point is start of next graphic ! - but open path
        if ( [g isKindOfClass:[VLine class]] )
        {
            [self writeLineVertex:[g pointWithNum:0]]; // :[g width]
            if (!closed && i == endIx) // must draw last point
                [self writeLineVertex:[g pointWithNum:1]]; // :[g width]
        }
        else if ( [g isKindOfClass:[VPolyLine class]] )
        {   int	j, gCnt = [(VPolyLine*)g numPoints];

            for (j=0; j<gCnt-1; j++)
                [self writeLineVertex:[g pointWithNum:j]];
            if (!closed && i == endIx) // must draw last point
                [self writeLineVertex:[g pointWithNum:gCnt-1]]; // :[g width]
        }
        else if (  [g isKindOfClass:[VRectangle class]] )
        {   NSAutoreleasePool	*pool = [NSAutoreleasePool new];
            VPath	*p;

            if ( (p = [g pathRepresentation]) )
            {   int	j, gCnt = [[p list] count];

                for (j=0; j<gCnt; j++)
                {   id	gg = [[p list] objectAtIndex:j];

                    if ( [gg isKindOfClass:[VLine class]] )
                    {
                        [self writeLineVertex:[gg pointWithNum:0]]; // :[g width]
                        if (!closed && i == endIx && j == gCnt-1) // must draw last point
                            [self writeLineVertex:[gg pointWithNum:1]]; // :[g width]
                    }
                    else if (  [gg isKindOfClass:[VArc class]] )
                    {   NSPoint	s, e, center, m, *pts;
                        float	h, a, angle, l, radius;
                        VLine	*line = [VLine line];

                        [gg getCenter:&center start:&s angle:&angle];
                        radius = [gg radius];
                        e = [gg pointWithNum:MAXINT]; // end

                        l = sqrt(SqrDistPoints(s, e));
                        LineMiddlePoint(s, e, m);
                        [line setVertices:center :m];
                        [line setLength:radius+5.0];
                        if (![gg getIntersections:&pts with:line])
                            continue;
                        h = sqrt(SqrDistPoints(m, pts[0]));
                        a = 2.0*h / l;
                        [self writeArcVertex:s :a :center :radius]; // :t :[g width]
                        if (/*!closed &&*/ i == endIx && j == gCnt-1)
                            [self writeLineVertex:e]; // :[g width]
                        free(pts);
                    }
                }
            }
            [pool release];
        }
        else if (  [g isKindOfClass:[VArc class]] )
        {
            if (Abs([g angle]) > 180.0) // we need two arcs !
            {   int		j;
                NSPoint		pts[2]; // array ?
                NSMutableArray	*arcArray;

                // splitt arc at middle point
                pts[0] = [(VArc*)g pointAt:0.5];
                arcArray = [g getListOfObjectsSplittedFrom:pts :1];
                for (j=0; j<2; j++)
                {   VArc	*arc = [arcArray objectAtIndex:j];
                    NSPoint	s, e, center;
                    float	h, a, angle, l, radius;

                    [arc getCenter:&center start:&s angle:&angle];
                    radius = [arc radius];
                    e = [arc pointWithNum:MAXINT]; // end
                    l = sqrt(SqrDistPoints(s, e));
                    if (Diff(Abs(angle), 180.0) < TOLERANCE)
                        h = radius;
                    else
                    {   VLine	*line = [VLine line];
                        NSPoint	m, *pts;

                        LineMiddlePoint(s, e, m);
                        [line setVertices:center :m];
                        [line setLength:radius+5.0];
                        if (![arc getIntersections:&pts with:line])
                            continue;
                        h = sqrt(SqrDistPoints(m, pts[0]));
                        free(pts);
                    }
                    a = 2.0*h / l;
                    if (angle < 0.0) a = -a;
                    [self writeArcVertex:s :a :center :radius]; // :t :[g width]
                    if (/*!closed &&*/ i == endIx && j == 1)
                        [self writeLineVertex:e]; // :[g width]
                }
            }
            else
            {   NSPoint	s, e, center;
                float	h, a, angle, l, radius;

                [g getCenter:&center start:&s angle:&angle];
                radius = [g radius];
                e = [g pointWithNum:MAXINT]; // end
                l = sqrt(SqrDistPoints(s, e));
                if (Diff(Abs(angle), 180.0) < TOLERANCE)
                    h = radius;
                else
                {   VLine	*line = [VLine line];
                    NSPoint	m, *pts;

                    LineMiddlePoint(s, e, m);
                    [line setVertices:center :m];
                    [line setLength:radius+5.0];
                    if (![g getIntersections:&pts with:line])
                        continue;
                    h = sqrt(SqrDistPoints(m, pts[0]));
                    free(pts);
                }
                a = 2.0*h / l;
                if (angle < 0.0) a = -a;
                [self writeArcVertex:s :a :center :radius]; // :t :[g width]
                if (/*!closed &&*/ i == endIx)
                    [self writeLineVertex:e]; // :[g width]
            }
        }
        else if (  [g isKindOfClass:[VCurve class]] )
        {   NSAutoreleasePool	*pool = [NSAutoreleasePool new];
            VPath		*p;

            if ( (p = [g flattenedObjectWithFlatness:0.1]) )
            {   int	j, gCnt = [[p list] count];

                for (j=0; j<gCnt; j++)
                {   id	line = [[p list] objectAtIndex:j];

                    [self writeLineVertex:[line pointWithNum:0]];
                    if (!closed && i == endIx && j == gCnt-1) // must draw last point
                        [self writeLineVertex:[line pointWithNum:1]]; // :[g width]
                }
            }
            [pool release];
        }
        else NSLog(@"DXF exportPath g type not implemented\n");
    }
    [self writePolyLineMode:NO :[path width] :closed]; // close last path
}

- (void)exportGroup:(VGroup*)group
{   int		i, cnt=[[group list] count];

    for (i=0; i<cnt; i++)
    {   VGraphic    *g = [[group list] objectAtIndex:i];

        if ( [g isKindOfClass:[VLine class]] )
            [self writeLine:[g pointWithNum:0] :[g pointWithNum:1] :[g width]];
        else if ( [g isKindOfClass:[VPolyLine class]] )
            [self exportPolyLine:(VPolyLine*)g];
        else if (  [g isKindOfClass:[VRectangle class]] )
            [self exportRectangle:(VRectangle*)g];
        else if (  [g isKindOfClass:[VArc class]] )
            [self exportArc:(VArc*)g];
        else if (  [g isKindOfClass:[VCurve class]] )
            [self exportCurve:(VCurve*)g];
        else if (  [g isKindOfClass:[VPath class]] )
            [self exportPath:(VPath*)g];
        else if (  [g isKindOfClass:[VGroup class]] )
            [self exportGroup:(VGroup*)g];
        else
            NSLog(@"DXF exportGroup g type not implemented\n");
    }
}


- (BOOL)exportToFile:(NSString*)filename
{   int			lCnt;
    BOOL		savedOk = NO;
    NSString		*backupFilename;
    NSFileManager	*fileManager = [NSFileManager defaultManager];

    backupFilename = [[[filename stringByDeletingPathExtension] stringByAppendingString:@"~"]
                      stringByAppendingPathExtension:DXF_EXT];
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

    //else if ( isDirectory && [fileManager createDirectoryAtPath:filename attributes:nil] )
    //fileDirectory = [filename stringByDeletingLastPathComponent];
    /* save */
//    if ([fileManager isWritableFileAtPath:filename])
    {   NSArray *layerList = [docView layerList];
        int		i;

        [self setRes:Prefs_DXFRes];

// 72 25400 div 72 25400 div scale\n

        lCnt = [layerList count];
        //for (i=(int)[layerList count]-1 ; i >=0  ; i--)
        for (i=0 ; i < lCnt  ; i++)
        {   LayerObject	*lObj = [layerList objectAtIndex:i];

            if (([lObj type] == LAYER_CLIPPING || ![lObj state]))
                continue;
            {   int	j, cnt = [[lObj list] count];

                for (j=0; j<cnt; j++)
                {   VGraphic    *g = [[lObj list] objectAtIndex:j];
                    NSColor     *col = [g color];

                    if ([g respondsToSelector:@selector(fillColor)] && [g width] == 0.0)
                     	col = [(VPath*)g fillColor];

                    if (!j)
                    {   int	attribute = 64; // default

                        /* layer attribute: default 64; 1 not editable; 5 not editable and not visible (4+1) */
                        attribute = (![lObj state]) ? (5) : ((![lObj editable]) ? (1) : (64));
                        [self addLayer:[lObj string] :col :(int)attribute];
                    }
                    [self setCurColor:col];

                    if ( [g isKindOfClass:[VLine class]] )
                        [self writeLine:[g pointWithNum:0] :[g pointWithNum:1] :[g width]];
                    else if ( [g isKindOfClass:[VPolyLine class]] )
                        [self exportPolyLine:(VPolyLine*)g];
                    else if (  [g isKindOfClass:[VRectangle class]] )
                        [self exportRectangle:(VRectangle*)g];
                    else if (  [g isKindOfClass:[VArc class]] )
                        [self exportArc:(VArc*)g];
                    else if (  [g isKindOfClass:[VCurve class]] )
                        [self exportCurve:(VCurve*)g];
                    else if (  [g isKindOfClass:[VPath class]] )
                        [self exportPath:(VPath*)g];
                    else if (  [g isKindOfClass:[VGroup class]] )
                        [self exportGroup:(VGroup*)g];
                    else if (  [g isKindOfClass:[VText class]] )
                        [self exportText:(VText*)g];
                    else NSLog(@"DXF exportToFile g type not implemented\n");
                }
            }
        }
        savedOk = [self saveToFile:filename];
    }
//    else
//        NSRunAlertPanel(SAVE_TITLE, DIR_NOT_WRITABLE, nil, nil, nil);

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
