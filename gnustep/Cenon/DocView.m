/* DocView.m
 * The Cenon document view class
 *
 * Copyright (C) 1996-2013 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1996-01-29
 * modified: 2013-02-13 (include header VCurveFit.h from GraphicObjects.subproj)
 *           2012-11-15 (-dragSelect: fixed for group selection)
 *           2012-06-29 (-reverse: -pathSetStartPoint: layerList updateObject)
 *           2012-04-13 (-moveObject: scroll_rect is now part of rect_vis around pt)
 *           2012-04-13 (-drawRect: centerScanRect added, -redrawObject: centerScanRect changed)
 *           2012-02-29 (-joinSelection:messages: copy path for correct undo)
 *           2012-02-19 (-setList: keep order, when separating color to layers)
 *           2012-02-13 (-drawRect: centerScanRect removed)
 *           2012-01-25 (-draw: do not draw invisible layers)
 *           2012-01-24 (-knowsPageRange: added)
 *           2012-01-04 (-mouseDown: no beep for locked objects, if mouse didn't move)
 *           2011-04-06 (pathSetStartPoint: added)
 *           2011-04-06 (-buildContour: [change setRemoveSource:], [path setSelected:YES], fitGraphic added)
 *                      (-vectorizeWithTolerance:... new)
 *           2009-09-22 (-dragMagnify: init region.origin)
 *           2009-09-21 (-draw: use NSAffineTranform on Apple/GNUstep and PStranslate on OpenStep)
 *           2009-13-19 (-draw: display #DATE_...#, display non-template elements on even/odd template layer)
 *           2008-12-18 (-selectColor: VGroup got a fillColor)
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

#include <AppKit/AppKit.h>
#include <math.h>
#include <VHFShared/types.h>
#include <VHFShared/vhf2DFunctions.h>
#include <VHFShared/VHFStringAdditions.h>
#include <VHFShared/vhfSoundFunctions.h>
#include "App.h"
#include "Document.h"
#include "DocWindow.h"
#include "DocView.h"
#include "LayerObject.h"
#include "TileObject.h"
#include "InspectorPanel.subproj/InspectorPanel.h"
#include "PreferencesPanel.subproj/NotificationNames.h"
#include "TileScrollView.h"
#include "Graphics.h"
#include "GraphicObjects.subproj/VCurveFit.h"   // vectorization
#include "messages.h"
#include "graphicsUndo.subproj/undo.h"
#include "propertyList.h"
#include "GraphicObjects.subproj/HiddenArea.h"
#include "GraphicObjects.subproj/PathContour.h"	// for buildContour:

/* Private methods
 */
@interface DocView(PrivateMethods)
- (void)scrollPointToVisible:(NSPoint)point;
- (NSRect)dragSelect:(NSEvent *)event;
- (void)dragMagnify:(NSEvent *)event;
- (void)rotateObject:obj :(NSEvent *)event :(NSRect)redrawRect;
- (void)joinSelection:(id)change messages:(BOOL)messages;
@end

NSString *e2PboardType = @"Cenon Graphic List";

@implementation DocView

/* common functions
 */
/*
 * Timers used to automatically scroll when the mouse is
 * outside the drawing view and not moving.
 */
static void startTimer(BOOL *inTimerLoop)
{
    if (!*inTimerLoop)
    {   [NSEvent startPeriodicEventsAfterDelay:0.15 withPeriod:0.2];
        //[NSEvent startPeriodicEventsAfterDelay:0.5 withPeriod:0.5];
        *inTimerLoop = YES;
    }
}
static void stopTimer(BOOL *inTimerLoop)
{
    if (*inTimerLoop)
    {  [NSEvent stopPeriodicEvents];
        *inTimerLoop = NO;
    }
}

extern NSEvent *periodicEventWithLocationSetToPoint(NSEvent *oldEvent, NSPoint point)
{
    return [NSEvent otherEventWithType:[oldEvent type] location:point modifierFlags:[oldEvent modifierFlags] timestamp:[oldEvent timestamp] windowNumber:[oldEvent windowNumber] context:[oldEvent context] subtype:[oldEvent subtype] data1:[oldEvent data1] data2:[oldEvent data2]];
}

/* class methods
 */


/* instance methods
 */

/*
 * Create a plain window the size of the rectangle passed in and
 * then insert a view into the window as a subview. A clip view
 * is swapped for the content view if addclipview is YES. The
 * ClipView is used for the alpha buffer, which holds the primary
 * drawing. The beta buffer does not need to scroll so a ClipView
 * is unnecessary.
 */
static id createBuffer(NSRect winRect, BOOL addclipview)
{   id          buffer, clipview;
    NSWindow    *window;
    NSRect      contRect;

    contRect.origin.x = contRect.origin.y = 0;
    contRect.size = winRect.size;
    window = [[NSWindow alloc] initWithContentRect:contRect styleMask:NSBorderlessWindowMask
                                           backing:NSBackingStoreRetained defer:NO];
    [window setReleasedWhenClosed:NO];	// we close the window, not [App terminate]

    buffer = [[NSView alloc] initWithFrame:contRect];
    [buffer allocateGState];
    if (addclipview)
    {
        clipview = [[NSClipView alloc] init];
        //[clipview setDisplayOnScroll:NO];
        [window setContentView:clipview];
        [clipview release];
        [clipview setDocumentView:buffer];
        [buffer release];
    }
    else
    {   [[window contentView] addSubview:buffer];
        [buffer release];
    }
    [window setAutodisplay:NO];
    [window display];
    //[window orderFront:nil];	// debugging: display cache window

    return buffer;
}

/*
 * This sets the class version so that we can compatibly read
 * old Graphic objects out of an archive.
 */
+ (void)initialize
{
    [DocView setVersion:6];
    return;
}

+ (NSRect)boundsOfArray:(NSArray*)list
{   int		i, l;
    NSRect	rect, bbox = NSZeroRect;

    if ( ![list count] )
        return bbox;

    /* layer list */
    if ( [[list objectAtIndex:0] isKindOfClass:[LayerObject class]] )
    {
        for (l=[list count]-1; l>=0; l--)
        {
            if ( [[[list objectAtIndex:l] list] count] )
            {
                rect = [self boundsOfArray:[[list objectAtIndex:l] list]];
                bbox = (!bbox.size.width) ? rect : NSUnionRect(rect, bbox);
            }
        }
        return bbox;
    }
    /* slayList */
    else if ( [[list objectAtIndex:0] isKindOfClass:[NSMutableArray class]] )
    {
        for (l=[list count]-1; l>=0; l--)
        {
            if ( [(NSArray*)[list objectAtIndex:l] count] )
            {
                rect = [self boundsOfArray:[list objectAtIndex:l]];
                bbox = (!bbox.size.width) ? rect : NSUnionRect(rect, bbox);
            }
        }
        return bbox;
    }

    /* graphic list */
    bbox = [[list objectAtIndex:0] bounds];
    for (i=[list count]-1; i>0; i--)
    {
        rect = [[list objectAtIndex:i] bounds];
        bbox = NSUnionRect(rect, bbox);
    }

    return bbox;
}

- (BOOL)acceptsFirstResponder
{
    return YES;
}

- (void)fillAllObjects
{   int	l, i;

    if ( !Prefs_FillObjects )
        return;

    for ( l=0; l<(int)[layerList count]; l++ )
    {   NSMutableArray	*list = [[layerList objectAtIndex:l] list];

        //[self selectAll:self redraw:NO];
        //[self joinSelection:nil messages:NO];
        for ( i=0; i<(int)[list count]; i++ )
            [[list objectAtIndex:i] setFilled:YES];
        //[self deselectAll:nil redraw:NO];
    }
}

- (void)setBackgroundColor:(NSColor*)color
{
    backgroundColor = [color retain];
}
- (NSColor*)backgroundColor
{
    return backgroundColor;
}

- (void)setSeparationColor:(NSColor*)color
{
    separationColor = [color retain];
}
- (NSColor*)separationColor	{   return separationColor; }

#define	vhfColorDifference(c1, c2)	(Diff([(c1) redComponent], [(c2) redComponent]) + Diff([(c1) greenComponent], [(c2) greenComponent]) + Diff([(c1) blueComponent], [(c2) blueComponent]))
#define	COLOR_TOLERANCE			0.02
int colorLayer(NSColor *color, NSDictionary *colorDict)
{   NSEnumerator	*enumerator = [colorDict keyEnumerator];
    id			key;
    NSColor		*color1 = [color colorUsingColorSpaceName:@"NSCalibratedRGBColorSpace"];

    while ( (key = [enumerator nextObject]) )
    {   NSColor	*colorD = [[colorDict objectForKey:key] colorUsingColorSpaceName:@"NSCalibratedRGBColorSpace"];

        if ( vhfColorDifference( colorD, color1 ) < COLOR_TOLERANCE )
            return [key intValue];
    }
    return -1;
}
/* set single list of objects or complete layerList
 * modified: 2012-02-19 (keep order, when separating color to layers)
 */
- (void)setList:(NSMutableArray*)list
{   int	l;

    if ([list count] && [[list objectAtIndex:0] isKindOfClass:[LayerObject class]])
    {
        [layerList release];
        layerList = [list retain];
        [self getSelection];
        //[self addLayerWithName:LAYERCLIPPING_STRING type:LAYER_CLIPPING tag:0 list:nil editable:NO];
        for ( l=[layerList count]-1; l>=0; l-- )
            [[layerList objectAtIndex:l] createPerformanceMapWithFrame:[self bounds]];
    }
    else
    {
        if ( ![layerList count] )
            return;
        for ( l=[layerList count]-1; (Prefs_ColorToLayer) ? l>=0 : l>0; l-- )
        {
            [layerList removeObjectAtIndex:l];
            [slayList  removeObjectAtIndex:l];
        }
        if ( Prefs_ColorToLayer )
        {   int                 i;
            NSMutableDictionary *colorDict = [NSMutableDictionary dictionary];

            /* create dictionary with colors and layer index */
            for ( i=0, l=0; i<(int)[list count]; i++ )
            {   id      obj = [list objectAtIndex:i];
                NSColor *col = ([obj color]) ? [obj color] : [NSColor blackColor];

                /* add color to dictionary, create layer */
                if ( colorLayer(col, colorDict) < 0 )
                {   LayerObject	*layerObject = [LayerObject layerObjectWithFrame:[self bounds]];

                    [layerObject setString:[NSString stringWithFormat:@"Layer %d", l+1]];
                    [layerList addObject:layerObject];
                    [slayList  addObject:[NSMutableArray array]];
                    [colorDict setObject:col forKey:[NSNumber numberWithInt:l++]];
                }
            }

            /* separate objects to layers */
            //for ( i=[list count]-1; i>=0; i-- )   // 2012-02-19: this was changing the order of the list !
            for ( i=0; i < [list count]; i++ )
            {   id	obj = [list objectAtIndex:i];

                if ( (l = colorLayer([obj color], colorDict)) < 0 )
                    l = 0;
                [[layerList objectAtIndex:l] addObject:obj];
            }
        }
        else
        {
            [[layerList objectAtIndex:0] setList:list];
            [self getSelection];
        }
    }

    [self fillAllObjects];

    if ( [self window] )
        [self drawAndDisplay];
}

/* build a single list if list is a layerList
 */
- (id)singleList:(NSArray*)list
{   NSMutableArray  *array;
    int             l, i;

    if (![list count] || ![[list objectAtIndex:0] isKindOfClass:[LayerObject class]])
        return list;

    array = [NSMutableArray array];
    for (l=0; l<(int)[list count]; l++)
    {   NSArray	*objs = [[list objectAtIndex:l] list];

        for (i=0; i<(int)[objs count]; i++)
            [array addObject:[objs objectAtIndex:i]];
    }
    return array;
}

/* add list of objects or layers
 * list		array of graphic objects or LayerObjects
 * layer	index of layer
 *		-1 => create layer(s)
 *		-2 => to existing layers (by color or name)
 * replaceObjs	remove objects before adding
 *
 * modified: 2005-09-25 (use existing layer)
 */
- (void)addList:(NSMutableArray*)list toLayerAtIndex:(int)layer //replaceObjects:(BOOL)replaceObjs
{   int	i, l, insertOffset = 0;

    if ( ![list count] )
        return;

    /* use existing layers */
    if ( layer == -2 )
    {	BOOL	createNonExistingLayers = YES;

        /* add to layers by layer name (LayerObjects) */
        if ([[list objectAtIndex:0] isKindOfClass:[LayerObject class]])
        {
            for (i=0; i<(int)[list count]; i++)	// find layer with name
            {   LayerObject	*layerObject = [list objectAtIndex:i], *destinationLayer = nil;
                NSString	*name = [layerObject string];

                for (l=0; l<[layerList count]; l++)
                {
                    if ( [[[layerList objectAtIndex:l] string] isEqual:name] )
                    {   destinationLayer = [layerList objectAtIndex:l];
                        break;
                    }
                }
                if (!destinationLayer)	// no layer with this name
                {
                    NSLog(@"Import to existing layer: No layer available with name '%@'", name);
                    if ( createNonExistingLayers  &&
                         NSRunAlertPanel(@"", IMPORTTONOTEXISTINGLAYER_STRING,
                                              CREATELAYER_STRING, SKIP_STRING, nil, name)
                         == NSAlertDefaultReturn )
                    {
                        [slayList  insertObject:[NSMutableArray array] atIndex:[layerList count]-insertOffset];
                        [layerList insertObject:layerObject            atIndex:[layerList count]-insertOffset];
                        [layerObject createPerformanceMapWithFrame:[self bounds]];
                    }
                    else
                        createNonExistingLayers = NO;
                }
                else
                {
                    //if (replaceObjs)	// remove all objects from destination layer
                        [destinationLayer removeAllObjects];
                    [destinationLayer addObjectsFromArray:[layerObject list]];	// add objects
               }
            }
        }
        /* add to layers by color of existing object */
        else if (Prefs_ColorToLayer)
        {   NSMutableDictionary	*colorDict = [NSMutableDictionary dictionary];
            LayerObject		*extraLayer = nil;

            /* create dictionary with colors and layer index */
            for ( l=0; l<(int)[layerList count]; l++ )
            {   LayerObject	*layerObject = [layerList objectAtIndex:l];
                VGraphic	*g = ([[layerObject list] count]) ? [[layerObject list] objectAtIndex:0] : nil;
                NSColor		*col = ([g color]) ? [g color] : [NSColor blackColor];

                /* add color to dictionary */
                if ( colorLayer(col, colorDict) < 0 )	// not in dictionary
                    [colorDict setObject:col forKey:[NSNumber numberWithInt:l]];
                //if (replaceObjs)	// remove all objects from destination layer
                    [layerObject removeAllObjects];
            }

            /* separate objects to layers */
            for ( i=[list count]-1; i>=0; i-- )
            {   VGraphic	*g = [list objectAtIndex:i];

                if ( (l = colorLayer([g color], colorDict)) < 0)	// not in dictionary -> add to extra layer
                {
                    if (!extraLayer)
                    {
                        if ( createNonExistingLayers )	// log only first object !
                             NSLog(@"Import to existing layer: No layer available with color '%@'", [g color]);
                        if ( createNonExistingLayers  &&
                             NSRunAlertPanel(@"", IMPORTTONOTEXISTINGLAYER_STRING,
                                                  CREATELAYER_STRING, SKIP_STRING, nil, [g color])
                             == NSAlertDefaultReturn )	// create extra layer
                        {
                            extraLayer = [LayerObject layerObjectWithFrame:[self bounds]];
                            [extraLayer setString:@"Extra Layer"];
                            [slayList  insertObject:[NSMutableArray array] atIndex:[layerList count]-insertOffset];
                            [layerList insertObject:extraLayer             atIndex:[layerList count]-insertOffset];
                        }
                        else
                            createNonExistingLayers = NO;
                    }
                    [extraLayer addObject:g];
                }
                else
                    [[layerList objectAtIndex:l] addObject:g];
            }
        }
        else	// fallback -> create one new layer for everything
        {   LayerObject	*layerObject = [LayerObject layerObjectWithFrame:[self bounds]];

            NSLog(@"Import to existing layer: We either need layer names (DXF) or reference objects with color.");
            [layerObject setString:[NSString stringWithFormat:@"Layer %d", [layerList count]-insertOffset]];
            [layerObject addObjectsFromArray:list];
            [slayList  insertObject:[NSMutableArray array] atIndex:[layerList count]-insertOffset];
            [layerList insertObject:layerObject            atIndex:[layerList count]-insertOffset];
        }
    }
    /* create layers */
    else if ( layer == -1 )
    {
        /* create layers from list of layers (LayerObjects) */
        if ([[list objectAtIndex:0] isKindOfClass:[LayerObject class]])
        {
            for (i=0; i<(int)[list count]; i++)
            {   LayerObject	*layerObject = [list objectAtIndex:i];

                [layerList insertObject:layerObject atIndex:[layerList count]-insertOffset];
                [layerObject createPerformanceMapWithFrame:[self bounds]];
            }
            [self getSelection];
        }
        /* create one new layer from single list of objects */
        else
        {   LayerObject	*layerObject = [LayerObject layerObjectWithFrame:[self bounds]];

            [layerObject setString:[NSString stringWithFormat:@"Layer %d", [layerList count]-insertOffset]];
            [layerObject addObjectsFromArray:list];
            [slayList  insertObject:[NSMutableArray array] atIndex:[layerList count]-insertOffset];
            [layerList insertObject:layerObject            atIndex:[layerList count]-insertOffset];
        }
    }
    /* add to layer at given index */
    else
    {
        if ( layer >= (int)[layerList count] )
            return;
        [[layerList objectAtIndex:layer] addObjectsFromArray:[self singleList:list]];
        [self getSelection];
    }

    [self fillAllObjects];

    [[NSNotificationCenter defaultCenter] postNotificationName:DocLayerListHasChanged object:self];
    if ( [self window] )
        [self drawAndDisplay];
}

- (int)addLayerWithName:(NSString*)name type:(int)type tag:(int)tag list:(NSMutableArray*)array editable:(BOOL)editable
{   LayerObject	*layerObject;
    int		l;

    /* check */
    for (l=0; l<(int)[layerList count]; l++)
    {   layerObject = [layerList objectAtIndex:l];

        if ( [[layerObject string] isEqualToString:name] )	/* name allready in use! */
            return NO;
        /* only one layer of leveling or clipping type */
        if ( (type == LAYER_LEVELING || type == LAYER_CLIPPING) && [layerObject type] == type )
            return NO;
    }

    /* get location of new layer */
    for (l=[layerList count]-1; l>=0; l--)
    {   layerObject = [layerList objectAtIndex:l];

        if ([layerObject type] == LAYER_STANDARD)
        {   l += 1;
            break;
        }
    }
    if ( l == -1 )
        l = 0;

    layerObject = [[[LayerObject alloc] initWithFrame:[self bounds]] autorelease];
    if (array)
        [layerObject setList:array];
    [layerObject setString:name];
    [layerObject setTag:tag];
    [layerObject setType:type];
    [layerObject setEditable:editable];

    [layerList insertObject:layerObject atIndex:l];
    [slayList  insertObject:[NSMutableArray array] atIndex:l];

    return l;
}

- (int)insertLayerWithName:(NSString*)name atIndex:(int)index type:(int)type tag:(int)tag list:(NSMutableArray*)array editable:(BOOL)editable
{   LayerObject	*layerObject;
    int         l;

    /* check */
    for (l=0; l<(int)[layerList count]; l++)
    {   layerObject = [layerList objectAtIndex:l];

        if ( [[layerObject string] isEqualToString:name] )	/* name allready in use! */
            return NO;
        /* only one layer of leveling or clipping type */
        if ( (type == LAYER_LEVELING || type == LAYER_CLIPPING) && [layerObject type] == type )
            return NO;
    }

    /* check location of new layer */
    for (l=[layerList count]-1; l>=0; l--)
    {   layerObject = [layerList objectAtIndex:l];
        
        if ([layerObject type] == LAYER_STANDARD)
        {   l += 1;
            break;
        }
    }
    if (index > l )
        index = l;
    if ( index < 0 )
        index = 0;

    layerObject = [[[LayerObject alloc] initWithFrame:[self bounds]] autorelease];
    if (array)
        [layerObject setList:array];
    [layerObject setString:name];
    [layerObject setTag:tag];
    [layerObject setType:type];
    [layerObject setEditable:editable];

    [layerList insertObject:layerObject atIndex:index];
    [slayList  insertObject:[NSMutableArray array] atIndex:index];

    return index;
}

- (DocView*)initWithFrame:(NSRect)frameRect
{   NSNotificationCenter	*notificationCenter = [NSNotificationCenter defaultCenter];

    [super initWithFrame:frameRect];
    [self createEditView];
    [self registerForDragging];

    [notificationCenter addObserver:self
                           selector:@selector(allLayersHaveChanged:)
                               name:PrefsAllLayersHaveChanged
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(cachingHasChanged:)
                               name:PrefsCachingHasChanged
                             object:nil];

    return self;
}

/* sets the document for the view
 */
- (void)setDocument:docu
{
    document = docu;
}
- (id)document
{
    return document;
}

- (DocView*)initView
{   LayerObject		*layerObject;
    NSMutableArray	*slist;

    [self setParameter];

    layerList = [[NSMutableArray allocWithZone:[self zone]] init];	// the layer list
    layerObject = [[[LayerObject allocWithZone:[self zone]] init] autorelease];
    [layerObject createPerformanceMapWithFrame:[self bounds]];
    [layerList addObject:layerObject];

    slayList = [[NSMutableArray allocWithZone:[self zone]] init];	// the selected list
    slist = [NSMutableArray array];
    [slayList addObject:slist];

    //[self addLayerWithName:LAYERCLIPPING_STRING type:LAYER_CLIPPING tag:0 list:nil editable:NO];

    origin = [[VCrosshairs allocWithZone:[self zone]] init];

    return self;
}

- (void)setParameter
{
    doCaching = Prefs_Caching;
    if (doCaching)
    {   cacheView = createBuffer([self bounds], NO);
        cache = [cacheView window];
        //[cacheView setOpaque:YES];
    }
    //[self setOpaque:YES];

    /* cache for moving objects (-moveObjects:)
     * the size should come from preferences
     */
#ifdef __APPLE__
    betaCache = nil;
#else
    betaCache = [[NSWindow allocWithZone:[self zone]] initWithContentRect:[self bounds]
                                                                styleMask:NSBorderlessWindowMask
                                                                  backing:NSBackingStoreRetained defer:NO];
    [betaCache setAutodisplay:NO];
    if ([betaCache respondsToSelector:@selector(setOpaque:)])
        [betaCache setOpaque:NO];
    [[betaCache contentView] allocateGState];
#endif

    scale = 1.0;	// the scale factor

    displayGraphic = YES;

    if ( !statusDict )
        statusDict = [NSMutableDictionary new];
}

- (NSMutableDictionary*)statusDict
{
    if ( !statusDict )
        statusDict = [NSMutableDictionary new];
    return statusDict;
}

/*
 * editView is essentially a dumb, FLIPPED (with extra emphasis on the
 * flipped) subview of our GraphicView which completely covers it and
 * which automatically sizes itself to always completely cover the
 * GraphicView.  It is necessary since growable Text objects only work
 * when they are subviews of a flipped view.
 *
 * See VText for more details about why we need editView
 * (it is purely a workaround for a limitation of the Text object).
 */
- (FlippedView*)createEditView
{   NSRect	viewFrame = [self frame];

    [self setAutoresizesSubviews:YES];
    editView = [[FlippedView allocWithZone:[self zone]] initWithFrame:
                (NSRect){{0, 0}, {viewFrame.size.width, viewFrame.size.height}}];
    //No resize, editView works on 100%
    //[editView setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
    [self addSubview:editView];

    return editView;
}

- (FlippedView*)editView
{
    return editView;
}

- (BOOL)caching
{
    return doCaching;
}

- (NSWindow*)cache
{
    return cache;
}

