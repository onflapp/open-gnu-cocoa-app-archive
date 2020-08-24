//  PXCanvasController.h
//  Pixen
//
//  Created by Joe Osborn on Sat Sep 13 2003.
//  Copyright (c) 2003 Open Sword Group. All rights reserved.
//
#import <AppKit/AppKit.h>

@class PXCanvasView, PXCanvas;

@interface PXCanvasController : NSWindowController {
  PXCanvas *canvas;
  PXCanvasView *view;
  id scrollView;
  id zoomPercentageBox;
  id zoomStepper;
  id zoomView;
  id prompter;
  id resizePrompter;
  id scaleController;
  id gridSettingsPrompter;
  id toolbar;
    
  id previewController;
  id layerController;
  id backgroundController;
  NSPoint initialPoint;
  BOOL downEventOccurred;
  BOOL usingControlKey;
	
  id window;
  id printView;
}

- (PXCanvasView *)view;
- (PXCanvas *)canvas;
- (void)setCanvas:aCanvas;
- (void)setColor:aColor;
- (void)setLayers:layers fromLayers:oldLayers;

- (IBAction)toggleLayersDrawer: (id) sender;
- (IBAction)newLayer: (id) sender;
- (IBAction)deleteLayer: (id) sender;
- (IBAction)mergeDown: (id) sender;
- (IBAction)promoteSelection: (id) sender;
- (IBAction)flipLayerHorizontally: (id) sender;
- (IBAction)flipLayerVertically: (id) sender;
- (IBAction)duplicateLayer: (id) sender;

- (IBAction)nextLayer: (id) sender;
- (IBAction)previousLayer: (id) sender;

- (IBAction)showBackgroundInfo: (id) sender;
- (IBAction)showPreviewWindow: (id) sender;
- (IBAction)togglePreviewWindow: (id) sender;
- (IBAction)toggleLeftToolProperties: (id) sender;
- (IBAction)toggleRightToolProperties: (id) sender;
- (IBAction)showGridSettingsPrompter: (id) sender;
- (IBAction)resizeCanvas: (id) sender;
- (IBAction)scaleCanvas: (id) sender;
- (IBAction)zoomIn: (id) sender;
- (IBAction)zoomOut: (id) sender;
- (IBAction)zoomStandard: (id) sender;
- (IBAction)zoomPercentageChanged: (id) sender;
- (IBAction)zoomStepperStepped: (id) sender;
- (IBAction)zoomToFit: (id) sender;

- (IBAction)increaseOpacity: (id) sender;
- (IBAction)decreaseOpacity: (id) sender;

- (void)zoomInOnCanvasPoint:(NSPoint)point;
- (void)zoomOutOnCanvasPoint:(NSPoint)point;
- (void)layerSelectionDidChange: (NSNotification *) aNotification;
- (void)canvasSizeDidChange: (NSNotification *) aNotification;
- (void)updatePreview;
- (void)updateCanvasSize;

-(NSUndoManager *) undoManager;
- (void)rightMouseDown:(NSEvent *) event;
- (void)rightMouseDragged:(NSEvent *) event;
- (void)rightMouseUp:(NSEvent *) event;


@end
