 //  PXCanvas.h
 //  Pixen
 //
 //  Created by Joe Osborn on Sat Sep 13 2003.
 //  Copyright (c) 2003 Open Sword Group. All rights reserved.
 //
 
#import <AppKit/AppKit.h>

extern NSString * PXCanvasSizeChangedNotificationName;
extern NSString * PXCanvasChangedNotificationName;
extern NSString * PXCanvasSelectionChangedNotificationName;
extern NSString * PXCanvasLayersChangedNotificationName;

@class PXImage;

@interface PXCanvas : NSObject <NSCoding>{
    id layers;
	id activeLayer;
	id lastActiveLayer;
    id mainBackgroundName, alternateBackgroundName;
	
	NSSize gridUnitSize;
	id gridColor;
	BOOL gridShouldDraw;
	
	NSSize previewSize;
	id palette;
	
	NSPoint lastDrawnPoint;
}
+ withContentsOfFile:aFile;
- initWithContentsOfFile:aFile;
- undoManager;

- palette;

- (BOOL)canDrawAtPoint:(NSPoint)point;
- colorAtPoint:(NSPoint)aPoint;
- (void)setColor:aColor atPoint:(NSPoint)aPoint;
- (void)setColor:aColor atPoints:(NSArray *)points;

- activeLayer;
- (void)activateLayer:aLayer;
- layers;
- (int)indexOfLayer:aLayer;
- (void)setLayers:newLayers;
- (void)addLayer:aLayer;
- (void)insertLayer:aLayer atIndex:(int)index;
- (void)removeLayer:aLayer;
- (void)removeLayerAtIndex:(int)index;
- (void)moveLayer:aLayer toIndex:(int)anIndex;
- (void)setLayers:layers fromLayers:oldLayers;
- lastActiveLayer;
- (void)restoreActivateLayer:aLayer lastActiveLayer:lastLayer;

- (NSSize)size;
- (void)setSize:(NSSize)newSize withOrigin:(NSPoint)origin backgroundColor:(NSColor *)color;
- (void)setSize:(NSSize)aSize;
- (void)drawRect:(NSRect)rect fixBug:(BOOL)fixBug;
- (void)changedInRect:(NSRect)rect;
- (void)layersChanged;
- (void)canvasShouldRedraw:aNotification;
- (NSPoint)correct:(NSPoint)aPoint;
- (BOOL)containsPoint:(NSPoint)aPoint;

- (NSSize)previewSize;
- (void)setPreviewSize:(NSSize)size;

- mainBackgroundName;
- (void)setMainBackgroundName:aName;
- alternateBackgroundName;
- (void)setAlternateBackgroundName:aName;

- (void)replacePixelsOfColor:oldColor withColor:newColor;

- (NSSize)gridUnitSize;
- (void)setGridUnitSize:(NSSize)newGridUnitSize;
- gridColor;
- (void)setGridColor:newGridColor;
- (BOOL)gridShouldDraw;
- (void)setGridShouldDraw:(BOOL)newGridShouldDraw;

- (BOOL)hasImage:anImage;
- (BOOL)hasSelection;
- (void)promoteSelection;
- (void)finalizeSelection;
- (void)deselect;
- (void)deselectPixelAtPoint:(NSPoint)point;
- (void)selectPixelAtPoint:(NSPoint)point;
- (BOOL)pointIsSelected:(NSPoint)point;
- (void)selectAll;
- (NSRect)selectedRect;

- (void)pasteFromPasteboard:board type:type;
- (NSData *)selectionData;
- (void)deleteSelection;

- imageDataWithType:(NSBitmapImageFileType)storageType properties:(NSDictionary *)properties;
- initWithImage:(NSImage *)anImage;
- initWithPSDData:(NSData *)data;
- PICTData;

- (void)setDefaultGridParameters;
- (void)applyImage:anImage toLayer:aLayer;

- (void)setLastDrawnPoint:(NSPoint)point;
- (NSPoint)lastDrawnPoint;

@end
