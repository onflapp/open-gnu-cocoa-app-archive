/* VSinking.m
 *
 * Copyright (C) 2000-2010 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  2000-09-18
 * modified: 2010-07-08 (-drawAtAngle:withCenter:in:, setAngle:withCenter: added)
 *           2009-04-29 (-mirrorAround: added)
 *           2009-02-11 (initialize new sinking in point, not mm)
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
#include <math.h>
#include "../App.h"
#include "VSinking.h"
#include "../DocView.h"
#include "../DocWindow.h"
#include "../Inspectors.h"

@interface VSinking(PrivateMethods)
@end

@implementation VSinking

/*
 * This sets the class version so that we can compatibly read
 * old VGraphic objects out of an archive.
 */
+ (void)initialize
{
    [VSinking setVersion:1];
    return;
}

- (id)init
{
    [super init];

    name = [@"M4" retain];
    d1 = MMToInternal(4.5);
    d2 = MMToInternal(8.6);
    t1 = MMToInternal(2.1);
    t2 = MMToInternal(0.3);
    stepSize = MMToInternal(0.6);
    type = SINKING_MEDIUM;
    unit = SINKING_METRIC;

    return self;
}

- (NSString*)title
{
    return @"Sinking";
}

/* subclassed:
 * we only need the position
 */
#define CREATEEVENTMASK NSLeftMouseDraggedMask|NSLeftMouseDownMask|NSLeftMouseUpMask|NSPeriodicMask
- (BOOL)create:(NSEvent *)event in:(DocView*)view
{   NSRect	viewBounds;
    BOOL	ok = YES;

    [[(App*)NSApp inspectorPanel] loadGraphic:self];	/* set the values of the inspector to self */

    /* get start location, convert window to view coordinates */
    origin = [view convertPoint:[event locationInWindow] fromView:nil];
    [view hitEdge:&origin spare:self];			/* snap to point */
    origin = [view grid:origin];			/* set on grid */
    viewBounds = [view visibleRect];			/* get the bounds of the view */

    ok = NSMouseInRect(origin, viewBounds , NO);

    if ([event type] == NSAppKitDefined || [event type] == NSSystemDefined)
        ok = NO;

    if (!ok)
    {	[view display];
        return NO;
    }

    dirty = YES;
    [view cacheGraphic:self];	// add to graphic cache
    return YES;
}



- (void)setName:(NSString*)s	{ [name release]; name = [s retain]; }
- (NSString*)name		{ return name; }

- (void)setD1:(float)v		{ d1 = v; dirty = YES; }
- (float)d1			{ return d1; }

- (void)setD2:(float)v		{ d2 = v; dirty = YES; }
- (float)d2			{ return d2; }

- (void)setT1:(float)v		{ t1 = v; dirty = YES; }
- (float)t1			{ return t1; }

- (void)setT2:(float)v		{ t2 = v; dirty = YES; }
- (float)t2			{ return t2; }

- (void)setStepSize:(float)v	{ stepSize = v; dirty = YES; }
- (float)stepSize		{ return stepSize; }

- (void)setType:(int)newType	{ type = newType; dirty = YES; }
- (int)type			{ return type; }

- (void)setUnit:(int)newUnit	{ unit = newUnit; dirty = YES; }
- (int)unit			{ return unit; }


/* created: 2005-10-13
 * purpose: return the gradient (delta x, y) of the arc at t (0 <= t <= 1)
 */
- (NSPoint)gradientAt:(float)t
{   NSPoint	arcP, d;
    float	angle = SINKING_ANGLE;

    arcP = [self pointAt:t];
    d.x = arcP.x - origin.x;
    d.y = arcP.y - origin.y;
    return (angle > 0) ? NSMakePoint(-d.y, d.x) : NSMakePoint(d.y, -d.x);
}
/* created:   2005-10-13
 * parameter: t  0 <= t <= 1
 * purpose:   get a point on the line at t
 */
- (NSPoint)pointAt:(float)t
{   float	a = SINKING_ANGLE * t;

    return vhfPointAngleFromRefPoint(origin, NSMakePoint(origin.x+d2/2.0, origin.y), a);
}

