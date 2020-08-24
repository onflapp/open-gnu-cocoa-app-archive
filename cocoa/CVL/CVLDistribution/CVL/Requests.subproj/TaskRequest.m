/* TaskRequest.m created by ja on Mon 24-Nov-1997 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "TaskRequest.h"
#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#import <SenFoundation/SenFoundation.h>

#define MIN_DATA_LEN_BEFORE_NOTIF 50

static NSCharacterSet* newLineCharacterSet= nil;
static BOOL				taskTracingEnabled = NO;
static id				taskLogger = nil;

#ifndef JA_PATCH
@interface TaskRequest (Private)
- (void)cancel;
@end
#endif


@implementation TaskRequest

+ (void) initialize
{
    [super initialize];
    taskTracingEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"TaskTracingEnabled"];
}

+ (void) setLogger:(id)logger
{
    if(logger)
        NSParameterAssert([logger respondsToSelector:@selector(taskRequestWillLaunch:)]);
    taskLogger = logger;
}

- init
{
    self = [super init];

    lastReceivedString= [[NSMutableString allocWithZone:[self zone]] initWithCapacity:512];
    lastReceivedErrorString= [[NSMutableString allocWithZone:[self zone]] initWithCapacity:128];
    completeErrorMsgString= [[NSMutableString allocWithZone:[self zone]] initWithCapacity:512];
    
    if (!newLineCharacterSet)
    {
        ASSIGN(newLineCharacterSet, [NSCharacterSet characterSetWithCharactersInString: RequestNewLineString]);
    }
    parseByLine=YES;
    
    return self;
}

-(void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    RELEASE(lastReceivedString);
    RELEASE(lastReceivedErrorString);
    RELEASE(completeErrorMsgString);
    RELEASE(readHandle);
    RELEASE(errorReadHandle);
    RELEASE(errorPipe);
    RELEASE(pipe);
    RELEASE(task);
    [super dealloc];
}

-(void)start
{
#ifndef JA_PATCH
    [super start];

    if (![self startTask]) {
        [self cancel];
        return;
    }
    endConditionsCount++;
    internalState=INTERNAL_STATE_TASK_RUN_TASK;
#endif
}

-(BOOL)startTask
{
#ifdef JA_PATCH
    success=YES;
    if ([self setUpTask]) {
        if(taskTracingEnabled) {
            NSString *aMsg = [NSString stringWithFormat:
                @"%@> %@ %@ [%@]", 
                [task currentDirectoryPath], [task launchPath], 
                [task arguments], [task environment]];
            SEN_LOG(aMsg);                                
            
        }
        if(taskLogger)
            [taskLogger taskRequestWillLaunch:self];

        NS_DURING
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(taskTerminated:)
                                                         name:NSTaskDidTerminateNotification
                                                       object:task];
            startTime = [NSDate timeIntervalSinceReferenceDate];
            [task launch];
        NS_HANDLER
            [[NSNotificationCenter defaultCenter] removeObserver:self
                                                         name:NSTaskDidTerminateNotification
                                                       object:task];
            NSRunAlertPanel(@"Request problem", @"%@ \n Current Directory Path: %@ \n Launch Path: %@ \n Task Arguments: %@ \n Task Environment: %@", @"OK", nil, nil,
                            localException, [task currentDirectoryPath], [task launchPath], 
                            [task arguments], [task environment]);
            success=NO;
        NS_ENDHANDLER
    } else {
        success=NO;
    }
    return success;
#else
    BOOL returnValue=YES;
    if ([self setUpTask]) {        
        if(taskTracingEnabled) {
            NSString	*cmdString = [NSString stringWithFormat:@"%@> %@ %@\n", [task currentDirectoryPath], [task launchPath], [[task arguments] componentsJoinedByString:@" "]];
            NSString *aMsg = [NSString stringWithFormat:
                @"In startTask: cmdString = \"%@\"", cmdString ];
            SEN_LOG(aMsg);
        }
        
        if(taskLogger)
            [taskLogger taskRequestWillLaunch:self];

        NS_DURING
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(taskTerminated:)
                                                         name:NSTaskDidTerminateNotification
                                                       object:task];
            startTime = [NSDate timeIntervalSinceReferenceDate];
            [task launch];
            taskEndConditionsCount++;
            if( taskTracingEnabled ) {
                NSString *aMsg = [NSString stringWithFormat:
                    @"In startTask task \"%@\" (pid = %d) taskEndConditionsCount is being set %d!",
                    [task launchPath], [task processIdentifier], taskEndConditionsCount ];
                SEN_LOG(aMsg);
            }                            
        NS_HANDLER
            [[NSNotificationCenter defaultCenter] removeObserver:self
                                                         name:NSTaskDidTerminateNotification
                                                       object:task];
            NSRunAlertPanel(@"Request problem", @"%@ \n Current Directory Path: %@ \n Launch Path: %@ \n Task Arguments: %@ \n Task Environment: %@", @"OK", nil, nil,
                            localException, [task currentDirectoryPath], [task launchPath], 
                            [task arguments], [task environment]);
            returnValue=NO;
        NS_ENDHANDLER
    } else {
        returnValue=NO;
    }
    return returnValue;
#endif
}

- (void)taskCleanUp
{
    if(task != nil){
        if( taskTracingEnabled ) {
            NSString *aMsg = [NSString stringWithFormat:
                @"Tasks \"%@\" (pid = %d) is being set to nil!",
                [task launchPath], [task processIdentifier]];
            SEN_LOG(aMsg);
        }        
        [[NSNotificationCenter defaultCenter] removeObserver:self name:NSTaskDidTerminateNotification object:task];
        RELEASE(task);
    }
    if(pipe){
        [[NSNotificationCenter defaultCenter] removeObserver:self name:NSFileHandleReadCompletionNotification object:readHandle];
        [lastReceivedString setString: @""];
        [readHandle closeFile];
        RELEASE(readHandle);
        RELEASE(pipe);
    }
    if(errorPipe){
        [[NSNotificationCenter defaultCenter] removeObserver:self name:NSFileHandleReadCompletionNotification object:errorReadHandle];
        [lastReceivedErrorString setString: @""];
        [completeErrorMsgString setString: @""];
        [errorReadHandle closeFile];
        RELEASE(errorReadHandle);
        RELEASE(errorPipe);
    }
    taskEndConditionsCount = 0;
}

#ifdef JA_PATCH
- (BOOL)taskWasSuccessfull
{
    return (!task && !readHandle && !errorReadHandle && success);
}

- (BOOL)taskWasAFailure
{
    return (!task && !readHandle && !errorReadHandle && !success);
}
#else
- (void) cancel
{
    if([self canBeCancelled] && task && [task isRunning])
        [task interrupt]; // Should we call -terminate instead?
    else
        [super cancel];
}

- (void)taskEnded
{
    [self endConditionReached];
}

-(void)taskEndConditionReached
{
    taskEndConditionsCount--;
    if( taskTracingEnabled ) {
        NSString *aMsg = [NSString stringWithFormat:
            @"In taskEndConditionReached task \"%@\" (pid = %d) taskEndConditionsCount is set to %d!",
            [task launchPath], [task processIdentifier], taskEndConditionsCount];
        SEN_LOG(aMsg);
    }                    
    
    if (taskEndConditionsCount == 0) {
        [self taskEnded];
    }
}
#endif

- (id)outputFile
{
    if (!pipe) {
        ASSIGN(pipe, [NSPipe pipe]);
        ASSIGN(readHandle, [pipe fileHandleForReading]);

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dataReceived:) name:NSFileHandleReadCompletionNotification object:readHandle];

        [readHandle readInBackgroundAndNotifyForModes:[NSArray arrayWithObjects:NSDefaultRunLoopMode, NSModalPanelRunLoopMode, nil]];

        taskEndConditionsCount++;
        if( taskTracingEnabled ) {
            NSString *aMsg = [NSString stringWithFormat:
                @"In outputFile task \"%@\" (pid = %d) taskEndConditionsCount is being set %d!",
                [task launchPath], [task processIdentifier], taskEndConditionsCount];
            SEN_LOG(aMsg);
        }                        
    }
    return pipe;
}

- (id)errorFile
{
    if (!errorPipe) {
        ASSIGN(errorPipe, [NSPipe pipe]);
        ASSIGN(errorReadHandle, [errorPipe fileHandleForReading]);

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(errorReceived:) name:NSFileHandleReadCompletionNotification object:errorReadHandle];

        [errorReadHandle readInBackgroundAndNotifyForModes:[NSArray arrayWithObjects:NSDefaultRunLoopMode, NSModalPanelRunLoopMode, nil]];

        taskEndConditionsCount++;
        if( taskTracingEnabled ) {
            NSString *aMsg = [NSString stringWithFormat:
                @"In errorFile task \"%@\" (pid = %d) taskEndConditionsCount is being set %d!",
                [task launchPath], [task processIdentifier], taskEndConditionsCount];
            SEN_LOG(aMsg);
        }                
    }
    return errorPipe;
}

/*
- (void)close
{
    if (task) {
        [task terminate];
        [task release];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:NSTaskDidTerminateNotification object:task];
        task=nil;
    }
    if (readHandle) {
        [readHandle release];
        [pipe release];
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:@"NSFileHandleReadCompletionNotification"
                                                      object:readHandle];
    }
    if (errorReadHandle) {
        [errorReadHandle release];
        [errorPipe release];
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:@"NSFileHandleReadCompletionNotification"
                                                      object:errorReadHandle];
    }
}*/

