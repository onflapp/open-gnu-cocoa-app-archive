/* PunchGraphicsChange.h
 *
 * Copyright (C) 1993-2006 by vhf interservice GmbH
 * Authors:  Georg Fleischmann
 *
 * created:  2006-11-03
 * modified: 2006-11-03
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

@interface PunchGraphicsChange: GraphicsChange
{
    NSMutableArray	*newObjects;
//    BOOL		removeSource;
}

- (NSString *)changeName;
- (void)saveBeforeChange;
- (void)saveAfterChange;
- (Class)changeDetailClass;
//- (void)noteNewObjects:(NSArray*)array;

@end
