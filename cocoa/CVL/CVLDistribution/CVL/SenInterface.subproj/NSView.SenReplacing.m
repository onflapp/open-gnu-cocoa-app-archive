/* NSView.SenReplacing.m created by stephane on Fri 03-Sep-1999 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "NSView.SenReplacing.h"

@implementation NSView(SenReplacing)

- (void) senReplaceView:(NSView *)aView
{
    [self setFrame:[aView frame]];
    [[aView superview] replaceSubview:aView with:self];
    // we also need to restore nextKey chain... See lysCode
}

@end
