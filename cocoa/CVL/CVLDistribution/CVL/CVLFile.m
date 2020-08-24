/* CVLFile.m created by ja on Thu 12-Mar-1998 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "CVLFile.h"
#import "ResultsRepository.h"
#import "NSFileManager_CVS.h"
#import <CvsRepository.h>
#import <Request.h>
#import <CvsEditor.h>
#import <CvsWatcher.h>
#import <CvsEntry.h>
#import <CvsTag.h>
#import <NSString+Lines.h>
#import <SenFoundation/SenFoundation.h>
#import "NSArray.SenCategorize.h"
#import "NSArray.SenUtilities.h"
#import "NSString.GentleCompare.h"
#import "NSString+CVL.h"
#import "WorkAreaViewer.h"
#import "CVLDelegate.h"
#import <AGRegex/AGRegexes.h>
#import <CvsStatusRequest.h>

static ECFileFlags defaultFileFlags={NO,NO,NO,NO,NO,YES,ECInvalidFile };
static NSString		*CVS_Entries_Directory = nil;
static NSString		*CVS_Repository_Directory = nil;
static NSString		*CVS_Tag_Directory = nil;

static BOOL	DO_NOT_USE_QUICKSTATUS = NO;


@interface SenFileSystemTree(CVLFile)
- initWithPath:(NSString *) value;
@end

@interface CVLFile (Private)
- (void)_setChildren:(NSArray *)childArray;
- (void)_setFlags:(ECFileFlags)newFlags;
- (void)_setModificationDate:(NSDate *)newDate;
- (void)setParent:(id)newParent;

- (void)getFlags;
- (void)getChildren;
- (void)getDifferences;
- (void)getLog;
- (void)getStatus;
- (void)getQuickStatus;
- (void)getTags;
- (void)getRepository;

- (void)getCumulatedStatusesArray;
- (void)summarizeDirectoryStatus;

- (void)touch;

- (NSComparisonResult)compareOnFileName:(CVLFile *)otherFile;

- (void) setRevisionInWorkArea:(NSString *)value;
- (void) setDateOfLastCheckout:(NSDate *)value;
- (void) setStickyOptions:(NSString *)value;
- (void) setStickyTag:(NSString *)value;
- (void) setStickyDate:(NSDate *)value;

@end

static NSArray *statusTokens=nil;
ECStatus tokenizedStatus[] = {
  {
      ECNoType, ECNoStatus
  }, {
      ECUpToDateType,ECUpToDate
  }, {
      ECLocallyModifiedType, ECLocallyModified
  }, {
      ECLocallyModifiedType, ECLocallyAdded
  }, {
      ECLocallyModifiedType, ECLocallyRemoved
  }, {
      ECNeedsUpdateType, ECNeedsPatch
  }, {
      ECNeedsUpdateType, ECNeedsCheckout
  }, {
      ECNeedsMergeType, ECNeedsMerge
  }, {
      ECNeedsMergeType, ECMixedStatus
  }, {
      ECConflictType ,ECConflict
  }, {
      ECConflictType ,ECConflict2
  }, {
      ECNotCVSType, ECNotCVS
  }, {
      ECNotCVSType, ECContainsNonCVSFiles
  }, {
      ECIgnoredType, ECIgnored
  }, {
      ECUnknownType, ECUnknown
  }, {
      ECUnknownType, ECInvalidEntry
  }
};


@implementation CVLFile
+ (void)initialize
{
    if (!statusTokens) {
        statusTokens=[[NSArray arrayWithObjects:
            @"none",
            @"Up-to-date",
            @"Locally Modified",
            @"Locally Added",
            @"Locally Removed",
            @"Needs Patch",
            @"Needs Checkout",
            @"Needs Merge",
            @"Mixed Status",
            @"Unresolved Conflict",
            @"File had conflicts on merge",
            @"not under CVS control",
            @"contains files not under CVS control",
            @"ignored",
            @"Unknown",
            @"Entry Invalid", nil] retain];
    };
    if(!CVS_Entries_Directory)
        CVS_Entries_Directory = [[@"CVS" stringByAppendingPathComponent:@"Entries"] retain]; // Let's cache the string
    if(!CVS_Repository_Directory)
        CVS_Repository_Directory = [[@"CVS" stringByAppendingPathComponent:@"Repository"] retain]; // Let's cache the string
    if(!CVS_Tag_Directory)
        CVS_Tag_Directory = [[@"CVS" stringByAppendingPathComponent:@"Tag"] retain]; // Let's cache the string
    DO_NOT_USE_QUICKSTATUS = [[NSUserDefaults standardUserDefaults] boolForKey:@"NoQuickStatus"];
}

- initWithPath:(NSString *) value
{
#warning (William 31-Oct-2003) This is being called on all the files in my home directory!!!
    if ( (self = [super initWithPath:value]) ) {
//        status = tokenizedStatus[ECUpToDate];//tokenizedStatus[ECUnknown];
        flags = defaultFileFlags;
        wasInvalidated = YES;
#warning William - This next statement temporarly turns off the consistency check.
		hasRunCvsEntriesConsistencyCheck = YES;
//        statusWasInvalidated = YES; // Do NOT set it to YES!
    }

    return self;
}

// ------------------ Flags
- (ECFileFlags)flags
{
    if (!have.flags) {
        [self getFlags];
    }
    return flags;
}

- (void)_setFlags:(ECFileFlags)newFlags
{
    if (1) { //if (newFlags!=flags) {
        flags=newFlags;
    }
    loading.flags=NO;
    have.flags=YES;
}

- (void)invalidateFlags
{
    if (loading.flags) {
        changes.flags=YES;
        [self touch];
    } else  if (have.flags) {
        have.flags=NO;       // We keep old value
        changes.flags=YES;
        [self touch];
    }
}

- (NSDate *)modificationDate
{
    if (!have.flags) {
        [self getFlags];
    }
    return modificationDate;
}

- (void)_setModificationDate:(NSDate *)newDate
{
    ASSIGN(modificationDate, newDate);
    loading.flags=NO;
    have.flags=YES;
}

- (void)getFlags
{
    if (!loading.flags) {
        loading.flags=YES;
//        [[self parent] getChildren];
        // Calling [[self parent] getChildren] will force rescanning fileSystem, which is sometimes unnecessary
        // and VERY time-consuming. Sometimes we'd like just to update some parts of flags.
        if(wasInvalidated){
            if(parent) // At startup, parent is nil; do not un-invalidate file here
                wasInvalidated = NO;
            [[self parent] getChildren];
        }
        else
        (void)[[self parent] loadedChildren];
		// Simply calling [[self parent] loadedChildren] will check if children need loading,
		// but sometimes (after an Update/Commit/...)
        // parent directory would need re-computing statuses (do NOT use summarizeDirectoryStatus or getCumulatedStatusesArray,
		// because gets recursive and scans whole fileSystem!), as it stays "Being Computed"...
    }
}

// ------------------ Children
- (NSArray *)children
{
    return children;
}

- parent
{
    if (!parent) {
        [self setParent:[super parent]];
    }
    return parent;
}

- (void)setParent:(id)newParent
{
    parent=newParent; // Not retained to avoid cycles
}

- (NSArray *)loadedChildren
{
    if (!have.children) {
        [self getChildren];
    }
    return children;
}

- (void)_setChildren:(NSArray *)childArray
{
    ASSIGN(children, childArray);
    have.children=YES;
    loading.children=NO;
}

- (void)invalidateChildren
{
    if (loading.children) {
        changes.children=YES;
        [self touch];
    } else if (have.children) {
        [self _setChildren:nil]; // We don't keep old value here
        have.children=NO;
        changes.children=YES;
        [self touch];
    }
    [[self repository] invalidateDir:[self path]];
}

//#define CVL_PROFILING
#ifdef CVL_PROFILING
#define INIT_PROFILE(c)		NSDate	*profileDate[c]; static NSTimeInterval	profileTotal[c]; static NSTimeInterval	profileSum = 0
#define START_PROFILE(i)	profileDate[i] = [[NSDate date] retain];
#define PROFILE(i)	{ NSTimeInterval	interval = -[profileDate[i] timeIntervalSinceNow]; [profileDate[i] release]; profileTotal[i] += interval; profileSum += interval; NSLog(@"PROFILING %@ [%d] = %.2lf (%.2lf / %.2lf)", NSStringFromSelector(_cmd), i, interval, profileTotal[i], profileSum);}
#define PROFILE2(i, p)	{ NSTimeInterval	interval = -[profileDate[i] timeIntervalSinceNow]; [profileDate[i] release]; profileTotal[i] += interval; profileSum += interval; NSLog(@"PROFILING %@ [%d] = %.2lf (%.2lf / %.2lf) %@", NSStringFromSelector(_cmd), i, interval, profileTotal[i], profileSum, p);}
#else
#define INIT_PROFILE(c)
#define START_PROFILE(i)
#define PROFILE(i)
#define PROFILE2(i, p)
#endif

- (void)getChildren
// Profiling: when opening CVL workarea, we spend 20s (total) in this method!!!
{
    ECFileFlags				fileFlags;

    INIT_PROFILE(10);

    /*    if(!have.quickStatus && !loading.quickStatus){
        BOOL	isDir;
        
        if(![[NSFileManager defaultManager] senFileExistsAtPath:[self path] isDirectory:&isDir])
            isDir = [self flags].isDir;

        if(isDir){
            CvsRepository	*dirRepository;

            [[ResultsRepository sharedResultsRepository] startUpdate];
            dirRepository = [self repository];
            if(dirRepository && [dirRepository root]){
                [[ResultsRepository sharedResultsRepository] getQuickStatusForFile:self];
                [[ResultsRepository sharedResultsRepository] endUpdate];
                return;
            }
            else
                [[ResultsRepository sharedResultsRepository] endUpdate];
        }
    }*/
    if(!loading.children){
        NSFileManager	*fileManager = [NSFileManager defaultManager];
        BOOL			isDir = NO;

        START_PROFILE(0);
        loading.children = YES;
        if(![fileManager senFileExistsAtPath:[self path] isDirectory:&isDir]) {
            isDir = [self flags].isDir;
        }
        if(isDir){
            
            // Here we have the case of the rootfile and its ancestors. They do 
            // not get their isDir flag set anywhere else. So we do it here.
            fileFlags = [self flags];
            if ( fileFlags.isDir == NO ) {
                fileFlags.isDir = isDir;
                [self _setFlags:fileFlags];
            }
                        
            // It's faster without an autoreleasePool... (10%)
            // [TRH] ...but this makes for a swapping hog on WinNT, so...
            // (and it would just delay the time spent waiting for autorelease to the end of the current runloop iteration, so it is probably better to spend it here and keep the working set manageable.)
            NSAutoreleasePool	*localAP = [[NSAutoreleasePool alloc] init];
            CvsRepository		*dirRepository = [self repository];

            // have.repository is initialized by [self repository] but can be set even if dirRespository is nil
            START_PROFILE(1); // 75%
            if (have.repository && ([dirRepository isNullRepository] == NO)) {
                ResultsRepository		*resultsRepository = [ResultsRepository sharedResultsRepository];
                NSMutableArray			*newChildren = [[NSMutableArray alloc] init];
                NSDirectoryEnumerator	*dirContentsEnumerator;
                CVLFile					*file;
                NSString				*fileName, *fullFilePath;

                [resultsRepository startUpdate];

                // (1) get files from local dir
                START_PROFILE(2); // 60%
                dirContentsEnumerator = [fileManager enumeratorAtPath:[self path]];
                while ( (fileName = [dirContentsEnumerator nextObject]) ) {
                    [dirContentsEnumerator skipDescendents]; // Perhaps later we can do it deeply, so it's faster!!
//                    START_PROFILE(9); // < 1%
                    fullFilePath = [[self path] stringByAppendingPathComponent:fileName];
                    file = (CVLFile *)[[self class] treeAtPath:fullFilePath];
                    [file setCvsEntry:nil];
                    [newChildren addObject:file];
//                    PROFILE(9);
                    if(dirRepository){
                        // Slow: takes 28%
                        NSDate	*fileModificationDate = nil;

                        if(file->have.flags)
                            fileFlags = [file flags];
                        else
                            fileFlags = defaultFileFlags;

                        START_PROFILE(8); // 10%
                        if([fileManager senFileExistsAtPath:fullFilePath isDirectory:&isDir]){
                            fileModificationDate = [[dirContentsEnumerator fileAttributes] objectForKey:NSFileModificationDate];
                            fileFlags.isInWorkArea = YES;
                            fileFlags.isInRepository = NO;
                            fileFlags.isDir = isDir;
                            fileFlags.isWrapper = isDir && ([dirRepository isWrapper:fullFilePath]);
                        }
                        PROFILE(8);
                        fileFlags.isIgnored = [dirRepository isIgnored:fullFilePath];
                        fileFlags.isHidden = fileFlags.isIgnored;
                        [file _setFlags:fileFlags];
                        [file _setModificationDate:fileModificationDate];
                    }
                }
                PROFILE(2);

                START_PROFILE(3); // 5%
                if(dirRepository){
#ifdef DEBUG
                    NSString *aMsg = [NSString stringWithFormat:
                                    @"++ Flags in dir:%@", [self path]];
                    SEN_LOG(aMsg);
#endif

                    // (2) get files from CVS/Entries
                    // 3%
                    {
                        // ./CVS/Entries: List and status of files in the working directory
                        // Each line represents an file or directory known by cvs (for the current directory)
                        // A line begins with / and has six items separated by /
                        // [D]/NAME/REVISION/CHECKOUT_DATE/STICKY_OPTIONS/STICKY_TAG_OR_DATE
                        // Directories have only D/NAME////
                        NSArray *childrenFromCvsEntries = nil;
                        NSEnumerator *aChildrenEnumerator = nil;
                        CVLFile *aCVLFile = nil;
                        
                        childrenFromCvsEntries = [self getChildrenFromCvsEntries];
                        if ( isNotEmpty(childrenFromCvsEntries) ) {
                            aChildrenEnumerator = [childrenFromCvsEntries objectEnumerator];
                            while ( (aCVLFile = [aChildrenEnumerator nextObject]) ) {
                                [newChildren addNewObject:aCVLFile];
                            }
                        }
                    }

                    // (3) get files from the repository
                    // This code works only for local repositories
                    // We need something like this for remote repositories too!
                    // Perhaps we should get the info from the repository and add missing files to our list.
                    // But we need a request (cvs -nq update ?) to do this => async!
                    /*                if (showRepositoryFiles) {
                        NSString *repositoryPath=[self repositoryPathForPath:dirPath];
                    NSString *fileNameInRepository;
                    NSString *fileInRepositoryPath;
                    BOOL isDir=NO;

                    if (dirContents=[fileManager directoryContentsAtPath: repositoryPath]) {
                        dirContentsEnumerator=[dirContents objectEnumerator];
                        while (fileNameInRepository=[dirContentsEnumerator nextObject]) {
                            if (![fileNameInRepository isEqual:@"Attic"]) {
                                fileName=nil;
                                fileInRepositoryPath=[repositoryPath stringByAppendingPathComponent:fileNameInRepository];
                                [fileManager senFileExistsAtPath:fileInRepositoryPath isDirectory: &isDir];

                                if (!isDir) {
                                    if ([fileNameInRepository hasSuffix:@",v"]) {
                                        fileName=[fileNameInRepository substringToIndex:[fileNameInRepository length]-2];
                                    }
                                } else {
                                    fileName=fileNameInRepository;
                                }

                                if (fileName) {
                                    fileName=[cvsEntryInfos objectAtIndex:1];
                                    fullFilePath=[dirPath stringByAppendingPathComponent:fileName];
                                    file=[[self class] treeAtPath:fullFilePath];
                                    [newChildren addNewObject:file];
                                    fileFlags=[file flags];
                                    fileFlags.isInRepository=YES;
                                    if (!(fileFlags.isInWorkArea || fileFlags.isInCVSEntries)) {
                                        fileFlags.isDir=isDir;
                                        fileFlags.isWrapper=([dirRepository isWrapper: fileName]);
                                        fileFlags.isHidden=[dirRepository shouldHideFile:fileName];
                                        fileFlags.isIgnored=fileFlags.isHidden;
                                    }
                                    [file _setFlags:fileFlags];
                                }
                            }
                        }
                    }

                    // 4 get files from the repository in Attic
                    repositoryPath=[repositoryPath stringByAppendingPathComponent:@"Attic"];
                    if (dirContents=[[NSFileManager defaultManager] directoryContentsAtPath: repositoryPath]) {
                        dirContentsEnumerator=[dirContents objectEnumerator];
                        while (fileNameInRepository=[dirContentsEnumerator nextObject]) {
                            fileName=nil;
                            fileInRepositoryPath=[repositoryPath stringByAppendingPathComponent:fileNameInRepository];

                            if ([fileNameInRepository hasSuffix:@",v"]) {
                                fileName=[fileNameInRepository substringToIndex:[fileNameInRepository length]-2];
                            }

                            if (fileName) {
                                fileName=[cvsEntryInfos objectAtIndex:1];
                                fullFilePath=[dirPath stringByAppendingPathComponent:fileName];
                                file=[[self class] treeAtPath:fullFilePath];
                                [newChildren addNewObject:file];
                                fileFlags=[file flags];
                                fileFlags.isInRepository=YES;
                                if (!(fileFlags.isInWorkArea || fileFlags.isInCVSEntries)) {
                                    fileFlags.isDir=NO;
                                    fileFlags.isWrapper=([dirRepository isWrapper: fileName]);
                                    fileFlags.isIgnored=[dirRepository shouldHideFile:fileName];
                                    fileFlags.isHidden=fileFlags.isIgnored;
                                }
                                [file _setFlags:fileFlags];
                            }
                        }
                    }
                    }
                    */
                    // Let's read CVS/Repository and CVS/Tag (if any)
                    if([self isRealDirectory]){
                        NSString        *aDirectory = nil;
                        NSString        *aTag = nil;
                        NSCalendarDate  *aDate = nil;

                        aDirectory = [self path];
                        aTag = [CvsTag getStringTagForDirectory:aDirectory];
                        [self setStickyTag:aTag];
                        have.stickyDateOrTagFetched = YES;
                        aDate = [CvsTag getDateTagForDirectory:aDirectory];
                        [self setStickyDate:aDate];                    
                        have.stickyDateOrTagFetched = YES;
                    }
                    // (5) put the whole damn thing in the database
                    // < 1%
                    {
                        // Block execution is fast: it takes less than 0.01% of method execution time
                        int	childIndex = [newChildren count] - 1;

                        for(; childIndex >= 0; childIndex--){
                            file = [newChildren objectAtIndex:childIndex];
                            fileFlags = [file flags];
                            if( fileFlags.isInWorkArea == YES ) {
                                // In workarea.
                                if ( fileFlags.isInCVSEntries == YES ) {
                                    // In CVS/Entries.
                                    fileFlags.type = ECCVSFile;
                                } else {
                                    // Not in CVS/Entries.
                                    if ( fileFlags.isInRepository == YES ) {
                                        // In repository; 
                                        // should be in CVS/Entries.
                                        fileFlags.type = ECInvalidFile;
                                    } else {
                                        // Not in repository.
                                        fileFlags.type = ECLocalFile;
                                    }                                    
                                }
                            } else {
                                // Not in workarea.
                                if ( fileFlags.isInCVSEntries == YES ) {
                                    // In CVS/Entries.
                                    if ( fileFlags.isInRepository == YES ) {
                                        // In repository.
                                        fileFlags.type = ECAbsentFile;
                                    } else {
                                        // Not in repository; 
                                        // but was in CVS/Entries.
                                        fileFlags.type = ECInvalidFile;
                                    }
                                } else {
                                    // Not in CVS/Entries.
                                    fileFlags.type = ECInactiveFile;
                                }                                
                            }

                            [file _setFlags:fileFlags];
                            if(fileFlags.isIgnored)
                                [file setStatus:tokenizedStatus[ECIgnored]];
                        }
                    }
                }
                PROFILE(3);

                // < 2%
                if(children){
                    // We need to check if some children, retrieved with quickStatus, are already in the array
                    NSMutableSet	*mySet = [[NSMutableSet alloc] initWithArray:newChildren];

                    [mySet addObjectsFromArray:children];
                    [newChildren setArray:[mySet allObjects]];
                    [mySet release];
                }
                [self _setChildren:[newChildren sortedArrayUsingSelector:@selector(compareOnFileName:)]];
                [resultsRepository endUpdate];
                [newChildren release];

            }
            PROFILE(1);
            [localAP release]; // Use of NSAutoreleasePool does not slow down at all
        } else { // If a leaf CVLFile
            [self _setChildren:nil];
        }
        PROFILE2(0, [self path]);
    }
}

