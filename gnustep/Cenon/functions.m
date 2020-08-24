/* functions.m
 * Common Cenon functions
 *
 * Copyright (C) 1996-2012 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1996-01-25
 * modified: 2012-01-05 (NSMenuItem)
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
#include <VHFShared/types.h>
#include <VHFShared/vhfCommonFunctions.h>
#include <VHFShared/VHFDictionaryAdditions.h>
#include "functions.h"
#include "locations.h"

/* return library paths
 * modified: 2008-02-28
 */
NSString *localLibrary(void)
{
#   if defined(GNUSTEP_BASE_VERSION) || defined(__APPLE__)
    NSFileManager	*fileManager = [NSFileManager defaultManager];
    NSString		*lPath, *sPath;

    /* we return the local path or the system path, whichever exists - local has priority */
    /* "/Library/Application Support/Cenon" */
    lPath = vhfPathWithPathComponents(
            [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSLocalDomainMask, YES) objectAtIndex:0],
            @"Application Support", APPNAME, nil);
    if ( lPath && [fileManager fileExistsAtPath:lPath] )
        return lPath;
    /* "/Library/Cenon" (Default) */
    lPath = [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSLocalDomainMask, YES) objectAtIndex:0]
             stringByAppendingPathComponent:APPNAME];
    if ( lPath && [fileManager fileExistsAtPath:lPath] )
        return lPath;
    /* "/System/Library/Cenon" */
    sPath = [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSSystemDomainMask, YES) objectAtIndex:0]
             stringByAppendingPathComponent:APPNAME];
    if ( sPath && [fileManager fileExistsAtPath:sPath] )
        return sPath;
    return lPath;
#   else
    return LOCALLIBRARY;
#   endif
}
NSString *userLibrary(void)
{
#   if defined(GNUSTEP_BASE_VERSION) || defined(__APPLE__)
    NSFileManager	*fileManager = [NSFileManager defaultManager];
    NSString		*lPath;

    /* "Library/Application Support/Cenon" */
    lPath = vhfPathWithPathComponents(
            [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0],
            @"Application Support", APPNAME, nil);
    if ( lPath && [fileManager fileExistsAtPath:lPath] )
        return lPath;
    /* "Library/Cenon" (Default) */
    return [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0]
            stringByAppendingPathComponent:APPNAME];
#   else
    return vhfPathWithPathComponents(NSHomeDirectory(), HOMELIBRARY, nil);
#   endif
}

NSString *localBundlePath(void)
{
#   if defined(GNUSTEP_BASE_VERSION) || defined(__APPLE__)
    return [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSLocalDomainMask, YES) objectAtIndex:0]
            stringByAppendingPathComponent:BUNDLEFOLDER];
#   else
    return vhfPathWithPathComponents(@"/LocalLibrary", BUNDLEFOLDER, nil);
#   endif
}
NSString *systemBundlePath(void)
{
#   if defined(__APPLE__)
    return nil; // we don't have any business here
#   elif defined(GNUSTEP_BASE_VERSION)
    return [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSSystemDomainMask, YES) objectAtIndex:0]
            stringByAppendingPathComponent:BUNDLEFOLDER];
#   else	// OpenStep
    return vhfPathWithPathComponents(@"/NextLibrary", BUNDLEFOLDER, nil);
#   endif
}
NSString *userBundlePath(void)
{
#   if defined(GNUSTEP_BASE_VERSION) || defined(__APPLE__)
    return [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0]
            stringByAppendingPathComponent:BUNDLEFOLDER];
#   else
    return vhfPathWithPathComponents(NSHomeDirectory(), @"Library", BUNDLEFOLDER, nil);
#   endif
}

/*
 * fill the device popup 'devicePopup' with menu cells
 * containing all devices ".dev" inside the appropriate folder ("Devices/xyz").
 * Search the folder 'path' in all library directories.
 *
 * begin:    1993-01-17
 * modified: 2012-03-09 (sub-folders, clean-up, don't add directories with extension)
 *           2005-11-16 (appendPathComponent)
 *
 * popup	the popup button
 * folder	the folder
 * ext 		the extension of the files
 * removeIx     the index of the first item of the popuplist to be removed
 */
