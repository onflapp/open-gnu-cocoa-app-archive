/* InspectorPanel.m
 * Cenon Inspector panel
 *
 * Copyright (C) 1996-2011 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1993-10-01
 * modified: 2010-01-17 (-windowWillResize:, constrainFrameRect: added)
 *           2009-03-26 (-sendEvent: clean-up, comma-handling)
 *           2008-03-17 (Accessory replaces AllText)
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
#include <VHFShared/VHFSystemAdditions.h>
#include "InspectorPanel.h"
#include "../PreferencesPanel.subproj/NotificationNames.h"
#include "../App.h"
#include "../Document.h"
#include "../DocView.h"
#include "../Graphics.h"
#include "../messages.h"
#include "IPTextPath.h"		// for managing of sub inspector

@implementation InspectorPanel

- (BOOL)canBecomeKeyWindow	{ return YES; }

/* FIXME: this -init is not what it seems and should be renamed, it's only privatly used
 */
- init
{   NSNotificationCenter	*notificationCenter = [NSNotificationCenter defaultCenter];

    if ( ! defaultView )
        defaultView = [[levView contentView] retain];
    if ( !viewDict )
        viewDict = [[NSMutableDictionary dictionary] retain];

    [self loadGraphic:nil];
    [self setDelegate:self];

    /* notification that the units of measurement have changed */
    [notificationCenter addObserver:self
                           selector:@selector(unitHasChanged:)
                               name:PrefsUnitHasChanged
                             object:nil];

    /* notification that the DocWindow has changed */
    [notificationCenter addObserver:self
                           selector:@selector(documentHasChanged:)
                               name:DocWindowDidChange
                             object:nil];

    return self;
}


- (void)update:sender
{
}

/* load inspector with first gs object in selection list
 */
- (void)loadList:(NSArray*)list
{   int	i, l, cnt = [list count];
    id	obj = nil;

    for (l=0; l<cnt; l++)
    {	NSMutableArray	*slist = [list objectAtIndex:l];

        if ( !obj && [slist count] )
            obj = [slist objectAtIndex:0];
        for ( i=[slist count]-1; i>=0; i-- )
            if ( ![[slist objectAtIndex:i] isKindOfClass:[obj class]] )
            {   [self loadGraphic:nil];
                return;
            }
    }
    [self loadGraphic:(obj) ? obj : nil];
}

