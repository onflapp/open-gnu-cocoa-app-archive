/* CvsLoginRequest.h created by ja on Thu 04-Dec-1997 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <CvsRequest.h>


@interface CvsLoginRequest : CvsRequest
{
    NSString *password;
    BOOL allowRepositoryEditing;
    NSFileHandle *cvsInput;
    NSMutableString *summedOutput;
}

+ (CvsLoginRequest *)cvsLoginRequest;
+ (CvsLoginRequest *)cvsLoginRequestForRepository:(CvsRepository *)aRepository;
+ (CvsLoginRequest *)cvsLoginRequestForRepository:(CvsRepository *)aRepository withPassword:(NSString *)password;

- (void)setPassword:(NSString *)passwordString;
@end
