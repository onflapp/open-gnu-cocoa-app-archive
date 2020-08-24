//
//  CvsImportController.m
//  CVL
//
//  Created by William Swats on 06/01/2005.
//  Copyright 2005 Sente SA. All rights reserved.
//

#import "CvsImportController.h"

#import "CVLDelegate.h"
#import "CvsRepository.h"
#import "RepositoryViewer.h"
#import "CvsModule.h"
#import "CvsCommitRequest.h"
#import "CvsImportRequest.h"
#import "SelectorRequest.h"

#import <SenFoundation/SenFoundation.h>
#import <SenOpenPanelController.h>


@implementation CvsImportController


- (id)initWithWindowNibName:(NSString *)windowNibName
    /*" This is the desinated initializer for this class. Since this is a 
        subclass of NSWindowController we first call super's implementation. 
        That implementation returns an NSWindowController object initialized 
        with windowNibName, the name of the nib file 
        (minus the “.nib” extension) that archives the receiver’s window. The 
        windowNibName argument cannot be nil. Sets the owner of the nib file to 
        the receiver. The default initialization turns on cascading, sets the 
        shouldCloseDocument flag to NO, and sets the autosave name for the 
        window’s frame to an empty string.

        Here in this subclass we set the autosave name for the window’s frame to 
        the name of the window nib name and create an empty mutable dictionary
		to save CVS import properties. Next we select 
		"Add the following module name..." checkbox to be on.
    "*/
{
    self = [super initWithWindowNibName:windowNibName];
    if ( self != nil ) {
        [self setWindowFrameAutosaveName:windowNibName];
		cvsImportProperties = [[NSMutableDictionary alloc] initWithCapacity:10];
		[self setIsAddedToTheModulesFile:[NSNumber numberWithBool:YES]];
    }
    return self;
}

- (void) dealloc
    /*" This method releases our instance variables.
    "*/
{
	RELEASE(isClearButtonEnabled);
	RELEASE(isImportButtonEnabled);
	RELEASE(isRepositorySubpathButtonEnabled);
	RELEASE(isAddedToTheModulesFile);
	RELEASE(importRepository);
	RELEASE(cvsImportProperties);
	RELEASE(moduleNameLabelColor);
	RELEASE(cvsRoot);
	
    [super dealloc];
}

- (int)showAndRunModal
    /*" This method displays our window, updates it and runs it inside a modal 
        loop. After the modal loop is terminated the window is closed and this 
        method returns the result of the modal loop. That result is either 
        NSOKButton or NSCancelButton depending whether the user clicked on the 
        #Import button or the #Cancel button.

        This method should not be called outside of this class.
    "*/
{
	int	modalResult = NSCancelButton;

    [self showWindow:self];
    
    modalResult = [NSApp runModalForWindow:[self window]];
    [[self window] orderOut:self];
    return modalResult;
}

- (IBAction)cancel:(id)sender
    /*" This is an action method that terminates the modal loop with a return 
        value of NSCancelButton.
    "*/
{
	SEN_ASSERT_NOT_NIL(cvsImportControllerAlias);

	[cvsImportControllerAlias commitEditing];
    [NSApp stopModalWithCode:NSCancelButton];
}


- (IBAction)import:(id)sender
    /*" This is an action method that terminates the modal loop with a return 
        value of NSOKButton.
    "*/
{
	SEN_ASSERT_NOT_NIL(cvsImportControllerAlias);
	
	[cvsImportControllerAlias commitEditing];
    [NSApp stopModalWithCode:NSOKButton];
}

- (IBAction)clear:(id)sender
    /*" This action method clears all the text fields in the tab view in the 
		CVS Import Panel. It does this by removing the corresponding 
		properties, then the binding systems takes over and blanks out the text 
		fields.
    "*/
{
	[cvsImportProperties removeAllObjects];
}

- (NSButton *)clearButton
	/*" This method returns the pointer to the clear button in the CVS Import 
		Panel.
	"*/
{
	return clearButton;
}

- (NSButton *)importButton
	/*" This method returns the pointer to the import button in the CVS Import 
		Panel.
	"*/
{
	return importButton;
}

- (void)windowDidLoad
    /*" This method allows subclasses of NSWindowController to perform any 
        required tasks after the window owned by the receiver has been loaded. 
        The default implementation does nothing.

        Here we check to make sure the outlets are connected, add observers 
		of the CVS properties and set the represented objects of the textfields 
		that we are interested in observing so we can update the buttons at the 
		bottom of the import panel. The represented objects are the same as the 
		keys into the cvsImportProperties dictionary.
    "*/
{	
	NSCell		*aCell				= nil;

    SEN_ASSERT_NOT_NIL(importButton);
    SEN_ASSERT_NOT_NIL(clearButton);
    SEN_ASSERT_NOT_NIL(cancelButton);
    SEN_ASSERT_NOT_NIL(cvsRootTextField);
    SEN_ASSERT_NOT_NIL(sourcePathTextField);
    SEN_ASSERT_NOT_NIL(repositorySubpathTextField);
    SEN_ASSERT_NOT_NIL(repositoryDirectoryTextField);
    SEN_ASSERT_NOT_NIL(moduleNameTextField);
    SEN_ASSERT_NOT_NIL(importMessageTextField);
    SEN_ASSERT_NOT_NIL(releaseTagTextField);
    SEN_ASSERT_NOT_NIL(vendorTagTextField);
	
	[self addObservers];	
	aCell = [sourcePathTextField cell];
	[aCell setRepresentedObject:@"sourcePath"];
	aCell = [repositorySubpathTextField cell];
	[aCell setRepresentedObject:@"repositorySubpath"];
	aCell = [repositoryDirectoryTextField cell];
	[aCell setRepresentedObject:@"repositoryDirectory"];
	aCell = [moduleNameTextField cell];
	[aCell setRepresentedObject:@"moduleName"];
	aCell = [importMessageTextField cell];
	[aCell setRepresentedObject:@"importMessage"];
	aCell = [releaseTagTextField cell];
	[aCell setRepresentedObject:@"releaseTag"];
	aCell = [vendorTagTextField cell];
	[aCell setRepresentedObject:@"vendorTag"];
}

