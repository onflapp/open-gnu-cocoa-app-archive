//
//  RestoreRetrieveController.m
//  CVL
//
//  Created by William Swats on Wed May 05 2004.
//  Copyright (c) 2004 Sente SA. All rights reserved.
//

/*" This is a abstract superclass used by the subclass controllers 
    RestoreWorkAreaPanelController and RetrievePanelController. This class 
    contains the common code used by these two subclasses.
"*/

#import "RestoreRetrieveController.h"

#import <CvsVerboseStatusRequestForWorkArea.h>
#import "NSString+CVL.h"
#import "CVLFile.h"
#import <SenFoundation/SenFoundation.h>
#import "WorkAreaViewer.h"
#import <CvsUpdateRequest.h>
#import <SelectorRequest.h>
#import <ResultsRepository.h>
#import "CVLWaitController.h"
#import <CvsTag.h>
#import <DateTimeController.h>


@implementation RestoreRetrieveController


- (id)init
    /*" This method should not be called. It will raise an exception named
        SenNotDesignatedInitializerException if it is. The designated 
        initializer for this class is #{-initWithNibNamed:}.
    "*/
{
    SEN_NOT_DESIGNATED_INITIALIZER(@"-initWithNibNamed:");
    
    return nil;
}


- (id)initWithNibNamed:(NSString *)aNibName
    /*" This method should not be called directly. It will be called by the 
        class method +sharedRestoreWorkAreaPanelController. Use that method 
        instead. It also creates the date formatter used with the date 
        textfield and creates the workarea tags cache dictionary.
    "*/
{
    NSString *aFormatString = nil;
    BOOL isNibLoaded = NO;
    
    SEN_ASSERT_NOT_EMPTY(aNibName);
    
    if ( (self = [super init]) ) {
        isNibLoaded = [NSBundle loadNibNamed:aNibName owner:self];
        SEN_ASSERT_CONDITION_MSG((isNibLoaded), 
             ([NSString stringWithFormat:
                 @"Unable to load nib named \"%@\"",aNibName]));
        SEN_ASSERT_NOT_NIL(dateTextField);
        SEN_ASSERT_NOT_NIL(tagTitleTextField);
        SEN_ASSERT_NOT_NIL([tagTitleTextField formatter]);
        SEN_ASSERT_NOT_NIL(actionButton);

        [dateTextField setObjectValue:nil];
        aFormatString = [[NSUserDefaults standardUserDefaults] 
                            stringForKey:@"CVLDateFormat"];
        tagsDictionary = [[NSMutableDictionary alloc] initWithCapacity:100];
    }
    return self;
}

- (void)dealloc
{
    [super dealloc];
}

- (NSMutableDictionary *)tagsDictionary
    /*" This is the get method for the instance variable named tagsDictionary. 
        This mutable dictionary is a cache for all the tags associated with the
         current repository and contains the following:

        _{SortedTagsKey An array of CvsTag instances sorted by tag title.}
        _{TagTitleKey A string representing the tag the user last chose for
            retrieving.}
        _{DateStringKey A string representing the date the user last entered for
            retrieving.}

        See Also #setTagsDictionary:.
    "*/
{
	return tagsDictionary;
}

- (void)setTagsDictionary:(NSDictionary *)newTagsDictionary
    /*" This is the set method for the instance variable named tagsDictionary. 
        This mutable dictionary is a cache for all the tags associated with the 
        current repository. This method empties the tagsDictionary and then 
        adds the entries in the newTagsDictionary into the tagsDictionary. It 
        does not retain the newTagsDictionary.

        See Also #tagsDictionary.
    "*/
{
    [tagsDictionary removeAllObjects];
    if ( newTagsDictionary != nil ) {
        SEN_ASSERT_CLASS(newTagsDictionary, @"NSDictionary");
        
        [tagsDictionary addEntriesFromDictionary:newTagsDictionary];
    }        
}

- (IBAction)show:(id)sender
    /*" This action method displays the modal panel.
    "*/
{
    [versionPanel orderFront:self];
}

- (IBAction)hide:(id)sender
    /*" This action method hides the modal panel (i.e. takes if off screen).
    "*/
{
    [versionPanel orderOut:self];
}

- (void) runModalWithTags
    /*" This method runs a modal panel that allows the user to specify the 
        version, either by revision, tag or date, that will be retrieved. 
    "*/
{
    SEN_ASSERT_NOT_NIL(versionPanel);

    [self setupModalLoop];
    [NSApp runModalForWindow:versionPanel];
    [self cleanupAfterModalLoop];
    
}

