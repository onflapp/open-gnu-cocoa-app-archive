//
//  AddRepositoryController.m
//  CVL
//
//  Created by William Swats on 10/28/2004.
//  Copyright 2004 Sente SA. All rights reserved.
//


/*" This class is used to display a panel where the user can add a repository to
	CVL.
"*/

#import "AddRepositoryController.h"

#import "CVLDelegate.h"
#import "CvsRepository.h"
#import "RepositoryProperties.h"

#import <SenFoundation/SenFoundation.h>
#import <SenOpenPanelController.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>


#ifndef MAC_OS_X_VERSION_10_4
@interface NSNetService(TigerAPI)
+ (NSDictionary *)dictionaryFromTXTRecordData:(NSData *)txtData;
- (NSData *)TXTRecordData;
- (void)resolveWithTimeout:(NSTimeInterval)timeout;
@end
#endif

@implementation AddRepositoryController


- (void)awakeFromNib
	/*" Here we are setting up the instance variable repositoryProperties to 
		match the selected tab. In this case it will always be the "local" tab, 
		hence repositoryProperties will be set to localRepositoryProperties the
		first time the add repository panel is displayed.

		Also setting the repository method and compression levels to their 
		default values.
	"*/
{	
	NSNumber *aZeroInt = [NSNumber numberWithInt:0];
	
	// Set the repository methods.
	[localRepositoryProperties setRepositoryMethod:@"local"];
	[pserverRepositoryProperties setRepositoryMethod:@"pserver"];
	[bonjourRepositoryProperties setRepositoryMethod:@"pserver"];
	[otherRepositoryProperties setRepositoryMethod:@"ext"];
	// Set the repository compression level to zero.
	[localRepositoryProperties setRepositoryCompressionLevel:aZeroInt];
	[pserverRepositoryProperties setRepositoryCompressionLevel:aZeroInt];
	[bonjourRepositoryProperties setRepositoryCompressionLevel:aZeroInt];
	[otherRepositoryProperties setRepositoryCompressionLevel:aZeroInt];
		
	[self switchRepositoryPropertiesToMatchSelectedTab];
}

- (id)initWithWindowNibName:(NSString *)windowNibName
    /*" This is the desinated initializer for this class. Since this is a 
        subclass of NSWindowController we first call super's implementation. 
        That implementation returns an NSWindowController object initialized 
        with windowNibName, the name of the nib file 
        (minus the “.nib” extension) that archives the receiver’s window. The 
        windowNibName argument cannot be nil. Sets the owner of the nib file to 
        the receiver. The default initialization turns on cascading, sets the 
        shouldCloseDocument flag to NO, and sets the autosave name for the 
        window’s frame to an empty string. 

        Here in this subclass we set the autosave name for the window’s frame to 
        the name of the window nib name.
    "*/
{
    self = [super initWithWindowNibName:windowNibName];
    if ( self != nil ) {
        [self setWindowFrameAutosaveName:windowNibName];
    }
    return self;
}

- (void) dealloc
    /*" This method releases our instance variables.
    "*/
{
	RELEASE(isClearButtonEnabled);
	RELEASE(isAddButtonEnabled);
	RELEASE(templateFile);
	RELEASE(committingFiles);
	RELEASE(domainBrowser);
	RELEASE(serviceBrowser);
	RELEASE(bonjourDomains);
	RELEASE(allServices);
	RELEASE(servicesResolved);
	RELEASE(currentDomain);
	
    [super dealloc];
}

- (int)showAndRunModal
    /*" This method displays our window, updates it and runs it inside a modal 
        loop. After the modal loop is terminated the window is closed and this 
        method returns the result of the modal loop. That result is either 
        NSOKButton or NSCancelButton depending whether the user clicked on the 
        #Add buton or the #Cancel button.

        This method should not be called outside of the class.
    "*/
{
    [self showWindow:self];

    modalResult = -1;
    
    modalResult= [NSApp runModalForWindow:[self window]];
    [[self window] orderOut:self];
    return modalResult;
}

- (IBAction)cancel:(id)sender
    /*" This is an action method that terminates the modal loop with a return 
        value of NSCancelButton.
    "*/
{
    modalResult = NSCancelButton;
    [NSApp stopModalWithCode:modalResult];
}


- (IBAction)add:(id)sender
    /*" This is an action method that terminates the modal loop with a return 
        value of NSOKButton.
    "*/
{
	SEN_ASSERT_NOT_NIL(AddRepositoryControllerAlias);
	
	[AddRepositoryControllerAlias commitEditing];
    modalResult = NSOKButton;
    [NSApp stopModalWithCode:modalResult];
}

