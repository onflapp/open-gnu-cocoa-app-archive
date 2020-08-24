/* ProgressIndicator.m
 * progress indicator
 *
 * Copyright (C) 2004 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  2004-07-07
 * modified: 2004-08-21
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
#include <math.h>			// floor()
#include <VHFShared/vhfCompatibility.h>	// PSWait()
#include "ProgressIndicator.h"

@implementation ProgressIndicator

- initWithFrame:(NSRect)frameRect
{
    [super initWithFrame:frameRect];
    displayCells = YES;
    return self;
}

- (void)setDisplayText:(BOOL)flag	{ displayText = flag; }
- (void)setDisplayCells:(BOOL)flag	{ displayCells = flag; }

- (void)setPercentNumber:(NSNumber*)p
{
    percent = [p floatValue];
    [self display];
    PSWait();
}
- (void)setPercent:(float)p
{
    percent = p;
    [self setNeedsDisplay:YES];
}
- (float)percent
{
    return percent;
}

/* set the background title under the progress bar
 */
- (void)setTitle:(NSString*)string
{
    [title release];
    title = [string retain];
    [self display];
    PSWait();
}

/* draw a growing bar from left to right
 * The progress is indicated by colors from red to green
 */
#define TEXT_WIDTH	35	// with of text ("100%")
#define CELL_DIVISION	20
- (void)draw
{   static id	sharedTextCell = nil;
    NSRect	bounds = [self bounds];
    NSRect	insetRect = NSInsetRect(bounds, 1, 1), r;
    int		i;
    float	cellWidth, x;

    if (!sharedTextCell)
    {   sharedTextCell = [[NSCell alloc] init];
        [sharedTextCell setWraps:NO];
        [sharedTextCell setFont:[NSFont systemFontOfSize:10.0]];
    }

    [self lockFocus];

    /* color bar */
    for (x=1; x<percent*insetRect.size.width; x++)
    {   float	h = x/(insetRect.size.width-1) * 1.0/3.0;	// red = 0, green = 1/3

        [[NSColor colorWithCalibratedHue:h saturation:0.7 brightness:1.0 alpha:1.0] set];
        r = NSMakeRect(x, insetRect.origin.y, 1.0, insetRect.size.height);
        NSRectFill(r);
    }

    /* cell frames every 5% */
    if (displayCells)
    {
        cellWidth = insetRect.size.width / CELL_DIVISION;
        [[NSColor darkGrayColor] set];
        for (i=0; i<=CELL_DIVISION; i++)
        {
            r = NSMakeRect(insetRect.origin.x, insetRect.origin.y,
                           floor(i*cellWidth+.5), insetRect.size.height);
            NSFrameRect(r);
        }
    }

    /* title */
    if (title)
    {
        r = NSMakeRect(bounds.origin.x, bounds.origin.y + bounds.size.height / 2.0 - 5.0,
                       bounds.size.width, 12);
        [sharedTextCell setEnabled:YES];
        [sharedTextCell setAlignment:NSCenterTextAlignment];
        [sharedTextCell setStringValue:title];
        [sharedTextCell drawInteriorWithFrame:r inView:self];
    }

    /* text "100%" */
    if (displayText)
    {
        r = NSMakeRect(bounds.origin.x + bounds.size.width - TEXT_WIDTH,
                       bounds.origin.y + bounds.size.height / 2.0 - 3.0,
                       TEXT_WIDTH, 10);
        [sharedTextCell setEnabled:YES];
        [sharedTextCell setStringValue:[NSString stringWithFormat:@"%.0f%%", percent*100.0]];
        [sharedTextCell drawInteriorWithFrame:r inView:self];
    }

    /* gray progress bar */
    //r = NSMakeRect(insetRect.origin.x, insetRect.origin.y,
    //               percent * insetRect.size.width, insetRect.size.height);
    //[[NSColor blackColor] set];
    //NSDrawButton(rect, rect);

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
        [self draw];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}


/*
 * Notifications
 */

/* update progress indicator
 */
- (void)progress:(NSNotification*)notification
{   NSDictionary	*dict = [notification object];
    float		p = [[dict objectForKey:@"percent"] floatValue];

    [self setPercent:p];
    //printf("%d%%\n", percent);
}

@end
