/* VLine3D.m
 * 3-D line object
 *
 * Copyright (C) 1996-2011 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1996-01-29
 * modified: 2011-04-04 (lineWithPoints: added)
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
#include "VLine3D.h"
#include "../DocView.h"

@interface VLine3D(PrivateMethods)
@end

@implementation VLine3D

+ (VLine3D*)line3D
{
    return [[VLine3D new] autorelease];
}
+ (VLine3D*)line3DWithPoints:(V3Point)pl0 :(V3Point)pl1
{   VLine3D *line = [[[VLine3D allocWithZone:[self zone]] init] autorelease];

    [line setVertices3D:pl0 :pl1];
    return line;
}


/* set our vertices
 */
- (void)setVertices3D:(V3Point)pv0 :(V3Point)pv1
{
    p0 = NSMakePoint(pv0.x, pv0.y);
    z0 = pv0.z;
    p1 = NSMakePoint(pv1.x, pv1.y);
    z1 = pv1.z;
    dirty = YES;
}

/* deep copy
 *
 * created:  2001-02-15
 * modified: 
 */
- copy
{   VLine3D *line3d = [[VLine3D allocWithZone:[self zone]] init];

    [line3d setWidth:width];
    [line3d setSelected:isSelected];
    [line3d setLocked:NO];
    [line3d setColor:color];
    [line3d setVertices:p0 :p1];
    [line3d setZLevel:z0 :z1];
    return line3d;
}

/* set our vertices
 */
- (void)setZLevel:(float)zv0 :(float)zv1
{
    z0 = zv0;
    z1 = zv1;
}

/*
 * return our vertices
 */
- (void)getZLevel:(float*)zv0 :(float*)zv1
{
    *zv0 = z0;
    *zv1 = z1; 
}

- (void)setLength:(float)length
{   double	axy, az, dx, dy, dz, xyLength, oxyLength = sqrt(SqrDistPoints(p0, p1));
    double	oLength = [self length];

    dz = z1 - z0;
    az = Asin(dz / oLength);
    if ( az < 0.0 )	az += 360.0;

    dz = length * Sin(az);
    xyLength = sqrt(length*length - dz*dz);
    if (Cos(az)<0.0) xyLength = -xyLength;

    dy = p1.y - p0.y;
    axy = Asin(dy / oxyLength);
    if ( axy < 0.0 )	axy += 360.0;
    if ( p1.x < p0.x )	axy = 180.0 - axy;
    if ( axy < 0.0 )	axy += 360.0;

    dy = xyLength * Sin(axy);
    dx = sqrt( xyLength*xyLength - dy*dy );
    if (Cos(axy)<0.0) dx = -dx;

    p1 = NSMakePoint(p0.x+dx, p0.y+dy);
    dx = p1.x - p0.x;
    dy = p1.y - p0.y;
    z1 = z0 + dz;
    dirty = YES;
}
- (float)length
{   float	lxy = sqrt(SqrDistPoints(p0, p1)), dz = z1-z0;

    return sqrt(lxy*lxy+dz*dz);
}

- (void)drawWithPrincipal:principal
{   float	defaultWidth = [NSBezierPath defaultLineWidth];

    [super drawWithPrincipal:principal];

    [NSBezierPath setDefaultLineWidth:(width > 0.0) ? width : defaultWidth];
    [NSBezierPath setDefaultLineCapStyle: NSRoundLineCapStyle];
    [NSBezierPath setDefaultLineJoinStyle:NSRoundLineJoinStyle];
    [NSBezierPath strokeLineFromPoint:p0 toPoint:p1];
    [NSBezierPath setDefaultLineWidth:defaultWidth];

    if ([principal showDirection])
        [self drawDirectionAtScale:[principal scaleFactor]];
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [super encodeWithCoder:aCoder];
    [aCoder encodeValuesOfObjCTypes:"ff", &z0, &z1];
}
- (id)initWithCoder:(NSCoder *)aDecoder
{   int	version;

    [super initWithCoder:aDecoder];
    version = [aDecoder versionForClassName:@"VLine3D"];
    [aDecoder decodeValuesOfObjCTypes:"ff", &z0, &z1];

    return self;
}

/* archiving with property list
 */
- (id)propertyList
{   NSMutableDictionary	*plist = [super propertyList];

    [plist setObject:propertyListFromFloat(z0) forKey:@"z0"];
    [plist setObject:propertyListFromFloat(z1) forKey:@"z1"];
    return plist;
}
- (id)initFromPropertyList:(id)plist inDirectory:(NSString *)directory
{
    [super initFromPropertyList:plist inDirectory:directory];
    z0 = [plist floatForKey:@"z0"];
    z1 = [plist floatForKey:@"z1"];
    return self;
}


- (void)dealloc
{
    [super dealloc];
}

@end
