
// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "RetrievePanelController.h"
#import "NSString+CVL.h"
#import "CVLFile.h"
#import <SenFoundation/SenFoundation.h>
#import "WorkAreaViewer.h"
#import <CvsRequest.h>
#import <CvsCheckoutRequest.h>
#import <CvsUpdateRequest.h>
#import <SelectorRequest.h>
#import <ResultsRepository.h>
#import <CVLDelegate.h>

static RetrievePanelController *sharedRetrievePanelController;

@implementation RetrievePanelController


+ sharedRetrievePanelController
    /*" This method returns the unique shared RetrievePanelController.
        There is only one instance of this controller and it is shared.
    "*/
{
    if ( sharedRetrievePanelController == nil ) {
        sharedRetrievePanelController = 
        [[RetrievePanelController alloc] 
            initWithNibNamed:@"RetrievePanel"];
    }
    return sharedRetrievePanelController;
}

- (void) retrieveVersionForFiles:(NSArray *)theRelativeSelectedPaths inDirectory:(NSString *)aPath forAction:(int)anActionType
    /*" This method is the one to call to begin the process of restoring, 
        replacing, removing sticky attributes, saving or opening a specified
        version of the selected files in the directory given by aPath. What 
        action preformed is based on the value of anActionType. The possible 
        values of anActionType are as follows:
        _{CVL_RETRIEVE_RESTORE Restores the selected files to the specified 
            version.}
        _{CVL_RETRIEVE_REPLACE Replaces the selected files with the specified 
            version.}
        _{CVL_REMOVE_STICKY_ATTRIBUTES Removes any sticky attributes and updates
            to the HEAD of the repository the selected files.}
        _{CVL_RETRIEVE_OPEN Opens the selected files with the specified version.}
        _{CVL_RETRIEVE_SAVE_AS Saves a copy of the selected files with the 
            specified version.}
    
        For removing sticky attributes this method calls the method 
        -removeStickyAttributesAndUpdateSelectedFiles to do the work. For the 
        other actions this method first ask the shared ResultsRepository to 
        perform a CVS request for all the tags that are common to all the 
        selected files. When the shared ResultsRepository receives them it will 
        post a TagsForFilesReceivedNotification. Here we add ourself to be an 
        observer of the notification TagsForFilesReceivedNotification. When we 
        get that notifcation we then call the method -tagsForFilesReceived:. 
    "*/
{    
    NSNotificationCenter *theNotificationCenter = nil;
    ResultsRepository *theSharedResultsRepository = nil;
    
    if ( isNilOrEmpty(theRelativeSelectedPaths) ) {
        NSBeep();
    }
    
    ASSIGN(selectedFilenames, theRelativeSelectedPaths);
    if ( [selectedFilenames count] > 0 ) {
        ASSIGN(selectedFilename, [theRelativeSelectedPaths objectAtIndex:0]);
    } else {
        ASSIGN(selectedFilename, nil);
    }
    ASSIGN(selectedDirectory, aPath);
    actionType = anActionType;
            
    if ( actionType == CVL_REMOVE_STICKY_ATTRIBUTES ) {
        [self removeStickyAttributesAndUpdateSelectedFiles];
    } else {
        theSharedResultsRepository = [ResultsRepository sharedResultsRepository];
        [theSharedResultsRepository launchTaskToGetTagsForFiles:selectedFilenames 
                                                    inDirectory:selectedDirectory];
        theNotificationCenter = [NSNotificationCenter defaultCenter];
        [theNotificationCenter  addObserver:self 
                                   selector:@selector(tagsForFilesReceived:) 
                                       name:@"TagsForFilesReceivedNotification" 
                                     object:theSharedResultsRepository];
    }
}

