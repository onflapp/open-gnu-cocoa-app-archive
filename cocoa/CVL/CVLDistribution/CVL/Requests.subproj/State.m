/* State.m created by ja on Fri 18-Feb-2000 */
/* Copyright (c) 1997, Sen:te Ltd.  All rights reserved. */

#import "State.h"
#import "Transition.h"

#define DEBUG_FSM 1

@interface State (Private)
- (void)setAttributes:(NSDictionary *)attributes;
- (void)setEnteringSelector:(SEL)selector;
- (SEL)enteringSelector;
- (void)addTransition:(Transition *)transition;

+ (NSDictionary *)readStatesFromProperties:(NSDictionary *)machineStateProperties;
+ (BOOL) readTransitionsBetweenStates:(NSDictionary *)machineStates fromProperties:(NSDictionary *)machineTransitionsProperties;
@end

@implementation State
+ (State *)initialStateForStateFile:(NSString *)filePath
{
    NSDictionary *machineStates;
    State *state=nil;
    NSDictionary *properties;
    NSDictionary *machineStatesProperties;

    if ( (properties=[NSDictionary dictionaryWithContentsOfFile:filePath]) ) {
        machineStatesProperties=[properties objectForKey:@"states"];
        if ( (machineStates=[self readStatesFromProperties:machineStatesProperties]) ) {
            if ([self readTransitionsBetweenStates:machineStates fromProperties:[properties objectForKey:@"transitions"]]) {
                state=[machineStates objectForKey:[properties objectForKey:@"beginState"]];
            }
        }
    }
    return state;
}

+ (NSDictionary *)readStatesFromProperties:(NSDictionary *)machineStatesProperties
{
    NSMutableDictionary *machineStates=nil;
    BOOL ok=YES;

    if (machineStatesProperties && [machineStatesProperties isKindOfClass:[NSDictionary class]]) {
        id stateKeyEnumerator;
        NSString *stateKey;
        NSDictionary *stateProperties=nil;
        NSDictionary *stateAttributes;
        NSString *stateEnteringSelectorName;
        State *state;

        machineStates=[NSMutableDictionary dictionary];

        stateKeyEnumerator=[machineStatesProperties keyEnumerator];
        while (ok && (stateKey=[stateKeyEnumerator nextObject])) {
            stateProperties=[machineStatesProperties objectForKey:stateKey];
            if ([stateProperties isKindOfClass:[NSDictionary class]]) {
                state=[[self alloc] init];
                stateAttributes=[stateProperties objectForKey:@"attributes"];
                if (stateAttributes) {
                    if ([stateAttributes isKindOfClass:[NSDictionary class]]) {
                        [state setAttributes:stateAttributes];
                    } else ok=NO;
                }

                if (ok) {
                    stateEnteringSelectorName=[stateProperties objectForKey:@"enteringSelector"];
                    if (stateEnteringSelectorName) {
                        if ([stateEnteringSelectorName isKindOfClass:[NSString class]]) {
                        [state setEnteringSelector:NSSelectorFromString(stateEnteringSelectorName)];
                        } else ok=NO;
                    }

                    if (ok) [machineStates setObject:state forKey:stateKey];
                    [state release];
                }
            } else ok=NO;
        }
    } else ok=NO;

    if (!ok) {
        return nil;
    } else {
        return machineStates;
    }
}

+ (BOOL) readTransitionsBetweenStates:(NSDictionary *)machineStates fromProperties:(NSDictionary *)machineTransitionsProperties
{
    BOOL ok=YES;
    
    if (machineTransitionsProperties && [machineTransitionsProperties isKindOfClass:[NSArray class]]) {
        id transitionEnumerator;
        NSDictionary *transitionProperties;
        NSString *conditionSelectorName;
        State *targetState;
        State *state;
        Transition *transition;

        transitionEnumerator=[machineTransitionsProperties objectEnumerator];
        while (ok && (transitionProperties=[transitionEnumerator nextObject])) {
            state=[machineStates objectForKey:[transitionProperties objectForKey:@"sourceState"]];
            targetState=[machineStates objectForKey:[transitionProperties objectForKey:@"targetState"]];
            conditionSelectorName=[transitionProperties objectForKey:@"conditionSelector"];
            if (state && targetState && conditionSelectorName && [conditionSelectorName isKindOfClass:[NSString class]]) {
                transition=[[Transition alloc] initWithTargetState:targetState condition:NSSelectorFromString(conditionSelectorName)];
                [state addTransition:transition];
                [transition release];
            } else ok=NO;
        }
    }
    return ok;
}

- init
{
    if ( (self=[super init]) ) {
        transitions=[[NSMutableArray alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [transitions release];

    [super dealloc];
}

- (State *)nextStateForMachine:(id)machine
{
    id transitionEnumerator;
    Transition *transition;
    NSInvocation *invocation;
    NSMethodSignature *conditionMethodSignature;
    BOOL conditionValue;
    State *newState=nil;
    
    conditionMethodSignature=[[self class] instanceMethodSignatureForSelector:@selector(condition)];
    invocation=[NSInvocation invocationWithMethodSignature:conditionMethodSignature];
    [invocation setTarget:machine];
    
    transitionEnumerator=[transitions objectEnumerator];
    while (!newState && (transition=[transitionEnumerator nextObject])) {
        [invocation setSelector:[transition conditionSelector]];
        [invocation invoke];
        [invocation getReturnValue:&conditionValue];
        if (DEBUG_FSM) {
            NSLog (@"%@=%i",NSStringFromSelector([transition conditionSelector]),conditionValue);
        }
        if (conditionValue) {
            newState=[transition targetState];
        }
    }
    if (DEBUG_FSM) {
        NSLog (@"New state %@ for machine %@",newState,machine);
    }
    return newState;
}

- (BOOL)condition
{
    return NO;
}

- (void)setAttributes:(NSDictionary *)value
{
    [value retain];
    [attributes release];
    attributes=value;
}

- (void)setEnteringSelector:(SEL)selector
{
    enteringSelector=selector;
}

- (SEL)enteringSelector
{
    return enteringSelector;
}

- (void)addTransition:(Transition *)transition
{
    [transitions addObject:transition];
}

- (BOOL)isTerminal
{
    return [transitions count]==0;
}

- (id)valueForKey:(NSString *)key
{
    return [attributes objectForKey:key];
}
@end
