//  PXCanvasController.m
//  Pixen
//
//  Created by Joe Osborn on Sat Sep 13 2003.
//  Copyright (c) 2003 Open Sword Group. All rights reserved.
//

#import "PXCanvasController.h"
#import "PXCanvas.h"
#import "PXCanvasView.h"
#import "PXImage.h"
#import "PXImageSizePrompter.h"
#import "PXCanvasResizePrompter.h"
#import "PXGridSettingsPrompter.h"
#import "PXTool.h"
#import "PXToolPaletteController.h"
#import "PXInfoPanelController.h"
#import "PXBackgroundController.h"
#import "PXPreviewController.h"
#import "PXLayerController.h"
#import "PXGrid.h"
#import "PXColorPaletteController.h"
#import "PXScaleController.h"
#import "PXDocument.h"
#import "PXPanelManager.h"

//Taken from a man calling himself "BROCK BRANDENBERG" who is here to save the day.
#import "SBCenteringClipView.h"

//Taken from a man calling himself "M. Uli Kusterer", who is totally not saving the day adequately (but we love him anyway).
#import "UKFeedbackProvider.h"

#ifndef __COCOA__
#include "math.h"
#import "NSArray_DeepMutableCopy.h"
#endif

@implementation PXCanvasController

- view
{
    return view;
}

- init
{
	[super initWithWindowNibName:@"PXDocument"];
	prompter = [[PXImageSizePrompter alloc] init];
	resizePrompter = [[PXCanvasResizePrompter alloc] init];
	previewController = [PXPreviewController sharedPreviewController];
	backgroundController = [[PXBackgroundController alloc] init];
	scaleController = [[PXScaleController alloc] init];
	[backgroundController setDelegate:self];
	[[NSNotificationCenter defaultCenter] addObserver:self
					      selector:@selector(canvasSizeDidChange:) 
					      name:PXCanvasSizeChangedNotificationName 
					      object:nil];

	return self;
}

- (void)awakeFromNib
{
	toolbar = [[NSToolbar alloc] initWithIdentifier:@"PXDocumentToolbar"];
	[toolbar setDelegate:self];
	[toolbar setAllowsUserCustomization:YES];
	[toolbar setAutosavesConfiguration:YES];
#ifndef __COCOA__
	[zoomPercentageBox setEditable: YES];
	[zoomPercentageBox setEnabled:YES];
	[zoomPercentageBox setUsesDataSource:NO];
	[zoomPercentageBox setNumberOfVisibleItems:10];
	[zoomPercentageBox setCompletes:NO];
#endif
	
	[[self window] setToolbar:toolbar];
	[[self window] setAcceptsMouseMovedEvents:YES];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	if([[backgroundController backgroundPanel] isVisible])
	  { 
	    [[backgroundController backgroundPanel] performClose:self];
	  }
	[backgroundController release];
	if([[prompter window] isVisible]) 
	  {
	    [prompter close]; 
	  }
	[prompter release];
	[resizePrompter release];
	[layerController release];
	[toolbar release];
	[super dealloc];
}

- (IBAction)increaseOpacity:sender
{
	id switcher = [[PXToolPaletteController sharedToolPaletteController] leftSwitcher];
	[switcher setColor:[[switcher color] colorWithAlphaComponent:[[switcher color] alphaComponent] + 0.1f]];
}

- (IBAction)decreaseOpacity:sender
{
	id switcher = [[PXToolPaletteController sharedToolPaletteController] leftSwitcher];
	[switcher setColor:[[switcher color] colorWithAlphaComponent:[[switcher color] alphaComponent] - 0.1f]];
}

