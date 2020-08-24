/* HPGLExportSub.m
 * Sub class of HPGL export
 *
 * Copyright (C) 2002-2005 by vhf interservice GmbH
 * Author:   Ilonka Fleischmann
 *
 * created:  2002-04-28
 * modified: 2005-11-17
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
#include "HPGLExportSub.h"
#include "Graphics.h"
#include "messages.h"
#include "locations.h"
#include "DocView.h"
#include "LayerObject.h"
#include "PreferencesMacros.h"

//#define RES 1000

@interface HPGLExportSub(PrivateMethods)
- (void)exportPolyLine:(VPolyLine*)g;
- (void)exportRectangle:(VRectangle*)g;
- (void)exportArc:(VArc*)g;
- (void)exportCurve:(VCurve*)g;
- (void)exportText:(VText*)g;
- (void)exportPath:(VPath*)path;
- (void)exportGroup:(VGroup*)group;
@end

@implementation HPGLExportSub

- (void)setDocumentView:view
{
    docView = view;
}

- (void)exportPolyLine:(VPolyLine*)g
{   int		i, cnt = [(VPolyLine*)g numPoints];

    for (i=0; i<cnt-1; i++)
        [self writeLine:[g pointWithNum:i] :[g pointWithNum:i+1]];
}

- (void)exportRectangle:(VRectangle*)g
{
    [self exportPath:[g pathRepresentation]];
}

- (void)exportArc:(VArc*)g
{
    if (Abs([g angle]) != 360.0 || ![g filled])
    {   float	angle;
        NSPoint	center, start, end;

        [g getCenter:&center start:&start angle:&angle];
        end = [g pointWithNum:MAXINT]; // end

        [self writeArc:center :start :end :angle];
    }
    else
        [self writeCircle:[g center] :[g radius]];
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
{   int		i, cnt=[[path list] count];

    for (i=0; i<cnt; i++)
    {   id	g = [[path list] objectAtIndex:i];

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
        else NSLog(@"HPGL exportPath g type not implemented\n");
    }
}

- (void)exportGroup:(VGroup*)group
{   int		i, cnt=[[group list] count];

    for (i=0; i<cnt; i++)
    {   id	g = [[group list] objectAtIndex:i];
/*        float	w = [g width];

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
*/
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
        else NSLog(@"HPGL exportGroup g type not implemented\n");
    }
}

#if 0
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
#endif

- (BOOL)exportToFile:(NSString*)filename
{   BOOL            savedOk = NO;
    NSString		*backupFilename; // *devPath
    NSFileManager	*fileManager = [NSFileManager defaultManager];

/*
    devPath = vhfPathWithPathComponents(userLibrary(), HPGLPATH, [NSString stringWithFormat:@"%@.dev", Prefs_HPGLParmsFileName], nil);
    if ( ![defaultManager fileExistsAtPath:devPath] )
    {   devPath = vhfPathWithPathComponents(localLibrary(), HPGLPATH, [NSString stringWithFormat:@"%@.dev", Prefs_HPGLParmsFileName], nil);
        if ( ![defaultManager fileExistsAtPath:devPath] )
        {   NSRunAlertPanel(@"", CANTLOADFILE_STRING, OK_STRING, nil, nil, path);
            return nil;
        }
    }
    if (![self loadParameter:devPath])
    {   NSRunAlertPanel(@"", CANTLOADFILE_STRING, OK_STRING, nil, nil, path);
        return nil;
    }
*/
    backupFilename = [[[filename stringByDeletingPathExtension] stringByAppendingString:@"~"]
                      stringByAppendingPathExtension:HPGL_EXT];
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


// 72 25400 div 72 25400 div scale\n

        // first clip rect
        for (i=(int)[layerList count]-1 ; i >=0  ; i--)
        {   LayerObject	*lObj = [layerList objectAtIndex:i];

            if ([lObj type] == LAYER_CLIPPING || ![lObj state]) // visible - ????????????????????????
                continue;
            {   int	j, cnt = [[lObj list] count];

                for (j=0; j<cnt; j++)
                {   id			g = [[lObj list] objectAtIndex:j];
//                    NSAutoreleasePool	*pool = [NSAutoreleasePool new];
/*                    float	w = [g width];

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
*/
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
                    else if (  [g isKindOfClass:[VText class]] )
                        [self exportText:g];
//                    [pool release];
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
