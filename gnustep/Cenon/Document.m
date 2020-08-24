/* Document.m
 * Cenon document class
 *
 * Copyright (C) 1996-2013 by vhf interservice GmbH
 * Author: Georg Fleischmann
 *
 * Created:  1996-02-09
 * Modified: 2013-01-02 (-printDocument: remove paper margins from view, which are not ignored any more since OS 10.8)
 *           2011-03-30 (-exportLock, -setExportLock:)
 *           2010-11-26 (-saveTiff text work)
 *           2010-06-30 (-saveTiff added)
 *           2008-10-21 (clean-up)
 *           2008-07-24 (document units, update units)
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
#include <VHFShared/vhfCommonFunctions.h>
#include <VHFShared/VHFDictionaryAdditions.h>
#include <VHFShared/VHFSystemAdditions.h>
#include "Document.h"
#include "DocWindow.h"
#include "DocView.h"
#include "TileScrollView.h"
#include "App.h"
#include "PreferencesMacros.h"
#include "messages.h"
#include "locations.h"
#include "propertyList.h"
#include "EPSExport.h"
#include "HPGLExportSub.h"
#include "GerberExportSub.h"
#include "DXFExportSub.h"
#ifdef __APPLE__
#    include "GSPropertyListSerialization.h"
#endif

#define XOFFSET             5.0     // Offset of subsequent windows
#define YOFFSET             -20.0
#define	MAXWINWIDTH         900     // maximum size of the window
#define	MAXWINHEIGHT        750

#define DOCUMENT_VERSION    102
#define DOCUMENT_NAME       @"document"
#define OUTPUT_NAME         @"output"

/* Private methods */
@interface Document(PrivateMethods)
- initWindow;
- (void)initializePrintInfo;
- (BOOL)setWindowSize:(NSSize)size;
//- (BOOL)loadOutputListsFromFile:(const char*)fileName;
- (BOOL)saveTiff:(NSString*)filename;
- (BOOL)saveEPS:(NSString*)filename;
- (BOOL)saveGerber:(NSString*)filename;
- (BOOL)saveHPGL:(NSString*)filename;
- (BOOL)saveDXF:(NSString*)filename;
- (BOOL)saveFont:(NSString*)filename;
@end

@implementation Document

/*
 * Calculates the size of the page the user has chosen (minus its margins)
 */
NSRect calcFrame(NSPrintInfo *printInfo)
{   NSRect	viewRect = NSZeroRect;

    viewRect.size = [printInfo paperSize];

    /* use machine area for our bounds if available */
    if ([NSApp respondsToSelector:@selector(getMachineSize:)])
    {   NSSize	size;

        [(App*)NSApp performSelector:@selector(getMachineSize:) withObject:(id)&size];
        viewRect.size = size;
    }

    /* fallback */
    if ( viewRect.size.width + viewRect.size.height < 50.0 )
        viewRect.size = NSMakeSize(595, 842);	// A4

    //viewRect.size.width -= [printInfo leftMargin] + [printInfo rightMargin];
    //viewRect.size.height -= [printInfo topMargin] + [printInfo bottomMargin];

    return viewRect;
}

/*
 * We reuse zones since it doesn't cost us anything to have a
 * zone lying around (e.g. if we open ten documents at the start
 * then don't use 8 of them for the rest of the session, it doesn't
 * cost us anything except VM (no real memory cost)), and it is
 * risky business to go around NSDestroy()'ing zones since if
 * your application accidentally allocates some piece of global
 * data into a zone that gets destroyed, you could have a pointer
 * to freed data on your hands!  We use the List object since it
 * is so easy to use (which is okay as long as 'id' remains a
 * pointer just like (NSZone *) is a pointer!).
 *
 * Note that we don't implement alloc and allocFromZone: because
 * we create our own zone to put ourselves in.  It is generally a
 * good idea to "notImplemented:" those methods if you do not allow
 * an object to be alloc'ed from an arbitrary zone (other examples
 * include Application and all of the Application Kit panels
 * (which allocate themselves into their own zone).
 */

static NSMutableArray *zoneList = nil;

+ (NSZone *)newZone
{   id	zone;

    if (!zoneList || ![zoneList count])
        return NSCreateZone(NSPageSize(), NSPageSize(), YES);
    zone = [zoneList lastObject];
    [zoneList removeLastObject];
    return (NSZone *)zone;
}

+ (void)reuseZone:(NSZone *)aZone
{
    if (!zoneList)
        zoneList = [[NSMutableArray alloc] init];
    [zoneList addObject:(id)aZone];
}

+ (id)allocWithZone:(NSZone *)aZone
{
    [NSException raise:@"NSInvalidArgumentException" format:@"*** Method: allocWithZone: not implemented by %@", [self class]];
    return nil;
}

+ (id)alloc
{
    [NSException raise:@"NSInvalidArgumentException" format:@"*** Method: alloc not implemented by %@", [self class]];
    return nil;
}

/*
 * Creates a new, empty, document.
 *
 * Creates a PrintInfo object; creates a view whose size depends on the
 * default PrintInfo created; creates a window for that view; sets self
 * as the window's delegate; orders the window front; registers the window
 * with the Workspace Manager.  Note that the default margins are set
 * to 1/2 inch--that's more appropriate for a draw program than 1 or 1.25
 * inches.
 */
+ new
{   Document	*newDocument = nil;

    newDocument = [[super allocWithZone:[self newZone]] init];
    //newDocument = [[Document allocWithZone:[Document newZone]] init];
    if (![NSBundle loadModelNamed:@"Document" owner:newDocument])
    {	NSLog(@"Cannot load Document model");	
        [newDocument release];
        return nil;
    }

    [newDocument setName:nil andDirectory:nil];
    [newDocument initWindow];
    return newDocument;
}

- (id)init
{
    [super init];

    baseUnit = UNIT_NONE;   // use unit from Preferences

    //[self registerForServicesMenu];
    return self;
}

- initWindow
{   NSRect	frameRect;
    DocView	*view;

    [window setDelegate:self];
    [scrollView setHasHorizontalScroller:YES];
    [scrollView setHasVerticalScroller:YES];

    /* Put the window offset from the previous document window... If no
     * previous window exists, or the main window is undetermined, then
     */
    if ([NSApp mainWindow])
    {	NSRect	winFrame, winLoc;

        winFrame = [[NSApp mainWindow] frame];
        winLoc = [[window class] contentRectForFrameRect:winFrame styleMask:[window styleMask]];
        [window setFrameOrigin:NSMakePoint(NSMinX(winLoc) + XOFFSET, NSMinY(winLoc) + YOFFSET)];
    }

    //printInfo = [[NSPrintInfo allocWithZone:[self zone]] init];
    [self initializePrintInfo];
    frameRect = calcFrame(printInfo);
    view = [[DocView allocWithZone:[self zone]] initWithFrame:frameRect];
    [view setDocument:self];
    [scrollView setDocumentView:view];
    [view initView];
    [view release];
    [scrollView setDocument:self];
    if ([[self documentView] caching])
        [[self documentView] draw:NSZeroRect];

    [window setDocument:self];
    [window makeKeyAndOrderFront:self];
    [window makeFirstResponder:view];	// makeKeyAndOrderFront makes the PopUp the first responder !
    [window setMiniwindowImage:[NSImage imageNamed:@"typeCenon"]];

    [[NSNotificationCenter defaultCenter] postNotificationName:DocumentDidOpen
                                                        object:view];

    return self;
}

/* modified: 2008-07-24 (load baseUnit, project settings)
 */
