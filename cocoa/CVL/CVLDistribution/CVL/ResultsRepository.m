
// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "ResultsRepository.h"
#import <CvsRequest.h>
#import <CvsRepository.h>
#import <CvsStatusRequest.h>
#import <CvsLogRequest.h>
#import <CvsDiffRequest.h>
#import <CvsVerboseStatusRequest.h>
#import <CvsVerboseStatusRequestForWorkArea.h>
#import <CvsQuickStatusRequest.h>
#import <CvsTag.h>
#import <CvsEditor.h>
#import <CvsEditorsRequest.h>
#import <CvsWatchersRequest.h>
#import <CVLWaitController.h>
#import "CVLFile.h"
#import "NSArray.SenCategorize.h"
#import "NSArray.SenUtilities.h"
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <SenFoundation/SenFoundation.h>

static ResultsRepository *resultsRepository = nil;

@interface ResultsRepository (private)
- (void)cmdEnded:(NSNotification *)notification;
- (void)getShowRepositoryFiles:(NSNotification *)notification;
@end

@implementation ResultsRepository
+ (ResultsRepository *)sharedResultsRepository;
    /*" This method returns the unique shared ResultsRepository.
        There is only one instance of this controller and it is shared.
    "*/
{
  if ( resultsRepository == nil ) {
    return resultsRepository=[[self alloc] init];
  }
    return resultsRepository;
}

- init
{
  if ( (self=[super init]) ) {
    changedFiles=[[NSMutableSet alloc] init];
    statusQueue=[[NSMutableArray alloc] init];
    quickStatusQueue=[[NSMutableArray alloc] init];
    logQueue= [[NSMutableArray alloc] init];
    logRequests=[[NSMutableArray alloc] init];
    tagsQueue= [[NSMutableArray alloc] init];
    tagsRequests= [[NSMutableArray alloc] init];
    workAreaTagsCache = [[NSMutableDictionary alloc] init];
    quickStatusTargetPaths = [[NSMutableSet alloc] init];
    [[NSNotificationCenter defaultCenter]
                  addObserver:self
                     selector:@selector(cmdEnded:)
                         name:@"RequestCompleted"
                       object:nil];

//    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(getShowRepositoryFiles:) name:@"PreferencesChanged" object:nil];
//    [self getShowRepositoryFiles:nil];
  }
  return self;
}

/*
- (void)getShowRepositoryFiles:(NSNotification *)notification
{
    BOOL oldShowRepositoryFiles=showRepositoryFiles;
    showRepositoryFiles=[[NSUserDefaults standardUserDefaults] boolForKey:@"ShowRepositoryFiles"];

    if (oldShowRepositoryFiles!=showRepositoryFiles) {
        [self invalidateResultsForDirWithPath:@"" andKey:@"dir" recursively:YES];
    }
} */

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter]
                removeObserver:self];
  [changedFiles release];
  [statusQueue release];
  [quickStatusQueue release];
  [logQueue release];
  [logRequests release];
  [tagsQueue release];
  [tagsRequests release];
  [quickStatusTargetPaths release];
  [super dealloc];
}

- (void)setStatusesFromDictionary:(NSDictionary *)aDictionary
    /*" This method will set the status of each CVLFile whose path is a key in 
        aDictionary and whose value in aDictionary is a dictionary of status 
        information. This dictionary was the result of a CvsStatusRequest on the
        files selected in the CVL browser. The dictionary of status information 
        has values for the following keys. Some key/values may not be present.
        _{StatusKey             mandatory}
        _{VersionKey            mandatory}
        _{RepositoryVersionKey	optional}
        _{RepositoryPathKey     optional}
        _{LastCheckoutKey       optional}
        _{StickyTagKey          optional}
        _{StickyDateKey         optional}
        _{StickyOptionsKey		optional}
    "*/
{
  id enumerator;
  NSString *path;
  CVLFile *aCVLFile;

  enumerator=[aDictionary keyEnumerator];
  [self startUpdate];
  while ( (path=[enumerator nextObject]) ) {
      aCVLFile=(CVLFile *)[CVLFile treeAtPath:path];
      [aCVLFile setStatusFromDictionary:[aDictionary objectForKey:path]];
  }
  [self endUpdate];
}

- (void)setQuickStatusesFromDictionary:(NSDictionary *)aDictionary successful:(BOOL)wasSuccessful parentPath:(NSString *)parentPath
{
    NSArray         *sortedKeys = nil;
    NSSet           *pathsToEnumerateOver = nil;
    NSEnumerator	*anEnumerator = nil;
    NSString		*path = nil;

    [self startUpdate];
    // Lets sort these keys so that when we are debugging it is earier to read.
    sortedKeys = [[aDictionary allKeys] sortedArrayUsingSelector:@selector(compare:)];
    anEnumerator = [sortedKeys objectEnumerator];
    while ( (path = [anEnumerator nextObject]) ) {
        CVLFile	*file = [CVLFile treeAtPath:path];

        [file setQuickStatusWithString:[aDictionary objectForKey:path]];
        [quickStatusTargetPaths removeObject:path];
    }
    // All other files are up-to-date (except ignored ones and files whose parent is unknown by cvs)!!!
    // We need to inform these files, because there status is currently set to loading.status = YES!
    // WARNING: it may happen that quickStatus is not finished and returns prematurately with an error
    // In this case, we need to perform a FULL STATUS on the remaining files!
    // SECOND WARNING: if two or more quickStatus are performed at the same time,
    // there is a concurrency problem: we may not remove files which are not children of the qs directory.
    pathsToEnumerateOver = [NSSet setWithSet:quickStatusTargetPaths];
    anEnumerator = [pathsToEnumerateOver objectEnumerator];
    while ( (path = [anEnumerator nextObject]) ) {
        if([path hasPrefix:parentPath]){
            CVLFile	*file = [CVLFile treeAtPath:path];

            if(!wasSuccessful){
                [file setQuickStatusWithString:@"!"];
            } else if ([(CVLFile *)[file parent] status].tokenizedStatus == ECContainsNonCVSFiles) {
                [file setQuickStatusWithString:@"?"];
            } else {
                [file setQuickStatusWithString:@"="];
            }
            [quickStatusTargetPaths removeObject:path];
        }
    }
    [self endUpdate];
//    [quickStatusTargetPaths removeAllObjects];
}

