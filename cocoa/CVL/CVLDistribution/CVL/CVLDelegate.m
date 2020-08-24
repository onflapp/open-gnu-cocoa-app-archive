// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "CVLDelegate.h"
#import "BrowserController.h"
#import "WorkAreaViewer.h"
#import "ProgressPanelController.h"
#import "ResultsRepository.h"

#import <CvsRequest.h>
#import <CvsCheckoutRequest.h>
#import <CvsLoginRequest.h>
#import <CvsUpdateRequest.h>
#import <CvsImportRequest.h>
#import <SelectorRequest.h>
#import <CVLSelectingFilesRequest.h>
#import <CvsPserverRepository.h>
#import <SenPanelFactory.h>
#import <SenFormPanelController.h>
#import <NSString+Lines.h>
#import "CVLConsole.subproj/CVLConsoleController.h"
#import "InfoPanel.subproj/InfoController.h"
#import "Inspector.subproj/CVLInspectorManager.h"
#import "NSFileManager_CVS.h"
#import "RepositoryViewer.h"
#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#import "Comparator.subproj/Comparator.h"
#import <SenFoundation/SenFoundation.h>
#import <CVLEditorClient.h>
#import <CvsEntry.h>

#import <ExceptionHandling/NSExceptionHandler.h>


#define BROWSERS_KEY			@"Browsers"
#define RESOURCES_FILENAME		@"Paths.plist"

static BOOL accessibilityExceptionEncountered = NO;

void CVLUncaughtExceptionHandler(NSException *);

void CVLUncaughtExceptionHandler(NSException *anException) {
    if ( [[anException name] isEqualToString:@"NSAccessibilityException"] ) {
        if ( accessibilityExceptionEncountered == NO ) {
            accessibilityExceptionEncountered = YES;
            NSRunAlertPanel(@"NSAccessibilityException Exceptions", 
                            @"CVL has encountered accessibility exceptions. CVL does not support the Apple accessibility functions at the present. These exception will be ignored. To not encounter these exception turn off the \"Enable access to assistive devices\" checkbox in the System Preferences under the Universal Access icon.", 
                            @"OK", nil, nil,
                            [anException name], [anException reason]);            
        }
        return;
    }
    NSRunAlertPanel(@"Uncaught Exception", 
                    @"The following exception occurred:\nName: %@\nReason: %@\nPlease terminate the application and relaunch it.", 
                    @"OK", nil, nil,
                    [anException name], [anException reason]);
}


//-------------------------------------------------------------------------------------

@interface CVLDelegate(Private)
- (void) viewerDidBecomeKey: (NSNotification *)notification;
- (void) viewerWillClose: (NSNotification *)notification;
- (void) openWorkAreaViewersFrom:(NSArray *)aWorkAreaViewersStateArray;
- (NSArray*) savedWorkAreaViewersStateFrom:(NSArray *)aWorkAreaViewersArray;
//- (void)goForModuleCvsCheckoutInRepository: (CvsRepository *)aRepository;
//- (void)repositoryUpdated:(NSNotification *)notification;
- (void)setActiveViewer:(id)aViewer;
- (void)viewerSelectionDidChange:(NSNotification *)notification;
- (WorkAreaViewer *) currentViewerShowingFile:(CVLFile *)aFile;
- (NSDictionary *) existingDirsFrom:(NSArray*)aWorkAreaViewersStateArray;

@end



//-------------------------------------------------------------------------------------

@implementation CVLDelegate

+ (void)initialize
{
    NSUserDefaults *theUserDefaults = nil;
    static BOOL initialized = NO;

    theUserDefaults = [NSUserDefaults standardUserDefaults];

    /* Make sure code only gets executed once. */
    if (initialized)
    {
        return;
    }
    else
    {
        initialized = YES;

        [NSApp registerServicesMenuSendTypes: [NSArray arrayWithObjects: NSFilenamesPboardType, NSStringPboardType, nil] returnTypes: nil];

        [theUserDefaults registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:[NSString pathWithComponents:[NSArray arrayWithObjects:@"/", @"usr", @"bin", @"opendiff", nil]], @"OpendiffPath", nil]];
        [theUserDefaults registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:[NSString pathWithComponents:[NSArray arrayWithObjects:@"/", @"usr", @"bin", @"cvs", nil]], @"CVSPath", nil]];

        [theUserDefaults registerDefaults: [NSDictionary dictionaryWithObjectsAndKeys: @"160", @"BrowserColumnWidth", nil]];
        [theUserDefaults registerDefaults: [NSDictionary dictionaryWithObjectsAndKeys: @"2", @"BrowserMinColumnCount", nil]];

        [theUserDefaults registerDefaults: [NSDictionary dictionaryWithObjectsAndKeys: @"2", @"BrowserColumnCount", nil]];
        [theUserDefaults registerDefaults: [NSDictionary dictionaryWithObjectsAndKeys: @"160", @"BrowserMinColumnWidth", nil]];
        {
            // Following code was in +[CvsRequest initialize], which is called only when we create the first request. Too late.
#ifdef __ppc__
            NSString* registeredValue= [NSString stringWithString: @"1"];
#else
            NSString* registeredValue= [NSString stringWithString: @"5"];
#endif
            [theUserDefaults registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:registeredValue, @"MaxParallelRequestsCount", @"NO", @"ShowBrowsers", nil]];
        }
        [theUserDefaults registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:@"%b %d %Y", @"CVLDateFormat", nil]];
        [theUserDefaults registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:@"300", @"AlertTimeInterval", nil]];
        [theUserDefaults registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:@"NO", @"CvsEditorsAndWatchersEnabled", nil]];
        [theUserDefaults registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:@"NO", @"DisplayCvsErrors", nil]];
        [theUserDefaults registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:@"", @"DefaultWorkAreaPath", nil]];
    }
    return;
}


+ (NSString*) oldResourceDirectory
{
    return [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:[[NSProcessInfo processInfo] processName]];
}

+ (NSString*) resourceDirectory
// Stephane: on devrait faire une categorie pour NSApplication
{
#if 0
    return [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:[[NSProcessInfo processInfo] processName]];
#else
    // We no longer want to store pref in ~/.AppInfo/CVL
    // We want to be good citizen and store this in ~/Library/CVL
    // To keeps things backward compatible, we copy content of ~/.AppInfo/CVL in ~/Library/CVL
    // if it has not yet been done, so the user will not loose its preferences.
    // If we cannot write to ~/Library/CVL, we try to write in $TEMP directory

#warning CHECK THIS
    static NSString	*resourceDirectory = nil;

    if(!resourceDirectory){
        NSFileManager	*fileManager = [NSFileManager defaultManager];
        BOOL			workWithTemporaryDirectory = NO;

        // Is there a public API to get the ~/Library/Application Support/CVL directory??
        resourceDirectory = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
        resourceDirectory = [resourceDirectory stringByAppendingPathComponent:@"Application Support"];
        resourceDirectory = [resourceDirectory stringByAppendingPathComponent:[[NSProcessInfo processInfo] processName]];

        NSAssert(resourceDirectory != nil, @"Unable to build resource directory path!");

        if(![fileManager senDirectoryExistsAtPath:resourceDirectory]){
            if(![fileManager senDirectoryExistsAtPath:[self oldResourceDirectory]]){
                // Didn't even exist in ~/Library so create it in ~/Library/Application Support
                if(![fileManager createAllDirectoriesAtPath:resourceDirectory attributes: nil])
                    workWithTemporaryDirectory = YES;
            }
            else{
                // Exists in .AppInfo (but not in ~/Library) so let's copy it to the new location
                if(![fileManager copyPath:[self oldResourceDirectory] toPath:resourceDirectory handler:nil]){
                    // Error during copy, so let's forget about old preferences...
                    NSString *aMsg = [NSString stringWithFormat:
                        @"### Unable to restore preferences by copying %@ to %@. Let's forget about them...", 
                        [self oldResourceDirectory], resourceDirectory];
                    SEN_LOG(aMsg);
                    if(![fileManager createAllDirectoriesAtPath:resourceDirectory attributes:nil])
                        workWithTemporaryDirectory = YES;
                }
            }
        }

        if(!workWithTemporaryDirectory) {
            if(![fileManager isWritableFileAtPath:resourceDirectory])
                workWithTemporaryDirectory = YES;
            else
                [resourceDirectory retain];            
        }

        if(workWithTemporaryDirectory){
            NSString *aMsg = nil;
            NSString	*temporaryDir = [[NSTemporaryDirectory() stringByAppendingPathComponent:[[NSProcessInfo processInfo] processName]] stringByAppendingPathComponent:NSUserName()];

            if(NSRunAlertPanel([[NSProcessInfo processInfo] processName], @"Unable to write in directory %@. CVL will temporarily use %@, but you should correct this problem.", @"Quit", @"Continue anyway", nil, resourceDirectory, temporaryDir) == NSAlertDefaultReturn)
                [NSApp terminate:nil];

            aMsg = [NSString stringWithFormat:
                @"### Unable to create directory %@. CVL needs this directory. Correct this. CVL will temporarily work with %@", 
                resourceDirectory, temporaryDir];
            SEN_LOG(aMsg);
            
            if(![fileManager senDirectoryExistsAtPath:temporaryDir])
                if(![fileManager createAllDirectoriesAtPath:temporaryDir attributes:nil]){
                    (void)NSRunCriticalAlertPanel([[NSProcessInfo processInfo] processName], @"Unable to create directory %@. Correct this problem first.", @"Quit", nil, nil, temporaryDir);
                    [NSApp terminate:nil];
                }

            if(![fileManager isWritableFileAtPath:temporaryDir]){
                (void)NSRunCriticalAlertPanel([[NSProcessInfo processInfo] processName], @"Unable to write in directory %@. Correct this problem first.", @"Quit", nil, nil, temporaryDir);
                [NSApp terminate:nil];
            }
            else
                resourceDirectory = [temporaryDir retain];
        }
    }
    return resourceDirectory;
#endif
} // resourceDirectory

