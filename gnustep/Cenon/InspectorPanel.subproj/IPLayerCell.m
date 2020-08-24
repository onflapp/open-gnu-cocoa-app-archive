/* IPLayerCell.m
 * part of IPAllLayers
 *
 * Copyright (C) 1996-2006 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * Created:  1996-03-07
 * Modified: 2006-11-08
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
#include <VHFShared/vhfCommonFunctions.h>
#include "../messages.h"
#include "../App.h"
#include "../MoveMatrix.h"
#include "../MoveCell.h"
#include "../LayerObject.h"
#include "IPLayerCell.h"
#include "IPAllLayers.h"

#define IMAGEMARGIN 4.0

static	NSImage	*showImage = nil;	// static declared, so we can keep one
static	NSImage	*altShowImage = nil;	// instance of the icons for all classes
static	NSImage	*editImage = nil;
static	NSImage	*altEditImage = nil;
static	NSImage	*colorImage = nil;


@implementation IPLayerCell

- init
{
    self = [super init];

    if (!showImage)
    {	showImage = [NSImage imageNamed:@"eyeclosed"];
        altShowImage = [NSImage imageNamed:@"eye"];

        editImage = [NSImage imageNamed:@"pencil"];
        altEditImage = [NSImage imageNamed:@"pencilBroken"];

        colorImage = [NSImage imageNamed:@"NSSwitch"];
    }

    return self;
}	


- (void)setLayerObject:(LayerObject*)theLayerObject
{
    [layerObject release];
    layerObject = [theLayerObject retain];
    [self setStringValue:[layerObject string]];
}
- (LayerObject*)layerObject
{
    return layerObject;
}

- (BOOL)dependant
{
    return ([layerObject type] == LAYER_PASSIVE) ? YES : NO;
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{   NSRect	rect = cellFrame;
    NSPoint	imageOrigin;
    NSSize	imageSize = NSZeroSize;
    float	textSize = 0.0;
    static id	sharedTextCell = nil;
    NSRect	splitRect = cellFrame;

    [controlView lockFocus];

    if (showImage)
    {
        [(([self state] || [self isHighlighted ]) ? [NSColor selectedControlColor]
                                                  : [NSColor controlBackgroundColor]) set];
        NSRectFill(cellFrame);

        imageSize = [([layerObject state] ? altShowImage : showImage) size];
        (&rect)->size.width -= (imageSize.width + IMAGEMARGIN * 2.0);
        (&rect)->origin.x += imageSize.width + IMAGEMARGIN * 2.0;

        imageSize = [([layerObject editable] ? editImage : altEditImage) size];
        (&rect)->size.width -= (imageSize.width + IMAGEMARGIN * 2.0);
        (&rect)->origin.x += imageSize.width + IMAGEMARGIN * 2.0;

        textSize = NSWidth(rect) / 2.5;
        (&rect)->size.width -= textSize;
        (&rect)->origin.x += textSize;
    }

    imageOrigin.x = NSMinX(cellFrame) + IMAGEMARGIN;
    [[NSColor blackColor] set];	// be sure alpha is off

    /* draw display state icon (eye) */
    if (showImage)
    {
        imageOrigin.y = NSMinY(cellFrame) + NSHeight(cellFrame) - (NSHeight(cellFrame) - imageSize.height)/2.0;
        [([layerObject state] ? altShowImage : showImage) compositeToPoint:imageOrigin
                                                                 operation:NSCompositeSourceOver];
        imageOrigin.x += IMAGEMARGIN + imageSize.width;
    }

    /* draw edit icon (pencil) */
    if (editImage)
    {
        if ( [layerObject type] != LAYER_PASSIVE )
        {
            imageOrigin.y = NSMinY(cellFrame)+NSHeight(cellFrame)-(NSHeight(cellFrame)-imageSize.height)/2.0;
            [([layerObject editable] ? editImage : altEditImage) compositeToPoint:imageOrigin
                                                                        operation:NSCompositeSourceOver];
        }
        imageOrigin.x += IMAGEMARGIN + imageSize.width;
    }

    if (!sharedTextCell)
    {   sharedTextCell = [[NSCell alloc] init];
        [sharedTextCell setWraps:NO];
    }
    [sharedTextCell setFont:[self font]];

    /* draw layer string */
    if ( [layerObject string] )
    {   //NSFont  *defaultFont = nil;

        splitRect.origin.x = imageOrigin.x;
        splitRect.size.width = cellFrame.size.width - (imageOrigin.x-cellFrame.origin.x);
        imageOrigin.y = NSMinY(cellFrame)+NSHeight(cellFrame)-(NSHeight(cellFrame)-imageSize.height)/2.0;
        [sharedTextCell setStringValue:[layerObject string]];
        /* TODO: IPLayerCell: allow text to be fixed pitch for certain modules or other reason
        if ( [[moveMatrix target] isFixedPitchFont] )   // target == IPAllLayer
        {   defaultFont = [sharedTextCell font];
            [sharedTextCell setFont:[NSFont userFixedPitchFontOfSize:[defaultFont pointSize]]];
        }*/
        [sharedTextCell drawInteriorWithFrame:splitRect inView:controlView];
        //if ( defaultFont )
        //    [sharedTextCell setFont:defaultFont];     // restore defaultFont
        imageOrigin.x += IMAGEMARGIN + textSize;
    }

    [controlView unlockFocus];
}

