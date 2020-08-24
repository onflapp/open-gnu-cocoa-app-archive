
// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.


#import "WorkAreaViewer.h"
#import "BrowserController.h"
#import "WorkAreaListViewer.h"
#import "ResultsRepository.h"
#import "DirectoryContentsFilterProvider.h"
#import "CVLTextView.h"
#import "CVLDelegate.h"
#import "CvsCommitPanelController.h"
#import <CvsUpdateRequest.h>
#import <CvsUpdateLocalRequest.h>
#import <CvsCommitRequest.h>
#import <CvsTagRequest.h>
#import <CvsStatusRequest.h>
#import <CvsLogRequest.h>
#import <CvsAddRequest.h>
#import <CvsDiffRequest.h>
#import <CvsEditRequest.h>
#import <CvsWatchRequest.h>
#import <CvsWatcher.h>
#import <CvsEntry.h>
#import <CvsTag.h>
#import <CvsRepository.h>
#import "CVLScheduler.h"
#import "RetrievePanelController.h"
#import <SenPanelFactory.h>
#import <SenFormPanelController.h>
#import <SenFormController.h>
#import "CVLFile.h"
#import <CVLOpendiffRequest.h>
#import <CvsRemoveRequest.h>
#import <CvsReleaseRequest.h>
#import <SelectorRequest.h>
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <SenFoundation/SenFoundation.h>
#import "RestoreWorkAreaPanelController.h"
#import "NSArray.SenCategorize.h"
#if WITH_FS_NOTIFICATION_CENTER
#import <FSNotificationCenter/FSNotificationCenter.h>
#endif /* WITH_FS_NOTIFICATION_CENTER */

static NSArray *cellsOrder;
static NSMutableArray *filterConfigurationPresets;
static NSPoint currentTopLeft= {0, 0};

//-------------------------------------------------------------------------------------

@interface WorkAreaViewer (Private)
//- (id) window;
- (void)reflectFilterConfiguration;
- (NSSize)suggestNewSizeForSize:(NSSize)frameSize;
- (void) viewerDoubleSelect: (NSNotification *)notification;
- (void) schedulerDidChange: (NSNotification *)notification;
- (void)updateProcessesIndicator;
- (void)_callSelectFiles:(NSSet *)someFiles;
@end

//-------------------------------------------------------------------------------------

@implementation WorkAreaViewer

+ (void)initialize
{
    NSArray *allFiles = nil;
    NSArray *interestingFiles = nil;
    NSArray *customFiles = nil;
    NSArray *customFilesDefault = nil;
    NSUserDefaults *defaults = nil;
    NSDictionary *appDefaults = nil;
    
    cellsOrder=[NSArray arrayWithObjects:@"Locally Modified",@"Needs Update",@"Needs Merge",@"Conflicts",@"Up-To-Date",@"Not in CVS",@"Ignored",@"Being Computed",@"Unknown",nil];
    [cellsOrder retain];

    filterConfigurationPresets = [[NSMutableArray alloc] initWithCapacity:3];
    allFiles = [NSArray arrayWithObjects:@"Locally Modified",@"Needs Update",
        @"Needs Merge" ,@"Conflicts",@"Up-To-Date",@"Not in CVS",@"Ignored",
        @"Being Computed",@"Unknown",nil];
    interestingFiles = [NSArray arrayWithObjects:@"Locally Modified",
        @"Needs Update",@"Needs Merge",@"Conflicts",@"Not in CVS",
        @"Being Computed",@"Unknown",nil];
    customFilesDefault = [interestingFiles copy];
    
    defaults = [NSUserDefaults standardUserDefaults];
    appDefaults = [NSDictionary dictionaryWithObject:customFilesDefault 
                                              forKey:@"CustomFilesConfiguration"];
    [defaults registerDefaults:appDefaults];
    
    customFiles = [defaults stringArrayForKey:@"CustomFilesConfiguration"];
    // NB: we are using tags in the nib to access these arrays
    // (i.e. tags are equal to indexes).
    [filterConfigurationPresets insertObject:allFiles atIndex:0];
    [filterConfigurationPresets insertObject:interestingFiles atIndex:1];
    [filterConfigurationPresets insertObject:customFiles atIndex:2];
}

+ (WorkAreaViewer*) viewerForPath: (NSString*) aPath
{
    return [self viewerForFile:(CVLFile *)[CVLFile treeAtPath:aPath]];
}

+ (WorkAreaViewer*) viewerForFile: (CVLFile *) aFile
{
    WorkAreaViewer* newViewer= nil;
    
    newViewer= [[self alloc] initForFile: aFile];
    if ( newViewer != nil ) {
        [newViewer autorelease];
        (void)[CvsTag checkTheTagsForViewer:newViewer];
    }
    return newViewer;
}

- init
{
    return [self initForFile:(CVLFile *)[CVLFile treeAtPath:NSHomeDirectory()]];
} // init


- initForFile: (CVLFile *) aFile;
{
    self= [super init];
    ASSIGN(rootFile, aFile);
    windowIsMiniaturized= NO;
    currentViewer= nil;
    browserViewer= nil;
    listViewer= nil;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(viewerDoubleSelect:)
                                                 name:@"ViewerDoubleSelect"
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(schedulerDidChange:)
                                                 name:@"SchedulerDidChange"
                                               object:[CVLScheduler sharedScheduler]];
#if WITH_FS_NOTIFICATION_CENTER
    if([[NSUserDefaults standardUserDefaults] boolForKey:@"UseFSNotifications"])
        // FIXME Actually it makes CVL much slower than before, because too many requests are done
        [[FSNotificationCenter defaultCenter] addObserver:self selector:@selector(fileSystemChanged:) type:FSNotifyAll path:[rootFile path] recursive:YES followLinks:YES];
#endif
    
    return self;
}


- (void) dealloc
{
#if WITH_FS_NOTIFICATION_CENTER
    [[FSNotificationCenter defaultCenter] removeObserver: self];
#endif
    [[NSNotificationCenter defaultCenter] removeObserver: self];
    RELEASE(currentViewer);
    RELEASE(browserViewer);
    RELEASE(listViewer);
    RELEASE(rootFile);
    RELEASE(filterProvider);
    [window setDelegate:nil];
//#warning COMMENTED ANTI-BUG CODE!!!
    [filterPopup setTarget:nil];
    // To avoid unexplicable bug we need to remove ourself as target of the popup...
	// It seems that popup remains in the responder chains, and it tries to send messages to its target when menus need validation!
    // Just releasing the window is not enough. Popup is still retained by ???
    [window autorelease]; // We cannot release the window, because other bugs happen!!! Autorelease seems to work...
    [super dealloc];
} // dealloc


- (IBAction) filterPreselectionPopped:(id)sender
{
    NSArray *aStringArray = nil;
    int aTag = 0;
    
    if ([sender selectedItem]) {
        aTag = [[sender selectedItem] tag];
        SEN_ASSERT_CONDITION((aTag < 3));
        SEN_ASSERT_CONDITION(([filterConfigurationPresets count] == 3));
        if ( aTag == -1 ) {
            // Set the Custom files array to be what is now selected.
            [self setCustomFiles];
            return;
        }
        aStringArray = [filterConfigurationPresets objectAtIndex:aTag];
        [filterProvider setFilterWithStringArray:aStringArray];
        [self reflectFilterConfiguration];
    }
}

- (void)setCustomFiles
{
    NSEnumerator *cellsOrderEnumerator = nil;
    NSEnumerator *cellsEnumerator = nil;
    NSMutableArray *aConfiguration = nil;
    NSCell *aCell = nil;

    cellsOrderEnumerator = [cellsOrder objectEnumerator];
    cellsEnumerator = [[filterButtonsMatrix cells] objectEnumerator];
    aConfiguration = [NSMutableArray  arrayWithCapacity:9];
    
    while ( (aCell = [cellsEnumerator nextObject]) ) {
        if ( [aCell intValue] != 0 ) {
            [aConfiguration addObject:[aCell title]];
        }
    }
    // A new "Custom files" configuration.
    [filterConfigurationPresets replaceObjectAtIndex:2 
                                          withObject:aConfiguration];
    [[NSUserDefaults standardUserDefaults] setObject:aConfiguration 
                                              forKey:@"CustomFilesConfiguration"];
}

- (IBAction) setViewer:(id)aViewer
{
    NSString *theCvsRepositoryPath = nil;
    id	previousKeyView = [viewHolder retain];
    id	nextKeyView = [[viewHolder nextKeyView] retain];
    id newView= [aViewer view];
    NSRect holderRect= [viewHolder frame];	
  //	NXRect	viewRect= [newView frame];
    
  //	NX_X (&viewRect) = (NX_WIDTH (&holderRect) - NX_WIDTH (&viewRect)) / 2.0;
  //	NX_Y (&viewRect) = (NX_HEIGHT (&multiRect) - NX_HEIGHT (&viewRect)) / 1.5;
    [newView setFrame:holderRect];
    [newView setFrameOrigin:(NSPoint) {0.0, 0.0}];
    if (currentViewer) {
        ASSIGN(previousKeyView, [currentViewer previousKeyView]);
        ASSIGN(nextKeyView, [currentViewer nextKeyView]);
        [[currentViewer view] removeFromSuperview];
    }
    [viewHolder setAutoresizesSubviews: YES];
    [newView setNextKeyView:nextKeyView];
    [previousKeyView setNextKeyView:newView];
    [viewHolder addSubview: newView];
    [previousKeyView release];
    [nextKeyView release];
    ASSIGN(currentViewer, aViewer);
    [currentViewer setDelegate:self];
    [currentViewer setFilterProvider:filterProvider];
    // Disconnected repositoryRootPathTextField since it should be per file.
    // Needs to be in the status inspector. Do this later.
    // William Swats  17-Dec-2003
    //SEN_ASSERT_NOT_NIL(repositoryRootPathTextField);
    theCvsRepositoryPath = [currentViewer cvsFullRepositoryPath];
    //[repositoryRootPathTextField setStringValue:theCvsRepositoryPath];
  //	[viewHolder update];
}

- (void)awakeFromNib
{
    // set default viewer;
    [self setBrowserView: self];

    [window makeFirstResponder: [currentViewer view]];
    [window setTitleWithRepresentedFilename:[rootFile path]];
    [window setMiniwindowImage:[NSImage imageNamed:@"appicon"]];
    [self updateProcessesIndicator];
} // awakeFromNib

- (void)showWindowWithDictionary:(NSDictionary *)dict
{
    NSString *showFilterDrawer = NO;
    BOOL miniaturized= [[dict objectForKey: @"isMiniaturized"] intValue] == 1;
    NSString *frameString=[dict objectForKey: @"frameString"];
    NSDictionary *theCommitMessageHistory = nil;
    CvsCommitPanelController *theCommitPanelController = nil;
    
    if (!window)
    {
        [NSBundle loadNibNamed:[WorkAreaViewer description] owner:self];
        if ((currentTopLeft.x == 0) && (currentTopLeft.y == 0))
        {
            currentTopLeft.x= NSMinX([window frame]);
            currentTopLeft.y= NSMaxY([window frame]);
        }
    }
    if (frameString)
    {
        [window setFrameFromString:frameString];
    }
    else
    {
        currentTopLeft= [window cascadeTopLeftFromPoint: currentTopLeft];
        [window setFrameTopLeftPoint: currentTopLeft];
#if 0
        [self viewerFrameSizeChanged:nil];
#endif
    }
    [window makeKeyAndOrderFront:self];
    if (miniaturized)
    {
        [window miniaturize: self];
    }
    [filterProvider setFilterWithStringArray:[dict objectForKey:@"show status"]];
    
    showFilterDrawer = [dict objectForKey:@"showFilterDrawer"];
    // Note: If showFilterDrawer does not exists then this means we have
    // an old saved browser state. In the old state the filters were always
    // being displayed, hence if showFilterDrawer is nil then display
    // the filter drawer.
    if ( (showFilterDrawer == nil) ||
         ([showFilterDrawer isEqualToString:@"YES"] == YES) ) {
        if ( [self isFilterDrawerOpen] == NO ) {
            [filterDrawer openOnEdge:NSMinXEdge];
        }        
    } else {
        if ( [self isFilterDrawerOpen] == YES ) {
            [filterDrawer close];
        }                
    }
    
    theCommitMessageHistory = [dict objectForKey:@"commitMessageHistory"];
    if ( isNotEmpty(theCommitMessageHistory) ) {
        theCommitPanelController = [self cvsCommitPanelController];
        [theCommitPanelController setCommitHistory:theCommitMessageHistory];
    }
    
    
    [self reflectFilterConfiguration];
    [self updateTheRecentMenu];
}

- (NSDictionary *)stateDictionary
    /*" This method wraps up the state of this viewer into a dictionary with the 
        following seven keys:
        _{path    The absolute path to this workarea}
        _{frameString    Describes the location and size of the CVL browser view}
        _{isMiniaturized    Indicates whether or not the browser view is miniaturized}
        _{show status    An array of filter names for showing which files to display}
        _{isDisplayed    Indicates whether or not the browser view is to be displayed}
        _{showFilterDrawer    Indicates whether or not the browser's filter drawer is to be displayed}
        _{commitMessageHistory    A dictionary of commit messages arranged by date}
    "*/
{
    // FIXME Sometimes that method is called on exit, but self has never loaded its nib file!
    NSMutableDictionary* browserDict = nil;
    NSDictionary* theCommitMessageHistory = nil;
    CvsCommitPanelController *theCommitPanelController = nil;
    BOOL isApplicationTerminating = NO;

    browserDict = [NSMutableDictionary dictionaryWithCapacity:6];
    [browserDict setObject: [rootFile path] forKey: @"path"];
    // Stephane: temporary check to avoid crash on quit in certain circumstances (bound to CVLSelectingFilesRequest)
    if ( window != nil ) {
        [browserDict setObject: [window stringWithSavedFrame] forKey: @"frameString"];
    }
    [browserDict setObject: [NSNumber numberWithInt: windowIsMiniaturized] forKey: @"isMiniaturized"];
    if(filterProvider)
        [browserDict setObject: [filterProvider stringArrayFilterDescription] forKey:@"show status"];
    isApplicationTerminating = [[NSApp delegate] isApplicationTerminating];
    if ( (isApplicationTerminating == NO) &&
         (viewerIsClosing == YES) ) {
        [browserDict setObject:@"NO" forKey:@"isDisplayed"];
    } else {
        [browserDict setObject:@"YES" forKey:@"isDisplayed"];
    }
    
    if ( [self isFilterDrawerOpen] == YES ) {
        [browserDict setObject:@"YES" forKey:@"showFilterDrawer"];
    } else {
        [browserDict setObject:@"NO" forKey:@"showFilterDrawer"];
    }

    theCommitPanelController = [self cvsCommitPanelController];
    theCommitMessageHistory = [theCommitPanelController commitHistory];
    if ( isNotEmpty(theCommitMessageHistory) ) {
        [browserDict setObject:theCommitMessageHistory 
                        forKey:@"commitMessageHistory"];
    }
    return browserDict;
}

