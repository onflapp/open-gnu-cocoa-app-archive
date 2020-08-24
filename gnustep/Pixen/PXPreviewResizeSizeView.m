//
//  PXPreviewResizeSizeView.m
//  Pixen-XCode
//
//  Created by Ian Henderson on Fri Jul 16 2004.
//  Copyright (c) 2004 Open Sword Group. All rights reserved.
//

#import "PXPreviewResizeSizeView.h"


@implementation PXPreviewResizeSizeView

- initWithFrame:(NSRect)frame
{
	[super initWithFrame:frame];
#ifdef __COCOA__
	shadow = [[NSShadow alloc] init];
	[shadow setShadowBlurRadius:5];
	[shadow setShadowOffset:NSMakeSize(0, 0)];
	[shadow setShadowColor:[NSColor blackColor]];
#else
#warning GNUstep TODO
#endif
	[self updateScale:0];
	return self;
}

- (void)dealloc
{
#ifdef __COCOA__
	[shadow release];
#endif
	[super dealloc];
}

- (void)updateScale:(float)scale
{
	if (scale > 100000) {
		return;
	}
	[scaleString release];
#ifdef __COCOA__
	scaleString = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%d%%", (int)(scale * 100)] attributes:[NSDictionary dictionaryWithObjectsAndKeys:
		[NSFont fontWithName:@"Verdana" size:20], NSFontAttributeName,
		[NSColor whiteColor], NSForegroundColorAttributeName,
		shadow, NSShadowAttributeName,
		nil]];
#else
#warning GNUstep TODO
#endif
	[self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)rect
{
	[[NSColor clearColor] set];
	NSRectFill([self frame]);
	NSBezierPath *background = [NSBezierPath bezierPath];
	NSPoint stringPoint = [self frame].origin;
	if ([self frame].size.height >= [self frame].size.width) {
		[background appendBezierPathWithOvalInRect:[self frame]];
	}
	else if ([self frame].size.height < [self frame].size.width) {
		NSRect leftSide = NSMakeRect([self frame].origin.x, [self frame].origin.y, [self frame].size.height, [self frame].size.height);
		NSRect rightSide = NSMakeRect([self frame].origin.x + [self frame].size.width - [self frame].size.height, [self frame].origin.y, [self frame].size.height, [self frame].size.height);
		NSRect middle = NSMakeRect([self frame].origin.x + ([self frame].size.height / 2.0f), [self frame].origin.y, [self frame].size.width - [self frame].size.height, [self frame].size.height);
		[background appendBezierPathWithOvalInRect:leftSide];
		[background appendBezierPathWithOvalInRect:rightSide];
		[background appendBezierPathWithRect:middle];
	}
	stringPoint.x += ([self frame].size.width - [scaleString size].width) / 2;
	stringPoint.y += ([self frame].size.height - [scaleString size].height) / 2 + [scaleString size].height / 9;
	[[NSColor colorWithCalibratedRed:0 green:0 blue:0 alpha:.5] set];
	[background fill];
	[scaleString drawAtPoint:stringPoint];
}

- (NSSize)scaleStringSize
{
	NSSize size = [scaleString size];
	return NSMakeSize(size.width * 1.3, size.height);
}

@end
