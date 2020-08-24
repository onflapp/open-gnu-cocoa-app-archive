/* CvsTagRequest.h created by vincent on Wed 26-Nov-1997 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <CvsRequest.h>


@interface CvsTagRequest : CvsRequest
{
    NSString* tag;
    BOOL isBranchTag;
    BOOL moveIfExists;
    BOOL tagIfUnmodified;
}

+ (id) cvsTagRequestForFiles: (NSArray*) someFiles
                      inPath: (NSString*) aPath
                         tag: (NSString*) tagString
                    isBranch: (BOOL) bFlag
                moveIfExists: (BOOL) mFlag
             tagIfUnmodified: (BOOL) uFlag;

- (void) setTag: (NSString*) aString;
- (void) setIsBranchTag: (BOOL) aFlag;
- (void) setMoveIfExists: (BOOL) aFlag;
- (void) setTagIfUnmodified: (BOOL) aFlag;
@end
