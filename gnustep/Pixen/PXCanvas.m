//  PXCanvas.m
//  Pixen
//
//  Created by Joe Osborn on Sat Sep 13 2003.
//  Copyright (c) 2003 Open Sword Group. All rights reserved.
//

#import "PXCanvas.h"
#import "PXLayer.h"
#import "PXSelectionLayer.h"
#ifdef __COCOA__
#import "PXBitmapExporter.h"
#import "PXPSDHandler.h"
#endif
#import "PXPalette.h"

#import "PXPoint.h"

NSString * PXCanvasSizeChangedNotificationName = @"PXCanvasSizeChangedNotification";
NSString * PXCanvasChangedNotificationName = @"PXCanvasChangedNotification";
NSString * PXCanvasSelectionChangedNotificationName = @"PXCanvasSelectionChangedNotification";
NSString * PXCanvasLayersChangedNotificationName = @"PXCanvasLayersChangedNotification";

@implementation PXCanvas

+ withContentsOfFile:aFile
{
    return [[[self alloc] initWithContentsOfFile:aFile] autorelease];
}

- initWithContentsOfFile:aFile
{
    if([[aFile pathExtension] isEqualToString:@"pxi"])
    {
        [self release];
        return self = [[NSKeyedUnarchiver unarchiveObjectWithFile:aFile] retain];
    }
    else
    {
        return [self initWithImage:[[[NSImage alloc] initWithContentsOfFile:aFile] autorelease]];
    }
    [self release];
    return self = nil;
}

- init
{
    [super init];
    layers = [[NSMutableArray alloc] initWithCapacity:23];
	palette = [[PXPalette alloc] initWithName:NSLocalizedString(@"GENERATED_PALETTE", @"Generated Palette")];
	[self setLastDrawnPoint:NSMakePoint(-1, -1)];
	[self setDefaultGridParameters];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(canvasShouldRedraw:) name:@"PXCanvasShouldRedrawNotificationName" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(colorAdded:) name:@"PXImageColorAddedNotification" object:nil];
	return self;
}

- (void)canvasShouldRedraw:aNotification
{
	[self changedInRect:NSMakeRect(0,0,[self size].width,[self size].height)];
}

- (void)dealloc
{
    [layers release];
	[palette release];
	[mainBackgroundName release];
	[alternateBackgroundName release];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

- (BOOL)containsPoint:(NSPoint)aPoint
{
	return ([[NSUserDefaults standardUserDefaults] boolForKey:@"PXShouldTile"] ? YES : NSPointInRect(aPoint, NSMakeRect(0, 0, [self size].width, [self size].height)));
}

- (NSPoint)correct:(NSPoint)aPoint
{
	NSPoint corrected = aPoint;
	while(corrected.x < 0)
	{
		corrected.x += [self size].width;
	}
	while(corrected.x >= [self size].width)
	{
		corrected.x -= [self size].width;
	}
	while(corrected.y < 0)
	{
		corrected.y += [self size].height;
	}
	while(corrected.y >= [self size].height)
	{
		corrected.y -= [self size].height;
	}
	return corrected;	
}

- colorAtPoint:(NSPoint)aPoint
{
    if(![self containsPoint:aPoint]) { return nil; }
    return [activeLayer colorAtPoint:aPoint];
}

- (void)changedInRect:(NSRect)rect
{
	[[NSNotificationCenter defaultCenter] postNotificationName:PXCanvasChangedNotificationName object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSValue valueWithRect:rect], @"changedRect", activeLayer, @"activeLayer", nil]];
	if ([self hasSelection])
	{
		if ([[[layers lastObject] workingPoints] count] > 0)
		{
			[[NSNotificationCenter defaultCenter] postNotificationName:PXCanvasChangedNotificationName object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSValue valueWithRect:rect], @"changedRect", lastActiveLayer, @"activeLayer", nil]];
		}
	}
}

- (void)setColor:aColor atPoint:(NSPoint)aPoint
{
    if(![self containsPoint:aPoint]) { return; }
    [activeLayer setColor:aColor atPoint:aPoint];
}

- (void)setColor:aColor atPoints:(NSArray *)points
{
    [activeLayer setColor:aColor atPoints:points];
}

- undoManager
{
    return [[[NSDocumentController sharedDocumentController] currentDocument] undoManager];
}

- (void)setLayers:newLayers fromLayers:oldLayers
{
	[[[self undoManager] prepareWithInvocationTarget:self] setLayers:oldLayers fromLayers:newLayers];
	[self setLayers:newLayers];
}