- (IBAction)clear:(id)sender
    /*" This action method clears all the text fields in the tab view in the 
		Repository Add Panel. It does this be setting the corresponding 
		properties to an empty string, then the binding systems takes over and 
		blanks out the text fields.
    "*/
{
	NSString *aRepositoryType = nil;
	
	aRepositoryType = [self repositoryType];
	if ( [aRepositoryType isEqualToString:@"local"] ) {
		[repositoryProperties setRepositoryPath:@""];
	} else 	if ( [aRepositoryType isEqualToString:@"pserver"] ) {
		[repositoryProperties setRepositoryPath:@""];
		[repositoryProperties setRepositoryUser:@""];
		[repositoryProperties setRepositoryHost:@""];
		[repositoryProperties setRepositoryPort:nil];
		[repositoryProperties setRepositoryPassword:@""];			
	} else 	if ( [aRepositoryType isEqualToString:@"bonjour"] ) {
		[repositoryProperties setRepositoryPath:@""];
		[repositoryProperties setRepositoryUser:@""];
		[repositoryProperties setRepositoryHost:@""];
		[repositoryProperties setRepositoryPassword:@""];					
	} else 	if ( [aRepositoryType isEqualToString:@"other"] ) {
		[repositoryProperties setRepositoryRoot:@""];
	}
	[repositoryProperties setRepositoryCompressionLevel:[NSNumber numberWithInt:0]];
	[repositoryProperties setCvsExecutablePath:[[NSUserDefaults standardUserDefaults] stringForKey:@"CVSPath"]];
}

- (NSButton *)clearButton
	/*" This method returns the pointer to the clear button in the Repository 
		Add Panel.
	"*/
{
	return clearButton;
}

- (NSButton *)addButton
	/*" This method returns the pointer to the add button in the Repository 
		Add Panel.
	"*/
{
	return addButton;
}

- (void)windowDidLoad
    /*" This method allows subclasses of NSWindowController to perform any 
        required tasks after the window owned by the receiver has been loaded. 
        The default implementation does nothing.

        Here we check to make sure the outlets are connected.
    "*/
{	
    SEN_ASSERT_NOT_NIL(addButton);
    SEN_ASSERT_NOT_NIL(clearButton);
    SEN_ASSERT_NOT_NIL(cancelButton);
	[self addObservers];	
}

- (int)showAddRepositoryPanel
    /*" This is the method that should be called by other objects. The method 
		#-showAndRunModal: is called by this method. This method will display 
		the Repository Add Panel. After the user clicks on the #Add button then 
		this method validates the repository properties. If there is an error 
		then an alert panel is displayed with the error and the Repository Add 
		Panel is redisplayed with the old properties.
    "*/
{
    int         modalReturnCode = 0;
    BOOL        showPanelAgain = NO;
    BOOL        doAdd = NO;
    BOOL        areValidProperties = NO;
	    
    do {
        modalReturnCode = [self showAndRunModal];
        showPanelAgain = NO;
		doAdd = NO;
        if ( modalReturnCode == NSOKButton ) {
			areValidProperties = [repositoryProperties validateRepositoryProperties];
			if ( areValidProperties == NO ) {
				showPanelAgain = YES;
			}
            if ( showPanelAgain == NO ) {
                doAdd = YES;
            }
        }
    } while ( showPanelAgain == YES );
	
	return modalReturnCode;
}

- (RepositoryProperties *)repositoryProperties
	/*" This is the get method for the instance variable named 
		repositoryProperties. The repositoryProperties is a holding class for 
		the properties needed to create a CvsRepository or one of its subclasses.

		See also #{-setRepositoryProperties:}
    "*/
{
    return repositoryProperties; 
}

- (void)setRepositoryProperties:(RepositoryProperties *)newRepositoryProperties
	/*" This is the set method for the instance variable named 
		repositoryProperties. The repositoryProperties is a holding class for 
		the properties needed to create a CvsRepository or one of its subclasses.

		See also #{-repositoryProperties}
    "*/
{
    if (repositoryProperties != newRepositoryProperties) {
        [newRepositoryProperties retain];
        [repositoryProperties release];
        repositoryProperties = newRepositoryProperties;
    }
}


-(NSString *)repositoryType
	/*" This method returns one of the 4 types (i.e. local, pserver, 
		bonjour or other). These are taken from the identifiers of the tabs
		in the tabview of the Repository Add Panel.
	"*/
{
	NSString *aRepositoryType = nil;
	NSTabViewItem *aTabViewItem = nil;
	
	aTabViewItem = [repositoryTypeTabView selectedTabViewItem];
	aRepositoryType = [aTabViewItem identifier];
	SEN_ASSERT_NOT_NIL(aRepositoryType);
	SEN_ASSERT_CLASS(aRepositoryType, @"NSString");
	
	return aRepositoryType;
}

