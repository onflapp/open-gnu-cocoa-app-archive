/* CVLOpendiffRequest.m created by stephane on Mon 27-Sep-1999 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "CVLOpendiffRequest.h"
#import <CvsUpdateRequest.h>
#import "CVLFile.h"
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <SenFoundation/SenFoundation.h>

static NSString	*opendiffPath = nil;

// WARNING
// CvsUpdateRequest does not support updates of directories if we try to restore old versions
// So CVLOpendiffRequest must never be invoked for directories (or multiselection)

// (Stephane) Instead of using opendiff, we could perhaps use FileMerge Services:
// FileMerge/Compare Files      => two files as parameters?
// FileMerge/Compare To Master  => three files as parameters?
// How do we set the merge file?

@interface CVLOpendiffRequest(Private)
+ (void) preferencesChanged:(NSNotification *)notification;
- (id) initWithFile:(NSString *)fileFullPath andFile:(NSString *)fileFullPath2; // Generic initializer for <opendiff fileFullPath fileFullPath2>
- (id) initWithCVLFile:(CVLFile *)file; // Calls -initWithFile:andFile: and adds arguments -merge previousRevision
- (id) initWithCVLFileAndAncestor:(CVLFile *)file; // Calls -initWithFile:andFile: and adds arguments -ancestor previousRevision -merge file
- (BOOL)isFileMergeRunning;

#ifdef JA_PATCH
- (CvsUpdateRequest *)getAndObserveUpdateRequestForFile:(CVLFile *)aFile revision:(NSString *)revision date:(NSString *)dateString toFile:(NSString *)destinationPath;
#endif
@end

@implementation CVLOpendiffRequest

+ (void) initialize
{
    static BOOL	initialized = NO;
    
    [super initialize];
    if(!initialized){
        initialized = YES;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(preferencesChanged:) name:@"PreferencesChanged" object:nil];
        [self preferencesChanged:nil];
    }
}

+ (void) preferencesChanged:(NSNotification *)notification
{
    ASSIGN(opendiffPath, [[NSUserDefaults standardUserDefaults] objectForKey:@"OpendiffPath"]);
	// This test should be done in preferences panel...  
    // Test to see if opendiffPath exists and is executable.
    if( isNilOrEmpty(opendiffPath) ){
        opendiffPath = @"";
    }
    if ( [[NSFileManager defaultManager] isExecutableFileAtPath:opendiffPath] == NO ) {
        NSRunAlertPanel(@"Warning",  
                        @"No executable for the opendiff command \"%@\". Please set this in preferences", 
                        @"OK", nil, nil, opendiffPath);
    }
}

+ (BOOL) opendiffIsValid
{
    if (opendiffPath != nil) return YES;
    return NO;
}

+ (CVLOpendiffRequest *) opendiffRequestForFile:(NSString *)fileFullPath
{
    CVLFile		*file;
    ECStatus	currentECStatus;

    if( [CVLOpendiffRequest opendiffIsValid] == NO ) return nil;

    file = (CVLFile *)[CVLFile treeAtPath:fileFullPath];
    currentECStatus = [file status]; // Stephane: shouldn't we check that status is up-to-date?
    
    if([file isLeaf]){
        if(currentECStatus.statusType == ECConflictType)
            return [[[self alloc] initWithCVLFileAndAncestor:file] autorelease];
        else
            return [[[self alloc] initWithCVLFile:file] autorelease];
    }
    else{
        // <file> is a directory: currently, this doesn't work for directories...
        // Don't do anything...
        return nil;
    }
}

#ifdef JA_PATCH
- (id) initWithCVLFile:(CVLFile *)file //prv
{
    NSParameterAssert([file isLeaf]);
    if (self = [self initWithTitle:@"opendiff"]) {
        NSString	*repoVersion = [file revisionInRepository]; // prv we are not sure the version is available !!!!
        ASSIGN(leftPath, [NSTemporaryDirectory() stringByAppendingPathComponent:[file filenameForRevision:repoVersion]]);
        ASSIGN(leftRequest, [self getAndObserveUpdateRequestForFile:file revision:repoVersion date:nil toFile:leftPath]);
        ASSIGN(rightPath, [file path]);
        ASSIGN(mergePath, [file path]);
    }

    return self;
}

- (id) initWithCVLFileAndAncestor:(CVLFile *)file
{
    NSParameterAssert([file isLeaf]);
    if(self = [self initWithCVLFile:file]){
        NSString	*previousVersion = [file precedingVersion];// prv we are not sure the version is available !!!!
        ASSIGN(ancestorPath, [NSTemporaryDirectory() stringByAppendingPathComponent:[file filenameForRevision:previousVersion]]);
        ASSIGN(leftPath, [file fileAncestorForRevision:previousVersion]);
        ASSIGN(ancestorRequest, [self getAndObserveUpdateRequestForFile:file revision:previousVersion date:nil toFile:ancestorPath]);
        ASSIGN(rightPath, [file path]);
        ASSIGN(mergePath, [file path]);
    }

    return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    RELEASE(leftPath);
    RELEASE(rightPath);
    RELEASE(mergePath);
    RELEASE(ancestorPath);
    RELEASE(leftRequest);
    RELEASE(rightRequest);
    RELEASE(ancestorRequest);
    [super dealloc];
}

- (CvsUpdateRequest *)getAndObserveUpdateRequestForFile:(CVLFile *)aFile revision:(NSString *)revision date:(NSString *)dateString toFile:(NSString *)destinationPath
{
    CvsUpdateRequest *theRequest;

theRequest=[CvsUpdateRequest cvsUpdateRequestForFile:[aFile name] inPath:[[aFile path] stringByDeletingLastPathComponent] revision:revision date:dateString toFile:destinationPath];
    if (theRequest) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(getVersionRequestCompleted:) name:@"RequestCompleted" object:theRequest];
    }
    return theRequest;
}

- (void)getVersionRequestCompleted:(NSNotification *)notification
{
    Request *aRequest=[notification object];

    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"RequestCompleted" object:aRequest];
    if (aRequest==leftRequest)
        RELEASE(leftRequest);
    if (aRequest==rightRequest)
        RELEASE(rightRequest);
    if (aRequest==ancestorRequest)
        RELEASE(ancestorRequest);
    if (![aRequest succeeded]) {
        allGetVersionRequestsSucceeded=NO; // should cancel the others
    }
    [self updateState];
}

- (void)start
{
    [leftRequest schedule];
    [rightRequest schedule];
    [ancestorRequest schedule];
    allGetVersionRequestsSucceeded=YES;
}

- (BOOL)allGetVersionRequestsEnded
{
    return (!leftRequest && !rightRequest && !ancestorRequest);
}

- (BOOL)readyForTask
{
    return [self allGetVersionRequestsEnded] && allGetVersionRequestsSucceeded;
}

- (BOOL)failedToGetReady
{
    return [self allGetVersionRequestsEnded] && !allGetVersionRequestsSucceeded;
}

- (id) initWithFile:(CVLFile *)file parameters:(NSDictionary *)parameterDictionary
{
    NSString		*leftVersion, *rightVersion, *ancestorVersion;
    NSString		*leftDatedVersion = nil, *rightDatedVersion = nil, *ancestorDatedVersion = nil;

    NSParameterAssert(file != nil);
    NSParameterAssert([file isLeaf]);

    leftVersion = [parameterDictionary objectForKey:@"LeftRevision"];
    if(!leftVersion){
        leftVersion = [parameterDictionary objectForKey:@"LeftTag"];
        if(!leftVersion){
            leftDatedVersion = [parameterDictionary objectForKey:@"LeftDate"];
            if(leftDatedVersion){
                ASSIGN(leftPath, [NSTemporaryDirectory() stringByAppendingPathComponent:[file filenameForDate:leftDatedVersion]]);
                ASSIGN(leftRequest, [self getAndObserveUpdateRequestForFile:file revision:nil date:leftDatedVersion toFile:leftPath]);
            }
        }
    }
    if(!leftPath)
        if(!leftVersion)
            ASSIGN(leftPath, [file path]);
        else{
            ASSIGN(leftPath, [NSTemporaryDirectory() stringByAppendingPathComponent:[file filenameForRevision:leftVersion]]);
            ASSIGN(leftRequest, [self getAndObserveUpdateRequestForFile:file revision:leftVersion date:nil toFile:leftPath]);
        }

    rightVersion = [parameterDictionary objectForKey:@"RightRevision"];
    if(!rightVersion){
        rightVersion = [parameterDictionary objectForKey:@"RightTag"];
        if(!rightVersion){
            rightDatedVersion = [parameterDictionary objectForKey:@"RightDate"];
            if(rightDatedVersion){
                ASSIGN(rightPath, [NSTemporaryDirectory() stringByAppendingPathComponent:[file filenameForDate:rightDatedVersion]]);
                ASSIGN(rightRequest, [self getAndObserveUpdateRequestForFile:file revision:nil date:rightDatedVersion toFile:rightPath]);
            }
        }
    }
    if(!rightPath)
        if(!rightVersion)
            ASSIGN(rightPath, [file path]);
        else{
            ASSIGN(rightPath, [NSTemporaryDirectory() stringByAppendingPathComponent:[file filenameForRevision:rightVersion]]);
            ASSIGN(rightRequest, [self getAndObserveUpdateRequestForFile:file revision:rightVersion date:nil toFile:rightPath]);
        }

    ancestorVersion = [parameterDictionary objectForKey:@"AncestorRevision"];
    if(!ancestorVersion){
        ancestorVersion = [parameterDictionary objectForKey:@"AncestorTag"];
        if(!ancestorVersion){
            ancestorDatedVersion = [parameterDictionary objectForKey:@"AncestorDate"];
            if(ancestorDatedVersion){
                ASSIGN(ancestorPath, [[NSTemporaryDirectory() stringByAppendingPathComponent:[file filenameForDate:ancestorDatedVersion]]);
                ASSIGN(ancestorRequest, [self getAndObserveUpdateRequestForFile:file revision:nil date:ancestorDatedVersion toFile:ancestorPath]);
            }
        }
    }
    if(!ancestorPath && ancestorVersion){
        ASSIGN(ancestorPath, [NSTemporaryDirectory() stringByAppendingPathComponent:[file filenameForRevision:ancestorVersion]]);
        ASSIGN(ancestorRequest, [self getAndObserveUpdateRequestForFile:file revision:ancestorVersion date:nil toFile:ancestorPath]);
    }

    ASSIGN(mergePath, [parameterDictionary objectForKey:@"MergeFile"]);
    if(!mergePath)
        ASSIGN(mergePath, [file path]);

    return self;
}

- (BOOL)setUpTask
{
    if ([super setUpTask]) {
        [task setLaunchPath:opendiffPath];
        if (ancestorPath) {
            [task setArguments:[NSArray arrayWithObjects:leftPath, rightPath, @"-ancestor", ancestorPath, @"-merge", mergePath, nil]];
        } else {
            [task setArguments:[NSArray arrayWithObjects:leftPath, rightPath, @"-merge", mergePath, nil]];
        }
        return YES;
    }
    return NO;
}



#else /* Not JA_PATCH */

