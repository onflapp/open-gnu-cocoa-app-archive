//
//  SubviewTableViewCell.m
//  SubviewTableViewRuleEditor
//
//  Created by Joar Wingfors on Sat Feb 15 2003.
//  Copyright (c) 2003 joar.com. All rights reserved.
//

#import "SubviewTableViewCell.h"

#import "SubviewTableViewController.h"
#import "PXLayerDetailsView.h"

@implementation SubviewTableViewCell

- (void) addSubview:(NSView *) view
{
    // Weak reference
    subview = view;
}

- (void) dealloc
{
    subview = nil;
    [super dealloc];
}

- (NSView *) view
{
    return subview;
}

- (void) drawWithFrame:(NSRect) cellFrame inView:(NSView *) controlView
{
	if ([[self view] isKindOfClass:[PXLayerDetailsView class]])
	{
		if ([self isHighlighted])
		{
			[[[self view] opacityText] setTextColor:[NSColor whiteColor]];
		}
		else
		{
			[[[self view] opacityText] setTextColor:[NSColor blackColor]];		
		}
	}
    [super drawWithFrame: cellFrame inView: controlView];
    [[self view] setFrame: cellFrame];
    if([[self view] superview] != controlView)
    {
		[controlView addSubview:[self view]];
    }
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
    NSImage *gradient;
    /* Determine whether we should draw a blue or grey gradient. */
    /* We will automatically redraw when our parent view loses/gains focus, 
	or when our parent window loses/gains main/key status. */
    if (([[controlView window] firstResponder] == controlView) && 
		[[controlView window] isMainWindow] &&
		[[controlView window] isKeyWindow]) {
        gradient = [NSImage imageNamed:@"highlight_blue.tiff"];
    } else {
        gradient = [NSImage imageNamed:@"highlight_grey.tiff"];
    }
    
    /* Make sure we draw the gradient the correct way up. */
    [gradient setFlipped:YES];
    int i = 0;
    
    if ([self isHighlighted]) {
        [controlView lockFocus];
        
        /* We're selected, so draw the gradient background. */
        NSSize gradientSize = [gradient size];
        for (i = cellFrame.origin.x; i < (cellFrame.origin.x + cellFrame.size.width); i += gradientSize.width) {
            [gradient drawInRect:NSMakeRect(i, cellFrame.origin.y, gradientSize.width, cellFrame.size.height)
						fromRect:NSMakeRect(0, 0, gradientSize.width, gradientSize.height)
					   operation:NSCompositeSourceOver
						fraction:1.0];
        }
        
       /* Now draw our text in white. *//*
        NSRect inset = cellFrame;
        inset.origin.x += 2; // Nasty to hard-code this. Can we get it to draw its own content, or determine correct inset?
        NSMutableDictionary *attrs = [NSMutableDictionary dictionaryWithDictionary:[[self attributedStringValue] attributesAtIndex:0 effectiveRange:NULL]];
        [attrs setValue:[NSColor whiteColor] forKey:@"NSColor"];
        [[self stringValue] drawInRect:inset withAttributes:attrs];*/
        
        [controlView unlockFocus];
    } else {
        /* We're not selected, so ask our superclass to draw our content normally. */
		//cellFrame.origin.y += 4;
		//cellFrame.size.height -=  4;
		cellFrame.origin.y -= 4;
		cellFrame.origin.y += 8;
        [super drawInteriorWithFrame:cellFrame inView:controlView];
    }	
}

- copyWithZone:(NSZone *)zone
{
	id new = [[[self class] allocWithZone:zone] init];
	[new addSubview:([subview conformsToProtocol:@protocol(NSCopying)] ? [subview copy] : subview)];
	return new;
}

@end
