/* DocView.h
 * Cenon document view class
 *
 * Copyright (C) 1996-2012 by vhf interservice GmbH
 *
 * Author:   Georg Fleischmann
 *
 * created:  1996-01-29
 * modified: 2012-02-13 (separated gridList for x and y)
 *           2011-04-06 (pathSetStartPoint: added)
 *           2011-03-03 (scaleGTo: added)
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the vhf Public License as
 * published by vhf interservice GmbH. Among other things, the
 * License requires that the copyright notices and this notice
 * be preserved on all copies.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the vhf Public License for more details.
 *
 * You should have received a copy of the vhf Public License along
 * with this program; see the file LICENSE. If not, write to vhf.
 *
 * vhf interservice GmbH, Im Marxle 3, 72119 Altingen, Germany
 * eMail: info@vhf.de
 * http://www.vhf.de
 */

#ifndef VHF_H_DOCVIEW
#define VHF_H_DOCVIEW

#include <AppKit/AppKit.h>
#include "FlippedView.h"
#include "Graphics.h"
#include "LayerObject.h"

#define KNOBSIZE	5
#define MARGIN		3

/* notification names */
#define DocLayerListHasChanged		@"DocLayerListHasChanged"       // layer lists need update
#define DocViewUpdateMenuItem		@"DocViewUpdateMenuItem"        // notification to update menu items
#define DocViewDrawGraphicAdditions	@"DocViewDrawGraphicAdditions"  // draw additional stuff in modules
#define DocViewDrawBatchAdditions	@"DocViewDrawBatchAdditions"    // draw batch additions in modules
#define DocViewDrawDecoration		@"DocViewDrawDecoration"        // draw stuff which is not inside cache
#define DocViewMouseDown            @"DocViewMouseDown"             // inform modules about mouse down
#define DocViewDragSelect           @"DocViewDragSelect"            // inform modules about drag region

extern NSString *e2PboardType;

@interface DocView:NSView
{
    id              document;               // the document holding this view
    NSColor         *backgroundColor;
    NSMutableDictionary	*statusDict;        // dictionary used for storing status information

    NSWindow        *cache;                 // the cache window and its view
    NSView          *cacheView;
    BOOL            doCaching;              // wether we have to cache
    id              betaCache;              // buffer for moving objects
    FlippedView     *editView;              // superview for text editing

    BOOL            inTimerLoop;            // used for scrolling

    BOOL            scrolling;              // wether we scroll when moving an object
    BOOL            magnifyMode;            // wether we zoom via magnify

    BOOL            displayGraphic;         // weather we have to display the graphics at all
    BOOL            drawPale;               // weather we draw our graphic objects pale
    BOOL            mustDrawPale;           // flag checked by graphic objects to draw in pale color
    BOOL            redrawEntireView;       // we have to redraw more than just the redraw rect
    BOOL            showDirection;          // display arrows showing winding direction

    NSMutableArray  *layerList;             // the layer list holding the graphic lists
    NSMutableArray  *slayList;              // list of selected objects
    int             indexOfSelectedLayer;   // index of selected layer

    NSMutableArray  *tileOriginList;        // positions of parts without original part
    NSPoint         tileLimits;
    BOOL            tileLimitSize;          // whether to limit by size instead of item-number
    NSPoint         tileDistance;           // distance between parts
    //BOOL          tileAbsoluteDistance;   // absolute instead of relative distance between tiles
    NSSize          tileSize;               // size of a part
    //BOOL          tileMoveMasterToOrigin; // whether to move the master graphics to origin
    id              serialNumber;           // the serialnumber object

    BOOL            gridIsEnabled;
    int             gridUnit;
    float           gridSpacing;
    NSRect          *gridListX, *gridListY;
    int             numGridRectsX, numGridRectsY;

    VCrosshairs     *origin;                // the crosshairs for the offset

    float           scale;                  // the scale factor 1.0->100%, 0.5->50%

