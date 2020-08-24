//
//  PXBackgroundController.h
//  Pixen-XCode
//
//  Created by Joe Osborn on Sun Oct 26 2003.
//  Copyright (c) 2003 Open Sword Group. All rights reserved.
//
#import <Foundation/NSObject.h>
#import <AppKit/NSNibDeclarations.h>

@class NSButton;
@class NSPanel;
@class NSPopUpButton;
@class NSView;

@interface PXBackgroundController : NSObject
{
  id delegate;
  id mainBackground;
  id alternateBackground;
  IBOutlet NSPopUpButton *mainMenu;
  IBOutlet NSPopUpButton *alternateMenu;
  IBOutlet NSView * mainConfigurator;
  IBOutlet NSView * alternateConfigurator;
  IBOutlet NSButton * alternateCheckbox;
  IBOutlet NSPanel *panel;
  BOOL usesAlternateBackground;
  id namePrompter;
}
+ backgroundNamed:aName;
- (void)useBackgroundsOf:(id)aCanvas;
- (void)setDelegate:(id)anObject;

//Actions methods
- (IBAction)useCurrentBackgroundsAsDefaults:(id)sender;
- (IBAction)useAlternateBackgroundCheckboxClicked:(id)sender;
- (IBAction)selectMainBackground:(id)sender;
- (IBAction)selectAlternateBackground:(id)sender;

//Accessor
-(NSPanel *) backgroundPanel;

@end

//PXNamePrompter delegate methods
@interface PXBackgroundController ( NamePrompterDelegate )
- (void)prompter:aPrompter didFinishWithName:name context:contextObject;
- (void)prompter:aPrompter didCancelWithContext:contextObject;
@end




@interface NSObject(PXBackgroundControllerDelegate)
- (void)setMainBackground:aBackground;
- (void)setAlternateBackground:aBackground;
- (void)backgroundChanged:aNotification;
@end
