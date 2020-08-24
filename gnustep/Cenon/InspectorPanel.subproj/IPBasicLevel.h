/*
 * IPBasicLevel.h
 *
 * Copyright (C) 1996-2011 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * Created:  1996-04-23
 * Modified: 2011-05-30 (labelField, -setLabel: added)
 *           2011-05-28 (excludeSwitch, -setExcluded: added)
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

#ifndef VHF_H_IPBASICLEVEL
#define VHF_H_IPBASICLEVEL

#include <AppKit/AppKit.h>

@interface IPBasicLevel:NSPanel
{
    id		window;         // the inspector panel

    id      labelField;
    id		excludeSwitch;
    id		lockSwitch;
}

+ (BOOL)servesObject:(NSObject*)g;  // whether this class serves the graphics object

- init;
- (void)setWindow:(id)win;  // inspector window
- window;
- view;                     // return document view
- (NSString*)name;
- (void)update:sender;

- (void)setLabel:sender;    // set label
- (void)setExcluded:sender; // exclude from processing
- (void)setLock:sender;     // lock position for mouse handling

/* delegate methods
 */
- (void)displayWillEnd;

@end

#endif // VHF_H_IPBASICLEVEL
