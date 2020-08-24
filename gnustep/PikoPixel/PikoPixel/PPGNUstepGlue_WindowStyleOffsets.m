/*
    PPGNUstepGlue_WindowStyleOffsets.m

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

// - Workarounds for window style offsets issues on Compiz WM (cropped window content),
// KWin, Marco, Openbox, Window Maker, & Xfwm WMs (drawing artifacts after maximizing or
// switching resizeable/nonresizable), and Budgie, Gala, Muffin, & Mutter WMs (1. After
// resizing a panel via a PPResizeControl, a transparent gap appears between the panel's
// content & its titlebar, 2. Hiding & reshowing a panel can cause its position to shift
// vertically towards the top of the screen)
//
// - Force GNUstep to ignore any cached style offset values stored in the root window, instead
// check offsets manually (in case the window manager changed since the values were cached)

#ifdef GNUSTEP

#import <Cocoa/Cocoa.h>
#import "NSObject_PPUtilities.h"
#import "PPAppBootUtilities.h"
#import "PPGNUstepGlueUtilities.h"
#import "GNUstepGUI/GSWindowDecorationView.h"
#import "GNUstepGUI/GSDisplayServer.h"
#import "PPToolsPanelController.h"
#import "PPLayersPanelController.h"
#import "PPPreviewPanelController.h"
#import "PPSamplerImagePanelController.h"
#import "PPToolModifierTipsPanelController.h"


// Compiz defines
#define kUserDefaultsKey_FallbackWindowStyleOffsets_Compiz  \
                    @"GSGlue_FallbackWindowStyleOffsets_Compiz"

#define kDefaultStyleOffsetValue_Compiz_Top                 28
#define kDefaultStyleOffsetValue_Compiz_SidesAndBottom      0

#define kMinValidStyleOffsetValue_Compiz_Top                21


typedef unsigned long int PPXWindow; // local definition of libX11's Window type


static NSString *gUserDefaultsKey_FallbackWindowStyleOffsets =
                                        kUserDefaultsKey_FallbackWindowStyleOffsets_Compiz;

static float gFallbackStyleOffset_Top = kDefaultStyleOffsetValue_Compiz_Top,
                gFallbackStyleOffset_Bottom = kDefaultStyleOffsetValue_Compiz_SidesAndBottom,
                gFallbackStyleOffset_Left = kDefaultStyleOffsetValue_Compiz_SidesAndBottom,
                gFallbackStyleOffset_Right = kDefaultStyleOffsetValue_Compiz_SidesAndBottom;

static PPXWindow gActiveResizingXWindow = 0;
static float gXFrameVerticalOffset = 0;
static bool gShouldCalculateXFrameVerticalOffset = NO;


@interface GSDisplayServer (PPGNUstep_GSDisplayServerPrivate)

- (void *) windowDevice: (int) win;

@end

@interface NSUserDefaults (PPGNUstepGlue_WindowStyleOffsetsUtilities)

- (void) ppGSGlue_IgnoreRootWindowStyleOffsets;

+ (void) ppGSGlue_SetupFallbackStyleOffsetsFromDefaults;

+ (void) ppGSGlue_SaveFallbackStyleOffsetsToDefaults;

@end


@implementation NSObject (PPGNUstepGlue_WindowStyleOffsets)

// Compiz WM

+ (void) ppGSGlue_WindowStyleOffsets_Compiz_InstallPatches
{
    [NSClassFromString(@"XGServer")
        ppSwizzleInstanceMethodWithSelector: @selector(styleoffsets::::::)
        forInstanceMethodWithSelector: @selector(ppGSPatch_Compiz_Styleoffsets::::::)];
}

+ (void) ppGSGlue_WindowStyleOffsets_Compiz_Install
{
    [NSUserDefaults ppGSGlue_SetupFallbackStyleOffsetsFromDefaults];

    [self ppGSGlue_WindowStyleOffsets_Compiz_InstallPatches];
}

// KWin, Marco, Openbox, Window Maker, or Xfwm WMs

+ (void) ppGSGlue_WindowStyleOffsets_KwinMrcoOpbxWmkrXfwm_InstallPatches
{
    macroSwizzleInstanceMethod(NSClassFromString(@"XGServer"), styleoffsets::::::,
                                ppGSPatch_KwinMrcoOpbxWmkrXfwm_Styleoffsets::::::);
}

// Budgie, Gala, Muffin, or Mutter WMs

+ (void) ppGSGlue_WindowStyleOffsets_BgieGalaMufnMutr_InstallPatches
{
    Class XGServerClass = NSClassFromString(@"XGServer");

    macroSwizzleInstanceMethod(XGServerClass, styleoffsets::::::,
                                ppGSPatch_BgieGalaMufnMutr_Styleoffsets::::::);

    macroSwizzleInstanceMethod(XGServerClass, _XFrameToOSFrame:for:,
                                ppGSPatch__XFrameToOSFrame:for:);

    // ppGSPatch_SetFrame: calls a private GNUstep method, -[GSDisplayServer windowDevice:],
    // so check that the private method is supported, in case a future version of GNUstep GUI
    // removes it.
    if ([GSDisplayServer instancesRespondToSelector: @selector(windowDevice:)])
    {
        macroSwizzleInstanceMethod(GSWindowDecorationView, setFrame:, ppGSPatch_SetFrame:);
    }

    macroSwizzleInstanceMethod(PPToolsPanelController, showPanel,
                                ppGSPatch_WindowStyleOffsets_ShowPanel);

    macroSwizzleInstanceMethod(PPLayersPanelController, showPanel,
                                ppGSPatch_WindowStyleOffsets_ShowPanel);

    macroSwizzleInstanceMethod(PPPreviewPanelController, showPanel,
                                ppGSPatch_WindowStyleOffsets_ShowPanel);

    macroSwizzleInstanceMethod(PPSamplerImagePanelController, showPanel,
                                ppGSPatch_WindowStyleOffsets_ShowPanel);

    macroSwizzleInstanceMethod(PPToolModifierTipsPanelController, showPanel,
                                ppGSPatch_WindowStyleOffsets_ShowPanel);
}

// All WMs

+ (void) ppGSGlue_WindowStyleOffsets_Install
{
    if (PPGSGlueUtils_WindowManagerMatchesTypeMask(kPPGSWindowManagerTypeMask_Compiz))
    {
        [self ppGSGlue_WindowStyleOffsets_Compiz_Install];
    }
    else if (PPGSGlueUtils_WindowManagerMatchesTypeMask(kPPGSWindowManagerTypeMask_KWin
                                                    | kPPGSWindowManagerTypeMask_Marco
                                                    | kPPGSWindowManagerTypeMask_Openbox
                                                    | kPPGSWindowManagerTypeMask_WindowMaker
                                                    | kPPGSWindowManagerTypeMask_Xfwm))
    {
        [self ppGSGlue_WindowStyleOffsets_KwinMrcoOpbxWmkrXfwm_InstallPatches];
    }
    else if (PPGSGlueUtils_WindowManagerMatchesTypeMask(kPPGSWindowManagerTypeMask_Budgie
                                                    | kPPGSWindowManagerTypeMask_Gala
                                                    | kPPGSWindowManagerTypeMask_Muffin
                                                    | kPPGSWindowManagerTypeMask_Mutter))
    {
        [self ppGSGlue_WindowStyleOffsets_BgieGalaMufnMutr_InstallPatches];
    }
}

+ (void) load
{
    macroPerformNSObjectSelectorAfterAppLoads(ppGSGlue_WindowStyleOffsets_Install);

    PPGSGlueUtils_PerformNSUserDefaultsSelectorBeforeGSBackendLoads(
                                            @selector(ppGSGlue_IgnoreRootWindowStyleOffsets));
}

// PATCH: -[XGServer styleoffsets::::::] (Compiz)
// When running on Compiz WM, the styleoffsets:::::: method can return garbage values for some
// styles (and which style values return garbage may change each time the app runs); Workaround
// patch checks whether the offsets returned by the original implementation appear invalid
// (t <= 0) - if so, it replaces the returned values with valid fallback values (using the
// first valid values found; saved in user defaults for future runs where the app hasn't yet
// received valid values).

- (void) ppGSPatch_Compiz_Styleoffsets: (float *) l : (float *) r : (float *) t
            : (float *) b : (unsigned int) style : (PPXWindow) win
{
    [self ppGSPatch_Compiz_Styleoffsets: l : r : t : b : style : win];

    if (style & NSTitledWindowMask)
    {
        static bool didSaveValidFallbackOffsetsToDefaults = NO;
        bool styleOffsetsAreInvalid;

        styleOffsetsAreInvalid = (*t < kMinValidStyleOffsetValue_Compiz_Top) ? YES : NO;

        if (styleOffsetsAreInvalid)
        {
            *l = gFallbackStyleOffset_Left;
            *r = gFallbackStyleOffset_Right;
            *t = gFallbackStyleOffset_Top;
            *b = gFallbackStyleOffset_Bottom;
        }
        else if (!didSaveValidFallbackOffsetsToDefaults)
        {
            if ((*l != gFallbackStyleOffset_Left)
                || (*r != gFallbackStyleOffset_Right)
                || (*t != gFallbackStyleOffset_Top)
                || (*b != gFallbackStyleOffset_Bottom))
            {
                gFallbackStyleOffset_Left = *l;
                gFallbackStyleOffset_Right = *r;
                gFallbackStyleOffset_Top = *t;
                gFallbackStyleOffset_Bottom = *b;

                [NSUserDefaults ppGSGlue_SaveFallbackStyleOffsetsToDefaults];
            }

            didSaveValidFallbackOffsetsToDefaults = YES;
        }
    }
}

// PATCH: -[XGServer styleoffsets::::::] (KWin, Marco, Openbox, Window Maker, or Xfwm)
// When running on KWin/Marco/Openbox/WindowMaker/Xfwm window managers, maximizing a titled
// window or switching a titled window between resizable & non-resizable causes drawing
// artifacts due to incorrect style offsets - this is because the affected WMs' window
// decorations are different sizes for different window states, and when the decoration sizes
// change on-the-fly, they no longer line up with GNUstep's drawing/graphics state (which seems
// to use cached offset values);
// Patch sets the win parameter to zero (if the window style is titled) before calling the
// original styleoffsets:::::: implementation - this forces it to return cached offset values
// (which should match the window's initial state & GNUstep's) instead of querying the window
// directly for its current offsets (which may no longer match GNUstep's state).

- (void) ppGSPatch_KwinMrcoOpbxWmkrXfwm_Styleoffsets: (float *) l : (float *) r : (float *) t
            : (float *) b : (unsigned int) style : (PPXWindow) win
{
    if (style & NSTitledWindowMask)
    {
        win = 0;
    }

    [self ppGSPatch_KwinMrcoOpbxWmkrXfwm_Styleoffsets: l : r : t : b : style : win];
}

// PATCH: -[XGServer styleoffsets::::::] (Budgie, Gala, Muffin, or Mutter)
// When running on Budgie/Gala/Muffin/Mutter window managers, resizing a panel by dragging a
// PPResizeControl causes a transparent gap to appear between the titlebar & panel content.
// This is due to GNUstep's -[NSWindow setFrame:display:] method calling through to
// -[XGServer styleoffsets::::::] with the win parameter set to zero - on
// Budgie/Gala/Muffin/Mutter, this returns a different style offset value for t (top) than when
// calling the method with a nonzero win value (valid xwindow pointer);
// Patch sets the win parameter on titled windows to a nonzero value (if a valid xwindow ptr is
// found in the global, gActiveResizingXWindow - the global's value is set up inside the
// -[GSWindowDecorationView ppGSPatch_SetFrame:] patch below).
// Patch also sets up the value of the global, gXFrameVerticalOffset, which is used by the
// -[XGServer _XFrameToOSFrame:for:] patch below to offset the vertical shift of panel windows
// after hiding & reshowing them (the distance shifted happens to be the same as the difference
// in the style offset value for t between calling styleoffsets:... with win containing a zero
// and calling styleoffsets:... with win containing a valid xwindow pointer).

- (void) ppGSPatch_BgieGalaMufnMutr_Styleoffsets: (float *) l : (float *) r : (float *) t
            : (float *) b : (unsigned int) style : (PPXWindow) win
{
    if ((style & NSTitledWindowMask)
        && !win
        && gActiveResizingXWindow)
    {
        win = gActiveResizingXWindow;
    }

    [self ppGSPatch_BgieGalaMufnMutr_Styleoffsets: l : r : t : b : style : win];

    if (gShouldCalculateXFrameVerticalOffset
        && (style & NSTitledWindowMask)
        && win)
    {
        float lt, rt, tp, bm;

        [self ppGSPatch_BgieGalaMufnMutr_Styleoffsets: &lt : &rt : &tp : &bm : style : 0];

        gXFrameVerticalOffset = *t - tp;

        if (gXFrameVerticalOffset)
        {
            gShouldCalculateXFrameVerticalOffset = NO;
        }
    }
}

// PATCH: -[XGServer _XFrameToOSFrame:] (Budgie, Gala, Muffin, or Mutter)
// Workaround for issue where hiding & reshowing panels can cause them to shift vertically;
// Patch adds a vertical offset to the returned XFrame, by the amount contained in the global,
// gXFrameVerticalOffset (set up in ppGSPatch_BgieGalaMufnMutr_Styleoffsets: above).

- (NSRect) ppGSPatch__XFrameToOSFrame: (NSRect) x for: (void*)window
{
    NSRect returnValue = [self ppGSPatch__XFrameToOSFrame: x for: window];

    returnValue.origin.y += gXFrameVerticalOffset;

    return returnValue;
}

@end

@implementation GSWindowDecorationView (PPGNUstepGlue_WindowStyleOffsets)

// PATCH: -[GSWindowDecorationView setFrame:]
// When setting the view's frame under Budgie/Gala/Muffin/Mutter WMs (called when dragging a
// PPResizeControl), temporarily store the XWindow in the global, gActiveResizingXWindow,
// so it can be used in the -[XGServer ppGSPatch_BgieGalaMufnMutr_Styleoffsets:...] patch above.

- (void) ppGSPatch_SetFrame: (NSRect) frame
{
    gActiveResizingXWindow =
                (PPXWindow) [GSCurrentServer() windowDevice: [[self window] windowNumber]];

    [self ppGSPatch_SetFrame: frame];

    gActiveResizingXWindow = 0;
}

@end

@implementation PPPanelController (PPGNUstepGlue_WindowStyleOffsets)

- (void) ppGSPatch_WindowStyleOffsets_ShowPanel
{
    static bool didSetGShouldCalculateXFrameVerticalOffset = NO;

    [self ppGSPatch_WindowStyleOffsets_ShowPanel];

    if (!didSetGShouldCalculateXFrameVerticalOffset)
    {
        gShouldCalculateXFrameVerticalOffset = YES;

        didSetGShouldCalculateXFrameVerticalOffset = YES;
    }
}

@end

@implementation NSUserDefaults (PPGNUstepGlue_WindowStyleOffsets)

- (void) ppGSGlue_IgnoreRootWindowStyleOffsets
{
    NSDictionary *defaultsDict =
                            [NSDictionary dictionaryWithObject: [NSNumber numberWithBool: YES]
                                            forKey: @"GSIgnoreRootOffsets"];

    if (!defaultsDict)
        goto ERROR;

    [self registerDefaults: defaultsDict];

    return;

ERROR:
    return;
}

+ (void) ppGSGlue_SetupFallbackStyleOffsetsFromDefaults
{
    NSUserDefaults *userDefaults;
    NSArray *fallbackOffsets;


// Currently only need fallback style offsets for one WM (Compiz); Leaving commented-out
// functionality in case fallbacks are someday needed on multiple WMs again. (Global values
// are already set up - initially defined with Compiz values).
/*
    if (PPGSGlueUtils_WindowManagerMatchesTypeMask(kPPGSWindowManagerTypeMask_KWin))
    {
        gUserDefaultsKey_FallbackWindowStyleOffsets =
                                            kUserDefaultsKey_FallbackWindowStyleOffsets_KWin;

        gFallbackStyleOffset_Left = kDefaultStyleOffsetValue_KWin_SidesAndBottom;
        gFallbackStyleOffset_Right = kDefaultStyleOffsetValue_KWin_SidesAndBottom;
        gFallbackStyleOffset_Top = kDefaultStyleOffsetValue_KWin_Top;
        gFallbackStyleOffset_Bottom = kDefaultStyleOffsetValue_KWin_SidesAndBottom;
    }
    else    // !KWin WM - use Compiz default values
    {
        gUserDefaultsKey_FallbackWindowStyleOffsets =
                                            kUserDefaultsKey_FallbackWindowStyleOffsets_Compiz;

        gFallbackStyleOffset_Left = kDefaultStyleOffsetValue_Compiz_SidesAndBottom;
        gFallbackStyleOffset_Right = kDefaultStyleOffsetValue_Compiz_SidesAndBottom;
        gFallbackStyleOffset_Top = kDefaultStyleOffsetValue_Compiz_Top;
        gFallbackStyleOffset_Bottom = kDefaultStyleOffsetValue_Compiz_SidesAndBottom;
    }
*/

    userDefaults = [NSUserDefaults standardUserDefaults];

    fallbackOffsets = [NSArray arrayWithObjects:
                                    [NSNumber numberWithFloat: gFallbackStyleOffset_Left],
                                    [NSNumber numberWithFloat: gFallbackStyleOffset_Right],
                                    [NSNumber numberWithFloat: gFallbackStyleOffset_Top],
                                    [NSNumber numberWithFloat: gFallbackStyleOffset_Bottom],
                                    nil];

    if (fallbackOffsets)
    {
        [userDefaults registerDefaults:
                        [NSDictionary dictionaryWithObject: fallbackOffsets
                                        forKey: gUserDefaultsKey_FallbackWindowStyleOffsets]];
    }

    fallbackOffsets = [userDefaults objectForKey: gUserDefaultsKey_FallbackWindowStyleOffsets];

    if (![fallbackOffsets isKindOfClass: [NSArray class]]
        || ([fallbackOffsets count] < 4))
    {
        goto ERROR;
    }

    gFallbackStyleOffset_Left = [[fallbackOffsets objectAtIndex: 0] floatValue];
    gFallbackStyleOffset_Right = [[fallbackOffsets objectAtIndex: 1] floatValue];
    gFallbackStyleOffset_Top = [[fallbackOffsets objectAtIndex: 2] floatValue];
    gFallbackStyleOffset_Bottom = [[fallbackOffsets objectAtIndex: 3] floatValue];

    return;

ERROR:
    return;
}

+ (void) ppGSGlue_SaveFallbackStyleOffsetsToDefaults
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSArray *fallbackOffsets =
                        [NSArray arrayWithObjects:
                                    [NSNumber numberWithFloat: gFallbackStyleOffset_Left],
                                    [NSNumber numberWithFloat: gFallbackStyleOffset_Right],
                                    [NSNumber numberWithFloat: gFallbackStyleOffset_Top],
                                    [NSNumber numberWithFloat: gFallbackStyleOffset_Bottom],
                                    nil];

    if (!fallbackOffsets)
        goto ERROR;

    [userDefaults setObject: fallbackOffsets
                    forKey: gUserDefaultsKey_FallbackWindowStyleOffsets];

    return;

ERROR:
    return;
}

@end

#endif  // GNUSTEP