- (int)showCvsImportPanel
    /*" This is the method that should be called by other objects. The method 
		#-showAndRunModal: is called by this method. This method will display 
		the CVS Import Panel. After the user clicks on the #Import button then 
		this method validates the CVS Import properties. If there is an error 
		then an alert panel is displayed with the error and the CVS Import 
		Panel is redisplayed with the old properties.
    "*/
{
    int         modalReturnCode = 0;
    BOOL        showPanelAgain = NO;
    BOOL        doAdd = NO;
    BOOL        areValidProperties = NO;
    BOOL        isValidModuleProperty = NO;
	    
    do {
        modalReturnCode = [self showAndRunModal];
        showPanelAgain = NO;
		doAdd = NO;
        if ( modalReturnCode == NSOKButton ) {
			areValidProperties = [self validateCvsImportProperties];
			if ( areValidProperties == NO ) {
				showPanelAgain = YES;
			} else {
				if ( [isAddedToTheModulesFile boolValue] == YES ) {
					isValidModuleProperty = [self validateModuleProperty];
					if ( isValidModuleProperty == NO ) {
						showPanelAgain = YES;
					}					
				}
			}
            if ( showPanelAgain == NO ) {
                doAdd = YES;
            }
        }
    } while ( showPanelAgain == YES );
	
	return modalReturnCode;
}

- (NSMutableDictionary *)cvsImportProperties
	/*" This is the get method for the instance variable named 
		cvsImportProperties. The cvsImportProperties is a holding container for 
		the properties needed to create a CvsImportRequest.

		See also #{-setCvsImportProperties:}
    "*/
{
    return cvsImportProperties; 
}

- (void)setCvsImportProperties:(NSMutableDictionary *)newRepositoryProperties
	/*" This is the set method for the instance variable named 
		cvsImportProperties. The cvsImportProperties is a holding container for 
		the properties needed to create a CvsImportRequest.

		See also #{-cvsImportProperties}
    "*/
{
    if (cvsImportProperties != newRepositoryProperties) {
        [newRepositoryProperties retain];
        [cvsImportProperties release];
        cvsImportProperties = [NSMutableDictionary 
			dictionaryWithDictionary:newRepositoryProperties];
		[cvsImportProperties retain];
		[newRepositoryProperties release];
    }
}

- (CvsRepository *)importRepository
	/*" This is the get method for the instance variable named 
		importRepository. The importRepository is the repository currently 
		selected in the repository viewer and the one into which this import 
		will use for importing new files and folders.

		See also #{-setImportRepository:}
    "*/
{
    return importRepository; 
}

- (void)setImportRepository:(CvsRepository *)anImportRepository
	/*" This is the set method for the instance variable named 
		importRepository. The importRepository is the repository currently 
		selected in the repository viewer and the one into which this import 
		will use for importing new files and folders.

		See also #{-importRepository}
    "*/
{
	NSString *aCvsRoot = nil;
	
	isNewImportRepository = NO;
    if (importRepository != anImportRepository) {
        [anImportRepository retain];
        [importRepository release];
        importRepository = anImportRepository;
		aCvsRoot = [importRepository path];
		[self setCvsRoot:aCvsRoot];
		[self updateRepositorySubpathButton];
		isNewImportRepository = YES;
    }
}

- (void)updateClearButton
	/*" This method indirectly enables and disables the Clear Button in the 
		CVS Import Panel by setting the instance variable named 
		isClearButtonEnabled to a YES or NO. Then via of the bindings the Clear
		Button is enabled or disabled depending on the value of 
		isClearButtonEnabled. The Clear Button is enabled whenever any of the
		text fields in the CVS Import Panel have been edited.
	"*/
{
	BOOL isButtonEnabled = NO;
		
	if ( isNotEmpty(cvsImportProperties) ) {
		isButtonEnabled = YES;
	}
	[self setIsClearButtonEnabled:[NSNumber numberWithBool:isButtonEnabled]];
}

- (void)updateImportButton
	/*" This method indirectly enables and disables the Import Button in the 
		CVS Import Panel by setting the instance variable named 
		isImportButtonEnabled to a YES or NO. Then via of the bindings the Import
		Button is enabled or disabled depending on the value of 
		isImportButtonEnabled. The Import Button is enabled whenever all of the
		text fields except the password test field in the current tabview have 
		been edited.
	"*/
{
	BOOL isButtonEnabled = NO;
	
	if ( [self areCvsImportPropertiesComplete] == YES ) {
		isButtonEnabled = YES;
	}
	[self setIsImportButtonEnabled:[NSNumber numberWithBool:isButtonEnabled]];
}

- (void)updateRepositorySubpathButton
	/*" This method indirectly enables and disables the Clear Button in the 
	CVS Import Panel by setting the instance variable named 
	isClearButtonEnabled to a YES or NO. Then via of the bindings the Clear
	Button is enabled or disabled depending on the value of 
	isClearButtonEnabled. The Clear Button is enabled whenever any of the
	text fields in the current tabview have been edited.
	"*/
{
	BOOL isButtonEnabled = NO;
		
	if ( (importRepository != nil) && ([importRepository isLocal] == YES) ) {
		isButtonEnabled = YES;
	}
	[self setIsRepositorySubpathButtonEnabled:
		[NSNumber numberWithBool:isButtonEnabled]];
}

