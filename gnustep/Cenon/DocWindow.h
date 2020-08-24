/* DocWindow.h
 * Cenon document window class
 *
 * Copyright (C) 1995-2010 by vhf interservice GmbH
 * Author: Georg Fleischmann
 *
 * Created:  1995-12-02
 * Modified: 2010-04-19 (unfoldedHeight)
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

#ifndef VHF_H_DOCWINDOW
#define VHF_H_DOCWINDOW

#include <AppKit/AppKit.h>

/* notifications */
#define DocWindowDidChange	@"DocWindowDidChange"		// DataPanel needs update

@interface DocWindow:NSWindow
{
    id		wCoord;
    id		hCoord;
    id		xCoord;
    id		yCoord;
    id		unitPopup;      // mm, inch, pt
    id		tileScrollView;
    id		coordBox;

    id		document;       // the relating document
    int		unit;           // the unit
    NSPoint	refPoint;       // the refernce point for the coordinate display
    NSTimer	*timer;
#ifdef __APPLE__
    float   unfoldedHeight; // height of unfolded window, if folded
#endif
}

- document;
- (void)setDocument:docu;

#ifdef __APPLE__            // stuff to fold window into title bar
- (float)unfoldedHeight;
- (void)setUnfoldedHeight:(float)h;
- (BOOL)isFolded;
#endif

- (NSSize)coordBoxSize;		// return size of coord box

- (void)setUnit:sender;
- (int)unit;

- (float)convertToUnit:(float)value;

- (void)enableCoordDisplay:(BOOL)enable;
- (BOOL)hasCoordDisplay;
- (void)displayCoordinate:(NSPoint)p0 ref:(BOOL)ref;

/* delegate methods
 */
- (void)windowDidBecomeMain:(NSNotification *)notification;
//- (void)windowDidResignMain:(NSNotification *)notification;
- (void)windowDidResignKey:(NSNotification *)notification;
//- (BOOL)windowShouldClose:(id)sender;

@end

#endif // VHF_H_DOCWINDOW
