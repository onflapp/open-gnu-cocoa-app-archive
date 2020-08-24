/* PSFontInfo.m
 * fontinfo panel for project settings
 *
 * Copyright (C) 1996-2003 by vhf interservice GmbH
 * Author: Ilonka Fleischmann, Georg Fleischmann
 *
 * Created:  2002-11-23
 * Modified: 2003-04-25
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

@interface PSFontInfo:NSObject
{
    id	view;
    id	versionForm;
    id	authorForm;
    id	copyrightForm;
    id	commentField;
}

- (id)init;
- (void)update:(id)sender;

- (NSString*)name;
- (NSView*)view;

- (void)set:sender;

@end
