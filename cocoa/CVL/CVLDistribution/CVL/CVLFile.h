/* CVLFile.h created by ja on Thu 12-Mar-1998 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <Foundation/Foundation.h>
#import <SenFoundation/SenFileSystemTree.h>

/*" ECStatusType is represented in the browser with the following images:
    _{ECNoType                elipsis}
    _{ECUpToDateType          unknown (actually nothing shows)}
    _{ECLocallyModifiedType   plus}
    _{ECNeedsUpdateType       minus}
    _{ECNeedsMergeType        triangle}
    _{ECConflictType          blackPoint}
    _{ECNotCVSType            star}
    _{ECIgnoredType           times}
    _{ECUnknownType           questionMark}


    ECFileType is partially described below:
    _{ECAbsentFile: not in work area, but should be; in grey}
    _{ECInvalidFile: 2 possible conditions:}
        _{a) (not in WA) &&   (in CVS/Entries)   && (not in repository)}
        _{b)   (in WA)   && (not in CVS/Entries) &&   (in repository)}

"*/

typedef enum _ECStatusType {    
    ECNoType, 
    ECUpToDateType, 
    ECLocallyModifiedType, 
    ECNeedsUpdateType, 
    ECNeedsMergeType, 
    ECConflictType, 
    ECNotCVSType, 
    ECIgnoredType, 
    ECUnknownType
} ECStatusType;

typedef enum _ECFileType {
    ECCVSFile,
    ECLocalFile,
    ECAbsentFile,
    ECInactiveFile,
    ECInvalidFile,
    ECDirContainingLocalFiles,
    ECNoFile
} ECFileType;

typedef enum _ECTokenizedStatus {
    ECNoStatus,
    ECUpToDate,
    ECLocallyModified,
    ECLocallyAdded,
    ECLocallyRemoved,
    ECNeedsPatch,
    ECNeedsCheckout,
    ECNeedsMerge,
    ECMixedStatus,
    ECConflict,
    ECConflict2,
    ECNotCVS,
    ECContainsNonCVSFiles,
    ECIgnored,
    ECUnknown,
    ECInvalidEntry
} ECTokenizedStatus;

typedef struct _ECStatus {
    ECStatusType statusType:4;
    ECTokenizedStatus tokenizedStatus:5;
} ECStatus;

typedef struct _ECFileFlags {
    unsigned int isDir:1;
    unsigned int isWrapper:1;
    unsigned int isInWorkArea:1;
    unsigned int isInCVSEntries:1;
    unsigned int isInRepository:1;
    unsigned int isHidden:1;
    unsigned int isIgnored:1; // copy of isHidden at the moment
    ECFileType type:3;
} ECFileFlags;

typedef struct _ECFileAttributeGroups {
    unsigned int flags:1;
    unsigned int children:1;
    unsigned int status:1;
    unsigned int log:1;
    unsigned int differences:1;
    unsigned int cumulatedStatuses:1;
    unsigned int repository:1;
    unsigned int tags:1;
    unsigned int quickStatus:1;
    unsigned int stickyDateOrTagFetched:1;
    unsigned int cvsEditorsFetchedFlag:1;
    unsigned int cvsWatchersFetchedFlag:1;    
} ECFileAttributeGroups;

typedef int ECCumulatedStatuses[ECUnknown+1];

typedef enum {
    CVLNormalOutputFormat = 0,
    CVLContextOutputFormat = 1,
    CVLUnifiedOutputFormat = 2
}CVLDiffOutputFormat;

extern ECStatus tokenizedStatus[];

@class CvsRepository;
@class CvsEditor;
@class CvsWatcher;
@class CvsEntry;

@interface CVLFile : SenFileSystemTree
{
    ECFileFlags flags;
    ECStatus status;
    
    NSString *differences;
    NSArray *log;
    NSArray* tags;
    NSString *revisionInWorkArea;
    NSString *revisionInRepository;

    NSDate *modificationDate;
    NSDate *dateOfLastCheckout;

    NSString *stickyTag;
    NSString *stickyOptions;
    NSDate *stickyDate;

    ECCumulatedStatuses *cumulatedStatusesArray;
    NSArray *children;
    CVLFile *parent;
    CVLFile *rootFile;

    CvsRepository *repository;
    
    ECFileAttributeGroups loading;
    ECFileAttributeGroups have;
    
    ECFileAttributeGroups changes;
    ECFileAttributeGroups oldChanges;
    ECFileAttributeGroups cumulatedChanges;
    BOOL	wasInvalidated;
    BOOL	statusWasInvalidated;
    BOOL    hasRunCvsEntriesConsistencyCheck;
    

    unsigned differencesContext;
    CVLDiffOutputFormat diffOutputFormat;

