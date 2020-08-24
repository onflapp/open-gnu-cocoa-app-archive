/*
    PPGNUstepGlue_ModifierKeys.m

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
#import "PPGNUstepGlueUtilities.h"
#import "PPToolModifierTipsText.h"
#import "PPGNUstepUserDefaults.h"


static NSUInteger RemappedModifierKeyMaskForMenuItemAction(SEL menuItemAction);
static inline NSUInteger RemappedModifierKeyMaskForMask(NSUInteger modifierKeyMask);

static NSArray *RenamedToolModifierTipsTextModifierDictsArrayForArray(NSArray *modifierDicts);

static NSDictionary *MenuItemSelectorNameToRemappedModifierKeysMaskDict(void);

static void RemapMainMenuModifierKeys(void);


@interface NSMenuItem (PPGNUstepGlue_ModifierKeysUtilities)

- (void) ppGSGlue_RemapModifierKeys;

@end

@interface NSUserDefaults (PPGNUstepGlue_ModifierKeysUtilities)

- (void) ppGSGlue_ModifierKeys_SetupDefaults;

@end

@implementation NSObject (PPGNUstepGlue_ModifierKeys)

+ (void) ppGSGlue_ModifierKeys_InstallPatches
{
    macroSwizzleInstanceMethod(NSMenu, awakeFromNib, ppGSPatch_AwakeFromNib);


    macroSwizzleInstanceMethod(NSButtonCell, setKeyEquivalentModifierMask:,
                                ppGSPatch_SetKeyEquivalentModifierMask:);


    macroSwizzleClassMethod(PPToolModifierTipsText,
                            getModifierDescriptions:andModifierKeyNames:
                                forToolWithName:usingModifierDicts:andTitlesDict:,
                            ppGSPatch_GetModifierDescriptions:andModifierKeyNames:
                                forToolWithName:usingModifierDicts:andTitlesDict:);
}

+ (void) ppGSGlue_ModifierKeys_Install
{
    RemapMainMenuModifierKeys();

    [self ppGSGlue_ModifierKeys_InstallPatches];
}

+ (void) load
{
    PPGSGlueUtils_PerformNSUserDefaultsSelectorBeforeGSBackendLoads(
                                            @selector(ppGSGlue_ModifierKeys_SetupDefaults));

    macroPerformNSObjectSelectorAfterAppLoads(ppGSGlue_ModifierKeys_Install);
}

@end

@implementation NSMenu (PPGNUstepGlue_ModifierKeys)

- (void) ppGSPatch_AwakeFromNib
{
    NSEnumerator *itemEnumerator;
    NSMenuItem *menuItem;

    [self ppGSPatch_AwakeFromNib];

    itemEnumerator = [[self itemArray] objectEnumerator];

    while (menuItem = [itemEnumerator nextObject])
    {
        [menuItem ppGSGlue_RemapModifierKeys];
    }
}

@end

@implementation NSButtonCell (PPGNUstepGlue_ModifierKeys)

- (void) ppGSPatch_SetKeyEquivalentModifierMask: (NSUInteger) mask
{
    if (mask)
    {
        // Some buttons have their command-key equivalents in the title - need to manually
        // replace the clover character (Command modifier key) with its remapped control-key (^)

        if (mask & NSCommandKeyMask)
        {
            NSString *title = [self title];

            if ([title length])
            {
                title = [title stringByReplacingOccurrencesOfString: @"\u2318"  // (clover)
                                withString: @"\u2303"]; // (^)

                if ([title length])
                {
                    [self setTitle: title];
                }
            }
        }

        mask = RemappedModifierKeyMaskForMask(mask);
    }

    [self ppGSPatch_SetKeyEquivalentModifierMask: mask];
}

@end

@implementation PPToolModifierTipsText (PPGNUstepGlue_ModifierKeys)

+ (bool) ppGSPatch_GetModifierDescriptions: (NSAttributedString **) returnedDescriptionsText
            andModifierKeyNames: (NSAttributedString **) returnedKeyNamesText
            forToolWithName: (NSString *) toolName
            usingModifierDicts: (NSArray *) modifierDicts
            andTitlesDict: (NSDictionary *) titlesDict
{
    return [self ppGSPatch_GetModifierDescriptions: returnedDescriptionsText
                    andModifierKeyNames: returnedKeyNamesText
                    forToolWithName: toolName
                    usingModifierDicts:
                            RenamedToolModifierTipsTextModifierDictsArrayForArray(modifierDicts)
                    andTitlesDict: titlesDict];
}

@end

@implementation NSMenuItem (PPGNUstepGlue_ModifierKeysUtilities)

- (void) ppGSGlue_RemapModifierKeys
{
    NSUInteger modifierKeyMask, remappedModifierKeyMask;

    modifierKeyMask = [self keyEquivalentModifierMask];

    if (!modifierKeyMask)
        return;

    remappedModifierKeyMask = RemappedModifierKeyMaskForMenuItemAction([self action]);

    if (!remappedModifierKeyMask)
    {
        remappedModifierKeyMask = RemappedModifierKeyMaskForMask(modifierKeyMask);
    }

    if (remappedModifierKeyMask != modifierKeyMask)
    {
        [self setKeyEquivalentModifierMask: remappedModifierKeyMask];
    }
}

@end

@implementation NSUserDefaults (PPGNUstepGlue_ModifierKeysUtilities)

- (void) ppGSGlue_ModifierKeys_SetupDefaults
{
    NSDictionary *defaultsDict = [NSDictionary dictionaryWithObjectsAndKeys:

                                        // Control keys
                                            kGSUserDefaultsValue_ModifierKeyName_LeftCtrl,
                                        kGSUserDefaultsKey_FirstControlKey,

                                            kGSUserDefaultsValue_ModifierKeyName_RightCtrl,
                                        kGSUserDefaultsKey_SecondControlKey,

                                        // Option (Alternate) keys
                                            kGSUserDefaultsValue_ModifierKeyName_LeftAlt,
                                        kGSUserDefaultsKey_FirstAlternateKey,

                                            kGSUserDefaultsValue_ModifierKeyName_RightAlt,
                                        kGSUserDefaultsKey_SecondAlternateKey,

                                         // Command (Super) keys
                                            kGSUserDefaultsValue_ModifierKeyName_LeftSuper,
                                        kGSUserDefaultsKey_FirstCommandKey,

                                            kGSUserDefaultsValue_ModifierKeyName_RightSuper,
                                        kGSUserDefaultsKey_SecondCommandKey,

                                            nil];

    if (defaultsDict)
    {
        [self registerDefaults: defaultsDict];
    }
}

@end

static NSUInteger RemappedModifierKeyMaskForMenuItemAction(SEL menuItemAction)
{
    static NSDictionary *selectorNameToRemappedModifierKeysMaskDict = nil;
    NSString *selectorName;
    NSNumber *remappedModifierKeysNumber;

    if (!selectorNameToRemappedModifierKeysMaskDict)
    {
        selectorNameToRemappedModifierKeysMaskDict =
            [MenuItemSelectorNameToRemappedModifierKeysMaskDict() retain];
    }

    if (!menuItemAction)
        return 0;

    selectorName = NSStringFromSelector(menuItemAction);

    if (!selectorName)
        return 0;

    remappedModifierKeysNumber =
        [selectorNameToRemappedModifierKeysMaskDict objectForKey: selectorName];

    if (!remappedModifierKeysNumber)
        return 0;

    return [remappedModifierKeysNumber unsignedIntegerValue];
}

static inline NSUInteger RemappedModifierKeyMaskForMask(NSUInteger modifierKeyMask)
{
    NSUInteger remappedModifierKeyMask = 0;

    // Command -> Control

    if (modifierKeyMask & NSCommandKeyMask)
    {
        remappedModifierKeyMask |= NSControlKeyMask;
    }

    // Control -> Alternate

    if (modifierKeyMask & NSControlKeyMask)
    {
        remappedModifierKeyMask |= NSAlternateKeyMask;
    }

    // Alternate -> Command

    if (modifierKeyMask & NSAlternateKeyMask)
    {
        remappedModifierKeyMask |= NSCommandKeyMask;
    }

    // Shift -> Shift

    if (modifierKeyMask & NSShiftKeyMask)
    {
        remappedModifierKeyMask |= NSShiftKeyMask;
    }

    return remappedModifierKeyMask;
}


#define kModifiersDictKey_Modifiers_ModifierStringDicts         @"ModifierStringDicts"
#define kModifiersDictKey_ModifierStrings_KeyNames              @"KeyNames"

static NSArray *RenamedToolModifierTipsTextModifierDictsArrayForArray(NSArray *modifierDicts)
{
    NSMutableArray *renamedModifierDicts, *renamedModifierStringDicts;
    NSEnumerator *modifierDictsEnumerator, *modifierStringDictsEnumerator;
    NSArray *modifierStringDicts;
    NSDictionary *modifiersDict, *modifierStringsDict;
    NSMutableDictionary *renamedModifiersDict, *renamedModifierStringsDict;
    NSString *renamedKeyNames;

    if (![modifierDicts count])
    {
        goto ERROR;
    }

    renamedModifierDicts = [NSMutableArray arrayWithCapacity: [modifierDicts count]];

    if (!renamedModifierDicts)
        goto ERROR;

    modifierDictsEnumerator = [modifierDicts objectEnumerator];

    while (modifiersDict = [modifierDictsEnumerator nextObject])
    {
        renamedModifiersDict = [NSMutableDictionary dictionaryWithDictionary: modifiersDict];

        if (!renamedModifiersDict)
            goto ERROR;

        modifierStringDicts =
            [modifiersDict objectForKey: kModifiersDictKey_Modifiers_ModifierStringDicts];

        renamedModifierStringDicts =
                            [NSMutableArray arrayWithCapacity: [modifierStringDicts count]];

        if (!renamedModifierStringDicts)
            goto ERROR;

        modifierStringDictsEnumerator = [modifierStringDicts objectEnumerator];

        while (modifierStringsDict = [modifierStringDictsEnumerator nextObject])
        {
            renamedModifierStringsDict =
                        [NSMutableDictionary dictionaryWithDictionary: modifierStringsDict];

            if (!renamedModifierStringsDict)
                goto ERROR;

            renamedKeyNames =
                [modifierStringsDict objectForKey: kModifiersDictKey_ModifierStrings_KeyNames];

            renamedKeyNames = [renamedKeyNames stringByReplacingOccurrencesOfString: @"Control"
                                                withString: @"Ctrl"];

            renamedKeyNames = [renamedKeyNames stringByReplacingOccurrencesOfString: @"Option"
                                                withString: @"Alt"];

            renamedKeyNames = [renamedKeyNames stringByReplacingOccurrencesOfString: @"Command"
                                                withString: @"Super"];

            [renamedModifierStringsDict setObject: renamedKeyNames
                                        forKey: kModifiersDictKey_ModifierStrings_KeyNames];

            [renamedModifierStringDicts addObject: renamedModifierStringsDict];
        }

        [renamedModifiersDict setObject: renamedModifierStringDicts
                                forKey: kModifiersDictKey_Modifiers_ModifierStringDicts];

        [renamedModifierDicts addObject: renamedModifiersDict];
    }

    return renamedModifierDicts;

ERROR:
    return modifierDicts;
}

static NSDictionary *MenuItemSelectorNameToRemappedModifierKeysMaskDict(void)
{
    return [NSDictionary dictionaryWithObjectsAndKeys:

                        // Erase Selected Pixels: Ctrl+Alt+L -> Alt+L
                                [NSNumber numberWithUnsignedInteger: NSAlternateKeyMask],
                        @"eraseSelectedPixels:",

                        // Delete Layer: Ctrl+Alt+Delete -> Ctrl+Alt+Shift+Delete
                                [NSNumber numberWithUnsignedInteger:
                                     NSControlKeyMask | NSAlternateKeyMask | NSShiftKeyMask],
                        @"deleteActiveLayer:",

                        // Merge with Layer Above: Ctrl+Alt+Up -> Ctrl+Super+Shift+Up
                                [NSNumber numberWithUnsignedInteger:
                                     NSControlKeyMask | NSCommandKeyMask | NSShiftKeyMask],
                        @"mergeWithLayerAbove:",

                        // Merge with Layer Below: Ctrl+Alt+Down -> Ctrl+Super+Shift+Down
                                [NSNumber numberWithUnsignedInteger:
                                     NSControlKeyMask | NSCommandKeyMask | NSShiftKeyMask],
                        @"mergeWithLayerBelow:",

                        // Next Window: Alt+Tab -> Ctrl+Tab
                                [NSNumber numberWithUnsignedInteger: NSControlKeyMask],
                        @"activateNextDocumentWindow:",

                        // Previous Window: Alt+` -> Ctrl+`
                                [NSNumber numberWithUnsignedInteger: NSControlKeyMask],
                        @"activatePreviousDocumentWindow:",

                                nil];
}

static void RemapMainMenuModifierKeys(void)
{
    NSMutableArray *menus;
    NSMenu *mainMenu, *currentMenu;
    int indexOfCurrentMenu;
    NSEnumerator *currentMenuItemEnumerator;
    NSMenuItem *currentMenuItem;

    menus = [NSMutableArray array];

    if (!menus)
        goto ERROR;

    mainMenu = [NSApp mainMenu];

    if (!mainMenu)
        goto ERROR;

    [menus addObject: mainMenu];

    indexOfCurrentMenu = 0;

    while (indexOfCurrentMenu < [menus count])
    {
        currentMenu = [menus objectAtIndex: indexOfCurrentMenu];

        currentMenuItemEnumerator = [[currentMenu itemArray] objectEnumerator];

        while (currentMenuItem = [currentMenuItemEnumerator nextObject])
        {
            [currentMenuItem ppGSGlue_RemapModifierKeys];

            if ([currentMenuItem hasSubmenu])
            {
                [menus addObject: [currentMenuItem submenu]];
            }
        }

        indexOfCurrentMenu++;
    }

    return;

ERROR:
    return;
}

#endif  // GNUSTEP