- (void) tagsForFilesReceived:(NSNotification *)aNotification
    /*" This method is called when the shared ResultsRepository posts a 
        TagsForFilesReceivedNotification. This method then retrieves the tags 
        common to all the selected files from this notification and then starts 
        up the moda loop for the retrieve panel by calling the method 
        -runModalWithTags. 
    "*/
{
    NSNotificationCenter *theNotificationCenter = nil;
    NSMutableDictionary *aTagsDictionary = nil;
    NSDictionary *aUserInfo = nil;
    
    theNotificationCenter = [NSNotificationCenter defaultCenter];
    [theNotificationCenter removeObserver:self 
                                     name:@"TagsForFilesReceivedNotification"  
                                   object:nil];
    
    aUserInfo = [aNotification userInfo];
    if ( isNotEmpty(aUserInfo) ) {
        aTagsDictionary = [aUserInfo objectForKey:@"TagsDictionaryKey"];
    }
    [self setTagsDictionary:aTagsDictionary];
    
    [self runModalWithTags];
}

- (void) setupModalLoop
    /*" This method sets up a panel (that will be made modal later) that allows 
        the user to specify the version, either by revision, tag or date, that
        will be retrieved. In particular the panel title and the action button 
        title at the bottom of the panel at set depending on the action type and
        the number of selected files.
    "*/
{
    NSString *aTitle = nil;
    
    if ( actionType == CVL_RETRIEVE_REPLACE ) {
        [headingTabView selectTabViewItemAtIndex:CVL_RETRIEVE_REPLACE];
        [actionButton setTitle:@"Replace WorkArea File(s)"];
    } else if ( actionType == CVL_RETRIEVE_RESTORE ) {
        [headingTabView selectTabViewItemAtIndex:CVL_RETRIEVE_RESTORE];
        [actionButton setTitle:@"Restore WorkArea File(s)"];
    } else if ( actionType == CVL_RETRIEVE_OPEN ) {
        [headingTabView selectTabViewItemAtIndex:CVL_RETRIEVE_OPEN];
        [actionButton setTitle:@"Open in Temporary Directory"];
    } else if ( actionType == CVL_RETRIEVE_SAVE_AS ) {
        [headingTabView selectTabViewItemAtIndex:CVL_RETRIEVE_SAVE_AS];
        [actionButton setTitle:@"Save As..."];
    } else {
        NSString *anErrorMsg = nil;
        
        anErrorMsg = [NSString stringWithFormat:
            @"actionType was %d, it should be either #CVL_RETRIEVE_REPLACE, #CVL_RETRIEVE_RESTORE, #CVL_RETRIEVE_OPEN or #CVL_RETRIEVE_SAVE_AS!", 
            actionType];
        SEN_ASSERT_CONDITION_MSG(NO, anErrorMsg);
    }
    
    [super setupModalLoop];

    if ( [selectedFilenames count] == 1 ) {
        // Title for one file.
        aTitle = [NSString stringWithFormat:@"%@/%@", 
            selectedDirectory, selectedFilename];
    } else {
        // Title for more than one file.
        aTitle = [NSString stringWithFormat:@"%@/...", selectedDirectory];
    }
    [versionPanel setTitle:aTitle];
}

- (NSString *) revisionFromTextField
    /*" This method returns the string that is entered into the "Revision:" 
        textfield. If there is no entry in the "Revision:" textfield then nil is 
        returned.
    "*/
{
    NSString	*aString;
    
    SEN_ASSERT_NOT_NIL(revisionTextField);
    aString = [revisionTextField stringValue];
    if([aString length])
        return [NSString stringWithString:aString];
    else
        return nil;
}

- (void)updateGuiForTag:(int)aTag
    /*" This method is called by other methods to blank out the text fields and
        grey out the test field labels that
        are not associated with this matrix position.
    "*/
{
    NSString *aRevision = nil;
    
    // NB: Be sure the tags in the RetrievePanel.nib for the
    // four positions in the matrix are set to 0,1,2 and 3 for the date,
    // tag, revision and head.    
    // NB: Be sure the tags in the RetrievePanel.nib for the
    // three text fields are set to 0,1 and 2 for the date,
    // tag and revision.    
    SEN_ASSERT_CONDITION( ((aTag >= 0) && (aTag <= 3)) );

    [super updateGuiForTag:aTag];
    
    // Blank out the other entries.
    if ( aTag != 2 ) {
        [revisionTextField setStringValue:@""];
    }
    
    // Update the buttons at the bottom of the panel.
    // Get the selected revision.
    aRevision = [self revisionFromTextField];
    if ( isNotEmpty(aRevision) ) {
        [actionButton setEnabled:YES];
    }
}