- (NSNumber *)isClearButtonEnabled
	/*" This is the get method for the instance variable named 
		isClearButtonEnabled. The isClearButtonEnabled is set to YES whenever 
		any of the repository properties have been edited. This allows bindings 
		to use this instance variable to enable and disable the Clear Button in 
		the CVS Import Panel.

		See also #{-setIsClearButtonEnabled:}
    "*/
{
    return isClearButtonEnabled; 
}

- (void)setIsClearButtonEnabled:(NSNumber *)newIsClearButtonEnabled
	/*" This is the set method for the instance variable named 
		isClearButtonEnabled. The isClearButtonEnabled is set to YES whenever 
		any of the repository properties have been edited. This allows bindings 
		to use this instance variable to enable and disable the Clear Button in 
		the CVS Import Panel.

		See also #{-isClearButtonEnabled}
    "*/
{
	ASSIGN(isClearButtonEnabled, newIsClearButtonEnabled);
}

- (NSNumber *)isImportButtonEnabled
	/*" This is the get method for the instance variable named 
		isImportButtonEnabled. The isImportButtonEnabled is set to YES when 
		all of the repository properties have been edited. This allows bindings 
		to use this instance variable to enable and disable the Import Button in 
		the CVS Import Panel.

		See also #{-setIsImportButtonEnabled:}
    "*/
{
    return isImportButtonEnabled; 
}

- (void)setIsImportButtonEnabled:(NSNumber *)newIsImportButtonEnabled
	/*" This is the set method for the instance variable named 
		isImportButtonEnabled. The isImportButtonEnabled is set to YES when 
		all of the repository properties have been edited. This allows bindings 
		to use this instance variable to enable and disable the Import Button in 
		the CVS Import Panel.

		See also #{-isImportButtonEnabled}
    "*/
{
	ASSIGN(isImportButtonEnabled, newIsImportButtonEnabled);
}

- (NSNumber *)isRepositorySubpathButtonEnabled
	/*" This is the get method for the instance variable named 
		isRepositorySubpathButtonEnabled. The isRepositorySubpathButtonEnabled 
		is set to YES when the import repository is a local repository. Only 
		then can a user navigate to the repository using the Finder. This allows
		bindings to use this instance variable to enable and disable the 
		"Repository Subpath Browse..." Button in the CVS Import Panel.

		See also #{-setIsRepositorySubpathButtonEnabled:}
    "*/
{
    return isRepositorySubpathButtonEnabled; 
}

- (void)setIsRepositorySubpathButtonEnabled:(NSNumber *)newIsRepositorySubpathButtonEnabled
	/*" This is the set method for the instance variable named 
		isRepositorySubpathButtonEnabled. The isRepositorySubpathButtonEnabled 
		is set to YES when the import repository is a local repository. Only 
		then can a user navigate to the repository using the Finder. This allows
		bindings to use this instance variable to enable and disable the 
		"Repository Subpath Browse..." Button in the CVS Import Panel.

		See also #{-isRepositorySubpathButtonEnabled}
    "*/
{
	ASSIGN(isRepositorySubpathButtonEnabled, newIsRepositorySubpathButtonEnabled);
}

- (NSNumber *)isAddedToTheModulesFile
	/*" This is the get method for the instance variable named 
		isAddedToTheModulesFile. This instance varible is set to YES when the 
		user selects the "Add the following module name..." checkbox, otherwise 
		this instance variable is set to NO. The default is that this checkbox
		is selected. This allows bindings to use this instance variable to
		enable and disable the "Module Name" textfield in the CVS Import Panel.

		See also #{-setIsAddedToTheModulesFile:}
    "*/
{	
    return isAddedToTheModulesFile; 
}

- (void)setIsAddedToTheModulesFile:(NSNumber *)anIsAddedToTheModulesFile
	/*" This is the set method for the instance variable named 
		isAddedToTheModulesFile. This instance varible is set to YES when the 
		user selects the "Add the following module name..." checkbox, otherwise 
		this instance variable is set to NO. The default is that this checkbox
		is selected. This allows bindings to use this instance variable to
		enable and disable the "Module Name" textfield in the CVS Import Panel.

		See also #{-isAddedToTheModulesFile}
    "*/
{
	ASSIGN(isAddedToTheModulesFile, anIsAddedToTheModulesFile);
	if ( [isAddedToTheModulesFile boolValue] == YES ) {
		[self setModuleNameLabelColor:[NSColor blackColor]];
		[self updateModuleName];
	} else {
		[self setModuleNameLabelColor:[NSColor grayColor]];
		[cvsImportProperties removeObjectForKey:@"moduleName"];
	}
}

- (NSColor *)moduleNameLabelColor
	/*" This is the get method for the instance variable named 
		moduleNameLabelColor. This instance varible determines the color of the 
		text in the module name textfield. It is black when the textfield is 
		enabled and gray when it is disabled.

		See also #{-setModuleNameLabelColor:}
    "*/
{	
    return moduleNameLabelColor; 
}

- (void)setModuleNameLabelColor:(NSColor *)aModuleNameLabelColor
	/*" This is the get method for the instance variable named 
		moduleNameLabelColor. This instance varible determines the color of the 
		text in the module name textfield. It is black when the textfield is 
		enabled and gray when it is disabled.

		See also #{-moduleNameLabelColor}
    "*/
{
	ASSIGN(moduleNameLabelColor, aModuleNameLabelColor);
}

- (NSString *)cvsRoot
	/*" This is the get method for the instance variable named 
		cvsRoot. The cvsRoot is the absolute path to the import respository.

		See also #{-setCvsRoot:}
    "*/
{	
    return cvsRoot; 
}

- (void)setCvsRoot:(NSString *)aCvsRoot
	/*" This is the set method for the instance variable named 
		cvsRoot. The cvsRoot is the absolute path to the import respository.

		See also #{-cvsRoot}
    "*/
{	
	ASSIGN(cvsRoot, aCvsRoot);
}

