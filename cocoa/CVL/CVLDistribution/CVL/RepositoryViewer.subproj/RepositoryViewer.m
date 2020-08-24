// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "RepositoryViewer.h"
#import "RepositoryDataSource.h"
#import "AddRepositoryController.h"
#import "RepositoryProperties.h"
#import <CvsImportRequest.h>
#import <CvsCheckoutRequest.h>
#import <CvsCommitRequest.h>
#import <SenPanelFactory.h>
#import <SenFormPanelController.h>
#import <NSView.SenReplacing.h>
#import <CvsInitRequest.h>
#import <CvsModule.h>
#import <SelectorRequest.h>
#import <CVLConsoleController.h>
#import "WorkAreaViewer.h"
#import "CvsCommitPanelController.h"
#import "CVLDelegate.h"
#import <SenOpenPanelController.h>
#import <AppKit/AppKit.h>
#import <SenFoundation/SenFoundation.h>
#import <CvsImportController.h>

#define CONNECT_TIMEOUT	120

static RepositoryViewer * sharedRepositoryViewer = nil;

// The FRAME_NAME has been modified, because the min size of the new window is greater the the min size of the old one
// So, to avoid displaying mess, we rename the FRAME_NAME.
#define FRAME_NAME	@"RepositoryViewerNEW"

@interface NSObject(CVLAppDelegate)
- (void) showViewer:(WorkAreaViewer *)aViewer; // Target is CVLDelegate
@end

@interface RepositoryViewer(Private)
- (void) selectionChanged:(NSNotification *)notification;
- (void) reloadTabViewItemView;
- (void) selectRepositoryAtIndex:(int)anIndex;
- (void) selectRepository:(CvsRepository *)aRepository;
@end


@implementation RepositoryViewer

+ (RepositoryViewer *) sharedRepositoryViewer
{
    if(!sharedRepositoryViewer)
        sharedRepositoryViewer = [[self alloc] init];

    return sharedRepositoryViewer;
}

- (id) init
{
    if ( (self = [self initWithWindowNibName:@"RepositoryViewer"]) ) {
        [self setWindowFrameAutosaveName:FRAME_NAME];
        [[NSNotificationCenter defaultCenter]
                        addObserver:self
                           selector:@selector(reloadTable:)
                               name:@"RegisteredRepositoriesChanged"
                             object:nil];
        [[NSNotificationCenter defaultCenter]
                        addObserver:self
                           selector:@selector(reloadTable:)
                               name:@"RepositoryChanged"
                             object:nil];
    }
    return self;
}

- (void) windowDidLoad
{
	CvsRepository *theDefaultRepository = nil;
    int			cvsRootRow = -1;

    [super windowDidLoad];
    
    [tabView retain];
    [noRepositoryView retain];

    [[NSNotificationCenter defaultCenter]
                    addObserver:self
                       selector:@selector(selectionChanged:)
                           name:NSTableViewSelectionDidChangeNotification
                         object:repositoryTableView];
    [[NSNotificationCenter defaultCenter]
                    addObserver:self
                       selector:@selector(envVariableSelectionChanged:)
                           name:NSTableViewSelectionDidChangeNotification
                         object:envTableView];
	theDefaultRepository = [CvsRepository defaultRepository];
    if ( theDefaultRepository != nil ) {
		cvsRootRow = [[repositoryTableView dataSource] rowOfObject:theDefaultRepository];
	}
	if(cvsRootRow != -1)
        [self selectRepositoryAtIndex:cvsRootRow];
    else
        [self selectionChanged:nil]; // We want to update the tabView if no default cvsRoot thus no repository

    [[self window] setMiniwindowImage:[NSImage imageNamed:@"appicon"]];
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [tabView release];
    [noRepositoryView release];
    [[self window] setDelegate:nil];

    [super dealloc];
}

- (void) reloadTable:(NSNotification *)notification
{
    [repositoryTableView reloadData];
    [envTableView reloadData];
}

- (CvsRepository *) selectedRepository
{
    if([repositoryTableView selectedRow] != -1)
        return (CvsRepository *)[[repositoryTableView dataSource] objectAtRow:[repositoryTableView selectedRow]];
    else
        return nil;
}

-(NSArray *)selectedPaths
    /*" This method returns an array of paths as NSStrings. These paths have 
        been extracted from the path to the CVSROOT workarea plus the name of the tab 
        selected.
    "*/
{
    NSString        *aName = nil;
    NSString        *aPath = nil;
    NSString        *aCVSROOTWorkAreaPath = nil;
    CvsRepository   *theSelectedRepository = nil;
    NSArray         *theSelectedPaths = nil;
    
    theSelectedRepository = [self selectedRepository];

    if ( theSelectedRepository != nil ) {
        aCVSROOTWorkAreaPath = [theSelectedRepository CVSROOTWorkAreaPath];
        if ( isNotEmpty(aCVSROOTWorkAreaPath) ) {
            aName = [[tabView selectedTabViewItem] identifier];
            if ( isNotEmpty(aName) ) {
                aPath = [aCVSROOTWorkAreaPath stringByAppendingPathComponent:aName];
                theSelectedPaths = [NSArray arrayWithObject:aPath];
            }
        }
    }
    return theSelectedPaths;
}

