/* CVLFileIconWellCell.m created by stephane on Tue 07-Sep-1999 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "CVLFileIconWellCell.h"
#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>

@implementation CVLFileIconWellCell

- (void) setDataSource:(id)aDataSource
{
    dataSource = aDataSource;
}

- (id) dataSource
{
    return dataSource;
}

- (NSString *) filename
{
    NSArray	*filenames = [self filenames];

    if(filenames && [filenames count] > 0)
        return [filenames objectAtIndex:0];
    return nil;
}

- (NSArray *) filenames
{
    return [[self controlView] filenamesForFileIconWellCell:self];
}

- (unsigned int) draggingSourceOperationMaskForLocal:(BOOL)flag
{
    return NSDragOperationCopy || NSDragOperationLink;
}

- (NSImage *) image
{
    NSArray	*filenames = [self filenames];
    int		count = filenames ? [filenames count]:0;

    switch(count){
        case 0:
            return [NSImage imageNamed:@"EmptyImage"];
        case 1:
            return [[NSWorkspace sharedWorkspace] iconForFile:[filenames objectAtIndex:0]];
        default:
            return [NSImage imageNamed:@"multiple"];
    }
}

- (void) reloadData
{
    [_iconWellControlView updateCell:self];
}

- (void) drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
    [self setImage:[self image]];
    [super drawInteriorWithFrame:cellFrame inView:controlView];
}

- (void) drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
    _iconWellControlView = (NSControl *)controlView;
    [super drawWithFrame:cellFrame inView:controlView];
}

- (void) highlight:(BOOL)flag withFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
    _iconWellControlView = (NSControl *)controlView;
    [super highlight:flag withFrame:cellFrame inView:controlView];
}

- (BOOL) startTrackingAt:(NSPoint)startPoint inView:(NSView *)controlView
{
    _iconWellControlView = (NSControl *)controlView;
    return [super startTrackingAt:startPoint inView:controlView];
}

- (BOOL) continueTracking:(NSPoint)lastPoint at:(NSPoint)currentPoint inView:(NSView *)controlView
{
    _iconWellControlView = (NSControl *)controlView;
    return [super continueTracking:lastPoint at:currentPoint inView:controlView];
}

- (void) stopTracking:(NSPoint)lastPoint at:(NSPoint)stopPoint inView:(NSView *)controlView mouseIsUp:(BOOL)flag
{
    _iconWellControlView = (NSControl *)controlView;
    [super stopTracking:lastPoint at:stopPoint inView:controlView mouseIsUp:flag];
}

- (BOOL) trackMouse:(NSEvent *)theEvent inRect:(NSRect)cellFrame ofView:(NSView *)controlView untilMouseUp:(BOOL)flag
{
    _iconWellControlView = (NSControl *)controlView;
    return [super trackMouse:theEvent inRect:cellFrame ofView:controlView untilMouseUp:flag];
}

- (void) editWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject event:(NSEvent *)theEvent
{
    _iconWellControlView = (NSControl *)controlView;
    [super editWithFrame:aRect inView:controlView editor:textObj delegate:anObject event:theEvent];
}

- (void) selectWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject start:(int)selStart length:(int)selLength;
{
    _iconWellControlView = (NSControl *)controlView;
    [super selectWithFrame:aRect inView:controlView editor:textObj delegate:anObject start:selStart length:selLength];
}

- (void) resetCursorRect:(NSRect)cellFrame inView:(NSView *)controlView;
{
    _iconWellControlView = (NSControl *)controlView;
    [super resetCursorRect:cellFrame inView:controlView];
}

- (NSControl *) controlView
{
    return _iconWellControlView;
}

- (id) target
{
    return _target;
}

- (void) setTarget:(id)anObject
{
    _target = anObject;
}

- (SEL) doubleAction
{
    return _doubleAction;
}

- (void) setDoubleAction:(SEL)aSelector
{
    _doubleAction = aSelector;
}

@end
