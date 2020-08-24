
// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "NSView_SenAdditions.h"

@implementation NSView (SenAdditions)

- (void) addSubview:(NSView *) subView isFilling:(BOOL) isFilling
{
    if (isFilling) {
        NSRect superFrame = [self frame];
        NSRect subFrame = superFrame;
        subFrame.origin = (NSPoint) {0, 0};

        //[self setAutoresizesSubviews:YES];
        [subView setFrame:subFrame];
        [self addSubview:subView];
        [subView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    }
    else {
        [self addSubview:subView hAlignment:HorizontalCenterAlignment vAlignment:VerticalCenterAlignment];
    }
}


- (void) addSubview:(NSView *) subView hAlignment:(HorizontalAlignment) hAlignment vAlignment:(VerticalAlignment) vAlignment
{
    NSRect superFrame = [self frame];
    NSRect subFrame = [subView frame];

    subFrame.size = superFrame.size;
    
    switch (hAlignment) {
        case HorizontalLeftAlignment:
            subFrame.origin.x = 0;
            break;
        case HorizontalCenterAlignment:
            subFrame.origin.x = (NSWidth (superFrame) - NSWidth (subFrame)) / 2.0;
            break;
        case HorizontalRightAlignment:
             subFrame.origin.x = (NSWidth (superFrame) - NSWidth (subFrame));
           break;
        default:
            break;
    }

    switch (vAlignment) {
        case VerticalBottomAlignment:
            subFrame.origin.y = 0;
            break;
        case VerticalCenterAlignment:
            subFrame.origin.y = (NSHeight (superFrame) - NSHeight (subFrame)) / 2.0;
            break;
        case VerticalTopAlignment:
            subFrame.origin.y = (NSHeight (superFrame) - NSHeight (subFrame));
            break;
        default:
            break;
    }

    [subView setFrame:subFrame];
    [self addSubview:subView];
}


@end
