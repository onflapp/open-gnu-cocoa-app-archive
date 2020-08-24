/* Request.h created by vincent on Fri 14-Nov-1997 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <Foundation/Foundation.h>
#ifdef JA_PATCH
#import "State.h"
#endif


@class NSArray, NSSet, NSMutableSet;


#define STATE_IDLE 0
#define STATE_READY 4
#define STATE_RUNNING 1
#define STATE_WAITING 2
#define STATE_ENDED 3

#define INTERNAL_STATE_NOT_STARTED 0
#define INTERNAL_STATE_TASK_RUN_TASK 1
#define INTERNAL_STATE_CVS_RETRY_AFTER_LOGIN 2
#define INTERNAL_STATE_CVS_TRY_LOGIN 3
#define INTERNAL_STATE_LOGIN_FIRST_PANEL 4
#define INTERNAL_STATE_LOGIN_PANEL 5
#define INTERNAL_STATE_WAITING_FOR_STATUSES 6
#define INTERNAL_STATE_WAITING_FOR_CHILDREN 7


extern NSString* RequestNewLineString;



@interface Request : NSObject
{
    NSNumber *sequenceId; // For debugging purposes.
#ifdef JA_PATCH
    NSString *cmdTitle;
    BOOL success;
    int order;

    State *currentState;
#else
    NSString *cmdTitle;
    int state;
    int internalState;
    int endConditionsCount;
    NSMutableSet *precedingRequests;
    BOOL success;
    int order;
#endif
}

- (NSNumber *)sequenceId;

#ifdef JA_PATCH
+ (State *)initialState;
- (State *)currentState;
- (void)updateState;
#endif

+ requestWithTitle:(NSString *)cmdString;
- initWithTitle:(NSString *)cmdString;

- (void)schedule;
#ifndef JA_PATCH
- (int)state;
- (void)setState:(int)aState;
- (void)start;

// methods used by the Scheduler, modify the state and send a notification
- (void)resumeNow; // NB: there is a method -(BOOL)resume declared in NSSound
#endif
- (void)setOrder:(int)aNumber;

- (NSComparisonResult)hasPriorityComparedToRequest:(Request *)anotherRequest;
- (int)priority;
- (int)order;

// methods called by other objects
//- (void)stop;
//- (void)pause;
- (void)schedule;

#ifndef JA_PATCH
// methods called by the request 
- (void)end;
- (void)cancel;
- (BOOL) canBeCancelled;

- (BOOL)addPrecedingRequest:(Request *)aRequest;
- (NSSet *)precedingRequests;
- (BOOL) canContinue; // called by scheduler for transition WAITING->RUNNING
- (BOOL) precedingRequestsEnded;
#endif
- (BOOL) canRunAgainstRequests:(NSSet *)runningRequests;
- (BOOL) canRunAgainstRequest:(Request *)runningRequest;

// query methods
- (NSString *)cmdTitle;
- (NSString *)summary;
- (NSString *)stateString;
- (NSString *)internalStateString;

#ifndef JA_PATCH
-(void)endConditionReached;
#endif

- (BOOL)succeeded;

- (NSString *)shortDescription;
- (NSMutableDictionary *)descriptionDictionary;
- (NSString *)moreInfoString;

- (NSArray *) modifiedFiles;
    // Result is passed in RequestCompleted notification userInfo, under key ModifiedFiles
    // Default implementation returns nil; should be overridden by subclasses

@end
