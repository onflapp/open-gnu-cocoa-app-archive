/*
    PPGNUstepGlue_Miscellaneous.m

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

// Miscellaneous standalone (single-method) GNUstep workarounds & tweaks

#ifdef GNUSTEP

#import <Cocoa/Cocoa.h>
#import "NSObject_PPUtilities.h"
#import "PPAppBootUtilities.h"
#import "PPApplication.h"
#import "NSFileManager_PPUtilities.h"
#import "PPPopupPanel.h"
#import "PPToolsPanelController.h"
#import "PPDocument.h"
#import "PPCanvasView.h"
#import "PPToolButtonMatrix.h"
#import "NSPasteboard_PPUtilities.h"
#import "NSDocumentController_PPUtilities.h"
#import "PPUserFolderPaths.h"
#import "PPGeometry.h"


@implementation NSObject (PPGNUstepGlue_Miscellaneous)

+ (void) ppGSGlue_Miscellaneous_InstallPatches
{
    macroSwizzleInstanceMethod(PPApplication, validateMenuItem:, ppGSPatch_ValidateMenuItem:);


    macroSwizzleInstanceMethod(NSFileManager, ppVerifySupportFileDirectory,
                                ppGSPatch_VerifySupportFileDirectory);


    macroSwizzleInstanceMethod(NSBrowser, setMaxVisibleColumns:,
                                ppGSPatch_SetMaxVisibleColumns:);


    macroSwizzleInstanceMethod(NSImage, copyWithZone:, ppGSPatch_CopyWithZone:);


    macroSwizzleInstanceMethod(PPPopupPanel, canBecomeKeyWindow, ppGSPatch_CanBecomeKeyWindow);


    macroSwizzleInstanceMethod(PPToolsPanelController, defaultPinnedWindowFrame,
                                ppGSPatch_DefaultPinnedWindowFrame);


    macroSwizzleInstanceMethod(PPDocument, setupNewPPDocumentWithCanvasSize:,
                                ppGSPatch_SetupNewPPDocumentWithCanvasSize:);


    macroSwizzleInstanceMethod(PPCanvasView, drawRect:, ppGSPatch_DrawRect:);


    macroSwizzleClassMethod(PPToolButtonMatrix, cellClass, ppGSPatch_CellClass);


    macroSwizzleInstanceMethod(NSColorWell, performClick:, ppGSPatch_PerformClick:);
}

+ (void) load
{
    macroPerformNSObjectSelectorAfterAppLoads(ppGSGlue_Miscellaneous_InstallPatches);
}

@end

@implementation PPApplication (PPGNUstepGlue_Miscellaneous)

// PATCH: -[PPApplication validateMenuItem:]
//  GNUstep doesn't support comparing selectors with ==, so patched to use sel_isEqual().

- (BOOL) ppGSPatch_ValidateMenuItem: (id <NSMenuItem>) menuItem
{
    SEL menuItemAction = [menuItem action];

    if (sel_isEqual(menuItemAction, @selector(newDocumentFromPasteboard:)))
    {
        return [NSPasteboard ppPasteboardHasBitmap] ? YES : NO;
    }

    // printing is currently disabled, so both printing-related menu items (print & page setup)
    // use runPageLayout: as their action for convenience when invalidating them

    if (sel_isEqual(menuItemAction, @selector(runPageLayout:)))
    {
        return NO;
    }


    if (sel_isEqual(menuItemAction, @selector(activateNextDocumentWindow:))
        || sel_isEqual(menuItemAction, @selector(activatePreviousDocumentWindow:)))
    {
        return [[NSDocumentController sharedDocumentController] ppHasMultipleDocuments];
    }

    return YES;
}

@end

@implementation NSFileManager (PPGNUstepGlue_Miscellaneous)

// PATCH: -[NSFileManager ppVerifySupportFileDirectory]
//  On GNUstep, the ApplicationSupport directory may not exist yet, and if it's not there, then
// creating the PikoPixel support folder (in the ApplicationSupport directory) will fail,
// because ppVerifySupportFileDirectory calls -[NSFileManager createDirectoryAtPath:...] with
// the createIntermediates parameter set to NO.
//  Patch calls -[NSFileManager createDirectoryAtPath:...] with the createIntermediates
// parameter set to YES.

- (bool) ppGSPatch_VerifySupportFileDirectory
{
    NSString *supportFolderPath = PPUserFolderPaths_ApplicationSupport();
    BOOL isDirectory = NO;

    if (![supportFolderPath length])
    {
        goto ERROR;
    }

    if ([self fileExistsAtPath: supportFolderPath isDirectory: &isDirectory])
    {
        if (!isDirectory)
            goto ERROR;

        return YES;
    }

    return [self createDirectoryAtPath: supportFolderPath
                    withIntermediateDirectories: YES
                    attributes: nil
                    error: NULL];

ERROR:
    return NO;
}

@end

@implementation NSBrowser (PPGNUstepGlue_Miscellaneous)

// PATCH: -[NSBrowser setMaxVisibleColumns:]
//  Patch allows browser columns on NSSavePanels & NSOpenPanels to be wider than the default
// max-width on GNUstep (140).

#define kNSBrowserMaxColumnWidth    190

- (void) ppGSPatch_SetMaxVisibleColumns: (NSInteger) columnCount
{
    static Class NSSavePanelClass = nil;

    if (!NSSavePanelClass)
    {
        NSSavePanelClass = [[NSSavePanel class] retain];
    }

    if ([[self window] isKindOfClass: NSSavePanelClass])
    {
        columnCount = [self frame].size.width / kNSBrowserMaxColumnWidth;

        if (columnCount < 1)
        {
            columnCount = 1;
        }
    }

    [self ppGSPatch_SetMaxVisibleColumns: columnCount];
}

@end

@implementation NSImage (PPGNUstepGlue_Miscellaneous)

// PATCH: -[NSImage copyWithZone:]
//  GNUstep's implementation of copyWithZone: only copies image representations that are
// non-cached, so if the source image only contains NSCachedImageReps, the copy will be empty.
//  Patch checks whether the copy is a valid image; If not - and the source image is valid -
// a valid representation is created by manually drawing the source image into the copy.

- (id) ppGSPatch_CopyWithZone: (NSZone *) zone
{
    NSImage *copiedImage = [self ppGSPatch_CopyWithZone: zone];

    if (copiedImage
        && ![copiedImage isValid]
        && [self isValid])
    {
        NSRect imageFrame = PPGeometry_OriginRectOfSize([self size]);

        [copiedImage lockFocus];

        [self drawInRect: imageFrame
                fromRect: imageFrame
                operation: NSCompositeCopy
                fraction: 1.0f];

        [copiedImage unlockFocus];
    }

    return copiedImage;
}

@end

@implementation PPPopupPanel (PPGNUstepGlue_Miscellaneous)

// PATCH: -[PPPopupPanel canBecomeKeyWindow]
//  GNUstep's implementation of -[NSWindow canBecomeKeyWindow] doesn't automatically return NO
// when the window has no title bar or resize bar (as on OS X), so need PPPopupPanel override
// to prevent popup panels from becoming key.

- (BOOL) ppGSPatch_CanBecomeKeyWindow
{
    return NO;
}

@end

@implementation PPToolsPanelController (PPGNUstepGlue_Miscellaneous)

// PATCH: -[PPToolsPanelController defaultPinnedWindowFrame]
//  Prevents the tools panel's default position from overlapping the main menu.

#define kMinDistanceBetweenToolsPanelAndMainMenu    20

- (NSRect) ppGSPatch_DefaultPinnedWindowFrame
{
    NSRect panelFrame, mainMenuFrame, mainMenuFrameMargin;

    panelFrame = [self ppGSPatch_DefaultPinnedWindowFrame];
    mainMenuFrame = [[[NSApp mainMenu] window] frame];
    mainMenuFrameMargin = NSInsetRect(mainMenuFrame, -kMinDistanceBetweenToolsPanelAndMainMenu,
                                        -kMinDistanceBetweenToolsPanelAndMainMenu);

    if (!NSIsEmptyRect(NSIntersectionRect(panelFrame, mainMenuFrameMargin)))
    {
        panelFrame.origin.y = NSMinY(mainMenuFrameMargin) - panelFrame.size.height;
    }

    return panelFrame;
}

@end

@implementation PPDocument (PPGNUstepGlue_Miscellaneous)

// PATCH: -[PPDocument setupNewPPDocumentWithCanvasSize:]
//  On GNUstep, closing a new, unmodified PPDocument will display a confirmation dialog, due to
// unsaved changes (whereas OS X can close an unmodified PPDocument immediately).
//  This is because a document's change count isn't cleared when its undoManager is sent a
// removeAllActions message (a new PPDocument is changed during setup, so removeAllActions is
// called at the end of setupNewPPDocumentWithCanvasSize:).
//  The workaround is to manually clear the new document's change count.

- (bool) ppGSPatch_SetupNewPPDocumentWithCanvasSize: (NSSize) canvasSize
{
    bool returnValue = [self ppGSPatch_SetupNewPPDocumentWithCanvasSize: canvasSize];

    if (returnValue)
    {
        [self updateChangeCount: NSChangeCleared];
    }

    return returnValue;
}

@end

@implementation PPCanvasView (PPGNUstepGlue_Miscellaneous)

// PATCH: -[PPCanvasView drawRect:]
//  Fix for PPCanvasView zoomout artifacts that appear when there's only one scrollbar visible
// (but not both) - workaround is to draw over the artifacts by manually filling the area
// outside the visible canvas with the enclosing scrollview's background color (normally
// the canvasview doesn't draw this area and the underlying scrollview's background shows
// through automatically).

- (void) ppGSPatch_DrawRect: (NSRect) rect
{
    // redraw the background surrounding the visible canvas if:
    // - drawing is allowed (zoomed-images draw-mode is 0 (normal))
    // - and the dirty-rect covers some area outside the visible canvas
    // - and at least one scrollbar is visible (should only be one at this point - if they were
    // both visible, the dirty-rect would not be outside the visible canvas)
    if ((_zoomedImagesDrawMode == 0)
        && (!NSContainsRect(_offsetZoomedVisibleCanvasBounds, rect))
        && ((_offsetZoomedCanvasFrame.origin.x == 0.0)
            || (_offsetZoomedCanvasFrame.origin.y == 0.0)))
    {
        static NSColor *backgroundColor = nil;
        NSRect rect1 = NSZeroRect, rect2 = NSZeroRect;

        if (!backgroundColor)
        {
            backgroundColor = [[[self enclosingScrollView] backgroundColor] retain];
        }

        if (_offsetZoomedCanvasFrame.origin.x == 0.0)
        {
            // horizontal scrollbar - background-fill areas are above & below visible canvas

            CGFloat canvasMaxY = NSMaxY(_offsetZoomedCanvasFrame);

            rect1 = NSMakeRect(rect.origin.x,
                                canvasMaxY,
                                rect.size.width,
                                NSMaxY(rect) - canvasMaxY);

            rect2 = NSMakeRect(rect.origin.x,
                                rect.origin.y,
                                rect.size.width,
                                _offsetZoomedCanvasFrame.origin.y - rect.origin.y);
        }
        else if (_offsetZoomedCanvasFrame.origin.y == 0.0)
        {
            // vertical scrollbar - background-fill areas are on left & right of visible canvas

            CGFloat canvasMaxX = NSMaxX(_offsetZoomedCanvasFrame);

            rect1 = NSMakeRect(canvasMaxX,
                                rect.origin.y,
                                NSMaxX(rect) - canvasMaxX,
                                rect.size.height);

            rect2 = NSMakeRect(rect.origin.x,
                                rect.origin.y,
                                _offsetZoomedCanvasFrame.origin.x - rect.origin.x,
                                rect.size.height);
        }

        [backgroundColor set];
        NSRectFill(rect1);
        NSRectFill(rect2);
    }

    [self ppGSPatch_DrawRect: rect];
}

@end

@implementation PPToolButtonMatrix (PPGNUstepGlue_Miscellaneous)

// PATCH: +[PPToolButtonMatrix cellClass]
//  GNUstep's nib loader has an issue when loading instances of NSMatrix subclasses (but not
// instances of NSMatrix itself): All of the NSMatrix-subclass' cells become NSActionCells,
// regardless of what their actual class is in the nib file. This is because the nib loader
// mistakenly forces the loaded cells (which originally have the correct class) to be
// reallocated by the class object returned by +cellClass (+[NSMatrix cellClass] returns
// NSActionCell).
//  The patch returns the correct class for allocating PPToolButtonMatrix's cells: NSButtonCell.

+ (Class) ppGSPatch_CellClass
{
    static Class buttonCellClass = NULL;

    if (!buttonCellClass)
    {
        buttonCellClass = [[NSButtonCell class] retain];
    }

    return buttonCellClass;
}

@end

@implementation NSColorWell (PPGNUstepGlue_Miscellaneous)

// PATCH: -[NSColorWell performClick:]
//  On GNUstep, -[NSColorWell performClick:] is unimplemented (calling the method falls through
// to inherited implementation which doesn't activate/deactivate the well). (This is now fixed
// in the GNUstep trunk, 2016-11-21).
//  Patch implements correct behavior for color wells: clicking deactivates if it's already
// active, & activates if it's not active.

- (void) ppGSPatch_PerformClick: (id) sender
{
    if ([self isActive])
    {
        [self deactivate];
    }
    else
    {
        [self activate: YES];
    }
}

@end

#endif  // GNUSTEP

