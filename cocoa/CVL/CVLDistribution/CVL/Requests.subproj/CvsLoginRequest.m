/* CvsLoginRequest.m created by ja on Thu 04-Dec-1997 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "CvsLoginRequest.h"
#import <CvsRepository.h>
#import <SenPanelFactory.h>
#import <SenFormPanelController.h>
#import <SenFoundation/SenFoundation.h>

#ifndef JA_PATCH
@interface CvsLoginRequest (Private)
- (NSString *)askPassword;
@end
#endif

@implementation CvsLoginRequest
+ (CvsLoginRequest *)cvsLoginRequest
{
    return [self cvsLoginRequestForRepository:[CvsRepository defaultRepository]];
}

+ (CvsLoginRequest *)cvsLoginRequestForRepository:(CvsRepository *)aRepository
{
    CvsLoginRequest *request;

    if ([aRepository needsLogin]) {
        if ( (request=[self requestWithCmd:CVS_UNIX_CMD_TAG title:@"login" path:nil files:nil]) ) {
            [request setRepository:aRepository];
        }
    } else {
        return nil;
    }

    return request;
}

+ (CvsLoginRequest *)cvsLoginRequestForRepository:(CvsRepository *)aRepository withPassword:(NSString *)passwordString
{
    CvsLoginRequest *request;

    if ( (request=[self requestWithCmd:CVS_UNIX_CMD_TAG title:@"login" path:nil files:nil]) ) {
        [request setRepository:aRepository];
        [request setPassword:passwordString];
    }

    return request;
}

#ifdef JA_PATCH
+(State *)initialState
{
    static BOOL triedInitialState=NO;
    static State *initialState=nil;

    if (!triedInitialState) {
        ASSIGN(initialState, [State initialStateForStateFile:[[NSBundle bundleForClass:[self class]] pathForResource:@"CvsLogin" ofType:@"fsm"]]);
        triedInitialState=YES;
    }
    return initialState;
}
#endif

- (void)setPassword:(NSString *)passwordString
{
    ASSIGN(password, passwordString);
}

- (NSString *)cvsCommand
{
    return @"login";
}

#ifdef JA_PATCH
- (void)askPassword
{
    SenFormPanelController *panel;

    panel=[[SenPanelFactory sharedPanelFactory] handleOfPanelWithName:@"CvsPserverLogin"];
    [panel setDictionaryValue:[repository properties]];
    if ([panel showAndRunModal]==NSOKButton) {
        [self setPassword:[panel objectValueForKey:PASSWORD_KEY]];
    } else {
        [self setPassword:nil];
    }
}
#else
- (NSString *)askPassword
{
    // FIXME (stephane) Very weird bug: if the path field in the login panel is selectable
    // and user selects and scrolls content, then -[CVLScheduler scheduleDelayed:] is called
    // in a re-entrant manner!
    // A second "run modal" is done while already modal!
    // I'm unable to reproduce that in a simple test app...
#if 0
    // We NEED to avoid popping up a new modal window (not a modal sheet)
    // when there is already one.
    if([NSApp modalWindow] != nil){
        // Returning nil is not a good patch for the reentrance problem, because
        // it would -end the request, while it is still running in original modal loop.
        return nil;
    }
#endif
    
    SenFormPanelController *panel;

    panel=[[SenPanelFactory sharedPanelFactory] handleOfPanelWithName:@"CvsPserverLogin"];
    [panel setDictionaryValue:[repository properties]];
    if ([panel showAndRunModal]==NSOKButton) {
        return [panel objectValueForKey:PASSWORD_KEY];
    } else {
        return nil;
    }
}

- (void)resumeNow
{
    switch (internalState) {
        case INTERNAL_STATE_LOGIN_FIRST_PANEL:
            if ( (password=[self askPassword]) ) {
                [password retain];
                internalState=INTERNAL_STATE_NOT_STARTED;
                [self setState:STATE_READY];
            } else {
                success=NO;
                [self end];
            }
            break;

        case INTERNAL_STATE_LOGIN_PANEL:
            if ( (password=[self askPassword]) ) {
                [password retain];
                internalState=INTERNAL_STATE_CVS_RETRY_AFTER_LOGIN;
                [self setState:STATE_READY];
            } else {
                success=NO;
                [self end];
            }
            break;

        default:
            [super resumeNow];
            break;
    }
}
#endif

- (BOOL) setUpTask {
    if ([super setUpTask]) {
        NSPipe *aPipe=[NSPipe pipe];

#ifdef DEBUG
        {
            NSString *aMsg = [[task environment] description];
            SEN_LOG(aMsg);        
        }
#endif
        ASSIGN(cvsInput, [aPipe fileHandleForWriting]);

        [task setStandardInput:aPipe];

        // Stephane: could we allow [NSString defaultCStringEncoding] ?
        [cvsInput writeData:[[password stringByAppendingString: RequestNewLineString] dataUsingEncoding:NSASCIIStringEncoding
                                                                                   allowLossyConversion:YES]];
        [cvsInput closeFile];

        parseByLine=NO;
        
        return YES;
    }
    return NO;
}



- (void)parseError:(NSString *)data
{
    if (!summedOutput) summedOutput=[[NSMutableString alloc] init];
    [summedOutput appendString:data];

    if ([summedOutput hasSuffix:@"CVS password: "]) {
 //       if (password) {
 //           [cvsInput writeData: [[password stringByAppendingString: RequestNewLineString] dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES]];
 //       }
 //       [summedOutput setString:@""];
    }
}

#ifdef JA_PATCH
- (void)taskTerminated:(NSNotification *)notification
{
    [cvsInput closeFile];
    RELEASE(cvsInput);

    [super taskTerminated:notification];
}

-(NSString *)summary
{
    return @"";
}

- (BOOL) canRunAgainstRequest:(Request *)runningRequest
{
    return !([runningRequest isKindOfClass:[CvsLoginRequest class]]);
}

- (NSString *)shortDescription
{
    return [NSString stringWithFormat: @"%@ in %@\n", [self cmdTitle], [repository root]];
}

- (void) endWithSuccess
{
    [repository setIsLoggedIn:YES];
}

- (void)endWithFailure
{
    [repository setIsLoggedIn:NO];
}

- (BOOL)havePassword
{
    return password!=nil;
}

- (BOOL)haveNoPassword
{
    return password==nil;
}
#else
- (void)taskEnded
{
    if (success) {
        [self endConditionReached];
    } else {
        RELEASE(password);
        internalState=INTERNAL_STATE_LOGIN_PANEL;
        [self setState:STATE_READY];
    }
}

- (void)end
{
    [cvsInput closeFile];
    RELEASE(cvsInput);

    if (internalState!=INTERNAL_STATE_NOT_STARTED) {
        [repository setIsLoggedIn:success];
    }
    [super endWithoutInvalidation];
}

-(NSString *)summary
{
    return @"";
}

- (BOOL) canContinue
{
    return [self precedingRequestsEnded];
}

- (void)schedule
{
    if (!password) {
        internalState=INTERNAL_STATE_LOGIN_FIRST_PANEL;
    }
    [super schedule];
}

- (BOOL) canRunAgainstRequest:(Request *)runningRequest
{
    return !([runningRequest isKindOfClass:[CvsLoginRequest class]]);
}

- (NSString *)shortDescription
{
    return [NSString stringWithFormat: @"%@ in %@\n", [self cmdTitle], [repository root]];
}
#endif

@end
