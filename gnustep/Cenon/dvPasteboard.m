/* dvPasteboard.m
 * Pasteboard additions for Cenon DocView class
 *
 * Copyright (C) 1997-2008 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1997
 * modified: 2008-10-21 (pasting of several layers to one layer keeps order of graphics elements)
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
#include <VHFShared/types.h>
#include "DocView.h"
#include "LayerObject.h"
#include "graphicsUndo.subproj/undo.h"

#ifdef __APPLE__
#   define PB_CANSERVE_PDF YES
#endif

@implementation DocView(NSPasteboard)

/* Methods to search through Pasteboard types lists. */

extern BOOL e2IncludesType(NSArray *types, NSString *type)
{
    return types ? ([types indexOfObject:type] != NSNotFound) : NO;
}

NSString *e2MatchTypes(NSArray *typesToMatch, NSArray *orderedTypes)
{   int typesCount = [orderedTypes count];
    int index = 0;

    while (index < typesCount)
    {   NSString * currType = [orderedTypes objectAtIndex:index];

	if (e2IncludesType(typesToMatch, currType))
	    return currType;
	++index;
    }
    return nil;
}

/*
 * Returns the pasteboard type in the passed array of types which is preferred
 * for pasting.
 */
NSString *e2TextPasteType(NSArray *types)
{
    if (e2IncludesType(types, NSRTFPboardType)) return NSRTFPboardType;
    if (e2IncludesType(types, NSStringPboardType)) return NSStringPboardType;
    return nil;
}

/*
 * Returns the pasteboard type in the passed array of types which is preferred
 * for pasting.
 */
NSString *e2ForeignPasteType(NSArray *types)
{   NSString	*retval = e2TextPasteType(types);

    return retval ? retval : e2MatchTypes(types, [NSImage imagePasteboardTypes]);
}

/*
 * Returns the pasteboard type in the passed list of types which is preferred
 * for pasting.  Cenon prefers its own type, then it prefers Text,
 * then something NSImage can handle.
 */
NSString *e2CenonPasteType(NSArray *types)
{
    if (e2IncludesType(types, e2PboardType))
        return e2PboardType;
    return e2ForeignPasteType(types);
}

NSArray *e2TypesCenonExports(void)
{   static	NSArray	*exportList = nil;

    if (!exportList)
    {
#ifdef PB_CANSERVE_PDF
        exportList = [[NSArray allocWithZone:NSDefaultMallocZone()] initWithObjects:e2PboardType, NSPDFPboardType, NSPostScriptPboardType/*, NSTIFFPboardType*/, nil];
#else
        exportList = [[NSArray allocWithZone:NSDefaultMallocZone()] initWithObjects:e2PboardType, NSPostScriptPboardType/*, NSTIFFPboardType*/, nil];
#endif
    }
    return exportList;
}

/* Lazy Pasteboard evaluation handler */

/*
 * IMPORTANT: The pasteboard:provideDataForType: method is a factory method since the
 * factory object is persistent and there is no guarantee that the INSTANCE of
 * the view that put stuff into the Pasteboard will be around
 * to lazily put PostScript or TIFF in there, so we keep one around (actually
 * we only create it when we need it) to do the conversion (scrapper).
 *
 * If you find this part of the code confusing, then you need not even
 * use the provideData: mechanism--simply put the data for all the different
 * types your program knows how to put in the Pasteboard in at the time
 * that you declareTypes:.
 */

/*
 * Converts the data in the Pasteboard from internal format to
 * either PostScript or TIFF using the dataForTIFF and dataForEPS
 * methods. It sends these messages to the scrapper (a GraphicView cached
 * to perform this very function).
 */