- (void)controlTextDidChange:(NSNotification *)aNotification
    /*" This method is being used to disable the action button at the botton of 
        the panel when the user deletes all the characters in one of the text
        fields named dateTextField, tagTitleTextField or revisionTextField. 
        The action button is one of the three NSButtons named replaceButton, 
        saveAsButton and openButton.
    "*/
{
    id aControl = nil;
    id theFieldEditor = nil;
    NSString *theInputtedString = nil;
    
    aControl = [aNotification object];
    theFieldEditor = [[aNotification userInfo] objectForKey:@"NSFieldEditor"];
    theInputtedString = [theFieldEditor string];
    if ( [theInputtedString length] == 0 ) {
        if ( (aControl == dateTextField) ||
             (aControl == tagTitleTextField) || 
             (aControl == revisionTextField) ) {
            [actionButton setEnabled:NO];
        }        
    }
}

- (IBAction) replaceWorkAreaFiles:(id)sender
    /*" This is the action method that replaces the selected workarea files with
         whatever version the user chooses in the modal panel that this method 
        brings up. This method is just a cover method for the method 
        -retrieveWorkAreaFilesForAction: with the action of CVL_RETRIEVE_REPLACE
        which does the real work.
    "*/
{
    [self retrieveWorkAreaFilesForAction:CVL_RETRIEVE_REPLACE];
}

- (IBAction) restoreWorkAreaFiles:(id)sender
    /*" This is the action method that restores the selected workarea files with
        whatever version the user chooses in the modal panel that this method 
        brings up. This method is just a cover method for the method 
        -retrieveWorkAreaFilesForAction: with the action of CVL_RETRIEVE_REPLACE
        which does the real work.
    "*/
{
    [self retrieveWorkAreaFilesForAction:CVL_RETRIEVE_RESTORE];
}

- (void)retrieveWorkAreaFilesForAction:(int)anActionType
{
    NSString        *aVersion = nil;
    NSString        *aTagTitle = nil;
    NSString        *aRevision = nil;
    NSString        *aDateString = nil;
    int             workAreaFilesRetrieved = 0;
    BOOL            useHead = NO;
    
    if ( isNilOrEmpty(selectedFilenames) ) {
        return;
    }
    SEN_ASSERT_CONDITION( isNotEmpty(selectedDirectory) );
    	
    // Get the selected revision.
    aTagTitle = [self tagTitleFromTextField];
    aRevision = [self revisionFromTextField];
    aDateString = [self dateStringFromTextField];
    if ( isNotEmpty(aTagTitle) ) {
        aVersion = aTagTitle;
    } else if ( isNotEmpty(aRevision) ) {
        aVersion = aRevision;
    } else if ( isNotEmpty(aDateString) ) {
        ;
    } else if ( [selectionMatrix selectedTag] == 3 ) {
        useHead = YES;
    } else {
        // No input, just beep and return.
        NSBeep();
        return;
    }
    
    workAreaFilesRetrieved = [self retrieveWorkAreaFiles:selectedFilenames 
                                             inDirectory:selectedDirectory 
                                             withVersion:aVersion
                                                withDate:aDateString 
                                                withHead:useHead 
                                               forAction:anActionType];
        if ( workAreaFilesRetrieved != NSAlertDefaultReturn ) {
        return;
    }
    [NSApp stopModal];
}