- (void)setCaching:(BOOL)flag redraw:(BOOL)rd
{
    doCaching = flag;
    if (doCaching)
    {	NSRect	rect;
        int	bits = NSBitsPerPixelFromDepth([NSWindow defaultDepthLimit]);

        rect = [self frame];
        if ((rect.size.width * rect.size.height)*bits/8 < Prefs_CacheLimit)
        {   [self sizeCacheWindow:NSWidth(rect) :NSHeight(rect)];
            if (rd)
                [self draw:rect];
            return;
        }
    }
    [cache release];
    cache = nil; cacheView = nil;
}

/* change cache size
 */
- (void)sizeCacheWindow:(float)width :(float)height
{   int	bits = NSBitsPerPixelFromDepth([NSWindow defaultDepthLimit]);

    if ( doCaching && ((width * height)*bits/8 < Prefs_CacheLimit) )
    {
        if (!cache)
        {
            cacheView = createBuffer([self frame], NO);
            cache = [cacheView window];
            [cacheView scaleUnitSquareToSize:NSMakeSize([self frame].size.width/[self bounds].size.width,
                                                        [self frame].size.width/[self bounds].size.width)];
        }
        [cache   setContentSize:NSMakeSize(width, height)];	// limit 10000 on OpenStep !!
        [cacheView setFrameSize:NSMakeSize(width, height)];
    }
    else if (cache)
    {   [cache release];
        cache = nil; cacheView = nil;
    }
}

/* zoom in or out
 * modified: 2012-08-12 (pass newUnitSize instead of float, realign bounds and frame at 100%)
 * FIXME: bounds/frame is screwed up when scaling to 150% or 300% and back to 100%.
 *        We realign at 100% now, 200% still sucks
 */
- (void)scaleCacheWindow:(NSSize)newUnitSize
{   int bits = NSBitsPerPixelFromDepth([NSWindow defaultDepthLimit]);

    //printf("c1. u.w = %f b.w = %f f.w = %f\n", newUnitSize.width, cacheView->_bounds.size.width, cacheView->_frame.size.width);
    /* the scrollview must allready be scaled */
    if ( ([self frame].size.width * [self frame].size.height)*bits/8 < Prefs_CacheLimit )
    {
        if (!cache)
        {   cacheView = createBuffer([self bounds], NO);
            cache = [cacheView window];

            /* the scrollview (frame, bounds) has already been scaled */
            [cacheView scaleUnitSquareToSize:NSMakeSize([self frame].size.width/[self bounds].size.width,
                                                        [self frame].size.width/[self bounds].size.width)];
        }
        else
        {
            /* realign rounding issues befor scaling */
            /*if ( [cacheView frame].size.width != [cacheView bounds].size.width )
            {   NSSize  invUnitSize;

                invUnitSize = NSMakeSize([cacheView bounds].size.width  / [cacheView frame].size.width,
                                         [cacheView bounds].size.height / [cacheView frame].size.height);
                [cacheView scaleUnitSquareToSize:invUnitSize]; // reset to 100%
                [cacheView setBoundsSize:[cacheView frame].size];       // bring coords back to normal
                newUnitSize.width  = (newUnitSize.width  / invUnitSize.width);
                newUnitSize.height = (newUnitSize.height / invUnitSize.height);
            }*/
            [cacheView scaleUnitSquareToSize:newUnitSize];
            if ( Diff([cacheView frame].size.width, [cacheView bounds].size.width) < 0.001 )
                [cacheView setBoundsSize:[cacheView frame].size];   // bring coords back to normal
        }
        //printf("c2. u.w = %f b.w = %f f.w = %f\n", newUnitSize.width, cacheView->_bounds.size.width, cacheView->_frame.size.width);
    }
    else
    {	[cache release];
        cache = nil; cacheView = nil;
    }

    [[betaCache contentView] scaleUnitSquareToSize:newUnitSize];
}

- (void)scaleUnitSquareToSize:(NSSize)_newUnitSize
{
    scale *= _newUnitSize.width;
    //printf("v1. u.w = %f b.w = %f f.w = %f\n", _newUnitSize.width, self->_bounds.size.width, self->_frame.size.width);
    [super scaleUnitSquareToSize:_newUnitSize];
    if ( Diff([self frame].size.width, [self bounds].size.width) < 0.001 )  // same in scaleCacheWindow !
        [self setBoundsSize:[self frame].size]; // bring coords back to normal
    //printf("v2. u.w = %f b.w = %f f.w = %f\n", _newUnitSize.width, self->_bounds.size.width, self->_frame.size.width);
    [self scaleCacheWindow:_newUnitSize];

    /* we are called before the frame is changed to fit the scale !
     * Here we keep the frame of the editview always 100%, whatever happens
     * This could go to VText -createText:
     */
    {   NSRect  newFrame = [self frame];

        newFrame.size.width  = NSWidth (newFrame) * _newUnitSize.width  / (scale);
        newFrame.size.height = NSHeight(newFrame) * _newUnitSize.height / (scale);
        if ( Diff(newFrame.size.width, [editView frame].size.width) > 0.1 )    // in case something rips this apart
        {
            NSLog(@"Note for scaleUnitSquareToSize: editView corrected to view size {%.1f %.1f} -> {%.1f %.1f}",
                  newFrame.size.width, newFrame.size.height,
                  [editView frame].size.width, [editView frame].size.height);
            [editView setFrame:newFrame];	// workaround: editview is resized bad , may end up with zero size
        }
        //printf("unitSize = %f  scale = %f  newFrame = {%f %f}\n", _newUnitSize.width, scale, newFrame.size.width, newFrame.size.height);
    }
}

/*
 * sizeTo:: is called whenever the view is resized. It resizes the bitmap cache
 * along with the view. It doesn't do anything if the new size is equal to the
 * old one.
 */
- (void)setFrameSize:(NSSize)_newSize
{   int		l;
    NSRect	bounds;

    if ( _newSize.width == [self frame].size.width && _newSize.height == [self frame].size.height )
        return;

    [super setFrameSize:_newSize];	// OpenStep: newSize/scale >= 10000 -> DPS errors !
    [self sizeCacheWindow:_newSize.width :_newSize.height];

    if ( [self gridIsEnabled] )
        [self resetGrid];

    /* resize performance map */
    bounds = [self bounds];
    for (l=0; l<(int)[layerList count]; l++)
    {   LayerObject	*layerObject = [layerList objectAtIndex:l];

        [[layerObject performanceMap] resizeFrame:bounds initWithList:[layerObject list]];
    }
}

- (NSMutableArray*)layerList
{
    return layerList;
}
- (NSMutableArray*)slayList
{
    return slayList;
}


/*
 * printing stuff
 */

/* return YES for multi page document
 * created: 2005-09-01
 */
- (BOOL)isMultiPage
{   int	l;

    for (l=0; l<(int)[layerList count]; l++)
        if ( [(LayerObject*)[layerList objectAtIndex:l] type] == LAYER_PAGE )
            return YES;
    return NO;
}
- (int)pageCount
{   int	l, cnt = 0;

    for (l=0; l<(int)[layerList count]; l++)
        if ( [(LayerObject*)[layerList objectAtIndex:l] type] == LAYER_PAGE )
            cnt++;
    return cnt;
}
/* DEPRECATED since long ago */
/*- (BOOL)knowsPagesFirst:(NSInteger*)firstPageNum last:(NSInteger*)lastPageNum
{
    if ([self isMultiPage])
    {
        *firstPageNum = 1;
        *lastPageNum  = [self pageCount];
        return YES;
    }
    return NO;
}*/
- (BOOL)knowsPageRange:(NSRangePointer)aRange
{
    if ([self isMultiPage])
    {
        *aRange = NSMakeRange(1, [self pageCount]);
        return YES;
    }
    return NO;
}
- (NSRect)rectForPage:(NSInteger)pageNumber
{   int	l, cnt = 1;

    /* enable page to print */
    for (l=0; l<(int)[layerList count]; l++)
    {   LayerObject	*layerObject = [layerList objectAtIndex:l];

        if ( [(LayerObject*)layerObject type] == LAYER_PAGE )
        {
            if ( cnt == pageNumber )	// turn on page to print
                [layerObject setState:1];
            else			// turn off all other pages
                [layerObject setState:0];
            cnt++;
        }
    }
    return [self bounds];
}


/* modified: 2001-08-20
 */
- (void)insertGraphic:g
{   int	l, cnt = [layerList count];

    for (l=0; l<cnt; l++)
    {	LayerObject	*layerObject = [layerList objectAtIndex:l];
        NSMutableArray	*slist = [slayList objectAtIndex:l];

        if ( [layerObject editable] )
        {
            if ( [[layerObject list] indexOfObject:g] != NSNotFound )
                return;
            [layerObject addObject:g];
            if ( [g isSelected] )
                [slist addObject:g];
            [self cache:[g extendedBoundsWithScale:scale]];
            [g setDirty:YES];
            [document setDirty:YES];
            return;
        }
    }
}

/* created: 01.10.1999
 */
- (void)insertGraphic:g onLayer:(int)layerIx
{
    if ( layerIx < (int)[layerList count] )
    {	LayerObject	*layer = [layerList objectAtIndex:layerIx];
        NSMutableArray	*slist = [slayList objectAtIndex:layerIx];

        if ( [layer editable] )
        {
            if ( [[layer list] indexOfObject:g] != NSNotFound )
                return;
            [layer addObject:g];
            if ( [g isSelected] )
                [slist addObject:g];
            [g setDirty:YES];
            [document setDirty:YES];
            return;
        }
    }
    else
        NSLog(@"Layer %d beyond bounds!", layerIx);
}

/* created: 12.03.99
 */
#define SORT_ROW_ULLR 0
#define SORT_ROW_LLUR 1
#define SORT_COL_ULLR 2
#define SORT_COL_LLUR 3
#define SORT_COL_URLL 4
#define SORT_COL_LRUL 5
#define SORT_ROW_URLL 6
#define SORT_ROW_LRUL 7
NSInteger sortPosition(id g1, id g2, void *context)
{   NSPoint	p1 = [g1 bounds].origin, p2 = [g2 bounds].origin;
    int		sort = *(int*)context;

    if ( sort <= SORT_COL_LLUR )
    {
        if ( sort==SORT_ROW_ULLR || sort==SORT_ROW_LLUR )
        {
            if ( p1.y < p2.y )
                return (sort==SORT_ROW_ULLR) ? NSOrderedDescending : NSOrderedAscending;
            if ( p1.y == p2.y )
            {
                if ( p1.x < p2.x )
                    return NSOrderedAscending;
                if ( p1.x > p2.x )
                    return NSOrderedDescending;
                return NSOrderedSame;
            }
            return (sort==SORT_ROW_ULLR) ? NSOrderedAscending : NSOrderedDescending;
        }
        if ( p1.x /*+ TOLERANCE*/ < p2.x )
            return NSOrderedAscending;
        if ( Diff(p1.x, p2.x) <= TOLERANCE )
        {
            if ( p1.y < p2.y )
                return (sort==SORT_COL_LLUR) ? NSOrderedAscending : NSOrderedDescending;
            if ( p1.y > p2.y )
                return (sort==SORT_COL_LLUR) ? NSOrderedDescending : NSOrderedAscending;
            /*if ( p1.x < p2.x )
                return NSOrderedAscending;*/
            return NSOrderedSame;
        }
        return NSOrderedDescending;
    }
    else
    {
        if ( sort==SORT_ROW_URLL || sort==SORT_ROW_LRUL )
        {
            if ( p1.y < p2.y )
                return (sort==SORT_ROW_URLL) ? NSOrderedDescending : NSOrderedAscending;
            if ( p1.y == p2.y )
            {
                if ( p1.x > p2.x )
                    return NSOrderedAscending;
                if ( p1.x < p2.x )
                    return NSOrderedDescending;
                return NSOrderedSame;
            }
            return (sort==SORT_ROW_URLL) ? NSOrderedAscending : NSOrderedDescending;
        }
        if ( p1.x /*+ TOLERANCE*/ > p2.x )
            return NSOrderedAscending;
        if ( Diff(p1.x, p2.x) <= TOLERANCE )
        {
            if ( p1.y < p2.y )
                return (sort==SORT_COL_LRUL) ? NSOrderedAscending : NSOrderedDescending;
            if ( p1.y > p2.y )
                return (sort==SORT_COL_LRUL) ? NSOrderedDescending : NSOrderedAscending;
            /*if ( p1.x > p2.x )
                return NSOrderedAscending;*/
            return NSOrderedSame;
        }
        return NSOrderedDescending;
    }
}

/* string to array
 * sort into textGraphics (ordered as it is, ordered from UL to LR, ordered from LR to UL)
 */
- (void)importASCII:(NSString*)string sort:(int)sort
{   NSScanner		*scanner = [NSScanner scannerWithString:string];
    NSCharacterSet	*skipSet = [NSCharacterSet characterSetWithCharactersInString:@" \n\r"];
    NSMutableArray	*array = [NSMutableArray array], *textArray = [NSMutableArray array];
    NSString		*str;
    int			l, cnt = [layerList count], i, iCnt;

    /* TAB -> use TAB as separator, not ' ' */
    if ([string rangeOfString:@"\t"].length != 0)
        skipSet = [NSCharacterSet characterSetWithCharactersInString:@"\t\n\r"];
    [scanner setCharactersToBeSkipped:[NSCharacterSet characterSetWithCharactersInString:@""]];
    [scanner scanCharactersFromSet:skipSet intoString:NULL];
    while ( ![scanner isAtEnd] )
    {   int location = [scanner scanLocation];

        /* up to location != ' ' */
        if ( ![scanner scanUpToCharactersFromSet:skipSet intoString:&str] )
            str = @"";
        /* '"' -> scan up to '"' */
        if ( [str hasPrefix:@"\""] )
        {
            [scanner setScanLocation:location+1];
            if ( ![scanner scanUpToString:@"\"" intoString:&str] )
                str = @"";
            [scanner scanString:@"\"" intoString:NULL];
        }
        str = [str stringByReplacing:@"\\n" by:@"\n"];
        str = [str stringByReplacing:@"\\t" by:@"\t"];
        [scanner scanCharactersFromSet:skipSet intoString:NULL];
        [array addObject:str];
    }

    for ( l=0; l<cnt; l++ )
    {	NSMutableArray	*list = [[layerList objectAtIndex:l] list];

        if ( ![[layerList objectAtIndex:l] editable] )
            continue;
        for ( i=0, iCnt=[list count]; i<iCnt; i++ )
        {   id	g = [list objectAtIndex:i];

            if ( ![g respondsToSelector:@selector(replaceTextWithString:)] || [g isSerialNumber] || [g isLocked] )
                continue;
            [textArray addObject:g];
            [[layerList objectAtIndex:l] setDirty:YES calculate:NO];
        }
    }

    [textArray sortUsingFunction:sortPosition context:&sort];

    for ( i=0, iCnt=[textArray count]; i<iCnt && i<(int)[array count]; i++ )
        [[textArray objectAtIndex:i] replaceTextWithString:[array objectAtIndex:i]];

    [document setDirty:YES];
    [self drawAndDisplay];
}

- (void)moveSelectionToLayer:(int)index
{   int			l, i;
    LayerObject		*targetLayer = [layerList objectAtIndex:index];
    NSMutableArray	*targetSList = [slayList objectAtIndex:index];

    if (![targetLayer editable])
        return;

    for (l=[slayList count]-1; l>=0; l--)
    {	NSMutableArray	*slist = [slayList objectAtIndex:l];
        LayerObject	*layerObject = [layerList objectAtIndex:l];

        if (l == index || ![layerObject editable])
            continue;
        for (i=[slist count]-1; i>=0; i--)		// remove from old layer, set objects dirty
        {   [layerObject removeObject:[slist objectAtIndex:i]];
            [[slist objectAtIndex:i] setDirty:YES];
        }
        [targetLayer addObjectsFromArray:slist];	// add to new layer
        [targetSList addObjectsFromArray:slist];	// add to selection list of new layer
        [slist removeAllObjects];
    }

    [document setDirty:YES];
    [self drawAndDisplay];
}

- (void)setAllLayerDirty:(BOOL)flag
{   int	l, layCnt;

    layCnt = [layerList count];
    for (l=0; l<layCnt; l++)
    {   LayerObject	*layerObject = [layerList objectAtIndex:l];

        if ([layerObject type] != LAYER_CLIPPING)
            [layerObject setDirty:YES calculate:NO];
    }
    [document setDirty:YES];
}

- (VCrosshairs*)origin
{
    return origin;
}

/* convert point to and from virtual origin
 */
- (NSPoint)pointRelativeOrigin:(NSPoint)p
{   NSPoint	offset = [origin pointWithNum:0];

    p.x -= offset.x;
    p.y -= offset.y;
    return p;
}
- (NSPoint)pointAbsolute:(NSPoint)p
{   NSPoint	offset = [origin pointWithNum:0];

    p.x += offset.x;
    p.y += offset.y;
    return p;
}

- (id)clipObject
{   int	l, i;

    for ( l=0; l<(int)[layerList count]; l++ )
        if ( [(LayerObject*)[layerList objectAtIndex:l] type] == LAYER_CLIPPING )
        {   LayerObject		*layer = [layerList objectAtIndex:l];
            NSMutableArray	*cList = [layer list];

            if ( [cList count]>1 || ([cList count] && ![[cList objectAtIndex:0] isKindOfClass:[VRectangle class]]) )
            {
                NSRunAlertPanel(@"", LAYERONLYFORRECTANGLE_STRING, OK_STRING, nil, nil);
                if ([cList count]>1)
                    for (i=[cList count]-1; i>=1; i--)
                        [layer removeObject:[cList objectAtIndex:i]];
                else
                    [layer removeObject:[cList objectAtIndex:0]];
                return nil;
            }
            else if ( [cList count] )
                return [cList objectAtIndex:0];
        }

    return nil;
}

- (int)indexOfSelectedLayer		{ return indexOfSelectedLayer; }
- (void)selectLayerAtIndex:(int)ix	{ indexOfSelectedLayer = ix; }

- (int)layerIndexOfGraphic:(VGraphic*)g
{   int	l;

    for ( l=[layerList count]-1; l>=0; l-- )
        if ( [[[layerList objectAtIndex:l] list] containsObject:g] )
            return l;
    NSLog(@"Graphic %@ not contained on any layer", [g title]);
    return -1;
}
- (LayerObject*)layerOfGraphic:(VGraphic*)g
{   int	l;

    if ([g isKindOfClass:[VCrosshairs class]])
        return nil;
    for ( l=[layerList count]-1; l>=0; l-- )
        if ( [[[layerList objectAtIndex:l] list] containsObject:g] )
            return [layerList objectAtIndex:l];
    NSLog(@"Graphic %@ not contained on any layer", [g title]);
    return nil;
}

/* created:  1996-04-26
 * modified: 
 * purpose:  remove object from list
 */
- (void)removeGraphic:g
{   int		l;

    for (l=[slayList count]-1; l>=0; l--)
    {	LayerObject     *layer = [layerList objectAtIndex:l];
        NSMutableArray	*slist = [slayList objectAtIndex:l];

        if (![[layer list] count] || ![layer editable])
            continue;
        [layer removeObject:g];
        [slist removeObject:g];
    }
}

/*
 * Resets slayList by going through the layerlist and locating all the Graphics
 * which respond YES to the isSelected method.
 */
- (void)getSelection
{   int         i, iCnt, l;
    VGraphic    *graphic;

    [slayList removeAllObjects];
    for (l=0; l<(int)[layerList count]; l++)
    {	NSMutableArray	*list = [[layerList objectAtIndex:l] list];
        NSMutableArray	*slist = [NSMutableArray array];

        [slayList addObject:slist];
        if (![(LayerObject*)[layerList objectAtIndex:l] state] || !(iCnt=[list count]))
            continue;
        for (i=0; i<iCnt; i++)
        {   graphic = [list objectAtIndex:i];
            if ([graphic isSelected])
                [slist addObject:graphic];
        }
    }
}

/*
 * Returns the size of the control point scaled to reflect the
 * current scale. If the scaling were not done, a control point
 * would look like the USS Enterprise at 400%. (The aircraft
 * carrier.) 
 *	
 */
- (float)controlPointSize
{
    return  KNOBSIZE * (1.0/scale);
}

- (float)scaleFactor
{
    return  scale;
}


- (void)drawControls:(NSRect)rect
{   int	l, i;

    for ( l=[layerList count]-1; l>=0; l-- )
    {	NSMutableArray	*list = [[layerList objectAtIndex:l] list];

        if ( ![list count] )
            continue;
        for ( i=[list count]-1; i>=0; i-- )
        {   [[list objectAtIndex:i] drawKnobs:rect    direct:NO scaleFactor:scale];
            [[list objectAtIndex:i] drawControls:rect direct:NO scaleFactor:scale];
        }
    }
    [VGraphic showFastKnobFills];
}

/*
 * drawSelf: composite cache and draw knobs
 * modified: 2012-04-13 (centerScanRect back again)
 *           2012-02-13 (centerScanRect removed as it destroys the result)
 *           2005-11-14 (apple workaround for composite)
 */
- (void)drawRect:(NSRect)rect
{   NSRect	r, vRect;

    if ( !VHFIsDrawingToScreen() )  // we are printing
    {	[self draw:rect];		// draw only the graphic objects
        return;
    }

    if (NSIsEmptyRect(rect))
        rect = [self bounds];

    vRect = [self visibleRect]; // limit redraw to visible area
    r = rect;
    r = NSIntersectionRect(vRect, r);
    if (cache)  // copy cache
    {   NSPoint	toP;

        r.origin.x    = floor(r.origin.x);  // 2012-02-13
        r.origin.y    = floor(r.origin.y);
        r.size.width  = ceil(r.size.width)  + 1.0;
        r.size.height = ceil(r.size.height) + 1.0;
        r = [self centerScanRect:r];    // Das ist die Loesung gegen ein "Pixel-Versetzt"-Geschmoddel
        toP = r.origin;                 // destination point
#ifdef __APPLE__	// workaround to fix scaling of the composite source rectangle (frame)
        r.origin.x    *= scale;
        r.origin.y    *= scale;
        r.size.width  *= scale;
        r.size.height *= scale;
#endif
        NSCopyBits([cacheView gState], r, toP);
    }
    else        // draw directly to screen
    {
        [self draw:r];
    }

    /* module: draw stuff outside of cache windows (decoration) */
    [[NSNotificationCenter defaultCenter] postNotificationName:DocViewDrawDecoration
                                                        object:self userInfo:nil];

    /* draw control points and lines */
    if ( VHFIsDrawingToScreen() && !scrolling )
        [self drawControls:rect];

    /* FIXME, Apple: if cache is disabled, autodisplay makes everything redraw endlessly
     * probably this is related to text drawing
     * needsDisplay is always = YES, no matter what
     */
    if ( ! cache )
    {
/*#       ifdef __APPLE__    // workaround for touch events flooding us with displayIfNeeded requests (SysDefined, subtype = 7)
        NSEvent *event = [[self window] currentEvent];
        if ( [event type] == NSSystemDefined && [event subtype] == 7 )  // NSTouchPhaseBegan|NSTouchPhaseMoved|NSTouchPhaseStationary )
        {
            printf("DocView -drawRect: %s, event = %s, rect = {%.0f %.0f %.0f %.0f}\n",
                   [[self description] UTF8String],
                   [[event description] UTF8String],
                   rect.origin.x, rect.origin.y, rect.size.width, rect.size.height);
            return;
        }
#       endif*/
        /*printf("DocView -drawRect: %s, event = %s, rect = {%.0f %.0f %.0f %.0f}\n",
         [[self description] UTF8String],
         [[[[self window] currentEvent] description] UTF8String],
         rect.origin.x, rect.origin.y, rect.size.width, rect.size.height);*/
        //printf("DocView -drawRect: needsDisplay=%d\n", [self needsDisplay]);
        [self setNeedsDisplayInRect:NSZeroRect];
        [self setNeedsDisplay:NO];  // we just did, but this method is doing nothing !?
        //printf("  DocView -drawRect: needsDisplay=%d\n", [self needsDisplay]);
    }
}