- (void)addObservers
	/*" This method adds self as an observer to all the possible keys in the 
		cvsImportProperties dictionary that might be bound to an UI object in 
		the CVS Import Panel.
	"*/
{	
	SEN_ASSERT_NOT_NIL(cvsImportProperties);
	
	[cvsImportProperties addObserver:self
						  forKeyPath:@"sourcePath" 
							 options:(NSKeyValueObservingOptionNew |
									  NSKeyValueObservingOptionOld)
							 context:NULL];	
	[cvsImportProperties addObserver:self
						   forKeyPath:@"repositorySubpath" 
							  options:(NSKeyValueObservingOptionNew |
									   NSKeyValueObservingOptionOld)
							  context:NULL];
	[cvsImportProperties addObserver:self
						   forKeyPath:@"repositoryDirectory" 
							  options:(NSKeyValueObservingOptionNew |
									   NSKeyValueObservingOptionOld)
							  context:NULL];
	[cvsImportProperties addObserver:self
						   forKeyPath:@"releaseTag" 
							  options:(NSKeyValueObservingOptionNew |
									   NSKeyValueObservingOptionOld)
							  context:NULL];
	[cvsImportProperties addObserver:self
						   forKeyPath:@"vendorTag" 
							  options:(NSKeyValueObservingOptionNew |
									   NSKeyValueObservingOptionOld)
							  context:NULL];
	[cvsImportProperties addObserver:self
						  forKeyPath:@"importMessage"
							 options:(NSKeyValueObservingOptionNew |
									  NSKeyValueObservingOptionOld)
							 context:NULL];
	[cvsImportProperties addObserver:self
						  forKeyPath:@"moduleName"
							 options:(NSKeyValueObservingOptionNew |
									  NSKeyValueObservingOptionOld)
							 context:NULL];
}

- (void)observeValueForKeyPath:(NSString *)aKeyPath ofObject:(id)anObject change:(NSDictionary *)aChange context:(void *)aContext
	/*" This message is sent to this receiver when the value at the specified 
		aKeyPath relative to the anObject has changed. The change dictionary 
		contains the entries described in “Constants”. The aContext is the value
		that was provided when the receiver was registered to receive key value
		observer notifications.

		This receiver must be registered as an observer for the specified 
		aKeyPath and anObject. We have done this in the method -addObservers.
	"*/
{
	if ( [aKeyPath isEqual:@"sourcePath"] ) {
		[self updateRepositoryDirectory];
    }
	
	if ( [aKeyPath isEqual:@"repositoryDirectory"] ) {
		[self updateModuleName];
    }
	
	if ( [aKeyPath isEqual:@"repositorySubpath"] || 
		 [aKeyPath isEqual:@"repositoryDirectory"] ||
		 [aKeyPath isEqual:@"sourcePath"] ) {
		[self updateImportRepositoryPath];
    }
	
    if ( [aKeyPath isEqual:@"repositorySubpath"] || 
		 [aKeyPath isEqual:@"repositoryDirectory"] ||
		 [aKeyPath isEqual:@"sourcePath"] ||
		 [aKeyPath isEqual:@"releaseTag"] ||
		 [aKeyPath isEqual:@"vendorTag"] ||
		 [aKeyPath isEqual:@"moduleName"] ||
		 [aKeyPath isEqual:@"importMessage"] ) {
		[self updateClearButton];
		[self updateImportButton];
    }
}

- (void)senOpenPanelController:(SenOpenPanelController *)aSenOpenPanelController selectedDirectory:(NSString *)aDirectory selectedFileNames:(NSArray *)someFilenames
    /*" This is the delegate method for the SenOpenPanelController. We use this
		method to set the source path when using the "Source Path Browse..." 
		button to select the path to the source directory to be imported. Also 
		we used this method to set the repository subpath when using the 
		"Repository Subpath Browse..." button to select the subpath in the local
		repository.
    "*/
{
	NSString *aRepositorySubpath = nil;
	
	if ( aSenOpenPanelController == sourceOpenPanelController ) {
		[cvsImportProperties setValue:aDirectory forKey:@"sourcePath"];
	} else 	if ( aSenOpenPanelController == repositoryOpenPanelController ) {
		aRepositorySubpath = [self repositorySubpathFrom:aDirectory];
		if ( isNotEmpty(aRepositorySubpath) ) {
			[cvsImportProperties setValue:aRepositorySubpath
								   forKey:@"repositorySubpath"];
		} else {
			[cvsImportProperties removeObjectForKey:@"repositorySubpath"];
		}
    } else {
        NSString *anErrorMsg = nil;
        
        anErrorMsg = [NSString stringWithFormat:
            @"aSenOpenPanelController was %@, it should be either sourceOpenPanelController or repositoryOpenPanelController!", 
            aSenOpenPanelController];
        SEN_ASSERT_CONDITION_MSG(NO, anErrorMsg);
    }
}

- (BOOL)areCvsImportPropertiesComplete
	/*" This is a helper method. It returns YES if all the necessary CVS import 
		properties has been completed in the CVS Import Panel, otherwise NO is
		returned.
	"*/
{
	NSString	*aRepositoryDirectory	= nil;
	NSString	*aSourcePath		= nil;
	NSString	*aReleaseTag		= nil;
	NSString	*aVendorTag			= nil;
	NSString	*aMessage			= nil;
	
	aRepositoryDirectory = [cvsImportProperties 
										objectForKey:@"repositoryDirectory"];
	aSourcePath = [cvsImportProperties objectForKey:@"sourcePath"];
	aReleaseTag = [cvsImportProperties objectForKey:@"releaseTag"];
	aVendorTag = [cvsImportProperties objectForKey:@"vendorTag"];
	aMessage = [cvsImportProperties objectForKey:@"importMessage"];
	
	if ( isNilOrEmpty(aRepositoryDirectory) ||
		 isNilOrEmpty(aSourcePath) ||
		 isNilOrEmpty(aReleaseTag) ||
		 isNilOrEmpty(aVendorTag) ||
		 isNilOrEmpty(aMessage) ) {
		return NO;
	}
	return YES;
}

