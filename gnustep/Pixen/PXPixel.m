//  PXPixel.m
//  Pixen
//
//  Created by Joe Osborn on Thu Sep 11 2003.
//  Copyright (c) 2003 Open Sword Group. All rights reserved.
//

#import "PXPixel.h"


@implementation PXPixel

- (BOOL)isEqual:other
{
    return [other isKindOfClass:[self class]] && [[self color] isEqual:[other color]];
}

- (unsigned)hash
{
    return [color hash];
}

+ withColor:aColor
{
    return [[[self alloc] initWithColor:aColor] autorelease];
}

- initWithColor:aColor
{
    [super init];
    [self setColor:aColor];
    return self;
}

- (void)dealloc
{
    [color release];
    [super dealloc];
}

- color
{
    return color;
}

- (void)setColor:aColor
{
	id newColor = (([aColor alphaComponent] == 0) ? [NSColor clearColor] : [aColor colorUsingColorSpaceName:NSCalibratedRGBColorSpace]);
	//newColor = [newColor colorUsingColorSpaceName:NSCalibratedRGBColorSpace]
    [newColor retain];
    [color release];
    color = newColor;
}

- (void)drawAtPoint:(NSPoint)aPoint withOpacity:(float)anOpacity;
{
	// now for a CG implementation!
	id newColor;
	if ([color colorSpaceName] != NSCalibratedRGBColorSpace) { newColor = [color colorUsingColorSpaceName:NSCalibratedRGBColorSpace]; }
	else { newColor = color; }

#ifdef __COCOA__	
    CGContextRef currentContext = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
	CGContextSetRGBFillColor(currentContext, [newColor redComponent], [newColor greenComponent], [newColor blueComponent], [newColor alphaComponent]*anOpacity);
	CGContextFillRect(currentContext, CGRectMake(aPoint.x, aPoint.y, 1, 1));
#endif
	/*NSColor * calibratedColor = [color colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	NSColor * compositeColor;
	if (anOpacity == 1)
	{
		compositeColor = calibratedColor;
	}
	else
	{
		compositeColor = [NSColor colorWithCalibratedRed:[calibratedColor redComponent] green:[calibratedColor greenComponent] blue:[calibratedColor blueComponent] alpha:[color alphaComponent] * anOpacity];
	}
	[compositeColor set];
    NSRectFillUsingOperation(NSMakeRect(aPoint.x, aPoint.y, 1, 1), [compositeColor alphaComponent] == 1 ? NSCompositeCopy : NSCompositeSourceOver);
	*/
}

/*we're not actually using this method because there seems to be a weirdness in -[NSMutableDictionary mutableCopy] that makes the mutably copied dictionary worthless-- it doesn't retain its objects!  At least, there were crashes when we used that method that didn't show up when we did -(void)setColor:atPoint: for each pixel.*/
- copyWithZone:(NSZone *)zone
{
	return [self retain];
}

- initWithCoder:coder
{
    [super init];
    color = [[coder decodeObjectForKey:@"color"] retain];    
    return self;
}

- (void)encodeWithCoder:coder
{
    [coder encodeObject:color forKey:@"color"];
}

@end
