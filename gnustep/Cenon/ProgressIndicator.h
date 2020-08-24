/* ProgressIndicator.h
 * progress indicator
 *
 * Copyright (C) 2004 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  2004-07-07
 * modified: 2004-08-04
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

#ifndef VHF_H_PROGRESSINDICATOR
#define VHF_H_PROGRESSINDICATOR

#include <AppKit/AppKit.h>

@interface ProgressIndicator:NSView
{
    BOOL	enabled;
    BOOL	displayText;
    BOOL	displayCells;
    float	percent;	// progress (0.0 - 1.0)
    NSString	*title;		// a subtitle displayed under the progress bar
}

- (void)setPercentNumber:(NSNumber*)p;	// set percent and display (for target and action)
- (void)setPercent:(float)p;		// set percent and setNeedsDisplay
- (float)percent;

- (void)setTitle:(NSString*)string;	// set string behind progress bar

- (void)setDisplayText:(BOOL)flag;
- (void)setDisplayCells:(BOOL)flag;

- (void)setEnabled:(BOOL)flag;

/* progress notification */
- (void)progress:(NSNotification*)notification;

@end

#endif // VHF_H_PROGRESSINDICATOR
