/*
 * VWeb.m
 *
 * Copyright (C) 1996-2002 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1999-05-03
 * modified: 2002-07-09
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
#include "VWeb.h"
#include "VPath.h"
#include "VArc.h"
#include "../App.h"
#include "../DocView.h"
#include "../DocWindow.h"
#include "../Inspectors.h"

@interface VWeb(PrivateMethods)
- (void)setParameter;
@end

@implementation VWeb

/* initialize
 */
- init
{
    [self setParameter];
    width = 5.669;
    return [super init];
}

/*
 * created: 25.09.95
 * purpose: initializes all the stuff needed after a -read:
 */
- (void)setParameter
{
}

- (NSString*)title
{
    return @"Web";
}

/*
 * draws the web
 */
- (void)drawWithPrincipal:principal
{
    [self drawColorPale:[principal mustDrawPale]];	// color
    NSRectFill(NSMakeRect(origin.x-width/2.0, origin.y-width/2.0, width, width));

    [[NSColor whiteColor] set];
    [NSBezierPath setDefaultLineWidth:[NSBezierPath defaultLineWidth]];
    [NSBezierPath strokeLineFromPoint:NSMakePoint(origin.x-width/2.0, origin.y)
                              toPoint:NSMakePoint(origin.x+width/2.0, origin.y)];
    [NSBezierPath strokeLineFromPoint:NSMakePoint(origin.x, origin.y-width/2.0)
                              toPoint:NSMakePoint(origin.x, origin.y+width/2.0)];
}

/*
 * Returns the bounds.  The flag variable determines whether the
 * knobs should be factored in. They may need to be for drawing but
 * might not if needed for constraining reasons.
 */
- (NSRect)coordBounds
{
    return [self bounds];
}
- (NSRect)bounds
{   NSRect	bRect;

    bRect.origin.x = origin.x - width/2.0;
    bRect.origin.y = origin.y - width/2.0;
    bRect.size.width = bRect.size.height = width;
    return bRect;
}

/*
 * Returns the bounds with the given rotation.
 */
- (NSRect)boundsAtAngle:(float)angle withCenter:(NSPoint)cp
{   NSPoint	p;
    float	x0, y0;
    NSRect	bRect;

    p = origin;
    vhfRotatePointAroundCenter(&p, cp, -angle);
    x0 = p.x; y0 = p.y;

    bRect.origin.x = x0 - width/2.0;
    bRect.origin.y = y0 - width/2.0;
    bRect.size.width =  bRect.size.height = width;

    return bRect;
}

@end
