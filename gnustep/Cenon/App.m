/* App.m
 * Application class of Cenon
 *
 * Copyright (C) 1995-2012 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1995-08-10
 * modified: 2012-06-29 (-terminate:, terminate sub processes)
 *           2012-06-22 (-openFile:, remove i-cut Import Stuff)
 *           2012-02-06 (systemLibrary: return nil on Apple)
 *           2011-12-02 (i-cut Import Stuff added)
 *           2011-04-05 (Vectorizer)
 *           2011-03-06 (-applicationDidFinishLaunching: auto check for updates, -importASCII: removed)
 *           2010-07-04 (svg stuff added)
 *           2010-06-30 (-changeSafeType: TIFF added)
 *           2010-04-10 (displayInfo: get version from plist and date from __DATE__)
 *           2010-01-12 (take snapshot of open documents and their positions)
 *           2009-06-24
 *           2009-03-27 (-sendEvent: ',' -> '.' on Apple)
 *           2009-02-25 (-listFromFile: check extensions for any case)
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
#include <VHFShared/vhfCommonFunctions.h>
#include <VHFShared/VHFSystemAdditions.h>
#include "messages.h"
#include "functions.h"
#include "locations.h"
#include "App.h"
#include "CenonModuleMethods.h"
//#include "MyPageLayout.h"
#include "TilePanel.h"
#include "GridPanel.h"
#include "WorkingAreaPanel.h"
#include "InspectorPanel.subproj/InspectorPanel.h"
#include "Document.h"
#include "DocView.h"
#include "DocWindow.h"
#include "PreferencesMacros.h"
#include "UpdateController.h"
#include "Vectorizer.h"

#include "DINImportSub.h"
#include "DXFImportSub.h"
#include "GerberImportSub.h"
#include "HPGLImportSub.h"
#include "PSImportSub.h"
#include "Type1ImportSub.h"
#include "SVGImportSub.h"
#include "ICUTImportSub.h"

@implementation App

/*
 * modified: 2006-12-11
 * Initializes the defaults.
 */
+ (void)initialize
{   NSMutableDictionary	*registrationDict = [NSMutableDictionary dictionary];

    [registrationDict setObject:@"." forKey:@"NSDecimalSeparator"];

    /* General Preferences defaults */
    [registrationDict setObject:@"YES" forKey:@"doCaching"];
    [registrationDict setObject:@"0"   forKey:@"unit"];
    [registrationDict setObject:@"NO"  forKey:@"removeBackups"];
    [registrationDict setObject:@"NO"  forKey:@"expertMode"];
    [registrationDict setObject:@"2"   forKey:@"snap"];
    [registrationDict setObject:@"0"   forKey:@"lineWidth"];
    [registrationDict setObject:@"YES"  forKey:@"selectByBorder"];
    [registrationDict setObject:@"20"  forKey:@"cacheLimit"];

    /* Import preferences defaults */
    [registrationDict setObject:@"hpgl_8Pen" forKey:@"hpglParmsFileName"];
    [registrationDict setObject:@"gerber"    forKey:@"gerberParmsFileName"];
    [registrationDict setObject:@""          forKey:@"dinParmsFileName"];
    [registrationDict setObject:@"25.4"      forKey:@"dxfRes"];
    [registrationDict setObject:@"NO"        forKey:@"psFlattenText"];
    [registrationDict setObject:@"NO"        forKey:@"psPreferArcs"];
    [registrationDict setObject:@"NO"        forKey:@"colorToLayer"];
    [registrationDict setObject:@"NO"        forKey:@"fillObjects"];
    //[registrationDict setObject:@"NO"        forKey:@"icutFillClosedPaths"];
    //[registrationDict setObject:@"NO"        forKey:@"icutOriginUL"];

    /* Export preferences defaults */
    [registrationDict setObject:@"NO"        forKey:@"exportFlattenText"];

    [[NSUserDefaults standardUserDefaults] registerDefaults:registrationDict];
}

/* modified: 2004-02-13
 */
- init
{
    if ( (self = [super init]) )
        [self setDelegate:self]; // so that we get NSApp delegation methods

    modules = [NSMutableArray new];

    return self;
}

/*
 * Directory where we are currently "working."
 */
- (NSString*)currentDirectory
{   NSString	*cdir = [[self currentDocument] directory], *path;

    if (cdir && [cdir length])
        path = cdir;
    else
        path = (haveOpenedDocument ? [((NSOpenPanel*)[NSOpenPanel openPanel]) directory]
                                   : NSHomeDirectory());
    if (!path)
        return NSHomeDirectory();
    return path;
}

/* set the current document without regard to the active window
 * we need this in the moment of opening a new document.
 */
- (void)setCurrentDocument:(Document*)docu
{
    fixedDocument = docu;
}

- (void)setActiveDocWindow:(DocWindow*)win
{
    activeWindowNum = [win windowNumber];
}

- (Document*)currentDocument
{
    if (fixedDocument)
        return fixedDocument;
    /* this is unreliable, because a panel may become the main window! */
    if ( [[self mainWindow] isMemberOfClass:[DocWindow class]] )
    {	id	docu = [(DocWindow*)[self mainWindow] document];

        if ([docu isMemberOfClass:[Document class]])
            return docu;
    }
    {   NSArray *wins = [self windows];
        int     i, cnt = [wins count];

        for (i=0; i<cnt; i++)
            if ( [[wins objectAtIndex:i] windowNumber] == activeWindowNum )
                return [[wins objectAtIndex:i] document];
    }
    /* does this really return the window last worked at? Probably we should remember the active document */
    /*for ( i=[[self windows] count]-1; i >= 0; i-- )
    {	DocWindow  *win = [[self windows] objectAtIndex:i];

        if ( [win isMemberOfClass:[DocWindow class]] )
            return [win document];
    }*/
    /*{   int wins[10];

        //NSCountWindowsForContext([self context], &nWin);
        NSWindowListForContext([self context], 10, wins);   // how to obtain the context? What context is that?
        for ( i=0; i < 10; i++ )
        {   DocWindow  *win = wins[i];

            if ( [win isMemberOfClass:[DocWindow class]] )
                return [win document];
        }
    }*/
    return nil;
}
- (Document*)openedDocument
{
    return document;
}

- (Document*)documentInWindow:(NSWindow*)window
{
    if ([window isMemberOfClass:[DocWindow class]])
    {	id	docu = [(DocWindow*)window document];

        if ([docu isMemberOfClass:[Document class]])
            return docu;
    }

    return nil;
}

/*
 * Returns the application-wide FontPageLayout panel.
 */
- (NSPageLayout *)pageLayout
{   static NSPageLayout *dpl = nil;

    if (!dpl)
    {
        dpl = [NSPageLayout pageLayout];
        if (![NSBundle loadModelNamed:@"PageLayoutAccessory" owner:self])
            NSLog(@"Cannot load PageLayoutAccessory interface file");
    }
    return dpl;
}

/* created:  2002-07-18
 * modified: 2012-02-06 (test for path == nil)
 *           2011-06-08 (add CAM.bundle to loadedFiles)
 *           2005-09-05 (load module only once)
 *
 * FIXME: Each module should give info about other modules needed before
 *        Each module should give info about modules to be in conflict
 *        Available modules should be selectable by switches in preferences
 */