- (void)setLogsFromDictionary:(NSDictionary *)aDictionary
{
  id enumerator;
  NSString *path;
  CVLFile *file;

  enumerator=[aDictionary keyEnumerator];
  [self startUpdate];
  while ( (path=[enumerator nextObject]) ) {
      file=(CVLFile *)[CVLFile treeAtPath:path];
      [file setLog:[[aDictionary objectForKey:path] objectForKey:@"log"]];
  }
  [self endUpdate];
}

- (void)setDifferencesFromDictionary:(NSDictionary *)aDictionary
{
  id enumerator;
  NSString *path;
  CVLFile *file;

  enumerator=[aDictionary keyEnumerator];
  [self startUpdate];
  while ( (path=[enumerator nextObject]) ) {
      file=(CVLFile *)[CVLFile treeAtPath:path];
      [file setDifferences:[[aDictionary objectForKey:path] objectForKey:@"diff"]];
  }
  [self endUpdate];
}


- (void)setTagsFromDictionary:(NSDictionary *)aDictionary
{
  id enumerator;
  NSString *path;
  CVLFile *file;

  enumerator=[aDictionary keyEnumerator];
  [self startUpdate];
  while ( (path=[enumerator nextObject]) ) {
      file=(CVLFile *)[CVLFile treeAtPath:path];
      [file setTags:[[aDictionary objectForKey:path] objectForKey:@"TagsKey"]];
  }
  [self endUpdate];
}

- (void)fileDidChange:(CVLFile *)file
{
    [self startUpdate];
    [changedFiles addObject:file];
    [self endUpdate];
}

- (void)startUpdate
{
    updateCount++;
}

- (void)endUpdate
{
    if (updateCount==1) {
        NSMutableSet *allChangedFiles=[[NSMutableSet alloc] init];
        NSMutableSet	*aSet;
        while ([changedFiles count]) {            
            [changedFiles makeObjectsPerformSelector:@selector(cumulateChanges)];
            [allChangedFiles unionSet:changedFiles];
            aSet = oldChangedFiles;
            oldChangedFiles=changedFiles;
            [aSet release];
            changedFiles=[[NSMutableSet alloc] init];
            aSet = [oldChangedFiles copy];
            [aSet makeObjectsPerformSelector:@selector(propagateChanges)];
            [aSet release];
        }
        aSet = oldChangedFiles;
        oldChangedFiles=[allChangedFiles copy];
        [aSet release];
        [[NSNotificationCenter defaultCenter]
                                postNotificationName:@"ResultsChanged"
                                              object:self];
        [allChangedFiles makeObjectsPerformSelector:@selector(clearChanges)];
        aSet = oldChangedFiles;
        oldChangedFiles=nil;
        [allChangedFiles release];
        [aSet release];
    }

  updateCount--;
}

- (BOOL)hasChanged
{
    return ([oldChangedFiles count]>0);
}

-(void)runStatus:(id)sender
{
  NSDictionary *sortedRequests;
  id dirsEnumerator;
  NSString *dir;
  CvsStatusRequest *request;
  id pathEnumerator;
  NSString *path;
  NSMutableArray *files;

  performStatusPending=NO;
  sortedRequests=[statusQueue categorizeUsingMethod:@selector(stringByDeletingLastPathComponent)];
  [statusQueue removeAllObjects];

  dirsEnumerator=[sortedRequests keyEnumerator];
  [self startUpdate];
  while ( (dir=[dirsEnumerator nextObject]) ) {
        files=[NSMutableArray array];
        pathEnumerator=[[sortedRequests objectForKey:dir] objectEnumerator];

        while ( (path=[pathEnumerator nextObject]) ) {
            [files addObject:[path lastPathComponent]];
        }
        request=[CvsStatusRequest cvsStatusRequestForFiles:files inPath:dir];
        [request setIsQuiet:YES];
        [request schedule];
  }
  [self endUpdate];
}

- (void) runQuickStatus:(id)sender
{
    NSEnumerator	*dirsEnumerator;
    NSString		*dir;

    performQuickStatusPending = NO;

    [self startUpdate];

    dirsEnumerator = [quickStatusQueue objectEnumerator];
    while ( (dir = [dirsEnumerator nextObject]) ) {
        [[CvsQuickStatusRequest cvsQuickStatusRequestFromPath:dir] schedule];
    }

    [quickStatusQueue removeAllObjects];
    [self endUpdate];
}


-(void)runLog:(id)sender
{
  NSDictionary *sortedRequests;
  id dirsEnumerator;
  NSString *dir;
  CvsLogRequest *request;
  id pathEnumerator;
  NSString *path;
  NSMutableArray *files;

  performLogPending=NO;
  sortedRequests=[logQueue categorizeUsingMethod:@selector(stringByDeletingLastPathComponent)];
  [logQueue removeAllObjects];

  dirsEnumerator=[sortedRequests keyEnumerator];
  [self startUpdate];
  while ( (dir=[dirsEnumerator nextObject]) ) {
    if (![logRequests containsObject:dir]) {
        [logRequests addObject:dir];
        files=[NSMutableArray array];
        pathEnumerator=[[sortedRequests objectForKey:dir] objectEnumerator];

        while ( (path=[pathEnumerator nextObject]) ) {
            [files addObject:[path lastPathComponent]];
        }
        request=[CvsLogRequest cvsLogRequestForFiles:files inPath:dir];
        [request setIsQuiet:YES];
        [request schedule];
    }
  }
  [self endUpdate];
}


