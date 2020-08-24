/* Cenon_main.m
 * main function of Cenon
 *
 * Copyright (C) 1992-2011 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1992
 * modified: 2011-09-01 (GNUstep: just call NSApplicationMain())
 *           2011-08-29 (cenon.tiff -> Cenon.tiff)
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

int main(int argc, const char *argv[])
{
/*#ifdef GNUSTEP_BASE_VERSION
    NSDictionary        *infoDict;
    NSString            *className;
    Class               appClass;
    NSAutoreleasePool   *pool = [NSAutoreleasePool new];
    NSApplication       *app;

#   if LIB_FOUNDATION_LIBRARY
    extern char		**environ;

    [NSProcessInfo initializeWithArguments:(char**)argv
                                     count:argc environment:environ];
#   endif

#   ifndef NX_CURRENT_COMPILER_RELEASE
//    initialize_gnustep_backend();
#   endif

    infoDict = [[NSBundle mainBundle] infoDictionary];
    className = [infoDict objectForKey: @"NSPrincipalClass"];
    appClass = NSClassFromString(className);

    if (appClass == 0)
    {
        NSLog(@"Bad application class '%@' specified", className);
        appClass = [NSApplication class];
    }

    app = [appClass sharedApplication];
    [app setApplicationIconImage:[NSImage imageNamed:@"Cenon.tiff"]];
    if (![NSBundle loadNibNamed:@"Main" owner:app])
        NSLog(@"Cannot load Main interface file");

    [app run];
    [pool release];
    return 0;
#else*/
   return NSApplicationMain(argc, argv);
//#endif
}
