//  PXImage.m
//  Pixen
//
//  Created by Joe Osborn on Thu Sep 11 2003.
//  Copyright (c) 2003 Open Sword Group. All rights reserved.
//

#import "PXImage.h"
#import "PXPixel.h"
#import "KTMutableMatrix.h"

extern BOOL isTiling;

@implementation PXImage

- initWithSize:(NSSize)aSize
{
    [super init];
	width = aSize.width;
	height = aSize.height;
    pixelsByColor = [[NSMutableDictionary alloc] initWithCapacity:128];
    pixelsByPosition = [[KTMutableMatrix matrixWithCapacity:512*512 cuboidBounds:(unsigned)(width), (unsigned)(height), 0, 0] retain];
	rects = malloc(sizeof(NSRect) * (height + 2));
	colors = malloc(sizeof(NSColor *) * (height + 2));
    return self;
}

- (NSSize)size
{
	return NSMakeSize(width, height);
}

- (void)setSize:(NSSize)newSize withOrigin:(NSPoint)origin backgroundColor:(NSColor *)color
{
	id newPixelsByPosition = [[KTMutableMatrix matrixWithCapacity:512*512 cuboidBounds:(unsigned)(newSize.width), (unsigned)(newSize.height), 0, 0] retain];
	unsigned int i, j;
	unsigned int newWidth = newSize.width, newHeight = newSize.height;
	unsigned int originX = origin.x, originY = origin.y;
	for(i = 0; i < newWidth; i++)
	{
		for(j = 0; j < newHeight; j++)
		{
			if (i < originX || j < originY || i >= width + originX || j >= height + originY) {
				[newPixelsByPosition setObject:[PXPixel withColor:color] atCoordinates:i, j];
			} else {
				[newPixelsByPosition setObject:[self pixelAtPoint:NSMakePoint(i - originX, j - originY)] atCoordinates:i, j];
			}
		}
	}
	width = newWidth;
	height = newHeight;
	[pixelsByPosition release];
	pixelsByPosition = newPixelsByPosition;
	free(rects);
	free(colors);
	rects = malloc(sizeof(NSRect) * (height + 2));
	colors = malloc(sizeof(NSColor *) * (height + 2));
}

- (void)setSize:(NSSize)newSize
{
	[self setSize:newSize withOrigin:NSMakePoint(0,0) backgroundColor:[NSColor clearColor]];
}

- (void)dealloc
{
    [pixelsByColor release];
    [pixelsByPosition release];
	free(rects);
	free(colors);
    [super dealloc];
}

- (BOOL)containsPoint:(NSPoint)point
{
	return (isTiling ? YES : NSPointInRect(point, NSMakeRect(0, 0, width, height)));
}

- (NSColor *)colorAtX:(unsigned int)x y:(unsigned int)y
{
	return [[self pixelAtX:x y:y] color];
}

- (NSColor *)colorAtPoint:(NSPoint)aPoint
{
	//if(![self containsPoint:aPoint]) { return nil; }
	return [[self pixelAtPoint:aPoint] color];
}

- pixelOfColor:aColor
{
	if(aColor == nil) { return nil; }
    id pixel = [pixelsByColor objectForKey:aColor];
    if(pixel == nil)
	{
		[pixelsByColor setObject:[PXPixel withColor:aColor] forKey:aColor]; 
		pixel = [pixelsByColor objectForKey:aColor]; 
		[[NSNotificationCenter defaultCenter] postNotificationName:@"PXImageColorAddedNotification" object:self userInfo:[NSDictionary dictionaryWithObject:aColor forKey:@"color"]];
	}
    return pixel;
}

- (NSPoint)correct:(NSPoint)aPoint
{
	NSPoint corrected = aPoint;
	while(corrected.x < 0)
	{
		corrected.x += width;
	}
	while(corrected.x >= width)
	{
		corrected.x -= width;
	}
	while(corrected.y < 0)
	{
		corrected.y += height;
	}
	while(corrected.y >= height)
	{
		corrected.y -= height;
	}
	return corrected;	
}

- (unsigned int)correctX:(unsigned int)x
{
	while(x < 0)
	{
		x += width;
	}
	while(x >= width)
	{
		x -= width;
	}
	return x;
}