-(void)runTags:(id)sender
{
  NSDictionary *sortedRequests;
  id dirsEnumerator;
  NSString *dir;
  CvsVerboseStatusRequest *request;
  id pathEnumerator;
  NSString *path;
  NSMutableArray *files;

  isGettingTagsForFiles = NO;
  
  performTagsPending=NO;
  sortedRequests=[tagsQueue categorizeUsingMethod:@selector(stringByDeletingLastPathComponent)];
  [tagsQueue removeAllObjects];

  dirsEnumerator=[sortedRequests keyEnumerator];
  [self startUpdate];
  while ( (dir=[dirsEnumerator nextObject]) ) {
    if (![tagsRequests containsObject:dir]) {
        [tagsRequests addObject:dir];
        files=[NSMutableArray array];
        pathEnumerator=[[sortedRequests objectForKey:dir] objectEnumerator];

        while ( (path=[pathEnumerator nextObject]) ) {
            [files addObject:[path lastPathComponent]];
        }
        request=[CvsVerboseStatusRequest cvsVerboseStatusRequestForFiles:files inPath:dir];
        [request setIsQuiet:YES];
        [request schedule];
    }
  }
  [self endUpdate];
}

- (void)cmdEnded:(NSNotification *)notification
{
    if ([[notification object] isKindOfClass: [CvsRequest class]])
    {
        CvsRequest *request=[notification object];
        NSString *path=[request path];

        switch([request cmdTag]){
            case CVS_STATUS_CMD_TAG:
                [self setStatusesFromDictionary:[(CvsStatusRequest *)request result]];
                break;
            case CVS_LOG_CMD_TAG:
                if ([logRequests containsObject:path]) {
                    [logRequests removeObject:path];
                }
                [self setLogsFromDictionary:[(CvsLogRequest *)request result]];
                break;
            case CVS_DIFF_CMD_TAG:
                [self setDifferencesFromDictionary:[(CvsDiffRequest *)request result]];
                break;
            case CVS_GET_TAGS_CMD_TAG:
                if ( isGettingTagsForFiles == YES) {
                    [self turnOnSwitchObjectForFileTagsReceived];
                } else {
                    if ([tagsRequests containsObject:path]) {
                        [tagsRequests removeObject:path];
                    }
                    [self setTagsFromDictionary:[(CvsVerboseStatusRequest *)request result]];                    
                }
                break;
            case CVS_GET_ALL_TAGS_CMD_TAG:
                [self turnOnSwitchObjectForWorkAreaTagsReceived];
                break;
            case CVS_QUICK_STATUS_CMD_TAG:
            {
                NSDictionary *aCvsRequestResult = nil;
                NSString *aPath = nil;
                BOOL requestWasAborted = NO;
                
                requestWasAborted = [(CvsQuickStatusRequest *)request updateAborted];
                aCvsRequestResult = [(CvsQuickStatusRequest *)request result];
                aPath = [request path];
                [self setQuickStatusesFromDictionary:aCvsRequestResult 
                                          successful:!requestWasAborted 
                                          parentPath:aPath];
                break;
            }
            case CVS_EDITORS_CMD_TAG:
                [self setCvsEditorsFromDictionary:[(CvsEditorsRequest *)request result]];
                break;
            case CVS_WATCHERS_CMD_TAG:
                [self setCvsWatchersFromDictionary:[(CvsWatchersRequest *)request result]];
                break;                
        }
    }
}

- (void)getStatusForFile:(CVLFile *)file
{
    NSString *path=[file path];
    
    if (![statusQueue containsObject:path]) {
        [statusQueue addObject:path];
        if (!performStatusPending) {
            performStatusPending=YES;
            [[NSRunLoop currentRunLoop] performSelector:@selector(runStatus:)
                                                 target:self
                                               argument:nil
                                                  order:0
                                                  modes:[NSArray arrayWithObjects:NSDefaultRunLoopMode/*, NSModalPanelRunLoopMode*/, nil]];
        }
    }
}

- (void) getQuickStatusForFile:(CVLFile *)file
{
    NSString	*path = [file path];

    if(![statusQueue containsObject:path]){
        NSEnumerator	*anEnum = [[NSArray arrayWithArray:quickStatusQueue] objectEnumerator];
        NSString		*aDir, *pathDir;

//        if(!performQuickStatusPending)
//            [quickStatusTargetPaths removeAllObjects];
        
        path = [path stringByStandardizingPath];
        pathDir = [path stringByDeletingLastPathComponent];
		pathDir = [pathDir stringByAppendingString:@"/"];
        [quickStatusTargetPaths addObject:path];
        while ( (aDir = [anEnum nextObject]) ) {
            // We are now sure that all dirs have a / suffix!
            if([path hasPrefix:aDir])
                return;
            else if([aDir hasPrefix:pathDir])
                [quickStatusQueue removeObject:aDir]; // Isn't it dangerous? If someone's observer of the request... Not dangerous, as we create the requests, and nobody else than self if observer of the request.            
        }
        [quickStatusQueue addObject:pathDir];
        if(!performQuickStatusPending){
            performQuickStatusPending = YES;
            [[NSRunLoop currentRunLoop] performSelector:@selector(runQuickStatus:) target:self argument:nil order:0 modes:[NSArray arrayWithObjects:NSDefaultRunLoopMode/*, NSModalPanelRunLoopMode*/, nil]];
        }
    }
}

- (void)getLogForFile:(CVLFile *)file
{
    NSString *path=[file path];
    if (![logQueue containsObject:path]) {
        [logQueue addObject:path];
        if (!performLogPending) {
            performLogPending=YES;
            [[NSRunLoop currentRunLoop] performSelector:@selector(runLog:)
                                                 target:self
                                               argument:nil
                                                  order:0
                                                  modes:[NSArray arrayWithObjects:NSDefaultRunLoopMode/*, NSModalPanelRunLoopMode*/, nil]];
        }
    }
}

