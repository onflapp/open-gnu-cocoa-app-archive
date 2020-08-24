//
//  PXPreferencesController.m
//  Pixen-XCode
//
//  Created by Andy Matuschak on Wed Jun 09 2004.
//  Copyright (c) 2004 Open Sword Group. All rights reserved.
//

#import "PXPreferencesController.h"
#import "PXHotkeyFormatter.h"

@implementation PXPreferencesController

PXPreferencesController * preferences = nil;

+ sharedPreferencesController
{
    if(preferences == nil) { preferences = [[self alloc] init]; }
    return preferences;
}

- init
{
	return [super initWithWindowNibName:@"PXPreferences"];
}

- (void)awakeFromNib
{
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"PXCrosshairEnabled"]) {
		[crosshairColor setEnabled:YES];
	} else {
		[crosshairColor setEnabled:NO];
	}
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"PXAutosaveEnabled"]) {
		[autoupdateFrequency setEnabled:YES];
	} else {
		[autoupdateFrequency setEnabled:NO];
	}
	
	id enumerator = [[form cells] objectEnumerator], current;
	while (current = [enumerator nextObject])
	{
		[current setFormatter:[[[PXHotkeyFormatter alloc] init] autorelease]];
	}
}

- (IBAction)switchCrosshair:sender
{
	if ([sender state] == NSOnState) {
		[crosshairColor setEnabled:YES];
	} else {
		[crosshairColor setEnabled:NO];
	}
}

- (IBAction)switchAutoupdate:sender
{
	[self updateAutoupdate:sender];
	if ([sender state] == NSOnState) {
		[autoupdateFrequency setEnabled:YES];
	} else {
		[autoupdateFrequency setEnabled:NO];
	}
}

- (IBAction)updateAutoupdate:sender
{
	[[[NSDocumentController sharedDocumentController] documents] makeObjectsPerformSelector:@selector(rescheduleAutosave)];
}

- (void)controlTextDidChange:aNotification
{
	[[[NSDocumentController sharedDocumentController] documents] makeObjectsPerformSelector:@selector(rescheduleAutosave)];
}


@end
