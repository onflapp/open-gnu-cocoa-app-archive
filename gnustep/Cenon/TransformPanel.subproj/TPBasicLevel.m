/*
 * TPBasicLebel.m
 *
 * Copyright (C) 1996-2003 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * Created:  1996-03-03
 * Modified: 2003-06-26
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

#include "TPBasicLevel.h"

@implementation TPBasicLevel

- init
{
    [self setDelegate:self];
    return self;
}

- (void)setWindow:win
{
    window = win; 
}

- view
{
    return [[(App*)NSApp currentDocument] documentView];
}

- window
{
    return window;
}

- (void)update:sender
{
}

/* delegate methods
 */
- (void)displayWillEnd
{
}

@end