- (void)getDifferencesForFile:(CVLFile *)file context:(CVLDiffOutputFormat)context outputFormat:(CVLDiffOutputFormat)outputFormat
{
    NSString *path=[file path];
    NSString *currentDir= [path stringByDeletingLastPathComponent];
    NSArray *someFiles= [NSArray arrayWithObject: [path lastPathComponent]];
    CvsDiffRequest *request= [CvsDiffRequest cvsDiffRequestAtPath: currentDir files: someFiles context:context outputFormat:outputFormat];

    [request setIsQuiet:YES];
    [request schedule];
}


- (void)getTagsForFile:(CVLFile *)file
{
    NSString *path=[file path];
    if (![tagsQueue containsObject:path]) {
        [tagsQueue addObject:path];
        if (!performTagsPending) {
            performTagsPending=YES;
            [[NSRunLoop currentRunLoop] performSelector:@selector(runTags:)
                                                 target:self
                                               argument:nil
                                                  order:0
                                                  modes:[NSArray arrayWithObjects:NSDefaultRunLoopMode/*, NSModalPanelRunLoopMode*/, nil]];
        }
    }
}

- (void) getCvsEditorsForFile:(CVLFile *)aCVLFile
    /*" This method gets all the CVS editors for file in the repository 
        represented by aCVLFile. In addition, to improve performance the 
        repository is asked for the CVS editors of all of this files siblings.
        Siblings are all the files in the same directory as this one.
        This is assuming that aCVLFile is not a directory in which case the
        directory is used in the request and not any of its siblings.
    
        See the method #{-setCvsEditorsFromDictionary:} for information on where
        the results of this method are applied.
    "*/
{
    NSString *path=[aCVLFile path];
    NSString *currentDir = nil;
    NSArray *someCVLFiles;
    NSMutableArray *someFiles = nil;
    CvsEditorsRequest *request;
    NSEnumerator *someCVLFilesEnumerator = nil;
    CVLFile *aSiblingCVLFile = nil;
    NSString *aSiblingFilename = nil;
    unsigned int aCount = 0;
    
    if([aCVLFile isRealDirectory]){
        currentDir = path;
        someFiles = nil;
    } else {
        currentDir = [path stringByDeletingLastPathComponent];
        someCVLFiles = [aCVLFile siblings];
        if (isNotEmpty(someCVLFiles) ) {
            aCount = [someCVLFiles count];
            someFiles = [NSMutableArray arrayWithCapacity:aCount];
            someCVLFilesEnumerator = [someCVLFiles objectEnumerator];
            while ( (aSiblingCVLFile = [someCVLFilesEnumerator nextObject]) ) {
                if ( [aSiblingCVLFile isRealWrapper] == NO ) {
                    if ( [aSiblingCVLFile isLeaf] == YES ) {
                        [aSiblingCVLFile loadingCvsEditors];
                        aSiblingFilename = [[aSiblingCVLFile path] lastPathComponent];
                        [someFiles addObject:aSiblingFilename];
                    }
                }
            }
        }
    }
    request= [CvsEditorsRequest editorsRequestForFiles:someFiles inPath:currentDir];
    [request setIsQuiet:YES];
    [request schedule];
}

- (void) getCvsWatchersForFile:(CVLFile *)aCVLFile
    /*" This method gets all the CVS watchers for file in the repository 
        represented by aCVLFile. In addition, to improve performance the 
        repository is asked for the CVS watchers of all of this files siblings.
        Siblings are all the files in the same directory as this one.
        This is assuming that aCVLFile is not a directory in which case the
        directory is used in the request and not any of its siblings.
    
        See the method #{-setCvsWatchersFromDictionary:} for information on where
        the results of this method are applied.
    "*/
{
    NSString *path=[aCVLFile path];
    NSString *currentDir = nil;
    NSArray *someCVLFiles;
    NSMutableArray *someFiles = nil;
    CvsWatchersRequest *request;
    NSEnumerator *someCVLFilesEnumerator = nil;
    CVLFile *aSiblingCVLFile = nil;
    NSString *aSiblingFilename = nil;
    unsigned int aCount = 0;
        
    if([aCVLFile isRealDirectory]){
        currentDir = path;
        someFiles = nil;
    } else {        
        currentDir = [path stringByDeletingLastPathComponent];
        someCVLFiles = [aCVLFile siblings];
        if (isNotEmpty(someCVLFiles) ) {
            aCount = [someCVLFiles count];
            someFiles = [NSMutableArray arrayWithCapacity:aCount];
            someCVLFilesEnumerator = [someCVLFiles objectEnumerator];
            while ( (aSiblingCVLFile = [someCVLFilesEnumerator nextObject]) ) {
                if ( [aSiblingCVLFile isRealWrapper] == NO ) {
                    if ( [aSiblingCVLFile isLeaf] == YES ) {
                        [aSiblingCVLFile loadingCvsWatchers];
                        aSiblingFilename = [[aSiblingCVLFile path] lastPathComponent];
                        [someFiles addObject:aSiblingFilename];
                    }
                }
            }
        }        
    }
    
    request= [CvsWatchersRequest watchersRequestForFiles:someFiles inPath:currentDir];
    [request setIsQuiet:YES];
    [request schedule];
}