+ (void)convert:(NSUnarchiver *)unarchiver to:(NSString *)type using:(SEL)writer toPasteboard:(NSPasteboard *)pb
{   NSWindow		*w;
    NSMutableArray	*array;
    NSData		*data;
    DocView		*scrapper;
    NSRect		scrapperFrame = {{0.0, 0.0}, {11.0*72.0, 14.0*72.0}};
    static NSZone	*scrapperZone = NULL;

    if (!scrapperZone)
        scrapperZone = NSCreateZone(NSPageSize(), NSPageSize(), YES);

    if (unarchiver)
    {
        scrapper = [[DocView allocWithZone:scrapperZone] initWithFrame:scrapperFrame];
        [scrapper initView];	// init scale etc.
        [unarchiver setObjectZone:scrapperZone];
        array = [[NSMutableArray allocWithZone:scrapperZone] initWithArray:[unarchiver decodeObject]];
        scrapperFrame = [scrapper boundsOfArray:array];
        scrapperFrame.size.width += scrapperFrame.origin.x;
        scrapperFrame.size.height += scrapperFrame.origin.y;
        scrapperFrame.origin.x = scrapperFrame.origin.y = 0.0;
        [scrapper setFrameSize:(NSSize){ scrapperFrame.size.width, scrapperFrame.size.height }];
        w = [[NSWindow allocWithZone:scrapperZone] initWithContentRect:scrapperFrame
                                                             styleMask:NSBorderlessWindowMask
                                                               backing:NSBackingStoreNonretained
                                                                 defer:NO];
        [w setContentView:scrapper];
        if ((data = [scrapper performSelector:writer withObject:array]))
            [pb setData:data forType:type];
        [scrapper release];
        [array release];
        [w release];
    }
}


/*
 * Called by the Pasteboard whenever PostScript or TIFF data is requested
 * from the Pasteboard by some other application. The current contents of
 * the Pasteboard (which is in the internal format) is taken out and loaded
 * into an NSData, then convert:to:using:toPasteboard: is called. This
 * returns self if successful, nil otherwise.
 * modified: 2005-09-23
 */
+ (void)pasteboard:(NSPasteboard*)sender provideDataForType:(NSString*)type
{
    if ( [e2TypesCenonExports() containsObject:type] )
    {   NSData	*pbData;

        if ((pbData = [sender dataForType:e2PboardType]))
        {   NSUnarchiver *unarchiver = [[NSUnarchiver allocWithZone:(NSZone *)[(NSObject *)self zone]]
                                       initForReadingWithData:pbData];

            if (unarchiver)
            {
                if ([type isEqual:NSPostScriptPboardType])
                {
                    [self convert:unarchiver to:type using:@selector(dataForEPSUsingList:)
                     toPasteboard:sender];
                }
#ifdef PB_CANSERVE_PDF
                else if ([type isEqual:NSPDFPboardType])
                {
                    [self convert:unarchiver to:type using:@selector(dataForPDFUsingList:)
                     toPasteboard:sender];
                }
#endif
                else	// So it must be "NSTIFFPboardType"...
                {
                    [self convert:unarchiver to:type using:@selector(dataForTIFFUsingList:)
                     toPasteboard:sender];
                }
                [unarchiver release];
            }
            //[sender deallocatePasteboardData:pbData];
        }
    }
}

/* Writing data in different forms (other than the internal format) */

/*
 * Writes out the PostScript generated by drawing all the objects in the
 * glist. The bounding box of the generated encapsulated PostScript will
 * be equal to the bounding box of the objects in the glist (NOT the
 * bounds of the view).
 */
- (NSData*)dataForEPS
{   NSRect	bbox;
    NSData	*data = nil;

    bbox = [self boundsOfArray:layerList];
    data = [self dataWithEPSInsideRect:bbox];
    return data;
}
#ifdef PB_CANSERVE_PDF
- (NSData*)dataForPDF
{   NSRect	bbox;
    NSData	*data = nil;

    bbox = [self boundsOfArray:layerList];
    data = [self dataWithPDFInsideRect:bbox];
    return data;
}
#endif
/*
 * Images all of the objects in the glist and writes out the result in
 * the Tagged VImage File Format (TIFF). The image will not have alpha in it.
 */
- (NSData*)dataForTIFF
{   NSData	*data = nil;
    /*NSRect	bbox;
    NSImage	*tiffCache;

    bbox = [self boundsOfArray:layerList];
    tiffCache = [[NSImage allocWithZone:[self zone]] initWithSize:bbox.size];
    //[self cacheList:layerList into:tiffCache];	// FIXME
    data = [tiffCache TIFFRepresentationUsingCompression:NSTIFFCompressionLZW factor:0.0];
    [tiffCache release];*/
    return data;
}

