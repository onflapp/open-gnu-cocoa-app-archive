/* PXToolPaletteController */

#import <Foundation/NSObject.h>
#import <AppKit/NSNibDeclarations.h>
@class PXToolSwitcher;
@class NSButton;
@class NSEvent;
@class NSPanel;


@interface PXToolPaletteController: NSObject
{
  IBOutlet NSPanel *panel;
  IBOutlet PXToolSwitcher *leftSwitcher;
  IBOutlet PXToolSwitcher *rightSwitcher;
  IBOutlet id minimalView;
  IBOutlet id rightSwitchView;
  IBOutlet NSButton *triangle;

  //Private ??
  unsigned int keyMask;
}

//singleton
+(id) sharedToolPaletteController;

//Action method
- (IBAction)disclosureClicked:sender;

//Events methods
- (void)keyDown:event;
- (BOOL)keyWasDown:(unsigned int)mask;
- (BOOL)isMask:(unsigned int)newMask upEventForModifierMask:(unsigned int)mask;
- (BOOL)isMask:(unsigned int)newMask downEventForModifierMask:(unsigned int)mask;
- (void)flagsChanged:(NSEvent *)theEvent;

//Accessor methods
-(id) leftTool;
-(id) rightTool;
-(PXToolSwitcher *) leftSwitcher;
-(PXToolSwitcher *) rightSwitcher;
-(NSPanel *) toolPanel;

@end
