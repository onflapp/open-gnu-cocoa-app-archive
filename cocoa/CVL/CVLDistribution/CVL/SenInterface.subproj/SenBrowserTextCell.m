/* SenBrowserTextCell.m created by ja on Mon 02-Mar-1998 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "SenBrowserTextCell.h"
#import <SenFoundation/SenFoundation.h>

@interface SenBrowserTextCell (private)
- (NSColor *)alternateTextColor;
- (NSColor *)normalTextColor;
- (void)setUpDefaultValues;
@end

@implementation SenBrowserTextCell
- (id)copyWithZone:(NSZone *)zone
{
    SenBrowserTextCell *copy;
    
    if ( (copy=[super copyWithZone:zone]) ) {
        [copy setAlternateTextColor:alternateTextColor];
    }
    return copy;
}

- (id)init
{
    if ( (self=[super init]) ) {
        [self setUpDefaultValues];
    }
    return self;
}

- (void)setUpDefaultValues
{
    [self setWraps:NO];
    [self setFont:[NSFont controlContentFontOfSize:12]];
}

- (void)dealloc
{
    RELEASE(normalTextColor);
    RELEASE(alternateTextColor);

    [super dealloc];
}

- (void)setAlternateTextColor:(NSColor *)aColor
{
    ASSIGN(alternateTextColor, aColor);
}

- (NSColor *)alternateTextColor
{
    if (!alternateTextColor) {
        ASSIGN(alternateTextColor, [self textColor]);
    }
    [self normalTextColor];
    return alternateTextColor;
}

- (NSColor *)normalTextColor
{
    if (!normalTextColor) {
        ASSIGN(normalTextColor, [self textColor]);
    }
    return normalTextColor;
}

- (void)setState:(int)flag
{
    [super setState:flag];
    if ([self state]) {
        [self setTextColor:[self alternateTextColor]];
    } else {
        [self setTextColor:[self normalTextColor]];
    }
}

- (void)highlight:(BOOL)flag withFrame:(NSRect)cellFrame inView:(NSView *)aView
{
//    [self setState:flag];
    [self drawInteriorWithFrame:cellFrame inView:aView];
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)aView 
{
    [super drawInteriorWithFrame:cellFrame inView:aView];
}

@end
