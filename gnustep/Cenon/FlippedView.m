/*
 * FlippedView.m, FlippedImage
 *
 * Copyright (C) 1997 - 2002 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1997-03-13
 * modified: 2002-07-15
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

#include "FlippedView.h"

/* flipped view
 */
@implementation FlippedView: NSView

- initWithFrame:(NSRect)frameRect
{
    [super initWithFrame:frameRect];
    isFlipped = YES;
    return self;
}

- (BOOL)isFlipped
{
    return isFlipped;
}

- (void)setFlipped:(BOOL)flag
{
    isFlipped = flag;
}

/*- (void)resizeWithOldSuperviewSize:(NSSize)size
{
    [super resizeWithOldSuperviewSize:size];
}*/

@end


/* flipped image
 */
@implementation FlippedImage: NSImage

- (BOOL)isFlipped	{ return YES; }

@end
