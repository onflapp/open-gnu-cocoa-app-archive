/*
    PPGNUstepGlue_ScrollerAutohiding.m

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

//   Fix for a scroller-autohiding issue that can cause the app to freeze: If the user resizes
// the PPDocumentWindow to within a pixel or two of the actual width/height of the canvas,
// sometimes this can cause an infinite-recursive loop that will eventually overflow the stack:
// clipview resize -> hidden scroller is auto-shown -> scroller change causes clipview resize ->
// visible scroller is auto-hidden -> scroller change causes clipview resize -> hidden scroller
// is auto-shown -> etc.
//   This issue only appears on GNUstep (no freezes on OS X), but it's probably
// PikoPixel-specific, due to the way PPCanvasView resizes itself in reponse to
// enclosing-clipview notifications, as well as the way PikoPixel's custom GNUstep theme
// resizes clipviews after -[NSScrollView tile] in order to maintain a custom gap between the
// clipview & scrollers (2-pixels instead of 1-pixel).
//   The workaround is to break the cycle of hiding/showing/hiding scrollers by patching
// -[NSScrollView tile] to keep track of its level of recursion, and disallowing the hiding of
// visible scrollers from within recursive calls. (If the clipview is large enough so the
// scrollers do need to be hidden, they will have been hidden from within the initial
// (nonrecursive) call to -[NSScrollView tile], where scroller hiding is allowed).

#ifdef GNUSTEP

#import <Cocoa/Cocoa.h>
#import "NSObject_PPUtilities.h"
#import "PPAppBootUtilities.h"


static bool gDisallowScrollerHiding = NO;


@implementation NSObject (PPGNUstepGlue_ScrollerAutohiding)

+ (void) ppGSGlue_ScrollerAutohiding_InstallPatches
{
    macroSwizzleInstanceMethod(NSScrollView, tile, ppGSPatch_ScrollerAutohiding_Tile);

    macroSwizzleInstanceMethod(NSScrollView, setHasVerticalScroller:,
                                ppGSPatch_SetHasVerticalScroller:);

    macroSwizzleInstanceMethod(NSScrollView, setHasHorizontalScroller:,
                                ppGSPatch_SetHasHorizontalScroller:);
}

+ (void) load
{
    macroPerformNSObjectSelectorAfterAppLoads(ppGSGlue_ScrollerAutohiding_InstallPatches);
}

@end

@implementation NSScrollView (PPGNUstepGlue_ScrollerAutohiding)

- (void) ppGSPatch_ScrollerAutohiding_Tile
{
    static int recursionCount = 0;
    bool oldDisallowScrollerHiding = gDisallowScrollerHiding;

    if (recursionCount > 0)
    {
        gDisallowScrollerHiding = YES;
    }

    recursionCount++;

    [self ppGSPatch_ScrollerAutohiding_Tile];

    recursionCount--;

    gDisallowScrollerHiding = oldDisallowScrollerHiding;
}

- (void) ppGSPatch_SetHasVerticalScroller: (BOOL) flag
{
    if (!flag
        && gDisallowScrollerHiding
        && [self hasVerticalScroller])
    {
        flag = YES;
    }

    [self ppGSPatch_SetHasVerticalScroller: flag];
}

- (void) ppGSPatch_SetHasHorizontalScroller: (BOOL) flag
{
    if (!flag
        && gDisallowScrollerHiding
        && [self hasHorizontalScroller])
    {
        flag = YES;
    }

    [self ppGSPatch_SetHasHorizontalScroller: flag];
}

@end

#endif  // GNUSTEP

