/* CvsAddRequest.h created by dagaeff on Wed 16-Jun-1999 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <CvsRequest.h>



@interface CvsAddRequest : CvsRequest
{
    BOOL	forcesBinary;
#ifdef JA_PATCH
    NSMutableSet *childrenRequests;
    BOOL childrenRequestsSucceeded;
#endif
}

+ cvsAddRequestWithFiles:(NSArray *)someFiles;
+ cvsAddRequestWithFiles:(NSArray *)someFiles forcesBinary:(BOOL)flag;
+ cvsAddRequestAtPath:(NSString *)aPath files:(NSArray *)someFiles;
+ cvsAddRequestAtPath:(NSString *)aPath files:(NSArray *)someFiles forcesBinary:(BOOL)flag;

- (void) setForcesBinary:(BOOL)flag;
- (BOOL) forcesBinary;

@end
