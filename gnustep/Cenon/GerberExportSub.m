/* GerberExportSub.m
 * Sub class of Gerber export
 *
 * Copyright (C) 2002-2012 by vhf interservice GmbH
 * Author:   Ilonka Fleischmann
 *
 * created:  2002-04-25
 * modified: 2008-12-02 (fix: export paths stacked on each other)
 *           2008-06-21 (fixes)
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
#include "GerberExportSub.h"
#include "Graphics.h"
#include "messages.h"
#include "locations.h"
#include "PreferencesMacros.h"

//#define RES 1000

@interface GerberExportSub(PrivateMethods)
- (void)exportPolyLine:(VPolyLine*)g;
- (void)exportRectangle:(VRectangle*)g;
- (void)exportArc:(VArc*)g;
- (void)exportCurve:(VCurve*)g;
- (void)exportText:(VText*)g;
- (void)exportPath:(VPath*)path;
- (void)exportGroup:(VGroup*)group;
@end

@implementation GerberExportSub

- (void)setDocumentView:view
{
    docView = view;
}

- (void)exportPolyLine:(VPolyLine*)g
{   int		i, cnt = [(VPolyLine*)g numPoints];

    // start polygon mode G36*
    if ([g filled] && cnt > 3)
        [self writePolygonMode:YES];

    for (i=0; i<cnt-1; i++)
        [self writeLine:[g pointWithNum:i] :[g pointWithNum:i+1]];

    // end polygon mode G37*
    if ([g filled] && cnt > 3)
        [self writePolygonMode:NO];
}

- (void)exportRectangle:(VRectangle*)g
{
    if ([g radius] || ![g filled])
        [self exportPath:[g pathRepresentation]];
    else
    {   NSPoint	origin, size, center;
        [g getVertices:&origin :&size];
        center.x = origin.x + size.x/2.0;
        center.y = origin.y + size.y/2.0;
        [self writeRectangle:center]; // flash to center
    }
}

- (void)exportArc:(VArc*)g
{
    if (Abs([g angle]) != 360.0 || ![g filled])
    {   float	angle;
        NSPoint	center, start, end;
        BOOL	ccw = 0; // cw -> G02

        [g getCenter:&center start:&start angle:&angle];
        end = [g pointWithNum:MAXINT]; // end

        if (angle > 0.0) // ccw -> G03
            ccw = 1;

        [self writeArc:center :start :end :ccw];
    }
    else
        [self writeCircle:[g center]]; // flash
}

- (void)exportCurve:(VCurve*)g
{   NSAutoreleasePool	*pool = [NSAutoreleasePool new];
    VPath		*path;

    if ( (path = [g flattenedObjectWithFlatness:0.1]) )
    {   int	i, cnt = [[path list] count];

        for (i=0; i<cnt; i++)
        {   id	line = [[path list] objectAtIndex:i];

            [self writeLine:[line pointWithNum:0] :[line pointWithNum:1]];
        }
    }
    [pool release];
}

- (void)exportText:(VText*)g
{   NSAutoreleasePool	*pool = [NSAutoreleasePool new];
    id			text = [g pathRepresentation];

    if (text && [text isKindOfClass:[VPath class]])
        [self exportPath:text];
    else if (text /*&& [text isKindOfClass:[VGroup class]]*/)
        [self exportGroup:text];
    [pool release];
}

