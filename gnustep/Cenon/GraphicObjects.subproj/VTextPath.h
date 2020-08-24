/* VTextPath.h
 * 2-D Textpath - text written on path
 *
 * Copyright (C) 2000-2012 by vhf interservice GmbH
 * Author:  Georg Fleischmann
 *
 * created:  2000-07-31
 * modified: 2002-07-09
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the vhf Public License as
 * published by vhf interservice GmbH. Among other things, the
 * License requires that the copyright notices and this notice
 * be preserved on all copies.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the vhf Public License for more details.
 *
 * You should have received a copy of the vhf Public License along
 * with this program; see the file LICENSE. If not, write to vhf.
 *
 * vhf interservice GmbH, Im Marxle 3, 72119 Altingen, Germany
 * eMail: info@vhf.de
 * http://www.vhf.de
 */

#ifndef VHF_H_VTEXTPATH
#define VHF_H_VTEXTPATH

#include "VText.h"
#include "VPath.h"

@interface VTextPath:VGraphic
{
    VText		*text;		// the text
    VGraphic	*path;		// the path, arc, curve, line
    BOOL		showPath;	// weather to display the path

    NSMutableArray	*serialStreams;	// holds the output streams for serial numbers
}

+ (BOOL)canBindToObject:(id)obj;
+ (id)textPathWithText:(VText*)theText path:(VGraphic*)thePath;
+ (id)newWithText:(VText*)theText path:(VGraphic*)thePath;
- (id)initWithText:(VText*)theText path:(VGraphic*)thePath;

- (VText*)textGraphic;	// returns the text graphic
- (id)path;			// returns the path, line, curve, arc
- (void)setShowPath:(BOOL)flag;
- (BOOL)showsPath;		// weather we displayOurPath

/* methods passed to VText */
- (BOOL)edit:(NSEvent*)event in:view;
- (void)setSerialNumber:(BOOL)flag;
- (BOOL)isSerialNumber;
- (void)incrementSerialNumberBy:(int)o;
- (void)drawSerialNumberAt:(NSPoint)p withOffset:(int)o;

- (NSColor*)fillColor;
- (void)setFillColor:(NSColor*)col;
- (NSColor*)endColor;
- (void)setEndColor:(NSColor*)col;
- (float)graduateAngle;
- (void)setGraduateAngle:(float)a;
- (void)setStepWidth:(float)sw;
- (float)stepWidth;

- (VPath*)pathRepresentation;

- (id)getFlattenedObjectAt:(NSPoint)offset withOffset:(int)o;

@end

#endif // VHF_H_VTEXTPATH
