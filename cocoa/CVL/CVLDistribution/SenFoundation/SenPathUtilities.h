/*$Id: SenPathUtilities.h,v 1.4 2004/12/17 09:59:51 william Exp $*/

// Copyright (c) 1997-2003, Sen:te (Sente SA).  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <Foundation/Foundation.h>
#import "SenFoundationDefines.h"

#if !defined(GNUSTEP) && !defined(RHAPSODY)

extern NSString *FolderManagerException;
extern NSString *CFURLException;


// see Folders.h for parameter constants
SENFOUNDATION_EXPORT NSString *SenSearchPathForDirectoriesInDomains(OSType folderType, short vRefNum);

#endif

@interface NSString (SenPathUtilities)
+ (NSString *) temporaryPathWithName:(NSString *) aName forApplicationIdentifier:(NSString *) anApplicationIdentifier;
+ (NSString*) uniqueTemporaryPathWithName:(NSString *) aName forApplicationIdentifier:(NSString *) anApplicationIdentifier;
+ (NSString*) uniqueFilenameWithPrefix:(NSString *)aName inDirectory:(NSString *)aDirectory;
@end