/*
 * This is the same as dataForEPS, but it lets you specify the list
 * of Graphics you want to generate PostScript for (does its job by swapping
 * the glist for the list you provide temporarily).
 */
- (NSData *)dataForEPSUsingList:(NSArray*)list
{   NSData	*data = nil;
    int		l;

    // FIXME: save current layer list
    for (l=0; l<[list count]; l++)
        [self addList:[list objectAtIndex:l] toLayerAtIndex:0];
    data = [self dataForEPS];
    // FIXME: restore layer list

    return data;
}
#ifdef PB_CANSERVE_PDF
- (NSData*)dataForPDFUsingList:(NSArray*)list
{   int	l;

    for (l=0; l<[list count]; l++)
        [self addList:[list objectAtIndex:l] toLayerAtIndex:0];
    return [self dataForPDF];
}
#endif
/*
 * This is the same as dataForTIFF, but it lets you specify the list
 * of Graphics you want to generate TIFF for (does its job by swapping
 * the list of the first layer for the list you provide temporarily.
 */
- (NSData*)dataForTIFFUsingList:(NSArray*)list
{   NSData		*data = nil;
    int			l;
    //NSMutableArray	*savedList = [[[layerList objectAtIndex:0] list] retain];	// FIXME

    for (l=0; l<[list count]; l++)
        [self addList:[list objectAtIndex:l] toLayerAtIndex:0];
    data = [self dataForTIFF];
    //[[layerList objectAtIndex:0] setList:[savedList autorelease]];	// FIXME
    return data;
}


/* Writing the selection to an NSData
 */
- (NSData *)copySelectionAsEPS
{
    return ([slayList count]) ? [self dataForEPSUsingList:slayList] : nil;
}
#ifdef PB_CANSERVE_PDF
- (NSData *)copySelectionAsPDF
{
    return ([slayList count]) ? [self dataForPDFUsingList:slayList] : nil;
}
#endif
- (NSData *)copySelectionAsTIFF
{
    return ([slayList count]) ? [self dataForTIFFUsingList:slayList] : nil;
}

- (NSData *)copySelection
{   NSData *data = nil;
    
    if ([slayList count])
	data = [NSArchiver archivedDataWithRootObject:slayList];

    return data;
}

/* Pasteboard-related target/action methods */

/*
 * Calls copy: then delete:.
 */
- (void)cut:(id)sender
{   id change;

    if ([slayList count] > 0)
    {
	change = [[CutGraphicsChange alloc] initGraphicView:self];
	[change startChange];
            [self copy:sender];
//        lastCutChangeCount = lastCopiedChangeCount;
            [self delete:sender];
            consecutivePastes = 0;
        [change endChange];
    }
}

- (void)copy:(id)sender
{   int	l;

    if ([slayList count])
    {
        [self copyToPasteboard:[NSPasteboard generalPasteboard]];
        lastPastedChangeCount = [[NSPasteboard generalPasteboard] changeCount];
        lastCopiedChangeCount = [[NSPasteboard generalPasteboard] changeCount];
        consecutivePastes = 1;
        for (l=[slayList count]-1; l>=0; l--)
        {   NSMutableArray	*list = [slayList objectAtIndex:l];

            if (list && [list count])
            {	originalPaste = [list objectAtIndex:0];
                break;
            }
        }
    }
}

- (void)paste:(id)sender
{
    [self paste:sender andLink:DontLink];
}
/*- (void)pasteAndLink:sender
{
    [self paste:sender andLink:Link];
}
- (void)link:sender
{
    [self paste:sender andLink:LinkOnly];
}*/

/* Methods to write to/read from the pasteboard */

/*
 * Puts all the objects in the slist into the Pasteboard by archiving
 * the slist itself.  Also registers the PostScript and TIFF types since
 * the GraphicView knows how to convert its internal type to PostScript
 * or TIFF via the write{PS,TIFF} methods.
 * modified: 2005-09-23
 */