- (void)loadModules
{   NSBundle        *mainBundle = [NSBundle mainBundle], *bundle;
    Class           bundleClass;
    NSString        *path = nil;
    int             i, j;
    NSFileManager   *fileManager = [NSFileManager defaultManager];
    NSMutableArray  *loadedFiles = [NSMutableArray array];

    /* load modules */
    for (i=0; i <= 5; i++)
    {   NSArray	*files;

        switch (i)
        {
            default:
            //case 0: path = [[mainBundle resourcePath] stringByAppendingPathComponent:@"Modules"]; break;
            case 0: path = [mainBundle resourcePath]; break;    // load modules from main bundle
            case 1: path = [userLibrary()  stringByAppendingPathComponent:@"Bundles"]; break;
            case 2: path = [localLibrary() stringByAppendingPathComponent:@"Bundles"]; break;
            case 3: path = userBundlePath();   break;           // load modules from Home Library/Cenon of user
            case 4: path = localBundlePath();  break;           // load modules from /Library/Extensions/Cenon
            case 5: path = systemBundlePath(); break;           // load modules from /System/Library/Bundles/Cenon (GNUstep only)
        }
        if ( !path )
            continue;

        /* we load the bundles in alphabetic order */
        files = [[fileManager directoryContentsAtPath:path] sortedArrayUsingSelector:@selector(compare:)];
        for (j=0; j<(int)[files count]; j++)
        {   NSString	*file = [files objectAtIndex:j];

            if ([loadedFiles containsObject:@"CAM.bundle"] && [file hasPrefix:@"Cut."]) // either CAM or Cut, not both
                continue;
            if ( [file hasSuffix:@".bundle"] &&
                 ![loadedFiles containsObject:file] &&  // already loaded ?
                 (bundle = [NSBundle bundleWithPath:[path stringByAppendingPathComponent:file]]) )
            {
                NSLog(@"Load Module: %@/%@\n", path, file);
                bundleClass = [bundle principalClass];  // controller (XYZPrincipal)
                [modules addObject:bundle];             // our loaded modules
                [bundleClass instance];                 // create instance
                [loadedFiles addObject:file];
            }
        }
    }
}
- (NSArray*)modules
{
    return modules;
}

/* created:  1993-01-??
 * modified: 2012-03-09 (Apple: copy existing Library to location in "Application Support")
 */
- (void)applicationDidFinishLaunching:(NSNotification *)notification
{   NSApplication	*theApplication = [notification object];
    NSString		*path;
    NSFileManager	*fileManager = [NSFileManager defaultManager];

    [[NSUserDefaults standardUserDefaults] setObject:@"." forKey:@"NSDecimalSeparator"];

    /* Apple: if Home-Library exists in old location, move to new location */
#   ifdef __APPLE__ // keep things working through transition to new Library-location
    {   NSString    *oldPath;

        oldPath = [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0]
                   stringByAppendingPathComponent:APPNAME];
        path    = vhfPathWithPathComponents(
                  [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0],
                  @"Application Support", APPNAME, nil );
        if ( [fileManager fileExistsAtPath:oldPath] && ![fileManager fileExistsAtPath:path] )
        {
            if ( NSRunAlertPanel(@"", NSLocalizedString(@"Cenon User-Library will be moved from old location\n \"%@\"\nto new location\n \"%@\".", NULL),
                                 OK_STRING, CANCEL_STRING, nil, oldPath, path) == NSAlertDefaultReturn )
            {
                if ( [fileManager respondsToSelector:@selector(moveItemAtPath:toPath:error:)] ) // >= 10.5
                    [fileManager moveItemAtPath:oldPath toPath:path error:NULL];    // mv oldPath -> path
                else                                                                // <  10.5
                    [fileManager movePath:oldPath toPath:path handler:nil];
            }
        }
        else if ( [fileManager fileExistsAtPath:oldPath] )  // it's in both locations
            NSRunAlertPanel(@"", NSLocalizedString(@"Cenon User-Library exists in old location\n \"%@\"\nand new location\n \"%@\".\nOnly the new location is used !", NULL),
                            OK_STRING, nil, nil, oldPath, path);
    }
#   endif

    /* create Cenon HOME-Library. If it doesn't exist, we copy the frame
     * FIXME: on Apple, we have to prepare this in the HOME/Documents folder now !
     */
    path = vhfUserLibrary(APPNAME); // vhfUserLibrary(APPNAME) or vhfUserDocuments(APPNAME)
    if ( ! [fileManager fileExistsAtPath:path] )    // no Cenon Home-Library
    {
        if ( ![fileManager fileExistsAtPath:localLibrary()] )
            NSRunAlertPanel(@"", CANTFINDLIB_STRING, OK_STRING, nil, nil, NULL);
        /* copy Cenon directory */
        else
        {   NSString	*from, *to;

            /* create HOME/Cenon */
            [fileManager createDirectoryAtPath:path attributes:nil];
            /* create HOME/Cenon/Projects */
            [fileManager createDirectoryAtPath:vhfPathWithPathComponents(path, @"Projects", nil)
                                    attributes:nil];
            /* copy Cenon/Projects/.dir.tiff */
            from = vhfPathWithPathComponents(localLibrary(), @"Projects", @".dir.tiff", nil);
            to   = vhfPathWithPathComponents(path,           @"Projects", @".dir.tiff", nil);
            [fileManager copyPath:from toPath:to handler:nil];
            /* copy Cenon/dir.tiff */
            from = vhfPathWithPathComponents(localLibrary(), @".dir.tiff", nil);
            to   = vhfPathWithPathComponents(path,           @".dir.tiff", nil);
            [fileManager copyPath:from toPath:to handler:nil];
        }
    }

    [theApplication setDelegate:self];

    /* to avoid another call of init when double clicking a file in workspace */
    appIsRunning = 1;

    /* load modules */
    [self loadModules];

    [self displayToolPanel:YES];

#if !defined(GNUSTEP_BASE_VERSION) && !defined(__APPLE__)	// OpenStep 4.2
    [self saveAsPanel];	// OS Bug: If 1st Panel is the open panel this function would return an open panel
#endif

    [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:500.0/1000000.0]];

    /* Load Document Snapshot */
    [self restoreSnapshot:self];

#ifdef __APPLE__
    /* automatically check for updates */
    [[UpdateController sharedInstance] checkForUpdates:self];
    /*[[NSRunLoop currentRunLoop] performSelector:@selector(checkForUpdates:)
                                         target:[UpdateController sharedInstance]
                                            argument:self order:10 modes:NSDefaultRunLoopMode];*/
#endif

#ifdef GNUSTEP_BASE_VERSION
    /* menu in window */
    if (NSInterfaceStyleForKey(@"NSMenuInterfaceStyle", nil) == NSWindows95InterfaceStyle)
    {
        [self new:self];
    }
#endif
}


- (NSString *)appDirectory
{
    return [[NSBundle mainBundle] bundlePath];
}


/* Creates a new document--called by pressing New in the Document menu.
 */
- (void)new:sender
{
    document = [Document new];
}

/* modified: 2011-09-16 (icut format added)
 *           2010-09-10 (defaultManager renamed to fileManager)
 *           2009-02-25 (fileNameLC)
 */