void fillPopup(NSPopUpButton *popup, NSString *folder, NSString *ext, int removeIx, BOOL searchSubFolders)
{   NSString        *path;
    int             i, j, selectedIx = [popup indexOfSelectedItem];
    NSFileManager   *fileManager = [NSFileManager defaultManager];

    if (!folder)
    {	[popup setEnabled:NO];
        return;
    }

    /* remove entries from popup list, but keep items before removeIx */
    if (removeIx == 0)
        [popup removeAllItems];
    else
        while ( [popup numberOfItems] > removeIx )
            [popup removeItemAtIndex:[popup numberOfItems]-1];

    /* search the files in several directories
     * add devices in these folders to popup list
     */
    for (i=0; i < 3 ;i++)
    {	NSArray *array;

        switch ( i )
        {
            case 0: // 1. application bundle
                path = [[NSBundle mainBundle] resourcePath]; break;
            case 1: // 2. local library
                path = localLibrary(); break;
            case 2: // 3. user local library
                path = userLibrary();  break;
            default:
                path = nil;
        }
        if ( ! path )
            break;
        path = [path stringByAppendingPathComponent:folder];

        array = [fileManager directoryContentsAtPath:path];
        for ( j = [array count]-1; j >= 0; j-- )
        {   NSString	*name = [array objectAtIndex:j];
            NSString    *filePath = [path stringByAppendingPathComponent:name];
            BOOL        isDir;

            /* A. files directly in folder */
            if ( [fileManager fileExistsAtPath:filePath isDirectory:&isDir] && !isDir )
            {
                if ( [name hasSuffix:ext] )
                {   NSString *title;

                    title = [name substringToIndex:[name rangeOfString:ext].location];
                    if ([popup indexOfItemWithTitle:title] < 0)
                        [popup addItemWithTitle:title];
                }
            }
            /* B. files in sub-folders */
            else if ( searchSubFolders )    // sub-folder
            {   NSString    *subpath = vhfPathWithPathComponents(path, name, nil);
                NSArray     *subArray = [fileManager directoryContentsAtPath:subpath];
                int         s;

                for ( s = [subArray count]-1; s >= 0; s-- )
                {   NSString	*subName = [subArray objectAtIndex:s];
                    NSString    *filePath = [subpath stringByAppendingPathComponent:subName];

                    if ( [subName hasSuffix:ext] &&
                        [fileManager fileExistsAtPath:filePath isDirectory:&isDir] && !isDir )
                    {   NSString *title;

                        title = [subName substringToIndex:[subName rangeOfString:ext].location];
                        if ([popup indexOfItemWithTitle:title] < 0)
                            [popup addItemWithTitle:title];
                    }
                }
            }
        }
    }
    sortPopup( popup, removeIx );

    /* enable popup list when having any entries */
    [popup setEnabled:([popup numberOfItems]) ? YES : NO];
    if ( [popup numberOfItems] > selectedIx )
        [popup selectItemAtIndex:selectedIx];
}

BOOL vhfUpdateMenuItem(NSMenuItem *menuItem, NSString *zeroItem, NSString *oneItem, BOOL state)
{
    if (state)
    {
        if ([menuItem tag] != 0)
        {
            [menuItem setTitleWithMnemonic:zeroItem];
            [menuItem setTag:0];
            [menuItem setEnabled:NO];	// causes it to get redrawn
        }
    }
    else if ([menuItem tag] != 1)
    {
        [menuItem setTitleWithMnemonic:oneItem];
        [menuItem setTag:1];
        [menuItem setEnabled:NO];	// causes it to get redrawn
    }
    return YES;
}

NSDictionary *dictionaryFromFolder(NSString *folder, NSString *name)
{   NSDictionary	*dict;
    int			i;

    for (i=0;  ;i++)
    {   NSString	*path;

        if (!i)		// application resource directory
            path = [[NSBundle mainBundle] resourcePath];
        else if (i==1)	// local library
            path = localLibrary();
        else if (i==2)	// user local library
            path = userLibrary();
        else
            break;
        path = vhfPathWithPathComponents(path, folder, name, nil);

        if ( (dict = [NSDictionary dictionaryWithContentsOfFile:path]) )
            return dict;
    }

    return nil;
}


/* DEPRECATED: use [document convertToUnit:uValue]
 * converts a value from internal unit (1/72 inch) to the current unit
 */
float convertToUnit(float value)
{
    switch ( [[NSUserDefaults standardUserDefaults] integerForKey:@"unit"] )
    {
        case UNIT_MM:		return (value*25.4/72.0);
        case UNIT_INCH:		return (value / 72.0);
        case UNIT_POINT:	return value;
    }
    return value;
}

/* DEPRECATED: use [document convertFrUnit:iValue]
 * converts a value from the current unit to internal unit (1/72 inch)
 */
float convertFromUnit(float value)
{
    switch ( [[NSUserDefaults standardUserDefaults] integerForKey:@"unit"] )
    {
        case UNIT_MM:		return (value/25.4*72.0);
        case UNIT_INCH:		return (value * 72.0);
        case UNIT_POINT:	return value;
    }
    return value;
}

/* DEPRECATED: use [document convertMMToUnit:mmValue]
 * converts a value from mm to the current unit
 */
float convertMMToUnit(float value)
{
    switch ( [[NSUserDefaults standardUserDefaults] integerForKey:@"unit"] )
    {
        case UNIT_MM:		return value;
        case UNIT_INCH:		return value / 25.4;
        case UNIT_POINT:	return value*72.0/25.4;
    }
    return value;
}

/* DEPRECATED: use [document convertUnitToMM:uValue]
 * converts a value from the current unit to mm
 */
float convertUnitToMM(float value)
{
    switch ( [[NSUserDefaults standardUserDefaults] integerForKey:@"unit"] )
    {
        case UNIT_MM:		return value;
        case UNIT_INCH:		return value * 25.4;
        case UNIT_POINT:	return value/72.0*25.4;
    }
    return value;
}

/* color/string functions
 */
NSString *vhfStringFromRGBColor(NSColor *color)
{
    if (![[color colorSpaceName] isEqualToString:NSCalibratedRGBColorSpace])
        color = [color colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
    return [NSString stringWithFormat:@"%.3f %.3f %.3f", [color redComponent], [color greenComponent], [color blueComponent]];
}
NSColor *vhfRGBColorFromString(NSString *string)
{   NSScanner	*scanner;
    float	r, g, b;

    if (!string)
    {   NSLog(@"vhfRGBColorFromString(): string != nil expected !");
        return nil;
    }
    scanner = [NSScanner scannerWithString:string];
    [scanner scanFloat:&r];
    [scanner scanFloat:&g];
    [scanner scanFloat:&b];
    return [NSColor colorWithCalibratedRed:r green:g blue:b alpha:1.0];
}
