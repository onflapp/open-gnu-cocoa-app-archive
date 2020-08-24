/* GeneralController.m
 * Preferences module for general settings
 *
 * Copyright (C) 1996-2011 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * Created:  1999-03-15
 * Modified: 2011-03-30 (switch to turn off automatic update check)
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
#include <VHFShared/VHFStringAdditions.h>	// +stringWithFloat:
#include "GeneralController.h"
#include "../NotificationNames.h"

@interface GeneralController(PrivateMethods)
@end

@implementation GeneralController

/*
 * registration of defaults resides in [App +initialize]
 */

/*
 * created:  1999-03-15
 * modified: 2002-07-01
 * Initialize defaults
 */
/*+ (void)initialize
{   NSMutableDictionary	*registrationDict = [NSMutableDictionary dictionary];

    [registrationDict setObject:@"YES" forKey:@"doCaching"];
    [registrationDict setObject:@"0" forKey:@"unit"];
    [registrationDict setObject:@"NO" forKey:@"removeBackups"];
    [registrationDict setObject:@"NO" forKey:@"expertMode"];
    [registrationDict setObject:@"0" forKey:@"snap"];
    [registrationDict setObject:@"." forKey:@"NSDecimalSeparator"];
    [[NSUserDefaults standardUserDefaults] registerDefaults:registrationDict];
}*/

// protocol methods

/* create new instance of GeneralController
 */
+ (id)controller
{   static GeneralController *controller = nil;

    if (!controller)
        controller = [[GeneralController alloc] init];
    return controller;
}

- (id)init
{
    [super init];

    if ( ![NSBundle loadNibNamed:@"General" owner:self] )
    {   NSLog(@"Cannot load 'General' interface file");
        return nil;
    }

//#ifdef __APPLE__
//    [[switchMatrix cellAtRow:SWITCH_DISABLECACHE column:0] setEnabled:NO];
//#endif
    [self update:self];

    return self;
}

- (NSImage*)icon
{   NSImage	*icon = nil;

    if (!icon)
    {   NSBundle	*bundle = [NSBundle bundleForClass:[self class]];
        NSString	*file = [bundle pathForResource:@"prefsGeneral" ofType:@"tiff"];

        icon = [[NSImage alloc] initWithContentsOfFile:file];
    }
    return icon;
}

- (NSString*)name
{   NSBundle	*bundle = [NSBundle bundleForClass:[self class]];

    return NSLocalizedStringFromTableInBundle(@"General", nil, bundle, NULL);
}

- (NSView*)view
{
    return box;
}

// end methods from protocol


- (void)update:sender
{   int		i;
    id		defaults = [NSUserDefaults standardUserDefaults];

//#ifdef __APPLE__
//    [[switchMatrix cellAtRow:SWITCH_DISABLECACHE column:0] setState:1];
//#else
    [[switchMatrix cellAtRow:SWITCH_DISABLECACHE column:0] setState:([[defaults objectForKey:@"doCaching"] isEqual:@"YES"]) ? 0 : 1];
//#endif
    [[switchMatrix cellAtRow:SWITCH_EXPERT              column:0] setState:([[defaults objectForKey:@"expertMode"]         isEqual:@"YES"]) ? 1 : 0];
    [[switchMatrix cellAtRow:SWITCH_REMOVEBACKUPS       column:0] setState:([[defaults objectForKey:@"removeBackups"]      isEqual:@"YES"]) ? 1 : 0];
    [[switchMatrix cellAtRow:SWITCH_SELECTNONEDIT       column:0] setState:([[defaults objectForKey:@"selectNonEditable"]  isEqual:@"YES"]) ? 1 : 0];
    [[switchMatrix cellAtRow:SWITCH_SELECTBYBORDER      column:0] setState:([[defaults objectForKey:@"selectByBorder"]     isEqual:@"YES"]) ? 1 : 0];

#if defined(GNUSTEP_BASE_VERSION) || defined(__APPLE__)
    [[switchMatrix cellAtRow:SWITCH_DISABLEANTIALIAS    column:0] setState:([[defaults objectForKey:@"disableAntiAliasing"] isEqual:@"YES"]) ? 1 : 0];
    [[switchMatrix cellAtRow:SWITCH_OSPROPERTYLIST      column:0] setState:([[defaults objectForKey:@"writeOSPropertyList"] isEqual:@"YES"]) ? 1 : 0];
    [[switchMatrix cellAtRow:SWITCH_DISABLEAUTOUPDATE   column:0] setState:([[defaults objectForKey:@"disableAutoUpdate"]   isEqual:@"YES"]) ? 1 : 0];
#endif

    /* snap */
    snap = [[defaults objectForKey:@"snap"] intValue];
    for (i=0; i<(int)[[snapRadio cells] count]; i++)
        if ( [[snapRadio cellAtRow:i column:0] tag] == snap )
        {   [snapRadio selectCellAtRow:i column:0];
            break;
        }

    /* set index of unit popup */
    [unitPopup selectItemAtIndex:[defaults integerForKey:@"unit"]];
    [unitPopup setAction:@selector(setUnit:)];

    /* line width */
    [lineWidthField setStringValue:[NSString stringWithFloat:[[defaults objectForKey:@"lineWidth"] floatValue]]];

    /* window grid */
    [windowGridField setIntValue:[defaults integerForKey:@"windowGrid"]];

    /* cache size */
    [cacheLimitField setIntValue:[[defaults objectForKey:@"cacheLimit"] intValue]];
}




