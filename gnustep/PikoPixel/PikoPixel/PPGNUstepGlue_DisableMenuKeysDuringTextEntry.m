/*
    PPGNUstepGlue_DisableMenuKeysDuringTextEntry.m

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

// GNUstep workaround to prevent keys which have menu-key-equivalents (such as '0' & <Delete>)
// from being intercepted while typing text in a textfield.

#ifdef GNUSTEP

#import <Cocoa/Cocoa.h>
#import "NSObject_PPUtilities.h"
#import "PPAppBootUtilities.h"
#import "PPKeyCancellableWindow.h"


@implementation NSObject (PPGNUstepGlue_DisableMenuKeysDuringTextEntry)

+ (void) ppGSGlue_DisableMenuKeysDuringTextEntry_InstallPatches
{
    //  Patch -[NSWindow performKeyEquivalent:] for all NSWindow subclasses that use textfields
    // in PikoPixel: NSOpenPanel, NSSavePanel, NSColorPanel, NSPanel, PPKeyCancellableWindow.
    //  This used to be a patch on a single class (NSWindow), but subclass inheritance of
    // patched methods no longer seems to work on the gcc runtime (perhaps it never worked, or
    // perhaps it's an issue with recent versions) apparently due to subclasses not updating
    // their method tables when the patch is installed on a superclass (calling
    // performKeyEquivalent: on an NSWindow works fine, but calling it on an NSPanel jumps
    // directly to the original NSWindow method without calling the patch), so workaround is to
    // manually patch every class where the patched functionality is needed (don't assume it
    // inherits the patch correctly).
    //  Subclasses should be patched before their parent classes, to prevent swapping methods
    // that are already swapped in the inherited method table (if patch inheritance is working
    // correctly).

    macroSwizzleInstanceMethod(NSOpenPanel, performKeyEquivalent:,
                                ppGSPatch_DisableMenuKeysDuringTextEntry_PerformKeyEquivalent:);

    macroSwizzleInstanceMethod(NSSavePanel, performKeyEquivalent:,
                                ppGSPatch_DisableMenuKeysDuringTextEntry_PerformKeyEquivalent:);

    macroSwizzleInstanceMethod(NSColorPanel, performKeyEquivalent:,
                                ppGSPatch_DisableMenuKeysDuringTextEntry_PerformKeyEquivalent:);

    macroSwizzleInstanceMethod(NSPanel, performKeyEquivalent:,
                                ppGSPatch_DisableMenuKeysDuringTextEntry_PerformKeyEquivalent:);

    macroSwizzleInstanceMethod(PPKeyCancellableWindow, performKeyEquivalent:,
                                ppGSPatch_DisableMenuKeysDuringTextEntry_PerformKeyEquivalent:);
}

+ (void) load
{
    macroPerformNSObjectSelectorAfterAppLoads(
                                        ppGSGlue_DisableMenuKeysDuringTextEntry_InstallPatches);
}

@end

@implementation NSWindow (PPGNUstepGlue_DisableMenuKeysDuringTextEntry)

// PATCH: -[NSWindow performKeyEquivalent:]
// Override prevents GNUstep from intercepting keypresses that are (non-modifier-key) menu-item
// equivalents when editing text; For keyDown events, when there's no modifier key pressed,
// if there's an active fieldEditor (window's firstResponder), the event's passed directly to it
// via its keyDown: method

- (BOOL) ppGSPatch_DisableMenuKeysDuringTextEntry_PerformKeyEquivalent: (NSEvent *) theEvent
{
    static NSUInteger disallowedFieldEditorModifierFlags =
                                    NSControlKeyMask | NSAlternateKeyMask | NSCommandKeyMask;

    if (([theEvent type] == NSKeyDown)
        && !([theEvent modifierFlags] & disallowedFieldEditorModifierFlags))
    {
        NSText *fieldEditor = [self fieldEditor: NO forObject: nil];

        if (fieldEditor && (fieldEditor == [self firstResponder]))
        {
            [fieldEditor keyDown: theEvent];

            return YES;
        }
    }

    return [self ppGSPatch_DisableMenuKeysDuringTextEntry_PerformKeyEquivalent: theEvent];
}

@end

#endif  // GNUSTEP