- (int) retrieveWorkAreaFiles:(NSArray *)theSelectedFilenames inDirectory:(NSString *)theSelectedDirectory withVersion:(NSString *)aVersion withDate:(NSString *)aDateString withHead:(BOOL)useHead forAction:(int)anActionType
{
	CVLFile         *aCVLFile = nil;
    NSString        *aFilename = nil;
    NSString        *aPath = nil;
    NSString        *toPath = nil;
    NSEnumerator    *aFilenameEnumerator = nil;
    CvsRequest		*aCvsUpdateRequest = nil;
    SelectorRequest *anUpdateRequest = nil;
    WorkAreaViewer  *aViewer = nil;
    NSArray         *anArrayOfFiles = nil;
    int             retrieveFileCheck = NSAlertDefaultReturn;
    BOOL            removesStickyAttributes = NO;

    if ( anActionType == CVL_RETRIEVE_REPLACE ) {
        retrieveFileCheck = [self 
                         askUserIfHeWantsToReplaceFiles:theSelectedFilenames 
                                            inDirectory:theSelectedDirectory 
                                            withVersion:aVersion 
                                               withDate:aDateString 
                                               withHead:useHead];        
    } if ( anActionType == CVL_RETRIEVE_RESTORE ) {
        retrieveFileCheck = [self 
                         askUserIfHeWantsToRestoreFiles:theSelectedFilenames 
                                            inDirectory:theSelectedDirectory 
                                            withVersion:aVersion 
                                               withDate:aDateString 
                                               withHead:useHead];        
    }
    
    if ( retrieveFileCheck != NSAlertDefaultReturn ) {
        return retrieveFileCheck; // Action cancelled, just return.
    }
    
    if ( anActionType == CVL_RETRIEVE_REPLACE ) {
        removesStickyAttributes = YES;
    } else if ( anActionType == CVL_RETRIEVE_RESTORE ) {
        if ( useHead == YES ) {
            removesStickyAttributes = YES;
        } else {
            removesStickyAttributes = NO;
        }
    }                
    aFilenameEnumerator = [theSelectedFilenames objectEnumerator];
    while ( (aFilename = [aFilenameEnumerator nextObject]) ) {
        aPath = [theSelectedDirectory stringByAppendingPathComponent:aFilename];
        if ( anActionType == CVL_RETRIEVE_REPLACE ) {
            toPath = aPath;
        } else if ( anActionType == CVL_RETRIEVE_RESTORE ) {
            toPath = nil;
        }            
		// Developer Note: For some unknown reason the pipe feature no longer works
		// for cvs wrapper files from pserver repositories. Hence we are using a 
		// checkout request to a temporary directory for all cvs wrapper files,
		// even the ones from other types of repositories, just to be consistent.
		// But only for the replacement type of action. For the restore type of
		// action we are not using pipes.
		// William Swats -- 16-Dec-2004
		aCVLFile = (CVLFile *)[CVLFile treeAtPath:aPath];		
		if ( ([aCVLFile isRealWrapper] == YES) &&
			 ( anActionType == CVL_RETRIEVE_REPLACE ) ) {
			aCvsUpdateRequest = [CvsCheckoutRequest 
								cvsUpdateRequestForFile:aFilename
												 inPath:theSelectedDirectory 
											   revision:aVersion 
												   date:aDateString
								removesStickyAttributes:useHead
												 toFile:toPath];
		// End of fix for wrapper files from pserver repositories.
		} else {
			aCvsUpdateRequest = [CvsUpdateRequest 
                            cvsUpdateRequestForFile:aFilename
                                             inPath:theSelectedDirectory
                                           revision:aVersion 
                                               date:aDateString
                            removesStickyAttributes:removesStickyAttributes
                                             toFile:toPath];			
		}			
        
        // Now create another request that will force the update of the GUI.
        // In this case it will normally put a plus sign in front of the file
        // whose contents were just replaced.
        aViewer = [WorkAreaViewer viewerForPath:aPath];
        SEN_ASSERT_NOT_NIL(aViewer);
        [aViewer refreshSelectedFiles:self];
        anArrayOfFiles = [NSArray arrayWithObject:aPath];
        anUpdateRequest = [SelectorRequest 
                       requestWithTarget:aViewer 
                                selector:@selector(refreshTheseSelectedFiles:) 
                                argument:anArrayOfFiles];
        SEN_ASSERT_NOT_NIL(anUpdateRequest);
        [anUpdateRequest setCanBeCancelled:YES];
        
        [anUpdateRequest addPrecedingRequest:aCvsUpdateRequest];
        [anUpdateRequest schedule];
    }    
    return retrieveFileCheck;
}

