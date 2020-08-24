/* HPGLExport.h
 *
 * Copyright (C) 2002-2004 by vhf interservice GmbH
 * Author:   Ilonka Fleischmann
 *
 * created:  2002-04-28
 * modified: 2004-09-20
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

typedef struct _HPGLState
{
    float	res;		// resolution
    int		toolCnt;
    int		curTool;
    int		noPoint;
    NSPoint	point;
    BOOL	setBounds; // if we have an clipRect
    float	maxW;
    NSPoint	ll;
    NSPoint	ur;
    float	width;
    NSColor	*color;
    BOOL	fill;
}HPGLState;

@interface HPGLExport:NSObject
{
    NSMutableString	*grStr;
//    NSString		*toolStr;
    HPGLState		state;	// the current state
//    NSMutableDictionary	*toolDict;
}

//- (void)writeCircleTool:(float)dia;
//- (void)writeRectangleTool:(float)w :(float)h;

- (void)writeLine:(NSPoint)s :(NSPoint)e;	// write line data
//- (void)writeRectangle:(NSPoint)origin;	// flash rectangle
- (void)writeCircle:(NSPoint)center :(float)radius;
- (void)writeArc:(NSPoint)center :(NSPoint)start :(NSPoint)end :(float)angle;
//- (void)writePolygonMode:(BOOL)mode;

- (BOOL)saveToFile:(NSString*)filename;

@end
