/*
    PPGNUstepGlue_SegmentedCellTracking.m

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

// Workaround for GNUstep issue which causes NSSegmentedControls to ignore mouseclicks
// (as of 2018-02-27, the issue has been fixed in the GNUstep trunk)

#ifdef GNUSTEP

#import <Cocoa/Cocoa.h>
#import "NSObject_PPUtilities.h"
#import "PPAppBootUtilities.h"


@implementation NSObject (PPGNUstepGlue_SegmentedCellTracking)

+ (void) ppGSGlue_SegmentedCellTracking_InstallPatches
{
    macroSwizzleInstanceMethod(NSSegmentedCell, startTrackingAt:inView:,
                                ppGSPatch_StartTrackingAt:inView:);

    macroSwizzleInstanceMethod(NSSegmentedCell, continueTracking:at:inView:,
                                ppGSPatch_ContinueTracking:at:inView:);
}

+ (void) load
{
    macroPerformNSObjectSelectorAfterAppLoads(ppGSGlue_SegmentedCellTracking_InstallPatches);
}

@end

@implementation NSSegmentedCell (PPGNUstepGlue_SegmentedCellTracking)

- (BOOL) ppGSPatch_StartTrackingAt: (NSPoint) startPoint inView: (NSView *) controlView
{
    return ([controlView mouse: startPoint inRect: [controlView bounds]]) ? YES : NO;
}

- (BOOL) ppGSPatch_ContinueTracking: (NSPoint) lastPoint
            at: (NSPoint) currentPoint
            inView: (NSView *) controlView
{
    return YES;
}

@end

#endif  // GNUSTEP

