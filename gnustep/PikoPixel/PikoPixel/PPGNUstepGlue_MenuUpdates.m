/*
    PPGNUstepGlue_MenuUpdates.m

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
#import "PPPopupPanelsController.h"
#import "PPCanvasView.h"


bool gHasActivePopupPanel = NO, gIsDraggingTool = NO;


@implementation NSObject (PPGNUstepGlue_MenuUpdates)

+ (void) ppGSGlue_MenuUpdates_InstallPatches
{
    macroSwizzleInstanceMethod(PPPopupPanelsController, setActivePopupPanel:,
                                ppGSPatch_MenuUpdates_SetActivePopupPanel:);


    macroSwizzleInstanceMethod(PPCanvasView, setIsDraggingTool:, ppGSPatch_SetIsDraggingTool:);


    macroSwizzleInstanceMethod(NSMenu, update, ppGSPatch_Update);
}

+ (void) load
{
    macroPerformNSObjectSelectorAfterAppLoads(ppGSGlue_MenuUpdates_InstallPatches);
}

@end

@implementation PPPopupPanelsController (PPGNUstepGlue_MenuUpdates)

- (void) ppGSPatch_MenuUpdates_SetActivePopupPanel: (PPPopupPanelType) popupPanelType
{
    [self ppGSPatch_MenuUpdates_SetActivePopupPanel: popupPanelType];

    gHasActivePopupPanel = [self hasActivePopupPanel];
}

@end

@implementation PPCanvasView (PPGNUstepGlue_MenuUpdates)

- (void) ppGSPatch_SetIsDraggingTool: (bool) isDraggingTool
{
    [self ppGSPatch_SetIsDraggingTool: isDraggingTool];

    gIsDraggingTool = _isDraggingTool;
}

@end

@implementation NSMenu (PPGNUstepGlue_MenuUpdates)

- (void) ppGSPatch_Update
{
    if (gHasActivePopupPanel || gIsDraggingTool)
    {
        return;
    }

    [self ppGSPatch_Update];
}

@end

#endif  // GNUSTEP

