/* VLine3D.h
 * 3-D line object
 *
 * Copyright (C) 1996-2011 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1996-01-19
 * modified: 2011-04-04 (-line3DWithPoints: added)
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

#ifndef VHF_H_VLINE3D
#define VHF_H_VLINE3D

#include "VLine.h"

#define  PTS_LINE	2

@interface VLine3D: VLine
{
    float	z0, z1;		// the z level of the line (0 - 1)
}

/* class methods */
+ (VLine3D*)line3D;
+ (VLine3D*)line3DWithPoints:(V3Point)p0 :(V3Point)p1;

/* line methods */
- (void)setVertices3D:(V3Point)pv0 :(V3Point)pv1;
- (void)setZLevel:(float)zv0 :(float)zv1;
- (void)getZLevel:(float*)zv0 :(float*)zv1;

@end

#endif // VHF_H_VLINE3D
