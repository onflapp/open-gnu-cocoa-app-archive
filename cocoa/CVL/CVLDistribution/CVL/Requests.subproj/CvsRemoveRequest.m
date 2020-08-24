/* CvsRemoveRequest.m created by ja on Sat 24-Jul-1999 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "CvsRemoveRequest.h"
#import "CVLFile.h"
#import <SenFoundation/SenFoundation.h>


@interface CvsRemoveRequest (private)
- (BOOL) removeWrappersInChildren;
@end


@implementation CvsRemoveRequest

+ (CvsRemoveRequest *) removeRequestAtPath:(NSString *)aPath files:(NSArray *)someFiles
{
    NSArray		*checkedFiles = nil;
    NSString	*commonPath;

    if(someFiles){
        NSDictionary	*pathDict = [[self class] canonicalizePath:aPath andFiles:someFiles];
        
        commonPath = [[pathDict allKeys] objectAtIndex:0];
        checkedFiles = [pathDict objectForKey:commonPath];
    }
    else
        commonPath = aPath;

    return [self requestWithCmd:CVS_REMOVE_CMD_TAG title:@"remove" path:commonPath files:checkedFiles];
}

- (NSArray *) cvsCommandOptions
    /*" This method returns the command options for the CVS remove request. 
        This consist of an array of one object, a string of "-fR". This 
        overrides supers implementation. The "-f" means for this command to 
        delete the file before removing it.  The "-R" means for this command to
        operate recursively.
    "*/
{
    return [NSArray arrayWithObject:@"-fR"];
}

- (NSString *) cvsWorkingDirectory
    /*" This method returns the working directory. In this case it is the same
        as the instance variable named path (i.e. the current directory in the 
        CVL Browser). This overrides supers implementation.
    "*/
{
    return [self path];
}

- (BOOL) removeWrappersInChildren
{
    NSEnumerator	*removedFileEnumerator = [files objectEnumerator];
    NSString		*removedFilePath;
    NSEnumerator	*childEnumerator = nil;
    CVLFile			*child;
    NSMutableArray	*filesToRemove = [NSMutableArray array];
    BOOL			result = YES;
    NSFileManager	*fileManager = [NSFileManager defaultManager];
    
    while ( (removedFilePath = [removedFileEnumerator nextObject]) ) {
        NSString	*fullRemovedFilePath = [path stringByAppendingPathComponent:removedFilePath];
        CVLFile		*removedFile = [CVLFile treeAtPath:fullRemovedFilePath];

        (void)[removedFile flags];
        if(![removedFile isLeaf]) {
            childEnumerator = [removedFile breadthFirstEnumerator];
            while ( (child = [childEnumerator nextObject]) ) {
                ECFileFlags	fileFlags = [child flags];
                
                if(!(fileFlags.isIgnored) && fileFlags.isInCVSEntries && fileFlags.isDir && fileFlags.isWrapper)
                    [filesToRemove addObject:child];
            }
        }
        else if([removedFile isRealWrapper])
            [filesToRemove addObject:removedFile];
    }

    // Now try to delete all marked files
    childEnumerator = [filesToRemove objectEnumerator];
    while(result && (child = [childEnumerator nextObject]))
        result = [fileManager removeFileAtPath:[child path] handler:nil];

    return result;
}

#ifdef JA_PATCH
- (BOOL)startTask
{
    success=NO;noLogin=NO;
    if (![self removeWrappersInChildren]) return NO;
    return [super startTask];
}
#else
- (void) start
{
    if([self removeWrappersInChildren])
        [super start];
    else
        [self cancel];
}
#endif

@end
