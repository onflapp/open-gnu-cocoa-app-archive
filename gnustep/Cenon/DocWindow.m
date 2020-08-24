/* DocWindow.m
 * Cenon document window class
 *
 * Copyright (C) 1995-2010 by vhf interservice GmbH
 * Author: Georg Fleischmann
 *
 * Created:  1995-12-02
 * Modified: 2010-04-18 (-sendEvent: double click to window bar reduces window to title bar)
 *           2010-01-18 (-windowDidBecomeMain: don't display tool panel)
 *           2010-01-12 (window position and size in grid steps added)
 *           2009-10-11 (-setDocument: coordinate timer uses -setAcceptsMouseMovedEvents: on Apple + GNUstep)
 *           2008-07-19 (send unit notification)
 *
 * info: the first responder of documentWindow is the graphic view (set in document.m)
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the vhf Public License as
 * published by vhf interservice GmbH. Among other things, the
 * License requires that the copyright notices and this notice
 * be preserved on all copies.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the vhf Public License for more details.
 *
 * You should have received a copy of the vhf Public License along
 * with this program; see the file LICENSE. If not, write to vhf.
 *
 * vhf interservice GmbH, Im Marxle 3, 72119 Altingen, Germany
 * eMail: info@vhf.de
 * http://www.vhf.de
 */

#include <AppKit/AppKit.h>
#include <VHFShared/types.h>
#include <VHFShared/vhfCommonFunctions.h>
#include <VHFShared/vhf2DFunctions.h>
#include "functions.h"
#include "App.h"
#include "DocView.h"
#include "Document.h"
#include "DocWindow.h"
#include "TilePanel.h"
#include "messages.h"
#include "PreferencesPanel.subproj/NotificationNames.h"  // PrefsUnitHasChanged notification
#include "PreferencesMacros.h"

@implementation DocWindow

/* returns the document of the window
 */
- document
{
    return document;
}

/* sets the document of the window (our private init method)
 * Note: bg-color is the color of the coordinate bar
 */
- (void)setDocument:docu
{
    document = docu;

    unit = [document baseUnit]; // we start with the unit from Preferences or document
    [unitPopup selectItemAtIndex:unit];	// init popup
    [unitPopup setTarget:self];
    [unitPopup setAction:@selector(setUnit:)];

    [self setDelegate:document];	// so that the document gets NSWindow delegation methods

    //[self setMiniwindowImage:[NSImage imageNamed:@"typeCenon"]];

#if defined(GNUSTEP_BASE_VERSION) || defined(__APPLE__)
    [self setAcceptsMouseMovedEvents:YES];	// doesn't work on OpenStep, works on GNUstep
#else   // OpenStep 4.2 Workaround
    if (!timer)
        timer = [NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(coordTimerFired:) userInfo:nil repeats:YES];	// workaround for OpenStep
#endif
}

- (NSSize)coordBoxSize
{
    return [coordBox borderRect].size;
}

- (BOOL)acceptsFirstResponder
{
    return YES;
}

/* the unit has been changed
 */
- (void)setUnit:sender
{
    unit = [sender indexOfSelectedItem]; 
    [self makeFirstResponder:[document documentView]];
}
- (int)unit
{
    return unit;
}

/* turn on/off coordinate display
 * modified: 2010-04-20
 */
- (void)enableCoordDisplay:(BOOL)enable
{   static float    coordOffset = 0.0;
    NSView          *contentView = [self contentView];
    NSRect          frame, tileFrame, boxFrame;

    if (enable == [coordBox isDescendantOf:contentView])
        return;
    frame     = [contentView    frame];
    tileFrame = [tileScrollView frame];
    boxFrame  = [coordBox       frame];
    if (enable)
    {
        [contentView addSubview:coordBox];
        [coordBox release];
        tileFrame.size.height = frame.size.height - coordOffset;
        boxFrame.origin.y     = frame.size.height - coordOffset;
        [tileScrollView setFrame:tileFrame];
        [coordBox       setFrameOrigin:boxFrame.origin];
    }
    else
    {
        coordOffset = frame.size.height - [tileScrollView frame].size.height;
        if ( coordOffset <= 0.0 )   // in case window is folded into title
            coordOffset = [coordBox frame].size.height;
        [coordBox retain];
        [coordBox removeFromSuperview];
        tileFrame.size.height = frame.size.height;
        //boxFrame.origin.y     = frame.size.height;
        [tileScrollView setFrame:tileFrame];
        //[coordBox       setFrameOrigin:boxFrame.origin];
    }
}

