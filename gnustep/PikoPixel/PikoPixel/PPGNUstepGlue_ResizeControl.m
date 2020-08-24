/*
    PPGNUstepGlue_ResizeControl.m

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
#import "PPResizeControl.h"
#import "PPGeometry.h"
#import "NSEvent_PPUtilities.h"


@implementation NSObject (PPGNUstepGlue_ResizeControl)

+ (void) ppGSGlue_ResizeControl_InstallPatches
{
    macroSwizzleInstanceMethod(PPResizeControl, mouseDown:, ppGSPatch_MouseDown:);

    macroSwizzleInstanceMethod(PPResizeControl, mouseDragged:, ppGSPatch_MouseDragged:);
}

+ (void) load
{
    macroPerformNSObjectSelectorAfterAppLoads(ppGSGlue_ResizeControl_InstallPatches);
}

@end

@implementation PPResizeControl (PPGNUstepGlue_ResizeControl)

- (void) ppGSPatch_MouseDown: (NSEvent *) theEvent
{
    [self ppGSPatch_MouseDown: theEvent];

    _mouseDownLocation = [NSEvent mouseLocation];
}

- (void) ppGSPatch_MouseDragged: (NSEvent *) theEvent
{
    NSWindow *window;
    NSRect windowFrame, newWindowFrame;
    NSPoint currentMouseLocation, mouseOffset;

    window = [self window];
    windowFrame = [window frame];

    // merging all mouseDragged events in the queue saves some redrawing (ignore the return val)
    [theEvent ppMouseDragDeltaPointByMergingWithEnqueuedMouseDraggedEvents];

    currentMouseLocation = [NSEvent mouseLocation];

    mouseOffset = PPGeometry_PointDifference(currentMouseLocation, _mouseDownLocation);

    newWindowFrame.size = NSMakeSize(_initialWindowSize.width + mouseOffset.x,
                                        _initialWindowSize.height - mouseOffset.y);

    newWindowFrame.size = [_windowDelegate windowWillResize: window
                                            toSize: newWindowFrame.size];

    if (PPGeometry_IsZeroSize(newWindowFrame.size))
    {
        goto ERROR;
    }

    newWindowFrame.origin = NSMakePoint(_initialWindowTopLeftPoint.x,
                                    _initialWindowTopLeftPoint.y - newWindowFrame.size.height);

    if (!NSEqualRects(windowFrame, newWindowFrame))
    {
        [window setFrame: newWindowFrame display: YES];
    }

    return;

ERROR:
    return;
}

- (BOOL) acceptsFirstMouse: (NSEvent *) theEvent
{
    return YES;
}

@end

#endif  // GNUSTEP

