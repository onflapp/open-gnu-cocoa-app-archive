/*
    PPGNUstepGlue_PopupPanelFrames.m

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
#import "PPPopupPanelController.h"
#import "PPPopupPanel.h"
#import "PPFilledRoundedRectView.h"


static bool gDisallowPopupPanelFrameChange = NO;


@implementation NSObject (PPGNUstepGlue_PopupPanelFrames)

+ (void) ppGSGlue_PopupPanelFrames_InstallPatches
{
    macroSwizzleInstanceMethod(PPPopupPanelController, loadWindow, ppGSPatch_LoadWindow);


    macroSwizzleInstanceMethod(PPPopupPanel, setFrame:display:, ppGSPatch_SetFrame:display:);


    macroSwizzleInstanceMethod(PPFilledRoundedRectView, setFrame:, ppGSPatch_SetFrame:);
}

+ (void) load
{
    macroPerformNSObjectSelectorAfterAppLoads(ppGSGlue_PopupPanelFrames_InstallPatches);
}

@end

@implementation PPPopupPanelController (PPGNUstepGlue_PopupPanelFrames)

- (void) ppGSPatch_LoadWindow
{
    gDisallowPopupPanelFrameChange = YES;

    [self ppGSPatch_LoadWindow];

    gDisallowPopupPanelFrameChange = NO;
}

@end

@implementation PPPopupPanel (PPGNUstepGlue_PopupPanelFrames)

- (void) ppGSPatch_SetFrame: (NSRect) windowFrame display: (BOOL) displayViews
{
    if (gDisallowPopupPanelFrameChange)
        return;

    [self ppGSPatch_SetFrame: windowFrame display: displayViews];
}

@end

@implementation PPFilledRoundedRectView (PPGNUstepGlue_PopupPanelFrames)

- (void) ppGSPatch_SetFrame: (NSRect) newFrame
{
    [super setFrame: newFrame];

    [self performSelector: @selector(setupFilledRoundedRectImage)];
}

@end

#endif  // GNUSTEP