- (NSString *)name
{
    return [[self path] lastPathComponent];
}

// ------------------ Status

- (ECStatus)status
{
    // Asking for a quickStatus on a file will perform the quickStatus on its parent directory
    // To avoid asking for a quickStatus when we don't need it, e.g. after committing a file,
    // we now check that parent directory does not need a quickStatus: it has not been invalidated,
    // and it is not refreshing.
    if ( (have.status == NO) && (have.quickStatus == NO) ) {
        BOOL parentStatusWasInvalidated = NO;
        if ( parent != nil ) {
            parentStatusWasInvalidated = ((CVLFile *)parent)->statusWasInvalidated;
        }
        if ( DO_NOT_USE_QUICKSTATUS || 
             (flags.isDir && ![self isRealWrapper]) || 
             (statusWasInvalidated && !parentStatusWasInvalidated) ) {
            [self getStatus];
        } else {
            [self getQuickStatus];
        }
    }
    return status;
}

- (void)setStatus:(ECStatus)newStatus
{
    if (newStatus.tokenizedStatus!=status.tokenizedStatus) {
        status=newStatus;
    }
    loading.quickStatus=NO;
    have.quickStatus=YES;
    if(loading.status){
        have.status=YES;
        loading.status=NO;
    }
    statusWasInvalidated = NO;
}

- (void)_setStatusString:(NSString *)statusString
{
    int tokenIndex;

    // WARNING: if status could not be done correctly, the assertion will NOT be respected!
    //  NSAssert1(statusString, @"No status retrieved for %@", self);
    if(statusString == nil)
        statusString = @"N/A";
    tokenIndex=[statusTokens indexOfObject:statusString];
    if (tokenIndex==NSNotFound) {
        NSString *aMsg = [NSString stringWithFormat:
            @"Warning no status token for status \"%@\". Status tokens are %@. CVLFile = %@",
            statusString, statusTokens, self];
        SEN_LOG(aMsg);
        
        tokenIndex=0;
    }
    SEN_ASSERT_CONDITION((tokenIndex >= 0));
    SEN_ASSERT_CONDITION((tokenIndex <= (ECUnknown+1)));
    [self setStatus:tokenizedStatus[tokenIndex]];
}

- (NSString *)statusString
{
    int statusToken = 0;
    if (have.quickStatus || have.status) {
        statusToken = [self status].tokenizedStatus;
        return [statusTokens objectAtIndex:statusToken];
    } else {
        return nil;
    }
}