- (id)listFromFile:(NSString*)fileName
{   NSArray         *list = nil;
    NSString        *path, *name;
    NSFileManager   *fileManager = [NSFileManager defaultManager];
    NSString        *fileNameLC = [fileName lowercaseString];

    //if ( [fileName rangeOfString:@".dxf" options:NSCaseInsensitiveSearch].length )
    //if ( [fileName compare:@".dxf" options:NSAnchoredSearch|NSBackwardsSearch|NSCaseInsensitiveSearch] )
    if ( [fileNameLC hasSuffix:@".dxf"] )
    {	id	dxfImport = [[DXFImportSub allocWithZone:[self zone]] init];
        NSData	*data = [NSData dataWithContentsOfFile:fileName];	// get data object

        [dxfImport setRes:Prefs_DXFRes];
        list = [[dxfImport importDXF:data] retain];	// get list of graphic objects from import
        [dxfImport release];
    }
    else if ( [fileNameLC hasSuffix:@".cut"] || [fileNameLC hasSuffix:@".icut"] )
    {	id      icutImport = [[ICUTImportSub allocWithZone:[self zone]] init];
        NSData  *data = [NSData dataWithContentsOfFile:fileName];   // get data object

        // FIXME: should come from Somewher with the possibility to change
        //        [icutImport fillClosedPaths:Prefs_ICUTFillClosedPaths];
        //        [icutImport originUL:Prefs_ICUTOriginUL];
        list = [[icutImport importICUT:data] retain];	// get list of graphic objects from import
        [icutImport release];
    }
    else if ( [fileNameLC hasSuffix:@".hpgl"] || [fileNameLC hasSuffix:@".hgl"] ||
              [fileNameLC hasSuffix:@".plt"] )
    {	id      hpglImport;
        NSData	*data;

        /* load parameter file
         * 1st try it in the users home library then try it in /LocalLibrary
         */
        name = Prefs_HPGLParmsFileName;
        if ( ![name length] ) name = @"hpgl_8Pen";  // workaround GNUstep issue with registering defaults
        name = [name stringByAppendingPathExtension:DEV_EXT];
        path = vhfPathWithPathComponents(userLibrary(), HPGLPATH, name, nil);
        if ( ![fileManager fileExistsAtPath:path] )
        {   path = vhfPathWithPathComponents(localLibrary(), HPGLPATH, name, nil);
            if ( ![fileManager fileExistsAtPath:path] )
            {	NSRunAlertPanel(@"", CANTLOADFILE_STRING, OK_STRING, nil, nil, path);
                return nil;
            }
        }
        hpglImport = [[HPGLImportSub allocWithZone:[self zone]] init];	// get new import-object
        if (![hpglImport loadParameter:path])
        {   NSRunAlertPanel(@"", CANTLOADFILE_STRING, OK_STRING, nil, nil, path);
      	    [hpglImport release];
            return nil;
        }
        data = [NSData dataWithContentsOfFile:fileName];	// get file-stream
        list = [[hpglImport importHPGL:data] retain];		// get list of graphic objects from import
        [hpglImport release];
    }
    else if ( [fileNameLC hasSuffix:@".ger"] || [fileNameLC hasSuffix:@".gerber"] )
    {   id      gerberImport;
        NSData  *data;

        /* load parameter file
         * 1st try it in the users home library then try it in /LocalLibrary
         */
        name = Prefs_GerberParmsFileName;
        if ( ![name length] ) name = @"gerber"; // workaround GNUstep issue with registering defaults
        name = [name stringByAppendingPathExtension:DEV_EXT];
        path = vhfPathWithPathComponents(userLibrary(), GERBERPATH, name, nil);
        if ( ![fileManager fileExistsAtPath:path] )
        {   path = vhfPathWithPathComponents(localLibrary(), GERBERPATH, name, nil);
            if ( ![fileManager fileExistsAtPath:path] )
            {	NSRunAlertPanel(@"", CANTLOADFILE_STRING, OK_STRING, nil, nil, path);
                return nil;
            }
        }
        gerberImport = [[GerberImportSub allocWithZone:[self zone]] init];	// get new import-object
        [gerberImport setDefaultParameter];
        if (![gerberImport loadParameter:path])
        {   NSRunAlertPanel(@"", CANTLOADFILE_STRING, OK_STRING, nil, nil, path);
            [gerberImport release];
            return nil;
        }
        /* look if RS274X file -> we need no Apertures
         */
        data = [NSData dataWithContentsOfFile:fileName]; // get file-stream
        if ( ![gerberImport loadRS274XApertures:data] ) // + parameter
        {
            /* load aperture table (extension: .tab)
             * try to load a table with the same name and in the same path as the file.
             * if this fails try to load the default-table from the Home-Library or the LocalLibrary
             */
            path = [[fileName stringByDeletingPathExtension] stringByAppendingPathExtension:@"tab"];
            if ( ![gerberImport loadApertures:path] )
            {
                if ( NSRunAlertPanel(@"", CANTLOADFILEDEFAULT_STRING,
                                    OK_STRING, CANCEL_STRING, nil, path) == NSAlertAlternateReturn )
                {   [gerberImport release];
                    return nil;
                }
                name = [Prefs_GerberParmsFileName stringByAppendingPathExtension:@"tab"];
                path = vhfPathWithPathComponents(userLibrary(), GERBERPATH, name, nil);
                if ( ![gerberImport loadApertures:path] )
                {   path = vhfPathWithPathComponents(localLibrary(), GERBERPATH, name, nil);
                    if ( ![gerberImport loadApertures:path] )
                    {   NSRunAlertPanel(@"", CANTLOADFILE_STRING, OK_STRING, nil, nil, path);
                        [gerberImport release];
                        return nil;
                    }
                }
            }
        }
        list = [[gerberImport importGerber:data] retain];	// get list of graphic-objects from import
        [gerberImport release];
    }
    else if ( [fileNameLC hasSuffix:@".drl"] || [fileNameLC hasSuffix:@".din"] )
    {   id          dinImport;
        NSData      *data;
        NSString    *devFileName;

        /* look for parameter file
         * 1st try it in the users home library then try it in /LocalLibrary
         */
        if ([(devFileName = Prefs_DINParmsFileName) length])
        {
            name = [devFileName stringByAppendingPathExtension:DEV_EXT];
            path = vhfPathWithPathComponents(userLibrary(), DINPATH, name, nil);
            if ( ![fileManager fileExistsAtPath:path] )
            {   path = vhfPathWithPathComponents(localLibrary(), DINPATH, name, nil);
                if ( ![fileManager fileExistsAtPath:path] )
                {   NSRunAlertPanel(@"", CANTLOADFILE_STRING, OK_STRING, nil, nil, path);
                    return nil;
                }
            }
        }
        else
            path = nil;
        dinImport = [[DINImportSub allocWithZone:[self zone]] init];	// get new import-object
        data = [NSData dataWithContentsOfFile:fileName]; // get file-stream
        // load parameter
        if (path && ![dinImport loadParameter:path])
        {   NSRunAlertPanel(@"", CANTLOADFILE_STRING, OK_STRING, nil, nil, path);
            [DINImport release];
            return nil;
        }
        list = [dinImport importDIN:data]; // get list of graphic-objects from import
        list = [[DINImportSub layerListFromGraphicList:list] retain];
        [dinImport release];
    }
    else if ( [fileNameLC hasSuffix:@".svg"] )
    {	SVGImport   *svgImport = [[SVGImportSub allocWithZone:[self zone]] init];
        NSData      *data = [NSData dataWithContentsOfFile:fileName];

        list = [[svgImport importSVG:data] retain]; // get list of graphic-objects from import
        [svgImport release];
    }
    else if ( [fileNameLC hasSuffix:@".font"] || [fileNameLC hasSuffix:@".pfa"] || [fileNameLC hasSuffix:@".pfb"] )
    {   id          fontObject, type1Import;
        NSData		*data;
        NSString	*name;

        if ( [fileNameLC hasSuffix:@".pfa"] || [fileNameLC hasSuffix:@".pfb"] )	// pfa file
            name = [NSString stringWithFormat:@"%@", fileName];
        else
            name = [fileName stringByAppendingPathComponent:
        [[fileName lastPathComponent] stringByDeletingPathExtension]];
        type1Import = [[Type1ImportSub allocWithZone:[self zone]] init];	// get new import-object
        data = [NSData dataWithContentsOfFile:name];				// get file-data

        fontObject = [[type1Import importType1:data] retain];	// get list of graphic-objects from import
        [type1Import release];
        return [fontObject autorelease];
    }

    /* PostScript, AI */
    else if ( [fileNameLC hasSuffix:@".eps"] || [fileNameLC hasSuffix:@".ps"] ||
              [fileNameLC hasSuffix:@".ai"] )
        list = [[self listFromPSFile:fileName] retain];

    /* PDF */
    else if ( [fileNameLC hasSuffix:@".pdf"] || [fileNameLC hasSuffix:@".PDF"])
    {   PSImportSub	*psImport = [[PSImportSub allocWithZone:[self zone]] init];

#ifdef __APPLE__    // check, if gs is installed (Linux has it installed anyway, OpenStep uses DPS)
        {   path = [psImport gsPath];
            if ( ! [fileManager fileExistsAtPath:path] )
                NSRunAlertPanel(@"", PSIMPORT_INSTALLGS_STRING, OK_STRING, nil, nil, nil);
        }
#endif
        [psImport preferArcs:Prefs_PSPreferArcs];
        [psImport flattenText:Prefs_PSFlattenText];
        list = [[psImport importPDFFromFile:fileName] retain];
        [psImport release];
    }

    /* raster images */
    else
    {   VImage	*g = [[[VImage allocWithZone:(NSZone *)[self zone]] initWithFile:fileName] autorelease];

        if ( g )
            list = [[NSMutableArray arrayWithObject:g] retain];
    }

    return [list autorelease];
}

