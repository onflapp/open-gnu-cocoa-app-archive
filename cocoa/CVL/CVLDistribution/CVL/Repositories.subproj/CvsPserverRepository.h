/* CvsPserverRepository.h created by ja on Mon 16-Feb-1998 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <CvsRemoteRepository.h>


@class CvsRequest;



@interface CvsPserverRepository : CvsRemoteRepository
{
    CvsRequest *loginRequest;
    BOOL isLoggedIn;
    NSString *password;
}

@end