+ newFromFile:(NSString*)fileName
{   Document        *newDocument = nil;
    NSDictionary    *plist = nil;
    NSString        *fileDirectory = nil, *outputFile = nil;
    NSString        *directoryContainingDocument = nil;
    NSFileManager   *fileManager = [NSFileManager defaultManager];
    BOOL            isDirectory = NO;
    DocView         *view;
    NSRect          fRect;

    if ([fileManager fileExistsAtPath:fileName isDirectory:&isDirectory])
    {
        if (isDirectory)
        {
            fileDirectory = fileName;
            fileName   = [fileDirectory stringByAppendingPathComponent:DOCUMENT_NAME];
            outputFile = [fileDirectory stringByAppendingPathComponent:OUTPUT_NAME];
        }
        else if ([[fileName lastPathComponent] isEqual:DOCUMENT_NAME])
        {
            fileDirectory = [fileName stringByDeletingLastPathComponent];
            if (![[fileDirectory pathExtension] isEqual:DOCUMENT_EXT])
                fileDirectory = nil;
        }
        if ([fileManager isReadableFileAtPath:fileName])
        {
            newDocument = [super allocWithZone:[self newZone]];
            [(App*)NSApp setCurrentDocument:newDocument];
            if (![NSBundle loadModelNamed:@"Document" owner:newDocument])
            {	NSLog(@"Cannot load Document model");	
                [newDocument release];
                return nil;
            }
            [newDocument init];

            plist = [NSDictionary dictionaryWithContentsOfFile:fileName];
            /* PrintInfo */
            if ( [[plist objectForKey:@"PrintInfo"] isKindOfClass:[NSDictionary class]] )
                newDocument->printInfo = printInfoFromPropertyList([plist objectForKey:@"PrintInfo"], [self zone]);
            else
                newDocument->printInfo = [[NSUnarchiver unarchiveObjectWithData:[plist objectForKey:@"PrintInfo"]] retain];
            [newDocument->printInfo setHorizontalPagination:NSAutoPagination];
            [newDocument->printInfo setVerticalPagination:NSAutoPagination];

            /* Project Info */
            newDocument->docVersion   = [[plist objectForKey:@"DocVersion"] retain];
            newDocument->docAuthor    = [[plist objectForKey:@"Author"]     retain];
            newDocument->docCopyright = [[plist objectForKey:@"Copyright"]  retain];
            newDocument->docComment   = [[plist objectForKey:@"Comment"]    retain];

            newDocument->exportLock   = ([plist objectForKey:@"exportLock"]) ? YES : NO;

            /* Project Settings */
            if ([plist objectForKey:@"DocSettings"])
                newDocument->docSettingsDict = [[plist objectForKey:@"DocSettings"] mutableCopy];
            if ([plist objectForKey:@"Unit"])
                newDocument->baseUnit        = [plist intForKey:@"Unit"];

            directoryContainingDocument = fileDirectory ? fileDirectory
                                                        : [fileName stringByDeletingLastPathComponent];

            [newDocument->window setDelegate:newDocument];
            [newDocument->scrollView setHasHorizontalScroller:YES];
            [newDocument->scrollView setHasVerticalScroller:YES];

            /* Put the window offset from the previous document window... If no
             * previous window exists, or the main window is undetermined, then
             */
            if ([NSApp mainWindow])
            {	NSRect	winFrame, winLoc;

                winFrame = [[NSApp mainWindow] frame];
                winLoc = [[newDocument->window class] contentRectForFrameRect:winFrame
                                                                    styleMask:[newDocument->window styleMask]];
                [newDocument->window setFrameOrigin:NSMakePoint(NSMinX(winLoc) + XOFFSET, NSMinY(winLoc) + YOFFSET)];
            }

            [newDocument->window setFrameFromString:[plist objectForKey:@"WindowFrame"]];
#ifdef __APPLE__    // needed, if a folded window is loaded to restore the window frame
            {   float  h = [plist floatForKey:@"WindowUnfoldedHeight"];

                [newDocument->window setUnfoldedHeight:h];
                if ( h > 20.0 ) // folded window: we have to reinforce the frame height
                {   NSRect  frame = rectFromPropertyList([plist objectForKey:@"WindowFrame"]);

                    //frame.size.height = h;    // if we want to open windows unfolded (add y!)
                    [newDocument->window setFrame:frame display:NO];
                }
            }
#endif
            /* GNUSTEP: make sure window is not bigger than necessary
             *          (the window frame doesn't include title bar and resize bar)
             */
#ifdef GNUSTEP_BASE_VERSION
            {   NSRect	r = rectFromPropertyList([plist objectForKey:@"ViewSize"]);

                r.size.height += [newDocument->window coordBoxSize].height;
                r.size.height += [NSScroller scrollerWidth] + 1.0;
                r.size.width  += [NSScroller scrollerWidth] + 2.0;
                [newDocument->window setContentSize:r.size];
                /* we call setFrame again to avoid X-Windows error. Why is this necessary ??? */
                [newDocument->window setFrameFromString:[newDocument->window stringWithSavedFrame]];
            }
#endif

            /* workaround: something (NSWindow according documentation) doesn't work with size>10000.0 */
            // #if VHF_IS_DOUBLE == 0
            fRect = rectFromPropertyList([plist objectForKey:@"ViewSize"]);
            if ( fRect.size.width > 10000.0 )
                fRect.size.width = 10000.0;
            if ( fRect.size.height > 10000.0 )
                fRect.size.height = 10000.0;
            view = [[DocView allocWithZone:[self zone]] initWithFrame:fRect];
            // #endif

            [view setDocument:newDocument];
            newDocument->magazineIndex = [plist intForKey:@"MagazineIndex"];
            [newDocument->scrollView setDocumentView:view];
            [view release];
            [newDocument->scrollView setDocument:newDocument];
            [newDocument setName:fileDirectory ? fileDirectory : fileName];	// needed to load VImage
            [[NSNotificationCenter defaultCenter] postNotificationName:DocWindowDidChange
                                                                object:newDocument];    // moved from before -setDocumentView: to here
            [newDocument->window setDocument:newDocument];
            [newDocument->window makeFirstResponder:view];
            if ( [[plist objectForKey:@"Data"] isKindOfClass:[NSDictionary class]] )
                [view initFromPropertyList:[plist objectForKey:@"Data"] inDirectory:fileDirectory];
            else
                [view initWithCoder:[[[NSUnarchiver alloc] initForReadingWithData:[plist objectForKey:@"Data"]] autorelease]];

            if ( [plist objectForKey:@"Output"] )	// old
                [view setAllLayerDirty:YES];
            else if ( [view respondsToSelector:@selector(readOutputFromPropertyList:)] )
            {   NSDictionary	*plist = [NSDictionary dictionaryWithContentsOfFile:outputFile];

                if ( ![plist objectForKey:@"Output"] && plist )
                {
                    NS_DURING
                        [view performSelector:@selector(readOutputFromPropertyList:) withObject:plist];
                    NS_HANDLER
                        NSLog(@"Unknown Output Data - ignoring!");
                        [view setAllLayerDirty:YES];
                    NS_ENDHANDLER
                }
                else
                {   [view setAllLayerDirty:YES];
                    [newDocument setDirty:NO];	// only layers are dirty to calculate output, not the document
                }
            }

            [newDocument resetScrollers];	// ???
            if ([view caching])
                [view draw:NSZeroRect];

            /* workaround: something doesn't work with size>10000.0, so we set it here */
            fRect = rectFromPropertyList([plist objectForKey:@"ViewSize"]);
            [view setFrameSize:fRect.size];

            if ( [plist objectForKey:@"hasCoordBox"] && [plist intForKey:@"hasCoordBox"] == 0 )
                [newDocument->window enableCoordDisplay:NO];
            [newDocument->window makeKeyAndOrderFront:newDocument];
            [newDocument->window makeFirstResponder:view];	// removed by makeKeyAndOrderFront !
            [newDocument->window setMiniwindowImage:[NSImage imageNamed:@"typeCenon"]];

            newDocument->haveSavedDocument = YES;

            [[NSNotificationCenter defaultCenter] postNotificationName:DocumentDidOpen
                                                                object:view];
        }
        else
            NSRunAlertPanel(OPEN_TITLE, OPEN_ERROR, nil, nil, nil, fileName);
    }

    return newDocument;
}

+ (NSMutableArray*)listFromFile:(NSString*)fileName
{   NSMutableArray	*gList = [NSMutableArray array];
    NSDictionary	*plist = nil;
    NSString		*fileDirectory = nil;
    NSFileManager	*fileManager = [NSFileManager defaultManager];
    BOOL            isDirectory = NO;
    NSArray         *layerList;
    int             l, lCnt;

    if ([fileManager fileExistsAtPath:fileName isDirectory:&isDirectory])
    {
        if (isDirectory)
        {
            fileDirectory = fileName;
            fileName = [fileName stringByAppendingPathComponent:DOCUMENT_NAME];
        }
        else if ([[fileName lastPathComponent] isEqual:DOCUMENT_NAME])
        {
            fileDirectory = [fileName stringByDeletingLastPathComponent];
            if (![[fileDirectory pathExtension] isEqual:DOCUMENT_EXT])
                fileDirectory = nil;
        }
        if ([fileManager isReadableFileAtPath:fileName])
        {
            plist = [NSDictionary dictionaryWithContentsOfFile:fileName];
            if ( [[plist objectForKey:@"Data"] isKindOfClass:[NSDictionary class]] )
                layerList = [DocView readList:[plist objectForKey:@"Data"] inDirectory:fileDirectory];
            else
                layerList = [DocView readList:[[[NSUnarchiver alloc] initForReadingWithData:[plist objectForKey:@"Data"]] autorelease] inDirectory:fileDirectory];

            for (l=0, lCnt = [layerList count]; l<lCnt; l++)
                [gList addObjectsFromArray:[[layerList objectAtIndex:l] list]];
        }
        else
            NSRunAlertPanel(OPEN_TITLE, OPEN_ERROR, nil, nil, nil, fileName);
    }

    return gList;
}

/*
 * Creates a new document from what is in the passed stream.
 * modified: 2008-07-19 (-init allocated document)
 */
+ newFromList:(NSMutableArray*)list
{   NSRect          frameRect, fRect;
    DocView         *view;
    TileScrollView  *sView;
    DocWindow       *win;
    Document        *newDocument;

    newDocument = [[super allocWithZone:[self newZone]] init];
    if (![NSBundle loadModelNamed:@"Document" owner:newDocument])
    {	NSLog(@"Cannot load Document model");	
        [newDocument release];
        return nil;
    }

    [(App*)NSApp setCurrentDocument:newDocument];
    [newDocument setName:nil andDirectory:nil];

    win = [newDocument window];
    sView = [newDocument scrollView];

    [win setDelegate:newDocument];
    [sView setHasHorizontalScroller:YES];
    [sView setHasVerticalScroller:YES];

    /* Put the window offset from the previous document window... If no
     * previous window exists, or the main window is undetermined, then
     */
    if ([NSApp mainWindow])
    {	NSRect	winFrame, winLoc;

        winFrame = [[NSApp mainWindow] frame];
        winLoc = [[win class] contentRectForFrameRect:winFrame styleMask:[win styleMask]];
        [win setFrameOrigin:NSMakePoint(NSMinX(winLoc) + XOFFSET, NSMinY(winLoc) + YOFFSET)];
    }

    /* print info */
    //newDocument->printInfo = [[NSPrintInfo allocWithZone:[newDocument zone]] init];
    [newDocument initializePrintInfo];

    /* calculate size of view */
    frameRect = [DocView boundsOfArray:list];	/* get bounds of list */
    frameRect.size.width  += frameRect.origin.x + MMToInternal(20.0);
    frameRect.size.height += frameRect.origin.y + MMToInternal(20.0);
    frameRect.origin.x = 0.0;
    frameRect.origin.y = 0.0;

    /* workaround: something doesn't work with size > 10000.0 */
    // #if VHF_IS_DOUBLE == 0
    fRect = frameRect;
    if ( fRect.size.width > 10000.0 )
        fRect.size.width = 10000.0;
    if ( fRect.size.height > 10000.0 )
        fRect.size.height = 10000.0;
    // #endif

    /* set view */
    view = [[[DocView allocWithZone:[newDocument zone]] initWithFrame:fRect] initView];
    [view setDocument:newDocument];
    [view setList:list];
    [sView setDocument:newDocument];
    [sView setDocumentView:view];
    [view release];

    [win makeFirstResponder:view];
    [win setDocument:newDocument];
    if ([[newDocument documentView] caching])
        [[newDocument documentView] draw:NSZeroRect];

    /* workaround: something doesn't work with size>10000.0, so we set it here */
    [view setFrameSize:frameRect.size];

    [win makeKeyAndOrderFront:newDocument];
    [win makeFirstResponder:view];	// removed by makeKeyAndOrderFront !
    [win setMiniwindowImage:[NSImage imageNamed:@"typeCenon"]];

    return newDocument;
}

