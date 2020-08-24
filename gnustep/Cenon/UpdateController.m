/* UpdateController.m
 * Checking for Updates...
 *
 * Copyright 2010-2012 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  2010-05-27
 * modified: 2012-02-07 (-connectionDidFinishLoading: use -writeToFile:...encoding:error:)
 *           2011-03-30 (-checkForUpdates: test for Prefs_DisableAutoUpdate)
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
 * eMail: service@vhf.de
 * http://www.vhf-interservice.com
 */

#include <AppKit/AppKit.h>
#include "UpdateController.h"
#include "App.h"
#include "locations.h"
#include "messages.h"
#include "CenonModuleMethods.h"
#include "PreferencesMacros.h"  // Prefs_DisableAutoUpdate
#include <VHFShared/VHFStringAdditions.h>       // -writeToFile:...

static UpdateController *sharedInstance = nil;  // default object
static NSString         *checkMarkStr = nil;    // the checkmark

@interface UpdateController(PrivateMethods)
- (void)loadPanel:sender;
@end
@interface UpdateTableData:NSObject
{
    NSMutableDictionary *dataDict;
    int                 rowCount;
}
/* class methods */
+ (UpdateTableData*)tableData;
- (int)numberOfRowsInTableView:(NSTableView*)table;
- (id)tableView:(NSTableView*)table objectValueForTableColumn:(NSTableColumn*)column
            row:(int)rowIndex;
- (void)setDataDict:(NSDictionary*)newDataDict;
- (NSDictionary*)dataDict;
@end

@interface NSFileManager(UpdateControllerMethods)
- (BOOL)fileExistsAtWildcardPath:(NSString*)path;
@end
@implementation NSFileManager(UpdateControllerMethods)
- (BOOL)fileExistsAtWildcardPath:(NSString*)path
{   NSString    *wildcard = [path lastPathComponent];
    NSArray     *array;
    int         i, cnt, j;
    NSArray     *components = [wildcard componentsSeparatedByString:@"*"];

    if ( [components count] == 1 )
        return [self fileExistsAtPath:path];
    path = [path stringByDeletingLastPathComponent];
    if ( !(array = [self directoryContentsAtPath:path]) || ![components count] )
        return NO;
    for ( i=0, cnt = [array count]; i<cnt; i++ )
    {   NSString    *file = [array objectAtIndex:i];
        NSRange     searchRange = NSMakeRange(0, [file length]);
        BOOL        hit = YES;

        for ( j=0; j<[components count]; j++ )
        {   NSString    *compo = [components objectAtIndex:j];
            NSRange     range;

            if ( ![compo length] )
                continue;
            if ( (range = [file rangeOfString:compo options:0 range:searchRange]).length )
            {   searchRange.location = range.location + range.length;
                searchRange.length   = [file length] - searchRange.location;
            }
            else
            {   hit = NO; break; }
        }
        if ( hit )
            return YES;
    }
    return NO;
}
@end

/*#ifndef MAC_OS_X_VERSION_10_6
#define MAC_OS_X_VERSION_10_6 1060
#endif*/
//#if defined(__APPLE__) && MACOSX_DEPLOYMENT_TARGET <= MAC_OS_X_VERSION_10_6
/* available OSX >= 10.6, not on GNUstep yet (2010-09-20) */
@interface NSWorkspace(UpdateControllerMethods)
- (void)activateFileViewerSelectingURLs:(NSArray*)fileURLs;
@end


@implementation UpdateController

+ (UpdateController*)sharedInstance
{
    if (!sharedInstance)
        sharedInstance = [self new];
    return sharedInstance;
}
- (id)init
{   char    checkMarkChars[4] = {0xE2, 0x9C, 0x93, 0};  // unicode

    [super init];
    checkMarkStr = [[NSString stringWithUTF8String:checkMarkChars] retain];
    updateDict   = nil;
    [self loadPanel:self];  // this loads the interface and has to come first
    return self;
}

/* show panel
 * load interface file and display panel
 */
- (void)loadPanel:sender
{
    if ( !panel )
    {   NSBundle	*bundle = [NSBundle mainBundle];

        /* load panel, this establishes connections to interface outputs */
        if ( ![bundle loadNibFile:@"UpdatePanel"
                externalNameTable:[NSDictionary dictionaryWithObject:self forKey:@"NSOwner"]
                         withZone:[self zone]] )
            NSLog(@"Cannot load Update Panel interface file");
        [panel setDelegate:self];
        [panel setFrameUsingName:@"UpdatePanel"];
        [panel setFrameAutosaveName:@"UpdatePanel"];
        
        [tableView setDelegate:self];
        [tableView setTarget:self];
        [tableView setAction:@selector(tableClick:)];
        //[tableView setDoubleAction:@selector(doubleClick:)];
    }
}

/* return Dictionary with installed modules and it's versions
 */
