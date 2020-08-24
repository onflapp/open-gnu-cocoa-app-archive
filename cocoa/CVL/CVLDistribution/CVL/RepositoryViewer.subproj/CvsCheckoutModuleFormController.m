//
//  CvsCheckoutModuleFormController.m
//  CVL
//
//  Created by William Swats on Wed Jul 30 2003.
//  Copyright (c) 2003 Sente SA. All rights reserved.
//

#import "CvsCheckoutModuleFormController.h"

#import <SenFoundation/SenFoundation.h>
#import <DateTimeController.h>


@interface CvsCheckoutModuleFormController (Private)

- (void)updateGuiForTag:(int)aTag;

@end

@implementation CvsCheckoutModuleFormController


- (void)refreshControls
{
    NSMatrix *selectionMatrix = nil;
    NSTextField *theWorkAreaPathTextField = nil;
    NSString *theCurrentWorkAreaPath = nil;
    NSString *theDefaultWorkAreaPath = nil;

    theWorkAreaPathTextField = [self controlForKey:@"workAreaPath"];
    theCurrentWorkAreaPath = [theWorkAreaPathTextField stringValue];
    if ( isNilOrEmpty(theCurrentWorkAreaPath) ) {
        theDefaultWorkAreaPath = [[NSUserDefaults standardUserDefaults] 
                                objectForKey:@"DefaultWorkAreaPath"];
        if ( isNotEmpty(theDefaultWorkAreaPath) ) {
            [theWorkAreaPathTextField setStringValue:theDefaultWorkAreaPath];
        }
    }
    
    
    [super refreshControls];
    
    selectionMatrix = [self controlForKey:@"selectionMatrix"];
    SEN_ASSERT_NOT_NIL(selectionMatrix);
    SEN_ASSERT_CLASS(selectionMatrix, @"NSMatrix");    
    [self selectionMatrixChanged:selectionMatrix];
}

- (IBAction)resultsChanged:(id)sender
    /*" This method is called whenever one of the two text fields is changed.
    These two text fields are the date and release tag fields.
    Its function is to blank out the text fields that are not
    associated with the data being entered.
    "*/
{
    NSString *aString = nil;
    NSMatrix *selectionMatrix = nil;
    int aTag = 0;
    
    SEN_ASSERT_CLASS(sender, @"NSTextField");
    
    aString = [sender stringValue];
    if ( isNotEmpty(aString) ) {
        // Select this entity in the matrix on the left if there
        // is a non-empty string in it.
        selectionMatrix = [self controlForKey:@"selectionMatrix"];
        SEN_ASSERT_NOT_NIL(selectionMatrix);
        SEN_ASSERT_CLASS(selectionMatrix, @"NSMatrix");
        
        aTag = [sender tag];    
        [selectionMatrix selectCellAtRow:aTag column:0];
        [self updateGuiForTag:aTag];
    }
}

- (IBAction)selectionMatrixChanged:(id)sender
    /*" This method is called by the matrix in the CvsCheckoutModulePanel.nib.
    Its function is to blank out the text fields that are not
    associated with this matrix position.
    "*/
{
    int aTag = 0;
    
    SEN_ASSERT_CLASS(sender, @"NSMatrix");
    
    aTag = [sender selectedTag];
    [self updateGuiForTag:aTag];
}

- (void)updateGuiForTag:(int)aTag
    /*" This method is called by other methods to blank out the text fields not
        associated with this matrix position.
    "*/
{
    NSTextField *aDateTextField = nil;
    NSTextField *aReleaseTagTextField = nil;
    
    
    // NB: Be sure the tags in the CvsCheckoutModulePanel.nib for the
    // two text fields are set to 0 and 1 for the date and release tag.
    // NB: Be sure the tags in the CvsCheckoutModulePanel.nib for the
    // two positions in the matrix are set to 0 and 1 for the date,
    // release tag.        
    SEN_ASSERT_CONDITION( ((aTag >= 0) && (aTag <= 1)) );
    
    // Blank out the other entries.
    if ( aTag != 0 ) {
        aDateTextField = [self controlForKey:@"date"];
        SEN_ASSERT_NOT_NIL(aDateTextField);
        SEN_ASSERT_CLASS(aDateTextField, @"NSTextField");        
        [aDateTextField setStringValue:@""];
    }
    if ( aTag != 1 ) {
        aReleaseTagTextField = [self controlForKey:@"revision"];
        SEN_ASSERT_NOT_NIL(aReleaseTagTextField);
        SEN_ASSERT_CLASS(aReleaseTagTextField, @"NSTextField");                
        [aReleaseTagTextField setStringValue:@""];
    }    
}

- (void)controlTextDidBeginEditing:(NSNotification *)aNotification
    /*" This method is being used to update the interface by calling the method
-updateGuiForTag: as soon as the user starts to type in one of the text
    fields named date or releasetag.
    "*/
{
    id aControl = nil;
    NSMatrix *selectionMatrix = nil;
    NSTextField *aDateTextField = nil;
    NSTextField *aReleaseTagTextField = nil;
    int aTag = 0;
    
    aControl = [aNotification object];
    
    aDateTextField = [self controlForKey:@"date"];
    SEN_ASSERT_NOT_NIL(aDateTextField);
    SEN_ASSERT_CLASS(aDateTextField, @"NSTextField");
    
    aReleaseTagTextField = [self controlForKey:@"revision"];
    SEN_ASSERT_NOT_NIL(aReleaseTagTextField);
    SEN_ASSERT_CLASS(aReleaseTagTextField, @"NSTextField");                
    
    if ( (aControl == aDateTextField) ||
         (aControl == aReleaseTagTextField) ) {
        aTag = [aControl tag];
        [self updateGuiForTag:aTag];
        
        selectionMatrix = [self controlForKey:@"selectionMatrix"];
        SEN_ASSERT_NOT_NIL(selectionMatrix);
        SEN_ASSERT_CLASS(selectionMatrix, @"NSMatrix");                        
        [selectionMatrix selectCellAtRow:aTag column:0];
    }
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
	NSTextField *aDateTextField = nil;
        
    aDateTextField = [self controlForKey:@"date"];
    SEN_ASSERT_NOT_NIL(aDateTextField);
    SEN_ASSERT_CLASS(aDateTextField, @"NSTextField");
	[aDateTextField setObjectValue:aDateTime];
	[self resultsChanged:aDateTextField];
}


@end
