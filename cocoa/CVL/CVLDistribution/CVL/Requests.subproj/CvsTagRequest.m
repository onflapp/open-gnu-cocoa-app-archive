/* CvsTagRequest.m created by vincent on Wed 26-Nov-1997 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "CvsTagRequest.h"
#import "ResultsRepository.h"
#import "CVLFile.h"
#import "NSArray.SenCategorize.h"
#import <SenFoundation/SenFoundation.h>
#import <Foundation/Foundation.h>

@implementation CvsTagRequest

+ (id) cvsTagRequestForFiles: (NSArray*) someFiles
                      inPath: (NSString*) aPath
                         tag: (NSString*) tagString
                    isBranch: (BOOL) bFlag
                moveIfExists: (BOOL) mFlag
             tagIfUnmodified: (BOOL) uFlag
{
    CvsTagRequest *newRequest;
    NSMutableDictionary* subpathsDict= [[someFiles categorizeUsingMethod: @selector(stringByDeletingLastPathComponent)] mutableCopy];
    NSString* commonPath= aPath;

    [subpathsDict removeObjectForKey: @""]; // remove files without any subpath

    NSAssert([[subpathsDict allKeys] count] <= 1, @"Cannot handle more than one common subpath!");

    if ([[subpathsDict allKeys] count] == 1)
    {
      NSEnumerator* fileEnum= [someFiles objectEnumerator];
      NSString* currentPath= nil;
      NSMutableArray* filesWithoutPath= [NSMutableArray arrayWithCapacity: [someFiles count]];

      while ( (currentPath= [fileEnum nextObject]) )
      {
        [filesWithoutPath addObject: [currentPath lastPathComponent]];
      }
      commonPath= [aPath stringByAppendingPathComponent: [[subpathsDict allKeys] objectAtIndex: 0]];

  #ifdef DEBUG
      {
          NSString *aMsg = [NSString stringWithFormat:
                @"multi path in args %@, commonPath: %@, new args %@", 
              someFiles, commonPath, filesWithoutPath];
          SEN_LOG(aMsg);        
      }
  #endif

      newRequest=[self requestWithCmd:CVS_TAG_CMD_TAG title:@"tag" path: commonPath files: filesWithoutPath];
    }
    else
    {
      newRequest=[self requestWithCmd:CVS_TAG_CMD_TAG title:@"tag" path:aPath files:someFiles];
    }

    [newRequest setTag: tagString];
    [newRequest setIsBranchTag: bFlag];
    [newRequest setMoveIfExists: mFlag];
    [newRequest setTagIfUnmodified: uFlag];
    return newRequest;
}


- (void) dealloc
{
    RELEASE(tag);
    [super dealloc];
}

- (void) setTag: (NSString*) aString
{
    ASSIGN(tag, aString);
}

- (void) setIsBranchTag: (BOOL) aFlag
{
    isBranchTag= aFlag;
}

- (void) setMoveIfExists: (BOOL) aFlag
{
    moveIfExists= aFlag;
}


- (void) setTagIfUnmodified: (BOOL) aFlag
{
    tagIfUnmodified= aFlag;
}

- (NSArray *)cvsCommandOptions
{
    NSMutableArray* options= [NSMutableArray arrayWithCapacity: 1];

    if (moveIfExists)
    {
        [options addObject: @"-F"];
    }
    if (isBranchTag)
    {
        [options addObject: @"-b"];
    }
    if (tagIfUnmodified)
    {
        [options addObject: @"-c"];        
    }
    return options;
}


- (NSArray *)cvsCommandArguments
{
  NSMutableArray* arguments= [NSMutableArray arrayWithCapacity: 2];

    if ( tag != nil ) {
        [arguments addObject: tag];
    }
  [arguments addObjectsFromArray: [self files]];
  return arguments;
}

- (NSString *)cvsWorkingDirectory
{
    return [self path];
}

- (void) updateFileInfos
{
    // It is not necessary to invalidate all file info. We can invalidate only necessary info,
    // like tags, and status (only if we created a new branch) => FASTER!
    ResultsRepository	*resultsRepository=[ResultsRepository sharedResultsRepository];
    CVLFile				*file;

    [resultsRepository startUpdate];

    if(![self files]){
        file = (CVLFile *)[CVLFile treeAtPath:[self path]];
        [file traversePostorder:@selector(invalidateTags)];
        if(isBranchTag){
            [file traversePostorder:@selector(invalidateStatus)];
            [file traversePostorder:@selector(invalidateCumulatedStatuses)];
        }
    }
    else{
        NSEnumerator	*enumerator = [[self files] objectEnumerator];
        NSString		*aPath;

        while ( (aPath = [enumerator nextObject]) ) {
            aPath = [[self path] stringByAppendingPathComponent:aPath];
            file = (CVLFile *)[CVLFile treeAtPath:aPath];
            [file traversePostorder:@selector(invalidateTags)];
            if(isBranchTag){
                [file traversePostorder:@selector(invalidateStatus)];
                [file traversePostorder:@selector(invalidateCumulatedStatuses)];
            }
        }
    }
    
    [resultsRepository endUpdate];
}

- (void) end
{
    [self updateFileInfos];
    [super endWithoutInvalidation];
}

@end