- (NSDictionary*)installedModules
{   NSMutableDictionary *installedDict = [NSMutableDictionary dictionary];
    NSArray             *modules = [(App*)NSApp modules];
    int                 i;

    for ( i=0; i<[modules count]; i++ ) // modules
    {   NSBundle        *bundle = [modules objectAtIndex:i]; // our loaded modules
        NSDictionary    *infoDict = [bundle infoDictionary];
        NSString        *version = [infoDict objectForKey:@"CFBundleVersion"];
        NSString        *name    = [infoDict objectForKey:@"CFBundleExecutable"];   // CAM, Astro, AstroFractal
        NSString        *date    = nil, *serial = nil, *netId = nil;

        if ( [[[bundle principalClass] instance] respondsToSelector:@selector(compileDate)] )
            date = [[[bundle principalClass] instance] compileDate];
        if ( [[[bundle principalClass] instance] respondsToSelector:@selector(serialNo)] )
            serial = [[[bundle principalClass] instance] serialNo];
        if ( [[[bundle principalClass] instance] respondsToSelector:@selector(netId)] )
            netId = [[[bundle principalClass] instance] netId];
        [installedDict setObject:[NSArray arrayWithObjects:version, (date) ? date : @"",
                                  (serial) ? serial : @"", (netId) ? netId : @"", nil]
                          forKey:name];
        if ( !isAutoCheck )
            printf("Installed Modules: %s = %s (%s) %s %s\n", [name UTF8String], [version UTF8String],
               (date) ? [date UTF8String] : "", (serial) ? [serial UTF8String] : "",
               (netId) ? [netId UTF8String] : "");
    }
    return installedDict;
}

/* tries to download update.plist from vhf server
 */
- (void)checkForUpdates:sender
{   NSDictionary    *installedModules;
    NSArray         *keys;
    NSURLRequest    *connectionRequest;
    NSMutableString *urlStr = [NSMutableString string];
    NSString        *appVersion = [(App*)NSApp version];        // 3.9.2
    NSString        *appDate    = [(App*)NSApp compileDate];    // 2010-06-28
    NSUserDefaults  *userDefaults = [NSUserDefaults standardUserDefaults];
    NSString        *skipVersion     = [userDefaults objectForKey:@"skipUpdateVersion"];
    NSDate          *lastUpdateCheck = [userDefaults objectForKey:@"lastUpdateCheck"];
    int             i;

    isAutoCheck = ([sender isKindOfClass:[NSMenuItem class]]) ? NO : YES;
    if ( isAutoCheck && Prefs_DisableAutoUpdate )
        return; // automatic check is disabled in preferences
    if ( isAutoCheck && lastUpdateCheck &&
         [[NSDate date] timeIntervalSinceDate:lastUpdateCheck] < 3600*24*7 )
        return; // not yet one week -> no check

    installedModules = [self installedModules];
    [urlStr appendString:@"http://www.cenon.info/cgi-bin/updateCenon"];
    [urlStr appendFormat:@"?n=%@&v=%@&d=%@", APPNAME, appVersion, appDate];
    if ( [skipVersion length] ) // version the user wants to skip
        [urlStr appendFormat:@"&sk=%@", skipVersion];
    //[urlStr appenFormat:@"&p="];    // TODO: pass plattform to update script
    for (keys = [installedModules allKeys], i=0; i < [keys count]; i++)
    {   int         n = i+1;
        NSString    *name = [keys objectAtIndex:i];
        NSArray     *array = [installedModules objectForKey:name];
        NSString    *version = [array objectAtIndex:0];
        NSString    *date    = [array objectAtIndex:1];
        NSString    *serial  = [array objectAtIndex:2];
        NSString    *netId   = [array objectAtIndex:3];

        [urlStr appendFormat:@"&n%d=%@", n, name];
        if ( [version length] ) [urlStr appendFormat:@"&v%d=%@", n, version];
        if ( [date    length] ) [urlStr appendFormat:@"&d%d=%@", n, date];
        if ( [serial  length] ) [urlStr appendFormat:@"&s%d=%@", n, serial];
        if ( [netId   length] ) [urlStr appendFormat:@"&o%d=%@", n, netId];     // origin
    }
    connectionRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:urlStr]
                                         cachePolicy:NSURLRequestReloadIgnoringCacheData
                                     timeoutInterval:60.0];
    urlConnection = [[NSURLConnection alloc] initWithRequest:connectionRequest delegate:self];
    if ( urlConnection )
    {   connectionData = [[NSMutableData alloc] init];
        [progressTitleText setStringValue:@""];
        [progressNameText setStringValue:@""];
        [progressSizeText setStringValue:@""];
        [progressIndicator setIndeterminate:YES];
        [progressIndicator startAnimation:nil];
        [progressPanel makeKeyAndOrderFront:self];
        [userDefaults setObject:[NSDate date] forKey:@"lastUpdateCheck"];   // date of this check
    }
#if 0   // this downloads a plist file directly (what, if it ends up in a proxy ?)
    NSURL           *url = [NSURL URLWithString:@"http://www.cenon.info/update/update.plist"];
    NSString        *path = vhfPathWithPathComponents(vhfUserLibrary(APPNAME), @".update.plist", nil);
    NSURLRequest    *request;
    NSURLDownload   *download;

    if ( checking || pkgDownload )
        return;
    checking = YES;
    request = [NSURLRequest requestWithURL:url];
    download = [[NSURLDownload alloc] initWithRequest:request delegate:self];
    if ( [sender isKindOfClass:[NSMenuItem class]] )    // we remove the skipped version
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"skipUpdateVersion"];
    [download setDeletesFileUponFailure:YES];
    [download setDestination:path allowOverwrite:YES];
#endif
}

/* check for available updates, if available display panel
 * created:  2010-05-27
 * modified: 2011-02-22 (don't offer update of uninstalled versions)
 * FIXME: this will not work with GNUstep, we need to access the infoDict correctly or add Apple info
 */