- (NSArray*)listFromPSFile:(NSString*)fileName
{   PSImportSub		*psImport;
    NSData          *data = nil;
    NSString		*path;
    NSFileManager	*fileManager = [NSFileManager defaultManager];

    /* Adobe Illustrator */
    if ( [fileName hasSuffix:@".ai"] )
    {   NSString	*string, *header;
        NSRange		range;

        string = [NSString stringWithContentsOfFile:fileName];	/* get file */
        range = [string rangeOfString:@"%%BeginResource"];
        if ( !range.length )	/* no ps-header */
        {
            path = [[[NSBundle bundleForClass:[PSImport class]] resourcePath]
                    stringByAppendingPathComponent:AI_HEADER];
            if ( ![fileManager fileExistsAtPath:path] )
            {   NSRunAlertPanel(@"", CANTLOADFILE_STRING, OK_STRING, nil, nil, path);
                return nil;
            }
            header = [NSString stringWithContentsOfFile:path];	/* get file */

            string = [header stringByAppendingString:string];
        }
        data = [string dataUsingEncoding:NSASCIIStringEncoding];
    }
    else
        data = [NSData dataWithContentsOfFile:fileName];	/* get file */

    /* import file */
    psImport = [[[PSImportSub allocWithZone:[self zone]] init] autorelease];
    //[psImport moveToOrigin:NO];
    [psImport preferArcs:Prefs_PSPreferArcs];
    [psImport flattenText:Prefs_PSFlattenText];
#ifdef __APPLE__    // check, if gs is installed (Linux has it installed anyway, OpenStep uses DPS)
    {   path = [psImport gsPath];
        if ( ! [fileManager fileExistsAtPath:path] )
            NSRunAlertPanel(@"", PSIMPORT_INSTALLGS_STRING, OK_STRING, nil, nil, nil);
    }
#endif
    return [psImport importPS:data];
}

- (BOOL)openFile:(NSString *)fileName
{   id              list = nil;
    NSString        *path;
    NSFileManager   *fileManager = [NSFileManager defaultManager];

    if (!appIsRunning)	// give application a chance to load modules first
    {
        [self performSelector:@selector(openFile:) withObject:fileName afterDelay:0];
        return YES;
    }

    document = nil;
    if ( ![fileManager fileExistsAtPath:fileName] )
        return NO;
    if ( [fileName hasSuffix:DOCUMENT_EXT] )
    {	int	i;

        for (i=[[self windows] count]-1; i>=0; i--)
        {   Document	*docu = [self documentInWindow:[[self windows] objectAtIndex:i]];

            if (!docu)
                continue;
            path = vhfPathWithPathComponents([docu directory], [docu name], nil);
            if ( docu && [path isEqualToString:fileName] )
            {	[[[self windows] objectAtIndex:i] makeKeyAndOrderFront:self];
                return YES;
            }
        }
        document = [Document newFromFile:fileName];
        [self setCurrentDocument:nil];
        return YES;
    }
    else if ( (list = [self listFromFile:fileName]) )
    {
        /* Fonts: special treatment for fonts */
        if ( [fileName hasSuffix:@".font"] || [fileName hasSuffix:@".pfa"] || [fileName hasSuffix:@".pfb"] )
        {
            document = [Document new];
            [self setCurrentDocument:nil];
            [document setName:UNTITLED_STRING andDirectory:[self currentDirectory]];
            [document setDirty:YES];
            [document setFontObject:list]; // add font data, font list
        }
        /* imports with complete layerList or a single list of objects */
        else
        {
            document = [Document newFromList:list];
            [self setCurrentDocument:nil];
        }
        return YES;
    }
    return NO;
}

/* Import files
 * modified: 2011-12-03 ("cut", "icut" added)
 *           2010-02-24 (allow extension ".tif")
 */
typedef enum
{   IMPORTTO_SELECTEDLAYER  = 0,
    IMPORTTO_NEWLAYER       = 1,
    IMPORTTO_EXISTINGLAYERS = 2
} ImportToLayerSelection;
- (void)import:sender
{   NSArray     *fileTypes = [NSArray arrayWithObjects:@"hpgl", @"hgl", @"plt", @"ai",
                                              @"dxf", @"eps", @"ps", @"pdf", @"gerber", @"ger",
                                              @"cenon", @"tiff", @"tif", @"jpg", @"jpeg", @"gif", @"png",
                                              @"font", @"pfa", @"din", @"drl", @"svg", @"cut", @"icut", nil];
    NSString    *fileName;
    id          openPanel = [NSOpenPanel openPanel];
    static      NSString	*openDir = @"";

    [openPanel setAccessoryView:[importAccessory retain]];
    [openPanel setAllowsMultipleSelection:NO];

    if ( [openPanel runModalForDirectory:openDir file:@"" types:fileTypes] )
    {   ImportToLayerSelection	importTo = [iaPopup indexOfSelectedItem];
        id      list;
        DocView *view = [[self currentDocument] documentView];

        [openDir release];
        openDir = [[[openPanel filename] stringByDeletingLastPathComponent] retain];

        fileName = [openPanel filename];
        list = [self listFromFile:fileName];

        switch (importTo)
        {
            case IMPORTTO_NEWLAYER:
                [view addList:list toLayerAtIndex:-1 /*replaceObjects:NO*/];
                break;
            case IMPORTTO_SELECTEDLAYER:
            {   id	layerList = [view layerList];
                int	i = [view indexOfSelectedLayer];

                if ([[layerList objectAtIndex:i] editable])
                    [view addList:list toLayerAtIndex:i /*replaceObjects:NO*/];
                else
                    NSRunAlertPanel(@"", LAYERNOTEDITABLE_STRING, OK_STRING, nil, nil, NULL);
                /*for (i=0; i<[layerList count]; i++)
                    if ([[layerList objectAtIndex:i] editable])
                {   [view addList:list toLayerAtIndex:i];
                        break;
                }
                if (i>=[layerList count])
                    [view addList:list toLayerAtIndex:-1];*/
                break;
            }
            case IMPORTTO_EXISTINGLAYERS:
                [view addList:list toLayerAtIndex:-2 /*replaceObjects:YES*/];
         }
    }
    [openPanel setAccessoryView:nil];
}

/* modified: 2005-11-14
 */
#if 0   // moved to CAM module, can be removed
- (void)importASCII:sender
{   NSArray         *fileTypes = [NSArray arrayWithObjects:@"txt", @"asc", @"tab", nil];
    NSString        *fileName;
    id              openPanel = [NSOpenPanel openPanel];
    static NSString *openDir = @"";

    fillPopup(iaaPopup, CHARCONV_FOLDER, DICT_EXT, 1);
    [openPanel setAccessoryView:[importASCIIAccessory retain]];

    [openPanel setAllowsMultipleSelection:NO];
    if ( [openPanel runModalForDirectory:openDir file:@"" types:fileTypes] )
    {   int             sort = [iaaRadio selectedColumn];
        NSString        *tabName, *string;
        NSDictionary    *conversionDict = nil;
        DocView         *docView = [[self currentDocument] documentView];

        if ( [iaaPopup indexOfSelectedItem] >= 1 &&
             (tabName = [NSString stringWithFormat:@"%@%@", [iaaPopup title], DICT_EXT]) )
                conversionDict = dictionaryFromFolder(CHARCONV_FOLDER, tabName);
        [openDir release];
        openDir = [[[openPanel filename] stringByDeletingLastPathComponent] retain];

        fileName = [openPanel filename];
        string = [NSString stringWithContentsOfFile:fileName];
        [docView importASCII:stringWithConvertedChars(string, conversionDict) sort:sort];
    }
    [openPanel setAccessoryView:nil];
}
#endif

/*
 * openDocument gets a file name from the user, creates a new document window,
 * and loads the specified file into it.
 * modified: 2012-03-13 (set openPanelAccessory)
 *           2011-12-03 ("cut", "icut" added)
 */
- (void)openDocument:sender
{   NSArray     *fileTypes = [NSArray arrayWithObjects:@"hpgl", @"hgl", @"plt", @"ai",
                                  @"dxf", @"eps", @"ps", @"pdf", @"gerber", @"ger",
                                  @"cenon", @"tiff", @"tif", @"jpg", @"jpeg", @"gif", @"png",
                                  @"font", @"pfa", @"din", @"drl", @"svg", @"cut", @"icut", nil];
    NSArray         *fileNames;
    id              openPanel = [NSOpenPanel openPanel];
    int             i, cnt;
    static NSString *openDir = @"";

    if (openPanelAccessory)
        [openPanel setAccessoryView:[openPanelAccessory retain]];
    [openPanel setAllowsMultipleSelection:YES];
    [openPanel setDirectory:openDir];
    [openPanel setAllowedFileTypes:fileTypes];  // FIXME, Apple: this method doesn't work, we stay with the deprecated modal method (2012-03-13)

    if ( [openPanel runModalForDirectory:openDir file:@"" types:fileTypes] )
    //if ( [openPanel runModal] )
    {
        [openDir release];
        openDir = [[[openPanel filename] stringByDeletingLastPathComponent] retain];

        fileNames = [openPanel filenames];
        cnt = [fileNames count];
        for ( i=0; i<cnt; i++ )
            haveOpenedDocument = [self openFile:[fileNames objectAtIndex:i]] || haveOpenedDocument;
    }
}
/* called by Open Panel Accessory to jump to places
 * created: 2012-03-13
 */
