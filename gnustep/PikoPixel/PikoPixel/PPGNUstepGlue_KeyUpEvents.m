/*
    PPGNUstepGlue_KeyUpEvents.m

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

#ifdef GNUSTEP

#import <Cocoa/Cocoa.h>
#import "NSObject_PPUtilities.h"
#import "PPAppBootUtilities.h"
#import "PPDocumentWindowController.h"
#import "PPScreencastController.h"
#import "PPHotkeys.h"
#import "PPCanvasView.h"


#define kKeyDownTimeoutInterval                 (3.0)

#define kKeyUpTimeoutInterval                   (0.1)

#define kKeyUpCheckTimerInterval                (0.03)

#define kKeyUpCheckSystemLagInterval            (kKeyUpCheckTimerInterval + 0.015)

#define kNumKeyUpChecksToSkipAfterSystemLag     3


static NSEvent *gKeyUpEvent_PopupHotkey = nil, *gKeyUpEvent_BlinkLayersHotkey = nil;
static NSDate *gKeyUpDate_LastCheckTimerFire = nil, *gKeyUpDate_PopupHotkey = nil,
                *gKeyUpDate_BlinkLayersHotkey = nil;
static bool gKeyUpCheckTimerIsRunning = NO;


@interface PPDocumentWindowController (PPGNUstepGlue_KeyUpEventsUtilities)

- (void) ppGSGlue_StartKeyUpCheckTimer;
- (void) ppGSGlue_StopKeyUpCheckTimer: (NSTimer *) keyUpCheckTimer;
- (void) ppGSGlue_KeyUpCheckTimerDidFire: (NSTimer *) timer;

- (void) ppGSGlue_ClearKeyUpGlobals_PopupHotkey;
- (void) ppGSGlue_ClearKeyUpGlobals_BlinkLayersHotkey;
- (void) ppGSGlue_ClearKeyUpGlobals_AllHotkeys;

@end

#if PP_OPTIONAL__BUILD_WITH_SCREENCASTING

typedef struct
{
    NSString *key;
    NSDate *date;

} PPKeyUpDate;

static NSDate *gScreencastKeyUpDate_LastCheckTimerFire = nil;
static bool gScreencastKeyUpCheckTimerIsRunning = NO;
static PPKeyUpDate gScreencastKeyUpDates[kScreencastMaxSimultaneousKeysAllowed];
static int gNumScreencastKeyUpDates = 0;

@interface PPScreencastController (PPGNUstepGlue_KeyUpEventsUtilities)

- (void) ppGSGlue_SetKeyUpDate: (NSDate *) date forKey: (NSString *) key;

- (void) ppGSGlue_StartScreencastKeyUpCheckTimer;
- (void) ppGSGlue_StopScreencastKeyUpCheckTimer: (NSTimer *) keyUpCheckTimer;
- (void) ppGSGlue_ScreencastKeyUpCheckTimerDidFire: (NSTimer *) timer;

@end

#endif  // PP_OPTIONAL__BUILD_WITH_SCREENCASTING

@implementation NSObject (PPGNUstepGlue_KeyUpEvents)

+ (void) ppGSGlue_KeyUpEvents_InstallPatches
{
    macroSwizzleInstanceMethod(PPDocumentWindowController, keyDown:, ppGSPatch_KeyDown:);

    macroSwizzleInstanceMethod(PPDocumentWindowController, keyUp:, ppGSPatch_KeyUp:);

#if PP_OPTIONAL__BUILD_WITH_SCREENCASTING

    macroSwizzleInstanceMethod(PPScreencastController, handleKeyDown:, ppGSPatch_HandleKeyDown:);

    macroSwizzleInstanceMethod(PPScreencastController, handleKeyUp:, ppGSPatch_HandleKeyUp:);

#endif  // PP_OPTIONAL__BUILD_WITH_SCREENCASTING
}

+ (void) load
{
    macroPerformNSObjectSelectorAfterAppLoads(ppGSGlue_KeyUpEvents_InstallPatches);
}

@end

@implementation PPDocumentWindowController (PPGNUstepGlue_KeyUpEvents)

- (void) ppGSPatch_KeyDown: (NSEvent *) theEvent
{
    [self ppGSPatch_KeyDown: theEvent];

    if (gKeyUpCheckTimerIsRunning)
    {
        NSString *eventChars = [theEvent charactersIgnoringModifiers];

        if (gKeyUpEvent_PopupHotkey
            && _pressedHotkeyForActivePopupPanel
            && [eventChars rangeOfString: _pressedHotkeyForActivePopupPanel].length)
        {
            [gKeyUpDate_PopupHotkey release];
            gKeyUpDate_PopupHotkey =
                    [[NSDate dateWithTimeIntervalSinceNow: kKeyDownTimeoutInterval] retain];
        }

        if (gKeyUpEvent_BlinkLayersHotkey
            && [eventChars rangeOfString: gHotkeys[kPPHotkeyType_BlinkDocumentLayers]].length
            && [_canvasView documentLayersAreHidden])
        {
            [gKeyUpDate_BlinkLayersHotkey release];
            gKeyUpDate_BlinkLayersHotkey =
                    [[NSDate dateWithTimeIntervalSinceNow: kKeyDownTimeoutInterval] retain];
        }
    }
}

- (void) ppGSPatch_KeyUp: (NSEvent *) theEvent
{
    bool runKeyUpCheckTimer = NO;
    NSString *eventChars = [theEvent charactersIgnoringModifiers];

    if (_pressedHotkeyForActivePopupPanel
        && [eventChars rangeOfString: _pressedHotkeyForActivePopupPanel].length)
    {
        [self ppGSGlue_ClearKeyUpGlobals_PopupHotkey];

        gKeyUpEvent_PopupHotkey = [theEvent retain];
        gKeyUpDate_PopupHotkey = [[NSDate date] retain];

        runKeyUpCheckTimer = YES;
    }

    if ([eventChars rangeOfString: gHotkeys[kPPHotkeyType_BlinkDocumentLayers]].length
        && [_canvasView documentLayersAreHidden])
    {
        [self ppGSGlue_ClearKeyUpGlobals_BlinkLayersHotkey];

        gKeyUpEvent_BlinkLayersHotkey = [theEvent retain];
        gKeyUpDate_BlinkLayersHotkey = [[NSDate date] retain];

        runKeyUpCheckTimer = YES;
    }

    if (runKeyUpCheckTimer && !gKeyUpCheckTimerIsRunning)
    {
        [self ppGSGlue_StartKeyUpCheckTimer];
    }
}

- (void) ppGSGlue_StartKeyUpCheckTimer
{
    NSTimer *keyUpCheckTimer;

    if (gKeyUpCheckTimerIsRunning)
        return;

    keyUpCheckTimer = [NSTimer scheduledTimerWithTimeInterval: kKeyUpCheckTimerInterval
                                target: self
                                selector: @selector(ppGSGlue_KeyUpCheckTimerDidFire:)
                                userInfo: nil
                                repeats: YES];

    gKeyUpCheckTimerIsRunning = (keyUpCheckTimer) ? YES : NO;

    [gKeyUpDate_LastCheckTimerFire release];
    gKeyUpDate_LastCheckTimerFire = [[NSDate date] retain];
}

- (void) ppGSGlue_StopKeyUpCheckTimer: (NSTimer *) keyUpCheckTimer
{
    if (!keyUpCheckTimer || !gKeyUpCheckTimerIsRunning)
    {
        return;
    }

    [keyUpCheckTimer invalidate];

    gKeyUpCheckTimerIsRunning = NO;
}

- (void) ppGSGlue_KeyUpCheckTimerDidFire: (NSTimer *) timer
{
    static bool systemIsLagging = NO;
    static int numTimeoutChecksToSkip = 0;
    NSTimeInterval timeIntervalSinceLastFire;

    if (![[self window] isKeyWindow])
    {
        systemIsLagging = NO;
        numTimeoutChecksToSkip = 0;

        [self ppGSGlue_ClearKeyUpGlobals_AllHotkeys];

        [self ppGSGlue_StopKeyUpCheckTimer: timer];

        return;
    }

    timeIntervalSinceLastFire = -[gKeyUpDate_LastCheckTimerFire timeIntervalSinceNow];

    [gKeyUpDate_LastCheckTimerFire release];
    gKeyUpDate_LastCheckTimerFire = [[NSDate date] retain];

    if ((timeIntervalSinceLastFire > kKeyUpCheckSystemLagInterval)
        && !systemIsLagging)
    {
        systemIsLagging = YES;

        numTimeoutChecksToSkip = kNumKeyUpChecksToSkipAfterSystemLag;
    }

    if (numTimeoutChecksToSkip)
    {
        numTimeoutChecksToSkip--;

        return;
    }

    systemIsLagging = NO;

    if (gKeyUpEvent_PopupHotkey
        && (-[gKeyUpDate_PopupHotkey timeIntervalSinceNow] > kKeyUpTimeoutInterval))
    {
        if (_pressedHotkeyForActivePopupPanel)
        {
            [self ppGSPatch_KeyUp: gKeyUpEvent_PopupHotkey];
        }

        [self ppGSGlue_ClearKeyUpGlobals_PopupHotkey];
    }

    if (gKeyUpEvent_BlinkLayersHotkey
        && (-[gKeyUpDate_BlinkLayersHotkey timeIntervalSinceNow] > kKeyUpTimeoutInterval))
    {
        if ([_canvasView documentLayersAreHidden])
        {
            [self ppGSPatch_KeyUp: gKeyUpEvent_BlinkLayersHotkey];
        }

        [self ppGSGlue_ClearKeyUpGlobals_BlinkLayersHotkey];
    }

    if (!gKeyUpEvent_PopupHotkey && !gKeyUpEvent_BlinkLayersHotkey)
    {
        [self ppGSGlue_StopKeyUpCheckTimer: timer];
    }
}

- (void) ppGSGlue_ClearKeyUpGlobals_PopupHotkey
{
    [gKeyUpEvent_PopupHotkey release];
    gKeyUpEvent_PopupHotkey = nil;

    [gKeyUpDate_PopupHotkey release];
    gKeyUpDate_PopupHotkey = nil;
}

- (void) ppGSGlue_ClearKeyUpGlobals_BlinkLayersHotkey
{
    [gKeyUpEvent_BlinkLayersHotkey release];
    gKeyUpEvent_BlinkLayersHotkey = nil;

    [gKeyUpDate_BlinkLayersHotkey release];
    gKeyUpDate_BlinkLayersHotkey = nil;
}

- (void) ppGSGlue_ClearKeyUpGlobals_AllHotkeys
{
    [self ppGSGlue_ClearKeyUpGlobals_PopupHotkey];
    [self ppGSGlue_ClearKeyUpGlobals_BlinkLayersHotkey];
}

@end

#if PP_OPTIONAL__BUILD_WITH_SCREENCASTING

@implementation PPScreencastController (PPGNUstepGlue_KeyUpEvents)

- (bool) ppGSPatch_HandleKeyDown: (NSString *) key
{
    [self ppGSGlue_SetKeyUpDate: [NSDate dateWithTimeIntervalSinceNow: kKeyDownTimeoutInterval]
            forKey: key];

    return [self ppGSPatch_HandleKeyDown: key];
}

- (bool) ppGSPatch_HandleKeyUp: (NSString *) key
{
    [self ppGSGlue_SetKeyUpDate: [NSDate date] forKey: key];

    return NO;
}

- (void) ppGSGlue_SetKeyUpDate: (NSDate *) date forKey: (NSString *) key
{
    int keyUpDateIndex;

    if (![key length])
    {
        return;
    }

    for (keyUpDateIndex=0; keyUpDateIndex<gNumScreencastKeyUpDates; keyUpDateIndex++)
    {
        if ([gScreencastKeyUpDates[keyUpDateIndex].key isEqualToString: key])
        {
            break;
        }
    }

    if (keyUpDateIndex < gNumScreencastKeyUpDates)  // found an existing keyUpDate entry
    {
        if (date)   // new date - update the existing entry
        {
            [gScreencastKeyUpDates[keyUpDateIndex].date release];
            gScreencastKeyUpDates[keyUpDateIndex].date = [date retain];
        }
        else        // nil date - remove the entry
        {
            [gScreencastKeyUpDates[keyUpDateIndex].key release];
            [gScreencastKeyUpDates[keyUpDateIndex].date release];

            if (keyUpDateIndex < (gNumScreencastKeyUpDates - 1))
            {
                memmove(&gScreencastKeyUpDates[keyUpDateIndex],
                        &gScreencastKeyUpDates[keyUpDateIndex+1],
                        (gNumScreencastKeyUpDates - keyUpDateIndex - 1) * sizeof(PPKeyUpDate));
            }

            gNumScreencastKeyUpDates--;
        }
    }
    else    // no current entry matches key
    {
        if ((gNumScreencastKeyUpDates < kScreencastMaxSimultaneousKeysAllowed)
            && date)
        {
            // enough space in the array & non-nil date: add new entry
            gScreencastKeyUpDates[gNumScreencastKeyUpDates].key = [key retain];
            gScreencastKeyUpDates[gNumScreencastKeyUpDates].date = [date retain];

            gNumScreencastKeyUpDates++;
        }
    }

    if ((gNumScreencastKeyUpDates > 0) && !gScreencastKeyUpCheckTimerIsRunning)
    {
        [self ppGSGlue_StartScreencastKeyUpCheckTimer];
    }
}

- (void) ppGSGlue_StartScreencastKeyUpCheckTimer
{
    NSTimer *keyUpCheckTimer;

    if (gScreencastKeyUpCheckTimerIsRunning)
        return;

    keyUpCheckTimer = [NSTimer scheduledTimerWithTimeInterval: kKeyUpCheckTimerInterval
                                target: self
                                selector: @selector(ppGSGlue_ScreencastKeyUpCheckTimerDidFire:)
                                userInfo: nil
                                repeats: YES];

    gScreencastKeyUpCheckTimerIsRunning = (keyUpCheckTimer) ? YES : NO;

    [gScreencastKeyUpDate_LastCheckTimerFire release];
    gScreencastKeyUpDate_LastCheckTimerFire = [[NSDate date] retain];
}

- (void) ppGSGlue_StopScreencastKeyUpCheckTimer: (NSTimer *) keyUpCheckTimer
{
    if (!keyUpCheckTimer || !gScreencastKeyUpCheckTimerIsRunning)
    {
        return;
    }

    [keyUpCheckTimer invalidate];

    gScreencastKeyUpCheckTimerIsRunning = NO;
}

- (void) ppGSGlue_ScreencastKeyUpCheckTimerDidFire: (NSTimer *) timer
{
    static bool systemIsLagging = NO;
    static int numTimeoutChecksToSkip = 0;
    NSTimeInterval timeIntervalSinceLastFire;
    int keyUpDateIndex;
    bool needToUpdateScreencastPopupStateString = NO;

    timeIntervalSinceLastFire = -[gScreencastKeyUpDate_LastCheckTimerFire timeIntervalSinceNow];

    [gScreencastKeyUpDate_LastCheckTimerFire release];
    gScreencastKeyUpDate_LastCheckTimerFire = [[NSDate date] retain];

    if ((timeIntervalSinceLastFire > kKeyUpCheckSystemLagInterval)
        && !systemIsLagging)
    {
        systemIsLagging = YES;

        numTimeoutChecksToSkip = kNumKeyUpChecksToSkipAfterSystemLag;
    }

    if (numTimeoutChecksToSkip)
    {
        numTimeoutChecksToSkip--;

        return;
    }

    systemIsLagging = NO;

    for (keyUpDateIndex=0; keyUpDateIndex<gNumScreencastKeyUpDates; keyUpDateIndex++)
    {
        if (-[gScreencastKeyUpDates[keyUpDateIndex].date timeIntervalSinceNow]
                > kKeyUpTimeoutInterval)
        {
            needToUpdateScreencastPopupStateString =
                [self ppGSPatch_HandleKeyUp: gScreencastKeyUpDates[keyUpDateIndex].key];

            [self ppGSGlue_SetKeyUpDate: nil forKey: gScreencastKeyUpDates[keyUpDateIndex].key];
        }
    }

    if (needToUpdateScreencastPopupStateString)
    {
        [self performSelector: @selector(updateScreencastPopupStateString)];
    }

    if (!gNumScreencastKeyUpDates)
    {
        [self ppGSGlue_StopScreencastKeyUpCheckTimer: timer];
    }
}

@end

#endif  // PP_OPTIONAL__BUILD_WITH_SCREENCASTING

#endif  // GNUSTEP

