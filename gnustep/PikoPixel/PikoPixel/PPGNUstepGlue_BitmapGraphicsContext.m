/*
    PPGNUstepGlue_BitmapGraphicsContext.m

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
#import "NSBitmapImageRep_PPUtilities.h"
#import "NSImage_PPUtilities.h"
#import "NSColor_PPUtilities.h"
#import "PPBackgroundPattern.h"
#import "PPThumbnailImageView.h"
#import "PPLayerControlButtonImagesManager.h"
#import "PPDocument.h"
#import "PPCanvasView.h"
#import "PPGeometry.h"
#import "PPDocumentLayer.h"


//  kGSMaskCutoffValue_Alpha is a "magic" number used as the threshold for a pixel's alpha value
// that determines whether a drawn pixel is 'on' or 'off' when converting to a mask bitmap from
// an image bitmap (following an antialiased stroke/fill of an NSBezierPath).
//  The current value (114) is an OK fit for Cairo (probably won't fit well with other backends,
// as the value is dependent on the drawing library's antialiasing implementation); During
// tests (Cairo), have seen drawn pixels that should be considered 'on' with alpha values as low
// as 115, and 'off' pixels with alpha values as high as 113 (small margin for error - may
// cause occasional incorrectly-masked pixels, but still better than turning off antialiasing on
// Cairo, because that causes a different set of pixel-accuracy issues that don't seem to have
// a simple workaround).
#define kGSMaskCutoffValue_Alpha                    114


//  GNUstep (Cairo?) has an antialiasing issue when drawing paths to graphics contexts smaller
// than 32x32: Drawing a path on a context smaller than 32x32 will result in diferent pixel
// values than drawing the same path to a context larger-than or equal-to 32x32, and can cause
// incorrect on/off pixels when thresholding to a mask bitmap.
//  Workaround is to construct all graphics contexts to be 32x32 or larger (using contexts that
// are silently larger than the requested size doesn't seem to cause issues).
#define kMinGraphicsContextDimension                32


#define kBitmapContextSetupStateStackSize           4

#define kMaxAllowedCachedOffscreenWindows           5


typedef struct
{
    NSRect boundsToClearBeforeDraw;

    bool copyBitmapToContextBeforeDraw;
    bool flushEntireContextAfterDraw;

} BitmapContextSetupState;

typedef struct
{
    NSWindow *window;
    NSSize size;

} CachedOffscreenWindow;


static bool gCurrentContextHasTargetBitmap = NO, gDisallowMaskBitmapThresholding = NO;
static NSBitmapImageRep *gContextTargetBitmap = nil;
static NSRect gContextBounds, gContextDirtyBounds;
static BitmapContextSetupState gBitmapContextSetupState,
        gBitmapContextSetupStateStack[kBitmapContextSetupStateStackSize];
static unsigned gBitmapContextSetupStateStackIndex = 0;


static NSGraphicsContext *GraphicsContextOfSize(NSSize size);

static inline bool CurrentContextIsTargettingBitmap(NSBitmapImageRep *bitmap);

static inline void SetContextDirtyInBounds(NSRect dirtyBounds);

static inline void PushDefaultBitmapContextSetupState(void);
static inline void PopBitmapContextSetupState(void);
static inline void ResetBitmapContextSetupState(void);

@interface NSBitmapImageRep (PPGNUstepGlue_BitmapGraphicsContextUtilities)

- (void) ppGSGlue_CopyFromCurrentGraphicsContextInBounds: (NSRect) bounds;

- (void) ppGSGlue_MergeToMaskBitmapFromImageBitmap: (NSBitmapImageRep *) sourceBitmap
            atPoint: (NSPoint) targetPoint;

@end


@implementation NSObject (PPGNUstepGlue_BitmapGraphicsContext)

+ (void) ppGSGlue_BitmapGraphicsContext_InstallPatches
{
    macroSwizzleInstanceMethod(NSBitmapImageRep, ppSetAsCurrentGraphicsContext,
                                ppGSPatch_SetAsCurrentGraphicsContext);

    macroSwizzleInstanceMethod(NSBitmapImageRep, ppRestoreGraphicsContext,
                                ppGSPatch_RestoreGraphicsContext);

    macroSwizzleInstanceMethod(NSBitmapImageRep, ppImageBitmapCompositedWithBackgroundColor:
                                    andBackgroundImage:backgroundImageInterpolation:,
                                ppGSPatch_ImageBitmapCompositedWithBackgroundColor:
                                    andBackgroundImage:backgroundImageInterpolation:);

    macroSwizzleInstanceMethod(NSBitmapImageRep, ppImageBitmapDissolvedToOpacity:,
                                ppGSPatch_ImageBitmapDissolvedToOpacity:);

    macroSwizzleInstanceMethod(NSBitmapImageRep, ppThresholdMaskBitmapPixelValuesInBounds:,
                                ppGSPatch_ThresholdMaskBitmapPixelValuesInBounds:);


    macroSwizzleInstanceMethod(NSImage, drawInRect:fromRect:operation:fraction:,
                                ppGSPatch_DrawInRect:fromRect:operation:fraction:);


    macroSwizzleInstanceMethod(NSColor, ppImageBitmapPixelValue,
                                ppGSPatch_ImageBitmapPixelValue);


    macroSwizzleInstanceMethod(PPBackgroundPattern, setupPatternFillColor,
                                ppGSPatch_SetupPatternFillColor);


    macroSwizzleInstanceMethod(PPThumbnailImageView, drawBackgroundBitmap,
                                ppGSPatch_DrawBackgroundBitmap);


    macroSwizzleInstanceMethod(PPLayerControlButtonImagesManager,
                                setupThumbnailBackgroundBitmap,
                                ppGSPatch_SetupThumbnailBackgroundBitmap);

    macroSwizzleInstanceMethod(PPLayerControlButtonImagesManager,
                                updateEnabledLayersCompositeThumbnails,
                                ppGSPatch_UpdateEnabledLayersCompositeThumbnails);

    macroSwizzleInstanceMethod(PPLayerControlButtonImagesManager,
                                updateDrawLayerCompositeThumbnails,
                                ppGSPatch_UpdateDrawLayerCompositeThumbnails);


    macroSwizzleInstanceMethod(PPDocument, mergedLayersBitmapFromIndex:toIndex:,
                                ppGSPatch_MergedLayersBitmapFromIndex:toIndex:);

    macroSwizzleInstanceMethod(PPDocument,
                                updateMergedVisibleLayersBitmapInRect:indexOfUpdatedLayer:,
                                ppGSPatch_UpdateMergedVisibleLayersBitmapInRect:
                                    indexOfUpdatedLayer:);

    macroSwizzleInstanceMethod(PPDocument, updateDissolvedDrawingLayerBitmapInRect:,
                                ppGSPatch_UpdateDissolvedDrawingLayerBitmapInRect:);

    macroSwizzleInstanceMethod(PPDocument, drawBezierPath:andFill:pathIsPixelated:,
                                ppGSPatch_BitmapGraphicsContext_DrawBezierPath:
                                    andFill:pathIsPixelated:);

    macroSwizzleInstanceMethod(PPDocument, selectPath:selectionMode:shouldAntialias:,
                                ppGSPatch_SelectPath:selectionMode:shouldAntialias:);

    macroSwizzleInstanceMethod(PPDocument, tileSelectionInBitmap:toBitmap:,
                                ppGSPatch_TileSelectionInBitmap:toBitmap:);


    macroSwizzleInstanceMethod(PPCanvasView, setSelectionToolOverlayToPath:selectionMode:
                                    intersectMask:toolPath:shouldAntialias:,
                                ppGSPatch_SetSelectionToolOverlayToPath:selectionMode:
                                    intersectMask:toolPath:shouldAntialias:);


    macroSwizzleInstanceMethod(NSBezierPath, ppAppendFillPathForMaskBitmap:inBounds:,
                                ppGSPatch_AppendFillPathForMaskBitmap:inBounds:);
}

+ (void) ppGSGlue_BitmapGraphicsContext_Install
{
    ResetBitmapContextSetupState();

    [self ppGSGlue_BitmapGraphicsContext_InstallPatches];
}

+ (void) load
{
    macroPerformNSObjectSelectorAfterAppLoads(ppGSGlue_BitmapGraphicsContext_Install);
}

@end

@implementation NSBitmapImageRep (PPGNUstepGlue_BitmapGraphicsContext)

// PATCHES: -[NSBitmapImageRep (PPUtilities) ppSetAsCurrentGraphicsContext]
//          -[NSBitmapImageRep (PPUtilities) ppRestoreGraphicsContext]
//
// GNUstep doesn't support setting an NSBitmapImageRep as the graphics context, so patches
// override the PPUtilities methods to substitute an NSCachedImageRep & use lock/unlockFocus
// on its window's contentView

- (void) ppGSPatch_SetAsCurrentGraphicsContext
{
    NSSize bitmapSize;
    NSGraphicsContext *bitmapContext;

    if (gCurrentContextHasTargetBitmap)
    {
        NSLog(@"ERROR: Unable to nest bitmap graphics contexts");
        goto ERROR;
    }

    bitmapSize = [self ppSizeInPixels];
    bitmapContext = GraphicsContextOfSize(bitmapSize);

    if (!bitmapContext)
        goto ERROR;

    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext: bitmapContext];

    // Workaround for differences between Cairo & Mac OS X when drawing paths:
    // The antialiasing-setting issue is now fixed for Cairo in the GNUstep trunk (2015-09-20),
    // so PPGNUstepGlue_BezierPathAliasing.m is no longer needed as an antialiasing-setting
    // workaround. However there's currently no workaround for Cairo & OS X differences with
    // un-antialiased drawing, so for now, enable antialiasing when drawing, and continue using
    // the antialiasing workaround, because it makes up for Cairo's differences when drawing
    // antialiased paths.

    [[NSGraphicsContext currentContext] setShouldAntialias: YES];

    gContextBounds = PPGeometry_OriginRectOfSize(bitmapSize);
    gContextDirtyBounds = NSZeroRect;

    gContextTargetBitmap = self;
    gCurrentContextHasTargetBitmap = YES;

    if (gBitmapContextSetupState.copyBitmapToContextBeforeDraw)
    {
        [self drawAtPoint: NSZeroPoint];
    }

    if (!NSIsEmptyRect(gBitmapContextSetupState.boundsToClearBeforeDraw))
    {
        NSRect clearBounds = PPGeometry_PixelBoundsCoveredByRect(
                                        gBitmapContextSetupState.boundsToClearBeforeDraw);

        NSRectFillUsingOperation(clearBounds, NSCompositeClear);
        SetContextDirtyInBounds(clearBounds);
    }

    return;

ERROR:
    return;
}

- (void) ppGSPatch_RestoreGraphicsContext
{
    if (!CurrentContextIsTargettingBitmap(self))
    {
        goto ERROR;
    }

    if (NSIsEmptyRect(gContextDirtyBounds)
        || gBitmapContextSetupState.flushEntireContextAfterDraw)
    {
        gContextDirtyBounds = gContextBounds;
        gBitmapContextSetupState.flushEntireContextAfterDraw = NO;
    }

    [self ppGSGlue_CopyFromCurrentGraphicsContextInBounds: gContextDirtyBounds];

    [NSGraphicsContext restoreGraphicsState];

    ResetBitmapContextSetupState();

    gCurrentContextHasTargetBitmap = NO;
    gContextTargetBitmap = nil;

    return;

ERROR:
    return;
}

- (NSBitmapImageRep *) ppGSPatch_ImageBitmapCompositedWithBackgroundColor:
                                                                   (NSColor *) backgroundColor
                        andBackgroundImage: (NSImage *) backgroundImage
                        backgroundImageInterpolation:
                                        (NSImageInterpolation) backgroundImageInterpolation
{
    NSBitmapImageRep *bitmap;

    PushDefaultBitmapContextSetupState();

    if (!backgroundColor)
    {
        gBitmapContextSetupState.boundsToClearBeforeDraw = [self ppFrameInPixels];
    }
    else
    {
        gBitmapContextSetupState.flushEntireContextAfterDraw = YES;
    }

    bitmap = [self ppGSPatch_ImageBitmapCompositedWithBackgroundColor: backgroundColor
                    andBackgroundImage: backgroundImage
                    backgroundImageInterpolation: backgroundImageInterpolation];

    PopBitmapContextSetupState();

    return bitmap;
}

- (NSBitmapImageRep *) ppGSPatch_ImageBitmapDissolvedToOpacity: (float) opacity
{
    NSBitmapImageRep *bitmap;

    PushDefaultBitmapContextSetupState();

    if ((opacity > 0.0) && (opacity < 1.0))
    {
        gBitmapContextSetupState.boundsToClearBeforeDraw = [self ppFrameInPixels];
    }

    bitmap = [self ppGSPatch_ImageBitmapDissolvedToOpacity: opacity];

    PopBitmapContextSetupState();

    return bitmap;
}

- (void) ppGSPatch_ThresholdMaskBitmapPixelValuesInBounds: (NSRect) bounds
{
    if (gDisallowMaskBitmapThresholding)
        return;

    [self ppGSPatch_ThresholdMaskBitmapPixelValuesInBounds: bounds];
}

@end

@implementation NSImage (PPGNUstepGlue_BitmapGraphicsContext)

- (void) ppGSPatch_DrawInRect: (NSRect) destinationRect
            fromRect: (NSRect) sourceRect
            operation: (NSCompositingOperation) operation
            fraction: (CGFloat) fraction
{
    [self ppGSPatch_DrawInRect: destinationRect
            fromRect: sourceRect
            operation: operation
            fraction: fraction];

    if (gCurrentContextHasTargetBitmap)
    {
        SetContextDirtyInBounds(destinationRect);
    }
}

@end

@implementation NSColor (PPGNUstepGlue_BitmapGraphicsContext)

// PATCH: -[NSColor (PPUtilities) ppImageBitmapPixelValue]
// GNUstep doesn't support -[NSGraphicsContext graphicsContextWithBitmapImageRep:] (called by
// in the original implementation of ppImageBitmapPixelValue), so override uses now-patched
// -[NSBitmapImageRep (PPUtilities) ppSetAsCurrentGraphicsContext] instead

- (PPImageBitmapPixel) ppGSPatch_ImageBitmapPixelValue
{
    static NSRect pixelBitmapBounds = {{0,0},{1,1}};
    static NSBitmapImageRep *pixelBitmap = nil;
    PPImageBitmapPixel *pixelData;

    if (!pixelBitmap)
    {
        pixelBitmap = [[NSBitmapImageRep ppImageBitmapOfSize: pixelBitmapBounds.size] retain];

        if (!pixelBitmap)
            goto ERROR;
    }

    [pixelBitmap ppSetAsCurrentGraphicsContext];

    [self set];
    NSRectFillUsingOperation(pixelBitmapBounds, NSCompositeCopy);

    [pixelBitmap ppRestoreGraphicsContext];

    pixelData = (PPImageBitmapPixel *) [pixelBitmap bitmapData];

    if (!pixelData)
        goto ERROR;

    return *pixelData;

ERROR:
    [pixelBitmap release];
    pixelBitmap = nil;

    return (PPImageBitmapPixel) 0;
}

@end

@implementation PPBackgroundPattern (PPGNUstepGlue_BitmapGraphicsContext)

- (void) ppGSPatch_SetupPatternFillColor
{
    PushDefaultBitmapContextSetupState();

    [self ppGSPatch_SetupPatternFillColor];

    PopBitmapContextSetupState();
}

@end

@implementation PPThumbnailImageView (PPGNUstepGlue_BitmapGraphicsContext)

- (void) ppGSPatch_DrawBackgroundBitmap
{
    // make sure pattern bitmap is already generated, otherwise it may try to set bitmap
    // as context while there's already a bitmap graphics context
    [_scaledBackgroundPattern patternFillColor];

    PushDefaultBitmapContextSetupState();
    gBitmapContextSetupState.flushEntireContextAfterDraw = YES;

    [self ppGSPatch_DrawBackgroundBitmap];

    PopBitmapContextSetupState();
}

@end

@implementation PPLayerControlButtonImagesManager (PPGNUstepGlue_BitmapGraphicsContext)

- (void) ppGSPatch_SetupThumbnailBackgroundBitmap
{
    PushDefaultBitmapContextSetupState();
    gBitmapContextSetupState.boundsToClearBeforeDraw =
                                            PPGeometry_OriginRectOfSize(_thumbnailFramesize);

    [self ppGSPatch_SetupThumbnailBackgroundBitmap];

    PopBitmapContextSetupState();
}

- (void) ppGSPatch_UpdateEnabledLayersCompositeThumbnails
{
    PushDefaultBitmapContextSetupState();
    gBitmapContextSetupState.copyBitmapToContextBeforeDraw = YES;

    [self ppGSPatch_UpdateEnabledLayersCompositeThumbnails];

    PopBitmapContextSetupState();
}

- (void) ppGSPatch_UpdateDrawLayerCompositeThumbnails
{
    PushDefaultBitmapContextSetupState();
    gBitmapContextSetupState.copyBitmapToContextBeforeDraw = YES;

    [self ppGSPatch_UpdateDrawLayerCompositeThumbnails];

    PopBitmapContextSetupState();
}

@end

@implementation PPDocument (PPGNUstepGlue_BitmapGraphicsContext)

- (NSBitmapImageRep *) ppGSPatch_MergedLayersBitmapFromIndex: (int) firstIndex
                        toIndex: (int) lastIndex
{
    NSBitmapImageRep *bitmap;

    PushDefaultBitmapContextSetupState();
    gBitmapContextSetupState.boundsToClearBeforeDraw = _canvasFrame;

    bitmap = [self ppGSPatch_MergedLayersBitmapFromIndex: firstIndex toIndex: lastIndex];

    PopBitmapContextSetupState();

    return bitmap;
}

- (void) ppGSPatch_UpdateMergedVisibleLayersBitmapInRect: (NSRect) rect
            indexOfUpdatedLayer: (int) indexOfUpdatedLayer
{
    PushDefaultBitmapContextSetupState();

    if (_layerBlendingMode != kPPLayerBlendingMode_Linear)
    {
        gBitmapContextSetupState.boundsToClearBeforeDraw = rect;
    }

    [self ppGSPatch_UpdateMergedVisibleLayersBitmapInRect: rect
            indexOfUpdatedLayer: indexOfUpdatedLayer];

    PopBitmapContextSetupState();
}

- (void) ppGSPatch_UpdateDissolvedDrawingLayerBitmapInRect: (NSRect) updateRect
{
    float drawingLayerOpacity = [_drawingLayer opacity];

    PushDefaultBitmapContextSetupState();

    if ([_drawingLayer isEnabled]
        && (drawingLayerOpacity > 0.0)
        && (drawingLayerOpacity < 1.0))
    {
        gBitmapContextSetupState.boundsToClearBeforeDraw = updateRect;
    }

    [self ppGSPatch_UpdateDissolvedDrawingLayerBitmapInRect: updateRect];

    PopBitmapContextSetupState();
}

- (void) ppGSPatch_BitmapGraphicsContext_DrawBezierPath: (NSBezierPath *) path
            andFill: (bool) shouldFillPath
            pathIsPixelated: (bool) pathIsPixelated
{
    PushDefaultBitmapContextSetupState();
    gBitmapContextSetupState.boundsToClearBeforeDraw = [path bounds];

    // mask bitmaps are automatically thresholded due to patches calling through to the local
    // method, ppGSGlue_MergeToMaskBitmapFromImageBitmap:atPoint:, so disable unnecessary
    // additional thresholding (ppThresholdMaskBitmapPixelValuesInBounds:)
    gDisallowMaskBitmapThresholding = YES;

    [self ppGSPatch_BitmapGraphicsContext_DrawBezierPath: path
            andFill: shouldFillPath
            pathIsPixelated: pathIsPixelated];

    gDisallowMaskBitmapThresholding = NO;

    PopBitmapContextSetupState();
}

- (void) ppGSPatch_SelectPath: (NSBezierPath *) path
            selectionMode: (PPSelectionMode) selectionMode
            shouldAntialias: (bool) shouldAntialias
{
    PushDefaultBitmapContextSetupState();
    gBitmapContextSetupState.boundsToClearBeforeDraw = [path bounds];

    // mask bitmaps are automatically thresholded due to patches calling through to the local
    // method, ppGSGlue_MergeToMaskBitmapFromImageBitmap:atPoint:, so disable unnecessary
    // additional thresholding (ppThresholdMaskBitmapPixelValuesInBounds:)
    gDisallowMaskBitmapThresholding = YES;

    [self ppGSPatch_SelectPath: path
            selectionMode: selectionMode
            shouldAntialias: shouldAntialias];

    gDisallowMaskBitmapThresholding = NO;

    PopBitmapContextSetupState();
}

- (bool) ppGSPatch_TileSelectionInBitmap: (NSBitmapImageRep *) sourceBitmap
            toBitmap: (NSBitmapImageRep *) destinationBitmap
{
    bool returnValue;

    PushDefaultBitmapContextSetupState();
    gBitmapContextSetupState.boundsToClearBeforeDraw = [destinationBitmap ppFrameInPixels];

    returnValue = [self ppGSPatch_TileSelectionInBitmap: sourceBitmap
                        toBitmap: destinationBitmap];

    PopBitmapContextSetupState();

    return returnValue;
}

@end

@implementation PPCanvasView (PPGNUstepGlue_BitmapGraphicsContext)

- (void) ppGSPatch_SetSelectionToolOverlayToPath: (NSBezierPath *) path
            selectionMode: (PPSelectionMode) selectionMode
            intersectMask: (NSBitmapImageRep *) intersectMask
            toolPath: (NSBezierPath *) toolPath
            shouldAntialias: (bool) shouldAntialias
{
    PushDefaultBitmapContextSetupState();
    gBitmapContextSetupState.boundsToClearBeforeDraw = [path bounds];

    // mask bitmaps are automatically thresholded due to patches calling through to the local
    // method, ppGSGlue_MergeToMaskBitmapFromImageBitmap:atPoint:, so disable unnecessary
    // additional thresholding (ppThresholdMaskBitmapPixelValuesInBounds:)
    gDisallowMaskBitmapThresholding = YES;

    [self ppGSPatch_SetSelectionToolOverlayToPath: path
            selectionMode: selectionMode
            intersectMask: intersectMask
            toolPath: toolPath
            shouldAntialias: shouldAntialias];

    gDisallowMaskBitmapThresholding = NO;

    PopBitmapContextSetupState();
}

@end

@implementation NSBezierPath (PPGNUstepGlue_BitmapGraphicsContext)

- (void) ppGSPatch_AppendFillPathForMaskBitmap: (NSBitmapImageRep *) maskBitmap
            inBounds: (NSRect) bounds
{
    if (CurrentContextIsTargettingBitmap(maskBitmap))
    {
        // target bitmap's data is out-of-date - update it from the current context's data
        [maskBitmap ppGSGlue_CopyFromCurrentGraphicsContextInBounds: bounds];
    }

    [self ppGSPatch_AppendFillPathForMaskBitmap: maskBitmap inBounds: bounds];
}

@end

@implementation NSBitmapImageRep (PPGNUstepGlue_BitmapGraphicsContextUtilities)

- (void) ppGSGlue_CopyFromCurrentGraphicsContextInBounds: (NSRect) bounds
{
    NSDictionary *contextReadRectDict;
    unsigned char *contextBoundsBitmapData;
    NSBitmapImageRep *contextBoundsBitmap;

    bounds = NSIntersectionRect(bounds, [self ppFrameInPixels]);

    if (NSIsEmptyRect(bounds))
    {
        return;
    }

    contextReadRectDict = [GSCurrentContext() GSReadRect: bounds];

    if (!contextReadRectDict)
        goto ERROR;

    contextBoundsBitmapData =
                    (unsigned char *) [[contextReadRectDict objectForKey: @"Data"] bytes];

    if (!contextBoundsBitmapData)
        goto ERROR;

    contextBoundsBitmap =
        [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes: &contextBoundsBitmapData
                                    pixelsWide: bounds.size.width
                                    pixelsHigh: bounds.size.height
                                    bitsPerSample: 8
                                    samplesPerPixel: 4
                                    hasAlpha: NO
                                    isPlanar: NO
                                    colorSpaceName: NSCalibratedRGBColorSpace
                                    bytesPerRow: bounds.size.width * 4
                                    bitsPerPixel: 0]
                                autorelease];

    if (!contextBoundsBitmap)
        goto ERROR;

    if ([self ppIsMaskBitmap])
    {
        [self ppGSGlue_MergeToMaskBitmapFromImageBitmap: contextBoundsBitmap
                atPoint: bounds.origin];
    }
    else
    {
        [self ppCopyFromBitmap: contextBoundsBitmap
                inRect: PPGeometry_OriginRectOfSize(bounds.size)
                toPoint: bounds.origin];
    }

    return;

ERROR:
    return;
}

- (void) ppGSGlue_MergeToMaskBitmapFromImageBitmap: (NSBitmapImageRep *) sourceBitmap
            atPoint: (NSPoint) targetPoint
{
    NSRect destinationFrame, destinationRect, sourceFrame, sourceRect;
    unsigned char *destinationData, *destinationRow, *sourceData, *sourceRow;
    int destinationBytesPerRow, destinationDataOffset, sourceBytesPerRow, sourceDataOffset,
        rowOffset, rowCounter, pixelsPerRow, pixelCounter;
    PPMaskBitmapPixel *destinationPixel;
    PPImageBitmapPixel *sourcePixel;

    if (![self ppIsMaskBitmap] || ![sourceBitmap ppIsImageBitmap])
    {
        goto ERROR;
    }

    destinationFrame = [self ppFrameInPixels];

    sourceFrame = [sourceBitmap ppFrameInPixels];

    targetPoint = PPGeometry_PointClippedToIntegerValues(targetPoint);

    sourceRect = sourceFrame;

    destinationRect.origin = targetPoint;
    destinationRect.size = sourceRect.size;

    destinationRect = NSIntersectionRect(destinationRect, destinationFrame);

    if (NSIsEmptyRect(destinationRect))
    {
        goto ERROR;
    }

    if (!NSEqualSizes(destinationRect.size, sourceRect.size))
    {
        sourceRect.origin.x += destinationRect.origin.x - targetPoint.x;
        sourceRect.origin.y += destinationRect.origin.y - targetPoint.y;

        sourceRect.size = destinationRect.size;
    }

    destinationData = [self bitmapData];
    sourceData = [sourceBitmap bitmapData];

    if (!destinationData || !sourceData)
    {
        goto ERROR;
    }

    destinationBytesPerRow = [self bytesPerRow];

    rowOffset =
        destinationFrame.size.height - destinationRect.size.height - destinationRect.origin.y;

    destinationDataOffset = rowOffset * destinationBytesPerRow
                            + destinationRect.origin.x * sizeof(PPMaskBitmapPixel);

    destinationRow = &destinationData[destinationDataOffset];


    sourceBytesPerRow = [sourceBitmap bytesPerRow];

    rowOffset = sourceFrame.size.height - sourceRect.size.height - sourceRect.origin.y;

    sourceDataOffset = rowOffset * sourceBytesPerRow
                        + sourceRect.origin.x * sizeof(PPImageBitmapPixel);

    sourceRow = &sourceData[sourceDataOffset];

    pixelsPerRow = destinationRect.size.width;
    rowCounter = destinationRect.size.height;

    while (rowCounter--)
    {
        destinationPixel = (PPMaskBitmapPixel *) destinationRow;
        sourcePixel = (PPImageBitmapPixel *) sourceRow;

        pixelCounter = pixelsPerRow;

        while (pixelCounter--)
        {
            if (macroImagePixelComponent_Alpha(sourcePixel) > kGSMaskCutoffValue_Alpha)
            {
                *destinationPixel = macroImagePixelComponent_Red(sourcePixel);
            }

            destinationPixel++;
            sourcePixel++;
        }

        destinationRow += destinationBytesPerRow;
        sourceRow += sourceBytesPerRow;
    }

    return;

ERROR:
    return;
}

@end

#pragma mark Private functions

static NSGraphicsContext *GraphicsContextOfSize(NSSize size)
{
    static CachedOffscreenWindow cachedOffscreenWindows[kMaxAllowedCachedOffscreenWindows];
    static int numCachedOffscreenWindows = 0;
    int i;

    if (PPGeometry_IsZeroSize(size))
    {
        goto ERROR;
    }

    if (size.width < kMinGraphicsContextDimension)
    {
        size.width = kMinGraphicsContextDimension;
    }

    if (size.height < kMinGraphicsContextDimension)
    {
        size.height = kMinGraphicsContextDimension;
    }

    for (i=0; i<numCachedOffscreenWindows; i++)
    {
        if (NSEqualSizes(size, cachedOffscreenWindows[i].size))
        {
            break;
        }
    }

    if (i >= numCachedOffscreenWindows)
    {
        NSCachedImageRep *cachedImageRep = [[[NSCachedImageRep alloc] initWithSize: size
                                                                        depth: 0
                                                                        separate: YES
                                                                        alpha: YES]
                                                                    autorelease];

        NSWindow *offscreenWindow = [cachedImageRep window];

        if (!offscreenWindow)
            goto ERROR;

        if (i >= kMaxAllowedCachedOffscreenWindows)
        {
            i = kMaxAllowedCachedOffscreenWindows - 1;

            [cachedOffscreenWindows[i].window release];
        }
        else
        {
            numCachedOffscreenWindows++;
        }

        memmove(&cachedOffscreenWindows[1], &cachedOffscreenWindows[0],
                i * sizeof(*cachedOffscreenWindows));

        cachedOffscreenWindows[0].window = [offscreenWindow retain];
        cachedOffscreenWindows[0].size = size;
    }
    else if (i > 0)
    {
        CachedOffscreenWindow cachedOffscreenWindow = cachedOffscreenWindows[i];

        memmove(&cachedOffscreenWindows[1], &cachedOffscreenWindows[0],
                i * sizeof(*cachedOffscreenWindows));

        cachedOffscreenWindows[0] = cachedOffscreenWindow;
    }

    return [cachedOffscreenWindows[0].window graphicsContext];

ERROR:
    return nil;
}

static inline bool CurrentContextIsTargettingBitmap(NSBitmapImageRep *bitmap)
{
    return (gCurrentContextHasTargetBitmap && (gContextTargetBitmap == bitmap)) ? YES : NO;
}

static inline void SetContextDirtyInBounds(NSRect dirtyBounds)
{
    gContextDirtyBounds =
        NSIntersectionRect(gContextBounds,
                            NSUnionRect(PPGeometry_PixelBoundsCoveredByRect(dirtyBounds),
                                        gContextDirtyBounds));
}

static inline void PushDefaultBitmapContextSetupState(void)
{
    if (gBitmapContextSetupStateStackIndex >= kBitmapContextSetupStateStackSize)
    {
        NSLog(@"ERROR: Overflowed bitmap graphics context state stack");
        return;
    }

    memcpy(&gBitmapContextSetupStateStack[gBitmapContextSetupStateStackIndex++],
            &gBitmapContextSetupState, sizeof(gBitmapContextSetupState));

    memset(&gBitmapContextSetupState, 0, sizeof(gBitmapContextSetupState));
}

static inline void PopBitmapContextSetupState(void)
{
    if ((gBitmapContextSetupStateStackIndex > kBitmapContextSetupStateStackSize)
        || !gBitmapContextSetupStateStackIndex)
    {
        return;
    }

    memcpy(&gBitmapContextSetupState,
            &gBitmapContextSetupStateStack[--gBitmapContextSetupStateStackIndex],
            sizeof(gBitmapContextSetupState));
}

static inline void ResetBitmapContextSetupState(void)
{
    memset(&gBitmapContextSetupState, 0, sizeof(gBitmapContextSetupState));
}

#endif  // GNUSTEP

