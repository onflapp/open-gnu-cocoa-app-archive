/* NSFileManager_CVS.m created by ja on Fri 04-Feb-2000 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "NSFileManager_CVS.h"

#import <SenFoundation/SenFoundation.h>


@implementation NSFileManager (CVS)
- (void)copyCVSAdministrativeFilesFromPath:(NSString *)fromPath to:(NSString *)toPath
{ /*
    NSDirectoryEnumerator *fileEnumerator;
    NSString *path;
    NSString *relativePath;
    NSString *commonPath;
    NSRange commonRange;
    NSRange relativeRange;
    NSString *targetCVSPath;
    NSString *targetCVSDirectoryPath;

    fromPath=[fromPath stringByStandardizingPath];
    commonRange.location=0;
    commonRange.length=[fromPath length];
    relativeRange.location=commonRange.length;
    
    fileEnumerator=[self enumeratorAtPath:fromPath];
    
    while (path=[fileEnumerator nextObject]) {
        if ([[path lastPathComponent] isEqual:@"CVS"]) {
            commonPath=[path substringWithRange:commonRange];
            if ([commonPath isEqual:fromPath]) {
                relativeRange.length=[path length]-relativeRange.location;
                relativePath=[path substringWithRange:relativePath];
                targetCVSPath=[toPath stringByAppendingPathComponent:relativePath];
                targetCVSDirectoryPath=[targetCVSPath stringByRemovingLastPathComponent];
                if ([self createAllDirectoriesAtPath:targetCVSDirectoryPath attributes:nil]) {
                    [self copyPath:path toPath:targetCVSDirectoryPath handler:nil];
                }
            }
        }
    } */
}

- (void)moveCVSAdministrativeFilesFromPath:(NSString *)fromPath to:(NSString *)toPath
{
    NSDirectoryEnumerator *fileEnumerator;
    NSString *relativePath;
    NSString *targetCVSPath;

    fileEnumerator=[self enumeratorAtPath:fromPath];

    while ( (relativePath=[fileEnumerator nextObject]) ) {
        if ([[relativePath lastPathComponent] isEqual:@"CVS"]) {
            targetCVSPath=[toPath stringByAppendingPathComponent:relativePath];
            if ([self createAllDirectoriesAtPath:[targetCVSPath stringByDeletingLastPathComponent] attributes:nil]) {
                [self movePath:[fromPath stringByAppendingPathComponent:relativePath] toPath:targetCVSPath handler:nil];
            }
        }
    }
}


@end
