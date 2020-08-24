/* VMark.m
 * Drill marker or any other marking
 *
 * Copyright (C) 1996-2010 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1997-11-13
 * modified: 2010-07-28 (-initFromPropertyList:, -propertyList, -setName:, name: use label now)
 *           2009-12-25 (description added)
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
#include "VMark.h"
#include "VPath.h"
#include "VArc.h"
#include "../App.h"
#include "../DocView.h"
#include "../DocWindow.h"
#include "../Inspectors.h"

@interface VMark(PrivateMethods)
- (void)setParameter;
@end

@implementation VMark

/* This sets the class version so that we can compatibly read old objects out of an archive.
 */
+ (void)initialize
{
    [VMark setVersion:3];
    return;
}

+ (id)markWithOrigin:(NSPoint)o diameter:(float)dia
{   id	mark = [[VMark new] autorelease];

    [mark setOrigin:o];
    [mark setDiameter:dia];
    return mark;
}

/* initialize
 */
- init
{
    [self setParameter];
    return [super init];
}

/*
 * created:  1995-09-25
 * purpose: initializes all the stuff needed after a -read:
 */
- (void)setParameter
{
}

- (NSString*)description
{
    return [NSString stringWithFormat:@"%@: origin = {%.4f, %.4f, %.4f}, dia = %.4f", [self title], origin.x, origin.y, z, diameter];
}

- (NSString*)title                  { return @"Mark"; }

- (void)setDiameter:(float)dia      { diameter = dia; }
- (float)diameter                   { return diameter; }
- (void)setOrigin:(NSPoint)pt       { origin = pt; }
- (NSPoint)origin                   { return origin; }

- (void)set3D:(BOOL)flag            { is3D = flag; }
- (BOOL)is3D                        { return is3D; }
- (void)setZ:(float)v               { z = v; is3D = YES; }
- (float)z                          { return z; }

/* Deprecated: use setLabel:, and -label from VGraphics */
- (void)setName:(NSString*)newName  { [label release]; label = [newName retain]; }
- (NSString*)name                   { return label; }