- (IBAction) show:(id)sender
{
    if ([window isVisible]) {
        [window makeKeyAndOrderFront:self];
    } else {
        NSDictionary* defaultFilterDict= [NSDictionary dictionaryWithObject: [filterConfigurationPresets objectAtIndex: 2]
                                                                     forKey: @"show status"];
        [self showWindowWithDictionary: defaultFilterDict];
        [self updateTheRecentMenu];
    }
}

- (void) updateTheRecentMenu
    /*" The method -noteNewRecentDocumentURL: should be called by applications 
        not based on NSDocument when they open or save documents identified by 
        aURL. NSDocument automatically calls this method when appropriate for 
        NSDocument-based applications. Applications not based on NSDocument must
        also implement the application:openFile: method in the application 
        delegate to handle requests from the Open Recent menu command. This 
        method does this.
    "*/
{
    NSDocumentController *theSharedDocumentController = nil;
    NSString *theRootPath = nil;
    NSURL *aURL = nil;
    
    theSharedDocumentController = [NSDocumentController sharedDocumentController];
    theRootPath = [self rootPath];
    aURL = [NSURL fileURLWithPath:theRootPath];
    [theSharedDocumentController noteNewRecentDocumentURL:aURL];
}

- (IBAction) setBrowserView:(id)sender
{
    if (!browserViewer)
    {
        ASSIGN(browserViewer, [BrowserController browserForPath:[rootFile path]]);
    }
    [self setViewer: browserViewer];
}


- (IBAction) setListView:(id)sender
{
    //NB: The list view has never been implemented.
    if (!listViewer)
    {
        ASSIGN(listViewer, [WorkAreaListViewer listViewerForPath:[rootFile path]]);
    }
    [self setViewer: listViewer];
}

- (id) viewer
{
    return currentViewer;
}

- (NSString*) rootPath
{
    return [rootFile path];
}

- (CVLFile *)rootFile
{
    return rootFile;
}

- (void)_callSelectFiles:(NSSet *)someFiles
{
    [currentViewer selectFiles:someFiles];
    [someFiles release]; // Because we retained it before invocation
}

- (void)selectFiles:(NSSet *)someFiles
{
    id fileEnumerator;
    CVLFile *aFile;

    fileEnumerator=[someFiles objectEnumerator];
    while ( (aFile=[fileEnumerator nextObject]) ) {
        [filterProvider configureToShowFile:aFile];
    }
    [self reflectFilterConfiguration];
    [someFiles retain];
#if 0
    [[NSRunLoop currentRunLoop] performSelector:@selector(_callSelectFiles:) target:self argument:someFiles order:100000 modes:[NSArray arrayWithObject:[[NSRunLoop currentRunLoop] currentMode]]];
#else
    // MOXS: sometimes, there is no currentRunLoop mode!!!
    // Open workarea A from Recent, then workarea B (located inside workarea A?)
    if([[NSRunLoop currentRunLoop] currentMode])
        [[NSRunLoop currentRunLoop] performSelector:@selector(_callSelectFiles:) target:self argument:someFiles order:100000 modes:[NSArray arrayWithObject:[[NSRunLoop currentRunLoop] currentMode]]];
    else{
//        $$$$$$$$ NO RUN LOOP MODE $$$$$$$$$$
        [[NSRunLoop currentRunLoop] performSelector:@selector(_callSelectFiles:) target:self argument:someFiles order:100000 modes:[NSArray arrayWithObject:NSDefaultRunLoopMode]];
    }
#endif
}

- (IBAction) restoreWorkAreaVersion:(id)sender
    /*" This action method accesses a shared RestoreWorkAreaPanelController 
        which is then asked to perform a restoring of a version of the 
        repository to the workarea based on either a date or a release tag.

        Also see the class #{RestoreWorkAreaPanelController} for more 
        information.
    "*/
{
    RestoreWorkAreaPanelController *aController = nil;
    NSString *aWorkAreaPath = nil;
    
    aWorkAreaPath = [rootFile path];
    SEN_ASSERT_NOT_EMPTY(aWorkAreaPath);
    aController=[RestoreWorkAreaPanelController 
                    sharedRestoreWorkAreaPanelController];
    SEN_ASSERT_NOT_NIL(aController);
    [aController restoreVersionForWorkArea:aWorkAreaPath];
}

- (void) clearControllerCacheForWorkArea:(NSString *)aWorkAreaPath
    /*" This method accesses a shared RestoreWorkAreaPanelController which is 
        then asked to clear its cache of tags, if any, for the workarea given in
        the argument aWorkAreaPath.

        Also see the class #{RestoreWorkAreaPanelController} for more 
        information.
    "*/
{
    ResultsRepository *theSharedResultsRepository = nil;
            
    if ( isNotEmpty(aWorkAreaPath) ) {
        theSharedResultsRepository = [ResultsRepository sharedResultsRepository];
        SEN_ASSERT_NOT_NIL(theSharedResultsRepository);
        [theSharedResultsRepository clearCacheForWorkArea:aWorkAreaPath];        
    }
}

- (IBAction) updateSelectedFiles:(id)sender
    /*" This is an action method that will update the CVLFiles selected in the 
        CVL browser using the CVS update command.
    "*/
{
    NSArray *mySelectedCVLFiles = nil;
    NSArray *myDirectoriesInCVLFiles = nil;
    NSArray *directoriesMarkedForRemoval = nil;
    NSArray *theRelativeSelectedPaths = nil;
	int aTag = 0;
    
    // Remove any .DS_Store files that are in otherwise empty directories so
    // that the CVS update command will delete them.
    mySelectedCVLFiles = [currentViewer selectedCVLFiles];
    myDirectoriesInCVLFiles = [currentViewer 
                                        directoriesInCVLFiles:mySelectedCVLFiles 
                                                     unrolled:YES];
    if ( isNotEmpty(myDirectoriesInCVLFiles) ) {
        directoriesMarkedForRemoval = [self 
                        directoriesMarkedForRemovalInCVLFiles:myDirectoriesInCVLFiles];
        if ( isNotEmpty(directoriesMarkedForRemoval) ) {
            [self deleteDS_StoreFilesIn:directoriesMarkedForRemoval];        
        }
    }
    
    theRelativeSelectedPaths=[currentViewer relativeSelectedPaths];
    if ( isNotEmpty(theRelativeSelectedPaths) ) {
		aTag = [sender tag];
		if ( aTag == 1 ) {
			[[CvsUpdateRequest cvsUpdateRequestForFiles:theRelativeSelectedPaths
												 inPath:[rootFile path]] schedule];
		} else if ( aTag == 2 ) {
			[[CvsUpdateLocalRequest cvsUpdateRequestForFiles:theRelativeSelectedPaths
												 inPath:[rootFile path]] schedule];
		} else {
			//Error
			SEN_ASSERT_CONDITION_MSG((( aTag == 1 ) || ( aTag == 2 )), 
									 ([NSString stringWithFormat:
				@"Set the tag for this menu to 1 for a recursive update and 2 for a local update."]));
		}
    }
}

- (void) updateWorkAreaSheetDidDismiss:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
    /*" This is the method called by the action method updateWorkArea: that does
        the actual updating of all the CVLFiles in the workarea in the CVL 
        browser using the CVS update command but only if the user clicked on the
        "OK" button.
    "*/
{
    NSArray *mySelectedCVLFiles = nil;
    NSArray *myDirectoriesInCVLFiles = nil;
    NSArray *directoriesMarkedForRemoval = nil;
    
    if ( returnCode == NSAlertDefaultReturn ) {
        // Remove any .DS_Store files that are in otherwise empty directories so
        // that the CVS update command will delete them.
        mySelectedCVLFiles = [NSArray arrayWithObject:rootFile];
        myDirectoriesInCVLFiles = [currentViewer 
                                            directoriesInCVLFiles:mySelectedCVLFiles 
                                                         unrolled:YES];
        if ( isNotEmpty(myDirectoriesInCVLFiles) ) {
            directoriesMarkedForRemoval = [self 
                directoriesMarkedForRemovalInCVLFiles:myDirectoriesInCVLFiles];
            if ( isNotEmpty(directoriesMarkedForRemoval) ) {
                [self deleteDS_StoreFilesIn:directoriesMarkedForRemoval];        
            }
        }
        
        [[CvsUpdateRequest cvsUpdateRequestForFiles:nil inPath:[rootFile path]] schedule];
    }
}

- (IBAction) updateWorkArea:(id)sender
    /*" This is an action method that will update all the CVLFiles in the 
        workarea in the CVL browser using the CVS update command.
    "*/
{
    NSBeginAlertSheet(@"CVS update", @"OK", @"Cancel", nil, window, self, NULL, @selector(updateWorkAreaSheetDidDismiss:returnCode:contextInfo:), NULL, @"Do you really want to update the whole Work Area ?");
}

- (IBAction) closeWorkArea:(id)sender
{
    [window performClose:sender];
}

- (IBAction) commitSelectedFiles:(id)sender
    /*" This is an action method that commits the selected files. This method 
        grabs the selected files and then calls the method -commitCVLFiles: to
        do the commiting.
    "*/
{
    NSArray *theSelectedCVLFiles = nil;
    
    theSelectedCVLFiles = [currentViewer selectedCVLFiles];
	if ( isNotEmpty(theSelectedCVLFiles) ) {
		[self commitCVLFiles:theSelectedCVLFiles];
	} else {
		(void)NSRunAlertPanel(@"CVL Commit", 
							  @"There are no files selected that can be committed. No CVS commit will be performed.",
							  nil, nil, nil);
	}
}

