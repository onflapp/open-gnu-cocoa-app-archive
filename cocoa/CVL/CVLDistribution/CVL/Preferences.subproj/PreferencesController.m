/* PreferencesController.m created by ja on Thu 21-Aug-1997 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "PreferencesController.h"
#import <SenFoundation/SenFoundation.h>
#import <SenStringArrayBrowserController.h>


@implementation PreferencesController
- show: sender
{
    NSUserDefaults *theUserDefaults = nil;
    
    theUserDefaults = [NSUserDefaults standardUserDefaults];
    [panel makeKeyAndOrderFront: self];
    //  [pathsController setStringArrayValue:[theUserDefaults stringArrayForKey:@"UnixPaths"]];
    [cvsPathTextField setObjectValue:[theUserDefaults stringForKey:@"CVSPath"]];
    [maxParallelRequestsField setIntValue:[theUserDefaults integerForKey:@"MaxParallelRequestsCount"]];
    [opendiffUnixPathField setObjectValue:[theUserDefaults stringForKey:@"OpendiffPath"]];
//    [showRepositoryFilesSwitch setState:[theUserDefaults boolForKey:@"ShowRepositoryFiles"]];
    [startupOpenSwitch setState:[theUserDefaults boolForKey:@"ShowBrowsers"]];
    [cvsTemplateUseSwitch setState:[theUserDefaults boolForKey:@"UseCvsTemplates"]];
    [cvsTemplateFilteringSwitch setState:[theUserDefaults boolForKey:@"FilterCvsTemplate"]];
    [alertTimeBeepButton setState:[theUserDefaults boolForKey:@"AlertTimeBeep"]];
    [alertTimeDisplayButton setState:[theUserDefaults boolForKey:@"AlertTimeDisplay"]];
    [alertTimeIntervalFormCell setStringValue:[theUserDefaults stringForKey:@"AlertTimeInterval"]];
    [cvsEditorsAndWatchersEnabledButton setState:[theUserDefaults boolForKey:@"CvsEditorsAndWatchersEnabled"]];
    [overrideCvsWrappersFileInHomeDirectoryButton setState:[theUserDefaults boolForKey:@"OverrideCvsWrappersFileInHomeDirectory"]];
    [displayCvsErrorsButton setState:[theUserDefaults boolForKey:@"DisplayCvsErrors"]];
    [defaultWorkAreaPathTextField setObjectValue:[theUserDefaults stringForKey:@"DefaultWorkAreaPath"]];

    [self featuresChanged:nil];
    
    return self;
}

- (IBAction)save:sender
{
    NSUserDefaults *theUserDefaults = nil;
    
    // This next bit of code prevents the user from saving if any of the input
    // fields are in the process of editing.
	if ([panel makeFirstResponder:panel]) {
		// All fields are now valid; it’s safe to use fieldEditor:forObject:
        // to claim the field editor.
	} else {
		// Force first responder to resign.
		[panel endEditingFor:nil];
	}
	    
    theUserDefaults = [NSUserDefaults standardUserDefaults];    
    //  [theUserDefaults setObject:[pathsController stringArrayValue] forKey:@"UnixPaths"];
    [theUserDefaults setObject:[cvsPathTextField stringValue] forKey:@"CVSPath"];
    [theUserDefaults setInteger:[maxParallelRequestsField intValue] forKey:@"MaxParallelRequestsCount"];
    [theUserDefaults setObject:[opendiffUnixPathField stringValue] forKey:@"OpendiffPath"];
//    [theUserDefaults setBool:[showRepositoryFilesSwitch state] forKey:@"ShowRepositoryFiles"];
    [theUserDefaults setBool:[startupOpenSwitch state] forKey:@"ShowBrowsers"];
    [theUserDefaults setBool:[cvsTemplateUseSwitch state] forKey:@"UseCvsTemplates"];
    [theUserDefaults setBool:[cvsTemplateFilteringSwitch state] forKey:@"FilterCvsTemplate"];
    [theUserDefaults setBool:[alertTimeBeepButton state] forKey:@"AlertTimeBeep"];
    [theUserDefaults setBool:[alertTimeDisplayButton state] forKey:@"AlertTimeDisplay"];
    [theUserDefaults setObject:[alertTimeIntervalFormCell stringValue] forKey:@"AlertTimeInterval"];
    [theUserDefaults setBool:[cvsEditorsAndWatchersEnabledButton state] forKey:@"CvsEditorsAndWatchersEnabled"];
    [theUserDefaults setBool:[overrideCvsWrappersFileInHomeDirectoryButton state] forKey:@"OverrideCvsWrappersFileInHomeDirectory"];
    [theUserDefaults setBool:[displayCvsErrorsButton state] forKey:@"DisplayCvsErrors"];
    [theUserDefaults setObject:[defaultWorkAreaPathTextField stringValue] forKey:@"DefaultWorkAreaPath"];

    [theUserDefaults synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"PreferencesChanged" object:self];
    [self cancel:nil];
}

- hide: sender
{
    if (panel)
        [panel orderOut: self];
    return self;
} // hide:

- (IBAction)cancel:(id)sender
{
    // This next bit of code cleans up the value of the input fields if any of the input
    // fields are in the process of editing.
    if ( isEditingControl != nil ) {
        NSCell *theSelectedCell = nil;
        
        if ( [isEditingControl respondsToSelector:@selector(selectedCell)] ) {
            theSelectedCell = [isEditingControl selectedCell];
            [theSelectedCell setObjectValue:previousObjectValue];
            SEN_ASSERT_NOT_NIL(panel);
            if ( [panel makeFirstResponder:panel] == YES ) {
                // All fields are now valid, proceed.
            } else {
                // Force first responder to resign.
                [panel endEditingFor:isEditingControl];
            }
        } else {
            NSString *aMsg = [NSString stringWithFormat:
                @"The control \"%@\" does not respond to the selector -selectedCell. We have made no error reporting provision for this control.", 
                isEditingControl];
            SEN_LOG(aMsg);            
        }                   
        isEditingControl = nil;
        ASSIGN(previousObjectValue, nil);
    }
    
    if ( panel != nil ) [panel orderOut: self];
}

- (void)awakeWithProperties:(NSDictionary *)someProperties
{
     if ([[someProperties objectForKey:@"autosaveFrame"] isEqual:@"YES"]) {
         // Thank you to Tom Hageman <trh@xs4all.nl> for this feature
         [panel setFrameAutosaveName:[someProperties objectForKey:@"nib"]];
     }
}

- (BOOL)control:(NSControl *)aControl didFailToFormatString:(NSString *)aString errorDescription:(NSString *)anError
    /*" This method allows us to present an error panel to user if he 
        types in an entry that is below the minimum or above the maximum set
        in a formatter.
    "*/
{
    NSString *aTitle = nil;
    NSString *aMessage = nil;
    NSString *aCellTitle = nil;
    NSNumberFormatter *aFormatter = nil;
    NSNumber *aMinimum = nil;
    NSNumber *aMaximum = nil;
    NSNumber *aNotANumber = nil;
    NSCell *theSelectedCell = nil;
    
    SEN_ASSERT_NOT_NIL(aControl);
    
    if ( [aControl respondsToSelector:@selector(selectedCell)] ) {
        theSelectedCell = [aControl selectedCell];
        aFormatter = [theSelectedCell formatter];
        SEN_ASSERT_NOT_NIL(aFormatter);
        aCellTitle = [theSelectedCell title];
        aNotANumber = [NSDecimalNumber notANumber];
        aMinimum = [aFormatter minimum];
        if ( [aMinimum compare:aNotANumber] == NSOrderedSame ) aMinimum = nil;
        aMaximum = [aFormatter maximum];
        if ( [aMaximum compare:aNotANumber] == NSOrderedSame ) aMaximum = nil;
        aTitle = [NSString stringWithFormat:
            @"Formatting Error for\"%@\"", aCellTitle];
        if ( (aMinimum != nil) && (aMaximum != nil) ) {
            aMessage = [NSString stringWithFormat:
                @"The input string \"%@\" had the following error.\n%@\nThe minimum for this entry is %@ and the maximum is %@.",
                aString, anError, aMinimum, aMaximum];            
        } else if ( aMinimum != nil ) {
            aMessage = [NSString stringWithFormat:
                @"The input string \"%@\" had the following error.\n%@\nThe minimum for this entry is %@ and has no maximum.",
                aString, anError, aMinimum];     
        } else if ( aMaximum != nil ) {
            aMessage = [NSString stringWithFormat:
                @"The input string \"%@\" had the following error.\n%@\nThe maximum for this entry is %@ and has no minimum.",
                aString, anError, aMaximum];                        
        } else {
            aMessage = [NSString stringWithFormat:
                @"The input string \"%@\" had the following error.\n%@\nThere is no maximum nor minimum for this entry.",
                aString, anError, aMaximum];
        }
        (void)NSRunAlertPanel(aTitle, aMessage, nil, nil, nil);                
    } else {
        NSString *aMsg = [NSString stringWithFormat:
            @"The control \"%@\" does not respond to the selector -selectedCell. We have made no error reporting provision for this control.", 
            aControl];
        SEN_LOG(aMsg);
    }
    return NO;
}