- (void) setQuickStatusWithString:(NSString *)quickStatus
/*" Status codes:
    'U' Up-to-date
    'A' Locally added
    'R' Locally removed
    'M' Locally modified
    'm' Custom flag to tell us we need a merge
    'C' Conflict OR needs merge
    '?' Unknown by cvs or not yet under cvs control
    'u' Custom flag to handle new directories in repository which are not yet registered in workarea
    '=' Custom flag to tell file is up-to-date
    '!' Custom flag to tell status output couldn't be parsed, so file needs full status retrieval
"*/
{
    NSString            *aMsg = nil;
    unichar				statusChar = [quickStatus characterAtIndex:0];
    ResultsRepository	*resultsRepository = [ResultsRepository sharedResultsRepository];
    int					tokenIndex = -1;
    BOOL				isNewFile = NO;
    BOOL				isNewDir = NO;

    // If file is not among parent's children, put it!!!
    // This is the case for files that are new in the repository, thus not registered in the workarea
    if(![[[self parent] children] containsObject:self]){
        if(![[self parent] children])
            [[self parent] _setChildren:[NSArray arrayWithObject:self]];
        else{
            NSMutableArray	*newChildren = [NSMutableArray arrayWithArray:[[self parent] children]];

            [newChildren addObject:self];
            [[self parent] _setChildren:[newChildren sortedArrayUsingSelector:@selector(compareOnFileName:)]];
        }
    }
    switch(statusChar){
        case 'U':
#if 0
            if(![self flags].isInWorkArea)
                isNewFile = YES;
			tokenIndex = 6; // Needs checkout
            if(!have.status){
                [self getStatus]; // We cannot determine if status is NeedsCheckout or NeedsPatch
                return; // Flags will be set correctly
            }
#else
                if(![self flags].isInWorkArea)
                    isNewFile = YES;
                else if(!have.status){
                    [self getStatus]; // We cannot determine if status is NeedsCheckout or NeedsPatch
                    return; // Flags will be set correctly
                }
                tokenIndex = 6; // Needs checkout
#endif
            break;
        case 'A': // Locally added
            tokenIndex = 3;
            break;
        case 'R': // Locally removed
            tokenIndex = 4;
            break;
        case 'M': // Locally modified
            tokenIndex = 2;
            break;
        case 'm': // Needs merge; custom flag!
            tokenIndex = 7;
            break;
        case 'C': // Conflict OR needs merge, depending on the current status: if currently needsMerge, don't change
            // If file had not yet fetched it status,
            // we have no way (?) to know if file status is currently conflict or if it will be (after update)!
            // Thus we need to launch a full status request...
            if(!have.status){
                [self getStatus];
                return;
            }
            if(status.tokenizedStatus == ECNeedsMerge)
                tokenIndex = 7; // Needs merge
            else
                tokenIndex = 9; // Conflict
            break;
        case '?': // Unknown by cvs or not yet under cvs control
            tokenIndex = [self isLeaf] ? 11:12;
            break;
        case 'u': // Custom flag to handle new directories in repository which are not yet registered in workarea
                  // In fact we cannot know if directory contains valid files,
                  // or if its contents is old. cvs output is not very explicit...
                  // BTW, it does not prune empty dirs when doing quickStatus.
                  // So, as long as we cannot know if dirs are new or old,
                  // let's mark them as unknown, so it will not display
                  // messy names.
            if(flags.isInCVSEntries) // No need to check for have.status flag; flags.isInCVSEntries is up-to-date before entering this method
                tokenIndex = 6; // Needs checkout
            else
                tokenIndex = 14; // Unknown status for cvs (even if it IS known by it...)
            isNewDir = YES;
            break;
        case '=': // Custom flag to tell file is up-to-date
            tokenIndex = 1;
            break;
//        case 'r': // Custom flag to tell file is being removed on next update
//            tokenIndex = 6; // NeedsUpdate
//            break;
        case '!': // Custom flag to tell status output couldn't be parsed, so file needs full status retrieval
            if(!have.status){
                [self getStatus];
                return;
            }
            else{
                [resultsRepository startUpdate];
                
                loading.quickStatus = NO;
                have.quickStatus = YES;    
                statusWasInvalidated = NO;
                changes.status = YES;
                changes.quickStatus = YES;
                [resultsRepository fileDidChange:self];

                [resultsRepository endUpdate];
                return;
            }
            break;
        default:
            aMsg = [NSString stringWithFormat:
                @"Unknown quick status char: %c", (char)statusChar];
            SEN_LOG(aMsg);
            
            return;
    }

    NSAssert(tokenIndex != -1, @"Did not set tokenIndex!");
    
    [resultsRepository startUpdate];

    [self setStatus:tokenizedStatus[tokenIndex]];
    loading.quickStatus = NO;
    have.quickStatus = YES;
    statusWasInvalidated = NO;
    changes.status = YES;
    changes.quickStatus = YES;
    if(isNewDir || isNewFile){
        // The case where local file AND repository file both exist is not handled correctly.
		// Some flags are overridden in -getChildren. Worse if we do a refresh...
        // It's a bit to messy to do it correctly now. We need to review many code lines...
        flags.isInRepository = YES;
        if(flags.isInWorkArea){
            flags.type = ECInvalidFile;
        }
        else{
            flags.isInRepository = YES;
            flags.isIgnored = [[self repository] isIgnored:[self path]];
            flags.isHidden = flags.isIgnored;
            flags.type = ECInactiveFile;
        }
    }
/*    if(isNewDir){
        flags.isDir = YES; // If we set isDir to YES, entry will not be displayed in browser!!
        flags.isWrapper = [[self repository] isWrapper:[self path]];
    }*/
    [resultsRepository fileDidChange:self];

    [resultsRepository endUpdate];
}

- (void)setStatusFromDictionary:(NSDictionary *)results
{
    // Sets status, revisionInWorkArea, revisionInRepository, dateOfLastCheckout, stickyTag, stickyDate and stickyOptions
  id result;
  ResultsRepository *resultsRepository=[ResultsRepository sharedResultsRepository];
  [resultsRepository startUpdate];

  [self _setStatusString:[results objectForKey:CVS_STATUS_KEYWORD]];
  [self setRevisionInWorkArea:[results objectForKey:CVS_VERSION_KEYWORD]];

  result = [results objectForKey:CVS_REPOSITORY_VERSION_KEYWORD];
  ASSIGN(revisionInRepository,result);

  result=[results objectForKey:CVS_LAST_CHECKOUT_DATE_KEYWORD];
  [self setDateOfLastCheckout:result]; // Do NOT check if returned last checkout date! If we do, we can never remove it
  // Notice that in client/server mode, this info is NOT returned by the server

  result=[results objectForKey:CVS_STICKY_TAG_KEYWORD];
  [self setStickyTag:result]; // Do NOT check if returned sticky tag! If we do, we can never remove it (Bug 1000103)
  have.stickyDateOrTagFetched = YES;

  result=[results objectForKey:CVS_STICKY_DATE_KEYWORD];
  [self setStickyDate:result]; // Do NOT check if returned sticky tag! If we do, we can never remove it (Bug 1000103)
  have.stickyDateOrTagFetched = YES;

  result=[results objectForKey:CVS_STICKY_OPTIONS_KEYWORD];
  [self setStickyOptions:result]; // Do NOT check if returned sticky tag! If we do, we can never remove it (Bug 1000103)

  loading.status=NO;
  loading.quickStatus=NO; // ????????????????
  have.status=YES;
  have.quickStatus=YES;
  statusWasInvalidated = NO;
  changes.status=YES;
  changes.quickStatus=YES;
  [resultsRepository fileDidChange:self];

  [resultsRepository endUpdate];
}

- (void)invalidateStatus
{
    statusWasInvalidated = YES;
    if (loading.status || loading.quickStatus) {
        changes.status=YES;
        changes.quickStatus=YES;
        [self touch];
    } else if (have.status || have.quickStatus) {
        status=tokenizedStatus[ECNoStatus];
        have.status=NO;       // We don't keep old value
        changes.status=YES;
        have.quickStatus=NO;       // We don't keep old value
        changes.quickStatus=YES;
        [self setStickyOptions:nil];
        have.stickyDateOrTagFetched = NO;            
        [self touch];
    }
}

- (BOOL)isLeaf
{
    (void)[self flags];
    if (have.flags) {
        return (!flags.isDir || flags.isWrapper);
    } else {
        CvsRepository *dirRepository;
        if ( (dirRepository=[[self parent] repository]) ) {
            return (([self loadedChildren]==nil) || ([dirRepository isWrapper:[self path]]));
        } else {
            return ([self loadedChildren]==nil);
        }
    }
}

- (void)getStatus
{
    if (!loading.status) {
        ECFileFlags fileFlags;

        fileFlags=[self flags];
        if (have.flags) {
            loading.status=YES;
            loading.quickStatus=YES;
            if (fileFlags.isIgnored) {
                [self setStatus:tokenizedStatus[ECIgnored]];
            } else {
                if ([self isLeaf]) {
#if 1
                    if (fileFlags.type==ECLocalFile) {
                        [self setStatus:tokenizedStatus[ECNotCVS]];
                    } else {
                        [[ResultsRepository sharedResultsRepository] getStatusForFile:self];
                    }
#else
#warning MODIFIED
                    if (!have.repository || [repository root] == nil){
                        [self setStatus:tokenizedStatus[ECNotCVS]];
                    } else {
                        [[ResultsRepository sharedResultsRepository] getStatusForFile:self];
                    }
#endif
                } else {
                    [self summarizeDirectoryStatus];
                }
            }
        }
    }
}

- (void)getQuickStatus
{
    if (!loading.status && !loading.quickStatus) {
        ECFileFlags fileFlags;

        fileFlags=[self flags];
        if (have.flags) {
            loading.quickStatus=YES;
            if (fileFlags.isIgnored) {
                [self setStatus:tokenizedStatus[ECIgnored]];
            } else {
                if ([self isLeaf]) {
#if 1
                    if (fileFlags.type==ECLocalFile) {
                        [self setStatus:tokenizedStatus[ECNotCVS]];
                    } else {
                        [[ResultsRepository sharedResultsRepository] getQuickStatusForFile:self];
                    }
#else
#warning MODIFIED
                    if (!have.repository || [repository root] == nil){
                        [self setStatus:tokenizedStatus[ECNotCVS]];
                    } else {
                        [[ResultsRepository sharedResultsRepository] getQuickStatusForFile:self];
                    }
#endif
                } else {
                        [self summarizeDirectoryStatus];
                }
            }
        }
    }
}

- (void)summarizeDirectoryStatus
{
    if ([self cumulatedStatusesArray]) {
        if (!(*cumulatedStatusesArray)[ECNoStatus]) {
            BOOL modified=NO,needsUpdate=NO,needsMerge=NO,conflict=NO,notCVS=NO,mixed=NO,ignored=NO;
            int statusToken;
            ECStatus childStatus;

            for (statusToken=0;statusToken<=ECUnknown;statusToken++) {
                if ((*cumulatedStatusesArray)[statusToken]>0) {
                    childStatus=tokenizedStatus[statusToken];
                    if (childStatus.statusType==ECLocallyModifiedType) modified=YES;
                    else if (childStatus.statusType==ECNeedsUpdateType) needsUpdate=YES;
                    else if (childStatus.statusType==ECConflictType) conflict=YES;
                    else if (childStatus.statusType==ECNeedsMergeType) needsMerge=YES;
                    else if (childStatus.statusType==ECNotCVSType) notCVS=YES;
                    else if (childStatus.statusType==ECIgnoredType) ignored=YES;
                }
            }

            statusToken=ECUpToDate; /////////////// Shouldn't it be UNKNOWN?
            if (notCVS) {
				statusToken=ECContainsNonCVSFiles;
            }
            if(needsUpdate) {
                if(flags.isInRepository && !flags.isInWorkArea) // In case where dir is in repository but not in work area
                    statusToken = ECNeedsCheckout;
                else
                    statusToken = ECNeedsPatch; // => a folder containing a file <NeedsCheckout> will display <Needs Patch>                
            }
            
//            if (needsUpdate) statusToken=ECNeedsPatch; // => a folder containing a file <NeedsCheckout> will display <Needs Patch>
            if (modified) statusToken=ECLocallyModified;
            if (needsMerge) statusToken=ECNeedsMerge;
            if (mixed || (modified && (needsUpdate || needsMerge)) || (needsUpdate && needsMerge)) statusToken=ECMixedStatus;
            if (conflict) statusToken=ECConflict;

            [self setStatus:tokenizedStatus[statusToken]];
        }
    }
}

// ---------- cumulated status
- (ECCumulatedStatuses *)cumulatedStatusesArray
{
    if ([self isLeaf]) { // a leaf don't have such a thing
        return NULL;
    }
    if (!have.cumulatedStatuses)
            [self getCumulatedStatusesArray];

    return cumulatedStatusesArray;
}

- (void)invalidateCumulatedStatuses
{
    if (loading.cumulatedStatuses) {
        changes.cumulatedStatuses=YES;
        [self touch];
    } else if (have.cumulatedStatuses) {
        have.cumulatedStatuses=NO;       // We keep old value
        changes.cumulatedStatuses=YES;
//        statusWasInvalidated = YES; // Needed?
        [self touch];
    }
}

