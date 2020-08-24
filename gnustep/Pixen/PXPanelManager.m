//
//  PXPanelManager.m
//  Pixen-XCode
//
//  Created by Ian Henderson on 25.11.04.
//  Copyright 2004 Open Sword Group. All rights reserved.
//

#import "PXPanelManager.h"
#import "UKFeedbackProvider.h"
#import "PXColorPaletteController.h"
#import "PXToolPropertiesController.h"

@implementation PXPanelManager

PXPanelManager *sharedManager = nil;

+ sharedManager
{
	if (sharedManager == nil) {
		sharedManager = [[self alloc] init];
	}
	return sharedManager;
}

- init
{
	[super init];
	sharedManager = self;
	provider = [[UKFeedbackProvider alloc] init];
	return self;
}

- (void)dealloc
{
	[provider release];
	[super dealloc];
}

- (void)show:panel
{
	[panel makeKeyAndOrderFront:self];
}

- (void)hide:panel
{
	[panel performClose:self];
}

- (void)toggle:panel
{
	if ([panel isVisible]) {
		[self hide:panel];
	} else {
		[self show:panel];
	}
}

- (NSPanel *)leftToolPropertiesPanel
{
	return [[PXToolPropertiesController leftToolPropertiesController] propertiesPanel];
}

- (NSPanel *)rightToolPropertiesPanel
{
	return [[PXToolPropertiesController rightToolPropertiesController] propertiesPanel];
}

- (NSPanel *)colorPalettePanel
{
	return [[PXColorPaletteController sharedPaletteController] palettePanel];
}

- (IBAction)showFeedback:sender
{
	[provider orderFrontFeedbackWindow:self];
}

- (IBAction)showLeftToolProperties:sender
{
	[self show:[self leftToolPropertiesPanel]];
}

- (IBAction)toggleLeftToolProperties:sender
{
	[self toggle:[self leftToolPropertiesPanel]];
}

- (IBAction)showRightToolProperties:sender
{
	[self show:[self rightToolPropertiesPanel]];
}

- (IBAction)toggleRightToolProperties:sender
{
	[self toggle:[self rightToolPropertiesPanel]];
}

- (IBAction)showColorPalette:sender
{
	[self show:[self colorPalettePanel]];
}

- (IBAction)toggleColorPalette:sender
{
	[self toggle:[self colorPalettePanel]];
}

@end