- (void) commitCVLFiles:(NSArray *)someCVLFiles
    /*" This method commits the files in the array named someCVLFiles. If templates
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
        returned commit message and creates a commit request with it. 

        If someCVLFiles is nil then no refresh request is created below since
        this means the user is asking for a commit of the whole workarea which
        will generate its own refresh.
    "*/
{
    NSArray                     *someFiles = nil;
    CvsCommitRequest            *aCvsCommitRequest = nil;
    NSString                    *theRootPath = nil;
    NSString                    *aMessage = nil;
    CvsCommitPanelController    *theCommitPanelController = nil;
    SelectorRequest             *aRefreshRequest = nil;
    CvsUpdateRequest            *anUpdateRequest = nil;
    BOOL                        useCvsTemplates = NO;
    
    someFiles = [currentViewer relativePathsFromCVLFiles:someCVLFiles];
    theRootPath = [self rootPath];
    useCvsTemplates = [[NSUserDefaults standardUserDefaults] 
                                boolForKey:@"UseCvsTemplates"];
    if( useCvsTemplates == YES ) {
        aCvsCommitRequest = [CvsCommitRequest 
                                    cvsCommitRequestForFiles:someFiles 
                                                      inPath:theRootPath 
                                                     message:nil];
        if ( aCvsCommitRequest != nil ) {
            [aCvsCommitRequest schedule];
        }
    } else {
        theCommitPanelController = [self cvsCommitPanelController];
        aMessage = [theCommitPanelController showCommitPanelWithFiles:someFiles 
                                                    usingTemplateFile:nil];
        if ( aMessage != nil ) {
            aCvsCommitRequest = [CvsCommitRequest 
                                    cvsCommitRequestForFiles:someFiles 
                                                      inPath:theRootPath 
                                                     message:aMessage];     
        }
        if ( aCvsCommitRequest != nil ) {
            aRefreshRequest = [self returnARefreshRequestIfNeeded:someCVLFiles];
            if ( aRefreshRequest != nil ) {
                [aRefreshRequest addPrecedingRequest:aCvsCommitRequest];
                anUpdateRequest = [self returnAnUpdateRequestIfNeeded:someCVLFiles];
                if ( anUpdateRequest != nil ) {
                    [anUpdateRequest addPrecedingRequest:aRefreshRequest];
                    [anUpdateRequest schedule];        
                } else {
                    [aRefreshRequest schedule];
                }                
            } else {
                [aCvsCommitRequest schedule];
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
        classes CVLEditorClient, CVLDelegate and RepositoryViewer.
    "*/
{
    NSArray                     *theRelativeSelectedPaths = nil;
    NSString                    *aMessage = nil;
    CvsCommitPanelController    *theCommitPanelController = nil;
    NSArray                     *someCVLFiles = nil;
    SelectorRequest             *aRefreshRequest = nil;
    CvsUpdateRequest            *anUpdateRequest = nil;

    theRelativeSelectedPaths = [currentViewer relativeSelectedPaths];
    theCommitPanelController = [self cvsCommitPanelController];
    aMessage = [theCommitPanelController 
                    showCommitPanelWithFiles:theRelativeSelectedPaths 
                           usingTemplateFile:aTemplateFile];
    if ( aMessage != nil ) {
        [aMessage writeToFile:aTemplateFile atomically:YES];
        someCVLFiles = [currentViewer selectedCVLFiles];        
        aRefreshRequest = [self returnARefreshRequestIfNeeded:someCVLFiles];
        if ( aRefreshRequest != nil ) {
            anUpdateRequest = [self returnAnUpdateRequestIfNeeded:someCVLFiles];
            if ( anUpdateRequest != nil ) {
                [anUpdateRequest addPrecedingRequest:aRefreshRequest];
                [anUpdateRequest schedule];        
            } else {
                [aRefreshRequest schedule];
            }                            
        }
        return YES;
    }
    return NO;
}

- (SelectorRequest *) returnARefreshRequestIfNeeded:(NSArray *)someCVLFiles
    /*" This method will return a refresh request if any of the CVLfiles in the
        array named someCVLFiles, after unrolling, have been marked for removal,
        otherwise nil is returned. If someCVLFiles is nil or empty then nil is 
        returned. If a refresh request is returned it will be a refresh of the
        lowest directory that contains all the CVLfiles marked for removal.

        This refresh request is needed in the case of files marked for removal
        because the enclosing directory would still show the file that has been
        deleted.
    "*/
{
    NSArray                     *filesMarkedForRemoval = nil;
    NSDictionary                *pathDict = nil;
    NSString                    *commonPath = nil;
    NSString                    *theRootPath = nil;
    NSArray                     *relativePaths = nil;
    NSArray                     *anArrayOfOneFile = nil;
    SelectorRequest             *aRefreshRequest = nil;
    
    // Check to see if any of these files that are being committed have been
    // marked for removal. If they have then we want (or need) to refresh the
    // highest enclosing directory of those files marked for removal.
    if ( isNotEmpty(someCVLFiles) ) {
        filesMarkedForRemoval = [self filesMarkedForRemovalInCVLFiles:someCVLFiles];
        if ( isNotEmpty(filesMarkedForRemoval) ) {
            relativePaths = [currentViewer 
                            relativePathsFromCVLFiles:filesMarkedForRemoval];
            theRootPath = [self rootPath];
            pathDict = [CvsRequest canonicalizePath:theRootPath
                                           andFiles:relativePaths];
            commonPath = [[pathDict allKeys] objectAtIndex:0];
            anArrayOfOneFile = [NSArray arrayWithObject:commonPath];
            aRefreshRequest = [SelectorRequest 
                    requestWithTarget:self 
                             selector:@selector(refreshTheseSelectedFiles:) 
                             argument:anArrayOfOneFile];
        }        
    }
    return aRefreshRequest;
}

- (CvsUpdateRequest *) returnAnUpdateRequestIfNeeded:(NSArray *)someCVLFiles
    /*" This method will return an update request if any of the CVLfiles in the
        array named someCVLFiles, after unrolling, have been marked for removal,
        otherwise nil is returned. If someCVLFiles is nil or empty then nil is 
        returned. If a update request is returned it will be a update of the
        lowest directory that contains all the CVLfiles marked for removal.

        This update request is needed in the case of files marked for removal
        because after removal some directories may be empty. So we need to 
        perform an update on these empty directories so they will be removed 
        from the workarea by CVS.
    "*/
{
    NSArray                     *directoriesMarkedForRemoval = nil;
    NSArray                     *relativePaths = nil;
    CvsUpdateRequest            *anUpdateRequest = nil;
    
    // Check to see if any of these files that are being committed have been
    // marked for removal. If they have then we want (or need) to update the
    // highest enclosing directory of those files marked for removal.
    if ( isNotEmpty(someCVLFiles) ) {
        directoriesMarkedForRemoval = [self directoriesMarkedForRemovalInCVLFiles:someCVLFiles];
        if ( isNotEmpty(directoriesMarkedForRemoval) ) {
            // The update will not delete the empty directory if it still has
            // a .DS_Store file in it, so we delete it here.
            [self deleteDS_StoreFilesIn:directoriesMarkedForRemoval];

            relativePaths = [currentViewer 
                            relativePathsFromCVLFiles:directoriesMarkedForRemoval];
            anUpdateRequest = [CvsUpdateRequest 
                                cvsUpdateRequestForFiles:relativePaths
                                                  inPath:[rootFile path]];
        }        
    }
    return anUpdateRequest;
}

- (CvsUpdateRequest *) returnAnUpdateRequestForEmptyDirectories:(NSArray *)someCVLFiles
    /*" This method will return an update request if any of the CVLfiles, 
        actually they are all directories, in the array named someCVLFiles are 
        empty, otherwise nil is returned. If someCVLFiles is nil or empty then
        nil is returned. If someCVLFiles contain empty directories that are 
        sub-directories of other empty directories then only the top most empty 
        directory is used. Otherwise CVS will start to do some complaining.

        See Also #{-parseUnremovedNibsFromString:} in the class CvsUpdateRequest.
    "*/
{
    NSArray             *emptyDirectories = nil;
    NSMutableArray      *innerDirectories = nil;
    NSArray             *relativePaths = nil;
    NSMutableArray      *keepTheseEmptyDirectories = nil;
    CvsUpdateRequest    *anUpdateRequest = nil;
    NSEnumerator        *outerEnumerator = nil;
    NSEnumerator        *innerEnumerator = nil;
    CVLFile            *anOuterCVLFile = nil;
    CVLFile            *anInnerCVLFile = nil;
    unsigned int        aCount = 0;
    BOOL                keepOuterCVLFile = NO;
    
    // Check to see if any of these directories are empty.
    // If they have then we want (or need) to update the
    // highest enclosing directory of these empty directories.
    if ( isNotEmpty(someCVLFiles) ) {
        emptyDirectories = [self emptyDirectoriesInCVLFiles:someCVLFiles];
        if ( isNotEmpty(emptyDirectories) ) {
            // The update will not delete the empty directory if it still has
            // a .DS_Store file in it, so we delete it here.
            [self deleteDS_StoreFilesIn:emptyDirectories];
            
            // Lets remove all empty directories that are already contained in
            // in other empty directories so will only perform an update on the
            // mimimum number of directories.
            outerEnumerator = [emptyDirectories objectEnumerator];
            aCount = [emptyDirectories count];
            keepTheseEmptyDirectories = [NSMutableArray arrayWithCapacity:aCount];
            while ( (anOuterCVLFile = [outerEnumerator nextObject]) ) {
                keepOuterCVLFile = YES;
                innerDirectories = [NSMutableArray arrayWithArray:emptyDirectories];
                [innerDirectories removeObject:anOuterCVLFile];
                innerEnumerator = [innerDirectories objectEnumerator];
                while ( (anInnerCVLFile = [innerEnumerator nextObject]) ) {
                    if ( [anOuterCVLFile isDescendantOf:anInnerCVLFile] == YES ) {
                        keepOuterCVLFile = NO;
                        break;
                    }
                }
                if ( keepOuterCVLFile == YES ) {
                    [keepTheseEmptyDirectories addObject:anOuterCVLFile];
                }
            }
            
            // Get the relative paths form the CVLFiles since that is what the
            // CvsUpdateRequest expects.
            relativePaths = [currentViewer 
                            relativePathsFromCVLFiles:keepTheseEmptyDirectories];
            // Get the update request.
            anUpdateRequest = [CvsUpdateRequest 
                                cvsUpdateRequestForFiles:relativePaths
                                                  inPath:[rootFile path]];
        }        
    }
    return anUpdateRequest;
}

- (NSArray *) emptyDirectoriesInCVLFiles:(NSArray *)someCVLFiles
    /*" This method checks to see which CVL files (directories only) in the 
        array someCVLFiles are empty. If they are none then this method returns 
        nil. If not then this method returns an array of CVLFiles (directories 
        only) of those that are empty.

        See also #{-returnAnUpdateRequestForEmptyDirectories:}.
    "*/
{
    NSMutableArray  *emptyDirectories = nil;
    CVLFile         *aCVLFile = nil;
    NSEnumerator    *anEnumerator = nil;
    unsigned int    aCount = 0;
    
    if ( isNotEmpty(someCVLFiles) ) {
        aCount = [someCVLFiles count];
        emptyDirectories = [NSMutableArray arrayWithCapacity:aCount];
        anEnumerator = [someCVLFiles objectEnumerator];
        while ( (aCVLFile = [anEnumerator nextObject]) ) {
            if ( [aCVLFile isRealDirectory] == YES ) {
                if ( [aCVLFile isAnEmptyDirectory] == YES ) {
                    [emptyDirectories addObject:aCVLFile];
                }
            }
        }
        if ( [emptyDirectories count] == 0 ) {
            emptyDirectories = nil;
        }        
    }        
    return emptyDirectories;
}

- (void) deleteDS_StoreFilesIn:(NSArray *)someCVLFiles
    /*" This method deletes the .DS_Store files that Apple's Finder puts into 
        directories from any directory that is represented by the CVLFiles in 
        the array someCVLFiles. This is done so that the CVS update command  
        (with option "-P") will delete said directory when it is otherwise empty.
    "*/
{
    NSEnumerator    *anEnumerator = nil;
    CVLFile         *aCVLFile = nil;
    NSString        *aPath = nil;
    NSString        *aPathToDS_Store = nil;
    NSString        *aRelativePathToDS_Store = nil;
    NSFileManager	*fileManager = nil;
    NSMutableArray  *theDS_StoreFiles = nil;

    if ( isNotEmpty(someCVLFiles) ) {
        theDS_StoreFiles = [NSMutableArray arrayWithCapacity:1];
        fileManager = [NSFileManager defaultManager];
        anEnumerator = [someCVLFiles objectEnumerator];
        while ( (aCVLFile = [anEnumerator nextObject]) ) {
            if ( [aCVLFile isRealDirectory] == YES ) {
                aPath = [aCVLFile path];
                if ( [fileManager senDirectoryExistsAtPath:aPath]  == YES ) {
                    aPathToDS_Store = [aPath stringByAppendingPathComponent:@".DS_Store"];
                    if ( [fileManager senFileExistsAtPath:aPathToDS_Store] == YES ) {
                        aRelativePathToDS_Store = [currentViewer
                                         relativePathFromPath:aPathToDS_Store];
                        [theDS_StoreFiles addObject:aRelativePathToDS_Store];
                    }
                }
            }
        }
        if ( isNotEmpty(theDS_StoreFiles) ) {
            [self deleteFiles:theDS_StoreFiles andUpdate:NO];
        }
    }
}

- (IBAction) commitWorkArea:(id)sender
    /*" This is an action method that commits the whole workarea. This method
        first asks the user if he really wants to commit the whole workarea. The
        answer is then passed on to the method 
        -commitWorkAreaSheetDidDismiss:returnCode:contextInfo: which
        calls the method -commitCVLFiles: with a nil argument to do the actual
        commiting but only if the user responds with a yes.
    "*/
{
    NSBeginAlertSheet(@"CVS Commit", @"OK", @"Cancel", nil, window, self, NULL,
        @selector(commitWorkAreaSheetDidDismiss:returnCode:contextInfo:), NULL,
        @"Do you really want to commit the whole Work Area ?");
}

- (void) commitWorkAreaSheetDidDismiss:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
    /*" This is an method that commits the whole workarea. This method 
        calls the method -commitCVLFiles: with a nil argument to do the commiting.
    "*/
{
    if(returnCode == NSAlertDefaultReturn) {
        [self commitCVLFiles:nil];
    }
}


- (IBAction) tagSelectedFiles:(id)sender
{
    NSArray *theRelativeSelectedPaths = [currentViewer relativeSelectedPaths];
    NSString *aTag = nil;

    if (theRelativeSelectedPaths)
    {
        SenFormPanelController *tagPanel= [[SenPanelFactory sharedPanelFactory] handleOfPanelWithName:@"CvsTagPanel"];

        [tagPanel setObjectValue:@"Tag Selected Files" forKey:@"PanelTitle"];
        if ([tagPanel showAndRunModal]==NSOKButton) {
            NSDictionary* tagInfos= [tagPanel dictionaryValue];
            aTag = [tagInfos objectForKey:@"name"];
            if ( isNilOrEmpty(aTag) ) {
                NSRunAlertPanel(@"Tagging Error", 
                                @"The tag field is empty. Please enter a tag.", 
                                @"OK", nil, nil);
                // Redisplay the tab panel again.
                [self tagSelectedFiles:sender];
            }
            [[CvsTagRequest cvsTagRequestForFiles: theRelativeSelectedPaths
                                           inPath: [rootFile path]
                                              tag: aTag
                                         isBranch: [[tagInfos objectForKey:@"branch"] boolValue]
                                     moveIfExists: [[tagInfos objectForKey:@"moveIfExists"] boolValue]
                                  tagIfUnmodified: [[tagInfos objectForKey:@"tagIfUnmodified"] boolValue]] schedule];
            [self clearControllerCacheForWorkArea:[rootFile path]];
        }
    }
}


- (IBAction) tagWorkArea:(id)sender
{
    SenFormPanelController *tagPanel= [[SenPanelFactory sharedPanelFactory] handleOfPanelWithName:@"CvsTagPanel"];

    [tagPanel setObjectValue:@"Tag All Files in Work Area" forKey:@"PanelTitle"];
    if ([tagPanel showAndRunModal]==NSOKButton) {
        NSDictionary* tagInfos= [tagPanel dictionaryValue];
        [[CvsTagRequest cvsTagRequestForFiles: nil
                                       inPath: [rootFile path]
                                          tag: [tagInfos objectForKey:@"name"]
                                     isBranch: [[tagInfos objectForKey:@"branch"] boolValue]
                                 moveIfExists: [[tagInfos objectForKey:@"moveIfExists"] boolValue]
                              tagIfUnmodified: [[tagInfos objectForKey:@"tagIfUnmodified"] boolValue]] schedule];
        [self clearControllerCacheForWorkArea:[rootFile path]];
    }
}

- (BOOL) checkForWappedDirInSelectedFiles
    /*" This method checks to see if there is a wrapped directory included amongst
        the selected files (after they have been unrolled) in the CVL browser. 
        If there is then the user is alerted and ask if he would like to proceed.
        Then that answer (i.e. either YES or NO) is returned from this method.
        
        See also #{-turnOnEditing:, -turnOffEditing: and -toggleWatchActionForTag:}
    "*/
{
    NSArray         *mySelectedCVLFiles = nil;
    NSArray         *mySelectedCVLFilesFiltered = nil;
    NSMutableArray  *mySelectedWrappedDirs = nil;
    CVLFile         *aCVLFile = nil;
    CVLFile         *aWrappedCVLFile = nil;
    CVLFile         *aNormalCVLFile = nil;
    NSEnumerator    *anEnumerator = nil;
    NSString        *anErrorMsg = nil;
    unsigned int    aCountOfAllFiles = 0;
    unsigned int    aCountOfWrappedDirs = 0;
    unsigned int    aCountOfFilteredFiles = 0;
    unsigned int    aCountOfOtherFiles = 0;
    int             aChoice = NSAlertDefaultReturn;
    
    mySelectedCVLFiles = [currentViewer selectedCVLFilesUnrolled];
    if ( isNotEmpty(mySelectedCVLFiles) ) {
        aCountOfAllFiles = [mySelectedCVLFiles count];
        mySelectedWrappedDirs = [NSMutableArray arrayWithCapacity:aCountOfAllFiles];
        anEnumerator = [mySelectedCVLFiles objectEnumerator];
        while ( (aCVLFile = [anEnumerator nextObject]) ) {
            if ( [aCVLFile isRealWrapper] == YES ) {
                [mySelectedWrappedDirs addObject:aCVLFile];
            }
        }
    }
    if ( isNilOrEmpty(mySelectedWrappedDirs) ) {
        return YES;
    } else {
        mySelectedCVLFilesFiltered = [currentViewer selectedCVLFilesUnrolledAndFiltered];
        aCountOfFilteredFiles = [mySelectedCVLFilesFiltered count];

        aCountOfWrappedDirs = [mySelectedWrappedDirs count];
        aCountOfOtherFiles = aCountOfAllFiles - aCountOfWrappedDirs;
        SEN_ASSERT_CONDITION_MSG((aCountOfFilteredFiles == aCountOfOtherFiles),
            ([NSString stringWithFormat:
            @"aCountOfFilteredFiles = %d and aCountOfOtherFiles = %d.", 
            aCountOfFilteredFiles, aCountOfOtherFiles]));
        
        aWrappedCVLFile = [mySelectedWrappedDirs objectAtIndex:0];
        if ( isNotEmpty(mySelectedCVLFilesFiltered) ) {
            aNormalCVLFile = [mySelectedCVLFilesFiltered objectAtIndex:0];
        }

        // Case 1: One selected file that is a wrapped directory.
        if ( (aCountOfAllFiles == 1) &&
             (aCountOfWrappedDirs == 1) ) {
            aChoice = NSRunAlertPanel(@"Wrapped Directories", 
                                      @"The file \"%@\" is a wrapped directory. Unfortunately cvs does not handle editors and watchers for wrapped directories. No further action will be performed.", 
                                      nil, nil, nil, [aWrappedCVLFile name]);
            return NO;
        }
        
        // Case 2: Two selected files with one file that is a wrapped directory.
        if ( (aCountOfAllFiles == 2) &&
             (aCountOfWrappedDirs == 1) ) {
            aChoice = NSRunAlertPanel(@"Wrapped Directories", 
                                      @"The file \"%@\" is a wrapped directory. Unfortunately cvs does not handle editors and watchers for wrapped directories. Would you like to proceed with the one file left (%@)?", 
                                      @"Yes", @"No", nil, 
                                      [aWrappedCVLFile name], [aNormalCVLFile name]);        
            if ( aChoice == NSAlertDefaultReturn ) {
                return YES;
            } else {
                return NO;
            }
        }        
        
        // Case 3: More than one selected file with one file that is a wrapped directory.
        if ( (aCountOfAllFiles > 1) &&
             (aCountOfWrappedDirs == 1) ) {
            aChoice = NSRunAlertPanel(@"Wrapped Directories", 
                                      @"The file \"%@\" is a wrapped directory. Unfortunately cvs does not handle editors and watchers for wrapped directories. Would you like to proceed with the other %d files?", 
                                      @"Yes", @"No", nil, 
                                      [aWrappedCVLFile name], aCountOfOtherFiles);        
            if ( aChoice == NSAlertDefaultReturn ) {
                return YES;
            } else {
                return NO;
            }
        }        
        
        // Case 4: There was more than one selected file and all of them 
        // were wrapped directories.
        if ( (aCountOfAllFiles > 1) &&
             (aCountOfAllFiles == aCountOfWrappedDirs) ) {
            aChoice = NSRunAlertPanel(@"Wrapped Directories", 
                                      @"All of the %d files that were selected are wrapped directories. Unfortunately cvs does not handle editors and watchers for wrapped directories.  No further action will be performed.", 
                                      nil, nil, nil, aCountOfAllFiles);
            return NO;
        }                
        
        // Case 5: More than one selected file with more than one file that is a
        // wrapped directory and exactly one file left.
        if ( (aCountOfAllFiles > 1) &&
             (aCountOfWrappedDirs > 1) &&
             (aCountOfOtherFiles == 1) ) {
            aChoice = NSRunAlertPanel(@"Wrapped Directories", 
                                      @"%d of the %d files that were selected are wrapped directories. Unfortunately cvs does not handle editors and watchers for wrapped directories. Would you like to proceed with the one file left (%@)?", 
                                      @"Yes", @"No", nil, 
                                      aCountOfWrappedDirs, aCountOfAllFiles, 
                                      [aNormalCVLFile name]);        
            if ( aChoice == NSAlertDefaultReturn ) {
                return YES;
            } else {
                return NO;
            }
        }
        
        // Case 6: More than one selected file with more than one file that is a wrapped directory.
        if ( (aCountOfAllFiles > 1) &&
             (aCountOfWrappedDirs > 1) ) {
            aChoice = NSRunAlertPanel(@"Wrapped Directories", 
                                      @"%d of the %d files that were selected are wrapped directories. Unfortunately cvs does not handle editors and watchers for wrapped directories. Would you like to proceed with the other %d files?", 
                                      @"Yes", @"No", nil, 
                                      aCountOfWrappedDirs, aCountOfAllFiles, 
                                      aCountOfOtherFiles);        
            if ( aChoice == NSAlertDefaultReturn ) {
                return YES;
            } else {
                return NO;
            }
        }                        
    }
    
    anErrorMsg = [NSString stringWithFormat:
        @"Should never arrive here. If we do then we have not satisfied all cases in the above code."];
    SEN_ASSERT_CONDITION_MSG(NO, anErrorMsg);
    
    return NO;
}

- (BOOL) checkForModificationsInFiles:(NSArray *)someFiles
    /*" This method checks to see if there are any modified files that are also
        being edited by the current user that are included amongst
        the files in the array named someFiles. 
        If there is then the user is alerted and ask if he would like to proceed.
        Then that answer (i.e. either YES or NO) is returned from this method.

        See also #{-turnOffEditing:}
    "*/
{
    NSMutableArray  *myModifiedFiles = nil;
    CVLFile         *aCVLFile = nil;
    NSEnumerator    *anEnumerator = nil;
    NSString        *aName = nil;
    unsigned int    aCountOfSomeFiles = 0;
    int            aChoice = NSAlertDefaultReturn;
    
    if ( isNotEmpty(someFiles) ) {
        aCountOfSomeFiles = [someFiles count];
        myModifiedFiles = [NSMutableArray arrayWithCapacity:aCountOfSomeFiles];
        anEnumerator = [someFiles objectEnumerator];
        while ( (aCVLFile = [anEnumerator nextObject]) ) {
            if ([aCVLFile isLeaf]) {
                // Check to see if this file has beenmodified?
                if ( [aCVLFile status].statusType == ECLocallyModifiedType ) {
                    // Check to see if this file is being edited by the current user.
                    if ( [aCVLFile cvsEditorForCurrentUser] != nil ) {
                        aName = [aCVLFile name];
                        SEN_ASSERT_NOT_EMPTY(aName);
                        [myModifiedFiles addObject:aName];                        
                    }
                }                
            }
        }
    }
    if ( isNotEmpty(myModifiedFiles) ) {
        
        aChoice = NSRunAlertPanel(@"Cancel Edit", 
                    @"The file(s) \"%@\" have been modified. \n\nIf you proceed with this action then these file(s) will be replaced with what is in the file when you issued the \"edit\" command.  Some or all of your modifications might be lost. Would you like to proceed?", 
                    @"No", @"Yes", nil, 
                    myModifiedFiles);        
        if ( aChoice == NSAlertDefaultReturn ) {
            return NO;
        } else if ( aChoice == NSAlertAlternateReturn ) {
            return YES;
        }
    }
    return YES;
}

- (NSArray *) filesMarkedForRemovalInCVLFiles:(NSArray *)someCVLFiles
    /*" This method checks to see which CVL files in the array someCVLFiles
        (after being unrolled) have been marked for removal. If they are none
        then this method returns nil. If not then this method returns an array of 
        CVLFiles of those that have been marked for removal. This method is
        used to present the user with a list of files that that are marked 
        for removal when he is trying to reinstate them.

        See also #{-reinstateFilesMarkedForRemoval:} and 
        #{-unrollCVLFiles:} and 
        #{-filenamesOfFilesNotMarkedForRemovalInSelectedFiles}.
    "*/
{
    NSArray         *theUnrolledCVLFiles = nil;
    NSMutableArray  *theFilesMarkedForRemoval = nil;
    CVLFile         *aCVLFile = nil;
    NSEnumerator    *anEnumerator = nil;
    unsigned int    aCountOfAllFiles = 0;
    
    theUnrolledCVLFiles = [currentViewer unrollCVLFiles:someCVLFiles];
    if ( isNotEmpty(theUnrolledCVLFiles) ) {
        aCountOfAllFiles = [theUnrolledCVLFiles count];
        theFilesMarkedForRemoval = [NSMutableArray arrayWithCapacity:aCountOfAllFiles];
        anEnumerator = [theUnrolledCVLFiles objectEnumerator];
        while ( (aCVLFile = [anEnumerator nextObject]) ) {
            if ( [aCVLFile markedForRemoval] == YES ) {
                [theFilesMarkedForRemoval addObject:aCVLFile];
            }                                
        }
        if ( [theFilesMarkedForRemoval count] == 0 ) {
            theFilesMarkedForRemoval = nil;
        }        
    }
    return theFilesMarkedForRemoval;
}

- (NSArray *) directoriesMarkedForRemovalInCVLFiles:(NSArray *)someCVLFiles
    /*" This method checks to see which CVL files (folders only) in the array someCVLFiles
    have been marked for removal. If they are none
    then this method returns nil. If not then this method returns an array of 
    CVLFiles (folders only) of those that have been marked for removal.

    See also #{-reinstateFilesMarkedForRemoval:} and 
#{-unrollCVLFiles:} and 
#{-filenamesOfFilesNotMarkedForRemovalInSelectedFiles}.
    "*/
{
    NSMutableArray  *theFoldersMarkedForRemoval = nil;
    CVLFile         *aCVLFile = nil;
    NSEnumerator    *anEnumerator = nil;
    unsigned int    aCount = 0;
    
    if ( isNotEmpty(someCVLFiles) ) {
        aCount = [someCVLFiles count];
        theFoldersMarkedForRemoval = [NSMutableArray arrayWithCapacity:aCount];
        anEnumerator = [someCVLFiles objectEnumerator];
        while ( (aCVLFile = [anEnumerator nextObject]) ) {
            if ( [aCVLFile isRealDirectory] == YES ) {
                if ( [aCVLFile markedForRemoval] == YES ) {
                    [theFoldersMarkedForRemoval addObject:aCVLFile];
                }                                                
            }
        }
        if ( [theFoldersMarkedForRemoval count] == 0 ) {
            theFoldersMarkedForRemoval = nil;
        }        
    }        
    return theFoldersMarkedForRemoval;
}

- (NSArray *) filenamesOfFilesMarkedForRemovalInSelectedFiles
    /*" This method checks to see which CVL files in the selected
        files (after being unrolled) have been marked for removal. If they are none
        then this method returns nil. If not then this method returns an array of 
        filenames of those that have been marked for removal. This method is
        used to present the user with a list of files that that are marked 
        for removal when he is trying to reinstate them.

        See also #{-reinstateFilesMarkedForRemoval:} and 
        #{-filenamesOfFilesMarkedForRemovalInFiles:} and 
        #{-filenamesOfFilesNotMarkedForRemovalInSelectedFiles}.
    "*/
{
    NSArray         *mySelectedCVLFiles = nil;
    NSArray         *myCVLFilesMarkedForRemoval = nil;
    NSMutableArray  *theFilenamesMarkedForRemoval = nil;
    NSEnumerator    *anEnumerator = nil;
    CVLFile        *aCVLFile = nil;
    NSString        *aName = nil;
    unsigned int    aCount = 0;

    mySelectedCVLFiles = [currentViewer selectedCVLFiles];
    if ( isNotEmpty(mySelectedCVLFiles) ) {
        myCVLFilesMarkedForRemoval = [self 
                            filesMarkedForRemovalInCVLFiles:mySelectedCVLFiles];
        if ( isNotEmpty(myCVLFilesMarkedForRemoval) ) {
            aCount = [myCVLFilesMarkedForRemoval count];
            theFilenamesMarkedForRemoval = [NSMutableArray arrayWithCapacity:aCount];
            anEnumerator = [myCVLFilesMarkedForRemoval objectEnumerator];
            while ( (aCVLFile = [anEnumerator nextObject]) ) {
                aName = [aCVLFile name];
                SEN_ASSERT_NOT_EMPTY(aName);
                [theFilenamesMarkedForRemoval addObject:aName];
            }        
        }
    }
    return theFilenamesMarkedForRemoval;
}

- (NSArray *) filenamesOfFilesNotMarkedForRemovalInSelectedFiles
    /*" This method checks to see if there all the CVL files in the selected
        files (after being unrolled) have been marked for removal. If they are
        then this method returns nil. If not then this method returns an array of 
        filenames of those that have not been marked for removal. This method is
        used to present the user with a list of files that that are not marked 
        for removal when he is trying to reinstate them by mistake.

        See also #{-reinstateFilesMarkedForRemoval:} and 
        #{-selectedCVLFilesUnrolled}.

        Note: As of version 3.1.0 (22-Jan-2004) this method is no longer being 
        used.
    "*/
{
    NSArray         *mySelectedCVLFiles = nil;
    NSMutableArray  *myFilesNotMarkedForRemoval = nil;
    CVLFile         *aCVLFile = nil;
    NSEnumerator    *anEnumerator = nil;
    NSString        *aName = nil;
    unsigned int    aCountOfAllFiles = 0;
    ECFileFlags fileFlags;

    mySelectedCVLFiles = [currentViewer selectedCVLFilesUnrolled];
    if ( isNotEmpty(mySelectedCVLFiles) ) {
        aCountOfAllFiles = [mySelectedCVLFiles count];
        myFilesNotMarkedForRemoval = [NSMutableArray arrayWithCapacity:aCountOfAllFiles];
        anEnumerator = [mySelectedCVLFiles objectEnumerator];
        while ( (aCVLFile = [anEnumerator nextObject]) ) {
            if ( [aCVLFile markedForRemoval] == NO ) {
                fileFlags = [aCVLFile flags];
                // Ignore if this file is an Inactive File. For example this
                // could be an empty folder whose files were removed.
                if ( fileFlags.type == ECInactiveFile ) {
                    continue;
                } else {
                    aName = [aCVLFile name];
                    SEN_ASSERT_NOT_EMPTY(aName);
                    [myFilesNotMarkedForRemoval addObject:aName];
                }
            }                                
        }
        if ( [myFilesNotMarkedForRemoval count] == 0 ) {
            myFilesNotMarkedForRemoval = nil;
        }        
    }
    return myFilesNotMarkedForRemoval;
}

- (IBAction) turnOnEditing:(id)sender
    /*" This is an action method. It will turn on the CVS edit feature for the
        current user for all the selected files (after they have been unrolled
        and filtered) in the CVL browser.
    "*/
{
    NSArray *theSelectedFilesFiltered = nil;
    NSString *theRootPath = nil;
    CvsEditRequest *aCvsEditRequest = nil;
    BOOL proceedWithEdit = NO;
    
    proceedWithEdit = [self checkForWappedDirInSelectedFiles];
    if ( proceedWithEdit ) {
        theSelectedFilesFiltered=[currentViewer relativePathsFromSelectedCVLFilesUnrolledAndFiltered];
        if ( isNotEmpty(theSelectedFilesFiltered) ) {
            theRootPath = [rootFile path];
            SEN_ASSERT_NOT_EMPTY(theRootPath);
            aCvsEditRequest = [CvsEditRequest editRequestForFiles:theSelectedFilesFiltered 
                                                           inPath:theRootPath];
            [aCvsEditRequest schedule];
        }            
    }        
}

- (IBAction) turnOffEditing:(id)sender
    /*" This is an action method. It will turn off the CVS edit feature for the
        current user for all the selected files (after they have been unrolled
        and filtered) in the CVL browser.
    "*/
{
    NSArray *theSelectedFilesFiltered = nil;
    NSArray *theSelectedCVLFilesFiltered = nil;
    NSString *theRootPath = nil;
    CvsEditRequest *aCvsEditRequest = nil;
    BOOL proceedWithUnedit = NO;
    
    proceedWithUnedit = [self checkForWappedDirInSelectedFiles];
    if ( proceedWithUnedit ) {
        theSelectedFilesFiltered=[currentViewer relativePathsFromSelectedCVLFilesUnrolledAndFiltered];
        if ( isNotEmpty(theSelectedFilesFiltered) ) {
            theRootPath = [rootFile path];
            SEN_ASSERT_NOT_EMPTY(theRootPath);
            
            theSelectedCVLFilesFiltered = [currentViewer selectedCVLFilesUnrolledAndFiltered];
            
            proceedWithUnedit = [self checkForModificationsInFiles:theSelectedCVLFilesFiltered];
            if ( proceedWithUnedit ) {
                aCvsEditRequest = [CvsEditRequest 
                    uneditRequestForFiles:theSelectedFilesFiltered 
                                   inPath:theRootPath];
                [aCvsEditRequest schedule];
            }
        }            
    }        
}

- (void) toggleWatchActionForTag:(int)anActionTag
    /*" This is an helper method. It will toggle on or off the CVS watch action 
        specified by the feature anActionTag for the current user for all the 
        selected files (after they have been unrolled and filtered) in the CVL 
        browser.

        See also #{+watchRequestForFiles:inPath:forAction:} in #CvsWatchRequest
    "*/
{
    NSArray *theSelectedFilesFiltered = nil;
    CvsWatchRequest *aCvsWatchRequest = nil;
    NSString *theRootPath = nil;
    BOOL proceedWithWatchAction = NO;

    proceedWithWatchAction = [self checkForWappedDirInSelectedFiles];
    if ( proceedWithWatchAction ) {
        theSelectedFilesFiltered=[currentViewer relativePathsFromSelectedCVLFilesUnrolledAndFiltered];
        if ( isNotEmpty(theSelectedFilesFiltered) ) {
            theRootPath = [rootFile path];
            aCvsWatchRequest = [CvsWatchRequest 
                                watchRequestForFiles:theSelectedFilesFiltered 
                                              inPath:theRootPath
                                           forAction:anActionTag];
            [aCvsWatchRequest schedule];            
        }            
    }
}


- (IBAction) turnOnWatchingForEditAction:(id)sender
    /*" This is an action method. It will turn on the CVS watch edits feature 
        for the current user for all the selected files 
        (after they have been unrolled and filtered) in the CVL browser.
    "*/
{
    [self toggleWatchActionForTag:CvsWatchEditActionTag];
}

- (IBAction) turnOnWatchingForUneditAction:(id)sender
    /*" This is an action method. It will turn on the CVS watch unedits feature 
        for the current user for all the selected files 
        (after they have been unrolled and filtered) in the CVL browser.
    "*/
{
    [self toggleWatchActionForTag:CvsWatchUneditActionTag];
}

- (IBAction) turnOnWatchingForCommitAction:(id)sender
    /*" This is an action method. It will turn on the CVS watch commits feature 
        for the current user for all the selected files 
        (after they have been unrolled and filtered) in the CVL browser.
    "*/
{
    [self toggleWatchActionForTag:CvsWatchCommitActionTag];
}

- (IBAction) turnOnWatchingForAllActions:(id)sender
    /*" This is an action method. It will turn on the CVS watch for all features 
        for the current user for all the selected files 
        (after they have been unrolled and filtered) in the CVL browser.
    "*/
{
    [self toggleWatchActionForTag:CvsWatchAllActionsTag];
}

- (IBAction) turnOnWatchingForNoActions:(id)sender
    /*" This is an action method. It will will no add any CVS watch feature 
        for the current user for all the selected files 
        (after they have been unrolled and filtered) in the CVL browser.
        This method/feature is rarely ever used.
    "*/
{
    [self toggleWatchActionForTag:CvsWatchNoActionTag];
}

- (IBAction) turnOffWatchingForEditAction:(id)sender
    /*" This is an action method. It will turn off the CVS watch edits feature 
        for the current user for all the selected files 
        (after they have been unrolled and filtered) in the CVL browser.
    "*/
{
    [self toggleWatchActionForTag:CvsUnwatchEditActionTag];
}

- (IBAction) turnOffWatchingForUneditAction:(id)sender
    /*" This is an action method. It will turn off the CVS watch unedits feature 
        for the current user for all the selected files 
        (after they have been unrolled and filtered) in the CVL browser.
    "*/
{
    [self toggleWatchActionForTag:CvsUnwatchUneditActionTag];
}

- (IBAction) turnOffWatchingForCommitAction:(id)sender
    /*" This is an action method. It will turn off the CVS watch commits feature 
        for the current user for all the selected files 
        (after they have been unrolled and filtered) in the CVL browser.
    "*/
{
    [self toggleWatchActionForTag:CvsUnwatchCommitActionTag];
}

- (IBAction) turnOffWatchingForAllActions:(id)sender
    /*" This is an action method. It will turn off the CVS watch for all features 
        for the current user for all the selected files 
        (after they have been unrolled and filtered) in the CVL browser.
    "*/
{
    [self toggleWatchActionForTag:CvsUnwatchAllActionsTag];
}

- (void) deleteFiles:(NSArray *)theRelativeSelectedPaths andUpdate:(BOOL)performUpdate
{
    NSEnumerator *paths = [theRelativeSelectedPaths objectEnumerator];
    NSString *aPath = nil;
    NSString *aCompletePath = nil;
    NSString *theRootPath = nil;
    CvsUpdateRequest *aCvsUpdateRequest = nil;
    NSFileManager	*fileManager = [NSFileManager defaultManager];

    theRootPath = [rootFile path];
    while ( (aPath = [paths nextObject]) ) {
        aCompletePath = [theRootPath stringByAppendingPathComponent:aPath];
        [fileManager removeFileAtPath:aCompletePath handler:nil];
    }
    if ( performUpdate == YES ) {
        aCvsUpdateRequest = [CvsUpdateRequest 
                            cvsUpdateRequestForFiles:theRelativeSelectedPaths 
                                              inPath:theRootPath];
        [aCvsUpdateRequest schedule];
    }
}

- (IBAction) delete:(id)sender
    /*" This method deletes all the selected files and/or folders and then does
        a refresh on the top most directory that contains all the selected files 
        and/or folders. This method is mostly used to delete files that are in
        the workarea but are not yet in the CVS repository.
    "*/
{
    NSArray *theRelativeSelectedPaths=[currentViewer relativeSelectedPaths];
    NSArray *anArrayOfOneFile = nil;
    NSString *aMsg = nil;
    NSString *aFilename = nil;
    NSString *theTopMostDirectory = nil;
    NSArray *theSelectedPaths = nil;
    int aChoice = NSAlertDefaultReturn;
    unsigned int aCount = 0;

    if ( isNotEmpty(theRelativeSelectedPaths) ) {
        aCount = [theRelativeSelectedPaths count];
        if ( aCount == 1 ) {
            aFilename = [theRelativeSelectedPaths objectAtIndex:0];
            aMsg = [NSString stringWithFormat:
                @"The file \"%@\" will be deleted.", aFilename];
        } else {
            aMsg = [NSString stringWithFormat:
                @"The %d selected files will be deleted.", aCount];
        }
        aChoice = NSRunAlertPanel(@"Delete", aMsg, 
                                  @"Delete", @"Cancel", nil);
        if ( aChoice == NSAlertDefaultReturn ) {
            [self deleteFiles:theRelativeSelectedPaths andUpdate:NO];
        }
        // Get the top most directory containing the selected files
        // and then perform a refresh on it.
        theSelectedPaths = [currentViewer selectedPaths];
        if ( isNotEmpty(theSelectedPaths) ) {
            theTopMostDirectory = [self 
                                getTopMostDirectoryContaining:theSelectedPaths];
            if ( theTopMostDirectory != nil ) {
                anArrayOfOneFile = [NSArray arrayWithObject:theTopMostDirectory];
                [self refreshTheseSelectedFiles:anArrayOfOneFile];
            }
        }        
    }
}

- (IBAction) deleteAndUpdateSelectedFiles:(id)sender
{
    NSArray *theRelativeSelectedPaths=[currentViewer relativeSelectedPaths];
    NSString *aMsg = nil;
    NSString *aFilename = nil;
    int aChoice = NSAlertDefaultReturn;
    unsigned int aCount = 0;
    BOOL anyFilesMarkedForRemoval = NO;

    if ( isNotEmpty(theRelativeSelectedPaths) ) {
        aCount = [theRelativeSelectedPaths count];
        if ( aCount == 1 ) {
            aFilename = [theRelativeSelectedPaths objectAtIndex:0];
            aMsg = [NSString stringWithFormat:
                @"The file or folder \"%@\" will lose all of its modifications and will be updated to the latest version in the CVS repository.", 
                aFilename];
        } else {
            aMsg = [NSString stringWithFormat:
                @"The %d selected files and or folders will lose all of their modifications and will be updated to the latest versions in the CVS repository.", 
                aCount];
        }        
        aChoice = NSRunAlertPanel(@"Delete and Update", aMsg, 
                                  @"Delete and Update", @"Cancel", nil);
        if ( aChoice == NSAlertDefaultReturn ) {
            // First check to see if any of the files need to be reinstated.
            anyFilesMarkedForRemoval = [self validateReinstateFilesMarkedForRemoval];
            if ( anyFilesMarkedForRemoval == YES ) {
                [self reinstateFilesMarkedForRemoval:self];
            }
            // Now delete and update.
            [self deleteFiles:theRelativeSelectedPaths andUpdate:YES];
        }
    }
}

- (IBAction) reinstateFilesMarkedForRemoval:(id)sender
    /*" This action method will reinstate the files marked for removal in the
        selected files; but only if at least one of the selected files 
        (after being unrolled) are marked for removal. The user is given a 
        chance via of an alert panel to cancel this operation. If none of the 
        selected files are marked for removal, then the user is presented
        with an alert panel saying none of these files are marked for removal. In 
        this case no action is performed.
    "*/
{
    NSArray *mySelectedCVLFiles = nil;
    NSEnumerator *anEnumerator = nil;
    NSString *theRootPath = nil;
    CvsUpdateRequest *aCvsUpdateRequest = nil;
    CVLFile *aCVLFile = nil;
    CvsEntry * aCvsEntry = nil;
    NSArray *myFilesMarkedForRemoval = nil;    
    NSArray *theRelativeSelectedPaths = nil; 
    NSString *aFilename = nil;
    int aChoice = NSAlertDefaultReturn;
    unsigned int aCount = 0;

    myFilesMarkedForRemoval = [self filenamesOfFilesMarkedForRemovalInSelectedFiles];

    if ( isNotEmpty(myFilesMarkedForRemoval) ) {
        aCount = [myFilesMarkedForRemoval count];
        if ( aCount == 1 ) {
            aFilename = [myFilesMarkedForRemoval objectAtIndex:0];
            aChoice = NSRunAlertPanel(@"Reinstate File(s) Marked for Removal", 
                                      @"The file \"%@\" has been deleted and then marked for removal in the CVS repository. This action will unmark this file for removal and then copy the latest file from the repository to this workarea.", 
                                      @"Reinstate", @"Cancel", nil,
                                      aFilename);            
        } else {
            aChoice = NSRunAlertPanel(@"Reinstate File(s) Marked for Removal", 
                                      @"There are %d files in the selection that have been deleted and then marked for removal in the CVS repository. This action will unmark these files for removal and then copy the latest files from the repository to this workarea.", 
                                      @"Reinstate", @"Cancel", nil,
                                      aCount);            
        }
        if ( aChoice == NSAlertDefaultReturn) {
            theRootPath = [rootFile path];
            mySelectedCVLFiles = [currentViewer selectedCVLFilesUnrolled];
            anEnumerator = [mySelectedCVLFiles objectEnumerator];
            while ( (aCVLFile = [anEnumerator nextObject]) ) {
                if ( [aCVLFile markedForRemoval] == YES ) {
                    aCvsEntry = [aCVLFile cvsEntry];
                    [aCvsEntry deleteTheMarkedForRemovalFlag];
                }
            }
            theRelativeSelectedPaths = [currentViewer relativeSelectedPaths];
            aCvsUpdateRequest = [CvsUpdateRequest 
                            cvsUpdateRequestForFiles:theRelativeSelectedPaths 
                                              inPath:theRootPath];
            [aCvsUpdateRequest schedule];
        }
    } else {
        (void)NSRunAlertPanel(@"Cancel Reinstate File(s) Marked For Removal", 
                              @"None of the files that are selected have been marked for removal. \n\nNothing will be done. Please select files or folders that contain files that have been marked for removal.", 
                              nil, nil, nil);                
    }
}


- (IBAction) diffSelectedFiles:(id)sender
{
    NSEnumerator	*selectedFileEnum = [[currentViewer relativeSelectedPaths] objectEnumerator];
    NSString		*aFile;

    while ( (aFile = [selectedFileEnum nextObject]) ) {
        NSString			*currentFullPath = [[rootFile path] stringByAppendingPathComponent:aFile];
        CVLOpendiffRequest	*aRequest = [CVLOpendiffRequest opendiffRequestForFile:currentFullPath];

        if(aRequest)
            [aRequest schedule];
        else{
#ifdef DEBUG
        {
            NSString *aMsg = [NSString stringWithFormat:
                @"opendiff not possible for %@; using diff", aFile];
            SEN_LOG(aMsg);            
        }
#endif
            [[CvsDiffRequest cvsDiffRequestAtPath:[rootFile path] files:[NSArray arrayWithObject:aFile] context:3 outputFormat:CVLNormalOutputFormat] schedule];
        }
    }
}


- (IBAction) addSelectedFiles:(id)sender
{
    NSArray *theRelativeSelectedPaths=[currentViewer relativeSelectedPaths];

    if (theRelativeSelectedPaths) {
        [[CvsAddRequest cvsAddRequestAtPath:[rootFile path] 
                                      files:theRelativeSelectedPaths] schedule];
    }
}

- (IBAction) addSelectedFilesAsBinary:(id)sender
{
    NSArray *theRelativeSelectedPaths=[currentViewer relativeSelectedPaths];

    if (theRelativeSelectedPaths) {
        [[CvsAddRequest cvsAddRequestAtPath:[rootFile path] 
                                      files:theRelativeSelectedPaths 
                               forcesBinary:YES] schedule];
    }
}


- (void) removeFilesSheetDidDismiss:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    NSArray *theRelativeSelectedPaths = (NSArray *)contextInfo;

    if(returnCode == NSAlertDefaultReturn)
        [[CvsRemoveRequest removeRequestAtPath: [rootFile path] files: theRelativeSelectedPaths] schedule];
    [theRelativeSelectedPaths release]; // Because we retained it before invocation
}

- (IBAction) removeSelectedFiles:(id)sender
{
    NSArray *theRelativeSelectedPaths=[currentViewer relativeSelectedPaths];

    if (theRelativeSelectedPaths)
    {
        NSBeginAlertSheet(@"CVS Remove", @"OK", @"Cancel", nil, window, self, NULL, @selector(removeFilesSheetDidDismiss:returnCode:contextInfo:), [theRelativeSelectedPaths retain], @"Do you really want to remove the selected file(s) from the Work Area ?");
    }
}


- (IBAction) refreshSelectedFiles:(id)sender
{    
    NSArray *theSelectedPaths=[currentViewer selectedPaths];
    if (theSelectedPaths && ([theSelectedPaths count] > 0)) {
        [self refreshTheseSelectedFiles:theSelectedPaths];
    }
}

- (void) refreshTheseSelectedFiles:(NSArray *)someSelectedFiles
{
    ResultsRepository *resultsRepository = [ResultsRepository sharedResultsRepository];
    
    if (someSelectedFiles && ([someSelectedFiles count] > 0)) {
        NSEnumerator *fileEnumerator = [someSelectedFiles objectEnumerator];
        NSString *filePath;
        
        [resultsRepository startUpdate];
        while ( (filePath = [fileEnumerator nextObject]) ) {
            CVLFile* file= [CVLFile treeAtPath:filePath];
            
            if ([file isLeaf])
            {
                [file invalidateAll];
            }
            else
            {
                [file traversePostorder:@selector(invalidateAll)];
            }
        }
        [resultsRepository endUpdate];
    }
}


/*
- (IBAction) renameSelectedFile:(id)sender
{
    [[CVLRenameController sharedInstance] renameFileNamed:[[currentViewer relativeSelectedPaths] lastObject] fromWorkArea:[rootFile path]];
}
*/

- (void) doReleaseWorkAreaAndDelete:(BOOL)flag
{
    CvsReleaseRequest	*aRequest = [CvsReleaseRequest cvsReleaseRequestWithPath:[rootFile path] deleteWorkArea:flag handler:self];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(releaseRequestCompleted:) name:@"RequestCompleted" object:aRequest];
    [aRequest schedule];
}

- (void) releaseWorkAreaSheetDidDismiss:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    BOOL	flag;
    
    switch(returnCode){
        case NSAlertDefaultReturn:
            flag = YES;
            break;
        case NSAlertAlternateReturn:
            flag = NO;
            break;
        default:
            return;
    }
    [self doReleaseWorkAreaAndDelete:flag];
}

- (IBAction) releaseWorkArea:(id)sender
{
    NSBeginAlertSheet(@"Release Work Area", @"Release & Delete", @"Release", @"Cancel", window, self, NULL, @selector(releaseWorkAreaSheetDidDismiss:returnCode:contextInfo:), NULL, @"Do you really want to release the work area?");
}

- (BOOL) request:(CvsReleaseRequest *)aRequest releaseWorkAreaContainingModifiedFilesNumber:(unsigned)aNumber
{
    if(NSRunAlertPanel(@"Release Work Area", @"You have %d altered %@ in work area %@. Are you sure you want to release%@ it?", @"Cancel", ([aRequest deleteWorkArea] ? @"Release & Delete":@"Release"), nil, aNumber, (aNumber == 1 ? @"file":@"files"), [aRequest workAreaPath], ([aRequest deleteWorkArea] ? @" and delete":@"")) != NSAlertAlternateReturn){
        [[NSNotificationCenter defaultCenter] removeObserver:self name:@"RequestCompleted" object:aRequest];
        return NO;
    }
    return YES;
}

- (void) releaseRequestCompleted:(NSNotification *)aNotification
{
    NSParameterAssert(aNotification != nil);
    [[NSNotificationCenter defaultCenter] removeObserver:self name:[aNotification name] object:[aNotification object]];
    if([[aNotification object] succeeded]){
        // WARNING: request will succeed even if we tell it not to release! That's why we remove ourself as observer of
        // notification in request:releaseWorkAreaContainingModifiedFilesNumber: if user does not want to continue
        if([[aNotification object] deleteWorkArea] || ![[NSUserDefaults standardUserDefaults] boolForKey:@"DoNotCloseReleasedWorkArea"])
            [window performClose:nil];
    }
    else{
        // We could warn user...
    }
}

//-------------------------------------------------------------------------------------


// @implementation WorkAreaViewer(WindowDelegate)

- (id) validRequestorForSendType:(NSString *)sendType returnType:(NSString *)returnType
{
    if (([sendType isEqualToString: NSStringPboardType]) || ([sendType isEqualToString: NSFilenamesPboardType]))
    {
        // Even if there is no selection, we can provide a path
        return self;
    }
    else
    {
        return nil;
    }
}


- (IBAction) updateViewer:(id)sender
{	// called through the responder chain
    ResultsRepository *resultsRepository=[ResultsRepository sharedResultsRepository];

    [resultsRepository startUpdate];
    [(CVLFile *)[CVLFile treeAtPath:[rootFile path]] traversePostorder:@selector(invalidateAll)];
    [resultsRepository endUpdate];
} // updateViewer:


- (void) doOpenFilesInWS:(NSArray *)files
{ // called through the responder chain
    NSString *filePath;
    id enumerator=[files objectEnumerator];

    while ( (filePath=[enumerator nextObject]) )
    {
        // First, let us check to see if the file still exists.
        NSFileManager	*fileManager = [NSFileManager defaultManager];
        if ( [fileManager senFileExistsAtPath:filePath] == NO ) {
            (void)NSRunAlertPanel(@"CVL File System Message", 
                                  @"Sorry, this file (i.e. %@) no longer exists in the file system.",
                                  nil, nil, nil, filePath);
        }
        // If open failed, we could try to open it with a default application
        // On Windows, files whose suffix is not mapped by any app are not opened
        // Let's use TextEdit/Open File service!
        if(![[NSWorkspace sharedWorkspace] openFile:filePath]){
            NSPasteboard	*aPasteboard = [NSPasteboard pasteboardWithUniqueName];

            [aPasteboard declareTypes:[NSArray arrayWithObjects:NSFilenamesPboardType, NSStringPboardType, nil] owner:nil];
            [aPasteboard addTypes:[NSArray arrayWithObjects:NSFilenamesPboardType, NSStringPboardType, nil] owner:nil];
            [aPasteboard setPropertyList:[NSArray arrayWithObject:filePath] forType:NSFilenamesPboardType];
            [aPasteboard setString:filePath forType:NSStringPboardType];
            
            (void)NSPerformService(@"TextEdit/Open File", aPasteboard);
        }
    }
}

- (IBAction) openFilesInWS: sender
{
    [self doOpenFilesInWS:[currentViewer selectedPaths]];
} // openFilesInWS:

- (IBAction) revealSelectedFiles:(id)sender
{
    NSString		*filePath;
    NSEnumerator	*enumerator = [[currentViewer selectedPaths] objectEnumerator];

    while ( (filePath = [enumerator nextObject]) ) {
        (void)[[NSWorkspace sharedWorkspace] selectFile:filePath inFileViewerRootedAtPath:[filePath stringByDeletingLastPathComponent]];
    }
}

- (IBAction) revealWorkArea:(id)sender
{
    NSString	*workAreaPath = [rootFile path];

    (void)[[NSWorkspace sharedWorkspace] selectFile:workAreaPath inFileViewerRootedAtPath:[workAreaPath stringByDeletingLastPathComponent]];
}

- (void) viewerDoubleSelect: (NSNotification *)notification
{
    if ([notification object] == currentViewer)
    {
        [self openFilesInWS: self];
    }
}


- (IBAction) selectInWS: sender
{ // called through the responder chain
    NSString* path= [[currentViewer selectedPaths] lastObject];
  //BOOL result= NO;
    
    [[NSWorkspace sharedWorkspace] selectFile:path inFileViewerRootedAtPath: @"/"]; //NSHomeDirectory()
} // selectInWS:


- (IBAction) windowDidBecomeKey:(id)sender
{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ViewerDidBecomeKey" object: self];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"PathSelected" object: [currentViewer selectedPaths]];
} // windowDidBecomeKey:


- (IBAction) windowWillClose:(id)sender
{
    viewerIsClosing = YES;
    [window setDelegate:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ViewerWillClose" object: self];
    //        [self release];
} // windowWillClose:
/*
- (id)autorelease
{
    return [super autorelease];
}

- (void)release
{
    [super release];
}
*/
- (IBAction) windowDidMiniaturize:(id)sender
{
    windowIsMiniaturized= YES;
} // windowDidMiniaturize:


- (IBAction) windowDidDeminiaturize:(id)sender
{
    windowIsMiniaturized= NO;
} // windowDidDeminiaturize:

#if 0
- (NSSize) windowWillResize:(id)sender toSize:(NSSize)frameSize
{
    return [self suggestNewSizeForSize:frameSize];
}

- (NSSize)suggestNewSizeForSize:(NSSize)frameSize
{
    if ([currentViewer respondsToSelector: @selector(viewerWillResizetoSize:)]) {
        NSSize viewerSize;
        NSSize newViewerSize;
        NSSize contentSize;
        NSRect newWindowFrame;
        NSSize newContentSize;
        NSRect contentFrame;

        contentFrame=[NSWindow contentRectForFrameRect:[window frame] styleMask:[window styleMask]];
        contentSize=contentFrame.size;

        newWindowFrame=[window frame];
        newWindowFrame.size=frameSize;
        newContentSize=[NSWindow contentRectForFrameRect:newWindowFrame styleMask:[window styleMask]].size;

        viewerSize=[[currentViewer view] frame].size;
        newViewerSize.width=newContentSize.width-(contentSize.width-viewerSize.width);
        newViewerSize.height=newContentSize.height-(contentSize.height-viewerSize.height);

        newViewerSize=[currentViewer viewerWillResizetoSize:newViewerSize];
        newContentSize.width=newViewerSize.width+(contentSize.width-viewerSize.width);
        newContentSize.height=newViewerSize.height+(contentSize.height-viewerSize.height);

        contentFrame.size=newContentSize;
        frameSize=[NSWindow frameRectForContentRect:contentFrame styleMask:[window styleMask]].size;
    }
    return frameSize;
} // windowWillResize:toSize:

- (IBAction) viewerFrameSizeChanged:(id)sender
{
    // Invoked when user changes column size/count in preferences
    // and from -showWindowWithDictionary:
    NSRect newFrame, oldFrame;

    oldFrame = newFrame =[window frame];
    newFrame.size=[self suggestNewSizeForSize:newFrame.size];
    if(NSEqualRects(oldFrame, newFrame)){
        // Special case: if frame didn't change, then browser
        // doesn't change size => doesn't update number of columns!
        // In order to force this, we change size by 1, then restore it,
        // this way notifications are sent correctly.
        oldFrame.size.width += 1;
        [window setFrame:oldFrame display:NO];
    }
    [window setFrame:newFrame display:YES];
}
#endif

- (void) windowDidResignKey: (NSNotification*) aNotification
{
    if ([aNotification object] == window)
    {
        currentTopLeft.x= NSMinX([window frame]);
        currentTopLeft.y= NSMaxY([window frame]);
    }
}

- (void) schedulerDidChange: (NSNotification *)notification
{
    [self updateProcessesIndicator];
}

- (void)updateProcessesIndicator
{
    int requestCount;

    requestCount=[[CVLScheduler sharedScheduler] requestCount];
    if (requestCount==0) {
        [processesButton setTitle:@""];
    } else {
        int requestCountForWorkArea = [[CVLScheduler sharedScheduler] requestCountForPath:[self rootPath]];
        if (requestCountForWorkArea < 2) {
            [processesButton setTitle:[NSString stringWithFormat:@"%d / %d background process...",requestCountForWorkArea, requestCount]];
        }
        else {
            [processesButton setTitle:[NSString stringWithFormat:@"%d / %d background processes...",requestCountForWorkArea, requestCount]];
        }
        
    }
}

- (BOOL)doesSelectedFilesContainAFolder
{
    NSArray	*theSelectedPaths = nil;
    NSString *aPathName = nil;
    CVLFile *aCVLFile = nil;
    NSEnumerator *anEnumerator = nil;
    
    theSelectedPaths = [currentViewer selectedPaths];
    if ( isNotEmpty(theSelectedPaths) ) {
        anEnumerator = [theSelectedPaths objectEnumerator];
        while ( (aPathName = [anEnumerator nextObject]) ) {
            aCVLFile = (CVLFile *)[CVLFile treeAtPath:aPathName];
            if ( [aCVLFile isRealDirectory] ) {
                return YES;
            }
        }
    }
    return NO;
}

- (BOOL)doAllSelectedFilesHaveStickyAttributes
    /*" This method returns YES if all of the selected files have sticky 
        attributes; otherwise NO is returned.
    "*/
{
    NSArray	*theSelectedPaths = nil;
    NSString *aPathName = nil;
    CVLFile *aCVLFile = nil;
    NSEnumerator *anEnumerator = nil;
    
    theSelectedPaths = [currentViewer selectedPaths];
    if ( isNotEmpty(theSelectedPaths) ) {
        anEnumerator = [theSelectedPaths objectEnumerator];
        while ( (aPathName = [anEnumerator nextObject]) ) {
            aCVLFile = (CVLFile *)[CVLFile treeAtPath:aPathName];
            // Check to see if this file has sticky attributes.
            if ( [aCVLFile hasStickyAttributes] == NO ) {
                return NO;
            }
        }
        return YES;
    }
    return NO;
}

- (BOOL)doesSelectedFilesContainAFileMarkedForRemoval
    /*" This method returns YES if any of the files in the selected files are
        marked for removal; otherwise NO is returned.
    "*/
{
    NSArray	*theSelectedPaths = nil;
    NSString *aPathName = nil;
    CVLFile *aCVLFile = nil;
    NSEnumerator *anEnumerator = nil;
    
    theSelectedPaths = [currentViewer selectedPaths];
    if ( isNotEmpty(theSelectedPaths) ) {
        anEnumerator = [theSelectedPaths objectEnumerator];
        while ( (aPathName = [anEnumerator nextObject]) ) {
            aCVLFile = (CVLFile *)[CVLFile treeAtPath:aPathName];
            // Check to see if this file is already marked for removal.
            if ( [aCVLFile markedForRemoval] == YES ) {
                return YES;
            }
        }
    }
    return NO;
}

- (BOOL)doesSelectedFilesContainAFileMarkedForAddition
    /*" This method returns YES if any of the files in the selected files are
        marked for addition; otherwise NO is returned.
    "*/
{
    NSArray	*theSelectedPaths = nil;
    NSString *aPathName = nil;
    CVLFile *aCVLFile = nil;
    NSEnumerator *anEnumerator = nil;
    
    theSelectedPaths = [currentViewer selectedPaths];
    if ( isNotEmpty(theSelectedPaths) ) {
        anEnumerator = [theSelectedPaths objectEnumerator];
        while ( (aPathName = [anEnumerator nextObject]) ) {
            aCVLFile = (CVLFile *)[CVLFile treeAtPath:aPathName];
            // Check to see if this file is already marked for addition.
            if ( [aCVLFile markedForAddition] == YES ) {
                return YES;
            }
        }
    }
    return NO;
}

- (BOOL)doesSelectedFilesContainAFileNotUnderCvsControl
    /*" This method returns YES if any of the files in the selected files are
        not under CVS control; otherwise NO is returned.
    "*/
{
    NSArray	*theSelectedPaths = nil;
    NSString *aPathName = nil;
    CVLFile *aCVLFile = nil;
    NSEnumerator *anEnumerator = nil;
    
    theSelectedPaths = [currentViewer selectedPaths];
    if ( isNotEmpty(theSelectedPaths) ) {
        anEnumerator = [theSelectedPaths objectEnumerator];
        while ( (aPathName = [anEnumerator nextObject]) ) {
            aCVLFile = (CVLFile *)[CVLFile treeAtPath:aPathName];
            // Check to see if this file can be added. If it is then it is not
            // under CVS control.
            if ( [aCVLFile canBeAdded] == YES ) {
                return YES;
            }
        }
    }
    return NO;
}

- (void) retrieveSelectedFilesVersionForAction:(int)anActionType
{
    NSArray *theRelativeSelectedPaths = nil;
    RetrievePanelController *aController = nil;
    NSString *aPath = nil;
    
    theRelativeSelectedPaths=[currentViewer relativeSelectedPaths];
    if ( isNotEmpty(theRelativeSelectedPaths) ) {
        aPath = [rootFile path];
        SEN_ASSERT_NOT_EMPTY(aPath);
        aController=[RetrievePanelController sharedRetrievePanelController];
        SEN_ASSERT_NOT_NIL(aController);
        [aController retrieveVersionForFiles:theRelativeSelectedPaths 
                                 inDirectory:aPath 
                                   forAction:anActionType];
    }
}

- (IBAction) removeStickyAttributesAndUpdate:(id)sender
{
    [self retrieveSelectedFilesVersionForAction:CVL_REMOVE_STICKY_ATTRIBUTES];
}

- (IBAction) replaceWorkAreaFiles:(id)sender
{
    [self retrieveSelectedFilesVersionForAction:CVL_RETRIEVE_REPLACE];
}

- (IBAction) restoreWorkAreaFiles:(id)sender
{
    [self retrieveSelectedFilesVersionForAction:CVL_RETRIEVE_RESTORE];
}

- (IBAction) openVersionsInTemporaryDirectory:(id)sender
{
    [self retrieveSelectedFilesVersionForAction:CVL_RETRIEVE_OPEN];
}

- (IBAction) saveVersionAs:(id)sender
{
    [self retrieveSelectedFilesVersionForAction:CVL_RETRIEVE_SAVE_AS];
}


//-------------------------------------------------------------------------------------

// @implementation WorkAreaViewer (MenuValidation)

- (BOOL)validateMenuItem:(id <NSMenuItem>)menuItem
{
    SEL anAction= [menuItem action];
    NSString* anActionString= NSStringFromSelector(anAction);
    CVLFile *aCVLFile = nil;
    CvsWatcher *aCvsWatcher = nil;
    NSRange filesRange= [anActionString rangeOfString: @"Files"];
    NSRange workareaRange= [anActionString rangeOfString: @"WorkArea"];
    int selectionCount= [[currentViewer selectedPaths] count];
    int currentTag= [menuItem tag];
    BOOL cvsEditorsAndWatchersEnabled = NO;

    // For popup item "View files with status:"
    if ( [anActionString isEqualToString:@"filterPreselectionPopped:"] ) {
        return YES;
    }
    
	// For menu items "Update" and "Update Locally"
    if ( [anActionString isEqualToString:@"updateSelectedFiles:"] ) {
        return YES;        
    }
	
    // For menu item "Open Versions in Temporary Dir..."
    if ( [anActionString isEqualToString:@"openVersionsInTemporaryDirectory:"] ) {
        if ( (selectionCount > 0) &&
             ([self doesSelectedFilesContainAFileNotUnderCvsControl] == NO) &&
             ([self doesSelectedFilesContainAFileMarkedForAddition] == NO) &&
             ([self doesSelectedFilesContainAFolder] == NO) ) {
            return YES;
        }
        return NO;        
    }
    
    // For menu item "Remove Sticky Attributes and Update..."
    if ( [anActionString isEqualToString:@"removeStickyAttributesAndUpdate:"] ) {
        if ( (selectionCount > 0) &&
             ([self doesSelectedFilesContainAFolder] == NO) &&
             ([self doesSelectedFilesContainAFileNotUnderCvsControl] == NO) &&
             ([self doesSelectedFilesContainAFileMarkedForRemoval] == NO) &&
             ([self doesSelectedFilesContainAFileMarkedForAddition] == NO) &&
             ([self doAllSelectedFilesHaveStickyAttributes] == YES) ) {
            return YES;
        }
        return NO;        
    }
    
    // For menu item "Replace WorkArea Files with Version..."
    if ( [anActionString isEqualToString:@"replaceWorkAreaFiles:"] ) {
        if ( (selectionCount > 0) &&
             ([self doesSelectedFilesContainAFolder] == NO) &&
             ([self doesSelectedFilesContainAFileNotUnderCvsControl] == NO) &&
             ([self doesSelectedFilesContainAFileMarkedForAddition] == NO) &&
             ([self doesSelectedFilesContainAFileMarkedForRemoval] == NO) ) {
            return YES;
        }
        return NO;        
    }
    
    // For menu item "Restore WorkArea Files with Version..."
    if ( [anActionString isEqualToString:@"restoreWorkAreaFiles:"] ) {
        if ( (selectionCount > 0) &&
             ([self doesSelectedFilesContainAFolder] == NO) &&
             ([self doesSelectedFilesContainAFileNotUnderCvsControl] == NO) &&
             ([self doesSelectedFilesContainAFileMarkedForAddition] == NO) &&
             ([self doesSelectedFilesContainAFileMarkedForRemoval] == NO) ) {
            return YES;
        }
        return NO;        
    }
    
    // For menu item "Save Version As..."
    if ( [anActionString isEqualToString:@"saveVersionAs:"] ) {
        if ( (selectionCount == 1) &&
             ([self doesSelectedFilesContainAFileNotUnderCvsControl] == NO) &&
             ([self doesSelectedFilesContainAFileMarkedForAddition] == NO) &&
             ([self doesSelectedFilesContainAFolder] == NO) ) {
            return YES;
        }
        return NO;        
    }
    
    // For all the Editors and Watchers menu items.
    cvsEditorsAndWatchersEnabled = [[NSUserDefaults standardUserDefaults] 
                                    boolForKey:@"CvsEditorsAndWatchersEnabled"];

    // For menu item "Start Editing"
    if ( [anActionString isEqualToString:@"turnOnEditing:"] ) {
        if ( cvsEditorsAndWatchersEnabled == NO ) return NO;
        if ( selectionCount == 1 ) {
            aCVLFile = [currentViewer selectedCVLFile];
            if ( aCVLFile != nil ) {
                if ( [aCVLFile isRealDirectory] ) {
                    return YES;
                }
                if ( [aCVLFile cvsEditorForCurrentUser] == nil ) {
                    return YES;
                }                
            }
        } else if ( selectionCount > 1 ) {
            return YES;
        }
        return NO;        
    }
    
    // For menu item "End Editing"
    if ( [anActionString isEqualToString:@"turnOffEditing:"] ) {
        if ( cvsEditorsAndWatchersEnabled == NO ) return NO;
        if ( selectionCount == 1 ) {
            aCVLFile = [currentViewer selectedCVLFile];
            if ( aCVLFile != nil ) {
                if ( [aCVLFile isRealDirectory] ) {
                    return YES;
                }
                if ( [aCVLFile cvsEditorForCurrentUser] != nil ) {
                    return YES;
                }                
            }
        } else if ( selectionCount > 1 ) {
            return YES;
        }
        return NO;        
    }
    
    // For menu item "Start Watching - All"
    if ( [anActionString isEqualToString:@"turnOnWatchingForAllActions:"] ) {
        if ( cvsEditorsAndWatchersEnabled == NO ) return NO;
        if ( selectionCount == 1 ) {
            aCVLFile = [currentViewer selectedCVLFile];
            if ( aCVLFile != nil ) {
                if ( [aCVLFile isRealDirectory] ) {
                    return YES;
                }                
                aCvsWatcher = [aCVLFile cvsWatcherForCurrentUser];
                if ( aCvsWatcher == nil ) {
                    return YES;
                } else {
                    if ( [[aCvsWatcher watchesEdit] boolValue] == NO ) return YES;
                    if ( [[aCvsWatcher watchesUnedit] boolValue] == NO ) return YES;
                    if ( [[aCvsWatcher watchesCommit] boolValue] == NO ) return YES;
                }
            }
        } else if ( selectionCount > 1 ) {
            return YES;
        }
        return NO;        
    }
    
    // For menu item "Stop Watching - All"
    if ( [anActionString isEqualToString:@"turnOffWatchingForAllActions:"] ) {
        if ( cvsEditorsAndWatchersEnabled == NO ) return NO;
        if ( selectionCount == 1 ) {
            aCVLFile = [currentViewer selectedCVLFile];
            if ( aCVLFile != nil ) {
                if ( [aCVLFile isRealDirectory] ) {
                    return YES;
                }                
                aCvsWatcher = [aCVLFile cvsWatcherForCurrentUser];
                if ( aCvsWatcher != nil ) {
                    return YES;
                }
            }
        } else if ( selectionCount > 1 ) {
            return YES;
        }
        return NO;        
    }
    
    // For menu item "Start Watching - Edit"
    if ( [anActionString isEqualToString:@"turnOnWatchingForEditAction:"] ) {
        if ( cvsEditorsAndWatchersEnabled == NO ) return NO;
        if ( selectionCount == 1 ) {
            aCVLFile = [currentViewer selectedCVLFile];
            if ( aCVLFile != nil ) {
                if ( [aCVLFile isRealDirectory] ) {
                    return YES;
                }                
                aCvsWatcher = [aCVLFile cvsWatcherForCurrentUser];
                if ( aCvsWatcher == nil ) {
                    return YES;
                } else {
                    if ( [[aCvsWatcher watchesEdit] boolValue] == NO ) return YES;
                }
            }
        } else if ( selectionCount > 1 ) {
            return YES;
        }
        return NO;        
    }
    
    // For menu item "Stop Watching - Edit"
    if ( [anActionString isEqualToString:@"turnOffWatchingForEditAction:"] ) {
        if ( cvsEditorsAndWatchersEnabled == NO ) return NO;
        if ( selectionCount == 1 ) {
            aCVLFile = [currentViewer selectedCVLFile];
            if ( aCVLFile != nil ) {
                if ( [aCVLFile isRealDirectory] ) {
                    return YES;
                }                
                aCvsWatcher = [aCVLFile cvsWatcherForCurrentUser];
                if ( aCvsWatcher != nil ) {
                    if ( [[aCvsWatcher watchesEdit] boolValue] == YES ) return YES;
                }
            }
        } else if ( selectionCount > 1 ) {
            return YES;
        }
        return NO;        
    }
    
    // For menu item "Start Watching - Unedit"
    if ( [anActionString isEqualToString:@"turnOnWatchingForUneditAction:"] ) {
        if ( cvsEditorsAndWatchersEnabled == NO ) return NO;
        if ( selectionCount == 1 ) {
            aCVLFile = [currentViewer selectedCVLFile];
            if ( aCVLFile != nil ) {
                if ( [aCVLFile isRealDirectory] ) {
                    return YES;
                }                
                aCvsWatcher = [aCVLFile cvsWatcherForCurrentUser];
                if ( aCvsWatcher == nil ) {
                    return YES;
                } else {
                    if ( [[aCvsWatcher watchesUnedit] boolValue] == NO ) return YES;
                }
            }
        } else if ( selectionCount > 1 ) {
            return YES;
        }
        return NO;        
    }
    
    // For menu item "Stop Watching - Unedit"
    if ( [anActionString isEqualToString:@"turnOffWatchingForUneditAction:"] ) {
        if ( cvsEditorsAndWatchersEnabled == NO ) return NO;
        if ( selectionCount == 1 ) {
            aCVLFile = [currentViewer selectedCVLFile];
            if ( aCVLFile != nil ) {
                if ( [aCVLFile isRealDirectory] ) {
                    return YES;
                }                
                aCvsWatcher = [aCVLFile cvsWatcherForCurrentUser];
                if ( aCvsWatcher != nil ) {
                    if ( [[aCvsWatcher watchesUnedit] boolValue] == YES ) return YES;
                }
            }
        } else if ( selectionCount > 1 ) {
            return YES;
        }
        return NO;        
    }
    
    // For menu item "Start Watching - Commit"
    if ( [anActionString isEqualToString:@"turnOnWatchingForCommitAction:"] ) {
        if ( cvsEditorsAndWatchersEnabled == NO ) return NO;
        if ( selectionCount == 1 ) {
            aCVLFile = [currentViewer selectedCVLFile];
            if ( aCVLFile != nil ) {
                if ( [aCVLFile isRealDirectory] ) {
                    return YES;
                }                
                aCvsWatcher = [aCVLFile cvsWatcherForCurrentUser];
                if ( aCvsWatcher == nil ) {
                    return YES;
                } else {
                    if ( [[aCvsWatcher watchesCommit] boolValue] == NO ) return YES;
                }
            }
        } else if ( selectionCount > 1 ) {
            return YES;
        }
        return NO;        
    }
    
    // For menu item "Stop Watching - Commit"
    if ( [anActionString isEqualToString:@"turnOffWatchingForCommitAction:"] ) {
        if ( cvsEditorsAndWatchersEnabled == NO ) return NO;
        if ( selectionCount == 1 ) {
            aCVLFile = [currentViewer selectedCVLFile];
            if ( aCVLFile != nil ) {
                if ( [aCVLFile isRealDirectory] ) {
                    return YES;
                }                                
                aCvsWatcher = [aCVLFile cvsWatcherForCurrentUser];
                if ( aCvsWatcher != nil ) {
                    if ( [[aCvsWatcher watchesCommit] boolValue] == YES ) return YES;
                }
            }
        } else if ( selectionCount > 1 ) {
            return YES;
        }
        return NO;        
    }
    
    // For menu item "Reinstate Files Marked For Removal..."
    if ( [anActionString isEqualToString:@"reinstateFilesMarkedForRemoval:"] ) {
        return [self validateReinstateFilesMarkedForRemoval];
    }

    // For menu item "Delete and Update..."
    if ( [anActionString isEqualToString:@"deleteAndUpdateSelectedFiles:"] ) {
        if ( selectionCount > 0 ) {
            return YES;
        } else {
            return NO;
        }
    }
    
    // For menu item "Mark File(s) for Addition"
    if ( [anActionString isEqualToString:@"addSelectedFiles:"] ) {
        return [self validateAddSelectedFiles];
    }
    
    // For menu item "Mark File(s) for Addition as Binary"
    if ( [anActionString isEqualToString:@"addSelectedFilesAsBinary:"] ) {
        return [self validateAddSelectedFiles];
    }
    
    // For menu item "Mark Files(s) for Removal..."
    if ( [anActionString isEqualToString:@"removeSelectedFiles:"] ) {
        return [self validateRemoveSelectedFiles];
    }
    
    // For menu item "Show Filter" Drawer
    if ( [anActionString isEqualToString:@"toggleFilterDrawer:"] ) {
        NSString *presentTitle = nil;
        
        presentTitle = [menuItem title];
        if ( [self isFilterDrawerOpen] == YES ) {
            if ( [presentTitle isEqualToString:@"Hide Filter"] == NO ) {
                [menuItem setTitle:@"Hide Filter"];
            }
        } else {
            if ( [presentTitle isEqualToString:@"Show Filter"] == NO ) {
                [menuItem setTitle:@"Show Filter"];
            }            
        }
        return YES;
    }
    
	// For all other menu items
    if (currentTag)
    {
        return (selectionCount == currentTag);
    }
    else if (filesRange.length)
    {
        return (selectionCount > 0);
    }
    else if (workareaRange.length)
    {
        return (BOOL) (currentViewer != nil);
    }
    return YES;  // validate other actions by default
}

- (BOOL) validateAddSelectedFiles
    /*" For menu items "Mark File(s) for Addition" and 
        "Mark File(s) for Addition as Binary".

        This method returns YES if all the selected files and or folders are not
        under CVS control; otherwise NO is returned. 
    
        For more information see #{-canBeAdded} in the #CVFiles class.
    "*/
{    
    CVLFile *aCVLFile = nil;
    NSArray *theSelectedCVLFiles = nil;
    NSEnumerator *aCVLFileEnumerator = nil;
    
    theSelectedCVLFiles = [currentViewer selectedCVLFiles];
    if ( isNotEmpty(theSelectedCVLFiles) ) {
        aCVLFileEnumerator = [theSelectedCVLFiles objectEnumerator];
        while ( (aCVLFile = [aCVLFileEnumerator nextObject]) ) {
            if ( [aCVLFile canBeAdded] == NO ) {
                return NO;
            }
        }
        return YES;            
    }
    return NO;        
}

- (BOOL) validateDeleteAndUpdateSelectedFiles
    /*" For menu item "Delete and Update..."

        This method returns YES if there is more than 1 unrolled selected files
        and or folders. (This is too loose, need more conditions here). If there 
        is only one selected file or an empty folder then we check to see if it 
        has been removed locally. If it has then NO is returned. If not then YES
        is returned. The goal here is to not allow the "Delete and Update..." 
        action to be run on a file that has been locally removed. Instead the 
        action "Reinstate Files Marked For Removal..." should be used.

        Note: As of version 3.1.0 (22-Jan-2004) this method is no longer being 
        used.
    "*/
{
    CVLFile *aCVLFile = nil;
    NSArray *theSelectedCVLFiles = nil;
    NSEnumerator *aCVLFileEnumerator = nil;
    
    theSelectedCVLFiles = [currentViewer selectedCVLFiles];
    if ( isNotEmpty(theSelectedCVLFiles) ) {
        aCVLFileEnumerator = [theSelectedCVLFiles objectEnumerator];
        while ( (aCVLFile = [aCVLFileEnumerator nextObject]) ) {
            if ( [aCVLFile canBeDeletedAndUpdated] == NO ) {
                return NO;
            }
        }
        return YES;
    }
    return NO;        
}

- (BOOL) validateReinstateFilesMarkedForRemoval
    /*" For menu item "Reinstate File(s) Marked For Removal..."

        This method returns YES if any of the selected files and or any of the 
        files in any of the selected folders are marked for removal; otherwise 
        NO is returned.
    "*/

{
    CVLFile *aCVLFile = nil;
    NSArray *theSelectedCVLFiles = nil;
    NSEnumerator *aCVLFileEnumerator = nil;
    
    theSelectedCVLFiles = [currentViewer selectedCVLFiles];
    if ( isNotEmpty(theSelectedCVLFiles) ) {
        aCVLFileEnumerator = [theSelectedCVLFiles objectEnumerator];
        while ( (aCVLFile = [aCVLFileEnumerator nextObject]) ) { 
            if ( [aCVLFile canBeReinstatedAfterMarkedForRemoval] == YES ) {
                return YES;
            }
        }
        return NO;            
    }
    return NO;        
}

- (BOOL) validateRemoveSelectedFiles
    /*" For menu item "Mark Files(s) for Removal..."

        This method returns YES if all the selected files and or folders are 
        under CVS control and if they all are not marked for removal already
        and are all up-to-date or only needs update 
        (i.e. have been removed in the file system); otherwise NO is returned.
    "*/
{
    CVLFile *aCVLFile = nil;
    NSArray *theSelectedCVLFiles = nil;
    NSEnumerator *aCVLFileEnumerator = nil;

    theSelectedCVLFiles = [currentViewer selectedCVLFiles];
    if ( isNotEmpty(theSelectedCVLFiles) ) {
        aCVLFileEnumerator = [theSelectedCVLFiles objectEnumerator];
        while ( (aCVLFile = [aCVLFileEnumerator nextObject]) ) { 
            if ( [aCVLFile canBeMarkedForRemoval] == NO ) {
                return NO;
            }
        }
        return YES;            
    }
    return NO;        
}

- (NSString *)getTopMostDirectoryContaining:(NSArray *)someSelectedPaths
    /*" This method returns the path of the top most directory that contains all
        the files/folders in the array named someSelectedPaths. Nil is returned
        if someSelectedPaths is empty.
    "*/
{
    NSEnumerator *selectedPathsEnumerator = nil;
    NSString *aPath = nil;
    NSString *theTopMostDirectory = nil;
    NSFileManager *fileManager = [NSFileManager defaultManager];

    if ( isNotEmpty(someSelectedPaths) ) {
        selectedPathsEnumerator = [someSelectedPaths objectEnumerator];
        while ( (aPath = [selectedPathsEnumerator nextObject]) ) {
            if ( [fileManager senDirectoryExistsAtPath:aPath] == NO ) {
                // Not a directory, delete the filename at the end.
                aPath = [aPath stringByDeletingLastPathComponent];
            }
            // We have a directory, compare with current top most directory.
            // The shortest path should be the top most directory.
            if ( theTopMostDirectory == nil ) {
                theTopMostDirectory = aPath;
            } else {
                if ( [aPath length] < [theTopMostDirectory length] ) {
                    theTopMostDirectory = aPath;
                }
            }
        }
    }
    return theTopMostDirectory;
}

- (BOOL) isFilterDrawerOpen
    /*" This method returns YES if the filter drawer is open or is in the 
        process of opening for this viewer; otherwise NO is returned.
    "*/
{
    if ( ([filterDrawer state] == NSDrawerOpenState) ||
         ([filterDrawer state] == NSDrawerOpeningState) ) {
        return YES;
    }
    return NO;
}

- (IBAction) toggleFilterDrawer:(id)sender
    /*" This method closes the filter drawer if it is open or opens it if it is
        closed.
    "*/
{
    if ( [self isFilterDrawerOpen] == YES ) {
        [filterDrawer close:sender];
    } else {
        [filterDrawer openOnEdge:NSMinXEdge];
    }
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

- (NSArray *)selectedPaths
    /*" This method returns the selected paths in the current viewer. The 
        current viewer is either an instance of WorkAreaListViewer or 
        BrowserController. However WorkAreaListViewer is no longer being used.
    "*/
{
        return [currentViewer selectedPaths];
}

- (void) checkTheTagsAndUpdate:(WorkAreaViewer *)aViewer
    /*" This method will check for branch tags in empty directories when all the
        non-empty directories have non-branch tags by calling the 
        -checkTheTagsForViewer: method. Note: the user is given a chance in the 
        -checkTheTagsForViewer: method to change these to non-branch tags. Then
        this method refreshes these directories since branch directories are 
        displayed in a blue font and non-branch directories are displayed in 
        an italic font.
    "*/
{
    NSArray *myDirectoriesWithEmptyBranchTags = nil;
    
    SEN_ASSERT_CONDITION((aViewer == self));
    // Now create another request that will check for branch tags in empty
    // directories while all the non-empty directories have non-branch tags.
    myDirectoriesWithEmptyBranchTags = [CvsTag checkTheTagsForViewer:self];
    if ( isNotEmpty(myDirectoriesWithEmptyBranchTags) ) {
        [self refreshTheseSelectedFiles:myDirectoriesWithEmptyBranchTags];  
    }
}

- (NSString *)description
    /*" This method overrides supers implementation. Here we return the 
        the class name and the path to the workarea being viewed.
    "*/
{
    NSString *aDescription = nil;
    
    aDescription = [NSString stringWithFormat:@"WorkAreaViewer for %@", [self rootPath]];
    
    return aDescription;
}


//-------------------------------------------------------------------------------------

//@implementation WorkAreaViewer (NSServicesRequests)

- (BOOL)writeSelectionToPasteboard:(NSPasteboard *)pboard
                             types:(NSArray *)types
{
    if (([types containsObject: NSStringPboardType]) || (([types containsObject: NSFilenamesPboardType])))
    {
        [pboard declareTypes: [NSArray arrayWithObjects: NSFilenamesPboardType, NSStringPboardType, nil] owner:self];
        return YES;
    }
    return NO;
}


- (void)pasteboard:(NSPasteboard *)pboard  provideDataForType:(NSString *)type
{
    NSArray	*theSelectedPaths = [currentViewer selectedPaths];

    if(!theSelectedPaths || ![theSelectedPaths count])
        theSelectedPaths = [NSArray arrayWithObject:[self rootPath]]; // Work area directory path
    
    if ([type isEqualToString: NSFilenamesPboardType])
    {
        [pboard setPropertyList: theSelectedPaths forType: NSFilenamesPboardType];
    }
    else if ([type isEqualToString: NSStringPboardType])
    {
        NSString* allSelection= [theSelectedPaths componentsJoinedByString: RequestNewLineString];

        [pboard setString: allSelection forType: NSStringPboardType];
    }
    return;
}


//-------------------------------------------------------------------------------------

// @implementation WorkAreaViewer (Private)

- (void)reflectFilterConfiguration
{
    id cellsOrderEnumerator=[cellsOrder objectEnumerator];
    id cellsEnumerator=[[filterButtonsMatrix cells] objectEnumerator];
    NSArray *configuration=[filterProvider stringArrayFilterDescription];
    id cell;

    while ( (cell=[cellsEnumerator nextObject]) ) {
        [cell setIntValue:[configuration containsObject:[cellsOrderEnumerator nextObject]]];
    }
}

- (void) doRetrieveFile:(NSString *)filePath inPath:(NSString *)path withRevision:(NSString *)revision date:(NSString *)dateString outputFile:(NSString *)outputPath
// File is retrieved in $TEMP and is opened automatically
{
    NSString			*fullPath = [NSTemporaryDirectory() stringByAppendingPathComponent:outputPath];
    CvsUpdateRequest	*updateRequest = nil;
    SelectorRequest		*openRequest;

    updateRequest = [CvsUpdateRequest cvsUpdateRequestForFile:filePath
                                                       inPath:path
                                                     revision:revision
                                                         date:dateString
                                      removesStickyAttributes:NO
                                                       toFile:fullPath];
    openRequest = [SelectorRequest requestWithTarget:self selector:@selector(doOpenFilesInWS:) argument:[NSArray arrayWithObject:[updateRequest destinationFilePath]]];
    [openRequest addPrecedingRequest: updateRequest];
    [openRequest schedule];
}

- (void) openWithApplicationSelectedFilesPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void  *)contextInfo
{
/*    if(returnCode == NSOKButton){
        [[NSWorkspace sharedWorkspace] openFile:withApplication:];
    }*/
}

- (IBAction) openWithApplicationSelectedFiles:(id)sender
{
    NSOpenPanel	*panel= [NSOpenPanel openPanel];

    [panel setCanChooseDirectories:NO];
    [panel setTitle:@"Choose Application"];
    [panel setAllowsMultipleSelection:NO];
    [panel beginSheetForDirectory:nil file:nil types:nil modalForWindow:window modalDelegate:self didEndSelector:@selector(openWithApplicationSelectedFilesPanelDidEnd:returnCode:contextInfo:) contextInfo:NULL];
}

- (void) fileSystemChanged:(NSNotification *)notification
{
    NSString *path = [notification object];
    //    NSString *path = [[notification userInfo] objectForKey:@"Path"];
    
    // FIXME Actually it makes CVL much slower than before, because too many requests are done
    // When you modify a single file, the parent folder is invalidated too!?
    [(CVLFile *)[CVLFile treeAtPath:path] invalidateAll];
}

@end

//-------------------------------------------------------------------------------------
