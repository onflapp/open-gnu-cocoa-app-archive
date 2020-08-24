
// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

@class NSString;

// I know it's not nice to define NSStrings like this, but it's the only easy way
// I found to make it work on MacOS X Server with ProjectBuilder, because file
// is also used in CVL project. I couldn't hack Makefiles to do this.
#ifndef IMPORTED_CVLEditorClientConnectionName
NSString	*CVLEditorClientConnectionName = @"CVLEditorClientConnectionName";
#define IMPORTED_CVLEditorClientConnectionName
#else
extern NSString	*CVLEditorClientConnectionName;
#endif


@protocol CVLEditorClient
- (BOOL) showCommitPanelWithSelectedFilesUsingTemplateFile:(NSString *)aTemplateFile;
@end