/* created:  1992
 * modified: 2002-07-15
 */
- (void)initializePrintInfo
{
    if ( !printInfo )
    {
        printInfo = [[NSPrintInfo sharedPrintInfo] copy];
        //printInfo = [[NSPrintInfo allocWithZone:[self zone]] init];

        //[printInfo setVerticallyCentered:NO];
        //[printInfo setHorizontallyCentered:NO];
        //[printInfo setHorizontalPagination:NSFitPagination];

        [printInfo setLeftMargin:0.0];
        [printInfo setRightMargin:0.0];
        [printInfo setTopMargin:0.0];
        [printInfo setBottomMargin:0.0];
        [printInfo setHorizontalPagination:NSAutoPagination];
        [printInfo setVerticalPagination:NSAutoPagination];

        [printInfo setPaperName:@"A4"];
    }
}

#if 0
- (BOOL)setWindowSize:(NSSize)size
{   NSRect	winFrame, frame;
    NSSize	desSize;

    frame = [scrollView frame];

    desSize = size;

    /* we set a limit for the maximum size of the window */
    if (desSize.width > MAXWINWIDTH)
        desSize.width = MAXWINWIDTH;
    if (desSize.height > MAXWINHEIGHT)
        desSize.height = MAXWINHEIGHT;
    // we have to add attention to the minimum size of the window
    //	if (desSize.width > winFrame.size.width)
    winFrame.size.width  = desSize.width;
    //	if (desSize.height > winFrame.size.height)
    winFrame.size.height = desSize.height;

    /* resize window to the given or maximum size, add scrollers to window size */
    desSize = [TileScrollView frameSizeForContentSize:winFrame.size hasHorizontalScroller:YES hasVerticalScroller:YES borderType:NSNoBorder];
    [window setContentSize:desSize];
    if (desSize.width!=frame.size.width || desSize.height!=frame.size.height)
        return YES;

    return NO;
}

- (void)sizeWindow:(NSSize)size
{   NSRect	oldFrame, frame;
    NSPoint	p = {0, 0};
    id		view = [scrollView documentView];

    oldFrame = [view frame];

    [window disableFlushWindow];

    //	[view disableDisplay:YES];
    [view scrollPoint:p];

    /* set window size
        */
    frame.size = size;

    /* resize doc view and cache window
     * size view relative (old size * old resolution / new resolution)
     */
    [view setFrameSize:NSMakeSize(NSWidth(frame), NSHeight(frame))];	// resize view

    [window enableFlushWindow];	// resize view

    [window flushWindow];
    [self setWindowSize:(frame.size)];
    //	[view disableDisplay:NO];
    if ([view cache])
        [view draw:NSZeroRect];
    [window display];
}
#endif

- (void)scale:(float)x :(float)y withCenter:(NSPoint)center
{
    NSLog(@"[document scale:x :y ...] is deprecated, use [document scale:NSSize ...");
    [self scale:NSMakeSize(x, y) withCenter:center];
}
- (void)scale:(NSSize)scaleSize withCenter:(NSPoint)center
{   NSPoint	p = {0, 0};
    DocView	*view = [scrollView documentView];
    NSRect	oldFrame = [view frame], bRect;

    /* scale doc view and cache window */
    [view scaleUnitSquareToSize:scaleSize];

    [window disableFlushWindow];

    /* resize doc view and cache window (old size * scaleFactor) */
    [view setFrameSize:NSMakeSize(NSWidth(oldFrame)*scaleSize.width, NSHeight(oldFrame)*scaleSize.height)];	// resize

    oldFrame = [window frame];
    oldFrame = [view convertRect:oldFrame fromView:nil];
    bRect = [view bounds];
    p = center;
    if ((p.x -= oldFrame.size.width /2.0) < 0.0) p.x = 0.0;
    if ((p.y -= oldFrame.size.height/2.0) < 0.0) p.y = 0.0;
    if (p.x > bRect.size.width  - oldFrame.size.width)  p.x = bRect.size.width  - oldFrame.size.width;
    if (p.y > bRect.size.height - oldFrame.size.height) p.y = bRect.size.height - oldFrame.size.height;
    [view scrollPoint:p];

    [window enableFlushWindow];
    //[window flushWindow];

    if ([view cache])
        [view draw:NSZeroRect];
    [window display];
}

- window
{
    return window;
}

- (void)resetScrollers
/*
 * Checks to see if the new window size is too large.
 * Called whenever the page layout (either by user action or
 * by the opening or reverting of a file) is changed or
 * the user resizes the window.
 */
{
    NSSize		contentSize;
    NSRect		contentRect, windowFrame;

    if (window)
    {
	windowFrame = [window frame];
	contentRect = [[window class] contentRectForFrameRect:windowFrame styleMask:[window styleMask]];
	contentSize = [scrollView frame].size;
        contentSize.height += 36.0;	// height of coordinate display !! get this from Document.nib

	if (contentRect.size.width >= contentSize.width || contentRect.size.height >= contentSize.height)
        {
	    contentSize.width = MIN(contentRect.size.width, contentSize.width);
	    contentSize.height = MIN(contentRect.size.height, contentSize.height);
	    [window setContentSize:(NSSize){contentSize.width, contentSize.height}];
	}
    } 
}

- (TileScrollView*)scrollView
{
    return scrollView;
}

- (DocView*)documentView
{
    return [scrollView documentView];
}


- (void)setDirty:(BOOL)flag
{
    dirty = flag;
    [window setDocumentEdited:flag]; 
}
- (BOOL)dirty
{
    return dirty;
}

- (void)setExportLock:(BOOL)flag
{
    exportLock = flag;
}
- (BOOL)exportLock
{
    return exportLock;
}

/* Services menu registrar */
- (void)registerForServicesMenu
{
    static BOOL registered = NO;
    NSArray *validSendTypes = [[NSArray array] initWithObjects:NSFilenamesPboardType, nil];

    if (!registered)
    {
	registered = YES;
	[NSApp registerServicesMenuSendTypes:validSendTypes returnTypes:nil];
    } 
}
- (id)validRequestorForSendType:(NSString *)sendType returnType:(NSString *)returnType
/*
 * Services menu support.
 * We are a valid requestor if the send type is filename
 * and there is no return data from the request.
 */
{
    return (haveSavedDocument && [sendType isEqual:NSFilenamesPboardType] && (!returnType || [returnType isEqual:@""])) ? self : nil;
}
- (BOOL)writeSelectionToPasteboard:(NSPasteboard *)pboard types:(NSArray *)types;
/*
 * Services menu support.
 * Here we are asked by the Services menu mechanism to supply
 * the filename (which we said we were a valid requestor for
 * in the above method).
 */
{
    return NO;
}


/*
 * Document info
 */
- (void)setDocVersion:(NSString*)newVersion
{
    [docVersion release];
    docVersion = [newVersion retain];
    [self setDirty:YES];
}
- (NSString*)docVersion     { return docVersion; }
- (void)setDocAuthor:(NSString*)newAuthor
{
    [docAuthor release];
    docAuthor = [newAuthor retain];
    [self setDirty:YES];
}
- (NSString*)docAuthor      { return docAuthor; }
- (void)setDocCopyright:(NSString*)newCopyright
{
    [docCopyright release];
    docCopyright = [newCopyright retain];
    [self setDirty:YES];
}
- (NSString*)docCopyright   { return docCopyright; }
- (void)setDocComment:(NSString*)newComment
{
    [docComment release];
    docComment = [newComment copy];
    [self setDirty:YES];
}
- (NSString*)docComment     { return docComment; }

/* Document setting
 * created:  2008-07-19
 * modified: 2008-07-24
 */
- (NSMutableDictionary*)docSettingsDict
{
    if (!docSettingsDict)
        docSettingsDict = [[NSMutableDictionary dictionary] retain];
    return docSettingsDict;
}
- (void)setBaseUnit:(CenonUnit)unit { baseUnit = unit; }
- (CenonUnit)baseUnitFlat           { return baseUnit; }
- (CenonUnit)baseUnit
{   NSUserDefaults  *defaults = [NSUserDefaults standardUserDefaults];
    return (baseUnit == UNIT_NONE) ? [defaults integerForKey:@"unit"] : baseUnit;
}
- (float)convertToUnit:(float)iValue
{   NSUserDefaults  *defaults = [NSUserDefaults standardUserDefaults];
    CenonUnit       unit = (baseUnit == UNIT_NONE) ? [defaults integerForKey:@"unit"] : baseUnit;

    switch ( unit )
    {
        case UNIT_MM:		return (iValue * 25.4/72.0);
        case UNIT_INCH:		return (iValue / 72.0);
        default:
        case UNIT_POINT:	return iValue;
    }
    return iValue;
}
- (float)convertFrUnit:(float)uValue
{   NSUserDefaults  *defaults = [NSUserDefaults standardUserDefaults];
    CenonUnit       unit = (baseUnit == UNIT_NONE) ? [defaults integerForKey:@"unit"] : baseUnit;

    switch ( unit )
    {
        case UNIT_MM:		return (uValue / 25.4*72.0);
        case UNIT_INCH:		return (uValue * 72.0);
        default:
        case UNIT_POINT:	return uValue;
    }
    return uValue;
}
- (float)convertMMToUnit:(float)mmValue
{   NSUserDefaults  *defaults = [NSUserDefaults standardUserDefaults];
    CenonUnit       unit = (baseUnit == UNIT_NONE) ? [defaults integerForKey:@"unit"] : baseUnit;

    switch ( unit )
    {
        default:
        case UNIT_MM:		return mmValue;
        case UNIT_INCH:		return mmValue / 25.4;
        case UNIT_POINT:	return mmValue * 72.0/25.4;
    }
    return mmValue;
}
- (float)convertUnitToMM:(float)uValue
{   NSUserDefaults  *defaults = [NSUserDefaults standardUserDefaults];
    CenonUnit       unit = (baseUnit == UNIT_NONE) ? [defaults integerForKey:@"unit"] : baseUnit;

    switch ( unit )
    {
        default:
        case UNIT_MM:		return uValue;
        case UNIT_INCH:		return uValue * 25.4;
        case UNIT_POINT:	return uValue / 72.0*25.4;
    }
    return uValue;
}


