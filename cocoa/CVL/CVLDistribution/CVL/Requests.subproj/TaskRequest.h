/* TaskRequest.h created by ja on Mon 24-Nov-1997 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <Foundation/Foundation.h>

#import <Request.h>


@class NSTask, NSPipe, NSFileHandle, NSMutableString;



@interface TaskRequest : Request
{
    BOOL isQuiet;
    NSTask *task;
    NSPipe *pipe;
    NSPipe *errorPipe;
    NSFileHandle *readHandle;
    NSFileHandle *errorReadHandle;
    int taskEndConditionsCount;
    BOOL parseByLine;
    NSMutableString* lastReceivedString;
    NSMutableString* lastReceivedErrorString;
    NSMutableString* completeErrorMsgString;
    NSTimeInterval startTime;
    NSTimeInterval endTime;

#ifdef JA_PATCH
    BOOL taskAuthorized;
#endif
}

+ (void) setLogger:(id)logger;

//+ requestWithTitle:(NSString *)cmdString path:(NSString *)thePath args:(NSArray *)theArgs;
//- initWithTitle:(NSString *)cmdString path:(NSString *)thePath args:(NSArray *)theArgs;

- (void) setTask: (NSTask*) aTask;
- (NSTask *) task;

- (BOOL)startTask;
- (BOOL)setUpTask;
// query methods
- (BOOL)isQuiet;
- (void)setIsQuiet:(BOOL)value;
#ifdef JA_PATCH
- (void)taskTerminated:(NSNotification *)notification;
#endif
- (void)errorReceived:(NSNotification *)notification;
- (void)taskTerminated:(NSNotification *)notification;

- (id)outputFile; //returns a NSFileHandle or a NSPipe, Do not use, subclass only
- (id)errorFile;

- (void)parseOutput:(NSString *)data;
- (void)parseError:(NSString *)data;

#ifdef JA_PATCH
- (void)closeReadHandle;
- (void)closeErrorReadHandle;
#else
- (void)taskEnded;
#endif
- (void)taskCleanUp;


@end

@interface NSObject(TaskRequestLogger)
- (void) taskRequestWillLaunch:(TaskRequest *)request;
@end
