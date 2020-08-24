/* CvsInitRequest.h created by stephane on Mon 06-Sep-1999 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <CvsRequest.h>


//
// This cvs request creates a new local repository on a given path
// If newRepositoryPath is a path for an existing repository, no new repository is created
//
// Request:
// 		cvs -d <newRepositoryPath> init
// Result:
//		Dictionary allowing registration of a repository
//

@interface CvsInitRequest : CvsRequest
{
    NSString	*newRepositoryPath;
}

+ (CvsInitRequest *) cvsInitRequestWithPath:(NSString *)initPath;
    // initPath must be an absolute path; it can point to a new directory that will be created.
    // initPath validity is not checked before execution. 

- (NSDictionary *) result;
    // Returns a dictionary allowing registration of a repository with call [CvsRepository repositoryWithProperties:]
    // Currently returns two key-value pairs:
    // path:	<newRepositoryPath>
    // method:	local

- (NSString *) newRepositoryPath;

@end
