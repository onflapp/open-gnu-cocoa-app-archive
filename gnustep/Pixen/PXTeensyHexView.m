//
//  PXTeensyHexView.m
//  Pixen-XCode
//
//  Created by Ian Henderson on 16.10.04.
//  Copyright 2004 Open Sword Group. All rights reserved.
//

#import "PXTeensyHexView.h"


@implementation PXTeensyHexView


- (void)setColor:aColor
{
	color = [[aColor colorUsingColorSpaceName:NSCalibratedRGBColorSpace] copy];
	[self setNeedsDisplay:YES];
}

- (void)dealloc
{
	[color release];
	[super dealloc];
}

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        color = [self setColor:[NSColor whiteColor]];
    }
    return self;
}

- (void)drawRect:(NSRect)rect {
	if (color == nil) {
		return;
	}
	
	NSString *string = [NSString stringWithFormat:@"#%02x%02x%02x", (int)([color redComponent] * 255), (int)([color greenComponent] * 255), (int)([color blueComponent] * 255)];
	NSAttributedString *attributedString = [[[NSAttributedString alloc] initWithString:string attributes:[NSDictionary dictionaryWithObjectsAndKeys:
		[NSFont fontWithName:@"Courier" size:8], NSFontAttributeName,
		[NSNumber numberWithFloat:-1.0], NSKernAttributeName,
		nil]] autorelease];
	NSRect drawRect = NSMakeRect(0, 0, [self frame].size.width, [self frame].size.height);
	NSSize stringSize = [attributedString size];
	drawRect.origin.x += (drawRect.size.width - stringSize.width) / 2;
	
	[attributedString drawAtPoint:drawRect.origin];
}

@end