- (BOOL)hasCoordDisplay
{
    return ([coordBox isDescendantOf:[self contentView]]);
}

- (void)coordTimerFired:(id)timer
{   NSPoint		pc, p;
    static NSPoint	lastP = {0.0, 0.0};
    NSRect		rect;
    id			view = [document documentView];

    if ( ![self isKeyWindow] )
        return;
    pc = [self mouseLocationOutsideOfEventStream];
    p = [[view superview] convertPoint:pc fromView:nil];
    rect = [(NSClipView*)[view superview] bounds];
    if ( ![view mouse:p inRect:rect] || DiffPoint(lastP, p)<0.001 )
        return;
    lastP = p;
    p = [view convertPoint:pc fromView:nil];
    [self displayCoordinate:p ref:NO];
}

/* display the passed coordinate
 */
- (void)displayCoordinate:(NSPoint)p0 ref:(BOOL)ref
{   NSPoint	p;

    if (ref)
        refPoint = p0;
    p = [[document documentView] pointRelativeOrigin:p0];

    [xCoord setStringValue:buildRoundedString([self convertToUnit:p.x], LARGENEG_COORD, LARGE_COORD)];
    [yCoord setStringValue:buildRoundedString([self convertToUnit:p.y], LARGENEG_COORD, LARGE_COORD)];

    //[distance setStringValue:buildRoundedString([self convertToUnit:sqrt((p.x*p.x)+(p.y*p.y))], LARGENEG_COORD, LARGE_COORD)];

    p = p0;
    p.x -= refPoint.x;
    p.y -= refPoint.y;
    [wCoord setStringValue:buildRoundedString([self convertToUnit:p.x], LARGENEG_COORD, LARGE_COORD)];
    [hCoord setStringValue:buildRoundedString([self convertToUnit:p.y], LARGENEG_COORD, LARGE_COORD)];

    if ( [self isAutodisplay] == NO )
        [coordBox display];
}

/*
 * converts a value from internal unit to the current unit
 */
- (float)convertToUnit:(float)value
{
    switch (unit)
    {
        case UNIT_MM:    return (value*25.4/72.0);
        case UNIT_INCH:  return (value / 72.0);
        case UNIT_POINT: return value;
    }
    return (value);
}

#ifdef __APPLE__    // Linux has this feature already
/* click into title bar, reduces window to it's title bar and vice versa
 * created:  2010-04-18
 * modified: 2010-04-20
 */