- (void)checkForUpdateAndDisplayPanel
{   static NSString     *infoString = nil;  // used to memorize infoLabel
    NSMutableDictionary *dataDict = [NSMutableDictionary dictionary];
    NSArray             *modules = [(App*)NSApp modules], *instKeys, *updateKeys;
    NSDictionary        *infoDict = [[NSBundle mainBundle] infoDictionary];
    NSString            *appVersion = [(App*)NSApp version];                            // "3.9.2"
    NSString            *appName    = [infoDict objectForKey:@"CFBundleExecutable"];    // Cenon, APPNAME
    NSString            *appDate    = [(App*)NSApp compileDate];
    NSMutableDictionary *installedDict = [NSMutableDictionary dictionary];
    NSMutableArray      *checkOrder = [NSMutableArray array];
    int                 i, j;
    NSString            *updateFile;
    NSString            *skipVersion = [[NSUserDefaults standardUserDefaults] objectForKey:@"skipUpdateVersion"];
    NSString            *newVersion;
    BOOL                updateAvailable = NO;
    NSFileManager       *fileManager = [NSFileManager defaultManager];

    [installButton setEnabled:NO];

    /* Update.plist */
    updateFile = vhfPathWithPathComponents(vhfUserLibrary(APPNAME), @".update.plist", nil);
    if ( updateDict )
        [updateDict release];
    updateDict = [[NSDictionary dictionaryWithContentsOfFile:updateFile] retain];
    updateKeys = [updateDict allKeys];
    newVersion = [[updateDict objectForKey:appName] objectForKey:@"v"];
    if ( isAutoCheck && newVersion && skipVersion && [newVersion isEqual:skipVersion] )
        return;

    /* Installed versions of App, Modules, Fonts, etc. */
    if ( !appName )
        appName = APPNAME;
    //infoVersion = [[(App*)NSApp infoVersionNo] stringValue];    // ex: 3.9.1 pre 1 (2010-02-13)
    [installedDict setObject:[NSArray arrayWithObjects:appVersion, appDate, nil] forKey:appName];
    [checkOrder addObject:appName];
    if ( !isAutoCheck )
        printf("Installed App:     %s = %s (%s)\n", [appName UTF8String], [appVersion UTF8String], [appDate UTF8String]);
    // FIXME: this is basically duplicating -installedModules and should be united
    for ( i=0; i<[modules count]; i++ ) // modules
    {   NSBundle        *bundle = [modules objectAtIndex:i]; // our loaded modules
        NSDictionary    *infoDict = [bundle infoDictionary];
        NSString        *version = [infoDict objectForKey:@"CFBundleVersion"];
        NSString        *name    = [infoDict objectForKey:@"CFBundleExecutable"];   // CAM, Astro, AstroFractal
        NSString        *date    = nil;

        if ( [[[bundle principalClass] instance] respondsToSelector:@selector(compileDate)] )
            date = [[[bundle principalClass] instance] compileDate];
        [installedDict setObject:[NSArray arrayWithObjects:version, date, nil] forKey:name];
        [checkOrder addObject:name];
        //if ( !isAutoCheck )
        //    printf("Installed Modules: %s = %s (%s)\n", [name UTF8String], [version UTF8String], (date) ? [date UTF8String] : "");
    }
    if ( [updateDict objectForKey:@"order"] )
        checkOrder = [updateDict objectForKey:@"order"];
    /* Check for install paths of additional items given in update.plist and add their versions etc. */
    for ( i=0; i<[updateKeys count]; i++ )
    {   NSString        *key = [updateKeys objectAtIndex:i], *path, *pathU = nil;
        NSDictionary    *uDict = [updateDict objectForKey:key];

        if ( ![uDict isKindOfClass:[NSDictionary class]] || !(path = [uDict objectForKey:@"c"]) )
            continue;
        if ( ! [path isAbsolutePath] )
        {   pathU = vhfPathWithPathComponents(NSHomeDirectory(),         path, nil);
            path  = vhfPathWithPathComponents(NSOpenStepRootDirectory(), path, nil);
        }
        if (           [fileManager fileExistsAtWildcardPath:path] ||
             (pathU && [fileManager fileExistsAtWildcardPath:pathU]) )
        {   NSString    *version = [uDict objectForKey:@"v"];   // TODO: version of additional installed stuff
            NSString    *date    = nil;                         // TODO: date of stuff
            [installedDict setObject:[NSArray arrayWithObjects:version, date, nil] forKey:key];
        }
    }
    instKeys = [installedDict allKeys];

    [dataDict setObject:[NSMutableArray array] forKey:@"install"];
    [dataDict setObject:[NSMutableArray array] forKey:@"name"];
    [dataDict setObject:[NSMutableArray array] forKey:@"version"];
    [dataDict setObject:[NSMutableArray array] forKey:@"size"];
    [dataDict setObject:[NSMutableArray array] forKey:@"price"];
    [dataDict setObject:[NSMutableArray array] forKey:@"updateKey"];    // our key to find way back
    [dataDict setObject:[NSMutableArray array] forKey:@"url"];          // download link

    /* Compare available updates with installed versions */
    for ( i=0; i<[checkOrder count]; i++ )  // CAM, AstroFractal, Astro, Cenon
    {   NSString        *key = [checkOrder objectAtIndex:i];
        NSDictionary    *uDict  = [updateDict objectForKey:key];    // v, s, l, i, n, r, d
        NSArray         *iArray = [installedDict objectForKey:key];
        NSString        *version  = [uDict objectForKey:@"v"];      // package version
        NSString        *mVersion = [uDict objectForKey:@"mv"];     // module version
        NSString        *name     = [uDict objectForKey:@"n"];
        NSString        *size     = [uDict objectForKey:@"s"], *price, *url;
        BOOL            installModule = NO; // install complete package or module ?

        if ( ! version || ! name )
            continue;
        /* is item eclipsed in rel "r" (ex: Cenon+Module.pkg eclipses Cenon.pkg alone) ? */
        {   BOOL    eclipsed = NO;

            for ( j=0; j<[instKeys count]; j++ )    // all installed stuff can eclipse
            {   NSString        *instKey = [instKeys objectAtIndex:j];
                NSDictionary    *uDictI = [updateDict objectForKey:instKey];
                NSArray         *relArray;
                int             k;

                if ( ![uDictI isKindOfClass:[NSDictionary class]] )
                    continue;
                relArray = [uDictI objectForKey:@"r"];
                for (k=0; k<[relArray count]; k++ ) // it's relationships: "-" will eclipse
                {   NSString    *relKey = [relArray objectAtIndex:k];

                    if ( ! [relKey hasPrefix:@"-"] )
                        continue;
                    relKey = [relKey substringFromIndex:1];
                    if ( [key isEqual:relKey]  )    // key eclipsed from relations of installed item
                    {   eclipsed = YES; break; }    // eclipsed
                }
                if (eclipsed)
                    break;
            }
            if ( eclipsed )
                continue;
        }

        /* compare installed versions with available updates */
        if ( iArray )   // installed item
        {   NSString    *v = (mVersion) ? mVersion : version;   // we compile module version

            if ( [v appearanceCountOfCharacter:'.'] <= 1 )  // workaround for single dot version numbers "1.11" -> "1.1.1"
                v = @"0.0.0"; // this is old anyway
            if ( [[iArray objectAtIndex:0] compare:(id)v options:NSNumericSearch] == NSOrderedAscending )   // installed < version
                updateAvailable = YES;
            // TODO: if version is the same, compare date
            else    // installed >= version
                continue;
        }
        else    // 2011-02-22: not installed -> we don't offer item for installation
            continue;

        /* check, wether to install module instead of Package (ex: CenonCAM + Astro-Module) */
        url = ([uDict objectForKey:@"d"]) ? [uDict objectForKey:@"d"] : @"";
        if ( mVersion && [uDict objectForKey:@"ms"] && [uDict objectForKey:@"md"] )
        {
            for ( j=0; j<[instKeys count]; j++ )    // all installed stuff
            {   NSString        *instKey = [instKeys objectAtIndex:j];
                NSDictionary    *uDictI = [updateDict objectForKey:instKey];

                if ( ![uDictI isKindOfClass:[NSDictionary class]] )
                    continue;
                /* if something is installed, then we installed a Cenon-Package already */
                if ( [(NSArray*)[dataDict objectForKey:@"updateKey"] count] )
                {   installModule = YES;
                    url = [uDict objectForKey:@"md"];
                    version = mVersion;
                    size    = [uDict objectForKey:@"ms"];
                    break;
                }
            }
        }

        /* Add item */
        if ( [url length] )
            [installButton setEnabled:YES]; // enable install button, if something is there to install
        [[dataDict objectForKey:@"install"]   addObject:([url length]) ? @"1" : @"0"];
        [[dataDict objectForKey:@"name"]      addObject:name];  // name
        [[dataDict objectForKey:@"size"]      addObject:(size) ? size : @""];
        [[dataDict objectForKey:@"updateKey"] addObject:key];   // key for reference
        [[dataDict objectForKey:@"url"]       addObject:url];
        /* License or Price */
        if ( [[uDict objectForKey:@"l"] hasPrefix:@"f"] )       // price or free
            price = NSLocalizedString(@"free", NULL);
        else
        {   NSDictionary    *priceDict = [uDict objectForKey:@"p"];

            price = nil;
            if ( priceDict )
            {   //NSString    *v = ([uDict objectForKey:@"mv"]) ? [uDict objectForKey:@"mv"] : version;
                NSString    *v = ([iArray count]) ? [iArray objectAtIndex:0] : appVersion;  // version of installed module
                NSRange     range = [v rangeOfString:@"." options:NSBackwardsSearch];

                if ( range.length )
                {   NSString    *vMajor = [v substringToIndex:range.location]; // "3.9", "1.1"

                    if ( iArray )   // installed
                    {   price = [priceDict objectForKey:vMajor];
                        if ( [price isEqual:@"0.0"] )
                            price = NSLocalizedString(@"free", NULL);
                    }
                    else            // not installed (2011-02-22)
                        price = [priceDict objectForKey:@"0"];
                }
            }
            if ( !price )
                price = @"";
        }
        [[dataDict objectForKey:@"price"]     addObject:price];
        if ( ! installModule && [uDict objectForKey:@"mv"] )    // version
            version = [version stringByAppendingFormat:@" (%@)", [uDict objectForKey:@"mv"]];
        [[dataDict objectForKey:@"version"]   addObject:version];
    }


    /* Add additional items for installed items (Fonts, Ephemeris, ...)
     */
    for ( i=0; i<[(NSArray*)[dataDict objectForKey:@"updateKey"] count]; i++ )
    {   NSString        *key = [[dataDict objectForKey:@"updateKey"] objectAtIndex:i];
        NSDictionary    *uDict  = [updateDict objectForKey:key];    // v, s, l, i, n, r
        NSArray         *relArray = [uDict objectForKey:@"r"];

        for ( j=0; j<[relArray count]; j++ )
        {   NSString        *key = [relArray objectAtIndex:j];
            NSDictionary    *uDictR = [updateDict objectForKey:key];
            NSString        *name    = [uDictR objectForKey:@"n"];
            NSString        *size    = [uDictR objectForKey:@"s"];
            NSString        *version = [uDictR objectForKey:@"v"], *price;
            NSString        *url = ([uDictR objectForKey:@"d"]) ? [uDictR objectForKey:@"d"] : @"";
            NSArray         *iArray;

            if ( [[dataDict objectForKey:@"updateKey"] containsObject:key]
                 || !name || !version )
                continue;
            /* check available version against installed stuff */
            iArray = [installedDict objectForKey:key];
            if ( [instKeys containsObject:key] &&
                 ([iArray count] && [[iArray objectAtIndex:0] compare:(id)version options:NSNumericSearch] != NSOrderedAscending) )
                continue;   // installed and up to date
            /* compare installed versions with available updates */
            if ( iArray )   // installed item
            {
                if ( [[iArray objectAtIndex:0] compare:(id)version options:NSNumericSearch] == NSOrderedAscending ) // version > installed
                    updateAvailable = YES;
            }
            [[dataDict objectForKey:@"install"]   addObject:@"0"];
            [[dataDict objectForKey:@"name"]      addObject:name];
            [[dataDict objectForKey:@"version"]   addObject:version];
            [[dataDict objectForKey:@"size"]      addObject:(size) ? size : @""];
            [[dataDict objectForKey:@"updateKey"] addObject:key];
            [[dataDict objectForKey:@"url"]       addObject:url];
            if ( [[uDictR objectForKey:@"l"] hasPrefix:@"f"] )
                price = NSLocalizedString(@"free", NULL);
            else
            {   //NSDictionary    *priceDict = [uDictR objectForKey:@"p"];

                price = nil;
                /*if ( priceDict )  // TODO: prices for additional stuff
                {   NSString    *v = ([uDict objectForKey:@"mv"]) ? [uDict objectForKey:@"mv"] : version;
                    NSRange     range = [v rangeOfString:@"." options:NSBackwardsSearch];

                    if ( range.length )
                    {   NSString    *vMajor = [v substringToIndex:range.location]; // "3.9", "1.1"
                        price = [priceDict objectForKey:vMajor];
                    }
                }*/
                if ( !price )
                    price = @"";
            }
            [[dataDict objectForKey:@"price"]     addObject:price];
        }
    }

    if ( !tableData )
        tableData = [UpdateTableData new];
    [tableData setDataDict:dataDict];

    //[self loadPanel:self];  // this loads the interface and has to come first

    /* update title and info labels */
    if ( updateAvailable )
    {
        [titleLabel setStringValue:NSLocalizedString(@"A new version of Cenon is available", NULL)];
        if ( !infoString )
            infoString = [[infoLabel stringValue] retain];
        if ( newVersion )
        {   NSString    *str = [infoString stringByReplacing:@"V_NEW" by:newVersion all:NO];
            str = [str stringByReplacing:@"V_INST" by:appVersion all:NO];
            [infoLabel setStringValue:str];
        }
        else
            [infoLabel setStringValue:@""];
    }
    else
    {   [titleLabel setStringValue:NSLocalizedString(@"Cenon is up to date", NULL)];
        if ( !infoString )
            infoString = [[infoLabel stringValue] retain];
        [infoLabel  setStringValue:@""];
    }

    [tableView setDataSource:tableData];
    [tableView reloadData];
    if ( updateAvailable )
        [tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];

    if ( [updateFile hasSuffix:@"update.plist"] )
        [[NSFileManager defaultManager] removeFileAtPath:updateFile handler:nil];   // <= 10.5
        //[[NSFileManager defaultManager] removeItemAtPath:updateFile error:NULL];  // >= 10.6

    if ( updateAvailable || !isAutoCheck )  // only display panel if update is available or manual
        [panel makeKeyAndOrderFront:self];
}