    NSString *pathInRepository;
    
    NSArray *cvsEditors;
    NSArray *cvsWatchers;    
    CvsEntry *cvsEntry;
}

- (ECFileFlags)flags;
/*
- (BOOL)isDirectory;
- (BOOL)isWrapper;
- (BOOL)isInEntries;
- (BOOL)isInRepository;
- (BOOL)isHidden; */
- (BOOL)isIgnored;

- (NSArray *)loadedChildren;

- (CVLFile *)rootFile;
- (BOOL)isRootFile;

- (NSArray *)children; // return children only if they are already loaded
- (NSArray *) unrolled;
- (NSString *)name;

- (NSString *)pathInRepository;
- (ECStatus)status;
- (void)setStatus:(ECStatus)newStatus;
- (NSString *)statusString;
- (void)setStatusFromDictionary:(NSDictionary *)results;
- (void) setQuickStatusWithString:(NSString *)quickStatus;
- (NSArray *)log;
- (NSString *)differencesWithContext:(unsigned)contextLineNumber outputFormat:(CVLDiffOutputFormat)outputFormat;
- (void)setLog:(NSArray *)newLog;
- (void)setDifferences:(NSString *)newDifferences;
- (NSString *)revisionInWorkArea;
- (NSString *)revisionInRepository;

- (NSDate *)modificationDate;
- (NSDate *)dateOfLastCheckout;

- (NSString *)stickyTag;
- (NSString *)stickyOptions;
- (NSDate *)stickyDate;
- (NSString *)strippedStickyTag;

- (NSArray*) tags; // Returns array of objects of the CvsTag class
- (void) setTags: (NSArray*) newTags;

// Following attributes are only for directories
- (CvsRepository *)repository;
- (ECCumulatedStatuses *)cumulatedStatusesArray;

- (void)clearChanges;
- (void)propagateChanges;
- (void)cumulateChanges;

- (ECFileAttributeGroups)changes;
- (ECFileAttributeGroups)have;

- (void)invalidateAll;

- (void)invalidateStatus;
- (void)invalidateFlags;
- (void)invalidateChildren;
- (void)invalidateLog;
- (void)invalidateDifferences;
- (void)invalidateCumulatedStatuses;
- (void)invalidateRepository;
- (void)invalidateCvsEditors;
- (void)invalidateCvsWatchers;

- (NSString *) filenameForRevision:(NSString *)aVersion; // Returns filename.revision
- (NSString *) filenameForDate:(NSString *)aDate; // Returns filename.xxx where xxx is date with _ separators
- (NSString *) fileAncestorForRevision:(NSString *)aVersion; // Returns full path name with same directory and .#filename.revision
- (NSString *) precedingVersion;
// Retrieves preceding version, assuming it is the earliest file matching pattern: .#filename.version

- (BOOL) hasBeenRegisteredByRepository;

- (BOOL) isBinary; // Returns YES if sticky options contain -kb
- (BOOL) isRealWrapper; // Returns YES if file is a directory which is considered as a single file by cvs
- (BOOL) hasStickyTagOrDate; // Returns YES if has sticky date or sticky tag
- (BOOL) isABranch;
- (BOOL) hasStickyAttributes;
- (BOOL) isRealDirectory; // Returns YES if file is a directory which is NOT considered as a single file by cvs (i.e. not a wrapper)
- (BOOL)isRealDirectoryAndHasDisappeared;
- (BOOL) isDirectory; // Returns YES if file is a directory without checking if it's a wrapper
- (BOOL) isAnEmptyDirectory;
- (BOOL) markedForRemoval;
- (BOOL) markedForAddition;

- (NSArray *) cvsEditors;
- (NSArray *) cvsWatchers;
- (CvsEditor *) cvsEditorForCurrentUser;
- (CvsWatcher *) cvsWatcherForCurrentUser;

- (void) setCvsEditors:(NSArray *)newCvsEditors;
- (void) setCvsWatchers:(NSArray *)newCvsWatchers;

- (void) loadingCvsEditors;
- (void) loadingCvsWatchers;

- (CvsEntry *) cvsEntry;
- (void) setCvsEntry:(CvsEntry *)newCvsEntry;
- (void) runCvsEntriesConsistencyCheck:(NSArray *)someCvsEntries;
- (NSArray *)getChildrenFromCvsEntries;

    /*" Menu Validation Helper Methods "*/
- (BOOL) canBeDeletedAndUpdated;
- (BOOL) canBeAdded;
- (BOOL) canBeMarkedForRemoval;
- (BOOL) canBeReinstatedAfterMarkedForRemoval;

    /*" Debug Helper Methods "*/
- (void) printFlags;
- (void) printStatus;


@end
