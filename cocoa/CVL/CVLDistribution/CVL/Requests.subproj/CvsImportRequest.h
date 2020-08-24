/* CvsImportRequest.h created by vincent on Wed 26-Nov-1997 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <CvsRequest.h>

@interface CvsImportRequest : CvsRequest
{
    NSString* repositorySubpath;
    NSString* releaseTag;
    NSString* vendorTag;
    NSString* message;
}

+ (id) cvsImportRequestForSubpath: (NSString*) aRepositorySubpath
                    inRepository: (CvsRepository *)aRepository
                      importPath: (NSString *)aPath
                      releaseTag: (NSString*) rTag
                       vendorTag: (NSString*) vTag
                         message: (NSString*) mesgString;

- (void) setRepositorySubpath: (NSString*) aString;
- (void) setReleaseTag: (NSString*) aString;
- (void) setVendorTag: (NSString*) aString;
- (void) setMessage: (NSString*) aString;

@end