- (void)exportPath:(VPath*)path
{   int			i, j, k, b, cnt=[[path list] count], subPathsCnt = 0, subPathsInCnt = 0;
    NSMutableArray	*subpaths = [NSMutableArray array], *subpathsIns = [NSMutableArray array];
    BOOL		lastDrawnIsClear = NO;

    /* sort subPaths of path in arrays */
    for ( i=0; i<cnt; i=j+1 )
    {	VPath		*pth = [VPath path];

        j = [path getLastObjectOfSubPath:i];
        subPathsCnt++;

        [pth setFilled:YES];
        for ( k=i; k < j+1; k++ )
            [[pth list] addObject:[[path list] objectAtIndex:k]];
        [subpaths addObject:pth];
    }
    /* polygons inside must be clear(white) outside must be dark(black)*/
    if (subPathsCnt > 1 && [path filled])
    {
        /* count how many times each subpath is inside all others */
        for ( i=0; i<subPathsCnt; i++ )
        {   id		gr = [[[subpaths objectAtIndex:i] list] objectAtIndex:0]; // first gr in subpath
            NSPoint	pt = [gr pointAt:0.4];
            int		inside = 0;

            for ( j=0; j< subPathsCnt; j++ )
            {	VPath	*sp = [subpaths objectAtIndex:j];

                if ( i == j )
                    continue;
                if ( [sp isPointInside:pt] )
                    inside++;
            }
            [subpathsIns addObject:[NSNumber numberWithInt:inside]];
            subPathsInCnt++;
        }
    }

    b = 0;
    while ( b >= 0 )
    {   BOOL	drawed = NO, somethingToDraw = NO;

        for ( j=0; j<subPathsCnt; j++ )
        {   int	inside;

            inside = (subPathsInCnt > 1) ? [[subpathsIns objectAtIndex:j] intValue] : 0;
            /* !b - we draw only the black one which have no realy no inside ; b - we draw only the white one */
            if ( (inside == b) )
            {   somethingToDraw  = YES;
                break;
            }
        }

        if (!Even(b) && [path filled] && b && subPathsCnt > b && somethingToDraw)
        {
            [self writeLayerPolarityMode:YES]; // clear
            lastDrawnIsClear = YES;
        }
        else if (Even(b) && [path filled] && b && subPathsCnt > b && somethingToDraw)
        {   [self writeLayerPolarityMode:NO]; // dark
            lastDrawnIsClear = NO;
        }

        for ( j=0; j<subPathsCnt; j++ )
        {   VPath	*sp = [subpaths objectAtIndex:j];
            int		cnt = [[sp list] count], inside;

            inside = (subPathsInCnt > 1) ? [[subpathsIns objectAtIndex:j] intValue] : 0;
            /* !b - we draw only the black one which have no realy no inside ; b - we draw only the white one */
            if ( !(inside == b) )
                continue;

            drawed = YES;
            // start polygon mode G36*
            if ([path filled])
                [self writePolygonMode:YES];

            for (i=0; i<cnt; i++)
            {   id	g = [[sp list] objectAtIndex:i];

                if ( [g isKindOfClass:[VLine class]] )
                    [self writeLine:[g pointWithNum:0] :[g pointWithNum:1]];
                else if ( [g isKindOfClass:[VPolyLine class]] )
                    [self exportPolyLine:g];
                else if (  [g isKindOfClass:[VRectangle class]] )
                    [self exportRectangle:g];
                else if (  [g isKindOfClass:[VArc class]] )
                    [self exportArc:g];
                else if (  [g isKindOfClass:[VPath class]] )
                    [self exportPath:g];
                else if (  [g isKindOfClass:[VCurve class]] )
                    [self exportCurve:g];
                else NSLog(@"Gerber exportPath g type not implemented\n");
            }
            // end polygon mode G37*
            if ([path filled])
                [self writePolygonMode:NO];
        }
        if ( drawed == NO )
            break;
        b++;
    }
    if ([path filled] && lastDrawnIsClear == YES)
        [self writeLayerPolarityMode:NO]; // set LayerPolarity back to dark
}

