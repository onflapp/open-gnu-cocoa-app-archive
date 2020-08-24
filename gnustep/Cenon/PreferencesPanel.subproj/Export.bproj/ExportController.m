/* ExportController.m
 * Preferences module for Cenon Exports
 *
 * Copyright (C) 1996-2004 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * Created:  1999-03-15
 * Modified: 2002-07-16
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
#include "ExportController.h"
//#include "../../functions.h"
//#include "../../locations.h"
#include "../NotificationNames.h"

@interface ExportController(PrivateMethods)
@end

@implementation ExportController

/*
 * registration of defaults resides in [App +initialize]
 */

/*
 * created:  1999-03-15
 * modified: 2002-07-07
 * Initializes the defaults.
 */
/*+ (void)initialize
{   NSMutableDictionary	*registrationDict = [NSMutableDictionary dictionary];

    [registrationDict setObject:@"NO" forKey:@"exportFlattenText"];
    [[NSUserDefaults standardUserDefaults] registerDefaults:registrationDict];
}*/

// protocol methods

/* create new instance of GeneralController
 */
+ (id)controller
{   static ExportController *controller = nil;

    if (!controller)
        controller = [[ExportController alloc] init];
    return controller;
}

- (id)init
{
    [super init];

    if ( ![NSBundle loadNibNamed:@"Export" owner:self] )
    {   NSLog(@"Cannot load 'Export' interface file");
        return nil;
    }

    [self update:self];

    return self;
}

- (NSImage*)icon
{   NSImage	*icon = nil;

    if (!icon)
    {   NSBundle	*bundle = [NSBundle bundleForClass:[self class]];
        NSString	*file = [bundle pathForResource:@"prefsExport" ofType:@"tiff"];

        icon = [[NSImage alloc] initWithContentsOfFile:file];
    }
    return icon;
}

- (NSString*)name
{
    return @"Export";
}

- (NSView*)view
{
    return box;
}

// end methods from protocol


- (void)update:sender
{   id	defaults = [NSUserDefaults standardUserDefaults];

    [[switchMatrix cellAtRow:SWITCH_FLATTENTEXT column:0]
      setState:([[defaults objectForKey:@"exportFlattenText"] isEqual:@"YES"]) ? 1 : 0];
}

- (void)set:sender;
{   NSString	*string;
    id		defaults = [NSUserDefaults standardUserDefaults];

    /* flatten text */
    string = ([switchMatrix cellAtRow:SWITCH_FLATTENTEXT column:0]) ? @"YES" : @"NO";
    if ( ![string isEqual:[defaults objectForKey:@"exportFlattenText"]] )
        [defaults setObject:string forKey:@"exportFlattenText"];
}

@end
