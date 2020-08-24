//
//  PXGridSettingsPrompter.h
//  Pixen-XCode
//
//  Created by Andy Matuschak on Thu Mar 18 2004.
//  Copyright (c) 2004 Open Sword Group. All rights reserved.
//

#import <AppKit/AppKit.h>

@interface NSObject(PXGridSettingsPrompterDelegate)
- (void)gridSettingsPrompter:aPrompter updatedWithSize:(NSSize)aSize color:color shouldDraw:(BOOL)shouldDraw;
@end

@interface PXGridSettingsPrompter : NSWindowController
{
    IBOutlet NSForm * sizeForm;
	IBOutlet id colorWell;
	IBOutlet id shouldDrawCheckBox;
	IBOutlet id colorLabel, sizeLabel;
	NSSize unitSize;
	id color;
    id delegate;
	BOOL shouldDraw;
}

- initWithSize:(NSSize)aSize color:aColor shouldDraw:(BOOL)shouldDraw;
- (void)setDelegate:newDelegate;
- (void)prompt;
- (IBAction)update:sender;
- (IBAction)useAsDefaults:sender;

@end