- (IBAction)duplicateDocument:sender
{
	id newDocument = [[NSDocumentController sharedDocumentController] makeUntitledDocumentOfType:@"Pixen Image"];
	id newCanvas = [canvas copy];
	[newDocument setValue:newCanvas forKey:@"canvas"];
	[newDocument makeWindowControllers];
	[[NSDocumentController sharedDocumentController] addDocument:newDocument];
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar 
     itemForItemIdentifier:(NSString *)itemIdentifier
 willBeInsertedIntoToolbar:(BOOL)flag
{
  NSToolbarItem *item = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
	
  if ([itemIdentifier isEqualToString:@"PXBackgroundConfigurator"])
    {
      [item setLabel:NSLocalizedString(@"BACKGROUND_LABEL", @"Background Label")];
      [item setPaletteLabel:[item label]];
      [item setToolTip:NSLocalizedString(@"BACKGROUND_TOOLTIP", @"Background Tooltip")];
      [item setTarget:self];
      [item setAction:@selector(showBackgroundInfo:)];
      [item setImage:[NSImage imageNamed:@"bgconf"]];
    }
  else if ([itemIdentifier isEqualToString:@"PXLayerDrawer"])
    {
      [item setLabel:NSLocalizedString(@"LAYERS_LABEL", @"Layers Label")];
      [item setPaletteLabel:[item label]];
      [item setToolTip:NSLocalizedString(@"LAYERS_TOOLTIP", @"Layers Tooltip")];
      [item setTarget:self];
      [item setAction:@selector(toggleLayersDrawer:)];
      [item setImage:[NSImage imageNamed:@"layerdrawer"]];
    }
  else if ([itemIdentifier isEqualToString:@"PXPreview"])
    {
      [item setLabel:NSLocalizedString(@"PREVIEW_LABEL", @"Preview Label")];
      [item setPaletteLabel:[item label]];
      [item setToolTip:NSLocalizedString(@"PREVIEW_TOOLTIP", @"Preview Tooltip")];
      [item setTarget:self];
      [item setAction:@selector(togglePreviewWindow:)];
      [item setImage:[NSImage imageNamed:@"preview"]];
    }
  else if ([itemIdentifier isEqualToString:@"PXToolProperties"])
    {
      [item setLabel:NSLocalizedString(@"TOOL_PROPERTIES_LABEL", @"Tool Properties Label")];
      [item setPaletteLabel:[item label]];
      [item setToolTip:NSLocalizedString(@"TOOL_PROPERTIES_TOOLTIP", @"Tool Properties Tooltip")];
      [item setTarget:self];
      [item setAction:@selector(toggleLeftToolProperties:)];
      [item setImage:[NSImage imageNamed:@"toolproperties"]];
    }
  else if ([itemIdentifier isEqualToString:@"PXGrid"])
    {
      [item setLabel:NSLocalizedString(@"GRID_LABEL", @"Grid Label")];
      [item setPaletteLabel:[item label]];
      [item setToolTip:NSLocalizedString(@"GRID_TOOLTIP", @"Grid Tooltip")];
      [item setTarget:self];
      [item setAction:@selector(showGridSettingsPrompter:)];
      [item setImage:[NSImage imageNamed:@"grid"]];
    }
  else if ([itemIdentifier isEqualToString:@"PXColorPalette"])
    {
      [item setLabel:NSLocalizedString(@"COLOR_PALETTE_LABEL", @"Color Palette Label")];
      [item setPaletteLabel:[item label]];
      [item setToolTip:NSLocalizedString(@"COLOR_PALETTE_TOOLTIP", @"Color Palette Tooltip")];
      [item setTarget:self];
      [item setAction:@selector(toggleColorPalette:)];
      [item setImage:[NSImage imageNamed:@"colorpalette"]];
    }
  else if ([itemIdentifier isEqualToString:@"PXZoomFit"])
    {

      [item setLabel:NSLocalizedString(@"ZOOM_FIT_LABEL", @"Zoom Fit Label")];
      [item setPaletteLabel:[item label]];
      [item setToolTip:NSLocalizedString(@"ZOOM_FIT_TOOLTIP", @"Zoom Fit Tooltip")];
      [item setTarget:self];
      [item setAction:@selector(zoomToFit:)];
      [item setImage:[NSImage imageNamed:@"zoomfit"]];
    }
  else if ([itemIdentifier isEqualToString:@"PXZoom100"])
    {
      [item setLabel:NSLocalizedString(@"ZOOM_ACTUAL_LABEL", @"Zoom Actual Label")];
      [item setPaletteLabel:[item label]];
      [item setToolTip:NSLocalizedString(@"ZOOM_ACTUAL_TOOLTIP", @"Zoom Actual Tooltip")];
      [item setTarget:self];
      [item setAction:@selector(zoomStandard:)];
      [item setImage:[NSImage imageNamed:@"zoom100"]];
    }
  else if ([itemIdentifier isEqualToString:@"PXScale"])
    {
      [item setLabel:NSLocalizedString(@"SCALE_LABEL", @"Scale Label")];
      [item setPaletteLabel:[item label]];
      [item setToolTip:NSLocalizedString(@"SCALE_TOOLTIP", @"Scale Tooltip")];
      [item setTarget:self];
      [item setAction:@selector(scaleCanvas:)];
      [item setImage:[NSImage imageNamed:@"scale"]];
    }
  else if ([itemIdentifier isEqualToString:@"PXResize"])
    {
      [item setLabel:NSLocalizedString(@"RESIZE_LABEL", @"Resize Label")];
      [item setPaletteLabel:[item label]];
      [item setToolTip:NSLocalizedString(@"RESIZE_TOOLTIP", @"Resize Tooltip")];
      [item setTarget:self];
      [item setAction:@selector(resizeCanvas:)];
      [item setImage:[NSImage imageNamed:@"resize"]];
    }
  else if ([itemIdentifier isEqualToString:@"PXFeedback"])
    {
      [item setLabel:NSLocalizedString(@"FEEDBACK_LABEL", @"Feedback Label")];
      [item setPaletteLabel:[item label]];
      [item setToolTip:NSLocalizedString(@"FEEDBACK_TOOLTIP", @"Feedback Tooltip")];
      [item setTarget:self];
      [item setAction:@selector(sendFeedback:)];
      [item setImage:[NSImage imageNamed:@"feedback"]];
    }
  else if ([itemIdentifier isEqualToString:@"PXZoom"])
    {
      [item setLabel:NSLocalizedString(@"ZOOM_LABEL", @"Zoom Label")];
      [item setPaletteLabel:[item label]];
      [item setToolTip:NSLocalizedString(@"ZOOM_TOOLTIP", @"Zoom Tooltip")];
      [item setTarget:self];
      [item setAction:@selector(togglePreviewWindow:)];
      [item setView:zoomView];
      [item setMinSize:NSMakeSize(124,NSHeight([zoomView frame]))];
      [item setMaxSize:NSMakeSize(0,NSHeight([zoomView frame]))];
    }

  return item;
}

- (NSArray *) toolbarAllowedItemIdentifiers:(NSToolbar *) toolbar
{
  return [NSArray arrayWithObjects:@"PXBackgroundConfigurator", @"PXLayerDrawer", 
		  @"PXPreview", @"PXZoom", 
		  @"PXZoomFit", @"PXZoom100",
		  @"PXResize", @"PXScale", 
		  @"PXFeedback", @"PXGrid",
		  @"PXColorPalette",
		  NSToolbarCustomizeToolbarItemIdentifier, 
		  NSToolbarSpaceItemIdentifier,
		  NSToolbarSeparatorItemIdentifier,
		  NSToolbarFlexibleSpaceItemIdentifier, 
		  nil];
}

- (NSArray *) toolbarDefaultItemIdentifiers:(NSToolbar *) toolbar
{
#ifdef __COCOA__
	return [NSArray arrayWithObjects:@"PXBackgroundConfigurator", @"PXGrid", 
			NSToolbarSeparatorItemIdentifier, @"PXLayerDrawer",
			@"PXColorPalette", @"PXPreview",
			NSToolbarFlexibleSpaceItemIdentifier, @"PXFeedback",
			@"PXZoom", 
			nil];
#else
	//Forget Zoom for GNUstep (TDOO)
	return [NSArray arrayWithObjects:@"PXBackgroundConfigurator", @"PXGrid", 
			NSToolbarSeparatorItemIdentifier, @"PXLayerDrawer",
			@"PXColorPalette", @"PXPreview",
			NSToolbarFlexibleSpaceItemIdentifier,
			@"PXFeedback",  
			nil];
#endif
}

- (IBAction) sendFeedback:(id) sender
{
  [[PXPanelManager sharedManager] showFeedback:sender];
}

- (IBAction) toggleLeftToolProperties:(id) sender
{
  [[PXPanelManager sharedManager] toggleLeftToolProperties:sender];
}

- (IBAction)toggleRightToolProperties:(id) sender
{
  [[PXPanelManager sharedManager] toggleRightToolProperties:sender];
}

- (IBAction)toggleColorPalette:(id) sender
{
  [[PXPanelManager sharedManager] toggleColorPalette:sender];
}

- (IBAction)mergeDown:(id) sender
{
  [layerController mergeDown];
}

- (IBAction)promoteSelection:(id) sender
{
  [canvas promoteSelection];
}

- (IBAction)newLayer:(id) sender
{
  [layerController addLayer:sender];
}

- (IBAction)deleteLayer:sender
{
    [layerController removeLayer:sender];
}

- (void)layerSelectionDidChange:(NSNotification *) aNotification
{
  [canvas deselect];
  [canvas activateLayer:[aNotification userInfo]];
}

- (void)setMainBackground:(id) aBackground
{
  [view setMainBackground:aBackground];
  [canvas setMainBackgroundName:[aBackground name]];
}

- (void)setAlternateBackground:(id) aBackground
{
  [view setAlternateBackground:aBackground];
  [canvas setAlternateBackgroundName:[aBackground name]];
}

- (void)backgroundChanged: (NSNotification *) aNotification
{
    [view setNeedsDisplayInRect:[view visibleRect]];
}

- (IBAction)flipLayerHorizontally:(id) sender
{
  [[self undoManager] beginUndoGrouping];
  [self setLayers:[[canvas layers] deepMutableCopy] fromLayers:[canvas layers]];		
  [[self undoManager] setActionName:@"Flip Layer Horizontally"];
  [[self undoManager] endUndoGrouping];
  [[canvas activeLayer] flipHorizontally];
  [canvas changedInRect:NSMakeRect(0, 0, [canvas size].width, [canvas size].height)];
}

- (IBAction)flipLayerVertically:(id) sender
{
  [[self undoManager] beginUndoGrouping];
  [self setLayers:[[canvas layers] deepMutableCopy] fromLayers:[canvas layers]];		
  [[self undoManager] setActionName:@"Flip Layer Vertically"];
  [[self undoManager] endUndoGrouping];
  [[canvas activeLayer] flipVertically];
  [canvas changedInRect:NSMakeRect(0, 0, [canvas size].width, [canvas size].height)];
}

- (IBAction)duplicateLayer:(id) sender
{
  [layerController duplicateLayer:sender];
}

- (IBAction)nextLayer:(id) sender
{
  [layerController nextLayer:sender];
}

- (IBAction)previousLayer:(id) sender
{
  [layerController previousLayer:sender];
}

- (void)promptForImageSize
{
  [prompter setDelegate:self];
  [prompter promptInWindow:[self window]];
}

//Should be  PXCanvas as returned type ?
- (id) canvas
{
    return canvas;
}
//Should be PXCanvas as returned type?
- (void)setCanvas:(id) aCanvas
{
  [[NSNotificationCenter defaultCenter] removeObserver:self name:PXCanvasChangedNotificationName object:canvas];

  canvas = aCanvas;
  if(NSEqualSizes([canvas size], NSZeroSize))
    {
      [self promptForImageSize];
      [prompter setDefaultSize:NSMakeSize(64,64)];
    }
    
  [[NSNotificationCenter defaultCenter] addObserver:self
					selector:@selector(canvasDidChange:)
					name:PXCanvasChangedNotificationName 
					object:canvas];

  [view setCanvas:aCanvas];
  [layerController setCanvas:aCanvas];
  [[PXColorPaletteController sharedPaletteController] reloadDataForCanvas:canvas];

  [[NSNotificationCenter defaultCenter] postNotificationName:PXCanvasLayersChangedNotificationName 
					object:canvas];

  [canvas changedInRect:NSMakeRect(0, 0, [canvas size].width, [canvas size].height)];
}

- (void)setColor:(NSColor *) aColor
{
  [[PXToolPaletteController sharedToolPaletteController] setColor:aColor];
}

- (void)canvasDidChange:(NSNotification *) aNotification
{
  NSRect rect = [[[aNotification userInfo] objectForKey:@"changedRect"] rectValue];
  [view setNeedsDisplayInCanvasRect:rect];
}

- (void)canvasSizeDidChange:(NSNotification *) aNotification
{
  [view sizeToCanvas];
  [self updatePreview];
  //[self zoomToFit:self];
}

- (void)updatePreview
{
  [previewController setCanvas:canvas];
  [previewController window];
}

- (NSUndoManager *) undoManager
{
  return [[[NSDocumentController sharedDocumentController] currentDocument] undoManager];
}

- (void)setLayers:layers fromLayers:oldLayers
{
    [[[self undoManager] prepareWithInvocationTarget:self] setLayers:oldLayers fromLayers:layers];
    [canvas setLayers:layers];
    //beginHack: it is probably bad to rely on the fact that all layers are the same size for now.  However, it is late and I want this to work and this is unlikely to change, so I will ignore this for now. __joe
    [canvas setSize:[[layers objectAtIndex:0] size]];
    //endHack
    [self canvasSizeDidChange:nil];
}

- (IBAction)resizeCanvas:(id) sender
{
    [[self undoManager] beginUndoGrouping];
    [self setLayers:[[canvas layers] deepMutableCopy] fromLayers:[canvas layers]];		
    [[self undoManager] setActionName:@"Resize Canvas"];
    [[self undoManager] endUndoGrouping];
    [resizePrompter setDelegate:self];
    NSLog(@"resizePrompter %@",resizePrompter);
    [resizePrompter promptInWindow:[self window]];
    [resizePrompter setCurrentSize:[canvas size]];
	
    NSImage *canvasImage = [[[NSImage alloc] initWithSize:[canvas size]] autorelease];
    [canvasImage lockFocus];
    [canvas drawRect:NSMakeRect(0, 0, [canvas size].width, [canvas size].height) fixBug:YES];
    [canvasImage unlockFocus];
    [resizePrompter setCachedImage:canvasImage];
}

- (IBAction)scaleCanvas:(id) sender
{
    [[self undoManager] beginUndoGrouping];
    [self setLayers:[[canvas layers] deepMutableCopy] fromLayers:[canvas layers]];		
    [[self undoManager] setActionName:@"Scale Canvas"];
    [[self undoManager] endUndoGrouping];
    [scaleController scaleCanvasFromController:self modalForWindow:[self window]];
}

- (void)windowDidBecomeMain:(NSNotification *) aNotification
{
  if([aNotification object] == [self window])
    {
      [self updatePreview];
      [[PXColorPaletteController sharedPaletteController] reloadDataForCanvas:canvas];
      [[PXInfoPanelController sharedInfoPanelController] setCanvasSize:[canvas size]];
    }
}

- (void)windowDidLoad
{
    [view setDelegate:self];
    [zoomPercentageBox removeAllItems];
    [zoomPercentageBox addItemsWithObjectValues:[NSArray arrayWithObjects:[NSNumber numberWithInt:3000], 
							 [NSNumber numberWithInt:2000], 
							 [NSNumber numberWithInt:1000], 
							 [NSNumber numberWithInt:800], 
							 [NSNumber numberWithInt:500], 
							 [NSNumber numberWithInt:400],
							 [NSNumber numberWithInt:200], 
							 [NSNumber numberWithInt:100],
							 [NSNumber numberWithInt:50], nil]]; 
    // If you're looking for randomly hard-coded percentages, they're right here!
    [zoomPercentageBox selectItemAtIndex:7];
    [zoomStepper setIntValue:7];
    NSLog(@"window %@ delegate %@",[self window], [[self window] delegate]);
    //[window setDelegate: self ]
    NSLog(@"scrollView %@",NSStringFromRect([[scrollView contentView] frame]));
    
    
    // Programmatically create our scrollview and canvas view
    id clip = [[[SBCenteringClipView alloc] initWithFrame:[[scrollView contentView] frame]] autorelease];
    [clip setBackgroundColor:[NSColor lightGrayColor]];
    [clip setCopiesOnScroll:NO];
    NSLog(@"clip^frame %@",NSStringFromRect([clip frame]));
   
#ifdef __COCOA__
    [(NSScrollView *)scrollView setContentView:clip];
#endif
    [scrollView setDocumentView:view];
    [view setCanvas:canvas];

    [backgroundController useBackgroundsOf:canvas];
    //[clip centerDocument];
    layerController = [[PXLayerController alloc] initWithCanvas:canvas];
    [[NSNotificationCenter defaultCenter] addObserver:self 
					  selector:@selector(layerSelectionDidChange:) 
					  name:PXLayerSelectionDidChangeName 
					  object:layerController];
    [layerController setWindow:[self window]];
    [layerController setNextResponder:self];
    [[NSNotificationCenter defaultCenter] postNotificationName:PXCanvasLayersChangedNotificationName object:canvas];
    [self zoomToFit:self];
    [[PXColorPaletteController sharedPaletteController] reloadDataForCanvas:canvas];
    [[PXColorPaletteController sharedPaletteController] 
      selectPaletteNamed:NSLocalizedString(@"GENERATED_PALETTE", @"Generated Palette")];

    [[self window] useOptimizedDrawing:YES];
    [[self window] makeKeyAndOrderFront:self];
    //[canvas changedInRect:NSMakeRect(0, 0, [canvas size].width, [canvas size].height)];
    //[self updatePreview];
}

- (void)updateCanvasSize
{
  [[PXInfoPanelController sharedInfoPanelController] setCanvasSize:[canvas size]];
  [view sizeToCanvas];
  [self updatePreview];
  [self zoomToFit:self];
}

- (void)prompter:aPrompter didFinishWithSize:(NSSize)aSize
{
  [canvas setSize:aSize];
	
  [self updateCanvasSize];
  [[PXColorPaletteController sharedPaletteController] reloadDataForCanvas:canvas];
  [[PXColorPaletteController sharedPaletteController] selectDefaultPalette];
  [(PXImage *)[[[canvas layers] objectAtIndex:0] image] replacePixelsOfColor:nil withColor:[NSColor clearColor]];

}

- (void)prompter:aPrompter didFinishWithSize:(NSSize)aSize position:(NSPoint)position backgroundColor:(NSColor *)color
{
    [canvas setSize:aSize withOrigin:position backgroundColor:color];
	[self updateCanvasSize];
}

//What is this coding Style ?
BOOL isTiling;
- (IBAction) shouldTileToggled: (id) sender
{
	isTiling = !isTiling;
	[sender setState:(isTiling) ? NSOffState : NSOnState];
	id defaults = [NSUserDefaults standardUserDefaults];
	[defaults setBool:isTiling forKey:@"PXShouldTile"];
	[defaults synchronize];
	[view setShouldTile:isTiling];
}

- (void)gridSettingsPrompter:aPrompter updatedWithSize:(NSSize)aSize color:color shouldDraw:(BOOL)shouldDraw
{
    [[view grid] setUnitSize:aSize];
    [[view grid] setColor:color];
    [[view grid] setShouldDraw:shouldDraw];
    [canvas setGridUnitSize:aSize];
    [canvas setGridColor:color];
    [canvas setGridShouldDraw:shouldDraw];
    [canvas changedInRect:NSMakeRect(0, 0, [canvas size].width, [canvas size].height)];
}

- (void)mouseDown:event forTool:aTool
{
  NSLog(@"mouse Down forTool %@",aTool);
  if(downEventOccurred) { return; } // avoid the case where the right mouse can be pressed while the left is dragging, and vice-versa. there should really be separate booleans for left-mouse-is-being-used and right-mouse-is-being-used, since right now if the right mouse is pressed and unpressed while the left mouse is pressed, the result will be that the left, too, becomes unpressed. fortunately, there are seemingly no unfortunate side effects from this situation, only the more obvious bug.
  downEventOccurred = YES;
  [[NSNotificationCenter defaultCenter] postNotificationName:@"PXLockToolSwitcher" object:aTool];
  if(! [aTool respondsToSelector:@selector(mouseDownAt:fromCanvasController:)]) 
    return; 

  initialPoint = [event locationInWindow];
  NSLog(@"go %@",NSStringFromPoint([view convertFromWindowToCanvasPoint:initialPoint]));
  [aTool mouseDownAt:[view convertFromWindowToCanvasPoint:initialPoint] fromCanvasController:self];    
}

- (void)mouseDragged:event forTool:aTool
{
    if(!downEventOccurred) { return; }
    if(![aTool respondsToSelector:@selector(mouseDraggedFrom:to:fromCanvasController:)]) { return; }
    NSPoint endPoint = [event locationInWindow];
    [aTool mouseDraggedFrom:[view convertFromWindowToCanvasPoint:initialPoint] to:[view convertFromWindowToCanvasPoint:endPoint] fromCanvasController:self];
    initialPoint = endPoint;
}

- (void)mouseUp:event forTool:aTool
{
  if(!downEventOccurred) { return; }
  downEventOccurred = NO;
  [[NSNotificationCenter defaultCenter] postNotificationName:@"PXUnlockToolSwitcher" object:aTool];
  if(![aTool respondsToSelector:@selector(mouseUpAt:fromCanvasController:)]) { return; }
  [aTool mouseUpAt:[view convertFromWindowToCanvasPoint:[event locationInWindow]] fromCanvasController:self];
}

- (void)mouseDown:(NSEvent *)event
{
  NSLog(@"mouseDown PXCanvasController");
  //users expect ctrl-left to == right
  usingControlKey = (([event modifierFlags] & NSControlKeyMask) == NSControlKeyMask);
    
  if (usingControlKey)
    {
      [self rightMouseDown:event]; return;
    }
  [self mouseDown:event forTool:[[PXToolPaletteController sharedToolPaletteController] leftTool]];
}

- (void)mouseDragged:(NSEvent *) event
{
  if (usingControlKey)
    {
      [self rightMouseDragged:event]; return;
    }
  [self mouseDragged:event forTool:[[PXToolPaletteController sharedToolPaletteController] leftTool]];
}

- (void)mouseMoved:(NSEvent *) event
{
  [view mouseMoved:event];
}

- (void)mouseUp:(NSEvent *) event
{
  if (usingControlKey)
    {
      [self rightMouseUp:event]; return;
    }
  [self mouseUp:event forTool:[[PXToolPaletteController sharedToolPaletteController] leftTool]];
}

- (void)rightMouseDown:(NSEvent *) event
{
  [self mouseDown:event forTool:[[PXToolPaletteController sharedToolPaletteController] rightTool]];
}

- (void)rightMouseDragged:(NSEvent *) event
{
    [self mouseDragged:event forTool:[[PXToolPaletteController sharedToolPaletteController] rightTool]];
}

- (void)rightMouseUp:(NSEvent *) event
{
    [self mouseUp:event forTool:[[PXToolPaletteController sharedToolPaletteController] rightTool]];
}

- (void)keyDown:(NSEvent *)event
{
  // [FIXME] Should we scroll the view or move the active layer here?  Hmm...
  if (downEventOccurred) { return; }
  int scrollAmount = 1;
  if(([event modifierFlags] & NSShiftKeyMask) == NSShiftKeyMask)
    {
      scrollAmount = 10;
    }
  if([[event characters] characterAtIndex:0] == NSUpArrowFunctionKey)
    {
      [view scrollUpBy:scrollAmount];
    }
  else if([[event characters] characterAtIndex:0] == NSRightArrowFunctionKey)
    {
      [view scrollRightBy:scrollAmount];
    }
  else if([[event characters] characterAtIndex:0] == NSDownArrowFunctionKey)
    {
      [view scrollDownBy:scrollAmount];
    }
  else if([[event characters] characterAtIndex:0] == NSLeftArrowFunctionKey)
    {
      [view scrollLeftBy:scrollAmount];
    }
  else if([[event characters] characterAtIndex:0] == NSDeleteFunctionKey)
    {
      [[[NSDocumentController sharedDocumentController] currentDocument] delete:self];
      //[canvas deleteSelection];
      //[canvas changedInRect:NSMakeRect(0, 0, [canvas size].width, [canvas size].height)];
    }
  else
    {
      [[PXToolPaletteController sharedToolPaletteController] keyDown:event];
      [[PXColorPaletteController sharedPaletteController] keyDown:event];
    }
}

- (void)flagsChanged:(NSEvent *) event
{
  [[PXToolPaletteController sharedToolPaletteController] flagsChanged:event];
}

- (IBAction)showPreviewWindow:(NSEvent *) sender
{
  [previewController showWindow:self];
}

- (IBAction)togglePreviewWindow: (id) sender
{
  if ([[previewController window] isVisible])
    {
      [[previewController window] performClose:self];
    }
  else
    {
      [previewController showWindow:self];
    }	
}

- (IBAction)showBackgroundInfo:(id) sender
{
  NSLog(@"showBackgroundInfo %@",[backgroundController backgroundPanel]);
  [[backgroundController backgroundPanel] makeKeyAndOrderFront: self];
}

- (IBAction)showGridSettingsPrompter:(id) sender
{
  if (gridSettingsPrompter) 
    [gridSettingsPrompter release];
  
  gridSettingsPrompter = [[PXGridSettingsPrompter alloc] initWithSize:[[view grid] unitSize] 
							 color:[[view grid] color] 
							 shouldDraw:[[view grid] shouldDraw] ? YES : NO];
  [gridSettingsPrompter setDelegate:self];
  [(PXGridSettingsPrompter *)gridSettingsPrompter prompt];
}

- (void)zoomToIndex:(float)index
{
  if(index < 0 || index >= [zoomPercentageBox numberOfItems]) { 
#ifdef __COCOA__
    NSBeep();
#endif
    return; 
  }
  
  [zoomPercentageBox selectItemAtIndex:index];
  [zoomStepper setIntValue:index];
  [view setZoomPercentage:[zoomPercentageBox intValue]];
}

- (void)zoomToPercentage:(NSNumber *)percentage
{
  if( percentage == nil 
      || [percentage isEqual:[NSNumber numberWithInt:0]] 
      || [[[percentage description] lowercaseString] isEqualToString:@"inf"] 
      || [[[percentage description] lowercaseString] isEqualToString:@"nan"]) 
    { 
      [self zoomToPercentage:[NSNumber numberWithFloat:100]]; 
      return;
    }
  // Kind of a HACK, could change if the description changes to display something other than inf or nan on such numbers.
  //Probably not an issue, but I'll mark it so it's easy to find if it breaks later.
    
  
  if( ! [[zoomPercentageBox objectValues] containsObject:percentage])
    {
      id values = [NSMutableArray arrayWithArray:[zoomPercentageBox objectValues]];
      [values addObject:percentage];
      [values sortUsingSelector:@selector(compare:)];
      [zoomPercentageBox removeAllItems];
      [zoomPercentageBox addItemsWithObjectValues:[[values reverseObjectEnumerator] allObjects]];
    }

  [zoomPercentageBox selectItemWithObjectValue:percentage];
  [self zoomToIndex:[zoomPercentageBox indexOfSelectedItem]];
}

- (IBAction)zoomIn: (id) sender
{
    [self zoomToIndex:[zoomStepper intValue]-1];
}

- (IBAction)zoomOut: (id) sender
{
    [self zoomToIndex:[zoomStepper intValue]+1];
}

- (IBAction)zoomStandard: (id) sender
{ 
  [self zoomToIndex:[zoomPercentageBox indexOfItemWithObjectValue:[NSNumber numberWithInt:100]]];
}

- (IBAction)zoomPercentageChanged:sender
{
    [self zoomToPercentage:[zoomPercentageBox objectValue]];
}

- (IBAction)zoomStepperStepped:(id) sender
{
  if([zoomStepper intValue] >= [zoomPercentageBox numberOfItems]) 
    { 
#ifdef __COCOA__
      NSBeep();
#endif
      [zoomStepper setIntValue:[zoomPercentageBox numberOfItems]-1]; 
      return; 
    }
  [self zoomToIndex:[zoomStepper intValue]];
}

- (IBAction)zoomToFit:(id) sender
{
  float xRatio = [[scrollView contentView] frame].size.width/[canvas size].width;
  float  yRatio = [[scrollView contentView] frame].size.height/[canvas size].height;

  [self zoomToPercentage:([[scrollView contentView] frame].size.width > [canvas size].width ||
			  [[scrollView contentView] frame].size.width > [canvas size].width) ?
	[NSNumber numberWithFloat:(floorf(xRatio < yRatio ? xRatio : yRatio))*100] :
	  [NSNumber numberWithFloat:100.0f]];
}

- (void)zoomInOnCanvasPoint:(NSPoint)point
{
    [self zoomIn:self];
    [view centerOn:[view convertFromCanvasToViewPoint:point]];
}

- (void)zoomOutOnCanvasPoint:(NSPoint)point
{
    [self zoomOut:self];
    [view centerOn:[view convertFromCanvasToViewPoint:point]];
}

- (IBAction)toggleLayersDrawer:(id) sender
{
  [layerController toggle:sender];
}

@end
