//
//  PXGradientBuilderController.h
//  Pixen-XCode
//
//  Created by Ian Henderson on 26.08.04.
//  Copyright 2004 Open Sword Group. All rights reserved.
//
#import <AppKit/AppKit.h>

@class PXPaletteSwitcher;

@interface PXGradientBuilderController : NSWindowController {
	IBOutlet NSTextField *nameField;
	IBOutlet NSColorWell *startColorWell;
	IBOutlet NSColorWell *endColorWell;
	IBOutlet NSTextField *colorsField;
	
	PXPaletteSwitcher *switcher;
}

- (void)beginSheetInWindow:(NSWindow *)window;

- initWithPaletteSwitcher:(PXPaletteSwitcher *)aSwitcher;

- (IBAction)create:sender;
- (IBAction)cancel:sender;

@end