- (BOOL) askUserIfHeWantsToReplaceFiles:(NSArray *)theSelectedFilenames inDirectory:(NSString *)theSelectedDirectory withVersion:(NSString *)aVersion withDate:(NSString *)aDateString withHead:(BOOL)useHead
{
    int             replaceFileCheck = NSAlertDefaultReturn;

    if ( [theSelectedFilenames count] == 1 ) {
		ASSIGN(selectedFilename, [theSelectedFilenames objectAtIndex:0]);
        if ( useHead == YES ) {
            replaceFileCheck = NSRunAlertPanel(@"Replace File", 
                   @"The contents of the workarea file \"%@\" in directory \"%@\" will be replaced by the contents of this file at the head of the repository. Any prior modifications in this workarea file will be lost.", 
                   @"Replace File", @"Cancel", nil, 
                   selectedFilename, theSelectedDirectory);     
        } else if ( isNotEmpty(aVersion) ) {
            replaceFileCheck = NSRunAlertPanel(@"Replace File", 
                   @"The contents of the workarea file \"%@\" in directory \"%@\" will be replaced by the contents of this file in the repository as of version %@. After replacing the contents, the file will need to be committed to make the change in the CVS repository permanent. Any prior modifications in this workarea file will be lost.", 
                   @"Replace File", @"Cancel", nil, 
                   selectedFilename, theSelectedDirectory, aVersion);                 
        } else if ( isNotEmpty(aDateString) ) {
            replaceFileCheck = NSRunAlertPanel(@"Replace File", 
                   @"The contents of the workarea file \"%@\" in directory \"%@\" will be replaced by the contents of this file in the repository as of %@. After replacing the contents, the file will need to be committed to make the change in the CVS repository permanent. Any prior modifications in this workarea file will be lost.", 
                   @"Replace File", @"Cancel", nil, 
                   selectedFilename, theSelectedDirectory, aDateString);                             
        } else {
            SEN_ASSERT_CONDITION_MSG((NO), ([NSString stringWithFormat:
                @"There was no revision, date or head use passed to this method. something is wrong."]));
        }
    } else {
        if ( useHead == YES ) {
            replaceFileCheck = NSRunAlertPanel(@"Replace Files", 
                   @"The contents of the %d workarea files in directory \"%@\" will be replaced by the contents of these files at the head of the repository. Any modifications in these files will be lost. ", 
                   @"Replace Files", @"Cancel", nil, 
                   [theSelectedFilenames count], theSelectedDirectory);  
        } else if ( isNotEmpty(aVersion) ) {
            replaceFileCheck = NSRunAlertPanel(@"Replace Files", 
                   @"The contents of the %d workarea files in directory \"%@\" will be replaced by the contents of these files in the repository as of version %@. After replacing the contents, the files will need to be committed to make the change in the CVS repository permanent. Any modifications in these files will be lost. ", 
                   @"Replace Files", @"Cancel", nil, 
                   [theSelectedFilenames count], theSelectedDirectory, aVersion);  
        } else if ( isNotEmpty(aDateString) ) {
            replaceFileCheck = NSRunAlertPanel(@"Replace Files", 
                   @"The contents of the %d workarea files in directory \"%@\" will be replaced by the contents of these files in the repository as of %@. After replacing the contents, the files will need to be committed to make the change in the CVS repository permanent. Any modifications in these files will be lost. ", 
                   @"Replace Files", @"Cancel", nil, 
                   [theSelectedFilenames count], theSelectedDirectory, aDateString);          
        } else {
            SEN_ASSERT_CONDITION_MSG((NO), ([NSString stringWithFormat:
                @"There was no revision, date or head use passed to this method. something is wrong."]));
        }
    }
    return replaceFileCheck;
}

