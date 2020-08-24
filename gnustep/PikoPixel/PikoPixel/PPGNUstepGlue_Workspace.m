/*
    PPGNUstepGlue_Workspace.m

    Copyright 2014-2018 Josh Freeman
    http://www.twilightedge.com

    This file is part of PikoPixel for GNUstep.
    PikoPixel is a graphical application for drawing & editing pixel-art images.

    PikoPixel is free software: you can redistribute it and/or modify it under
    the terms of the GNU Affero General Public License as published by the
    Free Software Foundation, either version 3 of the License, or (at your
    option) any later version approved for PikoPixel by its copyright holder (or
    an authorized proxy).

    PikoPixel is distributed in the hope that it will be useful, but WITHOUT ANY
    WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
    FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
    details.

    You should have received a copy of the GNU Affero General Public License
    along with this program. If not, see <http://www.gnu.org/licenses/>.
*/

// 1) Set up user default values for the app workspace:
// - Allow only one running instance of PikoPixel at a time
// - Suppress PikoPixel's app-icon desktop-window
// - Prevent minimized document windows from appearing as an icon window on the desktop (they'll
// still appear in the taskbar)
//
// 2) Workaround for issue when allowing only one running instance: Can't open image files from
// the desktop/filebrowser when there's already an instance running because the second instance
// (that receives the filepaths) quits immediately; Fixed by adding functionality to transmit
// filepaths from the second instance to the first, and open them in the first instance

#ifdef GNUSTEP

#import <Cocoa/Cocoa.h>
#import "NSObject_PPUtilities.h"
#import "PPAppBootUtilities.h"
#import "PPGNUstepGlueUtilities.h"
#import "PPGNUstepUserDefaults.h"
#import "GNUstepGUI/GSServicesManager.h"
#import "PPApplication.h"


#define kPPGSUserDefaultsKey_UseGSNativeWorkspaceDefaults   @"PPUseGSNativeWorkspaceDefaults"


@protocol PPAppProxyOpenFileAtPath

- (oneway void) ppAppProxyOpenFileAtPath: (NSString *) filepath;

@end


@interface NSUserDefaults (PPGNUstepGlue_WorkspaceUtilities)

- (void) ppGSGlue_Workspace_SetupAppDefaults;

@end

@interface GSServicesManager (PPGNUstepGlue_WorkspaceUtilities)

- (void) ppGSGlue_HandleNSAppNotification_WillTerminate: (NSNotification *) notification;

@end

@interface PPApplication (PPGNUstepGlue_WorkspaceUtilities) <PPAppProxyOpenFileAtPath>
@end

@implementation NSObject (PPGNUstepGlue_Workspace)

+ (void) ppGSGlue_Workspace_InstallPatches
{
    macroSwizzleInstanceMethod(GSServicesManager, registerAsServiceProvider,
                                ppGSPatch_RegisterAsServiceProvider);
}

+ (void) load
{
    PPGSGlueUtils_PerformNSUserDefaultsSelectorBeforeGSBackendLoads(
                                            @selector(ppGSGlue_Workspace_SetupAppDefaults));

    macroPerformNSObjectSelectorAfterAppLoads(ppGSGlue_Workspace_InstallPatches);
}

@end

@implementation NSUserDefaults (PPGNUstepGlue_WorkspaceUtilities)

