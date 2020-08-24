/* Comparator.m created by stephane on Wed 29-Sep-1999 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "Comparator.h"
#import "CVLFile.h"
#import "CVLDelegate.h"
#import "NSArray_RevisionComparison.h"
#import "ResultsRepository.h"
#import <CVLOpendiffRequest.h>
#import <CvsTag.h>
#import <DateTimeController.h>
#import <SenFoundation/SenFoundation.h>
#import <AppKit/AppKit.h>


#define CURRENT_REVISION_STRING	@"Current"
#define CHOOSE_REVISION_STRING	@"Choose Revision..."
#define CHOOSE_TAG_STRING	@"Choose Tag..."


@interface Comparator(Private)
- (void) updateGUI;
@end

@implementation Comparator

static Comparator	*sharedInstance = nil;

+ (Comparator *) sharedComparator
{
    if(!sharedInstance)
        sharedInstance = [[self alloc] init];

    return sharedInstance;
}

- (id) init
{
    if ( (self = [self initWithWindowNibName:@"Comparator"]) ) {
        // Like CVLInspectorManager: suffers the same bugs
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(selectionChanged:) name:SenSelectionDidChangeNotification object:[(CVLDelegate *)[[NSApplication sharedApplication] delegate] globalSelection]];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resultsChanged:) name:@"ResultsChanged" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewerWillClose:) name:@"ViewerWillClose" object:nil];
        [self setWindowFrameAutosaveName:@"Comparisons"];
    }

    return self;
}

- (void) dealloc
{
    RELEASE(comparisonParameterDictionary);
    RELEASE(aCVLFile);
    [[NSNotificationCenter defaultCenter] removeObserver: self];
    
    [super dealloc];
}

- (void) windowDidLoad
{
    [super windowDidLoad];

    [self updateGUI];
}

- (void) comparisonForFile:(CVLFile *)aFile parameters:(NSDictionary *)parameterDictionary orderFront:(BOOL)orderFront
{
    if(![aFile isLeaf]){
        // We do not support comparison of directories (limited by CvsUpdateRequest)
        aFile = nil;
        parameterDictionary = nil;
	}
    [comparisonParameterDictionary autorelease];
    comparisonParameterDictionary = [parameterDictionary copyWithZone:[self zone]];
    ASSIGN(aCVLFile, aFile);

    if(orderFront || ([self isWindowLoaded] && [[self window] isVisible])){
        [self updateGUI];
        if(orderFront)
            [self showWindow:self];
    }
}

- (void) comparisonForFile:(CVLFile *)aFile parameters:(NSDictionary *)parameterDictionary
{
    [self comparisonForFile:aFile parameters:parameterDictionary orderFront:YES];
}

- (id) objectValueFromDateAsString:(NSString *)string
{
	return [NSCalendarDate dateWithString:string calendarFormat:@"%Y-%m-%dT%H:%M:%S%z"];
}

- (void) updateGUI
{
    NSDictionary	*aDict;
    NSString		*aString;
    NSArray			*versionDictionaries = [aCVLFile log];
    NSMutableArray	*values = [NSMutableArray arrayWithCapacity:[versionDictionaries count]];
    NSEnumerator	*anEnum;
    BOOL			enabled = (aCVLFile != nil);

    (void)[self window]; // Force loading of nib if necessary

    [leftRevisionPopup removeAllItems];
    [rightRevisionPopup removeAllItems];
    [ancestorRevisionPopup removeAllItems];
    [leftTagPopup removeAllItems];
    [rightTagPopup removeAllItems];
    [ancestorTagPopup removeAllItems];

    [leftMatrix setEnabled:enabled];
    [leftRevisionPopup setEnabled:enabled];
    [leftTagPopup setEnabled:enabled];
    [leftDateTextField setEnabled:enabled];
	[leftSetDateButton setEnabled:enabled];

    [rightMatrix setEnabled:enabled];
    [rightRevisionPopup setEnabled:enabled];
    [rightTagPopup setEnabled:enabled];
    [rightDateTextField setEnabled:enabled];
	[rightSetDateButton setEnabled:enabled];

	[self updateAncestorGUI];
	
    [mergeTextField setEnabled:enabled];
    [mergeChooserButton setEnabled:enabled];

    if(!enabled){
        [pathTextField setStringValue:@""];
        [leftDateTextField setObjectValue:nil];
        [rightDateTextField setObjectValue:nil];
        [ancestorDateTextField setObjectValue:nil];
        [mergeTextField setStringValue:@""];
        return;
    }

    [pathTextField setStringValue:[[aCVLFile path] stringByAbbreviatingWithTildeInPath]];

    anEnum = [[versionDictionaries sortedRevisionArrayWithKey:@"revision" ascendingOrder:NO] objectEnumerator];
    while ( (aDict = [anEnum nextObject]) ) {
        [values addObject:[aDict objectForKey:@"revision"]];
    }

	[leftRevisionPopup addItemWithTitle:CHOOSE_REVISION_STRING];
	[leftRevisionPopup addItemWithTitle:CURRENT_REVISION_STRING];
    [leftRevisionPopup addItemsWithTitles:values];
    [rightRevisionPopup addItemWithTitle:CHOOSE_REVISION_STRING];
    [rightRevisionPopup addItemWithTitle:CURRENT_REVISION_STRING];
    [rightRevisionPopup addItemsWithTitles:values];
    [ancestorRevisionPopup addItemWithTitle:CHOOSE_REVISION_STRING];
    [ancestorRevisionPopup addItemWithTitle:CURRENT_REVISION_STRING];
    [ancestorRevisionPopup addItemsWithTitles:values];

    [values removeAllObjects];
	
	[self updatePopupButtonWithWorkAreaTags:leftTagPopup];
	[self updatePopupButtonWithWorkAreaTags:rightTagPopup];
	[self updatePopupButtonWithWorkAreaTags:ancestorTagPopup];

    [leftMatrix selectCellAtRow:0 column:0];
    aString = [comparisonParameterDictionary objectForKey:@"LeftRevision"];
    if(aString)
        [leftRevisionPopup selectItemWithTitle:aString];
    else{
        [leftRevisionPopup selectItemAtIndex:0];
        aString = [comparisonParameterDictionary objectForKey:@"LeftTag"];
        if(aString){
            [leftTagPopup selectItemWithTitle:aString];
            [leftMatrix selectCellAtRow:1 column:0];
        }
        else{
            if([leftTagPopup numberOfItems] > 0)
                [leftTagPopup selectItemAtIndex:0];
            else{
                [[leftMatrix cellAtRow:1 column:0] setEnabled:NO];
                [leftTagPopup setEnabled:NO];
            }
            aString = [comparisonParameterDictionary objectForKey:@"LeftDate"];
            if(aString){
                [leftDateTextField setObjectValue:[self objectValueFromDateAsString:aString]];
                [leftMatrix selectCellAtRow:2 column:0];
            }
            else
                [leftDateTextField setObjectValue:nil];
        }
    }

    [rightMatrix selectCellAtRow:0 column:0];
    aString = [comparisonParameterDictionary objectForKey:@"RightRevision"];
    if(aString)
        [rightRevisionPopup selectItemWithTitle:aString];
    else{
        [rightRevisionPopup selectItemAtIndex:0];
        aString = [comparisonParameterDictionary objectForKey:@"RightTag"];
        if(aString){
            [rightTagPopup selectItemWithTitle:aString];
            [rightMatrix selectCellAtRow:1 column:0];
        }
        else{
            if([rightTagPopup numberOfItems] > 0)
                [rightTagPopup selectItemAtIndex:0];
            else{
                [[rightMatrix cellAtRow:1 column:0] setEnabled:NO];
                [rightTagPopup setEnabled:NO];
            }
            aString = [comparisonParameterDictionary objectForKey:@"RightDate"];
            if(aString){
                [rightDateTextField setObjectValue:[self objectValueFromDateAsString:aString]];
                [rightMatrix selectCellAtRow:2 column:0];
            }
            else
                [rightDateTextField setObjectValue:nil];
        }
    }

    [ancestorMatrix selectCellAtRow:0 column:0];
    aString = [comparisonParameterDictionary objectForKey:@"AncestorRevision"];
    if(aString){
        [ancestorRevisionPopup selectItemWithTitle:aString];
    }
    else{
        [ancestorRevisionPopup selectItemAtIndex:0];
        aString = [comparisonParameterDictionary objectForKey:@"AncestorTag"];
        if(aString){
            [ancestorTagPopup selectItemWithTitle:aString];
            [ancestorMatrix selectCellAtRow:1 column:0];
        }
        else{
            if([ancestorTagPopup numberOfItems] > 0)
                [ancestorTagPopup selectItemAtIndex:0];
            else{
                [[ancestorMatrix cellAtRow:1 column:0] setEnabled:NO];
                [ancestorTagPopup setEnabled:NO];
            }
            aString = [comparisonParameterDictionary objectForKey:@"AncestorDate"];
            if(aString){
                [ancestorDateTextField setObjectValue:[self objectValueFromDateAsString:aString]];
                [ancestorMatrix selectCellAtRow:2 column:0];
            }
            else
                [ancestorDateTextField setObjectValue:nil];
        }
    }

    aString = [comparisonParameterDictionary objectForKey:@"MergeFile"];
    if(aString)
        [mergeTextField setStringValue:[aString stringByAbbreviatingWithTildeInPath]];
    else
        [mergeTextField setStringValue:[[aCVLFile path] stringByAbbreviatingWithTildeInPath]];
	
	[self updateCompareButton];
}

- (NSString *) dateAsStringForTextField:(NSTextField *)textField
{
    if ( [textField objectValue] != nil ){
		// http://www.w3.org/TR/NOTE-datetime
		// ISO8601
		// e.g. YYYY-MM-DDThh:mm:ss.sTZD (eg 1997-07-16T19:20:30.45+01:00)
		return [(NSCalendarDate *)[textField objectValue] descriptionWithCalendarFormat:@"%Y-%m-%dT%H:%M:%S%z"];
    }
	return nil;
}

- (IBAction) compareVersions:(id)sender
{
    // Do comparison by launching opendiffRequest
    NSMutableDictionary	*currentParams = [NSMutableDictionary dictionary];
    CVLOpendiffRequest	*aRequest;
    NSString			*aString;

    switch([leftMatrix selectedRow]){
        case 0:
            if([leftRevisionPopup indexOfSelectedItem] > 1){
                aString = [leftRevisionPopup titleOfSelectedItem];
                [currentParams setObject:aString forKey:@"LeftRevision"];
            }
			break;
        case 1:
            aString = [leftTagPopup titleOfSelectedItem];
            if(aString)
                [currentParams setObject:aString forKey:@"LeftTag"];
			break;
        case 2:
            aString = [self dateAsStringForTextField:leftDateTextField];
            if([aString length] != 0)
                [currentParams setObject:aString forKey:@"LeftDate"];
			break;
    }

    switch([rightMatrix selectedRow]){
        case 0:
            if([rightRevisionPopup indexOfSelectedItem] > 1){
                aString = [rightRevisionPopup titleOfSelectedItem];
                [currentParams setObject:aString forKey:@"RightRevision"];
            }
            break;
        case 1:
            aString = [rightTagPopup titleOfSelectedItem];
            if(aString)
                [currentParams setObject:aString forKey:@"RightTag"];
            break;
        case 2:
            aString = [self dateAsStringForTextField:rightDateTextField];
            if([aString length] != 0)
                [currentParams setObject:aString forKey:@"RightDate"];
            break;
    }

    if([ancestorSwitch state]) {
        switch([ancestorMatrix selectedRow]){
            case 0:
                if([ancestorRevisionPopup indexOfSelectedItem] > 1){
                    aString = [ancestorRevisionPopup titleOfSelectedItem];
                    [currentParams setObject:aString forKey:@"AncestorRevision"];
                }
                break;
            case 1:
                aString = [ancestorTagPopup titleOfSelectedItem];
                if(aString && [aString length])
                    [currentParams setObject:aString forKey:@"AncestorTag"];
                    break;
            case 2:
                aString = [self dateAsStringForTextField:ancestorDateTextField];
                if([aString length] != 0)
                    [currentParams setObject:aString forKey:@"AncestorDate"];
                    break;
        }
	}
	aString = [mergeTextField stringValue];
    if([aString length] != 0)
        [currentParams setObject:aString forKey:@"MergeFile"];
    
    aRequest = [[CVLOpendiffRequest alloc] initWithFile:aCVLFile parameters:currentParams];
    [aRequest schedule];
    [aRequest release];
}

- (IBAction) choiceChanged:(id)sender
{
	NSString *aTitle = nil;
    int	aTag = 0;

	aTag = [sender tag];

	// Do not change the matrix if there was no selection for CVS tags.
	if( [sender respondsToSelector: @selector(selectedItem)] ) {
		aTitle = [[sender selectedItem] title];
		if ( [aTitle isEqualToString:CHOOSE_TAG_STRING] ) {
			[self updateCompareButton];
			return;
		}		
	}
	[self updateGUIForTag:aTag];
	[self updateCompareButton];
}

- (void) comparisonForPath:(NSString *)aPath
{
    CVLFile *aFile = nil;
    
    if(aPath) {
        aFile = (CVLFile *)[CVLFile treeAtPath:aPath];
        [self comparisonForFile:aFile parameters:nil orderFront:NO];
    } else {
        [self comparisonForFile:nil parameters:nil orderFront:NO];
    }
}

- (void) selectionChanged:(NSNotification *)aNotif
{
    if([[aNotif object] count] == 1)
        [self comparisonForPath:(NSString *)[[aNotif object] selectedObject]];
    else
        [self comparisonForPath:nil]; // We don't support multiselections
	
	[self updateCompareButton];
}

- (void) resultsChanged:(NSNotification *)notification
{
    if(![[self window] isVisible])
        return;
    
    if(aCVLFile && [[notification object] hasChanged]) {
		if([[[notification object] changedFiles] containsObject:aCVLFile]) {
			[self updateGUI];
		}
	}
}

- (void) viewerWillClose:(NSNotification *)notification
{
    [self selectionChanged:nil];
}

- (IBAction) showWindow:(id)sender
{
    NSArray	*someSelectedFiles = [[(CVLDelegate *)[[NSApplication sharedApplication] delegate] globalSelection] selectedObjects];
    
    [super showWindow:sender];
    if([someSelectedFiles count] == 1)
        [self comparisonForPath:[someSelectedFiles lastObject]];
    else
        [self comparisonForPath:nil]; // We don't support multiselections
	
	[self updateCompareButton];
}

- (void)updateCompareButton
	/*" This method takes care of enabling and disabling the Compare Button 
		based on which fields and/or popup buttons are filled and/or selected. 
		In principle the Compare Button should only be enabled when the panel 
		has been completed to a point that it makes sense to perform a comparison.
	"*/
{
    NSString			*aString;
	BOOL enabledCompareButton = NO;
	
	enabledCompareButton = (aCVLFile != nil);
	
	if ( enabledCompareButton == YES ) {
		switch ( [leftMatrix selectedRow] ) {
			case 0:
				if ( [leftRevisionPopup indexOfSelectedItem] == 0 ) {
					enabledCompareButton = NO;
				}
				break;
			case 1:
				aString = [leftTagPopup titleOfSelectedItem];
				if ( (aString != nil) && 
					 ([aString isEqualToString:CHOOSE_TAG_STRING] == YES) ) {
					enabledCompareButton = NO;
				}
					break;
			case 2:
				aString = [self dateAsStringForTextField:leftDateTextField];
				if([aString length] == 0) {
					enabledCompareButton = NO;
				}
					break;
		}		
	}
	
	if ( enabledCompareButton == YES ) {
		switch ( [rightMatrix selectedRow] ) {
			case 0:
				if ( [rightRevisionPopup indexOfSelectedItem] == 0 ) {
					enabledCompareButton = NO;
				}
				break;
			case 1:
				aString = [rightTagPopup titleOfSelectedItem];
				if ( (aString != nil) && 
					 ([aString isEqualToString:CHOOSE_TAG_STRING] == YES) ) {
					enabledCompareButton = NO;
				}
					break;
			case 2:
				aString = [self dateAsStringForTextField:rightDateTextField];
				if([aString length] == 0) {
					enabledCompareButton = NO;
				}
					break;
		}
	}
	
	if ( enabledCompareButton == YES ) {
		if([ancestorSwitch state]) {
			switch([ancestorMatrix selectedRow]){
				case 0:
					if ( [ancestorRevisionPopup indexOfSelectedItem] == 0 ) {
						enabledCompareButton = NO;
					}					
					break;
				case 1:
					aString = [ancestorTagPopup titleOfSelectedItem];
					if ( (aString != nil) && 
						 ([aString isEqualToString:CHOOSE_TAG_STRING] == YES) ) {
						enabledCompareButton = NO;
					}
						break;
				case 2:
					aString = [self dateAsStringForTextField:ancestorDateTextField];
					if([aString length] == 0) {
						enabledCompareButton = NO;
					}
						break;
			}
		}
	}
	
    [compareButton setEnabled:enabledCompareButton];
}