- (BOOL) askUserIfHeWantsToRestoreFiles:(NSArray *)theSelectedFilenames inDirectory:(NSString *)theSelectedDirectory withVersion:(NSString *)aVersion withDate:(NSString *)aDateString withHead:(BOOL)useHead
{
    int             restoreFileCheck = NSAlertDefaultReturn;
    
    if ( [theSelectedFilenames count] == 1 ) {
		ASSIGN(selectedFilename, [theSelectedFilenames objectAtIndex:0]);
        if ( useHead == YES ) {
            restoreFileCheck = NSRunAlertPanel(@"Restore File", 
                                               @"This action will restore the workarea file \"%@\" in directory \"%@\" to the version at the head of the repository. This file will have all the sticky attributes removed. Any modifications in this workarea file will be merged into this version.", 
                                               @"Restore File", @"Cancel", nil, 
                                               selectedFilename, theSelectedDirectory);  
        } else if ( isNotEmpty(aVersion) ) {
            restoreFileCheck = NSRunAlertPanel(@"Restore File", 
                                               @"This action will restore the workarea file \"%@\" in directory \"%@\" to the version %@. This file will now have the sticky attribute %@. Any modifications in this workarea file will be merged into this version.", 
                                               @"Restore File", @"Cancel", nil, 
                                               selectedFilename, theSelectedDirectory, aVersion, aVersion);              
        } else if ( isNotEmpty(aDateString) ) {
            restoreFileCheck = NSRunAlertPanel(@"Restore File", 
                                               @"This action will restore the workarea file \"%@\" in directory \"%@\" to the version at date %@. This file will now have the sticky date attribute %@. Any modifications in this workarea file will be merged into this version.", 
                                               @"Restore File", @"Cancel", nil, 
                                               selectedFilename, theSelectedDirectory, aDateString, aDateString);              
        } else {
            SEN_ASSERT_CONDITION_MSG((NO), ([NSString stringWithFormat:
                @"There was no revision, date or head use passed to this method. something is wrong."]));
        }
    } else {
        if ( useHead == YES ) {
            restoreFileCheck = NSRunAlertPanel(@"Restore Files", 
                                               @"This action will restore the %d workarea files in directory \"%@\" to the version at the head of the repository. These files will have all the sticky attributes removed. Any modifications in these workarea files will be merged into this version.", 
                                               @"Restore Files", @"Cancel", nil, 
                                               [theSelectedFilenames count], theSelectedDirectory);  
        } else if ( isNotEmpty(aVersion) ) {
            restoreFileCheck = NSRunAlertPanel(@"Restore Files", 
                                               @"This action will restore the %d workarea files in directory \"%@\" to the version %@. These files will now have the sticky attribute %@. Any modifications in these workarea files will be merged into this version.", 
                                               @"Restore Files", @"Cancel", nil, 
                                               [theSelectedFilenames count], theSelectedDirectory, 
                                               aVersion, aVersion);              
        } else if ( isNotEmpty(aDateString) ) {
            restoreFileCheck = NSRunAlertPanel(@"Restore Files", 
                                               @"This action will restore the %d workarea files in directory \"%@\" to the version at date %@. These files will now have the sticky date attribute %@. Any modifications in these workarea files will be merged into this version.", 
                                               @"Restore Files", @"Cancel", nil, 
                                               [theSelectedFilenames count], theSelectedDirectory, 
                                               aDateString, aDateString);              
        } else {
            SEN_ASSERT_CONDITION_MSG((NO), ([NSString stringWithFormat:
                @"There was no revision, date or head use passed to this method. something is wrong."]));
        }
    }
    return restoreFileCheck;
}

