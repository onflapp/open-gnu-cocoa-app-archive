//
//  RestoreWorkAreaPanelController.m
//  CVL
//
//  Created by William Swats on Mon Apr 05 2004.
//  Copyright (c) 2004 Sente SA. All rights reserved.
//

#import "RestoreWorkAreaPanelController.h"

#import "NSString+CVL.h"
#import "CVLFile.h"
#import <SenFoundation/SenFoundation.h>
#import "WorkAreaViewer.h"
#import <CvsUpdateRequest.h>
#import <SelectorRequest.h>
#import <ResultsRepository.h>
#import "CVLWaitController.h"
#import <CvsTag.h>

static RestoreWorkAreaPanelController *sharedRestoreWorkAreaPanelController;

@implementation RestoreWorkAreaPanelController

+ sharedRestoreWorkAreaPanelController
    /*" This method returns the unique shared RestoreWorkAreaPanelController.
        There is only one instance of this controller and it is shared.
    "*/
{
    if ( sharedRestoreWorkAreaPanelController == nil ) {
        sharedRestoreWorkAreaPanelController = 
            [[RestoreWorkAreaPanelController alloc] 
            initWithNibNamed:@"RestoreWorkAreaPanel"];
    }
    return sharedRestoreWorkAreaPanelController;
}

- (void)dealloc
{
    RELEASE(workAreaPath);
    [super dealloc];
}

- (void) restoreVersionForWorkArea:(NSString *)aPath
    /*" This method is the one to call to begin the process of restoring another
        version of the repository to the workarea. It first checks the shared 
        ResultsRepository cache of workarea tags. If it finds a cache of 
        workarea tags then it uses these cached tags to call the method 
        -runModalWithTags to display a panel that allows the
        user to specify the version, either by tag or date, that will be 
        restored. If the shared ResultsRepository does not have the tags cached 
        then we add ourself to be an observer of the notification 
        WorkAreaTagsReceivedNotification. When we get that notifcation then we
        call the method -runModalWithTags. Note that the shared 
        ResultsRepository runs a CVS request for the tags if it does not have 
        them cached. When it receives them it it will post a 
        WorkAreaTagsReceivedNotification.
    "*/
{    
    NSNotificationCenter *theNotificationCenter = nil;
    NSArray *sortedTags = nil;
    ResultsRepository *theSharedResultsRepository = nil;
    NSMutableDictionary *aTagsDictionary = nil;

    ASSIGN(workAreaPath, aPath);

    theSharedResultsRepository = [ResultsRepository sharedResultsRepository];
    // Note: This next statement only returns a tags dictionary if it was already
    // cached. If it was not cached then an empty dictionary is returned and a
    // request is sent to the repository via the CvsVerboseStatusRequestForWorkArea
    // class for all the tags for this workarea. When the tags are received then
    // a WorkAreaTagsReceivedNotification is posted which is caught by this
    // controller in the method -workAreaTagsReceived: which will then call the
    // method -runModalWithTags.
    aTagsDictionary = [theSharedResultsRepository getTagsForWorkArea:workAreaPath];
    [self setTagsDictionary:aTagsDictionary];
    if ( aTagsDictionary == nil ) {
        (void)NSRunAlertPanel(@"Restore WorkArea", 
              @"Could not fetch a tags for workarea \"%@\". Will show Restore Panel without tags.",
              nil, nil, nil, workAreaPath);   
        [self runModalWithTags];
    } else {
        sortedTags = [aTagsDictionary objectForKey:@"SortedTagsKey"];
        if ( sortedTags != nil ) {
            // Go straight to running the modal loop with pre-cached tags.
            [self runModalWithTags];
        } else {
            // Otherwise wait until the notification...
            theNotificationCenter = [NSNotificationCenter defaultCenter];
            [theNotificationCenter  addObserver:self 
                                       selector:@selector(workAreaTagsReceived:) 
                                           name:@"WorkAreaTagsReceivedNotification" 
                                         object:theSharedResultsRepository];        
        }        
    }
}

- (void) workAreaTagsReceived:(NSNotification *)aNotification
    /*" This method is called when the WorkAreaTagsReceivedNotification is 
        posted. This notification is posted only if the shared ResultsRepository
        does not have the workarea tags cached and has to request them from the 
        CVS repository. This method simply gets the tags from the notification 
        and then calls the method -runModalWithTags to display the panel that 
        allows the user to specify the version, either by tag or date, that will
        be restored.
    "*/
{
    NSNotificationCenter *theNotificationCenter = nil;
    NSMutableDictionary *aTagsDictionary = nil;
    NSDictionary *aUserInfo = nil;
    
    theNotificationCenter = [NSNotificationCenter defaultCenter];
    [theNotificationCenter removeObserver:self 
                                     name:@"WorkAreaTagsReceivedNotification"  
                                   object:nil];
    
    aUserInfo = [aNotification userInfo];
    if ( isNotEmpty(aUserInfo) ) {
        aTagsDictionary = [aUserInfo objectForKey:@"TagsDictionaryKey"];
    }
    [self setTagsDictionary:aTagsDictionary];
    
    [self runModalWithTags];
}

