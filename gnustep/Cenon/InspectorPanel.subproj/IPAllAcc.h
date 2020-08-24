/* IPAllAcc.h
 * Inspector Accessory
 *
 * Copyright (C) 2008 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  2008-03-13
 * modified: 2008-03-17
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

#ifndef VHF_H_IPALLACC
#define VHF_H_IPALLACC

#include <AppKit/AppKit.h>
#include "IPBasicLevel.h"

/* notifications */
#define InspectorAccDidOpenNotification @"InspectorAccDidOpen"  // inform that we are open now
#define InspectorAccAddItemNotification	@"InspectorAccAddItem"  // we have to add a new item

#define IP_ACC_TEXT     1   // FIXME: if we use our notification, we don't need this any more !

@interface IPAllAcc:IPBasicLevel
{
    id  accPopup;           // the popup to allow the user to select the different accessories
    id  accView;            // the view containing the accessory view

    int levelCnt;           // number of accessories
    id  windows[10];        // all accessories
    id  activeWindow;       // the active accessory window
    id	accTextWindow;      // our private accessories have a link to catch the NIB

    VGraphic	*graphic;
    id          docView;    // temporary current document view
}

- (void)update:sender;

- (void)setAccLevel:sender;
- (void)setLevelAt:(int)level;

- windowAt:(int)level;

//- (void)loadGraphic:(id)g;
- (void)setLevelView:theView;

- (void)setDocView:(id)aView;
- (id)docView;

- (void)displayWillEnd;

@end

#endif // VHF_H_IPALLACC