- copyToPasteboard:(NSPasteboard *)pboard types:(NSArray *)typesList
{
    if ([slayList count])
    {   NSMutableArray  *types = [[[NSMutableArray alloc] initWithCapacity:1] autorelease];
        NSData          *data;

        [types addObject:e2PboardType];
        if (!typesList || e2IncludesType(typesList, NSPostScriptPboardType))
            [types addObject:NSPostScriptPboardType];
#ifdef PB_CANSERVE_PDF
        if (!typesList || e2IncludesType(typesList, NSPDFPboardType))
            [types addObject:NSPDFPboardType];
#endif
        if (!typesList || e2IncludesType(typesList, NSTIFFPboardType))
            [types addObject:NSTIFFPboardType];
        [pboard declareTypes:types owner:[self class]];
        data = [self copySelection];
        if (data)
            [pboard setData:data forType:e2PboardType];
        //[self writeLinkToPasteboard:pboard types:typesList];
        return self;
    }
    else
        return nil;
}

- copyToPasteboard:(NSPasteboard *)pboard
{
    return [self copyToPasteboard:pboard types:NULL];
}

/*
 * Pastes any data that comes from another application.
 * Basically this is the "else" in pasteFromPasteboard: below if there
 * is no internal format in the Pasteboard. This is also called
 * from the drag stuff (see gvDrag.m).
 */
- (BOOL)pasteForeignDataFromPasteboard:(NSPasteboard *)pboard andLink:(LinkType)doLink at:(NSPoint)center
{   VGraphic	*graphic = nil;

    //graphic = [[VText allocWithZone:(NSZone *)[self zone]] initWithPasteboard:pboard];
    if (!graphic)
        graphic = [[VImage allocWithZone:(NSZone *)[self zone]] initWithPasteboard:pboard];

    [self deselectAll:self];
    if (graphic && [self placeGraphic:graphic at:center])
            return YES;
    return NO;
}

/*
 * modified: 04.07.97
 *
 * Pastes any type available from the specified Pasteboard into the GraphicView.
 * If the type in the Pasteboard is the internal type, then the objects
 * are simply added to the slist and glist.  If it is PostScript or TIFF,
 * then an VImage object is created using the contents of
 * the Pasteboard.  Returns a list of the pasted objects (which should be freed
 * by the caller).
 */
