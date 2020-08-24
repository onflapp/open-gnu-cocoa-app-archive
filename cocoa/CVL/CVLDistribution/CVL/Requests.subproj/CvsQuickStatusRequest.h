/* CvsQuickStatusRequest.h created by stephane on Tue 05-Oct-1999 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <CvsRequest.h>


//
// This cvs request gets file status from given path
// It simply returns the statuses of contents, nothing more, unlike CvsLogRequest
// In fact it is an update which modifies nothing in the work area (-n flag)
//
// Request:
// 		cvs -nq update
// Result:
//		Dictionary of (full) paths with their corresponding status: U, A, R, M, C, ?, u
//


@class NSMutableDictionary;


@interface CvsQuickStatusRequest : CvsRequest
{
    NSMutableDictionary	*fileStatuses;
    NSMutableString		*parsingBuffer;
    NSMutableString		*errorParsingBuffer;
    BOOL				updateAborted;
}

+ (CvsQuickStatusRequest *) cvsQuickStatusRequestFromPath:(NSString *)aPath;
// Request is quiet

- (NSDictionary *) result;

- (BOOL) updateAborted;
- (void)setUpdateAborted:(BOOL)aState reason:(NSString *)aReason displayAlert:(BOOL)isDisplayed;

@end
