/* DirectoryContentsFilter.m created by ja on Tue 12-Aug-1997 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "DirectoryContentsFilter.h"
#import <SenFoundation/SenFoundation.h>

@interface DirectoryContentsFilter (Private)
- (void)updateFilteredContents;
@end

@implementation DirectoryContentsFilter
- (id)initForDirectory:(NSString *)directoryPath withProvider:(DirectoryContentsFilterProvider *)aProvider
{
    self=[self init];
    if (self) {
        resultsRepository=[ResultsRepository sharedResultsRepository];
        ASSIGN(filteredDirectory, [CVLFile treeAtPath:directoryPath]);
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resultsChanged:)
                                                       name:@"ResultsChanged"
                                                   object:resultsRepository];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(providerChanged:)
                                                       name:@"ProviderChanged"
                                                   object:aProvider];
        ASSIGN(provider, aProvider);
        cachedFilteredContents=[[NSMutableArray alloc] init];
        [self updateFilteredContents];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    RELEASE(provider);
    RELEASE(filteredDirectory);
    RELEASE(cachedFilteredContents);
    [super dealloc];
}

- (NSString *) description
    /*" This method overrides supers implementation. Here we return the 
        needsUpdate instance variable and the path of the directory that this
        filter is filtering.
    "*/
{
    return [NSString stringWithFormat:
        @"needsUpdate = %d, filteredDirectoryPath = %@, cachedFilteredContents = %@", 
        needsUpdate, [self filteredDirectoryPath], cachedFilteredContents];
}

- (NSString *)filteredDirectoryPath
{
    return [filteredDirectory path];
}

- (void)updateFilteredContents
{
    NSMutableArray *newFilteredContents=[NSMutableArray array];
    NSArray *children;
    id enumerator;
    CVLFile *file;

    [resultsRepository startUpdate];
    children=[filteredDirectory loadedChildren];

    enumerator=[children objectEnumerator];
    while ( (file=[enumerator nextObject]) ) {
        if ([provider showFile:file]) {
            [newFilteredContents addObject:file];
        }
    }
    [resultsRepository endUpdate];
    if (![newFilteredContents isEqual:cachedFilteredContents]) {
        ASSIGN(cachedFilteredContents, newFilteredContents);
        [[NSNotificationCenter defaultCenter] postNotificationName:@"FilteredContentsChanged" object:self];
    }
}

- (NSArray *)filteredContents
{
    return cachedFilteredContents;
}

- (void)providerChanged:(NSNotification *)aNotification
{
    [self updateFilteredContents];
}

- (void)resultsChanged:(NSNotification *)aNotification
{
    id childrenEnumerator;
    BOOL changed=NO;
    CVLFile *file;
    ECFileAttributeGroups changes;
    
    if ([resultsRepository hasChanged]) {
        if ([filteredDirectory changes].children) {
            changed=YES;
        } else {
            childrenEnumerator=[[filteredDirectory loadedChildren] objectEnumerator];

            while ( (file=[childrenEnumerator nextObject]) ) {
                changes=[file changes];
                if (changes.status || changes.quickStatus || changes.cumulatedStatuses) {
                    changed=YES;
                        break;
                }
            }
        }
    }
    if (changed) {
        [self updateFilteredContents];
    } 
}
@end
