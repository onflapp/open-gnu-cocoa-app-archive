/*
	$id$
*/

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>


@class CVLFile;
@class SenFormPanelController;
@class NSTextField;
@class CvsCommitPanelController;
@class NSDrawer;
@class SelectorRequest;
@class CvsUpdateRequest;
@class BrowserController;

@interface WorkAreaViewer:NSObject
{
	id window;
	id viewHolder;
    id filterProvider;
    id filterButtonsMatrix;
	
	id	(browserViewer);
	id	(listViewer);
	id	(currentViewer);

    id processesButton;
    IBOutlet NSTextField *repositoryRootPathTextField;
    CVLFile * rootFile;
	BOOL windowIsMiniaturized;
    id filterPopup;
    IBOutlet NSDrawer    *filterDrawer;
    CvsCommitPanelController *cvsCommitPanelController;
    BOOL viewerIsClosing;
}

+ (WorkAreaViewer*) viewerForPath: (NSString*) aPath;
+ (WorkAreaViewer*) viewerForFile: (CVLFile *) aFile;

- initForFile: (CVLFile *) aFile;

- (void)showWindowWithDictionary:(NSDictionary *)dict;
- (NSDictionary *)stateDictionary;
#if 0
- (IBAction)viewerFrameSizeChanged:(id)sender;
#endif

- (IBAction) filterPreselectionPopped:(id)sender;
- (void)setCustomFiles;

- (IBAction) show:(id)sender;
- (IBAction) setBrowserView:(id)sender;
- (IBAction) setListView:(id)sender;
- (id) viewer;

- (void)selectFiles:(NSSet *)someFiles;
- (NSArray *)selectedPaths;

- (NSString *)rootPath;
- (CVLFile *)rootFile;

- (IBAction) removeStickyAttributesAndUpdate:(id)sender;
- (IBAction) restoreWorkAreaFiles:(id)sender;
- (IBAction) replaceWorkAreaFiles:(id)sender;
- (IBAction) openVersionsInTemporaryDirectory:(id)sender;
- (IBAction) saveVersionAs:(id)sender;

- (IBAction) updateSelectedFiles:(id)sender;
- (IBAction) updateWorkArea:(id)sender;

- (IBAction) commitSelectedFiles:(id)sender;
- (IBAction) commitWorkArea:(id)sender;
- (IBAction) closeWorkArea:(id)sender;

- (IBAction) tagSelectedFiles:(id)sender;
- (IBAction) tagWorkArea:sender;

- (IBAction) diffSelectedFiles:(id)sender;
- (IBAction) addSelectedFiles:(id)sender;
- (IBAction) addSelectedFilesAsBinary:(id)sender;
- (IBAction) removeSelectedFiles:(id)sender;
- (IBAction) delete:(id)sender;
- (IBAction) deleteAndUpdateSelectedFiles:(id)sender;
- (IBAction) reinstateFilesMarkedForRemoval:(id)sender;
- (IBAction) refreshSelectedFiles:(id)sender;

- (void) retrieveSelectedFilesVersionForAction:(int)anActionType;
- (void) refreshTheseSelectedFiles:(NSArray *)someSelectedFiles;
- (NSArray *) filenamesOfFilesMarkedForRemovalInSelectedFiles;
- (NSArray *) filenamesOfFilesNotMarkedForRemovalInSelectedFiles;
- (NSArray *) filesMarkedForRemovalInCVLFiles:(NSArray *)someCVLFiles;
- (NSArray *) directoriesMarkedForRemovalInCVLFiles:(NSArray *)someCVLFilesMarkedForRemoval;
- (NSArray *) emptyDirectoriesInCVLFiles:(NSArray *)someCVLFiles;
- (void) deleteFiles:(NSArray *)theRelativeSelectedPaths andUpdate:(BOOL)performUpdate;
- (void) deleteDS_StoreFilesIn:(NSArray *)someCVLFiles;

//- (IBAction) renameSelectedFile:(id)sender;
- (IBAction) releaseWorkArea:(id)sender;

//- (void) doRetrieveFile:(NSString *)filePath inPath:(NSString *)path withRevision:(NSString *)revision date:(NSString *)dateString outputFile:(NSString *)fullPath;

- (IBAction) revealSelectedFiles:(id)sender;
- (IBAction) revealWorkArea:(id)sender;

- (void) toggleWatchActionForTag:(int)anActionTag;

- (IBAction) turnOnEditing:(id)sender;
- (IBAction) turnOffEditing:(id)sender;
- (IBAction) turnOnWatchingForAllActions:(id)sender;
- (IBAction) turnOffWatchingForAllActions:(id)sender;
- (IBAction) turnOnWatchingForEditAction:(id)sender;
- (IBAction) turnOffWatchingForEditAction:(id)sender;
- (IBAction) turnOnWatchingForUneditAction:(id)sender;
- (IBAction) turnOffWatchingForUneditAction:(id)sender;
- (IBAction) turnOnWatchingForCommitAction:(id)sender;
- (IBAction) turnOffWatchingForCommitAction:(id)sender;
- (IBAction) turnOnWatchingForNoActions:(id)sender;
- (BOOL) checkForModificationsInFiles:(NSArray *)someFiles;

- (BOOL) validateAddSelectedFiles;
- (BOOL) validateDeleteAndUpdateSelectedFiles;
- (BOOL) validateReinstateFilesMarkedForRemoval;
- (BOOL) validateRemoveSelectedFiles;


- (IBAction) restoreWorkAreaVersion:(id)sender;
- (IBAction) toggleFilterDrawer:(id)sender;
- (IBAction) openWithApplicationSelectedFiles:(id)sender;
- (void) updateTheRecentMenu;
    
- (NSString *)getTopMostDirectoryContaining:(NSArray *)someSelectedPaths;
- (BOOL) isFilterDrawerOpen;
- (CvsCommitPanelController *)cvsCommitPanelController;
- (BOOL) showCommitPanelWithSelectedFilesUsingTemplateFile:(NSString *)aTemplateFile;
- (void) commitCVLFiles:(NSArray *)someCVLFiles;
- (SelectorRequest *) returnARefreshRequestIfNeeded:(NSArray *)someCVLFiles;
- (CvsUpdateRequest *) returnAnUpdateRequestIfNeeded:(NSArray *)someCVLFiles;
- (CvsUpdateRequest *) returnAnUpdateRequestForEmptyDirectories:(NSArray *)someCVLFiles;
- (void) clearControllerCacheForWorkArea:(NSString *)aWorkAreaPath;
- (void) checkTheTagsAndUpdate:(WorkAreaViewer *)aViewer;

@end