- (void)promoteSelection
{
	id newLayer = [[PXLayer alloc] initWithName:@"New Layer" size:[self size]], lastLayer = [layers lastObject];
	if (![self hasSelection]) { return; }
	[[self undoManager] beginUndoGrouping];
	[[self undoManager] setActionName:@"Promote Selection"];
	[self setLayers:[layers deepMutableCopy] fromLayers:layers];
	// we have to recreate the layer so it won't be a PXSelectionLayer anymore
	// make a new layer and make it second to last - under the selection
	[newLayer compositeUnder:lastLayer flattenOpacity:YES];
	[layers removeLastObject];
	[self addLayer:newLayer];
	[self activateLayer:newLayer];
	lastActiveLayer = nil;
	[self layersChanged];
	[[self undoManager] endUndoGrouping];
}

- activeLayer
{
	return activeLayer;
}

- (void)activateLayer:aLayer
{
	if((activeLayer == aLayer) || (aLayer == nil)) { return; }
	lastActiveLayer = activeLayer;
	activeLayer = aLayer;
}

- lastActiveLayer
{
	return lastActiveLayer;
}

- (void)restoreActivateLayer:aLayer lastActiveLayer:lastLayer
{
	activeLayer = aLayer;
	lastActiveLayer = lastLayer;
}

- (void)layersChanged
{
	[[NSNotificationCenter defaultCenter] postNotificationName:PXCanvasLayersChangedNotificationName object:self];
	[self changedInRect:NSMakeRect(0, 0, [self size].width, [self size].height)];
}

- layers
{
	return layers;	
}

- (int)indexOfLayer:aLayer
{
	return [layers indexOfObject:aLayer];
}

- (void)setLayers:newLayers
{
	int oldActiveIndex = [layers indexOfObject:activeLayer];
	if([self hasSelection]) { oldActiveIndex = [layers indexOfObject:lastActiveLayer]; }
	if([newLayers count] <= oldActiveIndex) { oldActiveIndex = 0; }
	[self activateLayer:[newLayers objectAtIndex:oldActiveIndex]];
	if([[newLayers lastObject] isKindOfClass:[PXSelectionLayer class]]) { [self activateLayer:[newLayers lastObject]]; }
	[newLayers retain];
	[layers release];
	layers = newLayers;
	[self layersChanged];
}

- (void)addLayer:aLayer
{
	[self insertLayer:aLayer atIndex:[layers count]];
}

- (void)insertLayer:aLayer atIndex:(int)index
{
	[self deselect];
	[layers insertObject:aLayer atIndex:index];
	[[NSNotificationCenter defaultCenter] postNotificationName:PXCanvasLayersChangedNotificationName object:self];
}

- (void)removeLayer:aLayer
{
	[self deselect];
	if([layers count] == 1) { return; }
	[layers removeObject:aLayer];
	[[NSNotificationCenter defaultCenter] postNotificationName:PXCanvasLayersChangedNotificationName object:self];
	[self activateLayer:[layers objectAtIndex:0]];
	[self changedInRect:NSMakeRect(0,0,[self size].width,[self size].height)];
}

- (void)removeLayerAtIndex:(int)index
{
	if(index >= [layers count]) { return; }
	[self removeLayer:[layers objectAtIndex:index]];
}

- (void)moveLayer:aLayer toIndex:(int)targetIndex
{/*
	int i, j;*/
	id newLayers = [layers mutableCopy];
	int sourceIndex = [layers indexOfObject:aLayer];
	
	[newLayers removeObjectAtIndex:sourceIndex];
	[newLayers insertObject:aLayer atIndex:targetIndex + (sourceIndex < targetIndex ? 0 : 1)];
	
	/*
	for (i = 0, j = 0; [newLayers count] < [layers count]; i++, j++)
	{
		if (aLayer == [layers objectAtIndex:i]) { j++; }
		if (i == targetIndex)
		{
			[newLayers addObject:[layers objectAtIndex:sourceIndex]];
		}
		if (j == [layers count]) { break; }
		[newLayers addObject:[layers objectAtIndex:j]];
	}
	*/
	
	
	
	[layers release];
	layers = newLayers;
	
	[self layersChanged];
}

- (NSSize)size
{
	if([layers count] > 0) { return [[layers objectAtIndex:0] size]; }
	return NSZeroSize;
}