- (void)changeOpenLocation:(id)sender
{   NSOpenPanel *openPanel = (NSOpenPanel*)[sender window];
    NSString    *path = nil;

    switch ([(NSCell*)[sender selectedCell] tag])
    {
        case 0:     // Examples
            path = vhfLocalLibrary(APPNAME);     // ex: "/Library/Cenon"
            break;
        case 1:     // User Library
            path = vhfUserLibrary(APPNAME);      // ex: "HOME/Library/Cenon"
            break;
        case 2:     // Documents
            path = vhfUserDocuments(APPNAME);    // ex: HOME/Documents/Cenon
            break;
        default:
            NSLog(@"App, changeOpenLocation: Unknown index");
            return;
    }
    [openPanel setDirectory:path];
}

/*
 * Saves the file.  If this document has never been saved to disk,
 * then a SavePanel is put up to ask the user what file name she
 * wishes to use to save the document.
 */
- (void)save:sender
{
    [[self currentDocument] save:sender];
}

- (void)saveAs:sender
{
    [[self currentDocument] saveAs:sender];
}

- (void)changeSaveType:sender
{   id	savePanel = [sender window];

    switch ([sender indexOfSelectedItem])
    {
        case 0: [savePanel setRequiredFileType:DOCUMENT_EXT]; break;
        case 1: [savePanel setRequiredFileType:EPS_EXT];      break;
        case 2: [savePanel setRequiredFileType:GERBER_EXT];   break;
        case 3: [savePanel setRequiredFileType:DXF_EXT];      break;
        case 4: [savePanel setRequiredFileType:HPGL_EXT];     break;
        case 5: [savePanel setRequiredFileType:TIFF_EXT];     break;
        case 6: [savePanel setRequiredFileType:FONT_EXT];     break;
        case 7: [savePanel setRequiredFileType:DIN_EXT];      break;
        default: NSLog(@"App, changeFileType: Unknown file type");
    }
}

- (void)revertToSaved:sender
{   NSString	*fileName = [[self currentDocument] filename];

    if ( [[self currentDocument] dirty]
         &&  NSRunAlertPanel(@"", REVERT_STRING, OK_STRING, CANCEL_STRING, nil, fileName)
         == NSAlertAlternateReturn )
        return;

    [[self currentDocument] setDirty:NO];

    [[[self currentDocument] window] close];
    if (![self openFile:fileName])
        NSRunAlertPanel(@"", CANTOPENFILE_STRING, OK_STRING, nil, nil);
}

/*
 * Returns an OpenPanel with the accessory view
 */
- (NSOpenPanel*)openPanel
{   NSOpenPanel	*openpanel = [NSOpenPanel openPanel];

    [openpanel setAccessoryView:openPanelAccessory];
    return openpanel;
}

- (NSSavePanel*)saveAsPanelWithSaveType:(NSString*)ext
{   NSSavePanel		*savePanel = [NSSavePanel savePanel];
    NSDictionary	*dict = [NSDictionary dictionaryWithObjectsAndKeys:@"0", DOCUMENT_EXT, @"1", EPS_EXT, @"2", GERBER_EXT, @"3", DXF_EXT, @"4", HPGL_EXT, @"5", FONT_EXT, @"6", DIN_EXT, nil];

    [savePanel setAccessoryView:[savePanelAccessory retain]];
    [savePanel setRequiredFileType:ext];
    [spaFormatPopUp selectItemAtIndex:[dict intForKey:ext]];
    [[spaFormatPopUp selectedItem] setEnabled:YES];
    return savePanel;
}

/*
 * Returns a SavePanel with the accessory view which allows the user to
 * pick which type of file she wants to save.
 */
- (NSSavePanel*)saveAsPanel
{   NSSavePanel	*savePanel = [NSSavePanel savePanel];

    /* we have to set the file type and accessory on every call,
     * because it gets destroyed sometimes !
     */
    [savePanel setAccessoryView:[savePanelAccessory retain]];
    //[self changeSaveType:spaFormatPopUp];
    [savePanel setRequiredFileType:DOCUMENT_EXT];
    [spaFormatPopUp selectItemAtIndex:0];

    //[savepanel setTitle:@"Save As"];

    return savePanel;
}

- (NSView*)printPanelAccessory
{
    if (!printPanelAccessory && ![NSBundle loadModelNamed:@"PrintPanelAccessory" owner:self])
        NSLog(@"Cannot load PrintPanelAccessory interface file");
    return printPanelAccessory;
}
- (id)ppaRadio
{
    return ppaRadio; // 0 is composite 1 is separation
}

/*
 * app:openFile: is invoked by Workspace when the user double-clicks
 * on a file Cenon is prepared to accept.
 *
 * modified: 2002-07-01
 */
- (int)application:app openFile:(NSString *)path
{   BOOL	info = NO;

#if 0
    if (!appIsRunning)
    {
        //[self init];
        info = YES;
        [self displayInfo];
        [infoPanel center];
        [infoPanel orderFront:self];
    }
#endif

    if (![self openFile:path])
        NSRunAlertPanel(@"", CANTOPENFILE_STRING, OK_STRING, nil, nil);

    if (info)
        [infoPanel orderOut:self];

    return YES;
}

/* Snapshots
 * created:  2010-01-12
 * modified: 2012-09-04 (prefer Defaults-file over System-Defaults, don't save to Defaults any more)
 *           2010-04-23
 */
