//
//  PXColorWellCell.m
//  Pixen-XCode
//
//  Created by Joe Osborn on Thu Apr 22 2004.
//  Copyright (c) 2004 Open Sword Group. All rights reserved.
//

#import "PXColorWellCell.h"
#import "PXColorWell.h"

@implementation PXColorWellCell

- init
{
	[super init];
	[self addSubview:[[PXColorWell alloc] initWithFrame:NSMakeRect(0, 0, 32, 32)]];
	[(PXColorWell *)subview setToolTip:@"(R0, G0, B0, A0.00)"];
	[(PXColorWell *)subview setBordered:NO];
	return self;
}

- (void)dealloc
{
	[subview release];
	[super dealloc];
}

- (void)setColor:color
{
	color = [color colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	[(PXColorWell *)subview setToolTip:[NSString stringWithFormat:@"(R%.0f, G%.0f, B%.0f, A%.2f)", [color redComponent] * 255, [color greenComponent] * 255, [color blueComponent] * 255, [color alphaComponent], nil]];
	[(PXColorWell *)subview setColor:color];
}

- (void)leftSelect
{
	[(PXColorWell *)subview leftSelect];
}

- (void)rightSelect
{
	[(PXColorWell *)subview rightSelect];
}

- (void)deactivate
{
	[(PXColorWell *)subview deactivate];
}

- copyWithZone:(NSZone *)zone
{
	return [[[self class] allocWithZone:zone] init];
}

@end