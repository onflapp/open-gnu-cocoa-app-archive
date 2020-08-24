/* SliderBox.m
 * Slider box used in IPAllFilling
 *
 * Copyright (C) 2002-2002 by vhf interservice GmbH
 * Author:   Ilonka Fleischmann
 *
 * created:  2002-07-10
 * modified: 2002-07-19
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
//#include <VHFShared/VHFSystemAdditions.h>
#include "SliderBox.h"

#define SB_KNOBSIZE 5

@implementation SliderBox

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent
{
    return YES;
}

- (void)setTarget:(id)t
{
    target = t;
}
- (void)setAction:(SEL)a
{
    action = a;
}

- (void)setLocation:(NSPoint)p
{   NSRect	bounds = [self bounds];

    bounds = NSInsetRect(bounds, ceil(SB_KNOBSIZE/2.0)+2.0, ceil(SB_KNOBSIZE/2.0)+2.0);
    if (SB_KNOBSIZE-ceil(SB_KNOBSIZE)) bounds.origin.x += 1.0;
    if (SB_KNOBSIZE-ceil(SB_KNOBSIZE)) bounds.size.height -= 1.0;
    location.x = bounds.origin.x + bounds.size.width * p.x;
    location.y = bounds.origin.y + bounds.size.height * p.y;
    [self setNeedsDisplay:YES];
}

- (NSPoint)locationInPercent
{   NSPoint	p;
    NSRect	bounds = [self bounds];

    bounds = NSInsetRect(bounds, ceil(SB_KNOBSIZE/2.0)+2.0, ceil(SB_KNOBSIZE/2.0)+2.0);
    if (SB_KNOBSIZE-ceil(SB_KNOBSIZE)) bounds.origin.x += 1.0;
    if (SB_KNOBSIZE-ceil(SB_KNOBSIZE)) bounds.size.height -= 1.0;
    p.x = (location.x - bounds.origin.x)/bounds.size.width;
    p.y = (location.y - bounds.origin.y)/bounds.size.height;

    return p;
}

- (void)drawKnob
{   NSRect	rect = NSMakeRect(((int)location.x)-SB_KNOBSIZE/2.0, ((int)location.y)-SB_KNOBSIZE/2.0, SB_KNOBSIZE, SB_KNOBSIZE);

    [self lockFocus];
    [[NSColor blackColor] set];
    NSDrawButton(rect, rect);
    [self unlockFocus];
}
- (void)setEnabled:(BOOL)flag
{
    enabled = flag;
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)rect
{
    [super drawRect:rect];
    NSDrawGrayBezel(rect, rect);
    if (enabled)
        [self drawKnob];
}

- (void)mouseDown: (NSEvent *)theEvent
{
    NSApplication	*app = [NSApplication sharedApplication];
    unsigned int	eventMask = NSLeftMouseDownMask | NSLeftMouseUpMask      | NSPeriodicMask
                                                        | NSLeftMouseDraggedMask | NSMouseMovedMask;
    NSPoint		point = [self convertPoint: [theEvent locationInWindow] fromView: nil];
    NSEventType		eventType = [theEvent type];
    NSDate		*distantFuture = [NSDate distantFuture];

    NSRect		bounds = [self bounds], locRect;
    NSPoint		ll, ur;

    if (!enabled)
        return;

    locRect = NSMakeRect(location.x, location.y, SB_KNOBSIZE, SB_KNOBSIZE);
    bounds = NSInsetRect(bounds, ceil(SB_KNOBSIZE/2.0)+2.0, ceil(SB_KNOBSIZE/2.0)+2.0);
    ll = bounds.origin;
    if (SB_KNOBSIZE-ceil(SB_KNOBSIZE)) ll.x += 1.0;
    ur = NSMakePoint(bounds.origin.x+bounds.size.width, bounds.origin.y+bounds.size.height);
    if (SB_KNOBSIZE-ceil(SB_KNOBSIZE)) ur.y -= 1.0;

    if (point.x > ur.x)      location.x = ur.x;
    else if (point.x < ll.x) location.x = ll.x;
    else                     location.x = point.x;
    if (point.y > ur.y)      location.y = ur.y;
    else if (point.y < ll.y) location.y = ll.y;
    else                     location.y = point.y;
    [self setNeedsDisplay:YES];

    [NSEvent startPeriodicEventsAfterDelay: 0.05 withPeriod: 0.05];
    [[NSRunLoop currentRunLoop] limitDateForMode: NSEventTrackingRunLoopMode];

    do
    {
        if (eventType != NSPeriodic)
            point = [self convertPoint: [theEvent locationInWindow] fromView: nil];
        else
            point = [self convertPoint:[[self window] mouseLocationOutsideOfEventStream] fromView:nil];

        if (point.x > ur.x)      location.x = ur.x;
        else if (point.x < ll.x) location.x = ll.x;
        else                     location.x = point.x;

        if (point.y > ur.y)      location.y = ur.y;
        else if (point.y < ll.y) location.y = ll.y;
        else                     location.y = point.y;

        [self setNeedsDisplay:YES];

        if (target)
            [target performSelector:action withObject:self];

        theEvent = [app nextEventMatchingMask: eventMask
                                    untilDate: distantFuture
                                       inMode: NSEventTrackingRunLoopMode
                                      dequeue: YES];
        eventType = [theEvent type];
    } while (eventType != NSLeftMouseUp);
    [NSEvent stopPeriodicEvents];

//    if (target)
//        [target performSelector:action withObject:self];
}

@end