- (void)getCumulatedStatusesArray
{
    if (!loading.cumulatedStatuses) {
        int statusToken;
        id childrenEnumerator;
        CVLFile *child;
        ECCumulatedStatuses *childCumulatedStatusesArray;
        NSArray *myLoadedChildren = nil;
        unsigned int aCount = 0;
            
        ResultsRepository *resultsRepository=[ResultsRepository sharedResultsRepository];

        [resultsRepository startUpdate];
        loading.cumulatedStatuses=YES;

        [self flags];
        if (have.flags) {
            if (flags.isIgnored) { // no cumulated statuses for ignored files
                if (cumulatedStatusesArray) {
                    NSZoneFree(NSDefaultMallocZone(), cumulatedStatusesArray);
                    cumulatedStatusesArray=NULL;
                }
                loading.cumulatedStatuses=NO;
                have.cumulatedStatuses=YES;
//                statusWasInvalidated = NO; // Needed?
            } else {
                if (!cumulatedStatusesArray) {
                    cumulatedStatusesArray=(ECCumulatedStatuses *)NSZoneMalloc(NSDefaultMallocZone(), sizeof(ECCumulatedStatuses));
                }
                for (statusToken=0;statusToken<=ECUnknown;statusToken++) {
                    (*cumulatedStatusesArray)[statusToken]=0;
                }
                childrenEnumerator=[[self loadedChildren] objectEnumerator];
                while ( (child=[childrenEnumerator nextObject]) ) {
                    if ([child isLeaf]) {
                        statusToken=[child status].tokenizedStatus;
                        (*cumulatedStatusesArray)[statusToken]++;
                    } else {
                        childCumulatedStatusesArray=[child cumulatedStatusesArray];
                        if (childCumulatedStatusesArray) {
                            for (statusToken=0;statusToken<=ECUnknown;statusToken++) {
                                (*cumulatedStatusesArray)[statusToken]+=(*childCumulatedStatusesArray)[statusToken];
                            }
                        }
                    }
                }
                // If directory contains only a CVS subdirectory, resulting cumulated statuses will be 0 
				// because CVS is ignored and ignored files return no cumulated statuses
                myLoadedChildren = [self loadedChildren];
                if( myLoadedChildren != nil ){
                    aCount = [myLoadedChildren count];
                    switch(aCount){
                        case 0:
                            if(flags.isInCVSEntries) // We MUST check this first: if dir is in CVS entries, dir perhaps needs update
                                (*cumulatedStatusesArray)[ECNeedsCheckout]++;
                            else
                                // New empty directory not under cvs
                                (*cumulatedStatusesArray)[ECNotCVS]++;
                            break;
                        case 1: // Not only for 1, but for 1 and more (can contain other ignored files...)
                        default:
                            if([[[[[self loadedChildren] objectAtIndex:0] path] lastPathComponent] isEqualToString:@"CVS"]){
                    (*cumulatedStatusesArray)[ECUpToDate]++; // And if it misses some files? => ECNeedsCheckout. It depends on CVS/Entries. BUT missing files recorded in CVS/Entries have already returned status. => check only for missing files that are not yet in workarea
                            }
                            break;
                    }
                }

                loading.cumulatedStatuses=NO; // Shouldn't it be NO as long as children have not yet loaded their cumulated statuses?
                have.cumulatedStatuses=YES;
//                statusWasInvalidated = NO; // Needed?
            }
        }
        [resultsRepository endUpdate];
    }
}

- (NSString *)revisionInWorkArea
{
#if 0
    if (!have.status) {
        [self getStatus];
    }
#else
    if(!revisionInWorkArea && !have.status)
        [self getStatus];
#endif
    return revisionInWorkArea;
}

- (void) setRevisionInWorkArea:(NSString *)value
{
    //  NSAssert1(value, @"No version retrieved for %@", self);
    // It may happen that no version is retrieved if file has an incorrect version number(?)
    if(value == nil)
        value = @"N/A";
    ASSIGN(revisionInWorkArea, value);
}

- (NSString *)revisionInRepository
{
    if (!have.status) {
        [self getStatus];
    }
    return revisionInRepository;
}

- (void) setDateOfLastCheckout:(NSDate *)value
{
    ASSIGN(dateOfLastCheckout, value);
}

- (NSDate *)dateOfLastCheckout
{
#if 0
    if (!have.status) {
        [self getStatus];
    }
#else
    if(!dateOfLastCheckout && !have.status)
        [self getStatus];
#endif
    return dateOfLastCheckout;
}

- (NSString *)stickyTag
{
#if 0
    if (!have.status) {
        [self getStatus];
    }
#else
    if(!have.stickyDateOrTagFetched)
        [self getStatus];
#endif

    return stickyTag;
}

- (NSString *)strippedStickyTag
    /*" This method strips off the part in parenthesis from the sticky tag and 
        returns it (e.g. "TAG_1001 (revision: 1.62)" becomes "TAG_1001"). If
        there is no sticky tag then this method returns nil. This method is used
        mainly to create suggested file names when saving a copy of a workarea 
        file of a particular tag to the file system.
    "*/
{
    NSString *aStickyTag = nil;
    NSString *aStrippedStickyTag = nil;
    NSRange aRange;
    unsigned int anIndex = 0;
    
    aStickyTag = [self stickyTag];
    if ( isNotEmpty(aStickyTag) ) {
        aRange = [aStickyTag rangeOfString:@" ("];
        anIndex = aRange.location;
        if ( anIndex != NSNotFound ) {
            aStrippedStickyTag = [aStickyTag substringToIndex:anIndex];
        }
    }
    return aStrippedStickyTag;
}

- (void) setStickyTag:(NSString *)value
{
    if(value == nil)
        value = @"";
    ASSIGN(stickyTag, value);
}

- (NSString *)stickyOptions
{
#if 0
    if (!have.status) {
        [self getStatus];
    }
#else
    if(!stickyOptions)
        [self getStatus];
#endif
    return stickyOptions;
}

- (void) setStickyOptions:(NSString *)value
{
    if(value == nil)
        value = @"";
    ASSIGN(stickyOptions, value);
}

- (NSDate *)stickyDate
{
#if 0
    if (!have.status) {
        [self getStatus];
    }
#else
    if(!have.stickyDateOrTagFetched)
        [self getStatus];
#endif
    return stickyDate;
}

- (void) setStickyDate:(NSDate *)value
{
    ASSIGN(stickyDate, value);
}

// ------------- Log
- (NSArray *)log
{
    if (!have.log) {
        [self getLog];
    }
    return log;
}

- (void)setLog:(NSArray *)newLog
{
    if (!((newLog==log) || [newLog isEqual:log])) {
        ASSIGN(log, newLog);
        changes.log=YES;
        [self touch];
    }
    have.log=YES;
    loading.log=NO;
}

- (void)_setLog:(NSArray *)newLog
{
    ASSIGN(log, newLog);
    have.log=YES;
    loading.log=NO;
}

- (void)invalidateLog
{
    if (loading.log) {
        changes.log=YES;
        [self touch];
    } else if (have.log) {
        [self _setLog:nil];
        have.log=NO;
        changes.log=YES;
        [self touch];
    }
}

- (void)getLog
{
    if (!loading.log) {
        ECFileFlags fileFlags;

        fileFlags=[self flags];
        if (have.flags) {
            if ((fileFlags.type==ECLocalFile) || fileFlags.isIgnored || (fileFlags.isDir && !fileFlags.isWrapper)) {
                [self _setLog:nil];
                return ;
            }
        }
        loading.log=YES;
        [[ResultsRepository sharedResultsRepository] getLogForFile:self];
    }
}

// ------------------ Differences

- (NSString *)differencesWithContext:(unsigned)contextLineNumber outputFormat:(CVLDiffOutputFormat)outputFormat
{
    if (!differences || differencesContext != contextLineNumber || diffOutputFormat != outputFormat) {
        differencesContext = contextLineNumber;
        diffOutputFormat = outputFormat;
        [self getDifferences];
    }
    return differences;
}

- (void)setDifferences:(NSString *)newDifferences
{
    if (!((newDifferences==differences) || [newDifferences isEqual:differences])) {
        ASSIGN(differences, newDifferences);
        changes.differences=YES;
        [self touch];
    }
    loading.differences=NO;
    have.differences=YES;
}

- (void)_setDifferences:(NSString *)newDifferences
{
    ASSIGN(differences, newDifferences);
    loading.differences=NO;
    have.differences=YES;
}

- (void)invalidateDifferences
{
    if (loading.differences) {
        changes.differences=YES;
        [self touch];
    } else if (have.differences) {
        [self _setDifferences:nil];
        changes.differences=YES;
        have.differences=NO;
        [self touch];
    }
}

- (void)getDifferences
{
    if (!loading.differences) {
        ECFileFlags fileFlags;

        fileFlags=[self flags];
        if (have.flags) {
            if ((fileFlags.type==ECLocalFile) || fileFlags.isIgnored || fileFlags.isDir /* wrappers included */) {
                [self _setDifferences:nil];
                return;
            }
        }
        loading.differences=YES;
        [[ResultsRepository sharedResultsRepository] getDifferencesForFile:self context:differencesContext outputFormat:diffOutputFormat];
    }
}

// ---------- tags

- (NSArray*) tags
{
    if (!have.tags) {
        [self getTags];
    }
    return tags;
}

- (void) setTags: (NSArray*) newTags
{
    if (!((newTags==tags) || [newTags isEqual:tags])) {
        ASSIGN(tags, newTags);
        changes.tags=YES;
        [self touch];
    }
    have.tags=YES;
    loading.tags=NO;
}

- (void)_setTags:(NSArray *)newTags
{
    ASSIGN(tags, newTags);
    have.tags=YES;
    loading.tags=NO;
}

- (void)invalidateTags
{
    if (loading.tags) {
        changes.tags=YES;
        [self touch];
    } else if (have.tags) {
        [self _setTags:nil];
        changes.tags=YES;
        have.tags=NO;
        [self touch];
    }
}

- (void)getTags
{
    if (!loading.tags) {
        ECFileFlags fileFlags;

        fileFlags=[self flags];
        if (have.flags) {
            if ((fileFlags.type==ECLocalFile) || fileFlags.isIgnored || (fileFlags.isDir && !fileFlags.isWrapper)) {
                [self _setTags:nil];
                return ;
            }
        }
        loading.tags=YES;
        [[ResultsRepository sharedResultsRepository] getTagsForFile:self];
    }
}


// ---------- repository
- (CvsRepository *)repository
{
    if (!have.repository) {
        [self getRepository];
    }
    return repository;
}

- (void)invalidateRepository
{
    if (loading.repository) {
        changes.repository=YES;
        [self touch];
    } else if (have.repository) {
        changes.repository=YES;
        have.repository=NO;
        [self touch];
    }
}

- (void)getRepository
{
    CvsRepository *aCvsRepository = nil;
    
    if (!loading.repository) {
        loading.repository = YES;
        // Note: if loading.repository is not set to NO below then it gets set
        // in the -cumulateChanges method. It is not clear to me what is happening
        // here. But if loading.repository = NO is put at the end of this method
        // then no files  show up in the CVL browser.
        // William Swats   6-Nov-2003
        have.repository = NO;
        aCvsRepository = [CvsRepository repositoryForPath:[self path]];
        if ( aCvsRepository != nil ) {
            if ([aCvsRepository isUpToDate] == YES) {
                have.repository=YES;
                loading.repository = NO;
            } else {
                aCvsRepository = nil;
            }            
        }
        ASSIGN(repository, aCvsRepository);
    }
}

// ----------------- other methods
- (void)touch
{
    [[ResultsRepository sharedResultsRepository] fileDidChange:self];
}

- (void)invalidateAll
{
#warning BUG?
    // Some bug reports make me think that we are modifying the tree
    // during its traversal...
    ResultsRepository *resultsRepository=[ResultsRepository sharedResultsRepository];

    [resultsRepository startUpdate];
    [self invalidateFlags];
    [self invalidateChildren];
    [self invalidateStatus];
    [self invalidateLog];
    [self invalidateTags];
    [self invalidateDifferences];
    [self invalidateCumulatedStatuses];
    [self invalidateRepository];
    [self invalidateCvsEditors];
    [self invalidateCvsWatchers];    
    wasInvalidated = YES;
    [resultsRepository endUpdate];
}