- (BOOL)isQuiet
{
    return isQuiet;
}

- (void)setIsQuiet:(BOOL)value
{
    isQuiet=value;
}


- (void) setTask: (NSTask*) aTask
{
    ASSIGN(task, aTask);
}

- (NSTask *) task
{
    return task;
}

-(NSString *)summary
{
    return [[task arguments] description];
}

#ifdef JA_PATCH
- (void) resumeNow
{
    taskAuthorized=YES;
    [self updateState];
}

- (BOOL)authorizedToRun
{
    return taskAuthorized;
}
#endif

-(BOOL)setUpTask
{
    id anOutputFile = nil;
    id anErrorFile = nil;
    
    if (!task) {
        static NSDictionary	*env = nil;
        if(!env)
            ASSIGN(env, [[NSProcessInfo processInfo] environment]);
        task=[[NSTask alloc] init];
        [task setEnvironment:env];
        // It seems that -[NSProcessInfo environment] is time-consuming (15 samples @ 50ms = 0.75s)
		// If there is no internal cache, we should create our own cache, as it is often repeated
    }

    if( taskTracingEnabled ) {
        NSString *aMsg = [NSString stringWithFormat:
            @"In setUpTask: task \"%@\" (pid = %d)",
            [task launchPath], [task processIdentifier]];
        SEN_LOG(aMsg);
    }    
    //NB: The CVLOpendiffRequest class returns nil for outputFile and errorFile.
    //    They are not needed for this class. Plus this avoids the problem of
    //    the first task to call opendiff never gets removed from the Progress
    //    pannel because the outputFile and errorFile do not get a end notification
    //    until the FileMerge application is closed.
    anOutputFile = [self outputFile];
    if ( anOutputFile != nil ) {
        [task setStandardOutput:anOutputFile];
    }
    anErrorFile = [self errorFile];
    if ( anErrorFile != nil ) {
        [task setStandardError:anErrorFile];
    }
    return YES;
}


