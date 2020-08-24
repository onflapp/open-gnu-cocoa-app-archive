/*
 * VCrosshairs.h
 *
 * Copyright (C) 1996-2002 by vhf interservice GmbH
 * Author: Georg Fleischmann
 *
 * created:  1996-03-29
 * modified: 2002-07-07
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

#ifndef VHF_H_VCROSSHAIRS
#define VHF_H_VCROSSHAIRS

#include "VGraphic.h"

@interface VCrosshairs:VGraphic
{
    NSPoint	origin;			// the origin of the crosshairs
}

/* class methods */

/* crosshairs methods */

/* subclassed from graphic
 */
- init;
- (void)movePoint:(int)pt_num by:(NSPoint)pt;
- (void)moveBy:(NSPoint)pt;
- (NSPoint)pointWithNum:(int)pt_num;
- (BOOL)hitControl:(NSPoint)p :(int*)pt_num controlSize:(float)controlsize;
- (BOOL)hit:(NSPoint)p fuzz:(float)fuzz;

- (id)initWithCoder:(NSCoder *)aDecoder;
- (void)encodeWithCoder:(NSCoder *)aCoder;

@end

#endif // VHF_H_VCROSSHAIRS