/*
 * Methods related to naming/saving/loading this document.
 */

/*
 * Gets the fully specified file name of the document.
 * If directory is NULL, then the currentDirectory is used.
 * If name is NULL, then the default title is used.
 * ???kb NSString - This now returns an autorelease... I tried to fix up
 * all users of this, but it may kill something!
 */
- (NSString*)filename
{   NSString	*returnString = @"";

    if (!directory && !name)
        [self setName:nil andDirectory:nil];
    if (name)
        returnString = [directory stringByAppendingPathComponent:name];
    return returnString;
}
- (NSString*)directory
{
    return directory;
}
- (NSString*)name
{
    return name;
}

/*
 * Updates the name and directory of the document.
 * newName or newDirectory can be nil, in which case the name or directory
 * will not be changed (unless one is currently not set, in which case
 * a default name will be used).
 */
- (void)setName:(NSString*)newName andDirectory:(NSString*)newDirectory
{   static int	untitledCount = 0;
    NSString	*fileName;

    if ((newName && [newName length]) || !name)
    {
        if (!newName || ![newName length])
        {
            newName = UNTITLED_STRING;
            if (untitledCount)
                newName = [newName stringByAppendingFormat:@"%d", untitledCount];
            untitledCount++;
        }
        if (![newName isEqual:name])
        {
            [name autorelease];
            name = [newName copyWithZone:(NSZone*)[self zone]];
        }
    }

    if ((newDirectory && [newDirectory length]) || !directory)
    {
        if (!newDirectory || ![newDirectory length])
            newDirectory = [(App*)NSApp currentDirectory];
        if (![newDirectory isEqual:directory])
        {
            [directory autorelease];
            directory = [newDirectory copyWithZone:(NSZone*)[self zone]];
        }
    }

    if (!name)
        NSLog(@"-setName: name == nil, newName = '%@'", newName);
    if (!directory)
        NSLog(@"-setName: directory == nil, newDirectory = '%@'", newDirectory);

    if ( (fileName = [self filename]) )
    {
        [window setTitleWithRepresentedFilename:fileName];
        [window setMiniwindowTitle:fileName];
#ifdef __APPLE__    // well, he! the are lazy developers at Apple, the above works two times then never again
        [window setTitle:name];
#endif
        NSSetZoneName((NSZone*)[self zone], fileName);
    }
}

/*
 * If file is a full path name, then both the name and directory of the
 * document is updated appropriately, otherwise, only the name is changed.
 */
- (BOOL)setName:(NSString *)file
{
    if (file)
    {	NSString *lastComponent = [file lastPathComponent];

        if (![lastComponent isEqual:@""])
        {
            [self setName:lastComponent andDirectory:[file stringByDeletingLastPathComponent]];
            return YES;
        }
        else
        {
            [self setName:file andDirectory:nil];
            return YES;
        }
    }

    return NO;
}

- (void)setTemporaryTitle:(NSString *)title
{
    [window setTitle:title];
    haveSavedDocument = NO;
    [self setName:title andDirectory:NSHomeDirectory()];
}

- (void)setFontObject:(Type1Font*)fontObj
{   NSMutableArray	*array[4], *list;
    int			i, l;
    NSColor		*green = [NSColor greenColor], *yellow = [NSColor yellowColor],
                        *gray = [NSColor grayColor];
    NSRect		bounds;

    fontObject = [fontObj retain];

    for (i=0; i<4; i++)
        array[i] = [NSMutableArray array];

    list = [fontObject fontList];

    /* colors to arrays */
    for ( i=[list count]-1; i>=0; i-- )
    {   id	obj = [list objectAtIndex:i];
        NSColor	*objColor = [obj color];

        if ([objColor isEqual:gray] )
            [array[0] addObject:obj];
        else if ([objColor isEqual:yellow] )
            [array[1] addObject:obj];
        else if ([objColor isEqual:green] )
            [array[2] addObject:obj];
        else
            [array[3] addObject:obj];
    }

    /* create layer */
    for (l=1; l<=4; l++)
    {   NSString	*layerName = nil;
        BOOL		editable = NO;

        switch (l)
        {
            case FONTTAG_GRID:        layerName = @"Font Grid";   editable = NO;  break;
            case FONTTAG_STEM:        layerName = @"Stems";       editable = YES; break;
            case FONTTAG_SIDEBEARING: layerName = @"Sidebearing"; editable = YES; break;
            case FONTTAG_FONT:        layerName = @"Font";        editable = YES; break;
            default: NSLog(@"Document, -setFontObject: FONTTAG out of range !");
        }
        [[self documentView] addLayerWithName:layerName type:LAYER_STANDARD tag:l list:array[l-1] editable:editable];
    }

    /* resize view to font */
    bounds = [[self documentView] boundsOfArray:array[0]];
    [[self documentView] setFrameSize:
        NSMakeSize(bounds.origin.x+bounds.size.width, bounds.origin.y+bounds.size.height)];

    /* move crosshairs to 0/0 */
    [[[self documentView] origin] movePoint:0 to:NSMakePoint(0.0, 0.0)];

    /* set font */
    //[(App*)NSApp setSaveType:FONT_EXT];

    /* switch unit to pt */

    /* set grid to 10 pt */

    /* cacheable at 100% */

    [[self documentView] drawAndDisplay];
}


#if 0
- (BOOL)saveToTIFFFile:(NSString *)file
{
    if (![[file pathExtension] isEqualToString:@"tiff"]) file = [file stringByAppendingPathExtension:@"tiff"];
    return [self saveTo:file using:@selector(dataForTIFF)];
}

- (BOOL)saveToEPSFile:(NSString *)file
{
    if (![[file pathExtension] isEqualToString:@"eps"]) file = [file stringByAppendingPathExtension:@"eps"];
    return [self saveTo:file using:@selector(dataForEPS)];
}
#endif

/*
 * Writes out the document in 4 steps:
 *
 * 1. write in temporary file (#fileName.cenon)
 * 2. remove backup (fileName.cenon~)
 * 3. move file name (old) file to backup (fileName.cenon -> fileName.cenon~)
 * 4. move temporary file to file name (#fileName.cenon -> fileName.cenon)
 *
 * modified: 2007-07-24 (save baseUnit and project settings)
 */
