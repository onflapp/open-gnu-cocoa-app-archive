//
//  PXPanelManager.h
//  Pixen-XCode
//
//  Created by Ian Henderson on 25.11.04.
//  Copyright 2004 Open Sword Group. All rights reserved.
//

#import <AppKit/AppKit.h>

@class UKFeedbackProvider;

@interface PXPanelManager : NSObject {
	UKFeedbackProvider *provider;
}

+ sharedManager;

- (IBAction)showFeedback:sender;

- (IBAction)toggleLeftToolProperties:sender;
- (IBAction)showLeftToolProperties:sender;

- (IBAction)toggleRightToolProperties:sender;
- (IBAction)showRightToolProperties:sender;

- (IBAction)toggleColorPalette:sender;
- (IBAction)showColorPalette:sender;

@end