- (void)exportGroup:(VGroup*)group
{   int		j, k, cnt=[[group list] count];
    int		insideIs[cnt], insideCnt = 0, polygonIs[cnt], polyCnt = 0, pathsIns[cnt];
    NSRect	polyBounds[cnt];

    /* get all bounds of polygons and */
    /* get all indexes of polygons */
    for (j=0; j<cnt; j++)
    {   VGraphic    *g = [[group list] objectAtIndex:j];

        if ([g isKindOfClass:[VPath class]])
        {
            polygonIs[polyCnt] = j;
            polyBounds[polyCnt++] = [g bounds];
        }
    }

    if (polyCnt > 1)
    {
        /* count how many times each path is inside all others */
        for (j=0; j < polyCnt; j++)
        {   NSArray     *list = [[[group list] objectAtIndex:polygonIs[j]] list];
            VGraphic    *gr;
            NSPoint     pt;
            int         inside = 0;

            if (![list count])
                continue;   // empty group
            gr = [list objectAtIndex:0];
            pt = [gr pointWithNum:0];
            for (k=0; k < polyCnt; k++)
            {   NSRect	kbounds = polyBounds[k];

                if ( j == k )
                    continue;
                if ( NSPointInRect(pt, kbounds) )
                    inside++;
            }
            pathsIns[j] = inside;
        }
    }

    /* get all indexes of graphics inside/intersect bounds of polygons */
    for (j=0; j<cnt; j++)
    {   id	g = [[group list] objectAtIndex:j];

        if (![g isKindOfClass:[VPath class]])
        {   NSRect	bounds = [g bounds];

            for (k=0; k<polyCnt; k++)
            {
                if ( vhfIntersectsRect(polyBounds[k], bounds) )
                {   insideIs[insideCnt++] = j;
                    break;
                }
            }
        }
    }

    /* draw graphics, but polygons, outside bounds of polygons */
    /* draw polygons from outside to inside */
    /* draw graphics inside bounds of polygons */
    for (k=0; k < 3; k++)
    {
        /* draw polygons from outside to inside */
        if ( k == 1 )
        {   int	b = 0;

            while ( b >= 0 )
            {   BOOL	drawed = NO;

                for (j=0; j<polyCnt; j++)
                {   int	inside;
                    VPath	*sp = [[group list] objectAtIndex:polygonIs[j]];

                    inside = (polyCnt > 1) ? pathsIns[j] : 0;
                    /* b == inside; we draw from outside to inside */
                    if ( !(inside == b) )
                        continue;

                    drawed = YES;
                    [self exportPath:sp];
                }
                if (drawed == NO)
                    break;
                b++;
            }
            continue;
        }
        for (j=0; j<cnt; j++)
        {   VGraphic    *g = [[group list] objectAtIndex:j];
            float       w = [g width];

            if ( !(!k && ![g isKindOfClass:[VPath class]] && !valueInArray(j, insideIs, insideCnt)) &&
                 /*!(k == 1 && [g isKindOfClass:[VPath class]]) &&*/
                 !(k == 2 && ![g isKindOfClass:[VPath class]] && valueInArray(j, insideIs, insideCnt)) )
                continue;

            if ([g isKindOfClass:[VRectangle class]] && [g filled] && ![(VRectangle*)g radius])
            {   NSSize	rsize = [(VRectangle*)g size];

                [self writeRectangleTool:w+rsize.width :w+rsize.height];
            }
            else if (w ||
                     ([g isKindOfClass:[VArc class]] && Abs([(VArc*)g angle]) == 360.0 && [(VArc*)g filled]))
            {
                if ([g isKindOfClass:[VArc class]] && Abs([(VArc*)g angle]) == 360.0 && [(VArc*)g filled])
                    w += [(VArc*)g radius]*2.0;
                [self writeCircleTool:w];
            }

            if ( [g isKindOfClass:[VLine class]] )
                [self writeLine:[g pointWithNum:0] :[g pointWithNum:1]];
            else if ( [g isKindOfClass:[VPolyLine class]] )
                [self exportPolyLine:(VPolyLine*)g];
            else if (  [g isKindOfClass:[VRectangle class]] )
                [self exportRectangle:(VRectangle*)g];
            else if (  [g isKindOfClass:[VArc class]] )
                [self exportArc:(VArc*)g];
            else if (  [g isKindOfClass:[VCurve class]] )
                [self exportCurve:(VCurve*)g];
            else if (  [g isKindOfClass:[VPath class]] )
                NSLog(@"GerberExportSub.m: exportToFile, exportPath\n"); /*[self exportPath:(VPath*)g]*/
            else if (  [g isKindOfClass:[VGroup class]] )
                [self exportGroup:(VGroup*)g];
            else if (  [g isKindOfClass:[VText class]] )
                 [self exportText:(VText*)g];
        }
    }
/*
 for (i=0; i<cnt; i++)
 {   id	g = [[group list] objectAtIndex:i];
     float	w = [g width];

     if ([g isKindOfClass:[VRectangle class]] && [g filled] && ![(VRectangle*)g radius])
     {   NSSize	rsize = [(VRectangle*)g size];

         [self writeRectangleTool:w+rsize.width :w+rsize.height];
     }
     else if (w ||
              ([g isKindOfClass:[VArc class]] && Abs([(VArc*)g angle]) == 360.0 && [(VArc*)g filled]))
     {
         if ([g isKindOfClass:[VArc class]] && Abs([(VArc*)g angle]) == 360.0 && [(VArc*)g filled])
             w += [(VArc*)g radius]*2.0;
         [self writeCircleTool:w];
     }

     if ( [g isKindOfClass:[VLine class]] )
         [self writeLine:[g pointWithNum:0] :[g pointWithNum:1]];
     else if ( [g isKindOfClass:[VPolyLine class]] )
         [self exportPolyLine:g];
     else if (  [g isKindOfClass:[VRectangle class]] )
         [self exportRectangle:g];
     else if (  [g isKindOfClass:[VArc class]] )
         [self exportArc:g];
     else if (  [g isKindOfClass:[VCurve class]] )
         [self exportCurve:g];
     else if (  [g isKindOfClass:[VPath class]] )
         [self exportPath:g];
     else if (  [g isKindOfClass:[VGroup class]] )
         [self exportGroup:g];
     else NSLog(@"gerber exportGroup g type not implemented\n");
 }
 */
}