- (BOOL)save
{   BOOL                savedOk = NO;
    NSString            *filename = [self filename];
    NSString            *backupFilename = [filename stringByAppendingString:@"~"];
    //NSString          *tmpFilename = [@"#" stringByAppendingString:filename];
    NSString            *fileDirectory = nil;
    NSFileManager       *fileManager = [NSFileManager defaultManager];
    NSMutableDictionary *fileContents;
    BOOL                isDirectory = YES;
    NSAutoreleasePool   *pool;

    /* file not writable */
    if ( [fileManager fileExistsAtPath:filename] && ![fileManager isWritableFileAtPath:filename] )
    {   NSRunAlertPanel(SAVE_TITLE, CANT_CREATE_BACKUP, nil, nil, nil);
        return NO;
    }
    /* rename to backup */
    if ( ([fileManager fileExistsAtPath:backupFilename] && ![fileManager removeFileAtPath:backupFilename handler:nil]) || ([fileManager fileExistsAtPath:filename] && ![fileManager movePath:filename toPath:backupFilename handler:nil]) )
    {   NSRunAlertPanel(SAVE_TITLE, CANT_CREATE_BACKUP, nil, nil, nil);
        return NO;
    }
    /* create file directory */
    else if ( isDirectory && [fileManager createDirectoryAtPath:filename attributes:nil] )
    {
        fileDirectory = filename;
        filename = [fileDirectory stringByAppendingPathComponent:DOCUMENT_NAME];
    }

    pool = [NSAutoreleasePool new];
    /* save */
    if ([fileManager isWritableFileAtPath:fileDirectory])
    {   NSArchiver	*archiver;

        NS_DURING
            [window makeFirstResponder:[self documentView]];
            fileContents = [NSMutableDictionary dictionaryWithCapacity:7];
            [fileContents setObject:[NSString stringWithFormat:@"%d", DOCUMENT_VERSION] forKey:@"Version"];
            [fileContents setObject:propertyListFromNSPrintInfo(printInfo) forKey:@"PrintInfo"];
            [fileContents setObject:[window stringWithSavedFrame] forKey:@"WindowFrame"];
#ifdef __APPLE__    // needed, if a folded window is saved, to restore the window frame
            if ( [window isFolded] )
                [fileContents setObject:propertyListFromFloat([window unfoldedHeight])
                                 forKey:@"WindowUnfoldedHeight"];
#endif
            [fileContents setObject:propertyListFromNSRect([[self documentView] bounds]) forKey:@"ViewSize"];
            [fileContents setInt:[window hasCoordDisplay] forKey:@"hasCoordBox"];
            [fileContents setInt:magazineIndex forKey:@"MagazineIndex"];
            //[fileContents setObject:propertyListFromInt([VGraphic currentGraphicIdentifier]) forKey:@"GraphicIdentifier"];
            [fileContents setObject:@"Cenon" forKey:@"Creator"];
            [fileContents setObject:[[NSCalendarDate date] descriptionWithCalendarFormat:@"%Y-%m-%d %H:%M"] forKey:@"CreationDate"];
            /* Project Info */
            if (docVersion)
                [fileContents setObject:docVersion      forKey:@"DocVersion"];
            if (docAuthor)
                [fileContents setObject:docAuthor       forKey:@"Author"];
            if (docCopyright)
                [fileContents setObject:docCopyright    forKey:@"Copyright"];
            if (docComment)
                [fileContents setObject:docComment      forKey:@"Comment"];
            if (exportLock)
                [fileContents setObject:@"Y"            forKey:@"exportLock"];
            /* Project Settings */
            if (baseUnit != -1)
                [fileContents setObject:[NSString stringWithFormat:@"%d", baseUnit] forKey:@"Unit"];
            if (docSettingsDict)
                [fileContents setObject:docSettingsDict forKey:@"DocSettings"];

            if ( DOCUMENT_VERSION >= 101 )
                [fileContents setObject:[[self documentView] propertyList] forKey:@"Data"];
            else
            {   archiver = [[[NSArchiver alloc] initForWritingWithMutableData:[NSMutableData data]] autorelease];
                [[self documentView] encodeWithCoder:archiver];
                [fileContents setObject:[archiver archiverData] forKey:@"Data"];
            }

#ifdef __APPLE__
            /* ASCII PropertyList... it just doesn't work on Mac OS X,
             * so we use the class from the GNUstep project so long
             */
            if ( Prefs_OSPropertyList ) // ASCII PropertyList (best human readable, half the size of XML)
            {
                if ( [NSPropertyListSerialization propertyList:fileContents
                                              isValidForFormat:NSPropertyListOpenStepFormat] )
                {   NSData      *data;
                    NSString    *error = nil;
                    //NSDictionary *testplist = [NSDictionary dictionary];  // not even this works!

                    data = [NSPropertyListSerialization dataFromPropertyList:fileContents
                                                                      format:NSPropertyListOpenStepFormat
                                                            errorDescription:&error];
                    if (error)
                        { NSLog(@"%@", error); [error release]; }
                    savedOk = [data writeToFile:filename atomically:YES];

                    /* Apple stuff doesn't work:
                    if ([NSPropertyListSerialization propertyList:testplist
                                                isValidForFormat:NSPropertyListOpenStepFormat])
                        NSLog(@"valid for ASCII");
                    if ([NSPropertyListSerialization propertyList:testplist
                                                 isValidForFormat:NSPropertyListXMLFormat_v1_0])
                        NSLog(@"valid for XML");
                    data = [NSPropertyListSerialization dataFromPropertyList:testplist
                                                                      format:NSPropertyListOpenStepFormat
                                                            errorDescription:&error];
                    [data writeToFile:@"/Users/georg/Tempo/test.plist" atomically:YES];*/
                }
                else
                {   NSData      *data;
                    NSString    *error = nil;

                    data = [GSPropertyListSerialization dataFromPropertyList:fileContents
                                                                      format:NSPropertyListOpenStepFormat
                                                            errorDescription:&error];
                    if (error)
                    { NSLog(@"%@", error); [error release]; }
                    savedOk = [data writeToFile:filename atomically:YES];
                }
            }
            else	// use native PropertyList format
#endif
            /* FIXME: converting dictionary to string needs a lot lot of memory !! */
            savedOk = [fileContents writeToFile:filename atomically:YES];
            haveSavedDocument = savedOk;

            if ( fileDirectory && savedOk )
            {
                [[self documentView] allowGraphicsToWriteFilesIntoDirectory:fileDirectory];
                [[NSNotificationCenter defaultCenter] postNotificationName:DocumentHasBeenSaved
                                                                    object:self
                                                      userInfo:[NSDictionary dictionaryWithObject:fileDirectory
                                                                                           forKey:@"file"]];
            }
        NS_HANDLER
            NSLog(@"Save: %@", [localException reason]);
            savedOk = NO;
        NS_ENDHANDLER
    }
    else
        NSRunAlertPanel(SAVE_TITLE, DIR_NOT_WRITABLE, nil, nil, nil);

    /* restore backup */
    if (!savedOk)
    {
        [fileManager removeFileAtPath:fileDirectory handler:nil];	// remove what we just started to write
        [fileManager movePath:backupFilename toPath:fileDirectory handler:nil];	// restore backup
        NSRunAlertPanel(SAVE_TITLE, CANT_SAVE, nil, nil, nil);
    }
    else
    {
        if (Prefs_RemoveBackups)
            [fileManager removeFileAtPath:backupFilename handler:nil];
        [self setDirty:NO];
    }
    [pool release];
    return YES;
}

/*
 * Saves the file.  If this document has never been saved to disk,
 * then a SavePanel is put up to ask the user what file name she
 * wishes to use to save the document.
 */
- (BOOL)save:(id <NSMenuItem>)invokingMenuItem
{
    if (haveSavedDocument)
        [self save];
    else
        return [self saveAs:invokingMenuItem];
    return YES;
}

/* save or export
 * return: YES = saved succesfully
 *         NO  = save failed or just exporded
 */
- (BOOL)saveAs:(id <NSMenuItem>)invokingMenuItem
{   NSSavePanel *savepanel = [(App*)NSApp saveAsPanel];

    /* set special file type */
    if (fontObject)
        savepanel = [(App*)NSApp saveAsPanelWithSaveType:FONT_EXT];

    if ([savepanel runModalForDirectory:directory file:[name stringByDeletingPathExtension]])
    {   NSString *path = [savepanel filename];

        if ([[path pathExtension] isEqual:DOCUMENT_EXT])
        {   [self setName:path];
            return [self save];
        }
        if ( exportLock )   // this file is not supposed to be exported
        {
            NSRunAlertPanel(SAVE_TITLE, EXPORTLOCK_STRING, nil, nil, nil);
            return NO;
        }
        if ([[path pathExtension] isEqual:EPS_EXT])
            [self saveEPS:path];
        else if ([[path pathExtension] isEqual:GERBER_EXT])
            [self saveGerber:path];
        else if ([[path pathExtension] isEqual:HPGL_EXT])
            [self saveHPGL:path];
        else if ([[path pathExtension] isEqual:DXF_EXT])
            [self saveDXF:path];
        else if ([[path pathExtension] isEqual:FONT_EXT])
            [self saveFont:path];
        else if ([[path pathExtension] isEqual:TIFF_EXT])
            [self saveTiff:path];
    }

    return NO;
}

- (BOOL)saveEPS:(NSString*)filename
{   EPSExport	*epsExport = [EPSExport epsExport];

    [epsExport setDocumentView:[self documentView]];
    return [epsExport writeToFile:filename];
}
- (BOOL)saveGerber:(NSString*)filename
{   GerberExportSub	*gerberExport = [[GerberExportSub allocWithZone:[self zone]] init]; // get new export-object

    [gerberExport setDocumentView:[self documentView]];
    return [gerberExport exportToFile:filename];
}
- (BOOL)saveHPGL:(NSString*)filename
{   HPGLExportSub	*hpglExport = [[HPGLExportSub allocWithZone:[self zone]] init]; // get new export-object

    [hpglExport setDocumentView:[self documentView]];
    return [hpglExport exportToFile:filename];
}
- (BOOL)saveDXF:(NSString*)filename
{   DXFExportSub	*dxfExport = [[DXFExportSub allocWithZone:[self zone]] init]; // get new export-object

    [dxfExport setDocumentView:[self documentView]];
    return [dxfExport exportToFile:filename];
}

- (BOOL)saveFont:(NSString*)filename
{   //NSString		*filename = [self filename];
    NSMutableArray	*layerList, *fList;
    int			i, index = 0;
    BOOL		savedOk = NO;

    if ( !fontObject )
    {   NSRunAlertPanel(SAVE_TITLE, @"No Font Object ! File not saved", nil, nil, nil);
        return NO;
    }

    /* get all lists from view but (clip, fontGrid, charset, baseline)
     * put in one list -> our new font List
     */
    fList = [NSMutableArray array];
    layerList = [[self documentView] layerList];
    index = 0;
    for (i=(int)[layerList count]-1 ; i >=0  ; i--)
    {   LayerObject	*lObj = [layerList objectAtIndex:i];

        if ( [lObj tag] == FONTTAG_SIDEBEARING || [lObj tag] == FONTTAG_STEM || [lObj tag] == FONTTAG_FONT)
        {   int	j, cnt = [[lObj list] count];

            for (j=0; j<cnt; j++)
            {   id	g = [[lObj list] objectAtIndex:j];

                [g setSelected:NO];
                //[g setColor:green];
                if ([g isKindOfClass:[VPath class]])	/* we dont want a path inside a path ! */
                    [fList insertObject:[g copy] atIndex:index++]; // must copy path list
                else
                    [fList insertObject:g atIndex:index++];
            }
        }
    }
    [fontObject setFontList:fList];
    [fontObject update];

    savedOk = [fontObject writeToFile:filename];
    if (savedOk)
        [self setDirty:NO];
    return savedOk;
}

/* created:  2010-06-29
   modified: 2010-11-26
 */