/* created:   2010-07-08
 * modified:  2010-07-08
 * parameter: x, y	the angles to rotate in x/y direction
 *            p		the point we have to rotate around
 * purpose:   draw the graphic rotated around p with x and y
 */
- (void)drawAtAngle:(float)angle withCenter:(NSPoint)cp in:view
{   NSPoint p;
    float   radius = d1 / 2.0;
    NSBezierPath	*bPath = [NSBezierPath bezierPath];

    [bPath setLineWidth:1.0/[view scaleFactor]];
    p = vhfPointRotatedAroundCenter(origin, -angle, cp);
    /* cross for hole */
    [bPath moveToPoint:NSMakePoint(p.x, p.y+radius)];
    [bPath lineToPoint:NSMakePoint(p.x, p.y-radius)];
    [bPath moveToPoint:NSMakePoint(p.x+radius, p.y)];
    [bPath lineToPoint:NSMakePoint(p.x-radius, p.y)];
    /* arc for head */
    [bPath moveToPoint:NSMakePoint(p.x+d2/2.0, p.y)];
    [bPath appendBezierPathWithArcWithCenter:p radius:d2/2.0 startAngle:0.0 endAngle:360.0];
    [bPath stroke];
}

/* created:   21.10.95
 * modified:  2010-07-08
 * parameter: x, y	the angles to rotate in x/y direction
 *            cp	the point we have to rotate around
 * purpose:   rotate the graphic around cp with x and y
 */
- (void)setAngle:(float)angle withCenter:(NSPoint)cp
{
    origin = vhfPointRotatedAroundCenter(origin, -angle, cp);
    dirty = YES;
}

- (void)mirrorAround:(NSPoint)p
{
    origin.y = p.y - (origin.y - p.y);
    dirty = YES;
}

/*
 * draws the thread
 */
- (void)drawWithPrincipal:principal
{   float		radius = d1 / 2.0;
    NSBezierPath	*bPath = [NSBezierPath bezierPath];

    [super drawWithPrincipal:principal];
    [bPath setLineWidth:0.0];
    /* cross for hole */
    [bPath moveToPoint:NSMakePoint(origin.x, origin.y+radius)];
    [bPath lineToPoint:NSMakePoint(origin.x, origin.y-radius)];
    [bPath moveToPoint:NSMakePoint(origin.x+radius, origin.y)];
    [bPath lineToPoint:NSMakePoint(origin.x-radius, origin.y)];
    /* arc for head */
    [bPath moveToPoint:NSMakePoint(origin.x+d2/2.0, origin.y)];
    [bPath appendBezierPathWithArcWithCenter:origin radius:d2/2.0 startAngle:0.0 endAngle:360.0];
    [bPath stroke];

    if ([principal showDirection])
        [self drawDirectionAtScale:[principal scaleFactor]];
}

- (NSRect)coordBounds
{   NSRect	bRect;
    float	radius = d2 / 2.0;

    bRect.origin.x = origin.x - radius;
    bRect.origin.y = origin.y - radius;
    bRect.size.width = bRect.size.height = 2.0 * radius;
    return bRect;
}

- (int)numPoints
{
    return PTS_SINKING;
}

/* The pt argument holds the relative point change.
 */
- (void)moveBy:(NSPoint)pt
{
    origin.x += pt.x;
    origin.y += pt.y;
    dirty = YES;
}

/*
 * created:   25.09.95
 * modified:  
 * parameter: pt_num  number of vertices
 *            p       the new position in
 * purpose:   Sets a vertice to a new position.
 *            If it is a edge move the vertices with it
 *            Default must be the last point!
 */
- (void)movePoint:(int)pt_num to:(NSPoint)p
{   NSPoint	pc;
    NSPoint	pt;

    pc = origin;
    pt.x = p.x - pc.x;
    pt.y = p.y - pc.y;
    [self movePoint:pt_num by:pt];
}

/*
 * pt_num is the changing control point. pt holds the relative change in each coordinate. 
 * The relative is needed and not the absolute because the closest inside control point
 * changes when one of the outside points change.
 */
- (void)movePoint:(int)pt_num by:(NSPoint)pt
{
    origin.x += pt.x;
    origin.y += pt.y;
    dirty = YES;
}

/* Given the point number, return the point.
 * default must be the end point of the arc
 */
- (NSPoint)pointWithNum:(int)pt_num
{
    return origin;
}