- (void)setSize:(NSSize)aSize withOrigin:(NSPoint)origin backgroundColor:(NSColor *)color
{
    id enumerator = [layers objectEnumerator];
	id current;
	while ( ( current = [enumerator nextObject] ) )
	{
		[current setSize:aSize withOrigin:origin backgroundColor:color];
	}
	if([layers count] == 0) 
	{
		[self addLayer:[[[PXLayer alloc] initWithName:@"Main" size:aSize] autorelease]];   
		[self activateLayer:[layers objectAtIndex:0]];		
	}
	[self layersChanged];
    [self canvasShouldRedraw:nil];
}

- (void)setSize:(NSSize)aSize
{
	[self setSize:aSize withOrigin:NSMakePoint(0,0) backgroundColor:[NSColor colorWithCalibratedRed:0 green:0 blue:0 alpha:0]];
}

- (NSSize)previewSize
{
	if (previewSize.width == 0 && previewSize.height == 0) {
		return [self size];
	}
	return previewSize;
}

- (void)setPreviewSize:(NSSize)aSize
{
	previewSize = aSize;
}

- (BOOL)hasSelection
{
	return [[layers lastObject] isKindOfClass:[PXSelectionLayer class]];
}

- (void)deselect
{
	if(![self hasSelection]) { return; }
	[self activateLayer:lastActiveLayer];
	lastActiveLayer = nil;
	[activeLayer compositeUnder:[layers lastObject] flattenOpacity:NO];
	[layers removeLastObject];
	[self layersChanged];
}

- (void)deselectPixelAtPoint:(NSPoint)point
{
	if(![self hasSelection]) { return; }
	if (![[[layers lastObject] workingPoints] objectAtCoordinates:(unsigned)point.x, (unsigned)point.y])
	{	
		[activeLayer setColor:[[layers lastObject] colorAtPoint:point] atPoint:point];
	}
	[[layers lastObject] removeWorkingPoint:point];
}

- (void)finalizeSelection
{
	if(![self hasSelection]) { return; }
	unsigned i, j;
	for(i = 0; i < [[layers lastObject] size].width; i++)
	{
		for(j = 0; j < [[layers lastObject] size].height; j++)
		{
			NSPoint point = NSMakePoint(i, j);
			if (![self pointIsSelected:point] || ([[layers lastObject] colorAtPoint:point] != nil)) { continue; }
			id color = [activeLayer colorAtPoint:point];
			if(color == nil) { color = [NSColor clearColor]; }
			[[layers lastObject] setColor:color atPoint:point];
			[activeLayer setColor:nil atPoint:point];
		}
	}
	[[layers lastObject] finalize];
	[self activateLayer:[layers lastObject]];
}

- (void)selectPixelAtPoint:(NSPoint)point
{
	if(![self hasSelection])
	{
		id newLayer = [PXSelectionLayer selectionWithSize:[self size]];
		[self addLayer:newLayer];
		[newLayer setOpacity:[activeLayer opacity]];		
	}
	[[layers lastObject] addWorkingPoint:point];
}

- (BOOL)pointIsSelected:(NSPoint)point
{
	if(![self hasSelection]) { return NO; }
	return ([[layers lastObject] pointIsSelected:point]);
}

- (NSData *)selectionData
{
	return [NSKeyedArchiver archivedDataWithRootObject:[layers lastObject]];
}

- (void)pasteFromPasteboard:board type:type
{
	[self deselect];
	if ([type isEqualToString:@"PXLayer"])
	{
		id layer = [NSKeyedUnarchiver unarchiveObjectWithData:[board dataForType:type]];
		if (!NSEqualSizes([layer size], [self size])) {
			[layer setSize:[self size]];
		}
		[self addLayer:layer];
		[self finalizeSelection];
	}
	else if ([type isEqualToString:@"NSImage"])
	{
		id image = [[[NSImage alloc] initWithPasteboard:board] autorelease];
		if ([image size].width > [self size].width || [image size].height > [self size].height)
		{
#ifdef __COCOA__
			switch ([[NSAlert alertWithMessageText:@"The pasted image is too big!"
									 defaultButton:@"Resize Canvas"
								   alternateButton:@"Cancel Paste"
									   otherButton:@"Paste Anyway"
						 informativeTextWithFormat:@"The pasted image is %dx%d, while the canvas is only %dx%d.",
				(int)([image size].width), (int)([image size].height),
				(int)([self size].width), (int)([self size].height)]
				runModal])
            {
				case NSAlertDefaultReturn:
					[self setSize:[image size]];
					[[NSNotificationCenter defaultCenter] postNotificationName:PXCanvasSizeChangedNotificationName object:nil];
					break;
				case NSAlertAlternateReturn:
					return;
				case NSAlertOtherReturn:
					break;
				default:
					break;
            }
#else
#warning GNUstep TODO
#endif
		}
		[self addLayer:[[PXLayer alloc] initWithName:@"Pasted Image" size:[self size]]];
		[self activateLayer:[layers lastObject]];
		[self applyImage:image toLayer:[layers lastObject]];
	}
	[self layersChanged];
}