- (void)switchRepositoryPropertiesToMatchSelectedTab
	/*" Here we are switching the instance variable repositoryProperties to 
		match the instanciated RepositoryProperties that correspond to the 
		selected tab. There is one instanciated RepositoryProperties for each of
		the tabs labeled Local, Pserver, Bonjour and Other.
	"*/
{
	NSString *aRepositoryType = nil;
	
	if ( repositoryProperties != nil ) {
		[self removeObservers];
	}
	aRepositoryType = [self repositoryType];
	SEN_ASSERT_NOT_NIL(aRepositoryType);
	
	if ( [aRepositoryType isEqualToString:@"local"] ) {
		// Local Tab
		repositoryProperties = localRepositoryProperties;
	} else 	if ( [aRepositoryType isEqualToString:@"pserver"] ) {
		// Pserver Tab
		repositoryProperties = pserverRepositoryProperties;
	} else 	if ( [aRepositoryType isEqualToString:@"bonjour"] ) {
		// Bonjour Tab
		repositoryProperties = bonjourRepositoryProperties;
	} else 	if ( [aRepositoryType isEqualToString:@"other"] ) {
		// Other Tab
		repositoryProperties = otherRepositoryProperties;
	}	
	[self addObservers];	
		
	// Note: We needed to add Observers before we do the following.
	if ( [aRepositoryType isEqualToString:@"bonjour"] ) {
		// Bonjour Tab
		[serverListPopUpButton setEnabled:NO];
		[self performSetup];
	}	
}

- (void)tabView:(NSTabView *)aTabView didSelectTabViewItem:(NSTabViewItem *)aTabViewItem
	/*" This is a NSTabView delegate method. Informs the delegate that tabview 
		has selected tabViewItem. Here we switch the instance variable named 
		repositoryProperties to point to the corresponding instance of the class
		RepositoryProperties of the selected tab. Also the Clean and Add Buttons 
		enabled states are updated.
	"*/
{	
	[self switchRepositoryPropertiesToMatchSelectedTab];
	[self updateClearButton];
	[self updateAddButton];
}

- (void)addObservers
	/*" This method adds self as an observer to all the instance variables of 
		the currently selected instance of the RepositoryProperties class that
		might be bound to an UI object in the Repository Add Panel. Since the 
		selected instance of the RepositoryProperties class changes with each 
		selection of a different tab in the tabview of the Repository Add Panel,
		this method plus the -removeObservers method keeps this object observing
		the correct instance variables.

		See also #{-removeObservers}
	"*/
{
	SEN_ASSERT_NOT_NIL(repositoryProperties);
	[repositoryProperties addObserver:self
						   forKeyPath:ROOT_KEY 
							  options:(NSKeyValueObservingOptionNew |
									   NSKeyValueObservingOptionOld)
							  context:NULL];
	[repositoryProperties addObserver:self
						   forKeyPath:METHOD_KEY 
							  options:(NSKeyValueObservingOptionNew |
									   NSKeyValueObservingOptionOld)
							  context:NULL];
	[repositoryProperties addObserver:self
						   forKeyPath:USER_KEY 
							  options:(NSKeyValueObservingOptionNew |
									   NSKeyValueObservingOptionOld)
							  context:NULL];
	[repositoryProperties addObserver:self
						   forKeyPath:HOST_KEY 
							  options:(NSKeyValueObservingOptionNew |
									   NSKeyValueObservingOptionOld)
							  context:NULL];
	[repositoryProperties addObserver:self
						   forKeyPath:PORT_KEY 
							  options:(NSKeyValueObservingOptionNew |
									   NSKeyValueObservingOptionOld)
							  context:NULL];
	[repositoryProperties addObserver:self
						   forKeyPath:PATH_KEY 
							  options:(NSKeyValueObservingOptionNew |
									   NSKeyValueObservingOptionOld)
							  context:NULL];
	[repositoryProperties addObserver:self
						   forKeyPath:PASSWORD_KEY 
							  options:(NSKeyValueObservingOptionNew |
									   NSKeyValueObservingOptionOld)
							  context:NULL];
	[repositoryProperties addObserver:self
						   forKeyPath:COMPRESSION_LEVEL_KEY 
							  options:(NSKeyValueObservingOptionNew |
									   NSKeyValueObservingOptionOld)
							  context:NULL];
	[repositoryProperties addObserver:self
						   forKeyPath:CVS_EXECUTABLE_PATH_KEY 
							  options:(NSKeyValueObservingOptionNew |
									   NSKeyValueObservingOptionOld)
							  context:NULL];
}

- (void)removeObservers
	/*" This method removes self as an observer to all the instance variables of 
		the previous selected instance of the RepositoryProperties class that
		might be bound to an UI object in the Repository Add Panel. Since the 
		selected instance of the RepositoryProperties class changes with each 
		selection of a different tab in the tabview of the Repository Add Panel,
		this method plus the -addObservers method keeps this object observing
		the correct instance variables.

		See also #{-addObservers}
	"*/
{
	SEN_ASSERT_NOT_NIL(repositoryProperties);
	[repositoryProperties removeObserver:self
							  forKeyPath:ROOT_KEY];
	[repositoryProperties removeObserver:self
							  forKeyPath:METHOD_KEY];
	[repositoryProperties removeObserver:self
							  forKeyPath:USER_KEY];
	[repositoryProperties removeObserver:self
							  forKeyPath:HOST_KEY];
	[repositoryProperties removeObserver:self
							  forKeyPath:PORT_KEY];
	[repositoryProperties removeObserver:self
							  forKeyPath:PATH_KEY];
	[repositoryProperties removeObserver:self
							  forKeyPath:PASSWORD_KEY];
	[repositoryProperties removeObserver:self
							  forKeyPath:COMPRESSION_LEVEL_KEY];	
	[repositoryProperties removeObserver:self
							  forKeyPath:CVS_EXECUTABLE_PATH_KEY];	
}

