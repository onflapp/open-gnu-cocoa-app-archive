/*
    PPGNUstepGlue_PatternedLines.m

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

// GNUstep currently doesn't support drawing 1-pixel-wide bezier paths using pattern colors,
// so methods that draw patterned lines are overridden by patches that manually create the line
// patterns using NSBezierPath lineDash settings instead (requires 2 draws, less efficient)

#ifdef GNUSTEP

#import <Cocoa/Cocoa.h>
#import "NSObject_PPUtilities.h"
#import "PPAppBootUtilities.h"
#import "PPCanvasView.h"
#import "NSColor_PPUtilities.h"


// Selection outline colors
#define kUIColor_SelectionOutline_DarkDashes                \
                    [NSColor blackColor]

#define kUIColor_SelectionOutline_LightDashes               \
                    [NSColor whiteColor]

// Eraser tool outline colors
#define kUIColor_EraserToolOutline_DarkDots                 \
                    [NSColor ppSRGBColorWithWhite: 0 alpha: 0.64]

#define kUIColor_EraserToolOutline_LightDots                \
                    [NSColor ppSRGBColorWithWhite: 0.77 alpha: 0.64]

// Color Ramp tool overlay defines
#define kColorRampToolOverlay_MinZoomFactorToDrawXMarks     8

#define kColorRampToolOverlay_LineWidth_XMarkLine           (0.0)
#define kColorRampToolOverlay_LineWidth_XMarkHalo           (2.0)

#define kUIColor_ColorRampToolOverlay_XMarkLine             \
                    [NSColor ppSRGBColorWithWhite: 0.6 alpha: 0.7]

#define kUIColor_ColorRampToolOverlay_XMarkHalo             \
                    [NSColor ppSRGBColorWithWhite: 0.85 alpha: 0.7]

#define kUIColor_ColorRampToolOverlay_DarkDashes            \
                    [NSColor ppSRGBColorWithWhite: 0.10 alpha: 1.0]

#define kUIColor_ColorRampToolOverlay_LightDashes           \
                    [NSColor ppSRGBColorWithWhite: 0.95 alpha: 1.0]


@implementation NSObject (PPGNUstepGlue_PatternedLines)

+ (void) ppGSGlue_PatternedLines_InstallPatches
{
    macroSwizzleInstanceMethod(PPCanvasView, drawSelectionOutline,
                                ppGSPatch_DrawSelectionOutline);

    macroSwizzleInstanceMethod(PPCanvasView, drawEraserToolOverlay,
                                ppGSPatch_DrawEraserToolOverlay);

    macroSwizzleInstanceMethod(PPCanvasView, drawColorRampToolOverlay,
                                ppGSPatch_DrawColorRampToolOverlay);
}

+ (void) load
{
    macroPerformNSObjectSelectorAfterAppLoads(ppGSGlue_PatternedLines_InstallPatches);
}

@end

@implementation PPCanvasView (PPGNUstepGlue_PatternedLines)

- (void) ppGSPatch_DrawSelectionOutline
{
    static NSColor *darkDashColor, *lightDashColor;
    static CGFloat dashValues[] = {3,3};
    static int numDashValues = sizeof(dashValues)/sizeof(*dashValues);
    int dashPhase;

    if (!_hasSelectionOutline || _shouldHideSelectionOutline)
    {
        return;
    }

    if (!darkDashColor)
    {
        darkDashColor = [kUIColor_SelectionOutline_DarkDashes retain];
    }

    if (!lightDashColor)
    {
        lightDashColor = [kUIColor_SelectionOutline_LightDashes retain];
    }

    // the current implementation of the selection outline path allows the path to extend
    // one pixel beyond the right & bottom edges of the visible canvas; as a workaround,
    // set the clipping path to prevent drawing outside the canvas

    [NSGraphicsContext saveGraphicsState];
    [NSBezierPath clipRect: _offsetZoomedVisibleCanvasBounds];

    // dark dashes: draw as a solid line - will be overdrawn by light-dashes line

    [darkDashColor set];

    [_zoomedSelectionOutlineTopRightPath setLineDash: NULL count: 0 phase: 0];
    [_zoomedSelectionOutlineTopRightPath stroke];

    [_zoomedSelectionOutlineBottomLeftPath setLineDash: NULL count: 0 phase: 0];
    [_zoomedSelectionOutlineBottomLeftPath stroke];

    // light dashes

    [lightDashColor set];

    // selection outline pattern image is 8x8
    dashPhase = 8 - _selectionOutlineTopRightAnimationPhase.x;

    [_zoomedSelectionOutlineTopRightPath setLineDash: dashValues
                                            count: numDashValues
                                            phase: dashPhase];

    [_zoomedSelectionOutlineTopRightPath stroke];

    [_zoomedSelectionOutlineBottomLeftPath setLineDash: dashValues
                                            count: numDashValues
                                            phase: dashPhase];

    [_zoomedSelectionOutlineBottomLeftPath stroke];

    [NSGraphicsContext restoreGraphicsState];
}

- (void) ppGSPatch_DrawEraserToolOverlay
{
    static NSColor *darkDotColor = nil, *lightDotColor = nil;
    static CGFloat dashValues[] = {1,2};
    static int numDashValues = sizeof(dashValues)/sizeof(*dashValues);
    int dashPhase;

    if (!_shouldDisplayEraserToolOverlay)
        return;

    if (!darkDotColor)
    {
        darkDotColor = [kUIColor_EraserToolOutline_DarkDots retain];
    }

    if (!lightDotColor)
    {
        lightDotColor = [kUIColor_EraserToolOutline_LightDots retain];
    }

    // dark dots

    [darkDotColor set];

    dashPhase = 0;

    [_eraserToolOverlayPath_Outline setLineDash: dashValues
                                    count: numDashValues
                                    phase: dashPhase];

    [_eraserToolOverlayPath_Outline stroke];

    // light dots

    [lightDotColor set];

    dashPhase = 1;

    [_eraserToolOverlayPath_Outline setLineDash: dashValues
                                    count: numDashValues
                                    phase: dashPhase];

    [_eraserToolOverlayPath_Outline stroke];
}

- (void) ppGSPatch_DrawColorRampToolOverlay
{
    static NSColor *xMarkHaloColor = nil, *xMarkLineColor = nil, *darkDashColor = nil,
                    *lightDashColor = nil;
    static CGFloat dashValues[] = {1,1};
    static int numDashValues = sizeof(dashValues)/sizeof(*dashValues);

    if (!_shouldDisplayColorRampToolOverlay)
        return;

    if (!xMarkHaloColor)
    {
        xMarkHaloColor = [kUIColor_ColorRampToolOverlay_XMarkHalo retain];
    }

    if (!xMarkLineColor)
    {
        xMarkLineColor = [kUIColor_ColorRampToolOverlay_XMarkLine retain];
    }

    if (!darkDashColor)
    {
        darkDashColor = [kUIColor_ColorRampToolOverlay_DarkDashes retain];
    }

    if (!lightDashColor)
    {
        lightDashColor = [kUIColor_ColorRampToolOverlay_LightDashes retain];
    }

    if (![_colorRampToolOverlayPath_XMarks isEmpty]
        && (_zoomFactor >= kColorRampToolOverlay_MinZoomFactorToDrawXMarks))
    {
        [xMarkHaloColor set];
        [_colorRampToolOverlayPath_XMarks setLineWidth:
                                                    kColorRampToolOverlay_LineWidth_XMarkHalo];
        [_colorRampToolOverlayPath_XMarks stroke];

        [xMarkLineColor set];
        [_colorRampToolOverlayPath_XMarks setLineWidth:
                                                    kColorRampToolOverlay_LineWidth_XMarkLine];
        [_colorRampToolOverlayPath_XMarks stroke];
    }

    [darkDashColor set];
    [_colorRampToolOverlayPath_Outline setLineDash: NULL count: 0 phase: 0];
    [_colorRampToolOverlayPath_Outline stroke];

    [lightDashColor set];
    [_colorRampToolOverlayPath_Outline setLineDash: dashValues count: numDashValues phase: 0];
    [_colorRampToolOverlayPath_Outline stroke];
}

@end

#endif  // GNUSTEP