- (void)loadGraphic:(id)g
{   id          newWindow;
    NSString    *string = @"ipCrosshairs.tiff";

    if (!defaultName)
        defaultName = [[self title] retain];

    if ([g isMemberOfClass:[VLine3D class]])
    {
        if (!line3DWindow)
        {
            if ( ![NSBundle loadModelNamed:@"IPLine3D" owner:self] )
                NSLog(@"Cannot load IPLine3D model");
            [[line3DWindow init] setWindow:self];
            [viewDict setObject:[line3DWindow contentView] forKey:[line3DWindow className]];
        }
        newWindow = line3DWindow;
        string = @"ipLine3D.tiff";
    }
    else if ([g isKindOfClass:[VLine class]])
    {
        if (!lineWindow)
        {
            if ( ![NSBundle loadModelNamed:@"IPLine" owner:self] )
                NSLog(@"Cannot load IPLine model");
            [[lineWindow init] setWindow:self];
            [viewDict setObject:[lineWindow contentView] forKey:[lineWindow className]];
        }
        newWindow = lineWindow;
        string = @"ipLine.tiff";
    }
    else if ([g isKindOfClass:[VPolyLine class]])
    {
        if (!polyLineWindow)
        {   if ( ![NSBundle loadModelNamed:@"IPPolyLine" owner:self] )
                NSLog(@"Cannot load IPPolyLine model");
            [[polyLineWindow init] setWindow:self];
            [viewDict setObject:[polyLineWindow contentView] forKey:[polyLineWindow className]];
        }
        newWindow = polyLineWindow;
        string = @"ipPolyLine.tiff";
    }
    else if ([g isKindOfClass:[VCurve class]])
    {
        if (!curveWindow)
        {   if ( ![NSBundle loadModelNamed:@"IPCurve" owner:self] )
                NSLog(@"Cannot load IPCurve model");
            [[curveWindow init] setWindow:self];
            [viewDict setObject:[curveWindow contentView] forKey:[curveWindow className]];
        }
        newWindow = curveWindow;
        string = @"ipCurve.tiff";
    }
    else if ([g isMemberOfClass:[VArc class]])
    {
        if (!arcWindow)
        {   if ( ![NSBundle loadModelNamed:@"IPArc" owner:self] )
                NSLog(@"Cannot load IPArc model");
            [[arcWindow init] setWindow:self];
            [viewDict setObject:[arcWindow contentView] forKey:[arcWindow className]];
        }
        newWindow = arcWindow;
        string = @"ipArc.tiff";
    }
    else if ([g isMemberOfClass:[VThread class]])
    {
        if (!threadWindow)
        {   if ( ![NSBundle loadModelNamed:@"IPThread" owner:self] )
                NSLog(@"Cannot load IPThread model");
            [[threadWindow init] setWindow:self];
            [viewDict setObject:[threadWindow contentView] forKey:[threadWindow className]];
        }
        newWindow = threadWindow;
        string = @"ipThread.tiff";
    }
    else if ([g isKindOfClass:[VPath class]])
    {
        if (!pathWindow)
        {   if ( ![NSBundle loadModelNamed:@"IPPath" owner:self] )
                NSLog(@"Cannot load IPPath model");
            [[pathWindow init] setWindow:self];
            [viewDict setObject:[pathWindow contentView] forKey:[pathWindow className]];
        }
        newWindow = pathWindow;
        string = @"ipPath.tiff";
    }
    else if ([g isKindOfClass:[VText class]])
    {
        if (!textWindow)
        {   if ( ![NSBundle loadModelNamed:@"IPText" owner:self] )
                NSLog(@"Cannot load IPText model");
            [[textWindow init] setWindow:self];
            [viewDict setObject:[textWindow contentView] forKey:[textWindow className]];
        }
        newWindow = textWindow;
        string = @"ipText.tiff";
    }
    else if ([g isKindOfClass:[VTextPath class]])
    {   id	tpGraphic = [g path];
        id	tpView, tpWindow = nil;

        if (!textPathWindow)
        {
            if ( ![NSBundle loadModelNamed:@"IPTextPath" owner:self] )
                NSLog(@"Cannot load IPTextPath model");
            [[textPathWindow init] setWindow:self];
            [viewDict setObject:[textPathWindow contentView] forKey:[textPathWindow className]];
        }
        if ([tpGraphic isKindOfClass:[VLine class]])
        {   if (!lineWindow)
            {   if ( ![NSBundle loadModelNamed:@"IPLine" owner:self] )
                    NSLog(@"Cannot load IPLine model");
                [[lineWindow init] setWindow:self];
                [viewDict setObject:[lineWindow contentView] forKey:[lineWindow className]];
            }
            tpWindow = lineWindow;
        }
        else if ([tpGraphic isKindOfClass:[VCurve class]])
        {
            if (!curveWindow)
            {   if ( ![NSBundle loadModelNamed:@"IPCurve" owner:self] )
                    NSLog(@"Cannot load IPCurve model");
                [[curveWindow init] setWindow:self];
                [viewDict setObject:[curveWindow contentView] forKey:[curveWindow className]];
            }
            tpWindow = curveWindow;
        }
        else if ([tpGraphic isMemberOfClass:[VArc class]])
        {
            if (!arcWindow)
            {   if ( ![NSBundle loadModelNamed:@"IPArc" owner:self] )
                    NSLog(@"Cannot load IPArc model");
                [[arcWindow init] setWindow:self];
                [viewDict setObject:[arcWindow contentView] forKey:[arcWindow className]];
            }
            tpWindow = arcWindow;
        }
        if ( [viewDict objectForKey:[tpWindow className]] != [tpWindow contentView] )
            [tpWindow setContentView:[viewDict objectForKey:[tpWindow className]]];  // GNUstep removes the contentview
        tpView = [tpWindow contentView];
        [[textPathWindow pathView] setContentView:[tpView retain]];
        [tpView setAutoresizingMask:0]; // NSViewHeightSizable
        [tpWindow update:tpGraphic];

        newWindow = textPathWindow;
        string = @"ipTextPath.tiff";
    }
    else if ([g isKindOfClass:[VGroup class]])
    {
        if (!groupWindow)
        {   if ( ![NSBundle loadModelNamed:@"IPGroup" owner:self] )
                NSLog(@"Cannot load IPGroup model");
            [[groupWindow init] setWindow:self];
            [viewDict setObject:[groupWindow contentView] forKey:[groupWindow className]];
        }
        newWindow = groupWindow;
        string = @"ipGroup.tiff";
    }
    else if ([g isMemberOfClass:[VRectangle class]])
    {
        if (!rectangleWindow)
        {   if ( ![NSBundle loadModelNamed:@"IPRectangle" owner:self] )
                NSLog(@"Cannot load IPRectangle model");
            [[rectangleWindow init] setWindow:self];
            [viewDict setObject:[rectangleWindow contentView] forKey:[rectangleWindow className]];
        }
        newWindow = rectangleWindow;
        string = @"ipRectangle.tiff";
    }
    else if ([g isMemberOfClass:[VImage class]])
    {
        if (!imageWindow)
        {   if ( ![NSBundle loadModelNamed:@"IPImage" owner:self] )
                NSLog(@"Cannot load IPImage model");
            [[imageWindow init] setWindow:self];
            [viewDict setObject:[imageWindow contentView] forKey:[imageWindow className]];
        }
        newWindow = imageWindow;
        string = @"ipImage.tiff";
    }
    else if ([g isMemberOfClass:[VMark class]])
    {
        if (!markWindow)
        {   if ( ![NSBundle loadModelNamed:@"IPMark" owner:self] )
                NSLog(@"Cannot load IPMark model");
            [[markWindow init] setWindow:self];
            [viewDict setObject:[markWindow contentView] forKey:[markWindow className]];
        }
        newWindow = markWindow;
        string = @"ipMark.tiff";
    }
    else if ([g isMemberOfClass:[VWeb class]])
    {
        if (!webWindow)
        {   if ( ![NSBundle loadModelNamed:@"IPWeb" owner:self] )
                NSLog(@"Cannot load IPWeb model");
            [[webWindow init] setWindow:self];
            [viewDict setObject:[webWindow contentView] forKey:[webWindow className]];
        }
        newWindow = webWindow;
        string = @"ipWeb.tiff";
    }
    else if ([g isMemberOfClass:[VSinking class]])
    {
        if (!sinkingWindow)
        {   if ( ![NSBundle loadModelNamed:@"IPSinking" owner:self] )
                NSLog(@"Cannot load IPSinking model");
            [[sinkingWindow init] setWindow:self];
            [viewDict setObject:[sinkingWindow contentView] forKey:[sinkingWindow className]];
        }
        newWindow = sinkingWindow;
        string = @"ipSinking.tiff";
    }
    else if ( !g && [self view] )
    {
        if (!crosshairsWindow)
        {   if ( ![NSBundle loadModelNamed:@"IPCrosshairs" owner:self] )
                NSLog(@"Cannot load IPCrosshairs model");
            [[crosshairsWindow init] setWindow:self];
            [viewDict setObject:[crosshairsWindow contentView] forKey:[crosshairsWindow className]];
        }
        newWindow = crosshairsWindow;
        g = [(DocView*)[self view] origin];
        string = @"ipCrosshairs.tiff";
    }
    else
    {
//        if ([objectWindow respondsToSelector:@selector(displayWillEnd)])
//            [objectWindow displayWillEnd];
        objectWindow = nil;
        [self setTitle:defaultName];
//        [self setLevelView:nil];
        graphic = nil;
        return;
    }

    graphic = g;

    if (objectWindow != newWindow)
    {	NSImage	*image = [NSImage imageNamed:string];

        [[levRadio cellAtRow:0 column:0] setImage:image];
    }
    objectWindow = newWindow;

    [self setTitle:[objectWindow title]];

    if ( [levRadio selectedColumn] == 0 && newWindow != activeWindow )
    {
        if ([activeWindow respondsToSelector:@selector(displayWillEnd)])
            [activeWindow displayWillEnd];
        if ( [viewDict objectForKey:[objectWindow className]] != [objectWindow contentView] )
            [objectWindow setContentView:[viewDict objectForKey:[objectWindow className]]];  // GNUstep removes the contentview
        [self setLevelView:[objectWindow contentView]];
        activeWindow = objectWindow;
    }
    [activeWindow update:g];
    if ( [self isVisible] )
        [self orderFront:self];
}