- (void) selectionChanged:(NSNotification *)notification
{
    CvsRepository	*theSelectedRepository = [self selectedRepository];
    BOOL			hasValidSelectedRepository = (theSelectedRepository != nil) && [theSelectedRepository isUpToDate_WithoutRefresh];

    if(hasValidSelectedRepository){
		[CvsRepository setDefaultRepository:theSelectedRepository];
        if([tabView window] != [self window])
            [tabView senReplaceView:noRepositoryView];
        [self reloadTabViewItemView];
    }
    else if([theSelectedRepository isUpdating]){
        if([tabView window] != [self window])
            [tabView senReplaceView:noRepositoryView];
        [self reloadTabViewItemView];
    }
    else if([noRepositoryView window] != [self window])
            [noRepositoryView senReplaceView:tabView];

    [removeButton setEnabled:hasValidSelectedRepository];
    [importButton setEnabled:hasValidSelectedRepository];
    [checkoutButton setEnabled:hasValidSelectedRepository];
    [openWorkareaButton setEnabled:(hasValidSelectedRepository && ![theSelectedRepository cvsRootCheckoutFailed])];
}

- (void) envVariableSelectionChanged:(NSNotification *)notification
{
    [removeEnvVariableButton setEnabled:([envTableView selectedRow] >= 0)];
}

- (void) selectRepository:(CvsRepository *)aRepository
{
    int	anIndex = [[repositoryTableView dataSource] rowOfObject:aRepository];

    [self selectRepositoryAtIndex:anIndex];
}

- (void) selectRepositoryAtIndex:(int)anIndex
{
    // Force selection of newly added repository
    anIndex = MIN([repositoryTableView numberOfRows] - 1, anIndex); // Do not go out of bounds; select last one if anIndex is to big
    if(anIndex >= 0){
        // Notif IS sent, but lazy loading cannot work, because delegate is not asked if it allows selection => ask explicitly
        if([[repositoryTableView delegate] tableView:repositoryTableView shouldSelectRow:anIndex]){
            // Bug 1000062: If selected index does not change, no notif will be sent => deselect then reselect every time
            [repositoryTableView deselectAll:nil];
            [repositoryTableView selectRow:anIndex byExtendingSelection:NO];
            [repositoryTableView scrollRowToVisible:anIndex];
        }
    }
    else
        [repositoryTableView deselectAll:nil];
}

- (IBAction) showWindow:(id)sender
{
    [super showWindow:sender];
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"ShowRepositoryViewer"];
}

- (IBAction) addRepository:(id)sender
{
	CvsRepository	*aRepository;
    RepositoryProperties	*theRepositoryProperties;
    NSDictionary	*thePropertiesDictionary;
	int				aModalReturnCode = 0;
	
	if ( addRepositoryController == nil ) {
		addRepositoryController = [[AddRepositoryController alloc] 
									initWithWindowNibName:@"AddRepository"];
	}
	aModalReturnCode = [addRepositoryController showAddRepositoryPanel];
	if ( aModalReturnCode == NSOKButton ) {
        theRepositoryProperties = [addRepositoryController repositoryProperties];
		thePropertiesDictionary = [theRepositoryProperties propertiesDictionary];
        aRepository = [CvsRepository 
							repositoryWithProperties:thePropertiesDictionary];
        if ( aRepository != nil ) {
            [CvsRepository registerRepository:aRepository];
            if([aRepository needsLogin]){
                Request		*loginRequest;
                NSString	*password;
				
                password = [thePropertiesDictionary objectForKey:PASSWORD_KEY];
                if(password && ![password isEqual:@""])
                    loginRequest = [aRepository loginRequest];
            }
            [self selectRepository:aRepository];
        } else {
            (void)NSRunAlertPanel(@"Add Repository", 
				  @"Could not add the repository with the following properties \"%@\".",
				  nil, nil, nil, thePropertiesDictionary);
		}
    }	
}

- (IBAction) removeRepository:(id)sender
{
    CvsRepository	*theSelectedRepository;
	int	aChoice = 0;
	int	aRow = 0;

    if ( (theSelectedRepository = [self selectedRepository]) ) {
        aChoice = NSRunAlertPanel(@"Remove Repository", 
								  @"Do you really want to remove the repository from your list of avaiable repositories?", 
								  @"Yes", @"Cancel", nil, theSelectedRepository);
        if ( aChoice == NSAlertAlternateReturn ) {
            return;
        }
		
        aRow = [[repositoryTableView dataSource] rowOfObject:theSelectedRepository];
        
        if(![CvsRepository disposeRepository:theSelectedRepository]) {
			NSBeginInformationalAlertSheet(@"Removing a repository", nil, nil, nil, [self window], nil, NULL, NULL, NULL, @"This repository is currently in use, it will be removed from your list of repositories when the application terminates.");
			[repositoryTableView reloadData];
		} else {
			[self selectRepositoryAtIndex:aRow];
		}
    }
}

- (IBAction) repositoryImport:(id)sender
{
    [self importIntoRepository:[CvsRepository defaultRepository] importInfo:nil];
}

- (void) importIntoRepository:(CvsRepository *)aRepository importInfo:(NSDictionary *)importInfo;
{
	if ( cvsImportController == nil ) {
		cvsImportController = [[CvsImportController alloc] 
									initWithWindowNibName:@"CvsImportPanel"];
	}
	[cvsImportController importIntoRepository:aRepository];
}