- (void) setupModalLoop
    /*" This method sets up a panel (that will be made modal later) that allows 
        the user to specify the version, either by revision, tag or date, that
        will be retrieved. 
    "*/
{    
    [self show: self];
    [dateTextField setStringValue:@""];
    [tagTitleTextField setStringValue:@""];
    [self selectionMatrixChanged:selectionMatrix];
    
    [self updateGuiWithWorkAreaTags];
}

- (void) cleanupAfterModalLoop
    /*" This method closes the modal panel that allowed the user to specify the 
        version. Before this panel is closed the state of the textfields in the 
        panel is saved in this controller's cache along with the workarea tags. 
        The textfields saved are the date and the tag textfields.
    "*/
{
    NSString *aTagTitle = nil;
    NSString *aDateString = nil;        

    // First remove the previous saved state, if any.
    [tagsDictionary removeObjectForKey:@"TagTitleKey"];
    [tagsDictionary removeObjectForKey:@"DateStringKey"];
    // Lets save the state of this panel.
    aTagTitle = [self tagTitleFromTextField];
    aDateString = [dateTextField stringValue];
    if ( isNotEmpty(aTagTitle) ) {
        [tagsDictionary setObject:aTagTitle forKey:@"TagTitleKey"];
    } else if ( isNotEmpty(aDateString) ) {
        [tagsDictionary setObject:aDateString forKey:@"DateStringKey"];
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self 
                                                    name:@"ResultsChanged" 
                                                  object:nil];    
    [self hide:self];    
}

- (IBAction) cancel:(id)sender
    /*" This is the action method that is called when the user clicks on the 
        Cancel button in the modal panel. This method stops
        the modal loop which then returns control to the line after the call to
        -runModalForWindow: in the method -runModalWithTags.
    "*/
{
    modalResult=[sender tag];
    [NSApp stopModal];
}

- (NSString *) dateStringFromTextField
    /*" This method returns the date string that is entered in the "Date:" 
        textfield. The date string is of the form YYYY-MM-DDThh:mm:ss.sTZD 
        (e.g. 1997-07-16T19:20:30.45+0100).
    "*/
{
    NSCalendarDate *aDate = nil;
    
    aDate = [dateTextField objectValue];    
    if( aDate != nil ) {
		// http://www.w3.org/TR/NOTE-datetime
		// ISO8601
		// e.g. YYYY-MM-DDThh:mm:ss.sTZD (eg 1997-07-16T19:20:30.45+0100)
		return [aDate descriptionWithCalendarFormat:@"%Y-%m-%dT%H:%M:%S%z"];            
    }
    return nil;
}

- (NSString *) tagTitleFromTextField
    /*" This method returns the string that is entered into the "Tag:" 
        textfield. If there is no entry in the "Tag:" textfield then nil is 
        returned.
    "*/
{
    NSString	*aString;
    
    aString = [tagTitleTextField stringValue];
    if ( [aString length] > 0 ) {
        return [NSString stringWithString:aString];
    }
    return nil;
}

- (void)control:(NSControl *)aControl didFailToValidatePartialString:(NSString *)aString errorDescription:(NSString *)anError
    /*" This method allows us to present an error panel to user if he starts to 
        type in an incorrect release tag.
    "*/
{
    NSString *aTitle = nil;
    
    SEN_ASSERT_NOT_NIL(aControl);
    
    if ( aControl == tagTitleTextField ) {
        aTitle = [NSString stringWithFormat:@"CVS Tag Formatting Error"];
        (void)NSRunAlertPanel(aTitle, anError, nil, nil, nil);        
    }
}

- (IBAction)resultsChanged:(id)sender
    /*" This method is called whenever one of the three text fields is changed.
        These three text fields are the date, release tag and revision fields.
        Its function is to blank out the text fields that are not
        associated with the data being entered.
    "*/
{
    NSString *aString = nil;
    int aTag = 0;
    
    SEN_ASSERT_CLASS(sender, @"NSTextField");
    
    aString = [sender stringValue];
    if ( isNotEmpty(aString) ) {
        // Select this entity in the matrix on the left if there
        // is a non-empty string in it.
        aTag = [sender tag];
        SEN_ASSERT_CONDITION((aTag >= 0));
        [selectionMatrix selectCellAtRow:aTag column:0];
        [self updateGuiForTag:aTag];
    }
}

- (IBAction)selectionMatrixChanged:(id)sender
    /*" This method is called by the matrix in the RestoreWorkAreaPanel.nib.
        Its function is to call the method -updateGuiForTag to blank out the 
        textfield that is not associated with this matrix position.
    "*/
{
    int aTag = 0;

    SEN_ASSERT_CLASS(sender, @"NSMatrix");
    
    aTag = [sender selectedTag];
    [self updateGuiForTag:aTag];
}