- (BOOL)validateCvsImportProperties
	/*" This is a helper method. It returns YES if all the CVS import 
		properties are valid, otherwise NO is returned.
	"*/
{
	NSString	*aReleaseTag	= nil;
	NSString	*aVendorTag		= nil;
		
	// We need to check that all fields are filled (and valid) before sending request,
	// else empty fields have side-effects!!!
	aReleaseTag = [cvsImportProperties objectForKey:@"releaseTag"];
	aVendorTag = [cvsImportProperties objectForKey:@"vendorTag"];
	
	if ( [self areCvsImportPropertiesComplete] == NO ) {
		NSBeginAlertSheet(@"Import", nil, nil, nil, [self window], self, 
		  NULL, NULL, NULL, 
		  @"All fields  but the \"Repository Subpath\" must be completed. Please complete all these fields and try again.");
		return NO;
	}
	
	// Release and vendor tags may not be the same
	if ( [aVendorTag isEqualToString:aReleaseTag] ) {
		NSBeginAlertSheet(@"Import", nil, nil, nil, [self window], self, 
		  NULL, NULL, NULL, 
		  @"Release (%@) and vendor (%@) tags may not be the same.",
		  aReleaseTag, aVendorTag);
		return NO;
	}
	
	return YES;
}

- (void)updateRepositoryDirectory
	/*" This method updates the cvsImportProperties dictionary for the key
		"repositoryDirectory" which will indirectly update the repository 
		directory textfield via of the bindings. The repository directory is 
		directory name that CVS will use to import the files and folders that 
		are specified in this CVS Import Panel. This is usually the same as the 
		source directory. The source directory is the last component of the 
		source path. This method takes the last component of the source path and
		puts it into the cvsImportProperties dictionary for the key 
		"repositoryDirectory". Then the bindings take over and updates the 
		"Repository Directory" textfield. This method is only called when the 
		source path is changed. The user can override the value of "Repository
		Directory" textfield by entering data by hand in said textfield.
	"*/
{
	NSString	*aSourcePath				= nil;
	NSString	*aRepositoryDirectory		= nil;
	NSString	*lastSourcePathComponent	= nil;
	
	aSourcePath = [cvsImportProperties objectForKey:@"sourcePath"];
	aRepositoryDirectory = [cvsImportProperties 
								objectForKey:@"repositoryDirectory"];

	if ( isNotEmpty(aSourcePath) ) {
		lastSourcePathComponent = [aSourcePath lastPathComponent];
		if ( isNotEmpty(lastSourcePathComponent) ) {
			if ( isNilOrEmpty(aRepositoryDirectory) ||
				 [lastSourcePathComponent isEqualToString:aRepositoryDirectory] == NO ) {
				[cvsImportProperties setValue:lastSourcePathComponent 
									   forKey:@"repositoryDirectory"];
			}
		}
	}
}

- (void)updateImportRepositoryPath
	/*" This method updates the import repository path textfield. The import 
		repository path is the absolute path that CVS will use to import the 
		files and folders that are specified in this CVS Import Panel. This is 
		calculated from the absolute path to the repository with the repository 
		subpath appended to it plus the repository directory appended to that. 
		Note that the repository subpath is optional and in a lot of cases is an
		empty string. The import repository path textfield is read only. It is 
		shown for informational purposes only. It is always calculated from the
		other text fields on the CVS Import Panel.
	"*/
{
	NSString	*aRepositoryPath		= nil;
	NSString	*aRepositoryDirectory	= nil;
	NSString	*importRepositoryPath	= @"";
	
	aRepositoryPath = [cvsImportProperties objectForKey:@"repositorySubpath"];
	aRepositoryDirectory = [cvsImportProperties 
										objectForKey:@"repositoryDirectory"];

	if ( isNotEmpty(cvsRoot) ) {
		importRepositoryPath = [importRepositoryPath 
										stringByAppendingPathComponent:cvsRoot];
	}
	if ( isNotEmpty(aRepositoryPath) ) {
		importRepositoryPath = [importRepositoryPath 
								stringByAppendingPathComponent:aRepositoryPath];
	}
	if ( isNotEmpty(aRepositoryDirectory) ) {
		importRepositoryPath = [importRepositoryPath 
						stringByAppendingPathComponent:aRepositoryDirectory];
	}
	[importRepositoryPathTextField setStringValue:importRepositoryPath];
}

- (NSString *)repositorySubpathFrom:(NSString *)aPath
	/*" This is a helper method. It calculates the repository subpath given an
		absolute path in aPath. (e.g. if aPath is "/Users/Shared/Repository/Test" 
		and the repository path is "/Users/Shared/Repository" then this method 
		would return "Test").
	"*/
{
	// We can not compare filenames, because on MacOSX,
	// /Network is replaced by /automount/Network. Let's compare file IDs.
	NSFileManager	*fileManager				= nil;
	NSDictionary	*aDict						= nil;
	NSNumber		*cvsRootSystemNumber		= nil;
	NSNumber		*cvsRootSystemFileNumber	= nil;
	NSNumber		*cvsTempSystemNumber		= nil;
	NSNumber		*cvsTempSystemFileNumber	= nil;
	NSString		*tempPath					= nil;
	NSString		*theLastComponent			= nil;
	NSString		*aRepositorySubpath			= @"";
	NSMutableArray	*subpathComponents			= nil;

	subpathComponents = [NSMutableArray arrayWithCapacity:4]; 
	tempPath = [NSString stringWithString:aPath];
	fileManager = [NSFileManager defaultManager];
	aDict = [fileManager fileAttributesAtPath:cvsRoot traverseLink:YES];
	cvsRootSystemNumber = [aDict objectForKey:NSFileSystemNumber];
	cvsRootSystemFileNumber = [aDict objectForKey:NSFileSystemFileNumber];
	
	while ( [tempPath length] >= [cvsRoot length] ) {
		aDict = [fileManager fileAttributesAtPath:tempPath traverseLink:YES];
		cvsTempSystemFileNumber = [aDict objectForKey:NSFileSystemFileNumber];
		cvsTempSystemNumber = [aDict objectForKey:NSFileSystemNumber];
		if ([cvsTempSystemFileNumber isEqual:cvsRootSystemFileNumber] && 
			[cvsTempSystemNumber isEqual:cvsRootSystemNumber]) {
			break;
		}
		theLastComponent = [tempPath lastPathComponent];
		// Just to be on the safe side lets check for an empty or nil string.
		if ( isNilOrEmpty(theLastComponent) ) {
			break;
		}
		[subpathComponents insertObject:[tempPath lastPathComponent] atIndex:0];
		tempPath = [tempPath stringByDeletingLastPathComponent];
	}
	if ( isNotEmpty(subpathComponents) ) {
		aRepositorySubpath = [NSString pathWithComponents:subpathComponents];
		[[aRepositorySubpath retain] autorelease];
	}
	return aRepositorySubpath;
}

