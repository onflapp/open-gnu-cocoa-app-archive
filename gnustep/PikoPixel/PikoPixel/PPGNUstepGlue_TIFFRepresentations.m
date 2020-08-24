/*
    PPGNUstepGlue_TIFFRepresentations.m

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

// Workarounds for two GNUstep issues with creating TIFF representations (NSData):
// - Calling -[NSImage TIFFRepresentation] on (some) valid images causes a TIFF library error
// - TIFF data written by GNUstep GUI 0.25.0 is incorrect (apparently fixed in GUI 0.25.1)

#ifdef GNUSTEP

#import <Cocoa/Cocoa.h>
#import "NSObject_PPUtilities.h"
#import "PPAppBootUtilities.h"
#import "NSBitmapImageRep_PPUtilities.h"


@implementation NSObject (PPGNUstepGlue_TIFFRepresentations)

+ (void) ppGSGlue_TIFFRepresentations_InstallPatches
{
    macroSwizzleClassMethod(NSBitmapImageRep, TIFFRepresentationOfImageRepsInArray:,
                                ppGSPatch_TIFFRepresentationOfImageRepsInArray:);

    macroSwizzleInstanceMethod(NSBitmapImageRep, ppCompressedTIFFData,
                                ppGSPatch_CompressedTIFFData);
}

+ (void) load
{
    macroPerformNSObjectSelectorAfterAppLoads(ppGSGlue_TIFFRepresentations_InstallPatches);
}

@end

@implementation NSBitmapImageRep (PPGNUstepGlue_TIFFRepresentations)

// PATCH: +[NSBitmapImageRep TIFFRepresentationOfImageRepsInArray:]
//  Calling -[NSImage TIFFRepresentation] on some valid images causes a TIFF library error from
// within +[NSBitmapImageRep TIFFRepresentationOfImageRepsInArray:]. Workaround is to patch
// +[NSBitmapImageRep TIFFRepresentationOfImageRepsInArray:], and if the imageReps array just
// contains a single bitmap (which should be the case for all NSImages in PikoPixel), call
// -[NSBitmapImageRep TIFFRepresentation] instead (which seems to work correctly).

+ (NSData *) ppGSPatch_TIFFRepresentationOfImageRepsInArray: (NSArray *) anArray
{
    if ([anArray count] == 1)
    {
        NSBitmapImageRep *bitmapRep = [anArray objectAtIndex: 0];

        if ([bitmapRep isKindOfClass: [NSBitmapImageRep class]])
        {
            NSData *tiffData = [bitmapRep TIFFRepresentation];

            if (tiffData)
            {
                return tiffData;
            }
        }
    }

    return [self ppGSPatch_TIFFRepresentationOfImageRepsInArray: anArray];
}

// PATCH: -[NSBitmapImageRep (PPUtilities) ppCompressedTIFFData]
// GNUstep GUI 0.25.0 has issues reading back TIFF data that it wrote (OS X can't read the TIFF
// data either), so patched to write PNG-format data instead. (This issue appears to have been
// fixed in GUI 0.25.1).

- (NSData *) ppGSPatch_CompressedTIFFData
{
    return [self ppCompressedPNGData];
}

@end

#endif  // GNUSTEP