- (NSArray *)pasteFromPasteboard:(NSPasteboard *)pboard andLink:(LinkType)doLink at:(const NSPoint *)center
{   int         i, l;
    id          change;
    NSArray     *pblist = nil;
    VGraphic    *graphic = nil;
    BOOL        pasteDrawType = NO;

    //if (!linkManager)
    doLink = DontLink;
    if (!doLink)
        pasteDrawType = e2IncludesType([pboard types], e2PboardType);

    if (pasteDrawType)
    {   NSData	*pbData = nil;

        if ((pbData = [pboard dataForType:e2PboardType]))
        {   NSUnarchiver *unarchiver = [[NSUnarchiver allocWithZone:(NSZone *)[self zone]] initForReadingWithData:pbData];

            if (unarchiver)
            {   NSPoint	offset = NSMakePoint(0, 0);
                NSRect	pbBounds, bounds = [self bounds];

                pblist = [[[NSMutableArray alloc] initWithArray:[unarchiver decodeObject]] autorelease];

                /* keep graphics inside bounds (consecutive paste) or visible rect (1st paste) */
                pbBounds = [self boundsOfArray:pblist withKnobs:NO];
                if ( bounds.origin.x+bounds.size.width < pbBounds.origin.x+pbBounds.size.width )
                    offset.x = bounds.origin.x+bounds.size.width - (pbBounds.origin.x+pbBounds.size.width);
                if ( bounds.origin.y+bounds.size.height < pbBounds.origin.y+pbBounds.size.height )
                    offset.y = bounds.origin.y+bounds.size.height - (pbBounds.origin.y+pbBounds.size.height);
                if (gridIsEnabled)
                {   offset.x = floor(offset.x / [self grid]) * [self grid];
                    offset.y = floor(offset.y / [self grid]) * [self grid];
                }
                if ( offset.x || offset.y )
                {
                    for (l=[pblist count]-1; l>=0; l--)
                    {   NSMutableArray	*list = [pblist objectAtIndex:l];
                        int		i;

                        for (i=[list count]-1; i>=0; i--)
                            [[list objectAtIndex:i] moveBy:offset];
                    }
                }

                /* equal number of layers -> paste to same layer
                 * otherwise              -> paste all to first editable layer
                 */
                if ([pblist count])
                {   int	fixLayer = -1, cnt = Min([layerList count], [pblist count]);

                    [self deselectAll:self];
                    /* check, if 1:1 paste is possible */
                    for (l=0; l<(int)[pblist count]; l++)
                        if ( l >= (int)[layerList count] ||
                             (![[layerList objectAtIndex:l] editable] &&
                               [[[layerList objectAtIndex:l] list] count]) )
                            break;	// No
                    /* we can't paste to the same layer, so we paste to 1st editable layer */
                    if ( [layerList count] < [pblist count] || l < (int)[pblist count] )
                    {
                        for ( l=0; l<(int)[layerList count]; l++ )
                        {
                            if ( [[layerList objectAtIndex:l] editable] )
                            {   fixLayer = l; break; }
                        }
                    }
                    cnt = (fixLayer < 0) ? Min([layerList count], [pblist count]) : [pblist count];
                    //for ( l=cnt-1; l>=0; l-- )
                    for ( l=0; l < cnt; l++ )
                    {   int             insertLayer = (fixLayer >= 0) ? fixLayer : l;
                        NSMutableArray  *slist;
                        LayerObject     *layer;
                        NSMutableArray  *srcList = [pblist objectAtIndex:l];

                        /* paste to 1st editable layer */
                        if ( fixLayer < 0 && ![[layerList objectAtIndex:l] editable])
                        {
                            for ( i=0; i<cnt; i++ )
                            {
                                if ( [[layerList objectAtIndex:i] editable] )
                                {   insertLayer = i; break; }
                            }
                        }

                        layer = [layerList objectAtIndex:insertLayer];
                        slist = [slayList objectAtIndex:insertLayer];
                        if ([srcList count])
                        {
                            for (i=0; i<(int)[srcList count]; i++)
                            {
                                graphic = [srcList objectAtIndex:i];
                                [graphic setSelected:YES];
                                [slist addObject:graphic];
                                [layer addObject:graphic];
                            }
                        }
                    }
                    [document setDirty:YES];
                    change = [[PasteGraphicsChange alloc] initGraphicView:self];
                    [change startChange];
                    [change endChange];
                }
                else
                    pblist = nil;
                [unarchiver release];
            }
        }
    }
    else
    {   NSPoint position;
        NSRect bounds;
        if (!center)
        {
            bounds = [self visibleRect];
            position.x = floor(bounds.size.width / 2.0 + 0.5);
            position.y = floor(bounds.size.height / 2.0 + 0.5);
        }
        else
            position = *center;
        [self pasteForeignDataFromPasteboard:pboard andLink:doLink at:position];
    }

    return pblist;
}

/*
 * Pastes from the normal pasteboard.
 * This paste implements "smart paste" which goes like this: if the user
 * pastes in a single item (a VGroup is considered a single item), then
 * pastes that item again and moves that second item somewhere, then
 * subsequent pastes will be positioned at the same offset between the
 * first and second pastes (this is also known as "transform again").
 */