- (NSString*) resourceDirectory
{
    return [[self class] resourceDirectory];
}

+ (NSString*) resourceFilename
{
  return [[self resourceDirectory] stringByAppendingPathComponent:RESOURCES_FILENAME];
} // resourceFilename


- init
{
    NSString* resourceFilename;
    NSDictionary* dict;
    NSArray *theSavedWorkAreaViewersStateArray = nil;
    NSDictionary *theExistingSavedWorkAreaViewersState = nil;
    NSUserDefaults *theUserDefaults = nil;
    NSNotificationCenter *theNotificationCenter = nil;
    int aChoice = NSAlertDefaultReturn;
    
    theUserDefaults = [NSUserDefaults standardUserDefaults];
    theNotificationCenter = [NSNotificationCenter defaultCenter];
    
    self= [super init];
    activeViewer= nil;
    currentWorkAreaViewers= [[NSMutableDictionary dictionaryWithCapacity:1] retain];
    resultsRepository=[[ResultsRepository sharedResultsRepository] retain];
    processRequests = [[NSMutableSet setWithCapacity:100] retain];
    
    processStarted = NO;
    processEnded = YES;
    
    [theNotificationCenter 
                addObserver:self 
                   selector:@selector(preferencesChanged:) 
                       name:@"PreferencesChanged" 
                     object:nil];
    [self preferencesChanged:nil];

    [theNotificationCenter
                addObserver:self
                   selector:@selector(browserDidBecomeKey:)
                       name:@"BrowserDidBecomeKey"
                     object:nil];
    [theNotificationCenter
                addObserver:self
                   selector:@selector(viewerDidBecomeKey:)
                       name:@"ViewerDidBecomeKey"
                     object:nil];
    [theNotificationCenter
                addObserver:self
                   selector:@selector(viewerWillClose:)
                       name:@"ViewerWillClose"
                     object:nil];
    [theNotificationCenter
                addObserver:self
                   selector:@selector(requestStateChanged:)
                       name:@"RequestStateChanged"
                     object:nil];
    [theNotificationCenter
                addObserver:self
                   selector:@selector(checkForEndOfProcess:)
                       name:@"RequestStateChanged"
                     object:nil];
    [theNotificationCenter
                addObserver:self
                   selector:@selector(requestReceivedData:)
                       name:@"RequestReceivedData"
                     object:nil];
    [theNotificationCenter addObserver:self selector:@selector(pathSelected:) name:@"PathSelected" object:nil];
    [theNotificationCenter
                addObserver:self
                   selector:@selector(anyRequestCompleted:)
                       name:@"RequestCompleted"
                     object:nil];
    
    resourceFilename= [[self class] resourceFilename];
    dict= [[[NSDictionary alloc] initWithContentsOfFile: resourceFilename] autorelease];
    theSavedWorkAreaViewersStateArray = [dict objectForKey:BROWSERS_KEY];
    if ( isNotEmpty(theSavedWorkAreaViewersStateArray) ) {
        theExistingSavedWorkAreaViewersState = [self 
                                        existingDirsFrom:theSavedWorkAreaViewersStateArray];
    }
    if ( isNotEmpty(theExistingSavedWorkAreaViewersState) ) {
        savedWorkAreaViewersState = [NSMutableDictionary 
                        dictionaryWithDictionary:theExistingSavedWorkAreaViewersState];
    } else {
        savedWorkAreaViewersState = [NSMutableDictionary dictionaryWithCapacity:1];
    }
    [savedWorkAreaViewersState retain];
    
    globalSelection=[[SenSelection alloc] init];
    //  [[CvsRepository new] setLocalCopyPath: [[self class] resourceDirectory]];

    cvlEditorClientConnection = [NSConnection defaultConnection];
    [cvlEditorClientConnection setRootObject:self];
    if(![cvlEditorClientConnection registerName:CVLEditorClientConnectionName]) {
        aChoice = NSRunAlertPanel([[NSProcessInfo processInfo] processName], 
            @"An error occurred when initializing use of cvs templates. Probably another copy of CVL is running that is already using the NSConnection named %@. This connection is needed when cvs templates are enabled. If you continue then CVS Template support will be disabled.", 
            @"Continue", @"Quit", nil, CVLEditorClientConnectionName);
        if ( aChoice == NSAlertAlternateReturn ) {
            [NSApp terminate: nil];
        }
        
        cvlEditorClientConnection = nil;
        [theUserDefaults setBool:NO forKey:@"UseCvsTemplates"];
    }
    else
        [cvlEditorClientConnection retain];
    
    // Check the path to cvlEditor.
    (void)[self pathToCVLEditor];

    return self;
} // init


-(void)dealloc
{
  RELEASE(resultsRepository);
  RELEASE(savedWorkAreaViewersState);
  RELEASE(currentWorkAreaViewers);
  RELEASE(processRequests);
  RELEASE(globalSelection);
  
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  RELEASE(cvlEditorClientConnection);
  [super dealloc];
} // dealloc

- (void)awakeFromNib
{
    BOOL cvsEditorsAndWatchersEnabled = NO;
    
    SEN_ASSERT_NOT_NIL(fileMenu);
    SEN_ASSERT_NOT_NIL(startEditingMenuItem);
    SEN_ASSERT_NOT_NIL(cancelEditingMenuItem);
    SEN_ASSERT_NOT_NIL(startWatchingMenuItem);
    SEN_ASSERT_NOT_NIL(stopWatchingMenuItem);
    
    cvsEditorsAndWatchersEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"CvsEditorsAndWatchersEnabled"];
    
    if ( cvsEditorsAndWatchersEnabled == NO ) {
        //[fileMenu removeItem:startEditingMenuItem];
        //[fileMenu removeItem:cancelEditingMenuItem];
        //[fileMenu removeItem:startWatchingMenuItem];
        //[fileMenu removeItem:stopWatchingMenuItem];
    }
}

- (IBAction) openModule:(id)sender
{
    WorkAreaViewer *aViewer = nil;
    NSString *aPath = nil;
    NSOpenPanel	*panel= [NSOpenPanel openPanel];
    int			value = 0;

    [panel setCanChooseDirectories:YES];
    [panel setTitle:@"Choose"];
    [panel setAllowsMultipleSelection:NO];
    value = [panel runModalForTypes:nil];		// all types

    if (value == NSOKButton) {
        aPath =[[panel filenames] objectAtIndex:0];
        if ( isNotEmpty(aPath) ) {
            aViewer = [self viewerForPath:aPath];
            [self showViewer:aViewer];
        }
    }
} // openModule:

- (void) showViewer:(WorkAreaViewer *)aWorkAreaViewer
    /*" This method displays the workarea viewer in aWorkAreaViewer in a window. Before
        it does this it checks to see if this workarea has had it state saved in
        a file. It is does then the viewer is displayed using this state. This
        file is located at ~/Library/Application Support/CVL/Paths.plist.
    "*/
{
    NSDictionary* aWorkAreaViewerDict = nil;
    NSString *aPath = nil;
    
    if ( aWorkAreaViewer == nil ) return;
    
    aPath = [aWorkAreaViewer rootPath];
    aWorkAreaViewerDict = [savedWorkAreaViewersState objectForKey:aPath];
    if ( isNotEmpty(aWorkAreaViewerDict ) ) {
        [aWorkAreaViewer showWindowWithDictionary:aWorkAreaViewerDict];
    } else {
        [aWorkAreaViewer show:self];
    }
}

- (id) viewerForPath:(NSString *)aPath
{
    WorkAreaViewer	*aWorkAreaViewer = [currentWorkAreaViewers objectForKey:aPath];
    
    if(!aWorkAreaViewer){
        aWorkAreaViewer = [WorkAreaViewer viewerForPath:aPath];
        [currentWorkAreaViewers setObject:aWorkAreaViewer forKey:aPath];
    }
    return aWorkAreaViewer;
}

- doRepositoryLogin:sender
{
    [[CvsLoginRequest cvsLoginRequest] schedule];
    return self;
}