- (void)setCvsEditorsFromDictionary:(NSDictionary *)aDictionary
    /*" This method sets the CVS editors in CVLFiles from the information in 
        aDictionary. The information in aDictionary may include CVS editors
        data for more than one CVLFile.
    
        See the method #{-parseCvsEditorsFromString:} in #CvsEditorsRequest
        for information on the structure of aDictionary.
    
        Also see #{-setCvsEditors:} in #CVLFile.
    "*/
{
    NSEnumerator    *anEnumerator;
    NSString        *path = nil;
    CVLFile         *aCVLFile = nil;
    NSArray         *anArrayOfEditors = nil;
    
    anEnumerator = [aDictionary keyEnumerator];
    [self startUpdate];
    while ( (path = [anEnumerator nextObject]) ) {
        aCVLFile = (CVLFile *)[CVLFile treeAtPath:path];
        anArrayOfEditors = [aDictionary objectForKey:path];
        if ( isNotEmpty(anArrayOfEditors) ) {
            [aCVLFile setCvsEditors:anArrayOfEditors];
        } else {
            [aCVLFile setCvsEditors:nil];
        }
    }
    [self endUpdate];
}

- (void)setCvsWatchersFromDictionary:(NSDictionary *)aDictionary
    /*" This method sets the CVS watchers in CVLFiles from the information in 
        aDictionary. The information in aDictionary may include CVS watchers
        data for more than one CVLFile.

        See the method #{-parseCvsWatchersFromString:} in #CvsWatchersRequest
        for information on the structure of aDictionary.

        Also see #{-setCvsWatchers:} in #CVLFile.
    "*/
{
    NSEnumerator    *anEnumerator;
    NSString        *path = nil;
    CVLFile         *aCVLFile = nil;
    NSArray         *anArrayOfWatchers = nil;
    NSString        *aUsername = nil;
    
    anEnumerator = [aDictionary keyEnumerator];
    [self startUpdate];
    while ( (path = [anEnumerator nextObject]) ) {
        aCVLFile = (CVLFile *)[CVLFile treeAtPath:path];
        anArrayOfWatchers = [aDictionary objectForKey:path];
        if ( isNotEmpty(anArrayOfWatchers) ) {
            aUsername = [[aCVLFile repository] username];
            SEN_ASSERT_NOT_EMPTY(aUsername);
            [aCVLFile setCvsWatchers:anArrayOfWatchers];
        } else {
            [aCVLFile setCvsWatchers:nil];
        }
    }
    [self endUpdate];
}


/********************************************************************/
/* Lazy methods */

/*
- (NSString *)obtainRepositoryPath:(NSString *)fullPath andKey:(NSString *)key
{
  NSString *path;

  if (!fullPath) {
    [[[NSException alloc] init] raise];
  }
  path=[[[NSString alloc] initWithContentsOfFile:[[fullPath stringByAppendingPathComponent:@"CVS"] stringByAppendingPathComponent:@"Repository"]] autorelease];

  path=[path substringToIndex:[path length]-1];

  if (!path) {
    if ([fullPath length] > 0) {
      if (path=[self repositoryPathForPath:[fullPath stringByDeletingLastPathComponent]]) {
        path=[path stringByAppendingPathComponent:[fullPath lastPathComponent]];
      } else {
        path=@"";
      }
    } else {
      path= @"";
    }
  }

  [self startUpdate];
  [self setResult:path forPath:fullPath andKey:key];
  [self endUpdate];

  return path;
} */

/*
- (NSObject *)obtainMTimeForPath:(NSString *)path andKey:(NSString *)key
{
  NSDictionary* attributes= [[NSFileManager defaultManager] fileAttributesAtPath: path traverseLink: NO];
  NSDate* mDate= [attributes objectForKey: NSFileModificationDate];
  if (mDate)
  {
    [self setResult: [mDate dateWithCalendarFormat: nil timeZone: nil] forPath:path andKey:@"mod Time"];
  }

  return mDate;
} // obtainIsLeafAndMTimeForPath:andKey:
*/

- (NSSet *)changedFiles
{
    return oldChangedFiles;
}

- (CvsVerboseStatusRequest *)fetchTagsForFiles:(NSArray *)someFiles inDirectory:(NSString *)aPath
    /*" This method fetchs all the tags in the repository represented by 
    the files in the somefiles array. Thes files are all assumed to be in 
    the directory given by aPath. It does this by making a request using the 
    CvsVerboseStatusRequest class. The tags are not returned from 
    this method but the request is returned instead. When this request is 
    finished the switch switchObjectForFileTagsReceived is turned on. 
    This switch then tells the CVLWaitController to end its wait which then 
    sends out a CVLWaitConditionMetNotification which then tells us the tags
    are available.
    "*/
{
    CvsVerboseStatusRequest *aRequest = nil;
    
    if ( isNotEmpty(someFiles) && isNotEmpty(aPath) ) {
        isGettingTagsForFiles = YES;
        aRequest=[CvsVerboseStatusRequest 
                        cvsVerboseStatusRequestForFiles:someFiles inPath:aPath];
        [aRequest setIsQuiet:YES];
        [aRequest schedule];        
    }
    return aRequest;
}

- (CvsVerboseStatusRequestForWorkArea *)fetchTagsForWorkArea:(NSString *)aWorkAreaPath
    /*" This method fetchs all the tags in the repository represented by 
    the current workarea. It does this by making a request using the 
    CvsVerboseStatusRequestForWorkArea class. The tags are not returned from 
    this method but the request is returned instead. When this request is 
    finished the switch switchObjectForWorkAreaTagsReceived is turned on. 
    This switch then tells the CVLWaitController to end its wait which then 
    sends out a CVLWaitConditionMetNotification which then tells us to cache
    the tags.
    "*/
{
    CvsVerboseStatusRequestForWorkArea *aRequest = nil;
    
    if ( isNotEmpty(aWorkAreaPath) ) {
        aRequest=[CvsVerboseStatusRequestForWorkArea cvsVerboseStatusRequestForWorkArea:aWorkAreaPath]; 
        [aRequest setIsQuiet:YES];
        [aRequest schedule];        
    }
    return aRequest;
}