- (void)set:sender;
{   NSString    *string;
    id          defaults = [NSUserDefaults standardUserDefaults];

    /* caching */
//#ifdef __APPLE__
//    string = @"NO";
//#else
    string = ([[switchMatrix cellAtRow:SWITCH_DISABLECACHE      column:0] state]) ? @"NO" : @"YES";
//#endif
    if ( ![string isEqual:[defaults objectForKey:@"doCaching"]] )
    {
        [defaults setObject:string forKey:@"doCaching"];
        [[NSNotificationCenter defaultCenter] postNotificationName:PrefsCachingHasChanged object:nil userInfo:nil];
    }

    /* expert mode */
    string = ([[switchMatrix cellAtRow:SWITCH_EXPERT            column:0] state]) ? @"YES" : @"NO";
    [defaults setObject:string forKey:@"expertMode"];

    /* remove backups */
    string = ([[switchMatrix cellAtRow:SWITCH_REMOVEBACKUPS     column:0] state]) ? @"YES" : @"NO";
    [defaults setObject:string forKey:@"removeBackups"];

    /* allow selection of non editable layers */
    string = ([[switchMatrix cellAtRow:SWITCH_SELECTNONEDIT     column:0] state]) ? @"YES" : @"NO";
    [defaults setObject:string forKey:@"selectNonEditable"];

    /* select the objects only at border */
    string = ([[switchMatrix cellAtRow:SWITCH_SELECTBYBORDER    column:0] state]) ? @"YES" : @"NO";
    [defaults setObject:string forKey:@"selectByBorder"];

#if defined(GNUSTEP_BASE_VERSION) || defined(__APPLE__)
    string = ([[switchMatrix cellAtRow:SWITCH_DISABLEANTIALIAS  column:0] state]) ? @"YES" : @"NO";
    [defaults setObject:string forKey:@"disableAntiAliasing"];

    string = ([[switchMatrix cellAtRow:SWITCH_OSPROPERTYLIST    column:0] state]) ? @"YES" : @"NO";
    [defaults setObject:string forKey:@"writeOSPropertyList"];

    string = ([[switchMatrix cellAtRow:SWITCH_DISABLEAUTOUPDATE column:0] state]) ? @"YES" : @"NO";
    [defaults setObject:string forKey:@"disableAutoUpdate"];
#endif

    /* snap */
    string = [NSString stringWithFormat:@"%d", [[snapRadio selectedCell] tag]];
    if ( ![string isEqual:[defaults objectForKey:@"snap"]] )
    	[defaults setObject:string forKey:@"snap"];

    /* line width */
    string = [NSString stringWithFloat:[lineWidthField floatValue]];
    if ( ![string isEqual:[defaults objectForKey:@"lineWidth"]] )
        [defaults setObject:string forKey:@"lineWidth"];

    /* window grid */
    if ( [windowGridField intValue] != [defaults integerForKey:@"windowGrid"] )
        [defaults setObject:[NSNumber numberWithInt:[windowGridField intValue]]
                     forKey:@"windowGrid"];

    /* cache limit */
    if (cacheLimitField)
    {
        string = [NSString stringWithFormat:@"%d", [cacheLimitField intValue]];
        if ( string != [defaults objectForKey:@"cacheLimit"] )
            [defaults setObject:string forKey:@"cacheLimit"];
    }
    else	// set 20 MB default
        [defaults setObject:@"20" forKey:@"cacheLimit"];
}

/* created:  1994-03-18
 * modified: 2001-12-04
 * purpose:  set unit
 */
- (void)setUnit:sender
{   int		unit = [sender indexOfSelectedItem];

    [[NSUserDefaults standardUserDefaults] setObject:[NSString stringWithFormat:@"%d", unit] forKey:@"unit"];
    [[NSNotificationCenter defaultCenter] postNotificationName:PrefsUnitHasChanged object:nil userInfo:nil];
}

@end