- (void)takeSnapshot:sender
{   NSUserDefaults  *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableArray  *snapArray = [NSMutableArray array];
    int             count;

    for ( count=[[self windows] count]-1; count>=0; count-- )
    {	Document    *doc = [self documentInWindow:[[self windows] objectAtIndex:count]];

        if (doc)
        {   DocWindow   *window = [doc window];
            NSString    *rString = propertyListFromNSRect([window frame]);
            NSString    *sString = nil;
#ifdef __APPLE__
            if ( [window unfoldedHeight] > 20.0 )   // folded window -> save unfolded size
                sString = propertyListFromFloat([window unfoldedHeight]);
#endif
            if (sString)
                [snapArray addObject:[NSArray arrayWithObjects:[doc filename], rString, sString, nil]];
            else
                [snapArray addObject:[NSArray arrayWithObjects:[doc filename], rString, nil]];
        }
    }

    {   NSString    *path = vhfPathWithPathComponents(vhfUserLibrary(APPNAME), @".snapshots", nil);
        NSString    *file, *name = @"Default.plist";
        NSSavePanel *savePanel = [NSSavePanel savePanel];

        if ( ! [[NSFileManager defaultManager] fileExistsAtPath:path])
            [[NSFileManager defaultManager] createDirectoryAtPath:path attributes:nil];
        file = vhfPathWithPathComponents(path, name, nil);

        [savePanel setRequiredFileType:@"plist"];
        //[savePanel setCanCreateDirectories:NO];
        if ( [savePanel runModalForDirectory:path file:name] )
            file = [savePanel filename];
        else
            return;
        if ( [file rangeOfString:name].length ) // if we save to Default.plist, we also save it to Defaults
            [defaults removeObjectForKey:@"snapShotDocuments"]; // old -> delete
            //[defaults setObject:snapArray forKey:@"snapShotDocuments"];

        [snapArray writeToFile:file atomically:YES];
    }
}
- (void)restoreSnapshot:sender
{   NSUserDefaults  *defaults = [NSUserDefaults standardUserDefaults];
    NSString        *name = @"Default.plist";
    NSArray         *snapArray = nil;   //[defaults objectForKey:@"snapShotDocuments"];
    int             w, i;
    BOOL            abortOp = NO;

    if ( [sender isKindOfClass:[NSMenuItem class]] )
    {   NSString    *path = vhfPathWithPathComponents(vhfUserLibrary(APPNAME), @".snapshots", nil);
        NSString    *file = vhfPathWithPathComponents(path, name, nil);
        NSOpenPanel *openPanel = [NSOpenPanel openPanel];

        [openPanel setRequiredFileType:@"plist"];
        if ( [openPanel runModalForDirectory:path file:name] )
            file = [openPanel filename];
        else
            return;
        if ( ! (snapArray = [NSArray arrayWithContentsOfFile:file]) )   // load from file
            snapArray = [defaults objectForKey:@"snapShotDocuments"];   // no file -> load from System-Defaults
    }
    else    // load Defaults.plist or old @"snapShotDocuments" from System-Defaults
    {   NSString    *path = vhfPathWithPathComponents(vhfUserLibrary(APPNAME), @".snapshots", nil);
        NSString    *file = vhfPathWithPathComponents(path, name, nil);

        if ( ! (snapArray = [NSArray arrayWithContentsOfFile:file]) )   // load from file
            snapArray = [defaults objectForKey:@"snapShotDocuments"];   // no file -> load from System-Defaults
    }

    // TODO: check for unsaved windows before starting restore snapshot from menu
    for (w = [[self windows] count]-1; w >= 0; w--)
    {	Document    *doc = [self documentInWindow:[[self windows] objectAtIndex:w]];

        if (doc && [doc dirty])
        {
            switch (NSRunAlertPanel(CLOSEWINDOW_STRING, UNSAVEDDOCS_STRING, REVIEW_STRING, DONTSAVE_STRING, CANCEL_STRING))
            {
                case NSAlertDefaultReturn:      // review unsaved
                    w = -1;
                    break;
                case NSAlertAlternateReturn:    // close anyway
                    for (i = w; i >= 0; i--)
                        [[self documentInWindow:[[self windows] objectAtIndex:i]] setDirty:NO];
                    break;
                default:                        // cancel
                    return;
            }
        }
    }
    /* close documents which are not in snapArray */
    for ( w = [[self windows] count]-1; w >= 0; w-- )
    {	Document    *doc = [self documentInWindow:[[self windows] objectAtIndex:w]];

        if (doc)
        {   DocWindow   *window = [doc window];
            NSString    *fileName = [doc filename];
            BOOL        removeDoc = YES;

            for (i=0; i<[snapArray count]; i++)
            {   NSArray *array = [snapArray objectAtIndex:i];

                if ( [array isKindOfClass:[NSArray class]] && [array count] >= 1 )
                {   NSString    *path = [array objectAtIndex:0];

                    if ( [path isEqual:fileName] )
                    {   removeDoc = NO;
                        break;  // keep document
                    }
                }
            }   // end loop: snapArray
            if ( removeDoc )
            {
                if ( ! [doc dirty] )
                    [window performClose:self];
                else
                    abortOp = YES;
            }
        }
    }
    if ( abortOp )    // if window is not closed, then cancel
        return;	// cancel restauration

    /* open documents in snapArray */
    for (i=0; i<[snapArray count]; i++)
    {   NSArray *array = [snapArray objectAtIndex:i];

        if ( [array isKindOfClass:[NSString class]] )   // old format
            [self openFile:[snapArray objectAtIndex:i]];
        else if ([array count] >= 1)
        {   NSString    *path = [array objectAtIndex:0];
            Document    *doc;

#           ifdef __APPLE__ // keep things working through transition to new Library-location
            NSFileManager   *fileManager = [NSFileManager defaultManager];
            if ( ! [fileManager fileExistsAtPath:path] )
            {   NSString    *oldUserLib = [vhfUserLibrary(nil) stringByDeletingLastPathComponent];
                NSRange     range;

                oldUserLib = [oldUserLib stringByAppendingPathComponent:APPNAME];
                range = [path rangeOfString:oldUserLib];
                if ( range.length )
                {
                    path = [vhfUserLibrary(APPNAME) stringByAppendingPathComponent:
                            [path substringFromIndex:range.location+range.length]];
                }
            }
#           endif
            [self openFile:path];
            doc = (document) ? document : [self currentDocument];   // current doc if doc was open already

            if (doc && [[doc filename] isEqual:path] && [array count] >= 2) // point or rect
            {    NSArray    *components = [[array objectAtIndex:1] componentsSeparatedByString:@" "];

                if ( [components count] >= 4 )       // rectangle
                {   NSRect  rect = rectFromPropertyList([array objectAtIndex:1]);

                    [[doc window] setFrame:rect display:NO];
#ifdef __APPLE__
                    if ( [array count] >= 3 &&  // unfoldedSize
                        [[array objectAtIndex:2] respondsToSelector:@selector(floatValue)] )
                    {   float   h = [[array objectAtIndex:2] floatValue];
                        [[doc window] setUnfoldedHeight:h];
                    }
#endif
                }
                else                            // point only (v 3.9.1 only)
                {   NSPoint p = pointFromPropertyList([array objectAtIndex:1]);

                    [[doc window] setFrameOrigin:p];
                }
            }
        }
    }   // end loop: snapArray
}

/*
 * Methods to load model files for the various panels.
 */
- (void)displayInfo
{
    if (!infoPanel)
    {
        if (![NSBundle loadModelNamed:@"Info" owner:self])
            NSLog(@"Cannot load Info interface file");
#ifdef GNUSTEP_BASE_VERSION // FIXME: NSApplication on GNUstep has an icar named "_infoPanel" (2009-06-24)
        if ( !infoPanel && [self valueForKey:@"_infoPanel"] )
            infoPanel = [self valueForKey:@"_infoPanel"];
#endif
    }

    [serialNumber setStringValue:@""];

    /* set version number and date of compilation */
    {   NSDictionary    *infoDict = [[NSBundle mainBundle] infoDictionary];
        NSString        *version = [infoDict objectForKey:@"CFBundleShortVersionString"];

        if ( ! version )
            version = [infoDict objectForKey:@"CFBundleVersion"];   // Apple, 2nd chance
        if ( ! version )
            version = [infoDict objectForKey:@"NSVersion"];         // GNUstep
        if ( version )
        {   NSString    *compileDate = [self compileDate];

            if ( compileDate )
                version = [version stringByAppendingFormat:@" (%@)", compileDate];
            [infoVersionNo setStringValue:version]; // ex: 3.9.1 pre 1 (2010-02-13)
        }
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:InfoPanelWillDisplay
                                                        object:nil userInfo:nil];

    /*if ([keyPanel respondsToSelector:@selector(setVersionOfKey:andSerialNumber:)])
        [keyPanel performSelector:@selector(setVersionOfKey:andSerialNumber:)
                       withObject:kindOfVersion withObject:serialNumber];*/
}
- (void)showInfo:sender
{
    [self displayInfo];
    [infoPanel makeKeyAndOrderFront:sender];
}
- (NSString*)version
{   NSDictionary    *infoDict = [[NSBundle mainBundle] infoDictionary];
    NSString        *version = [infoDict objectForKey:@"CFBundleShortVersionString"];

    if ( ! version )
        version = [infoDict objectForKey:@"CFBundleVersion"];   // Apple, 2nd chance
    if ( ! version )
        version = [infoDict objectForKey:@"NSVersion"];         // GNUstep
    if ( ! version )
        version = infoVersionNo;
    return version;
}
- (NSString*)compileDate
{   char    *compileDate = __DATE__;    // Apr 10 2010
    char    date[15];

    if ( strlen(compileDate) == 11 )    // Apr  2 2010 -> 2010-04-02
    {   NSArray     *mArray;
        char        mStr[4];
        NSUInteger  m;

        strncpy(mStr, compileDate, 3); mStr[3] = 0;
        mArray = [NSArray arrayWithObjects:@"Jan", @"Feb", @"Mar", @"Apr", @"May", @"Jun", @"Jul", @"Aug", @"Sep", @"Oct", @"Nov", @"Dec", nil];
        if ( (m = [mArray indexOfObject:[NSString stringWithUTF8String:mStr]]) != NSNotFound )
        {   m ++;
            strncpy(date, compileDate+7, 4);                            // YYYY
            date[4] = '-';
            date[5] = (m >= 10) ? '1' : '0';                            // MM
            if (m >= 10) m -= 10;
            date[6] = '0' + m;
            date[7] = '-';
            date[8] = (compileDate[4] == ' ') ? '0' : compileDate[4];   // DD
            date[9] = compileDate[5];
            date[10] = 0;
            compileDate = date;
        }
    }
    if ( compileDate )
        return [NSString stringWithCString:compileDate encoding:NSASCIIStringEncoding];
    else
        return nil;
}
- (id)infoVersionNo     { return infoVersionNo; }   // ex: 3.9.0
- (id)infoVersionText	{ return kindOfVersion; }   // ex: "Licensed version"
- (id)infoSerialText	{ return serialNumber; }    // ex: 020001

