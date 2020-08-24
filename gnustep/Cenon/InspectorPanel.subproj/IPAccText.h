/* IPAccText.h
 * Accessory Text Inspector used for all Text objects
 *
 * Copyright (C) 2008 by vhf interservice GmbH
 * Author:   Ilonka Fleischmann
 *
 * created:  2008-03-13
 * modified: 2008-03-13
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

#ifndef VHF_H_IPACCTEXT
#define VHF_H_IPACCTEXT

#include <AppKit/AppKit.h>
#include "IPBasicLevel.h"

@interface IPAccText:IPBasicLevel
{
    id fontSizeField;
    id lineHeightField;
    id fontButtonLeft;
    id fontButtonRight;
    id lineButtonLeft;
    id lineButtonRight;

    VGraphic	*graphic;	// the loaded graphic or the first of them if multiple
}

- (void)update:sender;

- (void)setFontSize:(id)sender;
- (void)setLineHeight:(id)sender;

- (void)displayWillEnd;

@end

#endif // VHF_H_IPACCTEXT
