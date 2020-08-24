//
//  CvsImportController.h
//  CVL
//
//  Created by William Swats on 06/01/2005.
//  Copyright 2005 Sente SA. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class CvsRepository;
@class CvsLocalRepository;
@class CvsPserverRepository;
@class SenOpenPanelController;
@class CvsImportRequest;


@interface CvsImportController : NSWindowController
{
	IBOutlet NSButton				*clearButton;
	IBOutlet NSButton				*cancelButton;
	IBOutlet NSButton				*importButton;
	IBOutlet NSObjectController		*cvsImportControllerAlias;
	IBOutlet SenOpenPanelController *sourceOpenPanelController;
	IBOutlet SenOpenPanelController *repositoryOpenPanelController;
	IBOutlet NSTextField			*importRepositoryPathTextField;
	IBOutlet NSTextField			*cvsRootTextField;
	IBOutlet NSTextField			*sourcePathTextField;
	IBOutlet NSTextField			*repositorySubpathTextField;
	IBOutlet NSTextField			*repositoryDirectoryTextField;
	IBOutlet NSTextField			*moduleNameTextField;
	IBOutlet NSTextField			*importMessageTextField;
	IBOutlet NSTextField			*releaseTagTextField;
	IBOutlet NSTextField			*vendorTagTextField;
	
	CvsRepository		*importRepository;
	NSMutableDictionary *cvsImportProperties;
	NSNumber			*isClearButtonEnabled;
	NSNumber			*isImportButtonEnabled;
	NSNumber			*isRepositorySubpathButtonEnabled;
	NSNumber			*isAddedToTheModulesFile;
	NSColor				*moduleNameLabelColor;
	NSString			*cvsRoot;
	BOOL				 isNewImportRepository;
}


- (int)showAndRunModal;

- (IBAction)cancel:(id)sender;
- (IBAction)import:(id)sender;
- (IBAction)clear:(id)sender;

- (NSButton *)clearButton;
- (NSButton *)importButton;

- (void)addObservers;

- (int)showCvsImportPanel;

- (void)updateClearButton;
- (void)updateImportButton;
- (void)updateRepositorySubpathButton;

- (NSNumber *)isClearButtonEnabled;
- (void)setIsClearButtonEnabled:(NSNumber *)newIsClearButtonEnabled;

- (NSNumber *)isImportButtonEnabled;
- (void)setIsImportButtonEnabled:(NSNumber *)newIsImportButtonEnabled;

- (NSNumber *)isRepositorySubpathButtonEnabled;
- (void)setIsRepositorySubpathButtonEnabled:(NSNumber *)newIsRepositorySubpathButtonEnabled;

- (NSNumber *)isAddedToTheModulesFile;
- (void)setIsAddedToTheModulesFile:(NSNumber *)anIsAddedToTheModulesFile;

- (NSColor *)moduleNameLabelColor;
- (void)setModuleNameLabelColor:(NSColor *)aModuleNameLabelColor;

- (NSMutableDictionary *)cvsImportProperties;
- (void)setCvsImportProperties:(NSMutableDictionary *)newRepositoryProperties;

- (CvsRepository *)importRepository;
- (void)setImportRepository:(CvsRepository *)anImportRepository;

- (NSString *)cvsRoot;
- (void)setCvsRoot:(NSString *)aCvsRoot;


- (void)importIntoRepository:(CvsRepository *)aRepository;
- (BOOL)validateCvsImportProperties;
- (BOOL)validateModuleProperty;
- (BOOL)areCvsImportPropertiesComplete;
- (void)updateRepositoryDirectory;
- (void)updateModuleName;
- (void)updateImportRepositoryPath;
- (NSString *)repositorySubpathFrom:(NSString *)aPath;
- (BOOL)isModuleNameInUse:(NSString *)aModuleName;
- (void)addNewModuleName:(CvsImportRequest *)anImportRequest;
- (NSString *)modulePath;


@end
