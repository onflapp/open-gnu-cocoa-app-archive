/* ProjectSettings.h
 * project settings for document
 *
 * Copyright (C) 2002-2009 by vhf interservice GmbH
 * Author:   Ilonka Fleischmann, Georg Fleischmann
 *
 * Created:  2002-11-23
 * Modified: 2009-06-26 (awakeFromNib declaration removed)
 *           2008-07-30 (-indexOfItem:)
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

#ifndef VHF_H_PROJECTSETTINGS
#define VHF_H_PROJECTSETTINGS

#include <AppKit/AppKit.h>
#include <VHFShared/types.h>


#define DocSettingsDidOpenNotification  @"DocSettingsDidOpen"   // inform that we are open now
#define DocSettingsAddItemNotification  @"DocSettingsAddItem"   // we have to add a new item

#define PS_INFO     0
#define PS_SETTINGS 1

@interface ProjectSettings:NSObject
{
    id              levPopup;	// popup to select level
    NSScrollView    *levView;	// we add our subviews to this view
    id              panel;		// this is our panel

    id              windows[10];    // item views (info, general, ...)
    int             levelCnt;       // number of items
    id              activeWindow;
}

- (void)makeKeyAndOrderFront:sender;
- (void)update:sender;

- (void)setLevel:sender;
- (void)setLevelAt:(int)level;
- (void)setLevelView:theView;
- (void)setLevelWithItem:(id)item;  // set level of given item (either the controller or the view)

- (int)indexOfItem:(id)item;        // returns the index of the item in the popup
- windowAt:(int)level;

@end

#endif // VHF_H_PROJECTSETTINGS
