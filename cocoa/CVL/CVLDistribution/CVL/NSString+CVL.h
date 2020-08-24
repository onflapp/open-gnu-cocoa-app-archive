/* NSString+CVL.h created by stephane on Wed 31-Oct-2001 */

// Copyright (c) 1997-2000, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <Foundation/Foundation.h>


@interface NSString(CVL)

- (NSString *) cvlFilenameForRevision:(NSString *)aVersion;
- (NSString *) cvlFilenameForDate:(NSString *)aDate;
- (BOOL) cvlFilenameMatchesShellPatterns:(NSArray *)patterns;
- (NSString *)removeTrailingWhiteSpace;

@end
