/* SliderBox.h
 * Slider box used in IPAllFilling
 *
 * Copyright (C) 2002-2002 by vhf interservice GmbH
 * Author:   Ilonka Fleischmann
 *
 * created:  2002-07-10
 * modified: 2002-07-15
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

#ifndef VHF_H_SLIDERBOX
#define VHF_H_SLIDERBOX

#include <AppKit/AppKit.h>
#include <VHFShared/vhfCommonFunctions.h>
#include "../PreferencesMacros.h"
#include "../Graphics.h"
#include "../functions.h"

@interface SliderBox:NSView
{
    BOOL	enabled;
    NSPoint	location;
    id		target;
    SEL		action;
}

- (void)drawKnob;
- (void)setLocation:(NSPoint)p;
- (NSPoint)locationInPercent;
- (void)setEnabled:(BOOL)flag;

- (void)setTarget: (id)t;
- (void)setAction: (SEL)a;

@end

#endif // VHF_H_SLIDERBOX
