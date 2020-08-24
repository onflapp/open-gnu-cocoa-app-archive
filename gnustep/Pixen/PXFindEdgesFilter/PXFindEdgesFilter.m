//
//  PXFindEdgesFilter.m
//  PXFindEdgesFilter
//
//  Created by Ian Henderson on 20.09.04.
//  Copyright 2004 __MyCompanyName__. All rights reserved.
//

#import "PXFindEdgesFilter.h"
#import "PXCanvas.h"

typedef enum {
	PXRed,
	PXGreen,
	PXBlue
} PXColor;

float NSColorPXColorComponent(NSColor *color, PXColor component)
{
	switch (component) {
		case (PXRed): {
			return [color redComponent];
		}
		case (PXGreen): {
			return [color greenComponent];
		}
		case (PXBlue): {
			return [color blueComponent];
		}
		default: {
			return 1;
		} break;
	}
}

NSArray *PXImageExtractBoundaryAtPoint(id self, NSPoint point, PXColor component)
{
    static const int s_aiDx[8] = { -1,  0, +1, +1, +1,  0, -1, -1 };
    static const int s_aiDy[8] = { -1, -1, -1,  0, +1, +1, +1,  0 };
	
    // Create new point list containing first boundary point.  Note that the
    // index for the pixel is computed for the original image, not for the
    // larger temporary image.
	NSMutableArray *boundary = [NSMutableArray arrayWithObject:[NSValue valueWithPoint:NSMakePoint(point.x - 1, point.y - 1)]];
	
    // Compute the direction from background (0) to boundary pixel (1).
    int iCx = point.x, iCy = point.y;
    int iNx, iNy, iDir;
    for (iDir = 0; iDir < 8; iDir++)
    {
        iNx = iCx + s_aiDx[iDir];
        iNy = iCy + s_aiDy[iDir];
        if (NSColorPXColorComponent([[self colorAtPoint:NSMakePoint(iNx, iNy)] colorUsingColorSpaceName:NSCalibratedRGBColorSpace], component) == 0 )
        {
            iDir = (iDir+1)%8;
            break;
        }
    }
	
    // Traverse boundary in clockwise order.  Mark visited pixels as 3.
	NSColor *color = [[self colorAtPoint:NSMakePoint(iCx, iCy)] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	float r = [color redComponent];
	float g = [color blueComponent];
	float b = [color greenComponent];
	
	if (component == PXRed) {
		r = .75;
	}
	if (component == PXGreen) {
		g = .75;
	}
	if (component == PXBlue) {
		b = .75;
	}
	
	[self setColor:[NSColor colorWithCalibratedRed:r
											 green:g
											  blue:b
											 alpha:[color alphaComponent]]
		   atPoint:NSMakePoint(iCx,iCy)];
	
    while ( true )
    {
        int i, iNbr;
        for (i = 0, iNbr = iDir; i < 8; i++, iNbr = (iNbr+1)%8)
        {
            iNx = iCx + s_aiDx[iNbr];
            iNy = iCy + s_aiDy[iNbr];
            if ( NSColorPXColorComponent([[self colorAtPoint:NSMakePoint(iNx, iNy)] colorUsingColorSpaceName:NSCalibratedRGBColorSpace], component) )  // next boundary pixel found
                break;
        }
		
        if ( i == 8 )  // (iCx,iCy) is isolated
            break;
		
        if ( iNx == point.x && iNy == point.y )  // boundary traversal completed
            break;
		
        // (iNx,iNy) is next boundary point, add point to list.  Note that
        // the index for the pixel is computed for the original image, not
        // for the larger temporary image.
		[boundary addObject:[NSValue valueWithPoint:NSMakePoint(iNx-1, iNy-1)]];
		
		NSColor *color = [[self colorAtPoint:NSMakePoint(iNx, iNy)] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
		float r = [color redComponent];
		float g = [color blueComponent];
		float b = [color greenComponent];
		
		if (component == PXRed) {
			r = .75;
		}
		if (component == PXGreen) {
			g = .75;
		}
		if (component == PXBlue) {
			b = .75;
		}
		
		[self setColor:[NSColor colorWithCalibratedRed:r
												 green:g
												  blue:b
												 alpha:[color alphaComponent]]
			   atPoint:NSMakePoint(iNx,iNy)];
		
        iCx = iNx;
        iCy = iNy;
        iDir = (i+5+iDir)%8;
    }
	
    return boundary;
}


@implementation PXFindEdgesFilter

- (void)applyToCanvas:(id)canvas
{
    id canvasImage = [[canvas activeLayer] image];
	id temp = [[[[canvasImage class] alloc] initWithSize:NSMakeSize([canvasImage size].width + 2, [canvasImage size].height + 2)] autorelease];

    int iX, iY, iXP, iYP;
    for (iY = 0, iYP = 1; iY < [canvasImage size].height; iY++, iYP++)
    {
        for (iX = 0, iXP = 1; iX < [canvasImage size].width; iX++, iXP++)
		{
			NSColor *color = [[canvasImage colorAtPoint:NSMakePoint(iX,iY)] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
			[temp setColor:[NSColor colorWithCalibratedRed:[color redComponent] > 0.5 ? .5 : 0
													 green:[color greenComponent] > 0.5 ? .5 : 0
													  blue:[color blueComponent] > 0.5 ? .5 : 0
													 alpha:[color alphaComponent] > 0.5 ? 1 : 0]
				   atPoint:NSMakePoint(iXP,iYP)];
		}
    }
	
    for (iY = 1; iY+1 < [temp size].height; iY++)
    {
        for (iX = 1; iX+1 < [temp size].width; iX++)
        {
			NSColor *colorTop = [[temp colorAtPoint:NSMakePoint(iX, iY-1)] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
			NSColor *colorBottom = [[temp colorAtPoint:NSMakePoint(iX, iY+1)] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
			NSColor *colorLeft = [[temp colorAtPoint:NSMakePoint(iX-1, iY)] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
			NSColor *colorRight = [[temp colorAtPoint:NSMakePoint(iX+1, iY)] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
			NSColor *color = [[temp colorAtPoint:NSMakePoint(iX, iY)] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
			
			float r = [color redComponent], g = [color greenComponent], b = [color blueComponent];
			
			if ([color redComponent] && [colorTop redComponent]  && [colorBottom redComponent] && [colorLeft redComponent] && [colorRight redComponent]) {
				r = 1;
			}
			
			if ([color greenComponent] && [colorTop greenComponent]  && [colorBottom greenComponent] && [colorLeft greenComponent] && [colorRight greenComponent]) {
				g = 1;
			}
			
			if ([color blueComponent] && [colorTop blueComponent]  && [colorBottom blueComponent] && [colorLeft blueComponent] && [colorRight blueComponent]) {
				b = 1;
			}
			
			[temp setColor:[NSColor colorWithCalibratedRed:r
													 green:g
													  blue:b
													 alpha:[color alphaComponent]]
				   atPoint:NSMakePoint(iX,iY)];
        }
    }
	
	NSMutableArray *redBoundaries = [NSMutableArray array];
	NSMutableArray *greenBoundaries = [NSMutableArray array];
	NSMutableArray *blueBoundaries = [NSMutableArray array];
    for (iY = 0; iY < [temp size].height; iY++)
    {
        for (iX = 0; iX < [temp size].width; iX++)
        {
			NSColor *color = [[temp colorAtPoint:NSMakePoint(iX, iY)] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
			if ([color redComponent] == .5) {
				[redBoundaries addObject:PXImageExtractBoundaryAtPoint(temp, NSMakePoint(iX, iY), PXRed)];
			}
			if ([color greenComponent] == .5) {
				[greenBoundaries addObject:PXImageExtractBoundaryAtPoint(temp, NSMakePoint(iX, iY), PXGreen)];
			}
			if ([color blueComponent] == .5) {
				[blueBoundaries addObject:PXImageExtractBoundaryAtPoint(temp, NSMakePoint(iX, iY), PXBlue)];
			}
        }
    }
	/*
	int i;
	for (i=0; i<[redBoundaries count] i++) {
		[
	}
	
    // Repackage lists into a single array.
    int iSize = 1;  // make room for boundary count
    int i;
    for (i = 0; i < (int)kBoundaries.size(); i++)
        iSize += (int)kBoundaries[i]->size() + 1;
	
    int* aiPacked = new int[iSize];
    aiPacked[0] = (int)kBoundaries.size();
    int iIndex = 1;
    for (i = 0; i < (int)kBoundaries.size(); i++)
    {
        BoundaryList* pkBoundary = kBoundaries[i];
		
        aiPacked[iIndex++] = (int)pkBoundary->size();
        for (int j = 0; j < (int)pkBoundary->size(); j++)
            aiPacked[iIndex++] = (*pkBoundary)[j];
		
        delete pkBoundary;
    }
	
    return aiPacked;
*/
	id newImage = [[[[canvasImage class] alloc] initWithSize:NSMakeSize([canvasImage size].width, [canvasImage size].height)] autorelease];
	
	int i;
	for (i=0; i<[redBoundaries count]; i++) {
		[newImage setColor:[NSColor blackColor] atPoints:[redBoundaries objectAtIndex:i]];
	}
	for (i=0; i<[greenBoundaries count]; i++) {
		[newImage setColor:[NSColor blackColor] atPoints:[greenBoundaries objectAtIndex:i]];
	}
	for (i=0; i<[blueBoundaries count]; i++) {
		[newImage setColor:[NSColor blackColor] atPoints:[blueBoundaries objectAtIndex:i]];
	}
	
	[canvas addLayer:[[[[[canvas activeLayer] class] alloc] initWithName:@"Edges" image:newImage] autorelease]];
}

- (NSString *)name
{
	return @"Find Edges";
}

@end