- (void)deleteSelection
{
	if (![self hasSelection]) { return; }
	[layers removeLastObject];
	[self layersChanged];
	[self activateLayer:lastActiveLayer];
}

- (void)selectAll
{
	[self deselect];
	int i, j;
	for(i = 0; i < [self size].width; i++)
	{
		for(j = 0; j < [self size].height; j++)
		{
			[self selectPixelAtPoint:NSMakePoint(i, j)];
		}
	}
	[self finalizeSelection];
}

- (NSRect)selectedRect
{
	NSRect selected = NSZeroRect;
	int i, j;
	for(i = 0; i < [self size].width; i++)
	{
		for(j = 0; j < [self size].height; j++)
		{
			if([self pointIsSelected:NSMakePoint(i, j)])
			{	
				NSRect currentRect = NSMakeRect(i, j, 1, 1);
				if (NSEqualRects(selected, NSZeroRect))
					selected = currentRect;
				else
					selected = NSUnionRect(selected, NSMakeRect(i, j, 1, 1));
			}
		}
	}
	return selected;
}

- (BOOL)canDrawAtPoint:(NSPoint)point
{
//	return [activeLayer canDrawAtPoint:point];
	return ([[NSUserDefaults standardUserDefaults] boolForKey:@"PXShouldTile"] ? YES : [activeLayer canDrawAtPoint:point]);
}

- copyWithZone:zone
{
	return [NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:self]];
}

- imageDataWithType:(NSBitmapImageFileType)storageType properties:(NSDictionary *)properties
{
    NSRect frame = NSMakeRect(0, 0, [self size].width, [self size].height);
    id outputImage = [[[NSImage alloc] initWithSize:[self size]] autorelease];
    [outputImage lockFocus];
    [self drawRect:frame fixBug:YES];
    id rep = [[[NSBitmapImageRep alloc] initWithFocusedViewRect:frame] autorelease];
    [outputImage unlockFocus];

	if (storageType == NSBMPFileType)
	{
#ifdef __COCOA__
		return [PXBitmapExporter BMPDataForImage:outputImage];
#else
#warning GNUstep / COCOA implement that without Quicktime 
return nil;
#endif
	}

	/*if (storageType == NSGIFFileType)
	{
		id oldLayers = layers;
		id newLayers = [layers deepMutableCopy];
		id enumerator = [newLayers objectEnumerator], current;
		while (current = [enumerator nextObject])
		{
			int i, j;
			id image = [current image];
			for (i = 0; i < [image size].width; i++)
			{
				for (j = 0; j < [image size].height; j++)
				{
					NSPoint point = NSMakePoint(i, j);
					id color = [image colorAtPoint:point];
					if ([color alphaComponent] < 1 || [color alphaComponent] > 0)
					{
						[image setColor:[color colorWithAlphaComponent:rint([color alphaComponent])] atPoint:point];
					}
				}
			}
		}
		//layers = newLayers;
		
		id data = [rep representationUsingType:storageType properties:properties];
		//layers = oldLayers;
		[newLayers release];
		return data;
	}*/
	else
	{
		return [rep representationUsingType:storageType properties:properties];
	}
}

- PICTData
{
	NSRect frame = NSMakeRect(0, 0, [self size].width, [self size].height);
    id outputImage = [[[NSImage alloc] initWithSize:[self size]] autorelease];
    [outputImage lockFocus];
    [self drawRect:frame fixBug:YES];
    [outputImage unlockFocus];
#ifdef __COCOA__
    return [PXBitmapExporter PICTDataForImage:outputImage];
#else
#warning GNUstep/Cocoa implement that without Quicktime
return nil;
#endif
}

- initWithImage:(NSImage *)anImage
{
    [self init];
	//some PNGs have ... fractional sizes.  So I put in this ceilfing.
    [self setSize:NSMakeSize(ceilf([anImage size].width), ceilf([anImage size].height))];
	[self applyImage:anImage toLayer:activeLayer];
    return self;
}