- (WorkAreaViewer *)viewerWithRootFile:(CVLFile *)aCVLFile
{
    NSEnumerator    *viewerEnumerator = nil;
    WorkAreaViewer  *aWorkAreaViewer = nil;
    
    viewerEnumerator=[currentWorkAreaViewers objectEnumerator];
    while ( (aWorkAreaViewer = [viewerEnumerator nextObject]) ) {
        if ( aCVLFile == [aWorkAreaViewer rootFile] ) {
            return aWorkAreaViewer;
        }
    }
    return nil;
}

- (WorkAreaViewer *) currentViewerShowingFile:(CVLFile *)aFile
{
    id viewerEnumerator;
    WorkAreaViewer *aWorkAreaViewer;

    viewerEnumerator=[currentWorkAreaViewers objectEnumerator];

    while ( (aWorkAreaViewer=[viewerEnumerator nextObject]) ) {
        if ([aFile isDescendantOf:[aWorkAreaViewer rootFile]]) {
            return aWorkAreaViewer;
        }
    }

    return nil;
}

- (WorkAreaViewer *)viewerShowingFile:(CVLFile *)aFile
{
    WorkAreaViewer *aWorkAreaViewer = [self currentViewerShowingFile:aFile];
	
    if(!aWorkAreaViewer)
        aWorkAreaViewer = [self newViewerShowingFile:aFile];

    return aWorkAreaViewer;
}

- (WorkAreaViewer *)newViewerShowingFile:(CVLFile *)aFile
{
    CVLFile *openedFile;

#if 0
    if (![aFile isLeaf]) {
        openedFile=aFile;
    } else {
        openedFile=[aFile parent];
    }
#else
    if (![aFile isLeaf]) {
        openedFile=aFile;
    } else {
        // We can't always trust isLeaf, because returned status is wrong if file
        // has never been loaded earlier (no up-to-date repository, thus no loadedChildren,
        // thus considered as leaf!)
        // This test should work in most (if not all) cases
        if([[NSFileManager defaultManager] senDirectoryExistsAtPath:[aFile path]] && ![[[aFile parent] repository] isWrapper:[aFile path]])
            openedFile=aFile;
        else
            openedFile=[aFile parent];
    }
#endif

    return [self viewerForPath:[openedFile path]];
}

- (SenSelection *)globalSelection
{
    return globalSelection;
}

- (void) checkLocalCvsWrappersFile
	/*" This method checks to see if there is a .cvswrappers file in the home 
		directory. If there is then an alert panel is displayed to the user 
		suggesting they delete it and instead check the checkbox labeled 
		\"Override the .cvswrappers file...\" in preferences if they have not 
		already done so.
	"*/
{
	NSString *theCVSWrappersPath = nil;
	NSString *theCurrentUsersHomeDirectory = nil;
	NSFileManager *fileManager = nil;
	NSUserDefaults *theUserDefaults = nil;
    int aChoice = NSAlertDefaultReturn;
	BOOL doesFileExist = NO;
	BOOL overrideCvsWrappersFileInHomeDirectory = NO;
	BOOL doNotShowAgainFirstInstance = NO;
	BOOL doNotShowAgainSecondInstance = NO;
	
	fileManager = [NSFileManager defaultManager];	
	theCurrentUsersHomeDirectory = NSHomeDirectory();
	theCVSWrappersPath = [theCurrentUsersHomeDirectory 
								stringByAppendingPathComponent:@".cvswrappers"];
	doesFileExist = [fileManager senFileExistsAtPath:theCVSWrappersPath];
	if ( doesFileExist == YES ) {
		theUserDefaults = [NSUserDefaults standardUserDefaults];	
		overrideCvsWrappersFileInHomeDirectory = [theUserDefaults 
						boolForKey:@"OverrideCvsWrappersFileInHomeDirectory"];
		if ( overrideCvsWrappersFileInHomeDirectory == YES ) {
			doNotShowAgainFirstInstance = [theUserDefaults 
						boolForKey:@"DoNotShowAgainFirstInstance"];
			if ( doNotShowAgainFirstInstance == YES ) return;
			aChoice = NSRunInformationalAlertPanel(@"CVL Wrapper Warning", 
											   @"You have a .cvswrapper file in your home directory. In CVL Preferences you have checked the checkbox labeled \"Override the .cvswrappers file...\". Therefore the .cvswrapper file in your home directory is not used except when you are adding existing remote repositories to CVL. When adding remote repositories to CVL it is likely that CVS will not work properly because it will use your home directory version of .cvswrapper instead of what is in the remote repository. It is recommended that you delete the .cvswrapper file from your home directory.",
				   @"OK", @"Do Not Show Again", nil);		
			if ( aChoice == NSAlertAlternateReturn ) {
				[theUserDefaults setBool:YES forKey:@"DoNotShowAgainFirstInstance"];
				[theUserDefaults synchronize];
            }			
		} else {
			doNotShowAgainSecondInstance = [theUserDefaults 
						boolForKey:@"DoNotShowAgainSecondInstance"];
			if ( doNotShowAgainSecondInstance == YES ) return;
			aChoice = NSRunInformationalAlertPanel(@"CVL Wrapper Warning", 
								  @"You have a .cvswrapper file in your home directory. If you use CVS Wrappers it is recommended that you go to CVL Preferences > General tab. Check the checkbox labeled \"Override the .cvswrappers file...\". Then delete the .cvswrapper file from your home directory. Otherwise when adding remote repositories to CVL it is likely that CVS will not work properly because it will use your home directory version of .cvswrapper instead of what is in the remote repository.",
				   @"OK", @"Do Not Show Again", nil);		
			if ( aChoice == NSAlertAlternateReturn ) {
				[theUserDefaults setBool:YES forKey:@"DoNotShowAgainSecondInstance"];
				[theUserDefaults synchronize];
            }						
		}
	}
}

- (void) anyRequestCompleted:(NSNotification *)notification
{
    NSArray	*modifiedFiles = [[notification userInfo] objectForKey:@"ModifiedFiles"];

    if([modifiedFiles count] > 0){
        NSEnumerator	*anEnum = [modifiedFiles objectEnumerator];
        NSString		*aPath;

        while ((aPath = [anEnum nextObject]) ) {
            [[NSWorkspace sharedWorkspace] noteFileSystemChanged:aPath];
        }
    }
}

- (void)preferencesChanged:(NSNotification *)aNotification
    /*" This method checks to see if the long running process alert is activated.
        This depends on several user defaults. So we do it here only once and
        set the boolean instance variable named "isLongRunningProcessAlertActivated"
        to indicate this requirement for this class. This saves us the cpu cycles
        to calculate this requirement each time a request is processed. See the 
        method -checkForEndOfProcess: where this is used.
    "*/
{    
    NSUserDefaults *theUserDefaults = nil;
    NSString *anAlertTimeIntervalString = nil;
    NSTimeInterval theAlertTimeInterval = 0.0;
    
    isLongRunningProcessAlertActivated = NO;

    theUserDefaults = [NSUserDefaults standardUserDefaults];
    
    anAlertTimeIntervalString = [theUserDefaults objectForKey:@"AlertTimeInterval"];
    theAlertTimeInterval = [anAlertTimeIntervalString doubleValue];    
    if ( theAlertTimeInterval > 0.0 ) {        
        if([theUserDefaults boolForKey:@"AlertTimeBeep"]) {
            isLongRunningProcessAlertActivated = YES;
        }   
        if([theUserDefaults boolForKey:@"AlertTimeDisplay"]) {            
            isLongRunningProcessAlertActivated = YES;
        }   
    }
    
    // Check the path to cvlEditor.
    (void)[self pathToCVLEditor];
}

- (NSString *)pathToCVLEditor
    /*" This method returns the absolute pathname to the CVL Editor that is used
        to implement the template function for this application. If the user does
        not have "UseCvsTemplates" preference set then this method will return
        nil. Also if the pathname has any spaces in it then this method will 
        warn the user that such a path cannot be passed to CVS and if the user
        wish to continue then CVS template use will be disable and nil will be
        returned from this method. An exception will be raised if the pathname
        itself is nil or empty.
    "*/
{
    NSString *thePathToCVLEditor = nil;
    NSString *theStdPathToCVLEditor = nil;
    NSRange   searchRange;
    NSUserDefaults *theUserDefaults = nil;
    int aChoice = NSAlertDefaultReturn;

    theUserDefaults = [NSUserDefaults standardUserDefaults];
    
    if( [theUserDefaults boolForKey:@"UseCvsTemplates"] == YES ) {        
        
        thePathToCVLEditor = [[NSBundle mainBundle] pathForAuxiliaryExecutable:@"cvlEditor"];
        SEN_ASSERT_NOT_EMPTY(thePathToCVLEditor);
        theStdPathToCVLEditor = [thePathToCVLEditor stringByStandardizingPath];
        SEN_ASSERT_NOT_EMPTY(theStdPathToCVLEditor);
        searchRange = [theStdPathToCVLEditor rangeOfString:@" "];
        if ( searchRange.length > 0 ) {
            aChoice = NSRunAlertPanel(@"CVL Editor", 
                                      @"The path to the CVL Editor contains spaces. Unfortunally CVS will not handle a path to this editor that contains spaces. If you continue then CVS Template support will be disabled. The path in question is \"%@\".",
                                      @"Continue", @"Quit", nil, theStdPathToCVLEditor); 
            if ( aChoice == NSAlertAlternateReturn ) {
                [NSApp terminate: nil];
            }
            theStdPathToCVLEditor = nil;
            [theUserDefaults setBool:NO forKey:@"UseCvsTemplates"];
        }
    }    
    return theStdPathToCVLEditor;
}

