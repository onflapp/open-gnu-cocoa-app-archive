//
//  PXScale2xScaleAlgorithm.m
//  Pixen-XCode
//
//  Created by Ian Henderson on 26.08.04.
//  Copyright 2004 Open Sword Group. All rights reserved.
//

#import "PXScale2xScaleAlgorithm.h"
#import "PXCanvas.h"
#import "PXLayer.h"

@implementation PXScale2xScaleAlgorithm

- (NSString *)name
{
	return @"Scale2x";
}

- (NSString *)algorithmInfo
{
	return NSLocalizedString(@"SCALE2X_INFO", @"Scale2x Info Here");
}

- (BOOL)canScaleCanvas:canvas toSize:(NSSize)size
{
	if (canvas == nil || size.width < 1 || size.height < 1) {
		return NO;
	}
	double widthLog = log2(size.width / [canvas size].width);
	double heightLog = log2(size.height / [canvas size].height);
	if (fabs(floor(widthLog) - widthLog) > .001 || fabs(floor(heightLog) - heightLog) > .001 || fabs(widthLog - heightLog) > .001) {
		return NO;
	}
	return YES;
}

- (void)scaleCanvas:canvas toSize:(NSSize)size
{
	if (canvas == nil) {
		return;
	}
	NSEnumerator *layerEnumerator;
	PXLayer *layer, *layerCopy;
	int x, y;
	NSColor *A, *B, *C, *D, *E, *F, *G, *H, *I, *E0, *E1, *E2, *E3;
	int xScale = size.width / [canvas size].width;
	int yScale = size.height / [canvas size].height;
	int layerWidth, layerHeight;
	layerWidth = [canvas size].width;
	layerHeight = [canvas size].height;
	NSAutoreleasePool *pool;
	
	 while (xScale > 1 && yScale > 1) {
		layerWidth = layerWidth << 1;
		layerHeight = layerHeight << 1;
		layerEnumerator = [[canvas layers] objectEnumerator];
		while (layer = [layerEnumerator nextObject]) {
			pool = [[NSAutoreleasePool alloc] init];
			layerCopy = [[layer copy] autorelease];
			[layer setSize:NSMakeSize(layerWidth, layerHeight)];
			for (x=0; x<[canvas size].width; x++) {
				for (y=0; y<[canvas size].height; y++) {
					// A B C
					// D E F
					// G H I
					
					A = [layerCopy colorAtPoint:NSMakePoint(x - 1, y - 1)];
					B = [layerCopy colorAtPoint:NSMakePoint(x    , y - 1)];
					C = [layerCopy colorAtPoint:NSMakePoint(x + 1, y - 1)];
					D = [layerCopy colorAtPoint:NSMakePoint(x - 1, y)];
					E = [layerCopy colorAtPoint:NSMakePoint(x    , y)];
					F = [layerCopy colorAtPoint:NSMakePoint(x + 1, y)];
					G = [layerCopy colorAtPoint:NSMakePoint(x - 1, y + 1)];
					H = [layerCopy colorAtPoint:NSMakePoint(x    , y + 1)];
					I = [layerCopy colorAtPoint:NSMakePoint(x + 1, y + 1)];
					
					if (![B isEqual:H] && ![D isEqual:F]) {
						E0 = [D isEqual:B] ? D : E;
						E1 = [B isEqual:F] ? F : E;
						E2 = [D isEqual:H] ? D : E;
						E3 = [H isEqual:F] ? F : E;
					} else {
						E0 = E;
						E1 = E;
						E2 = E;
						E3 = E;
					}
					
					[layer setColor:E0 atPoint:NSMakePoint(x*2, y*2)];
					[layer setColor:E1 atPoint:NSMakePoint(x*2 + 1, y*2)];
					[layer setColor:E2 atPoint:NSMakePoint(x*2, y*2 + 1)];
					[layer setColor:E3 atPoint:NSMakePoint(x*2 + 1, y*2 + 1)];
				}
			}
			[pool release];
		}
		xScale = xScale >> 1;
		yScale = yScale >> 1;
		[canvas layersChanged];
	}
    [canvas canvasShouldRedraw:nil];
}

@end