/* this only updates the controls, but doesn't redraw the cache
 */
- (void)flatRedraw:(NSRect)rect
{
    if (redrawEntireView)	// something is too large to keep control over the size
        [self cache:rect];
    else
    {
        [self lockFocus];
        [self drawRect:rect];
        [self unlockFocus];
        [[self window] flushWindow];
    }
}

- (void)cache:(NSRect)rect
{
    if ( [self window] && [[self window] windowNumber] >= 0 )
    {
        if (redrawEntireView)
            rect = [self bounds];
        if (cache)
            [self draw:rect];
        [self lockFocus];
        [self drawRect:rect];
        [self unlockFocus];
        [[self window] flushWindow];
    }
}

- (void)drawAndDisplay
{
    [self cache:[self bounds]];
}

- (void)cacheGraphic:(VGraphic*)g
{
    [((cache && VHFIsDrawingToScreen()) ? cacheView : self) lockFocus];
    [g drawWithPrincipal:self];
    //[VGraphic showFastKnobFills];
    [((cache && VHFIsDrawingToScreen()) ? cacheView : self) unlockFocus];
}

- (BOOL)displayGraphic	{ return displayGraphic; }
- (BOOL)mustDrawPale	{ return mustDrawPale; }
- (void)setRedrawEntireView:(BOOL)flag	{ redrawEntireView = flag; return; }
- (BOOL)redrawEntireView		{ return redrawEntireView; }

/* return template layer
 * created: 2005-09-01
 */
- (LayerObject*)template:(LayerType)layerType
{   int	l;

    for (l=0; l<(int)[layerList count]; l++)
    {	LayerObject	*layerObject = [layerList objectAtIndex:l];

        if ([layerObject type] == layerType)
            return layerObject;
    }
    return nil;
}
/* return template object with name and template
 * created:  2005-11-07 (cast g to VText)
 * modified: 2009-03-19 (check for layerObject == nil)
 */
- (VGraphic*)templateObjectWithName:(NSString*)name
                       fromTemplate:(LayerObject*)layerObject
{   int		i;
    NSArray	*list = [layerObject list];

    if (!layerObject)
        return nil;
    for (i=0; i<(int)[list count]; i++)
    {	VGraphic	*g = [list objectAtIndex:i];

        if ([g isKindOfClass:[VText class]])
        {   VText	*text = (VText*)g;
            NSRange	range = [[text string] rangeOfString:name];

            if (range.length)
                return [[text copy] autorelease];
            /*{   NSMutableString	*string = [[[text string] mutableCopy] autorelease];

                text = [[text copy] autorelease];
                [string replaceCharactersInRange:range withString:string];
                [text replaceTextWithString:string];
                return text;
            }*/
        }
    }
    return nil;
}

- (void)drawTemplate:(LayerObject*)template forLayer:(LayerObject*)layerObject
{   VText       *text;
    int         i;

    /* Set Page Number and Count */
    if ( (text = (VText*)[self templateObjectWithName:@"#PAGENUM#" fromTemplate:template]) )
    {
        text = [[text copy] autorelease];
        [text replaceSubstring:@"#PAGENUM#" withString:[layerObject string]];
        [text replaceSubstring:@"#PAGECNT#"
                    withString:[NSString stringWithFormat:@"%d", [self pageCount]]];
        [text drawWithPrincipal:self];
    }
    /* Set Date */
    if ( (text = (VText*)[self templateObjectWithName:@"#DATE_" fromTemplate:template]) )
    {   NSString    *str = [text string];
        NSRange     range1, range2;

        range1 = [str rangeOfString:@"#DATE_"];
        if (range1.length)
            range2 = [str rangeOfString:@"#" options:0 range:NSMakeRange(range1.location+1, [str length]-range1.location-1)];
        if (range1.length && range2.length)
        {   NSString    *dateFormat = [str substringWithRange:NSMakeRange(range1.location+range1.length, range2.location-(range1.location+range1.length))];
            NSString    *dateStr = [[NSCalendarDate date] descriptionWithCalendarFormat:dateFormat];

            if (!dateStr)
                dateStr = [NSString stringWithFormat: @"Illegal date format: '%@'", dateFormat];
            text = [[text copy] autorelease];
            //str = [str substringWithRange:NSMakeRange(range1.location, range2.location+1-range1.location)];
            //[text replaceSubstring:str withString:dateStr];
            [text replaceCharactersInRange:NSMakeRange(range1.location, range2.location+1-range1.location) withString:dateStr];
            [text drawWithPrincipal:self];
        }
    }
    /* Draw other elements */
    if ( [template type] == LAYER_TEMPLATE_1 || [template type] == LAYER_TEMPLATE_2 )   // for even/odd template only
    {
        for ( i=0; i<(int)[[template list] count]; i++ )
        {	VGraphic	*g = [[template list] objectAtIndex:i];

            if ([g isKindOfClass:[VText class]])
            {   NSString    *string = [(VText*)g string];

                if ( [string rangeOfString:@"#PAGE"].length ||
                        [string rangeOfString:@"#DATE_"].length )
                    continue;
            }
            [g drawWithPrincipal:self];
        }
    }
}

/* redraw cache contents or draw for printing
 * modified: 2009-13-19 (display #DATE_...#, display non-template elements on even/odd template layer)
 */
- (void)draw:(NSRect)rect
{   int		j, l, lCnt;

    if (cache && VHFIsDrawingToScreen())
        [cacheView lockFocus];
    else
        [self lockFocus];

    VHFSetAntialiasing(Prefs_Antialias);

    if (NSIsEmptyRect(rect))
        rect = [self bounds];

    if (VHFIsDrawingToScreen())
    {
        if (backgroundColor)
        {   [backgroundColor set];
            NSRectFill(rect);
        }
        else
            NSEraseRect(rect);
    }

    NSRectClip(rect);

    [self drawGrid];

    /* display graphic */
    [NSBezierPath setDefaultLineWidth:(VHFIsDrawingToScreen() ? 1.0/scale : 0.1)];
    if ( displayGraphic )
    {   int templateIx, templateIxOdd, templateIxEven;

        templateIx = templateIxOdd = templateIxEven = [layerList count];

        if ( drawPale )	// set by modules, if we have to draw the graphic objects in pale colors
            mustDrawPale = YES;
        for ( l=0, lCnt=[layerList count]; l<lCnt; l++ )
        {   LayerObject	*layerObject = [layerList objectAtIndex:l];
            int         pageNum = [[layerObject string] intValue];  // Note: this works only with real page numbers

            if ( [layerObject invisible] == YES )
                continue; // we dont draw graphics

            if ( [layerObject type]      == LAYER_TEMPLATE )
                templateIx     = l;
            else if ( [layerObject type] == LAYER_TEMPLATE_1 )
                templateIxOdd  = l; // needed to draw templates in correct order for the pages
            else if ( [layerObject type] == LAYER_TEMPLATE_2 )
                templateIxEven = l;

            /* draw template before page content */
            if ([layerObject state] && [layerObject type] == LAYER_PAGE)
            {
                if (templateIx < l)
                    [self drawTemplate:[self template:LAYER_TEMPLATE]   forLayer:layerObject];
                if (pageNum%2 != 0 && templateIxOdd  < l)
                    [self drawTemplate:[self template:LAYER_TEMPLATE_1] forLayer:layerObject];
                if (pageNum%2 == 0 && templateIxEven < l)
                    [self drawTemplate:[self template:LAYER_TEMPLATE_2] forLayer:layerObject];
            }

            [layerObject draw:rect inView:self];

            /* draw template after page content */
            if ([layerObject state] && [layerObject type] == LAYER_PAGE)
            {
                if (templateIx > l)
                    [self drawTemplate:[self template:LAYER_TEMPLATE]   forLayer:layerObject];
                if (pageNum%2 != 0 && templateIxOdd  > l)
                    [self drawTemplate:[self template:LAYER_TEMPLATE_1] forLayer:layerObject];
                if (pageNum%2 == 0 && templateIxEven > l)
                    [self drawTemplate:[self template:LAYER_TEMPLATE_2] forLayer:layerObject];
            }
        }
        mustDrawPale = NO;
    }

    /* draw additional stuff in modules */
    [NSBezierPath setDefaultLineWidth:(VHFIsDrawingToScreen() ? 1.0/scale : 0.1)];
    [[NSNotificationCenter defaultCenter] postNotificationName:DocViewDrawGraphicAdditions
                                                        object:self userInfo:nil];

    /* batch production */
    if ( tileOriginList && [tileOriginList count] )
    {   int	cnt = [tileOriginList count];

        if (displayGraphic)	// draw the rectangles only once
        {   NSPoint	masterP = [(TileObject*)[tileOriginList objectAtIndex:0] position];

            PSgsave();
            [[NSColor blackColor] set];
            [NSBezierPath setDefaultLineWidth:(VHFIsDrawingToScreen() ? 1.0/scale : 0.1)];
            for (j=1; j<cnt; j++)
            {   TileObject  *obj = [tileOriginList objectAtIndex:j];
                NSPoint     objP = [obj position], p;

                p = NSMakePoint(objP.x-masterP.x, objP.y-masterP.y);

                /* draw rectangles for all tiles */
                if (VHFIsDrawingToScreen())	// screen
                {
                    [NSBezierPath strokeRect:NSMakeRect(objP.x, objP.y, tileSize.width, tileSize.height)];
                    //NSFrameRectWithWidth(NSMakeRect(objP.x, objP.y, tileSize.width, tileSize.height), 1.0/scale);
                }
                /* draw tiles */
                else				// printing
                {
#if defined(__APPLE__) || defined(GNUSTEP_BASE_VERSION)
                    NSAffineTransform   *xform = [NSAffineTransform transform];
                    PSgsave();
                    //p1 = [self convertPoint:p fromView:nil];
                    //[self setBoundsOrigin:NSMakePoint(-p1.x, -p1.y)];   // this fails with window size < document
                    [xform translateXBy:p.x yBy:p.y];
                    [xform concat];
#else	// OpenStep
                    PSgsave();
                    PStranslate(p.x, p.y);
#endif
                    for ( l=0, lCnt=[layerList count]; l<lCnt; l++ )
                    {   LayerObject *layerObject = [layerList objectAtIndex:l];
                        NSArray     *list = [layerObject list];
                        int         i, liCnt;

                        if ( [layerObject invisible] == YES )
                            continue;

                        if ([layerObject state] && [layerObject useForTile])
                        {
                            for (i=0, liCnt=[list count]; i<liCnt; i++)
                            {   id	g = [list objectAtIndex:i];

                                if ([g respondsToSelector:@selector(isSerialNumber)] && [g isSerialNumber])
                                    ; // [g drawSerialNumberAt:p withOffset:j];
                                else
                                    [g drawWithPrincipal:self];
                            }
                        }
                    }
//#ifdef __APPLE__
                    [self setBoundsOrigin:NSZeroPoint];
//#endif
                    PSgrestore();
                }
                [serialNumber drawSerialNumberAt:p withOffset:j];
            }
            PSgrestore();
        }
        /* draw additional batch stuff in modules */
        [[NSNotificationCenter defaultCenter] postNotificationName:DocViewDrawBatchAdditions
                                                            object:self userInfo:nil];
    }

    /* origin - crosshairs */
    if ( VHFIsDrawingToScreen() )
        [origin drawWithPrincipal:self];

    if (cache && VHFIsDrawingToScreen())
        [cacheView unlockFocus];
    else
        [self unlockFocus];
}


/*
 * Places the graphic centered at the given location on the page.
 */
- (BOOL)placeGraphic:(VGraphic*)graphic at:(NSPoint)location
{   NSPoint	offset;
    NSRect	bbox;
    id		change;

    if ( graphic )
    {
        [self deselectAll:self];

        bbox = [graphic extendedBoundsWithScale:[self scaleFactor]];
        offset.x = location.x - bbox.origin.x - bbox.size.width/2.0;
        offset.y = location.y - bbox.origin.y - bbox.size.height/2.0;

        [graphic moveBy:offset];

        change = [[CreateGraphicsChange alloc] initGraphicView:self graphic:graphic];
        [change startChangeIn:self];
            [graphic setSelected:YES];
            [self insertGraphic:graphic];
	[change endChange];
    }

    return YES;
}

/*
 * Places the graphic centered at the given location on the page.
 */
- (BOOL)placeList:(NSMutableArray*)aList at:(NSPoint)location
{   NSPoint	offset;
    NSRect	bbox;
    int		i, l;

    if (aList && [aList count])
    {
        bbox = [self boundsOfArray:aList withKnobs:NO];
        offset.x = location.x - bbox.origin.x - bbox.size.width/2.0;
        offset.y = location.y - bbox.origin.y - bbox.size.height/2.0;
        for (l=[layerList count]-1; l>=0; l--)
        {   LayerObject		*layerObject = [layerList objectAtIndex:l];
            NSMutableArray	*slist = [slayList objectAtIndex:l];

            [slist removeAllObjects];

            if (![(NSArray*)[aList objectAtIndex:l] count])
                continue;

            [[layerObject list] makeObjectsPerformSelector:@selector(moveBy:) withObject:(id)&offset];

            for (i=[(NSArray*)[aList objectAtIndex:l] count]-1; i>=0; i--)
            {	VGraphic	*g = [[aList objectAtIndex:l] objectAtIndex:i];

                [g setSelected:YES];
                [layerObject addObject:g];	// push all objects to the 1st editable layer
                [slist addObject:g];
            }
        }

        bbox = [self boundsOfArray:aList withKnobs:YES];
        [self cache:bbox];

        [aList release];
    }

    return YES;
}

- (NSRect)boundsOfArray:(NSArray*)list
{
    return [self boundsOfArray:list withKnobs:YES];
}
- (NSRect)boundsOfArray:(NSArray*)list withKnobs:(BOOL)knobs
{   int		i, l;
    NSRect	rect, bbox = NSZeroRect;

    if ( ![list count] )
        return bbox;

    /* layer list */
    if ( [[list objectAtIndex:0] isKindOfClass:[LayerObject class]] )
    {
        for (l=[list count]-1; l>=0; l--)
        {
            if ( [[[list objectAtIndex:l] list] count] )
            {
                rect = [self boundsOfArray:[[list objectAtIndex:l] list] withKnobs:knobs];
                bbox = (!bbox.size.width) ? rect : NSUnionRect(rect, bbox);
            }
        }
        return bbox;
    }
    /* slayList */
    else if ( [[list objectAtIndex:0] isKindOfClass:[NSMutableArray class]] )
    {
        for (l=[list count]-1; l>=0; l--)
        {
            if ( [(NSArray*)[list objectAtIndex:l] count] )
            {
                rect = [self boundsOfArray:[list objectAtIndex:l] withKnobs:knobs];
                bbox = (!bbox.size.width) ? rect : NSUnionRect(rect, bbox);
            }
        }
        return bbox;
    }

    /* graphic list */
    if (knobs)
        bbox = [[list objectAtIndex:0] extendedBoundsWithScale:[self scaleFactor]];
    else
        bbox = [[list objectAtIndex:0] bounds];
    for (i=[list count]-1; i>0; i--)
    {
        if (knobs)
            rect = [[list objectAtIndex:i] extendedBoundsWithScale:[self scaleFactor]];
        else
            rect = [[list objectAtIndex:i] bounds];
        bbox = NSUnionRect(rect, bbox);
    }

    return bbox;
}
- (NSRect)coordBoundsOfArray:(NSArray*)list
{   int		i, l;
    NSRect	rect, bbox = NSZeroRect;

    if ( ![list count] )
        return bbox;

    /* layer list */
    if ( [[list objectAtIndex:0] isKindOfClass:[LayerObject class]] )
    {
        for (l=[list count]-1; l>=0; l--)
        {
            if ( [[[list objectAtIndex:l] list] count] )
            {
                rect = [self coordBoundsOfArray:[[list objectAtIndex:l] list]];
                bbox  = (!bbox.size.width) ? rect : NSUnionRect(rect, bbox);
            }
        }
        return bbox;
    }
    /* slayList */
    else if ( [[list objectAtIndex:0] isKindOfClass:[NSMutableArray class]] )
    {
        for (l=[list count]-1; l>=0; l--)
        {
            if ( [(NSArray*)[list objectAtIndex:l] count] )
            {
                rect = [self coordBoundsOfArray:[list objectAtIndex:l]];
                bbox = (!bbox.size.width) ? rect : NSUnionRect(rect, bbox);
            }
        }
        return bbox;
    }
    /* graphic list */
    bbox = [[list objectAtIndex:0] coordBounds];
    for (i=[list count]-1; i>0; i--)
    {
        rect = [[list objectAtIndex:i] coordBounds];
        bbox = VHFUnionRect(rect, bbox);
    }

    return bbox;
}

- (void)scrollPointToVisible:(NSPoint)point
{   NSRect	r;
    float	tol = 5.0 / [self scaleFactor];

    r.origin.x = point.x - tol;
    r.origin.y = point.y - tol;
    r.size.width = r.size.height = 2*tol;

    [self scrollRectToVisible:r];
}

/*
 * Scrolls to rectangle passed in if it is not in visible portion of the view.
 * If the rectangle is larger in width or height than the view, the scrollRectToVisible
 * method is not altogether consistent. As a result, the rectangle contains only
 * the image that was previously visible.
 */
- (void)scrollToRect:(NSRect)toRect
{   NSRect	visRect;

    visRect = [self visibleRect];
    if (!NSContainsRect(visRect , toRect))
    {
        scrolling = YES;
        [[self window] disableFlushWindow];
        [self scrollRectToVisible:toRect];
        [[self window] enableFlushWindow];
        scrolling = NO;

        startTimer(&inTimerLoop);
    }
    else
        stopTimer(&inTimerLoop); 
}

/*
 * Constrain the point within the view. An offset is needed because when
 * an object is moved, it is often grabbed in the center of the object. If the
 * lower left offset and the upper right offset were not included then part of
 * the object could be moved off of the view. (In some applications, that might
 * be allowed but in this one the object is constrained to always lie in the
 * page.)
 */
- (void)constrainPoint:(NSPoint *)aPt withOffset:(const NSSize*)llOffset :(const NSSize*)urOffset
{   NSPoint	viewMin, viewMax;

    viewMin.x = [self bounds].origin.x + llOffset->width;
    viewMin.y = [self bounds].origin.y + llOffset->height;

    viewMax.x = [self bounds].origin.x + [self bounds].size.width - urOffset->width;
    viewMax.y = [self bounds].origin.y + [self bounds].size.height  - urOffset->height;

    aPt->x = MAX(viewMin.x, aPt->x);
    aPt->y = MAX(viewMin.y, aPt->y);

    aPt->x = MIN(viewMax.x, aPt->x);	
    aPt->y = MIN(viewMax.y, aPt->y);
}

/*
 * Constrain a rectangle within the view.
 */
- (void)constrainRect:(NSRect *)aRect
{   NSPoint	viewMin, viewMax;

    viewMin.x = [self bounds].origin.x;
    viewMin.y = [self bounds].origin.y;

    viewMax.x = [self bounds].origin.x + [self bounds].size.width  - aRect->size.width;
    viewMax.y = [self bounds].origin.y + [self bounds].size.height - aRect->size.height;

    aRect->origin.x = MAX(viewMin.x, aRect->origin.x);
    aRect->origin.y = MAX(viewMin.y, aRect->origin.y);

    aRect->origin.x = MIN(viewMax.x, aRect->origin.x );	
    aRect->origin.y = MIN(viewMax.y, aRect->origin.y);
}

/* snap *p to point
 * return hit point in *p
 *
 * created:  1996-10-02
 * modified: 2012-02-13
 */
- (BOOL)hitEdge:(NSPoint*)p spare:obj
{   int     l, i;
    float   snap = Prefs_Snap / [self scaleFactor];
    float   controlPointSize = [self controlPointSize];
    BOOL    gotHit = NO;
    NSPoint hitP = *p;
    double  sqrDistBest = MAXFLOAT;

    if (!snap)
        return NO;
    for (l=[layerList count]-1; l>=0; l--)
    {	LayerObject     *layerObj = [layerList objectAtIndex:l];
        NSMutableArray  *list = [layerObj list];

        //if ( ![layerObj state] || ![list count] )
        //    continue;
        if ( ![list count] )
            continue;
        for ( i=[list count]-1; i>=0; i-- )
        {   VGraphic    *g = [list objectAtIndex:i];
            NSPoint     snapPoint;

            if ( [g hitEdge:*p fuzz:snap :&snapPoint :controlPointSize] && g != obj )
            {   //hitP = snapPoint;
                /* if we have more than one hit, we have to get the closest one ! */
                if ( SqrDistPoints(snapPoint, *p) < sqrDistBest )
                {   hitP = snapPoint;
                    sqrDistBest = SqrDistPoints(snapPoint, *p);
                    gotHit = YES;
                }
            }
        }
    }
    if (gotHit)
    {   vhfPlaySound(@"Pop");
        *p = hitP;
        return YES;
    }
    return NO;
}

/*
 * Redraws the graphic. The image from the alpha buffer is composited
 * into the window and then the changed object is drawn atop the
 * old image. A copy of the image is necessary because when the
 * window is scrolled the alpha buffer is also scrolled. When the
 * alpha buffer is scrolled, the old image might have to be redrawn.
 * As a result, a copy is created and the changes performed on the
 * copy.  Care is taken to limit the amount of area that must be
 * composited and redrawn. A timer is started is the scrolling rect
 * moves outside the visible portion of the view.
 *
 * alternate: horicontal or vertical constrain
 * control:   ?
 *
 * modified: 2008-12-01 (FIXME: rect_draw_apple is a hack)
 *           2007-05-08 (apple workaround for NSCopyBits)
 */
