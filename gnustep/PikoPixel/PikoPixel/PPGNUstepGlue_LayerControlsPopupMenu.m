/*
    PPGNUstepGlue_LayerControlsPopupMenu.m

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

// Workarounds for issues affecting the layers popup menu & button on the Layer Controls popup
// panel in GNUstep:
// - Menu items' images were being drawn on the right side of the menu instead of the left
// - Disabled menu items & disabled popup-button titles looked the same as enabled items/titles
// (not grayed out, despite the title strings' attributes containing a gray foreground-color
// entry)

#ifdef GNUSTEP

#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>
#import "NSObject_PPUtilities.h"
#import "PPAppBootUtilities.h"
#import "PPLayerControlsPopupPanelController.h"
#import "PPUIFontDefines.h"
#import "PPTitleablePopUpButton.h"
#import "PPDocument.h"
#import "PPDocumentLayer.h"


#define kLayersPopupMenuItemSignature           (0x01234560)
#define kLayersPopupMenuItemSignatureMask       (0x0FFFFFF0)

#define kLayersPopupMenuItemDisabledMask        (0x00000001)


#define macroTagValueContainsLayersPopupMenuItemSignature(tagValue)     \
            (((tagValue) & kLayersPopupMenuItemSignatureMask)           \
                == kLayersPopupMenuItemSignature)

#define macroTagValueContainsDisabledFlag(tagValue)                     \
            ((tagValue) & kLayersPopupMenuItemDisabledMask)


//   If an NSMenuItemCell's instance variable, _mcell_belongs_to_popupbutton, is YES, then
// GNUstep displays its image (if it has one) on the right side, regardless of the cell's image
// position setting.
//   In order for items in the layers popup menu to display images on the left, the values of
// their _mcell_belongs_to_popupbutton ivars need to be manually set to NO.
//   Instead of clearing the NSMenuItemCell's ivar directly (which would cause issues if
// future versions of GNUstep remove or rename the ivar), the ivar is cleared using the macro,
// macroClearNSMenuItemCellIvar__mcell_belongs_to_popupbutton(), which accesses the ivar via
// its pointer offset (obtained using the objc runtime api - if unable to find the ivar, its
// offset will be zero - and stored in the global var,
// gIvarOffset_NSMenuItemCell_mcell_belongs_to_popupbutton).

#define macroClearNSMenuItemCellIvar__mcell_belongs_to_popupbutton(menuItemCell)            \
            if (menuItemCell && gIvarOffset_NSMenuItemCell_mcell_belongs_to_popupbutton)    \
            {                                                                               \
                unsigned char *menuItemCellPtr = (unsigned char *) menuItemCell;            \
                BOOL *menuItemCellIvar_mcell_belongs_to_popupbutton =                       \
                    (BOOL *) (&menuItemCellPtr[                                             \
                                gIvarOffset_NSMenuItemCell_mcell_belongs_to_popupbutton]);  \
                                                                                            \
                if (*menuItemCellIvar_mcell_belongs_to_popupbutton == YES)                  \
                {                                                                           \
                    *menuItemCellIvar_mcell_belongs_to_popupbutton = NO;                    \
                }                                                                           \
            }

static int gIvarOffset_NSMenuItemCell_mcell_belongs_to_popupbutton = 0;

static NSPopUpButtonCell *gPopUpButtonCellWithDisabledTitle = nil;


@interface NSMenuItemCell (PPGNUstepGlue_LayerControlsPopupMenuUtilities)

- (NSDictionary *) ppGSGlue_NonAutoreleasedDisabledTextAttributes;

@end

@implementation NSObject (PPGNUstepGlue_LayerControlsPopupMenu)

+ (void) ppGSGlue_LayerControlsPopupMenu_SetupGlobals
{
    Ivar ivar_mcell_belongs_to_popupbutton =
            class_getInstanceVariable([NSMenuItemCell class], "_mcell_belongs_to_popupbutton");

    if (ivar_mcell_belongs_to_popupbutton)
    {
        gIvarOffset_NSMenuItemCell_mcell_belongs_to_popupbutton =
                                    (int) ivar_getOffset(ivar_mcell_belongs_to_popupbutton);
    }
}

+ (void) ppGSGlue_LayerControlsPopupMenu_InstallPatches
{
    macroSwizzleInstanceMethod(PPLayerControlsPopupPanelController,
                                updateDrawingLayerAttributeControls,
                                ppGSPatch_UpdateDrawingLayerAttributeControls);

    macroSwizzleInstanceMethod(PPLayerControlsPopupPanelController,
                                updateDrawingLayerPopUpButtonMenu,
                                ppGSPatch_UpdateDrawingLayerPopUpButtonMenu);


    macroSwizzleInstanceMethod(NSPopUpButtonCell, _nonAutoreleasedTypingAttributes,
                                ppGSPatch_NSPopUpButtonCell__NonAutoreleasedTypingAttributes);


    macroSwizzleInstanceMethod(NSMenuItemCell, setImagePosition:, ppGSPatch_SetImagePosition:);

    macroSwizzleInstanceMethod(NSMenuItemCell, _nonAutoreleasedTypingAttributes,
                                ppGSPatch_NSMenuItemCell__NonAutoreleasedTypingAttributes);
}

+ (void) ppGSGlue_LayerControlsPopupMenu_Install
{
    [self ppGSGlue_LayerControlsPopupMenu_SetupGlobals];

    [self ppGSGlue_LayerControlsPopupMenu_InstallPatches];
}

+ (void) load
{
    macroPerformNSObjectSelectorAfterAppLoads(ppGSGlue_LayerControlsPopupMenu_Install);
}

@end

@implementation PPLayerControlsPopupPanelController (PPGNUstepGlue_LayerControlsPopupMenu)

// PATCH: -[PPLayerControlsPopupPanelController updateDrawingLayerAttributeControls]
//   This patch & the patch for -[NSPopUpButtonCell _nonAutoreleasedTypingAttributes] implement
// the workaround for the layers-popup-button drawing a disabled title the same color as an
// enabled title (not grayed out, ignoring the title string's foreground-color attribute).
//   If the current drawing layer is disabled, this patch stores the layers popup button's cell
// in the global, gPopUpButtonCellWithDisabledTitle, which is checked by the
// -[NSPopUpButtonCell _nonAutoreleasedTypingAttributes] patch when determining whether to
// return normal text attributes or disabled-text attributes.

- (void) ppGSPatch_UpdateDrawingLayerAttributeControls
{
    [self ppGSPatch_UpdateDrawingLayerAttributeControls];

    if (![_drawingLayerEnabledCheckbox intValue])
    {
        gPopUpButtonCellWithDisabledTitle = [_drawingLayerTitleablePopUpButton cell];
    }
    else
    {
        gPopUpButtonCellWithDisabledTitle = nil;
    }
}

// PATCH: -[PPLayerControlsPopupPanelController updateDrawingLayerPopUpButtonMenu]
//   This patch & the patches for -[NSMenuItemCell setImagePosition:] &
// -[NSMenuItemCell _nonAutoreleasedTypingAttributes] implement the workaround for the
// layers-popup-menu's items' images being drawn on the right side of the menu instead of the
// left, and the workaround for disabled layers-popup-button menu-items appearing the same as
// enabled items (not grayed out, ignoring the item-titles' string attribute for
// foreground-color).
//   This patch sets the tag values of the popup button menu's items so they can be identified
// later by the NSMenuItemCell patches as 1) items belonging to the layers popup menu and
// 2) items that are disabled.

- (void) ppGSPatch_UpdateDrawingLayerPopUpButtonMenu
{
    NSArray *menuItemArray;
    int numMenuItems, itemIndex, menuItemTag;
    NSMenuItem *menuItem;

    [self ppGSPatch_UpdateDrawingLayerPopUpButtonMenu];

    menuItemArray = [[_drawingLayerTitleablePopUpButton menu] itemArray];

    numMenuItems = [menuItemArray count];

    for (itemIndex=0; itemIndex<numMenuItems; itemIndex++)
    {
        menuItemTag = kLayersPopupMenuItemSignature;

        if (![[_ppDocument layerAtIndex: numMenuItems - 1 - itemIndex] isEnabled])
        {
            menuItemTag |= kLayersPopupMenuItemDisabledMask;
        }

        menuItem = [menuItemArray objectAtIndex: itemIndex];

        [menuItem setTag: menuItemTag];
    }
}

@end

@implementation NSPopUpButtonCell (PPGNUstepGlue_LayerControlsPopupMenu)

// PATCH: -[NSPopUpButtonCell _nonAutoreleasedTypingAttributes]
//   This patch is part of the workaround for the layers-popup-button drawing a disabled title
// the same color as an enabled title (not grayed out, ignoring the title string's
// foreground-color attribute).
//   If the pop-up-button-cell called is equal to gPopUpButtonCellWithDisabledTitle (set up by
// the -[PPLayerControlsPopupPanelController updateDrawingLayerAttributeControls] patch), then
// disabled-control-text attributes are returned rather than the normal text attributes
// returned by the original implementation.

- (NSDictionary *) ppGSPatch_NSPopUpButtonCell__NonAutoreleasedTypingAttributes
{
    NSDictionary *nonAutoreleasedTextAttributes;

    if (self == gPopUpButtonCellWithDisabledTitle)
    {
        nonAutoreleasedTextAttributes = [self ppGSGlue_NonAutoreleasedDisabledTextAttributes];
    }
    else
    {
        nonAutoreleasedTextAttributes =
                            [self ppGSPatch_NSPopUpButtonCell__NonAutoreleasedTypingAttributes];
    }

    return nonAutoreleasedTextAttributes;
}

@end

@implementation NSMenuItemCell (PPGNUstepGlue_LayerControlsPopupMenu)

// PATCH: -[NSMenuItemCell setImagePosition:]
//   This patch is part of the workaround for the layers-popup-menu's items' images being drawn
// on the right side of the menu instead of the left.
//   If called on a menu item cell with a tag value that identifies it as a layers popup menu
// item (set up by the -[PPLayerControlsPopupPanelController updateDrawingLayerPopUpButtonMenu]
// patch), then the image position is forced to left, and the _mcell_belongs_to_popupbutton
// member is cleared (if its value were to remain YES, the image position would be ignored and
// the image would automatically be drawn on the right).

- (void) ppGSPatch_SetImagePosition: (NSCellImagePosition) imagePosition
{
    if ((imagePosition == NSImageRight)
        && macroTagValueContainsLayersPopupMenuItemSignature([[self menuItem] tag]))
    {
        imagePosition = NSImageLeft;

        macroClearNSMenuItemCellIvar__mcell_belongs_to_popupbutton(self);
    }

    [self ppGSPatch_SetImagePosition: imagePosition];
}

// PATCH: -[NSMenuItemCell _nonAutoreleasedTypingAttributes]
//   This patch is part of the workaround for disabled layers-popup-button menu-items appearing
// the same as enabled items (not grayed out, ignoring the item-titles' string attribute for
// foreground-color).
//   If called on a menu item cell with a tag value that identifies it as a disabled
// layers-popup-menu item (set up by the
// -[PPLayerControlsPopupPanelController updateDrawingLayerPopUpButtonMenu] patch), then
// disabled-control-text attributes are returned rather than the normal text attributes
// returned by the original implementation.

- (NSDictionary *) ppGSPatch_NSMenuItemCell__NonAutoreleasedTypingAttributes
{
    int menuItemTag;
    NSDictionary *nonAutoreleasedTextAttributes;

    menuItemTag = [[self menuItem] tag];

    if (macroTagValueContainsLayersPopupMenuItemSignature(menuItemTag)
        && macroTagValueContainsDisabledFlag(menuItemTag))
    {
        nonAutoreleasedTextAttributes = [self ppGSGlue_NonAutoreleasedDisabledTextAttributes];
    }
    else
    {
        nonAutoreleasedTextAttributes =
                            [self ppGSPatch_NSMenuItemCell__NonAutoreleasedTypingAttributes];
    }

    return nonAutoreleasedTextAttributes;
}

@end

@implementation NSMenuItemCell (PPGNUstepGlue_LayerControlsPopupMenuUtilities)

- (NSDictionary *) ppGSGlue_NonAutoreleasedDisabledTextAttributes
{
    return [[NSDictionary alloc] initWithObjectsAndKeys:

                                        [self font],
                                    NSFontAttributeName,

                                        [NSColor disabledControlTextColor],
                                    NSForegroundColorAttributeName,

                                    nil];
}

@end

#endif  // GNUSTEP

