/* SenOpenPanelInspector.m created by ja on Wed 04-Mar-1998 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "SenOpenPanelInspector.h"
#ifndef RHAPSODY
#ifdef PANTHER
#import <SenFormControllerConnector.h>
#import <SenOpenPanelController.h>
#else /* Not PANTHER */
#import <SenPanels.subproj/SenFormControllerConnector.h>
#import <SenPanels.subproj/SenOpenPanelController.h>
#endif /* End PANTHER */
#else /* Not MACOSX */
#import <SenPanels/SenFormControllerConnector.h>
#import <SenPanels/SenOpenPanelController.h>
#endif /* End MACOSX */

@interface SenOpenPanelInspector (Private)
- (void)enableCanChooseGroup:(BOOL)flag;
@end

@implementation SenOpenPanelInspector
- (id)init
{
    if ( (self=[super init]) ) {
        [NSBundle loadNibNamed:@"SenOpenPanelInspector" owner:self];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [super dealloc];
}

- (void)awakeFromNib
{
    //    [super awakeFromNib];
}

- (BOOL)wantsButtons
{
    return NO;
}

- (void)chooseType:(id)sender
{
    [self enableCanChooseGroup:![[saveVsOpenRadio selectedCell] tag]];
    [self ok:sender];
}

- (void)enableCanChooseGroup:(BOOL)flag
{
    [allowsMultipleSelectionSwitch setEnabled:flag];
    [canChooseDirectoriesSwitch setEnabled:flag];
    [canChooseFilesSwitch setEnabled:flag];
}

- (void)revert:(id)sender
{
    [saveVsOpenRadio selectCellAtRow:[[self object] useSaveVsOpenPanel] column:0];
    [allowsMultipleSelectionSwitch setState:[[self object] allowsMultipleSelection]];
    [canChooseDirectoriesSwitch setState:[[self object] canChooseDirectories]];
    [canChooseFilesSwitch setState:[[self object] canChooseFiles]];
    [promptText setStringValue:[[self object] prompt]];
    [requiredFileTypeText setStringValue:[[self object] requiredFileType]];
    [titleText setStringValue:[[self object] title]];
    [treatsFilePackagesAsDirectoriesSwitch setState:[[self object] treatsFilePackagesAsDirectories]];

    [self enableCanChooseGroup:![[self object] useSaveVsOpenPanel]];

    [super revert:sender];
}

- (void)ok:(id)sender
{
    [[self object] setUseSaveVsOpenPanel:[[saveVsOpenRadio selectedCell] tag]];
    [[self object] setAllowsMultipleSelection:[allowsMultipleSelectionSwitch state]];
    [[self object] setCanChooseDirectories:[canChooseDirectoriesSwitch state]];
    [[self object] setCanChooseFiles:[canChooseFilesSwitch state]];
    [[self object] setPrompt:[promptText stringValue]];
    [[self object] setRequiredFileType:[requiredFileTypeText stringValue]];
    [[self object] setTitle:[titleText stringValue]];
    [[self object] setTreatsFilePackagesAsDirectories:[treatsFilePackagesAsDirectoriesSwitch state]];

    [super ok:sender];
}

@end
