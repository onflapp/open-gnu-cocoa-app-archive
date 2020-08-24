/*
    PPGNUstepGlue_ModalSheets.m

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
#import "PPDocumentSizeSheetController.h"
#import "PPDocumentBackgroundSettingsSheetController.h"
#import "PPDocumentGridSettingsSheetController.h"
#import "PPDocumentEditPatternPresetsSheetController.h"


@interface NSObject (PPGNUstepGlue_ModalSheetsUtilities)

- (void) ppGSGlue_PerformSelectorFromNewStackFrameInModalMode: (SEL) selector;

@end


@implementation NSObject (PPGNUstepGlue_ModalSheets)

+ (void) ppGSGlue_ModalSheets_InstallPatches
{
    macroSwizzleInstanceMethod(PPDocumentSizeSheetController,
                                sizePresetsMenuItemSelected_EditSizePresets:,
                                ppGSPatch_SizePresetsMenuItemSelected_EditSizePresets:);


    macroSwizzleInstanceMethod(PPDocumentBackgroundSettingsSheetController,
                                patternPresetsMenuItemSelected_AddCurrentPatternToPresets:,
                        ppGSPatch_PatternPresetsMenuItemSelected_AddCurrentPatternToPresets:);

    macroSwizzleInstanceMethod(PPDocumentBackgroundSettingsSheetController,
                                patternPresetsMenuItemSelected_EditPresets:,
                                ppGSPatch_PatternPresetsMenuItemSelected_EditPresets:);

    macroSwizzleInstanceMethod(PPDocumentBackgroundSettingsSheetController,
                                patternPresetsMenuItemSelected_ExportPresetsToFile:,
                                ppGSPatch_PatternPresetsMenuItemSelected_ExportPresetsToFile:);

    macroSwizzleInstanceMethod(PPDocumentBackgroundSettingsSheetController,
                                patternPresetsMenuItemSelected_ImportPresetsFromFile:,
                                ppGSPatch_PatternPresetsMenuItemSelected_ImportPresetsFromFile:);


    macroSwizzleInstanceMethod(PPDocumentGridSettingsSheetController,
                                presetsMenuItemSelected_AddCurrentPatternToPresets:,
                                ppGSPatch_PresetsMenuItemSelected_AddCurrentPatternToPresets:);

    macroSwizzleInstanceMethod(PPDocumentGridSettingsSheetController,
                                presetsMenuItemSelected_EditPresets:,
                                ppGSPatch_PresetsMenuItemSelected_EditPresets:);

    macroSwizzleInstanceMethod(PPDocumentGridSettingsSheetController,
                                presetsMenuItemSelected_ExportPresetsToFile:,
                                ppGSPatch_PresetsMenuItemSelected_ExportPresetsToFile:);

    macroSwizzleInstanceMethod(PPDocumentGridSettingsSheetController,
                                presetsMenuItemSelected_ImportPresetsFromFile:,
                                ppGSPatch_PresetsMenuItemSelected_ImportPresetsFromFile:);


    macroSwizzleClassMethod(PPDocumentEditPatternPresetsSheetController,
                                beginEditPatternPresetsSheetForWindow:patternPresets:
                                    patternTypeDisplayName:currentPattern:
                                    addCurrentPatternAsPreset:delegate:,
                                ppGSPatch_BeginEditPatternPresetsSheetForWindow:patternPresets:
                                    patternTypeDisplayName:currentPattern:
                                    addCurrentPatternAsPreset:delegate:);
}

+ (void) load
{
    macroPerformNSObjectSelectorAfterAppLoads(ppGSGlue_ModalSheets_InstallPatches);
}

@end

@implementation PPDocumentSizeSheetController (PPGNUstepGlue_ModalSheets)

- (IBAction) ppGSPatch_SizePresetsMenuItemSelected_EditSizePresets: (id) sender
{
    [self ppGSGlue_PerformSelectorFromNewStackFrameInModalMode:
                            @selector(ppGSPatch_SizePresetsMenuItemSelected_EditSizePresets:)];
}

@end

@implementation PPDocumentBackgroundSettingsSheetController (PPGNUstepGlue_ModalSheets)

- (IBAction) ppGSPatch_PatternPresetsMenuItemSelected_AddCurrentPatternToPresets: (id) sender
{
    [self ppGSGlue_PerformSelectorFromNewStackFrameInModalMode:
            @selector(ppGSPatch_PatternPresetsMenuItemSelected_AddCurrentPatternToPresets:)];
}

- (IBAction) ppGSPatch_PatternPresetsMenuItemSelected_EditPresets: (id) sender
{
    [self ppGSGlue_PerformSelectorFromNewStackFrameInModalMode:
                @selector(ppGSPatch_PatternPresetsMenuItemSelected_EditPresets:)];
}

- (IBAction) ppGSPatch_PatternPresetsMenuItemSelected_ExportPresetsToFile: (id) sender
{
    [self ppGSGlue_PerformSelectorFromNewStackFrameInModalMode:
                @selector(ppGSPatch_PatternPresetsMenuItemSelected_ExportPresetsToFile:)];
}

- (IBAction) ppGSPatch_PatternPresetsMenuItemSelected_ImportPresetsFromFile: (id) sender
{
    [self ppGSGlue_PerformSelectorFromNewStackFrameInModalMode:
                @selector(ppGSPatch_PatternPresetsMenuItemSelected_ImportPresetsFromFile:)];
}

@end

@implementation PPDocumentGridSettingsSheetController (PPGNUstepGlue_ModalSheets)

- (IBAction) ppGSPatch_PresetsMenuItemSelected_AddCurrentPatternToPresets: (id) sender
{
    [self ppGSGlue_PerformSelectorFromNewStackFrameInModalMode:
                @selector(ppGSPatch_PresetsMenuItemSelected_AddCurrentPatternToPresets:)];
}

- (IBAction) ppGSPatch_PresetsMenuItemSelected_EditPresets: (id) sender
{
    [self ppGSGlue_PerformSelectorFromNewStackFrameInModalMode:
                @selector(ppGSPatch_PresetsMenuItemSelected_EditPresets:)];
}

- (IBAction) ppGSPatch_PresetsMenuItemSelected_ExportPresetsToFile: (id) sender
{
    [self ppGSGlue_PerformSelectorFromNewStackFrameInModalMode:
                @selector(ppGSPatch_PresetsMenuItemSelected_ExportPresetsToFile:)];
}

- (IBAction) ppGSPatch_PresetsMenuItemSelected_ImportPresetsFromFile: (id) sender
{
    [self ppGSGlue_PerformSelectorFromNewStackFrameInModalMode:
                @selector(ppGSPatch_PresetsMenuItemSelected_ImportPresetsFromFile:)];
}

@end

@interface PPDocumentEditPatternPresetsSheetController (PPGNUstepGlue_ModalSheetsPrivate)

// mirror of private initializer declaration in PPDocumentEditPatternPresetsSheetController.m

- initWithPatternPresets: (PPPatternPresets *) patternPresets
    patternTypeDisplayName: (NSString *) patternTypeDisplayName
    currentPattern: (id <PPPresettablePattern>) currentPattern
    delegate: (id) delegate;

@end

@implementation PPDocumentEditPatternPresetsSheetController (PPGNUstepGlue_ModalSheets)

+ (bool) ppGSPatch_BeginEditPatternPresetsSheetForWindow: (NSWindow *) window
            patternPresets: (PPPatternPresets *) patternPresets
            patternTypeDisplayName: (NSString *) patternTypeDisplayName
            currentPattern: (id <PPPresettablePattern>) currentPattern
            addCurrentPatternAsPreset: (bool) addCurrentPatternAsPreset
            delegate: (id) delegate
{
    PPDocumentEditPatternPresetsSheetController *controller;

    controller = [[[self alloc] initWithPatternPresets: patternPresets
                                patternTypeDisplayName: patternTypeDisplayName
                                currentPattern: currentPattern
                                delegate: delegate]
                            autorelease];

    if (!controller)
        goto ERROR;

    if (addCurrentPatternAsPreset)
    {
        [controller ppGSGlue_PerformSelectorFromNewStackFrameInModalMode:
                                                @selector(addCurrentPatternToEditablePatterns)];
    }

    if (![controller beginSheetModalForWindow: window])
    {
        goto ERROR;
    }

    return YES;

ERROR:
    return NO;
}

@end

@implementation NSObject (PPGNUstepGlue_ModalSheetsUtilities)

- (void) ppGSGlue_PerformSelectorFromNewStackFrameInModalMode: (SEL) selector
{
    static NSArray *modes = nil;

    if (!modes)
    {
        modes = [[NSArray arrayWithObject: NSModalPanelRunLoopMode] retain];
    }

    if (selector)
    {
        [self performSelector: selector
                withObject: nil
                afterDelay: 0.0f
                inModes: modes];
    }
}

@end

#endif  // GNUSTEP

