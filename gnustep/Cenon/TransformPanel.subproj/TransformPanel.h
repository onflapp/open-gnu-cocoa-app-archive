/* TransformPanel.h
 * Cenon panel for transforming graphic objects
 *
 * Copyright (C) 1995-2011 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * Created:  1995-08-10
 * Modified: 2006-11-13
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

#ifndef VHF_H_TRANSFORMPANEL
#define VHF_H_TRANSFORMPANEL

#include <AppKit/AppKit.h>
#include "TPBasicLevel.h"

#define TP_SCALE	0
#define TP_MOVE		1
#define TP_ALIGN	2
#define TP_MIX		3
#define TP_ROTATE	4
#define DP_DEFAULT	99

#define BUTTONLEFT	0
#define BUTTONRIGHT	1
#define BUTTONUP	2
#define BUTTONDOWN	3

@interface TransformPanel:TPBasicLevel
{
    id              levRadio;
    NSScrollView    *levView;
    NSBox           *levBox;

    id              scalePanel;
    id              movePanel;
    id              alignPanel;
    id              mixPanel;
    id              rotatePanel;

    id              activeWindow;
    id              dataView;
}

- init;
- (void)update:sender;

- (void)setLevel:sender;
- (void)setLevelAt:(int)level;
- (void)setLevelView:theView;

- windowAt:(int)level;

@end

#endif // VHF_H_TRANSFORMPANEL
