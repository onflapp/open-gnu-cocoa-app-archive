/* CvsCommitRequest.h created by vincent on Mon 24-Nov-1997 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <CvsRequest.h>

@interface CvsCommitRequest : CvsRequest
{
  NSString* message;
    NSString	*revision;
}

+ (id) cvsCommitRequestForFiles: (NSArray*) files inPath:(NSString *)aPath message: (NSString*) mesgString;

- (void) setMessage: (NSString*) aString;
- (void) setRevision:(NSString *)aRevision; // Used to force commit to a specific revision (normally after a cvs add)

@end