- (void) effectiveStringReceived: (NSString*) aString
{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"RequestReceivedData" object:self userInfo:[NSDictionary dictionaryWithObject:aString forKey:@"RequestNewData"]];
    if (parseByLine) [self parseOutput:aString];
}

- (void) effectiveErrorStringReceived: (NSString*) aString
    /*" Here we are creating a new notification that contains a complete line.
        Since the -errorRecieved: method might get called with partial lines we
        use this method to make sure we have a complete error message before
        sending out an error notification.
    "*/
{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"RequestReceivedData" object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys: aString,@"RequestNewData", @"YES",@"ErrorStream",nil]];
    if (parseByLine) [self parseError:aString];
}


- (void)dataReceived:(NSNotification *)notification
{
    NSDictionary *info=[notification userInfo];
    NSString* receivedString = nil;
    NSData* receivedData = nil;
    NSRange newLineRange;
    NSStringEncoding anEncoding = 0;

    receivedData = [info objectForKey:NSFileHandleNotificationDataItem];
    receivedString= [[NSString alloc] initWithData:receivedData 
                                          encoding:NSUTF8StringEncoding];    
    if ( receivedString == nil ) {
        anEncoding = [NSString defaultCStringEncoding];
        receivedString= [[NSString alloc] initWithData:receivedData 
                                              encoding:anEncoding];
    }
    
    newLineRange= [receivedString rangeOfCharacterFromSet: newLineCharacterSet];
    
    if( taskTracingEnabled ) {
        NSString *aMsg = [NSString stringWithFormat:
            @"In dataReceived: task \"%@\" (pid = %d) taskEndConditionsCount is being set %d!",
            [task launchPath], [task processIdentifier], taskEndConditionsCount];
        SEN_LOG(aMsg);
        if( [receivedString length] > 0 ) {
            aMsg = [NSString stringWithFormat:@"<< %@", receivedString];
            SEN_LOG(aMsg);
        }        
    }    
    
    [lastReceivedString appendString: receivedString];
    if (!parseByLine) {
        [self parseOutput:receivedString];
    }
    
    if (newLineRange.length)
    {
        [self effectiveStringReceived: lastReceivedString];
        [lastReceivedString setString: @""]; 
    }
    if ([receivedString cStringLength])
    {
    [readHandle readInBackgroundAndNotifyForModes:[NSArray arrayWithObjects:NSDefaultRunLoopMode, NSModalPanelRunLoopMode, nil]];
    }
    else
    { //end of file
        if ([lastReceivedString cStringLength])
        {
            [self effectiveStringReceived: lastReceivedString];
            [lastReceivedString setString: @""]; 
        }
#ifdef JA_PATCH
        [self closeReadHandle];

        [self updateState];
#else
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:NSFileHandleReadCompletionNotification
                                                      object:readHandle];
        [readHandle closeFile];
        RELEASE(readHandle);
        RELEASE(pipe);

        [self taskEndConditionReached];
#endif
    }
    [receivedString release];
}

