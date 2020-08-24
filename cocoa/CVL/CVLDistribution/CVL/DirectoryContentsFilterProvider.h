/* DirectoryContentsFilterProvider.h created by ja on Tue 19-Aug-1997 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <AppKit/AppKit.h>
#import "ResultsRepository.h"
#import "DirectoryContentsFilter.h"
#import "CVLFile.h"

@class DirectoryContentsFilter;

@interface DirectoryContentsFilterProvider : NSObject
{
    BOOL showUpToDate;
    BOOL showModified;
    BOOL showNeedsUpdate;
    BOOL showNeedsMerge;
    BOOL showConflicts;
    BOOL showNotInCVS;
    BOOL showUnknown;
    BOOL showIgnored;
    BOOL showNoStatus;
}
- (DirectoryContentsFilter *)filterForDirectory:(NSString *)directoryPath;
- (BOOL)showFile:(CVLFile *)aFile;

- (void)setShowUpToDate:(id)sender;
- (void)setShowModified:(id)sender;
- (void)setShowNeedsUpdate:(id)sender;
- (void)setShowNeedsMerge:(id)sender;
- (void)setShowConflicts:(id)sender;
- (void)setShowNotInCVS:(id)sender;
- (void)setShowUnknown:(id)sender;
- (void)setShowIgnored:(id)sender;
- (void)setShowNoStatus:(id)sender;

- (void)configureToShowFile:(CVLFile *)aFile;

- (NSArray *)stringArrayFilterDescription;
- (void)setFilterWithStringArray:(NSArray *)value;

@end