- (BOOL) isApplicationTerminating;
    /*" This a get method for the instance variable named 
        isApplicationTerminating. This variable indicates whether or not the
        method -applicationWillTerminate: has been called.
    "*/
{
    return isApplicationTerminating;
}

- (void) openInTemporaryDirectory:(NSString *)aPath withVersion:(NSString *)aVersion orDateString:(NSString *)aDateString withHead:(BOOL)useHead
    /*" This method will copy the specified version of the workarea file 
        specified in the argument aPath into the temporary directory and then 
        open it. The argument aPath is the path to the file in the workarea. 
        This is the file to be opened. Using either aVersion or aDateString, but 
        not both, to select the version to be opened.
    "*/
{
    CVLFile         *aCVLFile = nil;
    NSString        *aFilename = nil;
    NSString        *aTmpFilename = nil;
    NSString        *aTmpDirectoryName = nil;
    CvsRequest		*aCvsUpdateRequest = nil;
    NSString        *targetDirectory = nil;
    NSString        *aTmpPathName = nil;
    id              aTarget = nil;
    SelectorRequest *anOpenRequest = nil;
    NSArray         *anArrayOfFiles = nil;
    NSString        *aParentPath = nil;
	NSArray			*temporaryPath = nil;

    aFilename = [aPath lastPathComponent];
    aParentPath = [aPath stringByDeletingLastPathComponent];
    aCVLFile = (CVLFile *)[CVLFile treeAtPath:aPath];
    
    targetDirectory = NSTemporaryDirectory();
    SEN_ASSERT_NOT_EMPTY(targetDirectory);
    if ( isNotEmpty(aVersion) ) {
        aTmpFilename = [aCVLFile filenameForRevision:aVersion];
    } else if ( isNotEmpty(aDateString) ) {
        aTmpFilename = [aCVLFile filenameForDate:aDateString];
    } else {
        aTmpFilename = [aCVLFile name];
    }
	temporaryPath = [NSArray arrayWithObjects:
		NSTemporaryDirectory(),
		@"CVL",
		nil];
	aTmpPathName =  [NSString pathWithComponents:temporaryPath];
	aTmpDirectoryName = [NSString uniqueFilenameWithPrefix:@"tmp" 
									   inDirectory:aTmpPathName];
	if ( aTmpDirectoryName == nil ) {
		(void)NSRunAlertPanel(@"CVL File Error", 
							  @"Sorry, could not create a temporary directory \"tmp\" in the directory \"%@\". Tried 10,000 times and failed. Giving up.",
							  nil, nil, nil, aTmpDirectoryName);
		return;
	}
	
    aTmpPathName = [aTmpPathName stringByAppendingPathComponent:aTmpDirectoryName];
    aTmpPathName = [aTmpPathName stringByAppendingPathComponent:aTmpFilename];

	// Developer Note: For some unknown reason the pipe feature no longer works
	// for cvs wrapper files from pserver repositories. Hence we are using a 
	// checkout request to a temporary directory for all cvs wrapper files,
	// even the ones from other types of repositories. Just to be consistent.
	// William Swats -- 16-Dec-2004
	if ( [aCVLFile isRealWrapper] == YES ) {
		aCvsUpdateRequest = [CvsCheckoutRequest cvsUpdateRequestForFile:aFilename
															   inPath:aParentPath 
															 revision:aVersion 
																 date:aDateString
											  removesStickyAttributes:useHead
															   toFile:aTmpPathName];
	// End of fix for wrapper files from pserver repositories.
	} else {
		aCvsUpdateRequest = [CvsUpdateRequest cvsUpdateRequestForFile:aFilename
															   inPath:aParentPath 
															 revision:aVersion 
																 date:aDateString
											  removesStickyAttributes:useHead
															   toFile:aTmpPathName];
	}
    aTarget = [[NSApplication sharedApplication] 
                                targetForAction:@selector(doOpenFilesInWS:)];
    
    if( aTarget != nil ){
        anArrayOfFiles = [NSArray arrayWithObject:aTmpPathName];
        anOpenRequest = [SelectorRequest requestWithTarget:aTarget 
                                                  selector:@selector(doOpenFilesInWS:) 
                                                  argument:anArrayOfFiles];
        SEN_ASSERT_NOT_NIL(anOpenRequest);
        [anOpenRequest setCanBeCancelled:YES];
        
        [anOpenRequest addPrecedingRequest:aCvsUpdateRequest];
        [anOpenRequest schedule];
    } else {
        [aCvsUpdateRequest schedule];
    }        
}

- (int) save:(NSString *)aPath withVersion:(NSString *)aVersion orDateString:(NSString *)aDateString withHead:(BOOL)useHead
    /*" This method will save a copy the specified version of the workarea file
        specified in the argument aPath. This is the file to be opened. Use
        either aVersion or aDateString, but not both, to select the version to 
        be opened.
    "*/
{
    CVLFile         *aCVLFile = nil;
    NSString        *aFilename = nil;
    NSString        *aTmpFilename = nil;
    CvsRequest		*aCvsUpdateRequest = nil;
    NSString        *targetDirectory = nil;
    NSString        *aParentPath = nil;
    NSString        *theTargetFilename = nil;
    NSSavePanel     *theSavePanel = nil;
    int             savePanelResultCode = 0;
    
    aFilename = [aPath lastPathComponent];
    aParentPath = [aPath stringByDeletingLastPathComponent];
    aCVLFile = (CVLFile *)[CVLFile treeAtPath:aPath];
    
    targetDirectory = NSTemporaryDirectory();
    SEN_ASSERT_NOT_EMPTY(targetDirectory);
    if ( isNotEmpty(aVersion) ) {
        aTmpFilename = [aCVLFile filenameForRevision:aVersion];
    } else if ( isNotEmpty(aDateString) ) {
        aTmpFilename = [aCVLFile filenameForDate:aDateString];
    } else {
        aTmpFilename = [aCVLFile name];
    }
    
    theSavePanel = [NSSavePanel savePanel];
    savePanelResultCode = [theSavePanel runModalForDirectory:nil
                                                        file:aTmpFilename];
    if ( savePanelResultCode == NSOKButton ) {
        theTargetFilename = [theSavePanel filename];
        SEN_ASSERT_NOT_EMPTY(theTargetFilename);
        		
		// Developer Note: For some unknown reason the pipe feature no longer works
		// for cvs wrapper files from pserver repositories. Hence we are using a 
		// checkout request to a temporary directory for all cvs wrapper files,
		// even the ones from other types of repositories. Just to be consistent.
		// William Swats -- 16-Dec-2004
		if ( [aCVLFile isRealWrapper] == YES ) {
			aCvsUpdateRequest = [CvsCheckoutRequest 
										cvsUpdateRequestForFile:aFilename
														 inPath:aParentPath 
													   revision:aVersion 
														   date:aDateString
										removesStickyAttributes:useHead
														 toFile:theTargetFilename];
		// End of fix for wrapper files from pserver repositories.
		} else {
			aCvsUpdateRequest = [CvsUpdateRequest 
                                cvsUpdateRequestForFile:aFilename
                                                 inPath:aParentPath 
                                               revision:aVersion 
                                                   date:aDateString
                                removesStickyAttributes:useHead
                                                 toFile:theTargetFilename];			
		}
        [aCvsUpdateRequest schedule];
    }
    return savePanelResultCode;
}


@end

//-------------------------------------------------------------------------------------

@implementation CVLDelegate(RequestObserver)


- (void) requestStateChanged: (NSNotification *)notification
{
#ifdef JA_PATCH
    Request *request=[notification object];

    if ([[request currentState] valueForKey:@"startsCvs"]) {
        if (!(CvsRequest *)[request isQuiet])
          {
            [[CVLConsoleController sharedConsoleController] output: [(CvsRequest *)request shortDescription] bold: YES];
          }
    }
#else
    if ([[notification object] state]==STATE_RUNNING) {
        if ([[notification object] isKindOfClass: [CvsRequest class]])
        {
            CvsRequest *request=[notification object];

            if (![request isQuiet])
            {
                [[CVLConsoleController sharedConsoleController] output: [request shortDescription] bold: YES];
            }
        }
    }
#endif
}

