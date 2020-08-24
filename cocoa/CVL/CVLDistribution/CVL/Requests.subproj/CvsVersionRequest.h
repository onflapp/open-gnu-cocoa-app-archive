/* CvsVersionRequest.h created by stephane on Thu 02-Sep-1999 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <CvsRequest.h>


@class NSMutableDictionary;


//
// This cvs request asks for cvs version string
//
// Request:
// 		cvs --version
// Result:
//		Unparsed version and copyright string
//

@interface CvsVersionRequest : CvsRequest
{
    NSMutableDictionary	*result;
}

+ (CvsVersionRequest *) cvsVersionRequest;

- (NSDictionary *) result;
    // Currently returns one key-value pair:
    // version:	<raw output>

@end