- (BOOL)redrawObject:(id)obj :(int)pt_num :(NSRect*)redrawRect
{   BOOL		tracking = YES;
    NSPoint		pt, pt_last, pt_old, delta, pt_start;
    NSRect		rect_start, rect_now, rect_last, rect_scroll, rect_vis, rect_draw_apple;
    NSEvent		*event;
    float		snap = Prefs_Snap / [self scaleFactor];	// snap distance
    NSPoint		snapPoint, p3;		// the point to snap to
    BOOL		alternate, control;
    BOOL		horizConstrain = NO, vertConstrain = NO;
    BOOL		doSnap = NO;
    int			l;
    DocWindow		*window = (DocWindow*)[self window];
    id			change;

#if 0
    [DPSGetCurrentContext() setOutputTraced:YES];
#endif

    if ( [obj isLocked] )
        return NO;

    /* The rect_scroll will cause scrolling whenever it goes outside the
     * visible portion of the view.
     */
    rect_vis = [self visibleRect];
    rect_scroll = [obj scrollRect:pt_num inView:self];
    rect_scroll = NSIntersectionRect(rect_vis, rect_scroll);

    rect_now = rect_start = [obj extendedBoundsWithScale:[self scaleFactor]];
    *redrawRect = rect_last = rect_now;

    pt_last = [obj pointWithNum:pt_num];
    pt_start = pt_old = pt_last;

    event = [[self window] nextEventMatchingMask:NSLeftMouseUpMask|NSLeftMouseDraggedMask];
    alternate = ([event modifierFlags] & NSAlternateKeyMask) ? YES : NO;
    control = ([event modifierFlags] & NSControlKeyMask) ? YES : NO;

    [window setAutodisplay:NO];

    if ([event type] != NSLeftMouseUp)
    {
        /* arc center (and curve pts 1 and 2) will move and noticed single ! */
        if (pt_num != [obj selectedKnobIndex])
            change = [[DragPointGraphicsChange alloc] initGraphicView:self graphic:obj];
        else // all other pts will noticed if obj is selected and the selectedKnobIndex is set
            change = [[MovePointGraphicsChange alloc] initGraphicView:self ptNum:pt_num moveAll:NO];
        [change startChange];
        if (pt_num != [obj selectedKnobIndex])
            [change setPointNum:pt_num];

        while (tracking)
        {
            /* If its a timer event than use the last point. It will be converted to
             * into the view's coordinate so it will appear as a new point.
             */
            pt = ([event type] == NSPeriodic) ? pt_old : (pt_old = [event locationInWindow]);

            pt = [self convertPoint:pt fromView:nil];
            [obj constrainPoint:&pt andNumber:pt_num toView:self];

            delta.x = pt.x - pt_last.x;
            delta.y = pt.y - pt_last.y;

            if (delta.x || delta.y)
            {
                /* vertical/horizontal constrain
                 */
                if (alternate)
                {   if (ABS(delta.x) > ABS(delta.y))
                        horizConstrain = YES;
                    else
                        vertConstrain = YES;
                    alternate = NO;
                }
                if (horizConstrain)
                    delta.y = 0.0;
                else if (vertConstrain)
                    delta.x = 0.0;

                doSnap = NO;
                if (snap)	/* snap to point */
                {   float	controlsize = [self controlPointSize];
                    int		i;
                    NSPoint hitP = pt;
                    double  sqrDistBest = MAXFLOAT;

                    /* find closest point to mouse */
                    for (l=[layerList count]-1; l>=0; l--)
                    {	NSMutableArray	*list = [[layerList objectAtIndex:l] list];

                        if (![(LayerObject*)[layerList objectAtIndex:l] state] || ![list count])
                            continue;
                        for (i=[list count]-1; i >= 0; i--)
                        {   VGraphic	*g = [list objectAtIndex:i];

                            if ( [g hitEdge:pt fuzz:snap :&snapPoint :controlsize] &&
                                 (g != obj || (g == obj && ([g isKindOfClass:[VPolyLine class]] ||
                                                            [g isKindOfClass:[VPath     class]] ||
                                                            [g isKindOfClass:[VArc      class]] ||
                                                            [g isKindOfClass:[VCurve    class]]   ))) )
                            {   doSnap = YES;
                                if ( SqrDistPoints(snapPoint, pt) < sqrDistBest )
                                {   hitP = snapPoint;
                                    sqrDistBest = SqrDistPoints(snapPoint, pt);
                                }
                                //break;
                            }
                        }
                    }
                    if (doSnap)
                    {   snapPoint = hitP;
                        vhfPlaySound(@"Pop");
                        if (!control)	/* update delta */
                        {   delta.x = snapPoint.x - pt_last.x;
                            delta.y = snapPoint.y - pt_last.y;
                        }
                    }
                }
                if ( !doSnap )	/* snap to grid */
                {
                    snapPoint = [self grid:pt];
                    doSnap = YES;
                }

                /* Change the point location and get the new bounds. */
                if (doSnap)
                    [obj movePoint:pt_num to:snapPoint];
                else if ([obj isKindOfClass:[VArc class]])
                    [obj movePoint:pt_num to:pt];
                else
                    [obj movePoint:pt_num by:delta];

                rect_now = [obj extendedBoundsWithScale:[self scaleFactor]];

                /* move all other selected points by delta */
                if (pt_num == [obj selectedKnobIndex])
                {
                    for (l=[layerList count]-1; l>=0; l--)
                    {   NSMutableArray	*list = [[layerList objectAtIndex:l] list];
                        int			i;

                        if (![[layerList objectAtIndex:l] editable] || ![list count])
                            continue;
                        for (i=[list count]-1; i>=0; i--)
                        {   VGraphic	*g = [list objectAtIndex:i];

                            if ([g isSelected] && g!=obj && [g selectedKnobIndex] >= 0)
                            {
                                [g movePoint:[g selectedKnobIndex] by:delta];
                                rect_now = NSUnionRect(rect_now, [g extendedBoundsWithScale:[self scaleFactor]]);
                            }
                        }
                    }
                }
                [obj getPoint:pt_num :&p3];	/* display coordinates */
                [window displayCoordinate:p3 ref:NO];

                /* Change the scrolling rectangle. */
                rect_scroll = NSOffsetRect(rect_scroll, delta.x, delta.y);
                [self scrollToRect:rect_scroll];

                /* Composite the old image and then redraw the new obj. */
                rect_draw_apple = NSUnionRect(rect_vis, rect_scroll);   // hack to work with Apple
                rect_draw_apple = NSUnionRect(rect_draw_apple, rect_last);
                rect_draw_apple = [self centerScanRect:rect_draw_apple];
                if (cacheView)
                {   NSRect	r = rect_draw_apple; //[self centerScanRect:rect_draw_apple]; // was: rect_last

#                   ifdef __APPLE__	// workaround to fix scaling of the composite source rectangle (frame)
                      r.origin.x    *= scale;
                      r.origin.y    *= scale;
                      r.size.width  *= scale;
                      r.size.height *= scale;
#                   endif
                    NSCopyBits([cacheView gState], r, rect_draw_apple.origin); // was: rect_last
                    //PScomposite(NSMinX(rect_last), NSMinY(rect_last), NSWidth(rect_last), NSHeight(rect_last), [cacheView gState], NSMinX(rect_last), NSMinY(rect_last), NSCompositeCopy);
                }
                else
                    [self drawRect:rect_draw_apple]; // was: rect_last

                [(VGraphic*)obj drawWithPrincipal:self];
                /* draw all other selected graphics where points moved by delta */
                if (pt_num == [obj selectedKnobIndex])
                {
                    for (l=[layerList count]-1; l>=0; l--)
                    {   NSMutableArray	*list = [[layerList objectAtIndex:l] list];
                        int			i;

                        if (![[layerList objectAtIndex:l] editable] || ![list count])
                            continue;
                        for (i=[list count]-1; i>=0; i--)
                        {   VGraphic	*g = [list objectAtIndex:i];

                            if ([g isSelected] && g!=obj && [g selectedKnobIndex] >= 0)
                                [(VGraphic*)g drawWithPrincipal:self];
                        }
                    }
                }
                /* so selected objects are shown selected while we scroll and so on */
                if ( VHFIsDrawingToScreen() && !scrolling )
                    [self drawControls:NSZeroRect]; //rect_now

                /* Flush the drawing so that it's consistent. */
                [[self window] flushWindow];
                PSWait();

                rect_last = rect_now;
                pt_last = pt;
            }
            else
                stopTimer(&inTimerLoop);

            event = [[self window] nextEventMatchingMask:NSLeftMouseUpMask|NSLeftMouseDraggedMask|NSPeriodicMask];
            tracking = ([event type] != NSLeftMouseUp);
        }
        stopTimer(&inTimerLoop);

        /*delta.x = rect_now.origin.x - rect_start.origin.x;
        delta.y = rect_now.origin.y - rect_start.origin.y;		
        if ( delta.x || delta.y )*/
        if (pt_last.x != pt_start.x || pt_last.y != pt_start.y)
            [[self layerOfGraphic:obj] updateObject:obj];

        [change endChange];
    }

    [window setAutodisplay:YES];
    if (pt_last.x != pt_start.x || pt_last.y != pt_start.y)
        [document setDirty:YES];

    /* Figure outside region that has to be redrawn
     * (the union of the old and the new rectangles).
     */
    *redrawRect = NSUnionRect(rect_now, *redrawRect);
    if (pt_last.x != pt_start.x || pt_last.y != pt_start.y)
        return YES;
    return NO;
}


/*
 * Moves the graphic object. If the selected graphic can fit in the beta
 * cache than the image is drawn into this buffer and then composited
 * to each new location. The image is redrawn at the new location
 * when the user releases the mouse button. If the selected graphic
 * cannot fit in the beta buffer than it is redrawn each time. This can
 * happen when the drawing view is scaled upwards.
 *
 * The offsets constrain the selected object to stay within the dimensions
 * of the view.
 *
 * modified: 2012-01-04 (no beep for locked objects, if mouse didn't move)
 *           2008-09-08 (2. apple workaround for NSCopyBits/drawRect)
 *           2007-05-08 (apple workaround for NSCopyBits)
 */
- (BOOL)moveObject:obj :(NSEvent *)event :(NSRect*)redrawRect
{   BOOL		tracking = YES, beta = NO;
    NSSize		llOffset, urOffset;
    NSPoint		pt, pt_last, pt_old, delta, delta_scroll, drawOffset, snapPoint;
    NSRect		rect_now, rect_start, rect_last, rect_scroll, rect_vis, rect_draw_apple;
    NSRect		rect_draw, rect_drawlast, rect_startdraw, rect_slaylist;
    id			betaView = [betaCache contentView];
    BOOL		alternate;
    BOOL		start = YES, horizConstrain = NO, vertConstrain = NO, doSnap = NO;
    int			l, i;
    DocWindow		*window = (DocWindow*)[self window];
    float		snap = Prefs_Snap / [self scaleFactor];	/* snap distance */
    id			snapObj = nil;
    float		controlsize = [self controlPointSize];

#if 0
    [DPSGetCurrentContext() setOutputTraced:YES];
#endif

    alternate = ([event modifierFlags] & NSAlternateKeyMask) ? YES : NO;

    pt_last = pt_old = [event locationInWindow];
    pt_last = [self convertPoint:pt_last fromView:nil];

    event = [window nextEventMatchingMask:NSLeftMouseUpMask|NSLeftMouseDraggedMask];

    /* Check whether the object can fit in the second buffer. */
    rect_now = [betaView frame];
    if (obj)
    {
        rect_start = [obj coordBounds];
        rect_draw = [obj extendedBoundsWithScale:[self scaleFactor]];

        if ( [obj isLocked] )
        {
            if ( [event type] != NSLeftMouseUp )            // check for mouse drag
                NSBeep();   //vhfPlaySound(@"Ping");
            return NO;
        }
        if ([obj hitEdge:pt_last fuzz:snap :&snapPoint :controlsize])
        //if ([obj hitControl:pt_last :&ptNum controlSize:controlsize])
        {   snapObj = obj;
            pt_last = snapPoint;
            //pt_last = [snapObj pointWithNum:ptNum];
        }
    }
    else
    {
        for ( l=[slayList count]-1; l>=0; l-- )		// objects must not be locked
        {   NSArray	*slist = [slayList objectAtIndex:l];
            for ( i=[slist count]-1; i>=0; i-- )
            {   id	ob = [slist objectAtIndex:i];

                if ( [ob isLocked] )
                {
                    if ( [event type] != NSLeftMouseUp )    // check for mouse drag
                        NSBeep();   //vhfPlaySound(@"Ping");
                    return NO;
                }
                if ([ob hitEdge:pt_last fuzz:snap :&snapPoint :controlsize])
                {   snapObj = ob;
                    pt_last = snapPoint;
                }
            }
        }
        rect_slaylist = [self boundsOfArray:slayList withKnobs:YES];
        [self deselectLockedLayers:YES lockedObjects:YES];
        rect_start = [self boundsOfArray:slayList withKnobs:NO]; // [self coordBoundsOfArray:slayList];
        rect_draw = [self boundsOfArray:slayList withKnobs:YES];
    }
    drawOffset.x = (rect_draw.size.width  - rect_start.size.width)/2.0;
    drawOffset.y = (rect_draw.size.height - rect_start.size.height)/2.0;
    drawOffset.x = MAX(1.0, ((int)drawOffset.x));
    drawOffset.y = MAX(1.0, ((int)drawOffset.y));
    rect_draw.origin.x = rect_start.origin.x - drawOffset.x;
    rect_draw.origin.y = rect_start.origin.y - drawOffset.y;
    rect_draw.size.width  = rect_start.size.width  + drawOffset.x*2.0;
    rect_draw.size.height = rect_start.size.height + drawOffset.y*2.0;
    
//NSLog(@"drawOffset.o %.3f %.3f", drawOffset.x, drawOffset.y);

    if (!snapObj)
        pt_last = [self grid:pt_last];

    if (betaView &&
        rect_now.size.width  > rect_draw.size.width  * scale && // rect_start
        rect_now.size.height > rect_draw.size.height * scale)
    {
        [betaView setBoundsOrigin:NSMakePoint(rect_draw.origin.x, rect_draw.origin.y)]; // rect_start
        [betaView lockFocus];
            [[NSColor colorWithDeviceWhite:1.0 alpha:0.0] set];
            NSRectFill(rect_draw); // rect_start
            if (obj)
                [(VGraphic*)obj drawWithPrincipal:self];
            else
            	for ( l=[slayList count]-1; l>=0; l-- )
                    [[slayList objectAtIndex:l] makeObjectsPerformSelector:@selector(drawWithPrincipal:)
                                                                withObject:self];
        [betaView unlockFocus];
        beta = YES;
    }

    /* Get the scrolling rectangle. If it turns out to be the visible portion of the window
     * then reduce it a bit so that the user is not playing pong when trying to
     * move the image.
     */
    rect_scroll = (obj) ? [obj scrollRect:-1 inView:self] : rect_start;
    rect_vis = [self visibleRect];
#if 0   // 2012-04-13
    if (NSContainsRect(rect_scroll, rect_vis))
    {	rect_scroll = rect_vis;
        rect_scroll = NSInsetRect(rect_scroll, rect_scroll.size.width * .20 , rect_scroll.size.height * .20);
    }
    else
    {
        if (rect_scroll.size.width == 0.0)
            rect_scroll.size.width = 1.0;
        if (rect_scroll.size.height == 0.0)
            rect_scroll.size.height = 1.0;
        rect_scroll = NSIntersectionRect(rect_vis , rect_scroll);
        /*if ( !obj && !NSContainsRect(rect_vis, rect_start) ) // rect_start not inside rect_vis - new part
        {   float   val = Abs(Min(rect_vis.size.width, rect_start.size.width)/Max(rect_vis.size.width, rect_start.size.width));

            val = Min(val, Abs(Min(rect_vis.size.height, rect_start.size.height)/Max(rect_vis.size.height, rect_start.size.height)));
            val = (val < 0.4) ? (0.3) : ((1.0-val)/2.0);
            rect_scroll = NSInsetRect(rect_scroll , rect_scroll.size.width * val , rect_scroll.size.height * val);
        }*/
    }
#endif
    /* 2012-04-13 - size */
    rect_scroll.size.width = rect_scroll.size.height = Min(rect_vis.size.width/5.0, rect_vis.size.height/5.0);

    *redrawRect = rect_startdraw = rect_drawlast = rect_draw;

    rect_now = rect_last = rect_start;
    delta_scroll.x = rect_scroll.origin.x - rect_now.origin.x;
    delta_scroll.y = rect_scroll.origin.y - rect_now.origin.y;

    /* Calculate where the mouse point falls relative to the object. */
    if (obj == origin)
    {	float	margin = 0.0; // ceil([self controlPointSize]);

        llOffset.width  = pt_last.x - (rect_start.origin.x + rect_start.size.width/2.0)  - margin;
        llOffset.height = pt_last.y - (rect_start.origin.y + rect_start.size.height/2.0) - margin;
        urOffset.width  = rect_start.origin.x + rect_start.size.width/2.0  - pt_last.x - margin;
        urOffset.height = rect_start.origin.y + rect_start.size.height/2.0 - pt_last.y - margin;
    }
    else
    {	llOffset.width = pt_last.x - rect_start.origin.x;
        llOffset.height = pt_last.y - rect_start.origin.y;
        urOffset.width = rect_start.origin.x + rect_start.size.width - pt_last.x;
        urOffset.height = rect_start.origin.y + rect_start.size.height - pt_last.y;
    }

    //event = [window nextEventMatchingMask:NSLeftMouseUpMask|NSLeftMouseDraggedMask];
    delta.x = delta.y = 0;

    [window setAutodisplay:NO];	// No because nextEvent would draw (flicker's without betaView)
    scrolling = YES;		// don't draw knobs
    if ([event type] != NSLeftMouseUp)
    {
        while (tracking)
        {
            pt = ([event type] == NSPeriodic) ? pt_old : (pt_old = [event locationInWindow]);
            pt = [self convertPoint:pt fromView:nil];
            [self constrainPoint:&pt withOffset:&llOffset :&urOffset];
            [self constrainPoint:&pt_last withOffset:&llOffset :&urOffset];

            /* snap to point */
            //doSnap = [self hitEdge:&pt spare:snapObj];  // FIXME: [layer state]
            if (snapObj)
            {   NSPoint hitP = pt;
                double  sqrDistBest = MAXFLOAT;

                doSnap = NO;
                for (l=[layerList count]-1; l>=0 && !doSnap; l--)
                {   LayerObject     *layerObj = [layerList objectAtIndex:l];
                    NSMutableArray	*list = [layerObj list];

                    if ( ![layerObj state] || ![list count] )
                        continue;
                    for (i=[list count]-1; i>=0; i--)
                    {   VGraphic	*g = [list objectAtIndex:i];

                        if ([g hitEdge:pt fuzz:snap :&snapPoint :controlsize] && g != snapObj)
                        {   doSnap = YES;
                            if ( SqrDistPoints(snapPoint, pt) < sqrDistBest )
                            {   hitP = snapPoint;
                                sqrDistBest = SqrDistPoints(snapPoint, pt);
                            }
                            //pt = snapPoint;
                            //break;
                        }
                    }
                }
                if ( doSnap )
                {   vhfPlaySound(@"Pop");
                    pt = hitP;
                }
            }
            /* snap to grid */
            if (!doSnap)
                pt = [self grid:pt];
            delta.x = pt.x - pt_last.x;
            delta.y = pt.y - pt_last.y;

            if ( (start && (delta.x + delta.y > 2.0)) || (delta.x || delta.y) )
            {
                start = NO;

                /* vertical/horizontal constrain
                 */
                if (alternate)
                {   if (ABS(delta.x) > ABS(delta.y))
                        horizConstrain = YES;
                    else
                        vertConstrain = YES;
                    alternate = NO;
                }
                if (horizConstrain)
                    delta.y = 0.0;
                else if (vertConstrain)
                    delta.x = 0.0;

                [window displayCoordinate:pt ref:NO];

                rect_now = NSOffsetRect(rect_now, delta.x, delta.y);
                if (obj != origin)
                    [self constrainRect:&rect_now];
                rect_draw.origin.x = rect_now.origin.x - drawOffset.x;
                rect_draw.origin.y = rect_now.origin.y - drawOffset.y;

#if 0   // 2012-04-13
                rect_scroll.origin.x = rect_now.origin.x + delta_scroll.x;
                rect_scroll.origin.y = rect_now.origin.y + delta_scroll.y;
#endif
                /* 2012-04-13 - origin */
                rect_scroll.origin = NSMakePoint(pt.x - rect_scroll.size.width /2.0,
                                                 pt.y - rect_scroll.size.height/2.0);
                //[self scrollPointToVisible:pt];
                [self scrollToRect:rect_scroll];

                /* Copy the old image into the window. If using the second buffer, copy
                 * it atop the old buffer. Otherwise, translate and redraw.
                 */
                rect_draw_apple = NSUnionRect(rect_vis, rect_scroll);
                rect_draw_apple = NSUnionRect(rect_draw_apple, rect_drawlast);
                if (cacheView)
                {   NSRect  r = rect_draw_apple; // rect_drawlast - reicht bei OpenStep

#                   ifdef __APPLE__	// workaround to fix scaling of the composite source rectangle (frame)
                      r = [self centerScanRect:rect_draw_apple]; // nicht bei OpenStep !
                      r.origin.x    *= scale;
                      r.origin.y    *= scale;
                      r.size.width  *= scale;
                      r.size.height *= scale;
#                   endif
                    NSCopyBits([cacheView gState], r, rect_draw_apple.origin); // rect_drawlast is sufficient for OpenStep only
                }
                else
                    [self drawRect:rect_draw_apple];    // rect_drawlast is sufficient for OpenStep only
                if (beta)
                    PScomposite(NSMinX(rect_startdraw), NSMinY(rect_startdraw), NSWidth(rect_startdraw), NSHeight(rect_startdraw), [betaView gState], NSMinX(rect_draw), NSMinY(rect_draw), NSCompositeSourceOver);
                else
                {   NSPoint	oldOrigin = [[NSView focusView] bounds].origin;

                    //[[NSView focusView] setBoundsOrigin: NSMakePoint(rect_start.origin.x - rect_now.origin.x,
                    //                                                 rect_start.origin.y - rect_now.origin.y)];
                    [[NSView focusView] setBoundsOrigin:
                        NSMakePoint(rect_startdraw.origin.x - rect_draw.origin.x,
                                    rect_startdraw.origin.y - rect_draw.origin.y)];
                    if (obj)
                        [(VGraphic*)obj drawWithPrincipal:self];
                    else
                    	for ( l=[slayList count]-1; l>=0; l-- )
                            [[slayList objectAtIndex:l] makeObjectsPerformSelector:@selector(drawWithPrincipal:)
                                                                        withObject:self];
                    [[NSView focusView] setBoundsOrigin:oldOrigin];
                }

                [window flushWindow];
                PSWait();

                rect_drawlast = rect_draw;
                rect_last = rect_now;
                pt_last = pt;
            }
            else
                stopTimer(&inTimerLoop);

            /* workaround for GNUsteps slow image processing */
#ifdef GNUSTEP_BASE_VERSION
            {   NSEvent	*lastEvent = nil;

                do
                {
                    if ((event = [window nextEventMatchingMask:
                                         NSLeftMouseUpMask|NSLeftMouseDraggedMask|NSPeriodicMask
                                                     untilDate:[NSDate date]
                                                        inMode:NSEventTrackingRunLoopMode dequeue:YES]))
                        lastEvent = event;
                }
                while (event);
                if (!lastEvent)
                    event = [window nextEventMatchingMask:
                                    NSLeftMouseUpMask|NSLeftMouseDraggedMask|NSPeriodicMask];
                else
                {
                    event = lastEvent;
                    [window discardEventsMatchingMask:
                            NSLeftMouseUpMask|NSLeftMouseDraggedMask|NSPeriodicMask
                                          beforeEvent:event];
                }
	    }
#else
            event = [window nextEventMatchingMask:
                            NSLeftMouseUpMask|NSLeftMouseDraggedMask|NSPeriodicMask];
#endif

            tracking = ([event type] != NSLeftMouseUp);
        }
        stopTimer(&inTimerLoop);

        delta.x = rect_now.origin.x - rect_start.origin.x;
        delta.y = rect_now.origin.y - rect_start.origin.y;		
        if ( delta.x || delta.y )
        {
            if (obj)
            {   [obj moveBy:delta];
                [[self layerOfGraphic:obj] updateObject:obj];
            }
            else
                [self moveGraphicsBy:delta andDraw:NO];
        }
    }
    scrolling = NO;
    [window setAutodisplay:YES];
    if ( delta.x || delta.y )
        [document setDirty:YES];

    *redrawRect = (obj) ? NSUnionRect(rect_draw, *redrawRect) : NSUnionRect(rect_draw, rect_slaylist);

    if (!floor(delta.x) && !floor(delta.y))
        return NO;

    /* wait a msec to allow correct redraw with performance map */
    [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0/1000.0]];

    return YES;
}

/*
 * Rotates the graphic object. If the selected graphic
 * cannot fit in the beta buffer than it is redrawn each time. This can
 * happen when the drawing view is scaled upwards.
 *
 * The offsets constrain the selected object to stay within the dimensions
 * of the view.
 *
 * modified: 2007-05-08 (apple workaround for NSCopyBits)
 */
