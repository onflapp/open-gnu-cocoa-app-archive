/* VMark.h
 * Drill marker or any other marking
 *
 * Copyright (C) 1996-2007 by vhf interservice GmbH
 * Author:  Georg Fleischmann
 *
 * created:  1997-11-13
 * modified: 2003-06-18
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

#ifndef VHF_H_VMARK
#define VHF_H_VMARK

#include "VGraphic.h"

#define  PTS_MARK	1

@interface VMark:VGraphic
{
    NSPoint     origin;     // the origin of the mark
    float       diameter;   // the diameter (Tool width) of the mark [mm]
    BOOL        is3D;       // wether we are a 3-D Marker
    float       z;          // z for 3-D Marker
    //NSString    *name;      // name of the marker (we use label from VGraphics now)
}

+ (id)markWithOrigin:(NSPoint)o diameter:(float)dia;

/* class methods */
- (void)setDiameter:(float)dia;
- (float)diameter;
- (void)setOrigin:(NSPoint)pt;
- (NSPoint)origin;

- (void)setName:(NSString*)newName;
- (NSString*)name;

- (void)set3D:(BOOL)flag;
- (BOOL)is3D;
- (void)setZ:(float)pt;
- (float)z;

@end

#endif // VHF_H_VMARK
