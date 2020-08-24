//
//  PXMonotoneBackground.m
//  Pixen-XCode
//
//  Created by Joe Osborn on Sun Oct 26 2003.
//  Copyright (c) 2003 Open Sword Group. All rights reserved.
//

#import "PXMonotoneBackground.h"


@implementation PXMonotoneBackground

- defaultName
{
    return NSLocalizedString(@"FLAT_BACKGROUND", @"Flat Background");
}

- (NSString *)nibName
{
    return @"PXMonotoneBackgroundConfigurator";
}

- (void)setConfiguratorEnabled:(BOOL)enabled
{
    [colorWell setEnabled:enabled];
}

- (IBAction)configuratorColorChanged:sender
{
#ifdef __COCOA__
    [self setColor:[sender color]];
#endif
    [self changed];
}

- init
{
  [super init];
  color = [[NSColor whiteColor] retain];
  return self;
}

- (void)dealloc
{
    [self setColor:nil];
    [super dealloc];
}

- color
{
    return color;
}

- (void)setColor:aColor
{
    [aColor retain];
    [color release];
    color = aColor;
    if(aColor != nil) 
      { 
	[colorWell setColor:aColor]; 
      }
}

- (void)drawRect:(NSRect)rect withinRect:(NSRect)wholeRect
{
#ifdef __COCOA__
  [color set];
#else
  [[colorWell color] set];
#endif
  NSRectFill(rect);
}

- (void)encodeWithCoder:coder
{
    [coder encodeObject:color forKey:@"color"];
    [super encodeWithCoder:coder];
}

- initWithCoder:coder
{
    [super initWithCoder:coder];
    [self setColor:[coder decodeObjectForKey:@"color"]];
    return self;
}

- copyWithZone:(NSZone *)zone
{
    id copy = [super copyWithZone:zone];
    [copy setColor:color];
    return copy;
}

@end