- (BOOL)trackMouse:(NSEvent *)theEvent inRect:(NSRect)cellFrame ofView:(NSView *)aView
      untilMouseUp:(BOOL)_untilMouseUp
{   NSRect	rect;
    NSPoint	p;
    NSSize	imageSize;
    NSEvent	*ep;
    BOOL	doubleClick = NO;
    float	textWidth;
    //id		delegate = [moveMatrix delegate];

    /* get the mouse event, but we don't remove it from the event queue.
     * FIXME: somehow a single click here adds up to a double click which
     *        is handled by MoveMatrix. That's why we disabled double clicks there. 
     */
    ep = [NSApp nextEventMatchingMask:NSLeftMouseDownMask
                            untilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]
                               inMode:NSEventTrackingRunLoopMode dequeue:NO];
    if (ep && [ep clickCount] >= 2)
    {	doubleClick = YES;
        [NSApp nextEventMatchingMask:NSLeftMouseUpMask untilDate:[NSDate distantFuture]
                              inMode:NSEventTrackingRunLoopMode dequeue:YES];
    }

    rect = [aView convertRect:cellFrame toView:nil];
    p = [theEvent locationInWindow];

    /* color rect */
    imageSize = [showImage size];
    //rect.origin.x += IMAGEMARGIN + imageSize.width;

    if (showImage)
    {
        rect.size = [([layerObject state] ? altShowImage : showImage) size];
        rect.size.width += IMAGEMARGIN;
        if (NSMouseInRect(p , rect , NO))	// click to visible / invisible
        {   [layerObject setState:([layerObject state]) ? NO : YES];
            [self drawInteriorWithFrame:cellFrame inView:aView];
            [[moveMatrix window] flushWindow];

            if ( ![[moveMatrix target] updateLayerLists] )	// war die einzige Lage
            {	[layerObject setState:YES];
                [self drawInteriorWithFrame:cellFrame inView:aView];
                [[moveMatrix window] flushWindow];
                NSBeep();
            }
            [[moveMatrix target] displayChanged:self];
        }
        rect.origin.x += IMAGEMARGIN + imageSize.width;
    }

    if (editImage)
    {	rect.size = [([layerObject state]==YES ? editImage : altEditImage) size];
        rect.size.width += IMAGEMARGIN;
        if (NSMouseInRect(p , rect , NO))	// click to edit/unedit
        {   BOOL	stateChanged = NO;

            if ( ![layerObject state] && ![layerObject editable] )	// layerObject will switch state on
                stateChanged = YES;
            [layerObject setEditable:([layerObject editable]) ? NO : YES];
            if (stateChanged)
                [[moveMatrix target] displayChanged:self];		// but doesn't know of view
            [self drawInteriorWithFrame:cellFrame inView:aView];			
            [[moveMatrix window] flushWindow];
        }
        rect.origin.x += IMAGEMARGIN + imageSize.width;
    }

    /* layer string */
    {
        textWidth = cellFrame.size.width - rect.origin.x;
        rect.size.width = textWidth + IMAGEMARGIN;
        if (doubleClick && NSMouseInRect(p, rect, NO))
            [moveMatrix performSelector:@selector(sendDoubleAction) withObject:nil afterDelay:0.0];
        rect.origin.x += IMAGEMARGIN + textWidth;
    }

//    [[moveMatrix window] updateColorWell];
    return [super trackMouse:theEvent inRect:cellFrame ofView:aView untilMouseUp:NO];
}


- (void)cellDidChangeSide:sender
{
}

- (void)dealloc
{
    [layerObject release];
    [super dealloc];
}

@end
