/* PSFontInfo.m
 * fontinfo panel for project settings
 *
 * Copyright (C) 1996-2002 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * Created:  2002-11-23
 * Modified: 2002-11-23
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

#include "ProjectSettings.h"
#include "PSFontInfo.h"
#include "../App.h"
#include "../DocView.h"
#include "../locations.h"
#include "../messages.h"

#define MIX_DONTMIX		0
#define MIX_DONTMIXLAYER	1

@implementation PSFontInfo

- (id)init
{
    [super init];

    if ( ![NSBundle loadNibNamed:@"PSSettings" owner:self] )
    {   NSLog(@"Cannot load 'PSSettings' interface file");
        return nil;
    }

    [self update:self];

    return self;
}

- (void)update:sender
{
    [versionForm setStringValue:@""];
    [authorForm setStringValue:@""];
    [copyrightForm setStringValue:@""];
    [commentField setStringValue:@""];

//    [scaleYField setEnabled:([uniformScaleSwitch state]) ? NO : YES];
}

- (NSString*)name   { return [[view window] title]; }

- (NSView*)view     { return view; }

- (void)set:sender
{
}

@end
