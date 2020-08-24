/*
    PPGNUstepGlue_ColorPickerPopupPanel.m

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
#import "PPGNUstepGlueUtilities.h"
#import "PPColorPickerPopupPanelController.h"
#import "PPColorPickerPopupPanel.h"
#import "PPToolsPanelController.h"
#import "PPGeometry.h"
#import "PPUserDefaults.h"


#define kWindowManagersIncompatibleWithNSWindowAboveOrderingForColorPanel   \
            (kPPGSWindowManagerTypeMask_Compiz)


static bool gColorPanelIsAttachedToPopupPanel = NO,
            gAllowNSWindowAboveOrderingForColorPanel = YES;
static NSRect gColorPanelFrameAtNextReveal = {{0,0},{0,0}};
static NSSize gColorPanelDefaultMaxSize, gColorPanelDefaultMinSize;

static void SetupColorPanelSizeGlobals(void);


@interface PPColorPickerPopupPanelController (PPGNUstepGlue_ColorPickerPopupPanelUtilities)

- (void) ppGSGlue_HandleNSColorPanelNotification_DidMove: (NSNotification *) notification;

@end

@interface NSWindow (PPGNUstepGlue_ColorPickerPopupPanelUtilities)

- (void) ppGSGlue_OrderBehindColorPanel;

@end


@implementation NSObject (PPGNUstepGlue_ColorPickerPopupPanel)

+ (void) ppGSGlue_ColorPickerPopupPanel_InstallPatches
{
    macroSwizzleInstanceMethod(PPColorPickerPopupPanelController, windowDidLoad,
                                ppGSPatch_WindowDidLoad);

    macroSwizzleInstanceMethod(PPColorPickerPopupPanelController, setPanelEnabled:,
                                ppGSPatch_SetPanelEnabled:);

    macroSwizzleInstanceMethod(PPColorPickerPopupPanelController,
                                colorPickerPopupPanelDidFinishHandlingMouseDownEvent:,
                                ppGSPatch_ColorPickerPopupPanelDidFinishHandlingMouseDownEvent:);


    macroSwizzleInstanceMethod(NSColorPanel, canBecomeKeyWindow, ppGSPatch_CanBecomeKeyWindow);

    macroSwizzleInstanceMethod(NSColorPanel, orderFront:, ppGSPatch_OrderFront:);


    macroSwizzleInstanceMethod(PPColorPickerPopupPanel, sendEvent:, ppGSPatch_SendEvent:);
}

+ (void) ppGSGlue_ColorPickerPopupPanel_Install
{
    if (PPGSGlueUtils_WindowManagerMatchesTypeMask(
                            kWindowManagersIncompatibleWithNSWindowAboveOrderingForColorPanel))
    {
        gAllowNSWindowAboveOrderingForColorPanel = NO;
    }

    [self ppGSGlue_ColorPickerPopupPanel_InstallPatches];
}

+ (void) load
{
    macroPerformNSObjectSelectorAfterAppLoads(ppGSGlue_ColorPickerPopupPanel_Install);
}

@end

@implementation PPColorPickerPopupPanelController (PPGNUstepGlue_ColorPickerPopupPanel)

- (void) ppGSPatch_WindowDidLoad
{
    [self ppGSPatch_WindowDidLoad];

    [[NSNotificationCenter defaultCenter]
                            addObserver: self
                            selector:
                                @selector(ppGSGlue_HandleNSColorPanelNotification_DidMove:)
                            name: NSWindowDidMoveNotification
                            object: [NSColorPanel sharedColorPanel]];

    SetupColorPanelSizeGlobals();
}

- (void) ppGSPatch_SetPanelEnabled: (bool) enablePanel
{
    static NSWindow *colorPanelInitialParentWindow = nil;
    bool popupPanelIsVisible = [self panelIsVisible];

    if (enablePanel && !popupPanelIsVisible)
    {
        NSWindow *popupPanel;
        NSColorPanel *colorPanel;
        NSSize colorPanelFrameSize;
        NSPoint colorPanelCenteredOrigin;

        // make sure panel is loaded before accessing IBOutlets
        popupPanel = [self window];

        colorPanel = [NSColorPanel sharedColorPanel];

        if (!NSIsEmptyRect(gColorPanelFrameAtNextReveal))
        {
            _oldColorPanelFrame = gColorPanelFrameAtNextReveal;
            gColorPanelFrameAtNextReveal = NSZeroRect;
        }
        else
        {
            _oldColorPanelFrame = [colorPanel frame];
        }

        _oldColorPanelMode = [colorPanel mode];
        [colorPanel setMode: _colorPanelMode];

        colorPanelFrameSize = _oldColorPanelFrame.size;

        if (!NSEqualSizes(_colorPanelFrameSize, colorPanelFrameSize))
        {
            _colorPanelFrameSize = colorPanelFrameSize;

            [self performSelector: @selector(updatePopupPanelSizeForColorPanelFrameSize)];
        }

        // disable color panel resizing
        [colorPanel setMaxSize: colorPanelFrameSize];
        [colorPanel setMinSize: colorPanelFrameSize];

        [self performSelector: @selector(updateColorWellColor)];
        [self performSelector: @selector(updateSamplerImageButtonsVisibility)];

        [super setPanelEnabled: YES];

        // If PPGNUstepGlue_WindowOrdering is installed, the color panel already has a parent
        // window, so preserve the parent window & detach from it before making the popup panel
        // the color panel's parent (initial parent is restored when the popup hides)

        colorPanelInitialParentWindow = [colorPanel parentWindow];

        if (colorPanelInitialParentWindow)
        {
            [colorPanelInitialParentWindow retain];
            [colorPanelInitialParentWindow removeChildWindow: colorPanel];
        }

        [popupPanel addChildWindow: colorPanel ordered: NSWindowAbove];
        gColorPanelIsAttachedToPopupPanel = YES;

        colorPanelCenteredOrigin =
            PPGeometry_CenterRectInRect(_oldColorPanelFrame, [popupPanel frame]).origin;

        [colorPanel setFrameOrigin: colorPanelCenteredOrigin];

        _needToReactivateToolPanelColorWell =
                            [[PPToolsPanelController sharedController] fillColorWellIsActive];

        if (![colorPanel isVisible])
        {
            [_colorWell activate: YES];
        }

        [popupPanel ppGSGlue_OrderBehindColorPanel];

        [self performSelector: @selector(addAsObserverForNSColorPanelNotifications)];
    }
    else if (!enablePanel && popupPanelIsVisible)
    {
        NSColorPanel *colorPanel;
        int initialColorPanelMode;

        colorPanel = [NSColorPanel sharedColorPanel];

        [self performSelector: @selector(removeAsObserverForNSColorPanelNotifications)];

        [colorPanel endEditingFor: nil];

        initialColorPanelMode = _colorPanelMode;
        _colorPanelMode = [colorPanel mode];

        if (_colorPanelMode != initialColorPanelMode)
        {
            [PPUserDefaults setColorPickerPopupPanelMode: _colorPanelMode];
        }

        [[self window] removeChildWindow: colorPanel];
        gColorPanelIsAttachedToPopupPanel = NO;

        // restore color panel's initial parent window if it had one
        if (colorPanelInitialParentWindow)
        {
            [colorPanelInitialParentWindow addChildWindow: colorPanel ordered: NSWindowAbove];
            [colorPanelInitialParentWindow autorelease];
            colorPanelInitialParentWindow = nil;
        }

        [super setPanelEnabled: NO];

        [colorPanel setMode: _oldColorPanelMode];

        // reenable color panel resizing
        [colorPanel setMaxSize: gColorPanelDefaultMaxSize];
        [colorPanel setMinSize: gColorPanelDefaultMinSize];

        if (_needToReactivateToolPanelColorWell)
        {
            [colorPanel setFrameOrigin: _oldColorPanelFrame.origin];

           [[PPToolsPanelController sharedController] activateFillColorWell];
        }
        else if ([[PPToolsPanelController sharedController] fillColorWellIsActive])
        {
            [colorPanel setFrameOrigin: _oldColorPanelFrame.origin];

            [NSApp orderFrontColorPanel: self];
        }
        else
        {
            if ([_colorWell isActive])
            {
                [_colorWell deactivate];
            }

            // let the color panel fade out before repositioning it to its old location - just
            // save the old frame and set it the next time the panel's ordered front
            gColorPanelFrameAtNextReveal = _oldColorPanelFrame;
        }
    }
    else
    {
        [super setPanelEnabled: enablePanel];
    }
}

- (void) ppGSPatch_ColorPickerPopupPanelDidFinishHandlingMouseDownEvent:
                                                            (PPColorPickerPopupPanel *) panel
{
    // GNUstep version doesn't need to handle mouse clicks, so just ignore
}

@end

@implementation NSColorPanel (PPGNUstepGlue_ColorPickerPopupPanel)

- (BOOL) ppGSPatch_CanBecomeKeyWindow
{
    if (gColorPanelIsAttachedToPopupPanel)
    {
        return NO;
    }

    return [self ppGSPatch_CanBecomeKeyWindow];
}

- (void) ppGSPatch_OrderFront: (id) sender
{
    if (!NSIsEmptyRect(gColorPanelFrameAtNextReveal))
    {
        [self setFrameOrigin: gColorPanelFrameAtNextReveal.origin];

        gColorPanelFrameAtNextReveal = NSZeroRect;
    }

    [self ppGSPatch_OrderFront: sender];
}

@end

@implementation PPColorPickerPopupPanel (PPGNUstepGlue_ColorPickerPopupPanel)

- (void) ppGSPatch_SendEvent: (NSEvent *) theEvent
{
    if (([theEvent type] == NSAppKitDefined)
        && ([theEvent subtype] == GSAppKitRegionExposed))
    {
        [self ppPerformSelectorAtomicallyFromNewStackFrame:
                                                    @selector(ppGSGlue_OrderBehindColorPanel)];
    }

    [self ppGSPatch_SendEvent: theEvent];
}

@end

@implementation PPColorPickerPopupPanelController (PPGNUstepGlue_ColorPickerPopupPanelUtilities)

- (void) ppGSGlue_HandleNSColorPanelNotification_DidMove: (NSNotification *) notification
{
    if (gColorPanelIsAttachedToPopupPanel)
    {
        [[self window] ppPerformSelectorAtomicallyFromNewStackFrame:
                                                    @selector(ppGSGlue_OrderBehindColorPanel)];
    }
}

@end

@implementation NSWindow (PPGNUstepGlue_ColorPickerPopupPanelUtilities)

- (void) ppGSGlue_OrderBehindColorPanel
{
    if (![self isVisible])
    {
        return;
    }

    //  NSWindowAbove-ordering for the color panel works on most window managers, except for
    // Compiz, where it causes the color panel to appear behind the target window if the panel
    // was already visible - workaround is to use NSWindowBelow ordering on the target window;
    //  NSWindowBelow-ordering works on most window managers, except for Openbox, where it
    // messes up the ordering of the document window & moves it behind the next app's frontmost
    // window (failure-mode is worse than with NSWindowAbove, so use NSWindowAbove as default)

    if (gAllowNSWindowAboveOrderingForColorPanel)
    {
        [[NSColorPanel sharedColorPanel] orderWindow: NSWindowAbove
                                            relativeTo: [self windowNumber]];
    }
    else
    {
        [self orderWindow: NSWindowBelow
                relativeTo: [[NSColorPanel sharedColorPanel] windowNumber]];
    }
}

@end

static void SetupColorPanelSizeGlobals(void)
{
    NSColorPanel *colorPanel = [NSColorPanel sharedColorPanel];

    gColorPanelDefaultMaxSize = [colorPanel maxSize];
    gColorPanelDefaultMinSize = [colorPanel minSize];
}

#endif  // GNUSTEP