/* Action methods
 * We collect the files that we have to download and start downloading the first one.
 * When the 1st file finished, -downloadDidFinish: continues with the other files.
 */
- (void)install:sender
{   int             i;
    NSDictionary    *dataDict = [tableData dataDict];
    NSArray         *keys = [dataDict objectForKey:@"updateKey"];

    /* determine number of files to download */
    [downloadFiles release];
    downloadFiles = [[NSMutableArray array] retain];
    for ( i=0, fileCnt=0; i < [keys count]; i++ )
    {
        if ( [[[dataDict objectForKey:@"install"] objectAtIndex:i] intValue] )
        {   NSString    *urlStr = [[dataDict objectForKey:@"url"] objectAtIndex:i];

            /* start download of file */
            if ( [urlStr length] )
            {   NSURL       *url = [NSURL URLWithString:urlStr];
                NSString    *fileName = [urlStr lastPathComponent], *path = nil;
                NSArray     *array = nil;

#ifdef __APPLE__
                if (NSAppKitVersionNumber >= NSAppKitVersionNumber10_5)
                    array = NSSearchPathForDirectoriesInDomains(15/*NSDownloadsDirectory*/, NSUserDomainMask, YES);
                if ( ![array count] && NSAppKitVersionNumber >= NSAppKitVersionNumber10_4)
                    array = NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES);
#endif
                if ( array && [array count] )   // 1. $HOME/Downloads/PACKAGE
                    path = [[array objectAtIndex:0] stringByAppendingPathComponent:fileName];
                if ( !path )                    // 2. /var/folders/8L/.../-Tmp-/PACKAGE
                    path = vhfPathWithPathComponents(NSTemporaryDirectory(), fileName, nil);   // this is a nonsense folder: "/var/folders/8L/arg/-Tmp-"
                if ( !path )                    // 3. /tmp/PACKAGE
                    path = vhfPathWithPathComponents(NSOpenStepRootDirectory(), @"tmp", fileName, nil);
                fileCnt ++;
                [downloadFiles addObject:[NSArray arrayWithObjects:url, path, nil]];    // url, path
            }
            else
                NSLog(@"Update-Controller: Nothing to install for '%@'",
                      [[dataDict objectForKey:@"name"] objectAtIndex:i]);
        }
    }

    if ( fileCnt )
    {   int             fileIx = [downloadFiles count] - fileCnt;
        NSArray         *array = [downloadFiles objectAtIndex:fileIx];
        NSURL           *url  = [array objectAtIndex:0];
        NSString        *path = [array objectAtIndex:1];
        NSURLRequest    *request = [NSURLRequest requestWithURL:url];
        NSString        *titleStr;

        pkgDownload = [[NSURLDownload alloc] initWithRequest:request delegate:self];
        [pkgDownload setDeletesFileUponFailure:YES];
        pkgPath = path;
        [pkgDownload setDestination:pkgPath allowOverwrite:YES];
        titleStr = [NSString stringWithFormat:NSLocalizedString(@"Downloading %d %@", NULL),
                    fileCnt, (fileCnt > 1) ? NSLocalizedString(@"Items", NULL) : NSLocalizedString(@"Item", NULL)];
        [progressTitleText setStringValue:titleStr];
        [progressNameText setStringValue:[path lastPathComponent]];
        [progressSizeText setStringValue:@""];
        [progressIndicator setIndeterminate:YES];
        [progressIndicator startAnimation:nil];
        [progressPanel makeKeyAndOrderFront:self];
        printf("UpdateController: Download %s\n", [[url absoluteString] UTF8String]);
    }
    [panel orderOut:self];
}
- (void)skip:sender
{   NSUserDefaults  *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary    *infoDict = [[NSBundle mainBundle] infoDictionary];
    NSString        *appName = [infoDict objectForKey:@"CFBundleExecutable"];    // Cenon, APPNAME
    NSString        *newVersion;

    if ( !appName )
        appName = APPNAME;
    newVersion = [[updateDict objectForKey:appName] objectForKey:@"v"];
    if ( newVersion )
        [defaults setObject:newVersion forKey:@"skipUpdateVersion"];
    [panel orderOut:self];
}
/* Close Update-Panel
 */