- (unsigned int)correctY:(unsigned int)y
{
	while(y < 0)
	{
		y += height;
	}
	while(y >= height)
	{
		y -= height;
	}
	return y;
}

- _pixelAtX:(unsigned int)x y:(unsigned int)y
{
	return [pixelsByPosition objectAtCoordinates:x, y];
}

- _pixelAtPoint:(NSPoint)aPoint
{
//	id pixel = [pixelsByPosition objectAtCoordinates:(unsigned)(aPoint.x), (unsigned)(aPoint.y)];
//	if ([[pixel color] alphaComponent] == 0) {
//		return nil;
//	}
	return [self _pixelAtX:aPoint.x y:aPoint.y];
}

- pixelAtX:(unsigned int)x y:(unsigned int)y
{
	return [self _pixelAtX:[self correctX:x] y:[self correctY:y]];
}

- pixelAtPoint:(NSPoint)aPoint
{
	NSPoint corrected = [self correct:aPoint];
    return [self _pixelAtPoint:corrected];
}

- (void)setPixel:aPixel atPoint:(NSPoint)aPoint
{
	NSPoint corrected = [self correct:aPoint];
    [pixelsByPosition setObject:aPixel atCoordinates:(unsigned)(corrected.x), (unsigned)(corrected.y)];
}

- (void)setPixel:aPixel atPoints:(NSArray *)points
{
    id enumerator = [points objectEnumerator];
    id current;
    while ( ( current = [enumerator nextObject] ) )
    {
        [self setPixel:aPixel atPoint:[current pointValue]];
    }
}

- (void)setColor:aColor atPoint:(NSPoint)aPoint
{
    [self setPixel:[self pixelOfColor:aColor] atPoint:aPoint];
}

- (void)setColor:(NSColor *)aColor atPoints:(NSArray *)points
{
    [self setPixel:[self pixelOfColor:aColor] atPoints:points];
}

- (void)replacePixelsOfColor:oldColor withColor:newColor
{
	id pixel = [self pixelOfColor:oldColor];
	if((pixel == nil) || ([oldColor isEqual:newColor])) { return; }
	[pixel setColor:newColor];
	[pixelsByColor setObject:pixel forKey:newColor];
	[pixelsByColor removeObjectForKey:oldColor];
}

- (void)translateXBy:(float)amountX yBy:(float)amountY
{
	id newMatrix = [KTMutableMatrix matrixWithCapacity:512*512 cuboidBounds:(unsigned)(width), (unsigned)(height), 0, 0];
	int i, j;
	for(i = 0; i < width; i++)
	{
		for(j = 0; j < height; j++)
		{
			float newX = i + amountX, newY = j + amountY;
			if(!(newX < 0 || newX >= width || newY < 0 || newY >= height))
			{
				[newMatrix setObject:[self pixelAtPoint:NSMakePoint(i, j)] atCoordinates:(unsigned)newX, (unsigned)newY];
			}
		}
	}
	[pixelsByPosition release];
	pixelsByPosition = [newMatrix retain];
}


- (void)flipHorizontally
{
	id newMatrix = [KTMutableMatrix matrixWithCapacity:512*512 cuboidBounds:(unsigned)(width), (unsigned)(height), 0, 0];
	int i, j;
	for(i = 0; i < width; i++)
	{
		for(j = 0; j < height; j++)
		{
			[newMatrix setObject:[self pixelAtPoint:NSMakePoint(width - i - 1, j)] atCoordinates:(unsigned)i, (unsigned)j];
		}
	}
	[pixelsByPosition release];
	pixelsByPosition = [newMatrix retain];
}

- (void)flipVertically
{
	id newMatrix = [KTMutableMatrix matrixWithCapacity:512*512 cuboidBounds:(unsigned)(width), (unsigned)(height), 0, 0];
	int i, j;
	for(i = 0; i < width; i++)
	{
		for(j = 0; j < height; j++)
		{
			[newMatrix setObject:[self pixelAtPoint:NSMakePoint(i, height - j - 1)] atCoordinates:(unsigned)i, (unsigned)j];
		}
	}
	[pixelsByPosition release];
	pixelsByPosition = [newMatrix retain];
}