- (void) goForModuleCvsCheckoutInRepository:(CvsRepository *)aRepository
{
    CvsCheckoutRequest		*request;
    SenFormPanelController	*moduleController = [[SenPanelFactory sharedPanelFactory] handleOfPanelWithName:@"CvsCheckoutModulePanel"];

    checkoutDateTextField = [[[moduleController formController] controlForKey:@"date"] retain];
	SEN_ASSERT_NOT_NIL(checkoutDateTextField);
    [moduleController setObjectValue:aRepository forKey:@"repository"];
    if([moduleController showAndRunModal] == NSOKButton){
        NSString	*dateString;
        NSString	*directoryName;

        if([checkoutDateTextField objectValue]){
			// http://www.w3.org/TR/NOTE-datetime
			// ISO8601
			// e.g. YYYY-MM-DDThh:mm:ss.sTZD (eg 1997-07-16T19:20:30.45+01:00)
			dateString = [(NSCalendarDate *)[moduleController objectValueForKey:@"date"] descriptionWithCalendarFormat:@"%Y-%m-%dT%H:%M:%S%z"];
        } else {
			dateString = nil;
		}

        request = [CvsCheckoutRequest cvsCheckoutRequestForModule:[moduleController objectValueForKey:@"module"]
                                                     inRepository:aRepository
                                                           toPath:[moduleController objectValueForKey:@"workAreaPath"]
                                                         revision:[moduleController objectValueForKey:@"revision"]
                                                             date:dateString
                                          removesStickyAttributes:[[moduleController objectValueForKey:@"removesStickyAttributes"] boolValue]];
        [request setIsReadOnly:[[moduleController objectValueForKey:@"readOnly"] boolValue]];
        directoryName = [moduleController objectValueForKey:@"directoryName"];
        if([directoryName length])
            [request setDestinationPath:directoryName];
		[request setIsQuiet:NO];

        [[NSNotificationCenter defaultCenter]
                    addObserver:self
                       selector:@selector(requestCompleted:)
                           name:@"RequestCompleted"
                         object:request];
        [request schedule];
    }
    [checkoutDateTextField release]; checkoutDateTextField = nil;
}

- (IBAction) repositoryCheckout:(id)sender
{
    CvsRepository	*aRepository = [CvsRepository defaultRepository];
    
    if([aRepository isUpToDate])
        [self goForModuleCvsCheckoutInRepository:aRepository];
    else
        [[NSNotificationCenter defaultCenter]
                      addObserver:self
                         selector:@selector(repositoryUpdated:)
                             name:@"RequestCompleted"
                           object:[aRepository checkoutRequest]];
}

- (IBAction) openRepositoryWorkarea:(id)sender
    /*" This method is used to open a CVSROOT workarea in this repository's 
		support directory. The CVSROOT workarea corresponds to
        the repository selected in the Repositories Panel of CVL.
    "*/
{
    CvsRepository	*theSelectedRepository = [self selectedRepository];
    WorkAreaViewer *aViewer = nil;
    NSString *aCVSROOTWorkAreaPath = nil;
    CVLDelegate *theAppDelegate = nil;
        
    SEN_ASSERT_NOT_NIL(theSelectedRepository);
    SEN_ASSERT_CONDITION([theSelectedRepository isUpToDate]);

    aCVSROOTWorkAreaPath =[theSelectedRepository CVSROOTWorkAreaPath];
    if ( isNotEmpty(aCVSROOTWorkAreaPath) ) {
        theAppDelegate = [NSApp delegate];
        aViewer = [theAppDelegate viewerForPath:aCVSROOTWorkAreaPath];
        [theAppDelegate showViewer:aViewer];
    }
}

- (void) repositoryUpdated:(NSNotification *)notification
{
    CvsRequest	*request = [notification object];
    
    NSParameterAssert(notification != nil);
    [[NSNotificationCenter defaultCenter]
                  removeObserver:self
                            name:@"RequestCompleted"
                          object:request];

    if([request succeeded])
        [[NSRunLoop currentRunLoop] performSelector:@selector(goForModuleCvsCheckoutInRepository:)
                                             target:self
                                           argument:[request repository]
                                              order:0
                                              modes:[NSArray arrayWithObjects:NSDefaultRunLoopMode, NSModalPanelRunLoopMode, nil]];
}

- (void) requestCompleted:(NSNotification *)notification
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:[notification name] object:[notification object]];    
    [[NSApp delegate] requestCompleted:notification];
}

- (IBAction) newRepository:(id)sender
{
    SenFormPanelController	*newRepositoryPanel = [[SenPanelFactory sharedPanelFactory] handleOfPanelWithName:@"CvsNewRepositoryPanel"];

    if([newRepositoryPanel showAndRunModal] == NSOKButton){
        NSDictionary	*tagInfos = [newRepositoryPanel dictionaryValue];
        NSString		*path = [tagInfos objectForKey:@"path"];

        if(path && [path length] > 0){
            CvsInitRequest	*initRequest = [CvsInitRequest cvsInitRequestWithPath:path];

            [initRequest schedule];
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(initRequestCompleted:) name:@"RequestCompleted" object:initRequest];
        } else {
#ifdef MACOSX
            NSBeginAlertSheet(@"Invalid Repository", nil, nil, nil, [self window], nil, NULL, NULL, NULL, @"You need to give a valid path for the new repository, of the form computer:/path/to/repository or /path/to/repository.");
#else
            (void)NSRunAlertPanel(@"New Repository", @"You need to give a valid path for the new repository, of the form computer:/path/to/repository or /path/to/repository.", nil, nil, nil);
#endif
        }
    }
}

