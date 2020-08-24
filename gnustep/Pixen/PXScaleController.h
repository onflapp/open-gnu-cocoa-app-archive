//
//  PXScaleController.h
//  Pixen-XCode
//
//  Created by Ian Henderson on Thu Jun 10 2004.
//  Copyright (c) 2004 Open Sword Group. All rights reserved.
//

#import <AppKit/AppKit.h>

@class PXCanvasController;

@interface PXScaleController : NSWindowController {
	IBOutlet NSPopUpButton *algorithmButton;
	IBOutlet NSBox *scaleParameterView;
	
	NSSize newSize;
	
	IBOutlet NSButton *scaleProportionallyCheckbox;
	IBOutlet NSForm *newWidthForm;
	IBOutlet NSForm *newHeightForm;
	IBOutlet NSTextView *algorithmInfoView;
	
	PXCanvasController *canvasController;
	NSArray *algorithms;
}

- (void)scaleCanvasFromController:(PXCanvasController *)canvasController modalForWindow:(NSWindow *)theWindow;

- (IBAction)setAlgorithm:sender;
- (IBAction)updateToScalePropotionally:sender;
- (IBAction)synchronizeForms:sender;
- (IBAction)cancel:sender;
- (IBAction)scale:sender;

@end