- initWithPSDData:(NSData *)data
{
#ifdef __COCOA__
	[self init];
	id images = [PXPSDHandler imagesForPSDData:data];
	[self setSize:[[images objectAtIndex:0] size]];
	id enumerator = [images objectEnumerator], current;
	while (current = [enumerator nextObject])
	{
		id layer = [[[PXLayer alloc] initWithName:@"Imported Layer" size:[current size]] autorelease];
		[self addLayer:layer];
		[self applyImage:current toLayer:layer];
	}
	return self;
#else
#warning GNUstep implement that without QUICKTIME
	return nil;
#endif
}

- (void)applyImage:anImage toLayer:aLayer
{
    int i, j;
    NSPoint point;
    id pool;

	[anImage lockFocus];
	id imageRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:NSMakeRect(0,0,[anImage size].width, [anImage size].height)];
	[anImage unlockFocus];
	unsigned char * bitmapData = [imageRep bitmapData];
	
	BOOL hasAlpha = ([imageRep samplesPerPixel] > 3);
    for(i = 0; i < floorf([anImage size].width); i++)
    {
        pool = [[NSAutoreleasePool alloc] init];
        for(j = 0; j < floorf([anImage size].height); j++)
        {   
			point = NSMakePoint(i, j);
			id color;
			if (hasAlpha)
			{
				unsigned long long baseIndex = (j * 4 * [anImage size].width) + (i * 4);
				color = [NSColor colorWithCalibratedRed:bitmapData[baseIndex + 0] / 255.0f
													 green:bitmapData[baseIndex + 1] / 255.0f
													  blue:bitmapData[baseIndex + 2] / 255.0f
													 alpha:bitmapData[baseIndex + 3] / 255.0f];				
			}
			else
			{
				unsigned long long baseIndex = (j * 3 * [anImage size].width) + (i * 3);
				color = [NSColor colorWithCalibratedRed:bitmapData[baseIndex + 0] / 255.0f
													 green:bitmapData[baseIndex + 1] / 255.0f
													  blue:bitmapData[baseIndex + 2] / 255.0f
													 alpha:1];
			}
			[aLayer setColor:color atPoint:NSMakePoint(i, [anImage size].height - j - 1)];
        }
        [pool release];
    }
	[imageRep release];
}

- palette
{
	return palette;
}

- mainBackgroundName
{
    return mainBackgroundName;   
}

- (void)setMainBackgroundName:aName
{
    id old = mainBackgroundName;
    mainBackgroundName = [aName copy];
    [old release];
}

- alternateBackgroundName
{
    return alternateBackgroundName;
}

- (void)setAlternateBackgroundName:aName
{
    id old = alternateBackgroundName;
    alternateBackgroundName = [aName copy];
    [old release];   
}

- (void)replacePixelsOfColor:oldColor withColor:newColor
{
	//i wish i had blocks
	id enumerator = [layers objectEnumerator];
	id current;
	while ( (current = [enumerator nextObject]) )
	{
		[current replacePixelsOfColor:oldColor withColor:newColor];
	}
	[self changedInRect:NSMakeRect(0, 0, [self size].width, [self size].height)];
}

- (NSSize)gridUnitSize
{
	return gridUnitSize;
}

- (void)setGridUnitSize:(NSSize)newGridUnitSize
{
	gridUnitSize = newGridUnitSize;
}

- gridColor
{
	return gridColor;
}

- (void)setGridColor:newGridColor
{
	[newGridColor retain];
	[gridColor release];
	gridColor = newGridColor;
}

- (BOOL)gridShouldDraw
{
	return gridShouldDraw;
}

- (void)setGridShouldDraw:(BOOL)newGridShouldDraw
{
	gridShouldDraw = newGridShouldDraw;
}

- (void)drawRect:(NSRect)rect fixBug:(BOOL)fixBug
{
  id enumerator = [layers objectEnumerator];
  id current;
	
  // If fixBug is YES, we need to draw the layers in reverse order because
  // we're using composite under. Bah.
	
  if (fixBug)
    {
      int i;
      for (i = [layers count] - 1; i >= 0; i--)
	{
	  [[layers objectAtIndex:i] drawRect:rect fixBug:fixBug];   
	}
    }
  else
    {
      while ( (current = [enumerator nextObject]) )
	{
	  [current drawRect:rect fixBug:fixBug];   
	}
    }
}

- (void)palette:aPalette foundDuplicateColorsAtIndex:(unsigned)first andIndex:(unsigned)second
{
	id oldColor = [palette colorAtIndex:first];
	id newColor = [oldColor colorWithAlphaComponent:[oldColor alphaComponent] - 0.0001];
	[palette setColor:newColor atIndex:second];
}

