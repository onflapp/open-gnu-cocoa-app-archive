/* NSView_SenAdditions.h created by marco on Sun 07-Dec-1997 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <AppKit/AppKit.h>

typedef enum {
    HorizontalLeftAlignment,
    HorizontalCenterAlignment,
    HorizontalRightAlignment,
    HorizontalNoAlignment

} HorizontalAlignment;

typedef enum {
    VerticalTopAlignment,
    VerticalCenterAlignment,
    VerticalBottomAlignment,
    VerticalNoAlignment

} VerticalAlignment;


@interface NSView (SenAdditions)

- (void) addSubview:(NSView *) aView hAlignment:(HorizontalAlignment) hAlignment vAlignment:(VerticalAlignment) vAlignment;
- (void) addSubview:(NSView *) subView isFilling:(BOOL) isFilling;

@end