- (void)cancel:sender
{
    [panel orderOut:self];
}


/* Cancel the download from within Progress Panel
 */
- (void)cancelDownload:sender
{
    if (urlConnection)
    {   [urlConnection cancel];
        [urlConnection release]; urlConnection = nil;
    }
    if (pkgDownload)
    {
        [pkgDownload cancel];
        [pkgDownload release]; pkgDownload = nil;
    }
    [progressPanel orderOut:self];
}

/* click into the table - checkmark
 * created:  2010-05-31
 * modified: 2010-06-01
 */
- (void)tableClick:sender
{   int rowIx = [sender clickedRow];
    int colIx = [sender clickedColumn];

    if ( rowIx < 0 )
        return;
    /* Checkmark row */
    if ( colIx == 0 )   // checkmark row
    {   NSString        *colId = [[[sender tableColumns] objectAtIndex:colIx] identifier];
        NSMutableArray  *colArray = [[[sender dataSource] dataDict] objectForKey:colId];
        NSMutableArray  *keyArray = [[[sender dataSource] dataDict] objectForKey:@"updateKey"];
        NSString        *boolStr = @"";
        NSString        *url = [[updateDict objectForKey:[keyArray objectAtIndex:rowIx]] objectForKey:@"d"];

        if ( url && // checkmark only for downloadable items
             (![(NSString*)[colArray objectAtIndex:rowIx] length] || ![[colArray objectAtIndex:rowIx] intValue]) )
            boolStr = @"1";
        [colArray replaceObjectAtIndex:rowIx withObject:boolStr];
    }
}

