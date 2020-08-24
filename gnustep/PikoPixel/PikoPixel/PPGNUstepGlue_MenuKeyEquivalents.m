/*
    PPGNUstepGlue_MenuKeyEquivalents.m

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


#define kModifierNamesArraySize     16

#define macroModifierNamesIndexForModifierMask(mask)        ((mask >> 17) & 0x0F)
#define macroModifierMaskForModifierNamesIndex(index)       (index << 17)


static NSString *gModifierNamesArray[kModifierNamesArraySize];


static void DequeueKeyAutorepeatEventsForKeyChars(NSString *keyChars);

static void SetupModifierNamesArray(void);

static NSDictionary *KeyToDisplayKeyDict(void);


@implementation NSObject (PPGNUstepGlue_MenuKeyEquivalents)

+ (void) ppGSGlue_MenuKeyEquivalents_InstallPatches
{
    macroSwizzleInstanceMethod(NSMenu, performKeyEquivalent:, ppGSPatch_PerformKeyEquivalent:);

    macroSwizzleInstanceMethod(NSMenuItemCell, _keyEquivalentString,
                                ppGSPatch_KeyEquivalentString);
}

+ (void) ppGSGlue_MenuKeyEquivalents_Install
{
    SetupModifierNamesArray();

    [self ppGSGlue_MenuKeyEquivalents_InstallPatches];
}

+ (void) load
{
    macroPerformNSObjectSelectorAfterAppLoads(ppGSGlue_MenuKeyEquivalents_Install);
}

@end

@implementation NSMenu (PPGNUstepGlue_MenuKeyEquivalents)

- (BOOL) ppGSPatch_PerformKeyEquivalent: (NSEvent *) theEvent
{
    static bool isRootCall = YES;
    BOOL didPerformKeyEquivalent;

    if (isRootCall)
    {
        NSString *eventChars = [theEvent charactersIgnoringModifiers];

        // Delete key won't trigger the "Delete" menu item because the item's key equivalent is
        // the backspace, so substitute the delete key event with a backspace key event

        if ([eventChars length]
            && ([eventChars characterAtIndex: 0] == NSDeleteCharacter))
        {
            NSEvent *backspaceKeyEvent = [NSEvent keyEventWithType: [theEvent type]
                                                    location: [theEvent locationInWindow]
                                                    modifierFlags: [theEvent modifierFlags]
                                                    timestamp: [theEvent timestamp]
                                                    windowNumber: [theEvent windowNumber]
                                                    context: [theEvent context]
                                                    characters: @"\b"
                                                    charactersIgnoringModifiers: @"\b"
                                                    isARepeat: [theEvent isARepeat]
                                                    keyCode: [theEvent keyCode]];

            if (backspaceKeyEvent)
            {
                theEvent = backspaceKeyEvent;
            }
        }

        isRootCall = NO;
        didPerformKeyEquivalent = [self ppGSPatch_PerformKeyEquivalent: theEvent];
        isRootCall = YES;

        if (didPerformKeyEquivalent)
        {
            // after performing a menu item's action by pressing its key-equivalent, clear the
            // event queue of key-autorepeat events - this is so that when holding down a menu
            // item's key-equivalent, the automatic repetition of the item's action stops
            // quickly when the key is released - otherwise, a backlog of key-autorepeat events
            // can accumulate in the event queue (especially when the item's action is a slow
            // operation) and the app will temporarily become unresponsive after the key is
            // released, as the actions triggered by the remaining enqueued key events are
            // performed

            DequeueKeyAutorepeatEventsForKeyChars(eventChars);
        }
    }
    else
    {
        didPerformKeyEquivalent = [self ppGSPatch_PerformKeyEquivalent: theEvent];
    }

    return didPerformKeyEquivalent;
}

@end

@implementation NSMenuItemCell (PPGNUstepGlue_MenuKeyEquivalents)

- (NSString *) ppGSPatch_KeyEquivalentString
{
    static NSDictionary *keyToDisplayKeyDict = nil;
    static NSCharacterSet *uppercaseLetterCharacterSet = nil;
    NSMenuItem *menuItem;
    NSString *key, *displayKey;
    NSUInteger modifierKeyMask;

    menuItem = [self menuItem];

    key = [menuItem keyEquivalent];

    if (!key || ![key length])
    {
        return nil;
    }

    modifierKeyMask = [menuItem keyEquivalentModifierMask];

    if (!keyToDisplayKeyDict)
    {
        keyToDisplayKeyDict = [KeyToDisplayKeyDict() retain];
    }

    if (!uppercaseLetterCharacterSet)
    {
        uppercaseLetterCharacterSet = [[NSCharacterSet uppercaseLetterCharacterSet] retain];
    }

    displayKey = [keyToDisplayKeyDict objectForKey: key];

    if (displayKey)
    {
        key = displayKey;
    }
    else if ([key rangeOfCharacterFromSet: uppercaseLetterCharacterSet].length)
    {
        modifierKeyMask |= NSShiftKeyMask;
    }

    return [gModifierNamesArray[macroModifierNamesIndexForModifierMask(modifierKeyMask)]
                stringByAppendingString: key];
}

@end

// DequeueKeyAutorepeatEventsForKeyChars():
//   GNUstep currently doesn't set the repeat flag for key events (-[NSEvent isARepeat] always
// returns NO), so need to manually determine whether key events are autorepeats (key is
// held down) so that autorepeat events can be removed and normal key events (key is pressed &
// released) are left alone:
// - Group consecutive keyDown events (no keyUp events between them) into a single event
// - Ignore keyUp events that are immediately followed by a keyDown event with an identical
// timestamp (GNUstep can sometimes post keyUp events while a key is autorepeating, but in that
// case, it will also post a second event (keyDown) with no elapsed time since the keyUp)

#define kMinTimeBetweenNonAutorepeatKeyUpAndKeyDownEvents   0.005

static void DequeueKeyAutorepeatEventsForKeyChars(NSString *keyChars)
{
    static NSMutableArray *dequeuedEvents = nil;
    NSUInteger keyEventsMask = NSKeyDownMask | NSKeyUpMask | NSFlagsChanged;
    NSEvent *dequeuedEvent, *lastDequeuedEvent;
    int dequeuedEventIndex;

    if (![keyChars length])
    {
        return;
    }

    if (!dequeuedEvents)
    {
        dequeuedEvents = [[NSMutableArray array] retain];

        if (!dequeuedEvents)
            return;
    }

    [dequeuedEvents removeAllObjects];

    dequeuedEvent = [NSApp nextEventMatchingMask: keyEventsMask
                            untilDate: nil
                            inMode: NSEventTrackingRunLoopMode
                            dequeue: YES];

    while (dequeuedEvent)
    {
        if (![[dequeuedEvent charactersIgnoringModifiers] isEqualToString: keyChars]
            || ([dequeuedEvent type] == NSFlagsChanged))
        {
            [NSApp postEvent: dequeuedEvent atStart: YES];

            dequeuedEvent = nil;
        }
        else
        {
            [dequeuedEvents addObject: dequeuedEvent];

            dequeuedEvent = [NSApp nextEventMatchingMask: keyEventsMask
                                    untilDate: nil
                                    inMode: NSEventTrackingRunLoopMode
                                    dequeue: YES];
        }
    }

    dequeuedEventIndex = [dequeuedEvents count] - 1;

    if (dequeuedEventIndex >= 0)
    {
        NSEventType lastRequeuedEventType, dequeuedEventType;

        dequeuedEvent = [dequeuedEvents objectAtIndex: dequeuedEventIndex];

        [NSApp postEvent: dequeuedEvent atStart: YES];

        lastRequeuedEventType = [dequeuedEvent type];

        lastDequeuedEvent = dequeuedEvent;
        dequeuedEventIndex--;

        while (dequeuedEventIndex >= 0)
        {
            dequeuedEvent = [dequeuedEvents objectAtIndex: dequeuedEventIndex];

            dequeuedEventType = [dequeuedEvent type];

            if ((lastRequeuedEventType != NSKeyDown)
                || ((dequeuedEventType == NSKeyUp)
                    && (([lastDequeuedEvent timestamp] - [dequeuedEvent timestamp])
                            > kMinTimeBetweenNonAutorepeatKeyUpAndKeyDownEvents)))
            {
                [NSApp postEvent: dequeuedEvent atStart: YES];

                lastRequeuedEventType = dequeuedEventType;
            }

            lastDequeuedEvent = dequeuedEvent;
            dequeuedEventIndex--;
        }
    }
}

static void SetupModifierNamesArray(void)
{
    NSUInteger i, modifierKeyMask;

    for (i=0; i<kModifierNamesArraySize; i++)
    {
        modifierKeyMask = macroModifierMaskForModifierNamesIndex(i);

        gModifierNamesArray[i] =
            [[NSString stringWithFormat: @"  %@%@%@%@",
                                        (modifierKeyMask & NSControlKeyMask) ? @"Ctrl+" : @"",
                                        (modifierKeyMask & NSAlternateKeyMask) ? @"Alt+" : @"",
                                        (modifierKeyMask & NSCommandKeyMask) ? @"Super+" : @"",
                                        (modifierKeyMask & NSShiftKeyMask) ? @"Shift+" : @""]
                    retain];
    }
}

static NSDictionary *KeyToDisplayKeyDict(void)
{
    NSMutableDictionary *keyToDisplayKeyDict;
    unichar lowercaseChar, uppercaseChar;

    keyToDisplayKeyDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:

                                                    // Tab
                                                        @"\u21E5",
                                                    @"\t",

                                                    // Return
                                                        @"\u21A9",
                                                    @"\r",

                                                    // ESC
                                                        @"\u238B",
                                                    @"\e",

                                                    // Space
                                                        @"\u23B5",
                                                    @" ",

                                                    // Backspace
                                                        @"\u232B",
                                                    @"\b",

                                                    // Left arrow
                                                        @"\u2190",
                                                    @"\uF702",

                                                    // Up arrow
                                                        @"\u2191",
                                                    @"\uF700",

                                                    // Right arrow
                                                        @"\u2192",
                                                    @"\uF703",

                                                    // Down arrow
                                                        @"\u2193",
                                                    @"\uF701",

                                                        nil];

    // Lowercase to uppercase alphabet chars

    for (lowercaseChar = 'a'; lowercaseChar <= 'z'; lowercaseChar++)
    {
        uppercaseChar = 'A' + lowercaseChar - 'a';

        [keyToDisplayKeyDict
                    setObject: [NSString stringWithCharacters: &uppercaseChar length: 1]
                    forKey: [NSString stringWithCharacters: &lowercaseChar length: 1]];
    }

    return [NSDictionary dictionaryWithDictionary: keyToDisplayKeyDict];
}

#endif  // GNUSTEP