- (void)checkForEndOfProcess:(NSNotification *)aNotification
    /*" This is a "RequestStateChanged" notification method. It is being used
        solely for the purpose of sounding a beep and-or putting up an alert
        for long running processes. It is sed with the preferences named
        "AlertTimeBeep", "AlertTimeDisplay" and "AlertTimeInterval".
    "*/
{
    Request	*aRequest = [aNotification object];
    
    // Check to see if we need to check for the end of the process. If not then
    // just return. NB: we are only doing this check so that we can put an alert
    // or sound a beep to the user when a long running process ends.
    if ( isLongRunningProcessAlertActivated == NO ) return;
    
    if( [processRequests containsObject:aRequest] == NO ) {
        if ( (processEnded == YES) && ([processRequests count] == 0) ) {
            startTime = [NSDate timeIntervalSinceReferenceDate];
            processStarted = YES;
        }
        [processRequests addObject:aRequest];
    }
    
    if( [aRequest state] == STATE_ENDED ) {
        [processRequests removeObject:aRequest];
        if ( (processStarted == YES) && ([processRequests count] == 0) ) {
            [self performSelector:@selector(checkAgainForEndOfProcess:) 
                       withObject:aNotification 
                       afterDelay:1.0];
            processEnded = NO;
        }        
    }
}

- (void)checkAgainForEndOfProcess:(NSNotification *)aNotification
    /*" This method is used to delay the activation of displaying an alert
        for a long running process for one second. This is done so that if there
        are other tasks that get scheduled for processing within one second then
        these new tasks are assumed to be part of the current process and hence
        the displaying of an alert is aborted until conditions are again met in
        the method -checkForEndOfProcess:.
    "*/
{    
    if ( (processStarted == YES) && ([processRequests count] == 0) ) {
        [self activateLongRunningProcessAlert];
        processStarted = NO;
        processEnded = YES;
    }        
}

- (void)activateLongRunningProcessAlert
    /*" This method checks the user preferences to see which of the alerts, if
        any, to activate. The alerts are either a system beep and-or an alert
        panel.
    "*/
{    
    NSUserDefaults *theUserDefaults = nil;
    NSString *anAlertTimeIntervalString = nil;
    NSDictionary *aUserInfo = nil;
    NSNumber *totalTimeObject = nil;
    NSTimeInterval theAlertTimeInterval = 0.0;
    NSTimeInterval totalTime = 0.0;
    
    theUserDefaults = [NSUserDefaults standardUserDefaults];
    
    anAlertTimeIntervalString = [theUserDefaults objectForKey:@"AlertTimeInterval"];
    theAlertTimeInterval = [anAlertTimeIntervalString doubleValue];
    endTime = [NSDate timeIntervalSinceReferenceDate];
    totalTime = endTime - startTime;

    if ( totalTime > theAlertTimeInterval ) {        
        if([theUserDefaults boolForKey:@"AlertTimeBeep"]) {
            NSBeep();
        }   
        if([theUserDefaults boolForKey:@"AlertTimeDisplay"]) {            
            totalTimeObject = [NSNumber numberWithDouble:totalTime];
            aUserInfo = [NSDictionary dictionaryWithObject:totalTimeObject
                                                    forKey:@"TotalTime"];
            [self performSelector:@selector(showAlertTimeDisplay:) 
                       withObject:aUserInfo 
                       afterDelay:2.0];
        }   
    }
}

- (void)showAlertTimeDisplay:(NSDictionary *)aUserInfo
    /*" This method displays an alert panel when a request task time exceeds the
        perference named AlertTimeInterval. This alert has been wrapped in this
        method so that it can be called with a delay. We want to delay this
        alert so that it does not stop the processing of other events.
    "*/
{
    NSNumber *totalTimeObject = nil;
    NSTimeInterval totalTime = 0.0;
    
    SEN_ASSERT_NOT_EMPTY(aUserInfo);
    
    totalTimeObject = [aUserInfo objectForKey:@"TotalTime"];
    SEN_ASSERT_NOT_NIL(totalTimeObject);
    SEN_ASSERT_CONDITION( [totalTimeObject respondsToSelector:@selector(doubleValue)] );
    
    totalTime = [totalTimeObject doubleValue];
    
    (void)NSRunAlertPanel(@"Process Time", 
                          @"The last process took %f seconds.",
                          nil, nil, nil, totalTime);    
}

- (void) requestReceivedData:(NSNotification *)notification
{
    if ([[notification object] isKindOfClass: [CvsRequest class]])
    {
        CvsRequest *request=[notification object];
        NSString *newBufPart=[[notification userInfo] objectForKey:@"RequestNewData"];

        if ([[[notification userInfo] objectForKey:@"ErrorStream"] isEqual:@"YES"]) {
            [[CVLConsoleController sharedConsoleController] outputError: newBufPart];
        } else if (![(CvsRequest *)request isQuiet]) {
            [[CVLConsoleController sharedConsoleController] output: newBufPart];
        }
    }
    return;
}

- (void) requestCompleted:(NSNotification *)aNotification
    /*" This method creates and displays a new workarea viewer using the destination path
        of the request found in aNotification. It is assumed that this request
        is of the class CvsCheckoutRequest or a subclass; but we check to be 
        sure. We only create this new viewer if the the request was successful.
    "*/
{ 
    Request         *aRequest = nil;
    WorkAreaViewer  *aWorkAreaViewer = nil;
    NSString        *aPath = nil;

    aRequest=[aNotification object];
    if ( [aRequest isKindOfClass:[CvsCheckoutRequest class]] == NO ) return;
    if ([aRequest succeeded]) {
        aPath =[(CvsCheckoutRequest *)aRequest destinationPath];
        if ( isNotEmpty(aPath) ) {
            aWorkAreaViewer = [self viewerForPath:aPath];
            [self showViewer:aWorkAreaViewer];
        }
    }    
    [[NSNotificationCenter defaultCenter] removeObserver:self 
                                                    name:nil
                                                  object:aRequest];
}


@end


//-------------------------------------------------------------------------------------

@implementation CVLDelegate(ApplicationDelegate)


- (NSDictionary *) existingDirsFrom:(NSArray *)aWorkAreaViewersStateArray
    /*" The aWorkAreaViewersStateArray is an array of dictionaries each of which represents 
        the state of a workarea viewer. This method examines the path of the 
        workarea of each of these viewers and if it still exists then this 
        state's dictionary is returned in another dictionary. A value in this 
        returned dictionary is the state dictionary of the workarea viewer and 
        the key is the path to this workarea viewer.
    "*/
{
    NSMutableDictionary* result = nil;
    NSEnumerator *anEnumerator = nil;	
    NSDictionary *aStateDictionary = nil;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *aPath = nil;
    unsigned int aCount = 0;
    
    if ( isNotEmpty(aWorkAreaViewersStateArray) ) {
        aCount = [aWorkAreaViewersStateArray count];
        result = [NSMutableDictionary dictionaryWithCapacity:aCount];
        anEnumerator = [aWorkAreaViewersStateArray objectEnumerator];	
        while ( (aStateDictionary = [anEnumerator nextObject]) ) {
            aPath = [aStateDictionary objectForKey: @"path"];
            if ( isNotEmpty(aPath) ) {
                if ( [fileManager senDirectoryExistsAtPath:aPath] )
                { // real directory, keep it
                    [result setObject:aStateDictionary forKey:aPath];
                }            
            }
        }        
    }
    return result;
}


- (void) registerToAvatarNotifications
{
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                        selector:@selector (fileDidSave:)
                                                            name:@"FileDidSave"
                                                          object:@"CVLAvatar"
                                              suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];

}

- (void) fileDidSave:(NSNotification *) notification
{
    NSString *path = [[notification userInfo] objectForKey:@"Path"];
    [(CVLFile *)[CVLFile treeAtPath:path] invalidateAll];
}

- (void) delayedOpenCurrentWorkAreaViewersFrom:(NSDictionary *)aDictionary
{
    NSArray *aWorkAreaViewersStateArray = nil;
    
    aWorkAreaViewersStateArray = [aDictionary allValues];
    [self openWorkAreaViewersFrom:aWorkAreaViewersStateArray];
}

- (IBAction) showHelp:(id)sender
{
    if(![helpView readRTFDFromFile:[[NSBundle mainBundle] pathForResource:@"CVL" ofType:@"rtfd"]])
        NSBeep();
    else
        [[helpView window] makeKeyAndOrderFront:sender];
}

- (IBAction) showReleaseNotes:(id)sender
{
    NSString *aPath = nil;
    NSURL *theReleaseNotes = nil;
    BOOL wasOpened = NO;
    
    aPath = [[NSBundle mainBundle] pathForResource:@"ReleaseNotes" ofType:@"html"];
    if ( aPath == nil ) {
        (void)NSRunAlertPanel(@"CVL Release Notes", 
              @"Sorry, could not find the CVL Release Notes in the application bundle.",
              nil, nil, nil);            
    }
    theReleaseNotes = [[NSURL alloc] initFileURLWithPath:aPath];
    if ( theReleaseNotes == nil ) {
        (void)NSRunAlertPanel(@"CVL Release Notes", 
                              @"Sorry, the CVL Release Notes at path \"%@\" does not seem to be a valid URL.",
                              nil, nil, nil, aPath);            
    }    
    wasOpened = [[NSWorkspace sharedWorkspace] openURL:theReleaseNotes];
    if ( wasOpened == NO ) {
        (void)NSRunAlertPanel(@"CVL Release Notes", 
                              @"Sorry, could not open the CVL Release Notes at the path \"%@\".",
                              nil, nil, nil, aPath);            
    }        
}

