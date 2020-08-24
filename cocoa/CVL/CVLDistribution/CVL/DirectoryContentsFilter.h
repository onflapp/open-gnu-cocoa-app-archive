/* DirectoryContentsFilter.h created by ja on Tue 12-Aug-1997 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <Foundation/Foundation.h>
#import "ResultsRepository.h"
#import "DirectoryContentsFilterProvider.h"

@class DirectoryContentsFilterProvider;

@interface DirectoryContentsFilter : NSObject
{
    ResultsRepository *resultsRepository;
    CVLFile *filteredDirectory;
    NSMutableArray *cachedFilteredContents;
    BOOL needsUpdate;
    DirectoryContentsFilterProvider *provider;
}
- (id)initForDirectory:(NSString *)directoryPath withProvider:(DirectoryContentsFilterProvider *)aProvider;
- (NSArray *)filteredContents;
- (NSString *)filteredDirectoryPath;
@end