- (void)paste:sender andLink:(LinkType)doLink
{   NSArray		*pblist;
    NSPoint		offset;
    VGraphic		*graphic = nil;
    NSPasteboard	*pboard = [NSPasteboard generalPasteboard];
    NSRect		originalBounds, secondBounds, rect, bounds;
    static VGraphic	*secondPaste;
    static NSPoint	pasteOffset;
    int			l;

    /* FIXME: We shouldn't insert the pblist in this method.
     * Instead we should return pblist and insert it here
     */
    pblist = [self pasteFromPasteboard:pboard andLink:doLink at:NULL];

    if (pblist && e2IncludesType([pboard types], e2PboardType))
    {
        /* take 1st graphic object to calculate paste offsets */
        for (l=[pblist count]-1; l>=0; l--)
        {   NSMutableArray	*list = [pblist objectAtIndex:l];

            if (list && [list count])
            {	graphic = [list objectAtIndex:0];
                break;
            }
            else if ( !l )
                return;
        }

        if (lastPastedChangeCount != [pboard changeCount] || !originalPaste)
        {   NSPoint	offset = NSMakePoint(0, 0);
            NSRect	pbBounds, bounds = [self visibleRect];

            consecutivePastes = 0;
            lastPastedChangeCount = [pboard changeCount];
            originalPaste = graphic;

            /* keep graphics inside visible rect for 1st paste */
            pbBounds = [self boundsOfArray:slayList withKnobs:NO];
            if ( bounds.origin.x > pbBounds.origin.x )
                offset.x = bounds.origin.x - pbBounds.origin.x;
            else if ( bounds.origin.x+bounds.size.width < pbBounds.origin.x+pbBounds.size.width )
                offset.x = bounds.origin.x+bounds.size.width - (pbBounds.origin.x+pbBounds.size.width);
            if ( bounds.origin.y > pbBounds.origin.y )
                offset.y = bounds.origin.y - pbBounds.origin.y;
            else if ( bounds.origin.y+bounds.size.height < pbBounds.origin.y+pbBounds.size.height )
                offset.y = bounds.origin.y+bounds.size.height - (pbBounds.origin.y+pbBounds.size.height);
            if (gridIsEnabled)
            {   offset.x = floor(offset.x / [self grid]) * [self grid];
                offset.y = floor(offset.y / [self grid]) * [self grid];
            }
            if ( offset.x || offset.y )
            {
                for (l=[slayList count]-1; l>=0; l--)
                {   NSMutableArray  *slist = [slayList objectAtIndex:l];
                    LayerObject     *layer = [layerList objectAtIndex:l];
                    int             i;

                    for (i=[slist count]-1; i>=0; i--)
                    {   VGraphic	*g = [slist objectAtIndex:i];

                        [g moveBy:offset];
                        [layer updateObject:g];
                    }
                }
            }
        }
        else
        {
            if (consecutivePastes == 1)	// smart paste
            {
                pasteOffset.x = (gridIsEnabled) ?  [self grid] : 10.0;
                pasteOffset.y = -pasteOffset.x;
                secondPaste = graphic;
            }
            else if ((consecutivePastes == 2) && graphic)
            {
                originalBounds = [originalPaste bounds];
                secondBounds = [secondPaste bounds];
                pasteOffset.x = secondBounds.origin.x - originalBounds.origin.x;
                pasteOffset.y = secondBounds.origin.y - originalBounds.origin.y;
            }
            offset.x = pasteOffset.x * consecutivePastes;
            offset.y = pasteOffset.y * consecutivePastes;

            /* get bounds of selection, limit offset to working area */
            rect = [self boundsOfArray:slayList];
            bounds = [self bounds];
            offset.x = (rect.origin.x+rect.size.width+offset.x < bounds.origin.x + bounds.size.width)
                       ? offset.x : bounds.origin.x+bounds.size.width - (rect.origin.x+rect.size.width);
            offset.y = (rect.origin.y+offset.y > bounds.origin.y)
                       ? offset.y : bounds.origin.y - rect.origin.y;

            /* move selected objects */
            for (l=[slayList count]-1; l>=0; l--)
            {	NSMutableArray	*slist = [slayList objectAtIndex:l];
                LayerObject	*layer = [layerList objectAtIndex:l];
                int		i;

                for (i=[slist count]-1; i>=0; i--)
                {   VGraphic	*g = [slist objectAtIndex:i];

                    [g moveBy:offset];
                    [layer updateObject:g];
                }
            }
        }
        consecutivePastes++;
        [[(App*)NSApp inspectorPanel] loadList:slayList];
        //	[self cacheSelection];
        [self drawAndDisplay];	// redraw object bounds
    }
    //[pblist release];
}

@end
