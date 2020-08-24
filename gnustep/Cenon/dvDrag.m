/* dvDrag.m
 * Drag additions for Cenon DocView class
 *
 * Copyright (C) 1997-2003 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1997-11-05
 * modified: 2003-06-26
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
#include "DocView.h"
#include "Document.h"
#include "App.h"
#include "locations.h"
#include "messages.h"

#define ERROR -1

@implementation DocView(Drag)

/*
 * Registers the view with the Workspace Manager so that when the
 * user picks up an icon in the Workspace and drags it over our view
 * and lets go, dragging messages will be sent to our view.
 * We register for NXFilenamePboardType because we handle data link
 * files and NXImage and Text files dragged into draw as well as any
 * random file when the Control key is depressed (indicating a link
 * operation) during the drag.  We also accept anything that NXImage
 * is able to handle (even if it's not in a file, i.e., it's directly
 * in the dragged Pasteboard--unusual, but we can handle it, so why
 * not?).
 */
- (void)registerForDragging
{
    [self registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];
    [self registerForDraggedTypes:[NSArray arrayWithObjects:NSColorPboardType, nil]];
    [self registerForDraggedTypes:[NSImage imagePasteboardTypes]]; 
}

/*
 * This is where we determine whether the contents of the dragging Pasteboard
 * is acceptable.  The gvFlags.drag*Ok flags say whether we can accept
 * the dragged information as a result of a copy or link (or both) operation.
 * If NXImage can handle the Pasteboard, then we know we can do copy.  We
 * always know we can do link as long as we have a linkManager.  We cache as
 * much of the answer around as we can so that draggingUpdated: will be fast.
 * Of course, we can't cache the part of the answer which is dependent upon
 * the position inside our view (important for colors).
 */
- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender
{//	Pasteboard *pboard;
    //	NXDragOperation sourceMask;

    //	sourceMask = [sender draggingSourceOperationMask];
    //	pboard = [sender draggingPasteboard];

    return NSDragOperationCopy;
}


/* A couple of convenience methods to determine what kind of file we have. */

static BOOL isNSImageFile(NSString * file)
{   NSString * extension = [file pathExtension];
    return ([NSImageRep imageRepClassForFileType:extension]) ? YES : NO;
}

static BOOL isRTFFile(NSString * file)
{   NSString * extension = [file pathExtension];
    return ([extension isEqual:@"rtf"]) ? YES : NO;
}

static BOOL isPSFile(NSString * file)
{   NSString * extension = [file pathExtension];
    return ([extension isEqual:@"ps"] || [extension isEqual:@"eps"] || [extension isEqual:@"ai"]) ? YES : NO;
}

/*
 * Creates a VGraphic from a file NXImage or the Text object can handle
 * (or just allows linking it if NXImage nor Text can handle the file).
 * It links to it if the doLink is YES.
 *
 * If we are linking, then we ask the user if she wants the file's icon,
 * a link button, or (if we can do so) the actually contents of the file
 * to appear in the view.
 *
 * Note the use of the workspace protocol object to get information about
 * the file. We know that we cannot import the contents of some applications,
 * so we don't even give the user the option of trying to do so.
 *
 * Again, if it ends up that we are linking, we just call the all-powerful
 * addLink:toGraphic:at:update: method in gvLinks.m, otherwise, we just
 * call placeGraphic:at:.
 */
- (int)createGraphicForDraggedFile:(NSString*)file at:(NSPoint)p
{   NSString		*fileType;
    VGraphic		*graphic;
    BOOL		isImportable;
    NSArray		*list;

    isImportable = isRTFFile(file);
    if (!isImportable && [[NSWorkspace sharedWorkspace] getInfoForFile:file application:NULL type:&fileType])
	isImportable = ([fileType isEqual:NSPlainFileType]);

    [(App*)NSApp setCurrentDocument:document];	// so that graphic objects know about the window and the view

    if (isPSFile(file))
    {
        list = [(App*)NSApp listFromPSFile:file];
        graphic = [[[VGroup allocWithZone:(NSZone *)[self zone]] initWithList:list] autorelease];
    }
    else if (isNSImageFile(file))
        graphic = [[[VImage allocWithZone:(NSZone *)[self zone]] initWithFile:file] autorelease];
    else if ( isRTFFile(file) )
        graphic = [[[VText allocWithZone:(NSZone *)[self zone]] initWithFile:file] autorelease];
    else if ( [fileType isEqual:DOCUMENT_EXT] )
        graphic = [[[VGroup allocWithZone:(NSZone *)[self zone]] initWithFile:file] autorelease];
    else if ( (list = [(App*)NSApp listFromFile:file]) )
    {   list = [self singleList:list];
        graphic = [[[VGroup allocWithZone:(NSZone *)[self zone]] initWithList:list] autorelease];
    }
    else
    {   [(App*)NSApp setCurrentDocument:nil];
        return NO;
    }

    if ( graphic && [self placeGraphic:graphic at:p] )
    {
        [(App*)NSApp setCurrentDocument:nil];
        return YES;
    }
    [(App*)NSApp setCurrentDocument:nil];

    NSRunAlertPanel(nil, nil, BAD_IMAGE, nil, nil, nil);

    return ERROR;
}
 
/*
 * If we get this far, we are pretty sure we can succeed (though we're
 * not 100% sure because it might be, for example, a WriteNow file
 * without the link button down).
 *
 * We return YES here and do the work in conclude so that we don't
 * timeout if we are dragging in a big image or something that will
 * take a long time to import (or if we have to ask the user a question
 * to figure out how to import the dragged thing).  The bummer here
 * is that if creating the image should fail for some reason, we can't
 * give the slide-back feedback because it's too late to do so in
 * concludeDragOperation:.
 */
- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
    return YES;
}

/*
 * Actually do the "drop" of the drag here.
 *
 * Note that if we successfully dropped, we bring the window
 * we dropped into to the front and activate ourselves.  We also
 * update our inspectors, etc. (this is especially important for
 * the LinkInspector window!) by calling updateWindows.
 */
- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{   NSPoint		p;
    NSPasteboard	*pboard;
    NSArray		*filenameArray;
    int			foundOne = NO;

    p = [sender draggingLocation];
    p = [self convertPoint:p fromView:nil];

    pboard = [sender draggingPasteboard];

    if (e2IncludesType([pboard types], NSFilenamesPboardType))
    {   int nameCount;
	int i = 0;

	filenameArray = [pboard propertyListForType:NSFilenamesPboardType];
	nameCount = [filenameArray count];

	for ( i=0; i<nameCount; i++ )
        {   NSString	*currFile = [filenameArray objectAtIndex:i];

	    foundOne = [self createGraphicForDraggedFile:currFile at:p] || foundOne;
	}
    }

    if (foundOne > 0)
    {
        [NSApp activateIgnoringOtherApps:YES];
        [[self window] makeKeyAndOrderFront:self];
        [NSApp updateWindows];
    }
}

@end
