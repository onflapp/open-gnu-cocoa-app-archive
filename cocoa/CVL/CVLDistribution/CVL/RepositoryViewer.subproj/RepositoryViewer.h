// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <AppKit/AppKit.h>

@class NSDictionary;
@class NSTableView;
@class NSTabView;
@class NSTextView;
@class NSView;
@class NSButton;
@class NSTextField;
@class CvsRepository;
@class NSDateFormatter;
@class CvsCommitPanelController;
@class AddRepositoryController;
@class CvsImportController;

@interface RepositoryViewer : NSWindowController
{
    IBOutlet NSTableView	*repositoryTableView;
    IBOutlet NSTabView		*tabView;
	NSTextView				*textView;
	IBOutlet NSTextView		*modulesTextView;
	IBOutlet NSTextView		*ignoredFilesTextView;
	IBOutlet NSTextView		*cvsWrappersTextView;
    IBOutlet NSTextField	*repositoryRootTextField;
    IBOutlet NSTextField	*repositoryCompressionLevelTextField;
    IBOutlet NSTextField	*repositoryCVSExecutablePathTextField;
    IBOutlet NSTableView	*envTableView;
    IBOutlet NSView			*noRepositoryView;
    IBOutlet NSSplitView	*repositorySplitView;
    IBOutlet NSBox			*topBox;
    IBOutlet NSBox			*bottomBox;
    IBOutlet NSButton		*removeButton;
    IBOutlet NSButton		*checkoutButton;
    IBOutlet NSButton		*importButton;
    IBOutlet NSButton		*openWorkareaButton;
	
    NSButton				*saveRepositoryParamsButton;
    NSButton				*validateRepositoryParamsButton;
    NSButton				*revertRepositoryParamsButton;				
    IBOutlet NSButton		*saveModulesButton;
    IBOutlet NSButton		*validateModulesButton;
    IBOutlet NSButton		*revertModulesButton;
    IBOutlet NSButton		*saveIgnoredFilesButton;
    IBOutlet NSButton		*validateIgnoredFilesButton;
    IBOutlet NSButton		*revertIgnoredFilesButton;
    IBOutlet NSButton		*saveCVSWrappersButton;
    IBOutlet NSButton		*validateCVSWrappersButton;
    IBOutlet NSButton		*revertCVSWrappersButton;
	
    IBOutlet NSButton		*addEnvVariableButton;
    IBOutlet NSButton		*removeEnvVariableButton;
    BOOL					initializingTabs;
    NSTextField				*checkoutDateTextField;
    CvsCommitPanelController *cvsCommitPanelController;
	CvsRepository			*mySelectedRepository;
	AddRepositoryController	*addRepositoryController;
	CvsImportController		*cvsImportController;
	unsigned				 aCounter;
}

+ (RepositoryViewer *) sharedRepositoryViewer;

- (IBAction) addRepository:(id)sender;
- (IBAction) removeRepository:(id)sender;
- (IBAction) newRepository:(id)sender;

- (IBAction)updateCompressionLevel:(id)sender;
- (IBAction)updateCVSExecutablePath:(id)sender;

- (IBAction) repositoryCheckout:(id)sender;
- (IBAction) repositoryImport:(id)sender;
- (IBAction) openRepositoryWorkarea:(id)sender;

- (IBAction) saveRepositoryParams:(id)sender;
- (IBAction) revertRepositoryParams:(id)sender;
- (IBAction) validateRepositoryParams:(id)sender;

- (IBAction) addEnvironmentVariable:(id)sender;
- (IBAction) removeEnvironmentVariable:(id)sender;

- (void) importIntoRepository:(CvsRepository *)aRepository importInfo:(NSDictionary *)importInfo;
    // importInfo can contains string values for keys module, sourcePath, releaseTag, vendorTag, message

- (BOOL) showCommitPanelWithSelectedFilesUsingTemplateFile:(NSString *)aTemplateFile;
- (CvsCommitPanelController *)cvsCommitPanelController;
- (void) commitFiles:(NSArray *)someFiles;
- (NSArray *)selectedPaths;
- (CvsRepository *) selectedRepository;
- (NSString *)getFileContentsForFilename:(NSString *)aName;

@end