- (void)drawRect:(NSRect)rect withOpacity:(double)anOpacity fixBug:(BOOL)fixBug
{
	unsigned int startX = MAX(rect.origin.x-1, 0), startY = MAX(rect.origin.y-1, 0);
	unsigned int offsetX = startX+rect.size.width+1, offsetY = startY+rect.size.height+1;
    unsigned int i, j;
	unsigned int count = 0;
	SEL colorAtXYselector = @selector(colorAtX:y:);
	IMP colorAtXY = [self methodForSelector:colorAtXYselector];
	
    for(i = startX; (i < offsetX) && (i < width); i++)
    {
        for(j = startY; (j < offsetY) && (j < height); j++)
        {
			rects[count] = NSMakeRect(i,j,1,1);
			colors[count] = colorAtXY(self, colorAtXYselector, i, j);
			if (colors[count] == nil)
			{
				colors[count] = [NSColor clearColor];
			}
			if (anOpacity != 1)
			{
				colors[count] = [colors[count] colorWithAlphaComponent:[colors[count] alphaComponent] * anOpacity];
			}
			count++;
        }
		NSRectFillListWithColorsUsingOperation(rects, colors, count, fixBug ? NSCompositeDestinationOver : NSCompositeSourceAtop);
		count = 0;
    }
}

- description
{
	int i, j;
	NSString * result = @"";
	for (i = 0; i < width; i++)
	{
		for (j = 0; j < height; j++)
		{
			result = [result stringByAppendingFormat:@"(%d,%d): %@, ", i, j, [self colorAtPoint:NSMakePoint(i,j)]];
		}
	}
	return result;
}

- (void)compositeUnder:anImage
{
	NSImage * compositedImage = [[[NSImage alloc] initWithSize:[self size]] autorelease];
	NSRect fullRect = NSMakeRect(0,0,width,height);
	NSPoint point;
	int i, j;
	id pool;
	
	[compositedImage lockFocus];
	[anImage drawRect:fullRect withOpacity:1 fixBug:YES];
	[self drawRect:fullRect withOpacity:1 fixBug:YES];
    for(i = 0; i < width; i++)
    {
        pool = [[NSAutoreleasePool alloc] init];
        for(j = 0; j < height; j++)
        {
			point = NSMakePoint(i, j);
            [self setColor:NSReadPixel(point) atPoint:point];
        }
        [pool release];
    }	
	[compositedImage unlockFocus];
}

- (void)setPixelsByColor:newPixelsByColor
{
	[newPixelsByColor retain];
	[pixelsByColor release];
	pixelsByColor = newPixelsByColor;
}

- (void)setPixelsByPosition:newPixelsByPosition
{
	[newPixelsByPosition retain];
	[pixelsByPosition release];
	pixelsByPosition = newPixelsByPosition;
}

- copyWithZone:(NSZone *)zone
{
	id new = [[[self class] allocWithZone:zone] initWithSize:[self size]];
	/*we're not using this approach because there seems to be a weirdness in -[NSMutableDictionary mutableCopy] that makes the mutably copied dictionary worthless-- it doesn't retain its objects!  At least, there were crashes when we used that method that didn't show up when we did -(void)setColor:atPoint: for each pixel.
	[new setPixelsByColor:[[pixelsByColor mutableCopyWithZone:zone] autorelease]];
	[new setPixelsByPosition:[[pixelsByPosition mutableCopyWithZone:zone] autorelease]];
*/
	unsigned int i, j;
	for(i = 0; i < width; i++)
	{
		for(j = 0; j < height; j++)
		{
			[new setColor:[self colorAtPoint:NSMakePoint(i, j)] atPoint:NSMakePoint(i, j)];
		}
	}
	return new;
}

@end


@implementation PXImage(Archiving)

NSString * PXCurrentVersion = @"r2v4";