    VGraphic        *originalPaste;         // the first pasted graphic
    int             consecutivePastes;      // number of consecutive pastes
    int             lastPastedChangeCount;  // the change count of last paste
    int             lastCopiedChangeCount;  // the change count of last cut or copy
    int             lastCutChangeCount;     // the change count of last cut

    NSColor         *separationColor;       // the current separation color - nil if nothing to separte
}

+ (NSRect)boundsOfArray:(NSArray*)list;

/* instance methods */
- (void)setBackgroundColor:(NSColor*)color;
- (NSColor*)backgroundColor;
- (void)setSeparationColor:(NSColor*)color;
- (NSColor*)separationColor;
- (void)setList:(NSMutableArray*)list;
- (id)singleList:(NSArray*)list;
- (void)addList:(NSMutableArray*)list toLayerAtIndex:(int)layer;
- (int)addLayerWithName:(NSString*)name type:(int)type tag:(int)tag list:(NSMutableArray*)array editable:(BOOL)editable;
- (int)insertLayerWithName:(NSString*)name atIndex:(int)index type:(int)type tag:(int)tag list:(NSMutableArray*)array editable:(BOOL)editable;
- (DocView*)initWithFrame:(NSRect)frameRect;
- (void)setDocument:(id)docu;
- (id)document;
- (DocView*)initView;
- (FlippedView*)createEditView;
- (FlippedView*)editView;
- (void)setParameter;
- (NSMutableDictionary*)statusDict;
- (BOOL)caching;
- (NSWindow*)cache;
- (void)setCaching:(BOOL)flag redraw:(BOOL)rd;
- (void)sizeCacheWindow:(float)width :(float)height;
- (void)scaleCacheWindow:(NSSize)newUnitSize;
- (void)scaleUnitSquareToSize:(NSSize)_newUnitSize;
- (void)setFrameSize:(NSSize)_newSize;
- (void)scrollPointToVisible:(NSPoint)point;

- (NSMutableArray*)layerList;
- (NSMutableArray*)slayList;
- (BOOL)isMultiPage;	// return YES, if this is a multi page document (contains LAYER_PAGE)
- (int)indexOfSelectedLayer;
- (void)selectLayerAtIndex:(int)ix;
- (int)layerIndexOfGraphic:(VGraphic*)g;
- (LayerObject*)layerOfGraphic:(VGraphic*)g;
- (void)removeGraphic:g;
- (BOOL)isSelectionEditable;
- (void)getSelection;
- (void)insertGraphic:g;	// insert a graphic on the 1st active layer
- (void)insertGraphic:g onLayer:(int)layer;
- (void)importASCII:(NSString*)string sort:(int)sort;
- (void)moveSelectionToLayer:(int)index;
- (void)setAllLayerDirty:(BOOL)flag;

- (VCrosshairs*)origin;		// get the origin marker
- (NSPoint)pointRelativeOrigin:(NSPoint)p;	// return point relative origin
- (NSPoint)pointAbsolute:(NSPoint)p;	// return point in absolute coordinates


- (id)clipObject;

- (float)scaleFactor;
- (float)controlPointSize;
- (void)drawControls:(NSRect)rect;
//- (void)drawControl:(NSRect)r for:object;
- (void)drawRect:(NSRect)rect;
- (void)flatRedraw:(NSRect)rect;
- (void)cache:(NSRect)rect;
- (void)drawAndDisplay;
- (void)cacheGraphic:(VGraphic*)g;
- (BOOL)displayGraphic;
- (BOOL)mustDrawPale;		// called from graphic objects to know how to draw
- (void)setRedrawEntireView:(BOOL)flag;
- (BOOL)redrawEntireView;
- (void)draw:(NSRect)rect;