- (void)updateClearButton
	/*" This method indirectly enables and disables the Clear Button in the 
		Repository Add Panel by setting the instance variable named 
		isClearButtonEnabled to a YES or NO. Then via of the bindings the Clear
		Button is enabled or disabled depending on the value of 
		isClearButtonEnabled. The Clear Button is enabled whenever any of the
		text fields in the current tabview have been edited.
	"*/
{
	NSString *aRepositoryPath = nil;
	NSString *aRepositoryUser = nil;
	NSString *aRepositoryPassword = nil;
	NSString *aRepositoryHost = nil;
	NSString *aRepositoryRoot = nil;
	NSNumber *aRepositoryCompressionLevel = nil;
	NSNumber *aRepositoryPort = nil;
	NSString *aCvsExecutablePath = nil;
	NSString *theDefaultPath = nil;
	BOOL isButtonEnabled = NO;
		
	aRepositoryCompressionLevel = [repositoryProperties repositoryCompressionLevel];
	if ( (aRepositoryCompressionLevel != nil) &&
		 ([aRepositoryCompressionLevel intValue] > 0) ) {
		isButtonEnabled = YES;
	}
	
	// If isButtonEnabled is still NO then check some more varaibles.
	if ( isButtonEnabled == NO ) {
		aRepositoryPath = [repositoryProperties repositoryPath];
		aRepositoryUser = [repositoryProperties repositoryUser];
		aRepositoryPassword = [repositoryProperties repositoryPassword];
		aRepositoryHost = [repositoryProperties repositoryHost];
		aRepositoryRoot = [repositoryProperties repositoryRoot];

		if ( isNotEmpty(aRepositoryUser) || 
			 isNotEmpty(aRepositoryPassword) ||
			 isNotEmpty(aRepositoryPath) ||
			 isNotEmpty(aRepositoryHost) ||
			 isNotEmpty(aRepositoryRoot) ) {
			isButtonEnabled = YES;
		}
	}
	
	// If isButtonEnabled is still NO then check some more varaibles.
	if ( isButtonEnabled == NO ) {
		aCvsExecutablePath = [repositoryProperties cvsExecutablePath];
		if ( isNotEmpty(aCvsExecutablePath) ) {
			theDefaultPath = [[NSUserDefaults standardUserDefaults] stringForKey:@"CVSPath"];
			if ( isNotEmpty(theDefaultPath) ) {
				if ( [aCvsExecutablePath isEqualToString:theDefaultPath] == NO ) {
					isButtonEnabled = YES;
				}			
			}			
		}
	}
	
	// If isButtonEnabled is still NO then check some more varaibles.
	if ( isButtonEnabled == NO ) {
		aRepositoryPort = [repositoryProperties repositoryPort];
		if ( (aRepositoryPort != nil) &&
			 ([aRepositoryPort intValue] > 0) ) {
			isButtonEnabled = YES;
		}		
	}
	
	[self setIsClearButtonEnabled:[NSNumber numberWithBool:isButtonEnabled]];
}

- (void)updateAddButton
	/*" This method indirectly enables and disables the Add Button in the 
		Repository Add Panel by setting the instance variable named 
		isAddButtonEnabled to a YES or NO. Then via of the bindings the Add
		Button is enabled or disabled depending on the value of 
		isAddButtonEnabled. The Add Button is enabled whenever all of the
		text fields except the password test field in the current tabview have 
		been edited.
	"*/
{
	NSString *aRepositoryType = nil;
	NSString *aRepositoryPath = nil;
	NSString *aRepositoryUser = nil;
	NSString *aRepositoryPassword = nil;
	NSString *aRepositoryHost = nil;
	NSString *aRepositoryRoot = nil;
	NSNumber *aRepositoryCompressionLevel = nil;
	NSString *aCvsExecutablePath = nil;
	BOOL isButtonEnabled = NO;
	
	aRepositoryType = [self repositoryType];
	aRepositoryPath = [repositoryProperties repositoryPath];
	aRepositoryUser = [repositoryProperties repositoryUser];
	aRepositoryPassword = [repositoryProperties repositoryPassword];
	aRepositoryHost = [repositoryProperties repositoryHost];
	aCvsExecutablePath = [repositoryProperties cvsExecutablePath];
	aRepositoryCompressionLevel = [repositoryProperties repositoryCompressionLevel];

	if ( [aRepositoryType isEqualToString:@"local"] ) {
		// Local Tab
		if ( isNotEmpty(aRepositoryPath) &&
			 isNotEmpty(aCvsExecutablePath) && 
			 ( (aRepositoryCompressionLevel != nil) &&
			   ([aRepositoryCompressionLevel intValue] >= 0) ) ) {
			isButtonEnabled = YES;
		}
	} else 	if ( [aRepositoryType isEqualToString:@"pserver"] ) {
		// Pserver Tab
		if ( isNotEmpty(aRepositoryUser) && 
			 isNotEmpty(aRepositoryPath) &&
			 isNotEmpty(aRepositoryHost) &&
			 isNotEmpty(aCvsExecutablePath) &&
			 ( (aRepositoryCompressionLevel != nil) &&
			   ([aRepositoryCompressionLevel intValue] >= 0) ) ) {
			isButtonEnabled = YES;
		}
	} else 	if ( [aRepositoryType isEqualToString:@"bonjour"] ) {
		// Bonjour Tab
		if ( isNotEmpty(aRepositoryUser) && 
			 isNotEmpty(aRepositoryPath) &&
			 isNotEmpty(aRepositoryHost) &&
			 isNotEmpty(aCvsExecutablePath) &&
			 ( (aRepositoryCompressionLevel != nil) &&
			   ([aRepositoryCompressionLevel intValue] >= 0) ) ) {
			isButtonEnabled = YES;
		}
	} else 	if ( [aRepositoryType isEqualToString:@"other"] ) {
		// Other Tab
		aRepositoryRoot = [repositoryProperties repositoryRoot];
		if ( isNotEmpty(aRepositoryRoot) &&
			 isNotEmpty(aCvsExecutablePath) &&
			 ( (aRepositoryCompressionLevel != nil) &&
			   ([aRepositoryCompressionLevel intValue] >= 0) ) ) {
			isButtonEnabled = YES;
		}
	}	
	[self setIsAddButtonEnabled:[NSNumber numberWithBool:isButtonEnabled]];
}