- initWithCoder:coder
{
    [self init];
    id image;
    if ( (image = [[coder decodeObjectForKey:@"image"] retain] ) )
    {
        layers = [[NSMutableArray alloc] initWithCapacity:23];
		[layers addObject:image];
    }
    else
    {
        layers = [[coder decodeObjectForKey:@"layers"] retain];
		if(layers == nil)
		{
			layers = [[coder decodeObjectForKey:@"forms"] retain];			
		}
    }
	if([[layers lastObject] isKindOfClass:[PXImage class]] && ([layers count] == 1)) 
	{
		[layers replaceObjectAtIndex:0 withObject:[[[PXLayer alloc] initWithName:@"Main" image:[layers lastObject]] autorelease]];
	}
    [self setMainBackgroundName:[coder decodeObjectForKey:@"mainBackgroundName"]];
    [self setAlternateBackgroundName:[coder decodeObjectForKey:@"alternateBackgroundName"]];
	[self setGridShouldDraw:[coder decodeBoolForKey:@"gridShouldDraw"]];
	[self setGridUnitSize:[coder decodeSizeForKey:@"gridUnitSize"]];
	[self setGridColor:[coder decodeObjectForKey:@"gridColor"]];
	if(gridColor == nil) 
	{
		[self setDefaultGridParameters];
	}
	[self setPreviewSize:[coder decodeSizeForKey:@"previewSize"]];
	
	activeLayer = [layers lastObject];
	if(!(palette = [[coder decodeObjectForKey:@"palette"] retain]))
	{
		palette = [[PXPalette alloc] initWithName:NSLocalizedString(@"GENERATED_PALETTE", @"Generated Palette")];
		id enumerator = [layers objectEnumerator];
		id current;
		while ( (current = [enumerator nextObject]) )
		{
			int i, j;
			for(i = 0; i < [self size].width; i++)
			{
				for(j = 0; j < [self size].height; j++)
				{
					[palette addColor:[current colorAtPoint:NSMakePoint(i, j)]];
				}
			}
		}
	}
    return self;
}

//violates law of demeter. live with it.
- (BOOL)hasImage:anImage
{
	id enumerator = [layers objectEnumerator];
	id current;
	while ( (current = [enumerator nextObject] )  )
	{
		if([current image] == anImage)
		{
			return YES;
		}
	}
	return NO;
}

- (void)colorAdded:aNotification
{
	if([self hasImage:[aNotification object]])
	{
		[palette addColor:[[aNotification userInfo] objectForKey:@"color"]];
	}
}

- (void)setDefaultGridParameters
{
	//maybe this should be in PXCanvasView or PXGrid instead.
	id defaults = [NSUserDefaults standardUserDefaults];
	if([defaults objectForKey:@"PXGridColorData"] == nil)
	{
		[self setGridShouldDraw:NO];
		[self setGridUnitSize:NSMakeSize(1,1)];
		[self setGridColor:[NSColor blackColor]];
	}
	else
	{
		[self setGridShouldDraw:[defaults boolForKey:@"PXGridShouldDraw"]];
		[self setGridUnitSize:NSMakeSize([defaults floatForKey:@"PXGridUnitWidth"], [defaults floatForKey:@"PXGridUnitHeight"])];
		[self setGridColor:[NSKeyedUnarchiver unarchiveObjectWithData:[defaults objectForKey:@"PXGridColorData"]]];	
	}
}

- (void)encodeWithCoder:coder
{
    [coder encodeObject:layers forKey:@"layers"];
    [coder encodeSize:[self size] forKey:@"size"]; //even though we got rid of canvas's size, we need to keep this around so Pixens before r1v12 can read post-r1v12 pxis.
    [coder encodeObject:mainBackgroundName forKey:@"mainBackgroundName"];
    [coder encodeObject:alternateBackgroundName forKey:@"alternateBackgroundName"];
	[coder encodeBool:gridShouldDraw forKey:@"gridShouldDraw"];
	[coder encodeSize:gridUnitSize forKey:@"gridUnitSize"];
	[coder encodeObject:gridColor forKey:@"gridColor"];
	[coder encodeSize:previewSize forKey:@"previewSize"];
	[coder encodeObject:palette forKey:@"palette"];
}

- (void)setLastDrawnPoint:(NSPoint)point
{
	lastDrawnPoint = point;
}

- (NSPoint)lastDrawnPoint
{
	return lastDrawnPoint;
}

@end