#ifdef JA_PATCH
- (void)closeReadHandle
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSFileHandleReadCompletionNotification object:readHandle];
    [readHandle closeFile];
    RELEASE(readHandle);
    RELEASE(pipe);
}
#endif

- (void)errorReceived:(NSNotification *)notification
{
    NSDictionary *info=[notification userInfo];
    NSString* receivedString = nil;
    NSData* receivedData = nil;
    NSRange newLineRange;
    NSStringEncoding anEncoding = 0;
    
    receivedData = [info objectForKey:NSFileHandleNotificationDataItem];
    receivedString= [[NSString alloc] initWithData:receivedData 
                                          encoding:NSUTF8StringEncoding];    
    if ( receivedString == nil ) {
        anEncoding = [NSString defaultCStringEncoding];
        receivedString= [[NSString alloc] initWithData:receivedData 
                                              encoding:anEncoding];
    }
    
    newLineRange= [receivedString rangeOfCharacterFromSet: newLineCharacterSet];
    
    if( taskTracingEnabled ) {
        NSString *aMsg = [NSString stringWithFormat:
            @"In errorReceived: task \"%@\" (pid = %d) taskEndConditionsCount is being set to %d!",
            [task launchPath], [task processIdentifier], taskEndConditionsCount];
        SEN_LOG(aMsg);
        if ( receivedString != nil ) {
            aMsg = [NSString stringWithFormat:
                @"In errorReceived: receivedString = \"%@\".", receivedString];
            SEN_LOG(aMsg);
        }
    }

    [lastReceivedErrorString appendString: receivedString];
    [completeErrorMsgString appendString: receivedString];
    
    if (!parseByLine) {
        [self parseError:receivedString];
    }

    if (newLineRange.length) {
        [self effectiveErrorStringReceived : lastReceivedErrorString];
        [lastReceivedErrorString setString: @""]; // reset
    }
    if ([receivedString cStringLength]) {
    [errorReadHandle readInBackgroundAndNotifyForModes:[NSArray arrayWithObjects:NSDefaultRunLoopMode, NSModalPanelRunLoopMode, nil]];
    } else { 
        //end of file
        if ([lastReceivedErrorString cStringLength]) {
            [self effectiveErrorStringReceived: lastReceivedErrorString];
            [lastReceivedErrorString setString: @""]; // reset
        }

#ifdef JA_PATCH
        [self closeErrorReadHandle];

        [self updateState];
#else
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:NSFileHandleReadCompletionNotification
                                                      object:errorReadHandle];
        [errorReadHandle closeFile];
        RELEASE(errorReadHandle);
        RELEASE(errorPipe);
        [self taskEndConditionReached];
#endif
    }
    [receivedString release];
}

