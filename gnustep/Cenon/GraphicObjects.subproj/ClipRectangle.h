/* ClipRectangle.h
 * Cenon 2-D Clip rectangle
 *
 * Copyright (C) 1996-2008 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1996-09-17
 * modified: 2008-06-08
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

#ifndef VHF_H_CLIPRECTANGLE
#define VHF_H_CLIPRECTANGLE

#include "VGraphic.h"

#define PTS_RECTANGLE	4
#define PT_LL		0
#define PT_UL		1
#define PT_UR		2
#define PT_LR		3

@interface ClipRectangle:VGraphic
{
    NSPoint	origin, size;	/* the origin and size of the rectangle */
    int		selectedKnob;	/* index of the selected knob (0 - 3 or -1) */
}

/* class methods */

/* rectangle methods */
- (void)setVertices:(NSPoint)origin :(NSPoint)size;
- (void)getVertices:(NSPoint*)origin :(NSPoint*)size;
- (int)selectedKnobIndex;
- (NSArray*)clip:obj;

@end

#endif // VHF_H_CLIPRECTANGLE
