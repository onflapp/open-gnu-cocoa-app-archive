/*
    PPGNUstepGlue_TitleablePopUpButton.m

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
#import "PPTitleablePopUpButton.h"


#define kTitlePrefixString      @"   "


static NSArray *gDefaultRunLoopModes = nil, *gModalPanelRunLoopModes = nil;


@implementation NSObject (PPGNUstepGlue_TitleablePopUpButton)

+ (void) ppGSGlue_TitleablePopUpButton_InstallPatches
{
    macroSwizzleInstanceMethod(PPTitleablePopUpButton, setTitle:, ppGSPatch_SetTitle:);

    macroSwizzleInstanceMethod(PPTitleablePopUpButton, setTitle:withTextAttributes:,
                                ppGSPatch_SetTitle:withTextAttributes:);

    macroSwizzleInstanceMethod(PPTitleablePopUpButton,
                                handleNSPopUpButtonNotification_WillPopUp:,
                                ppGSPatch_HandleNSPopUpButtonNotification_WillPopUp:);

    macroSwizzleInstanceMethod(PPTitleablePopUpButton,
                                handleNSMenuNotification_WillSendAction:,
                                ppGSPatch_HandleNSMenuNotification_WillSendAction:);

    macroSwizzleInstanceMethod(PPTitleablePopUpButton,
                                handleNSMenuNotification_DidEndTracking:,
                                ppGSPatch_HandleNSMenuNotification_DidEndTracking:);
}

+ (void) ppGSGlue_TitleablePopUpButton_Install
{
    gDefaultRunLoopModes = [[NSArray arrayWithObject: NSDefaultRunLoopMode] retain];

    gModalPanelRunLoopModes = [[NSArray arrayWithObject: NSModalPanelRunLoopMode] retain];

    [self ppGSGlue_TitleablePopUpButton_InstallPatches];
}

+ (void) load
{
    macroPerformNSObjectSelectorAfterAppLoads(ppGSGlue_TitleablePopUpButton_Install);
}

@end

@implementation PPTitleablePopUpButton (PPGNUstepGlue_TitleablePopUpButton)

- (void) ppGSPatch_SetTitle: (NSString *) aString
{
    if (aString)
    {
        aString = [kTitlePrefixString stringByAppendingString: aString];
    }

    if (!aString)
    {
        aString = kTitlePrefixString;
    }

    [super removeAllItems];
    [super addItemWithTitle: aString];
}

- (void) ppGSPatch_SetTitle: (NSString *) title
            withTextAttributes: (NSDictionary *) textAttributes
{
    [self setTitle: title];
}

- (void) ppGSPatch_HandleNSPopUpButtonNotification_WillPopUp: (NSNotification *) notification
{
    int numPopupMenuItems, itemIndex;
    NSMenu *realPopupMenu;
    id <NSMenuItem> menuItemForRealPopupMenu;
    NSArray *runLoopModes;

    [self performSelector: @selector(notifyDelegateWillDisplayPopupMenu)];

    [super removeAllItems];

    realPopupMenu = [super menu];

    numPopupMenuItems = [_popupMenu numberOfItems];

    for (itemIndex=0; itemIndex < numPopupMenuItems; itemIndex++)
    {
        menuItemForRealPopupMenu =
            [[[_popupMenu itemAtIndex: itemIndex] performSelector: @selector(copy)] autorelease];

        [realPopupMenu addItem: menuItemForRealPopupMenu];
    }

    [super selectItemAtIndex: _indexOfSelectedPopupMenuItem];

    [self performSelector: @selector(addAsObserverForNSMenuNotifications)];

    runLoopModes =
        ([self window] == [NSApp modalWindow]) ? gModalPanelRunLoopModes : gDefaultRunLoopModes;

    [self performSelector: @selector(handleNSMenuNotification_DidEndTracking:)
            withObject: nil
            afterDelay: 0.0f
            inModes: runLoopModes];
}

- (void) ppGSPatch_HandleNSMenuNotification_WillSendAction: (NSNotification *) notification
{
    NSMenuItem *menuItem = [[notification userInfo] objectForKey: @"MenuItem"];

    _indexOfSelectedPopupMenuItem = [super indexOfItem: menuItem];
}

- (void) ppGSPatch_HandleNSMenuNotification_DidEndTracking: (NSNotification *) notification
{
    [self performSelector: @selector(updateTitle)];

    [self performSelector: @selector(removeAsObserverForNSMenuNotifications)];
}

@end

#endif  // GNUSTEP

