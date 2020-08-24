/* PreferencesController.h created by ja on Thu 21-Aug-1997 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <AppKit/AppKit.h>

@interface PreferencesController : NSObject
{
    IBOutlet NSPanel		*panel;
//    id  pathsController;
    IBOutlet NSTextField    *cvsPathTextField;
    //id showRepositoryFilesSwitch;
    IBOutlet NSTextField     *opendiffUnixPathField;
    IBOutlet NSFormCell     *maxParallelRequestsField;
    IBOutlet NSButton		*startupOpenSwitch;
    IBOutlet NSButton		*cvsTemplateUseSwitch;
    IBOutlet NSButton		*cvsTemplateFilteringSwitch;
    IBOutlet NSButton           *alertTimeBeepButton;
    IBOutlet NSButton           *alertTimeDisplayButton;
    IBOutlet NSFormCell         *alertTimeIntervalFormCell;
    IBOutlet NSButton           *cvsEditorsAndWatchersEnabledButton;
    IBOutlet NSButton           *overrideCvsWrappersFileInHomeDirectoryButton;
    IBOutlet NSButton           *displayCvsErrorsButton;
    IBOutlet NSTextField        *defaultWorkAreaPathTextField;
    NSControl                   *isEditingControl;
    id                          (previousObjectValue);
}
- (IBAction)save:(id)sender;
- (IBAction)cancel:(id)sender;
- (IBAction)cvsEditorsAndWatchersEnabledButtonChanged:(id)sender;
- (IBAction)overrideCvsWrappersFileInHomeDirectoryButtonChanged:(id)sender;
- (IBAction)featuresChanged:(id)sender;


@end
