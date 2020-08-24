/* CvsAddRequest.m created by dagaeff on Wed 16-Jun-1999 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "CvsAddRequest.h"
#import "CVLFile.h"
#import "NSFileManager_CVS.h"
#import <SenFoundation/SenFoundation.h>


@interface CvsAddRequest (Private)
- (void)scheduleChildren;
@end


@implementation CvsAddRequest

+ cvsAddRequestWithFiles:(NSArray *)someFiles
{
    return [self cvsAddRequestWithFiles:someFiles forcesBinary:NO];
}

+ cvsAddRequestWithFiles:(NSArray *)someFiles forcesBinary:(BOOL)flag
{
    CVLFile *commonParent;
    NSMutableArray *checkedFiles;
    id fileEnumerator;
    CVLFile *aFile;
    CvsAddRequest *newRequest;

    if (!(commonParent = (id)[[someFiles lastObject] parent])) {
        return nil;
    }

    checkedFiles=[NSMutableArray array];
    fileEnumerator=[someFiles objectEnumerator];
    while ( (aFile=[fileEnumerator nextObject]) ) {
        if ([aFile parent]==commonParent) {
            [checkedFiles addObject:[[aFile path] lastPathComponent]];
        } else {
            NSString *aMsg = [NSString stringWithFormat:
                @"Warning : unsuported case, single request with different folders"];
            SEN_LOG(aMsg);
        }
    }

    if (![commonParent repository]) {
        return nil; // Must be done inside a repository
    }

    newRequest = [self requestWithCmd:CVS_ADD_CMD_TAG title:@"add" path:[commonParent path] files:checkedFiles];
    [newRequest setForcesBinary:flag];

    return newRequest;
}

+ cvsAddRequestAtPath:(NSString *)aPath files:(NSArray *)someFiles
{
    return [self cvsAddRequestAtPath:aPath files:someFiles forcesBinary:NO];
}

+ cvsAddRequestAtPath:(NSString *)aPath files:(NSArray *)someFiles forcesBinary:(BOOL)flag
{
    NSArray *checkedFiles = nil;
    NSDictionary* pathDict;
    NSString* commonPath;
    CvsAddRequest *newRequest;
    
    if (someFiles) {
        pathDict = [[self class] canonicalizePath:aPath andFiles:someFiles];
        commonPath = [[pathDict allKeys] objectAtIndex:0];
        checkedFiles = [pathDict objectForKey:commonPath];
    } else {
        return nil; // files are mandatory
    }

    if (![(CVLFile *)[CVLFile treeAtPath:commonPath] repository]) {
        return nil; // Must be done inside a repository
    }

    newRequest = [self requestWithCmd:CVS_ADD_CMD_TAG title:@"add" path:commonPath files:checkedFiles];
    [newRequest setForcesBinary:flag];

    return newRequest;
}

#ifndef JA_PATCH
- (void)resumeNow
{
    if (internalState==INTERNAL_STATE_WAITING_FOR_CHILDREN) {
        [self end];
    } else {
        [super resumeNow];
    }
}

- (void)taskEnded
{
    if (success) {
        internalState=INTERNAL_STATE_WAITING_FOR_CHILDREN;
        [self updateFileStatuses];
        [self scheduleChildren];
        [self setState:STATE_READY];
    } else {
        [self updateFileStatuses];
    }
    [super taskEnded];
}
#endif

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

- (void)scheduleChildren
{
    NSEnumerator *addedFileEnumerator = nil;
    NSString *addedFilePath,*fullAddedFilePath;
    CVLFile *addedFile;
    NSEnumerator *childEnumerator = nil;
    CVLFile *child;
    NSMutableArray *filesToAdd= [NSMutableArray array];
    CvsAddRequest *newRequest;
    ECFileFlags fileFlags;

    addedFileEnumerator=[files objectEnumerator];
#ifdef JA_PATCH
    childrenRequestsSucceeded=YES;
#endif
    while ( (addedFilePath=[addedFileEnumerator nextObject]) ) {
    // Create request for added dirs
        fullAddedFilePath=[path stringByAppendingPathComponent:addedFilePath];
        addedFile=(CVLFile *)[CVLFile treeAtPath:fullAddedFilePath];
        [addedFile flags];
        if (![addedFile isLeaf]) {
            [filesToAdd removeAllObjects];
            childEnumerator=[[addedFile children] objectEnumerator];
            while ( (child = [childEnumerator nextObject]) ) {
                fileFlags = [child flags];
                if (!fileFlags.isIgnored) {
                    [filesToAdd addObject:child];
                }
            }
            newRequest=[[self class] cvsAddRequestWithFiles:filesToAdd forcesBinary:forcesBinary];
#ifdef JA_PATCH
            [childrenRequests addObject:newRequest];
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(childrenRequestCompleted:) name:@"RequestCompleted" object:newRequest];
#endif
            [newRequest schedule];
            if (newRequest) {
                [self addPrecedingRequest:newRequest];
            }
        }
    }
}

- (NSString *)cvsWorkingDirectory
{
    return [self path];
}

#ifdef JA_PATCH
- (void)childrenRequestCompleted:(NSNotification *)notification
{
    Request *aRequest=[notification object];

    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"RequestCompleted" object:aRequest];
    [childrenRequests removeObject:aRequest];
    if (![aRequest succeeded]) {
        childrenRequestsSucceeded=NO; // should cancel the others
    }
    [self updateState];
}

- (BOOL)childrenRequestsFailed
{
    return (![childrenRequests count] && !childrenRequestsSucceeded);
}

- (BOOL)childrenRequestsSuceeded
{
    return (![childrenRequests count] && childrenRequestsSucceeded);
}

+(State *)initialState
{
    static BOOL triedInitialState=NO;
    static State *initialState=nil;

    if (!triedInitialState) {
        ASSIGN(initialState, [State initialStateForStateFile:[[NSBundle bundleForClass:[self class]] pathForResource:@"CvsAdd" ofType:@"fsm"]]);
        triedInitialState=YES;
    }
    return initialState;
}
#else
- (void)end
{
    [super endWithoutInvalidation];
}
#endif

- (void) setForcesBinary:(BOOL)flag
{
    forcesBinary = flag;
}

- (BOOL) forcesBinary
{
    return forcesBinary;
}

- (NSArray *)cvsCommandOptions
{
    if(forcesBinary)
        return [NSArray arrayWithObject:@"-kb"];
    else
        return [NSArray array];
}

- (NSArray *) modifiedFiles
{
    // We return only newly added directories, because a CVS directory is created.
    // When files are added, no file is created
    NSMutableArray	*modifiedFiles = [NSMutableArray array];
    NSEnumerator	*anEnum = [[super modifiedFiles] objectEnumerator];
    NSString		*aPath;
    NSFileManager	*fileManager = [NSFileManager defaultManager];
    
    while ( (aPath = [anEnum nextObject]) ) {
        if([fileManager senDirectoryExistsAtPath:aPath])
            // We don't check whether it's a wrapper or not.
            [modifiedFiles addObject:aPath];        
    }

    if([modifiedFiles lastObject])
        return modifiedFiles;
    else
        return nil;
}

@end