- (BOOL)control:(NSControl *)control textShouldBeginEditing:(NSText *)fieldEditor
    /*" This a delegate method of NSControl. It is being used here to capture
        the control being edited. Then we can disallow the user to
        cancel while this control is being edited.
    
        For more information see also #{-control:textShouldEndEditing:}
    "*/
{
    NSCell *theSelectedCell = nil;

    ASSIGN(previousObjectValue, nil);
    isEditingControl = control;
    if ( [isEditingControl respondsToSelector:@selector(selectedCell)] ) {
        theSelectedCell = [isEditingControl selectedCell];
        ASSIGN(previousObjectValue, [theSelectedCell objectValue]);
    } else {
        NSString *aMsg = [NSString stringWithFormat:
            @"The control \"%@\" does not respond to the selector -selectedCell. We have made no error reporting provision for this control.", 
            isEditingControl];
        SEN_LOG(aMsg);            
    }                   
    
    return YES;
}

- (BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor
    /*" This a delegate method of NSControl. It is being used here to uncapture
        the control being edited. Then we can allow the user to 
        cancel after this control has been fully edited.

        For more information see also #{-control:textShouldBeginEditing:}
    "*/
{
    isEditingControl = nil;
    ASSIGN(previousObjectValue, nil);
    return YES;
}

- (IBAction)cvsEditorsAndWatchersEnabledButtonChanged:(id)sender
{
    NSString *aTitle = nil;
    NSString *aMessage = nil;

    aTitle = [NSString stringWithFormat:@"CVL Preferences -- Editors and Watchers"];
    aMessage = [NSString stringWithFormat:
        @"The CVL application will have to be restarted for the change in the CvsEditorsAndWatchersEnabled preference to take effect."];
    (void)NSRunAlertPanel(aTitle, aMessage, nil, nil, nil);        
}

- (IBAction)overrideCvsWrappersFileInHomeDirectoryButtonChanged:(id)sender
	/*" This action method is called when the user clicks on the enabling 
		checkbox whose label is "Override the .cvswrappers file in the user's 
		home directory with per repository .cvswrapper files." This method will 
		then put up an user alert panel explaining what this preference does. 
		This is its only function.
	"*/
{
	NSUserDefaults *theUserDefaults = nil;

	// Only display info message on enabling.
	if ( [sender state] == YES ) {
		NSString *aTitle = nil;
		NSString *aMessage = nil;
		
		aTitle = [NSString stringWithFormat:@"CVL Preferences -- CVS Wrappers"];
		aMessage = [NSString stringWithFormat:
			@"This preference means that each of the repositories will use the .cvswrappers file in their respective CVSROOT directories. This is accomplished by making the directories in ~/Library/Application Support/CVL/Repositories the HOME directory for each of the repositories in your Repository Viewer. Links to the cvspass, .cvsrc and .cvsignore files in your real HOME directory will also be added to these CVS HOME directories. Note: CVS Wrappers are not supported in the newer versions of CVS and their use is discouraged. However if you have some old repostories that use cvswrappers and some new ones that do not then this feature should help."];
		(void)NSRunAlertPanel(aTitle, aMessage, nil, nil, nil);        		
	}
	// Reset the warnings for a local .cvswrappers file
	theUserDefaults = [NSUserDefaults standardUserDefaults];	
	[theUserDefaults setBool:NO forKey:@"DoNotShowAgainFirstInstance"];
	[theUserDefaults setBool:NO forKey:@"DoNotShowAgainSecondInstance"];
}

- (IBAction)featuresChanged:(id)sender
    /*" This is an action method that updates the Features tab view whenever
        the user changes a preference that effects the display of said 
        preferences.
    "*/
{
    // Update the CVS template box in the Features tab view.
    if( [cvsTemplateUseSwitch state] == YES ) {
        [cvsTemplateFilteringSwitch setEnabled:YES];
    } else {
        [cvsTemplateFilteringSwitch setEnabled:NO];
    }
}


@end