- (void)setLevel:sender
{
    [self setLevelAt:Max(0, [levRadio selectedColumn])];
}

- (void)setLevelAt:(int)level
{
    [activeWindow displayWillEnd];
    if (level < 10)
        [levRadio selectCellAtRow:0 column:level];
    switch ( level )
    {
        case IP_OBJECT:		// current object
            [self windowAt:IP_OBJECT];
            //if (!objectWindow)
            //    return;
            [self setLevelView:[objectWindow contentView]];
            activeWindow = objectWindow;
            break;
        case IP_STROKEWIDTH:	// stroke width
            [[NSColorPanel sharedColorPanel] setShowsAlpha:YES];
            [self windowAt:IP_STROKEWIDTH];
            [self setLevelView:[allStrokeWindow contentView]];
            activeWindow = allStrokeWindow;
            break;
        case IP_FILLING:	// filling
            [[NSColorPanel sharedColorPanel] setShowsAlpha:YES];
            [self windowAt:IP_FILLING];
            [self setLevelView:[allFillingWindow contentView]];
            activeWindow = allFillingWindow;
            break;
        /*case IP_TEXT:		// text
            [self windowAt:IP_TEXT];
            [self setLevelView:[allTextWindow contentView]];
            activeWindow = allTextWindow;
            break;*/
        case IP_ACC:		// text
            [self windowAt:IP_ACC];
            [self setLevelView:[allAccWindow contentView]];
            activeWindow = allAccWindow;
            break;
        case IP_LAYERS:		// layers
            [self windowAt:IP_LAYERS];
            [self setLevelView:[allLayersWindow contentView]];
            activeWindow = allLayersWindow;
            break;
        default:
            [self setLevelView:NULL];
            activeWindow = self;
            return;
    }
    [activeWindow update:graphic];
    [self orderFront:self];
}

