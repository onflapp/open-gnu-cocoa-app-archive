/* PXToolSwitcher */

#import <Foundation/NSObject.h>
#import <AppKit/NSNibDeclarations.h>

@class PXTool;
@class NSString;
@class NSColor;
@class NSColorWell;
@class NSImage;

extern NSString * PXToolDidChangeNotificationName;

typedef enum {
  PXPencilToolTag = 0,
  PXEraserToolTag,
  PXEyedropperToolTag,
  PXZoomToolTag,
  PXFillToolTag,
  PXLineToolTag,
  PXRectangularSelectionToolTag,
  PXMoveToolTag,
  PXRectangleToolTag,
  PXEllipseToolTag,
  PXMagicWandToolTag,
  PXLassoToolTag
} PXToolTag;



@interface PXToolSwitcher : NSObject
{
  id tools;
  IBOutlet id toolsMatrix;
  IBOutlet NSColorWell *colorWell;
@private 
  NSColor *_color;
  PXTool *_tool;
  PXTool *_lastTool;
  BOOL _locked;
}
- (id) init;
- (id) tool;

- (id) toolWithTag:(PXToolTag)tag;
- (PXToolTag)tagForTool:(id) aTool;
- (void)setIcon:(NSImage *) anImage forTool:(id)aTool;

//Manage color/colorWell
- (NSColor*) color;
- (void)setColor:aColor;

- (void)useTool:aTool;
- (void)useToolTagged:(PXToolTag)tag;

//Actions methods
- (IBAction)toolClicked:(id)sender;
- (IBAction)colorChanged:(id)sender;

//Events methods
- (void)keyDown:event;
- (void)optionKeyDown;
- (void)optionKeyUp;
- (void)shiftKeyDown;
- (void)shiftKeyUp;

- (void)checkUserDefaults;

- (void)requestToolChangeNotification;

@end