- (void)updateAncestorGUI
	/*" This method enables and disables the GUI elements related to the 
		ancestor. If the ancestorSwitch is off then all the ancestor GUI 
		elements are disabled and either cleared of data or set to initial 
		values.
	"*/
{
	BOOL enabled = NO;
	BOOL switchEnabled = NO;
	
	switchEnabled = (aCVLFile != nil);
	[ancestorSwitch setEnabled:switchEnabled];
	if ( switchEnabled == NO ) {
		[ancestorSwitch setState:NO];
	}
	
	enabled = [ancestorSwitch state];
	[ancestorMatrix setEnabled:enabled];
    [ancestorRevisionPopup setEnabled:enabled];
    [ancestorTagPopup setEnabled:enabled];
    [ancestorDateTextField setEnabled:enabled];
	[ancestorSetDateButton setEnabled:enabled];
	if(!enabled){
		[ancestorMatrix selectCellAtRow:0 column:0];
		if ( [ancestorRevisionPopup numberOfItems] > 0 ) {
			[ancestorRevisionPopup selectItemAtIndex:0];
		}
		if ( [ancestorTagPopup numberOfItems] > 0 ) {
			[ancestorTagPopup selectItemAtIndex:0];
		}
		[ancestorDateTextField setStringValue:@""];
    }
}