- windowAt:(int)level
{
    switch (level)
    {
        case IP_OBJECT:
            if ( [viewDict objectForKey:[objectWindow className]] != [objectWindow contentView] )
                [objectWindow setContentView:[viewDict objectForKey:[objectWindow className]]];   // GNUstep workaround
            return objectWindow;
        case IP_STROKEWIDTH:
            if (!allStrokeWindow)
            {
                if (![NSBundle loadModelNamed:@"IPAllStrokeWidth" owner:self])
                    NSLog(@"Cannot load IPAllStrokeWidth model");
                [[allStrokeWindow init] setWindow:self];
                [viewDict setObject:[allStrokeWindow contentView] forKey:[allStrokeWindow className]];
            }
            else if ( [viewDict objectForKey:[allStrokeWindow className]] != [allStrokeWindow contentView] )
                [allStrokeWindow setContentView:[viewDict objectForKey:[allStrokeWindow className]]];   // GNUstep workaround
            return allStrokeWindow;
        case IP_FILLING:
            if (!allFillingWindow)
            {
                if (![NSBundle loadModelNamed:@"IPAllFilling" owner:self])
                    NSLog(@"Cannot load IPAllFilling model");
                [[allFillingWindow init] setWindow:self];
                [viewDict setObject:[allFillingWindow contentView] forKey:[allFillingWindow className]];
            }
            else if ( [viewDict objectForKey:[allFillingWindow className]] != [allFillingWindow contentView] )
                [allFillingWindow setContentView:[viewDict objectForKey:[allFillingWindow className]]];   // GNUstep workaround
            return allFillingWindow;
        /*case IP_TEXT:
            if (!allTextWindow)
            {
                if (![NSBundle loadModelNamed:@"IPAllText" owner:self])
                    NSLog(@"Cannot load IPAllText model");
                [[allTextWindow init] setWindow:self];
            }
            return allTextWindow;*/
        case IP_ACC:
            if (!allAccWindow)
            {
                if (![NSBundle loadModelNamed:@"IPAllAcc" owner:self])
                    NSLog(@"Cannot load IPAllAcc model");
                [[allAccWindow init] setWindow:self];
                [viewDict setObject:[allAccWindow contentView] forKey:[allAccWindow className]];
            }
            else if ( [viewDict objectForKey:[allAccWindow className]] != [allAccWindow contentView] )
                [allAccWindow setContentView:[viewDict objectForKey:[allAccWindow className]]];   // GNUstep workaround
            return allAccWindow;
        case IP_LAYERS:
            if (!allLayersWindow)
            {
                if (![NSBundle loadModelNamed:@"IPAllLayers" owner:self])
                    NSLog(@"Cannot load IPAllLayers model");
                [[allLayersWindow init] setWindow:self];
                [viewDict setObject:[allLayersWindow contentView] forKey:[allLayersWindow className]];
            }
            else if ( [viewDict objectForKey:[allLayersWindow className]] != [allLayersWindow contentView] )
                [allLayersWindow setContentView:[viewDict objectForKey:[allLayersWindow className]]];   // GNUstep workaround
            return allLayersWindow;
        default: return nil;
    }
}