- (NSNumber *)isClearButtonEnabled
	/*" This is the get method for the instance variable named 
		isClearButtonEnabled. The isClearButtonEnabled is set to YES whenever 
		any of the repository properties have been edited. This allows bindings 
		to use this instance variable to enable and disable the Clear Button in 
		the Repository Add Panel.

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
		the Repository Add Panel.

		See also #{-isClearButtonEnabled}
    "*/
{
    if (isClearButtonEnabled != newIsClearButtonEnabled) {
        [newIsClearButtonEnabled retain];
        [isClearButtonEnabled release];
        isClearButtonEnabled = newIsClearButtonEnabled;
    }
}

- (NSNumber *)isAddButtonEnabled
	/*" This is the get method for the instance variable named 
		isAddButtonEnabled. The isAddButtonEnabled is set to YES when 
		all of the repository properties have been edited. This allows bindings 
		to use this instance variable to enable and disable the Add Button in 
		the Repository Add Panel.

		See also #{-setIsAddButtonEnabled:}
    "*/
{
    return isAddButtonEnabled; 
}

- (void)setIsAddButtonEnabled:(NSNumber *)newIsAddButtonEnabled
	/*" This is the set method for the instance variable named 
		isAddButtonEnabled. The isAddButtonEnabled is set to YES when 
		all of the repository properties have been edited. This allows bindings 
		to use this instance variable to enable and disable the Add Button in 
		the Repository Add Panel.

		See also #{-isAddButtonEnabled}
    "*/
{
    if (isAddButtonEnabled != newIsAddButtonEnabled) {
        [newIsAddButtonEnabled retain];
        [isAddButtonEnabled release];
        isAddButtonEnabled = newIsAddButtonEnabled;
    }
}

- (void)observeValueForKeyPath:(NSString *)aKeyPath ofObject:(id)anObject change:(NSDictionary *)aChange context:(void *)aContext
	/*" This message is sent to this receiver when the value at the specified 
		aKeyPath relative to the anObject has changed. The change dictionary 
		contains the entries described in “Constants”. The aContext is the value
		that was provided when the receiver was registered to receive key value
		observer notifications.

		This receiver must be registered as an observer for the specified 
		aKeyPath and anObject. We have done this in the methods -addObservers 
		and -removeObservers.
"*/
{
    if ( [aKeyPath isEqual:ROOT_KEY] || 
		 [aKeyPath isEqual:USER_KEY] ||
		 [aKeyPath isEqual:HOST_KEY] ||
		 [aKeyPath isEqual:PORT_KEY] ||
		 [aKeyPath isEqual:PATH_KEY] ||
		 [aKeyPath isEqual:PASSWORD_KEY] ||
		 [aKeyPath isEqual:COMPRESSION_LEVEL_KEY] ||
		 [aKeyPath isEqual:CVS_EXECUTABLE_PATH_KEY] ) {
		[self updateClearButton];
		[self updateAddButton];
    }
}

-(void)performSetup
    /*" This method performs all the setup needed each time the panel view for
        creating a new Bonjour repository link in CVL is brought up. Mainly
        a number of arrays and sets are initialized and a search for registered
        domains is started. If this setup has already been called then we empty
        the arrays and sets and start a new search of registered domains. We 
        also call on update to the GUI so that the progress gets started with a
        clean slate.
    "*/
{
    if ( hasPerformSetup == NO ) {
        hasPerformSetup = YES;
        allServices = [NSMutableArray arrayWithCapacity:1];
        [allServices retain];
        
        servicesResolved = [NSMutableArray arrayWithCapacity:1];
        [servicesResolved retain];

        bonjourDomains = [NSMutableSet setWithCapacity:1];
        [bonjourDomains retain];
        
        serviceBrowser = [[NSNetServiceBrowser alloc] init];
        [serviceBrowser setDelegate:self];
        
        domainBrowser = [[NSNetServiceBrowser alloc] init];
        [domainBrowser setDelegate:self];
    } else {
        [allServices removeAllObjects];
        [servicesResolved removeAllObjects];
        [bonjourDomains removeAllObjects];
    }
    [self updateUI];
    [domainBrowser searchForRegistrationDomains];
}