- (void)sendEvent:(NSEvent *)event
{
    if ( [event type] == NSLeftMouseDown && [event clickCount] == 2 )
    {   NSPoint point = [event locationInWindow];
        NSRect  frame = [self frame];
        NSView  *contentView = [self contentView];
        NSRect  contentRect = [contentView frame];

        if ( point.y > contentRect.size.height )    // title bar
        {   float   titleHeight = frame.size.height - contentRect.size.height;
            NSRect  newFrame = frame;
            int     gridSize = Prefs_WindowGrid;

            /* keep size/position within window grid */
            titleHeight = floor((titleHeight-2+gridSize/2) / gridSize) * gridSize;

            /* resize window to title bar, and back */
            if ( frame.size.height > titleHeight )  // reduce window to title bar
            {
                unfoldedHeight = frame.size.height;
                newFrame.size.height = titleHeight;
                newFrame.origin.y    += (unfoldedHeight - titleHeight);
                [self setFrame:newFrame display:NO];
            }
            else if ( unfoldedHeight > 0.0 )        // unfold window contents
            {
                newFrame.size.height = unfoldedHeight;
                newFrame.origin.y    -= (unfoldedHeight - titleHeight);
                [self setFrame:newFrame display:NO];

                if ( [coordBox isDescendantOf:contentView] )    // coordinate display
                {   NSRect  tileFrame, boxFrame;
                    float   coordHeight = [coordBox frame].size.height;

                    contentRect = [contentView    frame];
                    tileFrame   = [tileScrollView frame];
                    boxFrame    = [coordBox       frame];
                    tileFrame.size.height = contentRect.size.height - coordHeight;
                    boxFrame.origin.y     = contentRect.size.height - coordHeight;
                    [tileScrollView setFrame:tileFrame];
                    [coordBox       setFrameOrigin:boxFrame.origin];
                }
            }
            //printf("Document Window mouse down: wf.y = %.0f wf.h = %.0f, vy = %.0f vh = %.0f  p.y = %.0f, \n",
            //       frame.origin.y, frame.size.height, contentRect.origin.y, contentRect.size.height, point.y);
        }
    }
    [super sendEvent:event];
}
- (float)unfoldedHeight
{
    return unfoldedHeight;
}
- (void)setUnfoldedHeight:(float)h
{
    unfoldedHeight = h;
}
- (BOOL)isFolded
{   NSRect  frame = [self frame];
    NSRect  contentRect = [[self contentView] frame];
    float   titleHeight = frame.size.height - contentRect.size.height;

    if ( frame.size.height <= titleHeight )
        return YES;
    return NO;
}
- (NSRect)unfoldedFrame
{   NSRect  frame = [self frame];
    NSRect  contentRect = [[self contentView] frame];
    float   titleHeight = frame.size.height - contentRect.size.height;

    if ( frame.size.height <= titleHeight )
    {   frame.size.height = unfoldedHeight;
        frame.origin.y -= (unfoldedHeight - titleHeight);
    }
    return frame;
}
#endif


/* delegate methods
 */

/* allow resizing the window in grid
 * created: 2010-01-10
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
/* allow moving the window in grid
 * created: 2010-01-12
 */
- (NSRect)constrainFrameRect:(NSRect)frameRect toScreen:(NSScreen *)screen
{   int gridSize = Prefs_WindowGrid;

    frameRect = [super constrainFrameRect:frameRect toScreen:screen];
    if ( gridSize )
    {   frameRect.origin.x = floor((frameRect.origin.x+gridSize/2) / gridSize) * gridSize;
        frameRect.origin.y = floor((frameRect.origin.y+gridSize/2) / gridSize) * gridSize;
    }
    return frameRect;
}

/* [NSApp mainWindow] may not be set yet !!!
 * modified: 2010-01-18 (do not display tool panel)
 *           2008-07-19 (notification for units added)
 */
- (void)windowDidBecomeMain:(NSNotification *)notification
{
    [(App*)NSApp setActiveDocWindow:self];
    //[(App*)NSApp displayToolPanel:YES];
    [[NSNotificationCenter defaultCenter] postNotificationName:DocWindowDidChange
                                                        object:document];
    [[NSNotificationCenter defaultCenter] postNotificationName:PrefsUnitHasChanged
                                                        object:document];
    //[[(App*)NSApp tilePanel] updatePanel:self];
}

- (void)windowDidBecomeKey:(NSNotification *)notification
{
    [[(App*)NSApp tilePanel] updatePanel:self];
}

- (void)windowDidResignKey:(NSNotification *)notification
{
}
/*- (void)windowDidResignMain:(NSNotification *)notification
{   //NSWindow *theWindow = [notification object];

    [self endEditingFor:nil];	// end editing of text
}*/


- (void)close
{
    [self endEditingFor:nil];               // end editing of text
    [(App*)NSApp setActiveDocWindow:nil];   // if next main comes before close then this removes the wrong window!
    [timer invalidate];
    //NSLog(@"retain=%d", [self retainCount]);
    [[NSNotificationCenter defaultCenter] postNotificationName:DocWindowDidChange
                                                        object:nil];
    [super close];
}

@end
