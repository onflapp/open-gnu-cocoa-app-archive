/*
    PPGNUstepGlue_PopupPanelHidingOnWindowMove.m

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
#import "PPPopupPanelsController.h"
#import "PPSamplerImagePopupPanelController.h"


static int gNumBlocksOnPopupPanelHiding = 0;


@interface PPDocumentWindowController (PPGNUstepGlue_PopupPanelHidingOnWindowMoveUtilities)

+ (void) ppGSGlue_PopupPanelHidingOnWindowMove_Block;

+ (void) ppGSGlue_PopupPanelHidingOnWindowMove_Unblock;

+ (void) ppGSGlue_PopupPanelHidingOnWindowMove_UnblockFromNewStackFrame;

@end


@implementation NSObject (PPGNUstepGlue_PopupPanelHidingOnWindowMove)

+ (void) ppGSGlue_PopupPanelHidingOnWindowMove_InstallPatches
{
    macroSwizzleInstanceMethod(PPDocumentWindowController, handleNSWindowNotification_WillMove:,
                                ppGSPatch_HandleNSWindowNotification_WillMove:);


    macroSwizzleInstanceMethod(PPPopupPanelsController, setActivePopupPanel:,
                                ppGSPatch_PopupPanelHidingOnWindowMove_SetActivePopupPanel:);


    macroSwizzleInstanceMethod(PPSamplerImagePopupPanelController, windowWillResize:toSize:,
                                ppGSPatch_WindowWillResize:toSize:);


    macroSwizzleClassMethod(NSColorPanel, dragColor:withEvent:fromView:,
                                ppGSPatch_DragColor:withEvent:fromView:);


    macroSwizzleInstanceMethod(NSPopUpButtonCell, attachPopUpWithFrame:inView:,
                                ppGSPatch_AttachPopUpWithFrame:inView:);
}

+ (void) load
{
    macroPerformNSObjectSelectorAfterAppLoads(
                                        ppGSGlue_PopupPanelHidingOnWindowMove_InstallPatches);
}

@end

@implementation PPDocumentWindowController (PPGNUstepGlue_PopupPanelHidingOnWindowMove)

- (void) ppGSPatch_HandleNSWindowNotification_WillMove: (NSNotification *) notification
{
    if (gNumBlocksOnPopupPanelHiding > 0)
    {
        return;
    }

    [self ppGSPatch_HandleNSWindowNotification_WillMove: notification];
}

@end

@implementation PPPopupPanelsController (PPGNUstepGlue_PopupPanelHidingOnWindowMove)

- (void) ppGSPatch_PopupPanelHidingOnWindowMove_SetActivePopupPanel:
                                                            (PPPopupPanelType) popupPanelType
{
    [PPDocumentWindowController ppGSGlue_PopupPanelHidingOnWindowMove_Block];

    [self ppGSPatch_PopupPanelHidingOnWindowMove_SetActivePopupPanel: popupPanelType];

    [PPDocumentWindowController ppGSGlue_PopupPanelHidingOnWindowMove_UnblockFromNewStackFrame];
}

@end

@implementation PPSamplerImagePopupPanelController (PPGNUstepGlue_PopupPanelHidingOnWindowMove)

- (NSSize) ppGSPatch_WindowWillResize: (NSWindow *) sender toSize: (NSSize) proposedFrameSize
{
    NSSize newWindowSize;

    [PPDocumentWindowController ppGSGlue_PopupPanelHidingOnWindowMove_Block];

    newWindowSize = [self ppGSPatch_WindowWillResize: sender toSize: proposedFrameSize];

    [PPDocumentWindowController ppGSGlue_PopupPanelHidingOnWindowMove_UnblockFromNewStackFrame];

    return newWindowSize;
}

@end

@implementation NSColorPanel (PPGNUstepGlue_PopupPanelHidingOnWindowMove)

+ (BOOL) ppGSPatch_DragColor: (NSColor *) aColor
            withEvent: (NSEvent *) anEvent
            fromView: (NSView *) sourceView
{
    BOOL returnVal;

    [PPDocumentWindowController ppGSGlue_PopupPanelHidingOnWindowMove_Block];

    returnVal = [self ppGSPatch_DragColor: aColor withEvent: anEvent fromView: sourceView];

    [PPDocumentWindowController ppGSGlue_PopupPanelHidingOnWindowMove_Unblock];

    return returnVal;
}

@end

@implementation NSPopUpButtonCell (PPGNUstepGlue_PopupPanelHidingOnWindowMove)

- (void) ppGSPatch_AttachPopUpWithFrame: (NSRect) cellFrame inView: (NSView *) controlView
{
    [PPDocumentWindowController ppGSGlue_PopupPanelHidingOnWindowMove_Block];

    [self ppGSPatch_AttachPopUpWithFrame: cellFrame inView: controlView];

    [PPDocumentWindowController ppGSGlue_PopupPanelHidingOnWindowMove_Unblock];
}

@end

@implementation PPDocumentWindowController (PPGNUstepGlue_PopupPanelHidingOnWindowMoveUtilities)

+ (void) ppGSGlue_PopupPanelHidingOnWindowMove_Block
{
    gNumBlocksOnPopupPanelHiding++;
}

+ (void) ppGSGlue_PopupPanelHidingOnWindowMove_Unblock
{
    gNumBlocksOnPopupPanelHiding--;
}

+ (void) ppGSGlue_PopupPanelHidingOnWindowMove_UnblockFromNewStackFrame
{
    [self ppPerformSelectorFromNewStackFrame:
                                    @selector(ppGSGlue_PopupPanelHidingOnWindowMove_Unblock)];
}

@end

#endif  // GNUSTEP