- (id) initWithTitle:(NSString *)cmdString
{
    if( [CVLOpendiffRequest opendiffIsValid] == NO ) {
        [self dealloc];
        return nil;
    }

    if ( (self = [super initWithTitle:cmdString]) ) {
        NSTask	*opendiffTask = [[NSTask alloc] init];

        [opendiffTask setLaunchPath:opendiffPath];
        [self setTask:opendiffTask];
        [opendiffTask release];
    }

    return self;
}

- (id) initWithFile:(NSString *)fileFullPath andFile:(NSString *)fileFullPath2
{
    if ( (self = [self initWithTitle:@"opendiff"]) ) {
        [task setArguments:[NSArray arrayWithObjects:fileFullPath, fileFullPath2, nil]];
    }

    return self;
}

- (id) initWithCVLFile:(CVLFile *)file
{
    NSString	*repoVersion = nil;
    NSString	*repoVersionFullPath = nil;
    
#warning BUG: if file has no full status yet, revisionInRepository is nil => name will contain ending dot
    // We must be sure that we have a version number => we perhaps need to delay the request
    repoVersion = [file revisionInRepository];
    //if ( repoVersion != nil ) {
        repoVersionFullPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[file filenameForRevision:repoVersion]];
    //} else {
    //    repoVersionFullPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[file filenameForRevision:@""]];
    //}
    NSParameterAssert([file isLeaf]);
    if ( (self = [self initWithFile:repoVersionFullPath andFile:[file path]]) ) {
        CvsUpdateRequest	*repoVersionRequest = [CvsUpdateRequest cvsUpdateRequestForFile:[file name] inPath:[[file path] stringByDeletingLastPathComponent] revision:repoVersion date:nil toFile:repoVersionFullPath];

        [task setArguments:[[task arguments] arrayByAddingObjectsFromArray:[NSArray arrayWithObjects:@"-merge", [file path], nil]]];
        [self addPrecedingRequest:repoVersionRequest];
    }

    return self;
}

