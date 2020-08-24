/* ProjectSettings.m
 * project settings for document
 *
 * Copyright (C) 2002-2009 by vhf interservice GmbH
 * Author: Georg Fleischmann
 *
 * Created:  2002-11-23
 * Modified: 2009-06-26 (awakeFromNib returns void)
 *           2008-07-30 (-indexOfItem:)
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
#include "ProjectSettings.h"
#include "PSSettings.h"
#include "PSInfo.h"
#include "PSFontInfo.h"
#include "DocWindow.h"	// Notification macro

@implementation ProjectSettings

- (void)awakeFromNib
{   NSNotificationCenter	*notificationCenter = [NSNotificationCenter defaultCenter];

    [panel setFrameAutosaveName:@"ProjectSettingsPanel"];

    /* add observer for changes of document window (DocWindow) */
    [notificationCenter addObserver:self
                           selector:@selector(documentHasChanged:)
                               name:DocWindowDidChange
                             object:nil];

    /* add observer to add an entry */
    [notificationCenter addObserver:self
                           selector:@selector(addItemNotification:)
                               name:DocSettingsAddItemNotification
                             object:nil];

    [panel setDelegate:self];

    [levPopup setTarget:self];
    [levPopup setAction:@selector(setLevel:)];

    /* add Info item */
    windows[levelCnt] = [self windowAt:levelCnt];
    //[levPopup addItemWithTitle:[windows[levelCnt] name]];
    [levPopup selectItemAtIndex:levelCnt];
    levelCnt++;
    /* add Settings item */
    windows[levelCnt] = [self windowAt:levelCnt];
    //[levPopup addItemWithTitle:[windows[levelCnt] name]];
    //[levPopup selectItemAtIndex:levelCnt];
    levelCnt++;

    [self setLevel:self];

    /* tell anyone that we are open and can now receive accessory items */
    [notificationCenter postNotificationName:DocSettingsDidOpenNotification object:nil];
}

- (void)makeKeyAndOrderFront:sender
{
    [panel makeKeyAndOrderFront:sender];
}

- (void)update:sender
{
    [activeWindow update:sender];
}

- (void)setLevel:sender
{
    [self setLevelAt:Max(0, [levPopup indexOfSelectedItem])];
}

/*
 */
- (void)setLevelAt:(int)level
{
    //[activeWindow displayWillEnd];
    if (level < levelCnt)
        [levPopup selectItemAtIndex:level];

    if (level < levelCnt )
    {
        [self windowAt:level];
        activeWindow = windows[level];
        [self setLevelView:[windows[level] view]];
    }
    else
    {
        [self setLevelView:nil];
        activeWindow = self;
        return;
    }

    [activeWindow update:self];
    [panel orderFront:self];
}

- (void)setLevelView:theView
{
    [(NSBox*)levView setContentView:[theView retain]];
    [levView setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];

    [panel display];
    [panel flushWindow];
}

/* item can be either the controller (window) or the view (NSBox)
 * created: 2008-07-30
 */
- (void)setLevelWithItem:(id)item
{
    [self setLevelAt:[self indexOfItem:item]];
}
- (int)indexOfItem:(id)item
{   int i;

    for (i=0; i<levelCnt; i++)
        if (windows[i] == item || [windows[i] view] == item)
            return i;
    return 0;
}

- windowAt:(int)level
{
    if (level < 0)
        return nil;
    switch (level)
    {
        case PS_SETTINGS:
            if (! windows[level])
                windows[level] = [[PSSettings alloc] init];
            return windows[level];
        case PS_INFO:
            if (! windows[level])
                windows[level] = [[PSInfo alloc] init];
            return windows[level];
        /*case PS_FONTINFO:
            if (! windows[level])
                windows[level] = [[PSFontInfo alloc] init];
            return windows[level];*/
        default:
            if (level >= levelCnt)
                return nil;
            return windows[level];
    }
}


/*
 * Notifications
 */

- (void)addItemNotification:(NSNotification*)notification
{   id  controller = [notification object];
    int level = levelCnt;

    windows[level] = [controller retain];
    levelCnt ++;
    //[controller setWindow:self];

    [levPopup addItemWithTitle:[controller name]];
}

- (void)windowDidResignKey:(NSNotification*)notification
{   //NSWindow *theWindow = [notification object];

    if ( [activeWindow respondsToSelector:@selector(set:)] )
        [activeWindow set:nil];
}

/* notification that the DocWindow has changed
 */
- (void)documentHasChanged:(NSNotification*)notification
{
    [self update:[notification object]];
}

@end