-(void)updateUI
    /*" This method updates the view for creating new links to the Bonjour
        enabled CVS pservers.
    "*/
{
	//NSDictionary	*aDictionary	= nil;
	NSNetService	*aNetService	= nil;
	//NSData			*someRecordData	= nil;
	NSArray			*someAddresses	= nil;
	NSData			*addressData	= nil;
    unsigned int i;

    [serverListPopUpButton removeAllItems];
    for (i=0; i < [servicesResolved count]; i++) {
        NSString *_srvDesc; // to build the display string for the service
        NSString *_addressString =  nil;
        struct sockaddr *anAddress;
		NSString	*protocolSpecificInformation = nil;
		NSString	*aPath = nil;

		aNetService = [servicesResolved objectAtIndex:i];
		someAddresses = [aNetService addresses];
		addressData = [someAddresses objectAtIndex:0];
		if ( addressData != nil ) {
			anAddress = (struct sockaddr *)[addressData bytes];
			_addressString = [NSString stringWithCString:inet_ntoa(((struct in_addr)((struct sockaddr_in *)anAddress)->sin_addr))];
		} else {
			_addressString = @"";
		}
		
// The method -dictionaryFromTXTRecordData: does not seem to work on Tiger.
// I get back a dictionary with null keys.
// William Swats as of 24-Jun-2005
#if 0
		if([NSNetService respondsToSelector:@selector(dictionaryFromTXTRecordData:)]) {
			// Tiger
			someRecordData = [aNetService TXTRecordData];
			aDictionary = [NSNetService dictionaryFromTXTRecordData:someRecordData];
			protocolSpecificInformation = [aDictionary objectForKey:@"CVSRoot"]; // FIXME What is the key???
		} else {
			// Panther
			protocolSpecificInformation = [aNetService protocolSpecificInformation];
		}
#else
// Use this instead
		protocolSpecificInformation = [aNetService protocolSpecificInformation];
#endif
		
		if(protocolSpecificInformation == nil) protocolSpecificInformation = @"";
		
		// Remove the CVSROOT at the end it it is present.
		if ( [[protocolSpecificInformation lastPathComponent] isEqualToString:@"CVSROOT"] ) {
			aPath = [protocolSpecificInformation stringByDeletingLastPathComponent];
		} else {
			aPath = [NSString stringWithString:protocolSpecificInformation];
		}
		
        _srvDesc = [NSString stringWithFormat:@"%@-%@:%@", [aNetService name], _addressString, aPath];
        [serverListPopUpButton addItemWithTitle:_srvDesc];

        if ([serverListPopUpButton selectedItem] == nil && [[serverListPopUpButton itemArray] count] > 0) {
            [serverListPopUpButton selectItemAtIndex:0];
        }
    }

    // to update the uneditable fields...
    if ([serverListPopUpButton numberOfItems] > 0) {
        [self selectRepository:nil];
        [serverListPopUpButton setEnabled:YES];
    } else {
        [serverListPopUpButton setEnabled:NO];

    }
}

-(IBAction)selectRepository:(id)sender
    /*" This method takes the information in the selected bonjour repository
        and sets it into the appropriate fields for use in connecting to a CVS
        repository using the pserver connection method.
    "*/
{
    NSString *aHost, *aRepositoryPath;
    NSArray *_allElements;
    NSArray *_mainElements; 

    if ([serverListPopUpButton selectedItem] == nil && [serverListPopUpButton numberOfItems] > 0) {
        [serverListPopUpButton selectItemAtIndex:0];
    }

    _allElements = [[serverListPopUpButton titleOfSelectedItem] componentsSeparatedByString:@"-"];
    _mainElements = [[_allElements objectAtIndex:1] componentsSeparatedByString:@":"];

    aHost = [_mainElements objectAtIndex:0];
    aRepositoryPath = [_mainElements objectAtIndex:1];

    [repositoryProperties setRepositoryHost:aHost];
    [repositoryProperties setRepositoryPath:aRepositoryPath];
}


- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didNotSearch:(NSDictionary *)errorDict
    /*" This is a NSNetServiceBrowser delegate method. Here we put an alert
        panel and turn off searching.

        See Also: #netServiceBrowser:didNotSearch: in the NSNetServiceBrowser
        class.
    "*/
{
    NSString *anErrorCode = nil;
    NSString *anErrorDomain = nil;
    
    SEN_ASSERT_CONDITION(((domainBrowser == aNetServiceBrowser) || 
                          (serviceBrowser == aNetServiceBrowser)));

    isSearching = NO;
    
    anErrorCode = [errorDict objectForKey:NSNetServicesErrorCode];
    anErrorDomain = [errorDict objectForKey:NSNetServicesErrorDomain];
    
    NSRunAlertPanel(@"Bonjour Search Error", 
                    @"The following Bonjour error occurred:%@ in domain %@.", 
                    @"OK", nil, nil,
                    anErrorCode, anErrorDomain);    
}
-(void)netServiceBrowserWillSearch:(NSNetServiceBrowser *)aNetServiceBrowser
    /*" This is a NSNetServiceBrowser delegate method. Here we turn on searching
        and update the progress message. An assertion is raised if 
        aNetServiceBrowser is unknown.

        See Also: #netServiceBrowserWillSearch: in the NSNetServiceBrowser class.
    "*/
{
    NSString *progressMsg = nil;
    
    SEN_ASSERT_CONDITION(((domainBrowser == aNetServiceBrowser) || 
                          (serviceBrowser == aNetServiceBrowser)));
    isSearching = YES;
    if ( domainBrowser == aNetServiceBrowser ) {
        progressMsg = [NSString stringWithFormat:
            @"Searching for Bonjour domains..."];
    } else {
        progressMsg = [NSString stringWithFormat:
            @"Searching for %@ services in domain %@...",
            @"_cvspserver._tcp.", currentDomain];
    }
    [searchProgressTextField setStringValue:progressMsg];
}

