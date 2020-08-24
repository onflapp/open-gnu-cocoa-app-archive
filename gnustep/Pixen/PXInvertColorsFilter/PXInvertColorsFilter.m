//
//  PXInvertColorsFilter.m
//  PXInvertColorsFilter
//
//  Created by Ian Henderson on 20.09.04.
//  Copyright 2004 __MyCompanyName__. All rights reserved.
//

#import "PXInvertColorsFilter.h"
#import "PXCanvas.h"


@implementation PXInvertColorsFilter

- (NSString *)name
{
	return @"Invert Colors";
}

- (void)applyToCanvas:(PXCanvas *)canvas
{
	int x, y;
	for (x=0; x<[canvas size].width; x++) {
		for (y=0; y<[canvas size].height; y++) {
			NSColor *currentColor = [[canvas colorAtPoint:NSMakePoint(x, y)] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
			[canvas setColor:[NSColor colorWithCalibratedRed:1.0 - [currentColor redComponent]
													   green:1.0 - [currentColor greenComponent]
														blue:1.0 - [currentColor blueComponent]
													   alpha:[currentColor alphaComponent]]
					 atPoint:NSMakePoint(x, y)];
		}
	}
}

@end
