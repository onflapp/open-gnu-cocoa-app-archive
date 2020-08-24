//
//  PXBicubicScaleAlgorithm.m
//  Pixen-XCode
//
//  Created by Ian Henderson on 26.08.04.
//  Copyright 2004 Open Sword Group. All rights reserved.
//

#import "PXBicubicScaleAlgorithm.h"
#import "PXCanvas.h"
#import "PXLayer.h"

@implementation PXBicubicScaleAlgorithm

- (NSString *)name
{
	return @"Bicubic";
}

- (NSString *)algorithmInfo
{
	return NSLocalizedString(@"BICUBIC_INFO", @"Bicubic Info Here");
}

- (BOOL)canScaleCanvas:canvas toSize:(NSSize)size
{
	if (canvas == nil || size.width == 0 || size.height == 0) {
		return NO;
	}
	return YES;
}


float PXBicubicWeight(float x)
{
	return .1666 * (pow(MAX(0, x+2), 3) - 4*pow(MAX(0, x+1), 3) + 6*pow(MAX(0, x), 3) - 4*pow(MAX(0, x-1), 3));
}

- (void)scaleCanvas:canvas toSize:(NSSize)size
{
	if (canvas == nil) {
		return;
	}
	NSEnumerator *layerEnumerator = [[canvas layers] objectEnumerator];
	PXLayer *layer, *layerCopy;
	int x, y, m, n;
	float xScale = size.width / [canvas size].width;
	float yScale = size.height / [canvas size].height;
	float bicubicWeightedCoefficient, red, green, blue, alpha, dx, dy;
	NSColor *color;
	
	NSPoint currentPoint;
	while ( ( layer = [layerEnumerator nextObject] ) ) {
		layerCopy = [[layer copy] autorelease];
		[layer setSize:size];
		for (x=0; x<size.width; x++) {
			for (y=0; y<size.height; y++) {
				currentPoint = NSMakePoint((int)(x/xScale),(int)(y/yScale));
				red = 0;
				blue = 0;
				green = 0;
				alpha = 0;
				dx = x/xScale - currentPoint.x;
				dy = y/yScale - currentPoint.y;
				for (m=-1; m<=2; m++) {
					for (n=-1; n<=2; n++) {
						color = [[layerCopy colorAtPoint:NSMakePoint(currentPoint.x + m, currentPoint.y + n)] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
						bicubicWeightedCoefficient = PXBicubicWeight((float)m - dx) * PXBicubicWeight(dy - (float)n);
						red += [color redComponent] * bicubicWeightedCoefficient;
						green += [color greenComponent] * bicubicWeightedCoefficient;
						blue += [color blueComponent] * bicubicWeightedCoefficient;
						alpha += [color alphaComponent] * bicubicWeightedCoefficient;
					}
				}
				[layer setColor:[NSColor colorWithCalibratedRed:red green:green blue:blue alpha:alpha] atPoint:NSMakePoint(x, y)];
			}
		}
	}
	[canvas layersChanged];
    [canvas canvasShouldRedraw:nil];
}

@end

