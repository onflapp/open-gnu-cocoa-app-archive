//
//  PXDuotoneBackground.m
//  Pixen-XCode
//
//  Created by Joe Osborn on Tue Oct 28 2003.
//  Copyright (c) 2003 Open Sword Group. All rights reserved.
//

#import "PXDuotoneBackground.h"


@implementation PXDuotoneBackground

- (NSString *)nibName
{
    return @"PXDuotoneBackgroundConfigurator";
}

- (void)setConfiguratorEnabled:(BOOL)enabled
{
    [backWell setEnabled:enabled];
    [super setConfiguratorEnabled:enabled];
}

- (IBAction)configuratorBackColorChanged:sender
{
#ifdef __COCOA__
    [self setBackColor:[sender color]];
#endif
    [self changed];
}

- (void)setBackColor:aColor
{
    [aColor retain];
    [backColor release];
    backColor = aColor;
    if(aColor != nil) { [backWell setColor:aColor]; }
}

- init
{
    [super init];
    [self setColor:[NSColor lightGrayColor]];
    [self setBackColor:[NSColor whiteColor]];
    return self;
}

- copyWithZone:(NSZone *)zone
{
    id copy = [super copyWithZone:zone];
    [copy setBackColor:backColor];
    return copy;
}

- (void)encodeWithCoder:coder
{
    [coder encodeObject:backColor forKey:@"backColor"];
    [super encodeWithCoder:coder];
}

- initWithCoder:coder
{
    [super initWithCoder:coder];
    [self setBackColor:[coder decodeObjectForKey:@"backColor"]];
    return self;
}

- (void)dealloc
{
    [self setBackColor:nil];
    [super dealloc];
}

@end
