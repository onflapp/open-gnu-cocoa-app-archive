/*
    PPGNUstepGlue_ModalSessions.m

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

// Workarounds for issues during GNUstep modal dialog sessions:
// - During a modal session, should not be able to start a new modal session in a different
// document window (new/open/save menu actions)
// - Panels stay visible during save & alert dialogs because they're not sheets on GNUstep, so
// manually post NSWindow willBeginSheet & didEndSheet notifications (triggers panel-hiding
// logic), and add additonal logic to keep panels hidden during non-sheet modal sessions
// - Screencasting implementation currently misses events during modal sessions, so manually
// hide the screencasting popup when a modal session begins

#ifdef GNUSTEP

#import <Cocoa/Cocoa.h>
#import "NSObject_PPUtilities.h"
#import "PPAppBootUtilities.h"
#import "PPApplication.h"
#import "PPPanelsController.h"
#import "PPDocumentWindow.h"
#import "PPScreencastController.h"
#import "PPGNUstepGlueUtilities.h"


#define kMinTimeIntervalToAllowNewDocumentAfterModalSessionEnds     (0.5)


static int gModalSessionCount = 0;
static NSTimeInterval gLastModalSessionEndTime = 0;
static bool gDisallowManualPostingOfSheetNotifications = NO, gScreencastingIsEnabled = NO;


static inline NSSet *DisallowedModalActionNamesSet(void)
{
    return [NSSet setWithObjects: @"newDocument:", @"newDocumentFromSelection:",
                                    @"newDocumentFromPasteboard:", @"openDocument:",
                                    @"saveDocument:", @"saveDocumentAs:", @"saveDocumentTo:",
                                    @"editHotkeySettings:", nil];
}


@interface PPApplication (PPGNUstepGlue_ModalSessionsUtilities)

- (void) ppGSGlue_DecrementModalSessionCount;

@end

@implementation NSObject (PPGNUstepGlue_ModalSessions)

+ (void) ppGSGlue_ModalSessions_InstallPatches
{
    macroSwizzleInstanceMethod(PPApplication,
                                beginSheet:modalForWindow:modalDelegate:
                                    didEndSelector:contextInfo:,
                                ppGSPatch_BeginSheet:modalForWindow:modalDelegate:
                                    didEndSelector:contextInfo:);

    macroSwizzleInstanceMethod(PPApplication, runModalForWindow:,
                                ppGSPatch_ModalSessions_RunModalForWindow:);


    macroSwizzleInstanceMethod(NSMenu, performActionForItemAtIndex:,
                                ppGSPatch_PerformActionForItemAtIndex:);


    macroSwizzleInstanceMethod(NSDocumentController, newDocument:, ppGSPatch_NewDocument:);


    macroSwizzleInstanceMethod(PPPanelsController, updatePanelsVisibilityAllowedForWindow:,
                                ppGSPatch_UpdatePanelsVisibilityAllowedForWindow:);
}

+ (void) ppGSGlue_ModalSessions_Install
{
    [self ppGSGlue_ModalSessions_InstallPatches];

#if PP_OPTIONAL__BUILD_WITH_SCREENCASTING

    PPGSGlueUtils_PerformPPScreencastControllerSelectorOnEnableOrDisable(
                    @selector(ppGSGlue_ModalSessions_HandleScreencastEnableOrDisable));

#endif  // PP_OPTIONAL__BUILD_WITH_SCREENCASTING
}

+ (void) load
{
    macroPerformNSObjectSelectorAfterAppLoads(ppGSGlue_ModalSessions_Install);
}

@end

@implementation PPApplication (PPGNUstepGlue_ModalSessions)

- (void) ppGSPatch_BeginSheet: (NSWindow *) sheet
            modalForWindow: (NSWindow *) docWindow
            modalDelegate: (id) modalDelegate
            didEndSelector: (SEL) didEndSelector
            contextInfo: (void *) contextInfo
{
    bool oldDisallowManualPostingOfSheetNotifications =
                                                gDisallowManualPostingOfSheetNotifications;

    gDisallowManualPostingOfSheetNotifications = YES;

    [self ppGSPatch_BeginSheet: sheet
            modalForWindow: docWindow
            modalDelegate: modalDelegate
            didEndSelector: didEndSelector
            contextInfo: contextInfo];

    gDisallowManualPostingOfSheetNotifications = oldDisallowManualPostingOfSheetNotifications;
}

- (NSInteger) ppGSPatch_ModalSessions_RunModalForWindow: (NSWindow *) theWindow
{
    NSInteger returnValue;
    NSWindow *notifyingWindow = nil;
    bool shouldSendSheetNotifications;

    gModalSessionCount++;

#if PP_OPTIONAL__BUILD_WITH_SCREENCASTING

    if (gScreencastingIsEnabled)
    {
        [[PPScreencastController sharedController] performSelector:
                                                             @selector(clearScreencastState)];
    }

#endif  // PP_OPTIONAL__BUILD_WITH_SCREENCASTING

    shouldSendSheetNotifications = (gDisallowManualPostingOfSheetNotifications) ? NO : YES;

    if (shouldSendSheetNotifications)
    {
        notifyingWindow = [theWindow parentWindow];

        if (!notifyingWindow)
        {
            notifyingWindow = [self mainWindow];
        }

        [[NSNotificationCenter defaultCenter]
                                    postNotificationName: NSWindowWillBeginSheetNotification
                                    object: notifyingWindow];
    }

    returnValue = [self ppGSPatch_ModalSessions_RunModalForWindow: theWindow];

    if (shouldSendSheetNotifications)
    {
        [[NSNotificationCenter defaultCenter]
                                    postNotificationName: NSWindowDidEndSheetNotification
                                    object: notifyingWindow];
    }

    gModalSessionCount--;

    gLastModalSessionEndTime = [NSDate timeIntervalSinceReferenceDate];

    return returnValue;
}

- (void) ppGSGlue_DecrementModalSessionCount
{
    gModalSessionCount--;
}

@end

@implementation NSMenu (PPGNUstepGlue_ModalSessions)

- (void) ppGSPatch_PerformActionForItemAtIndex: (NSInteger) index
{
    if (gModalSessionCount > 0)
    {
        static NSSet *disallowedModalActionNamesSet = nil;

        SEL action = [[self itemAtIndex: index] action];
        NSString *actionName = (action) ? NSStringFromSelector(action) : nil;

        if (!disallowedModalActionNamesSet)
        {
            disallowedModalActionNamesSet = [DisallowedModalActionNamesSet() retain];
        }

        if (actionName && [disallowedModalActionNamesSet containsObject: actionName])
        {
            return;
        }
    }

    [self ppGSPatch_PerformActionForItemAtIndex: index];
}

@end

@implementation NSDocumentController (PPGNUstepGlue_ModalSessions)

- (void) ppGSPatch_NewDocument: (id) sender
{
    if (([NSDate timeIntervalSinceReferenceDate] - gLastModalSessionEndTime)
            < kMinTimeIntervalToAllowNewDocumentAfterModalSessionEnds)
    {
        return;
    }

    gModalSessionCount++;

    [self ppGSPatch_NewDocument: sender];

    [NSApp ppPerformSelectorFromNewStackFrame: @selector(ppGSGlue_DecrementModalSessionCount)];
}

@end

@interface PPPanelsController (PPGNUstepGlue_ModalSessions_PrivateMethodDeclarations)

// -[PPPanelsController updatePanelsVisibilityAllowedForWindow:] patch below needs to call
// private PPPanelsController method:
- (void) setPanelsVisibilityAllowed: (bool) panelsVisibilityAllowed;

@end

@implementation PPPanelsController (PPGNUstepGlue_ModalSessions)

- (void) ppGSPatch_UpdatePanelsVisibilityAllowedForWindow: (NSWindow *) window
{
    bool panelsVisibilityAllowed = NO;

    if (([window class] == [PPDocumentWindow class]) && ![window attachedSheet]
        && (gModalSessionCount <= 0))
    {
        panelsVisibilityAllowed = YES;
    }

    [self setPanelsVisibilityAllowed: panelsVisibilityAllowed];
}

@end

#if PP_OPTIONAL__BUILD_WITH_SCREENCASTING

@implementation PPScreencastController (PPGNUstepGlue_ModalSessions)

- (void) ppGSGlue_ModalSessions_HandleScreencastEnableOrDisable
{
    gScreencastingIsEnabled = (_screencastingIsEnabled) ? YES : NO;
}

@end

#endif  // PP_OPTIONAL__BUILD_WITH_SCREENCASTING

#endif  // GNUSTEP