- (BOOL)exportToFile:(NSString*)filename
{   BOOL		savedOk = NO;
    NSString		*backupFilename;
    NSFileManager	*fileManager = [NSFileManager defaultManager];

    backupFilename = [[[filename stringByDeletingPathExtension] stringByAppendingString:@"~"]
                      stringByAppendingPathExtension:GERBER_EXT];
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
    {   NSArray         *layerList = [docView layerList];
        int             i, lcnt = [layerList count];
        NSMutableArray	*gList = [NSMutableArray array];


// 72 25400 div 72 25400 div scale\n

        /* first clip rect */
        for (i=0 ; i < lcnt  ; i++)
        {   LayerObject	*lObj = [layerList objectAtIndex:i];

            if ([lObj type] == LAYER_CLIPPING || ![lObj state]) // not visible - continue
                continue;

            /* add all visible objects to gList */
            {   int	j, cnt = [[lObj list] count];

                for (j=0; j<cnt; j++)
                    [gList addObject:[[lObj list] objectAtIndex:j]];
            }
        }
        /* export gList */
        {   int	j, k, cnt = [gList count], maxInside = 0;
            int	insideIs[cnt], insideCnt = 0, polygonIs[cnt], polyCnt = 0, pathsIns[cnt];
            NSRect	polyBounds[cnt];

            /* get all bounds of polygons and */
            /* get all indexes of polygons */
            for (j=0; j<cnt; j++)
            {   id	g = [gList objectAtIndex:j];

                if ([g isKindOfClass:[VPath class]])
                {
                    polygonIs[polyCnt] = j;
                    polyBounds[polyCnt++] = [g bounds];
                }
            }

            if (polyCnt > 1)
            {
                /* count how many times each path is inside all others */
                for (j=0; j < polyCnt; j++)
                {   id	gr = [[[gList objectAtIndex:polygonIs[j]] list] objectAtIndex:0];
                    NSPoint	pt = [gr pointWithNum:0];
                    int	inside = 0;

                    for (k=0; k < polyCnt; k++)
                    {   NSRect	kbounds = polyBounds[k];

                        if ( j == k )
                            continue;
                        if ( NSPointInRect(pt, kbounds) )
                            inside++;
                    }
                    if ( inside > maxInside )
                        maxInside = inside;
                    pathsIns[j] = inside;
                }
            }

            /* get all indexes of graphics inside/intersect bounds of polygons */
            for (j=0; j<cnt; j++)
            {   id	g = [gList objectAtIndex:j];

                if (![g isKindOfClass:[VPath class]])
                {   NSRect	bounds = [g bounds];

                    for (k=0; k<polyCnt; k++)
                    {
                        if ( vhfIntersectsRect(polyBounds[k], bounds) )
                        {   insideIs[insideCnt++] = j;
                            break;
                        }
                    }
                }
            }

            /* draw graphics, but polygons, outside bounds of polygons */
            /* draw polygons from outside to inside */
            /* draw graphics inside bounds of polygons */
            for (k=0; k < 3; k++)
            {
                /* draw polygons from outside to inside */
                if ( k == 1 )
                {   int	b = 0;

                    while ( b >= 0 )
                    {   BOOL	drawed = NO;

                        for (j=0; j<polyCnt; j++)
                        {   int	inside;
                            VPath	*sp = [gList objectAtIndex:polygonIs[j]];

                            inside = (polyCnt > 1) ? pathsIns[j] : 0;
                            /* b == inside; we draw from outside to inside */
                            if ( !(inside == b) )
                                continue;

                            drawed = YES;
                            [self exportPath:sp];
                        }
                        if ( b >= maxInside ) // if (drawed == NO)
                            break;
                        b++;
                    }
                    continue;
                }
                for (j=0; j<cnt; j++)
                {   VGraphic    *g = [gList objectAtIndex:j];
                    float       w = [g width];

                    if ( !(!k && ![g isKindOfClass:[VPath class]] && !valueInArray(j, insideIs, insideCnt)) &&
                         /*!(k == 1 && [g isKindOfClass:[VPath class]]) &&*/
                         !(k == 2 && ![g isKindOfClass:[VPath class]] && valueInArray(j, insideIs, insideCnt)) )
                        continue;

                    if ([g isKindOfClass:[VRectangle class]] && [g filled] && ![(VRectangle*)g radius])
                    {   NSSize	rsize = [(VRectangle*)g size];

                        [self writeRectangleTool:w+rsize.width :w+rsize.height];
                    }
                    else if (w ||
                             ([g isKindOfClass:[VArc class]] && Abs([(VArc*)g angle]) == 360.0 && [(VArc*)g filled]))
                    {
                        if ([g isKindOfClass:[VArc class]] && Abs([(VArc*)g angle]) == 360.0 && [(VArc*)g filled])
                            w += [(VArc*)g radius]*2.0;
                        [self writeCircleTool:w];
                    }

                    if ( [g isKindOfClass:[VLine class]] )
                        [self writeLine:[g pointWithNum:0] :[g pointWithNum:1]];
                    else if ( [g isKindOfClass:[VPolyLine class]] )
                        [self exportPolyLine:(VPolyLine*)g];
                    else if (  [g isKindOfClass:[VRectangle class]] )
                        [self exportRectangle:(VRectangle*)g];
                    else if (  [g isKindOfClass:[VArc class]] )
                        [self exportArc:(VArc*)g];
                    else if (  [g isKindOfClass:[VCurve class]] )
                        [self exportCurve:(VCurve*)g];
                    else if (  [g isKindOfClass:[VPath class]] )
                        NSLog(@"GerberExportSub.m: exportToFile, exportPath\n");/*[self exportPath:(VPath*)g];*/
                              else if (  [g isKindOfClass:[VGroup class]] )
                              [self exportGroup:(VGroup*)g];
                              else if (  [g isKindOfClass:[VText class]] )
                              [self exportText:(VText*)g];
                }
            }
        }
        [gList removeAllObjects];
    }
    savedOk = [self saveToFile:filename];

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
