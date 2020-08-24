/* TileObject.m
 * Object managing batch production
 *
 * Copyright (C) 1996-2002 by vhf interservice GmbH
 * Author: Georg Fleischmann
 *
 * Created:  1996-03-07
 * Modified: 2002-07-15
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
#include <VHFShared/types.h>
#include "TileObject.h"
#include "messages.h"

@implementation TileObject

/*
 * This sets the class version so that we can compatibly read
 * old VGraphic objects out of an archive.
 */
+ (void)initialize
{
    [TileObject setVersion:1];
    return;
}

- init
{
    return [super init];
}

- (void)setPosition:(NSPoint)p
{
    position = p; 
}

- (NSPoint)position
{
    return position;
}

- (void)setAngle:(float)a
{
    angle = a; 
}

- (float)angle
{
    return angle;
}

- (void)dealloc
{
    [super dealloc];
}

- (id)initWithCoder:(NSCoder *)aDecoder
{   int	version;

    version = [aDecoder versionForClassName:@"TileObject"];
    if ( version < 1 )
        [aDecoder decodeValuesOfObjCTypes:"{ff}f", &position, &angle];
    else
        [aDecoder decodeValuesOfObjCTypes:"{NSPoint=ff}f", &position, &angle];

    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeValuesOfObjCTypes:"{NSPoint=ff}f", &position, &angle];
}

@end
