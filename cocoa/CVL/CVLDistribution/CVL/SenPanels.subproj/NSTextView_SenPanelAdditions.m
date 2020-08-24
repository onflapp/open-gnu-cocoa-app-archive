/* NSTextView_SenPanelAdditions.m created by ja on Thu 05-Mar-1998 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "NSTextView_SenPanelAdditions.h"

@implementation NSTextView (SenPanelAdditions)
- (NSCell *)selectedCell
{
    return (NSCell *)self;
}

- (id)objectValue
{
    return [[self textStorage] string];
}

- (void)setObjectValue:(id)aValue
{
    if ([aValue isKindOfClass:[NSString class]]) {
        [[[self textStorage] mutableString] setString:aValue];
    } else if ([aValue isKindOfClass:[NSAttributedString class]]) {
        [[self textStorage] setAttributedString:aValue];
    }
}

- (BOOL)hasValidObjectValue
{
    return YES;
}

@end
