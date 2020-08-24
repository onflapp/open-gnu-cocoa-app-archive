
// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <Foundation/Foundation.h>
#import "CVLFile.h"

@class CvsRepository;
@class CvsVerboseStatusRequestForWorkArea;
@class CvsVerboseStatusRequest;
@class CVLWaitController;

@interface ResultsRepository : NSObject
{
    NSMutableSet *changedFiles;
    NSMutableSet *oldChangedFiles;

    int             updateCount;
    NSMutableArray *statusQueue;
    NSMutableArray *quickStatusQueue;
    NSMutableArray *logRequests;
    NSMutableArray *logQueue;
    NSMutableArray *tagsRequests;
    NSMutableArray *tagsQueue;
    NSMutableSet	*quickStatusTargetPaths;
    
    NSMutableDictionary     *workAreaTagsCache;
    CVLWaitController       *waitController;
    NSObject                *switchObjectForFileTagsReceived;
    NSObject                *switchObjectForWorkAreaTagsReceived;

    BOOL performStatusPending;
    BOOL performQuickStatusPending;
    BOOL performLogPending;
    BOOL performTagsPending;
    BOOL isGettingTagsForFiles;

    //        BOOL showRepositoryFiles;
}

+ (ResultsRepository *)sharedResultsRepository;

- (void)startUpdate;
- (void)endUpdate;
- (BOOL)hasChanged;
- (NSSet *) changedFiles;

//- (void)updateDir:(NSString *)fullPath;
//- (NSObject *)resultForPath:(NSString *)path andKey:(NSString *)key;
//- (void)setResults:results forPath:(NSString *)path;

- (void)getStatusForFile:(CVLFile *)file;
- (void) getQuickStatusForFile:(CVLFile *)file;
- (void)getLogForFile:(CVLFile *)file;
- (void)getDifferencesForFile:(CVLFile *)file context:(CVLDiffOutputFormat)context outputFormat:(CVLDiffOutputFormat)outputFormat;
- (void)getTagsForFile:(CVLFile *)file;
- (void)getCvsEditorsForFile:(CVLFile *)file;
- (void)getCvsWatchersForFile:(CVLFile *)file;
- (void)setCvsEditorsFromDictionary:(NSDictionary *)aDictionary;
- (void)setCvsWatchersFromDictionary:(NSDictionary *)aDictionary;

- (void)turnOnSwitchObjectForWorkAreaTagsReceived;
- (void)turnOnSwitchObjectForFileTagsReceived;
- (NSMutableDictionary *)getTagsForWorkArea:(NSString *)aWorkAreaPath;
- (CvsVerboseStatusRequestForWorkArea *)fetchTagsForWorkArea:(NSString *)aWorkAreaPath;
- (NSArray *)launchTaskToGetTagsForWorkArea:(NSString *)aWorkAreaPath;
- (NSMutableDictionary *)tagsForWorkArea:(NSString *)aWorkAreaPath;
- (void)clearCacheForWorkArea:(NSString *)aWorkAreaPath;
- (CvsVerboseStatusRequest *)fetchTagsForFiles:(NSArray *)someFiles inDirectory:(NSString *)aPath;
- (void)launchTaskToGetTagsForFiles:(NSArray *)someFiles inDirectory:(NSString *)aPath;
- (NSArray *)allCommonCvsTagsInRequest:(CvsVerboseStatusRequest *)aRequest;

- (void)fileDidChange:(CVLFile *)file;
@end