- (BOOL)hit:(NSPoint)p fuzz:(float)fuzz
{   NSRect	bRect = [self bounds];
    float	radius = d2 / 2.0;

    bRect.origin.x -= fuzz;
    bRect.origin.y -= fuzz;
    bRect.size.width  += 2.0 * fuzz;
    bRect.size.height += 2.0 * fuzz;
    if ( NSPointInRect(p, bRect) &&
         (SqrDistPoints(p, origin) <= (radius+fuzz)*(radius+fuzz)) )
        return YES;
    return NO;
}

/*
 * Check for a control point hit.
 * Return the point number hit in the pt_num argument.
 */
- (BOOL)hitControl:(NSPoint)p :(int*)pt_num controlSize:(float)controlsize
{   NSRect	knobRect;
    NSPoint	pt = [self pointWithNum:PT_ORIGIN];

    knobRect.size.width = knobRect.size.height = controlsize;
    knobRect.origin.x = pt.x - controlsize/2.0;
    knobRect.origin.y = pt.y - controlsize/2.0;
    if ( NSPointInRect(p, knobRect) )
    {
        *pt_num = PT_ORIGIN;
        return YES;
    }
    return NO;
}

- (float)sqrDistanceGraphic:g
{
    return [g sqrDistanceGraphic:[VArc arcWithCenter:origin radius:d1/2.0 filled:NO]];
}

- (id)clippedWithRect:(NSRect)rect
{
    return ( NSPointInRect(origin, rect) ) ? self : nil;
}


/*
 * archiving
 */
- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [super encodeWithCoder:aCoder];
    //[aCoder encodeValuesOfObjCTypes:"{NSPoint=ff}", &origin];
    [aCoder encodePoint:origin];        // 2012-01-08
    [aCoder encodeValuesOfObjCTypes:"@", &name];
    [aCoder encodeValuesOfObjCTypes:"fffff", &d1, &d2, &t1, &t2, &stepSize];
    [aCoder encodeValuesOfObjCTypes:"ii", &type, &unit];
}
- (id)initWithCoder:(NSCoder *)aDecoder
{   int	version;

    [super initWithCoder:aDecoder];
    version = [aDecoder versionForClassName:@"VSinking"];
    //[aDecoder decodeValuesOfObjCTypes:"{NSPoint=ff}", &origin];
    origin = [aDecoder decodePoint];    // 2012-01-08
    [aDecoder decodeValuesOfObjCTypes:"@", &name];
    [aDecoder decodeValuesOfObjCTypes:"fffff", &d1, &d2, &t1, &t2, &stepSize];
    [aDecoder decodeValuesOfObjCTypes:"ii", &type, &unit];
    return self;
}

/* archiving with property list
 */
- (id)propertyList
{   NSMutableDictionary	*plist = [super propertyList];

    if (name)
        [plist setObject:name forKey:@"name"];
    [plist setObject:propertyListFromNSPoint(origin) forKey:@"origin"];
    [plist setObject:propertyListFromFloat(d1) forKey:@"d1"];
    [plist setObject:propertyListFromFloat(d2) forKey:@"d2"];
    [plist setObject:propertyListFromFloat(t1) forKey:@"t1"];
    [plist setObject:propertyListFromFloat(t2) forKey:@"t2"];
    [plist setObject:propertyListFromFloat(stepSize) forKey:@"st"];
    [plist setInt:type forKey:@"type"];
    [plist setInt:unit forKey:@"unit"];
    return plist;
}
- (id)initFromPropertyList:(id)plist inDirectory:(NSString *)directory
{
    [super initFromPropertyList:plist inDirectory:directory];
    origin = pointFromPropertyList([plist objectForKey:@"origin"]);
    name = [[plist objectForKey:@"name"] retain];
    d1 = [plist floatForKey:@"d1"];
    d2 = [plist floatForKey:@"d2"];
    t1 = [plist floatForKey:@"t1"];
    t2 = [plist floatForKey:@"t2"];
    stepSize = [plist floatForKey:@"st"];
    type = [plist intForKey:@"type"];
    unit = [plist intForKey:@"unit"];
    return self;
}

- (void)dealloc
{
    [name release];
    [super dealloc];
}

@end