-(void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser *)aNetServiceBrowser
    /*" This is a NSNetServiceBrowser delegate method. Here we turn off 
        searching and update the progress message. If there are domains that 
        still have not been searched then a search is started for the service
        "_cvspserver._tcp." in one of them. An assertion is raised if 
        aNetServiceBrowser is unknown.

        See Also: #netServiceBrowserDidStopSearch: in the NSNetServiceBrowser
        class.
    "*/
{
    NSString *aDomain = nil;

    SEN_ASSERT_CONDITION(((domainBrowser == aNetServiceBrowser) || 
                         (serviceBrowser == aNetServiceBrowser)));

    isSearching = NO;
    [searchProgressTextField setStringValue:@""];
    
    if ( isNotEmpty(bonjourDomains) ) {
        aDomain = [bonjourDomains anyObject];
        ASSIGN(currentDomain, aDomain);
        [serviceBrowser 
                    searchForServicesOfType:@"_cvspserver._tcp."
                                   inDomain:currentDomain];
        [bonjourDomains removeObject:currentDomain];
    }
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didFindDomain:(NSString *)domainString moreComing:(BOOL)moreComing
    /*" This is a NSNetServiceBrowser delegate method. Here we add the newly 
        found domain to a set and stop the search if there is no more coming. An
        assertion is raised if aNetServiceBrowser is not our domain browser or
        if domainString is nil;

        See Also: #netServiceBrowser:didFindDomain:moreComing: in the 
        NSNetServiceBrowser class.
    "*/
{    
    SEN_ASSERT_NOT_NIL(domainString);
    SEN_ASSERT_CONDITION((domainBrowser == aNetServiceBrowser));
    [bonjourDomains addObject:domainString]; // add the domain

    if ( moreComing == NO ) {
        [domainBrowser stop];
    }    
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didRemoveDomain:(NSString *)domainString moreComing:(BOOL)moreComing
    /*" This is a NSNetServiceBrowser delegate method. Here we remove the newly 
        removed domain from a set and stop the search if there is no more coming.
        An assertion is raised if aNetServiceBrowser is not our domain browser 
        or if domainString is nil;

        See Also: #netServiceBrowser:didRemoveDomain:moreComing: in the 
        NSNetServiceBrowser class.
    "*/
{    
    SEN_ASSERT_NOT_NIL(domainString);
    SEN_ASSERT_CONDITION((domainBrowser == aNetServiceBrowser));
    [bonjourDomains removeObject:domainString];
    
    if ( moreComing == NO ) {
        [domainBrowser stop];
    }    
}

-(void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didFindService:(NSNetService *)aNetService moreComing:(BOOL)moreComing
    /*" This is a NSNetServiceBrowser delegate method. Here we add the newly 
        found service to an array, start up the resolving of this service and
        stop the search if there is no more services coming. An assertion is 
        raised if aNetServiceBrowser is not our service browser or if 
        aNetService is nil;

        See Also: #netServiceBrowser:didFindService:moreComing: in the 
        NSNetServiceBrowser class.
    "*/
{
    SEN_ASSERT_NOT_NIL(aNetService);
    SEN_ASSERT_CONDITION((serviceBrowser == aNetServiceBrowser));

    [aNetService setDelegate:self];
    [allServices addObject:aNetService]; // remove the service
	if([NSNetService instancesRespondToSelector:@selector(resolveWithTimeout:)]) {
		// Tiger
		[aNetService resolveWithTimeout:30.]; // FIXME Use userDefault?
	} else {
		// Panther
		[aNetService resolve];
	}
    isResolvingServices = YES;

    if ( moreComing == NO ) {
        [serviceBrowser stop];
    }
}
-(void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didRemoveService:(NSNetService *)aNetService moreComing:(BOOL)moreComing
    /*" This is a NSNetServiceBrowser delegate method. Here we remove the newly 
        removed service from an array and stop the search if there is no more 
        coming. An assertion is raised if aNetServiceBrowser is not our service 
        browser or if aNetService is nil;

        See Also: #netServiceBrowser:didRemoveService:moreComing: in the 
        NSNetServiceBrowser class.
    "*/
{
    SEN_ASSERT_NOT_NIL(aNetService);
    SEN_ASSERT_CONDITION((serviceBrowser == aNetServiceBrowser));

    [allServices removeObject:aNetService]; // remove the service
    if ( moreComing == NO ) {
        [serviceBrowser stop];
    }
}

- (void)netService:(NSNetService *)aNetService didNotResolve:(NSDictionary *)errorDict
    /*" This is a NSNetServiceBrowser delegate method. Here we put an alert
        panel. We call #updateUI if there are no more services to resolve.

        See Also: #netService:didNotResolve: in the NSNetServiceBrowser class.
    "*/
{
    NSString *progressMsg = nil;
    NSString *anErrorCode = nil;
    NSString *anErrorDomain = nil;

    [allServices removeObject:aNetService]; // remove the service

    anErrorCode = [errorDict objectForKey:NSNetServicesErrorCode];
    anErrorDomain = [errorDict objectForKey:NSNetServicesErrorDomain];
    
    NSRunAlertPanel(@"Bonjour Resolve Error", 
                    @"The following Bonjour error occurred:%@ in domain %@.", 
                    @"OK", nil, nil,
                    anErrorCode, anErrorDomain);    
    
    if ( [servicesResolved count] == [allServices count] ) {
        isResolvingServices = NO;
        progressMsg = [NSString stringWithFormat:
            @"All services resolved as of %@.", [NSCalendarDate calendarDate]];        
        [searchProgressTextField setStringValue:progressMsg];
        [self updateUI]; // if there aren't any more coming
    }    
}

- (void)netServiceDidResolveAddress:(NSNetService *)aNetService
    /*" This is a NSNetServiceBrowser delegate method. Here we call #updateUI if
        there are no more services to resolve. Or update the progress message
        if there are.

        See Also: #netServiceDidResolveAddress: in the NSNetServiceBrowser class.
    "*/
{
    NSString *progressMsg = nil;
    
    [servicesResolved addObject:aNetService]; // add the service
    // This must be done here because, as you may or may not know,
    // the TXT information doesn't arrive unless you've resolved the
    // service.
    
    if ( [servicesResolved count] >= [allServices count] ) {
        isResolvingServices = NO;
        progressMsg = [NSString stringWithFormat:
            @"All services resolved as of %@.", [NSCalendarDate calendarDate]];        
        [searchProgressTextField setStringValue:progressMsg];
        [self updateUI]; // if there aren't any more coming
    } else {
        progressMsg = [NSString stringWithFormat:@"Resolving services..."];        
        [searchProgressTextField setStringValue:progressMsg];
    }
}

- (IBAction)openLocalRepositoryPath:(id)sender
    /*" We use this
		method to set the repository path when using the browse button the 
		select the path to a local repository.
    "*/
{
	NSOpenPanel	*anOpenPanel	= nil;
	NSArray		*theFilenames	= nil;
	NSString	*aDirectory		= nil;
	int			 aModalCode		= NSCancelButton;
	
	anOpenPanel = [NSOpenPanel openPanel];
	[anOpenPanel setAllowsMultipleSelection:NO];
	[anOpenPanel setCanChooseFiles:NO];
	[anOpenPanel setCanChooseDirectories:YES];
	
	aModalCode = [anOpenPanel runModalForTypes:nil];
	if ( aModalCode == NSOKButton ) {
		theFilenames = [anOpenPanel filenames];
		if ( isNotEmpty(theFilenames) ) {
			aDirectory = [theFilenames objectAtIndex:0];
			[repositoryProperties setRepositoryPath:aDirectory];
		}		
	}
}

- (IBAction)openCvsExecutablePath:(id)sender
{
	NSOpenPanel	*anOpenPanel		= nil;
	NSArray		*theFilenames		= nil;
	NSString	*aDirectory			= nil;
	NSString	*aCvsExecutablePath	= nil;
	int			 aModalCode			= NSCancelButton;
	
	anOpenPanel = [NSOpenPanel openPanel];
	[anOpenPanel setAllowsMultipleSelection:NO];
	[anOpenPanel setCanChooseFiles:YES];
	[anOpenPanel setCanChooseDirectories:NO];
	
	aDirectory = @"/usr/bin/";
	aModalCode = [anOpenPanel runModalForDirectory:aDirectory 
											  file:nil 
											 types:nil];
	if ( aModalCode == NSOKButton ) {
		theFilenames = [anOpenPanel filenames];
		if ( isNotEmpty(theFilenames) ) {
			aCvsExecutablePath = [theFilenames objectAtIndex:0];
			[repositoryProperties setCvsExecutablePath:aCvsExecutablePath];
		}		
	}
}


@end
