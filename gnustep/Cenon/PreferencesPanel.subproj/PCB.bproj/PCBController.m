/*
 * ExportController.m
 *
 * Copyright (C) 1996-2002 by vhf computer GmbH + vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * Created:  1999-03-15
 * Modified: 2002-07-01
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
 * created:  1999-03-15
 * modified: 2000-09-13
 * Initializes the defaults.
 */
+ (void)initialize
{   NSMutableDictionary	*registrationDict = [NSMutableDictionary dictionary];

    [[NSUserDefaults standardUserDefaults] registerDefaults:registrationDict];
}

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
    {   NSLog(@"Cannot load 'Export' model file");
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
{
}

- (void)set:sender;
{
}

@end