- (IBAction)showWindow:(id)sender
	/*" This action method displays the window associated with this 
		NSWindowController. This method calls super's implementation and if this
		is the first time this method has been called for this repository then 
		the -clear: method is called to clear all the textfields. The Repository 
		textfield at the top of the panel is filled in and the open panel 
		controller is set to this repository path. Finally the import repository
		path textfield is updated.
	"*/
{
	NSString *aPath	= nil;
	
	[super showWindow:sender];
	if ( isNewImportRepository == YES) {
		[self clear:self];
		isNewImportRepository = NO;
	}
	
	aPath = [importRepository root];
	if ( aPath != nil ) {
		[cvsRootTextField setStringValue:aPath];
	} else {
		[cvsRootTextField setStringValue:@"<Unknown>"];
	}
	
	if ( cvsRoot != nil ) {
		[repositoryOpenPanelController setStringValue:cvsRoot];
	} else {
		[repositoryOpenPanelController setStringValue:@""];
	}
	[self updateImportRepositoryPath];
}

- (void)control:(NSControl *)aControl didFailToValidatePartialString:(NSString *)aString errorDescription:(NSString *)anError
    /*" This method allows us to present an error panel to user if he starts to 
		enter incorrect data according to the CvsFormatter.
    "*/
{
    NSString *aTitle = nil;
    NSString *aControlTitle = @"Unknown Control";
	int aTag = 0;
    
    SEN_ASSERT_NOT_NIL(aControl);
    
	aTag = [aControl tag];
	if ( aTag == 1 ) {
		aControlTitle = @"Release Tag";
	} else if ( aTag == 2 ) {
		aControlTitle = @"Vendor Tag";
	} else {
		SEN_ASSERT_CONDITION_MSG((NO), ([NSString stringWithFormat:
			@"The NSTextFields of \"Release Tag\" and \"Vendor Tag\" in the import panel should have tags of 1 and 2 but at least one of them does not. It has a tag of %d! The CvsImportPanel.nib file needs to be corrected.", 
			aTag]));		
	}
    aTitle = [NSString stringWithFormat:@"%@ Formatting Error", aControlTitle];
    (void)NSRunAlertPanel(aTitle, anError, nil, nil, nil);
}

- (BOOL)isModuleNameInUse:(NSString *)aModuleName
	/*" This method return YES if the module name given in the argument 
		aModuleName is already in use in the modules file, otherwise NO is 
		returned.
	"*/
{
	CvsModule	*aModule = nil;
	
	aModule = [importRepository moduleWithSymbolicName:aModuleName];
	if ( aModule != nil ) {
		return YES;
	}
	return NO;
}

- (void)importIntoRepository:(CvsRepository *)aRepository
	/*" This method is used to import a directory of files and/or subfolders 
		into the repository given in the argument aRepository. This method will 
		put up a modal panel which will ask the user to entry all the 
		information needed to perform a CVS import.
	"*/
{
	CvsImportRequest	*anImportRequest		= nil;
	NSString			*aModulePath			= nil;
	NSString			*aRepositoryPath		= nil;
	NSString			*aRepositoryDirectory	= nil;
	NSString			*aSourcePath			= nil;
	NSString			*aReleaseTag			= nil;
	NSString			*aVendorTag				= nil;
	NSString			*aMessage				= nil;
	int					aModalReturnCode		= 0;
		
	if ( aRepository == nil ) {
		NSBeginAlertSheet(@"Import", nil, nil, nil, [self window], self, 
		  NULL, NULL, 
		  NULL, @"Could not determine the repository! Something is terribly wrong.");
		return;
	}
	
	[self setImportRepository:aRepository];
	aModalReturnCode = [self showCvsImportPanel];
	if ( aModalReturnCode == NSOKButton ) {
		aRepositoryPath = [cvsImportProperties objectForKey:@"repositorySubpath"];
		aRepositoryDirectory = [cvsImportProperties 
										objectForKey:@"repositoryDirectory"];
		aModulePath = [self modulePath];
		aSourcePath = [cvsImportProperties valueForKey:@"sourcePath"];
		aReleaseTag = [cvsImportProperties valueForKey:@"releaseTag"];
		aVendorTag = [cvsImportProperties valueForKey:@"vendorTag"];
		aMessage = [cvsImportProperties valueForKey:@"importMessage"];
		
		anImportRequest = [CvsImportRequest 
						   cvsImportRequestForSubpath:aModulePath
										 inRepository:aRepository
										   importPath:aSourcePath
										   releaseTag:aReleaseTag
											vendorTag:aVendorTag
											  message:aMessage];
		if (anImportRequest != nil ) {
			if ( [isAddedToTheModulesFile boolValue] == YES ) {
				[self addNewModuleName:anImportRequest];
			} else {
				[anImportRequest schedule];
			}
		}		
    }	
}

