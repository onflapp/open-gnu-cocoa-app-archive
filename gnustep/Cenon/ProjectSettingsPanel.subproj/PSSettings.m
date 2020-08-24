/* PSSettings.m
 * settings panel for project settings
 *
 * Copyright 1996-2008 by vhf interservice GmbH
 * Author: Georg Fleischmann
 *
 * Created:  2000-06-26
 * Modified: 2008-07-21
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

#include <VHFShared/VHFPopUpButtonAdditions.h>
#include "ProjectSettings.h"
#include "PSSettings.h"
#include "../App.h"
#include "../Document.h"
#include "../PreferencesPanel.subproj/NotificationNames.h"  // PrefsUnitHasChanged notification


@interface PSSettings(PrivateMethods)
@end

@implementation PSSettings

- (id)init
{
    [super init];

    if ( ![NSBundle loadNibNamed:@"PSSettings" owner:self] )
    {   NSLog(@"Cannot load 'PSSettings' interface file");
        return nil;
    }

    [unitPopup setAction:@selector(set:)];

    [self update:self];

    return self;
}

/* the sender is our document or nil
 * modified: 2008-07-21
 */
- (void)update:sender
{   id		doc = ([sender isKindOfClass:[Document class]]) ? sender : [(App*)NSApp currentDocument];
    //NSString	*string;

    /* set index of unit popup */
    [unitPopup selectItemWithTag:((!doc) ? -1 : [doc baseUnitFlat])];

    // ???: on Apple, the zoom is in the coordinate ruler too, so it shouldn't be disabled !
    //[[switches cellAtRow:SWITCH_COORDS column:0] setState:[doc showCoords]];
}

- (NSString*)name	{ return [[view window] title]; }
- (NSView*)view		{ return view; }

/* set project settings of document
 * modified: 2008-07-19
 */
- (void)set:sender
{   id		doc = ([sender isKindOfClass:[Document class]]) ? sender : [(App*)NSApp currentDocument];

    if (!doc)
        return;

    if (sender == unitPopup)
    {   int unit = [[sender selectedItem] tag]; // tag is the CenonUnit already

        [doc setBaseUnit:unit];
        [[NSNotificationCenter defaultCenter] postNotificationName:PrefsUnitHasChanged object:doc userInfo:nil];
    }
}

@end
