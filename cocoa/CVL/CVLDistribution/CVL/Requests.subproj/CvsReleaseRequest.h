/* CvsReleaseRequest.h created by stephane on Fri 22-Oct-1999 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <CvsRequest.h>


@class NSFileHandle;


//
// This cvs request checks that the work area has no uncommitted changes and then
// tells the repository that the work area is no longer in use
// It can also delete the work area
//
// Request:
// 		cvs release [-d] workAreaPath
// Result:
//		Request returns no result
//

@interface CvsReleaseRequest : CvsRequest
{
    NSString		*workAreaPath;
    BOOL			deleteWorkArea;
    NSFileHandle	*cvsInput;
    NSMutableString	*summedOutput;
    id				handler; // Not retained
    BOOL			failed;
}

+ (CvsReleaseRequest *) cvsReleaseRequestWithPath:(NSString *)rootPath deleteWorkArea:(BOOL)flag handler:(id)aHandler;
	// aHandler must implement request:releaseWorkAreaContainingModifiedFilesNumber:; it is not retained
	// If no handler is provided, release will take effect

- (NSString *) workAreaPath;
- (BOOL) deleteWorkArea;

@end

@interface NSObject(CvsReleaseRequestHandler)
- (BOOL) request:(CvsReleaseRequest *)aRequest releaseWorkAreaContainingModifiedFilesNumber:(unsigned)aNumber;
@end
