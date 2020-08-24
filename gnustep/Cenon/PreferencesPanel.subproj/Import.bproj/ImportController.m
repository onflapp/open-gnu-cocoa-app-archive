/* ImportController.m
 * Preferences module for Cenon imports
 *
 * Copyright (C) 1996-2006 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * Created:  1999-03-15
 * Modified: 2006-02-24
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
//#include <VHFShared/vhfCommonFunctions.h>
#include "ImportController.h"
#include "../../functions.h"		// fillPopup()
#include "../../locations.h"		// HPGL_PATH ...
#include "../NotificationNames.h"

@interface ImportController(PrivateMethods)
@end

@implementation ImportController

/*
 * registration of defaults resides in [App +initialize]
 */

/*
 * created:  1999-03-15
 * modified: 2000-09-13
 * Initializes the defaults.
 */
/*+ (void)initialize
{   NSMutableDictionary	*registrationDict = [NSMutableDictionary dictionary];

    [registrationDict setObject:@"hpgl_8Pen" forKey:@"hpglParmsFileName"];
    [registrationDict setObject:@"gerber" forKey:@"gerberParmsFileName"];
    [registrationDict setObject:@"" forKey:@"dinParmsFileName"];
    [registrationDict setObject:@"25.4" forKey:@"dxfRes"];
    [registrationDict setObject:@"NO" forKey:@"psFlattenText"];
    [registrationDict setObject:@"NO" forKey:@"psPreferArcs"];
    [registrationDict setObject:@"NO" forKey:@"colorToLayer"];
    [registrationDict setObject:@"NO" forKey:@"fillObjects"];
    [[NSUserDefaults standardUserDefaults] registerDefaults:registrationDict];
}*/

// protocol methods

/* create new instance of GeneralController
 */
+ (id)controller
{   static ImportController *controller = nil;

    if (!controller)
        controller = [[ImportController alloc] init];
    return controller;
}

- (id)init
{
    [super init];

    if ( ![NSBundle loadNibNamed:@"Import" owner:self] )
    {   NSLog(@"Cannot load 'Import' interface file");
        return nil;
    }

    [self update:self];

    return self;
}

- (NSImage*)icon
{   NSImage	*icon = nil;

    if (!icon)
    {   NSBundle	*bundle = [NSBundle bundleForClass:[self class]];
        NSString	*file = [bundle pathForResource:@"prefsImport" ofType:@"tiff"];

        icon = [[NSImage alloc] initWithContentsOfFile:file];
    }
    return icon;
}

- (NSString*)name
{
    return @"Import";
}

- (NSView*)view
{
    return box;
}

// end methods from protocol


- (void)update:sender
{   int         i;
    id          defaults = [NSUserDefaults standardUserDefaults];
    NSString    *string;

    [dxfResField setStringValue:[NSString stringWithFloat:[[defaults objectForKey:@"dxfRes"] floatValue]]];
    [psPreferArcsSwitch  setState:([[defaults objectForKey:@"psPreferArcs"]  isEqual:@"YES"]) ? 1 : 0];
    [psFlattenTextSwitch setState:([[defaults objectForKey:@"psFlattenText"] isEqual:@"YES"]) ? 1 : 0];
    [[switchMatrix cellAtRow:SWITCH_COLORTOLAYER column:0]
      setState:([[defaults objectForKey:@"colorToLayer"] isEqual:@"YES"]) ? 1 : 0];
    [[switchMatrix cellAtRow:SWITCH_FILLOBJECTS  column:0]
      setState:([[defaults objectForKey:@"fillObjects"]  isEqual:@"YES"]) ? 1 : 0];

    /* set hpgl popup */
    fillPopup(hpglPopup, HPGLPATH, @".dev", 0, NO);
    /* set popup button title from the cell having hpglParmsFileName as title */
    string = [defaults objectForKey:@"hpglParmsFileName"];
    for (i=[hpglPopup numberOfItems]-1;  i>0; i--)
       if ( [[hpglPopup itemTitleAtIndex:i] isEqual:string] )
            break;
    [hpglPopup selectItemAtIndex:i];
    [hpglPopup setTarget:self];				// set the target
    [hpglPopup setAction:@selector(set:)];		// set the action

    /* set gerber popup */
    fillPopup(gerberPopup, GERBERPATH, @".dev", 0, NO);
    /* set popup button title from the cell having gerberParmsFileName as title */
    string = [defaults objectForKey:@"gerberParmsFileName"];
    for (i=[gerberPopup numberOfItems]-1; i>0; i--)
       if ( [[gerberPopup itemTitleAtIndex:i] isEqual:string] )
            break;
    [gerberPopup selectItemAtIndex:i];
    [gerberPopup setTarget:self];			// set the target
    [gerberPopup setAction:@selector(set:)];		// set the action

    /* set DIN popup */
    fillPopup(dinPopup, DINPATH, @".dev", 1, NO);
    /* set popup button title from the cell having dinParmsFileName as title */
    string = [defaults objectForKey:@"dinParmsFileName"];
    for (i=[dinPopup numberOfItems]-1; i>0; i--)
       if ( [[dinPopup itemTitleAtIndex:i] isEqual:string] )
            break;
    [dinPopup selectItemAtIndex:i];
    [dinPopup setTarget:self];				// set the target
    [dinPopup setAction:@selector(set:)];		// set the action
}




- (void)set:sender;
{   NSString	*string, *title;
    int		ix;
    id		defaults = [NSUserDefaults standardUserDefaults];

    /* import colors to layers */
    string = ([[switchMatrix cellAtRow:SWITCH_COLORTOLAYER column:0] state]) ? @"YES" : @"NO";
    if ( ![string isEqual:[defaults objectForKey:@"colorToLayer"]] )
    	[defaults setObject:string forKey:@"colorToLayer"];

    /* fill objects after import (for HPGL, Gerber, DXF) */
    string = ([[switchMatrix cellAtRow:SWITCH_FILLOBJECTS column:0] state]) ? @"YES" : @"NO";
    if ( ![string isEqual:[defaults objectForKey:@"fillObjects"]] )
    	[defaults setObject:string forKey:@"fillObjects"];

    /* HPGL import device */
    title = [hpglPopup titleOfSelectedItem];
    [defaults setObject:title forKey:@"hpglParmsFileName"];

    /* Gerber import device */
    title =  [gerberPopup titleOfSelectedItem];
    [defaults setObject:title forKey:@"gerberParmsFileName"];

    /* DXF resolution */
    string = [NSString stringWithFloat:[dxfResField floatValue]];
    //string = [NSString stringWithFormat:@"%f", [dxfResField floatValue]];
    if ( ![string isEqual:[defaults objectForKey:@"dxfRes"]] )
        [defaults setObject:string forKey:@"dxfRes"];

    /* PS prefer arcs */
    string = ([psPreferArcsSwitch state]) ? @"YES" : @"NO";
    if ( ![string isEqual:[defaults objectForKey:@"psPreferArcs"]] )
    	[defaults setObject:string forKey:@"psPreferArcs"];

    /* PS flatten text */
    string = ([psFlattenTextSwitch state]) ? @"YES" : @"NO";
    if ( ![string isEqual:[defaults objectForKey:@"psFlattenText"]] )
        [defaults setObject:string forKey:@"psFlattenText"];

    /* DIN import device */
    ix = [dinPopup indexOfSelectedItem];
    title = [dinPopup titleOfSelectedItem];
    [defaults setObject:((!ix) ? (NSString*)@"" : title) forKey:@"dinParmsFileName"];
}

@end