- (id) initWithCVLFileAndAncestor:(CVLFile *)file
{
    NSParameterAssert([file isLeaf]);
    if ( (self = [self initWithCVLFile:file]) ) {
        NSString	*previousVersion = [file precedingVersion];
        NSString	*ancestorFullPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[file filenameForRevision:previousVersion]];
        NSString	*unMergedFullPath = [file fileAncestorForRevision:previousVersion];
        NSArray		*args = [task arguments];
        CvsUpdateRequest	*ancestorRequest = [CvsUpdateRequest cvsUpdateRequestForFile:[file name] inPath:[[file path] stringByDeletingLastPathComponent] revision:previousVersion date:nil toFile:ancestorFullPath];

        [self addPrecedingRequest:ancestorRequest];
        // Make opendiff /tmp/file.repo .#file.previous -ancestor /tmp/file.previous -merge file
        [task setArguments:[NSArray arrayWithObjects:[args objectAtIndex:0], unMergedFullPath, @"-ancestor", ancestorFullPath, [args objectAtIndex:2], [args objectAtIndex:3], nil]];
    }

    return self;
}

- (id) initWithFile:(CVLFile *)file parameters:(NSDictionary *)parameterDictionary
{
    NSString		*leftVersion, *rightVersion, *ancestorVersion;
    NSString		*leftDatedVersion = nil, *rightDatedVersion = nil, *ancestorDatedVersion = nil;
    NSString		*leftVersionFullPath = nil, *rightVersionFullPath = nil, *ancestorVersionFullPath = nil;
    NSString		*mergePath;
    NSMutableArray	*requests = [NSMutableArray array];

    NSParameterAssert(file != nil);
    NSParameterAssert([file isLeaf]);

    leftVersion = [parameterDictionary objectForKey:@"LeftRevision"];
    if(!leftVersion){
        leftVersion = [parameterDictionary objectForKey:@"LeftTag"];
        if(!leftVersion){
            leftDatedVersion = [parameterDictionary objectForKey:@"LeftDate"];
            if(leftDatedVersion){
                leftVersionFullPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[file filenameForDate:leftDatedVersion]];
                [requests addObject:[CvsUpdateRequest cvsUpdateRequestForFile:[file name] inPath:[[file path] stringByDeletingLastPathComponent] revision:nil date:leftDatedVersion toFile:leftVersionFullPath]];
            }
        }
    }
    if(!leftVersionFullPath) {
        if(!leftVersion)
            leftVersionFullPath = [file path];
        else{
            leftVersionFullPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[file filenameForRevision:leftVersion]];
            [requests addObject:[CvsUpdateRequest cvsUpdateRequestForFile:[file name] inPath:[[file path] stringByDeletingLastPathComponent] revision:leftVersion date:nil toFile:leftVersionFullPath]];
        }        
    }

    rightVersion = [parameterDictionary objectForKey:@"RightRevision"];
    if(!rightVersion){
        rightVersion = [parameterDictionary objectForKey:@"RightTag"];
        if(!rightVersion){
            rightDatedVersion = [parameterDictionary objectForKey:@"RightDate"];
            if(rightDatedVersion){
                rightVersionFullPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[file filenameForDate:rightDatedVersion]];
                [requests addObject:[CvsUpdateRequest cvsUpdateRequestForFile:[file name] inPath:[[file path] stringByDeletingLastPathComponent] revision:nil date:rightDatedVersion toFile:rightVersionFullPath]];
            }
        }
    }
    if(!rightVersionFullPath) {
        if(!rightVersion)
            rightVersionFullPath = [file path];
        else{
            rightVersionFullPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[file filenameForRevision:rightVersion]];
            [requests addObject:[CvsUpdateRequest cvsUpdateRequestForFile:[file name] inPath:[[file path] stringByDeletingLastPathComponent] revision:rightVersion date:nil toFile:rightVersionFullPath]];
        }        
    }

    ancestorVersion = [parameterDictionary objectForKey:@"AncestorRevision"];
    if(!ancestorVersion){
        ancestorVersion = [parameterDictionary objectForKey:@"AncestorTag"];
        if(!ancestorVersion){
            ancestorDatedVersion = [parameterDictionary objectForKey:@"AncestorDate"];
            if(ancestorDatedVersion){
                ancestorVersionFullPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[file filenameForDate:ancestorDatedVersion]];
                [requests addObject:[CvsUpdateRequest cvsUpdateRequestForFile:[file name] inPath:[[file path] stringByDeletingLastPathComponent] revision:nil date:ancestorDatedVersion toFile:ancestorVersionFullPath]];
            }
        }
    }
    if(!ancestorVersionFullPath && ancestorVersion){
        ancestorVersionFullPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[file filenameForRevision:ancestorVersion]];
        [requests addObject:[CvsUpdateRequest cvsUpdateRequestForFile:[file name] inPath:[[file path] stringByDeletingLastPathComponent] revision:ancestorVersion date:nil toFile:ancestorVersionFullPath]];
    }

    mergePath = [parameterDictionary objectForKey:@"MergeFile"];
    if(!mergePath)
        mergePath = [file path];

    if ( (self = [self initWithFile:leftVersionFullPath andFile:rightVersionFullPath]) ) {
        CvsUpdateRequest	*aRequest;
        NSEnumerator		*anEnum = [requests objectEnumerator];

        if(ancestorVersionFullPath)
            [task setArguments:[NSArray arrayWithObjects:leftVersionFullPath, rightVersionFullPath, @"-ancestor", ancestorVersionFullPath, @"-merge", mergePath, nil]];
        else
            [task setArguments:[NSArray arrayWithObjects:leftVersionFullPath, rightVersionFullPath, @"-merge", mergePath, nil]];

        while ( (aRequest = [anEnum nextObject]) ) {
            [self addPrecedingRequest:aRequest];
        }
    }

    return self;
}

