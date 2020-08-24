/* VCrosshairs.m
 *
 * Copyright (C) 1996-2009 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1996-03-29
 * modified: 2009-12-25 (description added)
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
#include "VCrosshairs.h"
#include "../App.h"
#include "../DocView.h"

@interface VCrosshairs(PrivateMethods)
@end

@implementation VCrosshairs

/* This sets the class version so that we can compatibly read old objects out of an archive.
 */
+ (void)initialize
{
    [VCrosshairs setVersion:1];
    return;
}

/* initialize
 */
- init
{
    origin.x = origin.y = 10.0 * MM;
    return [super init];
}

- (NSString*)description
{
    return [NSString stringWithFormat:@"%@: origin = {%.4f, %.4f}", [self title], origin.x, origin.y];
}

/* subclassed methods
 */

/*
 * returns the selected knob or -1
 */
- (int)selectedKnobIndex
{
    return -1;
}

/*
 * set the selection of the plane
 */
- (void)setSelected:(BOOL)flag
{
    [super setSelected:flag];
}

/*
 * draws the line
 */
- (void)drawWithPrincipal:principal
{   NSPoint		p = origin;
    NSBezierPath	*bPath = [NSBezierPath bezierPath];

    [bPath setLineWidth:0.0];
    [[NSColor blackColor] set];
    [bPath moveToPoint:NSMakePoint(p.x, p.y-14.0)];
    [bPath lineToPoint:NSMakePoint(p.x, p.y+14.0)];
    [bPath moveToPoint:NSMakePoint(p.x-14, p.y)];
    [bPath lineToPoint:NSMakePoint(p.x+14, p.y)];
    [bPath moveToPoint:NSMakePoint(p.x+7, p.y)];
    [bPath appendBezierPathWithArcWithCenter:p radius:7.0 startAngle:0.0 endAngle:360.0];
    [bPath stroke];

    [bPath removeAllPoints];
    [[NSColor whiteColor] set];
    [bPath moveToPoint:p];
    [bPath lineToPoint:p];
    [bPath moveToPoint:NSMakePoint(p.x+7, p.y)];
    [bPath lineToPoint:NSMakePoint(p.x+7, p.y)];
    [bPath moveToPoint:NSMakePoint(p.x-7, p.y)];
    [bPath lineToPoint:NSMakePoint(p.x-7, p.y)];
    [bPath moveToPoint:NSMakePoint(p.x, p.y+7)];
    [bPath lineToPoint:NSMakePoint(p.x, p.y+7)];
    [bPath moveToPoint:NSMakePoint(p.x, p.y-7)];
    [bPath lineToPoint:NSMakePoint(p.x, p.y-7)];
    [bPath stroke];
}

/*
 * Returns the bounds.
 */
- (NSRect)coordBounds
{   NSRect	bRect;

    bRect.origin.x = origin.x - 15;
    bRect.origin.y = origin.y - 15;
    bRect.size.width = bRect.size.height = 30;
    return bRect;
}

- (void)constrainPoint:(NSPoint *)aPt andNumber:(int)pt_num toView:aView
{   NSPoint		viewMax;
    NSRect		viewRect;

    viewRect = [aView bounds];
    viewMax.x = viewRect.origin.x + viewRect.size.width;
    viewMax.y = viewRect.origin.y + viewRect.size.height;

    aPt->x = MAX(viewRect.origin.x, aPt->x);
    aPt->y = MAX(viewRect.origin.y, aPt->y);

    aPt->x = MIN(viewMax.x, aPt->x);
    aPt->y = MIN(viewMax.y, aPt->y);
}

/*
 * created:   25.09.95
 * modified:
 * parameter: pt_num	number of vertices
 *            p		the new position in
 * purpose:   Sets a vertice to a new position.
 *            If it is a edge move the vertices with it
 */
- (void)movePoint:(int)pt_num to:(NSPoint)p
{
    origin = p;
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
}

/* The pt argument holds the relative point change. */
- (void)moveBy:(NSPoint)pt
{
    origin.x += pt.x;
    origin.y += pt.y;
}

/* Given the point number, return the point.
 */
- (NSPoint)pointWithNum:(int)pt_num
{
    return origin; 
}

/*
 * Check for a edge point hit.
 * parameter: p			the mouse position
 *            fuzz		the distance inside we snap to a point
 *            pt		the edge point
 *            controlsize	the size of the controls
 */
- (BOOL)hitEdge:(NSPoint)p fuzz:(float)fuzz :(NSPoint*)pt :(float)controlsize
{   NSRect	knobRect, hitRect;

    hitRect.origin.x = p.x -fuzz/2.0;
    hitRect.origin.y = p.y -fuzz/2.0;
    hitRect.size.width = hitRect.size.height = fuzz;
    knobRect.size.width = knobRect.size.height = controlsize;

    knobRect.origin.x = origin.x - controlsize/2.0;
    knobRect.origin.y = origin.y - controlsize/2.0;
    if (!NSIsEmptyRect(NSIntersectionRect(hitRect , knobRect)))
    {	*pt = origin;
        return YES;
    }

    return NO;
}

/*
 * Check for a control point hit.
 * Return the point number hit in the pt_num argument.
 */
- (BOOL)hitControl:(NSPoint)p :(int*)pt_num controlSize:(float)controlsize
{   NSRect	knobRect;

    knobRect.size.width = knobRect.size.height = controlsize;
    knobRect.origin.x = origin.x - controlsize/2.0;
    knobRect.origin.y = origin.y - controlsize/2.0;
    if ( NSPointInRect(p, knobRect) )
    {	*pt_num = 0;
        return YES;
    }
    return NO;
}

- (BOOL)hit:(NSPoint)p fuzz:(float)fuzz
{
    if ( SqrDistPoints(origin, p) <= (7.0+fuzz) * (7.0+fuzz) )
        return YES;
    return NO;
}


- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [super encodeWithCoder:aCoder];
    //[aCoder encodeValuesOfObjCTypes:"{NSPoint=ff}", &origin];
    [aCoder encodePoint:origin];            // 2012-01-08
}
- (id)initWithCoder:(NSCoder *)aDecoder
{   int	version;

    [super initWithCoder:aDecoder];
    version = [aDecoder versionForClassName:@"VCrosshairs"];
    if ( version < 1 )
        [aDecoder decodeValuesOfObjCTypes:"{ff}", &origin];
    else
        //[aDecoder decodeValuesOfObjCTypes:"{NSPoint=ff}", &origin];
        origin = [aDecoder decodePoint];    // 2012-01-08

    return self;
}

/* archiving with property list
 */
- (id)propertyList
{   NSMutableDictionary	*plist = [super propertyList];

    [plist setObject:propertyListFromNSPoint(origin) forKey:@"origin"];
    return plist;
}
- (id)initFromPropertyList:(id)plist inDirectory:(NSString *)directory
{
    [super initFromPropertyList:plist inDirectory:directory];
    origin = pointFromPropertyList([plist objectForKey:@"origin"]);
    return self;
}

@end
