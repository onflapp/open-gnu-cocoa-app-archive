/*
    PPCanvasView_RetinaDrawing.m

    Copyright 2013-2018 Josh Freeman
    http://www.twilightedge.com

    This file is part of PikoPixel for Mac OS X and GNUstep.
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

#import "PPCanvasView.h"

#if PP_DEPLOYMENT_TARGET_SUPPORTS_RETINA_DISPLAY

#import "NSObject_PPUtilities.h"
#import "NSBitmapImageRep_PPUtilities.h"
#import "NSImage_PPUtilities.h"
#import "PPGeometry.h"


static NSInvocation *gBackingScaleFactorInvocation = nil;
static bool gRetinaDrawingPatchesAreInstalled = NO;


@interface PPCanvasView (RetinaDrawingPrivateMethods)

- (void) setupRetinaDrawingBuffers;
- (bool) currentDisplayIsRetina;

+ (void) installRetinaDrawingPatches;
- (void) ppRetinaDrawingPatch_SetNeedsDisplayInRect: (NSRect) invalidRect;
- (void) ppRetinaDrawingPatch_LockFocusOnZoomedVisibleBackgroundImage;
- (void) ppRetinaDrawingPatch_UnlockFocusOnZoomedVisibleBackgroundImage;

@end

@implementation PPCanvasView (RetinaDrawing)

+ (void) initializeRetinaDrawing
{
    SEL backingScaleFactorSelector;
    NSMethodSignature *backingScaleFactorMethodSignature;

    // set up gBackingScaleFactorInvocation global

    backingScaleFactorSelector = NSSelectorFromString(@"backingScaleFactor");

    if (!backingScaleFactorSelector
        || ![NSWindow instancesRespondToSelector: backingScaleFactorSelector])
    {
        return;
    }

    backingScaleFactorMethodSignature =
        [NSWindow instanceMethodSignatureForSelector: backingScaleFactorSelector];

    if (!backingScaleFactorMethodSignature)
        return;

    gBackingScaleFactorInvocation =
        [[NSInvocation invocationWithMethodSignature: backingScaleFactorMethodSignature]
                retain];

    [gBackingScaleFactorInvocation setSelector: backingScaleFactorSelector];
}

- (void) setupRetinaDrawingForCurrentDisplay
{
    id oldRetinaBackgroundImageBuffer = _retinaBackgroundImageBuffer;

    _currentDisplayIsRetina = [self currentDisplayIsRetina];

    if (_currentDisplayIsRetina)
    {
        if (!gRetinaDrawingPatchesAreInstalled)
        {
            [PPCanvasView installRetinaDrawingPatches];
        }

        [self setupRetinaDrawingBuffers];
    }
    else
    {
        [self destroyRetinaDrawingBuffers];
    }

    if (_retinaBackgroundImageBuffer != oldRetinaBackgroundImageBuffer)
    {
        [self performSelector: @selector(updateVisibleBackground)];
    }
}

- (void) setupRetinaDrawingBuffersForResizedView;
{
    if (!_currentDisplayIsRetina)
        return;

    [self setupRetinaDrawingBuffers];
}

- (void) destroyRetinaDrawingBuffers
{
    if (_retinaDisplayBuffer)
    {
        [_retinaDisplayBuffer release];
        _retinaDisplayBuffer = nil;
    }

    if (_retinaBackgroundImageBuffer)
    {
        if ([[_zoomedVisibleBackgroundImage representations]
                                                containsObject: _retinaBackgroundImageBuffer])
        {
            [_zoomedVisibleBackgroundImage removeRepresentation: _retinaBackgroundImageBuffer];
        }

        [_retinaBackgroundImageBuffer release];
        _retinaBackgroundImageBuffer = nil;
    }
}

- (void) beginDrawingToRetinaDisplayBufferInRect: (NSRect) rect
{
    NSAffineTransform *transform;

    if (!_retinaDisplayBuffer)
        return;

    [_retinaDisplayBuffer ppSetAsCurrentGraphicsContext];

    transform = [NSAffineTransform transform];
    [transform translateXBy: -_offsetZoomedVisibleCanvasBounds.origin.x
                        yBy: -_offsetZoomedVisibleCanvasBounds.origin.y];

    [transform set];
}

- (void) finishDrawingToRetinaDisplayBufferInRect: (NSRect) rect
{
    NSRect bufferRect;

    if (!_retinaDisplayBuffer)
        return;

    [_retinaDisplayBuffer ppRestoreGraphicsContext];

    rect = NSIntersectionRect(rect, _offsetZoomedVisibleCanvasBounds);

    bufferRect.origin = PPGeometry_PointDifference(rect.origin,
                                                    _offsetZoomedVisibleCanvasBounds.origin);
    bufferRect.size = rect.size;

    [[_retinaDisplayBuffer ppShallowDuplicateFromBounds: bufferRect] drawInRect: rect];
}

#pragma mark Private methods

- (void) setupRetinaDrawingBuffers
{
    if (_retinaBackgroundImageBuffer
        && NSEqualSizes([_retinaBackgroundImageBuffer ppSizeInPixels], _zoomedVisibleImagesSize)
        && [[_zoomedVisibleBackgroundImage representations]
                                                containsObject: _retinaBackgroundImageBuffer])
    {
        return;
    }

    [self destroyRetinaDrawingBuffers];

    _retinaDisplayBuffer =
                    [[NSBitmapImageRep ppImageBitmapOfSize: _zoomedVisibleImagesSize] retain];

    if (!_retinaDisplayBuffer)
        goto ERROR;

    _retinaBackgroundImageBuffer =
                    [[NSBitmapImageRep ppImageBitmapOfSize: _zoomedVisibleImagesSize] retain];

    if (!_retinaBackgroundImageBuffer)
        goto ERROR;

    [_zoomedVisibleBackgroundImage addRepresentation: _retinaBackgroundImageBuffer];

    return;

ERROR:
    return;
}

- (bool) currentDisplayIsRetina
{
    NSWindow *parentWindow;
    CGFloat backingScaleFactor;

    if (!gBackingScaleFactorInvocation)
    {
        return NO;
    }

    parentWindow = [self window];

    if (!parentWindow)
    {
        return NO;
    }

    [gBackingScaleFactorInvocation invokeWithTarget: parentWindow];
    [gBackingScaleFactorInvocation getReturnValue: &backingScaleFactor];

    if (backingScaleFactor <= 1.0)
    {
        return NO;
    }

    return YES;
}

+ (void) installRetinaDrawingPatches
{
    if (gRetinaDrawingPatchesAreInstalled)
        return;

    macroSwizzleInstanceMethod(self, lockFocusOnZoomedVisibleBackgroundImage,
                                ppRetinaDrawingPatch_LockFocusOnZoomedVisibleBackgroundImage);

    macroSwizzleInstanceMethod(self, unlockFocusOnZoomedVisibleBackgroundImage,
                                ppRetinaDrawingPatch_UnlockFocusOnZoomedVisibleBackgroundImage);

    gRetinaDrawingPatchesAreInstalled = YES;
}

- (void) ppRetinaDrawingPatch_LockFocusOnZoomedVisibleBackgroundImage
{
    if (!_retinaBackgroundImageBuffer)
    {
        [_zoomedVisibleBackgroundImage lockFocus];
        return;
    }

    [_retinaBackgroundImageBuffer ppSetAsCurrentGraphicsContext];
}

- (void) ppRetinaDrawingPatch_UnlockFocusOnZoomedVisibleBackgroundImage
{
    if (!_retinaBackgroundImageBuffer)
    {
        [_zoomedVisibleBackgroundImage unlockFocus];
        return;
    }

    [_retinaBackgroundImageBuffer ppRestoreGraphicsContext];

    [_zoomedVisibleBackgroundImage recache];
}

@end

#endif  // PP_DEPLOYMENT_TARGET_SUPPORTS_RETINA_DISPLAY