- (NSMutableDictionary *)getTagsForWorkArea:(NSString *)aWorkAreaPath
    /*" This method gets all the release tags in the repository represented by 
        the current workarea. This method first checks its cache of 
        workarea tags. If it has the tags cached then it just returns the cached 
        tags. If it does not have the tags cached then the method 
        -launchTaskToGetTagsForWorkArea: is called which will search the 
        repository for the tags. See this method for what happens next.
    "*/
{    
    NSMutableDictionary *aTagsDictionary = nil;
    NSArray *sortedTags = nil;
        
    if ( isNotEmpty(aWorkAreaPath) ) {
        aTagsDictionary = [self tagsForWorkArea:aWorkAreaPath];
        sortedTags = [aTagsDictionary objectForKey:@"SortedTagsKey"];
        if ( sortedTags == nil ) {
            [self launchTaskToGetTagsForWorkArea:aWorkAreaPath];
        }        
    }
    return aTagsDictionary;
}

- (NSMutableDictionary *)tagsForWorkArea:(NSString *)aWorkAreaPath
    /*" This method returns the cached tags for the current workarea. If it does
        not have any cached tags then an empty dictionary is returned.
    "*/
{    
    NSMutableDictionary *aTagsDictionary = nil;
    
    if ( isNotEmpty(aWorkAreaPath) ) {
        aTagsDictionary = [workAreaTagsCache objectForKey:aWorkAreaPath];
        if ( aTagsDictionary == nil ) {
            aTagsDictionary = [NSMutableDictionary dictionaryWithCapacity:3];
            [workAreaTagsCache setObject:aTagsDictionary forKey:aWorkAreaPath];
        }
    }
    return aTagsDictionary;
}

- (void)launchTaskToGetTagsForFiles:(NSArray *)someFiles inDirectory:(NSString *)aPath
    /*" This method will launch a request to get the tags for all the files in 
        the array of someFiles from the repository by calling the method 
        -fetchTagsForFiles:inDirectory:. All the files in someFiles are assumed 
        to be the the directory named aPath. Then the CVLWaitController is asked
        to put up a progress bar if this request takes longer than half of a 
        second. Then we ask the notification center to notify this controller 
        when the progress bar has been stopped. That notification is named 
        CVLWaitConditionMetNotification. 
    "*/
{
    NSNotificationCenter *theNotificationCenter = nil;
    NSString *aWaitMessage = nil;
    NSDictionary *aUserInfo = nil;
    CvsVerboseStatusRequest *aRequestForTags = nil;
    
    SEN_ASSERT_NOT_EMPTY(someFiles);
    SEN_ASSERT_NOT_EMPTY(aPath);
    
    // A switch indicator for the CVLWaitController.
    [switchObjectForFileTagsReceived release];
    switchObjectForFileTagsReceived = nil;
    
    // We get a newly initialized wait controller each time one is needed.
    [waitController release];
    waitController = nil;
    aRequestForTags = [self fetchTagsForFiles:someFiles inDirectory:aPath];
    
    aUserInfo = [NSDictionary dictionaryWithObjectsAndKeys:
        aPath, @"WorkAreaPathKey", 
        aRequestForTags, @"RequestForTagsForFilesKey", nil];
    waitController = [CVLWaitController 
                        waitForConditionTarget:self 
                                      selector:@selector(switchObjectForFileTagsReceived) 
                                   cancellable:YES 
                                      userInfo:aUserInfo];
    [waitController retain];
    
    theNotificationCenter = [NSNotificationCenter defaultCenter];
    [theNotificationCenter addObserver:self 
                              selector:@selector(waitOverForFetchingTagsForFiles:) 
                                  name:CVLWaitConditionMetNotification 
                                object:waitController];
    aWaitMessage = [NSString stringWithFormat:
        @"Searching the repository for all the revision tags for these files. This may take a minute or two."];
    [waitController setWaitMessage:aWaitMessage];
}

- (NSArray *)launchTaskToGetTagsForWorkArea:(NSString *)aWorkAreaPath
    /*" This method will launch a request to get all the tags from all the files
        in the repository by calling the method -fetchTagsForWorkArea:. Then the 
        CVLWaitController is asked to put up a progress bar if this request 
        takes longer than half of a second. Then we ask the notification center 
        to notify this controller when the progress bar has been stopped. That 
        notification is named CVLWaitConditionMetNotification. 
    "*/
{
    NSNotificationCenter *theNotificationCenter = nil;
    NSString *aWaitMessage = nil;
    NSDictionary *aUserInfo = nil;
    CvsVerboseStatusRequestForWorkArea *aRequestForWorkAreaTags = nil;

    SEN_ASSERT_NOT_EMPTY(aWorkAreaPath);
        
    // A switch indicator for the CVLWaitController.
    [switchObjectForWorkAreaTagsReceived release];
    switchObjectForWorkAreaTagsReceived = nil;
    
    // We get a newly initialized wait controller each time one is needed.
    [waitController release];
    waitController = nil;
    aRequestForWorkAreaTags = [self fetchTagsForWorkArea:aWorkAreaPath];
    
    aUserInfo = [NSDictionary dictionaryWithObjectsAndKeys:
        aWorkAreaPath, @"WorkAreaPathKey", 
        aRequestForWorkAreaTags, @"RequestForWorkAreaTagsKey", nil];
    waitController = [CVLWaitController 
            waitForConditionTarget:self 
                          selector:@selector(switchObjectForWorkAreaTagsReceived) 
                       cancellable:YES 
                          userInfo:aUserInfo];
    [waitController retain];
    
    theNotificationCenter = [NSNotificationCenter defaultCenter];
    [theNotificationCenter addObserver:self 
                              selector:@selector(waitOverForFetchingWorkAreaTags:) 
                                  name:CVLWaitConditionMetNotification 
                                object:waitController];
    aWaitMessage = [NSString stringWithFormat:
        @"Searching the repository for all the revision tags. This may take a minute or two."];
    [waitController setWaitMessage:aWaitMessage];
        
    return nil;
}