- (BOOL)saveTiff:(NSString*)filename
{   NSArray             *layerList = [[self documentView] layerList];
    NSRect              conRect, rect, bbox = NSZeroRect;
    NSBitmapImageRep	*bitmapImage;
    NSImage             *img = nil;
    NSData              *tdata = nil;
    id                  win = nil, conView = nil;

    /* only all visible Layers */
    {   int	l, cnt = [layerList count];

        for (l=0; l<cnt; l++)
        {	LayerObject	*layerObject = [layerList objectAtIndex:l];

            if ( [layerObject state] ) // visible
                bbox = NSUnionRect([[self documentView] boundsOfArray:[layerObject list]], bbox);
        }
    }

    conRect.origin.x = conRect.origin.y = 10.0;
    conRect.size.width = bbox.size.width;
    conRect.size.height = bbox.size.height;

    rect.origin = NSZeroPoint;
    rect.size.width = (int)(conRect.size.width);
    rect.size.height = (int)(conRect.size.height);

    /* build an offscreen window
     * in which we draw the scaled black copy of original path on white background NSBackingStoreBuffered NSBackingStoreRetained
     */
    win = [[NSWindow alloc] initWithContentRect:conRect styleMask:NSBorderlessWindowMask backing:NSBackingStoreRetained defer:NO];
    [win setDepthLimit:NSBestDepth(NSCalibratedWhiteColorSpace, 8, 8, YES, NULL)];

    [win setBackgroundColor:[NSColor whiteColor]];
#if DEBUG_TIFFEXPORT
    [win makeKeyAndOrderFront:self]; /* weglassen wenn nicht gesehen werden soll */
#endif
    conView = [win contentView];
    [conView display];

    /* now draw our black scaled path in view
     */
    [conView lockFocus];

#ifdef __APPLE__
    /* draw color shading without antialiasing */
    [[NSGraphicsContext currentContext] setShouldAntialias:Prefs_Antialias];
#endif

    /* draw all visible Layers */
    {   int     l, cnt = [layerList count];
        NSPoint movePt = NSMakePoint(-bbox.origin.x, -bbox.origin.y);
        NSPoint moveBackPt = bbox.origin; // NSMakePoint(-bbox.origin.x, -bbox.origin.y);

        for (l=0; l<cnt; l++)
        {	LayerObject	*layerObject = [layerList objectAtIndex:l];

            if ( [layerObject state] ) // visible                
            {   NSMutableArray	*llist = [layerObject list];
                int i, lcnt = [llist count];

                for (i=0; i<lcnt; i++)
                {   VGraphic    *gr = [llist objectAtIndex:i];

                    [gr moveBy:movePt];
                    [gr drawWithPrincipal:nil/*[self documentView]*/]; // nil because our view don't answer to mustDrawPale
                    [gr moveBy:moveBackPt];
                }
            }
        }
    }

    /* get pixel information into data (char string) */

    bitmapImage = [[NSBitmapImageRep allocWithZone:[self zone]] initWithFocusedViewRect:rect];

    /* generate Image from bitmapRep */
    img = [[NSImage alloc] initWithSize:rect.size];
    [img addRepresentation:bitmapImage];

    /* save image */
    if ( (tdata = [img TIFFRepresentation]) )
    {   [tdata writeToFile:filename atomically:YES];
        return YES;
    }

    [conView unlockFocus];
    [win close];

    [img release];
    [bitmapImage release];
    return NO;
}
#if 0
/*{   NSPasteboard	*pb = [NSPasteboard pasteboardWithName:@"pasteboard"];
    NSImage         *img;
    NSData          *tdata = nil;
    NSRect          bbox;

    bbox = [[self documentView] boundsOfArray:[[self documentView] layerList]];

    [[self documentView] writeEPSInsideRect:bbox toPasteboard:pb]; // did not work (antialiased and no white)
    img = [[NSImage alloc] initWithPasteboard:pb];
    if ( (tdata = [img TIFFRepresentation]) )
    {   [tdata writeToFile:filename atomically:YES];
        return YES;
    }
    [img release];
    [pb releaseGlobally];
    return NO;
}*/
#endif