- (void)addNewModuleName:(CvsImportRequest *)anImportRequest
	/*" This method will generate and schedule CVS requests to add an entry to 
		the modules file for the CVS import being created by this controller. 
		This method is only called if the user selects the "Add the following 
		module name..." checkbox and enters a module name in the CVS Import 
		Panel. This automates the process of adding a module name to the modules
		file when performing an import.
	"*/
{
    NSString			*theModulesFilePath		= nil;
    NSString			*aModuleDescription		= nil;
    NSString			*aNewModuleDescription	= nil;
    NSString			*theCVSROOTWorkAreaPath	= nil;
    NSArray				*someFiles				= nil;
	RepositoryViewer	*theRepositoryViewer	= nil;
	CvsCommitRequest	*aCvsCommitRequest		= nil;
	SelectorRequest		*reloadRequest			= nil;
    NSString			*aMessage				= nil;
	NSString			*aModuleName			= nil;
	NSString			*aModulePath			= nil;

    SEN_ASSERT_NOT_NIL(importRepository);
	
    theRepositoryViewer = [RepositoryViewer sharedRepositoryViewer];
	SEN_ASSERT_NOT_NIL(theRepositoryViewer);

	aModuleDescription = [theRepositoryViewer getFileContentsForFilename:@"modules"];
	if ( isNilOrEmpty(aModuleDescription) ) {
		return;
	}
	
	aModuleName = [cvsImportProperties objectForKey:@"moduleName"];
	if ( isNilOrEmpty(aModuleName) ) {
		return;
	}
	
	aModulePath = [self modulePath];
	if ( isNilOrEmpty(aModulePath) ) {
		return;
	}
	
	//Add new module name to the modules file.
	aNewModuleDescription = [NSString stringWithFormat:@"%@\n%@\t%@\n",
		aModuleDescription, aModuleName, aModulePath];
		
	theCVSROOTWorkAreaPath = [importRepository CVSROOTWorkAreaPath];
    theModulesFilePath = [theCVSROOTWorkAreaPath stringByAppendingPathComponent:@"modules"];
    if ( [aNewModuleDescription writeToFile:theModulesFilePath
							  atomically:NO] == NO ) {
        NSBeginAlertSheet(@"Save", nil, nil, nil, [self window], nil, 
						  NULL, NULL, NULL, @"Unable to save file %@.", theModulesFilePath);
        return;
    }
	
    someFiles = [NSArray arrayWithObject:@"modules"];
	aMessage = [NSString stringWithFormat:@"Added module named %@.", 
		aModuleName];
	aCvsCommitRequest = [CvsCommitRequest 
                                    cvsCommitRequestForFiles:someFiles 
                                                      inPath:theCVSROOTWorkAreaPath 
                                                     message:aMessage];
	if ( aCvsCommitRequest != nil ) {
		reloadRequest = [SelectorRequest 
                                requestWithTarget:theRepositoryViewer
                                         selector:@selector(reloadRepository:) 
                                         argument:importRepository];
		[reloadRequest addPrecedingRequest:aCvsCommitRequest];
		[reloadRequest addPrecedingRequest:anImportRequest];
		[reloadRequest schedule];
	}                	
}

- (BOOL)validateModuleProperty
	/*" This is a helper method. It returns YES if the CVS module 
		property is valid, otherwise NO is returned.
	"*/
{
    NSString			*aModuleDescription		= nil;
    NSString			*aNewModuleDescription	= nil;
	RepositoryViewer	*theRepositoryViewer	= nil;
	NSString			*aModuleName			= nil;
	NSString			*aModulePath			= nil;
	NSCharacterSet		*theWhitespaceCharacterSet	= nil;
	BOOL				 isValidModuleProperty	= NO;
	NSRange				 aRange;
	
    SEN_ASSERT_NOT_NIL(importRepository);
	
    theRepositoryViewer = [RepositoryViewer sharedRepositoryViewer];
	SEN_ASSERT_NOT_NIL(theRepositoryViewer);
	
	aModuleName = [cvsImportProperties objectForKey:@"moduleName"];

	// Check that the module name is not nil or empty.
	if ( isNilOrEmpty(aModuleName) ) {
		NSBeginAlertSheet(@"Import", nil, nil, nil, [self window], self, 
						  NULL, NULL, NULL, 
						  @"The module name checkbox has been checked but no module name has been entered. Please either uncheck the checkbox or enter a module name.");			
		return NO;					
	}
	
	// Check that the module name does not contain spaces.
	theWhitespaceCharacterSet = [NSCharacterSet whitespaceCharacterSet];
	aRange = [aModuleName rangeOfCharacterFromSet:theWhitespaceCharacterSet];
	if ( aRange.length > 0 ) {
		NSBeginAlertSheet(@"Import", nil, nil, nil, [self window], self, 
						  NULL, NULL, NULL, 
						  @"The module name \"%@\" should not contain spaces. Please edit out the spaces in the module name.",
						  aModuleName);			
		return NO;					
	}
	
	// Check that the module name is not already in use.
	if ( [self isModuleNameInUse:aModuleName] == YES ) {
		NSBeginAlertSheet(@"Import", nil, nil, nil, [self window], self, 
						  NULL, NULL, NULL, 
						  @"The module name \"%@\" is already in use. Please choose another.",
						  aModuleName);			
		return NO;
	}			
	
	// Check that the module description is not nil.
	aModuleDescription = [theRepositoryViewer getFileContentsForFilename:@"modules"];
	if ( aModuleDescription == nil ) {
		NSBeginAlertSheet(@"Import", nil, nil, nil, [self window], self, 
						  NULL, NULL, NULL, 
						  @"The modules file either does not exists or we are unable to read it. Please try again or uncheck the \"Add the following module name...\" checkbox and try again.");					
		return NO;
	}
	
	// Check that the module path is not nil.
	aModulePath = [self modulePath];
	if ( isNilOrEmpty(aModulePath) ) {
		NSBeginAlertSheet(@"Import", nil, nil, nil, [self window], self, 
						  NULL, NULL, NULL, 
						  @"The modules file path does not exists. Please uncheck the \"Add the following module name...\" checkbox and try again.");					
		return NO;
	}

	// Check that the module path does not contain spaces.
	aRange = [aModulePath rangeOfCharacterFromSet:theWhitespaceCharacterSet];
	if ( aRange.length > 0 ) {
		NSBeginAlertSheet(@"Import", nil, nil, nil, [self window], self, 
						  NULL, NULL, NULL, 
						  @"The module path \"%@\" should not contain spaces. CVS does not handle spaces in the pathnames in the modules file. Please uncheck the \"Add the following module name...\" checkbox and try again.",
						  aModulePath);			
		return NO;					
	}
	
	// Check that the format of the new modules file is valid.
	aNewModuleDescription = [NSString stringWithFormat:@"%@\n%@\t%@\n",
		aModuleDescription, aModuleName, aModulePath];
	isValidModuleProperty = [CvsModule checkModuleDescription:aNewModuleDescription 
												forRepository:importRepository];
	if ( isValidModuleProperty == NO ) {
		NSBeginAlertSheet(@"Import", nil, nil, nil, [self window], self, 
						  NULL, NULL, NULL, 
						  @"The module entry \"%@\t%@\" is not formatted correctly. Please check your import entries or uncheck the \"Add the following module name...\" checkbox and try again.",
						  aModuleName, aModulePath);			
		return NO;					
	}
	
	return YES;
}

