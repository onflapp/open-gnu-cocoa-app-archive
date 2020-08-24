/* DXFExport.h
 *
 * Copyright (C) 2002-2003 by vhf interservice GmbH
 * Author:   Ilonka Fleischmann
 *
 * created:  2002-04-25
 * modified: 2002-04-25
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

#define	MAXLAYERS	50

typedef struct _DXFState
{
    int			toolCnt;
    int			curTool;
    int			noPoint;
    NSPoint		point;
//    BOOL		setBounds;	// if we have a clipRect
    float		maxW;
    NSPoint		ll;
    NSPoint		ur;
    float		width;
    int			curColor;
    BOOL		fill;
    NSString		*curLayer;
    int			ltypeCnt;
    NSString		*curLtype;
    int			layerCnt;
    NSMutableArray	*layerNames;
    int			layerAttrib[MAXLAYERS];
    int			layerColor[MAXLAYERS];
    float		res;
}DXFState;

@interface DXFExport:NSObject
{
    NSString		*headerStr;
    NSString		*tableStr;
    NSString		*blockStr;
    NSMutableString	*grStr; // entities
    DXFState		state;		// the current state
    NSMutableDictionary	*toolDict;
}

- (void)setRes:(float)res;
- (void)addLayer:(NSString*)name :(NSColor*)color :(int)attribut;
- (void)setCurColor:(NSColor*)color;

- (void)writeLine:(NSPoint)startPt :(NSPoint)endPt :(float)width;	// write line data
- (void)writePolyLineVertex:(NSPoint)p; // :(float)width
- (void)writePolyLineMode:(BOOL)mode :(float)width :(int)closed;
- (void)writeLineVertex:(NSPoint)s; // :(float)width
- (void)writeArcVertex:(NSPoint)e :(float)a :(NSPoint)center :(float)radius; // :(float)t // :(float)width
- (void)writeCircle:(NSPoint)center :(float)radius :(float)width;	// only unfilled 360 degree
- (void)writeArc:(NSPoint)center :(float)radius :(float)begAngle :(float)endAngle :(float)width;
- (void)writeText:(NSPoint)o :(float)height :(float)degree :(float)iangle :(NSString*)textStr :(float)width;

- (BOOL)saveToFile:(NSString*)filename;

@end