- (void) waitOverForFetchingTagsForFiles:(NSNotification *)aNotification
    /*" This method is called after the wait has ended for the CVLWaitController
        started up by the method -launchTaskToGetTagsForFiles:inDirectory:. The 
        CVLWaitController would have put up a  progress panel if the wait lasted 
        more that one-half of a second. If the wait was not cancelled then this
        method will sort the common tags for the files and then put them into an
        user info dictionary and post another notification with this user info 
        dictionary by the name of TagsForFilesReceivedNotification. If the wait was
        cancelled then the same notification is posted but without any user info
        dictionary.
    "*/
{
    NSNotificationCenter *theNotificationCenter = nil;
    CVLWaitController *theCVLWaitController = nil;
    NSDictionary *aUserInfo = nil;
    CvsVerboseStatusRequest *aRequest = nil;
    NSArray *someTags = nil;
    NSArray *sortedTags = nil;
    NSMutableDictionary *aTagsDictionary = nil;
    NSMutableDictionary *anotherUserInfo = nil;
    NSString *aPath = nil;
    NSArray *someFiles = nil;
    
    theCVLWaitController = [aNotification object];
    theNotificationCenter = [NSNotificationCenter defaultCenter];
    [theNotificationCenter removeObserver:self 
                                     name:CVLWaitConditionMetNotification
                                   object:theCVLWaitController];
    
    aUserInfo = [theCVLWaitController userInfo];
    aRequest = [aUserInfo objectForKey:@"RequestForTagsForFilesKey"];  
    
    if ( [theCVLWaitController waitCancelled] == YES ) { 
        // The fetching of the workarea tags was cancelled.
        [aRequest cancel];
        [theNotificationCenter 
            postNotificationName:@"TagsForFilesReceivedNotification"
                          object:self
                        userInfo:nil];            
    } else {
        // The fetching of the workarea tags was completed.
        someTags = [self  allCommonCvsTagsInRequest:aRequest];
        // Lets sort the tags first.
        if ( someTags != nil ) {
            sortedTags = [someTags 
                sortedArrayUsingSelector:@selector(compare:)];
        } else {
            sortedTags = [NSArray array];
        }
        aTagsDictionary = [NSMutableDictionary dictionaryWithCapacity:3];
        [aTagsDictionary setObject:sortedTags forKey:@"SortedTagsKey"];
        
        anotherUserInfo = [NSMutableDictionary dictionaryWithCapacity:3];
        [anotherUserInfo setObject:aTagsDictionary forKey:@"TagsDictionaryKey"];
        aPath = [aRequest path];
        if ( isNotEmpty(aPath) ) {
            [anotherUserInfo setObject:aPath forKey:@"PathKey"];
        }
        someFiles = [aRequest files];
        if ( isNotEmpty(someFiles) ) {
            [anotherUserInfo setObject:someFiles forKey:@"FilesKey"];
        }
        
        theNotificationCenter = [NSNotificationCenter defaultCenter];
        [theNotificationCenter 
            postNotificationName:@"TagsForFilesReceivedNotification"
                          object:self
                        userInfo:anotherUserInfo];                
    }
}

- (void) waitOverForFetchingWorkAreaTags:(NSNotification *)aNotification
    /*" This method is called after the wait has ended for the CVLWaitController
        started up by the method -launchTaskToGetTagsForWorkArea:. The 
        CVLWaitController would have put up a  progress panel if the wait lasted 
        more that one-half of a second. If the wait was not cancelled then this
        method will sort the workarea tags and then put them into an user info 
        dictionary and post another notification with this user info dictionary
        by the name of WorkAreaTagsReceivedNotification. If the wait was
        cancelled then the same notification is posted but without any user info
        dictionary.
    "*/
{
    NSNotificationCenter *theNotificationCenter = nil;
    CVLWaitController *theCVLWaitController = nil;
    NSDictionary *aUserInfo = nil;
    CvsVerboseStatusRequestForWorkArea *aRequest = nil;
    NSDictionary *someTagsInADictionary = nil;
    NSSet *someTagsInASet = nil;
    NSArray *someTags = nil;
    NSArray *sortedTags = nil;
    NSString *aWorkAreaPath = nil;
    NSMutableDictionary *aTagsDictionary = nil;
    NSMutableDictionary *anotherUserInfo = nil;
    
    theCVLWaitController = [aNotification object];
    theNotificationCenter = [NSNotificationCenter defaultCenter];
    [theNotificationCenter removeObserver:self 
                                     name:CVLWaitConditionMetNotification
                                   object:theCVLWaitController];
    
    aUserInfo = [theCVLWaitController userInfo];
    aRequest = [aUserInfo objectForKey:@"RequestForWorkAreaTagsKey"];  
    
    if ( [theCVLWaitController waitCancelled] == YES ) {
        // The fetching of the workarea tags was cancelled.
        [aRequest cancel];
        [theNotificationCenter 
            postNotificationName:@"WorkAreaTagsReceivedNotification"
                          object:self
                        userInfo:nil];            
    } else {
        // The fetching of the workarea tags was completed.
        someTagsInADictionary = [aRequest result];
        someTagsInASet = [someTagsInADictionary objectForKey:@"workAreaTagsKey"];
        someTags = [someTagsInASet allObjects];
        
        // Lets sort the tags first.
        if ( someTags != nil ) {
            sortedTags = [someTags 
                sortedArrayUsingSelector:@selector(compare:)];
        } else {
            sortedTags = [NSArray array];
        }
        aWorkAreaPath = [aRequest path];
        if ( isNotEmpty(aWorkAreaPath) ) {
            aTagsDictionary = [workAreaTagsCache objectForKey:aWorkAreaPath];
            [aTagsDictionary setObject:sortedTags forKey:@"SortedTagsKey"];
            
            anotherUserInfo = [NSMutableDictionary dictionaryWithCapacity:3];
            [anotherUserInfo setObject:aWorkAreaPath forKey:@"WorkAreaPathKey"];
            [anotherUserInfo setObject:aTagsDictionary forKey:@"TagsDictionaryKey"];
            
        }
        [theNotificationCenter 
            postNotificationName:@"WorkAreaTagsReceivedNotification"
                          object:self
                        userInfo:anotherUserInfo];            
    }
}