- (void)updateGuiForTag:(int)aTag
    /*" This method is called by other methods to blank out the textfield not 
        associated with the matrix position that has a tag equal to aTag.
    "*/
{
    NSString *aTagTitle = nil;
    NSString *aDateString = nil;    
    BOOL enableButton = NO;
    
    // NB: Be sure the tags in the RestoreWorkAreaPanel.nib for the
    // three positions in the matrix are set to 0 and 1 for the "Date:" and
    // "Tag:" and 3 for head.    
    // NB: Be sure the tags in the RestoreWorkAreaPanel.nib for the
    // two textfields are set to 0 and 1 for the "Date:" and
    // "Tag:".    
    SEN_ASSERT_CONDITION( ((aTag >= 0) && (aTag <= 3)) );

    [tagTitleTextField setTextColor:[NSColor textColor]];

    // Blank out the other entries.
    if ( aTag != 0 ) {
        [dateTextField setStringValue:@""];
    }
    if ( aTag != 1 ) {
        [tagTitleTextField setStringValue:@""];
    }
    
    // Update the buttons at the bottom of the panel.
    // Get the selected revision.
    enableButton = NO;
    aTagTitle = [self tagTitleFromTextField];
    aDateString = [self dateStringFromTextField];
    if ( isNotEmpty(aTagTitle) ) {
        // If the release tag is a branch then color it blue.
        if ( [self isTagTitleABranchTag:aTagTitle] == YES ) {
            [tagTitleTextField setTextColor:[NSColor blueColor]];
        }
        enableButton = YES;
    } else if ( isNotEmpty(aDateString) ) {
        enableButton = YES;
    } else if ( [selectionMatrix selectedTag] == 3 ) {
        enableButton = YES;
    }
    [actionButton setEnabled:enableButton];
}

- (BOOL)control:(NSControl *)aControl textShouldBeginEditing:(NSText *)theFieldEditor
    /*" This method is being used to select the correct row in the selection 
        matrix to the left of the "Date:" and "Tag:" textfields when the user 
        starts typing in those textfields.
    "*/
{
    int aTag = 0;

    aTag = [aControl tag];
    [selectionMatrix selectCellAtRow:aTag column:0];
    [self selectionMatrixChanged:selectionMatrix];
    return YES;
}

- (void)controlTextDidChange:(NSNotification *)aNotification
    /*" This method is being used to disable the action button at the botton of 
        the panel when the user deletes all the characters in one of the text
        fields named dateTextField or tagTitleTextField. The action button is the 
        NSButton named actionButton.
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
             (aControl == tagTitlePopUpButton) ) {
            [actionButton setEnabled:NO];
        }        
    }
}

- (void)updateGuiWithWorkAreaTags
    /*" This method fills the tags' pulldown button with the tags from the 
        repository. These tags were either just retrieved from the repository or 
        were already in this controller's cache. The title of the pulldown 
        button is set to "Existing Tags". Then the "Date:" and "Tag:" textfields 
        are set to their last known values which have also bee cached.
    "*/
{
    NSArray *sortedTags = nil;
    NSString *aTagTitle = nil;
    NSString *aDateString = nil;    
    NSAttributedString *anAttributedTitle = nil;
    NSMenuItem *anItem = nil;
    NSColor *txtColor = [NSColor blueColor];
    NSEnumerator *aCvsTagEnumerator = nil;
    CvsTag *aCvsTag = nil;
    NSDictionary *txtDict = nil;
    NSString *aTitle = nil;
    int anIndex = 0;
    
    sortedTags = [tagsDictionary objectForKey:@"SortedTagsKey"];
    txtDict = [NSDictionary dictionaryWithObjectsAndKeys:txtColor, 
                    NSForegroundColorAttributeName, nil];

    [tagTitlePopUpButton removeAllItems];
    [tagTitlePopUpButton addItemWithTitle:@"Existing Tags"];

    if ( isNotEmpty(sortedTags) ) {
        [tagTitlePopUpButton setEnabled:YES];
        aCvsTagEnumerator = [sortedTags objectEnumerator];
        while ( (aCvsTag = [aCvsTagEnumerator nextObject]) ) {
            aTitle = [aCvsTag tagTitle];
            [tagTitlePopUpButton addItemWithTitle:aTitle];
            anIndex = [tagTitlePopUpButton indexOfItemWithTitle:aTitle];
            anItem = (NSMenuItem *)[tagTitlePopUpButton itemAtIndex:anIndex];
            [anItem setRepresentedObject:aCvsTag];
            // Color it blue if it is a branch tag.
            if ( [aCvsTag isABranchTag] ) {
                anAttributedTitle = [[NSAttributedString alloc] 
                                                      initWithString:aTitle 
                                                          attributes:txtDict];  
                [anAttributedTitle autorelease];
                [anItem setAttributedTitle:anAttributedTitle];
            }
        }
    } else {
        [tagTitlePopUpButton setEnabled:NO];
    }

    // Reset last known values.
    aTagTitle = [tagsDictionary objectForKey:@"TagTitleKey"];
    if ( isNotEmpty(aTagTitle) ) {
        [tagTitleTextField setStringValue:aTagTitle];
        [self updateGuiForTag:[tagTitleTextField tag]];
    } else {
        aDateString = [tagsDictionary objectForKey:@"DateStringKey"];
        if ( isNotEmpty(aDateString) ) {
            [dateTextField setStringValue:aDateString];
            [self updateGuiForTag:[dateTextField tag]];
        }
    }
}

