/* CVLFileIconWell.m created by stephane on Tue 07-Sep-1999 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "CVLFileIconWell.h"
#import "CVLFileIconWellCell.h"
#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>


@implementation CVLFileIconWell

+ (void) initialize
{
    [super initialize];
    [self setCellClass:[self cellClass]];
}

+ (Class) cellClass
{
    return [CVLFileIconWellCell class];
}

- (void) setDataSource:(id)aDataSource
{
    // aDataSource must respond to CVLFileIconWellDataSource informal protocol
    NSParameterAssert(!aDataSource || [aDataSource respondsToSelector:@selector(filenamesForFileIconWell:)]);
    [[self cell] setDataSource:aDataSource];
}

- (id) dataSource
    // Comes from cell
{
    return [[self cell] dataSource];
}

- (NSString *) filename
    // Comes from cell
{
    return [[self cell] filename];
}

- (NSArray *) filenames
    // Comes from cell
{
    return [[self cell] filenames];
}

- (void) mouseDown:(NSEvent *)anEvent
{
    // We should add an hysteresis...
    NSArray	*filenames = [[self cell] filenames];
    int		aCount = [filenames count];

    if(aCount != 0){
        if([anEvent clickCount] == 2){
            SEL	aSelector = [self doubleAction];

            if(aSelector != NULL)
                if(![self sendAction:aSelector to:[self target]])
                    NSBeep();
        }
        else if(!_delegate || ![_delegate respondsToSelector:@selector(iconWellShouldStartDragging:)] || [_delegate iconWellShouldStartDragging:self]){
            BOOL	keepOn = YES;
            NSRect	trackRect;
            BOOL	doDragging = NO;
            NSEvent	*originalEvent = [anEvent retain];
            NSPoint	mouseLoc = [self convertPoint:[anEvent locationInWindow] fromView:nil];

            // Hysteresis
            trackRect.origin = mouseLoc;
            trackRect.origin.x -= 2;
            trackRect.origin.y -= 2;
            trackRect.size.width = 4;
            trackRect.size.height = 4;

            do{
                mouseLoc = [self convertPoint:[anEvent locationInWindow] fromView:nil];

                switch([anEvent type]){
                    case NSLeftMouseDragged:
                        if(!NSPointInRect(mouseLoc, trackRect)){
                            doDragging = YES;
                            keepOn = NO;
                        }
                        break;
                    case NSLeftMouseUp:
                        keepOn = NO;
                        break;
                    default:
                        /* Ignore any other kind of event. */
                        break;
                }

                anEvent = [[self window] nextEventMatchingMask: NSLeftMouseUpMask |
                    NSLeftMouseDraggedMask];

            }while(keepOn);

            if(doDragging){
                // On Windows, NSFilenamesPboardType AND NSStringPboardType are not
                // recognized by non-YB apps... Even D&D from PB does not work
                NSPasteboard	*pboard = [NSPasteboard pasteboardWithName:NSDragPboard];
                NSSize			offset;
                NSPoint			imageLoc;
				NSArray			*aTypeArray = nil;
				
                offset.width = NSMidX(trackRect) - mouseLoc.x;
                offset.height = NSMidY(trackRect) - mouseLoc.y;
                imageLoc.x = ([self bounds].size.width - [[[self cell] image] size].width) / 2;
                imageLoc.y = ([self bounds].size.height - [[[self cell] image] size].height) / 2;
				aTypeArray = [NSArray arrayWithObject:NSFilenamesPboardType];
                [pboard declareTypes:aTypeArray owner:nil];
                [pboard setPropertyList:filenames forType:NSFilenamesPboardType];
				[self dragImage:[[self cell] image] 
							 at:imageLoc 
						 offset:offset 
						  event:originalEvent 
					 pasteboard:pboard 
						 source:self 
					  slideBack:YES];
            }
            [originalEvent autorelease];
        }
    }
}

- (unsigned int) draggingSourceOperationMaskForLocal:(BOOL)flag
    // Comes from cell
{
    return [[self cell] draggingSourceOperationMaskForLocal:flag];
}

- (NSArray *) filenamesForFileIconWellCell:(CVLFileIconWellCell *)aFileIconWellCell
{
    return [[self dataSource] filenamesForFileIconWell:self];
}

- (BOOL) acceptsFirstMouse:(NSEvent *)theEvent
{
    return YES;
}

- (BOOL) shouldDelayWindowOrderingForEvent:(NSEvent *)theEvent
{
#warning (Stephane) Seems it is not enough...
    return YES;
}

- (BOOL) needsPanelToBecomeKey
{
    return NO;
}

- (void) reloadData
{
    [self setNeedsDisplay:YES];
}

- (void) setDelegate:(id)delegate
{
    _delegate = delegate;
}

- (id) delegate
{
    return _delegate;
}

- (id) target
{
    return [[self cell] target];
}

- (void) setTarget:(id)anObject
{
    [[self cell] setTarget:anObject];
}

- (SEL) doubleAction
{
    return [[self cell] doubleAction];
}

- (void) setDoubleAction:(SEL)aSelector
{
    [[self cell] setDoubleAction:aSelector];
}

@end