- (void)updateGUIForTag:(int)aTag
	/*" This method enables and disables the GUI elements related to the GUI 
		elements relating to the value in aTag. If aTag is 0, 1 or 2 then this 
		method updates the GUI elements for the lefthand version of the selected 
		file. If aTag is 10, 11 or 12 then this method updates the GUI elements 
		for the righthand version of the selected file. If aTag is 20, 21 or 22 
		then this method updates the GUI elements for the ancestor version of 
		the selected file. Here we mean by update that previous values or 
		selections are nullified when new values or selections are made.
	"*/
{
	if(aTag < 10) {
        [leftMatrix selectCellAtRow:aTag column:0];
		// Blank out the other entries.
		if ( aTag != 0 ) {
			[leftRevisionPopup selectItemAtIndex:0];
		}
		if ( aTag != 1 ) {
			[leftTagPopup selectItemAtIndex:0];
		}
		if ( aTag != 2 ) {
			[leftDateTextField setStringValue:@""];
		}		
    } else if(aTag < 20) {
        [rightMatrix selectCellAtRow:(aTag - 10) column:0];
		// Blank out the other entries.
		if ( aTag != 10 ) {
			[rightRevisionPopup selectItemAtIndex:0];
		}
		if ( aTag != 11 ) {
			[rightTagPopup selectItemAtIndex:0];
		}
		if ( aTag != 12 ) {
			[rightDateTextField setStringValue:@""];
		}				
    } else {
        [ancestorMatrix selectCellAtRow:(aTag - 20) column:0];
		// Blank out the other entries.
		if ( aTag != 20 ) {
			[ancestorRevisionPopup selectItemAtIndex:0];
		}
		if ( aTag != 21 ) {
			[ancestorTagPopup selectItemAtIndex:0];
		}
		if ( aTag != 22 ) {
			[ancestorDateTextField setStringValue:@""];
		}						
	}	
}