- (BOOL)rotateObject:(VGraphic*)obj :(NSEvent *)event :(NSRect*)redrawRect
{   BOOL		tracking = YES;
    NSSize		llOffset, urOffset;
    NSPoint		p, pt_start, pt, pt_last, pt_old, delta, delta_scroll;
    NSRect		rect_now, rect_start, rect_last, rect_scroll, rect_vis;
    float		angle = 0.0, startAngle, dx, dy, av;
    BOOL		alternate, control;
    BOOL		horizConstrain = NO, vertConstrain = NO;
    id			change;

#if 0
    [DPSGetCurrentContext() setOutputTraced:YES];
#endif

    alternate = ([event modifierFlags] & NSAlternateKeyMask) ? YES : NO;
    control = ([event modifierFlags] & NSControlKeyMask) ? YES : NO;

    rect_start = [obj extendedBoundsWithScale:[self scaleFactor]];
    rect_last = *redrawRect = [obj maximumBounds];

    /*if (cacheView)	// copy cached image to screen
        PScomposite(NSMinX(rect_start), NSMinY(rect_start), NSWidth(rect_start), NSHeight(rect_start),
                    [cacheView gState], NSMinX(rect_start), NSMinY(rect_start), NSCompositeCopy);*/

    /* Get the scrolling rectangle. If it turns out to be the visible portion of the window
     * then reduce it a bit so that the user is not playing pong when trying to
     * move the image.
     */
    rect_scroll = [obj scrollRect:-1 inView:self];
    rect_vis = [self visibleRect];
    if (NSContainsRect(rect_scroll , rect_vis))
    {	rect_scroll = rect_vis;
        rect_scroll = NSInsetRect(rect_scroll , rect_scroll.size.width * .20 , rect_scroll.size.height * .20);
    }
    else
        rect_scroll = NSIntersectionRect(rect_vis , rect_scroll);

    rect_now = rect_start;
    delta_scroll.x = rect_scroll.origin.x - rect_now.origin.x;
    delta_scroll.y = rect_scroll.origin.y - rect_now.origin.y;

    pt_last = pt_old = [event locationInWindow];
    pt_last = [self convertPoint:pt_last fromView:nil];
    pt_start = pt_last;

    p = [obj center];
    dx = pt_start.x - p.x; dy = pt_start.y - p.y;
    av = sqrt(dx*dx + dy*dy);
    /* calculate angle between mouse and center of object */
    startAngle = Asin(dy/av);
    startAngle = (dx<0) ? 180.0-startAngle : startAngle;
    startAngle = -startAngle;

    /* Calculate where the mouse point falls relative to the object. */
    llOffset.width = pt_last.x - rect_start.origin.x;
    llOffset.height = pt_last.y - rect_start.origin.y;
    urOffset.width = rect_start.origin.x + rect_start.size.width - pt_last.x;
    urOffset.height = rect_start.origin.y + rect_start.size.height - pt_last.y;

    event = [[self window] nextEventMatchingMask:NSLeftMouseUpMask|NSLeftMouseDraggedMask];
    if ([event type] != NSLeftMouseUp)
    {
        while (tracking)
        {
            pt = ([event type] == NSPeriodic) ? pt_old : (pt_old = [event locationInWindow]);

            pt = [self convertPoint:pt fromView:nil];
            [self constrainPoint:&pt withOffset:&llOffset :&urOffset];
            [self constrainPoint:&pt_last withOffset:&llOffset :&urOffset];
            delta.x = pt.x - pt_last.x;
            delta.y = pt.y - pt_last.y;

            if (delta.x || delta.y)
            {
                if (alternate && !control)
                {
                    if (ABS(delta.x) > ABS(delta.y))
                        horizConstrain = YES;
                    else
                        vertConstrain = YES;
                    alternate = NO;
                }
                if (horizConstrain)
                    delta.y = 0.0;
                else if (vertConstrain)
                    delta.x = 0.0;

                rect_scroll.origin.x = rect_now.origin.x + delta_scroll.x;
                rect_scroll.origin.y = rect_now.origin.y + delta_scroll.y;
                [self scrollToRect:rect_scroll];

                /* Copy the old image into the window. Then translate and redraw.
                 */
                if (cacheView)
                {   NSRect	r = [self centerScanRect:rect_last];

#                   ifdef __APPLE__	// workaround to fix scaling of the composite source rectangle (frame)
                      r.origin.x    *= scale;
                      r.origin.y    *= scale;
                      r.size.width  *= scale;
                      r.size.height *= scale;
#                   endif
                    NSCopyBits([cacheView gState], r, rect_last.origin);
                }
                else
                    [self drawRect:rect_last];

                {   float	dx, dy, av;

                    //dx = pt.x - pt_start.x; dy = pt.y - pt_start.y;	/* get the center of the object instead */
                    p = [obj center];
                    dx = pt.x - p.x; dy = pt.y - p.y;
                    av = sqrt(dx*dx + dy*dy);
                    /* calculate angle between mouse and center of object */
                    angle = Asin(dy/av);
                    angle = (dx<0) ? 180.0-angle : angle;
                    angle = -angle;
                    angle = angle - startAngle;
                    if (angle < 360.0 && angle > -360.0)
                        [obj drawAtAngle:angle in:self];
                }

                /* Flush the drawing so that it's consistent. */
                [[self window] flushWindow];
                PSWait();

                //	rect_last = rect_now;
                pt_last = pt;
            }
            else
                stopTimer(&inTimerLoop);

            event = [[self window] nextEventMatchingMask:NSLeftMouseUpMask|NSLeftMouseDraggedMask|NSPeriodicMask];

            tracking = ([event type] != NSLeftMouseUp);
        }
        stopTimer(&inTimerLoop);

        change = [[RotateGraphicsChange alloc] initGraphicView:self angle:angle center:[obj center]];
        [change startChange];
            [obj rotate:angle];
            [[self layerOfGraphic:obj] updateObject:obj];
        [change endChange];
        [document setDirty:YES];
    }

    //redrawRect = NSUnionRect(&rect_now, redrawRect);

    if (!angle)
        return NO;
    return YES;
}

/* Check to see whether a control point has been hit. */
- (BOOL) checkControl:(const NSPoint *) p :(int *) pt_num
{   BOOL	hit;
    float	controlsize/*, hitsetting*/;
    //	NXRect	hitRect;
    int		i, l;

    controlsize = [self controlPointSize];
    //	hitsetting = [superview hitSetting];	
    //	NXSetRect(&hitRect, p->x - hitsetting/2, p->y - hitsetting/2, hitsetting, hitsetting);

    for (l=[layerList count]-1; l>=0; l--)
    {	NSMutableArray	*list = [[layerList objectAtIndex:l] list];

        if (![[layerList objectAtIndex:l] editable] || ![list count])
            continue;
        for (i=[list count]-1; i>=0; i--)
        {	id	obj = [list objectAtIndex:i];

            if ((hit = [obj hitControl:*p :pt_num controlSize:controlsize]))
                return hit;
        }
    }

    return NO;
}

- (BOOL)magnify
{
    return magnifyMode;
}
- (void)setMagnify:(BOOL)flag
{
    magnifyMode = flag;
    if (!flag)
        [(App*)NSApp setCurrent2DTool:self];
}


/*
 * First Responder
 */

- (void)mouseMoved:(NSEvent*)event
{   //NSPoint	pc = [self mouseLocationOutsideOfEventStream], p;
    NSPoint	pc = [event locationInWindow], p;
    NSRect	rect;

    p = [[self superview] convertPoint:pc fromView:nil];
    rect = [(NSClipView*)[self superview] bounds];
    if ( ![self mouse:p inRect:rect] /*!NSPointInRect(p , rect)*/ )
        return;
    p = [self convertPoint:pc fromView:nil];
    [(DocWindow*)[self window] displayCoordinate:p ref:NO];
}

/* modified: 2012-01-05
 *
 * If the docview is zooming, then scale the drawing view. Else
 * check for hit detection on the bezier or the control points.
 */
- (void)mouseDown:(NSEvent *)event
{   BOOL        redraw = YES;
    NSPoint     p;
    NSRect      drawRect = NSZeroRect;
    int         pt_num, i, l, toolIx;
    BOOL        shift, control, gotHit = NO, compositeAll = NO, editable = NO;
    VGraphic    *g = nil;
    DocWindow   *window = (DocWindow*)[self window];

    /* You only need to do the following line in a mouseDown: method if
     * you receive this message because one of your subviews gets the
     * mouseDown: and does not respond to it (thus, it gets passed up the
     * responder chain to you).  In this case, our editView receives the
     * mouseDown:, but doesn't do anything about it, and when it comes
     * to us, we want to become the first responder.
     *
     * Normally you won't have a subview which doesn't do anything with
     * mouseDown:, in which case, you need only return YES from the
     * method acceptsFirstResponder (see that method below) and will NOT
     * need to do the following makeFirstResponder:.  In other words,
     * don't put the following line in your mouseDown: implementation!
     *
     * Wichtig, damit der View als First Responder des Window funktioniert
     */
    if ([window firstResponder] != self)
    {
        if ([event clickCount] < 2)
            [window makeFirstResponder:self];
        else
        {   [[window firstResponder] mouseDown:event];
            return;
        }
    }

    if (magnifyMode)
    {   [self dragMagnify:event];
        return;
    }

    shift   = ([event modifierFlags] & NSShiftKeyMask)   ? YES : NO;
    control = ([event modifierFlags] & NSControlKeyMask) ? YES : NO;

    p = [event locationInWindow];
    [self lockFocus];
    p = [self convertPoint:p fromView:nil];

    [window displayCoordinate:p ref:YES];

    [window endEditingFor:nil];	/* end editing of text */

    /* check whether we are editable
     */
    for ( l=[layerList count]-1; l>=0; l-- )
    {
        if ( [[layerList objectAtIndex:l] editable] )
        {   editable = YES;
            break;
        }
    }

    /*
     * create (edit)
     */
    if ( editable && displayGraphic )
    {
        switch ( toolIx = [(App*)NSApp current2DTool] )
        {
            /* if we are inside an existing text we edit this text instead of creating a new one */
            case TOOL2D_TEXT:
                [self deselectAll:nil];
                for (l=[layerList count]-1; l>=0; l--)	// if we hit a text -> we edit this text
                {   NSMutableArray	*list = [[layerList objectAtIndex:l] list];

                    if ( ![[layerList objectAtIndex:l] editable] )
                        continue;
                    for ( i=[list count]-1; i>=0; i-- )
                    {	g = [list objectAtIndex:i];

                        if ( [g isKindOfClass:[VText class]] && [g hit:p fuzz:2.0/scale] )
                        {   [(VText*)g edit:event in:editView];
                            gotHit = YES;
                            redraw = NO;
                            l = 0;
                            [document setDirty:YES];
                            break;
                        }
                    }
                }
                if (!gotHit)
                {   g = [[[VText allocWithZone:[self zone]] init] autorelease];
                    if ( [g create:event in:self] )
                    {   id	change;

                        change = [[CreateGraphicsChange alloc] initGraphicView:self graphic:g];
                        [change startChangeIn:self];
                            [(VText*)g edit:NULL in:editView];
                            [self insertGraphic:g];
                            gotHit = YES;
                            redraw = NO;
                        [change endChange];
                    }
                    //else
                        //[g release];
                }
                break;
            case TOOL2D_LINE:
                g = [VLine line];
                [g setWidth:Prefs_LineWidth];
            case TOOL2D_MARK:
                if ( toolIx == TOOL2D_MARK )
                    g = [[[VMark allocWithZone:[self zone]] init] autorelease];
            case TOOL2D_WEB:
                if ( toolIx == TOOL2D_WEB )
                    g = [[[VWeb allocWithZone:[self zone]] init] autorelease];
            case TOOL2D_ARC:
                if ( toolIx == TOOL2D_ARC )
                {   g = [VArc arc];
                    [g setWidth:Prefs_LineWidth];
                }
            case TOOL2D_THREAD:
                if ( toolIx == TOOL2D_THREAD )
                    g = [[[VThread allocWithZone:[self zone]] init] autorelease];
            case TOOL2D_SINKING:
                if ( toolIx == TOOL2D_SINKING )
                    g = [[[VSinking allocWithZone:[self zone]] init] autorelease];
            case TOOL2D_RECT:
                if ( toolIx == TOOL2D_RECT )
                {   g = [[[VRectangle allocWithZone:[self zone]] init] autorelease];
                    [g setWidth:Prefs_LineWidth];
                }
            case TOOL2D_CURVE:
                if (toolIx == TOOL2D_CURVE )
                {   g = [VCurve curve];
                    [g setWidth:Prefs_LineWidth];
                }
            case TOOL2D_PATH:
                if ( toolIx == TOOL2D_PATH )
                    g = [VPath path];
            case TOOL2D_POLYLINE:
                if ( toolIx == TOOL2D_POLYLINE )
                {   g = [VPolyLine polyLine];
                    [g setWidth:Prefs_LineWidth];
                }
                [self deselectAll:self];

/*if ([g isKindOfClass:[VLine class]])
{
    g = [VLine3D line3D];
    [g setVertices:NSMakePoint(10.0, 10.0) :NSMakePoint(50.0, 50.0)];
    [g setZLevel:10.0 :50.0];
    [g setSelected:YES];
    [self insertGraphic:g];
    gotHit = YES;
    redraw = NO;
    break;
}*/
                if ( [g create:event in:self] )
                {   id	change;

                    change = [[CreateGraphicsChange alloc] initGraphicView:self graphic:g];
                    [change startChangeIn:self];
                        [g setSelected:YES];
                        [self insertGraphic:g];
                        gotHit = YES;
                        redraw = NO;
                    [change endChange];
                }
                break;

            /* split objects at mouse position
             */
            case TOOL2D_SCISSOR:	// knife tool
                for (l=[layerList count]-1; l>=0; l--)	// if we hit an object -> split it
                {   NSMutableArray	*list = [[layerList objectAtIndex:l] list];

                    if ( ![[layerList objectAtIndex:l] editable] )
                        continue;
                    for ( i=[list count]-1; i>=0; i-- )
                    {	g = [list objectAtIndex:i];

                        if ( [g isSelected] && [g isPathObject] && [g hit:p fuzz:2.0/scale] )
                        {
                            [self splitObject:g atPoint:p redraw:YES];
                            gotHit = YES;
                            redraw = NO;
                            l = 0;
                            [document setDirty:YES];
                            break;
                        }
                    }
                }
                break;
            /* add point to object at mouse position
             */
            case TOOL2D_ADDPOINT:	// add tool
                for (l=[layerList count]-1; l>=0; l--)	// if we hit an Path or PolyLine -> add point to it
                {   NSMutableArray	*list = [[layerList objectAtIndex:l] list];

                    if ( ![[layerList objectAtIndex:l] editable] )
                        continue;
                    for ( i=[list count]-1; i>=0; i-- )
                    {	g = [list objectAtIndex:i];

                        if ( [g isSelected] && ([g isKindOfClass:[VPath class]] || [g isKindOfClass:[VPolyLine class]])
                             && [g hit:p fuzz:2.0/scale] )
                        {
                            [self addPointTo:g atPoint:p redraw:YES];
                            gotHit = YES;
                            redraw = NO;
                            l = 0;
                            [document setDirty:YES];
                            break;
                        }
                    }
                }
                break;
        }
    }

    /* check selected objects
     */
    if ( displayGraphic && !gotHit )
    {
        for ( l=[layerList count]-1; l>=0; l-- )
        {   NSMutableArray	*list = [[layerList objectAtIndex:l] list];
            NSMutableArray	*slist = [slayList objectAtIndex:l];

            if ( /*![[layerList objectAtIndex:l] editable] ||*/ ![list count] )
                continue;
            for ( i=[list count]-1; i>=0; i-- )
            {	id	obj = [list objectAtIndex:i];

                if ([obj isSelected])	/* object is selected */
                {
                    if ( [[layerList objectAtIndex:l] editable] && [event clickCount] >= 2 &&
                         [obj respondsToSelector:@selector(edit:in:)] && [obj hit:p fuzz:2.0/scale] )
                    {	[self deselectAll:nil];
                        [obj edit:NULL in:editView];
                        gotHit = YES;
                        redraw = NO;
                        l = 0; break;
                    }
                    else if (shift && [obj hit:p fuzz:2.0/scale])	/* deselect object */
                    {
                        gotHit = YES;
                        drawRect = [obj extendedBoundsWithScale:[self scaleFactor]];
                        [obj setSelected:NO];
                        [slist removeObject:obj];
                        [self drawRect:drawRect];
                        l = 0; break;
                    }
                    else if ([[layerList objectAtIndex:l] editable] && [(App*)NSApp current2DTool] != TOOL2D_ROTATE &&
                             [obj hitControl:p :&pt_num controlSize:[self controlPointSize]])	// move control
                    {	NSPoint	p3;

                        [obj getPoint:pt_num :&p3];
                        [window displayCoordinate:p3 ref:YES];
                        gotHit = YES;
                        if (![self redrawObject:obj :pt_num :&drawRect])
                            redraw = NO;
                        l = 0; break;
                    }
                    else if ([[layerList objectAtIndex:l] editable] && [obj hit:p fuzz:2.0/scale])	// move object
                    {
                        gotHit = YES;
                        if ([(App*)NSApp current2DTool] == TOOL2D_ROTATE)
                        {   if (![self rotateObject:obj :event :&drawRect])
                                redraw = NO;
                        }
                        else if (![self moveObject:nil :event :&drawRect])
                            redraw = NO;
                        [document setDirty:YES];
                        l = 0; break;
                    }
                }
            }
        }
    }

    /* we don't hit any selected object but we hit the origin -> move origin
     */
    if ( !shift && !gotHit && [origin hit:p fuzz:2.0/scale] )	// move origin
    {	[self moveObject:origin :event :&drawRect];
        gotHit = compositeAll = YES;
    }

    /* we don't hit any object which is selected and shift is not pressed
     * so we deselect all selected objects
     */
    if (!shift && !gotHit)
    {
        redraw = NO;
        [self deselectAll:self];
    }

    /* we don't hit any object which is selected
     * so we check objects which are not selected
     */
    if (!gotHit)
    {
        for (l=[layerList count]-1; l>=0; l--)
        {   NSMutableArray	*list = [[layerList objectAtIndex:l] list];
            NSMutableArray	*slist = [slayList objectAtIndex:l];

            /* we only select on editable layers, except with CAM module */
            if ( ![list count] || ![(LayerObject*)[layerList objectAtIndex:l] state]
                 || (!Prefs_SelectNonEditable && ![[layerList objectAtIndex:l] editable]) )
                continue;
            for (i=[list count]-1; i>=0; i--)
            {	id	obj = [list objectAtIndex:i];

                if (![obj isSelected])	// object is not selected
                {
                    if ([obj hit:p fuzz:2.0/scale])	// select object
                    {
                        gotHit = YES;
                        drawRect = [obj extendedBoundsWithScale:scale];
                        [obj setSelected:YES];
                        if ([obj respondsToSelector:@selector(font)])
                            [[NSFontManager sharedFontManager] setSelectedFont:[obj font] isMultiple:NO];
                        [slist addObject:obj];
                        [window flushWindow];
                        PSWait();

                        if ( displayGraphic && [[layerList objectAtIndex:l] editable] )
                        {
                            if ([(App*)NSApp current2DTool] == TOOL2D_ROTATE)
                            {
                                if ([self rotateObject:obj :event :&drawRect])
                                    redraw = YES;
                            }
                            else if ([self moveObject:nil :event :&drawRect])
                                redraw = YES;
                        }
                        //if (!redraw)
                        //    [self drawRect:drawRect];

                        l=-1; break;
                    }
                }
            }
        }
    }

    if (!gotHit)
    {	[window flushWindow];
        drawRect = [self dragSelect:event];
    }

    /* inform modules about mouse down */
    [[NSNotificationCenter defaultCenter] postNotificationName:DocViewMouseDown
                                                        object:self
                                                      userInfo:[NSDictionary dictionaryWithObject:event
                                                        forKey:@"event"]];

    [[(App*)NSApp inspectorPanel] loadList:slayList];

    /* redraw */
    if (tileOriginList)
        compositeAll = YES;	// make cache update in rect, but composite entire bounds
    if (redraw)
        [self cache:(compositeAll) ? [self bounds] : drawRect];
    else if ( compositeAll || drawRect.size.width || drawRect.size.height ) // 2008-05-03
        [self flatRedraw:(compositeAll) ? [self bounds] : drawRect];
    [self unlockFocus];
    [window flushWindow];
}

- (void)keyDown:(NSEvent *)event
{   NSString	*chars = [event characters];

    //NSLog(@"keyCode:%d", [event keyCode]);

    if ([chars length])
    {   unichar	character = [[event characters] characterAtIndex:0];

        //NSLog(@"key:%d %x", character, character);

        /* delete */
        if ( character == NSBackspaceCharacter ||	// backspace (0x8)
             character == NSDeleteFunctionKey ||	// delete (0xf728)
             character == NSDeleteCharacter )		// backspace OS (0x7f)
            [[document documentView] delete:self];
    }
}

/* modified: 2006-07-12
 * Allows the user the drag out a box to select all objects either
 * intersecting the box, or fully contained within the box (depending
 * on the state of the ALTERNATE key).  After the selection is made,
 * the slayList is updated.
 */
#define DRAG_MASK (NSLeftMouseUpMask|NSLeftMouseDraggedMask|NSPeriodicMask)
- (NSRect)dragSelect:(NSEvent *)event
{   int             i, l;
    NSWindow        *window = (DocWindow*)[self window];
    NSPoint         p, last, start;
    NSRect          visibleRect, region, oldRegion, drawRect;
    BOOL            mustContain, shift, canScroll, oldRegionSet = NO;
    NSMutableArray  *list;
    float           enlargeSize = 1.0/[self scaleFactor];

    p = start = [event locationInWindow];
    start = [self convertPoint:start fromView:nil];
    last = start;

    shift = ([event modifierFlags] & NSShiftKeyMask) ? YES : NO;
    mustContain = ([event modifierFlags] & NSAlternateKeyMask) ? YES : NO;

    [self lockFocus];

    visibleRect = [self visibleRect];
    canScroll = !NSEqualRects(visibleRect , [self bounds]);
    if (canScroll)
        startTimer(&inTimerLoop);

    region.origin.x = region.origin.y = 0.0;
    region.size.width = region.size.height = 0.0;
    event = [window nextEventMatchingMask:DRAG_MASK];
    while ([event type] != NSLeftMouseUp)
    {
        if ([event type] == NSPeriodic)
            //[event locationInWindow] = p;
            event = periodicEventWithLocationSetToPoint(event, p);
        p = [event locationInWindow];
        p = [self convertPoint:p fromView:nil];
        if (p.x != last.x || p.y != last.y)
        {
            region.origin.x = Min(p.x, start.x);
            region.origin.y = Min(p.y, start.y);
            region.size.width  = Max(p.x, start.x) - region.origin.x;
            region.size.height = Max(p.y, start.y) - region.origin.y;
            [[self window] disableFlushWindow];
            if (oldRegionSet)
            {	oldRegion = NSInsetRect(oldRegion , -enlargeSize , -enlargeSize);
                [self drawRect:oldRegion];
            }
            if (canScroll)
            {	[self scrollRectToVisible:region];
                [self scrollPointToVisible:p];
            }
            [[NSColor lightGrayColor] set];
            [NSBezierPath setDefaultLineWidth:1.0/scale];
            [NSBezierPath strokeRect:region];
            //NSFrameRectWithWidth(region, 1.0/scale);
            [window enableFlushWindow];
            [window flushWindow];
            oldRegion = region; oldRegionSet = YES;
            last = p;
            PSWait();
        }
        p = [event locationInWindow];
        event = [[self window] nextEventMatchingMask:DRAG_MASK];
    }

    if (canScroll)
        stopTimer(&inTimerLoop);

    drawRect = region;
    if (region.size.width > 0.0 && region.size.height > 0.0)
    {
        for ( l=[layerList count]-1; l>=0; l-- )
        {   LayerObject	*layerObject = [layerList objectAtIndex:l];

            list = [layerObject list];
            if ( ![layerObject state] || ![list count]
                 || (!Prefs_SelectNonEditable && ![layerObject editable]) )
                continue;

            for ( i = [list count] - 1; i >= 0; i-- )
            {   VGraphic	*g = [list objectAtIndex:i];
                NSRect      rect = [g coordBounds];	// may have zero width or height !

                rect.size.width  = MAX(rect.size.width,  0.001);
                rect.size.height = MAX(rect.size.height, 0.001);
                /* bounds check */
                if ( ( mustContain && NSContainsRect(region, rect)) ||
                     (!mustContain && !NSIsEmptyRect(NSIntersectionRect(region, rect))) )
                {   VRectangle	*gRect;

                   /* check for graphic intersection
                    * we are satisfied with the bounds check above for all but path-objects and groups
                    */
                    //if (mustContain || NSContainsRect(region, rect) || [g intersectsRect:region])
                    gRect = [VRectangle rectangle];
                    [gRect setVertices:region.origin :NSMakePoint(region.size.width, region.size.height)];
                    if ( mustContain || NSContainsRect(region, rect)
                         || (![g isPathObject] && ![g isKindOfClass:[VGroup class]])
                         || [gRect sqrDistanceGraphic:g] <= ([g width]/2.0)*([g width]/2.0) )
                    {
                        [g setSelected:(shift && [g isSelected]) ? NO : YES];
                        drawRect = NSUnionRect(rect, drawRect);
                    }
                }
            }
        }
    }

    if (drawRect.size.width > 0.0 && drawRect.size.height > 0.0)
    {
        [self getSelection];
        drawRect = NSInsetRect(drawRect, -enlargeSize, -enlargeSize);
        //[self flatRedraw:drawRect];	// will be redrawed in mouseDown
    }
    [self unlockFocus];

    /* post notification */
    if (region.size.width > 0.0 && region.size.height > 0.0)
    {   NSDictionary	*userInfo;

        userInfo = [NSDictionary dictionaryWithObject:propertyListFromNSRect(region)
                                               forKey:@"region"];
        [[NSNotificationCenter defaultCenter] postNotificationName:DocViewDragSelect
                                                            object:self userInfo:userInfo];
    }
    return drawRect;
}

