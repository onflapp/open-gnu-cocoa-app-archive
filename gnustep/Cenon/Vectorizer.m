/* Vectorizer.m
 * controller class of the Vectorizer panel
 *
 * Copyright (C) 2011 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  2011-04-05
 * modified: 2011-04-05
 */

#include <AppKit/AppKit.h>
#include "App.h"
#include "DocView.h"
#include "PreferencesMacros.h"
#include "Vectorizer.h"

typedef enum
{
    SWITCH_REPLACE = 0,
    SWITCH_FILL    = 1
} vectorizerSwitches;

@interface Vectorizer(PrivateMethods)
@end

@implementation Vectorizer

+ (Vectorizer*)sharedInstance
{   static Vectorizer   *sharedInstance = nil;

    if (!sharedInstance)
        sharedInstance = [self new];
    return sharedInstance;
}

/* open panel
 * sender should be the layer object
 */
- (void)showPanel:(id)sender
{
    if (!panel)
    {
        /* load panel, this establishes connections to interface outputs */
        if ( ![NSBundle loadNibNamed:@"Vectorizer" owner:self] )
        {   NSLog(@"Cannot load Vectorizer Panel interface file");
            return;
        }
        [panel setDelegate:self];
        [panel setFrameUsingName:@"VectorizerPanel"];
        [panel setFrameAutosaveName:@"VectorizerPanel"];
    }

    // TODO: 

    [panel makeKeyAndOrderFront:sender];
}

/* action methods */
- (void)set:(id)sender
{   DocView *docView = [[(App*)NSApp currentDocument] documentView];
    BOOL    createCurves = ([typPopup indexOfSelectedItem] == 0) ? NO : YES;
    float   maxError = Max([tolField floatValue]/4.0, 0.1);
    BOOL    replaceSource = ([(NSCell*)[switchMatrix cellAtRow:SWITCH_REPLACE column:0] state]) ? YES : NO;
    BOOL    fillResult    = ([(NSCell*)[switchMatrix cellAtRow:SWITCH_FILL    column:0] state]) ? YES : NO;

    [docView vectorizeWithTolerance:maxError
                       createCurves:createCurves
                               fill:fillResult
                      replaceSource:replaceSource];

    //[panel orderOut:self];
}

- (void)setTypePopup:(id)sender
{   int ix = [sender indexOfSelectedItem];  // 0 = lines, 1 = curves

    /* disable tolerance items for lines */
    [tolField  setEnabled:(ix) ? YES : NO];
    [tolSlider setEnabled:(ix) ? YES : NO];
}

/* updates tolerance
 */
- (void)setTolerance:(id)sender
{   float	min = 0.0, max = 50.0, v;

    if ( [sender isKindOfClass:[NSSlider class]] )
        v = [tolSlider intValue];
    else
        v = [tolField  intValue];

    if (v < min) v = min;
    if (v > max) v = max;
    [tolField setIntValue:(int)v];
    [tolSlider setFloatValue:v];
}


/* allow resizing the window in a grid
 * created: 2010-01-17
 */
- (NSSize)windowWillResize:(NSWindow*)sender toSize:(NSSize)newSize
{   int gridSize = Prefs_WindowGrid;

    if ( gridSize ) // grid size
    {
        newSize.width  = floor((newSize.width +gridSize/2) / gridSize) * gridSize;
        newSize.height = floor((newSize.height+gridSize/2) / gridSize) * gridSize;
    }
    return newSize;
}
/* allow moving of window in grid
 * created: 2010-01-17
 *
 * TODO: this needs to be in a subclass of the panel
 */
- (NSRect)constrainFrameRect:(NSRect)frameRect toScreen:(NSScreen *)screen
{   int gridSize = Prefs_WindowGrid;

    frameRect = [panel constrainFrameRect:frameRect toScreen:screen];
    if ( gridSize )
    {   frameRect.origin.x = floor((frameRect.origin.x+gridSize/2) / gridSize) * gridSize;
        frameRect.origin.y = floor((frameRect.origin.y+gridSize/2) / gridSize) * gridSize;
    }
    return frameRect;
}

@end
