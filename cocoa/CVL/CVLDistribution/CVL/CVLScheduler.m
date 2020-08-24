/* CVLScheduler.m created by vincent on Tue 25-Nov-1997 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "CVLScheduler.h"

#import <CvsRequest.h>
#import <Foundation/Foundation.h>
#import <SenFoundation/SenFoundation.h>


// It may happen that cvs commands never end, particularly when using ssh,
// because the connection cannot be established. That's why we put a timeout
// on the requests. If timeout value is zero, no timeout is set.
#define DEFAULT_REQUEST_TIMEOUT	120

static int timerInterval = 0;
static CVLScheduler* uniqueInstance= nil;


@interface CVLScheduler (Private)

- (void) startRequest: (Request*) aRequest;
- (void) scheduleDelayed:(id)sender;
- (void) schedule;

@end


@implementation CVLScheduler

+ sharedScheduler
{
    if (!uniqueInstance)
      {
        timerInterval = [[NSUserDefaults standardUserDefaults] integerForKey:@"RequestTimeout"];
        if(timerInterval < 0)
            timerInterval = 0;
        uniqueInstance= [[self alloc] init];
      }
    return uniqueInstance;
}


- init
{
    self = [super init];
    pendingRequests= [[NSMutableArray alloc] initWithCapacity:1];
    runningRequests= [[NSMutableSet alloc] initWithCapacity:1];
    requests=[[NSMutableSet alloc] initWithCapacity:1];
    timers = NSCreateMapTableWithZone(NSObjectMapKeyCallBacks, NSObjectMapValueCallBacks, 0, [self zone]);
    
    return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver: self];
    RELEASE(pendingRequests);
    RELEASE(runningRequests);
    [NSAllMapTableValues(timers) makeObjectsPerformSelector:@selector(invalidate)];
    NSFreeMapTable(timers);
    RELEASE(requests);
    [super dealloc];
}

- (void) schedule
{
    [self performSelector:@selector(scheduleDelayed:) withObject:self afterDelay:0 inModes:[NSArray arrayWithObjects:NSDefaultRunLoopMode, /*NSModalPanelRunLoopMode,*/ nil]];
}

- (void) scheduleDelayed:(id)sender
{
    id enumerator;
    id aRequest;
    NSMutableArray *candidates;
    NSMutableArray *removedCandidates;
    BOOL aRequestCouldBeStarted=YES;
    BOOL aRequestHasBeenStarted=NO;
    unsigned int aCount = [pendingRequests count];
    
    if ( aCount == 0 ) {
        // Nothing to do.
        return; 
    }
//    NSLog(@"$$$ pendingRequests count = %u", aCount);
    candidates=[pendingRequests mutableCopy];
    
    [candidates sortUsingSelector:@selector(hasPriorityComparedToRequest:)];
    removedCandidates = [NSMutableArray arrayWithCapacity:aCount];
    while (aRequestCouldBeStarted) {
        enumerator=[candidates objectEnumerator];
        aRequestHasBeenStarted=NO;
        while (!aRequestHasBeenStarted && (aRequest=[enumerator nextObject])) {
#ifdef JA_PATCH
            if ([aRequest canRunAgainstRequests:runningRequests]) 
#else
            if (([aRequest state]==STATE_READY) && [aRequest canRunAgainstRequests:runningRequests]) 
#endif
            {
                if(timerInterval > 0){
                    NSTimer	*aTimer = [NSTimer scheduledTimerWithTimeInterval:timerInterval target:self selector:@selector(requestTakesTooMuchTime:) userInfo:aRequest repeats:NO];

                    NSMapInsertKnownAbsent(timers, aRequest, aTimer);
                }
                [aRequest resumeNow];
                [removedCandidates addObject:aRequest];
                aRequestHasBeenStarted=YES;
            }
        }
        [candidates removeObjectsInArray:removedCandidates];
        [removedCandidates removeAllObjects]; // Start again with empty array.
        aRequestCouldBeStarted=([candidates count] && aRequestHasBeenStarted);
    }
    [candidates release];
}

- (void) requestTakesTooMuchTime:(NSTimer *)aTimer
{
    Request	*aRequest = nil;

    if ( (aTimer != nil ) && ([aTimer isValid] == YES) ) {
        aRequest = [aTimer userInfo];
        if ( aRequest != nil ) {
            NSString *aMsg = nil;
            
            NSMapRemove(timers, aRequest);
            aMsg = [NSString stringWithFormat:@"Interrupted request %@", aRequest];
            SEN_LOG(aMsg);
#ifndef JA_PATCH
            [aRequest cancel];
#endif                    
        }
    }
}

