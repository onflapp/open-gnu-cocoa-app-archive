/* VThread.m
 * screw thread
 *
 * Copyright (C) 2000-2005 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  2000-07-12
 * modified: 2005-10-13
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
#include "../App.h"
#include "VThread.h"
#include "VCurve.h"
#include "../DocView.h"
#include "../DocWindow.h"
#include "../Inspectors.h"

@interface VThread(PrivateMethods)
@end

@implementation VThread

/*
 * This sets the class version so that we can compatibly read
 * old VGraphic objects out of an archive.
 */
+ (void)initialize
{
    [VThread setVersion:1];
    return;
}

- init
{
    [super init];
    begAngle = 0.0;
    angle = 360.0;
    radius = MMToInternal(3.0);	// M6
    pitch  = MMToInternal(1.0);	// M6
    return self;
}

/* deep copy
 *
 * created:  2003-04-16
 * modified: 
 */
- copy
{   id	thread = [super copy];

    [thread setPitch:pitch];
    [thread setExternal:external];
    return thread;
}

- (NSString*)title
{
    return @"Thread";
}

/* subclassed:
 * we only need the position
 */
#define CREATEEVENTMASK NSLeftMouseDraggedMask|NSLeftMouseDownMask|NSLeftMouseUpMask|NSPeriodicMask
- (BOOL)create:(NSEvent *)event in:(DocView*)view
{   NSRect	viewBounds;
    BOOL	ok = YES;

    [[(App*)NSApp inspectorPanel] loadGraphic:self];	// set the values of the inspector to self

    /* get start location, convert window to view coordinates */
    center = [view convertPoint:[event locationInWindow] fromView:nil];
    [view hitEdge:&center spare:self];			// snap to point
    center = [view grid:center];			// set on grid
    viewBounds = [view visibleRect];			// get the bounds of the view

    start = NSMakePoint(center.x + radius, center.y);
    [self calcAddedValues];

    ok = NSMouseInRect(center, viewBounds , NO);

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

/* subclassed:
 * we never change the direction this way, only when right turn is selected
 */
- (void)changeDirection
{
}

- (float)pitch
{
    return pitch;
}
- (void)setPitch:(float)v
{
    pitch = v; 
    dirty = YES;
}

- (BOOL)external
{
    return external;
}
- (void)setExternal:(BOOL)flag
{
    external = flag;
    dirty = YES;
}

/*
 * draws the thread
 */
- (void)drawWithPrincipal:principal
{
    [super drawWithPrincipal:principal];
    [NSBezierPath strokeLineFromPoint:NSMakePoint(center.x, center.y+radius)
                              toPoint:NSMakePoint(center.x, center.y-radius)];
    [NSBezierPath strokeLineFromPoint:NSMakePoint(center.x+radius, center.y)
                              toPoint:NSMakePoint(center.x-radius, center.y)];
}

- (NSRect)coordBounds
{   NSRect	bRect;

    bRect.origin.x = center.x - radius;
    bRect.origin.y = center.y - radius;
    bRect.size.width = bRect.size.height = 2.0 * radius;
    return bRect;
}

- (int)numPoints
{
    return PTS_THREAD;
}

/* Given the point number, return the point.
 * default must be the end point of the arc
 */
- (NSPoint)pointWithNum:(int)pt_num
{
    return center;
}

/*
 * Check for a control point hit.
 * Return the point number hit in the pt_num argument.
 */
- (BOOL)hitControl:(NSPoint)p :(int*)pt_num controlSize:(float)controlsize
{   NSRect	knobRect;
    NSPoint	pt = [self pointWithNum:PT_CENTER];

    knobRect.size.width = knobRect.size.height = controlsize;
    knobRect.origin.x = pt.x - controlsize/2.0;
    knobRect.origin.y = pt.y - controlsize/2.0;
    if ( NSPointInRect(p, knobRect) )
    {
        *pt_num = PT_CENTER;
        return YES;
    }
    return NO;
}

/*
 * return an arc representing the thread in a distance of w/2
 */
- (id)contour:(float)w
{   VThread	*thread = [[[VThread allocWithZone:[self zone]] init] autorelease];
    float	r;
    NSPoint	p;

    r = w / 2.0;	/* the amount of growth or shrink */
    if ( radius+r <= 0.0 )
        return nil;

    external = (w>0.0) ? YES : NO;	// outside correction = external thread

    p.x = center.x+radius+r;
    p.y = center.y;
    vhfRotatePointAroundCenter(&p, center, begAngle);
    [thread setWidth:0.0];
    [thread setPitch:pitch];
    [thread setExternal:external];
    [thread setColor:color];
    [thread setCenter:center start:p angle:angle];
    [thread setSelected:[self isSelected]];
    return thread;
}

- (id)clippedWithRect:(NSRect)rect
{
    return ( NSPointInRect(center, rect) ) ? self : nil;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [super encodeWithCoder:aCoder];
    [aCoder encodeValuesOfObjCTypes:"f", &pitch];
    [aCoder encodeValuesOfObjCTypes:"c", &external];
}
- (id)initWithCoder:(NSCoder *)aDecoder
{   int	version;

    [super initWithCoder:aDecoder];
    version = [aDecoder versionForClassName:@"VThread"];
    [aDecoder decodeValuesOfObjCTypes:"f", &pitch];
    if ( version >= 1 )
        [aDecoder decodeValuesOfObjCTypes:"c", &external];

    return self;
}

/* archiving with property list
 */
- (id)propertyList
{   NSMutableDictionary	*plist = [super propertyList];

    //[plist setObject:propertyListFromFloat(pitch) forKey:@"pitch"];
    //if (external) [plist setObject:@"YES" forKey:@"external"];
    return plist;
}
- (id)initFromPropertyList:(id)plist inDirectory:(NSString *)directory
{
    [super initFromPropertyList:plist inDirectory:directory];
    //pitch = [plist floatForKey:@"pitch"];
    //external = ([plist objectForKey:@"external"] ? YES : NO);
    return self;
}

@end
