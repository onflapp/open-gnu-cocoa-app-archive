//
//  PXPalette.m
//  Pixen-XCode
//
//  Created by Joe Osborn on Wed Jun 09 2004.
//  Copyright (c) 2004 Open Sword Group. All rights reserved.
//

#import "PXPalette.h"

@implementation PXPalette

- initWithName:aName
{
	return [self initWithName:aName colors:[[NSMutableArray alloc] initWithCapacity:32]];
}

- initWithName:aName colors:someColors
{
	[super init];
	usedColors = [someColors mutableCopy];
	name = [aName copy];
	return self;
}

- (void)setDelegate:anObject
{
	delegate = anObject;
}

- (void)dealloc
{
	[usedColors release];
	[name release];
	[super dealloc];
}

- (int)addColor:color
{
	if(([color alphaComponent] < .00125) || [usedColors containsObject:color] || [usedColors count] > 255) { return -1; }
	int index = [usedColors count];
	int i;
	for(i = 0; i < [usedColors count]; i++)
	{
		if([[usedColors objectAtIndex:i] alphaComponent] <= .00125)
		{
			index = i;
			break;
		}
	}
	[usedColors insertObject:color atIndex:index];
	return index;
}

- colorAtIndex:(unsigned)index
{
	return [usedColors objectAtIndex:index];
}

- (void)setColor:color atIndex:(unsigned)index
{
	while([usedColors count] <= index)
	{
		[usedColors addObject:[NSColor colorWithCalibratedRed:0 green:0 blue:0 alpha:.001]];
	}
	[usedColors replaceObjectAtIndex:index withObject:color];
	[self removeDuplicatesOfColorAtIndex:index];
}

- (void)removeDuplicatesOfColorAtIndex:(unsigned)index
{	
	id color = [usedColors objectAtIndex:index];
	int i;
	for(i = 0; i < [usedColors count]; i++)
	{
		id current = [usedColors objectAtIndex:i];
		if([current isEqual:color] && (current != color) && ([current alphaComponent] > .00125))
		{
			//Not sure !! (Fabien) 
			[delegate palette:self foundDuplicateColorsAtIndex:index andIndex:i];
		}
	}
}

- colors
{
	return usedColors;
}

- (void)setColors:newColors
{
	id old = usedColors;
	usedColors = [newColors mutableCopy];
	[old release];
}

- name
{
	return name;
}

- (void)setName:newName
{
	[name autorelease]; 
	name = [newName copy];
}

- copyWithZone:(NSZone *)zone
{
	id copy = [[[self class] allocWithZone:zone] initWithName:name];
	[copy setColors:[[usedColors mutableCopy] autorelease]];
	return copy;
}

- initWithCoder:coder
{
	[super init];
	name = [[coder decodeObjectForKey:@"name"] retain];
	usedColors = [[coder decodeObjectForKey:@"usedColors"] mutableCopy];
	return self;
}

- (void)encodeWithCoder:coder
{
	[coder encodeObject:name forKey:@"name"];
	[coder encodeObject:usedColors forKey:@"usedColors"];
}

@end