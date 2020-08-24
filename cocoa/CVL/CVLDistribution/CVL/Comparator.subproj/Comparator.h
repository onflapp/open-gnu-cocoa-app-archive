/* Comparator.h created by stephane on Wed 29-Sep-1999 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <AppKit/AppKit.h>


@class CVLFile;
@class NSTextField;
@class NSMatrix;
@class NSPopUpButton;
@class NSButton;
@class NSBox;
@class NSDictionary;
@class NSDateFormatter;
@class DateTimeController;


@interface Comparator : NSWindowController
{
    IBOutlet NSTextField	*pathTextField;
    IBOutlet NSMatrix		*leftMatrix;
    IBOutlet NSPopUpButton	*leftRevisionPopup;
    IBOutlet NSPopUpButton	*leftTagPopup;
    IBOutlet NSTextField	*leftDateTextField;
    IBOutlet NSMatrix		*rightMatrix;
    IBOutlet NSPopUpButton	*rightRevisionPopup;
    IBOutlet NSPopUpButton	*rightTagPopup;
    IBOutlet NSTextField	*rightDateTextField;
    IBOutlet NSButton		*ancestorSwitch;
    IBOutlet NSMatrix		*ancestorMatrix;
    IBOutlet NSPopUpButton	*ancestorRevisionPopup;
    IBOutlet NSPopUpButton	*ancestorTagPopup;
    IBOutlet NSTextField	*ancestorDateTextField;
    IBOutlet NSTextField	*mergeTextField;
    IBOutlet NSButton		*mergeChooserButton;
    IBOutlet NSButton		*compareButton;
    IBOutlet NSButton		*leftSetDateButton;
    IBOutlet NSButton		*rightSetDateButton;
    IBOutlet NSButton		*ancestorSetDateButton;
    NSDictionary			*comparisonParameterDictionary;
    CVLFile					*aCVLFile;
	DateTimeController		*dateTimeController;
	NSTextField				*targetDateTextField;
}

+ (Comparator *) sharedComparator;

- (void) comparisonForFile:(CVLFile *)aFile parameters:(NSDictionary *)parameterDictionary;
    /*
        ParameterDictionary: keys are evaluated in this order
        LeftRevision, LeftTag, LeftDate
        RightRevision, RightTag, RightDate
        AncestorRevision, AncestorTag, AncestorDate
        MergeFile
     */

- (IBAction) compareVersions:(id)sender;
- (IBAction) choiceChanged:(id)sender;
- (IBAction) matrixSelectionChanged:(id)sender;
- (IBAction) useAncestorChanged:(id)sender;
- (IBAction)getDateTime:(id)sender;

- (NSString *) dateAsStringForTextField:(NSTextField *)textField;
- (void)updatePopupButtonWithWorkAreaTags:(NSPopUpButton *)aTagTitlePopUpButton;
- (void)updateCompareButton;
- (void)updateAncestorGUI;
- (void)updateGUIForTag:(int)aTag;
- (void)setDateTime:(NSCalendarDate *)aDateTime;

@end