/* modified: 2009-09-22 (init region.origin)
 */
- (void)dragMagnify:(NSEvent *)event
{   NSPoint     p, last, start;
    NSRect      visibleRect, region, oldRegion;
    BOOL        mustContain, shift, canScroll, oldRegionSet = NO;
    DocWindow   *window = (DocWindow*)[self window];

    region.origin = p = start = [event locationInWindow];
    start = [self convertPoint:start fromView:nil];
    last = start;

    shift = ([event modifierFlags] & NSShiftKeyMask) ? YES : NO;
    mustContain = ([event modifierFlags] & NSAlternateKeyMask) ? YES : NO;

    [self lockFocus];

    visibleRect = [self visibleRect];
    canScroll = !NSEqualRects(visibleRect, [self bounds]);
    if (canScroll)
        startTimer(&inTimerLoop);

    region.size.width = region.size.height = 0.0;
    event = [window nextEventMatchingMask:DRAG_MASK];
    while ([event type] != NSLeftMouseUp)
    {
        if ([event type] == NSPeriodic)
            event = periodicEventWithLocationSetToPoint(event, p);
        p = [event locationInWindow];
        p = [self convertPoint:p fromView:nil];
        if (p.x != last.x || p.y != last.y)
        {
            region.origin.x = Min(p.x, start.x);
            region.origin.y = Min(p.y, start.y);
            region.size.width  = Max(p.x, start.x) - region.origin.x;
            region.size.height = Max(p.y, start.y) - region.origin.y;
            [[self window] disableFlushWindow];
            if (oldRegionSet)
            {	oldRegion = NSInsetRect(oldRegion , -1.0 , -1.0);
                [self drawRect:oldRegion];
            }
            if (canScroll)
            {	[self scrollRectToVisible:region];
                [self scrollPointToVisible:p];
            }
            [[NSColor lightGrayColor] set];
            [NSBezierPath setDefaultLineWidth:1.0/scale];
            [NSBezierPath strokeRect:region];
            //NSFrameRectWithWidth(region, 1.0/scale);
            [window enableFlushWindow];
            [window flushWindow];
            oldRegion = region; oldRegionSet = YES;
            last = p;
            PSWait();
        }
        p = [event locationInWindow];
        event = [[self window] nextEventMatchingMask:DRAG_MASK];
    }

    if (canScroll)
        stopTimer(&inTimerLoop);

    [self unlockFocus];

    [self setMagnify:NO];

    //[[document scrollView] magnifyRegion:region];
    [(TileScrollView*)[[self superview] superview] magnifyRegion:region];
}

- (BOOL)isSelectionEditable
{   int	l;

    for ( l=[layerList count]-1; l>=0; l-- )
    {   NSMutableArray	*slist = [slayList objectAtIndex:l];

        if ( ![[layerList objectAtIndex:l] editable] || ![slist count] )
            continue;
        return YES;
    }
    return NO;
}

- (void)delete:(id)sender
{   int		i, l, selectedObjectsCnt = 0, selectedKnobObjectsToRemoveCnt = 0, selectedKnobObjectsCnt = 0;
    VGraphic	*graphic;
    id		change;
    NSRect	rect, drawRect = NSZeroRect;

    if ( ![self isSelectionEditable] )
        return;

    for ( l=[slayList count]-1; l>=0; l-- )
    {   NSMutableArray	*slist = [slayList objectAtIndex:l];

        selectedObjectsCnt += [slist count];

        if ([slist count] == 1)
        {   VGraphic	*gs = [slist objectAtIndex:0];

            if( ([gs isKindOfClass:[VPolyLine class]] || [gs isKindOfClass:[VPath class]])
                && [gs selectedKnobIndex] >= 0 && [gs numPoints] <= 2 )
                selectedKnobObjectsToRemoveCnt++;

            if( ([gs isKindOfClass:[VPolyLine class]] || [gs isKindOfClass:[VPath class]])
                && [gs selectedKnobIndex] >= 0 )
                selectedKnobObjectsCnt++;
        }
    }
    if ( selectedObjectsCnt == 1 && ((selectedKnobObjectsCnt == 1 && selectedKnobObjectsToRemoveCnt == 1) ||
         !selectedKnobObjectsCnt) )
        selectedObjectsCnt++; // little hack

    if ( selectedObjectsCnt > 1 ) // we have to remove the selected graphics
    {
        change = [[DeleteGraphicsChange alloc] initGraphicView:self];
        [change startChange];
            for ( l=[layerList count]-1; l>=0; l-- )
            {   LayerObject		*layerObject = [layerList objectAtIndex:l];
                NSMutableArray	*slist = [slayList objectAtIndex:l];

                if (![layerObject editable] || ![slist count])
                    continue;

                /* 1st object in list might have been used for the consecutive paste */
                if (originalPaste == [slist objectAtIndex:0])
                    originalPaste = nil;

                for (i=[slist count]-1; i>=0; i--)
                {
                    graphic = [slist objectAtIndex:i];
                    rect = [graphic extendedBoundsWithScale:[self scaleFactor]];
                    drawRect = (!drawRect.size.width) ? rect : NSUnionRect(rect, drawRect);
/*                    if (( [graphic isKindOfClass:[VPolyLine class]] && [graphic selectedKnobIndex] >= 0 ) ||
                        ( [graphic isKindOfClass:[VPath class]] && [graphic selectedKnobIndex] >= 0 ))
                    {
                        if (![(VPolyLine*)graphic removePointWithNum:[graphic selectedKnobIndex]])
                        {   [layerObject removeObject:graphic]; // we have removed the last point of graphic
                            [slist removeObject:graphic];
                        }
                    }
                    else*/
                    {   [layerObject removeObject:graphic];
                        [slist removeObject:graphic];
                    }
                }

                /* have to recalculate all output, if we remove something from clipping layer */
                if ([layerObject type] == LAYER_CLIPPING)
                    [layerObject setDirty:YES];
            }
            [document setDirty:YES];
            [self cache:drawRect];
        [change endChange];
    }
    else // we have to remove only the point of the one selected graphic
    {
        change = [[RemovePointGraphicsChange alloc] initGraphicView:self];
        [change startChange];
            for ( l=[layerList count]-1; l>=0; l-- )
            {   LayerObject		*layerObject = [layerList objectAtIndex:l];
                NSMutableArray	*slist = [slayList objectAtIndex:l];

                if (![layerObject editable] || ![slist count])
                    continue;

                /* 1st object in list might have been used for the consecutive paste */
                if (originalPaste == [slist objectAtIndex:0])
                    originalPaste = nil;

                for (i=[slist count]-1; i>=0; i--)
                {
                    graphic = [slist objectAtIndex:i];
                    rect = [graphic extendedBoundsWithScale:[self scaleFactor]];
                    drawRect = (!drawRect.size.width) ? rect : NSUnionRect(rect, drawRect);
                    if (( [graphic isKindOfClass:[VPolyLine class]] && [graphic selectedKnobIndex] >= 0 ) ||
                        ( [graphic isKindOfClass:[VPath class]] && [graphic selectedKnobIndex] >= 0 ))
                    {
                        if ( ![(VPolyLine*)graphic removePointWithNum:[graphic selectedKnobIndex]] )
                            NSLog(@"- delete: we remove the last point of graphic");
                    }
                }

                /* have to recalculate all output, if we remove something from clipping layer */
                if ([layerObject type] == LAYER_CLIPPING)
                    [layerObject setDirty:YES];
            }
            [document setDirty:YES];
            [self cache:drawRect];
        [change endChange];
    }
}

/*
 * Selects all the items in the layerlist.
 */
- (void)selectAll:(id)sender redraw:(BOOL)redraw
{   int		i, iCnt, l;
    VGraphic	*g;

    for ( l=[layerList count]-1; l>=0; l-- )
    {	NSMutableArray	*slist = [slayList objectAtIndex:l];
        NSMutableArray	*list = [[layerList objectAtIndex:l] list];

        [slist removeAllObjects];
        /* only select layers which are displayed and editable, exception: CAM-Module */
        if ( ![(LayerObject*)[layerList objectAtIndex:l] state] || !(iCnt=[list count])
             || (!Prefs_SelectNonEditable && ![[layerList objectAtIndex:l] editable]) )
            continue;

        for (i=0; i<iCnt; i++)
        {
            g = [list objectAtIndex:i];
            [g setSelected:YES];
            [slist addObject:g];
        }
    }
    if ( redraw )
        [self flatRedraw:[self bounds]];
    [[(App*)NSApp inspectorPanel] loadList:slayList];
}
- (void)selectAll:(id)sender
{
    [self selectAll:sender redraw:YES];
}

/*
 * Deselects all the items in the slayList.
 */
- (void)deselectAll:sender redraw:(BOOL)redraw
{   NSRect	sbounds;
    int		l;
    BOOL	deselected = NO;

    if (redraw)
        sbounds = [self boundsOfArray:slayList];
    for ( l=[slayList count]-1; l>=0; l-- )
    {	NSMutableArray	*slist = [slayList objectAtIndex:l];

        if ( [slist count] > 0 )
        {   int	i;

            for ( i=[slist count]-1; i>=0; i-- )
                [[slist objectAtIndex:i] setSelected:NO];
            [slist removeAllObjects];
            deselected = YES;
        }
    }
    if ( redraw && deselected )
    {
        [self flatRedraw:sbounds];
        if ( sender != self )
            [[self window] flushWindow];
    }
}
- (void)deselectAll:sender
{
    [self deselectAll:sender redraw:YES];
}

- (void)deselectLockedLayers:(BOOL)lockedLayers lockedObjects:(BOOL)lockedObjects
{   int		l, i;

    for ( l=[slayList count]-1; l>=0; l-- )
    {   LayerObject	*layer = [layerList objectAtIndex:l];
        NSMutableArray	*slist = [slayList objectAtIndex:l];

        if ( [slist count] > 0 )
        {
            for ( i=[slist count]-1; i>=0; i-- )
            {   VGraphic	*g = [slist objectAtIndex:i];

                if ((lockedLayers && ![layer editable]) || (lockedObjects && [g isLocked]))
                {
                    [g setSelected:NO];
                    [slist removeObjectAtIndex:i];
                }
            }
        }
    }
}

/*
 * Selects all the items in the layerList equal to those in slayList.
 */
#define	MAXCLASSES	10
- (void)selectEqual:sender
{   int		gcnt, scnt, i, j, l, c=0;
    id		classes[MAXCLASSES];

    if (![slayList count])
        return;

    for (l=[layerList count]-1; l>=0; l--)
    {   NSMutableArray	*slist = [slayList objectAtIndex:l];
        NSMutableArray	*list = [[layerList objectAtIndex:l] list];

        if ( ![list count])
            continue;

        if ( !(scnt=[slist count]) )
            continue;
        for ( i=0; i<scnt; i++ )
        {   id	sg = [slist objectAtIndex:i];

            for ( j=0; j<c; j++ )
                if ( [sg isMemberOfClass:classes[j]] )
                {   j = MAXCLASSES+1;
                    break;
                }
                if ( j > MAXCLASSES )	/* not in class list */
                    continue;

            classes[c++] = [sg class];
        }

        gcnt = [list count];
        for (i=0; i<gcnt; i++)
        {   id	gg = [list objectAtIndex:i];

            if (![gg isSelected])
            {
                for (j=0; j<c; j++)
                    if ([gg isMemberOfClass:classes[j]])
                        break;
                if (j >= c)	/* not in class list */
                    continue;
                [gg setSelected:YES];
                [slist addObject:gg];
            }
        }
    }

    [self flatRedraw:[self bounds]];
}

/*
 * Selects all the items in the layerList equal to those in slayList.
 */
#define	MAXCOLORS	20
- (void)selectColor:sender
{   int		gcnt, scnt, i, j, l, c=0, fs[MAXCOLORS];
    float	ws[MAXCOLORS];
    NSColor	*cols[MAXCOLORS];
    NSColor	*fcols[MAXCOLORS];
    NSColor	*ecols[MAXCOLORS];

    if (![slayList count])
        return;

    for (l=[layerList count]-1; l>=0; l--)
    {	NSMutableArray	*slist = [slayList objectAtIndex:l];
        NSMutableArray	*list = [[layerList objectAtIndex:l] list];

        if (![list count])
            continue;

        if (!(scnt=[slist count]))
            continue;
        for (i=0; i<scnt; i++)
        {   VGraphic    *sg = [slist objectAtIndex:i];
            float       sgw = [sg width];
            int         sgf = [sg filled];

            //if ([sg isKindOfClass:[VGroup class]]) // VGroup perhaps filled but no fillColor !
            //    continue;
            for (j=0; j<c; j++)
                if (((((ws[j] && sgw) || (!fs[j] && !sgf)) && [cols[j] isEqual:[sg color]])
                     || (!ws[j] && !sgw && fs[j] && fs[j] == sgf)) &&
                    ((fs[j] >= 1 && fs[j] == sgf && [fcols[j] isEqual:[(VPath*)sg fillColor]]) || (!fs[j] && !sgf)) &&
                    ((fs[j] > 1  && fs[j] == sgf && [ecols[j] isEqual:[(VPath*)sg endColor ]]) || (fs[j] <= 1 && fs[j] == sgf)))
                //if ( [cols[j] isEqual:[sg color]] )
                {   j = MAXCOLORS+1;
                    break;
                }
            if (j > MAXCOLORS)	/* not in class list */
                continue;

            ws[c] = [sg width];
            cols[c] = [sg color];
            fs[c++] = [sg filled]; // NO if nothing to fill
            if ([sg respondsToSelector:@selector(fillColor)])
            {
                fcols[c-1] = [(VPath*)sg fillColor];
                ecols[c-1] = [(VPath*)sg endColor];
            }
        }
        if (!c)
            return;

        gcnt = [list count];
        for (i=0; i<gcnt; i++)
        {   VGraphic    *gg = [list objectAtIndex:i];

            if (![gg isSelected])
            {   float	ggw = [gg width];
                int     ggf = [gg filled];

                for ( j=0; j<c; j++ )
                    if (((((ws[j] && ggw) || (!fs[j] && !ggf)) &&
                          [cols[j] isEqual:[gg color]]) || (!ws[j] && !ggw && fs[j] && fs[j] == ggf)) &&
                    ((fs[j] >= 1 && fs[j] == ggf && [fcols[j] isEqual:[(VPath*)gg fillColor]]) || (!fs[j] && !ggf)) &&
                    ((fs[j] > 1  && fs[j] == ggf && [ecols[j] isEqual:[(VPath*)gg endColor ]]) || (fs[j] <= 1 && fs[j] == ggf)))
                    //if ( [colors[j] isEqual:[gg color]] )
                        break;
                if (j >= c)	/* not in class list */
                    continue;
                [gg setSelected:YES];
                [slist addObject:gg];
            }
        }
    }

    [self flatRedraw:[self bounds]];
}

- (void)bringToFront:sender
{   int		scnt, i, l;
    id		change;

    if (![slayList count])
        return;

    change = [[BringToFrontGraphicsChange alloc] initGraphicView:self];
    [change startChange];
        for (l=[layerList count]-1; l>=0; l--)
        {   NSMutableArray	*slist = [slayList objectAtIndex:l];
            LayerObject		*layerObject = [layerList objectAtIndex:l];

            if (![[layerObject list] count])
                continue;

            if (!(scnt=[slist count]))
                continue;
            for (i=0; i<scnt; i++)
            {   id	sg = [slist objectAtIndex:i];

                [layerObject removeObject:sg];
                [layerObject addObject:sg];
            }
        }
        [self drawAndDisplay];
    [change endChange];
}
- (void)bringForward:sender
{   int		scnt, i, l;
    id		change;

    if (![slayList count])
        return;

    change = [[BringToFrontGraphicsChange alloc] initGraphicView:self];
    [change startChange];
        for (l=[layerList count]-1; l>=0; l--)
        {   NSMutableArray	*slist = [slayList objectAtIndex:l];
            LayerObject		*layerObject = [layerList objectAtIndex:l];

            if (![[layerObject list] count])
                continue;

            if (!(scnt=[slist count]))
                continue;
            for (i=0; i<scnt; i++)
            {   id	sg = [slist objectAtIndex:i];
                int	location = [[layerObject list] indexOfObject:sg];

                [layerObject removeObject:sg];
                [layerObject insertObject:sg atIndex:
                 (location+1 > (int)[[layerObject list] count]) ? ((int)[[layerObject list] count]-1)
                                                                : (location+1)];
            }
        }
        [self drawAndDisplay];
    [change endChange];
}

- (void)sendToBack:sender
{   int	scnt, i, l;
    id	change;

    if (![slayList count])
        return;

    change = [[SendToBackGraphicsChange alloc] initGraphicView:self];
    [change startChange];
        for (l=[layerList count]-1; l>=0; l--)
        {   NSMutableArray	*slist = [slayList objectAtIndex:l];
            LayerObject		*layerObject = [layerList objectAtIndex:l];

            if (![[layerObject list] count])
                continue;
            if (!(scnt=[slist count]))
                continue;
            for (i=0; i<scnt; i++)
            {   id	sg = [slist objectAtIndex:i];

                [layerObject removeObject:sg];
                [layerObject insertObject:sg atIndex:0];
            }
        }
        [self drawAndDisplay];
    [change endChange];
}
- (void)sendBackward:sender
{   int	scnt, i, l;
    id	change;

    if (![slayList count])
        return;

    change = [[SendToBackGraphicsChange alloc] initGraphicView:self];
    [change startChange];
        for (l=[layerList count]-1; l>=0; l--)
        {   NSMutableArray	*slist = [slayList objectAtIndex:l];
            LayerObject		*layerObject = [layerList objectAtIndex:l];

            if (![[layerObject list] count])
                continue;
            if (!(scnt=[slist count]))
                continue;
            for (i=0; i<scnt; i++)
            {   id	sg = [slist objectAtIndex:i];
                int	location = [[layerObject list] indexOfObject:sg];

                [layerObject removeObject:sg];
                [layerObject insertObject:sg atIndex:(location-1 < 0) ? 0 : (location-1)];
            }
        }
        [self drawAndDisplay];
    [change endChange];
}

- (void)changeFont:(id)sender
{   int	iCnt, i, l;

    if (![slayList count])
        return;

    for (l=[layerList count]-1; l>=0; l--)
    {	NSMutableArray	*slist = [slayList objectAtIndex:l];

        if (!(iCnt=[slist count]))
            continue;

        for (i=0; i<iCnt; i++)
        {   id	sg = [slist objectAtIndex:i];

            if ( [sg isKindOfClass:[VText class]] )
            {   [sg setFont:[sender convertFont:[sg font]]];
                [[layerList objectAtIndex:l] setDirty:YES];
            }
        }
    }

    [self drawAndDisplay];
}

/* turn on/off coordinate display of the document window
 * created: 2007-05-04
 */
- (void)toggleCoordDisplay:sender
{
    [(DocWindow*)[document window] enableCoordDisplay:([(NSMenuItem*)sender tag] ? YES : NO)];
}

- (void)displayDirections:sender
{
    if ([sender respondsToSelector:@selector(tag)])
        showDirection = [(NSMenuItem*)sender tag] ? YES : NO;
    [self drawAndDisplay];
}
- (BOOL)showDirection		{ return showDirection; }
- (void)setDirectionForLayer:(LayerObject*)layerObject
{   int		i, cnt;
    BOOL	ccw = YES;	/* outside correction = ccw */
    NSArray	*list = [layerObject list];

    if ( [layerObject side] == CUT_INSIDE )
        ccw = !ccw;
    if ( [layerObject revertDirection] )
        ccw = !ccw;

    /* set direction for objects */
    for ( i=0, cnt=[list count]; i<cnt; i++ )
    {   id	g = [list objectAtIndex:i];

        if ( [g respondsToSelector:@selector(setDirectionCCW:)] )
            [g setDirectionCCW:ccw];
    }
    [self drawAndDisplay];
}

/*BOOL vhfUpdateMenuItem(id <NSMenuItem> menuItem, NSString *zeroItem, NSString *oneItem, BOOL state)
{
    if (state)
    {
        if ([menuItem tag] != 0)
        {
            [menuItem setTitleWithMnemonic:zeroItem];
            [menuItem setTag:0];
            [menuItem setEnabled:NO];	// causes it to get redrawn
	}
    }
    else if ([menuItem tag] != 1)
    {
        [menuItem setTitleWithMnemonic:oneItem];
        [menuItem setTag:1];
        [menuItem setEnabled:NO];	// causes it to get redrawn
    }
    return YES;
}*/

/* Can be called to see if the specified action is valid on this view now.
 * It returns NO if the GraphicView knows that action is not valid now,
 * otherwise it returns YES. Note the use of the Pasteboard change
 * count so that the GraphicView does not have to look into the Pasteboard
 * every time paste: is validated.
 *
 * created:  1996-10-19
 * modified: 2011-04-07 (pathSetStartPoint)
 *           2007-07-25 (optimizeMoves queries removed)
 */
