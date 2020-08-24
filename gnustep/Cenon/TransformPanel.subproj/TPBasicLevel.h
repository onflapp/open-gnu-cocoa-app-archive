/*
 * TPBasicLevel.h
 *
 * Copyright (C) 1996-2002 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * Created:  1996-03-03
 * Modified: 2002-07-07
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

#ifndef VHF_H_TPBASICLEVEL
#define VHF_H_TPBASICLEVEL

#include <AppKit/AppKit.h>
#include <VHFShared/vhfCommonFunctions.h>
#include <VHFShared/types.h>
#include "../App.h"

@interface TPBasicLevel:NSPanel
{
    id	window;		// the data panel
}

- init;
- (void)setWindow:win;
- view;
- window;
- (void)update:sender;

/* delegate methods
 */
- (void)displayWillEnd;

@end

#endif // VHF_H_TPBASICLEVEL
