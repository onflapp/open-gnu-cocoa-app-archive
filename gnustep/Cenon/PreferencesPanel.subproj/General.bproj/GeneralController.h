/* GeneralController.h
 * Preferences module for general settings
 *
 * Copyright (C) 1996-2011 by vhf interservice GmbH
 * Author: Georg Fleischmann
 *
 * Created:  1999-03-15
 * Modified: 2011-03-30 (SWITCH_DISABLEAUTOUPDATE added)
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
#include "../PreferencesMethods.h"

typedef enum
{
    SWITCH_DISABLECACHE      = 0,
    SWITCH_EXPERT            = 1,
    SWITCH_REMOVEBACKUPS     = 2,
    SWITCH_SELECTNONEDIT     = 3,
    SWITCH_SELECTBYBORDER    = 4,
    SWITCH_DISABLEANTIALIAS  = 5,	// Apple/GNUstep: turn off anti aliasing
    SWITCH_OSPROPERTYLIST    = 6,	// Apple/GNUstep: save as property list (not xml)
    SWITCH_DISABLEAUTOUPDATE = 7    // turn off automatic update checking
}GeneralSwitches;

@interface GeneralController:NSObject <PreferencesMethods>
{
    id box;

    id switchMatrix;
    id snapRadio;
    id unitPopup;
    id lineWidthField;
    id windowGridField;     // field for window grid size
    id cacheLimitField;     // max size of cache

    int	snap;
}

- (void)set:sender;
- (void)setUnit:sender;

@end
