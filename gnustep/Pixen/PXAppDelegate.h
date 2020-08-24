//
//  PXAppDelegate.h
//  Pixen-XCode
//
//  Created by Andy Matuschak on Tue Dec 09 2003.
//  Copyright (c) 2003 Open Sword Group. All rights reserved.
//

#import <Foundation/NSObject.h>

#import <AppKit/NSNibDeclarations.h>

#import "PXToolPaletteController.h"
#import "PXToolPropertiesController.h"
#import "PXColorPaletteController.h"
#import "PXInfoPanelController.h"

@interface PXAppDelegate: NSObject
{
	PXToolPaletteController *toolPaletteController;
	PXToolPropertiesController *leftToolPropertiesController;
	PXToolPropertiesController *rightToolPropertiesController;
	PXColorPaletteController *colorPaletteController;
	PXInfoPanelController *infoPanelController;
}

- (IBAction)showLeftToolProperties:(id) sender;
- (IBAction)showRightToolProperties:(id) sender;
- (IBAction)showColorPalette:(id) sender;
- (IBAction)showPreferences:(id) sender;

- (IBAction)showInfoPanel:(id) sender;
- (IBAction)donate:sender;
- (IBAction)discoverPixen:(id) sender;

@end