- (void) initRequestCompleted:(NSNotification *)aNotif
{
    CvsRepository	*aRepository;
    NSDictionary	*thePropertiesDictionary;

    NSParameterAssert(aNotif != nil && [[aNotif object] isKindOfClass:[CvsInitRequest class]]);

    [[NSNotificationCenter defaultCenter] removeObserver:self name:[aNotif name] object:[aNotif object]];
    if(![[aNotif object] succeeded]){
        NSBeginAlertSheet(@"Unable to create new repository", nil, nil, nil, [self window], nil, NULL, NULL, NULL, @"Unable to create repository at path %@.", [[aNotif object] newRepositoryPath]);
        return;
    }
    
    thePropertiesDictionary = [[aNotif object] result];
    aRepository = [CvsRepository repositoryWithProperties:thePropertiesDictionary];
    if(aRepository){
        [CvsRepository registerRepository:aRepository];
        if([aRepository needsLogin]){
            Request		*loginRequest;
            NSString	*password;

            password = [thePropertiesDictionary objectForKey:PASSWORD_KEY];
            if(password && ![password isEqual:@""])
                loginRequest = [aRepository loginRequest];
        }
        [self selectRepository:aRepository];
    }
}

- (IBAction) validateRepositoryParams:(id)sender
{
    NSString		*aFileName = [[tabView selectedTabViewItem] identifier];
    CvsRepository	*theSelectedRepository = [self selectedRepository];

    NSAssert(theSelectedRepository != nil, @"No repository is selected!");
    NSAssert(aFileName != nil, @"Selected tab identifier is nil");

    if([aFileName isEqualToString:@"modules"]){
        if([CvsModule checkModuleDescription:[textView string] forRepository:theSelectedRepository]) {
            NSBeginInformationalAlertSheet(@"File consistency", nil, nil, nil, [self window], nil, NULL, NULL, NULL, @"File %@ is consistent.", [[tabView selectedTabViewItem] identifier]);
        }
    } else {
        NSBeginInformationalAlertSheet(@"File consistency", nil, nil, nil, [self window], nil, NULL, NULL, NULL, @"Feature not yet implemented for file %@.", [[tabView selectedTabViewItem] identifier]);
    }
}

- (IBAction) saveRepositoryParams:(id)sender
    /*" This action method commits any changes in the CVSROOT files named
        "modules", "cvsignore" or "cvswrappers" that are displayed in a tab view
        in the repository panel. Clicking on the "Saved" button calls 
        this method.
    "*/
{
    NSString				*aName = [[tabView selectedTabViewItem] identifier];
    NSString				*aFileName;
    NSArray                 *someFiles = nil;
    CvsRepository			*theSelectedRepository = [self selectedRepository];

    SEN_ASSERT_NOT_NIL(theSelectedRepository);
    SEN_ASSERT_NOT_EMPTY(aName);
    
    if([aName isEqualToString:@"modules"] ) {
        if(![CvsModule checkModuleDescription:[textView string] forRepository:theSelectedRepository]) {
            return;
        }
    }
    aFileName = [[theSelectedRepository CVSROOTWorkAreaPath] stringByAppendingPathComponent:aName];
    if(![[textView string] writeToFile:aFileName atomically:NO]){
        NSBeginAlertSheet(@"Save", nil, nil, nil, [self window], nil, NULL, NULL, NULL, @"Unable to save file %@.", aFileName);
        return;
    }

    someFiles = [NSArray arrayWithObject:aName];
    [self commitFiles:someFiles];
}

- (CvsCommitPanelController *)cvsCommitPanelController
    /*" This method returns an instance of the class CvsCommitPanelController;
        first creating it if needed.
    "*/
{
    if ( cvsCommitPanelController == nil ) {
        cvsCommitPanelController = [[CvsCommitPanelController alloc] 
                                    initWithWindowNibName:@"CvsCommitPanel"];
    }
    return cvsCommitPanelController;
}