- (IBAction) showLicense:(id)sender
{
    NSString *aPath = nil;
    NSURL *theLicense = nil;
    BOOL wasOpened = NO;
    
    aPath = [[NSBundle mainBundle] pathForResource:@"OpenSourceLicense" ofType:@"html"];
    if ( aPath == nil ) {
        (void)NSRunAlertPanel(@"CVL License", 
                              @"Sorry, could not find the CVL License in the application bundle.",
                              nil, nil, nil);            
    }
    theLicense = [[NSURL alloc] initFileURLWithPath:aPath];
    if ( theLicense == nil ) {
        (void)NSRunAlertPanel(@"CVL License", 
                              @"Sorry, the CVL License at path \"%@\" does not seem to be a valid URL.",
                              nil, nil, nil, aPath);            
    }    
    wasOpened = [[NSWorkspace sharedWorkspace] openURL:theLicense];
    if ( wasOpened == NO ) {
        (void)NSRunAlertPanel(@"CVL License", 
                              @"Sorry, could not open the CVL License at the path \"%@\".",
                              nil, nil, nil, aPath);            
    }        
}

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
    NSUncaughtExceptionHandler *anUncaughtExceptionHandler = NULL;
    //NSException *aTestException = nil;
    
    anUncaughtExceptionHandler =(NSUncaughtExceptionHandler *)CVLUncaughtExceptionHandler;
    [[NSExceptionHandler defaultExceptionHandler] setExceptionHandlingMask:127];
    NSSetUncaughtExceptionHandler(anUncaughtExceptionHandler);
    
    [[NSExceptionHandler defaultExceptionHandler] setDelegate:self];
    
    //aTestException = [NSException exceptionWithName:@"aTestException" reason:@"No reason" userInfo:nil];
    //[aTestException raise];
}


- (BOOL)exceptionHandler:(NSExceptionHandler *)sender shouldLogException:(NSException *)exception mask:(unsigned int)aMask
    // mask is NSLog<exception type>Mask, exception's userInfo has stack trace for key NSStackTraceKey
{
    CVLUncaughtExceptionHandler(exception);
    return YES;
}

- (void) applicationDidFinishLaunching:(NSNotification *)notUsed
{
    NSUserDefaults *defaults=[NSUserDefaults standardUserDefaults];
    
    NS_DURING
        // If CVL is launched for the first time, let's open the help file!
        if(![[defaults persistentDomainForName:@"ch.sente.CVL"] count])
            [self showHelp:nil];

        // services stuff
        [NSApp setServicesProvider: self]; //: [NSArray arrayWithObjects: NSFilenamesPboardType, NSStringPboardType, nil] returnTypes: nil];

        [[NSApp mainMenu] setAutoenablesItems: YES];

        if ([defaults boolForKey:@"ShowInspector"]) {
            [self showInspectorPanel: self];
        }
        if ([defaults boolForKey:@"ShowProgressPanel"]) {
            [self showProgressPanel: self];
        }
        if ([[CVLConsoleController sharedConsoleController] showConsoleAtStartup]) {
            [[CVLConsoleController sharedConsoleController] showWindow: self];
        }

        if ([defaults boolForKey:@"ShowRepositoryViewer"]) {
            [[RepositoryViewer sharedRepositoryViewer] showWindow:self];
        }

//        [self openWorkAreaViewersFrom:savedWorkAreaViewersState];
        if ([defaults boolForKey:@"ShowBrowsers"])
            // Thank you to Tom Hageman <trh@xs4all.nl> for this feature
            [self performSelector:@selector(delayedOpenCurrentWorkAreaViewersFrom:) 
                       withObject:savedWorkAreaViewersState afterDelay:0];
        [ProgressPanelController sharedProgressPanelController];	// to force it getting notifs
        [CVLInspectorManager sharedInspector];

        [self registerToAvatarNotifications];
		[self checkLocalCvsWrappersFile];
        SEN_LOG_CHECKPOINT();
    NS_HANDLER
        NSRunCriticalAlertPanel([localException name], [localException reason], @"Quit", nil, nil);
        [NSApp terminate: nil];
    NS_ENDHANDLER
}


- (void) applicationWillTerminate:(NSNotification *)notUsed
{
	NSUserDefaults *theUserDefaults = nil;

    isApplicationTerminating = YES;
    (void)[self saveViewerState];
    [cvlEditorClientConnection invalidate];
	theUserDefaults = [NSUserDefaults standardUserDefaults];    
	[theUserDefaults synchronize];
}

- (BOOL) saveViewerState
    /*" This method gets the state of all the current workarea viewers plus the
        state of the workarea viewers that have been saved in the file system and 
        writes the result back out to the file system. Any viewer states that 
        represent workareas that no longer exists are discarded. The file that 
        is written is located at ~/Library/Application Support/CVL/Paths.plist.
        If this file cannot be written then an alert panel is displayed to the 
        user.
    "*/
{
    // FIXME (stephane) We should discard ALL entries before writing new ones!
    // Original implementation worked like this.
    // There is no way for user to remove entries manually, but the entry list 
    // grows over time, making this option unusable.
    NSString *theResourceFilename = nil;
    NSArray *theCurrentWorkAreaViewers = nil;
    NSArray *theWorkAreaViewersStateArray = nil;
    NSDictionary *theWorkAreaViewersStateDictionary = nil;
    BOOL successful = NO;
    
    theResourceFilename = [[self class] resourceFilename];
    theCurrentWorkAreaViewers = [currentWorkAreaViewers allValues];
    theWorkAreaViewersStateArray = [self savedWorkAreaViewersStateFrom:theCurrentWorkAreaViewers];
    theWorkAreaViewersStateDictionary = [NSDictionary 
                         dictionaryWithObject:theWorkAreaViewersStateArray 
                                       forKey:BROWSERS_KEY];
    successful = [theWorkAreaViewersStateDictionary writeToFile:theResourceFilename 
                                              atomically: NO];
    if ( successful == NO ) {	// try to create nonexistent path
        NSFileManager *fileManager = nil;
        NSString *theResourceDirectory = nil;
        
        fileManager = [NSFileManager defaultManager];
        theResourceDirectory = [theResourceFilename stringByDeletingLastPathComponent];
        successful = [fileManager createAllDirectoriesAtPath:theResourceDirectory
                                                  attributes:nil];
        if ( successful == YES ) {
            successful = [theWorkAreaViewersStateDictionary 
                                writeToFile:theResourceFilename 
                                 atomically: NO];
        }
        if ( successful == NO ) {
            (void)NSRunAlertPanel(@"CVL File System Error", 
                  @"Was not able to save the state of the CVL workarea at path \"%@\" due to some file system error.",
                  nil, nil, nil, theResourceFilename);
        }        
    } 
    return successful;
}

- (IBAction) showConsole:(id)sender
{
    [[CVLConsoleController sharedConsoleController] showWindow:sender];
}

- (IBAction) clearConsole:(id)sender
{
    [[CVLConsoleController sharedConsoleController] clearText:sender];
}

- (IBAction) showPreferences:(id)sender
{
    [[[SenPanelFactory sharedPanelFactory] handleOfPanelWithName:@"Preferences"] show:sender];
}

- (IBAction) showInspectorPanel:(id)sender
{
    [[CVLInspectorManager sharedInspector] showWindow:sender];
}

- (IBAction) showRepositoryViewer:(id)sender
{
    [[RepositoryViewer sharedRepositoryViewer] showWindow:sender];
}

- (IBAction) showProgressPanel:(id)sender
{
    [[ProgressPanelController sharedProgressPanelController] showWindow:sender];
}

- (IBAction) showInfoPanel:(id)sender
{
  [[InfoController new] showPanel];
}

- (IBAction) showCvsInfoPanel:(id)sender
{
    [[InfoController new] showCvsPanel];
}

- (IBAction) showComparator:(id)sender
{
    [[Comparator sharedComparator] showWindow:sender];
}

- (void)pathSelected:(NSNotification *)notification
{
    NSArray *theSelectedPaths;
    
    theSelectedPaths=[notification object];
    [globalSelection setSelectedObjects:theSelectedPaths]; // to refactor to hlod files rather than paths
}

- (void)setActiveViewer:(id)aNewActiveViewer
    /*" This method sets the activeViewer. The activeViewer is either an
        instance of WorkAreaViewer or RepositoryViewer.

        See Also #activeViewer
    "*/
{
    if (aNewActiveViewer!=activeViewer) {        
        ASSIGN(activeViewer, aNewActiveViewer);
    }
}

