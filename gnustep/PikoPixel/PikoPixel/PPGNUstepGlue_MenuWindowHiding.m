/*
    PPGNUstepGlue_MenuWindowHiding.m

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

//  Workaround for a menu-windows issue in GNUstep when running on Budgie, Compiz, Gala, Muffin,
// Mutter, or Xfwm window managers: Dragging the mouse quickly along a menu with submenus can
// sometimes leave one or more of the submenus' windows stuck visible until the mouse is moved
// back over the submenu's item in the parent menu. If the user released the mouse while there
// were stuck submenu windows, they would remain visible & unresponsive until the user clicked
// again on the parent menu & navigated to the stuck submenu's parent item.
//  Could be that the affected window managers can't handle rapid showing & hiding of multiple
// windows from within an inner loop (menuview mouse tracking)?
//  The current workaround doesn't completely fix the issue - submenu windows can still get
// stuck visible while the mouse is down, but they will now be automatically hidden when the
// user releases the button. This is done by keeping track of the menus that are sent a 'close'
// message during menu-view mouse-tracking, then resending the close messages once tracking
// finishes.

#ifdef GNUSTEP

#import <Cocoa/Cocoa.h>
#import "NSObject_PPUtilities.h"
#import "PPAppBootUtilities.h"
#import "PPGNUstepGlueUtilities.h"


// Install MenuWindowHiding glue only if the window manager is Budgie, Compiz, Gala, Muffin,
// Mutter, or Xfwm
#define kTargetWindowManagerTypesMask_MenuWindowHiding      \
                (kPPGSWindowManagerTypeMask_Budgie          \
                | kPPGSWindowManagerTypeMask_Compiz         \
                | kPPGSWindowManagerTypeMask_Gala           \
                | kPPGSWindowManagerTypeMask_Muffin         \
                | kPPGSWindowManagerTypeMask_Mutter         \
                | kPPGSWindowManagerTypeMask_Xfwm)


static NSMutableSet *gMenusClosedDuringTracking = nil;
static bool gIsTrackingMenu = NO;


static inline void PPGSGlue_SetupMenuWindowHidingGlobals(void)
{
    gMenusClosedDuringTracking = [[NSMutableSet alloc] init];
}


@interface NSMenuView (PPGNUstepGlue_MenuWindowHidingUtilities)

- (void) ppGSGlue_ResendCloseMessagesToMenusClosedDuringTracking;

@end

@implementation NSObject (PPGNUstepGlue_MenuWindowHiding)

+ (void) ppGSGlue_MenuWindowHiding_InstallPatches
{
    macroSwizzleInstanceMethod(NSMenuView, trackWithEvent:, ppGSPatch_TrackWithEvent:);

    macroSwizzleInstanceMethod(NSMenu, close, ppGSPatch_Close);
}

+ (void) ppGSGlue_MenuWindowHiding_Install
{
    if (!PPGSGlueUtils_WindowManagerMatchesTypeMask(
                                                kTargetWindowManagerTypesMask_MenuWindowHiding))
    {
        return;
    }

    PPGSGlue_SetupMenuWindowHidingGlobals();

    [self ppGSGlue_MenuWindowHiding_InstallPatches];
}

+ (void) load
{
    macroPerformNSObjectSelectorAfterAppLoads(ppGSGlue_MenuWindowHiding_Install);
}

@end

@implementation NSMenuView (PPGNUstepGlue_MenuWindowHiding)

- (BOOL) ppGSPatch_TrackWithEvent: (NSEvent *) event
{
    BOOL returnValue;

    gIsTrackingMenu = YES;
    returnValue = [self ppGSPatch_TrackWithEvent: event];
    gIsTrackingMenu = NO;

    [self ppGSGlue_ResendCloseMessagesToMenusClosedDuringTracking];

    return returnValue;
}

- (void) ppGSGlue_ResendCloseMessagesToMenusClosedDuringTracking
{
    [gMenusClosedDuringTracking makeObjectsPerformSelector: @selector(close)];

    [gMenusClosedDuringTracking removeAllObjects];
}

@end

@implementation NSMenu (PPGNUstepGlue_MenuWindowHiding)

- (void) ppGSPatch_Close
{
    if (gIsTrackingMenu)
    {
        [gMenusClosedDuringTracking addObject: self];
    }

    [self ppGSPatch_Close];
}

@end

#endif  // GNUSTEP