- (BOOL)placeGraphic:(VGraphic*)graphic at:(NSPoint)location;
//- (BOOL)placeList:(NSArray*)list at:(NSPoint)location;
- (NSRect)boundsOfArray:(NSArray*)list;
- (NSRect)boundsOfArray:(NSArray*)list withKnobs:(BOOL)knobs;
- (NSRect)coordBoundsOfArray:(NSArray*)list;
- (void)scrollToRect:(NSRect)toRect;
- (void)constrainPoint:(NSPoint *)aPt withOffset:(const NSSize*)llOffset :(const NSSize*)urOffset;
- (void)constrainRect:(NSRect *)aRect;
- (BOOL)hitEdge:(NSPoint*)p spare:obj;
- (BOOL)redrawObject:obj :(int)pt_num :(NSRect*)redrawRect;
- (BOOL)moveObject:obj :(NSEvent *)event :(NSRect*)redrawRect;
- (BOOL)rotateObject:(VGraphic*)obj :(NSEvent *)event :(NSRect*)redrawRect;
- (BOOL)checkControl:(const NSPoint *) p :(int *) pt_num;
- (BOOL)magnify;
- (void)setMagnify:(BOOL)flag;
- (void)mouseDown:(NSEvent *)event;
//- keyDown:(NXEvent *)event;

- (void)group:sender;
- (void)ungroup:sender;
- (void)join:sender;
- (void)split:sender;
- (void)punch:sender;
- (void)mirror:sender;
- (void)rotateG:sender;
- (void)reverse:sender;
- (void)pathSetStartPoint:sender;
- (void)flatten:sender;
- (void)buildContour:sender;
- (void)delete:(id)sender;
- (void)selectAll:(id)sender redraw:(BOOL)redraw;
- (void)selectAll:(id)sender;
- (void)deselectAll:(id)sender redraw:(BOOL)redraw;
- (void)deselectAll:sender;
- (void)deselectLockedLayers:(BOOL)lockedLayers lockedObjects:(BOOL)lockedObjects;
- (void)selectEqual:sender;
- (void)selectColor:sender;
- (void)bringToFront:sender;
- (void)sendToBack:sender;
- (void)changeFont:(id)sender;
//- (void)transform:sender;

- (void)vectorizeWithTolerance:(float)maxError
                  createCurves:(BOOL)createCurves
                          fill:(BOOL)fillResult
                 replaceSource:(BOOL)removeSource;

- (void)scaleG:(float)x :(float)y;      // scale relative to common center
- (void)scaleGTo:(float)x :(float)y;    // scale absolute to individual centers

- (void)displayDirections:sender;
- (BOOL)showDirection;
- (void)setDirectionForLayer:(LayerObject*)layerObject;

- (id)initWithCoder:(NSCoder *)aDecoder;
- (void)encodeWithCoder:(NSCoder *)aCoder;
+ (id)readList:(id)stream inDirectory:(NSString*)directory;

- (void)allowGraphicsToWriteFilesIntoDirectory:(NSString *)directory;
- propertyList;
- (id)initFromPropertyList:(id)plist inDirectory:(NSString *)directory;

- (void)dealloc;

@end

/* Pasteboard */
@interface DocView(NSPasteboard)
#define NUM_TYPES_DRAW_EXPORTS 3
extern NSString *e2CenonPasteType(NSArray *types);
extern NSString *e2ForeignPasteType(NSArray *types);
extern NSString *e2TextPasteType(NSArray *types);
extern BOOL e2IncludesType(NSArray *types, NSString *type);
extern NSString *e2MatchTypes(NSArray *typesToMatch, NSArray *orderedTypes);
+ (void)convert:(NSUnarchiver *)unarchiver to:(NSString *)type using:(SEL)writer toPasteboard:(NSPasteboard *)pb;
+ (void)pasteboard:(NSPasteboard *)sender provideDataForType:(NSString *)type;
- (NSData *)dataForEPS;
- (NSData *)dataForEPSUsingList:(NSArray *)array;
- (NSData *)dataForTIFF;
- (NSData *)dataForTIFFUsingList:(NSArray *)array;
- (NSData *)copySelectionAsEPS;
- (NSData *)copySelectionAsTIFF;
- (NSData *)copySelection;
- copyToPasteboard:(NSPasteboard *)pboard types:(NSArray *)types;
- copyToPasteboard:(NSPasteboard *)pboard;
- (BOOL)pasteForeignDataFromPasteboard:(NSPasteboard *)pboard andLink:(LinkType)doLink at:(NSPoint)point;
- (NSArray *)pasteFromPasteboard:(NSPasteboard *)pboard andLink:(LinkType)doLink at:(const NSPoint *)point;
- (void)paste:sender andLink:(LinkType)doLink;
- (void)cut:(id)sender;
- (void)copy:(id)sender;
- (void)paste:(id)sender;
@end