- (void)printSeparation:(NSPrintOperation*)op
{   NSColor             *sepColor;
    NSPrintOperation    *sop=nil;
    NSPrintInfo         *pi = [op printInfo], *spi;
    NSMutableDictionary *piDict = [pi dictionary];
    NSAutoreleasePool   *pool0 = [NSAutoreleasePool new], *pool;
    NSString            *cropPath;
    NSString            *pStr=nil, *npStr=nil, *pExt=nil, *mStr, *paperName = [pi paperName];
    NSMutableArray      *ml, *mlist=[NSMutableArray array], *layerList;
    NSRect              mBounds, pageRect = NSZeroRect, newPageRect = NSZeroRect, oldFrame, visibleRect;
    NSPoint             mPosition = NSZeroPoint, mOffset, lr, ll, ur, ul, center, dm, pOffset = {55.0, 55.0};
    int                 i, orientation = [pi orientation];
    DocView             *docView = [self documentView];
    float               width, height, scale = [docView scaleFactor];

    cropPath = vhfPathWithPathComponents([[NSBundle mainBundle] resourcePath], CROPMARK_FOLDER, nil);

    if ([piDict objectForKey:NSPrintSavePath])
    {
        pStr = [NSString stringWithString:[piDict objectForKey:NSPrintSavePath]];
        pExt = [pStr pathExtension];

        npStr = [[[pStr stringByDeletingPathExtension] stringByAppendingString:@"_c"] stringByAppendingPathExtension:pExt];
        [piDict setObject:npStr forKey:NSPrintSavePath];
    }

    /* create mlist - separation marks */
    pageRect.size = newPageRect.size = [pi paperSize];
    ll = ul = lr = pageRect.origin;
    ur.y = ul.y = ul.y + pageRect.size.height;
    ur.x = lr.x = lr.x + pageRect.size.width;

    /* correct printInfo for new format */
    newPageRect.size.width += pOffset.x*2.0;
    newPageRect.size.height += pOffset.y*2.0;
    [pi setPaperSize:newPageRect.size];
    //[pi setPaperName:[NSString stringWithFormat:@"Other"]];
    [pi setOrientation:orientation];

    /* set scale to 1.0
     * and add pOffset to frameSize
     */
    scale = [docView scaleFactor];
    visibleRect = [docView visibleRect]; // needed later to calc the center to scroll back
    oldFrame = [docView frame];
    width  = oldFrame.size.width  / scale;
    height = oldFrame.size.height / scale;
    width  += (pOffset.x*2.0); // * scale
    height += (pOffset.y*2.0); // * scale
    [window disableFlushWindow];
    [docView scaleUnitSquareToSize:NSMakeSize(1.0/scale, 1.0/scale)];
    [docView setFrameSize:NSMakeSize(width, height)];

    /* up left - get separation mark */
    mStr = vhfPathWithPathComponents(cropPath, @"leftup.cenon", nil);
    ml = [Document listFromFile:mStr];
    /* get mark position */
    for (i=[ml count]-1; i>=0; i--)
    {   VGraphic	*g = [ml objectAtIndex:i];

        if ([g isMemberOfClass:[VMark class]])
        {   mPosition = [(VMark*)g origin];
            [ml removeObjectAtIndex:i]; // remove mark from list
            break;
        }
    }
    mOffset.x = ((mPosition.x - ul.x) * -1.0) + pOffset.x;
    mOffset.y = ((mPosition.y - ul.y) * -1.0) + pOffset.y;
    /* move mark to upleft */
    for (i=[ml count]-1; i>=0; i--)
        [[ml objectAtIndex:i] moveBy:mOffset];
    /* add mark objects to mlist */
    for (i=[ml count]-1; i>=0; i--)
        [mlist addObject:[ml objectAtIndex:i]];

    /* down right - (upleft 180 rotatet) get separation mark */
    mStr = vhfPathWithPathComponents(cropPath, @"leftup.cenon", nil);
    ml = [Document listFromFile:mStr];
    mBounds = [docView boundsOfArray:ml withKnobs:NO];
    center.x = mBounds.origin.x + mBounds.size.width/2.0;
    center.y = mBounds.origin.y + mBounds.size.height/2.0;
    /* rotate around 180 */
    for (i=[ml count]-1; i>=0; i--)
        [[ml objectAtIndex:i] setAngle:180.0 withCenter:center];
    /* get mark position */
    for (i=[ml count]-1; i>=0; i--)
    {   VGraphic	*g = [ml objectAtIndex:i];

        if ([g isMemberOfClass:[VMark class]])
        {   mPosition = [(VMark*)g origin];
            [ml removeObjectAtIndex:i]; // remove mark from list
            break;
        }
    }
    mOffset.x = ((mPosition.x - lr.x) * -1.0) + pOffset.x;
    mOffset.y = ((mPosition.y - lr.y) * -1.0) + pOffset.y;
    /* move mark to upleft */
    for (i=[ml count]-1; i>=0; i--)
        [[ml objectAtIndex:i] moveBy:mOffset];
    /* add mark objects to mlist */
    for (i=[ml count]-1; i>=0; i--)
        [mlist addObject:[ml objectAtIndex:i]];

    /* right up - get separation mark */
    mStr = vhfPathWithPathComponents(cropPath, @"rightup.cenon", nil);
    ml = [Document listFromFile:mStr];
    /* get mark position */
    for (i=[ml count]-1; i>=0; i--)
    {   VGraphic	*g = [ml objectAtIndex:i];

        if ([g isMemberOfClass:[VMark class]])
        {   mPosition = [(VMark*)g origin];
            [ml removeObjectAtIndex:i]; // remove mark from list
            break;
        }
    }
    mOffset.x = ((mPosition.x - ur.x) * -1.0) + pOffset.x;
    mOffset.y = ((mPosition.y - ur.y) * -1.0) + pOffset.y;
    /* move mark to upleft */
    for (i=[ml count]-1; i>=0; i--)
        [[ml objectAtIndex:i] moveBy:mOffset];
    /* add mark objects to mlist */
    for (i=[ml count]-1; i>=0; i--)
        [mlist addObject:[ml objectAtIndex:i]];

    /* down left - (right up rotate with 180) get separation mark */
    mStr = vhfPathWithPathComponents(cropPath, @"rightup.cenon", nil);
    ml = [Document listFromFile:mStr];
    mBounds = [docView boundsOfArray:ml withKnobs:NO];
    center.x = mBounds.origin.x + mBounds.size.width/2.0;
    center.y = mBounds.origin.y + mBounds.size.height/2.0;
    /* rotate around 180 */
    for (i=[ml count]-1; i>=0; i--)
        [[ml objectAtIndex:i] setAngle:180.0 withCenter:center];
    /* get mark position */
    for (i=[ml count]-1; i>=0; i--)
    {   VGraphic	*g = [ml objectAtIndex:i];

        if ([g isMemberOfClass:[VMark class]])
        {   mPosition = [(VMark*)g origin];
            [ml removeObjectAtIndex:i]; // remove mark from list
            break;
        }
    }
    mOffset.x = ((mPosition.x - ll.x) * -1.0) + pOffset.x;
    mOffset.y = ((mPosition.y - ll.y) * -1.0) + pOffset.y;
    /* move mark to upleft */
    for (i=[ml count]-1; i>=0; i--)
        [[ml objectAtIndex:i] moveBy:mOffset];
    /* add mark objects to mlist */
    for (i=[ml count]-1; i>=0; i--)
        [mlist addObject:[ml objectAtIndex:i]];

    /* down middle */
    mStr = vhfPathWithPathComponents(cropPath, @"middledown.cenon", nil);
    ml = [Document listFromFile:mStr];
    /* get mark position */
    for (i=[ml count]-1; i>=0; i--)
    {   VGraphic	*g = [ml objectAtIndex:i];

        if ([g isMemberOfClass:[VMark class]])
        {   mPosition = [(VMark*)g origin];
            [ml removeObjectAtIndex:i]; // remove mark from list
            break;
        }
    }
    dm.x = ll.x + pageRect.size.width/2.0;
    dm.y = ll.y;
    mOffset.x = ((mPosition.x - dm.x) * -1.0) + pOffset.x;
    mOffset.y = ((mPosition.y - dm.y) * -1.0) + pOffset.y;
    /* move mark to upleft */
    for (i=[ml count]-1; i>=0; i--)
        [[ml objectAtIndex:i] moveBy:mOffset];
    /* add mark objects to mlist */
    for (i=[ml count]-1; i>=0; i--)
        [mlist addObject:[ml objectAtIndex:i]];

    /* right middle */
    mStr = vhfPathWithPathComponents(cropPath, @"middledown.cenon", nil);
    ml = [Document listFromFile:mStr];
    mBounds = [docView boundsOfArray:ml withKnobs:NO];
    center.x = mBounds.origin.x + mBounds.size.width/2.0;
    center.y = mBounds.origin.y + mBounds.size.height/2.0;
    /* rotate around 180 */
    for (i=[ml count]-1; i>=0; i--)
        [[ml objectAtIndex:i] setAngle:-90.0 withCenter:center];
    /* get mark position */
    for (i=[ml count]-1; i>=0; i--)
    {   VGraphic	*g = [ml objectAtIndex:i];

        if ([g isMemberOfClass:[VMark class]])
        {   mPosition = [(VMark*)g origin];
            [ml removeObjectAtIndex:i]; // remove mark from list
            break;
        }
    }
    dm.x = ll.x + pageRect.size.width;
    dm.y = ll.y + pageRect.size.height/2.0;
    mOffset.x = ((mPosition.x - dm.x) * -1.0) + pOffset.x;
    mOffset.y = ((mPosition.y - dm.y) * -1.0) + pOffset.y;
    /* move mark to upleft */
    for (i=[ml count]-1; i>=0; i--)
        [[ml objectAtIndex:i] moveBy:mOffset];
    /* add mark objects to mlist */
    for (i=[ml count]-1; i>=0; i--)
        [mlist addObject:[ml objectAtIndex:i]];

    /* left middle */
    mStr = vhfPathWithPathComponents(cropPath, @"middledown.cenon", nil);
    ml = [Document listFromFile:mStr];
    mBounds = [docView boundsOfArray:ml withKnobs:NO];
    center.x = mBounds.origin.x + mBounds.size.width/2.0;
    center.y = mBounds.origin.y + mBounds.size.height/2.0;
    /* rotate around 180 */
    for (i=[ml count]-1; i>=0; i--)
        [[ml objectAtIndex:i] setAngle:90.0 withCenter:center];
    /* get mark position */
    for (i=[ml count]-1; i>=0; i--)
    {   VGraphic	*g = [ml objectAtIndex:i];

        if ([g isMemberOfClass:[VMark class]])
        {   mPosition = [(VMark*)g origin];
            [ml removeObjectAtIndex:i]; // remove mark from list
            break;
        }
    }
    dm.x = ll.x;
    dm.y = ll.y + pageRect.size.height/2.0;
    mOffset.x = ((mPosition.x - dm.x) * -1.0) + pOffset.x;
    mOffset.y = ((mPosition.y - dm.y) * -1.0) + pOffset.x;
    /* move mark to upleft */
    for (i=[ml count]-1; i>=0; i--)
        [[ml objectAtIndex:i] moveBy:mOffset];
    /* add mark objects to mlist */
    for (i=[ml count]-1; i>=0; i--)
        [mlist addObject:[ml objectAtIndex:i]];

    /* file string */
    dm.x = (ul.x + 36.0) + pOffset.x;
    dm.y = (ul.y + 18.0) + pOffset.y;
    {   VText	*text = [VText textGraphic];
        NSFont	*fObj;
        NSColor	*col = [NSColor colorWithDeviceCyan:1.0 magenta:1.0 yellow:1.0 black:1.0 alpha:1.0];

        if (!(fObj = [NSFont fontWithName:@"Helvetica" size:12.0]))
            fObj = [NSFont fontWithName:@"Courier" size:12.0];
        [text setFont:fObj];
        [text setString:[NSString stringWithFormat:@"%@  %@  ", name,
            [[NSCalendarDate calendarDate] descriptionWithCalendarFormat:@"%Y-%m-%d  %H:%M"]]];
        [text setFillColor:col];
        [text moveTo:dm];

        [mlist addObject:text];
    }

    /* color text - each color its own ! (layerlist layerObject list last object) */
    dm.x = (ur.x - 120.0) + pOffset.x;
    dm.y = (ur.y + 18.0) + pOffset.y;
    {   VText	*text = [VText textGraphic];
        NSFont	*fObj;
        NSColor	*col = [NSColor colorWithDeviceCyan:1.0 magenta:1.0 yellow:1.0 black:1.0 alpha:1.0];

        if (!(fObj = [NSFont fontWithName:@"Helvetica" size:12.0]))
            fObj = [NSFont fontWithName:@"Courier" size:12.0];
        [text setFont:fObj];
        [text setString:[NSString stringWithFormat:@"Cyan  "]];
        [text setFillColor:col];
        [text moveTo:dm];

        [mlist addObject:text];
    }

    /* add an Layerobject with mlist objects at index 0 to layerlist - and remove this after separation */
    layerList = [docView layerList];
    /* move layerLists by page Offset */
    {   int	l, cnt = [layerList count];

        for (l=0; l<cnt; l++)
        {	LayerObject	*layerObject = [layerList objectAtIndex:l];

            if ( [layerObject state] ) // visible
            {   NSMutableArray	*llist = [layerObject list];
                int			i, lcnt = [llist count];

                for (i=0; i<lcnt; i++)
                    [[llist objectAtIndex:i] moveBy:pOffset];
            }
        }
    }
    {   LayerObject	*layerObject = [LayerObject layerObjectWithFrame:[docView bounds]];

        [layerObject setString:[NSString stringWithFormat:@"Separation Marks For Printing"]];
        [layerList insertObject:layerObject atIndex:0];
        [layerObject addObjectsFromArray:mlist];
        [[docView slayList] insertObject:[NSMutableArray array] atIndex:0];
    }

    /* cyan */
    pool = [NSAutoreleasePool new];
    sepColor = [NSColor colorWithDeviceCyan:1.0 magenta:0.0 yellow:0.0 black:0.0 alpha:1.0];
    [docView setSeparationColor:sepColor];
    [sepColor release];
    /* op is allready currentOperation !!!! */
    [op setShowsPrintPanel:NO]; // else the user get a second printpanel
    [op runOperation];
    [pool release];

    /* magenta */
    /* op ist nun leeeeeeeeeeeer/fertig */
    pool = [NSAutoreleasePool new];
    ml = [[layerList objectAtIndex:0] list]; // set Color string
    [[ml objectAtIndex:[ml count]-1] setString:[NSString stringWithFormat:@"Magenta  "]];
    sop = [NSPrintOperation printOperationWithView:docView printInfo:pi];
    [sop setShowsPrintPanel:NO];
    spi = [sop printInfo]; // from here we add a "_c" to the NSPrintSavePath string in printInfo dictionary
    piDict = [spi dictionary];
    if ([piDict objectForKey:NSPrintSavePath])
    {
        npStr = [[[pStr stringByDeletingPathExtension] stringByAppendingString:@"_m"] stringByAppendingPathExtension:pExt];
        [piDict setObject:npStr forKey:NSPrintSavePath];
    }
    sepColor = [NSColor colorWithDeviceCyan:0.0 magenta:1.0 yellow:0.0 black:0.0 alpha:1.0];
    [docView setSeparationColor:sepColor];
    [sepColor release];
    [sop runOperation];
    [pool release];

    /* yellow */
    pool = [NSAutoreleasePool new];
    ml = [[layerList objectAtIndex:0] list]; // set Color string
    [[ml objectAtIndex:[ml count]-1] setString:[NSString stringWithFormat:@"Yellow  "]];
    sop = [NSPrintOperation printOperationWithView:docView printInfo:pi];
    [sop setShowsPrintPanel:NO];
    spi = [sop printInfo];
    piDict = [spi dictionary];
    if ([piDict objectForKey:NSPrintSavePath])
    {
        npStr = [[[pStr stringByDeletingPathExtension] stringByAppendingString:@"_y"] stringByAppendingPathExtension:pExt];
        [piDict setObject:npStr forKey:NSPrintSavePath];
    }
    sepColor = [NSColor colorWithDeviceCyan:0.0 magenta:0.0 yellow:1.0 black:0.0 alpha:1.0];
    [docView setSeparationColor:sepColor];
    [sepColor release];
    [sop runOperation];
    [pool release];

    /* black / kontrast */
    pool = [NSAutoreleasePool new];
    ml = [[layerList objectAtIndex:0] list]; // set Color string
    [[ml objectAtIndex:[ml count]-1] setString:[NSString stringWithFormat:@"Black  "]];
    sop = [NSPrintOperation printOperationWithView:docView printInfo:pi];
    [sop setShowsPrintPanel:NO];
    spi = [sop printInfo];
    piDict = [spi dictionary];
    if ([piDict objectForKey:NSPrintSavePath])
    {
        npStr = [[[pStr stringByDeletingPathExtension] stringByAppendingString:@"_k"] stringByAppendingPathExtension:pExt];
        [piDict setObject:npStr forKey:NSPrintSavePath];
    }
    sepColor = [NSColor colorWithDeviceCyan:0.0 magenta:0.0 yellow:0.0 black:1.0 alpha:1.0];
    [docView setSeparationColor:sepColor];
    [sepColor release];
    [sop runOperation];
    [pool release];

    /* color list */
        //ml = [[layerList objectAtIndex:0] list]; // set Color string
        //[[ml objectAtIndex:[ml count]-1] setString:[NSString stringWithFormat:@"Black  "]];


    /* remove layer with marks */
    [layerList removeObjectAtIndex:0];
    [[docView slayList] removeObjectAtIndex:0];
    [docView selectLayerAtIndex:0];

    /* correct printInfo */
    [pi setPaperSize:pageRect.size];
    [pi setPaperName:paperName];
    [pi setOrientation:orientation];

    /* move to old position */
    pOffset.x = -pOffset.x;
    pOffset.y = -pOffset.y;
    {   int	l, cnt = [layerList count];

        for (l=0; l<cnt; l++)
        {	LayerObject	*layerObject = [layerList objectAtIndex:l];

            if ( [layerObject state] ) // visible
            {   NSMutableArray	*llist = [layerObject list];
                int			i, lcnt = [llist count];

                for (i=0; i<lcnt; i++)
                    [[llist objectAtIndex:i] moveBy:pOffset];
            }
        }
    }

    /* scale view back to old scale */
    [docView scaleUnitSquareToSize:NSMakeSize(scale, scale)];
    [docView setFrameSize:oldFrame.size];
    /* scroll docView to old position */
    [docView scrollPoint:visibleRect.origin];
    [docView drawAndDisplay];

    [window enableFlushWindow];

    [pool0 release];
    [[self documentView] setSeparationColor:nil];
}