- (IBAction) openVersionInTemporaryDirectory:(id)sender
    /*" This is the action method that opens in the temporary directory the 
        selected workarea files with whatever version the user chooses in the 
        modal panel that this method brings up.
    "*/
{
    NSString        *aFilename = nil;
    NSString        *aVersion = nil;
    NSString        *aTagTitle = nil;
    NSString        *aRevision = nil;
    NSString        *aDateString = nil;
    NSString        *aPath = nil;
    NSEnumerator    *aFilenameEnumerator = nil;
    BOOL            useHead = NO;

    if ( isNilOrEmpty(selectedFilenames) ) {
        return;
    }
    SEN_ASSERT_CONDITION( isNotEmpty(selectedDirectory) );
    
    // Get the selected revision.
    aTagTitle = [self tagTitleFromTextField];
    aRevision = [self revisionFromTextField];
    aDateString = [self dateStringFromTextField];
    if ( isNotEmpty(aTagTitle) ) {
        aVersion = aTagTitle;
    } else if ( isNotEmpty(aRevision) ) {
        aVersion = aRevision;
    } else if ( isNotEmpty(aDateString) ) {
        ;
    } else if ( [selectionMatrix selectedTag] == 3 ) {
        useHead = YES;
    } else {
        // No input, just beep and return.
        NSBeep();
        return;
    }
    
    aFilenameEnumerator = [selectedFilenames objectEnumerator];
    while ( (aFilename = [aFilenameEnumerator nextObject]) ) {
        aPath = [selectedDirectory stringByAppendingPathComponent:aFilename];
        [[NSApp delegate] openInTemporaryDirectory:aPath 
                                       withVersion:aVersion 
                                      orDateString:aDateString 
                                          withHead:useHead];
    }
    [NSApp stopModal];
}

- (IBAction) saveVersionAs:(id)sender
    /*" This is the action method that saves via of the save panel the 
        selected workarea file (can only be one-at-a-time) with whatever version
        the user chooses in the modal panel that this method brings up.
    "*/
{
    NSString        *aVersion = nil;
    NSString        *aTagTitle = nil;
    NSString        *aRevision = nil;
    NSString        *aDateString = nil;
    NSString        *aPath = nil;
    int             savePanelResultCode = 0;
    BOOL            useHead = NO;
        
    // Get the selected revision.
    aTagTitle = [self tagTitleFromTextField];
    aRevision = [self revisionFromTextField];
    aDateString = [self dateStringFromTextField];
    if ( isNotEmpty(aTagTitle) ) {
        aVersion = aTagTitle;
    } else if ( isNotEmpty(aRevision) ) {
        aVersion = aRevision;
    } else if ( isNotEmpty(aDateString) ) {
        ;
    } else if ( [selectionMatrix selectedTag] == 3 ) {
        useHead = YES;
    } else {
        // No input, just beep and return.
        NSBeep();
        return;
    }
    
    // Get the selected file name and directory path of the file.
    SEN_ASSERT_NOT_EMPTY(selectedDirectory);
    SEN_ASSERT_NOT_EMPTY(selectedFilename);
    aPath = [selectedDirectory stringByAppendingPathComponent:selectedFilename];
    
    savePanelResultCode = [[NSApp delegate] save:aPath 
                                     withVersion:aVersion 
                                    orDateString:aDateString 
                                        withHead:useHead];
    
    if ( savePanelResultCode == NSOKButton ) {
        [NSApp stopModal];
    }
}

