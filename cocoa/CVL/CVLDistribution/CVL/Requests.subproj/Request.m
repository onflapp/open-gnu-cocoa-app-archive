/* Request.m created by vincent on Fri 14-Nov-1997 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "Request.h"
#import "CVLScheduler.h"
#import <Foundation/Foundation.h>
#import <SenFoundation/SenFoundation.h>

static int sequence = 0;


NSString* RequestNewLineString= @"\n";



#ifndef JA_PATCH
@interface Request (Private)
- (void)endConditionReached;
- (void)precedingRequestCompleted:(NSNotification *)notification;
@end
#endif

@implementation Request
+ requestWithTitle:(NSString *)cmdString
{
  return [[[self alloc] initWithTitle: cmdString] autorelease];
}


- initWithTitle:(NSString *)cmdString
{
  self=[self init];
  ASSIGN(cmdTitle, cmdString);
#ifndef JA_PATCH
  state=STATE_IDLE;
#endif
  // For debugging purposes; otherwise it is hard to tell which request is which.
  sequence++;
  sequenceId = [[NSNumber alloc] initWithInt:sequence];
  
  return self;
}

-(void)dealloc
{
//    NSLog(@"Deallocing %p <%s>", self, object_getClassName(self));
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    RELEASE(cmdTitle);
#ifndef JA_PATCH
    RELEASE(precedingRequests);
#endif
    
    [super dealloc];
}

#if 0
+ (id) allocWithZone:(NSZone *)zone
{
    id  newInstance = [super allocWithZone:zone];
    
    NSLog(@"alloc %p <%s>", newInstance, object_getClassName(newInstance));
    
    return newInstance;
}

- (id) retain
{
    NSLog(@"retain %p <%s>", self, object_getClassName(self));
    return [super retain];
}

- (void) release
{
    NSLog(@"release %p <%s>", self, object_getClassName(self));
    [super release];
}

- (id) autorelease
{
    NSLog(@"autorelease %p <%s>", self, object_getClassName(self));
    return [super autorelease];
}
#endif

- (NSNumber *)sequenceId
    /*" This method returns a sequence ID number starting with 1 for the first
        request created by this application, then 2 for the second request and
        so on. This sequence ID is only being used for debugging purposes so we
        can tell the different requests apart from one another.
    "*/
{
    return sequenceId;
}

#ifndef JA_PATCH
-(void)start
{
    success=YES;
    [self setState:STATE_RUNNING];
}

- (void)resumeNow
{
    if (internalState==INTERNAL_STATE_NOT_STARTED) {
        [self start];
    }
}

-(void)endConditionReached
{
    endConditionsCount--;
    if (!endConditionsCount) {
        [self end];
    }
}

-(void)cancel
{
    if([self canBeCancelled]){
        success=NO;
        [self end];
    }
}

- (BOOL) canBeCancelled
{
    return [self state] != STATE_ENDED;
}

-(void)end
{
    NSArray	*modifiedFiles = [self modifiedFiles];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self setState:STATE_ENDED];

    if(modifiedFiles != nil)
        [[NSNotificationCenter defaultCenter] postNotificationName:@"RequestCompleted" object:self userInfo:[NSDictionary dictionaryWithObject:modifiedFiles forKey:@"ModifiedFiles"]];
    else
        [[NSNotificationCenter defaultCenter] postNotificationName:@"RequestCompleted" object:self];
    [self autorelease]; // FIXME (stephane) See -schedule
}
#endif

-(NSString *)cmdTitle
{
  return cmdTitle;
}

-(NSString *)summary
{
    return @"";
}

#ifdef JA_PATCH
-(State *)currentState
{
    return currentState;
}

- (NSString *)stateString
{
    return [currentState valueForKey:@"description"];
}
#else
-(int)state
{
  return state;
}

- (NSString *)stateString
{
    switch (state) {
        case STATE_IDLE:
            return @"";
            break;

        case STATE_READY:
            return @"Ready";
            break;
            
        case STATE_WAITING:
            return @"Waiting";
            break;

        case STATE_RUNNING:
            return @"Running";
            break;

        case STATE_ENDED:
            if (success)
                return @"Done";
            else
                return @"Canceled";
            
            break;
    }

    return @"";
}

- (void)setState:(int)aState
{
    state=aState;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"RequestStateChanged" object:self];
}

- (NSString *)internalStateString
    /*" This method returns a string that describes the internalState code, 
        which is an integer. This method is used to display the internalState
        code to the user in an understandable way.
    "*/
{
    switch (internalState) {
        case INTERNAL_STATE_NOT_STARTED:
            return @"Not Started";
            break;            
        case INTERNAL_STATE_TASK_RUN_TASK:
            return @"Task Run Task";
            break;
        case INTERNAL_STATE_CVS_RETRY_AFTER_LOGIN:
            return @"CVS Retry after Login";
            break;
        case INTERNAL_STATE_CVS_TRY_LOGIN:
            return @"CVS Try Login";
            break;
        case INTERNAL_STATE_LOGIN_FIRST_PANEL:
            return @"Login First Panel";            
            break;
        case INTERNAL_STATE_LOGIN_PANEL:
            return @"Login Panel";
            break;
        case INTERNAL_STATE_WAITING_FOR_STATUSES:
            return @"Waiting for Statuses";            
            break;
        case INTERNAL_STATE_WAITING_FOR_CHILDREN:
            return @"Waiting for Children";
            break;            
    }
    
    return @"";
}

