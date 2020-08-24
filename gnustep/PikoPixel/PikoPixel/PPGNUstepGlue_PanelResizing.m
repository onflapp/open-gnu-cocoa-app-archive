/*
    PPGNUstepGlue_PanelResizing.m

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
#import "PPPanelController.h"
#import "PPPreviewView.h"
#import "PPLayersPanelController.h"
#import "PPResizeControl.h"


#define kMaxPanelSizeInitializer            {5000,5000}


@interface PPPanelController (PPGNUstepGlue_PanelResizingUtilities)

- (void) setupPanelWithResizeControl;

@end


@implementation NSObject (PPGNUstepGlue_PanelResizing)

+ (void) ppGSGlue_PanelResizing_InstallPatches
{
    macroSwizzleInstanceMethod(PPPanelController, windowDidLoad,
                                ppGSPatch_PanelResizing_WindowDidLoad);


    macroSwizzleInstanceMethod(PPPreviewView, handleResizingEnd, ppGSPatch_HandleResizingEnd);


    macroSwizzleInstanceMethod(PPLayersPanelController, windowDidLoad,
                                ppGSPatch_LayersPanelResizing_WindowDidLoad);

    macroSwizzleInstanceMethod(PPLayersPanelController, windowWillResize:toSize:,
                                ppGSPatch_WindowWillResize:toSize:);
}

+ (void) load
{
    macroPerformNSObjectSelectorAfterAppLoads(ppGSGlue_PanelResizing_InstallPatches);
}

@end

@implementation PPPanelController (PPGNUstepGlue_PanelResizing)

- (void) ppGSPatch_PanelResizing_WindowDidLoad
{
    [self ppGSPatch_PanelResizing_WindowDidLoad];

    if ([[self window] styleMask] & NSResizableWindowMask)
    {
        [self setupPanelWithResizeControl];
    }
}

@end

@implementation PPPreviewView (PPGNUstepGlue_PanelResizing)

- (void) ppGSPatch_HandleResizingEnd
{
    [self setFrameSize: [self frame].size]; // forces _scaledImageBounds to reposition
    [self setNeedsDisplay: YES];

    [self ppGSPatch_HandleResizingEnd];
}

@end

@implementation PPLayersPanelController (PPGNUstepGlue_PanelResizing)

static NSSize gLayersPanelMinSize = {0,0}, gLayersPanelMaxSize = kMaxPanelSizeInitializer;

- (void) ppGSPatch_LayersPanelResizing_WindowDidLoad
{
    NSWindow *layersPanel = [self window];

    gLayersPanelMinSize = [layersPanel minSize];
    gLayersPanelMaxSize = [layersPanel maxSize];

    [self ppGSPatch_LayersPanelResizing_WindowDidLoad];
}

- (NSSize) windowWillResize: (NSWindow *) sender toSize: (NSSize) frameSize
{
    // This NSWindow delegate stub method is defined here because it's not implemented by
    // PPLayersPanelController or its ancestors; Undefined methods can't be swizzled, so the
    // alternative would be to move the contents of ppGSPatch_WindowWillResize: here, which
    // would make this "patch" hard to find if one were only looking at the swizzling calls in
    // +ppGSGlue_PanelResizing_InstallPatches when searching for overridden functionality.

    return frameSize;
}

- (NSSize) ppGSPatch_WindowWillResize: (NSWindow *) sender toSize: (NSSize) frameSize
{
    if (frameSize.width < gLayersPanelMinSize.width)
    {
        frameSize.width = gLayersPanelMinSize.width;
    }
    else if (frameSize.width > gLayersPanelMaxSize.width)
    {
        frameSize.width = gLayersPanelMaxSize.width;
    }

    if (frameSize.height < gLayersPanelMinSize.height)
    {
        frameSize.height = gLayersPanelMinSize.height;
    }
    else if (frameSize.height > gLayersPanelMaxSize.height)
    {
        frameSize.height = gLayersPanelMaxSize.height;
    }

    return frameSize;
}

@end

@implementation PPPanelController (PPGNUstepGlue_PanelResizingUtilities)

- (void) setupPanelWithResizeControl
{
    NSWindow *panel;
    NSSize panelSize, panelContentSize;
    NSImage *resizeControlImage;
    NSRect resizeControlFrame;
    PPResizeControl *resizeControl;

    panel = [self window];
    panelSize = [panel frame].size;
    panelContentSize = [[panel contentView] bounds].size;

    resizeControlImage = [NSImage imageNamed: @"resize_control.png"];
    resizeControlFrame.size = [resizeControlImage size];

    resizeControlFrame.origin =
                    NSMakePoint(panelContentSize.width - resizeControlFrame.size.width, 0);

    resizeControl = [[[PPResizeControl alloc] initWithFrame: resizeControlFrame] autorelease];

    [resizeControl setImage: resizeControlImage];
    [resizeControl setEnabled: YES];
    [resizeControl setDelegate: self];
    [resizeControl setAutoresizingMask: NSViewMinXMargin | NSViewMaxYMargin];

    [[panel contentView] addSubview: resizeControl];

    [panel setMinSize: panelSize];
    [panel setMaxSize: panelSize];
}

#pragma mark PPResizeControl delegate methods

- (void) ppResizeControlDidBeginResizing: (PPResizeControl *) resizeControl
{
    static NSSize maxPanelSize = kMaxPanelSizeInitializer;
    NSWindow *panel = [self window];

    [panel setMinSize: NSZeroSize];
    [panel setMaxSize: maxPanelSize];
}

- (void) ppResizeControlDidFinishResizing: (PPResizeControl *) resizeControl
{
    NSWindow *panel = [self window];
    NSSize panelSize = [panel frame].size;

    [panel setMinSize: panelSize];
    [panel setMaxSize: panelSize];
}

@end

#endif  // GNUSTEP