- (void)showPrefsPanel:sender
{
    if (!preferencesPanel)
    {
        if (![NSBundle loadModelNamed:@"PreferencesPanel" owner:self])
            NSLog(@"Cannot load PreferencesPanel interface file");
        [preferencesPanel init];
        [preferencesPanel setFrameUsingName:@"PreferencesPanel"];
        [preferencesPanel setFrameAutosaveName:@"PreferencesPanel"];
    }
    [preferencesPanel makeKeyAndOrderFront:sender];
}
- preferencesPanel
{
    return preferencesPanel;
}

- (void)checkForUpdate:sender
{
#ifdef __APPLE__
    [[UpdateController sharedInstance] checkForUpdates:sender];
#else   // GNUstep: TODO
    {   NSString    *site;

        site = NSLocalizedString(@"http://www.cenon.info/news/news_gb.html", News);
        //site = NSLocalizedString(@"http://www.cenon.info/dApple_gb.html", Download);
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:site]];
    }
#endif
}

/* Show Web Page
 * created: 2010-05-19
 */
- (void)showWebPage:(id)sender
{   NSString    *site;
    int         tag = [(NSMenuItem*)sender tag];

	if ([sender isKindOfClass:[NSMatrix class]])
		tag = [sender selectedTag];
	switch (tag)
    {
        default: site = NSLocalizedString(@"http://www.cenon.info", Web Site); break;
        case 1:  site = NSLocalizedString(@"http://www.cenon.info/support_faq_gb.html", Web FAQ); break;
        case 2:  site = NSLocalizedString(@"http://www.cenon.info/releaseNotes_gb.html", Web Releae Notes); break;
        case 3:  site = NSLocalizedString(@"mailto:service@vhf.de?subject=Cenon%20Feedback", eMail Address); break;
        case 4:  site = NSLocalizedString(@"http://www.cenon.info/news/news_gb.html", News); break;
                 //site = NSLocalizedString(@"http://www.cenon.info/dApple_gb.html", Download); break;
    }
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:site]];
}

/* load PDF documentation
 * Note: each module can add a help menu entry to load it's docu
 * modified: 2007-07-22
 */
#if defined(GNUSTEP_BASE_VERSION) || defined(__APPLE__)	// GNUstep or Apple
- (void)showHelp:sender
{   NSArray     *localizations;
    NSString    *locale, *path, *helpFile;
    int         l, i;

    localizations = [NSBundle preferredLocalizationsFromArray:[[NSBundle mainBundle] localizations]];

    for (l=0; l<[localizations count]; l++ )
    {
        locale = [[localizations objectAtIndex:l] stringByAppendingString:@".lproj"];
        for (i=0; i<3; i++)
        {
            switch (i)
            {
                case 0: path = [[NSBundle mainBundle] resourcePath];
                    helpFile = vhfPathWithPathComponents(path, locale, @"Cenon.pdf", nil);
                    break;
                case 1: path = vhfUserLibrary(APPNAME);
                    helpFile = vhfPathWithPathComponents(path, @"Docu", locale, @"Cenon.pdf", nil);
                    break;
                case 2: path = vhfLocalLibrary(APPNAME);
                    helpFile = vhfPathWithPathComponents(path, @"Docu", locale, @"Cenon.pdf", nil);
                    break;
                default:
                    return;
            }
            if ( [[NSFileManager defaultManager] fileExistsAtPath:helpFile] )
            {   [[NSWorkspace sharedWorkspace] openFile:helpFile];
                l = [localizations count];
                break;
            }
        }
    }

    /*if ( !helpPanel && ![[NSBundle mainBundle] loadModelNamed:@"Help" owner:self] )
            NSLog(@"Cannot load Help interface file");
    [helpPanel setFrameAutosaveName:@"HelpPanel"];
    [helpPanel makeKeyAndOrderFront:sender];*/
}
#endif

- (void)showInspectorPanel:sender
{
    if (!inspectorPanel)
    {
        if (![NSBundle loadModelNamed:@"InspectorPanel" owner:self])
            NSLog(@"Cannot load InspectorPanel interface file");	
    }
    [inspectorPanel init];
    [inspectorPanel updateInspector];
    [inspectorPanel setFrameAutosaveName:@"InspectorPanel"];
    [inspectorPanel setBecomesKeyOnlyIfNeeded:YES];
    [inspectorPanel orderFront:sender];
}
- inspectorPanel
{
    return inspectorPanel;
}

- (void)showTransformPanel:sender
{
    if (!transformPanel)
    {
        if (![NSBundle loadModelNamed:@"TransformPanel" owner:self])
            NSLog(@"Cannot load TransformPanel interface file");	
        [transformPanel init];
    }
    [transformPanel setFrameAutosaveName:@"TransformPanel"];
    [transformPanel makeKeyAndOrderFront:sender];
}
- transformPanel
{
    return transformPanel;
}

- (void)showVectorizer:sender
{
    [[Vectorizer sharedInstance] showPanel:sender];
}

- (void)showProjectSettingsPanel:sender
{
    if (!projectSettingsPanel)
    {
        if (![NSBundle loadModelNamed:@"ProjectSettingsPanel" owner:self])
            NSLog(@"Cannot load ProjectSettingsPanel interface file");	
    }
    //[projectSettingsPanel setFrameAutosaveName:@"ProjectSettingsPanel"];
    [projectSettingsPanel makeKeyAndOrderFront:sender];
}
- projectSettingsPanel
{
    return projectSettingsPanel;
}

- (void)showTilePanel:sender
{
    if (!tilePanel)
    {
        if ( ![NSBundle loadModelNamed:@"TilePanel" owner:self] )
            NSLog(@"Cannot load TilePanel model");	
        [tilePanel updatePanel:sender];
    }
    [tilePanel setFrameAutosaveName:@"TilePanel"];
    [tilePanel setDelegate:self];
    [tilePanel makeKeyAndOrderFront:sender];
}
- tilePanel
{
    return tilePanel;
}

- (void)runGridPanel:sender
{
    if (!gridPanel)
    {
        if ( ![NSBundle loadModelNamed:@"GridPanel" owner:self] )
            NSLog(@"Cannot load GridPanel model");
    }

    [gridPanel update:sender];
    [gridPanel setDelegate:self];
    [gridPanel setFrameAutosaveName:@"GridPanel"];
    if (gridPanel)
        [self runModalForWindow:gridPanel];
}
- (id)gridPanel
{
    return gridPanel;
}

- (void)showWorkingAreaPanel:sender
{
    if (!workingAreaPanel)
    {
        if (![NSBundle loadModelNamed:@"WorkingAreaPanel" owner:self])
            NSLog(@"Cannot find WorkingAreaPanel model");	
    }
    [workingAreaPanel update:sender];
    [workingAreaPanel setFrameAutosaveName:@"WorkingAreaPanel"];
    [workingAreaPanel makeKeyAndOrderFront:sender];
}

- (void)showIntersectionPanel:sender
{
    if (!intersectionPanel)
    {
        if (![NSBundle loadModelNamed:@"IntersectionPanel" owner:self])
            NSLog(@"Cannot load IntersectionPanel interface file");	
    }
    [intersectionPanel setFrameAutosaveName:@"IntersectionPanel"];
    [intersectionPanel makeKeyAndOrderFront:sender];
}
- intersectionPanel;
{
    return intersectionPanel;
}

/*
 */

- (NSPanel*)toolPanel
{
    return toolPanel;
}

/* shows the tool panel
 */
- (void)showToolPanel:sender
{
    [self displayToolPanel:YES]; 
}

/* shows the tool panel
 */
