/*
    PPGNUstepGlue_BitmapNonpremultipliedPNG.m

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
#import "PPApplication.h"
#import "PPImagePixelAlphaPremultiplyTables.h"
#import "NSBitmapImageRep_PPUtilities.h"


static bool gAllowInPlaceUnpremultiply = NO, gBitmapSourceIsExternal = NO;


@interface NSBitmapImageRep (PPGNUstepGlue_BitmapNonpremultipliedPNGUtilities)

- (bool) ppGSGlue_CanPremultiplyImportedBitmap;

- (bool) ppGSGlue_Premultiply;
- (bool) ppGSGlue_Unpremultiply;

- (NSBitmapImageRep *) ppGSGlue_UnpremultipliedBitmap;

@end

@interface NSImage (PPGNUstepGlue_BitmapNonpremultipliedPNGUtilities)

- (void) ppGSGlue_PremultiplyBitmapRepresentations;

@end

@implementation NSObject (PPGNUstepGlue_BitmapNonpremultipliedPNG)

+ (void) ppGSGlue_AA_BitmapNonpremultipliedPNG_InstallPatches
{
    macroSwizzleInstanceMethod(NSBitmapImageRep, _initBitmapFromPNG:,
                                ppGSPatch_InitBitmapFromPNG:);

    macroSwizzleInstanceMethod(NSBitmapImageRep, _PNGRepresentationWithProperties:,
                                ppGSPatch_PNGRepresentationWithProperties:);

    macroSwizzleInstanceMethod(NSBitmapImageRep, ppCompressedTIFFDataFromBounds:,
                                ppGSPatch_CompressedTIFFDataFromBounds:);

    macroSwizzleClassMethod(NSBitmapImageRep, ppImageBitmapWithImportedData:,
                                ppGSPatch_ImageBitmapWithImportedData:);
}

+ (void) load
{
    // AA_ was inserted into the name of the _InstallPatches method to make sure it gets called
    // before ppGSGlue_BitmapGraphicsContext_Install (AfterAppLoads selectors are called
    // alphabetically) - this is because installing the BitmapGraphicsContext patches causes
    // +[PPCanvasView initialize] to be called, which loads some PNG images (for selection-tool
    // overlay pattern colors)

    macroPerformNSObjectSelectorAfterAppLoads(
                                        ppGSGlue_AA_BitmapNonpremultipliedPNG_InstallPatches);
}

@end

@implementation PPApplication (PPGNUstepGlue_BitmapNonpremultipliedPNG)

// OVERRIDE: -[NSApplication setApplicationIconImage:]
//  GNUstep sets up the application icon before the app finishes launching (& before PikoPixel
// installs its patches), so -[NSApplication setApplicationIconImage:] is "patched" by
// implementing a subclass override method in PPApplication (PPApplication doesn't implement
// this method elsewhere).
//  The override manually premultiplies the bitmap representations in the icon image, since
// the -[NSBitmapImageRep initBitmapFromPNG:] patch that would automatically premultiply them
// as they're initialized isn't installed yet.

- (void) setApplicationIconImage: (NSImage *) anImage
{
    [anImage ppGSGlue_PremultiplyBitmapRepresentations];

    [super setApplicationIconImage: anImage];
}

@end

@implementation NSBitmapImageRep (PPGNUstepGlue_BitmapNonpremultipliedPNG)

- (id) ppGSPatch_InitBitmapFromPNG: (NSData *) imageData
{
    self = [self ppGSPatch_InitBitmapFromPNG: imageData];

    [self ppGSGlue_Premultiply];

    return self;
}

- (NSData *) ppGSPatch_PNGRepresentationWithProperties: (NSDictionary *) properties
{
    if (gAllowInPlaceUnpremultiply)
    {
        [self ppGSGlue_Unpremultiply];
    }
    else
    {
        self = [self ppGSGlue_UnpremultipliedBitmap];
    }

    return [self ppGSPatch_PNGRepresentationWithProperties: properties];
}

// PATCH: -[NSBitmapImageRep (PPUtilities) ppCompressedTIFFDataFromBounds:]
// ppCompressedTIFFData (called by ppCompressedTIFFDataFromBounds:) is currently patched on
// GNUstep to return PNG data (OS X had issues reading GNUstep-written TIFF data), and it uses
// a temporary, single-use bitmap for constructing the PNG data, so unpremultiplying in-place
// is quicker than allocating & converting an additional temporary bitmap.

- (NSData *) ppGSPatch_CompressedTIFFDataFromBounds: (NSRect) bounds
{
    NSData *returnedData;

    gAllowInPlaceUnpremultiply = YES;

    returnedData = [self ppGSPatch_CompressedTIFFDataFromBounds: bounds];

    gAllowInPlaceUnpremultiply = NO;

    return returnedData;
}

+ (NSBitmapImageRep *) ppGSPatch_ImageBitmapWithImportedData: (NSData *) importedData
{
    NSBitmapImageRep *returnedBitmap;

    gBitmapSourceIsExternal = YES;

    returnedBitmap = [self ppGSPatch_ImageBitmapWithImportedData: importedData];

    gBitmapSourceIsExternal = NO;

    return returnedBitmap;
}

@end

@implementation NSBitmapImageRep (PPGNUstepGlue_BitmapNonpremultipliedPNGUtilities)

- (bool) ppGSGlue_CanPremultiplyImportedBitmap
{
    // Premultiply implementation only supports 4-channel bitmaps that have an alpha channel
    // and 8 bits-per-sample; For locally-created bitmaps, ppIsImageBitmap is enough for
    // verification, however, it only checks the number of channels, so external-source bitmaps
    // also need explicit alpha & bitsPerSample checks before allowing premultiply

    return (([self samplesPerPixel] == 4)
                && [self hasAlpha]
                && ([self bitsPerSample] == 8)) ? YES : NO;
}

- (bool) ppGSGlue_Premultiply
{
    NSSize bitmapSize;
    unsigned char *bitmapRow, *premultiplyTable;
    int bytesPerRow, pixelsPerRow, rowCounter, pixelCounter;
    PPImageBitmapPixel *bitmapPixel;

    if (!(_format & NSAlphaNonpremultipliedBitmapFormat)
        || ![self ppIsImageBitmap]
        || (gBitmapSourceIsExternal && ![self ppGSGlue_CanPremultiplyImportedBitmap]))
    {
        return NO;
    }

    bitmapSize = [self ppSizeInPixels];

    bitmapRow = [self bitmapData];

    if (!bitmapRow)
        goto ERROR;

    bytesPerRow = [self bytesPerRow];
    pixelsPerRow = bitmapSize.width;

    rowCounter = bitmapSize.height;

    while (rowCounter--)
    {
        bitmapPixel = (PPImageBitmapPixel *) bitmapRow;

        pixelCounter = pixelsPerRow;

        while (pixelCounter--)
        {
            if (macroImagePixelComponent_Alpha(bitmapPixel) == 255)
            {
                bitmapPixel++;
            }
            else if (macroImagePixelComponent_Alpha(bitmapPixel) == 0)
            {
                *bitmapPixel++ = 0;
            }
            else
            {
                premultiplyTable = macroAlphaPremultiplyTableForImagePixel(bitmapPixel);

                macroImagePixelComponent_Red(bitmapPixel) =
                            premultiplyTable[macroImagePixelComponent_Red(bitmapPixel)];

                macroImagePixelComponent_Green(bitmapPixel) =
                            premultiplyTable[macroImagePixelComponent_Green(bitmapPixel)];

                macroImagePixelComponent_Blue(bitmapPixel) =
                            premultiplyTable[macroImagePixelComponent_Blue(bitmapPixel)];

                bitmapPixel++;
            }
        }

        bitmapRow += bytesPerRow;
    }

    _format &= ~NSAlphaNonpremultipliedBitmapFormat;

    return YES;

ERROR:
    return NO;
}

- (bool) ppGSGlue_Unpremultiply
{
    NSSize bitmapSize;
    unsigned char *bitmapRow, *unpremultiplyTable;
    int bytesPerRow, pixelsPerRow, rowCounter, pixelCounter;
    PPImageBitmapPixel *bitmapPixel;

    if ((_format & NSAlphaNonpremultipliedBitmapFormat)
        || ![self ppIsImageBitmap])
    {
        return NO;
    }

    bitmapSize = [self ppSizeInPixels];

    bitmapRow = [self bitmapData];

    if (!bitmapRow)
        goto ERROR;

    bytesPerRow = [self bytesPerRow];
    pixelsPerRow = bitmapSize.width;

    rowCounter = bitmapSize.height;

    while (rowCounter--)
    {
        bitmapPixel = (PPImageBitmapPixel *) bitmapRow;

        pixelCounter = pixelsPerRow;

        while (pixelCounter--)
        {
            if ((macroImagePixelComponent_Alpha(bitmapPixel) == 255)
                || (macroImagePixelComponent_Alpha(bitmapPixel) == 0))
            {
                bitmapPixel++;
            }
            else
            {
                unpremultiplyTable = macroAlphaUnpremultiplyTableForImagePixel(bitmapPixel);

                macroImagePixelComponent_Red(bitmapPixel) =
                            unpremultiplyTable[macroImagePixelComponent_Red(bitmapPixel)];

                macroImagePixelComponent_Green(bitmapPixel) =
                            unpremultiplyTable[macroImagePixelComponent_Green(bitmapPixel)];

                macroImagePixelComponent_Blue(bitmapPixel) =
                            unpremultiplyTable[macroImagePixelComponent_Blue(bitmapPixel)];

                bitmapPixel++;
            }
        }

        bitmapRow += bytesPerRow;
    }

    _format |= NSAlphaNonpremultipliedBitmapFormat;

    return YES;

ERROR:
    return NO;
}

- (NSBitmapImageRep *) ppGSGlue_UnpremultipliedBitmap
{
    NSSize bitmapSize;
    NSBitmapImageRep *destinationBitmap;
    unsigned char *destinationRow, *sourceRow, *unpremultiplyTable;
    int destinationBytesPerRow, sourceBytesPerRow, pixelsPerRow, rowCounter, pixelCounter;
    PPImageBitmapPixel *destinationPixel, *sourcePixel;

    if (([self bitmapFormat] & NSAlphaNonpremultipliedBitmapFormat)
        || ![self ppIsImageBitmap])
    {
        return self;
    }

    bitmapSize = [self ppSizeInPixels];

    destinationBitmap =
                [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes: NULL
                                            pixelsWide: bitmapSize.width
                                            pixelsHigh: bitmapSize.height
                                            bitsPerSample: 8
                                            samplesPerPixel: sizeof(PPImageBitmapPixel)
                                            hasAlpha: YES
                                            isPlanar: NO
                                            colorSpaceName: NSCalibratedRGBColorSpace
                                            bitmapFormat: NSAlphaNonpremultipliedBitmapFormat
                                            bytesPerRow: 0
                                            bitsPerPixel: 0]
                                    autorelease];

    if (!destinationBitmap)
        goto ERROR;

    destinationRow = [destinationBitmap bitmapData];
    sourceRow = [self bitmapData];

    if (!destinationRow || !sourceRow)
    {
        goto ERROR;
    }

    destinationBytesPerRow = [destinationBitmap bytesPerRow];
    sourceBytesPerRow = [self bytesPerRow];

    pixelsPerRow = bitmapSize.width;

    rowCounter = bitmapSize.height;

    while (rowCounter--)
    {
        destinationPixel = (PPImageBitmapPixel *) destinationRow;
        sourcePixel = (PPImageBitmapPixel *) sourceRow;

        pixelCounter = pixelsPerRow;

        while (pixelCounter--)
        {
            if ((macroImagePixelComponent_Alpha(sourcePixel) == 255)
                || (macroImagePixelComponent_Alpha(sourcePixel) == 0))
            {
                *destinationPixel++ = *sourcePixel++;
            }
            else
            {
                unpremultiplyTable = macroAlphaUnpremultiplyTableForImagePixel(sourcePixel);

                macroImagePixelComponent_Red(destinationPixel) =
                            unpremultiplyTable[macroImagePixelComponent_Red(sourcePixel)];

                macroImagePixelComponent_Green(destinationPixel) =
                            unpremultiplyTable[macroImagePixelComponent_Green(sourcePixel)];

                macroImagePixelComponent_Blue(destinationPixel) =
                            unpremultiplyTable[macroImagePixelComponent_Blue(sourcePixel)];

                macroImagePixelComponent_Alpha(destinationPixel) =
                            macroImagePixelComponent_Alpha(sourcePixel);

                destinationPixel++;
                sourcePixel++;
            }
        }

        destinationRow += destinationBytesPerRow;
        sourceRow += sourceBytesPerRow;
    }

    return destinationBitmap;

ERROR:
    return self;
}

@end

@implementation NSImage (PPGNUstepGlue_BitmapNonpremultipliedPNGUtilities)

- (void) ppGSGlue_PremultiplyBitmapRepresentations
{
    NSEnumerator *repEnumerator;
    NSBitmapImageRep *bitmapRep;

    repEnumerator = [[self representations] objectEnumerator];

    while (bitmapRep = [repEnumerator nextObject])
    {
        if ([bitmapRep isKindOfClass: [NSBitmapImageRep class]]
                && ([bitmapRep bitmapFormat] & NSAlphaNonpremultipliedBitmapFormat))
        {
            [bitmapRep ppGSGlue_Premultiply];
        }
    }
}

@end

#endif  // GNUSTEP