/* NSURLConnection Delegate Methods */
//#if 0
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    [connectionData setLength:0];
    [progressTitleText setStringValue:NSLocalizedString(@"Connected to server", NULL)];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [connectionData appendData:data];
    [progressTitleText setStringValue:NSLocalizedString(@"Receiving data", NULL)];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{   NSString    *string = [[[NSString alloc] initWithData:connectionData
                                                 encoding:NSUTF8StringEncoding] autorelease];

    checking = NO;
    if ( connection == urlConnection )
        urlConnection = nil;
    [connection release];
    [connectionData release]; connectionData = nil;
    [progressPanel orderOut:self];
    if (string && [string length] > 0)
    {   NSString    *updateFile;

        updateFile = vhfPathWithPathComponents(vhfUserLibrary(APPNAME), @".update.plist", nil);
        //[string writeToFile:updateFile atomically:NO];
        [string writeToFile:updateFile atomically:NO
                   encoding:NSUTF8StringEncoding error:NULL];   // >= 10.5
        [self checkForUpdateAndDisplayPanel];
    }
    // TODO: show "up to date" info
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    checking = NO;
    if ( connection == urlConnection )
        urlConnection = nil;
    [connection release];
    [connectionData release]; connectionData = nil;
    [progressPanel orderOut:self];
}

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection
                  willCacheResponse:(NSCachedURLResponse *)cachedResponse
{
    return nil;     // Never cache
}
//#endif

