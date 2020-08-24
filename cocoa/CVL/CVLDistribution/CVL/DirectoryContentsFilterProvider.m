/* DirectoryContentsFilterProvider.m created by ja on Tue 19-Aug-1997 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "DirectoryContentsFilterProvider.h"

@implementation DirectoryContentsFilterProvider
- (DirectoryContentsFilter *)filterForDirectory:(NSString *)directoryPath
{
    return [[[DirectoryContentsFilter alloc] initForDirectory:directoryPath withProvider:self] autorelease];
}

- (BOOL)showFile:(CVLFile *)aFile
{
    ECFileFlags flags=[aFile flags];

    if (flags.isIgnored && showIgnored) return showIgnored;

    if ([aFile isLeaf]) {
        switch([aFile status].statusType){
            case ECUpToDateType:
                return showUpToDate;
            case ECLocallyModifiedType:
                return showModified;
            case ECNeedsUpdateType:
                return showNeedsUpdate;
            case ECNeedsMergeType:
                return showNeedsMerge;
            case ECConflictType:
                return showConflicts;
            case ECNotCVSType:
                if(![aFile flags].isIgnored)
                    return showNotInCVS;
                else
                    return NO;
            case ECUnknownType:
                return showUnknown;
            case ECNoType:
                return showNoStatus;
            default:
                return NO;
        }
    } else {
        BOOL result=NO;
        ECCumulatedStatuses *cumulatedStatusesArray=[aFile cumulatedStatusesArray];
        int statusToken;
        
        // The following "if" statement takes care of the condition that happens
        // when the CVS update command with the "-P" option is run on a 
        // directory that is empty.
        if ( [aFile isRealDirectoryAndHasDisappeared] == YES ) {
            return NO;
        }          
        
        if (cumulatedStatusesArray) {
            for (statusToken=0;statusToken<=ECUnknown;statusToken++) {
                if ((*cumulatedStatusesArray)[statusToken]>0) {
                    switch(tokenizedStatus[statusToken].statusType){
                        case ECIgnoredType:
                            result|=showIgnored; break;
                        case ECUpToDateType:
                            result|=showUpToDate; break;
                        case ECLocallyModifiedType:
                            result|=showModified; break;
                        case ECNeedsUpdateType:
                            result|=showNeedsUpdate; break;
                        case ECNeedsMergeType:
                            result|=showNeedsMerge; break;
                        case ECConflictType:
                            result|=showConflicts; break;
                        case ECNotCVSType:
                            result|=showNotInCVS; break;
                        case ECUnknownType:
                            result|=showUnknown; break;
                        case ECNoType:
                            result|=showNoStatus;
                    }
                }
            }
        }
        return result;
    }
}

- (void)didChange
{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ProviderChanged" object:self];
}

- (NSArray *)stringArrayFilterDescription
{
    NSMutableArray *newArray;

    newArray=[NSMutableArray array];
    if (showModified) {
        [newArray addObject:@"Locally Modified"];
    }
    if (showNeedsUpdate) {
        [newArray addObject:@"Needs Update"];
    }
    if (showNeedsMerge) {
        [newArray addObject:@"Needs Merge"];
    }
    if (showConflicts) {
        [newArray addObject:@"Conflicts"];
    }
    if (showUpToDate) {
        [newArray addObject:@"Up-To-Date"];
    }
    if (showNotInCVS) {
        [newArray addObject:@"Not in CVS"];
    }
    if (showUnknown) {
        [newArray addObject:@"Unknown"];
    }
    if (showIgnored) {
        [newArray addObject:@"Ignored"];
    }
    if (showNoStatus) {
        [newArray addObject:@"Being Computed"];
    }

    return newArray;
}


- (void)setFilterWithStringArray:(NSArray *)value
{
    showModified=[value containsObject:@"Locally Modified"];
    showNeedsUpdate=[value containsObject:@"Needs Update"];
    showNeedsMerge=[value containsObject:@"Needs Merge"];
    showConflicts=[value containsObject:@"Conflicts"];
    showUpToDate=[value containsObject:@"Up-To-Date"];
    showNotInCVS=[value containsObject:@"Not in CVS"];
    showUnknown=[value containsObject:@"Unknown"];
    showIgnored=[value containsObject:@"Ignored"];
    showNoStatus=[value containsObject:@"Being Computed"];
    
    [self didChange];
}

- (void)setShowUpToDate:(id)sender
{
    showUpToDate=([sender intValue]!=0);
    [self didChange];
}

- (void)setShowModified:(id)sender;
{
    showModified=([sender intValue]!=0);
    [self didChange];
}

- (void)setShowNeedsUpdate:(id)sender
{
    showNeedsUpdate=([sender intValue]!=0);
    [self didChange];
}

- (void)setShowNeedsMerge:(id)sender
{
    showNeedsMerge=([sender intValue]!=0);
    [self didChange];
}

- (void)setShowConflicts:(id)sender
{
    showConflicts=([sender intValue]!=0);
    [self didChange];
}

- (void)setShowNotInCVS:(id)sender
{
    showNotInCVS=([sender intValue]!=0);
    [self didChange];
}

- (void)setShowUnknown:(id)sender
{
    showUnknown=([sender intValue]!=0);
    [self didChange];
}

- (void)setShowIgnored:(id)sender
{
    showIgnored=([sender intValue]!=0);
    [self didChange];
}

- (void)setShowNoStatus:(id)sender
{
    showNoStatus=([sender intValue]!=0);
    [self didChange];
}

- (void)configureToShowFile:(CVLFile *)aFile
{
    ECStatus status=[aFile status];
    ECFileFlags flags=[aFile flags];

    if (flags.isIgnored) showIgnored=YES;
    switch(status.statusType){
        case ECUpToDateType:
            showUpToDate = YES; break;
        case ECLocallyModifiedType:
            showModified = YES; break;
        case ECNeedsUpdateType:
            showNeedsUpdate = YES; break;
        case ECNeedsMergeType:
            showNeedsMerge = YES; break;
        case ECConflictType:
            showConflicts = YES; break;
        case ECNotCVSType:
            if(!flags.isIgnored)
                showNotInCVS = YES;
            break;
        case ECUnknownType:
            showUnknown = YES; break;
        case ECNoType:
            showNoStatus = YES;
        default: // ECIgnoredType
            ;
    }
    [self didChange];
}

@end
