//
//  PXBackground.m
//  Pixen-XCode
//
//  Created by Joe Osborn on Mon Oct 27 2003.
//  Copyright (c) 2003 Open Sword Group. All rights reserved.
//

#import "PXBackground.h"


@implementation PXBackground

- init
{
    [super init];
    [self configurator];
    [self setName:[self defaultName]];
    return self;
}

- defaultName
{
    return [self className];
}

- (NSString *)name
{
    return name;   
}

- (void)setName:aName
{
    id old = name;
    name = [aName copy];
    [old release];
}

- (NSView *)configurator
{
    if([self class] == [PXBackground class]) { return nil; }
    if(configurator == nil) { [NSBundle loadNibNamed:[self nibName] owner:self]; }
    NSAssert1(configurator != nil, @"No configurator for %@!", self);
    return configurator;
}

- (NSString *)nibName
{
    return @"";
}

- (void)setConfiguratorEnabled:(BOOL)enabled
{
    
}

- (void)changed
{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"PXBackgroundChanged" object:self];
}

- (void)drawRect:(NSRect)rect withinRect:(NSRect)wholeRect withTransform:aTransform onCanvas:aCanvas
{
    //default behavior is to draw outside of the current transform.
    [aTransform invert];
    [aTransform concat];
    [self drawRect:rect withinRect:wholeRect];
    [aTransform invert];
    [aTransform concat];
}

- (void)drawRect:(NSRect)rect withinRect:(NSRect)wholeRect
{
    NSLog(@"drawRect:withinRect: of abstract PXBackground class's instance called.  Why?");
}

- copyWithZone:(NSZone *)zone
{
    id copy = [[[self class] allocWithZone:zone] init];
    return copy;
}

- (void)encodeWithCoder:coder
{
    [coder encodeObject:name forKey:@"name"];
}

- initWithCoder:coder
{
    [super init];
    [self setName:[coder decodeObjectForKey:@"name"]];
    [self configurator];
    return self;
}

@end