- (void)propagateChanges
{
    if (oldChanges.flags || oldChanges.children) {
        [self invalidateStatus];
        [self invalidateCumulatedStatuses];
    }
    if (oldChanges.cumulatedStatuses) {
        BOOL	oldFlag = statusWasInvalidated;

        [self invalidateStatus];
        statusWasInvalidated = oldFlag; // Needed?
        [[self parent] invalidateCumulatedStatuses];
    }
    if (oldChanges.status || oldChanges.quickStatus) {
        [[self parent] invalidateCumulatedStatuses];
    }
    if (oldChanges.repository) {
        if (have.children) {
            NSArray	*anArray = [children copy];
            
           [anArray makeObjectsPerformSelector:@selector(invalidateFlags)];
           [anArray release];
        }
        [self invalidateFlags];
        [self invalidateChildren];
    }
}

- (void)cumulateChanges
{
    loading.flags&=!changes.flags;
    loading.children&=!changes.children;
    loading.status&=!changes.status;
    loading.quickStatus&=!changes.quickStatus;
    loading.log&=!changes.log;
    loading.differences&=!changes.differences;
    loading.cumulatedStatuses&=!changes.cumulatedStatuses;
    loading.repository&=!changes.repository;
    loading.cvsEditorsFetchedFlag&=!changes.cvsEditorsFetchedFlag;
    loading.cvsWatchersFetchedFlag&=!changes.cvsWatchersFetchedFlag;
    
    cumulatedChanges.flags|=changes.flags;
    cumulatedChanges.children|=changes.children;
    cumulatedChanges.status|=changes.status;
    cumulatedChanges.quickStatus|=changes.quickStatus;
    cumulatedChanges.log|=changes.log;
    cumulatedChanges.differences|=changes.differences;
    cumulatedChanges.cumulatedStatuses|=changes.cumulatedStatuses;
    cumulatedChanges.repository|=changes.repository;
    cumulatedChanges.cvsEditorsFetchedFlag|=changes.cvsEditorsFetchedFlag;
    cumulatedChanges.cvsWatchersFetchedFlag|=changes.cvsWatchersFetchedFlag;
    
    oldChanges=changes;
    
    changes.flags=NO;
    changes.children=NO;
    changes.status=NO;
    changes.quickStatus=NO;
    changes.log=NO;
    changes.differences=NO;
    changes.cumulatedStatuses=NO;
    changes.repository=NO;
    changes.cvsEditorsFetchedFlag=NO;
    changes.cvsWatchersFetchedFlag=NO;    
}

- (void)clearChanges
{
    
    changes.flags=NO;
    changes.children=NO;
    changes.status=NO;
    changes.quickStatus=NO;
    changes.log=NO;
    changes.differences=NO;
    changes.cumulatedStatuses=NO;
    changes.repository=NO;
    changes.cvsEditorsFetchedFlag=NO;
    changes.cvsWatchersFetchedFlag=NO;
    
    oldChanges=changes;
    cumulatedChanges=changes;
}

- (ECFileAttributeGroups)changes
{
    return cumulatedChanges;
}

- (ECFileAttributeGroups)have
{
    return have;
}

- (NSComparisonResult)compareOnFileName:(CVLFile *)otherFile
{
    return [[[self path] lastPathComponent] gentleCompare:[[otherFile path] lastPathComponent]];
}

- (NSString *) filenameForRevision:(NSString *)aVersion
{
    if ( isNotEmpty(aVersion) ) {
        return [[[self path] lastPathComponent] cvlFilenameForRevision:aVersion];
    }
    return [[self path] lastPathComponent];
}

- (NSString *) filenameForDate:(NSString *)aDate
{
    return [[[self path] lastPathComponent] cvlFilenameForDate:aDate];
}

- (NSString *) fileAncestorForRevision:(NSString *)aVersion
{
    NSString	*aFilename = [self name];
    
    // This pattern MUST match the one defined in -precedingVersion
    // Do NOT apply our new naming convention, because in this case
    // we need to use cvs convention!
    return [[[self path] stringByDeletingLastPathComponent] stringByAppendingPathComponent:[NSString stringWithFormat:@".#%@.%@", aFilename, aVersion]];
}

- (NSString *) precedingVersion
// Retrieves preceding version, assuming it is the earliest file matching pattern: .#filename.version
{
    NSString		*currentFile = [self name];
    NSString		*currentDir = [path stringByDeletingLastPathComponent];
    NSArray			*dirContent = [[NSFileManager defaultManager] directoryContentsAtPath:currentDir];
    NSString		*latestVersion = nil;
    NSDate			*latestDate = [NSDate distantPast];
    NSEnumerator	*dirEnum = [dirContent objectEnumerator];
    NSString		*dirEntry;

    while ( (dirEntry = [dirEnum nextObject]) ) {
        NSArray	*possibleVersions = [dirEntry findAllSubPatternMatchesWithPattern:[NSString stringWithFormat:@"\\.#%@\\.(.*)", currentFile] options:0]; // A verifier si le pattern est ok !

        if([possibleVersions count]){
            NSDictionary	*attributes = [[NSFileManager defaultManager] fileAttributesAtPath:[currentDir stringByAppendingPathComponent:dirEntry] traverseLink:YES];
            NSDate			*modDate = [attributes objectForKey:NSFileModificationDate];

            if([modDate compare:latestDate] == NSOrderedDescending){
                latestDate = modDate;
                latestVersion = [possibleVersions objectAtIndex:0];
            }
        }
    }
    return latestVersion;
}

- (NSString *) description
{
    return [[super description] stringByAppendingFormat:@"(%@)", [self path]];
}

- (BOOL) hasBeenRegisteredByRepository
// We cannot rely on isInRepository flag, because it is not up-to-date!
{
    ECTokenizedStatus	myTokenizedStatus = [self status].tokenizedStatus;

    // Files which have been locally added then locally removed disappear: they are no longer in CVS/Entries
#warning (Stephane) Does it work for directories?
    return (myTokenizedStatus != ECNotCVS && myTokenizedStatus != ECNotCVS && myTokenizedStatus != ECUnknown && myTokenizedStatus != ECIgnored && myTokenizedStatus != ECLocallyAdded && myTokenizedStatus != ECNoStatus);
}

- (BOOL) isBinary
// Returns YES if sticky options contain -kb
{
    // Shouldn't we assert that stickyOptions must have been already loaded?
    return ([[self stickyOptions] rangeOfString:@"-kb"].length > 0);
}

- (BOOL) isRealWrapper
// Returns YES if file is a directory which is considered as a single file by cvs
{
    // Shouldn't we assert that flags must have been already loaded?
    (void)[self flags];
    return (flags.isDir && flags.isWrapper);
}

- (BOOL) hasStickyTagOrDate
    /*" This method returns YES if this file has a sticky tag or a sticky date.
        Otherwise NO is returned.
    "*/
{    
    NSString *aStickyTag = nil;
    
    if ( [self stickyDate] != nil ) {
        return YES;
    }
    aStickyTag = [self stickyTag];
    if ( isNotEmpty(aStickyTag) ) {
            return YES;
    }
    return NO;
}

- (BOOL) isRealDirectory
// Returns YES if file is a directory which is NOT considered as a single file by cvs (i.e. not a wrapper)
{
    // Shouldn't we assert that flags must have been already loaded?
    (void)[self flags];
    return (flags.isDir && !flags.isWrapper);
}

- (BOOL) isDirectory
    // Returns YES if file is a directory without checking if it's a wrapper
{
    // Shouldn't we assert that flags must have been already loaded?
    (void)[self flags];
    return (flags.isDir);
}

- (BOOL) isAnEmptyDirectory
    /*" This method returns YES if this is an empty directory. An empty 
        directory is one that contains no other files or sub-directories with 
        the exception of CVS sub-directories, .DS_Store files and 
        sub-directories that are themselves empty according to this definition.
        Otherwise NO is returned.
    "*/
{
    CVLFile         *aCVLFile = nil;
    NSEnumerator    *dirContentsEnumerator = nil;
    NSFileManager	*fileManager = nil;
    NSString        *aPath = nil;
    NSString        *aChildPath = nil;
    NSString        *aFilename = nil;
    NSArray         *dirContents = nil;
    BOOL            dirIsEmpty = NO;
    
    if ( [self isRealDirectory] == YES ) {
        dirIsEmpty = YES;
        aPath = [self path];
        fileManager = [NSFileManager defaultManager];
        dirContents = [fileManager directoryContentsAtPath:aPath];
        if ( dirContents == nil ) {
            NSString *aMsg = nil;
            // An error occurred or the directory does not exists.
            dirIsEmpty = NO;
            aMsg = [NSString stringWithFormat:
                @"While trying to get the contents of the directory \"%@\", an error occurred or the directory does not exists.", 
                aPath];
            SEN_LOG(aMsg);
        } else if ( isNotEmpty(dirContents) ) {
            dirContentsEnumerator = [dirContents objectEnumerator];
            while ( (aFilename = [dirContentsEnumerator nextObject]) ) {
                // Ignore CVS directories.
                if ( [aFilename isEqualToString:@"CVS"] ) continue;
                // Ignore .DS_Store files.
                if ( [aFilename isEqualToString:@".DS_Store"] ) continue;
                // Ignore empty sub-directories.
                aChildPath = [aPath stringByAppendingPathComponent:aFilename];
                aCVLFile = (CVLFile *)[CVLFile treeAtPath:aChildPath];
                if ( [aCVLFile isRealDirectory] == YES ) {
                    if ( [aCVLFile isAnEmptyDirectory] == YES ) continue;
                }
                // Alas, this directory is not empty.
                dirIsEmpty = NO;
                break;
            }
        }                           
    }
    return dirIsEmpty;
}

- (NSString *) pathInRepository
	/*" This method returns the repository path of this file relative to the top
		of the repository.
	"*/
{
	NSString *theRootFilePrefix = nil;
	NSString *aPath = nil;
	unsigned int anIndex = 0;
	
	theRootFilePrefix = [[[self rootFile] path] stringByDeletingLastPathComponent];
	anIndex = [theRootFilePrefix length];
	anIndex++; // Also remove the slash so that this path is a relative path.
	aPath = [[self path] substringFromIndex:anIndex];
	
	ASSIGN(pathInRepository, aPath);
	
    return pathInRepository;    
}

- (CvsEditor *) cvsEditorForCurrentUser
    /*" This method returns the CvsEditor for this CVLFile for the currently
        logged-in user. If there is no CvsEditor for this CVLFile for this user 
        then nil is returned.
    "*/
{
    CvsEditor       *myCvsEditor = nil;
    CvsEditor       *aCvsEditor = nil;
    NSArray         *anArrayOfEditors = nil;
    NSString        *myUsername = nil;
    NSString        *aUsername = nil;
    NSEnumerator    *aCvsEditorEnumerator = nil;

    anArrayOfEditors = [self cvsEditors];
    if ( isNotEmpty(anArrayOfEditors) ) {
        myUsername = [[self repository] username];
        SEN_ASSERT_NOT_EMPTY(myUsername);
        aCvsEditorEnumerator = [anArrayOfEditors objectEnumerator];
        while ( (aCvsEditor = [aCvsEditorEnumerator nextObject]) ) {
            aUsername = [aCvsEditor username];
            if ( (isNotEmpty(aUsername)) &&
                 ([aUsername isEqualToString:myUsername]) ) {
                myCvsEditor = aCvsEditor;
                break;
            }
        }
    }    
    return myCvsEditor;
}