- (void)displayToolPanel:(BOOL)flag
{
    if ( !toolPanel )
    {	if (![NSBundle loadModelNamed:@"ToolPanel" owner:self])
            NSLog(@"Cannot load ToolPanel interface file");
        [toolPanel setFrameUsingName:@"ToolPanel"];
        [toolPanel setFrameAutosaveName:@"ToolPanel"];
        [[NSNotificationCenter defaultCenter] postNotificationName:ToolPanelWillDisplay
                                                            object:toolPanel userInfo:nil];
    }
    [toolPanel setBecomesKeyOnlyIfNeeded:YES];
    [toolPanel setFloatingPanel:YES];
    [toolPanel orderFront:self];
}

/*
 * modified: 2004-12-03
 */
- (void)setCurrent2DTool:sender
{   id          cursor;
    id          matrix = [[[toolPanel contentView] subviews] objectAtIndex:0];
    static id   rotateCursor = nil, crossCursor = nil, scissorCursor = nil;	// the cursors

    if ( [self currentDocument] )
    {
        if (!sender && current2DTool)   // temporary arrow mode by pressing Alternate
        {   current2DTool = 0;
            [[[self currentDocument] scrollView] setDocumentCursor:[NSCursor arrowCursor]];
            return;
        }

        if (sender && sender != self)	// command key pressed
            [[[self currentDocument] window] endEditingFor:nil];	// end editing of text
        current2DTool = [(NSCell*)[matrix selectedCell] tag];
        switch (current2DTool)
        {
            case TOOL2D_ROTATE:		// rotate
                if (!rotateCursor)
                {
                    rotateCursor = [[NSCursor alloc] initWithImage:[NSImage imageNamed:@"cursorRotate.tiff"]
                                                           hotSpot:NSMakePoint(5, 2)]; // was 7, 7
                }
                cursor = rotateCursor;
                break;
            case TOOL2D_MARK:		// mark
            case TOOL2D_WEB:		// web
            case TOOL2D_LINE:		// line
            case TOOL2D_CURVE:		// curve
            case TOOL2D_ARC:		// arc
            case TOOL2D_THREAD:		// thread
            case TOOL2D_SINKING:	// sag
            case TOOL2D_RECT:		// rectangle
            case TOOL2D_PATH:		// path
            case TOOL2D_POLYLINE:	// polyline
                if (!crossCursor)
                {
                    crossCursor = [[NSCursor alloc] initWithImage:[NSImage imageNamed:@"cursorCross.tiff"]
                                                          hotSpot:NSMakePoint(7, 7)];
                }
                cursor = crossCursor;
                break;
            case TOOL2D_TEXT:		// text
                cursor = [NSCursor IBeamCursor];
                break;
            case TOOL2D_SCISSOR:	// scissor
                if (!scissorCursor)
                {
                    scissorCursor = [[NSCursor alloc] initWithImage:[NSImage imageNamed:@"cursorCutter.tiff"]
                                                            hotSpot:NSMakePoint(0, 14)];
                }
                cursor = scissorCursor;
                break;
            default:			// arrow
                cursor = [NSCursor arrowCursor];
        }
        [[[self currentDocument] scrollView] setDocumentCursor:cursor];
    }
}

/*
 * The current 2D tool used to create new Graphics.
 */
- (int)current2DTool
{
    return current2DTool;
}

/* terminating the app...
 *
 * modified: 2002-01-30
 */
- (void)terminate:(id)sender
{   int		count;

    for (count=[[self windows] count]-1; count>=0; count--)
    {	int	i;
        id	docu = [self documentInWindow:[[self windows] objectAtIndex:count]];

        if (docu && [docu dirty])
        {
            switch (NSRunAlertPanel(QUIT_STRING, UNSAVEDDOCS_STRING, REVIEW_STRING, QUITANYWAY_STRING, CANCEL_STRING))
            {
                case NSAlertDefaultReturn:	// review unsaved
                    count = -1;
                    break;
                case NSAlertAlternateReturn:	// quit
                    for (i=count; i>=0; i--)
                        [[self documentInWindow:[[self windows] objectAtIndex:i]] setDirty:NO];
                    break;
                default:			// cancel
                    return;
            }
        }
    }

    /* close doc windows, so the user has a chance to check dirty windows */
    for (count=[[self windows] count]-1; count>=0; count--)
        [[[self documentInWindow:[[self windows] objectAtIndex:count]] window] performClose:self];

    /* If window is not closed, then cancel */
    for (count=[[self windows] count]-1; count>=0; count--)
        if ([[self documentInWindow:[[self windows] objectAtIndex:count]] window])
            return;	// cancel termination

    /* terminate sub processes */
    for (count=[modules count]-1; count>=0; count--)
    {  NSBundle     *module = [modules objectAtIndex:count];

        if ( [[[module principalClass] instance] respondsToSelector:@selector(terminate)] )
            [[[module principalClass] instance] terminate];
    }

    [super terminate:sender];
}

- (BOOL)command		{ return command; }
- (BOOL)control		{ return control; }
- (BOOL)alternate	{ return alternate; }

/* created:  1995-11-05
 * modified: 2010-02-18 (right mouse down exits editing modes)
 *           2009-03-27
 *
 * We override this because we need to find out when the command key is down
 * and to change ',' to '.' for the decimal separator on the numeric pad
 */
- (void)sendEvent:(NSEvent *)event
{
#ifdef __APPLE__
    /* Change ',' to '.' */
    if ( event && [event type] == NSKeyDown && [event keyCode] == 65 )    // decimal-key: we want a '.'
    {   NSString    *chars = [event charactersIgnoringModifiers];

        chars = @".";   // we change ',' to '.'
        event = [NSEvent keyEventWithType:[event type]
                                 location:[event locationInWindow]
                            modifierFlags:[event modifierFlags]
                                timestamp:[event timestamp]
                             windowNumber:[event windowNumber]
                                  context:[event context]
                               characters:chars
              charactersIgnoringModifiers:chars
                                isARepeat:[event isARepeat]
                                  keyCode:[event keyCode]];
    }
#endif

    /* find out if command is pressed */
    if (event && [event type] < NSAppKitDefined)
    {	BOOL	lastCommand = command;

        command = ([event modifierFlags] & NSCommandKeyMask) ? YES : NO;
        control = ([event modifierFlags] & NSControlKeyMask) ? YES : NO;
        alternate = ([event modifierFlags] & NSAlternateKeyMask) ? YES : NO;
        shift = ([event modifierFlags] & NSShiftKeyMask) ? YES : NO;

        /* temporary set arrow mode
         */
        if (command != lastCommand)
            [self setCurrent2DTool:(command) ? nil : (id)self];

        if (command && [event type] == NSKeyDown &&
            [[self mainWindow] isMemberOfClass:[DocWindow class]])
        {   NSString    *string = [event charactersIgnoringModifiers];
            int         i = [string intValue];
            id          fe = [[self mainWindow] fieldEditor:NO forObject:nil];

            /* set inspector panel only, if no text ruler is activated,
             * to avoid setting the inspector when rulers are copied
             */
            if (![fe isRulerVisible])
            {
                if (i >= 1 && i<= 5)
                {
                    if (!inspectorPanel)
                        [self showInspectorPanel:self];
                    [inspectorPanel setLevelAt:i-1];
                    return;
                }
            }
        }
        /* right mouse down - we exit editing mode */
        if ([event type] == NSRightMouseDown && current2DTool)
        {   id  matrix = [[[toolPanel contentView] subviews] objectAtIndex:0];

            [matrix selectCellWithTag:0];
            [self setCurrent2DTool:self];
        }
    }

    [super sendEvent:event];
}

/*
 * Can be called to see if the specified action is valid now.
 * It returns NO if the action is not valid now,
 * otherwise it returns YES.
 */
//- (BOOL)validateMenuItem:(id <NSMenuItem>)anItem
- (BOOL)validateMenuItem:(NSMenuItem*)anItem
{   SEL	action = [anItem action];

    if ( (action == @selector(import:) ||
          action == @selector(revertToSaved:) ||
          action == @selector(save:) ||
          action == @selector(saveAs:)) &&
         ![self currentDocument] )
        return NO;

    return YES;
}


- (BOOL)windowShouldClose:(id)sender
{
    if ( sender == contourPanel || sender == gridPanel )
        [NSApp stopModalWithCode:YES];

    return YES;
}

@end
