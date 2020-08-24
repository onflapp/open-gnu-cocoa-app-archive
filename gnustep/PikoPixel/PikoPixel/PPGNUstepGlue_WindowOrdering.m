/*
    PPGNUstepGlue_WindowOrdering.m

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

//  Workaround for window-ordering issue in GNUstep when running on Compiz, KWin, or Xfwm window
// managers: Document windows can appear in front of higher-level windows, such as submenus
// & floating windows.
//
//  Refactored in version 1.0 BETA9d, since the previous version of this workaround caused
// PikoPixel's panels to occasionally show up in the window list of Xfce's menu bar (which
// should only list document windows). Compiz & KWin weren't affected by this issue.
//
//  As of 1.0 BETA9d, also fixed an app-deactivate issue on Xfwm: Closing the Layers panel or
// the Tool Modifier Tips panel using the panel's close button sends the main window to the
// background and deactivates PikoPixel (oddly, this issue doesn't happen with the other panels).
//  The app-deactivate issue seems to be caused by the window-ordering workaround itself,
// because the issue disappears if PikoPixel runs with the workaround disabled (the issue also
// appeared with the previous version of the workaround). Compiz & KWin don't seem to be
// affected by this issue, so the app-deactivate workaround is only installed when running on
// Xfwm. (Workaround is to set a cutoff date of 0.3 seconds after the user closes a panel, and
// if the app is deactivated before the cutoff date, it's automatically reactivated).

#ifdef GNUSTEP

#import <Cocoa/Cocoa.h>
#import "NSObject_PPUtilities.h"
#import "PPAppBootUtilities.h"
#import "PPGNUstepGlueUtilities.h"
#import "PPApplication.h"
#import "PPDocumentWindowController.h"
#import "PPPanelController.h"
#import "PPPanelsController.h"
#import "PPPopupPanelsController.h"
#import "PPScreencastController.h"
#import "PPScreencastPopupPanelController.h"


// Install WindowOrdering glue only if the window manager is Compiz, KWin, or Xfwm
#define kTargetWindowManagerTypesMask_WindowOrdering        \
                (kPPGSWindowManagerTypeMask_Compiz          \
                | kPPGSWindowManagerTypeMask_KWin           \
                | kPPGSWindowManagerTypeMask_Xfwm)

// Install WindowOrdering app-deactivate workaround only if the window manager is Xfwm
#define kTargetWindowManagerTypesMask_WindowOrdering_AppDeactivateWorkaround    \
                (kPPGSWindowManagerTypeMask_Xfwm)

#define kTimeIntervalToDisallowAppDeactivateAfterPanelClose (0.3)


static NSDate *gCutoffDateForDisallowingAppDeactivate = nil;


@interface NSMenu (PPGNUstepGlue_WindowOrderingUtilities)
- (void) ppGSGlue_SetAllMenuWindowsToMainMenuLevel;
@end

@interface NSWindow (PPGNUstepGlue_WindowOrderingUtilities)
- (void) ppGSGlue_SetupToRemainInFrontOfWindow: (NSWindow *) window;
@end

@interface PPPanelController (PPGNUstepGlue_WindowOrderingUtilities)
- (void) ppGSGlue_SetupPanelToRemainInFrontOfWindow: (NSWindow *) window;
@end

@interface PPPanelsController (PPGNUstepGlue_WindowOrderingUtilities)
- (void) ppGSGlue_SetupPanelsToRemainInFrontOfWindow: (NSWindow *) window;
@end

@interface PPPopupPanelsController (PPGNUstepGlue_WindowOrderingUtilities)
- (void) ppGSGlue_SetupPopupPanelsToRemainInFrontOfWindow: (NSWindow *) window;
@end

@interface PPDocumentWindowController (PPGNUstepGlue_WindowOrderingUtilities)
- (void) ppGSGlue_SetupAllPanelsToRemainInFrontOfWindow: (NSWindow *) window;
@end

#if PP_OPTIONAL__BUILD_WITH_SCREENCASTING

@interface PPScreencastController (PPGNUstepGlue_WindowOrderingUtilities)
- (void) ppGSGlue_WindowOrdering_HandleScreencastEnableOrDisable;
- (void) ppGSGlue_SetupScreencastPopupToRemainInFrontOfWindow: (NSWindow *) window;
@end

#endif  // PP_OPTIONAL__BUILD_WITH_SCREENCASTING


@implementation NSObject (PPGNUstepGlue_WindowOrdering)

+ (void) ppGSGlue_WindowOrdering_InstallPatches
{
    macroSwizzleInstanceMethod(PPApplication, runModalForWindow:,
                                ppGSPatch_WindowOrdering_RunModalForWindow:);

    macroSwizzleInstanceMethod(PPDocumentWindowController, windowDidBecomeMain:,
                                ppGSPatch_WindowDidBecomeMain:);
}

+ (void) ppGSGlue_WindowOrdering_AppDeactivateWorkaround_InstallPatches
{
    macroSwizzleInstanceMethod(PPPanelController, windowShouldClose:,
                                ppGSPatch_WindowShouldClose:);

    macroSwizzleInstanceMethod(PPApplication, deactivate, ppGSPatch_Deactivate);
}

+ (void) ppGSGlue_WindowOrdering_Install
{
    if (!PPGSGlueUtils_WindowManagerMatchesTypeMask(
                                                kTargetWindowManagerTypesMask_WindowOrdering))
    {
        return;
    }

    [self ppGSGlue_WindowOrdering_InstallPatches];

    if (PPGSGlueUtils_WindowManagerMatchesTypeMask(
                        kTargetWindowManagerTypesMask_WindowOrdering_AppDeactivateWorkaround))
    {
        [self ppGSGlue_WindowOrdering_AppDeactivateWorkaround_InstallPatches];
    }

    [[NSApp mainMenu] ppGSGlue_SetAllMenuWindowsToMainMenuLevel];

#if PP_OPTIONAL__BUILD_WITH_SCREENCASTING

    PPGSGlueUtils_PerformPPScreencastControllerSelectorOnEnableOrDisable(
                    @selector(ppGSGlue_WindowOrdering_HandleScreencastEnableOrDisable));

#endif  // PP_OPTIONAL__BUILD_WITH_SCREENCASTING
}

+ (void) load
{
    macroPerformNSObjectSelectorAfterAppLoads(ppGSGlue_WindowOrdering_Install);
}

@end

@implementation PPApplication (PPGNUstepGlue_WindowOrdering)

- (NSInteger) ppGSPatch_WindowOrdering_RunModalForWindow: (NSWindow *) theWindow
{
    NSInteger returnValue;
    bool didManuallyOrderModalWindowToFront = NO;

    if (![theWindow parentWindow])
    {
        [theWindow ppGSGlue_SetupToRemainInFrontOfWindow: [self mainWindow]];
        didManuallyOrderModalWindowToFront = YES;
    }

    returnValue = [self ppGSPatch_WindowOrdering_RunModalForWindow: theWindow];

    if (didManuallyOrderModalWindowToFront)
    {
        [theWindow ppGSGlue_SetupToRemainInFrontOfWindow: nil];
    }

    return returnValue;
}

@end

@implementation PPDocumentWindowController (PPGNUstepGlue_WindowOrdering)

- (void) ppGSPatch_WindowDidBecomeMain: (NSNotification *) notification
{
    [self ppGSPatch_WindowDidBecomeMain: notification];

    [self ppGSGlue_SetupAllPanelsToRemainInFrontOfWindow: [notification object]];
}

@end

@implementation PPPanelController (PPGNUstepGlue_WindowOrdering_AppDeactivateWorkaround)

- (BOOL) ppGSPatch_WindowShouldClose: (id) sender
{
    [gCutoffDateForDisallowingAppDeactivate release];
    gCutoffDateForDisallowingAppDeactivate =
        [[NSDate dateWithTimeIntervalSinceNow:
                                        kTimeIntervalToDisallowAppDeactivateAfterPanelClose]
            retain];

    return [self ppGSPatch_WindowShouldClose: sender];
}

@end

@implementation PPApplication (PPGNUstepGlue_WindowOrdering_AppDeactivateWorkaround)

- (void) ppGSPatch_Deactivate
{
    [self ppGSPatch_Deactivate];

    if (gCutoffDateForDisallowingAppDeactivate)
    {
        if ([gCutoffDateForDisallowingAppDeactivate timeIntervalSinceNow] > 0)
        {
            [self performSelector: @selector(unhide:) withObject: self afterDelay: 0.0];
        }

        [gCutoffDateForDisallowingAppDeactivate release];
        gCutoffDateForDisallowingAppDeactivate = nil;
    }
}

@end

@implementation NSMenu (PPGNUstepGlue_WindowOrderingUtilities)

- (void) ppGSGlue_SetAllMenuWindowsToMainMenuLevel
{
    NSWindow *menuWindow;
    NSEnumerator *menuItemsEnumerator;
    NSMenuItem *menuItem;

    menuWindow = [self window];

    if ([menuWindow level] != NSMainMenuWindowLevel)
    {
        [menuWindow setLevel: NSMainMenuWindowLevel];
    }

    menuItemsEnumerator = [[self itemArray] objectEnumerator];

    while (menuItem = [menuItemsEnumerator nextObject])
    {
        if ([menuItem hasSubmenu])
        {
            [[menuItem submenu] ppGSGlue_SetAllMenuWindowsToMainMenuLevel];
        }
    }
}

@end

@implementation NSWindow (PPGNUstepGlue_WindowOrderingUtilities)

- (void) ppGSGlue_SetupToRemainInFrontOfWindow:  (NSWindow *) window
{
    NSWindow *currentParentWindow = [self parentWindow];

    if (currentParentWindow == window)
    {
        return;
    }

    if (currentParentWindow)
    {
        [currentParentWindow removeChildWindow: self];
    }

    if (window)
    {
        [window addChildWindow: self ordered: NSWindowAbove];

        if ([self isVisible])
        {
            [self orderWindow: NSWindowAbove relativeTo: [window windowNumber]];
        }
    }
}

@end

@implementation PPPanelController (PPGNUstepGlue_WindowOrderingUtilities)

- (void) ppGSGlue_SetupPanelToRemainInFrontOfWindow: (NSWindow *) window
{
    [[self window] ppGSGlue_SetupToRemainInFrontOfWindow: window];
}

@end

@implementation PPPanelsController (PPGNUstepGlue_WindowOrderingUtilities)

- (void) ppGSGlue_SetupPanelsToRemainInFrontOfWindow: (NSWindow *) window
{
    [_panelControllers makeObjectsPerformSelector:
                                        @selector(ppGSGlue_SetupPanelToRemainInFrontOfWindow:)
                        withObject: window];
}

@end

@implementation PPPopupPanelsController (PPGNUstepGlue_WindowOrderingUtilities)

- (void) ppGSGlue_SetupPopupPanelsToRemainInFrontOfWindow: (NSWindow *) window
{
    [_popupControllers makeObjectsPerformSelector:
                                        @selector(ppGSGlue_SetupPanelToRemainInFrontOfWindow:)
                        withObject: window];
}

@end

#if PP_OPTIONAL__BUILD_WITH_SCREENCASTING

@implementation PPScreencastController (PPGNUstepGlue_WindowOrderingUtilities)

- (void) ppGSGlue_WindowOrdering_HandleScreencastEnableOrDisable
{
    NSWindow *window = (_screencastingIsEnabled) ? [NSApp mainWindow] : nil;

    [_screencastPopupController ppGSGlue_SetupPanelToRemainInFrontOfWindow: window];
}

- (void) ppGSGlue_SetupScreencastPopupToRemainInFrontOfWindow: (NSWindow *) window
{
    if (!_screencastingIsEnabled)
        return;

    [_screencastPopupController ppGSGlue_SetupPanelToRemainInFrontOfWindow: window];
}

@end

#endif  // PP_OPTIONAL__BUILD_WITH_SCREENCASTING

@implementation PPDocumentWindowController (PPGNUstepGlue_WindowOrderingUtilities)

- (void) ppGSGlue_SetupAllPanelsToRemainInFrontOfWindow: (NSWindow *) window
{
    static NSWindow *previousWindow = nil;

    if (!window || (window == previousWindow))
    {
        return;
    }

    [_panelsController ppGSGlue_SetupPanelsToRemainInFrontOfWindow: window];

    [_popupPanelsController ppGSGlue_SetupPopupPanelsToRemainInFrontOfWindow: window];

    [[NSColorPanel sharedColorPanel] ppGSGlue_SetupToRemainInFrontOfWindow: window];

#if PP_OPTIONAL__BUILD_WITH_SCREENCASTING

    [[PPScreencastController sharedController]
                                ppGSGlue_SetupScreencastPopupToRemainInFrontOfWindow: window];

#endif  // PP_OPTIONAL__BUILD_WITH_SCREENCASTING

    [previousWindow release];
    previousWindow = [window retain];
}

@end

#endif  // GNUSTEP

