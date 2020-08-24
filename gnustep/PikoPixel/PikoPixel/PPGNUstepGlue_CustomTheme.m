/*
    PPGNUstepGlue_CustomTheme.m

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

//  Customizations to the built-in GNUstep theme (disabled if GNUstep is using a different
// theme, or if PPDisableGSThemeCustomizations == "YES" in the user defaults):
// - Use NSWindows95InterfaceStyle (in-window menubars), except on Window Maker window manager
// - Adjust UI colors
// - Tweak menu dimensions (menu bar height, menu font size, separator height)
// - Horizontal menubars: center-align item titles, increase spacing between items
// - Remove the border frames around individual menu items
// - Draw table headers using the table's background color
// - Draw rounded-style & regular-square-style buttons as NeXT-style square buttons
// - Disable focus ring around controls

#ifdef GNUSTEP

#import <Cocoa/Cocoa.h>
#import "NSObject_PPUtilities.h"
#import "PPAppBootUtilities.h"
#import "PPGNUstepGlueUtilities.h"
#import "GNUstepGUI/GSTheme.h"
#import "PPGeometry.h"
#import "NSBitmapImageRep_PPUtilities.h"
#import "NSImage_PPUtilities.h"
#import "NSColor_PPUtilities.h"
#import "PPUIColors_Panels.h"
#import "PPGNUstepUserDefaults.h"


#define kCustomThemeName                                    @"PikoStep"

#define kCustomThemeDefaultsDictName                        @"PPGNUstepDefaults_CustomTheme"

#define kPPGSUserDefaultsKey_DisableGSThemeCustomizations   @"PPDisableGSThemeCustomizations"

#define kPPGSUserDefaultsKey_BoldMenuTextColorWhiteValue    @"PPBoldMenuTextColorWhiteValue"

#define kVerticalMenubarItem_DefaultEdgePadding             4   // GNUstep default
#define kHorizontalMenubarItem_CustomEdgePadding            9   // Custom theme padding


static bool ShouldInstallThemeCustomizations(void);
static void RecolorHorizontalSliderKnobImage(void);
static void RecolorSwitchImages(void);
static void RecolorReturnKeyButtonImage(void);


static NSMenuItemCell *gAppMenuTitleItem = nil;
static float gAppMenuTitleVerticalOffset = 0;
static bool gIsDrawingTableView = NO, gIsDrawingCustomSliderFrame = NO;


@interface NSUserDefaults (PPGNUstepGlue_CustomThemeUtilities)

- (void) ppGSGlue_CustomTheme_SetupDefaults;

@end

@interface NSImage (PPGNUstepGlue_CustomThemeUtilities)

+ (bool) ppGSGlue_RecolorSystemImageNamed: (NSString *) imageName
            imageSize: (NSSize) imageSize
            bitmapSize: (NSSize) bitmapSize
            backgroundFillPoint: (NSPoint) backgroundFillPoint
            shadowFillPoint: (NSPoint) shadowFillPoint
            darkShadowFillPoint: (NSPoint) darkShadowFillPoint
            colorMatchTolerance: (unsigned) colorMatchTolerance
            matchAnywhere: (bool) matchAnywhere;

@end

@implementation NSObject (PPGNUstepGlue_CustomTheme)

+ (void) ppGSGlue_CustomTheme_InstallPatches
{
    macroSwizzleInstanceMethod(GSTheme,
                                drawBorderAndBackgroundForMenuItemCell:withFrame:
                                    inView:state:isHorizontal:,
                                ppGSPatch_DrawBorderAndBackgroundForMenuItemCell:withFrame:
                                    inView:state:isHorizontal:);

    macroSwizzleInstanceMethod(GSTheme, drawTableHeaderCell:withFrame:inView:state:,
                                ppGSPatch_DrawTableHeaderCell:withFrame:inView:state:);

    macroSwizzleInstanceMethod(GSTheme, drawTableViewRect:inView:,
                                ppGSPatch_DrawTableViewRect:inView:);

    macroSwizzleInstanceMethod(GSTheme, drawButton:in:view:style:state:,
                                ppGSPatch_DrawButton:in:view:style:state:);

    macroSwizzleInstanceMethod(GSTheme,
                                drawSegmentedControlSegment:withFrame:inView:style:
                                    state:roundedLeft:roundedRight:,
                                ppGSPatch_DrawSegmentedControlSegment:withFrame:inView:style:
                                    state:roundedLeft:roundedRight:);

    macroSwizzleInstanceMethod(GSTheme,
                                drawSliderBorderAndBackground:frame:inCell:
                                    isHorizontal:,
                                ppGSPatch_DrawSliderBorderAndBackground:frame:inCell:
                                    isHorizontal:);

    macroSwizzleInstanceMethod(GSTheme, drawBarInside:inCell:flipped:,
                                ppGSPatch_DrawBarInside:inCell:flipped:);

    macroSwizzleInstanceMethod(GSTheme, drawFocusFrame:view:, ppGSPatch_DrawFocusFrame:view:);

    macroSwizzleInstanceMethod(GSTheme, scrollViewUseBottomCorner,
                                ppGSPatch_ScrollViewUseBottomCorner);

    macroSwizzleInstanceMethod(GSTheme, menuBackgroundColor, ppGSPatch_MenuBackgroundColor);

    macroSwizzleInstanceMethod(GSTheme, menuSeparatorColor, ppGSPatch_MenuSeparatorColor);

    macroSwizzleInstanceMethod(GSTheme, menuBorderColorForEdge:isHorizontal:,
                                ppGSPatch_MenuBorderColorForEdge:isHorizontal:);

    macroSwizzleInstanceMethod(GSTheme, tableHeaderTextColorForState:,
                                ppGSPatch_TableHeaderTextColorForState:);

    macroSwizzleInstanceMethod(GSTheme, name, ppGSPatch_Name);


    macroSwizzleClassMethod(NSColor, scrollBarColor, ppGSPatch_ScrollBarColor);

    macroSwizzleClassMethod(NSColor, selectedMenuItemColor, ppGSPatch_SelectedMenuItemColor);


    macroSwizzleInstanceMethod(NSMenuView, setHorizontal:, ppGSPatch_SetHorizontal:);


    macroSwizzleInstanceMethod(NSPopUpButtonCell, drawTitleWithFrame:inView:,
                                ppGSPatch_DrawTitleWithFrame:inView:);


    macroSwizzleInstanceMethod(NSMenuItemCell, drawTitleWithFrame:inView:,
                                ppGSPatch_DrawTitleWithFrame:inView:);

    macroSwizzleInstanceMethod(NSMenuItemCell, drawKeyEquivalentWithFrame:inView:,
                                ppGSPatch_DrawKeyEquivalentWithFrame:inView:);

    macroSwizzleInstanceMethod(NSMenuItemCell, textColor, ppGSPatch_TextColor);


    macroSwizzleInstanceMethod(NSTextFieldCell, titleRectForBounds:,
                                ppGSPatch_TitleRectForBounds:);


    macroSwizzleInstanceMethod(NSSliderCell, drawWithFrame:inView:,
                                ppGSPatch_DrawWithFrame:inView:);


    macroSwizzleInstanceMethod(NSScrollView, tile, ppGSPatch_CustomTheme_Tile);
}

+ (void) ppGSGlue_CustomTheme_Install
{
    if (!ShouldInstallThemeCustomizations())
    {
        return;
    }

    [self ppGSGlue_CustomTheme_InstallPatches];

    RecolorHorizontalSliderKnobImage();
    RecolorSwitchImages();
    RecolorReturnKeyButtonImage();
}

+ (void) load
{
    PPGSGlueUtils_PerformNSUserDefaultsSelectorBeforeGSBackendLoads(
                                                @selector(ppGSGlue_CustomTheme_SetupDefaults));

    macroPerformNSObjectSelectorAfterAppLoads(ppGSGlue_CustomTheme_Install);
}

@end

@implementation GSTheme (PPGNUStepGlue_CustomTheme)

// PATCH: -[GSTheme drawBorderAndBackgroundForMenuItemCell:withFrame:inView:state:isHorizontal:]
// Overrides the default theme to draw all menu items with no borders (reduces visual clutter)

- (void) ppGSPatch_DrawBorderAndBackgroundForMenuItemCell: (NSMenuItemCell *) cell
            withFrame: (NSRect) cellFrame
            inView: (NSView *) controlView
            state: (GSThemeControlState) state
            isHorizontal: (BOOL) isHorizontal
{
    [[cell backgroundColor] set];
    NSRectFill([cell drawingRectForBounds: cellFrame]);
}

// PATCH: -[GSTheme drawTableHeaderCell:withFrame:inView:state:]
//

#define kTableHeaderSeparatorVerticalMargin 2
#define kTableHeaderUnderlineOffset         1

- (void) ppGSPatch_DrawTableHeaderCell: (NSTableHeaderCell *) cell
            withFrame: (NSRect) cellFrame
            inView: (NSView *) controlView
            state: (GSThemeControlState) state
{
    NSColor *tableBackgroundColor = nil;
    NSPoint separatorPoint1, separatorPoint2, underlinePoint1, underlinePoint2;
    bool shouldDrawVerticalSeparator;

    if ([controlView isKindOfClass: [NSTableHeaderView class]])
    {
        tableBackgroundColor = [[((NSTableHeaderView *) controlView) tableView] backgroundColor];
    }

    if (!tableBackgroundColor)
    {
        tableBackgroundColor = [NSColor windowBackgroundColor];
    }

    [tableBackgroundColor set];

    NSRectFill(cellFrame);

    [[NSColor windowBackgroundColor] set];

    shouldDrawVerticalSeparator = (NSMaxX(cellFrame) < NSMaxX([controlView bounds])) ? YES : NO;

    if ([controlView isFlipped])
    {
        if (shouldDrawVerticalSeparator)
        {
            separatorPoint1 = PPGeometry_PixelCenteredPoint(
                                NSMakePoint(NSMaxX(cellFrame) - 1,
                                            NSMinY(cellFrame)
                                                + kTableHeaderSeparatorVerticalMargin));

            separatorPoint2 = PPGeometry_PixelCenteredPoint(
                                NSMakePoint(NSMaxX(cellFrame) - 1,
                                            NSMaxY(cellFrame) - 1
                                                - kTableHeaderSeparatorVerticalMargin
                                                - kTableHeaderUnderlineOffset));
        }

        underlinePoint1 = PPGeometry_PixelCenteredPoint(
                            NSMakePoint(NSMinX(cellFrame),
                                        NSMaxY(cellFrame) - 1
                                            - kTableHeaderUnderlineOffset));

        underlinePoint2 = PPGeometry_PixelCenteredPoint(
                            NSMakePoint(NSMaxX(cellFrame),
                                        NSMaxY(cellFrame) - 1
                                            - kTableHeaderUnderlineOffset));
    }
    else
    {
        if (shouldDrawVerticalSeparator)
        {
            separatorPoint1 = PPGeometry_PixelCenteredPoint(
                                NSMakePoint(NSMaxX(cellFrame) - 1,
                                            NSMinY(cellFrame)
                                                + kTableHeaderSeparatorVerticalMargin
                                                + kTableHeaderUnderlineOffset));

            separatorPoint2 = PPGeometry_PixelCenteredPoint(
                                NSMakePoint(NSMaxX(cellFrame) - 1,
                                            NSMaxY(cellFrame) - 1
                                                - kTableHeaderSeparatorVerticalMargin));
        }

        underlinePoint1 = PPGeometry_PixelCenteredPoint(
                            NSMakePoint(NSMinX(cellFrame),
                                        NSMinY(cellFrame) + kTableHeaderUnderlineOffset));

        underlinePoint2 = PPGeometry_PixelCenteredPoint(
                            NSMakePoint(NSMaxX(cellFrame),
                                        NSMinY(cellFrame) + kTableHeaderUnderlineOffset));
    }

    if (shouldDrawVerticalSeparator)
    {
        [NSBezierPath strokeLineFromPoint: separatorPoint1 toPoint: separatorPoint2];
    }

    [NSBezierPath strokeLineFromPoint: underlinePoint1 toPoint: underlinePoint2];
}

- (void) ppGSPatch_DrawTableViewRect: (NSRect) aRect
            inView: (NSView *) view
{
    gIsDrawingTableView = YES;

    [self ppGSPatch_DrawTableViewRect: aRect inView: view];

    gIsDrawingTableView = NO;
}

// PATCH: -[GSTheme drawButton:in:view:style:state:]
// Overrides the default theme's button drawing for rounded, regular-square, & circular
// buttons to instead draw them as NeXT-style square buttons. (OS X has been drawing rounded
// buttons as squares for the last several versions, and GNUstep's default theme currently
// draws regular-square-style buttons with just a simple frame outline & no highlights or
// shadows, so they look flat & different from other buttons).

- (void) ppGSPatch_DrawButton: (NSRect)frame
            in: (NSCell*)cell
            view: (NSView*)view
            style: (int)style
            state: (GSThemeControlState)state
{
    switch (style)
    {
        case NSRoundedBezelStyle:
        {
            style = NSNeXTBezelStyle;

            // tweak frame: RoundedBezel -> NeXT
            frame = NSInsetRect(frame, 3, 3);
        }
        break;

        case NSRegularSquareBezelStyle:
        {
            style = NSNeXTBezelStyle;

            // tweak frame: RegularSquare -> NeXT
            frame = NSInsetRect(frame, 2, 4);
            frame.size.height += 2;

            if (![view isFlipped])
            {
                frame.origin.y -= 2;
            }
        }
        break;

        case NSCircularBezelStyle:
        {
            style = NSNeXTBezelStyle;

            // tweak frame: Circular -> NeXT
            frame = NSInsetRect(frame, 6, 6);
        }
        break;

        default:
        break;
    }

    [self ppGSPatch_DrawButton: frame in: cell view: view style: style state: state];
}

- (void) ppGSPatch_DrawSegmentedControlSegment: (NSCell *) cell
            withFrame: (NSRect) cellFrame
            inView: (NSView *) controlView
            style: (NSSegmentStyle) style
            state: (GSThemeControlState) state
            roundedLeft: (BOOL) roundedLeft
            roundedRight: (BOOL) roundedRight
{
    cellFrame = NSInsetRect(cellFrame, -2, -2);
    cellFrame.origin.y += ([controlView isFlipped]) ? -1 : 1;

    [self ppGSPatch_DrawSegmentedControlSegment: cell
            withFrame: cellFrame
            inView: controlView
            style: style
            state: state
            roundedLeft: roundedLeft
            roundedRight: roundedRight];
}

- (void) ppGSPatch_DrawSliderBorderAndBackground: (NSBorderType) aType
            frame: (NSRect) cellFrame
            inCell: (NSCell *) cell
            isHorizontal: (BOOL) horizontal
{
    if (gIsDrawingCustomSliderFrame)
        return;

    [self ppGSPatch_DrawSliderBorderAndBackground: aType
            frame: cellFrame
            inCell: cell
            isHorizontal: horizontal];
}

- (void) ppGSPatch_DrawBarInside: (NSRect) rect inCell: (NSCell *) cell flipped: (BOOL) flipped
{
    float leftX, rightX, bottomY, topY, verticalPixelOffset;
    NSPoint bottomLeftPoint, topLeftPoint, bottomRightPoint, topRightPoint;

    if (!gIsDrawingCustomSliderFrame)
    {
        [self ppGSPatch_DrawBarInside: rect inCell: cell flipped: flipped];

        return;
    }

    rect = PPGeometry_PixelCenteredRect(rect);

    leftX = NSMinX(rect);
    rightX = NSMaxX(rect);

    if (flipped)
    {
        bottomY = NSMaxY(rect);
        topY = NSMinY(rect);
        verticalPixelOffset = -1;
    }
    else
    {
        bottomY = NSMinY(rect);
        topY = NSMaxY(rect);
        verticalPixelOffset = 1;
    }

    // scrollbar fill

    [[NSColor scrollBarColor] set];
    NSRectFill(NSInsetRect(rect,1,1));

    // outside edge highlight & shadow

    bottomLeftPoint = NSMakePoint(leftX, bottomY);
    bottomRightPoint = NSMakePoint(rightX, bottomY);
    topLeftPoint = NSMakePoint(leftX, topY);
    topRightPoint = NSMakePoint(rightX, topY);

    [[NSColor whiteColor] set];
    [NSBezierPath strokeLineFromPoint: bottomLeftPoint toPoint: bottomRightPoint];
    [NSBezierPath strokeLineFromPoint: bottomRightPoint toPoint: topRightPoint];

    [[NSColor controlShadowColor] set];
    [NSBezierPath strokeLineFromPoint: bottomLeftPoint toPoint: topLeftPoint];
    [NSBezierPath strokeLineFromPoint: topLeftPoint toPoint: topRightPoint];

    // inside edge highlight & shadow

    bottomLeftPoint = NSMakePoint(leftX + 1, bottomY + verticalPixelOffset);
    bottomRightPoint = NSMakePoint(rightX - 1, bottomY + verticalPixelOffset);
    topLeftPoint = NSMakePoint(leftX + 1, topY - verticalPixelOffset);
    topRightPoint = NSMakePoint(rightX - 1, topY - verticalPixelOffset);

    [NSBezierPath strokeLineFromPoint: bottomLeftPoint toPoint: bottomRightPoint];
    [NSBezierPath strokeLineFromPoint: bottomRightPoint toPoint: topRightPoint];

    [[NSColor controlDarkShadowColor] set];
    [NSBezierPath strokeLineFromPoint: bottomLeftPoint toPoint: topLeftPoint];
    [NSBezierPath strokeLineFromPoint: topLeftPoint toPoint: topRightPoint];
}

- (void) ppGSPatch_DrawFocusFrame: (NSRect) frame view: (NSView *) view
{
    // disable all focus rings
}

- (BOOL) ppGSPatch_ScrollViewUseBottomCorner
{
    return NO;
}

- (NSColor *) ppGSPatch_MenuBackgroundColor
{
    return [NSColor controlBackgroundColor];
}

- (NSColor *) ppGSPatch_MenuSeparatorColor
{
    return [NSColor disabledControlTextColor];
}

- (NSColor *) ppGSPatch_MenuBorderColorForEdge: (NSRectEdge) edge
                isHorizontal: (BOOL) horizontal
{
    if (horizontal
        && ((edge == NSMinXEdge) || (edge == NSMaxXEdge)))
    {
        return [NSColor controlBackgroundColor];
    }

    return [self ppGSPatch_MenuBorderColorForEdge: edge isHorizontal: horizontal];
}

- (NSColor *) ppGSPatch_TableHeaderTextColorForState: (GSThemeControlState) state
{
    return [NSColor controlDarkShadowColor];
}

- (NSString *) ppGSPatch_Name
{
    return kCustomThemeName;
}

@end

@implementation NSColor (PPGNUstepGlue_CustomTheme)

+ (NSColor *) ppGSPatch_ScrollBarColor
{
    static NSColor *scrollBarPatternColor = nil;

    if (!scrollBarPatternColor)
    {
        scrollBarPatternColor = [[NSColor ppCheckerboardPatternColorWithBoxDimension: 1
                                        color1: [NSColor windowBackgroundColor]
                                        color2: [self ppGSPatch_ScrollBarColor]]
                                    retain];
    }

    return (scrollBarPatternColor) ? scrollBarPatternColor : [self ppGSPatch_ScrollBarColor];
}

+ (NSColor *) ppGSPatch_SelectedMenuItemColor
{
    static NSColor *patternColor = nil;

    if (!patternColor)
    {
        patternColor =
            [[NSColor ppCenteredVerticalGradientPatternColorWithHeight:
                                        [[NSUserDefaults standardUserDefaults] integerForKey: @"NSMenuFontSize"]
                        innerColor: kUIColor_ToolsPanel_ActiveToolCellGradientInnerColor
                        outerColor: kUIColor_ToolsPanel_ActiveToolCellGradientOuterColor]
                retain];
    }

    return (patternColor) ? patternColor : [self ppGSPatch_SelectedMenuItemColor];
}

@end

@implementation NSMenuView (PPGNUstepGlue_CustomTheme)

// PATCH: -[NSMenuView setHorizontal:]
//   Horizontal menus' item titles are left-aligned instead of center-aligned, and are also too
// close together.
//   Patch manually sets up menu items' text alignment & the menuview's horizontal edge padding
// before calling through to original implementation.

- (void) ppGSPatch_SetHorizontal: (BOOL) menuIsHorizontal
{
    NSTextAlignment itemCellTextAlignment;
    float horizontalEdgePadding;
    int numMenuItems, itemIndex;

    [gAppMenuTitleItem release];
    gAppMenuTitleItem = nil;

    if (menuIsHorizontal)
    {
        itemCellTextAlignment = NSCenterTextAlignment;
        horizontalEdgePadding = kHorizontalMenubarItem_CustomEdgePadding;
    }
    else
    {
        itemCellTextAlignment = NSLeftTextAlignment;
        horizontalEdgePadding = kVerticalMenubarItem_DefaultEdgePadding;
    }

    // item cells' text alignment

    numMenuItems = [[self menu] numberOfItems];

    if (menuIsHorizontal && (numMenuItems > 0))
    {
        NSFont *menuFont, *boldMenuFont;

        menuFont = [NSFont menuFontOfSize: 0];
        boldMenuFont = [NSFont boldSystemFontOfSize: [menuFont pointSize]];

        if (menuFont && boldMenuFont)
        {
            [gAppMenuTitleItem release];
            gAppMenuTitleItem = [[self menuItemCellForItemAtIndex: 0] retain];

            [gAppMenuTitleItem setFont: boldMenuFont];

            gAppMenuTitleVerticalOffset = [boldMenuFont descender] - [menuFont descender];
        }
    }

    for (itemIndex=0; itemIndex<numMenuItems; itemIndex++)
    {
        [[self menuItemCellForItemAtIndex: itemIndex] setAlignment: itemCellTextAlignment];
    }

    // horizontal edge padding

    [self setHorizontalEdgePadding: horizontalEdgePadding];


    [self ppGSPatch_SetHorizontal: menuIsHorizontal];
}

@end

@implementation NSPopUpButtonCell (PPGNUstepGlue_CustomTheme)

- (void) ppGSPatch_DrawTitleWithFrame: (NSRect) cellFrame
            inView: (NSView *) controlView
{
    if ([self controlSize] == NSRegularControlSize)
    {
        cellFrame.origin.y += ([controlView isFlipped]) ? -1 : 1;
    }

    [self ppGSPatch_DrawTitleWithFrame: cellFrame inView: controlView];
}

@end

@implementation NSMenuItemCell (PPGNUstepGlue_CustomTheme)

- (void) ppGSPatch_DrawTitleWithFrame: (NSRect) cellFrame
            inView: (NSView *) controlView
{
    bool controlViewIsFlipped = [controlView isFlipped];

    cellFrame.origin.y += (controlViewIsFlipped) ? -1 : 1;

    if ((self == gAppMenuTitleItem) && (gAppMenuTitleVerticalOffset != 0))
    {
        cellFrame.origin.y +=
            (controlViewIsFlipped) ? -gAppMenuTitleVerticalOffset : gAppMenuTitleVerticalOffset;
    }

    [self ppGSPatch_DrawTitleWithFrame: cellFrame inView: controlView];
}

- (void) ppGSPatch_DrawKeyEquivalentWithFrame: (NSRect) cellFrame
            inView: (NSView *) controlView
{
    cellFrame.origin.y += ([controlView isFlipped]) ? -1 : 1;

    [self ppGSPatch_DrawKeyEquivalentWithFrame: cellFrame inView: controlView];
}

- (NSColor *) ppGSPatch_TextColor
{
    static NSColor *appMenuTitleItemTextColor = nil;

    if ((self == gAppMenuTitleItem) && ![self isHighlighted])
    {
        if (!appMenuTitleItemTextColor)
        {
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            float whiteValue = [defaults floatForKey:
                                            kPPGSUserDefaultsKey_BoldMenuTextColorWhiteValue];
            appMenuTitleItemTextColor =
                            [[NSColor colorWithCalibratedWhite: whiteValue alpha: 1.0] retain];

            if (!appMenuTitleItemTextColor)
            {
                return [self ppGSPatch_TextColor];
            }
        }

        return appMenuTitleItemTextColor;
    }

    return [self ppGSPatch_TextColor];
}

@end

@implementation NSTextFieldCell (PPGNUstepGlue_CustomTheme)

- (NSRect) ppGSPatch_TitleRectForBounds: (NSRect) rect
{
    rect = [self ppGSPatch_TitleRectForBounds: rect];

    if (gIsDrawingTableView)
    {
        rect.origin.y += ([[self controlView] isFlipped]) ? 1 : -1;
    }

    return rect;
}

@end

@implementation NSSliderCell (PPGNUstepGlue_CustomTheme)

#define kSliderCellKnobImageName            @"common_SliderHoriz"
#define kSliderCellKnobImageDefaultHeight   14

- (void) ppGSPatch_DrawWithFrame: (NSRect) cellFrame inView: (NSView *) controlView
{
    static float customSliderFrameHeight = 0;

    if (!customSliderFrameHeight)
    {
        NSImage *knobImage = [NSImage imageNamed: kSliderCellKnobImageName];
        float knobImageHeight =
                (knobImage) ? [knobImage size].height : kSliderCellKnobImageDefaultHeight;

        customSliderFrameHeight = knobImageHeight + 4; // +4 accounts for 2-pixel frame border
    }

    // only draw custom slider frames on horizontal, non-bezeled slider cells;
    // need to manually compare the cellFrame's width & height to determine if it's horizontal,
    // since -[NSSliderCell isVertical] may return an incorrect value if the slider hasn't
    // been displayed yet
    gIsDrawingCustomSliderFrame =
        ((cellFrame.size.width > cellFrame.size.height) && ![self isBezeled]) ? YES : NO;

    if (gIsDrawingCustomSliderFrame)
    {
        cellFrame.origin.y += roundf((cellFrame.size.height - customSliderFrameHeight) / 2.0f);
        cellFrame.size.height = customSliderFrameHeight;
    }

    [self ppGSPatch_DrawWithFrame: cellFrame inView: controlView];

    gIsDrawingCustomSliderFrame = NO;
}

@end

@implementation NSScrollView (PPGNUstepGlue_CustomTheme)

#define kMarginBetweenContentViewAndScroller    2

- (void) ppGSPatch_CustomTheme_Tile
{
    NSView *contentView, *scrollerView;
    NSRect contentViewFrame, scrollerViewFrame;

    [self ppGSPatch_CustomTheme_Tile];

    contentView = [self contentView];
    contentViewFrame = [contentView frame];

    if ([self hasHorizontalScroller])
    {
        scrollerView = [self horizontalScroller];
        scrollerViewFrame = [scrollerView frame];

        if ([self isFlipped])
        {
            contentViewFrame.size.height =
                NSMinY(scrollerViewFrame) - NSMinY(contentViewFrame) + 1
                    - kMarginBetweenContentViewAndScroller;
        }
        else
        {
            CGFloat maxY = NSMaxY(contentViewFrame);

            contentViewFrame.origin.y =
                NSMaxY(scrollerViewFrame) + kMarginBetweenContentViewAndScroller;

            contentViewFrame.size.height = maxY - contentViewFrame.origin.y;
        }

        if (contentViewFrame.size.height < 0)
        {
            contentViewFrame.size.height = 0;
        }
    }

    if ([self hasVerticalScroller])
    {
        scrollerView = [self verticalScroller];
        scrollerViewFrame = [scrollerView frame];

        if (scrollerViewFrame.origin.x > contentViewFrame.origin.x)
        {
            // right-side vertical scroller
            contentViewFrame.size.width =
                NSMinX(scrollerViewFrame) - NSMinX(contentViewFrame) + 1
                    - kMarginBetweenContentViewAndScroller;
        }
        else
        {
            // left-side vertical scroller
            contentViewFrame.size.width =
                NSMaxX(contentViewFrame) - NSMaxX(scrollerViewFrame) + 1
                    - kMarginBetweenContentViewAndScroller;

            contentViewFrame.origin.x =
                NSMaxX(scrollerViewFrame) + kMarginBetweenContentViewAndScroller - 1;
        }

        if (contentViewFrame.size.width < 0)
        {
            contentViewFrame.size.width = 0;
        }
    }

    [contentView setFrame: contentViewFrame];
}

@end

@implementation NSUserDefaults (PPGNUstepGlue_CustomThemeUtilities)

- (void) ppGSGlue_CustomTheme_SetupDefaults
{
    if (!ShouldInstallThemeCustomizations())
    {
        return;
    }

    // Register custom UI colors & menu dimensions from resource dict

    [NSUserDefaults
            ppGSGlueUtils_RegisterDefaultsFromDictionaryNamed: kCustomThemeDefaultsDictName];

    // Register NSWindows95InterfaceStyle as the default style, unless the window manager is
    // Window Maker

    if (!PPGSGlueUtils_WindowManagerMatchesTypeMask(kPPGSWindowManagerTypeMask_WindowMaker))
    {
        NSDictionary *defaultsDict =
            [NSDictionary
                    dictionaryWithObject: kGSUserDefaultsValue_InterfaceStyleName_Windows95
                    forKey: kGSUserDefaultsKey_InterfaceStyleName];

        if (defaultsDict)
        {
            [self registerDefaults: defaultsDict];
        }
    }
}

@end

@implementation NSImage (PPGNUstepGlue_CustomThemeUtilities)

+ (bool) ppGSGlue_RecolorSystemImageNamed: (NSString *) imageName
            imageSize: (NSSize) imageSize
            bitmapSize: (NSSize) bitmapSize
            backgroundFillPoint: (NSPoint) backgroundFillPoint
            shadowFillPoint: (NSPoint) shadowFillPoint
            darkShadowFillPoint: (NSPoint) darkShadowFillPoint
            colorMatchTolerance: (unsigned) colorMatchTolerance
            matchAnywhere: (bool) matchAnywhere
{
    NSImage *oldImage, *newImage;
    NSBitmapImageRep *imageBitmap, *maskBitmap;
    NSRect bitmapFrame;

    if (!imageName)
        goto ERROR;

    oldImage = [self imageNamed: imageName];

    if (!oldImage || !NSEqualSizes([oldImage size], imageSize))
    {
        goto ERROR;
    }

    imageBitmap = [[oldImage bestRepresentationForDevice: nil] ppImageBitmap];

    if (!imageBitmap || !NSEqualSizes([imageBitmap ppSizeInPixels], bitmapSize))
    {
        goto ERROR;
    }

    maskBitmap = [NSBitmapImageRep ppMaskBitmapOfSize: bitmapSize];

    if (!maskBitmap)
        goto ERROR;

    bitmapFrame = PPGeometry_OriginRectOfSize(bitmapSize);

    // control background color

    if (!NSEqualPoints(backgroundFillPoint, NSZeroPoint))
    {
        if (matchAnywhere)
        {
            [maskBitmap ppMaskAllPixelsMatchingColorAtPoint: backgroundFillPoint
                        inImageBitmap: imageBitmap
                        colorMatchTolerance: colorMatchTolerance
                        selectionMask: nil
                        selectionMaskBounds: NSZeroRect];
        }
        else
        {
            [maskBitmap ppMaskNeighboringPixelsMatchingColorAtPoint: backgroundFillPoint
                        inImageBitmap: imageBitmap
                        colorMatchTolerance: colorMatchTolerance
                        selectionMask: nil
                        selectionMaskBounds: NSZeroRect
                        matchDiagonally: NO];
        }

        [imageBitmap ppMaskedFillUsingMask: maskBitmap
                        inBounds: bitmapFrame
                        fillPixelValue:
                                [[NSColor controlBackgroundColor] ppImageBitmapPixelValue]];
    }

    // control shadow color

    if (!NSEqualPoints(shadowFillPoint, NSZeroPoint))
    {
        if (matchAnywhere)
        {
            [maskBitmap ppMaskAllPixelsMatchingColorAtPoint: shadowFillPoint
                        inImageBitmap: imageBitmap
                        colorMatchTolerance: colorMatchTolerance
                        selectionMask: nil
                        selectionMaskBounds: NSZeroRect];
        }
        else
        {
            [maskBitmap ppMaskNeighboringPixelsMatchingColorAtPoint: shadowFillPoint
                        inImageBitmap: imageBitmap
                        colorMatchTolerance: colorMatchTolerance
                        selectionMask: nil
                        selectionMaskBounds: NSZeroRect
                        matchDiagonally: NO];
        }

        [imageBitmap ppMaskedFillUsingMask: maskBitmap
                        inBounds: bitmapFrame
                        fillPixelValue: [[NSColor controlShadowColor] ppImageBitmapPixelValue]];
    }

    // control dark shadow color

    if (!NSEqualPoints(darkShadowFillPoint, NSZeroPoint))
    {
        if (matchAnywhere)
        {
            [maskBitmap ppMaskAllPixelsMatchingColorAtPoint: darkShadowFillPoint
                        inImageBitmap: imageBitmap
                        colorMatchTolerance: colorMatchTolerance
                        selectionMask: nil
                        selectionMaskBounds: NSZeroRect];
        }
        else
        {
            [maskBitmap ppMaskNeighboringPixelsMatchingColorAtPoint: darkShadowFillPoint
                        inImageBitmap: imageBitmap
                        colorMatchTolerance: colorMatchTolerance
                        selectionMask: nil
                        selectionMaskBounds: NSZeroRect
                        matchDiagonally: NO];
        }

        [imageBitmap ppMaskedFillUsingMask: maskBitmap
                        inBounds: bitmapFrame
                        fillPixelValue:
                                [[NSColor controlDarkShadowColor] ppImageBitmapPixelValue]];
    }

    newImage = [NSImage ppImageWithBitmap: imageBitmap];

    if (!newImage)
        goto ERROR;

    if (!NSEqualSizes(imageSize, bitmapSize))
    {
        [newImage setSize: imageSize];
    }

    [oldImage setName: nil];
    [newImage setName: imageName];

    return YES;

ERROR:
    return NO;
}

@end

#define kStandardGSThemeName                @"GNUstep"
#define kStandardGSThemeNameWithExtension   @"GNUstep.theme"

static bool ShouldInstallThemeCustomizations(void)
{
    NSUserDefaults *userDefaults;
    NSString *currentGSThemeName;
    bool currentGSThemeIsStandardTheme, disallowThemeCustomizations;

    userDefaults = [NSUserDefaults standardUserDefaults];

    currentGSThemeName = [userDefaults stringForKey: kGSUserDefaultsKey_ThemeName];

    currentGSThemeIsStandardTheme =
        (!currentGSThemeName
            || [currentGSThemeName isEqualToString: kStandardGSThemeName]
            || [currentGSThemeName isEqualToString: kStandardGSThemeNameWithExtension])
            ? YES : NO;

    disallowThemeCustomizations =
        ([userDefaults boolForKey: kPPGSUserDefaultsKey_DisableGSThemeCustomizations])
            ? YES : NO;

    return (currentGSThemeIsStandardTheme && !disallowThemeCustomizations) ? YES : NO;
}

#define kSliderKnobImageName                                @"common_SliderHoriz"
#define kSliderKnobImageSize                                NSMakeSize(19,14)
#define kSliderKnobBitmapSize                               NSMakeSize(19,14)
#define kSliderKnobBitmapColorFillPoint_ControlBackground   NSMakePoint(3,3)
#define kSliderKnobBitmapColorFillPoint_ControlShadow       NSMakePoint(3,1)
#define kSliderKnobBitmapColorFillPoint_ControlDarkShadow   NSMakePoint(1,0)
#define kSliderKnobBitmapColorMatchTolerance                0
#define kSliderKnobBitmapColorMatchAnywhere                 YES

static void RecolorHorizontalSliderKnobImage(void)
{
    [NSImage ppGSGlue_RecolorSystemImageNamed: kSliderKnobImageName
                imageSize: kSliderKnobImageSize
                bitmapSize: kSliderKnobBitmapSize
                backgroundFillPoint: kSliderKnobBitmapColorFillPoint_ControlBackground
                shadowFillPoint: kSliderKnobBitmapColorFillPoint_ControlShadow
                darkShadowFillPoint: kSliderKnobBitmapColorFillPoint_ControlDarkShadow
                colorMatchTolerance: kSliderKnobBitmapColorMatchTolerance
                matchAnywhere: kSliderKnobBitmapColorMatchAnywhere];
}

#define kSwitchImageName                                @"GSSwitch"
#define kHighlightedSwitchImageName                     @"GSSwitchSelected"
#define kSwitchImageSize                                NSMakeSize(15,15)
#define kSwitchBitmapSize                               NSMakeSize(60,60)
#define kSwitchBitmapColorFillPoint_ControlBackground   NSMakePoint(6,10)
#define kSwitchBitmapColorFillPoint_ControlShadow       NSMakePoint(6,5)
#define kSwitchBitmapColorFillPoint_ControlDarkShadow   NSMakePoint(1,0)
#define kSwitchBitmapColorMatchTolerance                45
#define kSwitchBitmapColorMatchAnywhere                 YES

static void RecolorSwitchImages(void)
{
    [NSImage ppGSGlue_RecolorSystemImageNamed: kSwitchImageName
                imageSize: kSwitchImageSize
                bitmapSize: kSwitchBitmapSize
                backgroundFillPoint: kSwitchBitmapColorFillPoint_ControlBackground
                shadowFillPoint: kSwitchBitmapColorFillPoint_ControlShadow
                darkShadowFillPoint: kSwitchBitmapColorFillPoint_ControlDarkShadow
                colorMatchTolerance: kSwitchBitmapColorMatchTolerance
                matchAnywhere: kSwitchBitmapColorMatchAnywhere];

    [NSImage ppGSGlue_RecolorSystemImageNamed: kHighlightedSwitchImageName
                imageSize: kSwitchImageSize
                bitmapSize: kSwitchBitmapSize
                backgroundFillPoint: kSwitchBitmapColorFillPoint_ControlBackground
                shadowFillPoint: kSwitchBitmapColorFillPoint_ControlShadow
                darkShadowFillPoint: NSZeroPoint
                colorMatchTolerance: kSwitchBitmapColorMatchTolerance
                matchAnywhere: YES];

    [NSImage ppGSGlue_RecolorSystemImageNamed: kHighlightedSwitchImageName
                imageSize: kSwitchImageSize
                bitmapSize: kSwitchBitmapSize
                backgroundFillPoint: NSZeroPoint
                shadowFillPoint: NSZeroPoint
                darkShadowFillPoint: kSwitchBitmapColorFillPoint_ControlDarkShadow
                colorMatchTolerance: 0
                matchAnywhere: NO];
}

#define kReturnKeyImageName                                 @"common_ret"
#define kReturnKeyImageSize                                 NSMakeSize(15,10)
#define kReturnKeyBitmapSize                                NSMakeSize(15,10)
#define kReturnKeyBitmapColorFillPoint_ControlBackground    NSZeroPoint
#define kReturnKeyBitmapColorFillPoint_ControlShadow        NSMakePoint(4,4)
#define kReturnKeyBitmapColorFillPoint_ControlDarkShadow    NSZeroPoint
#define kReturnKeyBitmapColorMatchTolerance                 0
#define kReturnKeyBitmapColorMatchAnywhere                  NO

static void RecolorReturnKeyButtonImage(void)
{
    [NSImage ppGSGlue_RecolorSystemImageNamed: kReturnKeyImageName
                imageSize: kReturnKeyImageSize
                bitmapSize: kReturnKeyBitmapSize
                backgroundFillPoint: kReturnKeyBitmapColorFillPoint_ControlBackground
                shadowFillPoint: kReturnKeyBitmapColorFillPoint_ControlShadow
                darkShadowFillPoint: kReturnKeyBitmapColorFillPoint_ControlDarkShadow
                colorMatchTolerance: kReturnKeyBitmapColorMatchTolerance
                matchAnywhere: kReturnKeyBitmapColorMatchAnywhere];
}

#endif  // GNUSTEP