//- (BOOL)validateMenuItem:(id <NSMenuItem>)anItem
- (BOOL)validateMenuItem:(NSMenuItem*)anItem
{   int         i, iCnt, l, lCnt, cnt;
    SEL			action = [anItem action];
    static BOOL pboardHasPasteableType = NO;
    static int  cachedPasteboardChangeCount = -1;

    if ( VHFSelectorIsEqual(action, @selector(bringToFront:)) ||
         VHFSelectorIsEqual(action, @selector(bringForward:)) )
    {	lCnt = [layerList count];
        for (l=0; l<lCnt; l++)
        {   NSMutableArray	*list = [[layerList objectAtIndex:l] list];
            NSMutableArray	*slist = [slayList objectAtIndex:l];

            if ( [[layerList objectAtIndex:l] editable] )
                 /*&& (!Prefs_OptimizeMoves || ![self respondsToSelector:@selector(optimizeMoves:)]) )*/
            {
                if ((iCnt = [slist count]) && (cnt=[list count]) > iCnt)
                {
                    for (i=1; i<=iCnt; i++)
                        if ([slist objectAtIndex:iCnt-i] != [list objectAtIndex:cnt-i])
                            return YES;
                }
            }
        }
        return NO;
    }
    else if ( VHFSelectorIsEqual(action, @selector(sendToBack:)) ||
              VHFSelectorIsEqual(action, @selector(sendBackward:)) )
    {	lCnt = [layerList count];
        for (l=0; l<lCnt; l++)
        {   NSMutableArray	*list = [[layerList objectAtIndex:l] list];
            NSMutableArray	*slist = [slayList objectAtIndex:l];

            if ( [[layerList objectAtIndex:l] editable] )
                 /*&& (!Prefs_OptimizeMoves || ![self respondsToSelector:@selector(optimizeMoves:)]) )*/
            {
                if ((iCnt = [slist count]) && (int)[list count] > iCnt)
                {
                    for (i=0; i<iCnt; i++)
                        if ([slist objectAtIndex:i] != [list objectAtIndex:i])
                            return YES;
                }
            }
        }
        return NO;
    }
    else if ( VHFSelectorIsEqual(action, @selector(toggleGrid:)) )
    {
	return (gridSpacing > 0) ? vhfUpdateMenuItem(anItem, HIDE_GRID, SHOW_GRID, [self gridIsEnabled]) : NO;
    }
    /* we need at least two selected objects */
    else if ( VHFSelectorIsEqual(action, @selector(group:))
              //   || VHFSelectorIsEqual(action == @selector(align:))
              || VHFSelectorIsEqual(action, @selector(join:)) )
    {
        for (l=0, lCnt = [slayList count]; l<lCnt; l++)
        {   NSMutableArray	*slist = [slayList objectAtIndex:l];

            if ( [[layerList objectAtIndex:l] editable] && [slist count] > 1 )
                return YES;
        }
        return NO;
    }
    /* we need at least two selected and one filled objects */
    else if ( VHFSelectorIsEqual(action, @selector(punch:)) )
    {
        for (l=0, lCnt = [slayList count]; l<lCnt; l++)
        {   NSMutableArray	*slist = [slayList objectAtIndex:l];

            /* we need at least one filled graphic */
            if ( [[layerList objectAtIndex:l] editable] && [slist count] > 1 )
            	for (i=[slist count]-1; i>=0; i--)
                {
                    if ( [[slist objectAtIndex:i] filled])
                        return YES;
                    else if ([[slist objectAtIndex:i] isKindOfClass:[VGroup class]])
                    {   int	j, gCnt = [[slist objectAtIndex:i] countRecursive];

                        for (j=0; j < gCnt; j++)
                            if ([[[slist objectAtIndex:i] recursiveObjectAtIndex:j] filled])
                                return YES;
                    }
                }
        }
        return NO;
    }
    /* we need a selected group */
    else if ( VHFSelectorIsEqual(action, @selector(ungroup:)) )
    {
        for (l=0, lCnt = [slayList count]; l<lCnt; l++)
        {   NSMutableArray	*slist = [slayList objectAtIndex:l];

            if ( [[layerList objectAtIndex:l] editable] && [slist count] )
            	for (i=[slist count]-1; i>=0; i--)
                    if ( [[slist objectAtIndex:i] isMemberOfClass:[VGroup class]] )
                        return YES;
        }
        return NO;
    }
    /* we need a selected path */
    else if ( VHFSelectorIsEqual(action, @selector(split:)) )
    {
        for (l=0, lCnt = [slayList count]; l<lCnt; l++)
        {   NSMutableArray	*slist = [slayList objectAtIndex:l];

            if ( [[layerList objectAtIndex:l] editable] && [slist count] &&
                 ([[slist objectAtIndex:0] isMemberOfClass:[VPath class]] ||
                  [[slist objectAtIndex:0] isMemberOfClass:[VTextPath class]] ||
                  [[slist objectAtIndex:0] isMemberOfClass:[VImage class]]) )
                return YES;
        }
        return NO;
    }
    /* we need a selected text */
    else if ( VHFSelectorIsEqual(action, @selector(flatten:)) )
    {
        for (l=0, lCnt = [slayList count]; l<lCnt; l++)
        {   NSMutableArray	*slist = [slayList objectAtIndex:l];

            if ( [[layerList objectAtIndex:l] editable] && [slist count] &&
                 ([[slist objectAtIndex:0] isMemberOfClass:[VText class]] ||
                  [[slist objectAtIndex:0] isMemberOfClass:[VTextPath class]]) )
                return YES;
        }
        return NO;
    }
    /* we need a text being edited */
    else if ( VHFSelectorIsEqual(action, @selector(addLink:)) )
    {
        if ( [[self window] fieldEditor:NO forObject:nil] == [[self window] firstResponder] )
            return YES;
        return NO;
    }
    /* bindTextToPath: we need one selected text and one of path, line, arc, curve */
    else if ( VHFSelectorIsEqual(action, @selector(bindTextToPath:)) )
    {
        for ( l=0, lCnt = [slayList count]; l<lCnt; l++ )
        {   NSMutableArray	*slist = [slayList objectAtIndex:l];

            if ( [[layerList objectAtIndex:l] editable] && [slist count]==2 &&
                 ([[slist objectAtIndex:0] isMemberOfClass:[VText class]] ||
                  [[slist objectAtIndex:1] isMemberOfClass:[VText class]]) &&
                 ([VTextPath canBindToObject:[slist objectAtIndex:0]] ||
                  [VTextPath canBindToObject:[slist objectAtIndex:1]]) )
                return YES;
        }
        return NO;
    }
    /* pathSetStartPoint: we need one selected path */
    else if ( VHFSelectorIsEqual(action, @selector(pathSetStartPoint:)) )
    {
        for ( l=0, lCnt = [slayList count]; l<lCnt; l++ )
        {   NSMutableArray	*slist = [slayList objectAtIndex:l];

            if ( [[layerList objectAtIndex:l] editable] && [slist count]==1 &&
                [[slist objectAtIndex:0] isMemberOfClass:[VPath class]] )
                return YES;
        }
        return NO;
    }
    /* we need at least one selected object */
    else if ( VHFSelectorIsEqual(action, @selector(copy:)) )
    {
        for (l=0, lCnt = [slayList count]; l<lCnt; l++)
        {   NSMutableArray	*slist = [slayList objectAtIndex:l];

            if ( [slist count] )
                return YES;
        }
        return NO;
    }
    /* we need at least one selected object on an editable layer */
    else if ( VHFSelectorIsEqual(action, @selector(mirror:))
              || VHFSelectorIsEqual(action, @selector(rotateG:))
              || VHFSelectorIsEqual(action, @selector(reverse:))
              || VHFSelectorIsEqual(action, @selector(buildContour:))
              || VHFSelectorIsEqual(action, @selector(delete:))
              || VHFSelectorIsEqual(action, @selector(selectColor:))
              || VHFSelectorIsEqual(action, @selector(selectEqual:))
              || VHFSelectorIsEqual(action, @selector(cut:))
              || VHFSelectorIsEqual(action, @selector(transform:)) )
    {
        for (l=0, lCnt = [slayList count]; l<lCnt; l++)
        {   NSMutableArray	*slist = [slayList objectAtIndex:l];

            if ( [[layerList objectAtIndex:l] editable] && [slist count] )
                return YES;
        }
        return NO;
    }
    /* we need at least one unselected object */
    else if ( VHFSelectorIsEqual(action, @selector(selectAll:)) )
    {
        for (l=0, lCnt = [layerList count]; l<lCnt; l++)
        {   NSMutableArray	*list = [[layerList objectAtIndex:l] list];
            NSMutableArray	*slist = [slayList objectAtIndex:l];

            if ( /*[[layerList objectAtIndex:l] editable] &&*/ ([slist count] != [list count]) )
                return YES;
        }
        return NO;
    }
    /* we need something to paste */
    else if ( VHFSelectorIsEqual(action, @selector(paste:)) )
    {	NSPasteboard *pb = [NSPasteboard generalPasteboard];

        cnt = [pb changeCount];
        if (cnt != cachedPasteboardChangeCount)
        {   cachedPasteboardChangeCount = cnt;
            pboardHasPasteableType = (e2CenonPasteType([pb types]) != NULL);
        }
        return pboardHasPasteableType;
    }
    else if ( VHFSelectorIsEqual(action, @selector(displayDirections:)) )
        return vhfUpdateMenuItem(anItem, HIDE_DIRECTION, SHOW_DIRECTION, [self showDirection]);
    else if ( VHFSelectorIsEqual(action, @selector(toggleCoordDisplay:)) )
        return vhfUpdateMenuItem(anItem, HIDE_COORDS,    SHOW_COORDS,
                                 [(DocWindow*)[document window] hasCoordDisplay]);

    [[NSNotificationCenter defaultCenter] postNotificationName:DocViewUpdateMenuItem
                                                        object:anItem userInfo:statusDict];

    return YES;
}

/* created:  1995-12-03
 * modified: 2005-03-12 (Performance map recreation)
 * purpose:  group objects
 *           allocate new group object
 *           add slayList to group
 *           remove objects in slayList from list
 */
- (void)group:sender
{   VGroup	*group;
    int		i, iCnt, l;
    id		change;

    /* deselect everything which will not be part of the group(s) */
    for (l=[layerList count]-1; l>=0; l--)
    {   LayerObject	*layer = [layerList objectAtIndex:l];
        NSMutableArray	*slist = [slayList objectAtIndex:l];

        if (![[layer list] count] || ![layer editable] || [slist count] < 2)
            [slist removeAllObjects];
    }

    /* group */
    change = [[GroupGraphicsChange alloc] initGraphicView:self];
    [change startChange];
        for (l=[layerList count]-1; l>=0; l--)
        {   LayerObject		*layer = [layerList objectAtIndex:l];
            NSMutableArray	*slist = [slayList objectAtIndex:l], *llist = [layer list];
            PerformanceMap	*lpm;

            if (![[layer list] count] || ![layer editable])
                continue;
            if ([slist count] < 2)	// we need at least two objects for a group
                continue;

            /* 1st object in list may be used for the consecutive paste */
            originalPaste = nil;

            group = [VGroup group];
	    [change noteGroup:group layer:layer];
            for (i=0, iCnt = [llist count]; i<iCnt; i++)
            {	id  obj = [llist objectAtIndex:i];

                if ([slist indexOfObject:obj] != NSNotFound)
                    [group addObject:obj];
            }
            for (i=[slist count]-1; i>=0; i--)
                [layer removeObject:[slist objectAtIndex:i]];

            /* hier Neuaufbau der performanceMap der layer - weil Group sonst evtl viel zu oft gemalt wird,
             * wenn viel kleines zur Gruppe wird (viel kleines, viele maps),
             * neuaufbau macht im ganzen weniger maps !
             */
            if ( (lpm = [layer performanceMap]) )
                [lpm sortNewInFrame:[lpm bounds] initWithList:llist];

            [layer addObject:group];
            [slist removeAllObjects];
            [slist addObject:group];
            [group setSelected:YES];
        }
    [change endChange];

    [document setDirty:YES];
    [self drawAndDisplay];
    [[(App*)NSApp inspectorPanel] loadList:slayList];
}

/* created:  1995-12-03
 * modified: 2012-01-05
 * purpose:  ungroup objects
 *           ungroup all groups in slayList
 *           remove the groups from list
 *           select all ungrouped objects
 */
- (void)ungroup:sender
{   int             i, iCnt, l;
    NSMutableArray  *newSlist;
    id              change;

    change = [[UngroupGraphicsChange alloc] initGraphicView:self];
    [change startChange];
        for (l=[slayList count]-1; l>=0; l--)
        {   LayerObject		*layerObject = [layerList objectAtIndex:l];
            NSMutableArray	*slist = [slayList objectAtIndex:l];

            if (![slist count] || ![layerObject editable])
                continue;

            newSlist = [NSMutableArray array];
            for (i=[slist count]-1; i>=0; i--)
            {   id	g = [slist objectAtIndex:i];

                if ([g isMemberOfClass:[VGroup class]])
                {
                    [g ungroupTo:newSlist];
                    [layerObject removeObject:g];
                }
                else
                    [g setSelected:NO];
            }
            [slayList replaceObjectAtIndex:l withObject:newSlist];
            for (i=0, iCnt = [newSlist count]; i<iCnt; i++)
                [layerObject addObject:[newSlist objectAtIndex:i]];
        }
    [change endChange];

    [document setDirty:YES];
    [self drawAndDisplay];
}

/* created:  1995-09-19
 * modified: 2012-02-28 (copy path - for correct undo)
 * purpose:  join two objects
 */
- (void)joinSelection:(id)change messages:(BOOL)messages
{   int             i, iCnt, l;
    PerformanceMap  *lpm;

    for ( l=[slayList count]-1; l>=0; l-- )
    {	LayerObject	*layerObject = [layerList objectAtIndex:l];
        NSMutableArray	*slist = [slayList objectAtIndex:l];
        VGraphic    *obj1 = 0, *obj2 = 0;
        BOOL        complex = NO, filled = NO;

        if ( ![slist count] || ![layerObject editable] )
            continue;
        if ( [slist count] < 2 )
        {
            if ( messages )
                NSRunAlertPanel(@"", SELECT2FORJOIN_STRING, OK_STRING, nil, nil);
            return;
        }

        /* 1st object in list may be used for the consecutive paste */
        originalPaste = nil;

        /* join image and path to clip image from path
         */
        if ( [slist count] == 2 && ([[slist objectAtIndex:0] isMemberOfClass:[VImage class]] ||
                                    [[slist objectAtIndex:1] isMemberOfClass:[VImage class]]) )
        {   id	imageObj, clipObj;

            imageObj = ([[slist objectAtIndex:0] isMemberOfClass:[VImage class]]) ?
                                                        [slist objectAtIndex:0] : [slist objectAtIndex:1];
            clipObj  = ([[slist objectAtIndex:0] isMemberOfClass:[VImage class]]) ?
                                                        [slist objectAtIndex:1] : [slist objectAtIndex:0];
            if (([clipObj isMemberOfClass:[VPath class]] && [clipObj closed]) ||
                ([clipObj isMemberOfClass:[VArc class]] && Abs([clipObj angle]) == 360.0) ||
                ([clipObj isMemberOfClass:[VPolyLine class]] &&
                 SqrDistPoints([clipObj pointWithNum:0], [clipObj pointWithNum:MAXINT]) < TOLERANCE) ||
                [clipObj isMemberOfClass:[VRectangle class]])
            {   VImage  *nImageObj = [imageObj copy]; // for undo - should not change the pointer of objects

                [change notePathBefore:imageObj];
                [nImageObj join:clipObj];
                [slist removeObject:clipObj];
                [slist removeObject:imageObj];
                [layerObject removeObject:clipObj];
                [layerObject removeObject:imageObj];
                [layerObject addObject:nImageObj];
                [nImageObj setSelected:YES];
                [slist addObject:nImageObj];
                [change notePath:nImageObj];
            }
            return;
        }

        for (i=0, iCnt = [slist count]; i<iCnt; i++)
        {   id obj = [slist objectAtIndex:i];

            if ( [obj isMemberOfClass:[VPath class]] || [obj isMemberOfClass:[VCurve class]] ||
                 [obj isMemberOfClass:[VLine class]] || [obj isMemberOfClass:[VArc class]] ||
                 [obj isMemberOfClass:[VRectangle class]] || [obj isMemberOfClass:[VPolyLine class]] )
            {
                if (!obj1)
                    obj1 = obj;
                else if (!obj2)
                    obj2 = obj;
                else
                    complex = YES;
                if ( [obj filled] )
                    filled = YES;
            }
            else
            {   [slist removeObject:obj];
                i--; iCnt--;
            }
        }
        if ( ![obj1 isMemberOfClass:[VPath class]] && ![obj1 isMemberOfClass:[VPolyLine class]] &&
             ([obj2 isMemberOfClass:[VPath class]] || [obj2 isMemberOfClass:[VPolyLine class]]) )
        {   id	o = obj1; obj1 = obj2; obj2 = o; }

        /* if both polylines are closed - we must join both in one path ! - set complex = YES */
        if ( [obj1 isMemberOfClass:[VPolyLine class]] && !filled && !complex &&
             [obj2 isMemberOfClass:[VPolyLine class]] )
        {   NSPoint	p0, p1;

            p0 = [obj1 pointWithNum:0];
            p1 = [obj1 pointWithNum:[(VPolyLine*)obj1 ptsCount]-1];
            if ( Diff(p0.x, p1.x) <= TOLERANCE && Diff(p0.y, p1.y) <= TOLERANCE )
            {
                p0 = [obj2 pointWithNum:0];
                p1 = [obj2 pointWithNum:[(VPolyLine*)obj2 ptsCount]-1];
                if ( Diff(p0.x, p1.x) <= TOLERANCE && Diff(p0.y, p1.y) <= TOLERANCE )
                    complex = YES;
            }
        }

        if ( [slist count] < 2 )
        {
            if ( messages )
                NSRunAlertPanel(@"", SELECT2FORJOIN_STRING, OK_STRING, nil, nil);
        }
        else if ( [obj1 isMemberOfClass:[VPath class]] )
        {   VPath	*area = [obj1 copy]; // for undo - should not change the pointer of objects

            [change notePathBefore:obj1];
            [layerObject addObject:area];
            if (complex)
            {
                for (i=[slist count]-1; i>=0; i--)
                    [layerObject removeObject:[slist objectAtIndex:i]];

                [slist removeObject:obj1]; // sonst ist der doppelt
                [area join:slist];

                /* hier Neuaufbau der performanceMap der layer */
                if ( (lpm = [layerObject performanceMap]) )
                    [lpm sortNewInFrame:[lpm bounds] initWithList:[layerObject list]];

                [slist removeAllObjects];
                [area setSelected:YES];
                [slist addObject:area];
            }
            else
            {   [area join:obj2];
                [slist removeObject:obj1];
                [slist removeObject:obj2];
                [layerObject removeObject:obj1];
                [layerObject removeObject:obj2];
                [area setSelected:YES];
                [slist addObject:area];
            }
            [change notePath:area];
        }
        else if ( [obj1 isMemberOfClass:[VPolyLine class]] && !filled && !complex &&
                 ([obj2 isMemberOfClass:[VPolyLine class]] || [obj2 isMemberOfClass:[VLine class]]) )
        {   VPolyLine   *area = [obj1 copy]; // for undo - should not change the pointer of objects

            [change notePathBefore:obj1];
            [area join:obj2];
            [slist removeObject:obj1];
            [slist removeObject:obj2];
            [layerObject removeObject:obj1];
            [layerObject removeObject:obj2];
            [layerObject addObject:area];
            [change notePath:area];
            [area setSelected:YES];
            [slist addObject:area];
        }
        else	/* build new area */
        {   VPath	*area = [VPath path];

            [change notePath:area];
            [area setColor:[(VGraphic*)obj1 color]];
            [area setFillColor:[(VGraphic*)obj1 color]];
            [area setWidth:[obj1 width]];
            [area setFilled:filled];
            if (complex)
            {
                for (i=[slist count]-1; i>=0; i--)
                    if ([slist objectAtIndex:i] != area )
                        [layerObject removeObject:[slist objectAtIndex:i]];

                /* hier Neuaufbau der performanceMap der layer */
                if ( (lpm = [layerObject performanceMap]) )
                    [lpm sortNewInFrame:[lpm bounds] initWithList:[layerObject list]];

                [area join:slist];
                [slist removeAllObjects];
            }
            else
            {   [area join:obj1];
                [area join:obj2];
                [layerObject removeObject:obj1];
                [layerObject removeObject:obj2];
                [slist removeObject:obj1];
                [slist removeObject:obj2];
            }
            [area setSelected:YES];
            [layerObject addObject:area];
            [slist addObject:area];
        }
    }
}
- (void)join:sender
{   id		change;
    NSRect	drawRect;

    change = [[JoinGraphicsChange alloc] initGraphicView:self];
    [change startChange];
        [self joinSelection:change messages:YES];
    [change endChange];

    drawRect = [self boundsOfArray:slayList];
    [self cache:drawRect];
    [document setDirty:YES];
    [[(App*)NSApp inspectorPanel] loadList:slayList];
}

/* created:  1995-09-19
 * modified: 2012-02-29 (noteList:list added)
 * purpose:  split selected objects
 */
- (void)split:sender
{   int		i, l;
    NSRect	rect, drawRect;
    BOOL	start = YES;
    id		change;

    change = [[SplitGraphicsChange alloc] initGraphicView:self];
    [change startChange];
        for (l=[layerList count]-1; l>=0; l--)
        {   LayerObject		*layer = [layerList objectAtIndex:l];
            NSMutableArray	*slist = [slayList objectAtIndex:l];

            if (![layer editable] || ![slist count])
                continue;
            if (start)
            {   drawRect = [[slist objectAtIndex:[slist count]-1] extendedBoundsWithScale:[self scaleFactor]];
                start = NO;
            }
            for (i=[slist count]-1; i>=0; i--)
            {   id	obj = [slist objectAtIndex:i];

                rect = [obj extendedBoundsWithScale:[self scaleFactor]];
                drawRect = NSUnionRect(rect, drawRect);

                if ( [obj isSelected] && [obj respondsToSelector:@selector(splitTo:)] &&
                     (![obj isKindOfClass:[VImage class]] || [(VImage*)obj clipPath]) )	// image: test for clipPath
                {   int			i, location = [[layer list] indexOfObject:obj];
                    NSMutableArray	*list = [NSMutableArray array];

                    [slist removeObject:obj];
                    [obj retain];
                    [layer removeObject:obj];
                    [obj splitTo:list];
                    for ( i = [list count] - 1; i >= 0; i-- )
                        [layer insertObject:[list objectAtIndex:i] atIndex:location];
                    [obj release];
                    [change noteList:list];
                }
            }
        }
        [self getSelection];
    [change endChange];

    [self cache:drawRect];
    [document setDirty:YES];
}

/* created:  1996-09-27
 * modified: 2006-06-07 (remove VText from selection)
 * purpose:  remove hidden areas from selected elements
 */
- (void)punch:sender
{   int			i, iCnt, l;
    NSRect		drawRect;
    NSMutableArray	*tmpList = [NSMutableArray array];
    id			change;

    /* deselect unfit objects (VText) */
    for ( l=[layerList count]-1; l>=0; l-- )
    {   NSMutableArray	*slist = [slayList objectAtIndex:l];

        for ( i=[slist count]-1; i>=0; i-- )
        {   id	g = [slist objectAtIndex:i];

            if ([g isKindOfClass:[VText class]])
            {
                [[slist objectAtIndex:i] setSelected:NO];
                [slist removeObjectAtIndex:i];
            }
        }
    }

    change = [[PunchGraphicsChange alloc] initGraphicView:self];
    [change startChange];
        for ( l=[layerList count]-1; l>=0; l-- )
        {   LayerObject		*layerObject = [layerList objectAtIndex:l];
            NSMutableArray	*slist = [slayList objectAtIndex:l];

            if ( ![layerObject editable] || ![slist count] )
                continue;

            /* 1st object in list may be used for the consecutive paste */
            originalPaste = nil;

            /* build list of selected objects in the order of list */
            for (i=0, iCnt = [[layerObject list] count]; i<iCnt; i++)
            {   id	obj = [[layerObject list] objectAtIndex:i];
                if ([obj isSelected])
                    [tmpList addObject:obj];
            }
            /* remove objects from layer list */
            for ( i=[slist count]-1; i>=0; i-- )
            {   [layerObject removeObject:[slist objectAtIndex:i]];
                [slist removeObjectAtIndex:i];
            }
            /* unite elements in slist */
            [[[HiddenArea new] autorelease] removeHiddenAreas:tmpList];
            //[change noteNewObjects:tmpList];
            /* add objects from tmpList to list */
            for ( i=0, iCnt = [tmpList count]; i<iCnt; i++ )
            {   id	g = [tmpList objectAtIndex:i];

                [g setSelected:YES];
                [layerObject addObject:g];
                [slist addObject:g];
            }
            /* remove objects to allow reuse for next layer */
            [tmpList removeAllObjects];
        }
    [change endChange];

    [self getSelection];
    drawRect = [self boundsOfArray:slayList];
    [self cache:drawRect];
    [document setDirty:YES];
}