/* NSURLDownload Delegate Methods */
/* notification: download did finish
 */
- (void)download:(NSURLDownload *)download didReceiveResponse:(NSURLResponse *)response
{
    sizeTotal = [response expectedContentLength];
    sizeDownl = 0;
}
- (void)download:(NSURLDownload *)download didReceiveDataOfLength:(NSUInteger)length
{  
    sizeDownl += length;
    if (sizeTotal > 0)
    {   float       percentComplete = ((float)sizeDownl / (float)sizeTotal) * 100.0;
        NSString    *sizeStr;
        float       div = (sizeTotal < 1024*100) ? 1024.0 : (1024.0*1024.0);    // MB or KB

        [progressIndicator setIndeterminate:NO];
        [progressIndicator setDoubleValue:percentComplete];
        sizeStr = [NSString stringWithFormat:((sizeTotal < 1024*100) ? @"%.1f KB %@ %.1f KB" : @"%.1f MB %@ %.1f MB"),
                   sizeDownl/div, NSLocalizedString(@"of", NULL), sizeTotal/div];
        [progressSizeText setStringValue:sizeStr];
    }
}
- (void)downloadDidFinish:(NSURLDownload*)download
{   NSURLRequest    *request;
    NSURL           *url;

    if ( [download isKindOfClass:[NSURLDownload class]] )
        request = [download request];
    else    // this is a hack to avoid to many methods
    {   request = (NSURLRequest*)download;
        download = nil;
    }
    url = [request URL];

    if ( [[url absoluteString] hasSuffix:@"update.plist"] )
    {   checking = NO;
        [self checkForUpdateAndDisplayPanel];
    }
    else if ( [[url absoluteString] hasSuffix:@".rtf"] )    // info file
    {   NSString        *path, *name;
        NSData          *rtfData;

        name = [[url absoluteString] lastPathComponent];
        path = vhfPathWithPathComponents(vhfUserLibrary(APPNAME), @".update", name, nil);
        rtfData = [NSData dataWithContentsOfFile:path];
        if (rtfData)
            [textView replaceCharactersInRange:NSMakeRange(0, [[textView string] length])
                                       withRTF:rtfData];
    }
    else    // package
    {
        fileCnt --;

        if ( [[pkgPath pathExtension] isEqual:@"tar"] )             // unpack TAR archive
        {   NSString    *path = [pkgPath stringByDeletingLastPathComponent];
            NSString    *command = [NSString stringWithFormat:@"/usr/bin/tar -x -C %@ -f %@", path, pkgPath];

            system([command UTF8String]);
            pkgPath = [pkgPath stringByDeletingPathExtension];
        }
        if ( ! [[NSWorkspace sharedWorkspace] openFile:pkgPath] )   // open package in Installer
            NSLog(@"Couldn't open file %@", pkgPath);
        pkgDownload = nil;

        if ( !fileCnt )
        {   NSFileManager   *fileManager = [NSFileManager defaultManager];
            NSString        *path;
            int             i;

            // TODO: "sudo installer -pkg %@ -target /"   // man installer
            // -dumplog ... &2 > LOGFILE
            // -showChoiceChangesXML, -applyChoiceChangesXML <pathToXMLFile>

            /* cleanup files: .update.plist, .update/rtf-files, packages */
            path = vhfPathWithPathComponents(vhfUserLibrary(APPNAME), @".update.plist", nil);
            [fileManager removeFileAtPath:path handler:nil];
            path = vhfPathWithPathComponents(vhfUserLibrary(APPNAME), @".update", nil);
            [fileManager removeFileAtPath:path handler:nil];

            for ( i=0, path=nil; i<[downloadFiles count]; i++)
            {   path = [[downloadFiles objectAtIndex:i] objectAtIndex:1];
                if ( [[path pathExtension] isEqual:@"tar"] && [fileManager fileExistsAtPath:path] ) // del TAR-file
                    [fileManager removeFileAtPath:path handler:nil];
                // TODO: the following must not happen before the files are really installed !
                /*path = [path stringByDeletingPathExtension];
                if ( [fileManager fileExistsAtPath:path] )  // delete PKG-file
                    [fileManager removeFileAtPath:path handler:nil];*/
            }
            if ( [[NSWorkspace sharedWorkspace] respondsToSelector:@selector(activateFileViewerSelectingURLs:)] )
            {   NSMutableArray  *array = [NSMutableArray array];

                //path = [path stringByDeletingPathExtension];
                for ( i=0; i<[downloadFiles count]; i++)
                {   path = [[downloadFiles objectAtIndex:i] objectAtIndex:1];
                    path = [path stringByDeletingPathExtension];    //remove ".tar"
                    [array addObject:[NSURL URLWithString:path]];
                }
                [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:array];
            }
            [progressPanel orderOut:self];
            NSRunAlertPanel(@"Update Downloaded", @"You can now install the open packages.", OK_STRING, nil, nil);
            [downloadFiles release]; downloadFiles = nil;
        }
        else
        {   int             fileIx = [downloadFiles count] - fileCnt;
            NSArray         *array = [downloadFiles objectAtIndex:fileIx];
            NSURL           *url  = [array objectAtIndex:0];
            NSString        *path = [array objectAtIndex:1];
            NSURLRequest    *request = [NSURLRequest requestWithURL:url];
            NSString        *titleStr;

            pkgDownload = [[NSURLDownload alloc] initWithRequest:request delegate:self];
            [pkgDownload setDeletesFileUponFailure:YES];
            pkgPath = path;
            [pkgDownload setDestination:pkgPath allowOverwrite:YES];
            titleStr = [NSString stringWithFormat:NSLocalizedString(@"Downloading %d %@", NULL),
                        fileCnt, (fileCnt > 1) ? NSLocalizedString(@"Items", NULL) : NSLocalizedString(@"Item", NULL)];
            [progressTitleText setStringValue:titleStr];
            [progressNameText setStringValue:[path lastPathComponent]];
            [progressSizeText setStringValue:@""];
            [progressIndicator setIndeterminate:YES];
            [progressIndicator startAnimation:nil];
            [progressPanel makeKeyAndOrderFront:self];
            printf("UpdateController: Download %s\n", [[url absoluteString] UTF8String]);
        }
    }
    if ( download == pkgDownload )
        pkgDownload = nil;
    [download release];
}
- (void)download:(NSURLDownload*)download didFailWithError:(NSError*)error
{   NSURLRequest    *request = [download request];
    NSURL           *url = [request URL];
    //name = [dataDict objectForKey:@"name"];

    if ( [[url absoluteString] hasSuffix:@"update.plist"] )
        checking = NO;
    else if ( [[url absoluteString] hasSuffix:@".rtf"] )    // info file
        [textView replaceCharactersInRange:NSMakeRange(0, [[textView string] length])
                                withString:@""];
    else                                                    // package download
    {
        NSLog(@"Update-Controller: Download failed for file '%@'", url);
        [progressTitleText setStringValue:NSLocalizedString(@"Download failed !", NULL)];
        [downloadFiles release]; downloadFiles = nil;
        //[progressPanel orderOut:self];
    }
    if ( download == pkgDownload )
        pkgDownload = nil;
    [download release];
}

