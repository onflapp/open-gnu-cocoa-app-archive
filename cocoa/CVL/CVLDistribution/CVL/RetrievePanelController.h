
// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "RestoreRetrieveController.h"

#import <AppKit/AppKit.h>


@class CVLFile;

#define CVL_RETRIEVE_REPLACE 0
#define CVL_RETRIEVE_RESTORE 1
#define CVL_RETRIEVE_OPEN 2
#define CVL_RETRIEVE_SAVE_AS 3
#define CVL_REMOVE_STICKY_ATTRIBUTES 4

@interface RetrievePanelController : RestoreRetrieveController
{
    IBOutlet NSTabView      *headingTabView;
    IBOutlet NSTextField    *revisionTextField;
    NSString                *selectedFilename;
    NSArray                 *selectedFilenames;
    NSString                *selectedDirectory;
    int                     actionType;
}
+ sharedRetrievePanelController;

- (IBAction) replaceWorkAreaFiles:(id)sender;
- (IBAction) restoreWorkAreaFiles:(id)sender;
- (IBAction) openVersionInTemporaryDirectory:(id)sender;
- (IBAction) saveVersionAs:(id)sender;
- (IBAction) performButtonAction:(id)sender;

- (void) removeStickyAttributesAndUpdateSelectedFiles;
- (void) retrieveVersionForFiles:(NSArray *)theRelativeSelectedPaths inDirectory:(NSString *)aPath forAction:(int)anActionType;
- (void)retrieveWorkAreaFilesForAction:(int)anActionType;
- (int) retrieveWorkAreaFiles:(NSArray *)theSelectedFilenames inDirectory:(NSString *)theSelectedDirectory withVersion:(NSString *)aVersion withDate:(NSString *)aDateString withHead:(BOOL)useHead forAction:(int)anActionType;

- (BOOL) askUserIfHeWantsToReplaceFiles:(NSArray *)theSelectedFilenames inDirectory:(NSString *)theSelectedDirectory withVersion:(NSString *)aVersion withDate:(NSString *)aDateString withHead:(BOOL)useHead;
- (BOOL) askUserIfHeWantsToRestoreFiles:(NSArray *)theSelectedFilenames inDirectory:(NSString *)theSelectedDirectory withVersion:(NSString *)aVersion withDate:(NSString *)aDateString withHead:(BOOL)useHead;

- (NSString *)revisionFromTextField;

@end
