//
//  PXLayer.m
//  Pixen-XCode
//
//  Created by Joe Osborn on Sun Jan 04 2004.
//  Copyright (c) 2004 Open Sword Group. All rights reserved.
//

#import "PXLayer.h"
#import "PXLayerController.h"
#import "PXImage.h"

@implementation PXLayer

- initWithName:aName image:anImage
{
	[super init];
	[self setName:aName];
	image = [anImage retain];
	opacity = 100;
	visible = YES;
	return self;
}

- initWithName:aName size:(NSSize)size
{
	return [self initWithName:aName image:[[[PXImage alloc] initWithSize:size] autorelease]];
}

- (void)dealloc
{
	[name release];
	[image release];
	[super dealloc];
}

- name
{
	return name;
}

- (void)setName:aName
{
	[name release];
	name = [aName copy];
}

- image
{
	return image;
}

- (double)opacity
{
	return opacity;
}

- (void)setOpacity:(double)newOpacity
{
	opacity = newOpacity;
}

- (BOOL)visible
{
	return visible;
}

- (void)setVisible:(BOOL)isVisible
{
	visible = isVisible;
}

- (BOOL)canDrawAtPoint:(NSPoint)point
{
	return [image containsPoint:point];
}

- (NSColor *)colorAtPoint:(NSPoint)aPoint
{
	id color = [image colorAtPoint:aPoint];
	if(color == nil) { color = [NSColor clearColor]; }
	return color;
}

- (void)setColor:(NSColor *)aColor atPoint:(NSPoint)aPoint
{
	[image setColor:aColor atPoint:aPoint];
}

- (void)setColor:(NSColor *)aColor atPoints:(NSArray *)points
{
	[image setColor:aColor atPoints:points];
}

- (void)moveToPoint:(NSPoint)newOrigin
{
	origin = newOrigin;
}

- (NSSize)size
{
	return [image size];
}

- (void)setSize:(NSSize)newSize withOrigin:(NSPoint)anOrigin backgroundColor:(NSColor *)color
{
	[image setSize:newSize withOrigin:anOrigin backgroundColor:color];
}

- (void)setSize:(NSSize)newSize
{
	[self setSize:newSize withOrigin:NSZeroPoint backgroundColor:[NSColor clearColor]];
}

- (void)finalizeMotion
{
	[image translateXBy:origin.x yBy:origin.y];
	origin = NSZeroPoint;
}

- (void)translateXBy:(float)amountX yBy:(float)amountY
{
	[self moveToPoint:NSMakePoint(origin.x + amountX, origin.y + amountY)];
}

- (void)replacePixelsOfColor:oldColor withColor:newColor
{
	[image replacePixelsOfColor:oldColor withColor:newColor];
}

- (void)transformedDrawRect:(NSRect)rect fixBug:(BOOL)fixBug
{
	[image drawRect:rect withOpacity:(opacity / 100.00) fixBug:fixBug];
}

- (void)drawRect:(NSRect)rect fixBug:(BOOL)fixBug
{
	if (!visible) { return; }
	NSAffineTransform * transform = [NSAffineTransform transform];
	[transform translateXBy:origin.x yBy:origin.y];
	[transform concat];
	[self transformedDrawRect:rect fixBug:fixBug];
	[transform invert];
	[transform concat];
}

- (void)compositeUnder:aLayer flattenOpacity:(BOOL)flattenOpacity
{
	int i, j;
	for (i=0; i < [image size].width; i++)
	{
		for (j=0; j < [image size].height; j++)
		{
			NSPoint point = NSMakePoint(i, j);
			id color1 = [image colorAtPoint:point], color2 = [(PXImage *)[aLayer image] colorAtPoint:point];
			[image setColor:((flattenOpacity) ? [color1 colorWithAlphaComponent:[color1 alphaComponent]*(opacity/100.00)] : color1) atPoint:point];
			[(PXImage *)[aLayer image] setColor:((flattenOpacity) ? [color2 colorWithAlphaComponent:[color2 alphaComponent]*([aLayer opacity]/100.00)] : color2) atPoint:point];

		}
	}
	[image compositeUnder:[aLayer image]];
	if (flattenOpacity) { [self setOpacity:100]; }
}

- (void)flipHorizontally
{
	[image flipHorizontally];
}

- (void)flipVertically
{
	[image flipVertically];
}

- initWithCoder:coder
{
	[super init];
	image = [[coder decodeObjectForKey:@"image"] retain];
	name = [[coder decodeObjectForKey:@"name"] retain];
	visible = YES;
	if([coder decodeObjectForKey:@"opacity"] != nil)
	{	
		opacity = [[coder decodeObjectForKey:@"opacity"] doubleValue];
	}
	else
	{
		opacity = 100;
	}
	return self;
}

- (void)encodeWithCoder:coder
{
	[coder encodeObject:image forKey:@"image"];
	[coder encodeObject:name forKey:@"name"];
	[coder encodeObject:[NSNumber numberWithDouble:opacity] forKey:@"opacity"];
}

- copyWithZone:(NSZone *)zone
{
	id copy = [[[self class] allocWithZone:zone] initWithName:name image:[[image copyWithZone:zone] autorelease]];
	[copy setOpacity:opacity];
	[copy setVisible:visible];
	[copy setLayerController:layerController];
	return copy;
}

- (void)setLayerController:controller
{
	layerController = controller;
}

- (void)delete:sender
{
	[layerController removeLayerObject:self];
}

- (void)duplicate:sender
{
	[layerController duplicateLayerObject:self];
}

- (void)mergeDown:sender
{
	[layerController mergeDownLayerObject:self];
}

@end
