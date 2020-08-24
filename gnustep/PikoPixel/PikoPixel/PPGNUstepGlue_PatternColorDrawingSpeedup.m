/*
    PPGNUstepGlue_PatternColorDrawingSpeedup.m

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

// Speedup for drawing small-image pattern colors on GNUstep (Cairo?)

#ifdef GNUSTEP

#import <Cocoa/Cocoa.h>
#import "NSObject_PPUtilities.h"
#import "PPAppBootUtilities.h"
#import "PPGeometry.h"


#define kMinPatternImageDimension   32


@implementation NSObject (PPGNUstepGlue_PatternColorDrawingSpeedup)

// AA_ was inserted into the name of the _InstallPatches method to make sure it gets called
// before ppGSGlue_BitmapGraphicsContext_Install (AfterAppLoads selectors are called
// alphabetically) - this is because installing the BitmapGraphicsContext patches causes
// +[PPCanvasView initialize] to be called, which loads some pattern colors (selection-tool
// overlay)

+ (void) ppGSGlue_AA_PatternColorDrawingSpeedup_InstallPatches
{
    macroSwizzleClassMethod(NSColor, colorWithPatternImage:, ppGSPatch_ColorWithPatternImage:);
}

+ (void) load
{
    macroPerformNSObjectSelectorAfterAppLoads(
                                        ppGSGlue_AA_PatternColorDrawingSpeedup_InstallPatches);
}

@end

@implementation NSColor (PPGNUstepGlue_PatternColorDrawingSpeedup)

// PATCH: -[NSColor colorWithPatternImage:]
//  On GNUstep (Cairo?), pattern-colors made from small images (< 32x32) draw slowly.
//  The patch speeds up drawing by only returning pattern-colors with 32x32 (or larger) images;
// When the passed image is too small, the returned pattern-color instead uses an upsized image,
// drawn by tiling the original.

+ (NSColor *) ppGSPatch_ColorWithPatternImage: (NSImage *) image
{
    NSColor *patternColor;
    NSSize imageSize, minPatternSize;

    patternColor = [self ppGSPatch_ColorWithPatternImage: image];

    if (!patternColor)
        goto ERROR;

    imageSize = [image size];

    if (PPGeometry_IsZeroSize(imageSize))
    {
        goto ERROR;
    }

    minPatternSize =
            NSMakeSize(imageSize.width * ceilf(kMinPatternImageDimension / imageSize.width),
                        imageSize.height * ceilf(kMinPatternImageDimension / imageSize.height));

    if (!NSEqualSizes(imageSize, minPatternSize))
    {
        NSImage *upsizedPatternImage;
        NSColor *upsizedPatternColor;

        upsizedPatternImage = [[[NSImage alloc] initWithSize: minPatternSize] autorelease];

        if (!upsizedPatternImage)
            goto ERROR;

        [upsizedPatternImage lockFocus];

        [patternColor set];
        NSRectFill(PPGeometry_OriginRectOfSize(minPatternSize));

        [upsizedPatternImage unlockFocus];

        upsizedPatternColor = [self ppGSPatch_ColorWithPatternImage: upsizedPatternImage];

        if (!upsizedPatternColor)
            goto ERROR;

        patternColor = upsizedPatternColor;
    }

    return patternColor;

ERROR:
    return patternColor;
}

@end

#endif  // GNUSTEP