- (void) commitFiles:(NSArray *)someFiles
    /*" This method commits the files in the array named someFiles. If templates
        are in use, a preliminary commit request is generated with a option to
        use cvlEditor as an editor. Then cvlEditor will pass back the path of
        the completed template to this application. So that eventually the 
        method -showCommitPanelWithSelectedFilesUsingTemplateFile: in this class
        gets called along with the path to this completed template file. That
        method will then display the commit panel with the completed template 
        contents which the user can then fill in. Then in that method a second 
        commit request is called which uses this filled in template file as the
        commit message.

        If templates are not in use then this method calls on the 
        CvsCommitPanelController to display the commit panel. Then takes the
        returned commit message and creates a commit request with it. In this
        case the workarea for the CVSROOT repository is reloaded.
    "*/
{
    CvsCommitRequest            *aCvsCommitRequest = nil;
    SelectorRequest             *reloadRequest = nil;
    NSString                    *aCVSROOTWorkAreaPath = nil;
    NSString                    *aMessage = nil;
    CvsCommitPanelController    *theCommitPanelController = nil;
    CvsRepository               *theSelectedRepository = nil;
    BOOL                        useCvsTemplates = NO;
    
    theSelectedRepository = [self selectedRepository];
    SEN_ASSERT_NOT_NIL(theSelectedRepository);

    aCVSROOTWorkAreaPath = [theSelectedRepository CVSROOTWorkAreaPath];
    useCvsTemplates = [[NSUserDefaults standardUserDefaults] 
                                boolForKey:@"UseCvsTemplates"];
    if( useCvsTemplates == YES ) {
        aCvsCommitRequest = [CvsCommitRequest 
                                    cvsCommitRequestForFiles:someFiles 
                                                      inPath:aCVSROOTWorkAreaPath 
                                                     message:nil];
        [aCvsCommitRequest schedule];
    } else {
        theCommitPanelController = [self cvsCommitPanelController];
        aMessage = [theCommitPanelController showCommitPanelWithFiles:someFiles 
                                                    usingTemplateFile:nil];
        if ( aMessage != nil ) {
            aCvsCommitRequest = [CvsCommitRequest 
                                    cvsCommitRequestForFiles:someFiles 
                                                      inPath:aCVSROOTWorkAreaPath 
                                                     message:aMessage];
            if ( aCvsCommitRequest != nil ) {
                reloadRequest = [SelectorRequest 
                                requestWithTarget:self
                                         selector:@selector(reloadRepository:) 
                                         argument:theSelectedRepository];
                [reloadRequest addPrecedingRequest:aCvsCommitRequest];
                [reloadRequest schedule];
            }                
        }
    }
}

- (BOOL) showCommitPanelWithSelectedFilesUsingTemplateFile:(NSString *)aTemplateFile
    /*" This method is called by the CVLDelegate. This occurs after CVS is
        sent a commit message with an option to use CVLEditorClient as an editor.
        CVS then creates a temporary file and then CVLEditorClient is called 
        with an argument equal to the path to this temporary file. 
        CVLEditorClient then calls this method in CVLDelegate with that same 
        path. That method then calls this viewer with the same method name and 
        argument. This method will then display a commit panel which will show 
        the contents of this temporary file (i.e. a template file). This method 
        then returns YES if it was successful in committing the selected files 
        using the contents of this template file.

        See also: #showCommitPanelWithSelectedFilesUsingTemplateFile: in the 
        classes CVLEditorClient, CVLDelegate and WorkAreaViewer.
    "*/
{
    CvsRepository               *theSelectedRepository = nil;
    NSString                    *aName = nil;
    NSString                    *aMessage = nil;
    SelectorRequest             *reloadRequest = nil;
    CvsCommitPanelController    *theCommitPanelController = nil;
    NSArray                     *someFiles = nil;
    
    theSelectedRepository = [self selectedRepository];
    aName = [[tabView selectedTabViewItem] identifier];
    
    SEN_ASSERT_NOT_NIL(theSelectedRepository);
    SEN_ASSERT_NOT_EMPTY(aName);

    someFiles = [NSArray arrayWithObject:aName];
    theCommitPanelController = [self cvsCommitPanelController];
    aMessage = [theCommitPanelController showCommitPanelWithFiles:someFiles 
                                                usingTemplateFile:aTemplateFile];
    if ( aMessage != nil ) {
        [aMessage writeToFile:aTemplateFile atomically:YES];
        reloadRequest = [SelectorRequest requestWithTarget:self
                                                  selector:@selector(reloadRepository:) 
                                                  argument:theSelectedRepository];
        [reloadRequest schedule];
        return YES;
    }
    return NO;
}

- (void) reloadRepository:(CvsRepository *)aRepository
{
    [self reloadTabViewItemView];
    [aRepository checkoutAgain];
}

- (IBAction) revertRepositoryParams:(id)sender
{
    // Force reloading/parsing of ALL files; we need to DELETE file first, then do a checkout on it
    NSString		*aFileName = [[tabView selectedTabViewItem] identifier];
    CvsRepository	*theSelectedRepository = [self selectedRepository];
    CvsRequest		*aRequest;

    NSAssert(theSelectedRepository != nil, @"No repository is selected!");
    NSAssert(aFileName != nil, @"Selected tab identifier is nil");

    (void)[[NSFileManager defaultManager] removeFileAtPath:[[theSelectedRepository CVSROOTWorkAreaPath] stringByAppendingPathComponent:aFileName] handler:nil];

    aRequest = [theSelectedRepository checkoutAgain];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(fileRequestCompleted:) name:@"RequestCompleted" object:aRequest];
    [self reloadTabViewItemView];
}

- (void) fileRequestCompleted:(NSNotification *)aNotif
{
    [self reloadTabViewItemView];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:[aNotif name] object:[aNotif object]];    
}

- (void) tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
    [self reloadTabViewItemView];
}