- (NSArray *)allCommonCvsTagsInRequest:(CvsVerboseStatusRequest *)aRequest
    /*" This method will return an array of CvsTags from the 
        CvsVerboseStatusRequest given by the argument aRequest. These CvsTags 
        returned are the ones common to all the files in the request so it could
        be an empty array.
    "*/
{
    NSArray *someCvsTags = nil;
    NSDictionary *aDictionaryOfDictionariesByPath = nil;
    NSEnumerator *aPathEnumerator = nil;
    NSString *aPath = nil;
    NSEnumerator *aCvsTagEnumerator = nil;
    NSDictionary *aDictionaryForPath = nil;
    NSArray *anArrayOfDictionariesForPathAndTags = nil;
    NSMutableSet *commonCvsTagsInASet = nil;
    CvsTag *aCvsTag = nil;
    NSMutableArray *cvsTagsForPath = nil;
    NSSet *cvsTagsForPathAsASet = nil;
    unsigned int aCount = 0;
    
    SEN_ASSERT_NOT_NIL(aRequest);
    
    aDictionaryOfDictionariesByPath = [aRequest result];
    if ( isNotEmpty(aDictionaryOfDictionariesByPath) ) {
        aPathEnumerator = [aDictionaryOfDictionariesByPath keyEnumerator];
        while ( (aPath = [aPathEnumerator nextObject]) ) {
            aDictionaryForPath = [aDictionaryOfDictionariesByPath 
                                                            objectForKey:aPath];
            anArrayOfDictionariesForPathAndTags = [aDictionaryForPath 
                                                    objectForKey:@"TagsKey"];
            if ( isNotEmpty(anArrayOfDictionariesForPathAndTags) ) {
                aCvsTagEnumerator = [anArrayOfDictionariesForPathAndTags 
                    objectEnumerator];
                aCount = [anArrayOfDictionariesForPathAndTags count];
                cvsTagsForPath = [NSMutableArray arrayWithCapacity:aCount];
                while ( (aCvsTag = [aCvsTagEnumerator nextObject]) ) {
                    [cvsTagsForPath addObject:aCvsTag];
                }
                
                if ( commonCvsTagsInASet == nil ) {
                    commonCvsTagsInASet = [NSMutableSet setWithArray:cvsTagsForPath];
                } else {
                    cvsTagsForPathAsASet = [NSSet setWithArray:cvsTagsForPath];
                    [commonCvsTagsInASet intersectSet:cvsTagsForPathAsASet];
                }
            } else {
                // Found an empty array of CvsTags. Hence the intersection will
                // be empty. Break and return an empty array.
                [commonCvsTagsInASet removeAllObjects];
                break;
            }
        }
        someCvsTags = [commonCvsTagsInASet allObjects];        
        [[someCvsTags retain] autorelease];
    }
    return someCvsTags;
}

- (id)switchObjectForWorkAreaTagsReceived
    /*" This method acts as a switch for the CVLWaitController which controls 
        the progress window. As long as this method returns a nil value then the
        progress window remains displayed. As soon as this method returns a non 
        nil value then the CVLWaitController will take down the progress window.
        The CVLWaitController queries this method repeatedly using a timer.
    "*/
{
    return switchObjectForWorkAreaTagsReceived;
}

- (id)switchObjectForFileTagsReceived
    /*" This method acts as a switch for the CVLWaitController which controls 
        the progress window. As long as this method returns a nil value then the
        progress window remains displayed. As soon as this method returns a non 
        nil value then the CVLWaitController will take down the progress window.
        The CVLWaitController queries this method repeatedly using a timer.
    "*/
{
    return switchObjectForFileTagsReceived;
}

- (void)turnOnSwitchObjectForFileTagsReceived
    /*" This method is called when the request to fetch all the tags for all the
        selected files from the repository has ended. This method then sets the 
        switch (i.e. the object switchObjectForFileTagsReceived) to a non nil 
        value which will alert the CVLWaitController to end the wait. After the 
        wait has ended the CVLWaitController will post the 
        CVLWaitConditionMetNotification which is also being observed by this 
        object. That will cause the tags that were fetched to be cached. 

        Also see #{-waitOverForFetchingTagsForFiles:} for more information.
    "*/
{    
    // A switch indicator for CVLWaitController.
    switchObjectForFileTagsReceived = [[NSObject alloc] init];
}

- (void)turnOnSwitchObjectForWorkAreaTagsReceived
    /*" This method is called when the request to fetch all the workarea tags 
        from the repository has ended. This method then sets the switch 
        (i.e. the object switchObjectForWorkAreaTagsReceived) to a non nil value 
        which will alert the CVLWaitController to end the wait. After the wait 
        has ended the CVLWaitController will post the 
        CVLWaitConditionMetNotification which is also being observed by this 
        object. That will cause the tags that were fetched to be cached. 

        Also see #{-waitOverForFetchingWorkAreaTags:} for more information.
    "*/
{
    // A switch indicator for CVLWaitController.
    switchObjectForWorkAreaTagsReceived = [[NSObject alloc] init];
}

- (void)clearCacheForWorkArea:(NSString *)aWorkAreaPath
    /*" This method clears out the cache of tags for the workarea given in the 
        argument aWorkAreaPath. This method is called whenever a new tag is 
        added to the repository that backs up this workarea.
    "*/
{
    if ( isNotEmpty(workAreaTagsCache) && isNotEmpty(aWorkAreaPath) ) {
        [workAreaTagsCache removeObjectForKey:aWorkAreaPath];
    }
}


@end

