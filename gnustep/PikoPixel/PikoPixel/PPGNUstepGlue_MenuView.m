/*
    PPGNUstepGlue_MenuView.m

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

// Workarounds for several issues with NSMenuViews on GNUstep:
// - Submenus of document windows' horizontal menubars (Win95InterfaceStyle) appear at the
// wrong location (top left of screen) - appears in GUI 0.25.1, now fixed in the GNUstep trunk
// (2017-06-28)
// - Menus with separator items appear with a black area at the top (menuview's window height
// is too large)
// - Disabled menu items & separators can be highlighted
// - Menu items on menus that are attached to small-sized NSPopUpButtons use the wrong fontsize

#ifdef GNUSTEP

#import <Cocoa/Cocoa.h>
#import "NSObject_PPUtilities.h"
#import "PPAppBootUtilities.h"


static NSMenuView *gMenuViewToAttachSubmenu = nil;
static bool gNSMenuViewPrivateMethodIsSupported_HeightForItem = NO;


static inline void PPGSGlue_SetupMenuViewGlobals(void)
{
    gNSMenuViewPrivateMethodIsSupported_HeightForItem =
            ([NSMenuView instancesRespondToSelector: @selector(heightForItem:)]) ? YES : NO;
}


@interface NSMenuView (PPGNUstep_NSMenuViewPrivate)

// local declaration of private GNUstep GUI method, -[NSMenuView heightForItem:]
- (CGFloat) heightForItem: (NSInteger) idx;

@end

@implementation NSObject (PPGNUstepGlue_MenuView)

+ (void) ppGSGlue_MenuView_InstallPatches
{
    macroSwizzleInstanceMethod(NSMenuView, attachSubmenuForItemAtIndex:,
                                ppGSPatch_AttachSubmenuForItemAtIndex:);

    macroSwizzleInstanceMethod(NSMenuView, locationForSubmenu:, ppGSPatch_LocationForSubmenu:);

    macroSwizzleInstanceMethod(NSMenuView,
                                setWindowFrameForAttachingToRect:onScreen:
                                    preferredEdge:popUpSelectedItem:,
                                ppGSPatch_SetWindowFrameForAttachingToRect:onScreen:
                                    preferredEdge:popUpSelectedItem:);

    macroSwizzleInstanceMethod(NSMenuView, setHighlightedItemIndex:,
                                ppGSPatch_SetHighlightedItemIndex:);


    macroSwizzleInstanceMethod(NSPopUpButtonCell, setMenuView:, ppGSPatch_SetMenuView:);
}

+ (void) ppGSGlue_MenuView_Install
{
    PPGSGlue_SetupMenuViewGlobals();

    [self ppGSGlue_MenuView_InstallPatches];
}

+ (void) load
{
    macroPerformNSObjectSelectorAfterAppLoads(ppGSGlue_MenuView_Install);
}

@end

@implementation NSMenuView (PPGNUstepGlue_MenuView)

// PATCHES: -[NSMenuView attachSubmenuForItemAtIndex:]
//          -[NSMenuView locationForSubmenu:]
//   In GNUstep GUI 0.25.1: When using Win95InterfaceStyle, the submenus of document windows'
// horizontal menubars appear at the top left of the screen instead of under the menubar. (This
// is now fixed in the current trunk).
//   The issue was due to calling -[NSMenuView locationForSubmenu:] on a shared main-menu
// menuview (this works fine in non-Win95 styles, since the menubar is separate & shared by all
// document windows) instead of the menuview that's attached to the top of the document window.
//   The patch for attachSubmenuForItemAtIndex: stores the menuview that's about to attach a
// submenu (at that point, it's the correct menuview for getting the submenu location) to the
// global var, gMenuViewToAttachSubmenu, and the patch for locationForSubmenu: directs its
// callthrough to gMenuViewToAttachSubmenu instead of to self (since self may be the wrong
// (shared) menuview to determine the submenu location).

- (void) ppGSPatch_AttachSubmenuForItemAtIndex: (NSInteger) index
{
    gMenuViewToAttachSubmenu = self;

    [self ppGSPatch_AttachSubmenuForItemAtIndex: index];

    gMenuViewToAttachSubmenu = nil;
}

- (NSPoint) ppGSPatch_LocationForSubmenu: (NSMenu *) aSubmenu
{
    NSMenuView *targetMenuView = self;

    if (gMenuViewToAttachSubmenu)
    {
        targetMenuView = gMenuViewToAttachSubmenu;
    }

    return [targetMenuView ppGSPatch_LocationForSubmenu: aSubmenu];
}

// PATCH: -[NSMenuView setWindowFrameForAttachingToRect:onScreen:preferredEdge:
//                      popUpSelectedItem:]
//   Menus containing separator items appear with a black area at the top. This is because
// GNUstep's implementation of setWindowFrameForAttachingToRect:... doesn't account for the
// difference in height between normal menu items & separator items.
//   The patch loops over the menu's items, summming up separator items' differences with normal
// items' height, then the window frame's height is offet by the total height difference.

- (void) ppGSPatch_SetWindowFrameForAttachingToRect: (NSRect) screenRect
            onScreen: (NSScreen*) screen
            preferredEdge: (NSRectEdge) edge
            popUpSelectedItem: (NSInteger) selectedItemIndex
{
    NSWindow *window;
    NSRect windowFrame;
    int numMenuItems;
    CGFloat correctWindowHeight, separatorItemsHeightOffset = 0;

    [self ppGSPatch_SetWindowFrameForAttachingToRect: screenRect
            onScreen: screen
            preferredEdge: edge
            popUpSelectedItem: selectedItemIndex];

    window = [self window];
    windowFrame = [window frame];

    numMenuItems = [[self menu] numberOfItems];

    if (gNSMenuViewPrivateMethodIsSupported_HeightForItem
        && (selectedItemIndex > 0)
        && (numMenuItems > 1))
    {
        float defaultMenuItemHeight;
        int itemIndex;

        defaultMenuItemHeight = [self heightForItem: 0];    // assume first item isn't separator

        for (itemIndex=1; itemIndex<selectedItemIndex; itemIndex++)
        {
            separatorItemsHeightOffset +=
                                    (defaultMenuItemHeight - [self heightForItem: itemIndex]);
        }

        separatorItemsHeightOffset =
                    [self convertSizeToBase: NSMakeSize(1, separatorItemsHeightOffset)].height;
    }

    correctWindowHeight = [window frameRectForContentRect: [self frame]].size.height;

    if ((separatorItemsHeightOffset != 0)
        || (windowFrame.size.height != correctWindowHeight))
    {
        CGFloat heightDifference = correctWindowHeight - windowFrame.size.height;

        windowFrame.size.height += heightDifference;
        windowFrame.origin.y -= heightDifference + separatorItemsHeightOffset;

        [window setFrame: windowFrame display: NO];
    }
}

// PATCH: -[NSMenuView setHighlightedItemIndex:]
//   Prevents disabled menu items or separators from being highlighted

- (void) ppGSPatch_SetHighlightedItemIndex: (NSInteger) index
{
    if (index != -1)
    {
        NSMenuItemCell *menuItemCell = [self menuItemCellForItemAtIndex: index];

        if (![menuItemCell isEnabled]
            || [[menuItemCell menuItem] isSeparatorItem])
        {
            index = -1;
        }
    }

    [self ppGSPatch_SetHighlightedItemIndex: index];
}

@end

@implementation NSPopUpButtonCell (PPGNUstepGlue_Miscellaneous)

// PATCH: -[NSPopUpButtonCell setMenuView:]
//   On GNUstep, small-sized popup buttons' menu items are drawn with a regular-sized font (too
// big).
//   The patch checks whether the menuview's items match the popup button's font - if not, it
// manually updates each menu-item's font.

- (void) ppGSPatch_SetMenuView: (NSMenuView *) menuView
{
    if (menuView)
    {
        NSFont *buttonFont;
        int numMenuItems, itemIndex;
        NSMenuItemCell *menuItemCell;

        buttonFont = [self font];

        numMenuItems = [[menuView menu] numberOfItems];

        // assume all the menu's items share the same font - only update all the menu items'
        // fonts if the first item's font doesn't match with the popup button's font

        if ((numMenuItems > 0)
            && (menuItemCell = [menuView menuItemCellForItemAtIndex: 0])
            && ([menuItemCell font] != buttonFont))
        {
            [menuItemCell setFont: buttonFont];
            [menuItemCell setNeedsSizing: YES];

            for (itemIndex=1; itemIndex<numMenuItems; itemIndex++)
            {
                menuItemCell = [menuView menuItemCellForItemAtIndex: itemIndex];

                [menuItemCell setFont: buttonFont];
                [menuItemCell setNeedsSizing: YES];
            }
        }
    }

    [self ppGSPatch_SetMenuView: menuView];
}

@end

#endif  // GNUSTEP