#ifdef JA_PATCH
- (void)closeErrorReadHandle
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSFileHandleReadCompletionNotification object:errorReadHandle];
    [errorReadHandle closeFile];
    RELEASE(errorReadHandle);
    RELEASE(errorPipe);
}
#endif

- (void)taskTerminated:(NSNotification *)notification
{
    int status = 0;
    NSTask *aTask = nil;
    
    aTask = [notification object];
    if ( aTask != task ) return; // Not my task, ignore!
    
    status = [task terminationStatus];
    if (status) success=NO;
    else success=YES;
    if(taskTracingEnabled) {
        NSString *aMsg = [NSString stringWithFormat:
            @"### Task \"%@\" (pid = %d), taskEndConditionsCount = %d, termination status: %d is being terminated.", 
            [task launchPath], [task processIdentifier], 
            taskEndConditionsCount, status];
        SEN_LOG(aMsg);
        if( success == NO ) {
            aMsg = [NSString stringWithFormat:@"<No task error>"];
            SEN_LOG(aMsg);
        }
    }

    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSTaskDidTerminateNotification object:task];
#ifdef JA_PATCH
    RELEASE(task);

    [self updateState];
#else
    [self taskEndConditionReached];
#endif
}

- (void)parseOutput:(NSString *)data
{
    return;
}

- (void)parseError:(NSString *)data
{
    return;
}

-(void)end
{
    if( taskTracingEnabled ) {
        NSString *aMsg = [NSString stringWithFormat:
            @"In end (pid = %d) lastReceivedErrorString = \"%@\"",
            [task processIdentifier], lastReceivedErrorString];
        SEN_LOG(aMsg);
    }
    
    [super end];
}


#ifdef JA_PATCH
+(State *)initialState
{
    static BOOL triedInitialState=NO;
    static State *initialState=nil;

    if (!triedInitialState) {
        ASSIGN(initialState, [State initialStateForStateFile:[[NSBundle bundleForClass:[self class]] pathForResource:@"Request" ofType:@"fsm"]]);
        triedInitialState=YES;
    }
    return initialState;
}
#endif

- (NSString *)moreInfoString
    /*" This is a method that returns more information about this request.
        Mainly we are talking about the instance variables some of which have 
        been converted to informational strings. This is mostly used for 
        debugging purposes but also appears in the processes panel.
    "*/
{    
    NSString *moreInfoString = nil;
    
    moreInfoString = [NSString stringWithFormat:
                             @"%@\nTask End Conditions Count: %d", 
        [super moreInfoString], taskEndConditionsCount];
    
    return moreInfoString;
}

@end