- legacyDiscoverPixelsByPositionFromPositionsByPixel:positionsByPixel
{
    id newPixelsByPosition = [NSMutableDictionary dictionaryWithCapacity:10000];
    id pixelEnumerator = [positionsByPixel keyEnumerator];
    id currentPixel;
    while ( ( currentPixel = [pixelEnumerator nextObject] ) )
    {
        id positionEnumerator = [[positionsByPixel objectForKey:currentPixel] objectEnumerator];
        id currentPosition;
        while ( ( currentPosition = [positionEnumerator nextObject] ) )
        {
            [newPixelsByPosition setObject:currentPixel forKey:currentPosition];
        }
    }
    return newPixelsByPosition;
}

- (NSSize)legacyDiscoverSizeFromPixelsByPosition:pixels
{
    float w = 0, h = 0;
    id enumerator = [pixels keyEnumerator];
    id current;
    while ( ( current = [enumerator nextObject] ) )
    {
        NSPoint point = NSPointFromString(current);
        if(point.x > w) { w = point.x; }
        if(point.y > h) { h = point.y; }
    }
    return NSMakeSize(w+1, h+1);
}

- legacyDiscoverPixelsByPositionMatrixFromPixelsByPositionDictionary:pixels
{
    id realPixelsByPosition = [KTMutableMatrix matrixWithCapacity:512*512 cuboidBounds:(unsigned)(width), (unsigned)(height), 0, 0];
	int i, j;
	for(i = 0; i < width; i++)
	{
		for(j = 0; j < height; j++)
		{
			NSPoint point = NSMakePoint(i, j);
			id pixel = [pixels objectForKey:NSStringFromPoint(point)];
			//if(pixel == nil) { pixel = [self pixelOfColor:[NSColor clearColor]]; }
			[realPixelsByPosition setObject:[pixel retain] atCoordinates:(unsigned)(point.x), (unsigned)(point.y)];
		}
	}
    return realPixelsByPosition;
}

- legacyInitWithCoder:coder
{
    id positionsByPixel = [coder decodeObjectForKey:@"positionsByPixel"];
    if(positionsByPixel != nil) { pixelsByPosition = [self legacyDiscoverPixelsByPositionFromPositionsByPixel:positionsByPixel]; }
    if(NSEqualSizes([self size], NSZeroSize)) {
		NSSize imageSize = [self legacyDiscoverSizeFromPixelsByPosition:pixelsByPosition];
		width = imageSize.width;
		height = imageSize.height;
	}
    pixelsByPosition = [[self legacyDiscoverPixelsByPositionMatrixFromPixelsByPositionDictionary:pixelsByPosition] retain];
    return self;
}

- initWithCoder:coder
{
    [super init];
    pixelsByColor = [[coder decodeObjectForKey:@"pixelsByColor"] mutableCopy];
    pixelsByPosition = [[coder decodeObjectForKey:@"pixelsByPosition"] mutableCopy];
    NSSize imageSize = [coder decodeSizeForKey:@"size"];
	width = imageSize.width;
	height = imageSize.height;
    //if(![PXCurrentVersion isEqual:[coder decodeObjectForKey:@"version"]]) 
	{ 
		[self legacyInitWithCoder:coder]; 
	}
	rects = malloc(sizeof(NSRect) * (height + 2));
	colors = malloc(sizeof(NSColor *) * (height + 2));
    return self;
}

- (void)encodeWithCoder:coder
{
    //can't encode version until KTMatrix works properly.  we're still faking encoding in the old format.  sigh.
    [coder encodeObject:PXCurrentVersion forKey:@"version"];
    [coder encodeSize:[self size] forKey:@"size"];
    [coder encodeObject:pixelsByColor forKey:@"pixelsByColor"];
    //[coder encodeObject:pixelsByPosition forKey:@"pixelsByPosition"];
    id fakePixelsByPosition = [NSMutableDictionary dictionaryWithCapacity:50000];
    unsigned i, j;
    for(i = 0; i < width; i++)
    {
        for(j = 0; j < height; j++)
        {
            id pixel = [pixelsByPosition objectAtCoordinates:i, j];
            if(pixel != nil) { [fakePixelsByPosition setObject:pixel forKey:NSStringFromPoint(NSMakePoint(i, j))]; }
        }
    }
    [coder encodeObject:fakePixelsByPosition forKey:@"pixelsByPosition"];
}

@end
