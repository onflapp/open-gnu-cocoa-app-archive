/*
    PPGNUstepGlue_ColorPanel.m

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

// Workarounds/tweaks for several NSColorPanel issues on GNUstep:
// - Automatically hide the color panel when there are no active color wells
// - Fix inability to click on color panel's swatches (when using the color-picker popup-panel),
// due to the NSColorWells being set up with the wrong target (now fixed in the GNUstep trunk
// 2016-11-21)
// - When the color panel becomes key, check if one of its textfields is being edited - if not,
// automatically resign key & return key status to the current document window
// - Workaround for issue where typing in one of the color panel's textfields would cause the
// entire text to be selected after each keypress (causing the next keypress to replace all of
// the current text) - this was due to the color panel text change causing an update to the
// tools panel's color well, causing an update to the document's fill color, which then posted
// a PPDocument notification that its fill color changed, which, when received by the tools
// panel controller, would update the panel's color well's color, which updated the color
// panel's color, interfering with in-progress text editing; Patched PPToolsPanelController to
// prevent it from updating the color well with the document's new color when the new color was
// the result of an update from the color well itself

#ifdef GNUSTEP

#import <Cocoa/Cocoa.h>
#import "NSObject_PPUtilities.h"
#import "PPAppBootUtilities.h"
#import "PPToolsPanelController.h"
#import "PPDocument.h"


static bool gIsActivatingColorWell = NO, gDisallowToolsPanelColorWellUpdates = NO;


@interface NSColorPanel (PPGNUstepGlue_ColorPanelUtilities)

- (void) ppGSGlue_ResignKeyUnlessEditingText;

@end

@interface PPToolsPanelController (PPGNUstepGlue_ColorPanelUtilities)

- (void) ppGSGlue_UpdateDocumentFillColorAndBlockColorWellUpdate;

@end


@implementation NSObject (PPGNUstepGlue_ColorPanel)

+ (void) ppGSGlue_ColorPanel_InstallPatches
{
    macroSwizzleInstanceMethod(NSColorWell, activate:, ppGSPatch_Activate:);

    macroSwizzleInstanceMethod(NSColorWell, deactivate, ppGSPatch_Deactivate);


    macroSwizzleInstanceMethod(NSColorPanel, init, ppGSPatch_Init);

    macroSwizzleInstanceMethod(NSColorPanel, becomeKeyWindow, ppGSPatch_BecomeKeyWindow);


    macroSwizzleInstanceMethod(PPToolsPanelController, fillColorWellUpdated:,
                                                        ppGSPatch_FillColorWellUpdated:);

    macroSwizzleInstanceMethod(PPToolsPanelController, updateFillColorWellColor,
                                                        ppGSPatch_UpdateFillColorWellColor);
}

+ (void) load
{
    macroPerformNSObjectSelectorAfterAppLoads(ppGSGlue_ColorPanel_InstallPatches);
}

@end

@implementation NSColorWell (PPGNUstepGlue_ColorPanel)

- (void) ppGSPatch_Activate: (BOOL) exclusive
{
    gIsActivatingColorWell = YES;

    [self ppGSPatch_Activate: exclusive];

    gIsActivatingColorWell = NO;
}

- (void) ppGSPatch_Deactivate
{
    if (!gIsActivatingColorWell && [self isActive])
    {
        [[NSColorPanel sharedColorPanel] orderOut: self];
    }

    [self ppGSPatch_Deactivate];
}

@end

@implementation NSColorPanel (PPGNUstepGlue_ColorPanel)

- (id) ppGSPatch_Init
{
    Class colorWellClass;
    NSMutableArray *viewsToCheck;
    int viewIndex;
    NSView *view;
    NSColorWell *colorWell;

    self = [self ppGSPatch_Init];

    colorWellClass = [NSColorWell class];

    viewsToCheck = [NSMutableArray arrayWithArray: [[self contentView] subviews]];

    viewIndex = 0;

    while (viewIndex < [viewsToCheck count])
    {
        view = [viewsToCheck objectAtIndex: viewIndex];

        if ([view isKindOfClass: colorWellClass])
        {
            colorWell = (NSColorWell *) view;

            if (sel_isEqual([colorWell action], @selector(_bottomWellAction:))
                && ![[colorWell target] respondsToSelector: @selector(_bottomWellAction:)])
            {
                [colorWell setTarget: self];
            }
        }

        [viewsToCheck addObjectsFromArray: [view subviews]];

        viewIndex++;
    }

    return self;
}

- (void) ppGSPatch_BecomeKeyWindow
{
    [self ppGSPatch_BecomeKeyWindow];

    [self ppPerformSelectorFromNewStackFrame: @selector(ppGSGlue_ResignKeyUnlessEditingText)];
}

- (void) ppGSGlue_ResignKeyUnlessEditingText
{
    if (![self isKeyWindow])
    {
        return;
    }

    if (![[self firstResponder] isKindOfClass: [NSText class]])
    {
        [[NSApp mainWindow] makeKeyWindow];
    }
}

@end

@implementation PPToolsPanelController (PPGNUstepGlue_ColorPanel)

- (IBAction) ppGSPatch_FillColorWellUpdated: (id) sender
{
    [self ppPerformSelectorAtomicallyFromNewStackFrame:
                            @selector(ppGSGlue_UpdateDocumentFillColorAndBlockColorWellUpdate)];
}

- (void) ppGSPatch_UpdateFillColorWellColor
{
    if (gDisallowToolsPanelColorWellUpdates)
        return;

    [_fillColorWell setColor: [_ppDocument fillColor]];
}

- (void) ppGSGlue_UpdateDocumentFillColorAndBlockColorWellUpdate
{
    gDisallowToolsPanelColorWellUpdates = YES;

    [_ppDocument setFillColor: [_fillColorWell color]];

    gDisallowToolsPanelColorWellUpdates = NO;
}

@end

#endif  // GNUSTEP

