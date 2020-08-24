/* SelectorRequest.h created by stephane on Mon 31-Jan-2000 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <CvsRequest.h>


// Will tell target to perform selector with argument
// argument must be an object; it may be nil.
// If execution raises an exception, exception is caught and request finishes unsuccessfully
// target and argument are retained
// On start, checks that selector and target are not NULL/nil, and checks that target responds to selector
// If not, request is cancelled

@interface SelectorRequest : Request
{
    SEL	selector;
    id	target;
    id	argument;
    BOOL canBeCancelled;
}

+ (id) requestWithTarget:(id)aTarget selector:(SEL)aSelector argument:(id)anArgument;

- (void)setCanBeCancelled:(BOOL)aState;

@end