-(BOOL)startTask
    /*" This method first calls super to launch the task. If that is successful
        then this method delays for up to 10 seconds to see if the FileMerge
        application is running. If the fileMerge application has not started
        after 10 seconds processing continues anyway. This has been done so that
        multiply instances of the FileMerge application do not get started when 
        a user selects more that one file to to inspect the differences and
        before an instance of the FileMerge application is running.

        This method returns YES if super returns YES, otherwise NO is returned.
    "*/
{
    unsigned int myCount = 0;
    BOOL results = NO;
    
    results = [super startTask];
    if ( results == YES ) {
        while ( myCount < 10 ) {
            if ( [self isFileMergeRunning] ) {
                break;
            }
            [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.]];
            myCount++;
        }
    }
    return results;
}

- (BOOL)isFileMergeRunning
    /*" This method returns YES if the fileMerge application is running and
        NO otherwise.
    "*/
{
    NSWorkspace *theWorkspace = nil;
    NSArray *theLaunchedApplications = nil;
    NSDictionary *aLaunchedApplication  = nil;
    BOOL results = NO;
    NSEnumerator *anEnumerator = nil;
    NSString *theAppName = nil;
    
    theWorkspace = [NSWorkspace sharedWorkspace];
    theLaunchedApplications = [theWorkspace launchedApplications];
    if ( isNotEmpty(theLaunchedApplications) ) {
        anEnumerator = [theLaunchedApplications objectEnumerator];
        while ( (aLaunchedApplication = [anEnumerator nextObject]) ) {
            theAppName = [aLaunchedApplication objectForKey:@"NSApplicationName"];
            if ( [theAppName isEqualToString:@"FileMerge"] ) {
                results = YES;
                break;
            }
        }
    }
    return results;
}

-(NSString *)summary
{
    NSString *aSummary = nil;

    aSummary = [NSString stringWithFormat:@"\"%@\" (pid = %d)",
          [task launchPath], [task processIdentifier]];

    return aSummary;
}

- (id)outputFile
    /*" This class returns nil for outputFile and errorFile.
    They are not needed for this class. Plus this avoids the problem of
    the first task to call opendiff never gets removed from the Progress
    pannel because the outputFile and errorFile do not get a end notification
    until the FileMerge application is closed.
    "*/
{
    return nil;
}

- (id)errorFile
    /*" This class returns nil for outputFile and errorFile.
        They are not needed for this class. Plus this avoids the problem of
        the first task to call opendiff never gets removed from the Progress
        pannel because the outputFile and errorFile do not get a end notification
        until the FileMerge application is closed.
    "*/
{
    return nil;
}

#endif /* JA_PATCH */

- (NSArray *) modifiedFiles
{
    return nil;
}

@end
