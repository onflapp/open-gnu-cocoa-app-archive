/* IPAllText.h
 * Text Inspector used for all Text objects
 *
 * Copyright (C) 2002 by vhf interservice GmbH
 * Author:   Ilonka Fleischmann
 *
 * created:  2002-06-27
 * modified: 2002-07-20
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

#ifndef VHF_H_IPALLTEXT
#define VHF_H_IPALLTEXT

#include <AppKit/AppKit.h>
#include "IPBasicLevel.h"

@interface IPAllText:IPBasicLevel
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

#endif // VHF_H_IPALLTEXT
