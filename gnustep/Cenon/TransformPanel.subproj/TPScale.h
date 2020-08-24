/* TPScale.h
 * Transform panel for scaling objects
 *
 * Copyright (C) 1996-2011 by vhf interservice GmbH
 * Author: Georg Fleischmann
 *
 * Created:  1996-04-22
 * Modified: 2011-03-03
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

#include <AppKit/AppKit.h>
#include "TransformPanel.h"

@interface TPScale:TPBasicLevel
{
    id  scalePopup;         // relative, scale to size
    id	scaleXField;
    id	scaleYField;
    id	uniformScaleSwitch; // on = keep aspekt ratio
}

- (void)setHowToScale:sender;
- (void)setUniformScale:sender;
- (void)setScale:sender;

@end
