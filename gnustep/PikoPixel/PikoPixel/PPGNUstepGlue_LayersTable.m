/*
    PPGNUstepGlue_LayersTable.m

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
#import "PPLayersPanelController.h"
#import "PPLayersTableView.h"
#import "PPLayerOpacitySliderCell.h"


#define kLayersTableColumnIndex_Name            2
#define kLayersTableColumnIndex_Opacity         3

#define kLayersTableColumnIdentifier_Opacity    @"Opacity"


static NSTableColumn *gLayersTableColumn_Opacity = nil;


@interface PPLayersPanelController (PPGNUstepGlue_LayersTableUtilities)

- (void) ppGSGlue_SetupTableHeaderView;

- (void) ppGSGlue_SetupOpacitySliderTableColumnGlobals;

- (void) ppGSGlue_AdjustTableWidthIfNeeded;

@end


@implementation NSObject (PPGNUstepGlue_LayersTable)

+ (void) ppGSGlue_LayersTable_InstallPatches
{
    // Setup (Table header, Sliders globals)

    macroSwizzleInstanceMethod(PPLayersPanelController, windowDidLoad,
                                ppGSPatch_LayersTable_WindowDidLoad);

    // Resizing

    macroSwizzleInstanceMethod(PPLayersTableView, superviewFrameChanged:,
                                ppGSPatch_SuperviewFrameChanged:);

    // Text editing

    macroSwizzleInstanceMethod(PPLayersTableView, editColumn:row:withEvent:select:,
                                ppGSPatch_EditColumn:row:withEvent:select:);

    macroSwizzleInstanceMethod(PPLayersTableView, textDidEndEditing:,
                                ppGSPatch_TextDidEndEditing:);


    macroSwizzleInstanceMethod(PPLayersPanelController, windowDidResignKey:,
                                ppGSPatch_WindowDidResignKey:);

    // Sliders

    macroSwizzleInstanceMethod(PPLayersPanelController, layersTableOpacitySliderMoved:,
                                ppGSPatch_LayersTableOpacitySliderMoved:);

    macroSwizzleInstanceMethod(PPLayersTableView, mouseDown:, ppGSPatch_MouseDown:);
}

+ (void) load
{
    macroPerformNSObjectSelectorAfterAppLoads(ppGSGlue_LayersTable_InstallPatches);
}

@end

@implementation PPLayersPanelController (PPGNUstepGlue_LayersTable_Setup)

- (void) ppGSPatch_LayersTable_WindowDidLoad
{
    [self ppGSPatch_LayersTable_WindowDidLoad];

    [self ppGSGlue_SetupTableHeaderView];

    [self ppGSGlue_SetupOpacitySliderTableColumnGlobals];

    [self ppGSGlue_AdjustTableWidthIfNeeded];
}

@end

@implementation PPLayersTableView (PPGNUstepGlue_LayersTable_Resizing)

- (void) ppGSPatch_SuperviewFrameChanged: (NSNotification*) aNotification
{
    [self ppGSPatch_SuperviewFrameChanged: aNotification];

    [self sizeToFit];
}

@end

@implementation PPLayersTableView (PPGNUstepGlue_LayersTable_TextEditing)

- (void) ppGSPatch_EditColumn: (NSInteger) columnIndex
            row: (NSInteger) rowIndex
            withEvent: (NSEvent *) theEvent
            select: (BOOL) flag
{
    [self ppGSPatch_EditColumn: columnIndex row: rowIndex withEvent: theEvent select: flag];

    if (columnIndex == kLayersTableColumnIndex_Name)
    {
        // On some platforms (ARM), double-clicking the layer name to start editing doesn't
        // automatically make the window key, so do it manually:
        [[self window] makeKeyWindow];
    }
}

- (void) ppGSPatch_TextDidEndEditing: (NSNotification *) aNotification
{
    // copy notification without userInfo to prevent text movement actions (return, tab)
    aNotification = [NSNotification notificationWithName: [aNotification name]
                                    object: [aNotification object]];

    [self ppGSPatch_TextDidEndEditing: aNotification];
}

@end

@implementation PPLayersPanelController (PPGNUstepGlue_LayersTable_TextEditing)

- (void) windowDidResignKey: (NSNotification *) notification
{
    // This NSWindow delegate method is defined here because it's not implemented by
    // PPLayersPanelController or its ancestors; Undefined methods can't be swizzled, so the
    // alternative would be to move the contents of ppGSPatch_WindowDidResignKey: here, which
    // would make this "patch" hard to find if one were only looking at the swizzling calls in
    // +ppGSGlue_LayersTable_InstallPatches when searching for overridden functionality.
}

- (void) ppGSPatch_WindowDidResignKey: (NSNotification *) notification
{
    NSWindow *layersPanel = [self window];
    NSText *layersTableFieldEditor = [layersPanel fieldEditor: NO forObject: _layersTable];

    if (layersTableFieldEditor && (layersTableFieldEditor == [layersPanel firstResponder]))
    {
        // layers table doesn't automatically end editing when the panel resigns key, so do it
        // manually:
        [layersPanel endEditingFor: _layersTable];
    }
}

@end

@implementation PPLayersPanelController (PPGNUstepGlue_LayersTable_Sliders)

- (void) ppGSPatch_LayersTableOpacitySliderMoved: (id) sender
{
    NSRect sliderCellFrame;

    [self ppGSPatch_LayersTableOpacitySliderMoved: sender];

    // force slider to redraw immediately while it's being dragged
    sliderCellFrame = [_layersTable frameOfCellAtColumn: kLayersTableColumnIndex_Opacity
                                    row: [_layersTable clickedRow]];

    [_layersTable setNeedsDisplayInRect: sliderCellFrame];

    [_layersTable displayIfNeeded];
}

@end

@implementation PPLayersTableView (PPGNUstepGlue_LayersTable_Sliders)

- (void) ppGSPatch_MouseDown: (NSEvent *) theEvent
{
    NSPoint clickPoint;
    NSInteger clickedColumn;

    clickPoint = [self convertPoint: [theEvent locationInWindow] fromView: nil];
    clickedColumn = [self columnAtPoint: clickPoint];

    if (clickedColumn == kLayersTableColumnIndex_Opacity)
    {
        NSInteger clickedRow;
        PPLayerOpacitySliderCell *opacitySliderCell;
        NSRect cellFrame;
        id <NSTableViewDataSource> tableDataSource;
        id initialOpacityValue, finalOpacityValue;
        PPLayersPanelController *layersPanelController;

        clickedRow = [self rowAtPoint: clickPoint];

        opacitySliderCell =
            (PPLayerOpacitySliderCell *) [self preparedCellAtColumn: clickedColumn
                                                row: clickedRow];

        cellFrame = [self frameOfCellAtColumn: clickedColumn row: clickedRow];

        tableDataSource = [self dataSource];

        initialOpacityValue =
            [tableDataSource tableView: self
                                objectValueForTableColumn: gLayersTableColumn_Opacity
                                row: clickedRow];

         [_selectedRowsAtMouseDown release];
        _selectedRowsAtMouseDown = [[self selectedRowIndexes] retain];

        _clickedColumn = clickedColumn;
        _clickedRow = clickedRow;

        layersPanelController = (PPLayersPanelController *) [opacitySliderCell target];

        [layersPanelController setTrackingOpacitySliderCell: opacitySliderCell];

        [opacitySliderCell trackMouse: theEvent
                            inRect: cellFrame
                            ofView: self
                            untilMouseUp: YES];

        [layersPanelController setTrackingOpacitySliderCell: nil];

        _clickedColumn = _clickedRow = -1;

        finalOpacityValue =
            [tableDataSource tableView: self
                                objectValueForTableColumn: gLayersTableColumn_Opacity
                                row: clickedRow];

        if ([initialOpacityValue floatValue] != [finalOpacityValue floatValue])
        {
            // manually update the data source's value so it registers with the document's undo
            // manager (changing the value during slider dragging did not register undo)

            [tableDataSource tableView: self
                                setObjectValue: finalOpacityValue
                                forTableColumn: gLayersTableColumn_Opacity
                                row: clickedRow];
        }

        [self setNeedsDisplayInRect: cellFrame];
    }
    else
    {
        [self ppGSPatch_MouseDown: theEvent];
    }
}

@end

@implementation PPLayersPanelController (PPGNUstepGlue_LayersTableUtilities)

- (void) ppGSGlue_SetupTableHeaderView
{
    NSTableHeaderView *headerView;
    NSRect headerViewFrame;
    NSView *contentView;

    headerView = [_layersTable headerView];

    if ([headerView superview])
    {
        return;
    }

    headerViewFrame = [headerView frame];

    contentView = [[self window] contentView];

    headerViewFrame.origin = [_canvasDisplayModeButton frame].origin;
    headerViewFrame.origin.y -= headerViewFrame.size.height;
    [headerView setFrame: headerViewFrame];

    [contentView addSubview: headerView];
    [headerView setAutoresizingMask: NSViewMinYMargin];
}

- (void) ppGSGlue_SetupOpacitySliderTableColumnGlobals
{
    gLayersTableColumn_Opacity =
                [_layersTable tableColumnWithIdentifier: kLayersTableColumnIdentifier_Opacity];
}

- (void) ppGSGlue_AdjustTableWidthIfNeeded
{
    const float maxAllowedWidthDifference = 0.01;
    NSView *tableEnclosingScrollView = [_layersTable enclosingScrollView];
    CGFloat tableWidth = [_layersTable frame].size.width,
            tableVisibleWidth = [_layersTable convertRect: [tableEnclosingScrollView bounds]
                                                fromView: tableEnclosingScrollView].size.width;
    float widthDifference = (float) (tableVisibleWidth - tableWidth);

    if (fabsf(widthDifference) > maxAllowedWidthDifference)
    {
        [_layersTable sizeToFit];
    }
}

@end

#endif  // GNUSTEP