/*
 * modified: 2013-01-02 (10.8: remove paper margins by adjusting print view)
 */
- (void)printDocument:sender
{   NSPrintOperation    *op;
    NSPrintPanel        *pp;
    NSPrintInfo         *pi;
    DocView             *docView = [self documentView];
    NSRect              visibleRect, oldFrame, pageBounds = [printInfo imageablePageBounds];
    VFloat              width, height, scale = [docView scaleFactor];

    /* set scale to 1.0 */
    scale = [docView scaleFactor];
    visibleRect = [docView visibleRect]; // needed later to calc the center to scroll back
    oldFrame = [docView frame];
    width  = oldFrame.size.width  / scale;
    height = oldFrame.size.height / scale;
#ifdef __APPLE__
    /* Apple 10.8: the PrintInfo margins are 0, but there are paper margins PMPaperMargins()
     * we could create a custom paper with PMPaperCreateCustom() or adjust our print view
     */
    if ( NSAppKitVersionNumber > NSAppKitVersionNumber10_7 )    // Workaround Max OS 10.8: make view smaller by paper margins
    {   width  -= ([printInfo paperSize].width  - pageBounds.size.width);
        height -= ([printInfo paperSize].height - pageBounds.size.height);
    }
#endif
    [window disableFlushWindow];
    [docView scaleUnitSquareToSize:NSMakeSize(1.0/scale, 1.0/scale)];
    [docView setFrameSize:NSMakeSize(width, height)];
    /* Workaround Mac OS 10.8: we have to translate printing by the page margin to remove the margin */
#ifdef __APPLE__
    if ( NSAppKitVersionNumber > NSAppKitVersionNumber10_7 )
        [docView translateOriginToPoint:NSMakePoint(-pageBounds.origin.x, -pageBounds.origin.y)];
#endif

    //[printInfo setHorizontalPagination:NSClipPagination];
    //[printInfo setVerticalPagination:NSClipPagination];

    /* multi page document */
    if ([docView isMultiPage])
    {
        op = [NSPrintOperation printOperationWithView:[self documentView] printInfo:printInfo];
        [op setShowsPrintPanel:YES];
        [op runOperation];

        // FIXME: restore enabled/disabled pages
    }
    /* single page document */
    else
    {
        /* FIXME: GNUstep printing needs to be fixed to work with the code below */
#ifdef GNUSTEP_BASE_VERSION
        op = [NSPrintOperation printOperationWithView:[self documentView] printInfo:printInfo];
        [op setShowPanels:YES];
        [op runOperation];
#else
        if (![printInfo printer] && [NSPrintInfo defaultPrinter])
            [printInfo setPrinter:[NSPrintInfo defaultPrinter]];	// set default printer for the first time

        op = [NSPrintOperation printOperationWithView:[self documentView] printInfo:printInfo];
        [op setShowsPrintPanel:YES];
        [NSPrintOperation setCurrentOperation:op];

        pp = [NSPrintPanel printPanel];
        [pp setAccessoryView:[[(App*)NSApp printPanelAccessory] retain]];
        //[pp addAccessoryController:[[(App*)NSApp printPanelAccessory] retain]];
        [op setPrintPanel:pp];

        if ([pp runModal] == NSCancelButton)
        {
            [op setShowsPrintPanel:NO]; // else the user get a second printpanel
            //[op runOperation];	// this will end the operation ! (this deletes a saved file from the prev. operation !)
        }
        else if (![[(App*)NSApp ppaRadio] selectedRow])		// composite
        {
            [op setShowsPrintPanel:NO]; // else the user get a second printpanel
            [op runOperation];
        }
        else							// color separation
        {   [[(App*)NSApp ppaRadio] selectCellAtRow:0 column:0];	// 0 is composite
            [self printSeparation:op];
        }
        pi = [op printInfo];
        [printInfo release];
        printInfo = [pi retain];	// remember printInfo values for the next time ! (2005-05-06)
#endif
    }
    [op cleanUpOperation];

#ifdef __APPLE__
    /* translate back */
    if ( NSAppKitVersionNumber > NSAppKitVersionNumber10_7 )
        [docView translateOriginToPoint:NSMakePoint(pageBounds.origin.x, pageBounds.origin.y)];
#endif
    /* scale view back to old scale */
    [docView scaleUnitSquareToSize:NSMakeSize(scale, scale)];
    [docView setFrameSize:oldFrame.size];
    /* scroll docView to old position */
    [docView scrollPoint:visibleRect.origin];
    [docView drawAndDisplay];

    [window enableFlushWindow];
}

/*
 * Puts up a PageLayout panel and allows the user to pick a different
 * size paper to work on.  After she does so, the view is resized to the
 * new paper size.
 * Since the PrintInfo is effectively part of the document, we note that
 * the document is now dirty (by performing the dirty method).
 */
- (void)changeLayout:sender
{   //NSRect		frame;
    //float		lm, rm, tm, bm;
    //NSSize		paperSize;
    NSPrintInfo		*tempPrintInfo;

    tempPrintInfo = [[printInfo copy] autorelease];

    if ( [[NSPageLayout pageLayout] runModalWithPrintInfo:tempPrintInfo] == NSOKButton )
    {
        [tempPrintInfo setLeftMargin:0.0];
        [tempPrintInfo setRightMargin:0.0];
        [tempPrintInfo setTopMargin:0.0];
        [tempPrintInfo setBottomMargin:0.0];

/*
	paperSize = [printInfo paperSize];
	lm = [printInfo leftMargin];
	rm = [printInfo rightMargin];
	tm = [printInfo topMargin];
	bm = [printInfo bottomMargin];
	if (lm < 0.0 || rm < 0.0 || tm < 0.0 || bm < 0.0 ||
	    paperSize.width - lm - rm < 0.0 || paperSize.height - tm - bm < 0.0)
	    NSRunAlertPanel(nil, BAD_MARGINS, nil, nil, nil);
	else
*/
        {
            [printInfo release];
            printInfo = [tempPrintInfo retain];
            //frame = calcFrame(printInfo);
            //[view setFrameSize:(NSSize){ frame.size.width, frame.size.height }];
            //[self resetScrollers];
            //[view display];
            //[self dirty:self];
	}
    } 
}

- (void)setMagazineIndex:(int)i
{
    magazineIndex = i; 
}

- (int)magazineIndex
{
    return magazineIndex;
}

/* delegate methods
 */
- (BOOL)windowShouldClose:(id)sender
{   int	l;

    if ( dirty )
        switch (NSRunAlertPanel(CLOSEWINDOW_STRING, SAVECHANGES_STRING, SAVE_STRING, DONTSAVE_STRING, CANCEL_STRING, [sender title]))
        {
            case NSAlertDefaultReturn:      // save
                [self save:nil];
                break;
            case NSAlertAlternateReturn:    // dont save
                break;
            default:                        // cancel
                return NO;
        }

    for (l=[[[self documentView] layerList] count]-1; l>=0; l--)
        [[[[self documentView] layerList] objectAtIndex:l] setDirty:NO];
    [window endEditingFor:nil]; // end editing of text
    [window setDocument:nil];
    [self autorelease];

    return YES;
}
- (void)windowDidResignKey:(NSNotification *)notification
{   [window windowDidResignKey:notification]; }
- (void)windowDidBecomeKey:(NSNotification *)notification
{   [window windowDidBecomeKey:notification]; }
- (void)windowDidBecomeMain:(NSNotification *)notification
{   [window windowDidBecomeMain:notification]; }
- (void)windowDidResignMain:(NSNotification *)notification
{
    [window endEditingFor:nil]; // end editing of text
    [[NSNotificationCenter defaultCenter] postNotificationName:DocWindowDidChange
                                                        object:nil];
}


- (void)dealloc
{
    /*if ( dirty && NSRunAlertPanel(@"", SAVECHANGES_STRING, SAVE_STRING, DONTSAVE_STRING, nil, [self name]) == NSAlertDefaultReturn )
        [self save];*/
    [printInfo release];
    [fontObject release];
    [docSettingsDict release];
    [super dealloc];
}

@end
