//
//  AddRepositoryController.h
//  CVL
//
//  Created by William Swats on 10/28/2004.
//  Copyright 2004 Sente SA. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class CvsRepository;
@class CvsLocalRepository;
@class CvsPserverRepository;
@class RepositoryProperties;
@class SenOpenPanelController;

@interface AddRepositoryController : NSWindowController 
{
	IBOutlet NSButton *clearButton;
	IBOutlet NSButton *cancelButton;
	IBOutlet NSButton *addButton;
	IBOutlet NSTabView *repositoryTypeTabView;
	IBOutlet NSObjectController *AddRepositoryControllerAlias;
	IBOutlet RepositoryProperties *localRepositoryProperties;
	IBOutlet RepositoryProperties *pserverRepositoryProperties;
	IBOutlet RepositoryProperties *bonjourRepositoryProperties;
	IBOutlet RepositoryProperties *otherRepositoryProperties;
			
	RepositoryProperties *repositoryProperties;

	NSNumber *isClearButtonEnabled;
	NSNumber *isAddButtonEnabled;
	
	NSString *templateFile;
	NSArray *committingFiles;
	int	modalResult;

	IBOutlet NSPopUpButton 	*serverListPopUpButton;
	IBOutlet NSTextField 	*searchProgressTextField;
	NSNetServiceBrowser *domainBrowser;
	NSNetServiceBrowser *serviceBrowser;
	NSMutableSet    *bonjourDomains;
	NSMutableArray  *allServices; // Lazy, in this first implementation
	NSMutableArray  *servicesResolved; // Lazy, in this first implementation
	NSString        *currentDomain;
	BOOL hasPerformSetup;
	BOOL isSearching;
	BOOL isResolvingServices;
}

- (int)showAndRunModal;

- (IBAction)cancel:(id)sender;
- (IBAction)add:(id)sender;
- (IBAction)clear:(id)sender;
- (IBAction)openLocalRepositoryPath:(id)sender;
- (IBAction)openCvsExecutablePath:(id)sender;

- (NSButton *)clearButton;
- (NSButton *)addButton;

- (void)addObservers;
- (void)removeObservers;
- (void)switchRepositoryPropertiesToMatchSelectedTab;

- (int)showAddRepositoryPanel;
-(NSString *)repositoryType;

- (void)updateClearButton;
- (void)updateAddButton;

- (NSNumber *)isClearButtonEnabled;
- (void)setIsClearButtonEnabled:(NSNumber *)newIsClearButtonEnabled;

- (NSNumber *)isAddButtonEnabled;
- (void)setIsAddButtonEnabled:(NSNumber *)newIsAddButtonEnabled;

- (RepositoryProperties *)repositoryProperties;
- (void)setRepositoryProperties:(RepositoryProperties *)newRepositoryProperties;


-(IBAction)selectRepository:(id)sender;
-(void)updateUI;

	// NSNetServiceBrowser delegate methods...
- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser
             didNotSearch:(NSDictionary *)errorDict;
-(void)netServiceBrowserWillSearch:(NSNetServiceBrowser *)aNetServiceBrowser;
-(void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser *)aNetServiceBrowser;

	// We're not doing multiple domains at the moment...
	//-(void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser
	//    didFindDomain:(NSString *)domainString moreComing:(BOOL)moreComing;
-(void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser
		  didFindService:(NSNetService *)aNetService moreComing:(BOOL)moreComing;
-(void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser
		didRemoveService:(NSNetService *)aNetService moreComing:(BOOL)moreComing;

-(void)performSetup;

@end
