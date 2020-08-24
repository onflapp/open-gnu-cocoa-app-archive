/*
    PPGNUstepGlue_ImageRecacheSpeedups.m

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
#import "PPDocument.h"
#import "PPCanvasView.h"
#import "PPDocumentLayer.h"
#import "PPDocument_Notifications.h"
#import "NSBitmapImageRep_PPUtilities.h"
#import "PPGeometry.h"

//  An NSImage with no cached native-format representations (such as an image that hasn't been
// drawn yet or an image that's been sent an -[NSImage recache] message) needs a native-format
// representation to be generated (internally) before it can be drawn to a graphics context.
//  The native-format representation is always generated for the entire image (and it's
// relatively slow to generate on GNUstep, compared to OS X), even when only a small part of
// the image is being drawn to the graphics context. It's also inefficient to delete &
// regenerate the entire native representation when only a small part of the image's source
// bitmap representation has changed (such as when dragging a drawing tool).
//  Workaround/speedup intercepts recache messages to prevent the cached native representation
// from being deleted & regenerated, and instead updates the cached native representation
// directly by drawing the updated area of the source bitmap representation onto it. (NSImage's
// lockFocus sets the image's native representation to be the target graphics context).


//  For now, disable patch of -[PPDocument recacheDissolvedDrawingLayerThumbnailImageInBounds:],
// because _dissolvedDrawingLayerThumbnailImage is currently only drawn in one place: on the
// navigator popup when the canvas' view mode is set to draw-layer-only.
//  The recache speedup patch is most useful on images that are redrawn often, but the
// additional slowdown (updating the native representation each time the image is recached)
// probably isn't worth it for a rarely-drawn image like _dissolvedDrawingLayerThumbnailImage.
#define SHOULD_PATCH_PPDOCUMENT_RECACHEDISSOLVEDDRAWINGLAYERTHUMBNAILIMAGEINBOUNDS      (false)


@implementation NSObject (PPGNUstepGlue_ImageRecacheSpeedups)

+ (void) ppGSGlue_ImageRecacheSpeedups_InstallPatches
{
    macroSwizzleInstanceMethod(PPDocument, recacheMergedVisibleLayersThumbnailImageInBounds:,
                                ppGSPatch_RecacheMergedVisibleLayersThumbnailImageInBounds:);

#if SHOULD_PATCH_PPDOCUMENT_RECACHEDISSOLVEDDRAWINGLAYERTHUMBNAILIMAGEINBOUNDS

    macroSwizzleInstanceMethod(PPDocument, recacheDissolvedDrawingLayerThumbnailImageInBounds:,
                                ppGSPatch_RecacheDissolvedDrawingLayerThumbnailImageInBounds:);

#endif  // SHOULD_PATCH_PPDOCUMENT_RECACHEDISSOLVEDDRAWINGLAYERTHUMBNAILIMAGEINBOUNDS

    macroSwizzleInstanceMethod(PPDocument, handleUpdateToInteractiveMoveTargetBitmapInBounds:,
                                ppGSPatch_HandleUpdateToInteractiveMoveTargetBitmapInBounds:);


    macroSwizzleInstanceMethod(PPCanvasView, recacheZoomedVisibleCanvasImageInBounds:,
                                ppGSPatch_RecacheZoomedVisibleCanvasImageInBounds:);


    macroSwizzleInstanceMethod(PPDocumentLayer, handleUpdateToBitmapInRect:,
                                ppGSPatch_HandleUpdateToBitmapInRect:);
}

+ (void) load
{
    macroPerformNSObjectSelectorAfterAppLoads(ppGSGlue_ImageRecacheSpeedups_InstallPatches);
}

@end

@implementation PPDocument (PPGNUstepGlue_ImageRecacheSpeedups)

- (void) ppGSPatch_RecacheMergedVisibleLayersThumbnailImageInBounds: (NSRect) bounds
{
    if (NSIsEmptyRect(bounds))
    {
        return;
    }

    [_mergedVisibleLayersThumbnailImage lockFocus];

    [[_mergedVisibleLayersBitmap ppShallowDuplicateFromBounds: bounds] drawInRect: bounds];

    [_mergedVisibleLayersThumbnailImage unlockFocus];
}

#if SHOULD_PATCH_PPDOCUMENT_RECACHEDISSOLVEDDRAWINGLAYERTHUMBNAILIMAGEINBOUNDS

- (void) ppGSPatch_RecacheDissolvedDrawingLayerThumbnailImageInBounds: (NSRect) bounds
{
    if (NSIsEmptyRect(bounds))
    {
        return;
    }

    [_dissolvedDrawingLayerThumbnailImage lockFocus];

    [[_dissolvedDrawingLayerBitmap ppShallowDuplicateFromBounds: bounds] drawInRect: bounds];

    [_dissolvedDrawingLayerThumbnailImage unlockFocus];
}

#endif  // SHOULD_PATCH_PPDOCUMENT_RECACHEDISSOLVEDDRAWINGLAYERTHUMBNAILIMAGEINBOUNDS

- (void) ppGSPatch_HandleUpdateToInteractiveMoveTargetBitmapInBounds: (NSRect) bounds
{
    if (NSIsEmptyRect(bounds))
    {
        return;
    }

    if (_interactiveMoveDisplayMode == kPPLayerDisplayMode_DrawingLayerOnly)
    {
        [_drawingLayer handleUpdateToBitmapInRect: bounds];

        [self handleUpdateToLayerAtIndex: _indexOfDrawingLayer inRect: bounds];
    }
    else
    {
        // patch replaces original method's call to [_mergedVisibleLayersThumbnailImage recache]

        [_mergedVisibleLayersThumbnailImage lockFocus];

        [[_mergedVisibleLayersBitmap ppShallowDuplicateFromBounds: bounds] drawInRect: bounds];

        [_mergedVisibleLayersThumbnailImage unlockFocus];

        [self postNotification_UpdatedMergedVisibleAreaInRect: bounds];
    }
}

@end

@implementation PPCanvasView (PPGNUstepGlue_ImageRecacheSpeedups)

- (void) ppGSPatch_RecacheZoomedVisibleCanvasImageInBounds: (NSRect) bounds
{
    if (NSIsEmptyRect(bounds))
    {
        return;
    }

    [_zoomedVisibleCanvasImage lockFocus];

    [[_zoomedVisibleCanvasBitmap ppShallowDuplicateFromBounds: bounds] drawInRect: bounds];

    [_zoomedVisibleCanvasImage unlockFocus];
}

@end

@implementation PPDocumentLayer (PPGNUstepGlue_ImageRecacheSpeedups)

- (void) ppGSPatch_HandleUpdateToBitmapInRect: (NSRect) updateRect
{
    updateRect = NSIntersectionRect(PPGeometry_OriginRectOfSize(_size), updateRect);

    if (NSIsEmptyRect(updateRect))
    {
        return;
    }

    [_image lockFocus];

    [[_bitmap ppShallowDuplicateFromBounds: updateRect] drawInRect: updateRect];

    [_image unlockFocus];

    if (_linearBlendingBitmap)
    {
        [_linearBlendingBitmap ppLinearCopyFromImageBitmap: _bitmap inBounds: updateRect];
    }
}

@end

#endif  // GNUSTEP

