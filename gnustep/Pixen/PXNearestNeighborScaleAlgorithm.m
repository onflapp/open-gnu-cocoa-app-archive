//
//  PXNearestNeighborScaleAlgorithm.m
//  Pixen-XCode
//
//  Created by Ian Henderson on Thu Jun 10 2004.
//  Copyright (c) 2004 Open Sword Group. All rights reserved.
//

#import "PXNearestNeighborScaleAlgorithm.h"
#import "PXCanvas.h"
#import "PXLayer.h"

@implementation PXNearestNeighborScaleAlgorithm

- (NSString *)name
{
	return @"Nearest Neighbor";
}

- (NSString *)algorithmInfo
{
	return NSLocalizedString(@"NEAREST_NEIGHBOR_INFO", "Nearest Neighbor Info Here");
}

- (BOOL)canScaleCanvas:canvas toSize:(NSSize)size
{
	if (canvas == nil || size.width == 0 || size.height == 0) {
		return NO;
	}
	return YES;
}

- (void)scaleCanvas:canvas toSize:(NSSize)size
{
	if (canvas == nil) {
		return;
	}
	NSEnumerator *layerEnumerator = [[canvas layers] objectEnumerator];
	PXLayer *layer, *layerCopy;
	int x, y;
	float xScale = size.width / [canvas size].width;
	float yScale = size.height / [canvas size].height;
	
	NSPoint currentPoint;
	while ( (layer = [layerEnumerator nextObject]) ) {
		layerCopy = [[layer copy] autorelease];
		[layer setSize:size];
		for (x=0; x<size.width; x++) {
			for (y=0; y<size.height; y++) {
				currentPoint = NSMakePoint((int)(x/xScale),(int)(y/yScale));
				[layer setColor:[layerCopy colorAtPoint:currentPoint] atPoint:NSMakePoint(x, y)];
			}
		}
	}
	[canvas layersChanged];
    [canvas canvasShouldRedraw:nil];
}

@end
