/*
    PPGNUstepGlue_ViewDisplayCaching.m

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

// Workaround for GNUStep issue where -[NSView cacheDisplayInRect:toBitmapImageRep:] doesn't
// capture content from any of the view's subviews, only the view itself.

#ifdef GNUSTEP

#import <Cocoa/Cocoa.h>
#import "NSObject_PPUtilities.h"
#import "PPAppBootUtilities.h"
#import "NSBitmapImageRep_PPUtilities.h"


@interface NSView (PPGNUstepGlue_ViewDisplayCachingUtilities)

- (NSImage *) ppGSGlue_ContentImage;

@end

@implementation NSObject (PPGNUstepGlue_ViewDisplayCaching)

+ (void) ppGSGlue_ViewDisplayCaching_InstallPatches
{
    macroSwizzleInstanceMethod(NSView, cacheDisplayInRect:toBitmapImageRep:,
                                ppGSPatch_CacheDisplayInRect:toBitmapImageRep:);
}

+ (void) load
{
    macroPerformNSObjectSelectorAfterAppLoads(ppGSGlue_ViewDisplayCaching_InstallPatches);
}

@end

@implementation NSView (PPGNUstepGlue_ViewDisplayCaching)

// PATCH: -[NSView cacheDisplayInRect:toBitmapImageRep:]
// GNUstep's implmentation only reads the top-level view's pixels, ignoring subviews -
// override adds support for subviews (only first level, though) in order to work properly with
// PPCompositeThumbnail

- (void) ppGSPatch_CacheDisplayInRect: (NSRect) rect
            toBitmapImageRep: (NSBitmapImageRep *) bitmapImageRep
{
    NSImage *contentImage;
    NSEnumerator *subviewsEnumerator;
    NSView *subview;

    [bitmapImageRep ppSetAsCurrentGraphicsContext];

    contentImage = [self ppGSGlue_ContentImage];

    [contentImage drawInRect: [self bounds]
                    fromRect: [self bounds]
                    operation: NSCompositeCopy
                    fraction: 1.0];

    subviewsEnumerator = [[self subviews] objectEnumerator];

    while (subview = [subviewsEnumerator nextObject])
    {
        contentImage = [subview ppGSGlue_ContentImage];

        [contentImage drawInRect: [subview frame]
                        fromRect: [subview bounds]
                        operation: NSCompositeSourceOver
                        fraction: 1.0];
    }

    [bitmapImageRep ppRestoreGraphicsContext];
}

// ppGSGlue_ContentImage returns an NSImage of a single view's drawn content (no content from
// subviews)

- (NSImage *) ppGSGlue_ContentImage
{
    NSRect contentBounds;
    NSImage *contentImage;

    contentBounds = [self bounds];
    contentImage = [[[NSImage alloc] initWithSize: contentBounds.size] autorelease];

    [contentImage lockFocus];

    [self drawRect: contentBounds];

    [contentImage unlockFocus];

    return contentImage;
}

@end

#endif  // GNUSTEP

