/* IPPath.h
 * Path Inspector
 *
 * Copyright (C) 1995-2002 by vhf interservice GmbH
 * Author: Georg Fleischmann
 *
 * created:  1995-12-09
 * modified: 2005-09-07
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

#ifndef VHF_H_IPPATH
#define VHF_H_IPPATH

#include <AppKit/AppKit.h>
#include "IPBasicLevel.h"

@interface IPPath:IPBasicLevel
{
    id	originXField;
    id	originYField;
    id	sizeWidthField;
    id	sizeHeightField;
    id	xField;
    id	yField;
    id	xButtonLeft;
    id	xButtonRight;
    id	yButtonLeft;
    id	yButtonRight;
}

- (void)update:sender;

- (void)setOriginX:sender;
- (void)setOriginY:sender;
- (void)setSizeWidth:sender;
- (void)setSizeHeight:sender;
- (void)setPointX:sender;
- (void)setPointY:sender;

- (void)displayWillEnd;

@end

#endif // VHF_H_IPPATH