- (void) scheduleRequest: (Request *) aRequest
{
#ifdef JA_PATCH
    if (![requests containsObject:aRequest]) {
        [[NSNotificationCenter defaultCenter]
                    addObserver:self
                       selector:@selector(requestStateDidChange:)
                           name:@"RequestStateDidChange"
                         object:aRequest];
        [requests addObject:aRequest];
        [aRequest setOrder:order++];
    }
#else
    NSSet *precedingRequests;

    if (![requests containsObject:aRequest]) {
        [[NSNotificationCenter defaultCenter]
                    addObserver:self
                       selector:@selector(requestStateChanged:)
                           name:@"RequestStateChanged"
                         object:aRequest];
//        NSLog(@"$$$ Adding6 to requests %p <%@>", aRequest, NSStringFromClass([aRequest class]));
        [requests addObject:aRequest];
        [aRequest setOrder:order++];
    }

    precedingRequests=[[aRequest precedingRequests] copy];
    [precedingRequests makeObjectsPerformSelector:@selector(schedule)];
    [precedingRequests release];
#endif
}

- (int)requestCount
{
    return [requests count];
}

- (int)requestCountForPath: (NSString*)aPath
{
    NSEnumerator *requestsEnumerator = [requests objectEnumerator];
    id request;
    int requestCount = 0;
    NSString *comparedPath = [aPath stringByAppendingString:@"/"]; // avoid the case where aPath == @"/1/dirname" and the request path is @"/1/dirnameplus"

    while ( (request = [requestsEnumerator nextObject]) ) {
        if ([request isKindOfClass:[CvsRequest class]]) {
            requestCount += [[[request path] stringByAppendingString:@"/"] hasPrefix:comparedPath];
        }
    }
    return requestCount;
}

@end


@implementation CVLScheduler (RequestNotificationObserver)

#ifdef JA_PATCH
- (void)requestStateDidChange:(NSNotification *)notification
{
    Request *theRequest=[notification object];
    State *currentState=[theRequest currentState];

    if ([currentState valueForKey:@"awaitsAuthorization"]) {
        if (![pendingRequests containsObject:theRequest]) {
            [pendingRequests addObject:theRequest];
        }
    } else {
        if ([pendingRequests containsObject:theRequest]) {
            [pendingRequests removeObject:theRequest];
        }
    }

    if ([currentState valueForKey:@"isRunning"]) {
        if (![runningRequests containsObject:theRequest]) {
            [runningRequests addObject:theRequest];
        }
    } else {
        if ([runningRequests containsObject:theRequest]) {
            [runningRequests removeObject:theRequest];
        }
    }

    if ([currentState isTerminal]) {
        [(NSTimer *)NSMapGet(timers, theRequest) invalidate];
        NSMapRemove(timers, theRequest);
        [requests removeObject:theRequest];
        [[NSNotificationCenter defaultCenter]
                    removeObserver:self
                           name:nil
                            object:theRequest];
    }

    [self schedule];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SchedulerDidChange" object:self];
}
#else
- (void) requestStateChanged:(NSNotification *)notification
{
    Request *theRequest=[notification object];
    int state=[theRequest state];

    switch (state) {
        case STATE_RUNNING:
            if ([pendingRequests containsObject:theRequest]) {
//                NSLog(@"$$$ Removing2 from pendingRequests %p <%@>", theRequest, NSStringFromClass([theRequest class]));
                [pendingRequests removeObject:theRequest];
            }
//            NSLog(@"$$$ Adding4 to runningRequests %p <%@>", theRequest, NSStringFromClass([theRequest class]));
            [runningRequests addObject:theRequest];
            break;
                
        case STATE_READY:
            if ([runningRequests containsObject:theRequest]) {
//                NSLog(@"$$$ Removing4 from runningRequests %p <%@>", theRequest, NSStringFromClass([theRequest class]));
                [runningRequests removeObject:theRequest];
            }
            if (![pendingRequests containsObject:theRequest]) {
//                NSLog(@"$$$ Adding2 to pendingRequests %p <%@>", theRequest, NSStringFromClass([theRequest class]));
                [pendingRequests addObject:theRequest];
            }
            [self schedule];
            break;

        case STATE_ENDED:
            [(NSTimer *)NSMapGet(timers, theRequest) invalidate];
            NSMapRemove(timers, theRequest);
//            NSLog(@"$$$ Removing6 from requests %p <%@>", theRequest, NSStringFromClass([theRequest class]));
            [requests removeObject:theRequest];
            [[NSNotificationCenter defaultCenter]
                        removeObserver:self
                               name:nil
                                object:theRequest];
            
        case STATE_WAITING:
            if ([runningRequests containsObject:theRequest]) {
//                NSLog(@"$$$ Removing5 from runningRequests %p <%@>", theRequest, NSStringFromClass([theRequest class]));
                [runningRequests removeObject:theRequest];
            }
            [self schedule];
            break;
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SchedulerDidChange" object:self];
}
#endif

@end
