/* IPAllAcc.m
 * Inspector Accessory
 *
 * Copyright (C) 2008 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  2008-03-13
 * modified: 2008-03-21
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

#include <VHFShared/VHFSystemAdditions.h>
#include "InspectorPanel.h"
#include "IPAllAcc.h"
#include "../PreferencesPanel.subproj/NotificationNames.h"
#include "../App.h"
//#include "../Document.h"
#include "../DocView.h"

@implementation IPAllAcc

- init
{   NSNotificationCenter	*notificationCenter = [NSNotificationCenter defaultCenter];

    [super init];
    levelCnt = 0;

    /* notification that the DocWindow has changed */
    [notificationCenter addObserver:self
                           selector:@selector(documentHasChanged:)
                               name:DocWindowDidChange
                             object:nil];
    /* add observer to add items */
    [notificationCenter addObserver:self
                           selector:@selector(addItemNotification:)
                               name:InspectorAccAddItemNotification
                             object:nil];

    [accPopup setTarget:self];
    [accPopup setAction:@selector(setAccLevel:)];
    [accPopup setAutoenablesItems:NO];

    /* First item is "None" */
    if (IP_ACC_TEXT > 0)
        levelCnt++;
    windows[levelCnt] = nil;
    activeWindow = nil;

    /* add text accessory */
    //[accPopup removeAllItems];    // make text first item
    /*if (![NSBundle loadNibNamed:@"IPAccText" owner:self] || !accTextWindow)
        NSLog(@"Cannot load IPAccText interface file");
    [notificationCenter postNotificationName:InspectorAccessoryAddItemNotification
                                      object:accTextWindow];*/
    windows[levelCnt] = [self windowAt:levelCnt];
    [accPopup addItemWithTitle:[windows[levelCnt] name]];
    [accPopup selectItemAtIndex:levelCnt];
    levelCnt++;

    /* tell anyone that we are open and can now receive accessory items */
    [notificationCenter postNotificationName:InspectorAccDidOpenNotification object:nil];

    return self;
}

- (void)update:sender
{   int i, selectIx = 0;

    graphic = ([sender isKindOfClass:[VGraphic class]]) ? sender : nil;

    for (i=0; i<levelCnt; i++)
    {
        if ([[windows[i] class] servesObject:graphic])
        {
            if (selectIx <= 0)
                selectIx = i;
            [[accPopup itemAtIndex:i] setEnabled:YES];
        }
        else
            [[accPopup itemAtIndex:i] setEnabled:NO];
    }
    [accPopup selectItemAtIndex:selectIx];
    [self setAccLevel:accPopup];
}

- (void)setAccLevel:sender
{
    [self setLevelAt:Max(0, [sender indexOfSelectedItem])];
}

- (void)setLevelAt:(int)level
{   NSPanel *win = [self windowAt:level];

    if (level < 0)
        return;
    if ( activeWindow != win )
    {
        [activeWindow displayWillEnd];
        if ( level < levelCnt )
        {
            [accPopup selectItemAtIndex:level];
            [self setLevelView:[win contentView]];
        }
    }
    activeWindow = [self windowAt:level];
    [activeWindow update:graphic];
}

- windowAt:(int)level
{
    if (level < 0)
        return nil;
    switch (level)
    {
        case IP_ACC_TEXT:
            if (!accTextWindow)
            {
                if (![NSBundle loadModelNamed:@"IPAccText" owner:self])
                    NSLog(@"Cannot load IPAccText interface");
                windows[level] = accTextWindow;
                [[windows[level] init] setWindow:self];
            }
            return windows[level];
        default:
            if (level >= levelCnt)
                return nil;
            return windows[level];
    }
}

- (void)setLevelView:theView
{
    [accView setContentView:[theView retain]];
    [theView setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];

    [self display];
    [self flushWindow];
}

- (void)setDocView:(id)aView
{
    [docView release];
    docView = [aView retain];
}
- docView
{
    return (docView) ? (docView) : [[(App*)NSApp currentDocument] documentView];
}


/*
 * Notifications
 */

/* notification that the DocWindow has changed
 * modified: 2005-11-28
 */
- (void)documentHasChanged:(NSNotification*)notification
{   DocView	*view = [[notification object] documentView];

    if ([view isKindOfClass:[DocView class]] && [[view slayList] count])
    {   NSArray *sList = [[view slayList] objectAtIndex:0];

        [self setDocView:view];	// set a temporary document view to make sure we have one available
        [self update:([sList count]) ? [sList objectAtIndex:0] : nil];
        [self setDocView:nil];
    }
    else
        [self update:nil];
}


- (void)addItemNotification:(NSNotification*)notification
{   IPBasicLevel    *panel = [notification object];
    int             level = levelCnt;

    windows[level] = [panel retain];
    levelCnt ++;
    [panel init];	// ???
    [panel setWindow:self];
    [[panel contentView] retain];	// GNUstep

    [accPopup addItemWithTitle:[panel name]];
}


- (void)displayWillEnd
{	 
}

@end