- (void)setLevelView:theView
{
    if ( ! defaultView )
        defaultView = [[levView contentView] retain];
    if ( theView != [levView contentView] ) // GNUstep can't handle setting the same contentView twice
        [levView setContentView:(theView) ? [theView retain] : defaultView];
    [theView setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];

    [self display];
    [self flushWindow];
}

- (void)updateInspector
{   id	document = [(App*)NSApp currentDocument];

    [self loadList:[[document documentView] slayList]];
    [self display];
}

/*
 * we overwrite this to catch a keyDown before NSMatrix etc. does
 */
- (void)sendEvent:(NSEvent *)event
{
    if ( event && [event type] == NSKeyDown )
    {   NSString    *chars = [event charactersIgnoringModifiers];

#ifdef __APPLE__
        if ( [event keyCode] == 65 )    // decimal-key: we want a '.'
            chars = @".";
#endif
        /* we remove the modifiers when we pass down the event,
         * so we can use control for the speed control of DPControl
         */
        event = [NSEvent keyEventWithType:[event type]
                                 location:[event locationInWindow]
                            modifierFlags:0
                                timestamp:[event timestamp]
                             windowNumber:[event windowNumber]
                                  context:[event context]
                               characters:chars
              charactersIgnoringModifiers:chars
                                isARepeat:[event isARepeat]
                                  keyCode:[event keyCode]];
        if ( [[event characters] isEqual:@"\t"] )
            tabEvent = YES;
    }
    [super sendEvent:event];
}

/* send for NSMatrix and NSTextField
 */
- (void)controlTextDidEndEditing:(NSNotification *)aNotification
{   id	matrix = [aNotification object];

    if ( tabEvent )
    {
        if ( [[matrix selectedCell] action] )
            [[[matrix selectedCell] target] performSelector:[[matrix selectedCell] action]
                                                 withObject:[matrix selectedCell]];
        else if ( [matrix action] )
            [[matrix target] performSelector:[matrix action] withObject:matrix];
        tabEvent = NO;
    }
}


- (void)setDocView:(id)aView
{
    [docView release];
    docView = [aView retain];
}
- docView
{
    return (docView) ? docView
                     : [[(App*)NSApp currentDocument] documentView];
}

/* notification that the unit of measurement has changed
 */
- (void)unitHasChanged:(NSNotification*)sender
{
    [activeWindow update:graphic];
}

/* notification that the DocWindow has changed
 * modified: 2005-11-28
 */
- (void)documentHasChanged:(NSNotification*)notification
{   DocView	*view = [[notification object] documentView];

    if ([view isKindOfClass:[DocView class]])
    {
        [self setDocView:view];	// set a temporary document view to make sure we have one available
        [self loadList:[view slayList]];
        [self setDocView:nil];
    }
    else
        [self loadGraphic:nil];
}

/* allow resizing the window in grid
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

@end
