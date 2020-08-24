/* MultipleChange.m
 *
 * Copyright (C) 1993-2002 by vhf interservice GmbH
 * Authors:  Georg Fleischmann
 *
 * created:  1993 based on the Draw example files
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

#include "undochange.h"

@implementation MultipleChange

- (void)_setName:(NSString*) newString
{
    if (!newString || ![name isEqual:newString])
    {
        [name autorelease];
	name = [newString copyWithZone:(NSZone *)[self zone]];
    }
}

- (id)init
{
    [super init];
    lastChange = nil;
    changes = [[NSMutableArray alloc] init];
    name = nil;

    return self;
}

- (id)initChangeName:(NSString*)changeName
{
    [self init];
    [self _setName:changeName];
    return self;
}

- (void)dealloc
{
    [changes removeAllObjects];
    [changes release];
    [self _setName:nil];

    [super dealloc];
}

- (NSString *)changeName
{
    if (name)
        return name;
    if (lastChange != nil)
	return [lastChange changeName];

    return(@"");
}

- (void)undoChange
{   int i;

    for (i = [changes count] - 1; i >= 0; i--)
	[[changes objectAtIndex:i] undoChange];

    [super undoChange]; 
}

- (void)redoChange
{   int i, count;

    count = [changes count];
    for (i = 0; i < count; i++)
	[[changes objectAtIndex:i] redoChange];

    [super redoChange];
}

- (BOOL)subsumeChange:change
{
    if (lastChange != nil)
	return [lastChange subsumeChange:change];
    return NO;
}

- (BOOL)incorporateChange:change
{
    if (lastChange != nil && [lastChange incorporateChange:change])
	return YES;

    [changes addObject:change];
    lastChange = change;
    return YES;
}

- (void)finishChange
{
    if (lastChange != nil)
	[lastChange finishChange];
}

@end