- (void)mirror:sender
{   int		i, l;
    NSRect	rect, drawRect;
    NSPoint	p;
    id		change;

    /* // Debugging of intersections
     {	id	list = [[layerList objectAtIndex:0] list];
        NSPoint	*pa;

        i = [[list objectAtIndex:0] getIntersections:&pa with:[list objectAtIndex:1]];
        NSLog(@"i:%d", i);
        return;
    }*/

    rect = [self coordBoundsOfArray:slayList];
    p.x = rect.origin.x + rect.size.width / 2.0;
    p.y = rect.origin.y + rect.size.height / 2.0;

    drawRect = [self boundsOfArray:slayList];
    change = [[MirrorGraphicsChange alloc] initGraphicView:self center:p];
    [change startChange];
        for (l=[slayList count]-1; l>=0; l--)
        {   NSMutableArray	*slist = [slayList objectAtIndex:l];
            LayerObject		*layer = [layerList objectAtIndex:l];

            if (![layer editable])
                continue;
            //drawRect = [[slayList objectAt:0] extendedBoundsWithScale:[self scaleFactor]];
            for (i=[slist count]-1; i>=0; i--)
            {   VGraphic	*g = [slist objectAtIndex:i];

                //rect = [g extendedBoundsWithScale:[self scaleFactor]];
                //NXUnionRect(&rect, &drawRect);
                [g mirrorAround:p];
                [layer updateObject:g];
                //rect = [g extendedBoundsWithScale:[self scaleFactor]];
                //NXUnionRect(&rect, &drawRect);
            }
        }
    [change endChange];

    rect = [self boundsOfArray:slayList];
    drawRect = NSUnionRect(rect , drawRect);
    [self cache:drawRect];
    [document setDirty:YES];
    [[(App*)NSApp inspectorPanel] loadList:slayList];
}

- (void)rotateG:sender
{
    [self rotate:90.0];
}

/*- (void)transform:sender
{
    [(App*)NSApp showTransformPanel:self];
}*/

/* vectorize images
 * modified: 2011-04-06
 */
- (void)vectorizeWithTolerance:(float)maxError
                  createCurves:(BOOL)createCurves
                          fill:(BOOL)fillResult
                 replaceSource:(BOOL)removeSource
{   int		i, l;
    NSRect	rect, drawRect;
    id		path;
    id		change;

    /* deselect everything that is not image */
    for (l=[slayList count]-1; l>=0; l--)
    {   NSMutableArray	*slist = [slayList  objectAtIndex:l];
        LayerObject		*layer = [layerList objectAtIndex:l];

        if ([layer editable] && [slist count])
        {
            for (i=[slist count]-1; i>=0; i--)
            {   VGraphic	*g = [slist objectAtIndex:i];
                
                if ( ! [g isKindOfClass:[VImage class]] )
                {   [slist removeObjectAtIndex:i];
                    i--;
                }
            }
        }
    }

    drawRect = [self boundsOfArray:slayList];

    change = [[ContourGraphicsChange alloc] initGraphicView:self];
    [change startChange];
    [change setRemoveSource:removeSource];
    for (l=[slayList count]-1; l>=0; l--)
    {   NSMutableArray	*slist = [slayList  objectAtIndex:l];
        LayerObject		*layer = [layerList objectAtIndex:l];

        if ([layer editable] && [slist count])
        {
            for (i=[slist count]-1; i>=0; i--)
            {   VGraphic	*g = [slist objectAtIndex:i];

                if ( [g isKindOfClass:[VImage class]] )
                {   path = [g contour:0.0];
                    if ( createCurves )
                        path = [[VCurveFit sharedInstance] fitGraphic:path maxError:maxError];
                    if ( fillResult )
                        [path setFilled:YES];
                    [slist replaceObjectAtIndex:i withObject:path];
                    [path setSelected:YES];
                    [layer insertObject:path atIndex:[[layer list] indexOfObject:g]+1];
                    if ( removeSource )
                        [layer removeObject:g];
                    else
                        [g setSelected:NO];
                }
            }
        }
    }
    [change endChange];

    rect = [self boundsOfArray:slayList];
    drawRect = NSUnionRect(rect, drawRect);
    [self cache:drawRect];	// update cache
    [document setDirty:YES];
}

- (void)scaleG:(float)x :(float)y
{   int		i, l;
    NSRect	rect, drawRect;
    NSPoint	scaleCenter;
    id		change;

    if ( ![slayList count] )
        return;

    rect = [self boundsOfArray:slayList withKnobs:NO];
    scaleCenter.x = rect.origin.x + rect.size.width  / 2.0;
    scaleCenter.y = rect.origin.y + rect.size.height / 2.0;

    drawRect = [self boundsOfArray:slayList];
    change = [[ScaleGraphicsChange alloc] initGraphicView:self xScale:x yScale:y center:scaleCenter];
    [change startChange];
        for (l=[slayList count]-1; l>=0; l--)
        {   NSMutableArray	*slist = [slayList objectAtIndex:l];

            if (![[layerList objectAtIndex:l] editable])
                continue;
            for (i=[slist count]-1; i>=0; i--)
            {	VGraphic	*g = [slist objectAtIndex:i];

                [g scale:x :y withCenter:scaleCenter];
                [[layerList objectAtIndex:l] updateObject:g];
            }
        }
    [change endChange];

    rect = [self boundsOfArray:slayList];
    drawRect = NSUnionRect(rect, drawRect);
    [self cache:drawRect];
    [document setDirty:YES];
}
- (void)scaleGTo:(float)x :(float)y
{   int		i, l;
    NSRect	rect, drawRect;
    NSPoint	scaleCenter;
    id		change;

    if ( ![slayList count] )
        return;

    //rect = [self boundsOfArray:slayList withKnobs:NO];
    //scaleCenter.x = rect.origin.x + rect.size.width  / 2.0;
    //scaleCenter.y = rect.origin.y + rect.size.height / 2.0;

    drawRect = [self boundsOfArray:slayList];
    //change = [[ScaleGraphicsChange alloc] initGraphicView:self xScale:x yScale:y center:scaleCenter];
    change = [[DimensionsGraphicsChange alloc] initGraphicView:self];
    [change startChange];
    for (l=[slayList count]-1; l>=0; l--)
    {   NSMutableArray	*slist = [slayList objectAtIndex:l];

        if (![[layerList objectAtIndex:l] editable])
            continue;
        for (i=[slist count]-1; i>=0; i--)
        {	VGraphic	*g = [slist objectAtIndex:i];
            NSRect      r = [g coordBounds];
            float       sx, sy;

            sx = x / r.size.width;
            sy = (y != 0.0) ? y / r.size.height : sx;
            scaleCenter = r.origin;
            //scaleCenter.x = r.origin.x + r.size.width  / 2.0;
            //scaleCenter.y = r.origin.y + r.size.height / 2.0;
            [g scale:sx :sy withCenter:scaleCenter];
            [[layerList objectAtIndex:l] updateObject:g];
        }
    }
    [change endChange];

    rect = [self boundsOfArray:slayList];
    drawRect = NSUnionRect(rect, drawRect);
    [self cache:drawRect];
    [document setDirty:YES];
}

- (void)reverse:sender
{   int		i, l;
    NSRect	drawRect;

    drawRect = [self boundsOfArray:slayList];

    for (l=[slayList count]-1; l>=0; l--)
    {	NSMutableArray	*slist = [slayList objectAtIndex:l];

        if (![[layerList objectAtIndex:l] editable])
            continue;
        for (i=[slist count]-1; i>=0; i--)
        {   VGraphic	*g = [slist objectAtIndex:i];

            [g changeDirection];
            [[layerList objectAtIndex:l] updateObject:g];
        }
    }

    [self cache:drawRect];
    [document setDirty:YES];
}

- (void)pathSetStartPoint:sender
{   int		i, l;
    NSRect	drawRect;

    drawRect = [self boundsOfArray:slayList];

    for (l=[slayList count]-1; l>=0; l--)
    {	NSMutableArray	*slist = [slayList objectAtIndex:l];

        if (![[layerList objectAtIndex:l] editable] || [slist count] > 1 )
            continue;
        for (i=[slist count]-1; i>=0; i--)
        {   VPath   *g = [slist objectAtIndex:i];

            if ( [g respondsToSelector:@selector(pointWithNumBecomeStartPoint:)] )
            {   [g pointWithNumBecomeStartPoint:[g selectedKnobIndex]];
                [[layerList objectAtIndex:l] updateObject:g];
            }
        }
    }

    [self cache:drawRect];
    [document setDirty:YES];
}

/* Build Outline of stroked or outline objects, vectorize images
 * modified: 2011-04-06 (-setRemoveSource: added, [path setSelected:YES] added)
 */
- (void)buildContour:sender
{   int		i, l;
    NSRect	rect, drawRect;
    id		path;
    float	width;
    id		change;
    BOOL	removeSource = [(App*)NSApp contourRemoveSource];

    /* show panel to get width */
    if (![(App*)NSApp showContourPanel:self])
        return;
    width = [(App*)NSApp contour]*2.0; // die unit wird in apContour -contour beruecksichtig

    drawRect = [self boundsOfArray:slayList];

    change = [[ContourGraphicsChange alloc] initGraphicView:self];
    [change startChange];
    [change setRemoveSource:removeSource];
        for (l=[slayList count]-1; l>=0; l--)
        {   NSMutableArray	*slist = [slayList  objectAtIndex:l];
            LayerObject		*layer = [layerList objectAtIndex:l];

            if ([layer editable] && [slist count])
            {
                /* hier lokales useRaster nehmen */
                if ( [(App*)NSApp contourUseRaster] )
                {   PathContour	*pathContour = [PathContour new];

                    for (i=[slist count]-1; i>=0; i--)
                    {   VGraphic	*g = [slist objectAtIndex:i];

                        if ( [g isKindOfClass:[VPath class]] )
                            path = [pathContour contourPath:(VPath*)g width:width];
                        else if ( [g respondsToSelector:@selector(contour:)] )
                        {   path = [g contour:width];

                            //if ( [g isKindOfClass:[VImage class]] ) // turn lines into curves
                            //    path = [[VCurveFit sharedInstance] fitGraphic:path maxError:2.0];
                        }
                        else
                            continue; // skip graphic

                        [slist replaceObjectAtIndex:i withObject:path];
                        [path setSelected:YES];
                        [layer insertObject:path atIndex:[[layer list] indexOfObject:g]+1];
                        /* source removen oder nicht */
                        if ( removeSource )
                            [layer removeObject:g];
                        else
                            [g setSelected:NO];
                    }
                    [PathContour release];
                }
                else
                {
                    for (i=[slist count]-1; i>=0; i--)
                    {   VGraphic	*g = [slist objectAtIndex:i];

                        if ( [g respondsToSelector:@selector(contour:)] )
                        {   path = [g contour:width];
                            //if ( [g isKindOfClass:[VImage class]] ) // turn lines into curves
                            //      path = [[VCurveFit sharedInstance] fitGraphic:path maxError:2.0];
                            [slist replaceObjectAtIndex:i withObject:path];
                            [path setSelected:YES];
                            [layer insertObject:path atIndex:[[layer list] indexOfObject:g]+1];
                            /* source removen oder nicht */
                            if ( removeSource )
                                [layer removeObject:g];
                            else
                                [g setSelected:NO];
                        }
                    }
                }
            }
        }
    //[change noteNewObjects:slist];
    [change endChange];

    rect = [self boundsOfArray:slayList];
    drawRect = NSUnionRect(rect, drawRect);
    [self cache:drawRect];	/* update cache */
    [document setDirty:YES];
}

- (void)flatten:sender
{   int		i, l, ix;
    NSRect	drawRect = [self boundsOfArray:slayList];
    id		change;

    change = [[GroupGraphicsChange alloc] initGraphicView:self];
    [change startChange];

    for (l=[slayList count]-1; l>=0; l--)
    {	NSMutableArray	*slist = [slayList objectAtIndex:l];
        LayerObject	*layer = [layerList objectAtIndex:l];

        if (![[layerList objectAtIndex:l] editable])
            continue;
        for (i=[slist count]-1; i>=0; i--)
        {   id	fg, g = [slist objectAtIndex:i];

            fg = [g pathRepresentation];
	    [change noteGroup:fg layer:layer];
            [slist replaceObjectAtIndex:i withObject:fg];
            ix = [[layer list] indexOfObject:g];
            [layer removeObject:g];
            [layer insertObject:fg atIndex:ix];
            //[list replaceObjectAtIndex:[list indexOfObject:g] withObject:fg];
        }
    }

    [change endChange];

    //	[self getBBox:&rect of:slayList];
    //	NXUnionRect(&rect, &drawRect);
    [self cache:drawRect];
    [document setDirty:YES];
}

/* bind text to path
 * create TextPath, remove text and path object from lists
 */
- (void)bindTextToPath:sender
{   int		l, i;
    NSRect	drawRect = [self boundsOfArray:slayList];
    id		change;

    /* deselect everything which will not be part of the group(s) */
    for (l=[layerList count]-1; l>=0; l--)
    {   LayerObject	*layer = [layerList objectAtIndex:l];
        NSMutableArray	*slist = [slayList objectAtIndex:l];
        BOOL		textOk = NO, pathOk = NO;

        if (![layer editable] || [slist count] < 2)
            [slist removeAllObjects];
        for (i=0; i<(int)[slist count]; i++)
        {   VGraphic	*g = [slist objectAtIndex:i];

            /* remove all texts but the first text object */
            if ([g isMemberOfClass:[VText class]])
            {
                if (textOk) {
                    [slist removeObjectAtIndex:i]; i--; }
                textOk = YES;
            }
            /* remove all path objects but the first path object */
            else if ([g isPathObject])
            {
                if (pathOk) {
                    [slist removeObjectAtIndex:i]; i--; }
                pathOk = YES;
            }
            /* remove everything else */
            else {
                [slist removeObjectAtIndex:i]; i--; }
        }
    }

    /* create textPath */
    change = [[GroupGraphicsChange alloc] initGraphicView:self];
    [change startChange];
        for ( l=[slayList count]-1; l>=0; l-- )
        {   NSMutableArray	*slist = [slayList objectAtIndex:l];
            LayerObject		*layer = [layerList objectAtIndex:l];
            VText		*text;
            VGraphic		*path;
            VTextPath		*textPath;

            if ( ![layer editable] || [slist count]<2 )
                continue;
            if ( [[slist objectAtIndex:0] isMemberOfClass:[VText class]] )
            {   text = [slist objectAtIndex:0];
                path = [slist objectAtIndex:1];
            }
            else
            {   text = [slist objectAtIndex:1];
                path = [slist objectAtIndex:0];
            }

            textPath = [VTextPath textPathWithText:text path:path];
	    [change noteGroup:textPath layer:layer];
            [slist removeObject:text];  [slist removeObject:path];
            [layer removeObject:text];  [layer removeObject:path];
            [slist addObject:textPath]; [layer addObject:textPath];
        }
    [change endChange];

    [self cache:drawRect];
    [document setDirty:YES];
}

/* created: 2010-06-13
 */
-(void)addLink:sender
{   NSTextView          *fe = (NSTextView*)[[self window] fieldEditor:NO forObject:nil];
    NSRange             range = [fe selectedRange];
    NSObject            *linkObject;
    NSMutableDictionary *linkAttributes;

    if (range.length == 0)
        return;
    linkObject = [NSURL URLWithString:[[[fe textStorage] string] substringWithRange:range]];
    if ( !linkObject )
        linkObject = [[[fe textStorage] string] substringWithRange:range];
    linkAttributes = [NSMutableDictionary dictionaryWithObject:linkObject
                                                        forKey:NSLinkAttributeName];
    [linkAttributes setObject:[NSColor blueColor]            forKey:NSForegroundColorAttributeName];
    [linkAttributes setObject:[NSNumber numberWithBool: YES] forKey:NSUnderlineStyleAttributeName];
	[[fe textStorage] addAttributes:linkAttributes range:range];
    //[[fe window] resetCursorRects];
}

/*
 * Writes out the layerList and the flags.
 * No need to write out the slayList since it can be regenerated from the layerList.
 * We also ensure that no Text object that might be a subview of the
 * editView gets written out by removing all subviews of the editView.
 */
- (void)encodeWithCoder:(NSCoder *)aCoder
{   int		version = [DocView version];
    BOOL	tile = (tileOriginList) ? YES : NO;

    [aCoder encodeValuesOfObjCTypes:"i", &version];
    [aCoder encodeValuesOfObjCTypes:"@", &layerList];
    [aCoder encodeValuesOfObjCTypes:"@", &origin];
    [aCoder encodeValuesOfObjCTypes:"c{NSPoint=ff}c{NSPoint=ff}", &tile, &tileDistance, &tileLimitSize, &tileLimits];
    [aCoder encodeValuesOfObjCTypes:"cif", &gridIsEnabled, &gridUnit, &gridSpacing];
}
/*
 * Reads in the list and the flags, and regenerates the slayList from the list.
 */
- (id)initWithCoder:(NSCoder *)aDecoder
{   int		version;
    BOOL	tile = NO;

    [layerList release];

    [aDecoder decodeValuesOfObjCTypes:"i", &version];
    [aDecoder decodeValuesOfObjCTypes:"@", &layerList];
    [aDecoder decodeValuesOfObjCTypes:"@", &origin];
    if ( version >= 6 )
        [aDecoder decodeValuesOfObjCTypes:"c{NSPoint=ff}c{NSPoint=ff}", &tile, &tileDistance, &tileLimitSize, &tileLimits];
    else if ( version >=5 )
        [aDecoder decodeValuesOfObjCTypes:"c{NSPoint=ff}", &tile, &tileDistance];
    else
        [aDecoder decodeValuesOfObjCTypes:"c{ff}", &tile, &tileDistance];
    if ( version >= 3 )
        [aDecoder decodeValuesOfObjCTypes:"cif", &gridIsEnabled, &gridUnit, &gridSpacing];

    [self setParameter];
    [self resetGrid];

    {	int	l, i;

        slayList = [[NSMutableArray allocWithZone:[self zone]] init];	// the selected list
        for (l=[layerList count]-1; l>=0; l--)
        {   NSMutableArray	*slist = [NSMutableArray array];
            LayerObject		*layerObject = [layerList objectAtIndex:l];
            NSMutableArray	*list = [layerObject list];

            [layerObject createPerformanceMapWithFrame:[self bounds]];	// create performance map
            [slayList addObject:slist];	// build slist
            [[NSNotificationCenter defaultCenter] postNotificationName:DocLayerListHasChanged
                                                                object:self];

            /* copy clipping rectangle to clipping layer */
            if ( version < 4 )	// < 31.01.00 versions without clipping layer
                for ( i=[list count]-1; i>=0; i-- )
                    if ( [[list objectAtIndex:i] isMemberOfClass:[ClipRectangle class]] )
                    {   NSPoint		o, s;
                        ClipRectangle	*cr = [list objectAtIndex:i];
                        VRectangle	*r = [VRectangle rectangle];

                        [self addLayerWithName:LAYERCLIPPING_STRING type:LAYER_CLIPPING
                                           tag:0 list:nil editable:NO];
                        [[NSNotificationCenter defaultCenter] postNotificationName:DocLayerListHasChanged
                                                                            object:self];
                        [cr getVertices:&o :&s];
                        [r setVertices:o :s];
                        [[layerList objectAtIndex:[layerList count]-1] addObject:r];
                        [layerObject removeObject:cr];
                        break;
                    }
        }
    }
    [self getSelection];
    if (tile)
    {
        if (!tileLimits.x || !tileLimits.y)
            tile = NO;
        [self setTileWithLimits:tileLimits limitSize:tileLimitSize distance:tileDistance
                   moveToOrigin:NO];
    }

    return self;
}
/* used to import document (see VGroup and Document)
 */
+ (id)readList:(id)stream inDirectory:(NSString*)directory
{   NSMutableArray  *list;
    int             version;

    if ( [stream isKindOfClass:[NSUnarchiver class]] )
    {
        [stream decodeValuesOfObjCTypes:"i", &version];
        [stream decodeValuesOfObjCTypes:"@", &list];
    }
    else
        list = arrayFromPropertyList([stream objectForKey:@"layerList"], directory, [self zone]);
    // other stuff ignored

    return list;
}

/* archiving with property list
 */
- (void)allowGraphicsToWriteFilesIntoDirectory:(NSString *)directory
{   int l, i;

    for ( l=[layerList count]-1; l>=0; l-- )
    {   LayerObject	*layerObject = [layerList objectAtIndex:l];
        NSMutableArray	*list = [layerObject list];

        for (i = [list count]-1; i >= 0; i--)
            [[list objectAtIndex:i] writeFilesToDirectory:directory];
    }
}
- (id)propertyList
{   NSMutableDictionary *plist = [NSMutableDictionary dictionaryWithCapacity:9];

    [plist setObject:propertyListFromArray(layerList) forKey:@"layerList"];

    if (backgroundColor)
        [plist setObject:propertyListFromNSColor(backgroundColor) forKey:@"bgColor"];
    [plist setObject:[origin propertyList] forKey:@"origin"];

    if (tileOriginList) [plist setObject:@"YES" forKey:@"tile"];
    [plist setObject:propertyListFromNSPoint(tileDistance) forKey:@"tileDistance"];
    if (tileLimitSize) [plist setObject:@"YES" forKey:@"tileLimitSize"];
    [plist setObject:propertyListFromNSPoint(tileLimits) forKey:@"tileLimits"];

    if (gridIsEnabled) [plist setObject:@"YES" forKey:@"gridIsEnabled"];
    [plist setObject:propertyListFromInt(gridUnit) forKey:@"gridUnit"];
    [plist setObject:propertyListFromFloat(gridSpacing) forKey:@"gridSpacing"];

    return plist;
}
- (id)initFromPropertyList:(id)plist inDirectory:(NSString *)directory
{   id		plistObject, obj;
    BOOL	tile;
    NSString	*className;

    [layerList release];
    layerList = arrayFromPropertyList([plist objectForKey:@"layerList"], directory, [self zone]);

    backgroundColor = colorFromPropertyList([plist objectForKey:@"bgColor"], [self zone]);

    plistObject = [plist objectForKey:@"origin"];
    className = [plistObject objectForKey:@"Class"];
    obj = [NSClassFromString(className) allocWithZone:[self zone]];
    if (!obj)	// load old projects (< 3.50 beta 13)
        obj = [NSClassFromString(newClassName(className)) allocWithZone:[self zone]];
    origin = [obj initFromPropertyList:plistObject inDirectory:directory];

    tile = ([plist objectForKey:@"tile"] ? YES : NO);
    tileDistance = pointFromPropertyList([plist objectForKey:@"tileDistance"]);
    tileLimitSize = ([plist objectForKey:@"tileLimitSize"] ? YES : NO);
    tileLimits = pointFromPropertyList([plist objectForKey:@"tileLimits"]);

    gridIsEnabled = ([plist objectForKey:@"gridIsEnabled"] ? YES : NO);
    gridUnit = [plist floatForKey:@"gridUnit"];
    gridSpacing = [plist floatForKey:@"gridSpacing"];

    [self setParameter];
    [self resetGrid];

    /* create selected list
     * set tool for layer
     */
    {	int	l;

        slayList = [[NSMutableArray allocWithZone:[self zone]] init];	// the selected list
        for ( l=[layerList count]-1; l>=0; l-- )
        {   NSMutableArray	*slist = [NSMutableArray array];
            LayerObject		*layerObject = [layerList objectAtIndex:l];

            [layerObject createPerformanceMapWithFrame:[self bounds]];	// create performance map
            [slayList addObject:slist];		// build slist
        }
    }
    [self getSelection];
    if (tile)
        [self setTileWithLimits:tileLimits limitSize:tileLimitSize distance:tileDistance
                   moveToOrigin:NO];

    return self;
}



/* notification that we have to set our dirty flag
 */
- (void)allLayersHaveChanged:(NSNotification*)sender
{
    [self setAllLayerDirty:YES];
}
/* notification that we have to update the caching
 */
- (void)cachingHasChanged:(NSNotification*)sender
{
    [self setCaching:Prefs_Caching redraw:YES];
}



- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [backgroundColor release];
    [origin release]; origin = nil;

    [layerList release]; layerList = nil;
    [slayList release];

    [tileOriginList release];

    if (![editView superview])
        [editView release];
    [cache release];

    if (numGridRectsX)
    {   NSZoneFree([self zone], gridListX);
        NSZoneFree([self zone], gridListY);
    }

    [super dealloc];
}

@end