- (IBAction) restoreWorkArea:(id)sender
    /*" This is the action method that is called when the user clicks on the 
        "Restore Work Area Files" button in the RestoreWorkAreaPanel. This 
        method first warns the user that modifications may be lost or merged 
        depending on the case. Then an 
        update request is created with the date or tag specified by the user. 
        Also a refresh request is appended to the update request so that the CVL 
        browser gets updated. Then another request is created that will check for 
        branch tags in empty directories when all the non-empty directories have
        non-branch tags. Then these three requests are scheduled and then 
        this method stops the modal loop which then returns control to the line
        after the call to -runModalForWindow: in the method 
        -runModalWithTags. Finally this method stops the modal loop which then 
        returns control to the line after the call to -runModalForWindow: in the
        method -runModalWithTags.
    "*/
{
    NSString        *aSuffix = nil;
    NSString        *aVersion = nil;
    NSString        *aTagTitle = nil;
    NSString        *aDateString = nil;
    CvsUpdateRequest *aCvsUpdateRequest = nil;
    SelectorRequest *aCheckTagsRequest = nil;
    SelectorRequest *anUpdateRequest = nil;
    WorkAreaViewer  *aViewer = nil;
    NSArray         *anArrayOfFiles = nil;
    int             replaceFileCheck = 0;
    BOOL            removesStickyAttributes = NO;
    

    // Get the selected revision.
    aTagTitle = [self tagTitleFromTextField];
    aDateString = [self dateStringFromTextField];
    if ( isNotEmpty(aTagTitle) ) {
        aVersion = aTagTitle;
        aSuffix = aTagTitle;
    } else if ( isNotEmpty(aDateString) ) {
        aSuffix = aDateString;
    } else if ( [selectionMatrix selectedTag] == 3 ) {
        removesStickyAttributes = YES;
        aSuffix = @"NONE";
    } else {
        // No input, just return.
        return;
    }
    SEN_ASSERT_CONDITION( (isNotEmpty(aVersion) || 
                           isNotEmpty(aDateString) ||
                           ([selectionMatrix selectedTag] == 3)) );
    
    if ( [aSuffix isEqualToString:@"NONE"] ) {
        replaceFileCheck = NSRunAlertPanel(@"Restore Workarea", 
                @"This action will remove any sticky tags, dates, or options and then the contents will be updated to the head of the repository. Any modifications in workarea files will be merged into the version at the head of the repository.", 
               @"Restore Workarea", @"Cancel", nil);                
    } else {
        replaceFileCheck = NSRunAlertPanel(@"Restore Workarea", 
               @"The contents of the workarea files will be replaced by the contents of these files as of version %@. Any modifications in workarea files will be lost. ", 
               @"Restore Workarea", @"Cancel", nil, aSuffix);        
    }
    if ( replaceFileCheck != NSAlertDefaultReturn ) {
        return; // Action cancelled, just return.
    }
        
    SEN_ASSERT_CONDITION( isNotEmpty(workAreaPath) );

    aCvsUpdateRequest = [CvsUpdateRequest 
                            cvsUpdateRequestForFiles:nil
                                              inPath:workAreaPath 
                                            revision:aVersion 
                                                date:aDateString
                             removesStickyAttributes:removesStickyAttributes];
    
    // Now create another request that will force the update of the GUI.
    // In this case it will normally put a plus sign in front of the file
    // whose contents were just replaced.
    aViewer = [WorkAreaViewer viewerForPath:workAreaPath];
    SEN_ASSERT_NOT_NIL(aViewer);
    [aViewer refreshSelectedFiles:self];
    anArrayOfFiles = [NSArray arrayWithObject:workAreaPath];
    anUpdateRequest = [SelectorRequest 
                            requestWithTarget:aViewer 
                                     selector:@selector(refreshTheseSelectedFiles:) 
                                     argument:anArrayOfFiles];
    SEN_ASSERT_NOT_NIL(anUpdateRequest);
    [anUpdateRequest setCanBeCancelled:YES];
    [anUpdateRequest addPrecedingRequest:aCvsUpdateRequest];
    
    // Now create another request that will check for branch tags in empty
    // directories while all the non-empty directories have non-branch tags.
    aCheckTagsRequest = [SelectorRequest 
                            requestWithTarget:aViewer 
                                     selector:@selector(checkTheTagsAndUpdate:) 
                                     argument:aViewer];
    SEN_ASSERT_NOT_NIL(aCheckTagsRequest);
    [aCheckTagsRequest setCanBeCancelled:YES];
    [aCheckTagsRequest addPrecedingRequest:anUpdateRequest];
    
    [aCheckTagsRequest schedule];
    [NSApp stopModal];
}


@end
