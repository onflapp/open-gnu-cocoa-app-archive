/*
    PPGNUstepGlue_PreviewImageViewResizing.m

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

// Workarounds for resizing issues with the preview image views on the Export & Scaling sheets
// that caused scrollbars to remain visible when not needed

#ifdef GNUSTEP

#import <Cocoa/Cocoa.h>
#import "NSObject_PPUtilities.h"
#import "PPAppBootUtilities.h"
#import "PPExportPanelAccessoryViewController.h"
#import "PPDocumentScaleSheetController.h"
#import "GNUstepGUI/GSTheme.h"
#import "PPGeometry.h"
#import "NSBitmapImageRep_PPUtilities.h"
#import "NSImage_PPUtilities.h"


@implementation NSObject (PPGNUstepGlue_PreviewImageViewResizing)

+ (void) ppGSGlue_PreviewImageViewResizing_InstallPatches
{
    macroSwizzleInstanceMethod(PPExportPanelAccessoryViewController,
                                resizePreviewViewForImageWithSize:,
                                ppGSPatch_ResizePreviewViewForImageWithSize:);


    macroSwizzleInstanceMethod(PPDocumentScaleSheetController,
                                updatePreviewImageForCurrentScaledSize,
                                ppGSPatch_UpdatePreviewImageForCurrentScaledSize);
}

+ (void) load
{
    macroPerformNSObjectSelectorAfterAppLoads(ppGSGlue_PreviewImageViewResizing_InstallPatches);
}

@end

@implementation PPExportPanelAccessoryViewController (PPGNUstepGlue_PreviewImageViewResizing)

- (void) ppGSPatch_ResizePreviewViewForImageWithSize: (NSSize) previewImageSize
{
    NSScrollView *previewScrollView;
    NSSize borderFramePadding;
    NSRect newPreviewScrollViewFrame;
    int viewMarginPadding;

    previewScrollView = [_previewImageView enclosingScrollView];

    borderFramePadding = [[GSTheme theme] sizeForBorderType: [previewScrollView borderType]];

    newPreviewScrollViewFrame = _previewScrollViewInitialFrame;

    if (previewImageSize.width < _previewScrollViewInitialFrame.size.width)
    {
        if (previewImageSize.height > _previewScrollViewInitialFrame.size.height)
        {
            viewMarginPadding = _previewScrollerWidth;
        }
        else
        {
            viewMarginPadding = 2 * borderFramePadding.width;
        }

        newPreviewScrollViewFrame.size.width = previewImageSize.width + viewMarginPadding;
    }

    if (previewImageSize.height < _previewScrollViewInitialFrame.size.height)
    {
        if (previewImageSize.width > _previewScrollViewInitialFrame.size.width)
        {
            viewMarginPadding = _previewScrollerWidth;
        }
        else
        {
            viewMarginPadding = 2 * borderFramePadding.height;
        }

        newPreviewScrollViewFrame.size.height = previewImageSize.height + viewMarginPadding;
    }

    newPreviewScrollViewFrame =
        PPGeometry_CenterRectInRect(newPreviewScrollViewFrame, _previewScrollViewInitialFrame);

    _shouldPreservePreviewNormalizedCenter = YES;

    // to set up previewScrollView's scrollbars correctly, first set _previewImageView's frame
    // to a small size
    [_previewImageView setFrameSize: NSMakeSize(1,1)];

    [previewScrollView setFrame: newPreviewScrollViewFrame];

    [_previewImageView setFrameSize: previewImageSize];

    // Changing scrollview frame causes drawing artifacts (10.4) - fix by redrawing superview
    [[previewScrollView superview] setNeedsDisplayInRect: _previewScrollViewInitialFrame];

    _previewImageSize = previewImageSize;

    [self performSelector: @selector(scrollPreviewToNormalizedCenter)];

    _shouldPreservePreviewNormalizedCenter = NO;
}

@end

@implementation PPDocumentScaleSheetController (PPGNUstepGlue_PreviewImageViewResizing)

- (void) ppGSPatch_UpdatePreviewImageForCurrentScaledSize
{
    NSScrollView *previewScrollView;
    NSSize borderFramePadding;
    NSRect newPreviewScrollViewFrame;
    int viewMarginPadding;

    previewScrollView = [_previewImageView enclosingScrollView];

    borderFramePadding = [[GSTheme theme] sizeForBorderType: [previewScrollView borderType]];

    newPreviewScrollViewFrame = _previewScrollViewInitialFrame;

    if (_scaledSize.width < _previewScrollViewInitialFrame.size.width)
    {
        if (_scaledSize.height > _previewScrollViewInitialFrame.size.height)
        {
            viewMarginPadding = _previewScrollerWidth;
        }
        else
        {
            viewMarginPadding = 2 * borderFramePadding.width;
        }

        newPreviewScrollViewFrame.size.width = _scaledSize.width + viewMarginPadding;
    }

    if (_scaledSize.height < _previewScrollViewInitialFrame.size.height)
    {
        if (_scaledSize.width > _previewScrollViewInitialFrame.size.width)
        {
            viewMarginPadding = _previewScrollerWidth;
        }
        else
        {
            viewMarginPadding = 2 * borderFramePadding.height;
        }

        newPreviewScrollViewFrame.size.height = _scaledSize.height + viewMarginPadding;
    }

    newPreviewScrollViewFrame =
        PPGeometry_CenterRectInRect(newPreviewScrollViewFrame, _previewScrollViewInitialFrame);

    _shouldPreservePreviewNormalizedCenter = YES;

    // to set up previewScrollView's scrollbars correctly, first set _previewImageView's frame
    // to a small size
    [_previewImageView setFrameSize: NSMakeSize(1,1)];

    [previewScrollView setFrame: newPreviewScrollViewFrame];

    [_previewImageView setFrameSize: _scaledSize];

    // Changing scrollview frame causes drawing artifacts (10.4) - fix by redrawing superview
    [[previewScrollView superview] setNeedsDisplayInRect: _previewScrollViewInitialFrame];

    // NSImageView seems to ignore (non)antialiasing settings when drawing downsized images
    // (on 10.5+?), so when downscaling, have to set the preview to a manually-resized image

    if (_scalingType == kPPScalingType_Downscale)
    {
        // use a local autorelease pool to make sure old images & bitmaps get dealloc'd during
        // slider tracking
        NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init];

        [_previewImageView setImage:
                            [NSImage ppImageWithBitmap:
                                        [_canvasBitmap ppBitmapResizedToSize: _scaledSize
                                                        shouldScale: YES]]];

        [autoreleasePool release];
    }
    else    // !(_scalingType == kPPScalingType_Downscale)
    {
        // upscaling - let NSImageView handle the resizing
        [_previewImageView setImage: _canvasImage];
    }

    [self performSelector: @selector(scrollPreviewToNormalizedCenter)];

    _shouldPreservePreviewNormalizedCenter = NO;
}

@end

#endif  // GNUSTEP