- (void) ppGSGlue_Workspace_SetupAppDefaults
{
    NSDictionary *defaultsDict;
    bool useRunningCopy = YES,  // YES: allow only one running instance of the application
        suppressAppIcon = YES,  // YES: suppress the app-icon desktop-window
        appOwnsMiniwindow = NO; // NO: suppress minimized-document desktop-windows

    if ([self boolForKey: kPPGSUserDefaultsKey_UseGSNativeWorkspaceDefaults])
    {
        return;
    }

    if (PPGSGlueUtils_WindowManagerMatchesTypeMask(kPPGSWindowManagerTypeMask_WindowMaker))
    {
        // If using WindowMaker WM, enable the app-icon & minimized-document desktop-windows
        // (Causes issues with WM if they're disabled)
        suppressAppIcon = NO;
        appOwnsMiniwindow = YES;
    }
    else if (![[self stringForKey: kGSUserDefaultsKey_InterfaceStyleName]
                        isEqualToString: kGSUserDefaultsValue_InterfaceStyleName_Windows95])
    {
        // If not using Windows95 interface style, enable the app-icon window (clicking on it
        // is the only way to bring a background app with no open document windows to the front)
        suppressAppIcon = NO;
    }

    defaultsDict = [NSDictionary dictionaryWithObjectsAndKeys:

                                        [NSNumber numberWithBool: useRunningCopy],
                                    kGSUserDefaultsKey_UseRunningCopy,

                                        [NSNumber numberWithBool: suppressAppIcon],
                                    kGSUserDefaultsKey_SuppressAppIcon,

                                        [NSNumber numberWithBool: appOwnsMiniwindow],
                                    kGSUserDefaultsKey_AppOwnsMiniwindow,

                                        nil];

    if (defaultsDict)
    {
        [self registerDefaults: defaultsDict];
    }
}

@end

@implementation GSServicesManager (PPGNUstepGlue_Workspace)

- (void) ppGSPatch_RegisterAsServiceProvider
{
    NSNotificationCenter *notificationCenter = nil;
    bool useRunningCopy;

    useRunningCopy =
        [[NSUserDefaults standardUserDefaults] boolForKey: kGSUserDefaultsKey_UseRunningCopy];

    if (useRunningCopy)
    {
        notificationCenter = [[NSNotificationCenter defaultCenter] retain];

        [notificationCenter addObserver: self
                            selector: @selector(ppGSGlue_HandleNSAppNotification_WillTerminate:)
                            name: NSApplicationWillTerminateNotification
                            object: NSApp];
    }

    [self ppGSPatch_RegisterAsServiceProvider];

    if (useRunningCopy)
    {
        [notificationCenter removeObserver: self
                            name: NSApplicationWillTerminateNotification
                            object: NSApp];

        [notificationCenter release];
    }
}

- (void) ppGSGlue_HandleNSAppNotification_WillTerminate: (NSNotification *) notification
{
    NSArray *filesToOpen;
    NSString *processName, *filepath;
    NSDistantObject <PPAppProxyOpenFileAtPath> *runningAppProxy;
    NSEnumerator *filesEnumerator;

    // _openFiles & _openDocument: are private NSApplication methods, so manually check that
    // NSApp responds to them (in case they've been renamed or removed in a future version of
    // the gnustep-gui framework)
    if (![NSApp respondsToSelector: @selector(_openFiles)]
        || ![NSApp respondsToSelector: @selector(_openDocument:)])
    {
        return;
    }

    filesToOpen = [NSApp performSelector: @selector(_openFiles)];

    if (!filesToOpen
        || ![filesToOpen isKindOfClass: [NSArray class]]
        || ![filesToOpen count])
    {
        return;
    }

    processName = [[NSProcessInfo processInfo] processName];

    if (!processName)
        return;

    runningAppProxy =
        (NSDistantObject <PPAppProxyOpenFileAtPath> *)
            [NSConnection rootProxyForConnectionWithRegisteredName: processName
                            host: @""];

    if (!runningAppProxy)
        return;

    [runningAppProxy setProtocolForProxy: @protocol(PPAppProxyOpenFileAtPath)];

    filesEnumerator = [filesToOpen objectEnumerator];

    while (filepath = [filesEnumerator nextObject])
    {
        [runningAppProxy ppAppProxyOpenFileAtPath: filepath];
    }
}

@end

@implementation PPApplication (PPGNUstepGlue_WorkspaceUtilities)

- (oneway void) ppAppProxyOpenFileAtPath: (NSString *) filepath
{
    [self performSelector: @selector(_openDocument:) withObject: filepath];
}

@end

#endif  // GNUSTEP