- (IBAction)tagSelectedFromPullDownButton:(id)sender
    /*" This method is called whenever the tags pulldown button has been 
        selected. This method then fills the "Tag:" textfield with whatever was 
        selected from the pulldown button. Then the method -resultsChanged: is 
        called to update the GUI.
    "*/
{
    NSString *aString = nil;
    
    SEN_ASSERT_CONDITION((sender == tagTitlePopUpButton));
    
    aString = [sender titleOfSelectedItem];
    if ( isNotEmpty(aString) ) {
        [tagTitleTextField setStringValue:aString];
        [self resultsChanged:tagTitleTextField];
    }
}

- (BOOL)isTagTitleABranchTag:(NSString *)aTagTitle
    /*" This method returns YES if aTagTitle is also a branch tag; otherwise 
        NO is returned.
    "*/
{
    NSArray *sortedTags = nil;
    NSEnumerator *aCvsTagEnumerator = nil;
    CvsTag *aCvsTag = nil;
    NSString *aTitle = nil;
    BOOL isTagTitleABranchTag = NO;
    
    if ( isNilOrEmpty(aTagTitle) ) return NO;
        
    // To determine if aTagTitle is a branch tag we find the CvsTag object
    // with the same title in the sortedTags array in the tagsDictionary.
    // We can then ask that CvsTag object if it is a branch.
    sortedTags = [tagsDictionary objectForKey:@"SortedTagsKey"];
    if ( isNotEmpty(sortedTags) ) {
        aCvsTagEnumerator = [sortedTags objectEnumerator];
        while ( (aCvsTag = [aCvsTagEnumerator nextObject]) ) {
            aTitle = [aCvsTag tagTitle];
            if ( [aTagTitle isEqualToString:aTitle] == YES ) {
                // Color it blue if it is a branch tag.
                if ( [aCvsTag isABranchTag] ) {
                    isTagTitleABranchTag = YES;
                }
                break;
            }
        }
    }
    return isTagTitleABranchTag;
}

- (IBAction)getDateTime:(id)sender
	/*" This method opens a drawer containing a calendar controller and a time 
		controller that will allow the user to set a date and time. The date and
		time will then be put into the correct format for use by cvs. This 
		object has to implement the method -setDateTime: in order to use this
		method.
	"*/
{
	NSDrawer *aDateTimeDrawer = nil;
	NSWindow *theMainWindow = nil;
	
	if ( dateTimeController == nil ) {
		dateTimeController = [[DateTimeController alloc] 
									initWithWindowNibName:@"DateTime"];
	}
	// Force the window to load with a -window message. Otherwise 
	// aDateTimeDrawer will be nil.
	(void)[dateTimeController window];
	[dateTimeController setParentController:self];
	theMainWindow = [sender window];
	SEN_ASSERT_NOT_NIL(theMainWindow);
	SEN_ASSERT_CLASS(theMainWindow, @"NSWindow");
	aDateTimeDrawer = [dateTimeController dateTimeDrawer];
	SEN_ASSERT_NOT_NIL(aDateTimeDrawer);
	[aDateTimeDrawer setParentWindow:theMainWindow];
	[aDateTimeDrawer open];
}

- (void)setDateTime:(NSCalendarDate *)aDateTime
	/*" This method is called by the class DateTimeController to set the date
		and time that a user selects using the drawer that the 
		DateTimeController opens. This drawer has a calendar controller and a 
		time controller that will allow the user to set a date and time.
	"*/
{	
    SEN_ASSERT_NOT_NIL(dateTextField);
    SEN_ASSERT_CLASS(dateTextField, @"NSTextField");
	[dateTextField setObjectValue:aDateTime];
	[self resultsChanged:dateTextField];
}


@end
