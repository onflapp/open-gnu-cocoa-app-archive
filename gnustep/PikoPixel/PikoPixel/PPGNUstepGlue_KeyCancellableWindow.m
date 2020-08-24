/*
    PPGNUstepGlue_KeyCancellableWindow.m

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

// Workarounds for issues affecting PPKeyCancellableWindows on GNUstep:
// - Windows loaded from nibs don't automatically set up their default button
// - When using Win95 interface style, embedded menubars would appear on PPKeyCancellableWindows

#ifdef GNUSTEP

#import <Cocoa/Cocoa.h>
#import "NSObject_PPUtilities.h"
#import "PPAppBootUtilities.h"
#import "PPKeyCancellableWindow.h"


@implementation NSObject (PPGNUstepGlue_KeyCancellableWindow)

+ (void) ppGSGlue_KeyCancellableWindow_InstallPatches
{
    macroSwizzleInstanceMethod(PPKeyCancellableWindow, awakeFromNib, ppGSPatch_AwakeFromNib);

    macroSwizzleInstanceMethod(PPKeyCancellableWindow, canBecomeMainWindow,
                                ppGSPatch_CanBecomeMainWindow);
}

+ (void) load
{
    macroPerformNSObjectSelectorAfterAppLoads(ppGSGlue_KeyCancellableWindow_InstallPatches);
}

@end

@implementation PPKeyCancellableWindow (PPGNUstepGlue_KeyCancellableWindow)

// PATCH: -[PPKeyCancellableWindow awakeFromNib]
//  On GNUstep, windows loaded from nibs don't set up their default button (if it exists), so
// the 'default' button looks the same as other buttons (no return-key icon).
//  Besides open/save panels (where the default button is set up correctly), default buttons
// only appear in PikoPixel on PPKeyCancellableWindows, so patched this class directly instead
// of NSWindow. (Sometimes there's issues inheriting patches from parent classes on GCC).
//  The patch manually sets up the window's default button by searching the window's top-level
// views for a button with a return-key key-equivalent.

#define kKeyEquivalent_DefaultButton    @"\r"

- (void) ppGSPatch_AwakeFromNib
{
    Class buttonClass;
    NSEnumerator *viewEnumerator;
    NSView *view;
    NSButton *button;
    bool didSetDefaultButton = NO;

    [self ppGSPatch_AwakeFromNib];

    buttonClass = [NSButton class];

    viewEnumerator = [[[self contentView] subviews] objectEnumerator];

    while (!didSetDefaultButton
            && (view = [viewEnumerator nextObject]))
    {
        if ([view isKindOfClass: buttonClass])
        {
            button = (NSButton *) view;

            if ([[button keyEquivalent] isEqualToString: kKeyEquivalent_DefaultButton]
                && ![button keyEquivalentModifierMask])
            {
                [self setDefaultButtonCell: [button cell]];

                didSetDefaultButton = YES;
            }
        }
    }
}

// PATCH: -[PPKeyCancellableWindow canBecomeMainWindow]
//  When using Win95 interface style, embedded menubars would appear on PPKeyCancellableWindows.
//  Patching canBecomeMainWindow to return NO prevents GNUstep from embedding a window menubar.

- (BOOL) ppGSPatch_CanBecomeMainWindow
{
    return NO;
}

@end

#endif  // GNUSTEP