- (CvsWatcher *) cvsWatcherForCurrentUser
    /*" This method returns the CvsWatcher for this CVLFile for the currently
        logged-in user. If there is no CvsWatcher for this CVLFile for this user 
        then nil is returned. The CvsWatcher has to be a permanent one for this
        method to return it. Temporary CvsWatchers are ignored.
    "*/
{
    CvsWatcher      *myCvsWatcher = nil;
    CvsWatcher      *aCvsWatcher = nil;
    NSArray         *anArrayOfWatchers = nil;
    NSString        *myUsername = nil;
    NSString        *aUsername = nil;
    NSEnumerator    *aCvsWatcherEnumerator = nil;
    
    anArrayOfWatchers = [self cvsWatchers];
    if ( isNotEmpty(anArrayOfWatchers) ) {
        myUsername = [[self repository] username];
        SEN_ASSERT_NOT_EMPTY(myUsername);
        aCvsWatcherEnumerator = [anArrayOfWatchers objectEnumerator];
        while ( (aCvsWatcher = [aCvsWatcherEnumerator nextObject]) ) {
            aUsername = [aCvsWatcher username];
            if ( (isNotEmpty(aUsername)) &&
                 ([aUsername isEqualToString:myUsername]) &&
                 ([[aCvsWatcher isTemporary] boolValue] == NO) ) {
                myCvsWatcher = aCvsWatcher;
                break;
            }
        }
    }    
    return myCvsWatcher;
}

- (void) invalidateCvsWatchers
    /*" This method sets this CVLFiles CvsWatchers to nil and sets the 
        have.cvsWatchersFetchedFlag to NO. But only if not in the loading mode.

        See also #{-touch}
    "*/
{
    if(loading.cvsWatchersFetchedFlag){
        changes.cvsWatchersFetchedFlag = YES;
        [self touch];
    }
    else if(have.cvsWatchersFetchedFlag){
        [cvsWatchers release]; cvsWatchers = nil;
        have.cvsWatchersFetchedFlag = NO;
        changes.cvsWatchersFetchedFlag = YES;
        [self touch];
    }
}

- (void) getCvsWatchers
    /*" This method gets this CVLFiles CvsWatchers from the repository. As a 
        result of calling this method, the set method -setCvsWatchers: eventually
        gets called. However we do not know when the set will be called since
        if depends on another process.

        See also #{-getCvsWatchersForFile:} in ResultsRepository.
    "*/
{
    if( loading.cvsWatchersFetchedFlag == NO ){
        ECFileFlags fileFlags;

        fileFlags = [self flags];
        if(have.flags){
            if((fileFlags.type == ECLocalFile) || fileFlags.isIgnored || (fileFlags.isDir && !fileFlags.isWrapper)){
                have.cvsWatchersFetchedFlag = YES;
                loading.cvsWatchersFetchedFlag = NO;
                return;
            }
        }
        loading.cvsWatchersFetchedFlag = YES;
        [[ResultsRepository sharedResultsRepository] getCvsWatchersForFile:self];
    }
}

- (void) setCvsWatchers:(NSArray *)newWatchers
    /*" This is the set method for the instance variable cvsWatchers. It is
        usually called as an indirect result of calling the method 
        #{-getCvsWatchers:}.

        See also #{-getCvsWatchersForFile:} in ResultsRepository.
    "*/
{
    if(newWatchers != cvsWatchers && ![newWatchers isEqual:cvsWatchers]){
        [newWatchers retain];
        [cvsWatchers release];
        cvsWatchers = newWatchers;

        changes.cvsWatchersFetchedFlag = YES;
        [self touch];
    }
    have.cvsWatchersFetchedFlag = YES;
    loading.cvsWatchersFetchedFlag = NO;
}

- (NSArray *) cvsWatchers
    /*" This is the get method for the instance variable cvsWatchers.

        See also #{-getCvsWatchers} and #{-setCvsWatchers}.
    "*/
{
    // cvs does not support editors and watchers for wrapped directories;
    // so we just retrun nil in these cases.
    if ( [self isRealWrapper] ) return nil;
    
    if( have.cvsWatchersFetchedFlag == NO ){
        [self getCvsWatchers];
    }

    return cvsWatchers;
}

- (void) loadingCvsWatchers
    /*" This method sets the loading.cvsWatchersFetchedFlag to YES.
    "*/
{
    loading.cvsWatchersFetchedFlag = YES;
}

- (void) invalidateCvsEditors
    /*" This method sets this CVLFiles CvsEditors to nil and sets the 
        have.cvsEditorsFetchedFlag to NO. But only if not in the loading mode.

        See also #{-touch}
    "*/
{
    if(loading.cvsEditorsFetchedFlag){
        changes.cvsEditorsFetchedFlag = YES;
        [self touch];
    }
    else if(have.cvsEditorsFetchedFlag){
        [cvsEditors release]; cvsEditors = nil;
        have.cvsEditorsFetchedFlag = NO;
        changes.cvsEditorsFetchedFlag = YES;
        [self touch];
    }
}

- (void) getCvsEditors
    /*" This method gets this CVLFiles CvsEditors from the repository. As a 
        result of calling this method, the set method -setCvsEditors: eventually
        gets called. However we do not know when the set will be called since
        if depends on another process.

        See also #{-getCvsEditorsForFile:} in ResultsRepository.
    "*/
{
    if( loading.cvsEditorsFetchedFlag == NO ){
        ECFileFlags fileFlags;
        
        fileFlags = [self flags];
        if(have.flags){
            if((fileFlags.type == ECLocalFile) || fileFlags.isIgnored || (fileFlags.isDir && !fileFlags.isWrapper)){
                have.cvsEditorsFetchedFlag = YES;
                loading.cvsEditorsFetchedFlag = NO;
                return;
            }
        }
        loading.cvsEditorsFetchedFlag = YES;
        [[ResultsRepository sharedResultsRepository] getCvsEditorsForFile:self];
    }
}

- (void) setCvsEditors:(NSArray *)newCvsEditors;
    /*" This is the set method for the instance variable cvsEditors. It is
        usually called as an indirect result of calling the method 
        #{-getCvsEditors:}.

        See also #{-getCvsEditorsForFile:} in ResultsRepository.
    "*/
{
    if(newCvsEditors != cvsEditors && ![newCvsEditors isEqual:cvsEditors]){
        [newCvsEditors retain];
        [cvsEditors release];
        cvsEditors = newCvsEditors;
        
        changes.cvsEditorsFetchedFlag = YES;
        [self touch];
    }
    have.cvsEditorsFetchedFlag = YES;
    loading.cvsEditorsFetchedFlag = NO;
}

- (NSArray *) cvsEditors;
    /*" This is the get method for the instance variable cvsEditors.

        See also #{-getCvsEditors} and #{-setCvsEditors}.
    "*/
{
    // cvs does not support editors and watchers for wrapped directories;
    // so we just retrun nil in these cases.
    if ( [self isRealWrapper] ) return nil;
    
    if( have.cvsEditorsFetchedFlag == NO ){
            [self getCvsEditors];
    }
    
    return cvsEditors;
}

- (void) loadingCvsEditors
    /*" This method sets the loading.cvsEditorsFetchedFlag to YES.
    "*/
{
    loading.cvsEditorsFetchedFlag = YES;
}

- (NSArray *) siblings
    /*" This method returns an array of all CVLFiles that are in the same
        directory as self. However CVLFiles that are to be ignored are not 
        returned. If there are no siblings or only ignored siblings then nil is 
        returned.
    "*/
{
    NSArray *mySiblings = nil;
    NSMutableArray *mySiblingsNotIgnored = nil;
    NSEnumerator *mySiblingsEnumerator = nil;
    CVLFile *aSibling = nil;
    unsigned int aCount = 0;

    mySiblings = [super siblings];
    if ( isNotEmpty(mySiblings) ) {
        aCount = [mySiblings count];
        mySiblingsNotIgnored = [NSMutableArray arrayWithCapacity:aCount];
        mySiblingsEnumerator = [mySiblings objectEnumerator];
        while ( (aSibling = [mySiblingsEnumerator nextObject]) ) {
            if ( [aSibling isIgnored] == NO ) {
                [mySiblingsNotIgnored addObject:aSibling];
            }
        }
        if ( isNilOrEmpty(mySiblingsNotIgnored) ) {
            mySiblingsNotIgnored = nil;
        }
    }
    return mySiblingsNotIgnored;
}

- (BOOL) isIgnored
    /*" This method YES if this CVLFile is to ignored and NO otherwise. An
        example of an ignored file is a CVS directory.
    "*/
{
    ECFileFlags myflags = [self flags];
    
    if (myflags.isIgnored) return YES;
    return NO;
}

- (NSArray *) unrolled
    /*" This method returns an array of all CVLFiles that are children of self.
        Also children that also have children are also included in the returned
        array and so on. However CVLFiles that are to be ignored are not 
        included. Also wrapped directories are not unrolled. If there are no 
        children or only ignored children then nil is returned.
    "*/
{
    NSArray         *myChilden = nil;
    NSMutableArray  *myChildenUnrolled = nil;
    CVLFile         *aCVLFile = nil;
    NSArray         *aCVLFilesChilren = nil;
    NSEnumerator    *anEnumerator = nil;
    unsigned int    aCount = 0;
    
    myChilden = [self loadedChildren];
    if ( isNotEmpty(myChilden) ) {
        aCount = [myChilden count];
        myChildenUnrolled = [NSMutableArray arrayWithCapacity:aCount];
        anEnumerator = [myChilden objectEnumerator];
        while ( (aCVLFile = [anEnumerator nextObject]) ) {
            if ( ([aCVLFile isRealDirectory] == YES) &&
                 ([aCVLFile isIgnored] == NO) ) {
                aCVLFilesChilren = [aCVLFile unrolled];
                if ( isNotEmpty(aCVLFilesChilren)  ) {
                    [myChildenUnrolled addObjectsFromArray:aCVLFilesChilren];
                }
            } else if ( [aCVLFile isIgnored] == NO ) {
                [myChildenUnrolled addObject:aCVLFile];
            }
        }
        if ( isNilOrEmpty(myChildenUnrolled) ) {
            myChildenUnrolled = nil;
        }
    }
    return myChildenUnrolled;
}

- (CvsEntry *) cvsEntry
    /*" This is the get method for the cvsEntry instance variable.
        This allows the getting of information from the CVS/Entries file for
        this files entry by accessing this cvsEntry object.

        See also #{-setCvsEntry:}
    "*/
{
	return cvsEntry;
}

- (void) setCvsEntry:(CvsEntry *)newCvsEntry
    /*" This is the set method for the cvsEntry instance variable.

        See also #{-cvsEntry}
    "*/
{
    ASSIGN(cvsEntry, newCvsEntry);
}

- (void) runCvsEntriesConsistencyCheck:(NSArray *)someCvsEntries
    /*" This method runs one consistency check on the CVS Entries file contents.
        If this file is a directory then this method checks to see if it has an 
        entry in the CVS Entries file if any of its contents do. If it does not
        then an alert panel is displayed to the user warning of this 
        inconsistency.
    "*/
{
    CvsEntry *aCvsEntry = nil;
    CVLFile *theRootFile = nil;
    
    if ( hasRunCvsEntriesConsistencyCheck == YES ) return;
    hasRunCvsEntriesConsistencyCheck = YES;
    
    if ( isNilOrEmpty(someCvsEntries) ) return;
    
    theRootFile = [self rootFile];
    if ( self == theRootFile ) return;

    aCvsEntry = [self cvsEntry];
    if ( aCvsEntry == nil ) {
        NSEnumerator *aCvsEntriesEnumerator = nil;
        NSMutableArray *someFilenames = nil;
        NSString *aFilename = nil;
            
        someFilenames = [NSMutableArray arrayWithCapacity:[someCvsEntries count]];
        aCvsEntriesEnumerator = [someCvsEntries objectEnumerator];
        while ( (aCvsEntry = [aCvsEntriesEnumerator nextObject]) ) { 
            aFilename = [aCvsEntry filename];
            if ( isNotEmpty(aFilename) ) {
                [someFilenames addObject:aFilename];
            }
        }
        (void)NSRunAlertPanel(@"CVS Consistency Error!", 
                              @"The folder \"%@\" did not have an entry in the CVS/Entries file but some or all of its contents do. These contents are:\n%@\nThis should be fixed before proceeding!",
                              nil, nil, nil, [self path], someFilenames);    
    }
}

- (CVLFile *)rootFile
    /*" This is a helper method to fetch the root file from workarea viewer that
        is displaying this file. The root file is the file path to the workarea.
    "*/
{    
    if ( rootFile == nil ) {
        CVLDelegate *theAppDelegate = nil;
        WorkAreaViewer *theWorkAreaViewer = nil;

        theAppDelegate = [NSApp delegate];
        theWorkAreaViewer = [theAppDelegate viewerShowingFile:self];
        rootFile = [theWorkAreaViewer rootFile];
        [rootFile retain];
    }
    return rootFile;
}

