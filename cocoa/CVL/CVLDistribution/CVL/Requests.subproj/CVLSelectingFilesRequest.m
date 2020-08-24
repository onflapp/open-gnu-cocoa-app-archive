/* CVLSelectingFilesRequest.m created by me on Thu 03-Sep-1998 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "CVLSelectingFilesRequest.h"
#import "WorkAreaViewer.h"
#import "CVLDelegate.h"
#import "CVLFile.h"
#import "ResultsRepository.h"
#import <AppKit/AppKit.h>
#import <SenFoundation/SenFoundation.h>

@interface CVLSelectingFilesRequest (private)
- (id)initWithViewer:(WorkAreaViewer *)viewer andFiles:(NSSet *)someFiles;
- (void)checkForStatuses;
@end

@implementation CVLSelectingFilesRequest
+ (NSSet *)requestsForSelectionOfPaths:(NSArray *)fullPaths
{
    NSMutableDictionary *filesByViewer;
    id pathEnumerator;
    NSString *path;
    CVLFile *viewerRootFile;
    NSMutableSet *viewerFiles;
    id viewerEnumerator;
    NSMutableSet *result;
    CVLFile *aFile = nil;

    pathEnumerator=[fullPaths objectEnumerator];
    filesByViewer=[[NSMutableDictionary alloc] init];
    while ( (path=[pathEnumerator nextObject]) ) {
        aFile = (CVLFile *)[CVLFile treeAtPath:path];
        viewerRootFile=[[[[NSApplication sharedApplication] delegate] viewerShowingFile:aFile] rootFile];
        if (!(viewerFiles=[filesByViewer objectForKey:viewerRootFile])) {
            viewerFiles=[[NSMutableSet alloc] init];
            [filesByViewer setObject:viewerFiles forKey:viewerRootFile];
            [viewerFiles release];
        }
        [viewerFiles addObject:[CVLFile treeAtPath:path]];
    }

    result=[NSMutableSet set];
    viewerEnumerator=[filesByViewer keyEnumerator];
    while ( (viewerRootFile=[viewerEnumerator nextObject]) ) {
        id	myViewer = [[[NSApplication sharedApplication] delegate] viewerWithRootFile:viewerRootFile];

        [result addObject:[[[self alloc] initWithViewer:myViewer andFiles:[filesByViewer objectForKey:viewerRootFile]] autorelease]];
    }

    return result;
}

- (id)initWithViewer:(WorkAreaViewer *)viewer andFiles:(NSSet *)someFiles
{
    if ( (self=[self initWithTitle:@"Showing files"]) ) {
        filesToSelect=[someFiles copy];
        filesYetToShow=[someFiles mutableCopy];
        ASSIGN(workAreaViewer, viewer);
#ifdef JA_PATCH
        [self schedule];
#endif
    }
    return self;
}

- (void)dealloc
{
    RELEASE(filesToSelect);
    RELEASE(filesYetToShow);
    RELEASE(workAreaViewer);
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [super dealloc];
}

- (void)start
{
#ifndef JA_PATCH
    [super start];
#endif
    [[ResultsRepository sharedResultsRepository] startUpdate];
    [filesToSelect makeObjectsPerformSelector:@selector(invalidateAll)];
#ifndef JA_PATCH
    [self checkForStatuses];
#endif
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(filesDidChange:)
                                                   name:@"ResultsChanged"
                                               object:[ResultsRepository sharedResultsRepository]];
    [[ResultsRepository sharedResultsRepository] endUpdate];
#ifdef JA_PATCH
    [self updateState];
#endif
}

#ifdef JA_PATCH
- (void)conditionBecameTrue
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"ResultsChanged" object:[ResultsRepository sharedResultsRepository]];
    [workAreaViewer show:self];
    [workAreaViewer selectFiles:filesToSelect];
}
#else
- (void)resumeNow
{
    if (internalState==INTERNAL_STATE_WAITING_FOR_STATUSES) {
        [self checkForStatuses];
    } else {
        [super resumeNow];
    }
}

- (void)end
{
    [workAreaViewer show:self];
    [workAreaViewer selectFiles:filesToSelect];
    [super end];
}
#endif

- (void)filesDidChange:(NSNotification *)aNotification
{
   if ([[[aNotification object] changedFiles] intersectsSet:filesYetToShow]) {
#ifdef JA_PATCH
       [self updateState];
#else
        [self checkForStatuses];
#endif
    }
}

#ifdef JA_PATCH
- (BOOL)conditionIsTrue
{
    id fileEnumerator;
    CVLFile *file;

    [[ResultsRepository sharedResultsRepository] startUpdate];
    fileEnumerator=[[[filesYetToShow mutableCopy] autorelease] objectEnumerator];
    while (file=[fileEnumerator nextObject]) {
        if (([file status].statusType)!=ECNoType) {
            [filesYetToShow removeObject:file];
        }
    }
    [[ResultsRepository sharedResultsRepository] endUpdate];

    return [filesYetToShow count] == 0;
}

+(State *)initialState
{
    static BOOL triedInitialState=NO;
    static State *initialState=nil;

    if (!triedInitialState) {
        ASSIGN(initialState, [State initialStateForStateFile:[[NSBundle bundleForClass:[self class]] pathForResource:@"WaitCondition" ofType:@"fsm"]]);
        triedInitialState=YES;
    }
    return initialState;
}
#else
- (void)checkForStatuses
{
    id fileEnumerator;
    CVLFile *file;

    [[ResultsRepository sharedResultsRepository] startUpdate];
    fileEnumerator=[[[filesYetToShow mutableCopy] autorelease] objectEnumerator];
    while ( (file=[fileEnumerator nextObject]) ) {
        if (([file status].statusType)!=ECNoType) {
            [filesYetToShow removeObject:file];
        }
    }
    
    if ([filesYetToShow count]) {
        [self setState:STATE_WAITING];
    } else {
        success=YES;
        [self end];
    }
    [[ResultsRepository sharedResultsRepository] endUpdate];
}
#endif

@end
