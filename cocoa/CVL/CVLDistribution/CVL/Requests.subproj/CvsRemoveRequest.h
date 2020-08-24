/* CvsRemoveRequest.h created by ja on Sat 24-Jul-1999 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <CvsRequest.h>


@interface CvsRemoveRequest : CvsRequest
{
}

+ (CvsRemoveRequest *) removeRequestAtPath:(NSString *) aPath files:(NSArray *)someFiles;

@end
