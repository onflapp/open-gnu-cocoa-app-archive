/*
    PPGNUstepGlue_DocumentWindow.m

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

// Workarounds for several issues with PPDocumentWindows on GNUstep:
// - PPDocumentWindows can become main without also becoming key (when a PPDocumentWindow
// closes, key status might go to a panel instead of the now-main next PPDocumentWindow)
// - A mouseclick on a background PPDocumentWindow that brings it to the front will also
// register as a tool click on its canvas (ignores acceptsFirstMouse, which defaults to NO)
// - When closing a PPDocumentWindow, its delegate doesn't receive the final
// windowDidResignKey: & windowDidResignMain: messages
// - GNUstep intercepts some events after they reach PPDocumentWindow, before they reach the
// window's PPCanvasView

#ifdef GNUSTEP

#import <Cocoa/Cocoa.h>
#import "NSObject_PPUtilities.h"
#import "PPAppBootUtilities.h"
#import "PPDocumentWindow.h"
#import "PPDocumentWindowController.h"
#import "NSWindow_PPUtilities.h"


#define kTimeIntervalForIgnoringMouseDownEventsAfterBecomingKeyOrMainWindow         (0.3f)


static NSDate *gCutoffDateForIgnoringMouseDownEvents = nil;


static void DequeueNextMouseDownEvent(void);
static void SetupCutoffDateForIgnoringMouseDownEventsAfterBecomingKeyOrMain(void);
static void ClearCutoffDateForIgnoringMouseDownEvents(void);


@implementation NSObject (PPGNUstepGlue_DocumentWindow)

+ (void) ppGSGlue_DocumentWindow_InstallPatches
{
    macroSwizzleInstanceMethod(PPDocumentWindow, becomeMainWindow, ppGSPatch_BecomeMainWindow);

    macroSwizzleInstanceMethod(PPDocumentWindow, becomeKeyWindow, ppGSPatch_BecomeKeyWindow);

    macroSwizzleInstanceMethod(PPDocumentWindow, close, ppGSPatch_Close);

    macroSwizzleInstanceMethod(PPDocumentWindow, mouseDown:, ppGSPatch_MouseDown:);

    macroSwizzleInstanceMethod(PPDocumentWindow, mouseDragged:, ppGSPatch_MouseDragged:);

    macroSwizzleInstanceMethod(PPDocumentWindow, mouseUp:, ppGSPatch_MouseUp:);

    macroSwizzleInstanceMethod(PPDocumentWindow, keyDown:, ppGSPatch_KeyDown:);

    macroSwizzleInstanceMethod(PPDocumentWindow, keyUp:, ppGSPatch_KeyUp:);

    macroSwizzleInstanceMethod(PPDocumentWindow, flagsChanged:, ppGSPatch_FlagsChanged:);
}

+ (void) load
{
    macroPerformNSObjectSelectorAfterAppLoads(ppGSGlue_DocumentWindow_InstallPatches);
}

@end

@implementation PPDocumentWindow (PPGNUstepGlue_DocumentWindow)

// PATCH: -[PPDocumentWindow becomeMainWindow]
// Workarounds for two issues:
// - PPDocumentWindows can become main without also becoming key, so the patch forces the
// window to become key
// - A mouseclick on a background PPDocumentWindow that brings it to the front will also
// register as a tool click on its canvas, so the patch dequeues the next mouseDown event (if
// there is one), and sets up a cutoff date for ignoring subsequent mouseDown events, checked
// within -[PPDocumentWindow ppGSPatch_MouseDown:]
//
// (Need to deal with mouseclicks in becomeMainWindow patch in addition to becomeKeyWindow
// patch below, because becomeMain... is called later than becomeKey..., so cutoff date should
// be set up at latest possible time - also, DequeueNextMouseDownEvent() can't be called from
// within becomeKey...).

- (void) ppGSPatch_BecomeMainWindow
{
    [self ppGSPatch_BecomeMainWindow];

    [self ppMakeKeyWindowIfMain];

    DequeueNextMouseDownEvent();

    // Sometimes the mouseDown event hasn't been enqueued yet, so also ignore subsequent
    // mouseDown events for a short interval
    SetupCutoffDateForIgnoringMouseDownEventsAfterBecomingKeyOrMain();
}

// PATCH: -[PPDocumentWindow becomeKeyWindow]
// - A mouseclick on a non-key PPDocumentWindow that makes it key will also register as a tool
// click on its canvas, so set up a cutoff date for ignoring subsequent mouseDown events,
// checked within -[PPDocumentWindow ppGSPatch_MouseDown:]
//
// (Can't call DequeueNextMouseDownEvent(), as in the becomeMainWindow patch above, because it
// will block mouse clicks on panels - panels briefly become key when clicked, then return key
// to the main PPDocumentWindow before the panel's mouseclick event is processed).

- (void) ppGSPatch_BecomeKeyWindow
{
    [self ppGSPatch_BecomeKeyWindow];

    SetupCutoffDateForIgnoringMouseDownEventsAfterBecomingKeyOrMain();
}

// PATCH: -[PPDocumentWindow close]
// When closing a GNUstep window, its delegate (in this case, the window's controller) is
// cleared before the window sends its final windowDidResignKey: & windowDidResignMain:
// messages, so the patch manually sends those messages to the window controller

- (void) ppGSPatch_Close
{
    PPDocumentWindowController *windowController = [self windowController];

    if ([self isKeyWindow])
    {
        [windowController windowDidResignKey: nil];
    }

    if ([self isMainWindow])
    {
        [windowController windowDidResignMain: nil];
    }

    [self ppGSPatch_Close];
}

// PATCHES: -[PPDocumentWindow mouseDown:]
//          -[PPDocumentWindow mouseDragged:]
//          -[PPDocumentWindow mouseUp:]
//          -[PPDocumentWindow keyDown:]
//          -[PPDocumentWindow keyUp:]
//          -[PPDocumentWindow flagsChanged:]
//
// GNUstep's NSWindow event handling methods can prevent events from reaching the canvas view
// (intercepted by backing window?), so event handler patches manually forward the event to the
// next responder;
// The mouseDown: patch also checks whether mouseDown events should currently be ignored
// (during a short interval after the window becomes main, to prevent a click that brings a
// window to focus from also registering as a tool click on the canvas)

- (void) ppGSPatch_MouseDown: (NSEvent *) theEvent
{
    if (gCutoffDateForIgnoringMouseDownEvents)
    {
        if ([gCutoffDateForIgnoringMouseDownEvents timeIntervalSinceNow] > 0.0f)
        {
            return;
        }
        else
        {
            ClearCutoffDateForIgnoringMouseDownEvents();
        }
    }

    [[self nextResponder] mouseDown: theEvent];
}

- (void) ppGSPatch_MouseDragged: (NSEvent *) theEvent
{
    [[self nextResponder] mouseDragged: theEvent];
}

- (void) ppGSPatch_MouseUp: (NSEvent *) theEvent
{
    [[self nextResponder] mouseUp: theEvent];
}

- (void) ppGSPatch_KeyDown: (NSEvent *) theEvent
{
    [[self nextResponder] keyDown: theEvent];
}

- (void) ppGSPatch_KeyUp: (NSEvent *) theEvent
{
    [[self nextResponder] keyUp: theEvent];
}

- (void) ppGSPatch_FlagsChanged: (NSEvent *) theEvent
{
    [[self nextResponder] flagsChanged: theEvent];
}

@end

static void DequeueNextMouseDownEvent(void)
{
    [NSApp nextEventMatchingMask: NSLeftMouseDownMask
            untilDate: nil
            inMode: NSEventTrackingRunLoopMode
            dequeue: YES];
}

static void SetupCutoffDateForIgnoringMouseDownEventsAfterBecomingKeyOrMain(void)
{
    [gCutoffDateForIgnoringMouseDownEvents release];

    gCutoffDateForIgnoringMouseDownEvents =
        [[NSDate dateWithTimeIntervalSinceNow:
                            kTimeIntervalForIgnoringMouseDownEventsAfterBecomingKeyOrMainWindow]
            retain];
}

static void ClearCutoffDateForIgnoringMouseDownEvents(void)
{
    [gCutoffDateForIgnoringMouseDownEvents release];
    gCutoffDateForIgnoringMouseDownEvents = nil;
}

#endif  // GNUSTEP