- (void) reloadTabViewItemView
{
    CvsRepository	*theSelectedRepository = [self selectedRepository];
    NSString		*aName = [[tabView selectedTabViewItem] identifier];
	NSString		*fileContents = nil;
    BOOL			fileAction = YES;

    NSAssert(theSelectedRepository != nil, @"Trying to reload tab view when no repository is selected!");
    NSAssert(aName != nil, @"[[tabView selectedTabViewItem] identifier] is nil!");

	[textView setString:@""];
    if([aName isEqualToString:@"environment"]){
        [addEnvVariableButton setEnabled:YES];
        [removeEnvVariableButton setEnabled:([envTableView selectedRow] >= 0)];
        [envTableView reloadData];
    } else {
		if ( [aName isEqualToString:@"modules"] ) {
			textView = modulesTextView;
			saveRepositoryParamsButton = saveModulesButton;
			validateRepositoryParamsButton = validateModulesButton;
			revertRepositoryParamsButton = revertModulesButton;
		} else if ( [aName isEqualToString:@"cvsignore"] )  {
			textView = ignoredFilesTextView;
			saveRepositoryParamsButton = saveIgnoredFilesButton;
			validateRepositoryParamsButton = validateIgnoredFilesButton;
			revertRepositoryParamsButton = revertIgnoredFilesButton;			
		} else if ( [aName isEqualToString:@"cvswrappers"] )  {
			textView = cvsWrappersTextView;
			saveRepositoryParamsButton = saveCVSWrappersButton;
			validateRepositoryParamsButton = validateCVSWrappersButton;
			revertRepositoryParamsButton = revertCVSWrappersButton;			
		} else {
			NSString *anErrorMsg = [NSString stringWithFormat:
				@"An identifier should be either environment, modules, cvsignore or cvswrappers. Instead it was %@. Please contact Sente for a fix to this problem.",
				aName];
			SEN_ASSERT_CONDITION_MSG((NO),anErrorMsg);
		}
		
        if([theSelectedRepository isUpToDate]){
			fileContents = [self getFileContentsForFilename:aName];
            if(fileContents)
                [textView setString:fileContents];
            else{
                [textView setString:@"N/A"];
                fileAction = NO;
            }
        }
        else{
            if([theSelectedRepository isUpdating])
                [textView setString:@"Information is being loaded. Please wait..."];
            else
                [textView setString:@"N/A"];
            fileAction = NO;
        }
        fileAction = fileAction && ![theSelectedRepository cvsRootCheckoutFailed];
        [textView setEditable:fileAction];
        [saveRepositoryParamsButton setEnabled:fileAction];
        [validateRepositoryParamsButton setEnabled:fileAction];
        [revertRepositoryParamsButton setEnabled:![theSelectedRepository isUpdating]]; // This button should always be enabled, even if file does not exist. Exception: CVSROOT is being updated.
    }
	[repositoryRootTextField setStringValue:[theSelectedRepository root]];
	[repositoryCompressionLevelTextField setObjectValue:[theSelectedRepository compressionLevel]];
	[repositoryCVSExecutablePathTextField setObjectValue:[theSelectedRepository cvsExecutablePath]];
    [openWorkareaButton setEnabled:(![theSelectedRepository cvsRootCheckoutFailed] && ![theSelectedRepository isUpdating])];
}

- (BOOL) tableView:(NSTableView *)aTableView shouldSelectRow:(int)row
{
    if(aTableView == envTableView) {
		return YES;
    } else {
        //Force refresh (checkout) of repository, in a lazy way
        // This call forces the update (checkout) of the repository; as the result is obtained asynchronously,
        // we first receive NO, and later we are notified of the results
        CvsRepository	*theSelectedRepository = [[repositoryTableView dataSource] objectAtRow:row];

        if([CvsRepository isRepositoryToBeDisposed:theSelectedRepository])
            return YES;
        if(![theSelectedRepository isUpToDate])
			aCounter = 0;
            [[NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(repositoryIsUpdating:) userInfo:nil repeats:YES] retain];
    }
    return YES;
}

- (void) repositoryIsUpdating:(NSTimer *)aTimer
{
    CvsRepository	*theSelectedRepository = [self selectedRepository];
	int				 aChoice				= NSAlertDefaultReturn;

	if ( theSelectedRepository == nil ) {
		[aTimer invalidate];
        [aTimer release];
		return;
	}
	
    if([CvsRepository isRepositoryToBeDisposed:theSelectedRepository] || [theSelectedRepository isUpToDate_WithoutRefresh]){
        [aTimer invalidate];
        [aTimer release];
        [self selectionChanged:nil];
    }
    else if(![theSelectedRepository isUpdating]){
        // Updating failed; warn user and remove repository from list
        int	aRow = [[repositoryTableView dataSource] rowOfObject:theSelectedRepository];

        [self selectRepositoryAtIndex:aRow];
        if(![CvsRepository disposeRepository:theSelectedRepository])
            NSBeginInformationalAlertSheet(@"Invalid Repository", nil, nil, nil, [self window], nil, NULL, NULL, NULL, @"This repository \"%@\" is currently in use, but is invalid. It will be removed from your list of repositories when the application terminates.", [theSelectedRepository root]);
        else
            NSBeginInformationalAlertSheet(@"Invalid Repository", nil, nil, nil, [self window], nil, NULL, NULL, NULL, @"This repository \"%@\" is invalid. It is removed from your list of repositories.", [theSelectedRepository root]);
		[aTimer invalidate];
        [aTimer release];
    } else {
		// Abort after CONNECT_TIMEOUT tries. That would be CONNECT_TIMEOUT seconds.
		aCounter++;
		if ( aCounter > CONNECT_TIMEOUT ) {
			aChoice = NSRunAlertPanel(@"Unreachable Repository", 
                                      @"We could not reach the repository \"%@\" after %d seconds. Do you want to continue trying for another %d seconds?",
                                      @"Yes", @"No", nil, 
									  [theSelectedRepository root],
									  CONNECT_TIMEOUT, CONNECT_TIMEOUT); 
            if ( aChoice == NSAlertDefaultReturn ) {
				aCounter = 0;
			} else {
				[aTimer invalidate];
				[aTimer release];
            }
		}
	}
}

