/* IPCurve.h
 * Curve inspector
 *
 * Copyright (C) 1995-2006 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1995-12-09
 * modified: 2006-12-08
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

#ifndef VHF_H_IPCURVE
#define VHF_H_IPCURVE

#include <AppKit/AppKit.h>
#include "IPBasicLevel.h"

@interface IPCurve:IPBasicLevel
{
    id		xField;
    id		yField;
    id		xButtonLeft;
    id		xButtonRight;
    id		yButtonLeft;
    id		yButtonRight;

    id		xc1Field;
    id		yc1Field;
    id		xc1ButtonLeft;
    id		xc1ButtonRight;
    id		yc1ButtonLeft;
    id		yc1ButtonRight;

    id		xc2Field;
    id		yc2Field;

    id		xeField;
    id		yeField;

    VGraphic	*graphic;
}

- (void)update:sender;

- (void)setPointX:sender;
- (void)setPointY:sender;
- (void)setControlX:sender;
- (void)setControlY:sender;

- (void)displayWillEnd;

@end

#endif // VHF_H_IPCURVE
