/*
    PPGNUstepGlue_SliderDragging.m

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

// Three fixes for dragging sliders on GNUstep:
//   1) Better responsiveness on sliders that control a slow operation (such as the navigator
// popup's zoom slider); The fix works by processing only the last mouseDragged event in the
// event queue (discarding earlier mouseDragged events) so the expensive operation can be
// skipped for out-of-date events that correspond to an old mouse position.
//   2) Make the mouse-tracking behavior the same as on OS X: When the dragging-mouse is moved
// outside the bounds of the slider control, Macs continue sending the control's action message,
// but GNUstep does not; The fix is to patch -[NSView mouse:inRect:] for the three NSView
// subclasses that contain NSSliderCells in PikoPixel (PPParabolicSlider, NSSlider,
// & PPLayersTableView), so they always return YES while tracking. When
// -[NSCell trackMouse:inRect:ofView:untilMouseUp:] calls one of the patched methods to check
// whether the mouse is still inside the rect, it will receive YES no matter where the mouse is,
// so the control's action message will always be sent.
//   3) Workaround for rare crash in GSHorizontalTypesetter while dragging a slider with an
// empty title; Patched init & initWithCoder: methods to return a slider with its title cell
// set to nil (so that when -[NSSliderCell drawInteriorWithFrame:...] calls
// [_titleCell drawInteriorWithFrame:...], it's a no-op), and patched setTitle: so that when
// setting a non-empty title, it first sets up a non-nil title cell.

#ifdef GNUSTEP

#import <Cocoa/Cocoa.h>
#import "NSObject_PPUtilities.h"
#import "PPAppBootUtilities.h"
#import "PPApplication.h"
#import "PPParabolicSlider.h"
#import "PPLayersTableView.h"
#import "NSEvent_PPUtilities.h"


static bool gIsTrackingMouseInSlider = NO;


@implementation NSObject (PPGNUstepGlue_SliderDragging)

+ (void) ppGSGlue_SliderDragging_InstallPatches
{
    macroSwizzleInstanceMethod(NSSliderCell, init, ppGSPatch_Init);

    macroSwizzleInstanceMethod(NSSliderCell, initWithCoder:, ppGSPatch_InitWithCoder:);

    macroSwizzleInstanceMethod(NSSliderCell, setTitle:, ppGSPatch_SetTitle:);

    macroSwizzleInstanceMethod(NSSliderCell, startTrackingAt:inView:,
                                ppGSPatch_StartTrackingAt:inView:);

    macroSwizzleInstanceMethod(NSSliderCell, stopTracking:at:inView:mouseIsUp:,
                                ppGSPatch_StopTracking:at:inView:mouseIsUp:);


    macroSwizzleInstanceMethod(PPApplication, nextEventMatchingMask:untilDate:inMode:dequeue:,
                                ppGSPatch_NextEventMatchingMask:untilDate:inMode:dequeue:);


    //  Patch -[NSView mouse:inRect:] for all NSView subclasses that contain an NSSliderCell in
    // PikoPixel: PPParabolicSlider, NSSlider, PPLayersTableView

    macroSwizzleInstanceMethod(PPParabolicSlider, mouse:inRect:, ppGSPatch_Mouse:inRect:);

    macroSwizzleInstanceMethod(NSSlider, mouse:inRect:, ppGSPatch_Mouse:inRect:);

    macroSwizzleInstanceMethod(PPLayersTableView, mouse:inRect:, ppGSPatch_Mouse:inRect:);
}

+ (void) load
{
    macroPerformNSObjectSelectorAfterAppLoads(ppGSGlue_SliderDragging_InstallPatches);
}

@end

@implementation NSSliderCell (PPGNUstepGlue_SliderDragging)

- (id) ppGSPatch_Init
{
    self = [self ppGSPatch_Init];

    [self setTitleCell: nil];

    return self;
}

- (id) ppGSPatch_InitWithCoder: (NSCoder *) decoder
{
    self = [self ppGSPatch_InitWithCoder: decoder];

    [self setTitleCell: nil];

    return self;
}

- (void) ppGSPatch_SetTitle: (NSString *) title
{
    if (![self titleCell] && [title length])
    {
        NSTextFieldCell *titleCell = [[[NSTextFieldCell alloc] init] autorelease];

        [titleCell setTextColor: [NSColor controlTextColor]];
        [titleCell setAlignment: NSCenterTextAlignment];

        [self setTitleCell: titleCell];
    }

    [self ppGSPatch_SetTitle: title];
}

- (BOOL) ppGSPatch_StartTrackingAt: (NSPoint) startPoint inView: (NSView *) controlView
{
    BOOL didStartTracking = [self ppGSPatch_StartTrackingAt: startPoint inView: controlView];

    if (didStartTracking)
    {
        gIsTrackingMouseInSlider = YES;
    }

    return didStartTracking;
}

- (void) ppGSPatch_StopTracking: (NSPoint) lastPoint
            at: (NSPoint) stopPoint
            inView: (NSView *) controlView
            mouseIsUp: (BOOL) flag
{
    gIsTrackingMouseInSlider = NO;

    [self ppGSPatch_StopTracking: lastPoint
            at: stopPoint
            inView: controlView
            mouseIsUp: flag];
}

@end

@implementation PPApplication (PPGNUstepGlue_SliderDragging)

- (NSEvent *) ppGSPatch_NextEventMatchingMask: (NSUInteger) mask
                untilDate: (NSDate *) expiration
                inMode: (NSString *) mode
                dequeue: (BOOL) flag
{
    static int recursionLevel = 0;
    NSEvent *event = [self ppGSPatch_NextEventMatchingMask: mask
                            untilDate: expiration
                            inMode: mode
                            dequeue: flag];

    if (gIsTrackingMouseInSlider
        && (recursionLevel == 0)
        && ([event type] == NSLeftMouseDragged))
    {
        // -[NSEvent ppLatestMouseDraggedEventFromEventQueue] calls back to this method, so
        // keep track of recursion level to prevent recursing more than once

        recursionLevel++;

        event = [event ppLatestMouseDraggedEventFromEventQueue];

        recursionLevel--;
    }

    return event;
}

@end

@implementation NSView (PPGNUstepGlue_SliderDragging)

- (BOOL) ppGSPatch_Mouse: (NSPoint) aPoint inRect: (NSRect) aRect
{
    if (gIsTrackingMouseInSlider)
    {
        return YES;
    }

    return [self ppGSPatch_Mouse: aPoint inRect: aRect];
}

@end

#endif  // GNUSTEP