/* NSTableView Delegate methods and Notifications */
/* notification: selection changed
 */
- (void)tableViewSelectionDidChange:(NSNotification*)notification
{   //NSTableView *tableView = [notification object];
    int             rowIx = [tableView selectedRow];
    NSString        *updateKey; // key in updateDict
    NSDictionary    *uDict, *names;
    NSURL           *url;
    NSArray         *lngArray = [[NSBundle mainBundle] preferredLocalizations];
    NSString        *lngKey, *name, *path;
    NSURLRequest    *request;
    NSURLDownload   *download;
    NSFileManager   *fileManager = [NSFileManager defaultManager];
    BOOL            isDir;

    if ( rowIx < 0 )
        return;

    updateKey = [[[tableData dataDict] objectForKey:@"updateKey"] objectAtIndex:rowIx];
    uDict = [updateDict objectForKey:updateKey];
    names = [uDict objectForKey:@"i"];   // info file
    //v    = [uDict objectForKey:@"v"];   // version
    if ( !names )
        return;
    /* get language file */
    lngKey = [[updateDict objectForKey:@"lng"] objectForKey:[lngArray objectAtIndex:0]];
    if ( ! lngKey )
        lngKey = @"gb";
    if ( [names isKindOfClass:[NSDictionary class]] )
        name = [names objectForKey:lngKey];
    else
        name = (NSString*)names;
    //ext = [name pathExtension];
    NSLog(@"name = %@", name);

    
    url = [NSURL URLWithString:[NSString stringWithFormat:@"http://www.cenon.info/update/%@", name]];
    path = vhfPathWithPathComponents(vhfUserLibrary(APPNAME), @".update", nil);
    if ( ! [fileManager fileExistsAtPath:path isDirectory:&isDir] )
        [fileManager createDirectoryAtPath:path attributes:nil];
    else if ( ! isDir )
        NSLog(@"Cenon-Update: unexpected file at path '%@'", path);
    path = vhfPathWithPathComponents(path, name, nil);
    request = [NSURLRequest requestWithURL:url];
    if ( [[NSFileManager defaultManager] fileExistsAtPath:path] )
        [self downloadDidFinish:(NSURLDownload*)request];
    else
    {   download = [[NSURLDownload alloc] initWithRequest:request delegate:self];
        [download setDeletesFileUponFailure:YES];
        [download setDestination:path allowOverwrite:YES];
    }
}

@end


/*
 * Table Data for our tableView
 */

@implementation UpdateTableData

+ (UpdateTableData*)tableData;
{
    return [[self new] autorelease];
}

- init
{
    [super init];
    dataDict = [NSMutableDictionary new];
    rowCount = 0;
    return self;
}

- (int)numberOfRowsInTableView:(NSTableView*)table
{
    return rowCount;
}

- (id)tableView:(NSTableView*)table objectValueForTableColumn:(NSTableColumn*)column row:(int)row
{   NSString    *obj = [[dataDict objectForKey:[column identifier]] objectAtIndex:row];

    if ( [[column identifier] isEqual:@"install"] )
    {
        return ([obj intValue]) ? checkMarkStr : @"";
    }
    return obj;
}

- (void)setDataDict:(NSDictionary*)newDataDict
{
    [dataDict release];
    dataDict = [newDataDict retain];
    rowCount = [(NSArray*)[dataDict objectForKey:@"name"] count];
}
- (NSDictionary*)dataDict
{
    return dataDict;
}

- (void)dealloc
{
    [dataDict release];
    [super dealloc];
}

@end