- (BOOL)addPrecedingRequest:(Request *)aRequest
{
    if (!precedingRequests) {
        precedingRequests=[[NSMutableSet alloc] initWithCapacity:1];
    }
    [precedingRequests addObject:aRequest];
    [[NSNotificationCenter defaultCenter] addObserver:self                    selector:@selector(precedingRequestCompleted:)
                                                 name:@"RequestCompleted"
                                               object:aRequest];

    return YES;
}

- (void)precedingRequestCompleted:(NSNotification *)notification
{
    Request *aRequest=[notification object];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:@"RequestCompleted"
                                                  object:aRequest];
    if (![aRequest succeeded]) {
        [self cancel];
    } else {
        [precedingRequests removeObject:aRequest];
        if ([self canContinue]) {
            [self setState:STATE_READY];
        }
    }
}

- (NSSet *)precedingRequests
{
    return precedingRequests;
}

- (BOOL) precedingRequestsEnded
{
    return ([[self precedingRequests] count]==0);
}
#endif

- (BOOL) canRunAgainstRequests:(NSSet *)runningRequests
{
    id enumerator;
    Request *aRequest;

    enumerator=[runningRequests objectEnumerator];
    while ( (aRequest=[enumerator nextObject]) ) {
        if (![self canRunAgainstRequest:aRequest]) return NO;
    }
    return YES;
}

- (BOOL) canRunAgainstRequest:(Request *)runningRequest
{
    return YES;
}

#ifndef JA_PATCH
- (BOOL) canContinue
{
    return [self precedingRequestsEnded];
}

- (void)schedule
{
    [self retain]; // FIXME (stephane) Why do we need to retain ourself (we autorelease in -end)? Scheduler does retain us.
    [[CVLScheduler sharedScheduler] scheduleRequest:self];
    if ([self canContinue]) {
        [self setState:STATE_READY];
    } else {
        [self setState:STATE_WAITING];
    }
}
#endif

- (BOOL)succeeded
{
    return success;
}

- (NSString *)shortDescription
{
    return cmdTitle;
}

- (NSMutableDictionary *)descriptionDictionary
    /*" This method returns a description of this instance in the form of a 
        dictionary. The keys are the names of the instance variables and the 
        values are the values of those instance variables. The keys return here 
        are sequenceId, cmdTitle, stateString and internalStateString. Using a
        method like this makes it easy to added more keys and values to the 
        description in subclasses.

        This method is used for debugging purposes.
    "*/
{
    NSMutableDictionary* dict= [NSMutableDictionary dictionaryWithCapacity: 4];
    
    [dict setObject: [self className] forKey: @"className"];
    [dict setObject: (cmdTitle ? cmdTitle : @"") forKey: @"cmdTitle"];
    [dict setObject: [self stateString] forKey: @"stateString"];
    [dict setObject: [self internalStateString] forKey: @"internalStateString"];
    [dict setObject: [self sequenceId] forKey: @"sequenceId"];

    return [[dict retain] autorelease];
}

- (NSString *)description
    /*" This method overrides supers implementation. Here we return the 
        description of the dictionary obtained from the method 
        -descriptionDictionary.

        See Also #{-descriptionDictionary}
    "*/
{
    NSString *aDescription = nil;
    
    aDescription = [[self descriptionDictionary] description];
    
    return aDescription;
}

- (NSString *)moreInfoString
    /*" This is a method that returns more information about this request.
        Mainly we are talking about the instance variables some of which have 
        been converted to informational strings. This is mostly used for 
        debugging purposes but also appears in the processes panel.
    "*/
{    
    NSString *moreInfoString = nil;
    NSString *myClassName = nil;
    
    myClassName = [self className];
    moreInfoString =  [NSString stringWithFormat:
          @"Class Name: %@\nTitle: %@\nState: %@\nInternal State: %@\nEnd Conditions Count: %d\nSuccess: %@\nOrder: %d", 
        myClassName, cmdTitle, [self stateString], [self internalStateString], 
        endConditionsCount, (success ? @"YES" : @"NO"), order];
    return moreInfoString;
}

- (void)setOrder:(int)aNumber
{
    order=aNumber;
}

- (int)order
{
    return order;
}

- (int)priority
{
    return 0;
}

- (NSComparisonResult)hasPriorityComparedToRequest:(Request *)anotherRequest
{
    int comparison;

    comparison=[self priority]-[anotherRequest priority];

    if (comparison==0) comparison=[anotherRequest order]-[self order];
    
    if (comparison==0) return NSOrderedSame;
    if (comparison<0) return NSOrderedDescending;
    return NSOrderedAscending;
}

#ifdef JA_PATCH
+ (State *)initialState
{
    return nil;
}

- (void)updateState
{
    State *nextState;

    if (!currentState) {
        NSString *aMsg = nil;
        
        nextState=[[self class] initialState];
        aMsg = [NSString stringWithFormat:@"Next state",nextState];
        SEN_LOG(aMsg);        
    } else {
        nextState=[currentState nextStateForMachine:self];
    }
    if (nextState) {
        SEL selector=[nextState enteringSelector];

        ASSIGN(currentState, nextState);
        if (selector!=NULL) {
            [self performSelector:selector];
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:@"RequestStateDidChange" object:self];
        if ([currentState isTerminal]) {
            [[NSNotificationCenter defaultCenter] postNotificationName:@"RequestCompleted" object:self];
        } else {
            [self updateState];
        }
    }
}

- (void)schedule
{
    [[CVLScheduler sharedScheduler] scheduleRequest:self];
    [self updateState];
}
#endif

- (NSArray *) modifiedFiles
{
    return nil;
}

@end
