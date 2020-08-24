//
//  CVLTextView.h
//  CVL
//
//  Created by Stephane Corthesy on Thu Jul 03 2003.
//  Copyright (c) 2003 Sen:te. All rights reserved.
//

#import <AppKit/AppKit.h>


/*
 * Simple subclass of NSTextView to let the Enter key send an action to a target.
 * Used for the commit panel.
 */

@interface CVLTextView : NSTextView {
    IBOutlet id	target;
    SEL			action;
    IBOutlet id	escapeTarget;
    SEL			escapeAction;
}

- (id) target;
- (void) setTarget:(id)target;

- (SEL) action;
- (void) setAction:(SEL)action;

- (id) escapeTarget;
- (void) setEscapeTarget:(id)target;

- (SEL) escapeAction;
- (void) setEscapeAction:(SEL)action;

@end