#define CREATEEVENTMASK NSLeftMouseDraggedMask|NSLeftMouseDownMask|NSLeftMouseUpMask|NSPeriodicMask
- (BOOL)create:(NSEvent *)event in:(DocView*)view
{   NSPoint	gridPoint, hitPoint;
    NSRect	viewBounds;
    BOOL	ok = YES, hitEdge;

//	[drawMarkGraphic setUseColor:YES];
//	[self setUseColor:YES];

    [[(App*)NSApp inspectorPanel] loadGraphic:self];	// set the values of the inspector to self

    /* get origin location, convert window to view coordinates */
    hitPoint = origin = [view convertPoint:[event locationInWindow] fromView:nil];
    hitEdge = [view hitEdge:&hitPoint spare:self];	// snap to point
    gridPoint = [view grid:origin];			// set on grid
    if ( hitEdge &&
         ((gridPoint.x == origin.x && gridPoint.y == origin.y)  ||
          (SqrDistPoints(hitPoint, origin) < SqrDistPoints(gridPoint, origin))) )
        origin = hitPoint; 				// we take the closer point if we got a hit
    else
        origin = gridPoint;

    viewBounds = [view visibleRect];			// get the bounds of the view

    ok = NSMouseInRect(origin , viewBounds , NO);

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

/* created:   1997-11-13
 * modified:  2006-01-17
 * parameter: x, y	the angles to rotate in x/y direction
 *            p		the point we have to rotate around
 * purpose:   draw the graphic rotated around p with x and y
 */
- (void)drawAtAngle:(float)angle withCenter:(NSPoint)cp in:view
{   NSPoint	p;
    float	radius = 5.0;

    [color set];
    [NSBezierPath setDefaultLineWidth:1.0/[view scaleFactor]];
    p = vhfPointRotatedAroundCenter(origin, -angle, cp);
    [NSBezierPath strokeLineFromPoint:NSMakePoint(p.x-radius, p.y)
                              toPoint:NSMakePoint(p.x+radius, p.y)];
    [NSBezierPath strokeLineFromPoint:NSMakePoint(p.x, p.y-radius)
                              toPoint:NSMakePoint(p.x, p.y+radius)];
}

/* created:   21.10.95
 * modified:  2001-11-25
 * parameter: x, y	the angles to rotate in x/y direction
 *            cp	the point we have to rotate around
 * purpose:   rotate the graphic around cp with x and y
 */
- (void)setAngle:(float)angle withCenter:(NSPoint)cp
{
    origin = vhfPointRotatedAroundCenter(origin, -angle, cp);
    dirty = YES;
}

- (void)scale:(float)x :(float)y withCenter:(NSPoint)cp
{
    origin.x = ScaleValue(origin.x, cp.x, x);
    origin.y = ScaleValue(origin.y, cp.y, y);
    dirty = YES;
}

- (void)mirrorAround:(NSPoint)p
{
    origin.y = p.y - (origin.y - p.y);
    dirty = YES;
}

/*
 * draws the mark
 */
- (void)drawWithPrincipal:principal
{   float	radius = 5.0;	// FIXME: shouldn't there exist a mode to display the diameter ???
    //float	radius = (displayDia) ? MMToInternal(diameter) : 5.0;
    //float   defaultWidth = [NSBezierPath defaultLineWidth];

    [super drawWithPrincipal:principal];	// color
    if (!VHFIsDrawingToScreen())
        [NSBezierPath setDefaultLineWidth:0.5];
    [NSBezierPath setDefaultLineWidth:[NSBezierPath defaultLineWidth]];
    [NSBezierPath strokeLineFromPoint:NSMakePoint(origin.x-radius, origin.y)
                              toPoint:NSMakePoint(origin.x+radius, origin.y)];
    [NSBezierPath strokeLineFromPoint:NSMakePoint(origin.x, origin.y-radius)
                              toPoint:NSMakePoint(origin.x, origin.y+radius)];
}

/*
 * Returns the bounds.  The flag variable determines whether the
 * knobs should be factored in. They may need to be for drawing but
 * might not if needed for constraining reasons.
 */
- (NSRect)coordBounds
{   float	radius = 5.0;
    NSRect	bRect;

    bRect.origin.x = origin.x - radius;
    bRect.origin.y = origin.y - radius;
    bRect.size.width = bRect.size.height = 2.0 * radius;

    return bRect;
}

/*
 * Returns the bounds with the given rotation.
 */
- (NSRect)boundsAtAngle:(float)angle withCenter:(NSPoint)cp
{   NSPoint	p;
    float	x0, y0, radius = 5.0;
    NSRect	bRect;

    p = origin;
    vhfRotatePointAroundCenter(&p, cp, -angle);
    x0 = p.x; y0 = p.y;

    bRect.origin.x = x0 - radius;
    bRect.origin.y = y0 - radius;
    bRect.size.width =  bRect.size.height = 2.0 * radius;

    return bRect;
}

/*
 * Depending on the pt_num passed in, return the rectangle
 * that should be used for scrolling purposes. When the rectangle
 * passes out of the visible rectangle then the screen should
 * scroll. If the first and last points are selected, then the second
 * and third points are included in the rectangle. If the second and
 * third points are selected, then they are used by themselves.
 */
- (NSRect)scrollRect:(int)pt_num inView:(id)aView
{   float	knobsize;
    NSRect	aRect;

    if (pt_num == -1)
        aRect = [self bounds];
    else
    {
        aRect.origin.x = origin.x;
        aRect.origin.y = origin.y;
        aRect.size.width = 0;
        aRect.size.height = 0;
    }
    knobsize = -[VGraphic maxKnobSizeWithScale:[aView scaleFactor]]/2.0;
    aRect = NSInsetRect(aRect , knobsize , knobsize);
    return aRect;
}

/* 
 * This method constains the point to the bounds of the view passed
 * in. Like the method above, the constaining is dependent on the
 * control point that has been selected.
 */
- (void)constrainPoint:(NSPoint *)aPt andNumber:(int)pt_num toView:(DocView*)aView
{	NSPoint		viewMax;
	NSRect		viewRect;

	viewRect = [aView bounds];
	viewMax.x = viewRect.origin.x + viewRect.size.width;
	viewMax.y = viewRect.origin.y + viewRect.size.height;

	viewMax.x -= MARGIN;
	viewMax.y -= MARGIN;
	viewRect.origin.x += MARGIN;
	viewRect.origin.y += MARGIN;

	aPt->x = MAX(viewRect.origin.x, aPt->x);
	aPt->y = MAX(viewRect.origin.y, aPt->y);

	aPt->x = MIN(viewMax.x, aPt->x);
	aPt->y = MIN(viewMax.y, aPt->y); 
}

/*
 * created:   13.11.97
 * modified:
 * parameter: pt_num	number of vertices
 *            p		the new position in
 * purpose:   Sets a vertice to a new position.
 */
- (void)movePoint:(int)pt_num to:(NSPoint)p
{
    origin = p;
    dirty = YES;
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

/* The pt argument holds the relative point change. */
- (void)moveBy:(NSPoint)pt
{
    [self movePoint:0 by:pt];
}

- (int)numPoints
{
    return PTS_MARK;
}

/* Given the point number, return the point.
 * Default must be p1
 */
- (NSPoint)pointWithNum:(int)pt_num
{
    return origin;
}

/*
 * Check for a edge point hit.
 * parameter: p	the mouse position
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
{   NSRect	bRect = [self bounds];

    bRect.origin.x -= fuzz;
    bRect.origin.y -= fuzz;
    bRect.size.width  += 2.0 * fuzz;
    bRect.size.height += 2.0 * fuzz;
    if ( NSPointInRect(p, bRect) )
        return YES;
    return NO;
}

- contour:(float)w
{   VLine	*line = [VLine line];

    [line setVertices:origin :origin];
    return line;
}

- (id)clippedWithRect:(NSRect)rect
{
    return ( NSPointInRect(origin, rect) ) ? self : nil;
}

- (BOOL)identicalWith:(VGraphic*)g
{   NSPoint	s2;

    if ( ![g isKindOfClass:[VMark class]] )
        return NO;

    [g getPoint:0 :&s2];
    if ( Diff(origin.x, s2.x) <= TOLERANCE && Diff(origin.y, s2.y) <= TOLERANCE )
        return YES;
    return NO;
}

- (float)sqrDistanceGraphic:g
{
    if ([g isKindOfClass:[VLine class]])
    {   NSPoint	p0, p1;

        [g getVertices:&p0 :&p1];
        return vhfSqrDistancePointLine(p0, p1, origin);
    }
    // FIXME
    /*else if ()
    {
        dist = [g sqrDistanceLine:origin :origin];
        return dist;
    }*/

    NSLog(@"VMark, distance with unknown class (%@)!", [g class]);
    return MAXCOORD;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [super encodeWithCoder:aCoder];
    //[aCoder encodeValuesOfObjCTypes:"{NSPoint=ff}", &origin];
    [aCoder encodePoint:origin];        // 2012-01-08
    [aCoder encodeValuesOfObjCTypes:"cf", &is3D, &z];
}
- (id)initWithCoder:(NSCoder *)aDecoder
{   int	version;

    [super initWithCoder:aDecoder];
    version = [aDecoder versionForClassName:@"VMark"];
    if ( version < 2 )
        [aDecoder decodeValuesOfObjCTypes:"{ff}", &origin];
    else
        //[aDecoder decodeValuesOfObjCTypes:"{NSPoint=ff}", &origin];
        origin = [aDecoder decodePoint];    // 2012-01-08
    [aDecoder decodeValuesOfObjCTypes:"cf", &is3D, &z];

    [self setParameter];

    return self;
}

/* archiving with property list
 */
- (id)propertyList
{   NSMutableDictionary	*plist = [super propertyList];

    [plist setObject:propertyListFromNSPoint(origin) forKey:@"origin"];
    if (is3D)
        [plist setObject:propertyListFromFloat(z) forKey:@"z"];
    //if ([name length])
    //    [plist setObject:name forKey:@"name"];

    return plist;
}
- (id)initFromPropertyList:(id)plist inDirectory:(NSString *)directory
{
    [super initFromPropertyList:plist inDirectory:directory];
    origin = pointFromPropertyList([plist objectForKey:@"origin"]);
    if ([plist objectForKey:@"z"])
    {
        z = [plist floatForKey:@"z"];
        is3D = YES;
    }
    if ( [plist objectForKey:@"name"] ) // legacy support, we have label in VGraphics now
        label = [[plist objectForKey:@"name"] retain];

    return self;
}


- (void)dealloc
{
    [super dealloc];
}

@end