/* Dragging */
@interface DocView(Drag)
- (void)registerForDragging;
- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender;
- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender;
@end

/* Grid */
@interface DocView(Grid)
- (void)drawGrid;
- (void)toggleGrid:sender;
- (void)setGridEnabled:(BOOL)flag;
- (BOOL)gridIsEnabled;
- (void)setGridUnit:(int)flag;
- (int)gridUnit;
- (BOOL)gridIsRelative;
- (void)setGridSpacing:(float)spacing;
- (float)gridSpacing;
- (float)resolution;
- (void)resetGrid;
- (float)grid;
- (NSPoint)grid:(NSPoint)p;
@end

/* Tile */
@interface DocView(Tile)
- (NSMutableArray*)tileOriginList;
- (NSPoint)tileDistance;
- (BOOL)tileLimitSize;
- (NSPoint)tileLimits;
- (void)setTileWithLimits:(NSPoint)limits limitSize:(BOOL)limitSize distance:(NSPoint)dist
             moveToOrigin:(BOOL)moveToOrigin;
- (void)removeTiles;
- (void)buildTileCopies:(NSPoint)limits limitSize:(BOOL)limitSize distance:(NSPoint)dist
           moveToOrigin:(BOOL)moveToOrigin;
- (id)serialNumber;
- (void)incrementSerialNumbers;
- (int)numberOfTiles;
- (NSRect)tileBounds;
@end

/* HiddenAreas */
@interface DocView(HiddenArea)
- (void)removeHiddenAreas:(NSMutableArray*)list;
- (void)uniteAreas:(NSMutableArray*)list;
- (BOOL)removeGraphics:(NSMutableArray*)list inside:(id)graphic;
@end

/* Undo */
@interface DocView(Undo)
- (void)graphicsPerform:(SEL)aSelector with:(void *)argument;
- (void)takeColorFrom:sender colorNum:(int)colorNum;
- (void)takeFillFrom:sender;
- (void)takeStepWidth:(float)stepWidth;
- (void)takeRadialCenter:(NSPoint)radialCenter;
- (void)takeWidth:(float)width;
- (void)takeLength:(float)length;
- (void)takeWidth:(float)width height:(float)height;
- (void)takeRadius:(float)radius;
- (void)takeAngle:(float)angle angleNum:(int)angleNum;
- (void)moveGraphicsBy:(NSPoint)vector andDraw:(BOOL)drawFlag;
- (void)movePointTo:(NSPoint)pt x:(BOOL)x y:(BOOL)y all:(BOOL)moveAll;
- (void)movePoint:(int)ptNum to:(NSPoint)pt x:(BOOL)x y:(BOOL)y all:(BOOL)moveAll;
- (void)rotate:(float)rotAngle;
- (void)splitObject:(VGraphic*)g atPoint:(NSPoint)p redraw:(BOOL)redraw;
- (void)addPointTo:(VGraphic*)g atPoint:(NSPoint)p redraw:(BOOL)redraw;
@end

#endif // VHF_H_DOCVIEW
