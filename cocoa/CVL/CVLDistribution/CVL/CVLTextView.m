//
//  CVLTextView.m
//  CVL
//
//  Created by Stephane Corthesy on Thu Jul 03 2003.
//  Copyright (c) 2003 Sen:te. All rights reserved.
//

#import "CVLTextView.h"


@implementation CVLTextView

- (void) interpretKeyEvents:(NSArray *)eventArray
{
    if([eventArray count] == 1){
        NSString	*chars = [(NSEvent *)[eventArray lastObject] characters];

        if([chars length] == 1){
            switch([chars characterAtIndex:0]){
                case NSEnterCharacter:
                    [[self target] performSelector:[self action] withObject:self];
                    return;
                case 0x001B: // ESC
                    [[self escapeTarget] performSelector:[self escapeAction] withObject:self];
                    return;
            }
        }
    }
    [super interpretKeyEvents:eventArray];
}

- (id) target
{
    return target;
}

- (void) setTarget:(id)newTarget
{
    target = newTarget;
}

- (SEL) action
{
    return action;
}

- (void) setAction:(SEL)newAction
{
    action = newAction;
}

- (id) escapeTarget
{
    return escapeTarget;
}

- (void) setEscapeTarget:(id)newTarget
{
    escapeTarget = newTarget;
}

- (SEL) escapeAction
{
    return escapeAction;
}

- (void) setEscapeAction:(SEL)newAction
{
    escapeAction = newAction;
}

@end