- (NSString *)modulePath
	/*" This method returns the relative path used in the entry to the modules 
		file in the CVSROOT. It is made up of the repository subpath if any and 
		appended to that the repository directory.
	"*/
{
	NSString			*aModulePath			= nil;
	NSString			*aRepositorySubpath		= nil;
	NSString			*aRepositoryDirectory	= nil;
	
	aRepositorySubpath = [cvsImportProperties objectForKey:@"repositorySubpath"];
	aRepositoryDirectory = [cvsImportProperties 
										objectForKey:@"repositoryDirectory"];
	aModulePath = @"";
	if ( isNotEmpty(aRepositorySubpath) ) {
		aModulePath = [aModulePath 
							stringByAppendingPathComponent:aRepositorySubpath];
	}
	if ( isNotEmpty(aRepositoryDirectory) ) {
		aModulePath = [aModulePath 
						stringByAppendingPathComponent:aRepositoryDirectory];
	}	
	return aModulePath;
}

- (void)updateModuleName
	/*" This method updates the cvsImportProperties dictionary for the key
		"moduleName" which will indirectly update the module  
		name textfield via of the bindings. The module name is 
		name that CVS will use to add an entry to the CVS modules file. This is 
		usually the same as the last component of the repository directory. This
		method takes the last component of the repository directory and
		puts it into the cvsImportProperties dictionary for the key 
		"moduleName". Then the bindings take over and updates the 
		"Module Name" textfield. This method is only called when the 
		repository directory is changed. The user can override the value of 
		"Module Name" textfield by entering data by hand in said textfield.
	"*/
{
	NSString	*aModuleName			= nil;
	NSString	*aRepositoryDirectory	= nil;
	NSString	*lastPathComponent		= nil;
	
	
	aModuleName = [cvsImportProperties objectForKey:@"moduleName"];
	aRepositoryDirectory = [cvsImportProperties 
								objectForKey:@"repositoryDirectory"];
	
	if ( isNotEmpty(aRepositoryDirectory) ) {
		lastPathComponent = [aRepositoryDirectory lastPathComponent];
		if ( isNotEmpty(lastPathComponent) ) {
			if ( isNilOrEmpty(aModuleName) ||
				 [lastPathComponent isEqualToString:aModuleName] == NO ) {
				[cvsImportProperties setValue:lastPathComponent 
									   forKey:@"moduleName"];
			}
		}
	}
}

- (void)controlTextDidChange:(NSNotification *)aNotification
	/*" This is a delegate method of NSControl. Sent to the delegate when the 
		text in the receiving control (a text field ) changes. We are the 
		delegate.

		Here we are observing each character that the user types into any of the 
		7 text fields of the CVS import panel. We are doing this so we can 
		update the buttons at the bottom of the import panel. The updating of 
		these buttons via of the bindings is not good enough since the bindings 
		mechanism only occurs when the user leaves a text field, but we want to 
		update the buttons as soon as the user starts typing. Not only that we 
		want to know if the user erases all of the characters in the text field 
		also, say by backing up, so we can also disable some of the buttons in 
		this case.

		See also #{-windowDidLoad}
	"*/
{
	id			 anObject			= nil;
	NSString	*aValue				= nil;
	NSString	*aRepresentedObject	= nil;
	NSCell		*aCell				= nil;
		
	anObject = [aNotification object];
	if ( [anObject isKindOfClass:[NSTextField class]] == YES ) {
		aCell = [anObject cell];
		aRepresentedObject = [aCell representedObject];
		if ( aRepresentedObject != nil ) {
			if ( [aRepresentedObject isKindOfClass:[NSString class]] == YES ) {
				aValue = [anObject stringValue];
				if ( isNotEmpty(aValue) ) {
					[cvsImportProperties setValue:aValue forKey:aRepresentedObject];
				} else {
					[cvsImportProperties removeObjectForKey:aRepresentedObject];
				}
				[self updateClearButton];
				[self updateImportButton];						
			}
		}
	}
}


@end
