/* PreferencesPanel.m
 * Control class of preferences panel
 *
 * Copyright (C) 1996-2011 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * Created:  1999-03-15
 * Modified: 2011-09-13 (-update: new)
 *           2004-04-20
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

#include <VHFShared/types.h>
#include "PreferencesPanel.h"
#include "PreferencesMethods.h"
#include "../App.h"

@implementation PreferencesPanel

/*  located in App.m, because this is called too late !
+ (void)initialize
{   NSMutableDictionary	*registrationDict = [NSMutableDictionary dictionary];

    // General Preferences defaults
#ifdef __APPLE__
    [registrationDict setObject:@"NO" forKey:@"doCaching"];
#else
    [registrationDict setObject:@"YES" forKey:@"doCaching"];
#endif
    [registrationDict setObject:@"0" forKey:@"unit"];
    [registrationDict setObject:@"NO" forKey:@"removeBackups"];
    [registrationDict setObject:@"NO" forKey:@"expertMode"];
    [registrationDict setObject:@"0" forKey:@"snap"];
    [registrationDict setObject:@"." forKey:@"NSDecimalSeparator"];

    // Import preferences defaults
    [registrationDict removeAllObjects];
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

- init
{
    modules = [[NSMutableArray array] retain];
    [self loadModules];
    [self setModuleAt:0 orderFront:NO];

    return self;
}

/* load preferences modules
 * we allow prefs bundles in all loaded application modules: 'BUNDLE/Resources/NAME.prefs'
 */
- (void)loadModules
{   NSBundle        *mainBundle = [NSBundle mainBundle], *bundle;
    NSFileManager   *fileManager = [NSFileManager defaultManager];
    int             i, j;
    NSString        *path;
    NSArray         *appModules = [(App*)NSApp modules], *files;

    while ([iconMatrix numberOfColumns])
        [iconMatrix removeColumn:0];

    /* load basic modules first to have them ordered first */
    [self addBundleWithPath:[mainBundle pathForResource:@"General" ofType:@"prefs"]];
    [self addBundleWithPath:[mainBundle pathForResource:@"Import"  ofType:@"prefs"]];
    [self addBundleWithPath:[mainBundle pathForResource:@"Export"  ofType:@"prefs"]];

    /* load optional modules */
    for (i=0; i<(int)[appModules count]+1; i++)
    {
        if (!i)	// search inside main bundle
            bundle = mainBundle;
        else	// search inside loaded bundles
            bundle = [appModules objectAtIndex:i-1];

        path = [bundle resourcePath];
        files = [fileManager directoryContentsAtPath:path];
        for (j=0; j<(int)[files count]; j++)
        {   NSString	*file = [files objectAtIndex:j];

            if ([file hasSuffix:@".prefs"])
                [self addBundleWithPath:[path stringByAppendingPathComponent:file]];
        }
    }
}

- (void)addBundleWithPath:(NSString*)path
{   NSBundle	*bundle;
    Class       bundleClass;

    /* load bundle */
    bundle = [NSBundle bundleWithPath:path];
    bundleClass = [bundle principalClass];	// controller

    /* get controller class and add module to icon matrix */
    if ([bundleClass conformsToProtocol: @protocol(PreferencesMethods)])
    {   id <PreferencesMethods>	module = [bundleClass controller];
        int			ix;
        NSButtonCell		*cell;

        if ([modules containsObject:module])
            return;
        [modules addObject:module];
        [iconMatrix addColumn];
        ix = [iconMatrix numberOfColumns] - 1;
        cell = [iconMatrix cellAtRow:0 column:ix];

        [cell setTitle:[module name]];
        [cell setFont:[NSFont systemFontOfSize:10]];
        [cell setImage:[module icon]];

        [iconMatrix sizeToCells];
    }
}

/* select module
 */
- (void)setModule:(id)sender
{
    [self setModuleAt:Max(0, [iconMatrix selectedColumn]) orderFront:YES];
}

/* attention with the -init if it is not subclassed you will loss the window!
 */
- (void)setModuleAt:(int)ix orderFront:(BOOL)orderFront
{   id	module;	// module controller

    if (![modules count])
    {   NSLog(@"PreferencesPanel: No module found!");
        return;
    }

    //[activeWindow displayWillEnd];
    module = [modules objectAtIndex:ix];
    [(NSBox*)moduleView setContentView:[[module view] retain]];
    [moduleView setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
    [module update:self];
    [self display];
    [self flushWindow];

    if ( orderFront )
        [self orderFront:self];
}

- (void)update:sender
{   int i, mCnt = [modules count];

    for (i=0; i<mCnt; i++)
        [[modules objectAtIndex:i] update:sender];
}

@end
