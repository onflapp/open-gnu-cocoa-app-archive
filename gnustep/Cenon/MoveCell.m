/* MoveCell.m
 *
 * Copyright (C) 1993-2005 by vhf interservice GmbH
 *
 * Created:  1993-05-14
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

#include <AppKit/AppKit.h>
#include "MoveMatrix.h"
#include "MoveCell.h"

@implementation MoveCell

/* modified: 21.01.93
 */
- (void)setMatrix:(MoveMatrix *)anMatrix;
{
    moveMatrix = anMatrix;	
}

/* modified: 13.01.93
 */
- (void)setTag:(int)anInt
{
    tag=anInt;
}

/* modified: 13.01.93
 */
- (int)tag
{
    return tag;
}

/* cell depends on the cell prior in list
 */
- (BOOL)dependant
{
    return NO;
}

/* modified: 13.01.93
 * save this info so we don't have to look it up every time we draw Note:  
 * support for a TextCell is a font object 
 */
- (void)setFont:(NSFont *)fontObj
{
    [super setFont:fontObj];
    //NSTextFontInfo([super font], &ascender, &descender, &lineHeight);
}

@end