- (BOOL) validateMenuItem:(id <NSMenuItem>)menuItem
{
    if([menuItem action] == @selector(newRepository:) || [menuItem action] == @selector(addRepository:))
        return YES;
    if([self selectedRepository])
        return YES;
    else
        return NO;
}

- (IBAction) addEnvironmentVariable:(id)sender
{
    CvsRepository		*theSelectedRepository = [self selectedRepository];
    NSMutableDictionary	*newDict = [[theSelectedRepository environment] mutableCopy];

    [newDict setObject:@"" forKey:@""];
    [theSelectedRepository setEnvironment:newDict];
    [newDict release];
    [envTableView reloadData];
}

- (IBAction) removeEnvironmentVariable:(id)sender
{
    CvsRepository		*theSelectedRepository = [self selectedRepository];
    NSMutableDictionary	*newDict = [[theSelectedRepository environment] mutableCopy];
    NSEnumerator		*selectedRowEnumerator = [envTableView selectedRowEnumerator];
    NSNumber			*aRow;
    NSTableColumn		*tableColumn = [envTableView tableColumnWithIdentifier:@"key"];
	NSString *aKey = nil;

    while ( (aRow = [selectedRowEnumerator nextObject]) ) {
		aKey = [self tableView:envTableView objectValueForTableColumn:tableColumn row:[aRow intValue]];
		if ( aKey != nil ) {
			[newDict removeObjectForKey:aKey];        
		}
	}

    [theSelectedRepository setEnvironment:newDict];
    [newDict release];
    [envTableView reloadData];
}

- (int) numberOfRowsInTableView:(NSTableView *)aTableView
{
	unsigned int aCount = 0;
	
	if ( aTableView == envTableView ) {
		mySelectedRepository = [self selectedRepository];
		aCount = [[mySelectedRepository environment] count];
	}
	return aCount;
}

- (id) tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
	id aValue = nil;

	if ( aTableView == envTableView ) {
		NSArray			*orderedKeys = [[[mySelectedRepository environment] allKeys] sortedArrayUsingSelector:@selector(compare:)];
		NSString *aKey = nil;

		aKey = [orderedKeys objectAtIndex:row];
		if([[tableColumn identifier] isEqualToString:@"key"])
			aValue = aKey;
		else
			aValue = [[mySelectedRepository environment] objectForKey:aKey];   
	}
	return aValue;
}

- (void) tableView:(NSTableView *)aTableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
	if ( aTableView == envTableView ) {
		NSArray				*orderedKeys = [[[mySelectedRepository environment] allKeys] sortedArrayUsingSelector:@selector(compare:)];
		NSMutableDictionary	*newDict = [[mySelectedRepository environment] mutableCopy];
		NSString *aKey = nil;
		
		if([[tableColumn identifier] isEqualToString:@"key"]){
			if(![orderedKeys containsObject:object]){
				aKey = [orderedKeys objectAtIndex:row];
				if ( aKey != nil ) {
					[newDict setObject:[newDict objectForKey:aKey] forKey:object];
					[newDict removeObjectForKey:aKey];
				}
			}
		}
		else
			[newDict setObject:object forKey:[orderedKeys objectAtIndex:row]];
		[mySelectedRepository setEnvironment:newDict];
		[newDict release];
		[envTableView reloadData];		
	}
}

- (void) tableView:(NSTableView *)aTableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(int)row
	/*" This method will make the text in the cell to be displayed italic if it is 
		inherited from the CVL environment else the text will be bold.
	"*/
{
    NSString	*aKey, *aValue;
    BOOL		inherited;

	if ( aTableView == envTableView ) {
		NSArray			*orderedKeys = [[[mySelectedRepository environment] allKeys] sortedArrayUsingSelector:@selector(compare:)];

		aKey = [orderedKeys objectAtIndex:row];
		aValue = [[mySelectedRepository environment] objectForKey:aKey];
		inherited = [mySelectedRepository isInheritedEnvironmentKey:aKey value:aValue];
		if(inherited)
			[cell setFont:[[NSFontManager sharedFontManager] convertFont:[NSFont fontWithName:@"Helvetica" size:[[cell font] pointSize]] toHaveTrait:NSItalicFontMask]];
		else
			[cell setFont:[[NSFontManager sharedFontManager] convertFont:[NSFont fontWithName:@"Helvetica" size:[[cell font] pointSize]] toHaveTrait:NSBoldFontMask]];
	}
}

- (IBAction)updateCompressionLevel:(id)sender
{
	CvsRepository	*theSelectedRepository = nil;
	NSNumber *aCompressionLevel = nil;
	
	SEN_ASSERT_NOT_NIL(repositoryCompressionLevelTextField);

	theSelectedRepository = [self selectedRepository];
    if ( theSelectedRepository != nil ) {
		aCompressionLevel = [repositoryCompressionLevelTextField objectValue];
		[theSelectedRepository setCompressionLevel:aCompressionLevel];
		[repositoryTableView reloadData];
	}
		
}

- (IBAction)updateCVSExecutablePath:(id)sender
{
	CvsRepository	*theSelectedRepository = nil;
	
	SEN_ASSERT_NOT_NIL(repositoryCVSExecutablePathTextField);
	
	theSelectedRepository = [self selectedRepository];
    if ( theSelectedRepository != nil ) {
		NSString	*aPath = [repositoryCVSExecutablePathTextField objectValue];

		[theSelectedRepository setCvsExecutablePath:aPath]; // FIXME We don't validate it, unlike when adding new repository
	}
	
}

