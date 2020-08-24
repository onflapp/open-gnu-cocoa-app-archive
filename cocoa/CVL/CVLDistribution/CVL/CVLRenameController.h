/* CVLRenameController.h created by stephane on Wed 20-Oct-1999 */

// Copyright (c) 1997-2000, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>


@class NSView;
@class NSButtonCell;
@class SenOpenPanelController;


@interface CVLRenameController : NSObject
{
    IBOutlet NSView					*accessoryView;
    IBOutlet NSButtonCell			*commitButtonCell;
    IBOutlet SenOpenPanelController	*savePanelController;
    NSString						*oldPathName;
    NSString						*newPathName;
    NSString						*workAreaRootPath;
    BOOL							renaming;
}

+ (id) sharedInstance;
// As we are using a shared instance, we can invoke renaming only once at a time
	
- (void) renameFileNamed:(NSString *)aName fromWorkArea:(NSString *)rootFilePath;
// aName is a path relative to rootFilePath

@end