- (BOOL)isRootFile
    /*" This method returns YES if this instance is the root file. The root file
        is the file path to the workarea.
    "*/
{
    if ( self == [self rootFile] ) {
        return YES;
    }
    return NO;
}

- (BOOL)isRealDirectoryAndHasDisappeared
    /*" This method returns YES if self is a real directory (i.e. a directory 
        that has not been wrapped) and has disappeared from the file system 
        while CVL was running and there is no longer an entry for it in its 
        parent's CVS/Entries file. Otherwise NO is returned. This condition 
        happens when the CVS update command with the "-P" option is run on a 
        directory that is empty.

        As a side effect this method also sets the status of this CVLFile to 
        ECUnknown. This makes the display of the directory in the CVL browser 
        changed from inconsistent to unknown which is usually not shown.
    "*/
{
    NSString *aPath= nil;
    NSFileManager *fileManager = nil;
    NSArray *childrenFromCvsEntries = nil;
        
    if ( [self isRealDirectory] == YES ) {
        fileManager = [NSFileManager defaultManager];
        aPath = [self path];
        if ( [fileManager senDirectoryExistsAtPath:aPath] == NO ) {
            if ( [self cvsEntry] != nil ) {
                // Do not ask the root file for its parent.
                if ( [self isRootFile] == NO ) {
                    // This next statement should not effect overall performance
                    // since it will be called only infrequently (i.e. only
                    // when a directory has been deleted from the workarea).
                    childrenFromCvsEntries = [[self parent] getChildrenFromCvsEntries];
                    if ( [childrenFromCvsEntries containsObject:self] == NO ) {
                        [self setCvsEntry:nil];
                    }                            
                }
            }
            if ( [self cvsEntry] == nil ) {
                [self setStatus:tokenizedStatus[ECUnknown]];
                [self invalidateAll];
                [[self parent] invalidateAll];
                return YES;
            }
        }
    }
    return NO;
}

- (BOOL) markedForRemoval
    /*" This method returns YES if this file has been removed locally from the
        workarea but has not been committed to the repository otherwise NO is 
        returned. This is a cover method for the method -markedForRemoval
        in the class CvsEntry. If the instance variable cvsEntry is nil then
        this method returns NO.
    
        This method means that this file
        has had the CVS remove command run on it. This is indicated
        in the CVS/entries file by having a minus sign preceeding the revision
        number. This file will need a CVS commit command run on it to actually
        change the repository and remove this entry from the CVS/entries file.
    
        If this is a directory then this means that all of the its contents 
        are marked for removal or ignored or the directory is empty. This method is 
        recursive; calling itself on the contents of each directory and 
        sub-directory.

        See also #{-markedForRemoval} in the class CvsEntry.
    "*/
{
    CvsEntry *aCvsEntry = nil;
    BOOL fileHasBeenMarked = NO;
    
    aCvsEntry = [self cvsEntry];
    if ( aCvsEntry != nil ) {
        fileHasBeenMarked = [aCvsEntry markedForRemoval];
    }                                
    // If we are a real directory then lets check our contents.
    if ( [self isRealDirectory] == YES ) {
        CVLFile *aCVLFile = nil;
        NSArray *myChildren = nil;
        NSEnumerator *aCVLFileEnumerator = nil;
        
        fileHasBeenMarked = YES;
        myChildren = [self loadedChildren];
        if ( isNotEmpty(myChildren) ) {
            aCVLFileEnumerator = [myChildren objectEnumerator];
            while ( (aCVLFile = [aCVLFileEnumerator nextObject]) ) { 
                if ( [aCVLFile isIgnored] ) {
                    continue;
                }
                if ( [aCVLFile markedForRemoval] == NO ) {
                    fileHasBeenMarked = NO;
                    break;
                }
            }
        }
    }    
    return fileHasBeenMarked;
}

- (BOOL) markedForAddition
    /*" This method returns YES if this file has been marked for additon to the
    workarea but has not been committed to the repository. Otherwise NO is 
    returned. This is a cover method for the method -markedForAddition
    in the class CvsEntry. If the instance variable cvsEntry is nil then
    this method returns NO.

    This method means that this file
    has had the CVS add command run on it. This is indicated
    in the CVS/entries file by having a zero for the the revision
    number. This file will need a CVS commit command run on it to actually
    change the repository and add this entry to the repository.

    If this is a directory then this means that all of the its contents 
    are marked for addition or ignored or the directory is empty. This method is 
    recursive; calling itself on the contents of each directory and 
    sub-directory.

    See also #{-markedForAddition} in the class CvsEntry.
    "*/
{
    CvsEntry *aCvsEntry = nil;
    BOOL fileHasBeenMarked = NO;
    
    aCvsEntry = [self cvsEntry];
    if ( aCvsEntry != nil ) {
        fileHasBeenMarked = [aCvsEntry markedForAddition];
    }                                
    // If we are a real directory then lets check our contents.
    if ( [self isRealDirectory] == YES ) {
        CVLFile *aCVLFile = nil;
        NSArray *myChildren = nil;
        NSEnumerator *aCVLFileEnumerator = nil;
        
        fileHasBeenMarked = YES;
        myChildren = [self loadedChildren];
        if ( isNotEmpty(myChildren) ) {
            aCVLFileEnumerator = [myChildren objectEnumerator];
            while ( (aCVLFile = [aCVLFileEnumerator nextObject]) ) { 
                if ( [aCVLFile isIgnored] ) {
                    continue;
                }
                if ( [aCVLFile markedForAddition] == NO ) {
                    fileHasBeenMarked = NO;
                    break;
                }
            }
        }
    }    
    return fileHasBeenMarked;
}

- (BOOL) canBeAdded
    /*" This is a helper method for validation of the menu item 
        "Add to Work Area...". 

        This method returns YES if this is a new file that can be added to CVS.
        This means that this file must not have an entry in the CVS/Entries 
        file. If this is a directory then this means that each of the its 
        contents can be added to CVS. This method is recursive; calling itself 
        on the contents of each directory and sub-directory.

        This method always returns YES if this file (or directory) is ignored.
        Also YES is returned if this file (or directory) has a status type of 
        ECUnknownType and a flag type of ECInactiveFile. These are empty folders
        that are in CVS but have had their contents removed.
    "*/
{    
    CvsEntry *aCvsEntry = nil;
    ECFileFlags fileFlags;
    
    // Ignore if this file is an ignored File. 
    // We return YES so that validation methods will not fail.
    if ( [self isIgnored] == YES ) {
        return YES;
    }
    
    // Ignore if this file is an Inactive File and
    // a status type of unknown. For example this
    // could be an empty folder whose files were removed. 
    // We return YES so that validation methods will not fail.
    fileFlags = [self flags];
    if ( (fileFlags.type == ECInactiveFile) && 
         ([self status].statusType == ECUnknownType) ) {
        return YES;
    }
    
    // Check if we have a CvsEntry.
    aCvsEntry = [self cvsEntry];
    if ( aCvsEntry != nil ) {                
        return NO;
    }
    // If we are a real directory then lets check our contents.
    if ( [self isRealDirectory] == YES ) {
        CVLFile *aCVLFile = nil;
        NSArray *myChildren = nil;
        NSEnumerator *aCVLFileEnumerator = nil;
        
        myChildren = [self loadedChildren];
        if ( isNotEmpty(myChildren) ) {
            aCVLFileEnumerator = [myChildren objectEnumerator];
            while ( (aCVLFile = [aCVLFileEnumerator nextObject]) ) { 
                if ( [aCVLFile canBeAdded] == NO ) {
                    return NO;
                }
            }
        }
    }
    return YES;
}

- (BOOL) canBeDeletedAndUpdated
    /*" This is a helper method for validation of the menu item 
        "Delete and Update...". 

        This method returns YES if this is a new file that can be deleted and 
        then updated to CVS. This means that this file
        must not be marked for removal. If this is a directory then this 
        means that each of the its contents can be deleted and then updated to 
        CVS. This method is recursive; calling itself on the contents of each 
        directory and sub-directory.
    
        This method always returns YES if this file (or directory) is ignored.
        Also YES is returned if this file (or directory) has a status type of 
        ECUnknownType and a flag type of ECInactiveFile. These are empty folders
        that are in CVS but have had their contents removed.

        Note: As of version 3.1.0 (22-Jan-2004) this method is no longer being 
        used.
    "*/
{
    ECFileFlags fileFlags;
    
    // Ignore if this file is an ignored File. 
    // We return YES so that validation methods will not fail.
    if ( [self isIgnored] == YES ) {
        return YES;
    }
    
    // Ignore if this file is an Inactive File and
    // a status type of unknown. For example this
    // could be an empty folder whose files were removed. 
    // We return YES so that validation methods will not fail.
    fileFlags = [self flags];
    if ( (fileFlags.type == ECInactiveFile) && 
         ([self status].statusType == ECUnknownType) ) {
        return YES;
    }
    
    // Check to see if this file is already marked for removal.
    if ( [self markedForRemoval] == YES ) {
        return NO;
    }
    
    // If we are a real directory then lets check our contents.
    if ( [self isRealDirectory] == YES ) {
        CVLFile *aCVLFile = nil;
        NSArray *myChildren = nil;
        NSEnumerator *aCVLFileEnumerator = nil;
        
        myChildren = [self loadedChildren];
        if ( isNotEmpty(myChildren) ) {
            aCVLFileEnumerator = [myChildren objectEnumerator];
            while ( (aCVLFile = [aCVLFileEnumerator nextObject]) ) { 
                if ( [aCVLFile canBeDeletedAndUpdated] == NO ) {
                    return NO;
                }
            }
        }
    }    
    return YES;        
}

- (BOOL) canBeMarkedForRemoval
    /*" This is a helper method for validation of the menu item 
        "Mark Files(s) for Removal...". 
    
        This method returns YES if this file is under CVS control, is not marked
        for removal already and is up-to-date or only needs update
        (i.e. have been removed in the file system). If this is a 
        directory then this means that each of the its contents can be marked 
        for removal. This method is recursive; calling itself on the contents of
        each directory and sub-directory.
    
        This method always returns YES if this file (or directory) is ignored.
        Also YES is returned if this file (or directory) has a status type of 
        ECUnknownType and a flag type of ECInactiveFile. These are empty folders
        that are in CVS but have had their contents removed.
    "*/
{
    CvsEntry *aCvsEntry = nil;
    ECFileFlags fileFlags;
        
    // Ignore if this file is an ignored File. 
    // We return YES so that validation methods will not fail.
    if ( [self isIgnored] == YES ) {
        return YES;
    }
    
    // Ignore if this file is an Inactive File and
    // a status type of unknown. For example this
    // could be an empty folder whose files were removed. 
    // We return YES so that validation methods will not fail.
    fileFlags = [self flags];
    if ( (fileFlags.type == ECInactiveFile) && 
         ([self status].statusType == ECUnknownType) ) {
        return YES;
    }
    
    // Check if we do not have a CvsEntry.
    aCvsEntry = [self cvsEntry];
    if ( aCvsEntry == nil ) {                
        return NO;
    }
    // Check to see if this file is already marked for removal.
    if ( [self markedForRemoval] == YES ) {
        return NO;
    }                            
    // Check to see if it is not up-to-date or needs update.
    if ( (([self status].statusType == ECUpToDateType) ||
         ([self status].statusType == ECNeedsUpdateType)) == NO ) {                
        return NO;
    }
    // If we are a real directory then lets check our contents.
    if ( [self isRealDirectory] == YES ) {
        CVLFile *aCVLFile = nil;
        NSArray *myChildren = nil;
        NSEnumerator *aCVLFileEnumerator = nil;
        
        myChildren = [self loadedChildren];
        if ( isNotEmpty(myChildren) ) {
            aCVLFileEnumerator = [myChildren objectEnumerator];
            while ( (aCVLFile = [aCVLFileEnumerator nextObject]) ) { 
                if ( [aCVLFile canBeMarkedForRemoval] == NO ) {
                    return NO;
                }
            }
        }
    }
    return YES;        
}