- (IBAction) performButtonAction:(id)sender
    /*" This action method calls the appropriate action method based on the 
        action type that was used to display the modal panel in the call to the 
        method -retrieveVersionForFiles:inDirectory:forAction:. See that method
        for more infomation.
    "*/
{        
    if ( actionType == CVL_RETRIEVE_REPLACE ) {
        [self replaceWorkAreaFiles:sender];
    } else if ( actionType == CVL_RETRIEVE_RESTORE ) {
        [self restoreWorkAreaFiles:sender];
    } else if ( actionType == CVL_RETRIEVE_OPEN ) {
        [self openVersionInTemporaryDirectory:sender];
    } else if ( actionType == CVL_RETRIEVE_SAVE_AS ) {
        [self saveVersionAs:sender];
    } else {
        NSString *anErrorMsg = nil;
        
        anErrorMsg = [NSString stringWithFormat:
            @"actionType was %d, it should be either #CVL_RETRIEVE_REPLACE, #CVL_RETRIEVE_OPEN or #CVL_RETRIEVE_SAVE_AS!", actionType];
        SEN_ASSERT_CONDITION_MSG(NO, anErrorMsg);
    }
}

- (void) removeStickyAttributesAndUpdateSelectedFiles
    /*" This method removes the sticky attributes and then updates the selected 
        files to the head of the repository. The user is asked to confirm this 
        action before proceeding.
    "*/
{
    NSString        *aPath = nil;
    NSString        *aFilename = nil;
    NSEnumerator    *aFilenameEnumerator = nil;
    CvsUpdateRequest *aCvsUpdateRequest = nil;
    SelectorRequest *anUpdateRequest = nil;
    WorkAreaViewer  *aViewer = nil;
    NSArray         *anArrayOfFiles = nil;
    int             replaceFileCheck = 0;
    
    if ( isNilOrEmpty(selectedFilenames) ) {
        return;
    }
    SEN_ASSERT_CONDITION( isNotEmpty(selectedDirectory) );
    
    if ( [selectedFilenames count] == 1 ) {
        replaceFileCheck = NSRunAlertPanel(
                                           @"Remove Sticky Attributes and Update", 
                                           @"This action will remove any sticky tags, dates, or options and then the contents will be updated to the head of the repository. Any modifications in workarea file \"%@\" in directory \"%@\" will be merged into the version at the head of the repository.", 
                                           @"Remove Sticky Attributes and Update", @"Cancel", nil, 
                                           selectedFilename, selectedDirectory);                 
    } else {
        replaceFileCheck = NSRunAlertPanel(
                                           @"Remove Sticky Attributes and Update", 
                                           @"This action will remove any sticky tags, dates, or options and then the contents will be updated to the head of the repository. Any modifications in the %d workarea files in directory \"%@\" will be merged into the version at the head of the repository.", 
                                           @"Remove Sticky Attributes and Update", @"Cancel", nil, 
                                           [selectedFilenames count], selectedDirectory);        
    }
    if ( replaceFileCheck != NSAlertDefaultReturn ) {
        return; // Action cancelled, just return.
    }
    
    aFilenameEnumerator = [selectedFilenames objectEnumerator];
    while ( (aFilename = [aFilenameEnumerator nextObject]) ) {
        aPath = [selectedDirectory stringByAppendingPathComponent:aFilename];
        aCvsUpdateRequest = [CvsUpdateRequest 
                            cvsUpdateRequestForFile:aFilename
                                             inPath:selectedDirectory
                                           revision:nil 
                                               date:nil
                            removesStickyAttributes:YES
                                             toFile:nil];
        
        // Now create another request that will force the update of the GUI.
        // In this case it will normally put a plus sign in front of the file
        // whose contents were just replaced.
        aViewer = [WorkAreaViewer viewerForPath:aPath];
        SEN_ASSERT_NOT_NIL(aViewer);
        [aViewer refreshSelectedFiles:self];
        anArrayOfFiles = [NSArray arrayWithObject:aPath];
        anUpdateRequest = [SelectorRequest requestWithTarget:aViewer 
                                                    selector:@selector(refreshTheseSelectedFiles:) 
                                                    argument:anArrayOfFiles];
        SEN_ASSERT_NOT_NIL(anUpdateRequest);
        [anUpdateRequest setCanBeCancelled:YES];
        
        [anUpdateRequest addPrecedingRequest:aCvsUpdateRequest];
        [anUpdateRequest schedule];
    }
}


@end