- (id)activeViewer
    /*" This method returns the activeViewer. The activeViewer is either an
        instance of WorkAreaViewer or RepositoryViewer.

        See Also #setActiveViewer:
    "*/
{
    return activeViewer;
}

- (void) viewerDidBecomeKey: (NSNotification *) notification
{
    [self setActiveViewer:[notification object]];
}


- (void) viewerWillClose: (NSNotification *)notification
{
    NSArray	*keys = [currentWorkAreaViewers allKeysForObject:[notification object]];

    if ( isApplicationTerminating == NO ) {
        // When the application terminates, it closes all the windows, thus the
        // method -viewerWillClose: gets called. But we have already saved the
        // viewer state in the method -applicationWillTerminate:. So there is no 
        // need to do it here also.
        (void)[self saveViewerState];
    }
    [currentWorkAreaViewers removeObjectsForKeys:keys];
    [self setActiveViewer:nil];
}

- (void) openWorkAreaViewersFrom:(NSArray *)aWorkAreaViewersStateArray
    /*" This method gets and displays all of the workarea viewers who have a 
        state dictionary in the array aWorkAreaViewersStateArray and whose 
        "isDisplayed" state is equal to "YES".
    "*/
{
  NSEnumerator      *dictEnumerator = nil;
  NSDictionary      *aWorkAreaViewerDict = nil;
  WorkAreaViewer    *aWorkAreaViewer = nil;
  NSString          *aPath = nil;
  NSString          *isDisplayed = nil;

  dictEnumerator = [aWorkAreaViewersStateArray objectEnumerator];
  while((aWorkAreaViewerDict = [dictEnumerator nextObject])){
      id pool = [[NSAutoreleasePool alloc] init]; // [TRH] attempt to keep temporaries in check.

      isDisplayed = [aWorkAreaViewerDict objectForKey:@"isDisplayed"];
      // Note: If isDisplayed does not exists then this means we have
      // an old saved workarea state. The old state only saved those workareas
      // that were being displayed, hence if isDisplayed is nil then display
      // the workarea viewer.
      if ( (isDisplayed == nil) ||
           ([isDisplayed isEqualToString:@"YES"] == YES) ) {
          aPath = [aWorkAreaViewerDict objectForKey:@"path"];
          aWorkAreaViewer = [self viewerForPath:aPath];
          [aWorkAreaViewer showWindowWithDictionary:aWorkAreaViewerDict];          
      }
      [pool release];
  }
}


- (NSArray *) savedWorkAreaViewersStateFrom:(NSArray *)aWorkAreaViewersArray
    /*" This method returns in an array the state of all the current workarea 
        viewers plus the state of the workarea viewers that have been saved in 
        the file system less any viewer states that represent workareas that no
        longer exists.
    "*/
{
  NSArray           *theSavedWorkAreaViewersStateArray = nil;
  NSEnumerator      *anEnumerator = nil;
  WorkAreaViewer    *aWorkAreaViewer = nil;
  NSString          *aPath = nil;
  NSDictionary      *aStateDictionary = nil;

  SEN_ASSERT_NOT_NIL(savedWorkAreaViewersState);
  
  if ( isNotEmpty(aWorkAreaViewersArray) ) {
      anEnumerator = [aWorkAreaViewersArray objectEnumerator];
      while ( (aWorkAreaViewer = [anEnumerator nextObject]) ) {
          aPath = [aWorkAreaViewer rootPath];
          aStateDictionary = [aWorkAreaViewer stateDictionary];
          [savedWorkAreaViewersState setObject:aStateDictionary forKey:aPath];
      }      
  }
  theSavedWorkAreaViewersStateArray = [savedWorkAreaViewersState allValues];
  return theSavedWorkAreaViewersStateArray;
}

- (BOOL) application:(NSApplication *)sender openFile:(NSString *)filename
    /*" Sent directly by theApplication to the delegate. The method should open 
        the file filename, returning YES if the file is successfully opened, and
        NO otherwise. If the user started up the application by double-clicking
        a file, the delegate receives the application:openFile: message before
        receiving applicationDidFinishLaunching:. 
        (applicationWillFinishLaunching: is sent before application:openFile:.)
    "*/
{
    NSFileManager	*fileManager = nil;
    // Duplicates code of selectInCVL:userData:error: !!!
    NSSet           *requests = nil;
    BOOL            isDirectory = NO;

    // Let's check directory existence (if we use Recent.bundle, method can be called with yet unexistant filename)
    fileManager = [NSFileManager defaultManager];
    if(![fileManager senFileExistsAtPath:filename isDirectory:&isDirectory]){
        (void)NSRunAlertPanel(@"CVL", 
              @"The file or folder \"%@\" does not exist anymore in the file system. Cannot run CVL on it now.",
              nil, nil, nil, filename);    
        return NO;
    }

    if ( isDirectory == YES ) {
        CVLFile			*aFile = [CVLFile treeAtPath:filename];
        WorkAreaViewer	*aWorkAreaViewer = [self currentViewerShowingFile:aFile];

        if ( aWorkAreaViewer != nil ) {
            [aWorkAreaViewer selectFiles:[NSSet setWithObject:aFile]];
        } else {
            aWorkAreaViewer = [self newViewerShowingFile:aFile];
            [self showViewer:aWorkAreaViewer];
        }
    } else {
        requests = [CVLSelectingFilesRequest requestsForSelectionOfPaths:[NSArray arrayWithObject:filename]];
        [requests makeObjectsPerformSelector:@selector(schedule)];
    }

    return YES; // We don't need to check if directory contains a CVS directory
}

- (BOOL)fileManager:(NSFileManager *)fileManager shouldProceedAfterError:(NSDictionary *)errorInfo
	/*" The NSFileManager manager sends this message for each error it 
	encounters when copying, moving, removing, or linking files or 
	directories. The NSDictionary object errorInfo contains two or three 
		pieces of information (all NSStrings) related to the error:

	@"Path" The path related to the error (usually the source path)

	@"Error" A description of the error

	@"ToPath" The destination path (not all errors)

	Return YES if the operation (which is often continuous within a loop) 
	should proceed and NO if it should not; the Boolean value is passed back
		to the invoker of copyPath:toPath:handler:, movePath:toPath:handler:, 
   removeFileAtPath:handler:, or linkPath:toPath:handler:. If an error o
	ccurs and your handler has not implemented this method, the invoking 
	method automatically returns NO.

		The following implementation of fileManager:shouldProceedAfterError: 
	displays the error string in an alert dialog.
	"*/
{
	NSString *errorMsg = nil;
	NSString *sourcePath = nil;
	NSString *destinationPath = nil;
		
	errorMsg = [errorInfo objectForKey:@"Error"];
	sourcePath = [errorInfo objectForKey:@"Path"];
	destinationPath = [errorInfo objectForKey:@"ToPath"];
	if ( destinationPath != nil ) {
		(void)NSRunAlertPanel(@"CVL Application", 
							  @"File operation error: \"%@\" with source file: \"%@\" and destination file: \"%@\".", 
							  nil, nil, nil, 
							  errorMsg, sourcePath, destinationPath);
	} else {
		(void)NSRunAlertPanel(@"CVL Application",
							  @"File operation error: \"%@\" with file: \"%@\"", 
							  nil, nil, nil, errorMsg, sourcePath);
	}
	return NO;
}


@end

//-------------------------------------------------------------------------------------

@implementation CVLDelegate(ServicesDelegate)

