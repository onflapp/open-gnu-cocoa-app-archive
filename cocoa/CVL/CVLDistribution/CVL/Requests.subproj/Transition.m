/* Transition.m created by ja on Fri 18-Feb-2000 */
/* Copyright (c) 1997, Sen:te Ltd.  All rights reserved. */

#import "Transition.h"
#import "State.h"

@implementation Transition
- (id)initWithTargetState:(State *)state condition:(SEL)selector
{
    if ( (self=[super init]) ) {
        conditionSelector=selector;
        targetState=[state retain];
    }
    return self;
}

- (void)dealloc
{
    [targetState release];
    [super dealloc];
}

- (SEL)conditionSelector
{
    return conditionSelector;
}

- (State *)targetState
{
    return targetState;
}

@end
