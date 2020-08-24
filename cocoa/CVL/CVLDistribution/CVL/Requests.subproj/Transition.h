/* Transition.h created by ja on Fri 18-Feb-2000 */
/* Copyright (c) 1997, Sen:te Ltd.  All rights reserved. */

#import <AppKit/AppKit.h>

@class State;

@interface Transition : NSObject
{
    SEL conditionSelector;
    State *targetState;
}
- (id)initWithTargetState:(State *)state condition:(SEL)selector;
- (SEL)conditionSelector;
- (State *)targetState;

@end
