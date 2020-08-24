/* IPTextPath.h
 * TextPath Inspector
 *
 * Copyright (C) 2000-2011 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1996-08-??
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

#ifndef VHF_H_IPTEXTPATH
#define VHF_H_IPTEXTPATH

#include <AppKit/AppKit.h>
#include "../Graphics.h"
#include "IPBasicLevel.h"

@interface IPTextPath:IPBasicLevel
{
    id			showPathSwitch;
    id			serialNumberSwitch;

    NSScrollView	*pathView;

    VTextPath		*graphic;	// the loaded graphic or the first of them if multiple
}

- (void)update:sender;

- (NSScrollView*)pathView;
//- (void)showPathInspector:sender;
- (void)setShowPath:sender;
- (void)setSerialNumber:sender;

- (void)displayWillEnd;

@end

#endif // VHF_H_IPTEXTPATH