- (BOOL)control:(NSControl *)aControl didFailToFormatString:(NSString *)aString errorDescription:(NSString *)anError
    /*" This method allows us to present an error panel to user if he starts to 
		type in an incorrect compression level. The compresion level should be 
		between 0 and 9 inclusive.
    "*/
{
    NSString *aTitle = nil;
    

    SEN_ASSERT_NOT_NIL(aControl);
    
    if ( aControl == repositoryCompressionLevelTextField ) {
        aTitle = [NSString stringWithFormat:@"Formatting Error"];
        (void)NSRunAlertPanel(aTitle, anError, nil, nil, nil);
		return NO;
    }
	return YES;
}

- (void)senOpenPanelController:(SenOpenPanelController *)aSenOpenPanelController selectedDirectory:(NSString *)aDirectory selectedFileNames:(NSArray *)someFilenames
    /*" This is the delegate method for the SenOpenPanelController. We use this
	method to set the repository path when using the browse button the 
	select the path to a local repository.
    "*/
{
	CvsRepository	*theSelectedRepository = nil;
	
	theSelectedRepository = [self selectedRepository];
    if ( theSelectedRepository != nil ) {
		NSString	*aPath = [someFilenames lastObject];
		
		[theSelectedRepository setCvsExecutablePath:aPath]; // FIXME We don't validate it, unlike when adding new repository
	}
}

- (NSString *)getFileContentsForFilename:(NSString *)aName
	/*" This method returns the contents of the file in the CVSROOT 
		directory by the name given in aName that is located in 
		~/Library/Application Support/CVL/Repositories/<a selected repository>/ 
		or nil if it cannot access the file. aName has to be one of the 
		following names: "modules", "cvsignore" or "cvswrappers". If not an 
		exception is thrown.
	"*/
{
	CvsRepository	*theSelectedRepository	= nil;
	NSString		*aPath					= nil;
	NSString		*fileContents			= nil;

	SEN_ASSERT_CONDITION( ([aName isEqualToString:@"modules"] ||
						   [aName isEqualToString:@"cvsignore"] ||
						   [aName isEqualToString:@"cvswrappers"]) );
	
	theSelectedRepository = [self selectedRepository];
	if ( [theSelectedRepository isUpToDate] ) {
		aPath = [[theSelectedRepository CVSROOTWorkAreaPath] stringByAppendingPathComponent:aName];
		fileContents = [NSString stringWithContentsOfFile:aPath];
	}	
	return fileContents;
}


@end

@implementation RepositoryViewer (WindowDelegate)

- (void) windowDidBecomeKey:(NSNotification *)notification
{
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"ShowRepositoryViewer"];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ViewerDidBecomeKey" object: self];
}

- (void) windowWillClose:(NSNotification *)notification
{
    if([[NSApplication sharedApplication] isRunning])
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"ShowRepositoryViewer"];
}

@end

@implementation RepositoryViewer (NSSplitViewDelegate)


- (float)splitView:(NSSplitView *)sender constrainMinCoordinate:(float)proposedCoord ofSubviewAt:(int)offset
	/*" This method is a NSSplitView delegate method. It allows the delegate to
		constrain the minimum coordinate limit of the top view when the 
		user drags a divider. This method is invoked before the NSSplitView begins tracking the 
		cursor to position a divider. You may further constrain the limits that
		have been already set, but you cannot extend the divider limits. 
		proposedCoord is specified in the NSSplitView’s flipped coordinate 
		system. If the split bars are horizontal (views are one on top of the 
		other), proposedCoord is the top limit. The initial value of 
		proposedCoord is the top of the subview before the 
		divider. offset specifies the divider the user is moving, with the first
		divider being 0 and going down from top to bottom.

		We are returning 200 pixels here so that the top view does not get so 
		small that the vertical scroll button disappears.
	"*/
{
	SEN_ASSERT_NOT_NIL(repositorySplitView);
	
	if ( sender == repositorySplitView ) {
		if ( offset == 0 ) {
			return 150.0;
		}
	}
	return proposedCoord;
}

- (float) splitView:(NSSplitView *)sender constrainMaxCoordinate:(float)proposedCoord ofSubviewAt:(int)offset
	/*" This method is a NSSplitView delegate method. It allows the delegate for 
		sender to constrain the maximum coordinate limit of the top view when the 
		user drags a divider. This method is invoked before the NSSplitView begins 
		tracking the mouse to position a divider. You may further constrain the 
		limits that have been already set, but you cannot extend the divider 
		limits. proposedMax is specified in the NSSplitView’s flipped coordinate
		system. If the split bars are horizontal (views are one on top of the 
		other), proposedMax is the bottom limit. The initial value of 
		proposedMax is the bottom of the subview after the divider. offset 
		specifies the divider the user is moving, with the first divider being 0
		and going up from top to bottom.
	"*/
{
	float actualCoord = 0.0;
	
	if ( sender == repositorySplitView ) {
		if ( offset == 0 ) {
			actualCoord = MAX(150.0, NSHeight([sender frame]) - 260.0);
			return actualCoord;
		}
	}
	return proposedCoord;
}


@end
