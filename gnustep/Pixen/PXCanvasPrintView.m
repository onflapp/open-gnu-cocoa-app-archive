//
//  PXCanvasPrintView.m
//  Pixen-XCode
//
//  Created by Joe Osborn on Tue Jul 13 2004.
//  Copyright (c) 2004 Open Sword Group. All rights reserved.
//

#import "PXCanvasPrintView.h"
#import "PXCanvas.h"

@implementation PXCanvasPrintView


+ viewForCanvas:aCanvas
{
	return [[[self alloc] initWithCanvas:aCanvas] autorelease];	
}

- (id)initWithCanvas:aCanvas
{
	[super initWithFrame:NSMakeRect(0, 0, [aCanvas size].width, [aCanvas size].height)];
	canvas = [aCanvas retain];
	return self;
}

- (void)dealloc
{
	[canvas release];
	[super dealloc];
}

- (void)drawRect:(NSRect)rect 
{
	//find and apply the proper transform for the paper size
	float scale = [[[[[NSPrintOperation currentOperation] printInfo] dictionary] objectForKey:NSPrintScalingFactor] floatValue];
	id transform = [NSAffineTransform transform];
	[transform scaleXBy:scale yBy:scale];
	[transform concat];
	[canvas drawRect:rect fixBug:NO];
	[transform invert];
	[transform concat];
}

@end