- (void)selectInCVL:(NSPasteboard *)pboard
           userData:(NSString *)data
              error:(NSString **)error
{
    NSArray *pboardFilenames = nil;
    NSString *pboardFilename = nil;
    NSArray *types= [pboard types];
    NSSet *requests;
    NSMutableArray	*filenames;
    NSMutableArray	*removedFilenames;
    NSEnumerator	*anEnum;
    NSString		*aPath;
    CVLFile         *aFile = nil;
    NSString        *aDirectory = nil;
    NSFileManager	*fileManager = [NSFileManager defaultManager];
    unsigned int    aCount = 0;

    if ( ([types containsObject:NSFilenamesPboardType] == NO) &&
         ([types containsObject:NSStringPboardType] == NO) ) {
        *error = @"Could not select a file path, pasteboard would not give a filename type or a string type.";
        (void)NSRunAlertPanel(@"CVL Services Error", *error, nil, nil, nil);            
        return;
    }

    if ( [types containsObject:NSFilenamesPboardType] == YES ) {
        pboardFilenames = [pboard propertyListForType:NSFilenamesPboardType];
        if ( isNilOrEmpty(pboardFilenames) ) {
            *error = @"Could not select a file path, pasteboard would not provide data for pasteboard type of filenames.";
            (void)NSRunAlertPanel(@"CVL Services Error", *error, nil, nil, nil);            
            return;
        }        
    } else if ( [types containsObject:NSStringPboardType] == YES ) {
        pboardFilename = [pboard propertyListForType:NSStringPboardType];
        if ( isNilOrEmpty(pboardFilename) ) {
            *error = @"Could not select a file path, pasteboard would not provide data for pasteboard type of string.";
            (void)NSRunAlertPanel(@"CVL Services Error", *error, nil, nil, nil);            
            return;
        } else {
            pboardFilenames = [NSArray arrayWithObject:pboardFilename];
        }
    }
    
    // Let's remove files/directories which do not exist in fileSystem
    filenames = [pboardFilenames mutableCopy];
    aCount = [filenames count]; // First time count.
    if ( aCount == 0 ) {
        *error = @"No filenames found on pasteboard.";
        (void)NSRunAlertPanel(@"CVL Services Error", *error, nil, nil, nil);            
        [filenames release];
        return;
    }
    
    removedFilenames = [NSMutableArray arrayWithCapacity:aCount];
    anEnum = [filenames objectEnumerator];
    while ( (aPath = [anEnum nextObject]) ) {
        if(![[NSFileManager defaultManager] senFileExistsAtPath:aPath]) {
            [removedFilenames addObject:aPath];
        }
    }
    [filenames removeObjectsInArray:removedFilenames];

    aCount = [filenames count]; // Recount the number of filenames.
    if( aCount == 0 ){
        *error = [NSString stringWithFormat:@"The path(s) selected do not exist in the file system. The paths selected are: \"%@\".", removedFilenames];
        (void)NSRunAlertPanel(@"CVL Services Error", *error, nil, nil, nil);            
        [filenames release];
        return;
    }

    anEnum = [filenames objectEnumerator];
    while ( (aPath = [anEnum nextObject]) ) {
        if ( [fileManager senDirectoryExistsAtPath:aPath] == YES ) {
            aDirectory = aPath;
        } else {
            aDirectory = [aPath stringByDeletingLastPathComponent];
        }
        if ( [CvsEntry doesDirectoryContainAnyCVSFiles:aDirectory]  == NO ) {
            // Also check parent directory in case this is a wrapper.
            aDirectory = [aDirectory stringByDeletingLastPathComponent];
            if ( [CvsEntry doesDirectoryContainAnyCVSFiles:aDirectory]  == NO ) {
                (void)NSRunAlertPanel(@"CVL Services Error", 
                                      @"The file \"%@\" is in a folder that does not contain any CVS data. CVL is ignoring this request.",
                                      nil, nil, nil, aPath);    
                [removedFilenames addObject:aPath];                
            }
        }
    }
    [filenames removeObjectsInArray:removedFilenames];
    aCount = [filenames count]; // Recount the number of filenames.
    if( aCount == 0 ){
        [filenames release];
        return;
    }
    
    [removedFilenames removeAllObjects]; // Start again with empty array.
    anEnum = [filenames objectEnumerator];
    while ( (aPath = [anEnum nextObject]) ) {        
        // See comment in -newViewerShowingFile:
        if([[NSFileManager defaultManager] senDirectoryExistsAtPath:aPath] && ![[[[CVLFile treeAtPath:aPath] parent] repository] isWrapper:aPath]){
            WorkAreaViewer	*aWorkAreaViewer;

            aFile = (CVLFile *)[CVLFile treeAtPath:aPath];
            aWorkAreaViewer= [self currentViewerShowingFile:aFile];

            if(!aWorkAreaViewer) {
                [self showViewer:[self newViewerShowingFile:aFile]];
            } else {
                [aWorkAreaViewer selectFiles:[NSSet setWithObject:aFile]];
            }
            [removedFilenames addObject:aPath];
        }
    }
    [filenames removeObjectsInArray:removedFilenames];

    aCount = [filenames count]; // Recount the number of filenames.
    if ( aCount > 0 ) {
        requests=[CVLSelectingFilesRequest requestsForSelectionOfPaths:filenames];
        [requests makeObjectsPerformSelector:@selector(schedule)];
    }
    [filenames release];
}

- (void) delayedImportOfDirectoriesIntoRepository:(NSDictionary *)aDictionary
{
    NSEnumerator	*dirEnum = [[aDictionary objectForKey:@"directories"] objectEnumerator];
    NSString		*aPath;
    CvsRepository	*aRepository = [aDictionary objectForKey:@"repository"];

    while ( (aPath = [dirEnum nextObject]) ) {
        // Perhaps we should also display the CVSROOT...
        [[RepositoryViewer sharedRepositoryViewer] importIntoRepository:aRepository importInfo:[NSDictionary dictionaryWithObject:aPath forKey:@"sourcePath"]];
    }
}

- (BOOL)errorsBeforeImportingIntoCvs:(NSPasteboard *)pboard error:(NSString **)errorMessage
{
    NSArray			*pboardFilenames = nil;
	NSString		*pboardFilename = nil;
    NSArray			*types = [pboard types];
    NSFileManager	*fileManager = [NSFileManager defaultManager];
    NSEnumerator	*fileEnum = nil;
    NSString		*aPath = nil;
    CvsRepository	*aRepository = nil;
	
    if( ([types containsObject:NSFilenamesPboardType] == NO) &&
		([types containsObject:NSStringPboardType] == NO) ){
        *errorMessage = @"Error: could not import directory, not a valid pasteboard type.";
        return YES;
    }
	
    pboardFilenames = [pboard propertyListForType:NSFilenamesPboardType];
    if ( pboardFilenames == nil ) {
		pboardFilename = [pboard propertyListForType:NSStringPboardType];
		if ( pboardFilename == nil ){
			
			*errorMessage = @"Error: could not import directory, pasteboard could not give filename. Invalid.";
			return YES;
		}
		pboardFilenames = [NSArray arrayWithObject:pboardFilename];
    }
	
    fileEnum = [pboardFilenames objectEnumerator];
    while ( (aPath = [fileEnum nextObject]) ) {        
    	// Let's check that filename is an existing directory
        if(![fileManager senFileExistsAtPath:aPath]){
            *errorMessage = [NSString stringWithFormat:@"%@ does not exist. CVL cannot import nonexistent directories.", aPath];
            return YES;
        }
        if(![fileManager senDirectoryExistsAtPath:aPath]){
            *errorMessage = [NSString stringWithFormat:@"%@ is not a directory. CVL can only import directories.", aPath];
            return YES;
        }
    }
	
	aRepository = [[CvsRepository registeredRepositories] objectAtIndex:0];
    if(!aRepository){
        *errorMessage = [NSString stringWithFormat:@"Unable to get repository for CVSROOT %@", aRepository];
        return YES;
    }
	return NO;
}

- (void) importIntoCvs:(NSPasteboard *)pboard userData:(NSString *)data error:(NSString **)errorMessage
{
    NSArray			*pboardFilenames = nil;
	NSString		*pboardFilename = nil;
    CvsRepository	*aRepository = nil;
	NSDictionary	*aDictionary = nil;
	BOOL hasErrors = NO;
	
	hasErrors = [self errorsBeforeImportingIntoCvs:pboard error:errorMessage];
	if ( hasErrors == YES ) {
        (void)NSRunAlertPanel(@"CVL Import Error!", 
                              *errorMessage, nil, nil, nil);
		return;
	}

	aRepository = [[CvsRepository registeredRepositories] objectAtIndex:0];
	pboardFilenames = [pboard propertyListForType:NSFilenamesPboardType];
	if ( pboardFilenames == nil ) {
		pboardFilename = [pboard propertyListForType:NSStringPboardType];
		pboardFilenames = [NSArray arrayWithObject:pboardFilename];
    }	
    aDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
		pboardFilenames, @"directories", aRepository, @"repository", nil];
    // We need to delay import, because services have a timeout and we will display a modal panel
    [self performSelector:@selector(delayedImportOfDirectoriesIntoRepository:) 
			   withObject:aDictionary 
			   afterDelay:0];
}


@end

@interface CVLDelegate(CVLEditorClient) <CVLEditorClient>
@end

@implementation CVLDelegate(CVLEditorClient)

- (BOOL) showCommitPanelWithSelectedFilesUsingTemplateFile:(NSString *)aTemplateFile
    /*" This method is called by the CVLEditorClient. This occurs after CVS is
        sent a commit message with an option to use CVLEditorClient as an editor.
        CVS then creates a temporary file and then CVLEditorClient is called 
        with an argument equal to the path to this temporary file. 
        CVLEditorClient then calls this method with that same path. This method 
        then calls the active viewer with the same method name and argument. The
        active viewer will then display a commit panel which will show the 
        contents of this temporary file (i.e. a template file). This method just
        sends the same message onto the active viewer and then returns YES if the
        viewer called was successful in committing the selected files using the
        contents of this template file.

        See also: #showCommitPanelWithSelectedFilesUsingTemplateFile: in the 
        classes CVLEditorClient, RepositoryViewer and WorkAreaViewer.
    "*/
{
    id  aViewer = nil;
    BOOL success = NO;
    
    aViewer = [self activeViewer];
    if ( aViewer != nil ) {
        success = [aViewer showCommitPanelWithSelectedFilesUsingTemplateFile:aTemplateFile];
    } else {
        NSBeep();
    }
    return success;
}


@end


//-------------------------------------------------------------------------------
