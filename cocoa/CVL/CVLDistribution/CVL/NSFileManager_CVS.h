/* NSFileManager_CVS.h created by ja on Fri 04-Feb-2000 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <AppKit/AppKit.h>

@interface NSFileManager (CVS)

- (void)copyCVSAdministrativeFilesFromPath:(NSString *)fromPath to:(NSString *)toPath;
- (void)moveCVSAdministrativeFilesFromPath:(NSString *)fromPath to:(NSString *)toPath;

@end
