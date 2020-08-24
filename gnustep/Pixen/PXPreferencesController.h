//
//  PXPreferencesController.h
//  Pixen-XCode
//
//  Created by Andy Matuschak on Wed Jun 09 2004.
//  Copyright (c) 2004 Open Sword Group. All rights reserved.
//

#import <AppKit/AppKit.h>


@interface PXPreferencesController : NSWindowController
{
	IBOutlet id crosshairColor;
	IBOutlet id autoupdateFrequency;
	IBOutlet id form;
}

+ sharedPreferencesController;
- (IBAction)switchCrosshair:sender;
- (IBAction)switchAutoupdate:sender;
- (IBAction)updateAutoupdate:sender;

@end