- (void)updatePopupButtonWithWorkAreaTags:(NSPopUpButton *)aTagTitlePopUpButton
    /*" This method fills the CVS tags popup button with the tags from the 
		CVLFile selected. The title of the popup button is set to "Choose Tag...". 
    "*/
{
    NSArray *someTags = nil;
    NSArray *sortedTags = nil;
    NSAttributedString *anAttributedTitle = nil;
    NSMenuItem *anItem = nil;
    NSColor *txtColor = [NSColor blueColor];
    NSEnumerator *aCvsTagEnumerator = nil;
    CvsTag *aCvsTag = nil;
    NSDictionary *txtDict = nil;
    NSString *aTitle = nil;
    int anIndex = 0;
    
	someTags = [aCVLFile tags];
	if ( someTags != nil ) {
		sortedTags = [someTags  sortedArrayUsingSelector:@selector(compare:)];
	} else {
		sortedTags = [NSArray array];
	}
	
    txtDict = [NSDictionary dictionaryWithObjectsAndKeys:txtColor, 
		NSForegroundColorAttributeName, nil];
	
    [aTagTitlePopUpButton removeAllItems];
    [aTagTitlePopUpButton addItemWithTitle:CHOOSE_TAG_STRING];
	
    if ( isNotEmpty(sortedTags) ) {
        aCvsTagEnumerator = [sortedTags objectEnumerator];
        while ( (aCvsTag = [aCvsTagEnumerator nextObject]) ) {
            aTitle = [aCvsTag tagTitle];
            [aTagTitlePopUpButton addItemWithTitle:aTitle];
            anIndex = [aTagTitlePopUpButton indexOfItemWithTitle:aTitle];
            anItem = (NSMenuItem *)[aTagTitlePopUpButton itemAtIndex:anIndex];
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
    }
}

- (IBAction) matrixSelectionChanged:(id)sender
    /*" This is an action method that gets called whenever the user selects a 
		different option in either the left version, the right version or the 
		ancestor version. The options refered to here are either the Revision, 
		Tag or Date. This method then updates the GUI to reflect this change.
    "*/
{
	int aTag = 0;
	
	SEN_ASSERT_CLASS(sender, @"NSMatrix");

	// The sender tag is either 0, 10 or 20 and the row is either 0, 1 or 2
	// hence aTag will be either 0, 1 or 2 or 10, 11 or 12 or 20, 21 or 22.
	// This is in accordance with what is expected by the method -updateGUIForTag:
	aTag = [sender tag] + [sender selectedRow];
	[self updateGUIForTag:aTag];
	[self updateCompareButton];
}


- (IBAction) useAncestorChanged:(id)sender
    /*" This is an action method that gets called whenever the user changes the 
		"Use Ancestor" checkbox. This method then updates the GUI to reflect 
		this change.
    "*/
{
	[self updateAncestorGUI];
	[self updateCompareButton];
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
		
	if ( sender == leftSetDateButton ) {
		targetDateTextField = leftDateTextField;
	} else if ( sender == rightSetDateButton ) {
		targetDateTextField = rightDateTextField;
	} else if ( sender == ancestorSetDateButton ) {
		targetDateTextField = ancestorDateTextField;
	} else {
		SEN_ASSERT_CONDITION_MSG((NO), ([NSString stringWithFormat:
			@"A sender \"%@\" should be one of leftDateTextField \"%@\"  or rightDateTextField \"%@\" or ancestorSetDateButton \"%@\" but it is not!", 
			sender, 
			leftDateTextField, rightDateTextField, ancestorSetDateButton]));
	}
	
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
    SEN_ASSERT_NOT_NIL(targetDateTextField);
    SEN_ASSERT_CLASS(targetDateTextField, @"NSTextField");
	[targetDateTextField setObjectValue:aDateTime];
	
	[self choiceChanged:targetDateTextField];
}

@end