- (BOOL) canBeReinstatedAfterMarkedForRemoval
    /*" This is a helper method for validation of the menu item 
        "Reinstate File(s) Marked For Removal...". 
    
        This method returns YES if this file (not a directory) is under CVS 
        control and is marked for removal.  If this is a directory then this 
        means that at least one of the its contents is marked for removal. This 
        method is recursive; calling itself on the contents of each directory 
        and sub-directory.
    
        This method always returns NO if this file (or directory) is ignored.
        Also NO is returned if this file (or directory) has a status type of 
        ECUnknownType and a flag type of ECInactiveFile. These are empty folders
        that are in CVS but have had their contents removed.
    "*/
{
    CvsEntry *aCvsEntry = nil;
    ECFileFlags fileFlags;
    
    // Ignore if this file is an ignored File. 
    if ( [self isIgnored] == YES ) {
        return NO;
    }
    
    // Ignore if this file is an Inactive File and
    // a status type of unknown. For example this
    // could be an empty folder whose files were removed. 
    fileFlags = [self flags];
    if ( (fileFlags.type == ECInactiveFile) && 
         ([self status].statusType == ECUnknownType) ) {
        return NO;
    }
    
    // Check if we have a CvsEntry.
    aCvsEntry = [self cvsEntry];
    if ( aCvsEntry == nil ) {                
        return NO;
    }
    // Check to see if this file is not a directory and is marked for removal.
    if ( ([self isRealDirectory] == NO) && 
         ([self markedForRemoval] == YES) ) {
        return YES;
    }                            
    // If we are a real directory then lets check our contents.
    if ( [self isRealDirectory] == YES ) {
        CVLFile *aCVLFile = nil;
        NSArray *myChildren = nil;
        NSEnumerator *aCVLFileEnumerator = nil;
        
        myChildren = [self loadedChildren];
        if ( isNotEmpty(myChildren) ) {
            aCVLFileEnumerator = [myChildren objectEnumerator];
            while ( (aCVLFile = [aCVLFileEnumerator nextObject]) ) { 
                if ( [aCVLFile canBeReinstatedAfterMarkedForRemoval] == YES ) {
                    return YES;
                }
            }
        }
    }
    return NO;        
}

- (void) printFlags
    /*" This method prints this CVLFile's flags to standard output. This is a 
        method used in debugging.
    "*/
{
    NSLog(@"For %@",[self name]);
    NSLog(@"    flags.isDir = %d",flags.isDir);
    NSLog(@"    flags.isWrapper = %d",flags.isWrapper);
    NSLog(@"    flags.isInWorkArea = %d",flags.isInWorkArea);
    NSLog(@"    flags.isInCVSEntries = %d",flags.isInCVSEntries);
    NSLog(@"    flags.isInRepository = %d",flags.isInRepository);
    NSLog(@"    flags.isHidden = %d",flags.isHidden);
    NSLog(@"    flags.isIgnored = %d",flags.isIgnored);        
    if ( flags.type == ECCVSFile ) NSLog(@"    flags.type = ECCVSFile");
    else if ( flags.type == ECLocalFile ) NSLog(@"    flags.type = ECLocalFile");
    else if ( flags.type == ECAbsentFile ) NSLog(@"    flags.type = ECAbsentFile");
    else if ( flags.type == ECInactiveFile ) NSLog(@"    flags.type = ECInactiveFile");
    else if ( flags.type == ECInvalidFile ) NSLog(@"    flags.type = ECInvalidFile");
    else if ( flags.type == ECDirContainingLocalFiles ) NSLog(@"    flags.type = ECDirContainingLocalFiles");
    else if ( flags.type == ECNoFile ) NSLog(@"    flags.type = ECNoFile");
    else NSLog(@"    flags.type = %d", flags.type);
}

- (void) printStatus
    /*" This method prints this CVLFile's status to standard output. This is a 
        method used in debugging.
    "*/
{
    NSLog(@"For %@",[self name]);
    if ( status.statusType == ECNoType ) NSLog(@"    status.statusType = ECNoType");
    else if ( status.statusType == ECUpToDateType ) NSLog(@"    status.statusType = ECUpToDateType");
    else if ( status.statusType == ECLocallyModifiedType ) NSLog(@"    status.statusType = ECLocallyModifiedType");
    else if ( status.statusType == ECNeedsUpdateType ) NSLog(@"    status.statusType = ECNeedsUpdateType");
    else if ( status.statusType == ECNeedsMergeType ) NSLog(@"    status.statusType = ECNeedsMergeType");
    else if ( status.statusType == ECConflictType ) NSLog(@"    status.statusType = ECConflictType");
    else if ( status.statusType == ECNotCVSType ) NSLog(@"    status.statusType = ECNotCVSType");
    else if ( status.statusType == ECIgnoredType ) NSLog(@"    status.statusType = ECIgnoredType");
    else if ( status.statusType == ECUnknownType ) NSLog(@"    status.statusType = ECUnknownType");
    else NSLog(@"    status.statusType = %d",status.statusType);

    if ( status.tokenizedStatus == ECNoStatus ) NSLog(@"    status.tokenizedStatus = ECNoStatus");
    else if ( status.tokenizedStatus == ECUpToDate ) NSLog(@"    status.tokenizedStatus = ECUpToDate");
    else if ( status.tokenizedStatus == ECLocallyModified ) NSLog(@"    status.tokenizedStatus = ECLocallyModified");
    else if ( status.tokenizedStatus == ECLocallyAdded ) NSLog(@"    status.tokenizedStatus = ECLocallyAdded");
    else if ( status.tokenizedStatus == ECLocallyRemoved ) NSLog(@"    status.tokenizedStatus = ECLocallyRemoved");
    else if ( status.tokenizedStatus == ECNeedsPatch ) NSLog(@"    status.tokenizedStatus = ECNeedsPatch");
    else if ( status.tokenizedStatus == ECNeedsCheckout ) NSLog(@"    status.tokenizedStatus = ECNeedsCheckout");
    else if ( status.tokenizedStatus == ECNeedsMerge ) NSLog(@"    status.tokenizedStatus = ECNeedsMerge");
    else if ( status.tokenizedStatus == ECMixedStatus ) NSLog(@"    status.tokenizedStatus = ECMixedStatus");
    else if ( status.tokenizedStatus == ECConflict ) NSLog(@"    status.tokenizedStatus = ECConflict");
    else if ( status.tokenizedStatus == ECConflict2 ) NSLog(@"    status.tokenizedStatus = ECConflict2");
    else if ( status.tokenizedStatus == ECNotCVS ) NSLog(@"    status.tokenizedStatus = ECNotCVS");
    else if ( status.tokenizedStatus == ECContainsNonCVSFiles ) NSLog(@"    status.tokenizedStatus = ECContainsNonCVSFiles");
    else if ( status.tokenizedStatus == ECIgnored ) NSLog(@"    status.tokenizedStatus = ECIgnored");
    else if ( status.tokenizedStatus == ECUnknown ) NSLog(@"    status.tokenizedStatus = ECUnknown");
    else if ( status.tokenizedStatus == ECInvalidEntry ) NSLog(@"    status.tokenizedStatus = ECInvalidEntry");
    else  NSLog(@"    status.tokenizedStatus = %d",status.tokenizedStatus);

}

- (NSArray *)getChildrenFromCvsEntries
    /*" This method returns an array of CVLFiles caculated from the CVS/Entries 
        file in the workarea directory of this CVLFile. So these would be the 
        children of this CVLFile as far as the workarea is concerned. If there 
        is no CVS/Entries file or if it is empty then nil is returned.
    "*/
{
    NSArray	*cvsEntries = nil;
    NSString *aFilePath = nil;
    NSString *aStickyTag = nil;
    NSMutableArray *childrenFromCvsEntries = nil;
    CVLFile *aCVLFile = nil;
    CvsRepository *dirRepository = nil;
    unsigned int aCount = 0;
    ECFileFlags fileFlags;

    dirRepository = [self repository];
    if (have.repository && ([dirRepository isNullRepository] == NO)) {
        cvsEntries = [CvsEntry getCvsEntriesForDirectory:[self path]];
        
        if( isNotEmpty(cvsEntries) ) {
            NSEnumerator *aCvsEntriesEnumerator = nil;
            CvsEntry *aCvsEntry = nil;
            aCount = [cvsEntries count];
            
            childrenFromCvsEntries = [NSMutableArray arrayWithCapacity:aCount];
            
            [self runCvsEntriesConsistencyCheck:cvsEntries];
            
            aCvsEntriesEnumerator = [cvsEntries objectEnumerator];
            while ( (aCvsEntry = [aCvsEntriesEnumerator nextObject]) ) { 
                aFilePath = [aCvsEntry path];
                aCVLFile = (CVLFile *)[[self class] treeAtPath:aFilePath];
                [childrenFromCvsEntries addObject:aCVLFile];
                
                if(aCVLFile->have.flags)
                    fileFlags = [aCVLFile flags];
                else
                    fileFlags = defaultFileFlags;
                
                if(!fileFlags.isInWorkArea){
                    fileFlags.isDir = [[aCvsEntry isADirectory] boolValue];
                    fileFlags.isWrapper = ([dirRepository isWrapper:aFilePath]);
                    fileFlags.isIgnored = [dirRepository isIgnored:aFilePath];
                    fileFlags.isHidden = fileFlags.isIgnored;
                }
                fileFlags.isInCVSEntries = YES;
                // We don't know for now because we don't look in the repository from here
                fileFlags.isInRepository = fileFlags.isInCVSEntries;
                [aCVLFile _setFlags:fileFlags];
                
                [aCVLFile setRevisionInWorkArea:[aCvsEntry revisionInWorkArea]];
                [aCVLFile setDateOfLastCheckout:[aCvsEntry dateOfLastCheckout]];
                [aCVLFile setStickyOptions:[aCvsEntry stickyOptions]];
                
                aCVLFile->have.stickyDateOrTagFetched = YES;
                aStickyTag = [aCvsEntry stickyTag];
                [aCVLFile setStickyTag:aStickyTag];
                // If we have a non-empty stickyTag check to see if it is a
                // branch. If so continue. If not run a status on aCVLFile to
                // see if it is a branch since there is no way to tell if a Tag
                // is a branch or non-branch by looking at the CVS/Entries file
                // as they are all coded with a "T" indicating they are a branch.
                // CVS sucks big time!                
                if ( isNotEmpty(aStickyTag) ) {
                    if ( [aCVLFile isABranch] == NO ) {
                        // This next statement will put aCVLFile in a queue so
                        // that all the files needing a status request will be
                        // done in one request. This will be quicker that one at
                        // a time.
                        [[ResultsRepository sharedResultsRepository]
                             getStatusForFile:aCVLFile];
                    }
                }
                // Done with setting a sticky tag.
                                
                [aCVLFile setStickyDate:[aCvsEntry stickyDate]];
                [aCVLFile setCvsEntry:aCvsEntry];
            }
        }        
    }
    return childrenFromCvsEntries;
}

- (BOOL) hasStickyAttributes
    /*" This method returns YES if this workarea file has sticky 
        attributes; otherwise NO is returned.
    "*/
{
    if ( ( [self hasStickyTagOrDate] == YES ) ||
         isNotEmpty([self stickyOptions]) ) {
        return YES;
    }
    return NO;
}

- (BOOL) isABranch
    /*" This method returns YES if this workarea file is tagged with a branch 
    tag otherwise NO is returned. NO is also returned if this file is not 
    tagged at all.
    "*/
{    
    NSString *aStickyTag = nil;
    
    aStickyTag = [self stickyTag];
    if ( isNotEmpty(aStickyTag) ) {
        if ( [aStickyTag rangeOfString:@"branch:"].length > 0 ) {
            return YES;
        }
        // We are assuming that whenever the phrase "MISSING from RCS file!"
        // appears in a tag that the tag is a branch otherwise how can it happen.
        // This would be a file that has been added but not committed. But you
        // cannot add a file that is not on a branch or on the head. Hence this
        // phrase should not appear when the file is a revision tag.
        if ( [aStickyTag rangeOfString:@"MISSING from RCS file!"].length > 0 ) {
            return YES;
        }
    }
    return NO;
}

@end
